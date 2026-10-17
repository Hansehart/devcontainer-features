#!/usr/bin/env bash
# The TeX Live install routine, shared by the install script and the hook.

# Install a self-contained TeX Live tree, which stays usable wherever it is kept.
install_texlive() {
  local texdir="$1"
  local tmp
  tmp="$(mktemp -d)"
  {
    echo "selected_scheme $SCHEME"
    echo "TEXDIR $texdir"
    echo "TEXMFLOCAL $texdir/texmf-local"
    echo "TEXMFSYSVAR $texdir/texmf-var"
    echo "TEXMFSYSCONFIG $texdir/texmf-config"
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
