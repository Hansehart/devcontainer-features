#!/usr/bin/env bash
set -euo pipefail

# Take the user the CLI provisions for, which varies by base image.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, NPMRC.
STATE_DIR="$STATEDIR"

# Take the state dir before any work is done, so a path this feature cannot
# own leaves the image untouched.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" node "$STATE_DIR"
fi

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  libatomic1
rm -rf /var/lib/apt/lists/*

# Map the CPU arch to Node's release arch token.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  nodearch="x64" ;;
  aarch64 | arm64) nodearch="arm64" ;;
  *) echo "node: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Map the channel or line to a tag from the release index, since asset names embed the version (explicit versions pass through).
base="https://nodejs.org/dist"
# tr puts one release per line, so the greps below hold whether or not the index stays pretty-printed.
index="$(curl -fsSL "$base/index.json" | tr '}' '\n')"
case "${VERSION:-lts}" in
  v[0-9]*.[0-9]*.[0-9]*) tag="$VERSION" ;;
  [0-9]*.[0-9]*.[0-9]*)  tag="v$VERSION" ;;
  # grep -m1 reads a here-string, not a pipe: stopping early on a pipe leaves the writer on a
  # closed pipe, and pipefail turns that SIGPIPE into a failed install.
  latest) tag="$(grep -m1 -oP '"version":"\Kv[^"]+' <<< "$index" || true)" ;;
  lts)    tag="$(grep -m1 '"lts":"' <<< "$index" | grep -oP '"version":"\Kv[^"]+' || true)" ;;
  *)      tag="$(grep -m1 -F "\"version\":\"v${VERSION#v}." <<< "$index" | grep -oP '"version":"\Kv[^"]+' || true)" ;;
esac
[ -n "$tag" ] || { echo "node: could not resolve version '$VERSION'" >&2; exit 1; }
asset="node-$tag-linux-$nodearch.tar.gz"
echo "node: installing $tag ($VERSION)"

# Download the tarball and verify it against Node's published checksums.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/$tag/$asset" -o "$tmp/$asset"
curl -fsSL "$base/$tag/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt"
( cd "$tmp" && grep " $asset\$" SHASUMS256.txt | sha256sum -c - )

# Extract into /usr/local, as root, so node, npm, and npx land on the default PATH.
tar -xzf "$tmp/$asset" -C /usr/local --strip-components=1 --no-same-owner \
  --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md

# Write a login-shell profile with a global prefix the dev user owns, so npm -g needs no root.
{
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  if [ -n "$STATE_DIR" ]; then
    echo "export NPM_CONFIG_CACHE=\"$STATE_DIR/cache\""
    echo "export NPM_CONFIG_PREFIX=\"$STATE_DIR/global\""
    echo "export NPM_CONFIG_USERCONFIG=\"$STATE_DIR/npmrc\""
    echo "export PATH=\"$STATE_DIR/global/bin:\$PATH\""
  else
    echo 'export NPM_CONFIG_PREFIX="$HOME/.local"'
  fi
} > /etc/profile.d/node.sh
chmod 0644 /etc/profile.d/node.sh

# Install the run-once hook and save the requested config for it to write.
install -d /usr/local/share/node
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/node/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/share/node/state-dir.sh
printf '%s' "$NPMRC" > /usr/local/share/node/requested-npmrc

# Check the runtime and its package tooling resolve on PATH.
node --version
npm --version
command -v npx >/dev/null
