#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The daemon starts in the background, so wait for it. Going through DOCKER_HOST covers
# the published name and its link as well, which naming a listener has to leave standing.
check "daemon reachable" bash -c 'for _ in $(seq 30); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'
# Naming a listener replaces the default, so the daemon's own socket is named alongside.
check "own socket still answers" bash -c '[ -S "/run/user/$(id -u)/docker.sock" ]'
# The shared directory answers the same daemon, which the matching engine id shows.
check "shared socket answers" bash -c '
  own=$(docker info --format "{{.ID}}")
  shared=$(docker -H unix:///run/docker-host/docker.sock info --format "{{.ID}}")
  [ -n "$own" ] && [ "$own" = "$shared" ]'
# The mount arrives owned by root, and the remote user's id is what carries back out of it.
check "shared socket belongs to the remote user" bash -c '[ -O /run/docker-host/docker.sock ]'
# The daemon's log holds the warnings its setup emits, which a failure here should carry.
check "nested container runs" bash -c 'docker run --rm hello-world || { echo "--- dockerd.log ---" >&2; cat /tmp/dockerd.log >&2; exit 1; }'

# Report result
reportResults
