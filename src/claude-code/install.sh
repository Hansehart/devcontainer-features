#!/usr/bin/env bash
set -euo pipefail

# Take the user the CLI provisions for, which varies by base image.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, DISABLENONESSENTIALTRAFFIC, SETTINGSJSON.
STATE_DIR="$STATEDIR"

# Take the state dir before any work is done, so a path this feature cannot
# own leaves the image untouched.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" claude-code "$STATE_DIR"
fi
DISABLE_NONESSENTIAL_TRAFFIC="$DISABLENONESSENTIALTRAFFIC"
SETTINGS_JSON="$SETTINGSJSON"

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Run the upstream installer as the dev user so claude lands in ~/.local/bin.
su - "$_REMOTE_USER" -c "curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"

# Write a login-shell profile with PATH plus opted-in Claude env.
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

# Install the run-once hook and save the requested settings for it to write.
install -d /usr/local/share/claude-code
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/claude-code/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/share/claude-code/state-dir.sh
printf '%s' "$SETTINGS_JSON" > /usr/local/share/claude-code/requested-settings.json

# Check claude resolves on PATH (as the dev user).
su - "$_REMOTE_USER" -c "claude --version"
