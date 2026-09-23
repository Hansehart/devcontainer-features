#!/usr/bin/env bash
set -euo pipefail

# Own the state dir for a feature: resolve the dev user's home, accept a path inside it,
# and create it. The home is the one place the CLI's UID remap chowns, so a state dir
# there stays the dev user's own when they are renumbered.
feature="$1"
state_dir="$2"

user="${_REMOTE_USER:-$(id -un)}"
home="${_REMOTE_USER_HOME:-}"
if [ -z "$home" ]; then
  home="$(getent passwd "$user" | cut -d: -f6)" || true
fi
[ -n "$home" ] || { echo "$feature: cannot resolve a home for $user" >&2; exit 1; }
[ -d "$home" ] || { echo "$feature: $user has no home directory at $home" >&2; exit 1; }

# Compare resolved paths, so neither .. nor a trailing slash can walk out of the home.
home="$(realpath -m "$home")"
resolved="$(realpath -m "$state_dir")"
case "$resolved" in
  "$home"/?*) ;;
  *) echo "$feature: stateDir must be inside $home (got $state_dir)" >&2; exit 1 ;;
esac

# Create it here, so the state dir exists only where install.sh ran this script.
install -d -m 0700 "$state_dir"
chown "$user:" "$state_dir"
