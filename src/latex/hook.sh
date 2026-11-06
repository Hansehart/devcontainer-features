#!/usr/bin/env bash
# The create-time sequence every feature's hook shares, copied unchanged into each feature by
# lib/sync.sh. A hook defines what's its own in init_state, then runs init_main.

# Locate the root the system paths hang from, which only the library's tests move.
HOOK_ROOT="${_FEATURE_TEST_ROOT:-}"

# Prepare the state dir the build recorded, then run the hook's own part.
init_main() {
  local record profile
  FEATURE="$1"
  shift
  # Keep everything the hook creates private to the dev user.
  umask 0077
  record="$HOOK_ROOT/usr/local/etc/$FEATURE/state-dir"
  profile="$HOOK_ROOT/etc/profile.d/$FEATURE.sh"
  STATE_DIR=""
  if [ -r "$record" ]; then STATE_DIR="$(cat "$record")"; fi
  # Read the feature's settings.
  # shellcheck disable=SC1090  # each feature writes its own profile
  if [ -r "$profile" ]; then . "$profile"; fi
  if [ -n "$STATE_DIR" ]; then
    mkdir -p "$STATE_DIR"
    # Warn when the state dir sits on the container filesystem, since a volume is what keeps
    # it across rebuilds; the build itself has no volume yet, and the create carries on.
    if [ "${1:-}" != --build ] && [ "$(stat -c %d "$STATE_DIR")" = "$(stat -c %d /)" ]; then
      echo "$FEATURE: $STATE_DIR is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
    fi
  fi
  if declare -F init_state >/dev/null; then init_state "$@"; fi
}

# Apply a requested config the build recorded, when there is one, expanded or as the format says.
apply_config() {
  local request="$HOOK_ROOT/usr/local/etc/$FEATURE/$1" target="$2" format="${3:-%b}"
  [ -s "$request" ] || return 0
  mkdir -p "$(dirname "$target")"
  # shellcheck disable=SC2059  # the format is the caller's choice of %b or %s
  printf "$format\n" "$(cat "$request")" > "$target"
}

# Keep the shared steps the same for every hook.
readonly -f init_main apply_config
