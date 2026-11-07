#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION.
FEATURE=headless-chrome
VERSION="$(option VERSION latest)"

# Accept only options in the feature's format, before anything is installed.
require_version '^(latest|stable|beta|dev|canary|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$'
# Name the build's platform first, so an unsupported machine stops before any package installs.
PLATFORM="$(arch_name x86_64=linux64)"
# Install the libraries the browser loads at run time.
PACKAGES+=(
  fonts-liberation
  libasound2t64
  libatk-bridge2.0-0t64
  libatk1.0-0t64
  libatspi2.0-0t64
  libcairo2
  libcups2t64
  libdbus-1-3
  libdrm2
  libgbm1
  libglib2.0-0t64
  libnspr4
  libnss3
  libpango-1.0-0
  libx11-6
  libxcb1
  libxcomposite1
  libxdamage1
  libxext6
  libxfixes3
  libxkbcommon0
  libxrandr2
  unzip
)

# Resolve a channel to its current version, keeping an exact version as given.
resolve_version() {
  local key=""
  case "$VERSION" in
    latest | stable) key="Stable" ;;
    beta)            key="Beta" ;;
    dev)             key="Dev" ;;
    canary)          key="Canary" ;;
  esac
  if [ -n "$key" ]; then
    tag="$(curl -fsSL "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json" \
      | grep -oP "\"$key\":\{[^}]*?\"version\":\"\K[0-9.]+" || true)"
    [ -n "$tag" ] || die "could not resolve channel '$VERSION'"
  else
    tag="$VERSION"
  fi
  url="https://storage.googleapis.com/chrome-for-testing-public/$tag/$PLATFORM/chrome-headless-shell-$PLATFORM.zip"
  unverified="the vendor publishes no checksums for these builds"
}

# Place the build in its own tree, with the browser on the PATH.
install_program() {
  unpack /opt/chrome-headless-shell
  link_bin /opt/chrome-headless-shell chrome-headless-shell
}

# Confirm the browser runs from the PATH.
confirm() {
  chrome-headless-shell --version
}

feature_main
