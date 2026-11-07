#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/go
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/go/.probe && rm /home/ubuntu/go/.probe'

# Run the hook as a container create does.
/usr/local/libexec/go/init.sh

check "GOPATH exported" bash -lc '[ "$(go env GOPATH)" = /home/ubuntu/go ]'
check "GOCACHE exported" bash -lc '[ "$(go env GOCACHE)" = /home/ubuntu/go/cache ]'
check "installed tools from the state dir on PATH" bash -lc 'case ":$PATH:" in *":/home/ubuntu/go/bin:"*) ;; *) exit 1;; esac'

# A build fills the cache in the state dir.
project="$(mktemp -d)"
printf 'package main\n\nfunc main() {}\n' > "$project/main.go"
check "a build caches into the state dir" bash -lc "cd '$project' && go build -o /dev/null main.go && [ -n \"\$(ls -A /home/ubuntu/go/cache)\" ]"

# The hook keeps the state dir private to the dev user.
check "state dir private to the dev user" \
  bash -c '[ -z "$(find /home/ubuntu/go -maxdepth 0 -perm /g+rwx,o+rwx)" ]'

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/libexec/go/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/libexec/go/state-dir.sh go /var/go'
check "the refusal names the home" \
  bash -c '/usr/local/libexec/go/state-dir.sh go /var/go 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
