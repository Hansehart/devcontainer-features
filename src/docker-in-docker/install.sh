#!/usr/bin/env bash
set -euo pipefail

# Options (uppercased by the CLI): VERSION, DAEMONJSON.
DAEMON_JSON="$DAEMONJSON"

export DEBIAN_FRONTEND=noninteractive

# Dependencies: packages this feature needs to install and run.
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  erofs-utils \
  iptables \
  pigz

# Dependencies: add Docker's official apt repository and signing key.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update

# Resolve: take the current CE packages, or pin them to an apt version matching VERSION.
if [ "$VERSION" = "latest" ]; then
  ce="docker-ce docker-ce-cli"
else
  pin="$(apt-cache madison docker-ce | awk -v v="$VERSION" '$3 ~ v {print $3; exit}')"
  [ -n "$pin" ] || { echo "docker-in-docker: Docker CE version '$VERSION' not found in apt" >&2; exit 1; }
  ce="docker-ce=$pin docker-ce-cli=$pin"
fi

# Install: engine, CLI, containerd, and the buildx/compose plugins (Docker's official set).
# shellcheck disable=SC2086
apt-get install -y --no-install-recommends $ce containerd.io docker-buildx-plugin docker-compose-plugin

# Pin the engine so a later apt upgrade keeps it in sync with the persisted data volume.
apt-mark hold docker-ce docker-ce-cli containerd.io

rm -rf /var/lib/apt/lists/*

# Configure: add the non-root remote user to the docker group so it can run docker directly.
groupadd -f docker
if [ -n "$_REMOTE_USER" ] && [ "$_REMOTE_USER" != "root" ]; then
  usermod -aG docker "$_REMOTE_USER" || true
fi

# Configure: write the requested daemon settings to daemon.json (empty leaves the file untouched).
if [ -n "$DAEMON_JSON" ]; then
  mkdir -p /etc/docker
  printf '%s\n' "$DAEMON_JSON" > /etc/docker/daemon.json
fi

# Hook: install the entrypoint that starts dockerd at container start, then execs the container command.
install -d /usr/local/share/docker-in-docker
install -m 0755 "$(dirname "$0")/docker-init.sh" /usr/local/share/docker-in-docker/docker-init.sh

# Verify: the CLI resolves on PATH.
docker --version
