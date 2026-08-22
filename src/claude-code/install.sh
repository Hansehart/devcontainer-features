#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, STATEDIR, DISABLENONESSENTIALTRAFFIC, SETTINGSJSON.
STATE_DIR="$STATEDIR"
DISABLE_NONESSENTIAL_TRAFFIC="$DISABLENONESSENTIALTRAFFIC"
SETTINGS_JSON="$SETTINGSJSON"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: packages this feature needs to install and run.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Install: run the upstream installer as the dev user so claude lands in ~/.local/bin.
su - "$_REMOTE_USER" -c "curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"

# Configure: login-shell profile with PATH plus opted-in Claude env.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export CLAUDE_CONFIG_DIR=\"$STATE_DIR\""
  fi
  if [ "$DISABLE_NONESSENTIAL_TRAFFIC" = "true" ]; then
    echo 'export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1'
  fi
} > /etc/profile.d/claude-code.sh
chmod 0644 /etc/profile.d/claude-code.sh

# Configure: pre-create the state dir owned by the dev user so a volume mounted there inherits it.
if [ -n "$STATE_DIR" ]; then
  install -d -m 0700 "$STATE_DIR"
  chown "$_REMOTE_USER:" "$STATE_DIR"
fi

# Hook: install the run-once hook and save the requested settings for it to write.
install -d /usr/local/share/claude-code
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/claude-code/init.sh
printf '%s' "$SETTINGS_JSON" > /usr/local/share/claude-code/requested-settings.json

# Verify: claude resolves on PATH (as the dev user).
su - "$_REMOTE_USER" -c "claude --version"
