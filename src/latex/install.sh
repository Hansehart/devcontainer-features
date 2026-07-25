#!/usr/bin/env bash
set -euo pipefail

# Define constants
SHARE_DIR="/usr/local/share/latex"
SELF="${SHARE_DIR}/latex.sh"
INSTALLER_DIR="${SHARE_DIR}/installer"

# Install TeX Live into $1. Portable keeps the whole tree self-contained under it (independent of
# $HOME and system paths). Uses SCHEME/REPO/INSTALLER_DIR from the caller's scope (build env or
# the baked config sourced in hook mode).
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

# ── Hook mode ──────────────────────────────────────────────────────────────────────────────────
# Runs at postCreate as the dev user (this script is self-copied to $SELF at build). Installs into
# the persisted volume on first create, then reuses it (idempotent) on later rebuilds.
if [ "${1:-}" = "hook" ]; then
  # shellcheck disable=SC1091
  . "${SHARE_DIR}/config.env"
  [ -n "${STATE_DIR:-}" ] || exit 0
  TEXDIR="${STATE_DIR}/texlive/${VERSION}"
  # texlive.profile is written only on a fully successful install - reuse it, skip the download.
  if [ -f "${TEXDIR}/tlpkg/texlive.profile" ]; then
    exit 0
  fi
  echo "latex: installing TeX Live ${VERSION} (${SCHEME}) into ${TEXDIR} - one-time, reused on later rebuilds"
  rm -rf "${TEXDIR}"          # clear any partial tree from a failed attempt (install-tl won't reuse it)
  mkdir -p "${TEXDIR}"
  install_texlive "${TEXDIR}"
  exit 0
fi

# ── Build mode ─────────────────────────────────────────────────────────────────────────────────
# Options (uppercased by the CLI): VERSION, SCHEME, STATEDIR.
STATE_DIR="$STATEDIR"
REPO="https://texlive.info/historic/systems/texlive/${VERSION}/tlnet-final"

export DEBIAN_FRONTEND=noninteractive

# 1. Dependencies: install-tl's runtime deps — perl, wget, ca-certs, fontconfig.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  wget \
  perl \
  fontconfig
rm -rf /var/lib/apt/lists/*

# 2. Fetch: the year-matched installer bootstrap, persisted outside /tmp so the postCreate hook
#    can run it later (stateDir mode).
mkdir -p "${INSTALLER_DIR}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
wget -q -O "${tmp}/install-tl-unx.tar.gz" "${REPO}/install-tl-unx.tar.gz"
tar -xzf "${tmp}/install-tl-unx.tar.gz" -C "${tmp}"
boot="$(find "${tmp}" -maxdepth 1 -type d -name 'install-tl-*' -print -quit)"
cp -a "${boot}"/. "${INSTALLER_DIR}"/

# 3. Detect: the TeX Live platform id names the binary dir (TEXDIR/bin/<PLAT>).
PLAT="$("${INSTALLER_DIR}/install-tl" -print-platform)"

# 4. Configure: bake the hook's config and install this script as the postCreate hook.
{
  echo "STATE_DIR=\"${STATE_DIR}\""
  echo "VERSION=\"${VERSION}\""
  echo "SCHEME=\"${SCHEME}\""
  echo "REPO=\"${REPO}\""
  echo "PLAT=\"${PLAT}\""
  echo "INSTALLER_DIR=\"${INSTALLER_DIR}\""
} > "${SHARE_DIR}/config.env"
install -m 0755 install.sh "${SELF}"

# 5. Install: with no stateDir, install into the image now (build-time). With a stateDir the install
#    is deferred to the postCreate hook (step above) so it lands on the persisted volume; expose the
#    volume's bin dir on PATH for login shells (it appears after the first postCreate).
if [ -z "${STATE_DIR}" ]; then
  TEXDIR="/usr/local/texlive/${VERSION}"
  install_texlive "${TEXDIR}"
  ln -sf "${TEXDIR}/bin/${PLAT}"/* /usr/local/bin/
  latex --version
else
  echo "export PATH=\"${STATE_DIR}/texlive/${VERSION}/bin/${PLAT}:\$PATH\"" > /etc/profile.d/latex.sh
  chmod 0644 /etc/profile.d/latex.sh
fi
