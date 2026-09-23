#!/usr/bin/env bash
set -euo pipefail

# Accept a state dir inside the dev user's home, the one place the CLI's UID remap chowns,
# so the directory stays theirs when the user is renumbered.
feature="$1"
state_dir="$2"

home="${_REMOTE_USER_HOME:-$(getent passwd "${_REMOTE_USER:-$(id -un)}" | cut -d: -f6)}"
case "$state_dir" in
  "$home"/*) ;;
  *) echo "$feature: stateDir must be inside $home (got $state_dir)" >&2; exit 1 ;;
esac
