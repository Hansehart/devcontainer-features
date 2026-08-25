#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, STATEDIR, NPMRC.
STATE_DIR="$STATEDIR"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: packages this feature needs to install and run.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Resolve: map the CPU arch to Node's release arch token.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  nodearch="x64" ;;
  aarch64 | arm64) nodearch="arm64" ;;
  *) echo "node: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Resolve: asset names embed the version, so read the newest tag from the release index (explicit versions pass through).
base="https://nodejs.org/dist"
case "${VERSION:-latest}" in
  latest)
    tag="$(curl -fsSL "$base/index.json" | grep -oP '"version":"\Kv[^"]+' | head -n 1)"
    [ -n "$tag" ] || { echo "node: could not resolve the latest version" >&2; exit 1; } ;;
  v*) tag="$VERSION" ;;
  *)  tag="v$VERSION" ;;
esac
asset="node-$tag-linux-$nodearch.tar.gz"

# Fetch: download the tarball and verify it against Node's published checksums.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/$tag/$asset" -o "$tmp/$asset"
curl -fsSL "$base/$tag/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt"
( cd "$tmp" && grep " $asset\$" SHASUMS256.txt | sha256sum -c - )

# Install: extract into /usr/local, as root, so node, npm, and npx land on the default PATH.
tar -xzf "$tmp/$asset" -C /usr/local --strip-components=1 --no-same-owner \
  --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md

# Configure: login-shell profile with a global prefix the dev user owns, so npm -g needs no root.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export NPM_CONFIG_CACHE=\"$STATE_DIR/cache\""
    echo "export NPM_CONFIG_PREFIX=\"$STATE_DIR/global\""
    echo "export NPM_CONFIG_USERCONFIG=\"$STATE_DIR/npmrc\""
    echo "export PATH=\"$STATE_DIR/global/bin:\$PATH\""
  else
    echo 'export NPM_CONFIG_PREFIX="$HOME/.local"'
  fi
} > /etc/profile.d/node.sh
chmod 0644 /etc/profile.d/node.sh

# Configure: own the state dir by a dedicated group so it stays writable after a UID remap.
if [ -n "$STATE_DIR" ]; then
  groupadd -r -f node
  usermod -aG node "$_REMOTE_USER" || true
  install -d -m 0770 "$STATE_DIR"
  chown "$_REMOTE_USER:node" "$STATE_DIR"
  chmod g+s "$STATE_DIR"
fi

# Hook: install the run-once hook and save the requested config for it to write.
install -d /usr/local/share/node
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/node/init.sh
printf '%s' "$NPMRC" > /usr/local/share/node/requested-npmrc

# Verify: the runtime and its package tooling resolve on PATH.
node --version
npm --version
command -v npx >/dev/null
