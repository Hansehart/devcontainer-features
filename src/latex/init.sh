#!/usr/bin/env bash
set -euo pipefail

# Install TeX Live into the persisted stateDir and reuse it on later creates.
SHARE_DIR="/usr/local/share/latex"
# shellcheck source=lib.sh
. "${SHARE_DIR}/lib.sh"
. "${SHARE_DIR}/config.env"

# Run only for a stateDir that has no completed-install marker yet.
[ -n "${STATE_DIR:-}" ] || exit 0

# A state dir sharing a filesystem with / holds its contents in the container, which goes at
# the next rebuild. Report it before the install, which otherwise spends minutes writing there.
if [ -d "$STATE_DIR" ] && [ "$(stat -c %d "$STATE_DIR")" = "$(stat -c %d /)" ]; then
  echo "latex: $STATE_DIR is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

TEXDIR="${STATE_DIR}/texlive/${VERSION}"
if [ -f "${TEXDIR}/tlpkg/texlive.profile" ]; then
  exit 0
fi

# Install onto the volume once, clearing any partial tree so install-tl starts fresh.
echo "latex: installing TeX Live ${VERSION} (${SCHEME}) into ${TEXDIR} once, reused on later rebuilds"
rm -rf "${TEXDIR}"
mkdir -p "${TEXDIR}"
install_texlive "${TEXDIR}"

# Check that the freshly installed tree resolves.
"${TEXDIR}/bin/${PLAT}/latex" --version
