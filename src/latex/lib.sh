#!/usr/bin/env bash
# Sourced by install.sh and init.sh to define install_texlive(), inheriting the caller's shell options.

# Install TeX Live into $1, portable so the self-contained tree stays reusable when persisted.
install_texlive() {
  local texdir="$1"
  local tmp
  tmp="$(mktemp -d)"
  {
    echo "selected_scheme ${SCHEME}"
    echo "TEXDIR ${texdir}"
    echo "TEXMFLOCAL ${texdir}/texmf-local"
    echo "TEXMFSYSVAR ${texdir}/texmf-var"
    echo "TEXMFSYSCONFIG ${texdir}/texmf-config"
    echo "instopt_portable 1"
    echo "tlpdbopt_install_docfiles 0"
    echo "tlpdbopt_install_srcfiles 0"
    echo "tlpdbopt_autobackup 0"
  } > "${tmp}/texlive.profile"
  TEXLIVE_INSTALL_ENV_NOCHECK=1 "${INSTALLER_DIR}/install-tl" \
    --profile "${tmp}/texlive.profile" \
    --repository "${REPO}" \
    --no-interaction
  rm -rf "${tmp}"
}
