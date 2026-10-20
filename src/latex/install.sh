#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, SCHEME.
VERSION="${VERSION:-2025}"
STATE_DIR="${STATEDIR:-}"
SCHEME="${SCHEME:-scheme-basic}"

# Claim the state dir first, so a rejected path stops the build before it changes anything.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" latex "$STATE_DIR"
fi

LIBEXEC_DIR="/usr/local/libexec/latex"
CONFIG_DIR="/usr/local/etc/latex"
INSTALLER_DIR="$LIBEXEC_DIR/installer"
REPO="https://texlive.info/historic/systems/texlive/$VERSION/tlnet-final"

# Share the TeX Live install routine with the hook.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  fontconfig \
  perl \
  wget
rm -rf /var/lib/apt/lists/*

# Fetch the installer for the chosen release, verify it, and keep it for the hook.
mkdir -p "$INSTALLER_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$REPO/install-tl-unx.tar.gz" -o "$tmp/install-tl-unx.tar.gz"
curl -fsSL "$REPO/install-tl-unx.tar.gz.sha512" -o "$tmp/install-tl-unx.tar.gz.sha512"
( cd "$tmp" && sha512sum -c install-tl-unx.tar.gz.sha512 )
tar -xzf "$tmp/install-tl-unx.tar.gz" -C "$tmp"
boot="$(find "$tmp" -maxdepth 1 -type d -name 'install-tl-*' -print -quit)"
cp -a "$boot"/. "$INSTALLER_DIR"/

# Read the platform name, which locates the binaries.
PLAT="$("$INSTALLER_DIR/install-tl" -print-platform)"

# Install TeX Live into the image, or leave it to the hook when a state dir holds it.
if [ -z "$STATE_DIR" ]; then
  TEXDIR="/opt/texlive/$VERSION"
  install_texlive "$TEXDIR" "/var/opt/texlive/$VERSION" "/etc/opt/texlive/$VERSION"
  ln -sf "$TEXDIR/bin/$PLAT"/* /usr/local/bin/
else
  echo "export PATH=\"$STATE_DIR/texlive/$VERSION/bin/$PLAT:\$PATH\"" > /etc/profile.d/latex.sh
  chmod 0644 /etc/profile.d/latex.sh
fi

# Record the hook's settings.
install -d "$CONFIG_DIR"
{
  echo "STATE_DIR=\"$STATE_DIR\""
  echo "VERSION=\"$VERSION\""
  echo "SCHEME=\"$SCHEME\""
  echo "REPO=\"$REPO\""
  echo "PLAT=\"$PLAT\""
  echo "INSTALLER_DIR=\"$INSTALLER_DIR\""
} > "$CONFIG_DIR/config.env"

# Install the hook, the shared routine and the state-dir guard next to the kept installer.
install -m 0644 "$(dirname "$0")/lib.sh" "$LIBEXEC_DIR/lib.sh"
install -m 0755 "$(dirname "$0")/init.sh" "$LIBEXEC_DIR/init.sh"
install -m 0755 "$(dirname "$0")/state-dir.sh" "$LIBEXEC_DIR/state-dir.sh"

# Confirm an image install runs from the PATH; the hook confirms a state-dir install.
[ -n "$STATE_DIR" ] || latex --version
