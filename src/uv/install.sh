#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, PYTHON.
FEATURE=uv
VERSION="$(option VERSION latest)"
PYTHON_VERSION="$(option PYTHON "")"

# Resolve the request to a release, its archive and its checksum.
resolve_version() {
  tag="$(release_tag github astral-sh/uv "$VERSION" --bare)"
  url="https://github.com/astral-sh/uv/releases/download/$tag/uv-$(arch_name x86_64=x86_64-unknown-linux-gnu aarch64=aarch64-unknown-linux-gnu).tar.gz"
  checksum="$url.sha256"
}

# Install both tools on the PATH.
install_program() {
  untar
  install_bin "$tmp/uv" "$tmp/uvx"
}

# Write the login profile: the tools' PATH and the chosen state locations.
profile() {
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export UV_CACHE_DIR=\"$STATE_DIR/cache\""
    echo "export UV_TOOL_DIR=\"$STATE_DIR/tools\""
    echo "export UV_TOOL_BIN_DIR=\"$STATE_DIR/bin\""
    echo "export UV_PYTHON_INSTALL_DIR=\"$STATE_DIR/python\""
    echo 'export UV_LINK_MODE=copy'
    echo "export PATH=\"$STATE_DIR/bin:\$PATH\""
  fi
}

# Bake the chosen interpreter in as the default.
post_install() {
  if [ -n "$PYTHON_VERSION" ]; then
    su - "$_REMOTE_USER" -c \
      "env -u UV_PYTHON_INSTALL_DIR $FEATURE_ROOT/usr/local/bin/uv python install --default --preview-features python-install-default '$PYTHON_VERSION'"
  fi
}

# Confirm both tools run from the PATH.
confirm() {
  uv --version
  command -v uvx >/dev/null
}

feature_main
