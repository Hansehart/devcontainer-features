#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, SCHEME.
FEATURE=latex
VERSION="$(option VERSION 2025)"
SCHEME="$(option SCHEME scheme-basic)"
PACKAGES+=(fontconfig perl wget)

# Accept only options in the feature's format, before anything is installed.
check_options() {
  require_version '^20[0-9]{2}$'
}

# Resolve the year to its final snapshot and the installer it ships.
resolve_version() {
  tag="$VERSION"
  REPO="https://texlive.info/historic/systems/texlive/$tag/tlnet-final"
  url="$REPO/install-tl-unx.tar.gz"
  checksum="$url.sha512"
}

# Install the distribution into its own tree, with its generated data and host config kept
# apart, where the layout rules place them, and its commands on the PATH.
install_program() {
  local texdir="/opt/texlive/$tag" platform
  untar
  {
    echo "selected_scheme $SCHEME"
    echo "TEXDIR $FEATURE_ROOT$texdir"
    echo "TEXMFLOCAL $FEATURE_ROOT$texdir/texmf-local"
    echo "TEXMFSYSVAR $FEATURE_ROOT/var/opt/texlive/$tag"
    echo "TEXMFSYSCONFIG $FEATURE_ROOT/etc/opt/texlive/$tag"
    echo "tlpdbopt_install_docfiles 0"
    echo "tlpdbopt_install_srcfiles 0"
    echo "tlpdbopt_autobackup 0"
  } > "$tmp/texlive.profile"
  TEXLIVE_INSTALL_ENV_NOCHECK=1 "$tmp/install-tl" \
    --profile "$tmp/texlive.profile" \
    --repository "$REPO" \
    --no-interaction
  platform="$("$tmp/install-tl" -print-platform)"
  link_bin "$texdir/bin/$platform"
}

# Point the user's own trees at the state dir when set.
profile() {
  if [ -n "$STATE_DIR" ]; then
    echo "export TEXMFHOME=\"$STATE_DIR/texmf\""
    echo "export TEXMFVAR=\"$STATE_DIR/texmf-var\""
    echo "export TEXMFCONFIG=\"$STATE_DIR/texmf-config\""
  fi
}

feature_main
