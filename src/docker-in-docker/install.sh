#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Options (uppercased by the CLI): VERSION, STATEDIR, BUILDXVERSION, COMPOSEVERSION, DAEMONJSON.
FEATURE=docker-in-docker
VERSION="$(option VERSION latest)"
BUILDX_VERSION="$(option BUILDXVERSION latest)"
COMPOSE_VERSION="$(option COMPOSEVERSION latest)"
DAEMON_JSON="$(option DAEMONJSON "")"

# Accept only options in the feature's format, before anything is installed.
format='^(latest|[0-9]+(\.[0-9]+){0,2})$'
require_version "$format"
require_version "$format" "$BUILDX_VERSION" buildxVersion
require_version "$format" "$COMPOSE_VERSION" composeVersion

# Install the packages the engine needs at build and at run time.
PACKAGES+=(erofs-utils iptables pigz)
# Ship the entrypoint that starts the daemon with the container.
HOOKS+=(docker-init.sh)

# Turn a requested version into the exact release the package manager installs, so a short version
# picks the newest release in its line.
resolve() {
  local pkg="$1" want="$2" ver
  if [ "$want" = "latest" ]; then
    ver="$(apt-cache policy "$pkg" | awk '/Candidate:/ {print $2}')"
  else
    # Compare against the project's own version number, so a requested version reads as
    # the project numbers its releases.
    ver="$(apt-cache madison "$pkg" | awk -v v="$want" '
      { s = $3; sub(/^[0-9]+:/, "", s) }
      index(s, v) == 1 && substr(s, length(v) + 1, 1) ~ /[.-]/ { print $3; exit }')"
  fi
  [ -n "$ver" ] || die "$pkg version '$want' not found in apt"
  echo "$ver"
}

# Resolve each component to an exact release from the vendor's own package repository.
resolve_version() {
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  engine="$(resolve docker-ce "$VERSION")"
  buildx="$(resolve docker-buildx-plugin "$BUILDX_VERSION")"
  compose="$(resolve docker-compose-plugin "$COMPOSE_VERSION")"
  tag="$engine"
  delegated="apt checks each package against the repository's signed index"
}

# Install the engine with its official plugins, plus the helpers a daemon run by the dev
# user relies on. The engine's companion packages share its release, which they require.
install_program() {
  log "with buildx $buildx ($BUILDX_VERSION), compose $compose ($COMPOSE_VERSION)"
  apt_install \
    "docker-ce=$engine" \
    "docker-ce-cli=$engine" \
    "docker-ce-rootless-extras=$engine" \
    containerd.io \
    "docker-buildx-plugin=$buildx" \
    "docker-compose-plugin=$compose" \
    fuse-overlayfs \
    iproute2 \
    libcap2-bin \
    slirp4netns \
    uidmap
  # Hold the engine at this release, so it stays matched to the data it keeps.
  apt-mark hold docker-ce docker-ce-cli docker-ce-rootless-extras containerd.io
}

# Point login shells at the published socket, and the CLI config at the state dir when set.
profile() {
  echo 'export DOCKER_HOST=unix:///run/docker-rootless.sock'
  if [ -n "$STATE_DIR" ]; then echo "export DOCKER_CONFIG=\"$STATE_DIR\""; fi
}

# Record which user runs the daemon and the requested daemon settings, for the entrypoint
# to apply at start.
settings() {
  record rootless-user "$_REMOTE_USER"$'\n'
  record requested-daemon.json "$DAEMON_JSON"
}

# Set up the dev user who runs the daemon, and ship the syscall profile it needs.
post_install() {
  # Keep the docker group that tooling expects.
  groupadd -f docker
  if [ "$_REMOTE_USER" != "root" ]; then
    usermod -aG docker "$_REMOTE_USER" || true
    # Grant the subordinate ids the daemon maps its containers into.
    local f
    for f in /etc/subuid /etc/subgid; do
      grep -q "^${_REMOTE_USER}:" "$f" || echo "${_REMOTE_USER}:100000:65536" >> "$f"
    done
  fi
  install -d "$FEATURE_ROOT/usr/local/share/$FEATURE"
  install -m 0644 "$FEATURE_DIR/seccomp.json" "$FEATURE_ROOT/usr/local/share/$FEATURE/seccomp.json"
}

# Confirm the CLI runs from the PATH.
confirm() {
  docker --version
}

feature_main
