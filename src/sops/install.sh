#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR.
FEATURE=sops
VERSION="$(option VERSION latest)"

# Accept only options in the feature's format, before anything is installed.
require_version '^(latest|v?[0-9]+\.[0-9]+\.[0-9]+)$'

# Resolve the request to a release, its binary and its checksum list.
resolve_version() {
  tag="$(release_tag github getsops/sops "$VERSION")"
  local base="https://github.com/getsops/sops/releases/download/$tag"
  url="$base/sops-$tag.linux.$(arch_name x86_64=amd64 aarch64=arm64)"
  checksums="$base/sops-$tag.checksums.txt"
}

# Install the binary on the PATH under the tool's name.
install_program() {
  install_bin "$tmp/$asset" as sops
}

# Point the tool at the key in the state dir, when one is set.
profile() {
  if [ -n "$STATE_DIR" ]; then echo "export SOPS_AGE_KEY_FILE=\"$STATE_DIR/keys.txt\""; fi
}

# Confirm the tool runs from the PATH, checking its version offline.
confirm() {
  sops --version --disable-version-check
}

feature_main
