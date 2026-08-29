#!/usr/bin/env bash
set -euo pipefail

# Prepare uv's state once the volume is mounted.
if [ -r /etc/profile.d/uv.sh ]; then . /etc/profile.d/uv.sh; fi

# Create the state dir once the volume is mounted (the cache dir names it).
if [ -n "${UV_CACHE_DIR:-}" ]; then mkdir -p "${UV_CACHE_DIR%/*}"; fi
