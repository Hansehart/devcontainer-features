#!/usr/bin/env bash
set -euo pipefail

# Claim a feature's state dir inside the dev user's home, which keeps it theirs when the
# CLI renumbers them.
feature="$1"
state_dir="$2"

user="${_REMOTE_USER:-$(id -un)}"
home="${_REMOTE_USER_HOME:-}"
if [ -z "$home" ]; then
  home="$(getent passwd "$user" | cut -d: -f6)" || true
fi
[ -n "$home" ] || { echo "$feature: cannot resolve a home for $user" >&2; exit 1; }
[ -d "$home" ] || { echo "$feature: $user has no home directory at $home" >&2; exit 1; }

# Compare where both paths really lead, so the state dir stays inside the home.
home="$(realpath -m "$home")"
resolved="$(realpath -m "$state_dir")"
case "$resolved" in
  "$home"/?*) ;;
  *) echo "$feature: stateDir must be inside $home (got $state_dir)" >&2; exit 1 ;;
esac

# Create the state dir as part of the claim, for the dev user alone.
install -d -m 0700 "$state_dir"
chown "$user:" "$state_dir"
