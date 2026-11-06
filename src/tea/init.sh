#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/hook.sh"

# Point the tool's config dir at the state dir, at build and at create.
init_state() {
  local link target
  # Act only when a state dir is set.
  [ -n "$STATE_DIR" ] || return 0

  link="${XDG_CONFIG_HOME:-$HOME/.config}/tea"
  mkdir -p "$(dirname "$link")"

  # Point out a config file the tool reads ahead of the config dir, at build and at create.
  if [ -f "$HOME/.tea/tea.yml" ] && [ ! -f "$link/config.yml" ]; then
    echo "tea: $HOME/.tea/tea.yml is the config tea will read; move it to $link/config.yml to keep it across rebuilds" >&2
  fi

  # Use the state dir directly when it is the config dir itself.
  if [ "$STATE_DIR" -ef "$link" ]; then
    return 0
  fi

  # Check for a link first, which also catches one whose target is gone.
  if [ -L "$link" ]; then
    target="$(readlink "$link")"
    # Compare resolved targets, so any spelling of the state dir counts as ours.
    if [ "$(readlink -f "$link")" = "$(readlink -f "$STATE_DIR")" ]; then
      ln -sfn "$STATE_DIR" "$link"
    # Repoint a link whose target is gone.
    elif [ ! -e "$link" ]; then
      echo "tea: $link pointed at $target, which is not there; pointing it at $STATE_DIR" >&2
      ln -sfn "$STATE_DIR" "$link"
    else
      # Respect a link the user pointed elsewhere.
      echo "tea: $link already links to $target, leaving it in place" >&2
    fi
  elif [ ! -e "$link" ]; then
    ln -sfn "$STATE_DIR" "$link"
  elif [ -d "$link" ] && [ -z "$(ls -A "$link")" ]; then
    # Replace an empty config dir with the link.
    rmdir "$link"
    ln -sfn "$STATE_DIR" "$link"
  else
    # Keep the user's own config in place and show how to move it.
    echo "tea: keeping the existing $link; move its contents into $STATE_DIR to persist them" >&2
  fi
}

init_main tea "$@"
