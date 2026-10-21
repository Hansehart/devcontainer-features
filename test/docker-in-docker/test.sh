#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The default confinement applies here, so this covers the client; the rootless_daemon
# scenario covers the daemon.

check "docker on PATH" bash -c "command -v docker"
check "docker version" docker --version
check "compose plugin" docker compose version
check "buildx plugin" docker buildx version
# Start from an empty environment, so the socket name comes from the profile alone.
check "login shell gets DOCKER_HOST" bash -c 'env -i bash -lc "echo \$DOCKER_HOST" | grep -qx unix:///run/docker-rootless.sock'
check "socket path is fixed" bash -c '[ "$DOCKER_HOST" = "unix:///run/docker-rootless.sock" ]'
# The default image runs as root, which keeps the daemon down and the socket unlinked; the
# rootless_daemon scenario covers the link.
check "root leaves the socket unlinked" bash -c '[ "$(id -u)" = 0 ] && [ ! -e /run/docker-rootless.sock ] && [ ! -L /run/docker-rootless.sock ]'
# The settings sit with the feature's config, and the seccomp profile with its shipped data.
check "settings in the feature's config dir" test -f /usr/local/etc/docker-in-docker/rootless-user
check "seccomp profile in the shipped data" test -f /usr/local/share/docker-in-docker/seccomp.json
# The store's volume is named after the feature.
check "store volume named after the feature" \
  bash -c "awk '\$5 == \"/var/lib/docker-rootless\" { print \$4 }' /proc/self/mountinfo | grep -q '/docker-in-docker/_data\$'"

# Report result
reportResults
