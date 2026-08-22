#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, STATEDIR, CONFIGTOML.
STATE_DIR="$STATEDIR"
CONFIG_TOML="$CONFIGTOML"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: packages this feature needs to install and run.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Resolve: install-time env, single-quoted so $HOME expands in the dev user's shell.
codex_env='PATH="$HOME/.local/bin:$PATH" CODEX_HOME="$HOME/.local/share/codex" CODEX_NON_INTERACTIVE=1'

# Install: run the upstream installer as the dev user, with the payload outside Codex's state dir.
su - "$_REMOTE_USER" -c "curl -fsSL https://chatgpt.com/codex/install.sh | $codex_env sh -s -- --release '$VERSION'"

# Configure: login-shell profile with PATH plus the opted-in Codex state dir.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export CODEX_HOME=\"$STATE_DIR\""
  fi
} > /etc/profile.d/codex.sh
chmod 0644 /etc/profile.d/codex.sh

# Configure: pre-create the state dir owned by the dev user so a volume mounted there inherits it.
if [ -n "$STATE_DIR" ]; then
  install -d -m 0700 "$STATE_DIR"
  chown "$_REMOTE_USER:" "$STATE_DIR"
fi

# Hook: install the run-once hook and save the requested config for it to write.
install -d /usr/local/share/codex
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/codex/init.sh
printf '%s' "$CONFIG_TOML" > /usr/local/share/codex/requested-config.toml

# Verify: codex resolves on PATH (as the dev user).
su - "$_REMOTE_USER" -c "codex --version"
