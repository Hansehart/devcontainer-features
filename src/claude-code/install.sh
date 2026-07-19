#!/usr/bin/env bash
set -euo pipefail

# VERSION comes from the feature options: a channel (latest|stable) or exact version.

# Install as the dev user (_REMOTE_USER) so claude lands in their home (~/.local/bin).
su - "$_REMOTE_USER" -c "curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"

# Put ~/.local/bin on PATH for every login shell, resolved per-user via $HOME.
# Portable across base images whose remote user is not 'ubuntu'.
cat > /etc/profile.d/claude-code.sh <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
chmod 0644 /etc/profile.d/claude-code.sh
