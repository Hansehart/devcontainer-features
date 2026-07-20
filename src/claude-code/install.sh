#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, CONFIGDIR, DISABLENONESSENTIALTRAFFIC.
CONFIG_DIR="$CONFIGDIR"
DISABLE_NONESSENTIAL_TRAFFIC="$DISABLENONESSENTIALTRAFFIC"

# Install as the dev user (_REMOTE_USER) so claude lands in their home (~/.local/bin).
su - "$_REMOTE_USER" -c "curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"

# Login-shell profile snippet: ~/.local/bin on PATH ($HOME resolves per-user), plus
# any opted-in Claude env.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$CONFIG_DIR" ]; then
    echo "export CLAUDE_CONFIG_DIR=\"$CONFIG_DIR\""
  fi
  if [ "$DISABLE_NONESSENTIAL_TRAFFIC" = "true" ]; then
    echo 'export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1'
  fi
} > /etc/profile.d/claude-code.sh
chmod 0644 /etc/profile.d/claude-code.sh
