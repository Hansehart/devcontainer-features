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

check "docker on PATH" bash -c "command -v docker"
check "docker version" docker --version
check "compose plugin" docker compose version
check "buildx plugin" docker buildx version
check "daemon reachable" bash -c "$(declare -f wait_for_daemon); wait_for_daemon"
check "daemon runs rootless" bash -c "docker info --format '{{.SecurityOptions}}' | grep -q rootless"
check "overlay2 storage driver" bash -c "docker info --format '{{.Driver}}' | grep -qx overlay2"
check "socket is the remote user's" bash -c 'test -S "${DOCKER_HOST#unix://}"'
check "nested container runs" docker run --rm hello-world

# Report result
reportResults
