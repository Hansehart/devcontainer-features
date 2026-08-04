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

# Resolve: asset names embed the version, so read the latest tag from the GitHub API (explicit versions pass through).
base="https://github.com/getsops/sops/releases"
case "${VERSION:-latest}" in
  latest)
    tag="$(curl -fsSL "https://api.github.com/repos/getsops/sops/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+')"
    [ -n "$tag" ] || { echo "sops: could not resolve the latest version" >&2; exit 1; } ;;
  v*) tag="$VERSION" ;;
  *)  tag="v$VERSION" ;;
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

# Hook: install the create-state-dir hook to run once at container create.
install -d /usr/local/share/sops
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/sops/init.sh

# Verify: sops resolves on PATH and reports its version locally.
sops --version --disable-version-check
