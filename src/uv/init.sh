#!/usr/bin/env bash
set -euo pipefail

# Create the state dir once the volume is mounted.
if [ -r /etc/profile.d/uv.sh ]; then . /etc/profile.d/uv.sh; fi
[ -n "${UV_CACHE_DIR:-}" ] || exit 0
mkdir -p "${UV_CACHE_DIR%/*}"
