#!/usr/bin/env bash
set -euo pipefail

# Define constants
REPO="https://texlive.info/historic/systems/texlive/${VERSION}/tlnet-final"
TEXDIR="/usr/local/texlive/${VERSION}"

export DEBIAN_FRONTEND=noninteractive

# 1. install-tl's runtime deps: a Perl interpreter, a downloader, and CA certs.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  wget \
  perl \
  fontconfig
rm -rf /var/lib/apt/lists/*

# 2. Fetch the year-matched installer bootstrap from the pinned snapshot.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
wget -q -O "$tmp/install-tl-unx.tar.gz" "${REPO}/install-tl-unx.tar.gz"
tar -xzf "$tmp/install-tl-unx.tar.gz" -C "$tmp"
installer="$(find "$tmp" -maxdepth 1 -type d -name 'install-tl-*' -print -quit)"

# 3. Non-interactive profile installing the selected scheme without docs or sources.
{
  echo "selected_scheme ${SCHEME}"
  echo "TEXDIR ${TEXDIR}"
  echo "TEXMFLOCAL ${TEXDIR}/texmf-local"
  echo "TEXMFSYSVAR ${TEXDIR}/texmf-var"
  echo "TEXMFSYSCONFIG ${TEXDIR}/texmf-config"
  echo "tlpdbopt_install_docfiles 0"
  echo "tlpdbopt_install_srcfiles 0"
  echo "tlpdbopt_autobackup 0"
} > "$tmp/texlive.profile"

# 4. Install from the pinned repository.
"${installer}/install-tl" \
  --profile "$tmp/texlive.profile" \
  --repository "${REPO}" \
  --no-interaction

# 5. Expose the binaries on PATH (the bin dir is named after the platform).
bindir="$(find "${TEXDIR}/bin" -mindepth 1 -maxdepth 1 -type d -print -quit)"
ln -sf "${bindir}"/* /usr/local/bin/

# 6. Sanity check.
latex --version | head -1
latexmk --version | head -1
biber --version | head -1
