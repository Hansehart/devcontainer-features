#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR.
VERSION="${VERSION:-latest}"
STATE_DIR="${STATEDIR:-}"

# Claim the state dir first, so a rejected path stops the build before it changes anything.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" sops "$STATE_DIR"
fi

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
  *) echo "sops: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Resolve the requested version to a release tag.
base="https://github.com/getsops/sops/releases"
case "$VERSION" in
  latest)
    tag="$(curl -fsSL "https://api.github.com/repos/getsops/sops/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+')"
    [ -n "$tag" ] || { echo "sops: could not resolve the latest version" >&2; exit 1; } ;;
  v*) tag="$VERSION" ;;
  *)  tag="v$VERSION" ;;
esac
asset="sops-$tag.linux.$goarch"
echo "sops: installing $tag ($VERSION)"

# Download the release and verify it against the published checksums.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/download/$tag/$asset" -o "$tmp/$asset"
curl -fsSL "$base/download/$tag/sops-$tag.checksums.txt" -o "$tmp/checksums.txt"
( cd "$tmp" && grep " $asset\$" checksums.txt | sha256sum -c - )

# Install the binary on the PATH.
install -m 0755 "$tmp/$asset" /usr/local/bin/sops

# Point the tool at the age key in the state dir, when one is set.
if [ -n "$STATE_DIR" ]; then
  echo "export SOPS_AGE_KEY_FILE=\"$STATE_DIR/keys.txt\"" > /etc/profile.d/sops.sh
  chmod 0644 /etc/profile.d/sops.sh
fi

# Install the hook that prepares the state dir when the container is created.
install -d /usr/local/share/sops
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/sops/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/share/sops/state-dir.sh

# Confirm the tool runs from the PATH, checking its version offline.
sops --version --disable-version-check
