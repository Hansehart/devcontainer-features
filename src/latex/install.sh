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

REPO="https://texlive.info/historic/systems/texlive/$VERSION/tlnet-final"
TEXDIR="/opt/texlive/$VERSION"

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

# Fetch the installer for the chosen release and verify it.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$REPO/install-tl-unx.tar.gz" -o "$tmp/install-tl-unx.tar.gz"
curl -fsSL "$REPO/install-tl-unx.tar.gz.sha512" -o "$tmp/install-tl-unx.tar.gz.sha512"
( cd "$tmp" && sha512sum -c install-tl-unx.tar.gz.sha512 )
tar -xzf "$tmp/install-tl-unx.tar.gz" -C "$tmp"
installer="$(find "$tmp" -maxdepth 1 -type d -name 'install-tl-*' -print -quit)"

# Install the distribution into its own tree, with its generated data and host config kept
# apart, where the layout rules place them.
{
  echo "selected_scheme $SCHEME"
  echo "TEXDIR $TEXDIR"
  echo "TEXMFLOCAL $TEXDIR/texmf-local"
  echo "TEXMFSYSVAR /var/opt/texlive/$VERSION"
  echo "TEXMFSYSCONFIG /etc/opt/texlive/$VERSION"
  echo "tlpdbopt_install_docfiles 0"
  echo "tlpdbopt_install_srcfiles 0"
  echo "tlpdbopt_autobackup 0"
} > "$tmp/texlive.profile"
TEXLIVE_INSTALL_ENV_NOCHECK=1 "$installer/install-tl" \
  --profile "$tmp/texlive.profile" \
  --repository "$REPO" \
  --no-interaction

# Link the commands onto the default PATH.
PLAT="$("$installer/install-tl" -print-platform)"
ln -sf "$TEXDIR/bin/$PLAT"/* /usr/local/bin/

# Point the user's own trees at the state dir when set.
if [ -n "$STATE_DIR" ]; then
  {
    echo "export TEXMFHOME=\"$STATE_DIR/texmf\""
    echo "export TEXMFVAR=\"$STATE_DIR/texmf-var\""
    echo "export TEXMFCONFIG=\"$STATE_DIR/texmf-config\""
  } > /etc/profile.d/latex.sh
  chmod 0644 /etc/profile.d/latex.sh
fi

# Install the hook that prepares the state dir when the container is created.
install -d /usr/local/libexec/latex
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/libexec/latex/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/libexec/latex/state-dir.sh

# Confirm the distribution runs from the PATH.
latex --version
