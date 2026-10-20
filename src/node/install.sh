#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, IGNORESCRIPTS, NPMRC.
VERSION="${VERSION:-lts}"
STATE_DIR="${STATEDIR:-}"
IGNORE_SCRIPTS="${IGNORESCRIPTS:-true}"
NPMRC="${NPMRC:-}"

# Claim the state dir first, so a rejected path stops the build before it changes anything.
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

# Name the CPU architecture the way the release assets do.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  nodearch="x64" ;;
  aarch64 | arm64) nodearch="arm64" ;;
  *) echo "node: unsupported architecture '$arch'" >&2; exit 1 ;;
esac

# Resolve the channel or release line to a release tag.
base="https://nodejs.org/dist"
# Put one release per line, so the searches hold for any index layout.
index="$(curl -fsSL "$base/index.json" | tr '}' '\n')"
case "$VERSION" in
  v[0-9]*.[0-9]*.[0-9]*) tag="$VERSION" ;;
  [0-9]*.[0-9]*.[0-9]*)  tag="v$VERSION" ;;
  # Search a here-string, so stopping at the first match ends the search cleanly.
  latest) tag="$(grep -m1 -oP '"version":"\Kv[^"]+' <<< "$index" || true)" ;;
  lts)    tag="$(grep -m1 '"lts":"' <<< "$index" | grep -oP '"version":"\Kv[^"]+' || true)" ;;
  *)      tag="$(grep -m1 -F "\"version\":\"v${VERSION#v}." <<< "$index" | grep -oP '"version":"\Kv[^"]+' || true)" ;;
esac
[ -n "$tag" ] || { echo "node: could not resolve version '$VERSION'" >&2; exit 1; }
asset="node-$tag-linux-$nodearch.tar.gz"
echo "node: installing $tag ($VERSION)"

# Download the release and verify it against the published checksums.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/$tag/$asset" -o "$tmp/$asset"
curl -fsSL "$base/$tag/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt"
( cd "$tmp" && grep " $asset\$" SHASUMS256.txt | sha256sum -c - )

# Unpack into the feature's own folder.
install -d /opt/node
tar -xzf "$tmp/$asset" -C /opt/node --strip-components=1 --no-same-owner \
  --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md

# Link the runtime and its tools onto the default PATH.
ln -sf /opt/node/bin/* /usr/local/bin/

# Give every process a global prefix on the default PATH, through the config containerEnv
# points npm at.
install -d /etc/opt/node
echo 'prefix=/usr/local' > /etc/opt/node/npmrc

# Write the login profile with a global prefix the dev user owns and the chosen npm settings.
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
  if [ "$IGNORE_SCRIPTS" = "true" ]; then
    echo 'export NPM_CONFIG_IGNORE_SCRIPTS=true'
  fi
} > /etc/profile.d/node.sh
chmod 0644 /etc/profile.d/node.sh

# Install the hook that prepares the state dir and applies the requested config at create.
install -d /usr/local/libexec/node
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/libexec/node/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/libexec/node/state-dir.sh

# Record the requested config, for the hook to apply at create.
install -d /usr/local/etc/node
printf '%s' "$NPMRC" > /usr/local/etc/node/requested-npmrc

# Confirm the runtime and its package tools run from the PATH.
node --version
npm --version
command -v npx >/dev/null
