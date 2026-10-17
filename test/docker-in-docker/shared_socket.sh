#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Wait for the background daemon, reaching it through the published name.
check "daemon reachable" bash -c 'for _ in $(seq 30); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'
# The daemon keeps its own socket next to the shared one.
check "own socket still answers" bash -c '[ -S "/run/user/$(id -u)/docker.sock" ]'
# Both sockets lead to the same daemon, as its engine id shows.
check "shared socket answers" bash -c '
  own=$(docker info --format "{{.ID}}")
  shared=$(docker -H unix:///run/docker-host/docker.sock info --format "{{.ID}}")
  [ -n "$own" ] && [ "$own" = "$shared" ]'
# The shared directory belongs to the daemon's user.
check "shared socket belongs to the remote user" bash -c '[ -O /run/docker-host/docker.sock ]'
# The shared directory stays private, since its socket serves anyone who reaches it.
check "shared directory is closed to other accounts" bash -c '[ "$(stat -c %a /run/docker-host)" = "700" ]'
# Show the daemon's log when a check fails.
check "nested container runs" bash -c 'docker run --rm hello-world || { echo "--- dockerd.log ---" >&2; cat /tmp/dockerd.log >&2; exit 1; }'

# Report result
reportResults
