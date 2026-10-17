#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Wait for the background daemon, reaching it through the published name.
check "daemon reachable" bash -c 'for _ in $(seq 30); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'
# The published name leads to the socket of the user this shell runs as.
check "socket link resolves to the remote user" bash -c '[ "$(readlink /run/docker-rootless.sock)" = "/run/user/$(id -u)/docker.sock" ]'
check "daemon runs rootless" bash -c "docker info --format '{{.SecurityOptions}}' | grep -q rootless"
# Read the container's granted capabilities from pid 1.
check "container is unprivileged" bash -c 'bnd=$(awk "/^CapBnd:/ {print \$2}" /proc/1/status); [ $((0x$bnd >> 21 & 1)) -eq 0 ]'
check "overlay2 storage driver" bash -c "docker info --format '{{.Driver}}' | grep -qx overlay2"
# Show the daemon's log when a check fails.
check "nested container runs" bash -c 'docker run --rm hello-world || { echo "--- dockerd.log ---" >&2; cat /tmp/dockerd.log >&2; exit 1; }'

# Report result
reportResults
