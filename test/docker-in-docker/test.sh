#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The harness runs this container under the default apparmor and seccomp profiles, which
# deny the mounts and namespaces RootlessKit needs, so the daemon is not expected here.
# The rootless_daemon scenario relaxes both and covers the daemon itself.

check "docker on PATH" bash -c "command -v docker"
check "docker version" docker --version
check "compose plugin" docker compose version
check "buildx plugin" docker buildx version
# The entrypoint writes this just before it backgrounds the daemon, so its presence shows
# the setup ran to completion and handed off rather than aborting the container.
check "entrypoint handed off" bash -c "grep -qF 'DOCKER_HOST=unix:///run/user/' /etc/profile.d/99-rootless-docker.sh"
check "socket path is the remote user's" bash -c '[ "$DOCKER_HOST" = "unix:///run/user/$(id -u)/docker.sock" ]'

# Report result
reportResults
