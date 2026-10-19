#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, STATEDIR, BUILDXVERSION, COMPOSEVERSION, DAEMONJSON.
VERSION="${VERSION:-latest}"
STATE_DIR="${STATEDIR:-}"
BUILDX_VERSION="${BUILDXVERSION:-latest}"
COMPOSE_VERSION="${COMPOSEVERSION:-latest}"
DAEMON_JSON="${DAEMONJSON:-}"

# Claim the state dir first, so a rejected path stops the build before it changes anything.
if [ -n "$STATE_DIR" ]; then
  "$(dirname "$0")/state-dir.sh" docker-in-docker "$STATE_DIR"
fi

export DEBIAN_FRONTEND=noninteractive

# Install the packages this feature needs at build and at run time.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  erofs-utils \
  iptables \
  pigz

# Trust Docker's own package repository.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update

# Turn a requested version into the exact release apt installs, so a short version
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
  [ -n "$ver" ] || { echo "docker-in-docker: $pkg version '$want' not found in apt" >&2; return 1; }
  echo "$ver"
}

# Resolve each component to an exact release, so the log names what gets installed.
engine="$(resolve docker-ce "$VERSION")"
buildx="$(resolve docker-buildx-plugin "$BUILDX_VERSION")"
compose="$(resolve docker-compose-plugin "$COMPOSE_VERSION")"
echo "docker-in-docker: installing engine $engine ($VERSION), buildx $buildx ($BUILDX_VERSION), compose $compose ($COMPOSE_VERSION)"

# Install the engine with its official plugins, plus the helpers a daemon run by the dev
# user relies on. The engine's companion packages share its release, which they require.
apt-get install -y --no-install-recommends \
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

rm -rf /var/lib/apt/lists/*

# Keep the docker group that tooling expects.
groupadd -f docker
# Set up the dev user, who runs the daemon.
if [ "$_REMOTE_USER" != "root" ]; then
  usermod -aG docker "$_REMOTE_USER" || true

  # Grant the subordinate ids the daemon maps its containers into.
  for f in /etc/subuid /etc/subgid; do
    grep -q "^${_REMOTE_USER}:" "$f" || echo "${_REMOTE_USER}:100000:65536" >> "$f"
  done
fi

# Install the entrypoint that starts the daemon with the container.
install -d /usr/local/share/docker-in-docker
install -m 0755 "$(dirname "$0")/docker-init.sh" /usr/local/share/docker-in-docker/docker-init.sh

# Record which user runs the daemon, for the entrypoint to read at start.
printf '%s\n' "$_REMOTE_USER" > /usr/local/share/docker-in-docker/rootless-user

# Keep the requested daemon settings for the entrypoint to apply.
printf '%s' "$DAEMON_JSON" > /usr/local/share/docker-in-docker/requested-daemon.json

# Ship the seccomp profile the daemon needs, for consumers to reference.
install -m 0644 "$(dirname "$0")/seccomp.json" /usr/local/share/docker-in-docker/seccomp.json

# Install the hook that prepares the state dir when the container is created.
install -m 0755 "$(dirname "$0")/init.sh" /usr/local/share/docker-in-docker/init.sh
install -m 0755 "$(dirname "$0")/state-dir.sh" /usr/local/share/docker-in-docker/state-dir.sh

# Point login shells at the published socket, and the CLI config at the state dir when set.
{
  echo 'export DOCKER_HOST=unix:///run/docker-rootless.sock'
  if [ -n "$STATE_DIR" ]; then
    echo "export DOCKER_CONFIG=\"$STATE_DIR\""
  fi
} > /etc/profile.d/docker-in-docker.sh
chmod 0644 /etc/profile.d/docker-in-docker.sh

# Confirm the CLI runs from the PATH.
docker --version
