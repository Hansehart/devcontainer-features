#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION.
VERSION="${VERSION:-latest}"

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Name the CPU architecture the way the release assets do.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  goarch="amd64" ;;
  aarch64 | arm64) goarch="arm64" ;;
  *) echo "age: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Resolve the requested version to a release tag.
base="https://github.com/FiloSottile/age/releases"
case "$VERSION" in
  latest)
    tag="$(curl -fsSL "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+')"
    [ -n "$tag" ] || { echo "age: could not resolve the latest version" >&2; exit 1; } ;;
  v*) tag="$VERSION" ;;
  *)  tag="v$VERSION" ;;
esac
asset="age-$tag-linux-$goarch.tar.gz"
echo "age: installing $tag ($VERSION)"

# Download the release over HTTPS, which authenticates its origin.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/download/$tag/$asset" -o "$tmp/$asset"

# Install both tools on the PATH.
tar -xzf "$tmp/$asset" -C "$tmp" --strip-components=1
install -m 0755 "$tmp/age" "$tmp/age-keygen" /usr/local/bin/

# Confirm both tools run from the PATH.
age --version
command -v age-keygen >/dev/null
