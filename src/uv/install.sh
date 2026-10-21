#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, PYTHON.
VERSION="${VERSION:-latest}"
STATE_DIR="${STATEDIR:-}"
PYTHON_VERSION="${PYTHON:-}"

# Claim the state dir first, so a rejected path stops the build before it changes anything.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" uv "$STATE_DIR"
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
  x86_64 | amd64)  target="x86_64-unknown-linux-gnu" ;;
  aarch64 | arm64) target="aarch64-unknown-linux-gnu" ;;
  *) echo "uv: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Resolve the requested version to a release tag.
base="https://github.com/astral-sh/uv/releases"
case "$VERSION" in
  latest)
    tag="$(curl -fsSL "https://api.github.com/repos/astral-sh/uv/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+')"
    [ -n "$tag" ] || { echo "uv: could not resolve the latest version" >&2; exit 1; } ;;
  *) tag="$VERSION" ;;
esac
url_dir="$base/download/$tag"
asset="uv-$target.tar.gz"
echo "uv: installing $tag ($VERSION)"

# Download the release and verify it against the published checksum.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url_dir/$asset" -o "$tmp/$asset"
curl -fsSL "$url_dir/$asset.sha256" -o "$tmp/$asset.sha256"
( cd "$tmp" && sha256sum -c "$asset.sha256" )

# Install both tools on the PATH.
tar -xzf "$tmp/$asset" -C "$tmp" --strip-components=1
install -m 0755 "$tmp/uv" "$tmp/uvx" /usr/local/bin/

# Write the login profile: the tools' PATH and the chosen state locations.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export UV_CACHE_DIR=\"$STATE_DIR/cache\""
    echo "export UV_TOOL_DIR=\"$STATE_DIR/tools\""
    echo "export UV_TOOL_BIN_DIR=\"$STATE_DIR/bin\""
    echo "export UV_PYTHON_INSTALL_DIR=\"$STATE_DIR/python\""
    echo 'export UV_LINK_MODE=copy'
    echo "export PATH=\"$STATE_DIR/bin:\$PATH\""
  fi
} > /etc/profile.d/uv.sh
chmod 0644 /etc/profile.d/uv.sh

# Bake the chosen interpreter in as the default.
if [ -n "$PYTHON_VERSION" ]; then
  su - "$_REMOTE_USER" -c \
    "env -u UV_PYTHON_INSTALL_DIR uv python install --default --preview-features python-install-default '$PYTHON_VERSION'"
fi

# Install the hook that prepares the state dir when the container is created.
install -d /usr/local/libexec/uv
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/libexec/uv/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/libexec/uv/state-dir.sh

# Confirm both tools run from the PATH.
uv --version
command -v uvx >/dev/null
