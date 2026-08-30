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
  ce="docker-ce docker-ce-cli docker-ce-rootless-extras"
else
  pin="$(apt-cache madison docker-ce | awk -v v="$VERSION" '$3 ~ v {print $3; exit}')"
  [ -n "$pin" ] || { echo "docker-in-docker: Docker CE version '$VERSION' not found in apt" >&2; exit 1; }
  # The rootless extras depend on the exact engine version, so they carry the same pin.
  ce="docker-ce=$pin docker-ce-cli=$pin docker-ce-rootless-extras=$pin"
fi

# Install: engine, CLI, containerd and the buildx/compose plugins (Docker's official set),
# plus the userspace networking, id-mapping and capability helpers an unprivileged daemon needs.
# shellcheck disable=SC2086
apt-get install -y --no-install-recommends $ce \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  fuse-overlayfs \
  iproute2 \
  libcap2-bin \
  slirp4netns \
  uidmap

# Configure: pin the engine so a later apt upgrade keeps it in sync with the persisted data root.
apt-mark hold docker-ce docker-ce-cli docker-ce-rootless-extras containerd.io

rm -rf /var/lib/apt/lists/*

# Configure: keep the docker group tooling expects, though the user owns its socket outright.
groupadd -f docker
# A non-root remote user is the one the daemon runs as, so the grants below are its own.
if [ -n "$_REMOTE_USER" ] && [ "$_REMOTE_USER" != "root" ]; then
  usermod -aG docker "$_REMOTE_USER" || true

  # Grant the subordinate ids the daemon maps its containers into.
  for f in /etc/subuid /etc/subgid; do
    grep -q "^${_REMOTE_USER}:" "$f" || echo "${_REMOTE_USER}:100000:65536" >> "$f"
  done
fi

# Hook: install the entrypoint that starts dockerd at container start, then execs the container command.
install -d /usr/local/share/docker-in-docker
install -m 0755 "$(dirname "$0")/docker-init.sh" /usr/local/share/docker-in-docker/docker-init.sh

# Hook: persist which user runs the rootless daemon (the entrypoint has no _REMOTE_USER at runtime).
printf '%s\n' "${_REMOTE_USER:-root}" > /usr/local/share/docker-in-docker/rootless-user

# Hook: save the requested daemon settings for the entrypoint to install (empty writes nothing).
printf '%s' "$DAEMON_JSON" > /usr/local/share/docker-in-docker/requested-daemon.json

# Hook: carry the seccomp profile the daemon needs, where a consumer can take it from.
install -m 0644 "$(dirname "$0")/seccomp.json" /usr/local/share/docker-in-docker/seccomp.json

# Configure: point login shells that inherit no container environment at the published socket.
echo 'export DOCKER_HOST=unix:///run/docker-rootless.sock' > /etc/profile.d/docker-in-docker.sh
chmod 0644 /etc/profile.d/docker-in-docker.sh

# Verify: the CLI resolves on PATH.
docker --version
