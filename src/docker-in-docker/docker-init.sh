#!/bin/sh
set -e

# The unprivileged user that owns the daemon (persisted by install.sh).
RUSER="$(cat /usr/local/share/docker-in-docker/rootless-user 2>/dev/null || echo root)"
RUID="$(id -u "$RUSER")"
RHOME="$(getent passwd "$RUSER" | cut -d: -f6)"
RUNTIME_DIR="/run/user/${RUID}"

# The daemon runs as the remote user, and cannot start as root.
if [ "$RUSER" = "root" ]; then
  echo "docker-in-docker: needs a non-root remoteUser, the daemon stays down" >&2
  exec "$@"
fi

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
if [ ! -c /dev/net/tun ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200 2>/dev/null || true
  # Readable by the remote user, which runs the network stack.
  chmod 0666 /dev/net/tun 2>/dev/null || true
fi

# Prepare the runtime and data directories owned by the remote user.
mkdir -p "$RUNTIME_DIR" "${RHOME}/.local/share/docker"
chown "$RUSER":"$RUSER" "$RUNTIME_DIR" "${RHOME}/.local/share/docker" 2>/dev/null || true

# Place the daemon settings where the daemon reads them, once the home mounts are in place.
if [ -f /usr/local/share/docker-in-docker/daemon.json ]; then
  mkdir -p "${RHOME}/.config/docker"
  cp /usr/local/share/docker-in-docker/daemon.json "${RHOME}/.config/docker/daemon.json"
  chown -R "$RUSER":"$RUSER" "${RHOME}/.config/docker" 2>/dev/null || true
fi

# Re-privilege the id-mapping helpers, since the image unpack drops their capabilities.
for b in /usr/bin/newuidmap /usr/bin/newgidmap; do
  # Keep the caller's identity, which is what the kernel grants the mapping to.
  chmod u-s "$b" 2>/dev/null || true
  # Carry the mapping rights as file capabilities instead.
  setcap cap_setuid,cap_setgid+ep "$b" 2>/dev/null || true
done

# Point interactive shells at the socket the daemon listens on.
printf 'export DOCKER_HOST=unix://%s/docker.sock\n' "$RUNTIME_DIR" \
  > /etc/profile.d/99-rootless-docker.sh

start_dockerd() {
  # Clear pid files left by an unclean stop, which otherwise block the next start.
  find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || true
  find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || true

  # Run as the remote user, with userspace networking and a private pid namespace.
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
