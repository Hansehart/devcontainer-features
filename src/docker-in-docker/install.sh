#!/usr/bin/env bash
set -euo pipefail

# Install for the dev user the CLI provisions.
_REMOTE_USER="${_REMOTE_USER:-root}"

# Options (uppercased by the CLI): VERSION, DAEMONJSON.
VERSION="${VERSION:-latest}"
DAEMON_JSON="${DAEMONJSON:-}"

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

# Install the current release, or the release matching the requested version.
if [ "$VERSION" = "latest" ]; then
  # Read the release apt installs, so the log names the version.
  pin="$(apt-cache policy docker-ce | awk '/Candidate:/ {print $2}')"
  ce=(docker-ce docker-ce-cli docker-ce-rootless-extras)
else
  pin="$(apt-cache madison docker-ce | awk -v v="$VERSION" '$3 ~ v {print $3; exit}')"
  [ -n "$pin" ] || { echo "docker-in-docker: Docker CE version '$VERSION' not found in apt" >&2; exit 1; }
  # Pin the companion packages to the same release, which they require.
  ce=("docker-ce=$pin" "docker-ce-cli=$pin" "docker-ce-rootless-extras=$pin")
fi
echo "docker-in-docker: installing $pin ($VERSION)"

# Install the engine with its official plugins, plus the helpers a daemon run by the dev
# user relies on.
apt-get install -y --no-install-recommends "${ce[@]}" \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
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

# Point login shells at the published socket.
echo 'export DOCKER_HOST=unix:///run/docker-rootless.sock' > /etc/profile.d/docker-in-docker.sh
chmod 0644 /etc/profile.d/docker-in-docker.sh

# Confirm the CLI runs from the PATH.
docker --version
