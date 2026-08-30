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
# Read against the id this shell runs as, which the link is resolved to at start.
check "socket link resolves to the remote user" bash -c '[ "$(readlink /run/docker-rootless.sock)" = "/run/user/$(id -u)/docker.sock" ]'

# Report result
reportResults
