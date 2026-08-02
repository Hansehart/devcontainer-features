#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, STATEDIR.
STATE_DIR="$STATEDIR"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: download tooling, installed defensively for minimal bases.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Resolve: map the CPU arch to sops's release arch token.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  goarch="amd64" ;;
  aarch64 | arm64) goarch="arm64" ;;
  *) echo "sops: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Resolve: sops embeds the version in each asset name, so resolve a channel to a concrete tag via the releases/latest redirect.
base="https://github.com/getsops/sops/releases"
case "${VERSION:-latest}" in
  latest | stable) tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$base/latest" | sed 's#.*/tag/##')" ;;
  v*)              tag="$VERSION" ;;
  *)               tag="v$VERSION" ;;
esac
asset="sops-$tag.linux.$goarch"

# Fetch: download the binary and verify it against sops's published checksums.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/download/$tag/$asset" -o "$tmp/$asset"
curl -fsSL "$base/download/$tag/sops-$tag.checksums.txt" -o "$tmp/checksums.txt"
( cd "$tmp" && grep " $asset\$" checksums.txt | sha256sum -c - )

# Install: place sops on PATH.
install -m 0755 "$tmp/$asset" /usr/local/bin/sops

# Configure: point SOPS_AGE_KEY_FILE at the age key under the state dir, if given.
if [ -n "$STATE_DIR" ]; then
  echo "export SOPS_AGE_KEY_FILE=\"$STATE_DIR/keys.txt\"" > /etc/profile.d/sops.sh
  chmod 0644 /etc/profile.d/sops.sh
fi

# Verify: sops resolves on PATH (skip the network update check).
sops --version --disable-version-check
