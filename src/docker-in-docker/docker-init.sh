#!/bin/sh
set -e

# Read the user who runs the daemon, as recorded at build.
RUSER="$(cat /usr/local/etc/docker-in-docker/rootless-user 2>/dev/null || true)"

# Start the daemon only for a known non-root user.
if [ "$RUSER" = "root" ] || ! RUSER_ENT="$(getent passwd "$RUSER")"; then
  echo "docker-in-docker: needs a non-root remoteUser, the daemon stays down" >&2
  # Hand off to the container command.
  exec "$@"
  exit 0
fi

# Derive the user's id, home and runtime directory.
RUID="$(echo "$RUSER_ENT" | cut -d: -f3)"
RHOME="$(echo "$RUSER_ENT" | cut -d: -f6)"
RUNTIME_DIR="/run/user/${RUID}"
# Keep the store at a fixed path, so a volume can hold it for any account.
DATA_ROOT=/var/lib/docker-rootless

# Match the firewall backend to the host kernel.
if type iptables-legacy > /dev/null 2>&1 \
   && { grep -qE '^ip_tables\b' /proc/modules || [ -d /sys/module/ip_tables ]; } \
   && update-alternatives --list iptables 2>/dev/null | grep -q '/usr/sbin/iptables-legacy'; then
  # Use the legacy backend when the kernel runs it.
  update-alternatives --set iptables  /usr/sbin/iptables-legacy  || true
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
elif type iptables-nft > /dev/null 2>&1 \
     && update-alternatives --list iptables 2>/dev/null | grep -q '/usr/sbin/iptables-nft'; then
  # Use the nft backend everywhere else.
  update-alternatives --set iptables  /usr/sbin/iptables-nft  || true
  update-alternatives --set ip6tables /usr/sbin/ip6tables-nft || true
fi

export container=docker

# Give the daemon the mounts it expects: securityfs and a private /tmp.
if [ -d /sys/kernel/security ] && ! mountpoint -q /sys/kernel/security; then
  mount -t securityfs none /sys/kernel/security || true
fi
mountpoint -q /tmp || mount -t tmpfs none /tmp || true

# Nest the cgroup controllers wherever the host delegates them.
if [ -f /sys/fs/cgroup/cgroup.controllers ] && mkdir -p /sys/fs/cgroup/init 2>/dev/null; then
  # Move the running processes into a leaf, retrying while they settle.
  cg_tries=0
  until xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null \
        || [ "$cg_tries" -ge 5 ]; do
    sleep 1
    cg_tries=$((cg_tries + 1))
  done
  # Hand the controllers down to that leaf.
  sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
    > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
fi

# Provide the tun device the userspace network stack builds on.
if [ ! -c /dev/net/tun ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200 2>/dev/null || true
  # Open it to the user who runs the network stack.
  chmod 0666 /dev/net/tun 2>/dev/null || true
fi
# Name a missing tun device here, where the cause is clear.
[ -c /dev/net/tun ] \
  || echo "docker-in-docker: no /dev/net/tun, the daemon comes up without networking" >&2

# Create the runtime and store directories for the daemon's user.
mkdir -p "$RUNTIME_DIR" "$DATA_ROOT"
# Keep the runtime directory, which holds the socket, private to that user.
chmod 0700 "$RUNTIME_DIR"
chown "$RUSER":"$RUSER" "$RUNTIME_DIR" "$DATA_ROOT" || true

# Seed the user's daemon settings with the requested ones.
req=/usr/local/etc/docker-in-docker/requested-daemon.json
if [ -s "$req" ] && [ ! -f "${RHOME}/.config/docker/daemon.json" ]; then
  mkdir -p "${RHOME}/.config/docker"
  cp "$req" "${RHOME}/.config/docker/daemon.json"
  chown -R "$RUSER":"$RUSER" "${RHOME}/.config/docker" || true
fi

# Give the id-mapping helpers the capabilities they run with.
for b in /usr/bin/newuidmap /usr/bin/newgidmap; do
  chmod u-s "$b" 2>/dev/null || true
  setcap cap_setuid,cap_setgid+ep "$b" 2>/dev/null || true
done

# Publish the socket under a fixed name for every account.
ln -sfn "${RUNTIME_DIR}/docker.sock" /run/docker-rootless.sock

# Serve a second socket in a mounted directory, for reaching the daemon from outside the
# container. Both listeners are named together; daemon settings that name hosts win.
SHARED_DIR=/run/docker-host
HOSTS=""
if [ -d "$SHARED_DIR" ]; then
  if grep -q '"hosts"' "$req" 2>/dev/null; then
    echo "docker-in-docker: daemonJson already names hosts, so ${SHARED_DIR} is left out" >&2
  else
    # Keep the shared directory private to the daemon's user, since its socket serves anyone
    # who reaches it.
    chown "$RUSER":"$RUSER" "$SHARED_DIR" || true
    chmod 0700 "$SHARED_DIR" || true
    HOSTS="-H unix://${RUNTIME_DIR}/docker.sock -H unix://${SHARED_DIR}/docker.sock"
  fi
fi

start_dockerd() {
  # Clear pid files from an earlier run, so the daemon starts fresh.
  find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || true
  find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || true

  # Run the daemon as its user, with userspace networking and a private pid namespace.
  # shellcheck disable=SC2086  # HOSTS carries separate flags
  runuser -u "$RUSER" -- env \
    HOME="$RHOME" \
    XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    DOCKER_HOST="unix://${RUNTIME_DIR}/docker.sock" \
    PATH="/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/bin" \
    DOCKERD_ROOTLESS_ROOTLESSKIT_NET=slirp4netns \
    DOCKERD_ROOTLESS_ROOTLESSKIT_DETACH_NETNS=false \
    DOCKERD_ROOTLESS_ROOTLESSKIT_FLAGS="--pidns" \
    dockerd-rootless.sh $HOSTS --data-root "$DATA_ROOT" --storage-driver=overlay2 > /tmp/dockerd.log 2>&1
}

# Supervise the daemon in the background, so the container command starts right away.
{
  # Trust any mounted CA, so the daemon reaches registries behind a TLS proxy.
  update-ca-certificates >/dev/null 2>&1 || true

  if ! start_dockerd; then
    echo "docker-in-docker: rootless dockerd exited, retrying once" >&2
    # Copy the daemon's log into the container log, where every run can read it.
    cat /tmp/dockerd.log >&2 || true
    sleep 2
    if ! start_dockerd; then
      echo "docker-in-docker: rootless dockerd failed to start" >&2
      cat /tmp/dockerd.log >&2 || true
    fi
  fi
} &

# Hand off to the container command.
exec "$@"
