#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, DISABLENONESSENTIALTRAFFIC, SETTINGSJSON.
VERSION="${VERSION:-latest}"
STATE_DIR="${STATEDIR:-}"
DISABLE_NONESSENTIAL_TRAFFIC="${DISABLENONESSENTIALTRAFFIC:-true}"
SETTINGS_JSON="${SETTINGSJSON:-}"

# Claim the state dir first, so a rejected path stops the build before it changes anything.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" claude-code "$STATE_DIR"
fi

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

# Run the vendor installer as the dev user, who owns the result.
su - "$_REMOTE_USER" -c "curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"

# Write the login profile: the tool's PATH and the chosen settings.
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

# Install the hook that prepares the state dir and applies the requested settings at create.
install -d /usr/local/libexec/claude-code
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/libexec/claude-code/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/libexec/claude-code/state-dir.sh

# Record the requested settings, for the hook to apply at create.
install -d /usr/local/etc/claude-code
printf '%s' "$SETTINGS_JSON" > /usr/local/etc/claude-code/requested-settings.json

# Confirm the tool runs for the dev user.
su - "$_REMOTE_USER" -c "claude --version"
