#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, IGNORESCRIPTS, NPMRC.
FEATURE=node
VERSION="$(option VERSION lts)"
IGNORE_SCRIPTS="$(option IGNORESCRIPTS true)"
NPMRC="$(option NPMRC "")"
PACKAGES+=(libatomic1)

# Resolve the channel or release line to a release and its checksum list.
resolve_version() {
  local base="https://nodejs.org/dist" index
  # Put one release per line, so the searches hold for any index layout.
  index="$(curl -fsSL "$base/index.json" | tr '}' '\n')"
  case "$VERSION" in
    v[0-9]*.[0-9]*.[0-9]*) tag="$VERSION" ;;
    [0-9]*.[0-9]*.[0-9]*)  tag="v$VERSION" ;;
    # Follow the release pointer, which moves on releases alone.
    latest) tag="$(curl -fsSL "$base/latest/SHASUMS256.txt" | grep -m1 -oP 'node-\Kv[0-9]+\.[0-9]+\.[0-9]+(?=-)' || true)" ;;
    # Search a here-string, so stopping at the first match ends the search cleanly.
    lts)    tag="$(grep -m1 '"lts":"' <<< "$index" | grep -oP '"version":"\Kv[^"]+' || true)" ;;
    *)      tag="$(grep -m1 -F "\"version\":\"v${VERSION#v}." <<< "$index" | grep -oP '"version":"\Kv[^"]+' || true)" ;;
  esac
  [ -n "$tag" ] || die "could not resolve version '$VERSION'"
  url="$base/$tag/node-$tag-linux-$(arch_name x86_64=x64 aarch64=arm64).tar.gz"
  checksums="$base/$tag/SHASUMS256.txt"
}

# Place the runtime in its own tree, with its commands on the PATH.
install_program() {
  unpack /opt/node --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md
  link_bin /opt/node/bin
}

# Write the login profile with a global prefix the dev user owns and the chosen settings.
profile() {
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
}

# Give every process a global prefix on the default PATH, and record the requested config for
# the hook to apply at create.
settings() {
  write_file /etc/opt/node/npmrc $'prefix=/usr/local\n'
  write_file /usr/local/etc/node/requested-npmrc "$NPMRC"
}

# Confirm the runtime and its package tools run from the PATH.
confirm() {
  node --version
  npm --version
  command -v npx >/dev/null
}

feature_main
