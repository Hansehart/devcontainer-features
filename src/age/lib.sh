#!/usr/bin/env bash
# The install sequence every feature shares, copied unchanged into each feature by lib/sync.sh.
# A feature names itself, defines how its program is resolved and installed, then runs the sequence.

# Default the dev user the CLI provisions, for features that act as that user.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Locate the feature's own files, and the root the system paths hang from.
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_ROOT="${FEATURE_ROOT:-}"
if [ -n "$FEATURE_ROOT" ]; then PATH="$FEATURE_ROOT/usr/local/bin:$PATH"; fi

# Read the options features share, and the packages every feature needs.
STATE_DIR="${STATEDIR:-}"
VERSION="${VERSION:-}"
PACKAGES=(ca-certificates curl)

# Read an option the user set, or its default.
option() {
  local value="${!1:-}"
  printf '%s' "${value:-$2}"
}

# Report progress and failures under the feature's name.
log() { echo "$FEATURE: $*"; }
die() { echo "$FEATURE: $*" >&2; exit 1; }

# Name the CPU architecture the way the release names it.
arch_name() {
  local machine pair
  machine="$(uname -m)"
  case "$machine" in
    amd64) machine=x86_64 ;;
    arm64) machine=aarch64 ;;
  esac
  for pair in "$@"; do
    if [ "${pair%%=*}" = "$machine" ]; then
      printf '%s' "${pair#*=}"
      return 0
    fi
  done
  die "unsupported architecture '$machine'"
}

# Resolve the requested version to the exact release it names.
release_tag() {
  local host="$1" repo="$2" version="$3" bare="${4:-}" api tag
  if [ "$version" = latest ]; then
    if [ "$host" = github ]; then
      api="${RELEASE_API:-https://api.github.com}"
    else
      api="${RELEASE_API:-https://$host}/api/v1"
    fi
    tag="$(curl -fsSL "$api/repos/$repo/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' || true)"
    [ -n "$tag" ] || die "could not resolve the latest version"
    printf '%s' "$tag"
  elif [ "$bare" = --bare ]; then
    printf '%s' "$version"
  else
    printf 'v%s' "${version#v}"
  fi
}

# Install the packages the feature needs at build and at run time.
apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends "$@"
  rm -rf "$FEATURE_ROOT"/var/lib/apt/lists/*
}

# Unpack the release into the work dir.
untar() { tar -xzf "$tmp/$asset" -C "$tmp" --strip-components=1; }

# Install the program's commands, optionally under a chosen name.
install_bin() {
  local dir="$FEATURE_ROOT/usr/local/bin"
  install -d "$dir"
  if [ "${2:-}" = as ]; then
    install -m 0755 "$1" "$dir/$3"
  else
    install -m 0755 "$@" "$dir/"
  fi
}

# Claim the state dir first, so a rejected path stops the build before it changes anything.
claim_state_dir() {
  [ -n "$STATE_DIR" ] || return 0
  [ -f "$FEATURE_DIR/state-dir.sh" ] || die "a state dir needs state-dir.sh in the feature"
  "$FEATURE_DIR/state-dir.sh" "$FEATURE" "$STATE_DIR"
}

# Download the release and verify it the one way the feature declared.
download_release() {
  local declared=0 kind
  for kind in "$checksums" "$checksum" "$unverified"; do
    if [ -n "$kind" ]; then declared=$((declared + 1)); fi
  done
  [ "$declared" -eq 1 ] || die "declare one of checksums, checksum or unverified"
  asset="${url##*/}"
  curl -fsSL "$url" -o "$tmp/$asset"
  if [ -n "$checksums" ]; then
    curl -fsSL "$checksums" -o "$tmp/checksums.txt"
    # Match the asset's line by its exact name, in either notation.
    ( cd "$tmp" && awk -v a="$asset" '{ n = $2; sub(/^\*/, "", n) } n == a { print $1 "  " a }' checksums.txt \
      | sha256sum -c - ) || die "checksum mismatch for $asset"
  elif [ -n "$checksum" ]; then
    curl -fsSL "$checksum" -o "$tmp/$asset.sha256"
    # Check the hash the file leads with, whether or not it names the asset too.
    ( cd "$tmp" && printf '%s  %s\n' "$(awk '{ print $1; exit }' "$asset.sha256")" "$asset" \
      | sha256sum -c - ) || die "checksum mismatch for $asset"
  else
    log "skipping verification: $unverified"
  fi
}

# Write the login profile from the lines the feature prints, when it prints any.
write_profile() {
  local lines dir="$FEATURE_ROOT/etc/profile.d"
  declare -F profile >/dev/null || return 0
  lines="$(profile)"
  [ -n "$lines" ] || return 0
  install -d "$dir"
  printf '%s\n' "$lines" > "$dir/$FEATURE.sh"
  chmod 0644 "$dir/$FEATURE.sh"
}

# Install the hooks the feature ships, which run when the container is created.
install_hooks() {
  local dir="$FEATURE_ROOT/usr/local/libexec/$FEATURE"
  [ -f "$FEATURE_DIR/init.sh" ] || return 0
  install -d "$dir"
  install -m 0755 "$FEATURE_DIR/init.sh" "$dir/init.sh"
  if [ -f "$FEATURE_DIR/state-dir.sh" ]; then
    install -m 0755 "$FEATURE_DIR/state-dir.sh" "$dir/state-dir.sh"
  fi
}

# Run a part the feature may define, when it does.
optional() {
  if declare -F "$1" >/dev/null; then "$1"; fi
}

# Run the feature through the shared sequence.
feature_main() {
  local part
  for part in resolve_version install_program; do
    declare -F "$part" >/dev/null || die "missing $part"
  done
  claim_state_dir
  apt_install "${PACKAGES[@]}"
  tag="" url="" checksums="" checksum="" unverified=""
  resolve_version
  log "installing $tag${VERSION:+ ($VERSION)}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  download_release
  install_program
  write_profile
  optional settings
  install_hooks
  optional post_install
  # Confirm the tool runs from the PATH, the feature's own way when it has one.
  if declare -F confirm >/dev/null; then confirm; else "$FEATURE" --version; fi
}

# Keep the shared steps the same for every feature.
readonly -f option log die arch_name release_tag apt_install untar install_bin claim_state_dir \
  download_release write_profile install_hooks optional feature_main
