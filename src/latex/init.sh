#!/usr/bin/env bash
set -euo pipefail

# postCreate hook: install TeX Live into the persisted stateDir and reuse it on later creates.
SHARE_DIR="/usr/local/share/latex"
# shellcheck source=lib.sh
. "${SHARE_DIR}/lib.sh"
# shellcheck disable=SC1091
. "${SHARE_DIR}/config.env"

# Run only for a stateDir that has no completed-install marker yet.
[ -n "${STATE_DIR:-}" ] || exit 0
TEXDIR="${STATE_DIR}/texlive/${VERSION}"
if [ -f "${TEXDIR}/tlpkg/texlive.profile" ]; then
  exit 0
fi

# Install onto the volume once, clearing any partial tree so install-tl starts fresh.
echo "latex: installing TeX Live ${VERSION} (${SCHEME}) into ${TEXDIR} once, reused on later rebuilds"
rm -rf "${TEXDIR}"
mkdir -p "${TEXDIR}"
install_texlive "${TEXDIR}"

# Verify: the freshly installed tree resolves.
"${TEXDIR}/bin/${PLAT}/latex" --version
