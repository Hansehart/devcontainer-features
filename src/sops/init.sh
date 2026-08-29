#!/usr/bin/env bash
set -euo pipefail

# Prepare sops's state once the volume is mounted.
if [ -r /etc/profile.d/sops.sh ]; then . /etc/profile.d/sops.sh; fi

# Create the state dir once the volume is mounted (the age key file names it).
if [ -n "${SOPS_AGE_KEY_FILE:-}" ]; then mkdir -p "${SOPS_AGE_KEY_FILE%/*}"; fi
