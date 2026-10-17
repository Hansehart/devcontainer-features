#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Default apparmor and seccomp apply here, so this covers the client alone.
# The rootless_daemon scenario relaxes both and covers the daemon.

check "docker on PATH" bash -c "command -v docker"
check "docker version" docker --version
check "compose plugin" docker compose version
check "buildx plugin" docker buildx version
# An empty environment proves profile.d supplies the socket name to a login shell.
check "login shell gets DOCKER_HOST" bash -c 'env -i bash -lc "echo \$DOCKER_HOST" | grep -qx unix:///run/docker-rootless.sock'
check "socket path is fixed" bash -c '[ "$DOCKER_HOST" = "unix:///run/docker-rootless.sock" ]'
# The default image runs as root, where the entrypoint leaves the daemon down and the socket
# unlinked. The rootless_daemon scenario covers the link for its remote user.
check "root leaves the socket unlinked" bash -c '[ "$(id -u)" = 0 ] && [ ! -e /run/docker-rootless.sock ] && [ ! -L /run/docker-rootless.sock ]'

# Report result
reportResults
