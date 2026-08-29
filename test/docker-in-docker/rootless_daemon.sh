#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The entrypoint starts the daemon in the background, so give it time to accept commands.
wait_for_daemon() {
  for _ in $(seq 1 30); do
    docker info > /dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

check "daemon reachable" bash -c "$(declare -f wait_for_daemon); wait_for_daemon"
check "daemon runs rootless" bash -c "docker info --format '{{.SecurityOptions}}' | grep -q rootless"
# The point of 2.0.0: the daemon comes up in a container that was never granted
# CAP_SYS_ADMIN, which privileged would have put in pid 1's bounding set. Read pid 1
# rather than this shell, whose capabilities are empty simply because it is not root.
check "container is unprivileged" bash -c 'bnd=$(awk "/^CapBnd:/ {print \$2}" /proc/1/status); [ $((0x$bnd >> 21 & 1)) -eq 0 ]'
check "overlay2 storage driver" bash -c "docker info --format '{{.Driver}}' | grep -qx overlay2"
# The published name has to reach a live socket.
check "socket is live at the fixed path" bash -c 'test -S /run/docker-rootless.sock && [ "$DOCKER_HOST" = "unix:///run/docker-rootless.sock" ]'
# And to lead to this shell's own runtime directory, which a path fixed at build time misses.
check "socket link resolves to the remote user" bash -c '[ "$(readlink /run/docker-rootless.sock)" = "/run/user/$(id -u)/docker.sock" ]'
check "nested container runs" docker run --rm hello-world

# Report result
reportResults
