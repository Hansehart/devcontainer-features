#!/usr/bin/env bash
set -euo pipefail

# postCreate hook: installs TeX Live into the persisted stateDir on first create, reuses it after.
SHARE_DIR="/usr/local/share/latex"
# shellcheck source=lib.sh
. "${SHARE_DIR}/lib.sh"
# shellcheck disable=SC1091
. "${SHARE_DIR}/config.env"

# Reuse guards: skip when there's no stateDir (already in the image) or a completed-install marker.
[ -n "${STATE_DIR:-}" ] || exit 0
TEXDIR="${STATE_DIR}/texlive/${VERSION}"
if [ -f "${TEXDIR}/tlpkg/texlive.profile" ]; then
  exit 0
fi

# Install: one-time install onto the volume (clear any partial tree first; install-tl won't reuse it).
echo "latex: installing TeX Live ${VERSION} (${SCHEME}) into ${TEXDIR} - one-time, reused on later rebuilds"
rm -rf "${TEXDIR}"
mkdir -p "${TEXDIR}"
install_texlive "${TEXDIR}"

# Verify: the freshly installed tree resolves.
"${TEXDIR}/bin/${PLAT}/latex" --version
