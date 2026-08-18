#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, PYTHON, STATEDIR.
PYTHON_VERSION="$PYTHON"
STATE_DIR="$STATEDIR"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: packages this feature needs to install and run.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Resolve: map the CPU arch to uv's gnu release target triple.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  target="x86_64-unknown-linux-gnu" ;;
  aarch64 | arm64) target="aarch64-unknown-linux-gnu" ;;
  *) echo "uv: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Resolve: build the GitHub Releases URL for the channel or version.
base="https://github.com/astral-sh/uv/releases"
case "$VERSION" in
  latest | stable) url_dir="$base/latest/download" ;;
  *)               url_dir="$base/download/$VERSION" ;;
esac
asset="uv-$target.tar.gz"

# Fetch: download the tarball and verify its published sha256.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url_dir/$asset" -o "$tmp/$asset"
curl -fsSL "$url_dir/$asset.sha256" -o "$tmp/$asset.sha256"
( cd "$tmp" && sha256sum -c "$asset.sha256" )

# Install: extract and place uv + uvx on PATH.
tar -xzf "$tmp/$asset" -C "$tmp" --strip-components=1
install -m 0755 "$tmp/uv" "$tmp/uvx" /usr/local/bin/

# Configure: login-shell profile with PATH, tool bin dir, and optional state redirect.
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

# Hook: install the create-state-dir hook to run once at container create.
install -d /usr/local/share/uv
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/uv/init.sh

# Configure: optionally bake a default Python so python3 exists at open.
if [ -n "$PYTHON_VERSION" ]; then
  su - "$_REMOTE_USER" -c \
    "env -u UV_PYTHON_INSTALL_DIR uv python install --default --preview-features python-install-default '$PYTHON_VERSION'"
fi

# Verify: uv resolves on PATH.
uv --version
