#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "docker on PATH" bash -c "command -v docker"
check "docker version" docker --version
check "compose plugin" docker compose version
check "buildx plugin" docker buildx version
check "daemon reachable" docker info
check "nested container runs" docker run --rm hello-world

# Report result
reportResults
