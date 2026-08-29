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
  curl \
  fontconfig \
  perl \
  wget
rm -rf /var/lib/apt/lists/*

# Fetch: the year-matched installer bootstrap, verified against its published sha512 and
# persisted so the hook can reuse it at runtime.
mkdir -p "${INSTALLER_DIR}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "${REPO}/install-tl-unx.tar.gz" -o "${tmp}/install-tl-unx.tar.gz"
curl -fsSL "${REPO}/install-tl-unx.tar.gz.sha512" -o "${tmp}/install-tl-unx.tar.gz.sha512"
( cd "${tmp}" && sha512sum -c install-tl-unx.tar.gz.sha512 )
tar -xzf "${tmp}/install-tl-unx.tar.gz" -C "${tmp}"
boot="$(find "${tmp}" -maxdepth 1 -type d -name 'install-tl-*' -print -quit)"
cp -a "${boot}"/. "${INSTALLER_DIR}"/

# Resolve: the TeX Live platform id names the binary dir (needs the fetched installer).
PLAT="$("${INSTALLER_DIR}/install-tl" -print-platform)"

# Install: TeX Live into the image directly, or set PATH and defer to the hook when a stateDir is set.
if [ -z "${STATE_DIR}" ]; then
  TEXDIR="/usr/local/texlive/${VERSION}"
  install_texlive "${TEXDIR}"
  ln -sf "${TEXDIR}/bin/${PLAT}"/* /usr/local/bin/
else
  echo "export PATH=\"${STATE_DIR}/texlive/${VERSION}/bin/${PLAT}:\$PATH\"" > /etc/profile.d/latex.sh
  chmod 0644 /etc/profile.d/latex.sh
  # Configure: own the state dir by a dedicated group so it stays writable after a UID remap.
  groupadd -r -f latex
  usermod -aG latex "$_REMOTE_USER" || true
  install -d -m 0770 "${STATE_DIR}"
  chown "$_REMOTE_USER:latex" "${STATE_DIR}"
  chmod g+s "${STATE_DIR}"
fi

# Hook: bake the hook's config and install the shared lib + hook script.
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

# Verify: build-time install resolves on PATH, and the hook verifies stateDir mode.
[ -n "${STATE_DIR}" ] || latex --version
