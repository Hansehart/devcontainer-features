#!/usr/bin/env bash
set -euo pipefail

# Option (uppercased by the CLI): VERSION.

API="https://googlechromelabs.github.io/chrome-for-testing"
BUCKET="https://storage.googleapis.com/chrome-for-testing-public"
INSTALL_DIR="/opt/chrome-headless-shell"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: packages this feature needs to install and run.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  unzip \
  fonts-liberation \
  libasound2t64 \
  libatk-bridge2.0-0t64 \
  libatk1.0-0t64 \
  libatspi2.0-0t64 \
  libcairo2 \
  libcups2t64 \
  libdbus-1-3 \
  libdrm2 \
  libgbm1 \
  libglib2.0-0t64 \
  libnspr4 \
  libnss3 \
  libpango-1.0-0 \
  libx11-6 \
  libxcb1 \
  libxcomposite1 \
  libxdamage1 \
  libxext6 \
  libxfixes3 \
  libxkbcommon0 \
  libxrandr2
rm -rf /var/lib/apt/lists/*

# Resolve: the channel keyword to a concrete version (exact versions pass through).
case "$VERSION" in
  latest | stable) key="Stable" ;;
  beta)            key="Beta" ;;
  dev)             key="Dev" ;;
  canary)          key="Canary" ;;
  *)               key="" ;;
esac

if [ -n "$key" ]; then
  resolved="$(curl -fsSL "$API/last-known-good-versions.json" \
    | grep -oP "\"$key\":\{[^}]*?\"version\":\"\K[0-9.]+")"
  [ -n "$resolved" ] || { echo "chrome: could not resolve channel '$VERSION'" >&2; exit 1; }
else
  resolved="$VERSION"
fi

url="$BUCKET/$resolved/linux64/chrome-headless-shell-linux64.zip"
echo "chrome: installing chrome-headless-shell $resolved ($VERSION)"

# Fetch: download and unpack the build.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url" -o "$tmp/chs.zip"
unzip -q "$tmp/chs.zip" -d "$tmp"

# Install: place the binary and expose it on PATH.
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mv "$tmp/chrome-headless-shell-linux64/"* "$INSTALL_DIR/"
ln -sf "$INSTALL_DIR/chrome-headless-shell" /usr/local/bin/chrome-headless-shell

# Verify: chrome-headless-shell resolves on PATH.
chrome-headless-shell --version
