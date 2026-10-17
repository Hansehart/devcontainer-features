#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Install TeX Live onto the state dir once and reuse it on later creates.
SHARE_DIR="/usr/local/share/latex"
# shellcheck source=lib.sh
. "$SHARE_DIR/lib.sh"
. "$SHARE_DIR/config.env"

# Act only when a state dir holds the install.
[ -n "${STATE_DIR:-}" ] || exit 0

# Warn before the install when the state dir sits on the container filesystem, since a
# volume is what keeps it across rebuilds.
if [ -d "$STATE_DIR" ] && [ "$(stat -c %d "$STATE_DIR")" = "$(stat -c %d /)" ]; then
  echo "latex: $STATE_DIR is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

TEXDIR="$STATE_DIR/texlive/$VERSION"
if [ -f "$TEXDIR/tlpkg/texlive.profile" ]; then
  exit 0
fi

# Install onto the volume from a clean tree.
echo "latex: installing TeX Live $VERSION ($SCHEME) into $TEXDIR once, reused on later rebuilds"
rm -rf "$TEXDIR"
mkdir -p "$TEXDIR"
install_texlive "$TEXDIR"

# Confirm the new tree runs.
"$TEXDIR/bin/$PLAT/latex" --version
