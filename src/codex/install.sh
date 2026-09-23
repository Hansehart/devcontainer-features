#!/usr/bin/env bash
set -euo pipefail

# Take the user the CLI provisions for, which varies by base image.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, CONFIGTOML.
STATE_DIR="$STATEDIR"

# Take the state dir before any work is done, so a path this feature cannot
# own leaves the image untouched.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" codex "$STATE_DIR"
fi
CONFIG_TOML="$CONFIGTOML"

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  ripgrep
rm -rf /var/lib/apt/lists/*

# Build the install-time env, single-quoted so $HOME expands in the dev user's shell.
codex_env='PATH="$HOME/.local/bin:$PATH" CODEX_HOME="$HOME/.local/share/codex" CODEX_NON_INTERACTIVE=1'

# Run the upstream installer as the dev user, with the payload outside Codex's state dir.
su - "$_REMOTE_USER" -c "curl -fsSL https://chatgpt.com/codex/install.sh | $codex_env sh -s -- --release '$VERSION'"

# Write a login-shell profile with PATH plus the opted-in Codex state dir.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export CODEX_HOME=\"$STATE_DIR\""
  fi
} > /etc/profile.d/codex.sh
chmod 0644 /etc/profile.d/codex.sh

# Install the run-once hook and save the requested config for it to write.
install -d /usr/local/share/codex
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/codex/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/share/codex/state-dir.sh
printf '%s' "$CONFIG_TOML" > /usr/local/share/codex/requested-config.toml

# Check codex resolves on PATH (as the dev user).
su - "$_REMOTE_USER" -c "codex --version"
