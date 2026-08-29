#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Default apparmor and seccomp apply here, so no daemon is expected and only the client is
# checked. The rootless_daemon scenario relaxes both and covers the daemon itself.

check "docker on PATH" bash -c "command -v docker"
check "docker version" docker --version
check "compose plugin" docker compose version
check "buildx plugin" docker buildx version
# Written just before the daemon is backgrounded, so its presence shows the setup finished.
check "entrypoint handed off" bash -c "grep -qF 'DOCKER_HOST=unix:///run/docker-rootless.sock' /etc/profile.d/99-rootless-docker.sh"
check "socket path is fixed" bash -c '[ "$DOCKER_HOST" = "unix:///run/docker-rootless.sock" ]'
# Read against the id this shell runs as, which a path fixed at build time would not match.
check "socket link resolves to the remote user" bash -c '[ "$(readlink /run/docker-rootless.sock)" = "/run/user/$(id -u)/docker.sock" ]'

# Report result
reportResults
