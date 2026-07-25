#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, PYTHON, STATEDIR.
PYTHON_VERSION="$PYTHON"
STATE_DIR="$STATEDIR"

export DEBIAN_FRONTEND=noninteractive

# 1. Download tooling (present in most bases, installed defensively).
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# 2. Resolve arch to the glibc release triple. uv publishes gnu builds for both;
#    Ubuntu's glibc clears python-build-standalone's floor comfortably.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  target="x86_64-unknown-linux-gnu" ;;
  aarch64 | arm64) target="aarch64-unknown-linux-gnu" ;;
  *) echo "uv: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# 3. Build the GitHub Releases URL. Hitting releases directly avoids the astral.sh
#    redirector and the api.github.com round trip; assets nest under uv-<target>/.
base="https://github.com/astral-sh/uv/releases"
case "$VERSION" in
  latest | stable) url_dir="$base/latest/download" ;;
  *)               url_dir="$base/download/$VERSION" ;;
esac
asset="uv-$target.tar.gz"

# 4. Download, verify the published sha256 (the installer does not do this itself),
#    and place uv + uvx on PATH.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url_dir/$asset" -o "$tmp/$asset"
curl -fsSL "$url_dir/$asset.sha256" -o "$tmp/$asset.sha256"
( cd "$tmp" && sha256sum -c "$asset.sha256" )
tar -xzf "$tmp/$asset" -C "$tmp" --strip-components=1
install -m 0755 "$tmp/uv" "$tmp/uvx" /usr/local/bin/

# 5. Login-shell profile: ~/.local/bin on PATH (managed-Python and tool shims land
#    there), tool executables into a PATH dir, and - when a state dir is given -
#    redirect uv's state onto it. Cache and a project's .venv then live on separate
#    volumes, so hardlinks fail; copy mode makes that deliberate and quiet.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  echo 'export UV_TOOL_BIN_DIR="/usr/local/bin"'
  if [ -n "$STATE_DIR" ]; then
    echo "export UV_CACHE_DIR=\"$STATE_DIR/cache\""
    echo "export UV_TOOL_DIR=\"$STATE_DIR/tools\""
    echo "export UV_PYTHON_INSTALL_DIR=\"$STATE_DIR/python\""
    echo 'export UV_LINK_MODE=copy'
  fi
} > /etc/profile.d/uv.sh
chmod 0644 /etc/profile.d/uv.sh

# 6. Optionally bake a default Python so python3 exists the moment the container
#    opens. Install it into the image default (~/.local/share/uv) - not STATE_DIR,
#    which a runtime volume would shadow, orphaning the shims - as the dev user.
if [ -n "$PYTHON_VERSION" ]; then
  su - "$_REMOTE_USER" -c \
    "env -u UV_PYTHON_INSTALL_DIR uv python install --default --preview-features python-install-default '$PYTHON_VERSION'"
fi

# 7. Sanity check.
uv --version
