#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, STATEDIR, DISABLENONESSENTIALTRAFFIC.
STATE_DIR="$STATEDIR"
DISABLE_NONESSENTIAL_TRAFFIC="$DISABLENONESSENTIALTRAFFIC"

# Install: run the upstream installer as the dev user so claude lands in ~/.local/bin.
su - "$_REMOTE_USER" -c "curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"

# Configure: login-shell profile — PATH plus opted-in Claude env.
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

# Hook: install the create-state-dir hook to run once at container create.
install -d /usr/local/share/claude-code
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/claude-code/init.sh

# Verify: claude resolves on PATH (as the dev user).
su - "$_REMOTE_USER" -c "claude --version"
