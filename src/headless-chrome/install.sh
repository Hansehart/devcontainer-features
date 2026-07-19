#!/usr/bin/env bash
set -euo pipefail

# Define constants
API="https://googlechromelabs.github.io/chrome-for-testing"
BUCKET="https://storage.googleapis.com/chrome-for-testing-public"
INSTALL_DIR="/opt/chrome-headless-shell"

export DEBIAN_FRONTEND=noninteractive

# 1. Runtime shared libraries chrome-headless-shell dlopen()s at startup.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
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

# 2. Resolve the channel keyword to a concrete version (exact versions pass through).
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

# 3. Download, unpack, and expose the binary on PATH.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url" -o "$tmp/chs.zip"
unzip -q "$tmp/chs.zip" -d "$tmp"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mv "$tmp/chrome-headless-shell-linux64/"* "$INSTALL_DIR/"
ln -sf "$INSTALL_DIR/chrome-headless-shell" /usr/local/bin/chrome-headless-shell

rm -rf /var/lib/apt/lists/*

# 4. Sanity check.
/usr/local/bin/chrome-headless-shell --version
