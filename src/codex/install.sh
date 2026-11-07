#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, CONFIGTOML.
FEATURE=codex
VERSION="$(option VERSION latest)"
CONFIG_TOML="$(option CONFIGTOML "")"

# Accept only options in the feature's format, before anything is installed.
require_version '^(latest|[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?)$'

# The tool's searches rely on ripgrep.
PACKAGES+=(ripgrep)

# Hand the requested version to the vendor installer, which fetches and checks the tool itself.
resolve_version() {
  tag="$VERSION"
  delegated="the vendor installer checks each archive against its release digest"
}

# Run the vendor installer as the dev user, keeping the binary apart from the state dir.
install_program() {
  local codex_env='PATH="$HOME/.local/bin:$PATH" CODEX_HOME="$HOME/.local/share/codex" CODEX_NON_INTERACTIVE=1'
  as_user "curl -fsSL https://chatgpt.com/codex/install.sh | $codex_env sh -s -- --release '$VERSION'"
}

# Write the login profile: the tool's PATH and the chosen state dir.
profile() {
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then echo "export CODEX_HOME=\"$STATE_DIR\""; fi
}

# Record the requested config, for the hook to apply at create.
settings() {
  record requested-config.toml "$CONFIG_TOML"
}

# Confirm the tool runs for the dev user.
confirm() {
  as_user "codex --version"
}

feature_main
