#!/bin/sh
set -e

# The unprivileged user that owns the daemon (persisted by install.sh).
RUSER="$(cat /usr/local/share/docker-in-docker/rootless-user 2>/dev/null || echo root)"

# The daemon runs as the remote user, and cannot start as root.
# Resolving the account here lets a name with no passwd entry take this branch too.
if [ "$RUSER" = "root" ] || ! RUSER_ENT="$(getent passwd "$RUSER")"; then
  echo "docker-in-docker: needs a non-root remoteUser, the daemon stays down" >&2
  # Hand off to the container command, or stop when there is none to hand off to.
  exec "$@"
  exit 0
fi

RUID="$(echo "$RUSER_ENT" | cut -d: -f3)"
RHOME="$(echo "$RUSER_ENT" | cut -d: -f6)"
RUNTIME_DIR="/run/user/${RUID}"

# Trust a mounted CA, so registries behind a TLS proxy resolve.
update-ca-certificates >/dev/null 2>&1 || true

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

# Provide the device the userspace network stack builds its tap on.
# A container given the device already keeps this branch closed, and needs no CAP_MKNOD.
if [ ! -c /dev/net/tun ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200 2>/dev/null || true
  # Readable by the remote user, which runs the network stack.
  chmod 0666 /dev/net/tun 2>/dev/null || true
fi

# Prepare the runtime and data directories owned by the remote user.
# The store expects a volume here, since it cannot sit on the container's own overlayfs.
mkdir -p "$RUNTIME_DIR" "${RHOME}/.local/share/docker"
# The runtime directory carries the daemon socket, so it stays shut to the other accounts.
chmod 0700 "$RUNTIME_DIR"
chown "$RUSER":"$RUSER" "$RUNTIME_DIR" "${RHOME}/.local/share/docker" 2>/dev/null || true

# Restore the daemon settings when a volume mounted over the home hides the image's copy.
if [ -f /usr/local/share/docker-in-docker/daemon.json ] \
   && [ ! -f "${RHOME}/.config/docker/daemon.json" ]; then
  mkdir -p "${RHOME}/.config/docker"
  cp /usr/local/share/docker-in-docker/daemon.json "${RHOME}/.config/docker/daemon.json"
  chown -R "$RUSER":"$RUSER" "${RHOME}/.config/docker" 2>/dev/null || true
fi

# Re-privilege the id-mapping helpers, since the image unpack drops their capabilities.
# no-new-privileges has to stay unset, or the kernel ignores what is set below.
for b in /usr/bin/newuidmap /usr/bin/newgidmap; do
  # Keep the caller's identity, which is what the kernel grants the mapping to.
  chmod u-s "$b" 2>/dev/null || true
  # Carry the mapping rights as file capabilities instead.
  setcap cap_setuid,cap_setgid+ep "$b" 2>/dev/null || true
done

# Publish the socket under a name that holds no user id.
# The daemon's own path holds one, and it is only known once the container runs.
ln -sfn "${RUNTIME_DIR}/docker.sock" /run/docker-rootless.sock

# Point login shells at the same name, for the ones that inherit no container environment.
printf 'export DOCKER_HOST=unix:///run/docker-rootless.sock\n' \
  > /etc/profile.d/99-rootless-docker.sh

start_dockerd() {
  # Clear pid files left by an unclean stop, which otherwise block the next start.
  find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || true
  find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || true

  # Run as the remote user, with userspace networking and a private pid namespace.
  # That namespace mounts a procfs of its own, which the kernel permits only where the
  # container's own procfs is left unmasked.
  # Exits unless the container's apparmor and seccomp profiles admit those namespaces.
  # overlay2 needs the store on a real filesystem, which the volume above provides.
  runuser -u "$RUSER" -- env \
    HOME="$RHOME" \
    XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    DOCKER_HOST="unix://${RUNTIME_DIR}/docker.sock" \
    PATH="/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/bin" \
    DOCKERD_ROOTLESS_ROOTLESSKIT_NET=slirp4netns \
    DOCKERD_ROOTLESS_ROOTLESSKIT_MTU=65520 \
    DOCKERD_ROOTLESS_ROOTLESSKIT_DETACH_NETNS=false \
    DOCKERD_ROOTLESS_ROOTLESSKIT_FLAGS="--pidns" \
    DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SANDBOX=auto \
    DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SECCOMP=auto \
    dockerd-rootless.sh --storage-driver=overlay2 > /tmp/dockerd.log 2>&1
}

# Supervise in the background, so the container command starts without waiting.
{
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
