#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Read the feature's settings.
if [ -r /etc/profile.d/docker-in-docker.sh ]; then . /etc/profile.d/docker-in-docker.sh; fi

# Create the state dir on the mounted volume, where the tool expects it.
if [ -n "${DOCKER_CONFIG:-}" ]; then mkdir -p "${DOCKER_CONFIG}"; fi

# Warn when the state dir sits on the container filesystem, since a volume is what keeps it
# across rebuilds; the create carries on.
state_dir="${DOCKER_CONFIG:-}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "docker-in-docker: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi
