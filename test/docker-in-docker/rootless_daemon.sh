#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The daemon starts in the background, so wait for it. Going through DOCKER_HOST covers
# the published name and its link as well.
check "daemon reachable" bash -c 'for _ in $(seq 30); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'
check "daemon runs rootless" bash -c "docker info --format '{{.SecurityOptions}}' | grep -q rootless"
# Pid 1 holds the bounding set the container was granted, which is where CAP_SYS_ADMIN shows.
check "container is unprivileged" bash -c 'bnd=$(awk "/^CapBnd:/ {print \$2}" /proc/1/status); [ $((0x$bnd >> 21 & 1)) -eq 0 ]'
check "overlay2 storage driver" bash -c "docker info --format '{{.Driver}}' | grep -qx overlay2"
# The daemon's log holds the warnings its setup emits, which a failure here should carry.
check "nested container runs" bash -c 'docker run --rm hello-world || { echo "--- dockerd.log ---" >&2; cat /tmp/dockerd.log >&2; exit 1; }'

# Report result
reportResults
