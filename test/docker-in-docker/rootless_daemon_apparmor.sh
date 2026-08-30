#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The entrypoint starts the daemon in the background, so give it time to accept commands.
wait_for_daemon() {
  for _ in $(seq 1 30); do
    docker info > /dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

check "daemon reachable" bash -c "$(declare -f wait_for_daemon); wait_for_daemon"
check "daemon runs rootless" bash -c "docker info --format '{{.SecurityOptions}}' | grep -q rootless"
# The profile has to leave the engine able to work, which the nested run is the proof of.
run_nested() {
  docker run --rm hello-world && return 0
  echo "--- dockerd.log ---" >&2
  cat /tmp/dockerd.log >&2 || true
  return 1
}

check "nested container runs" bash -c "$(declare -f run_nested); run_nested"
# And it has to be enforcing, which the container's own /proc is the proof of: the mask
# that used to cover this path is gone, so a readable kcore means nothing is mediating it.
check "kcore denied by the profile" bash -c '! head -c 1 /proc/kcore > /dev/null 2>&1'
check "sysrq-trigger denied by the profile" bash -c '! head -c 1 /proc/sysrq-trigger > /dev/null 2>&1'

# Report result
reportResults
