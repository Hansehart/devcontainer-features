#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, CONFIGTOML.
VERSION="${VERSION:-latest}"
STATE_DIR="${STATEDIR:-}"
CONFIG_TOML="${CONFIGTOML:-}"

# Claim the state dir first, so a rejected path stops the build before it changes anything.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" codex "$STATE_DIR"
fi

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  ripgrep
rm -rf /var/lib/apt/lists/*

# Describe the installer's environment in the dev user's terms, resolved in their shell.
codex_env='PATH="$HOME/.local/bin:$PATH" CODEX_HOME="$HOME/.local/share/codex" CODEX_NON_INTERACTIVE=1'

# Run the vendor installer as the dev user, keeping the binary apart from the state dir.
su - "$_REMOTE_USER" -c "curl -fsSL https://chatgpt.com/codex/install.sh | $codex_env sh -s -- --release '$VERSION'"

# Write the login profile: the tool's PATH and the chosen state dir.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export CODEX_HOME=\"$STATE_DIR\""
  fi
} > /etc/profile.d/codex.sh
chmod 0644 /etc/profile.d/codex.sh

# Install the hook that prepares the state dir and applies the requested config at create.
install -d /usr/local/libexec/codex
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/libexec/codex/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/libexec/codex/state-dir.sh

# Record the requested config, for the hook to apply at create.
install -d /usr/local/etc/codex
printf '%s' "$CONFIG_TOML" > /usr/local/etc/codex/requested-config.toml

# Confirm the tool runs for the dev user.
su - "$_REMOTE_USER" -c "codex --version"
