#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, TOOLCHAIN.
FEATURE=go
VERSION="$(option VERSION latest)"
TOOLCHAIN="$(option TOOLCHAIN local)"

# Resolve the channel or release line to a release and its checksum.
resolve_version() {
  require_version '^(latest|1\.[0-9]+(\.[0-9]+)?)$'
  require_version '^(local|path|auto)$' "$TOOLCHAIN" toolchain
  case "$VERSION" in
    # Follow the release pointer, which names the newest release on its first line.
    latest) tag="$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n1 || true)" ;;
    *.*.*) tag="go$VERSION" ;;
    # Take the newest release in the line, whose patch number sets it apart from previews.
    *) tag="$(curl -fsSL "https://go.dev/dl/?mode=json&include=all" \
         | grep -m1 -oP "\"version\":\s*\"\Kgo${VERSION//./\\.}\.[0-9]+(?=\")" || true)" ;;
  esac
  [[ "$tag" =~ ^go1\.[0-9]+\.[0-9]+$ ]] || die "could not resolve version '$VERSION'"
  url="https://dl.google.com/go/$tag.linux-$(arch_name x86_64=amd64 aarch64=arm64).tar.gz"
  checksum="$url.sha256"
}

# Place the toolchain in its own tree, with its commands on the PATH.
install_program() {
  unpack /opt/go
  link_bin /opt/go/bin
}

# Write the login profile: the chosen toolchain setting, and the paths of installed tools and
# caches, in the state dir when set.
profile() {
  echo "export GOTOOLCHAIN=$TOOLCHAIN"
  if [ -n "$STATE_DIR" ]; then
    echo "export GOPATH=\"$STATE_DIR\""
    echo "export GOCACHE=\"$STATE_DIR/cache\""
    echo "export PATH=\"$STATE_DIR/bin:\$PATH\""
  else
    echo 'export PATH="$HOME/go/bin:$PATH"'
  fi
}

# Confirm the toolchain runs from the PATH.
confirm() {
  go version
}

feature_main
