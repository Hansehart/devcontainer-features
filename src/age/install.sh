#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION.

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Map the CPU arch to age's release arch token.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  goarch="amd64" ;;
  aarch64 | arm64) goarch="arm64" ;;
  *) echo "age: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Read the latest tag from the GitHub API, since asset names embed the version (explicit versions pass through).
base="https://github.com/FiloSottile/age/releases"
case "${VERSION:-latest}" in
  latest)
    tag="$(curl -fsSL "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+')"
    [ -n "$tag" ] || { echo "age: could not resolve the latest version" >&2; exit 1; } ;;
  v*) tag="$VERSION" ;;
  *)  tag="v$VERSION" ;;
esac
asset="age-$tag-linux-$goarch.tar.gz"
echo "age: installing $tag ($VERSION)"

# Download the tarball over HTTPS, trusting the TLS-authenticated GitHub origin for integrity.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/download/$tag/$asset" -o "$tmp/$asset"

# Extract and place age + age-keygen on PATH (/usr/local/bin is already on PATH).
tar -xzf "$tmp/$asset" -C "$tmp" --strip-components=1
install -m 0755 "$tmp/age" "$tmp/age-keygen" /usr/local/bin/

# Check both tools resolve on PATH.
age --version
command -v age-keygen >/dev/null
