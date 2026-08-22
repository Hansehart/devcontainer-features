#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, SCHEME, STATEDIR.
STATE_DIR="$STATEDIR"

SHARE_DIR="/usr/local/share/latex"
INSTALLER_DIR="${SHARE_DIR}/installer"
REPO="https://texlive.info/historic/systems/texlive/${VERSION}/tlnet-final"

# Shared install_texlive(), also placed in SHARE_DIR for the hook to source at runtime.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: packages this feature needs to install and run.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  fontconfig \
  perl \
  wget
rm -rf /var/lib/apt/lists/*

# Fetch: the year-matched installer bootstrap, persisted so the hook can reuse it at runtime.
mkdir -p "${INSTALLER_DIR}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
wget -q -O "${tmp}/install-tl-unx.tar.gz" "${REPO}/install-tl-unx.tar.gz"
tar -xzf "${tmp}/install-tl-unx.tar.gz" -C "${tmp}"
boot="$(find "${tmp}" -maxdepth 1 -type d -name 'install-tl-*' -print -quit)"
cp -a "${boot}"/. "${INSTALLER_DIR}"/

# Resolve: the TeX Live platform id names the binary dir (needs the fetched installer).
PLAT="$("${INSTALLER_DIR}/install-tl" -print-platform)"

# Configure: bake the hook's config and install the shared lib + hook script.
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

# Install into the image directly, or set PATH and defer to the hook when a stateDir is set.
if [ -z "${STATE_DIR}" ]; then
  TEXDIR="/usr/local/texlive/${VERSION}"
  install_texlive "${TEXDIR}"
  ln -sf "${TEXDIR}/bin/${PLAT}"/* /usr/local/bin/
else
  echo "export PATH=\"${STATE_DIR}/texlive/${VERSION}/bin/${PLAT}:\$PATH\"" > /etc/profile.d/latex.sh
  chmod 0644 /etc/profile.d/latex.sh
  # Pre-create the state dir owned by the dev user so a volume mounted there inherits it.
  install -d -m 0700 "${STATE_DIR}"
  chown "$_REMOTE_USER:" "${STATE_DIR}"
fi

# Verify: build-time install resolves on PATH, and the hook verifies stateDir mode.
[ -n "${STATE_DIR}" ] || latex --version
