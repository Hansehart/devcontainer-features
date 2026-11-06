#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION.
FEATURE=age
VERSION="$(option VERSION latest)"

# Resolve the request to a release and its asset.
resolve_version() {
  tag="$(release_tag github FiloSottile/age "$VERSION")"
  url="https://github.com/FiloSottile/age/releases/download/$tag/age-$tag-linux-$(arch_name x86_64=amd64 aarch64=arm64).tar.gz"
  unverified="the release publishes transparency proofs alone"
}

# Install both tools on the PATH.
install_program() {
  untar
  install_bin "$tmp/age" "$tmp/age-keygen"
}

# Confirm both tools run from the PATH.
confirm() {
  age --version
  command -v age-keygen >/dev/null
}

feature_main
