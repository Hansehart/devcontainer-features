#!/bin/sh
set -e

# The unprivileged user that owns the daemon (persisted by install.sh).
RUSER="$(cat /usr/local/share/docker-in-docker/rootless-user 2>/dev/null || true)"

# The daemon runs as the remote user, so root and a name with no passwd entry both stop here.
if [ "$RUSER" = "root" ] || ! RUSER_ENT="$(getent passwd "$RUSER")"; then
  echo "docker-in-docker: needs a non-root remoteUser, the daemon stays down" >&2
  # Hand off to the container command, or stop when there is none to hand off to.
  exec "$@"
  exit 0
fi

# Id and home come from that entry, the runtime directory from the id.
RUID="$(echo "$RUSER_ENT" | cut -d: -f3)"
RHOME="$(echo "$RUSER_ENT" | cut -d: -f6)"
RUNTIME_DIR="/run/user/${RUID}"
# A fixed store, so the volume holding it is declarable without knowing the account.
DATA_ROOT=/var/lib/docker-rootless

# Match the iptables backend to the host kernel we share.
if type iptables-legacy > /dev/null 2>&1 \
   && { grep -qE '^ip_tables\b' /proc/modules || [ -d /sys/module/ip_tables ]; } \
   && update-alternatives --list iptables 2>/dev/null | grep -q '/usr/sbin/iptables-legacy'; then
  # Select legacy when /proc/modules shows ip_tables loaded, reflecting the kernel without a modprobe.
  update-alternatives --set iptables  /usr/sbin/iptables-legacy  || true
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
elif type iptables-nft > /dev/null 2>&1 \
     && update-alternatives --list iptables 2>/dev/null | grep -q '/usr/sbin/iptables-nft'; then
  # Select nft when the module is absent.
  update-alternatives --set iptables  /usr/sbin/iptables-nft  || true
  update-alternatives --set ip6tables /usr/sbin/ip6tables-nft || true
fi

export container=docker

# Mount securityfs for AppArmor detection and a private tmpfs on /tmp.
if [ -d /sys/kernel/security ] && ! mountpoint -q /sys/kernel/security; then
  mount -t securityfs none /sys/kernel/security || true
fi
mountpoint -q /tmp || mount -t tmpfs none /tmp || true

# Nest the cgroup controllers where the host delegates them, and pass over where it does not.
if [ -f /sys/fs/cgroup/cgroup.controllers ] && mkdir -p /sys/fs/cgroup/init 2>/dev/null; then
  # Move the existing processes into a leaf, retrying while they settle.
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

# The userspace network stack builds its tap on this device, given or created here.
if [ ! -c /dev/net/tun ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200 2>/dev/null || true
  # Open to the remote user, which runs the network stack.
  chmod 0666 /dev/net/tun 2>/dev/null || true
fi
# Say so here, where the reason is known, since the daemon reports it as a network failure.
[ -c /dev/net/tun ] \
  || echo "docker-in-docker: no /dev/net/tun, the daemon comes up without networking" >&2

# The runtime and store directories, owned by the remote user and the store on a volume.
mkdir -p "$RUNTIME_DIR" "$DATA_ROOT"
# The runtime directory carries the daemon socket, so it stays shut to other accounts.
chmod 0700 "$RUNTIME_DIR"
chown "$RUSER":"$RUSER" "$RUNTIME_DIR" "$DATA_ROOT" || true

# Write the requested daemon settings, which the home directory may not carry yet.
req=/usr/local/share/docker-in-docker/requested-daemon.json
if [ -s "$req" ] && [ ! -f "${RHOME}/.config/docker/daemon.json" ]; then
  mkdir -p "${RHOME}/.config/docker"
  cp "$req" "${RHOME}/.config/docker/daemon.json"
  chown -R "$RUSER":"$RUSER" "${RHOME}/.config/docker" || true
fi

# Restore the id-mapping helpers' capabilities, which the image unpack drops.
for b in /usr/bin/newuidmap /usr/bin/newgidmap; do
  chmod u-s "$b" 2>/dev/null || true
  setcap cap_setuid,cap_setgid+ep "$b" 2>/dev/null || true
done

# Publish the socket under a fixed name, since the daemon's own path carries a user id.
ln -sfn "${RUNTIME_DIR}/docker.sock" /run/docker-rootless.sock

# A directory mounted here carries a second socket, for reaching the daemon from outside the
# container. Naming one listener replaces the default, so both are named, and settings that
# already carry hosts would collide with the flag.
SHARED_DIR=/run/docker-host
HOSTS=""
if [ -d "$SHARED_DIR" ]; then
  if grep -q '"hosts"' "$req" 2>/dev/null; then
    echo "docker-in-docker: daemonJson already names hosts, so ${SHARED_DIR} is left out" >&2
  else
    # The daemon creates the socket as the remote user, whose id the mount carries back out,
    # and the socket answers to whoever opens it, so the directory stays shut to that id alone.
    chown "$RUSER":"$RUSER" "$SHARED_DIR" || true
    chmod 0700 "$SHARED_DIR" || true
    HOSTS="-H unix://${RUNTIME_DIR}/docker.sock -H unix://${SHARED_DIR}/docker.sock"
  fi
fi

start_dockerd() {
  # Clear pid files left by an unclean stop, which otherwise block the next start.
  find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || true
  find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || true

  # Run as the remote user with userspace networking and a private pid namespace, which
  # an unmasked procfs and permissive confinement profiles admit.
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

# Supervise in the background, so the container command starts without waiting.
{
  # Trust a mounted CA, so registries behind a TLS proxy resolve for the daemon.
  update-ca-certificates >/dev/null 2>&1 || true

  if ! start_dockerd; then
    echo "docker-in-docker: rootless dockerd exited, retrying once" >&2
    # Carry the reason into the container log, which is all a CI run gets to read.
    cat /tmp/dockerd.log >&2 || true
    sleep 2
    if ! start_dockerd; then
      echo "docker-in-docker: rootless dockerd failed to start" >&2
      cat /tmp/dockerd.log >&2 || true
    fi
  fi
} &

# Hand off to the container's original entrypoint/command.
exec "$@"
