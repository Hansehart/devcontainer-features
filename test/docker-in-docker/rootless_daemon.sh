#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The entrypoint starts the daemon in the background, so give it time to accept commands.
# This reaches it through DOCKER_HOST, so it covers the published socket name and its link too.
check "daemon reachable" bash -c 'for _ in $(seq 30); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'
check "daemon runs rootless" bash -c "docker info --format '{{.SecurityOptions}}' | grep -q rootless"
# The daemon comes up without CAP_SYS_ADMIN. Read pid 1 rather than this shell, whose
# bounding set is empty simply because it is not root.
check "container is unprivileged" bash -c 'bnd=$(awk "/^CapBnd:/ {print \$2}" /proc/1/status); [ $((0x$bnd >> 21 & 1)) -eq 0 ]'
check "overlay2 storage driver" bash -c "docker info --format '{{.Driver}}' | grep -qx overlay2"
# The daemon's log holds the warnings its setup emits, and the entrypoint only surfaces that
# log when the daemon itself failed to start, which says nothing about a run that fails after.
check "nested container runs" bash -c 'docker run --rm hello-world || { echo "--- dockerd.log ---" >&2; cat /tmp/dockerd.log >&2; exit 1; }'

# Report result
reportResults
