#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/docker-in-docker
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/docker-in-docker/.probe && rm /home/ubuntu/docker-in-docker/.probe'

# Run the hook as a container create does.
/usr/local/share/docker-in-docker/init.sh

check "DOCKER_CONFIG exported" bash -lc '[ "$DOCKER_CONFIG" = /home/ubuntu/docker-in-docker ]'
# A context needs no daemon, so creating one shows where the CLI keeps its config.
check "the CLI writes its config to the state dir" \
  bash -lc 'docker context create probe --docker host=unix:///run/docker-rootless.sock >/dev/null && test -d /home/ubuntu/docker-in-docker/contexts'

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/docker-in-docker/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/docker-in-docker/state-dir.sh docker-in-docker /var/docker-in-docker'
check "the refusal names the home" \
  bash -c '/usr/local/share/docker-in-docker/state-dir.sh docker-in-docker /var/docker-in-docker 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
