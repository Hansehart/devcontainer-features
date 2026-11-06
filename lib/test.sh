#!/usr/bin/env bash
# Tests for lib.sh: each case writes a small feature into a sandbox and runs it the way the
# CLI runs install.sh, with releases, checksums and the release API served from local files.
set -uo pipefail

LIB="$(cd "$(dirname "$0")" && pwd)/lib.sh"
passed=0
failed=0

# Build a sandbox with a fake release, fake system tools and an empty install root.
sandbox() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/bin" "$SANDBOX/feature" "$SANDBOX/root" "$SANDBOX/release/v1.2.3" \
    "$SANDBOX/api/repos/acme/tool/releases" "$SANDBOX/pkg/tool-v1.2.3"
  # Package manager and machine name, recorded and faked.
  printf '#!/bin/sh\necho "$*" >> "%s/apt.log"\n' "$SANDBOX" > "$SANDBOX/bin/apt-get"
  printf '#!/bin/sh\necho "${FAKE_ARCH:-x86_64}"\n' > "$SANDBOX/bin/uname"
  chmod +x "$SANDBOX/bin/apt-get" "$SANDBOX/bin/uname"
  # A release tarball holding one tool, its checksum list and its per-file checksum.
  printf '#!/bin/sh\necho "tool 1.2.3"\n' > "$SANDBOX/pkg/tool-v1.2.3/tool"
  chmod +x "$SANDBOX/pkg/tool-v1.2.3/tool"
  tar -czf "$SANDBOX/release/v1.2.3/tool-v1.2.3-linux-amd64.tar.gz" -C "$SANDBOX/pkg" tool-v1.2.3
  ( cd "$SANDBOX/release/v1.2.3" && sha256sum tool-v1.2.3-linux-amd64.tar.gz > checksums.txt \
    && cp checksums.txt tool-v1.2.3-linux-amd64.tar.gz.sha256 )
  printf '{"tag_name": "v1.2.3"}\n' > "$SANDBOX/api/repos/acme/tool/releases/latest"
  cp "$LIB" "$SANDBOX/feature/lib.sh"
}

# Write the feature's install.sh: the library, the standard declarations, then the body.
feature() {
  {
    echo '#!/usr/bin/env bash'
    echo 'set -euo pipefail'
    echo '. "$(dirname "$0")/lib.sh"'
    echo 'FEATURE=tool'
    echo 'VERSION="$(option VERSION latest)"'
    cat
  } > "$SANDBOX/feature/install.sh"
}

# Run the feature like the CLI does, with the sandbox's tools and paths.
run() {
  env PATH="$SANDBOX/bin:$PATH" FEATURE_ROOT="$SANDBOX/root" RELEASE_API="file://$SANDBOX/api" \
    REL="file://$SANDBOX/release" "$@" bash "$SANDBOX/feature/install.sh" > "$SANDBOX/out" 2>&1
}

# Record one case: its name, and whether the check holds.
check() {
  local name="$1"; shift
  if "$@"; then passed=$((passed + 1)); echo "ok   $name"
  else failed=$((failed + 1)); echo "FAIL $name"; sed 's/^/     /' "$SANDBOX/out" 2>/dev/null; fi
}

has() { grep -qF -- "$1" "$SANDBOX/out"; }
installed() { [ -x "$SANDBOX/root/usr/local/bin/$1" ]; }

# The standard body: resolve from the release API, verify by list, install the tool.
standard() {
  cat <<'EOF'
resolve_version() {
  tag="$(release_tag github acme/tool "$VERSION")"
  url="$REL/$tag/tool-$tag-linux-$(arch_name x86_64=amd64 aarch64=arm64).tar.gz"
  checksums="$REL/$tag/checksums.txt"
}
install_program() { untar; install_bin "$tmp/tool"; }
EOF
}

# --- options and helpers ---------------------------------------------------------------

sandbox; feature <<<"$(standard); echo \"opt=\$(option COLOR blue) set=\$(option SHAPE round)\"; exit 0"
run SHAPE=square
check "option falls back to its default and reads a set value" has "opt=blue set=square"

sandbox; feature <<<"$(standard); echo \"a=\$(arch_name x86_64=amd64 aarch64=arm64)\"; exit 0"
run FAKE_ARCH=aarch64
check "arch_name maps the machine name" has "a=arm64"

sandbox; feature <<<"$(standard); arch_name x86_64=amd64"
run FAKE_ARCH=riscv64
check "arch_name stops on an unknown machine" has "tool: unsupported architecture 'riscv64'"

