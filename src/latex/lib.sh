#!/usr/bin/env bash
# The TeX Live install routine, shared by the install script and the hook.

# Install a TeX Live tree, with its generated data and host config in the given dirs.
install_texlive() {
  local texdir="$1" vardir="$2" configdir="$3"
  local tmp
  tmp="$(mktemp -d)"
  {
    echo "selected_scheme $SCHEME"
    echo "TEXDIR $texdir"
    echo "TEXMFLOCAL $texdir/texmf-local"
    echo "TEXMFSYSVAR $vardir"
    echo "TEXMFSYSCONFIG $configdir"
    echo "instopt_portable 1"
    echo "tlpdbopt_install_docfiles 0"
    echo "tlpdbopt_install_srcfiles 0"
    echo "tlpdbopt_autobackup 0"
  } > "$tmp/texlive.profile"
  TEXLIVE_INSTALL_ENV_NOCHECK=1 "$INSTALLER_DIR/install-tl" \
    --profile "$tmp/texlive.profile" \
    --repository "$REPO" \
    --no-interaction
  rm -rf "$tmp"
}
