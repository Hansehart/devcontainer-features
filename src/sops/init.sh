#!/usr/bin/env bash
set -euo pipefail

# postCreate hook: create the state dir once the volume is mounted.
if [ -r /etc/profile.d/sops.sh ]; then . /etc/profile.d/sops.sh; fi
[ -n "${SOPS_AGE_KEY_FILE:-}" ] || exit 0
mkdir -p "${SOPS_AGE_KEY_FILE%/*}"
