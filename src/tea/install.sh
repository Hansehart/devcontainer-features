#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR.
FEATURE=tea
VERSION="$(option VERSION latest)"

# Accept only options in the feature's format, before anything is installed.
check_options() {
  require_version '^(latest|v?[0-9]+\.[0-9]+\.[0-9]+)$'
}

# Resolve the request to a release, its binary and its checksum list.
resolve_version() {
  tag="$(release_tag gitea.com gitea/tea "$VERSION")"
  local base="https://gitea.com/gitea/tea/releases/download/$tag"
  # Name the asset by the bare version inside the tagged release.
  url="$base/tea-${tag#v}-linux-$(arch_name x86_64=amd64 aarch64=arm64)"
  checksums="$base/checksums.txt"
}

# Install the binary on the PATH under the tool's name.
install_program() {
  install_bin "$tmp/$asset" as tea
}

# Link the config at build too, as the dev user, so the image carries the redirect from
# the start and one script decides what may be replaced.
post_install() {
  if [ -n "$STATE_DIR" ]; then
    as_user "$FEATURE_ROOT/usr/local/libexec/tea/init.sh --build"
  fi
}

feature_main
