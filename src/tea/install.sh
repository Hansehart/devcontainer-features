#!/usr/bin/env bash
set -euo pipefail

# Take the user the CLI provisions for, which varies by base image.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR.
STATE_DIR="$STATEDIR"

# Take the state dir before any work is done, so a path this feature cannot
# own leaves the image untouched.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" tea "$STATE_DIR"
fi

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Map the CPU arch to tea's release arch token.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  goarch="amd64" ;;
  aarch64 | arm64) goarch="arm64" ;;
  *) echo "tea: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Read the latest tag from the Gitea API, since asset names embed the version (explicit versions pass through).
base="https://gitea.com/gitea/tea/releases"
case "${VERSION:-latest}" in
  latest)
    tag="$(curl -fsSL "https://gitea.com/api/v1/repos/gitea/tea/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+')"
    [ -n "$tag" ] || { echo "tea: could not resolve the latest version" >&2; exit 1; } ;;
  v*) tag="$VERSION" ;;
  *)  tag="v$VERSION" ;;
esac
# The tag locating the release keeps its v prefix, while the asset name carries the bare version.
asset="tea-${tag#v}-linux-$goarch"
echo "tea: installing $tag ($VERSION)"

# Download the binary and verify it against tea's published checksums.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/download/$tag/$asset" -o "$tmp/$asset"
curl -fsSL "$base/download/$tag/checksums.txt" -o "$tmp/checksums.txt"
( cd "$tmp" && grep " $asset\$" checksums.txt | sha256sum -c - )

# Place tea on PATH.
install -m 0755 "$tmp/$asset" /usr/local/bin/tea

# Install the link-state-dir hook and the state dir it links to, since tea
# resolves its config dir from XDG alone.
install -d /usr/local/share/tea
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/tea/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/share/tea/state-dir.sh
echo "STATE_DIR=\"$STATE_DIR\"" > /usr/local/share/tea/config.env
chmod 0644 /usr/local/share/tea/config.env

# Run it once at build, as the dev user whose $HOME names the link, so the image
# carries the redirect and a create that skips the hook still finds tea's config moved.
# Running the hook keeps one decision about what may be replaced.
if [ -n "$STATE_DIR" ]; then
  su - "$_REMOTE_USER" -c "/usr/local/share/tea/init.sh --build"
fi

# Check tea resolves on PATH and reports its version.
tea --version