sandbox; feature <<<"$(standard); echo \"l=\$(release_tag github acme/tool latest) e=\$(release_tag github acme/tool 2.0.0) v=\$(release_tag github acme/tool v2.0.0) b=\$(release_tag github acme/tool 2.0.0 --bare)\"; exit 0"
run
check "release_tag resolves latest and prefixes exact versions" has "l=v1.2.3 e=v2.0.0 v=v2.0.0 b=2.0.0"

sandbox; mkdir -p "$SANDBOX/api/api/v1/repos/acme/tool/releases"
printf '{"tag_name": "v9.9.9"}\n' > "$SANDBOX/api/api/v1/repos/acme/tool/releases/latest"
feature <<<"$(standard); echo \"g=\$(release_tag gitea.example acme/tool latest)\"; exit 0"
run
check "release_tag reads a Gitea host through its API path" has "g=v9.9.9"

# --- the sequence ----------------------------------------------------------------------

sandbox; feature <<<"$(standard)
PACKAGES=(ca-certificates curl)
feature_main"
run
check "feature_main installs the verified tool" installed tool
check "feature_main logs the resolved release" has "tool: installing v1.2.3 (latest)"
check "feature_main installs the declared packages" grep -qF "install -y --no-install-recommends ca-certificates curl" "$SANDBOX/apt.log"
check "feature_main confirms the tool runs" has "tool 1.2.3"

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#checksum="\$url.sha256"#')
feature_main"
run
check "a per-file checksum verifies the download" installed tool

sandbox; feature <<<"$(standard)
feature_main"
echo "0000000000000000000000000000000000000000000000000000000000000000  tool-v1.2.3-linux-amd64.tar.gz" \
  > "$SANDBOX/release/v1.2.3/checksums.txt"
run
check "a checksum mismatch stops the install" bash -c "! [ -e '$SANDBOX/root/usr/local/bin/tool' ]"

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#unverified="the vendor publishes none"#')
feature_main"
run
check "an unverified download states its reason" has "tool: skipping verification: the vendor publishes none"
check "an unverified download still installs" installed tool

sandbox; feature <<<"$(standard | sed '/checksums=/d')
feature_main"
run
check "a download without a verification declaration stops" has "tool: declare one of checksums, checksum or unverified"

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#checksums="\$REL/\$tag/checksums.txt"; unverified="both"#')
feature_main"
run
check "two verification declarations stop" has "tool: declare one of checksums, checksum or unverified"

sandbox; feature <<<"$(standard | sed '/^install_program/d')
feature_main"
run
check "a missing required function stops and names it" has "tool: missing install_program"

sandbox; feature <<<"$(standard)
log() { echo overridden; }
feature_main"
run
check "a feature can't override a library function" bash -c "! [ -e '$SANDBOX/root/usr/local/bin/tool' ] && grep -q 'readonly function' '$SANDBOX/out'"

# --- optional parts --------------------------------------------------------------------

sandbox; feature <<<"$(standard)
profile() { echo 'export TOOL_HOME=/x'; }
settings() { install -d \"\$FEATURE_ROOT/usr/local/etc/tool\"; echo set > \"\$FEATURE_ROOT/usr/local/etc/tool/config\"; }
post_install() { echo post-ran; }
confirm() { echo confirm-ran; }
feature_main"
run
check "profile writes the login profile" grep -qx "export TOOL_HOME=/x" "$SANDBOX/root/etc/profile.d/tool.sh"
check "settings runs" grep -qx set "$SANDBOX/root/usr/local/etc/tool/config"
check "post_install runs" has "post-ran"
check "confirm can be replaced" has "confirm-ran"

sandbox; feature <<<"$(standard)
profile() { :; }
feature_main"
run
check "an empty profile writes no file" bash -c "! [ -e '$SANDBOX/root/etc/profile.d/tool.sh' ]"

sandbox; printf '#!/bin/sh\necho "claimed $1 $2"\n' > "$SANDBOX/feature/state-dir.sh"
printf '#!/bin/sh\n' > "$SANDBOX/feature/init.sh"; chmod +x "$SANDBOX/feature/state-dir.sh" "$SANDBOX/feature/init.sh"
feature <<<"$(standard)
feature_main"
run STATEDIR=/home/u/tool
check "a set state dir is claimed first" has "claimed tool /home/u/tool"
check "the hooks land in libexec" bash -c "[ -x '$SANDBOX/root/usr/local/libexec/tool/init.sh' ] && [ -x '$SANDBOX/root/usr/local/libexec/tool/state-dir.sh' ]"

sandbox; feature <<<"$(standard)
feature_main"
run
check "a feature without hooks installs none" bash -c "! [ -e '$SANDBOX/root/usr/local/libexec/tool' ]"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
