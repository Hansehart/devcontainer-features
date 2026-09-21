#!/usr/bin/env bash
set -euo pipefail

# Create group-writable so the contents stay reachable after a UID remap.
umask 0002

# Prepare tea's config once the volume is mounted.
. /usr/local/share/tea/config.env

# Prepare only when a state dir was opted into.
[ -n "${STATE_DIR:-}" ] || exit 0

# tea resolves its config as $XDG_CONFIG_HOME/tea, so point that path at the
# mounted state dir.
mkdir -p "$STATE_DIR"

# A state dir sharing a filesystem with / holds its contents in the container, which goes at
# the next rebuild. install.sh passes --build, where a volume is still to come.
if [ "${1:-}" != "--build" ] && [ "$(stat -c %d "$STATE_DIR")" = "$(stat -c %d /)" ]; then
  echo "tea: $STATE_DIR is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

link="${XDG_CONFIG_HOME:-$HOME/.config}/tea"
mkdir -p "$(dirname "$link")"

# Test -L first: -e follows the link, and so reports false for a dangling one.
if [ -L "$link" ]; then
  target="$(readlink "$link")"
  # Compare where the link resolves, so a trailing slash or a relative form still reads as ours.
  if [ "$(readlink -f "$link")" = "$(readlink -f "$STATE_DIR")" ]; then
    ln -sfn "$STATE_DIR" "$link"
  # Test the link, which lets the kernel resolve a relative target against its own directory.
  elif [ ! -e "$link" ]; then
    echo "tea: $link pointed at $target, which is not there; pointing it at $STATE_DIR" >&2
    ln -sfn "$STATE_DIR" "$link"
  else
    # Leave a link the user made themselves pointing where they put it.
    echo "tea: $link already links to $target, leaving it in place" >&2
  fi
elif [ ! -e "$link" ]; then
  ln -sfn "$STATE_DIR" "$link"
elif [ -d "$link" ] && [ -z "$(ls -A "$link")" ]; then
  # An empty config dir is safe to replace.
  rmdir "$link"
  ln -sfn "$STATE_DIR" "$link"
else
  # Anything else is the user's own config: keep it, and say how to move it.
  echo "tea: keeping the existing $link; move its contents into $STATE_DIR to persist them" >&2
fi
