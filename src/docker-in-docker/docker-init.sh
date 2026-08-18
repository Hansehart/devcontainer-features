#!/bin/sh
set -e

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

# Delegate cgroup v2 controllers to a leaf so nested cgroups work.
# Retry the process move, which races with EBUSY on a cold boot.
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  mkdir -p /sys/fs/cgroup/init
  cg_tries=0
  until xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null \
        || [ "$cg_tries" -ge 5 ]; do
    sleep 1
    cg_tries=$((cg_tries + 1))
  done
  sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
    > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
fi

# Start the daemon and wait for it to accept commands.
dockerd_pid=""
start_dockerd() {
  # Clear stale pid files left by an unclean stop.
  find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || true
  find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || true
  dockerd > /tmp/dockerd.log 2>&1 &
  dockerd_pid=$!
  tries=0
  until docker info > /dev/null 2>&1 || [ "$tries" -ge 30 ]; do
    sleep 1
    tries=$((tries + 1))
  done
  docker info > /dev/null 2>&1
}

# Retry once when a stale lock in the persisted data volume kills the first start.
if ! start_dockerd; then
  echo "docker-in-docker: dockerd did not come up, restarting once" >&2
  cat /tmp/dockerd.log >&2 || true
  kill "$dockerd_pid" 2>/dev/null || true
  sleep 1
  start_dockerd || { echo "docker-in-docker: dockerd failed to start" >&2; cat /tmp/dockerd.log >&2 || true; }
fi

# Hand off to the container's original entrypoint/command.
exec "$@"
