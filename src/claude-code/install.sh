#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, DISABLENONESSENTIALTRAFFIC, SETTINGSJSON.
FEATURE=claude-code
VERSION="$(option VERSION latest)"
DISABLE_NONESSENTIAL_TRAFFIC="$(option DISABLENONESSENTIALTRAFFIC true)"
SETTINGS_JSON="$(option SETTINGSJSON "")"

# Hand the requested version to the vendor installer, which fetches and checks the tool itself.
resolve_version() {
  require_version '^(latest|stable|[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)$'
  tag="$VERSION"
  delegated="the vendor installer checks each download against its release manifest"
}

# Run the vendor installer as the dev user, who owns the result.
install_program() {
  as_user "curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"
}

# Write the login profile: the tool's PATH and the chosen settings.
profile() {
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then echo "export CLAUDE_CONFIG_DIR=\"$STATE_DIR\""; fi
  if [ "$DISABLE_NONESSENTIAL_TRAFFIC" = "true" ]; then echo 'export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1'; fi
}

# Record the requested settings, for the hook to apply at create.
settings() {
  record requested-settings.json "$SETTINGS_JSON"
}

# Confirm the tool runs for the dev user.
confirm() {
  as_user "claude --version"
}

feature_main
