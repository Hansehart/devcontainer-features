#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, TOOLCHAIN.
FEATURE=go
VERSION="$(option VERSION latest)"
TOOLCHAIN="$(option TOOLCHAIN local)"

# Find a release in the index: the newest of a line, or an exact one that exists.
find_release() {
  local pattern="$1" query="$2" index
  index="$(curl -fsSL "https://go.dev/dl/?mode=json$query")" || return 0
  # Search a here-string, so stopping at the first match ends the search cleanly.
  grep -m1 -oP "\"version\":\s*\"\K$pattern(?=\")" <<< "$index" || true
}

# Resolve the channel or release line to a release and its checksum.
resolve_version() {
  local pattern
  require_version '^(latest|1\.[0-9]+(\.[0-9]+)?)$'
  require_version '^(local|path|auto)$' "$TOOLCHAIN" toolchain
  if [ "$VERSION" = latest ]; then
    # Follow the release pointer, which names the newest release on its first line.
    tag="$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n1 || true)"
  else
    # Match the exact release, or the newest in the line, whose patch number sets it apart
    # from previews.
    pattern="go${VERSION//./\\.}"
    if [[ "$VERSION" != *.*.* ]]; then pattern="$pattern\\.[0-9]+"; fi
    # Look among the supported releases first, then in the full history.
    tag="$(find_release "$pattern" "")"
    if [ -z "$tag" ]; then tag="$(find_release "$pattern" "&include=all")"; fi
  fi
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
