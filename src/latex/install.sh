#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, SCHEME, STATEDIR.
STATE_DIR="$STATEDIR"

# Define constants
SHARE_DIR="/usr/local/share/latex"
INSTALLER_DIR="${SHARE_DIR}/installer"
REPO="https://texlive.info/historic/systems/texlive/${VERSION}/tlnet-final"

# Shared install_texlive() — also installed to SHARE_DIR for the hook to source at runtime.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

export DEBIAN_FRONTEND=noninteractive

# 1. Dependencies: install-tl's runtime deps — perl, wget, ca-certs, fontconfig.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  wget \
  perl \
  fontconfig
rm -rf /var/lib/apt/lists/*

# 2. Fetch: the year-matched installer bootstrap, persisted so the hook can reuse it at runtime.
mkdir -p "${INSTALLER_DIR}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
wget -q -O "${tmp}/install-tl-unx.tar.gz" "${REPO}/install-tl-unx.tar.gz"
tar -xzf "${tmp}/install-tl-unx.tar.gz" -C "${tmp}"
boot="$(find "${tmp}" -maxdepth 1 -type d -name 'install-tl-*' -print -quit)"
cp -a "${boot}"/. "${INSTALLER_DIR}"/

# 3. Resolve: the TeX Live platform id names the binary dir (needs the fetched installer).
PLAT="$("${INSTALLER_DIR}/install-tl" -print-platform)"

# 4. Configure: bake the hook's config and install the shared lib + hook script.
{
  echo "STATE_DIR=\"${STATE_DIR}\""
  echo "VERSION=\"${VERSION}\""
  echo "SCHEME=\"${SCHEME}\""
  echo "REPO=\"${REPO}\""
  echo "PLAT=\"${PLAT}\""
  echo "INSTALLER_DIR=\"${INSTALLER_DIR}\""
} > "${SHARE_DIR}/config.env"
install -m 0644 "$(dirname "$0")/lib.sh" "${SHARE_DIR}/lib.sh"
install -m 0755 "$(dirname "$0")/init.sh" "${SHARE_DIR}/init.sh"

# 5. Install: no stateDir installs into the image now; a stateDir defers to the hook and just sets PATH.
if [ -z "${STATE_DIR}" ]; then
  TEXDIR="/usr/local/texlive/${VERSION}"
  install_texlive "${TEXDIR}"
  ln -sf "${TEXDIR}/bin/${PLAT}"/* /usr/local/bin/
else
  echo "export PATH=\"${STATE_DIR}/texlive/${VERSION}/bin/${PLAT}:\$PATH\"" > /etc/profile.d/latex.sh
  chmod 0644 /etc/profile.d/latex.sh
fi

# 6. Verify: build-time install resolves on PATH; stateDir mode is verified by the hook.
[ -n "${STATE_DIR}" ] || latex --version
