#!/usr/bin/env bash
# The install sequence every feature shares, copied unchanged into each feature by lib/sync.sh.
# A feature names itself, defines how its program is resolved and installed, then runs the sequence.

# Default the dev user the CLI provisions, for features that act as that user.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Locate the feature's own files, and the root the system paths hang from, which only the
# library's tests move.
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_ROOT="${_FEATURE_TEST_ROOT:-}"
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
      api="${_FEATURE_TEST_API:-https://api.github.com}"
    else
      api="${_FEATURE_TEST_API:-https://$host}/api/v1"
    fi
    tag="$(curl -fsSL "$api/repos/$repo/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' || true)"
    [ -n "$tag" ] || die "could not resolve the latest version"
    if [ "$bare" = --bare ]; then printf '%s' "${tag#v}"; else printf '%s' "$tag"; fi
  elif [ "$bare" = --bare ]; then
    printf '%s' "${version#v}"
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
untar() {
  [ -n "$asset" ] || die "nothing was downloaded to unpack"
  tar -xzf "$tmp/$asset" -C "$tmp" --strip-components=1
}

# Unpack the release into its own tree, without the archive's single top folder or its owners.
unpack() {
  local dest="$FEATURE_ROOT$1" staging="$tmp/unpacked" entries
  shift
  [ -n "$asset" ] || die "nothing was downloaded to unpack"
  install -d "$dest"
  case "$asset" in
    *.zip)
      [ "$#" -eq 0 ] || die "archive options apply to tarballs"
      command -v unzip >/dev/null || die "unpacking a zip needs unzip among the packages"
      unzip -q "$tmp/$asset" -d "$staging"
      # Step into a single top folder, counting hidden entries too, and keep any other layout
      # as the archive has it.
      entries="$(find "$staging" -mindepth 1 -maxdepth 1)"
      if [ -n "$entries" ] && [ "$(printf '%s\n' "$entries" | wc -l)" -eq 1 ] && [ -d "$entries" ]; then
        staging="$entries"
      fi
      # Replace what an earlier unpack left under each name, so the tree matches the archive.
      find "$staging" -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' entry; do
        rm -rf "${dest:?}/${entry##*/}"
        mv "$entry" "$dest/"
      done
      ;;
    *)
      tar -xf "$tmp/$asset" -C "$dest" --strip-components=1 --no-same-owner "$@"
      ;;
  esac
}

# Link a tree's commands onto the PATH: the named ones, or every one it holds.
link_bin() {
  local tree="$1" dir="$FEATURE_ROOT$1" bin="$FEATURE_ROOT/usr/local/bin" path name
  shift
  install -d "$bin"
  if [ "$#" -eq 0 ]; then
    [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ] || die "no commands in $tree"
    for path in "$dir"/*; do ln -sf "$path" "$bin/"; done
  else
    for name in "$@"; do ln -sf "$dir/$name" "$bin/$name"; done
  fi
}

# Accept only a requested version in the feature's format, before it reaches any command.
require_version() {
  [[ "$VERSION" =~ $1 ]] || die "unsupported version '$VERSION'"
}

# Keep a setting for the feature's hooks, exactly as given.
record() { write_file "/usr/local/etc/$FEATURE/$1" "${2-}"; }

# Run a command as the dev user, in a login shell.
as_user() { su - "$_REMOTE_USER" -c "$1"; }

# Write a file with exactly the given content, readable by everyone.
write_file() {
  local path="$FEATURE_ROOT$1"
  install -d "$(dirname "$path")"
  printf '%s' "${2-}" > "$path"
  chmod 0644 "$path"
}

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

# Check the download against a digest, by the algorithm its length shows.
check_digest() {
  local sum
  case "${#1}" in
    64) sum=sha256sum ;;
    128) sum=sha512sum ;;
    *) die "checksum mismatch for $asset" ;;
  esac
  ( cd "$tmp" && printf '%s  %s\n' "$1" "$asset" | "$sum" -c - ) || die "checksum mismatch for $asset"
}

# Download the release and verify it the one way the feature declared.
download_release() {
  local declared=0 kind digest
  for kind in "$checksums" "$checksum" "$unverified" "$delegated"; do
    if [ -n "$kind" ]; then declared=$((declared + 1)); fi
  done
  [ "$declared" -eq 1 ] || die "declare one of checksums, checksum, unverified or delegated"
  # Leave the download to the vendor's installer, which fetches and checks the program itself.
  if [ -n "$delegated" ]; then
    log "delegating the download: $delegated"
    return 0
  fi
  asset="${url##*/}"
  curl -fsSL "$url" -o "$tmp/$asset"
  if [ -n "$checksums" ]; then
    curl -fsSL "$checksums" -o "$tmp/checksums.txt"
    # Take the digest from the asset's line, matched by its exact name in either notation.
    digest="$(awk -v a="$asset" '{ n = $2; sub(/^\*/, "", n) } n == a { print $1; exit }' "$tmp/checksums.txt")"
    [ -n "$digest" ] || die "no checksum for $asset in the list"
    check_digest "$digest"
  elif [ -n "$checksum" ]; then
    curl -fsSL "$checksum" -o "$tmp/$asset.sum"
    # Take the digest the file leads with, whether or not it names the asset too.
    check_digest "$(awk '{ print $1; exit }' "$tmp/$asset.sum")"
  else
    log "trusting the download over HTTPS: $unverified"
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
  if [ -f "$FEATURE_DIR/hook.sh" ]; then
    install -m 0644 "$FEATURE_DIR/hook.sh" "$dir/hook.sh"
  fi
  # Record the state dir, for the hook to prepare at create.
  record state-dir "$STATE_DIR"
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
  tag="" url="" asset="" checksums="" checksum="" unverified="" delegated=""
  resolve_version
  # Name the requested version beside the release only when the two differ.
  if [ -n "$VERSION" ] && [ "$VERSION" != "$tag" ]; then
    log "installing $tag ($VERSION)"
  else
    log "installing $tag"
  fi
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
readonly -f option log die arch_name release_tag apt_install untar unpack link_bin write_file record as_user \
  require_version \
  install_bin claim_state_dir check_digest \
  download_release write_profile install_hooks optional feature_main
