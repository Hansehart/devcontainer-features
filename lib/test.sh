#!/usr/bin/env bash
# Tests for lib.sh: each case writes a small feature into a sandbox and runs it the way the
# CLI runs install.sh, with releases, checksums and the release API served from local files.
set -uo pipefail

LIB="$(cd "$(dirname "$0")" && pwd)/lib.sh"
passed=0
failed=0

# Remove every sandbox when the run ends.
SANDBOXES=()
trap 'rm -rf "${SANDBOXES[@]}"' EXIT

# Build a sandbox with a fake release, fake system tools and an empty install root.
sandbox() {
  SANDBOX="$(mktemp -d)"
  SANDBOXES+=("$SANDBOX")
  mkdir -p "$SANDBOX/bin" "$SANDBOX/feature" "$SANDBOX/root" "$SANDBOX/release/v1.2.3" \
    "$SANDBOX/api/repos/acme/tool/releases" "$SANDBOX/pkg/tool-v1.2.3"
  # Package manager and machine name, recorded and faked.
  printf '#!/bin/sh\necho "$*" >> "%s/apt.log"\n' "$SANDBOX" > "$SANDBOX/bin/apt-get"
  printf '#!/bin/sh\necho "${FAKE_ARCH:-x86_64}"\n' > "$SANDBOX/bin/uname"
  # Switching user, recorded and run as the current user.
  printf '#!/bin/sh\necho "as $2: $4" >> "%s/su.log"\nexec bash -c "$4"\n' "$SANDBOX" > "$SANDBOX/bin/su"
  chmod +x "$SANDBOX/bin/apt-get" "$SANDBOX/bin/uname" "$SANDBOX/bin/su"
  # A release tarball holding one tool, its checksum list and its per-file checksum.
  printf '#!/bin/sh\necho "tool 1.2.3"\n' > "$SANDBOX/pkg/tool-v1.2.3/tool"
  chmod +x "$SANDBOX/pkg/tool-v1.2.3/tool"
  echo notes > "$SANDBOX/pkg/tool-v1.2.3/README.md"
  tar -czf "$SANDBOX/release/v1.2.3/tool-v1.2.3-linux-amd64.tar.gz" -C "$SANDBOX/pkg" tool-v1.2.3
  ( cd "$SANDBOX/release/v1.2.3" && sha256sum tool-v1.2.3-linux-amd64.tar.gz > checksums.txt \
    && cp checksums.txt tool-v1.2.3-linux-amd64.tar.gz.sha256 \
    && sha512sum tool-v1.2.3-linux-amd64.tar.gz > tool-v1.2.3-linux-amd64.tar.gz.sha512 )
  # The same tool as a zip archive with its own top folder, as some vendors ship it.
  python3 -I -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], "w")
i = zipfile.ZipInfo("tool-linux64/tool"); i.external_attr = 0o755 << 16
z.writestr(i, open(sys.argv[2]).read()); z.close()' \
    "$SANDBOX/release/v1.2.3/tool-linux64.zip" "$SANDBOX/pkg/tool-v1.2.3/tool"
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
  env PATH="$SANDBOX/bin:$PATH" _FEATURE_TEST_ROOT="$SANDBOX/root" _FEATURE_TEST_API="file://$SANDBOX/api" \
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

sandbox; feature <<<"$(standard); echo \"l=\$(release_tag github acme/tool latest) e=\$(release_tag github acme/tool 2.0.0) v=\$(release_tag github acme/tool v2.0.0) b=\$(release_tag github acme/tool 2.0.0 --bare) w=\$(release_tag github acme/tool v2.0.0 --bare)\"; exit 0"
run
check "release_tag resolves latest, prefixes exact versions and keeps bare ones bare" has "l=v1.2.3 e=v2.0.0 v=v2.0.0 b=2.0.0 w=2.0.0"

sandbox; mkdir -p "$SANDBOX/api/api/v1/repos/acme/tool/releases"
printf '{"tag_name": "v9.9.9"}\n' > "$SANDBOX/api/api/v1/repos/acme/tool/releases/latest"
feature <<<"$(standard); echo \"g=\$(release_tag gitea.example acme/tool latest)\"; exit 0"
run
check "release_tag reads a Gitea host through its API path" has "g=v9.9.9"

sandbox; mkdir -p "$SANDBOX/elsewhere"; feature <<<"$(standard)
feature_main"
run FEATURE_ROOT="$SANDBOX/elsewhere" RELEASE_API="file:///nowhere"
check "the install root and release API come from the test settings alone" bash -c "[ -x '$SANDBOX/root/usr/local/bin/tool' ] && [ -z \"\$(ls -A '$SANDBOX/elsewhere')\" ]"

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
check "a checksum mismatch stops the install" bash -c "! [ -e '$SANDBOX/root/usr/local/bin/tool' ] && grep -qF 'tool: checksum mismatch for tool-v1.2.3-linux-amd64.tar.gz' '$SANDBOX/out'"

sandbox; feature <<<"$(standard)
feature_main"
sed -i 's/  / */' "$SANDBOX/release/v1.2.3/checksums.txt"
run
check "a checksum list in binary-mode notation verifies the download" installed tool

sandbox; feature <<<"$(standard)
feature_main"
sed -i 's/tool-v1.2.3-linux-amd64.tar.gz/tool-v1x2x3-linux-amd64xtarxgz/' "$SANDBOX/release/v1.2.3/checksums.txt"
run
check "a checksum list matches the asset name exactly" bash -c "! [ -e '$SANDBOX/root/usr/local/bin/tool' ] && grep -qF 'tool: no checksum for tool-v1.2.3-linux-amd64.tar.gz in the list' '$SANDBOX/out'"

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#checksum="\$url.sha256"#')
feature_main"
cut -d' ' -f1 "$SANDBOX/release/v1.2.3/checksums.txt" > "$SANDBOX/release/v1.2.3/tool-v1.2.3-linux-amd64.tar.gz.sha256"
run
check "a per-file checksum holding the hash alone verifies the download" installed tool

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#unverified="the vendor publishes none"#')
feature_main"
run
check "an unverified download states its reason" has "tool: trusting the download over HTTPS: the vendor publishes none"
check "an unverified download still installs" installed tool

sandbox; feature <<<"$(standard | sed '/checksums=/d')
feature_main"
run
check "a download without a verification declaration stops" has "tool: declare one of checksums, checksum, unverified or delegated"

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#checksums="\$REL/\$tag/checksums.txt"; unverified="both"#')
feature_main"
run
check "two verification declarations stop" has "tool: declare one of checksums, checksum, unverified or delegated"

sandbox; feature <<<"$(standard | sed '/^install_program/d')
feature_main"
run
check "a missing required function stops and names it" has "tool: missing install_program"

sandbox; feature <<<"$(standard)
log() { echo overridden; }
feature_main"
run
check "the library functions stay fixed for every feature" bash -c "! [ -e '$SANDBOX/root/usr/local/bin/tool' ] && grep -q 'readonly function' '$SANDBOX/out'"

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
check "a profile is written only from printed lines" bash -c "! [ -e '$SANDBOX/root/etc/profile.d/tool.sh' ]"

sandbox; printf '#!/bin/sh\necho "claimed $1 $2"\n' > "$SANDBOX/feature/state-dir.sh"
printf '#!/bin/sh\n' > "$SANDBOX/feature/init.sh"; chmod +x "$SANDBOX/feature/state-dir.sh" "$SANDBOX/feature/init.sh"
cp "$(dirname "$LIB")/hook.sh" "$SANDBOX/feature/hook.sh"
feature <<<"$(standard)
feature_main"
run STATEDIR=/home/u/tool
check "a set state dir is claimed first" has "claimed tool /home/u/tool"
check "the hooks land in libexec" bash -c "[ -x '$SANDBOX/root/usr/local/libexec/tool/init.sh' ] && [ -x '$SANDBOX/root/usr/local/libexec/tool/state-dir.sh' ]"
check "the shared hook lands beside them" bash -c "[ -f '$SANDBOX/root/usr/local/libexec/tool/hook.sh' ]"
check "the state dir is recorded for the hook" bash -c "[ \"\$(cat '$SANDBOX/root/usr/local/etc/tool/state-dir')\" = /home/u/tool ]"

sandbox; feature <<<"$(standard)
feature_main"
run STATEDIR=/home/u/tool
check "a state dir names the guard the feature needs" has "tool: a state dir needs state-dir.sh in the feature"

sandbox; feature <<<"$(standard)"
sed -i '/^VERSION=/d; s/release_tag github acme\/tool "\$VERSION"/release_tag github acme\/tool 1.2.3/' "$SANDBOX/feature/install.sh"
echo feature_main >> "$SANDBOX/feature/install.sh"
run
check "a feature without a version option installs" installed tool
check "a feature without a version option logs its release" has "tool: installing v1.2.3"

sandbox; feature <<<"$(standard)
feature_main"
run
check "hooks are installed only for features that ship them" bash -c "! [ -e '$SANDBOX/root/usr/local/libexec/tool' ]"

# --- program trees ---------------------------------------------------------------------

sandbox; feature <<<"$(standard | sed 's#^install_program.*#install_program() { unpack /opt/tool --exclude=README.md; link_bin /opt/tool; }#')
feature_main"
run
check "unpack places the release in its own tree" bash -c "[ -x '$SANDBOX/root/opt/tool/tool' ]"
check "unpack passes extra archive options through" bash -c "! [ -e '$SANDBOX/root/opt/tool/README.md' ]"
check "link_bin puts the tree's commands on the PATH" bash -c "[ -L '$SANDBOX/root/usr/local/bin/tool' ] && [ \"\$(readlink '$SANDBOX/root/usr/local/bin/tool')\" = '$SANDBOX/root/opt/tool/tool' ]"
check "a linked command runs" has "tool 1.2.3"

sandbox; feature <<<"$(standard | sed 's#url=.*#url="$REL/$tag/tool-linux64.zip"#; s#checksums=.*#unverified="zip fixture"#; s#^install_program.*#install_program() { unpack /opt/tool; link_bin /opt/tool tool; }#')
feature_main"
run
check "unpack opens a zip archive into the tree" bash -c "[ -x '$SANDBOX/root/opt/tool/tool' ]"
check "link_bin links the named command" bash -c "[ -L '$SANDBOX/root/usr/local/bin/tool' ]"

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#checksum="\$url.sha512"#')
feature_main"
run
check "a sha512 checksum verifies the download" installed tool

sandbox; feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#checksum="\$url.sha512"#')
feature_main"
printf '%0128d  tool-v1.2.3-linux-amd64.tar.gz\n' 0 > "$SANDBOX/release/v1.2.3/tool-v1.2.3-linux-amd64.tar.gz.sha512"
run
check "a sha512 mismatch stops the install" has "tool: checksum mismatch for tool-v1.2.3-linux-amd64.tar.gz"

sandbox; feature <<<"$(standard)
settings() { write_file /etc/opt/tool/config 'key=value'; write_file /usr/local/etc/tool/empty ''; }
feature_main"
run
check "write_file writes the content exactly" bash -c "[ \"\$(cat '$SANDBOX/root/etc/opt/tool/config')\" = 'key=value' ] && [ \"\$(stat -c %a '$SANDBOX/root/etc/opt/tool/config')\" = 644 ]"
check "write_file keeps empty content empty" bash -c "[ -f '$SANDBOX/root/usr/local/etc/tool/empty' ] && ! [ -s '$SANDBOX/root/usr/local/etc/tool/empty' ]"

# Build a zip in the release from name=content pairs, each entry executable.
zipped() {
  local zip="$1"; shift
  python3 -I -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], "w")
for pair in sys.argv[2:]:
    name, content = pair.split("=", 1)
    i = zipfile.ZipInfo(name); i.external_attr = 0o755 << 16
    z.writestr(i, content)
z.close()' "$SANDBOX/release/v1.2.3/$zip" "$@"
}

sandbox; zipped flat.zip "tool=#!/bin/sh
echo tool 1.2.3" "NOTICE=notes"
feature <<<"$(standard | sed 's#url=.*#url="$REL/$tag/flat.zip"#; s#checksums=.*#unverified="zip fixture"#; s#^install_program.*#install_program() { unpack /opt/tool; link_bin /opt/tool tool; }#')
feature_main"
run
check "unpack keeps a zip's root files as they are" bash -c "[ -x '$SANDBOX/root/opt/tool/tool' ] && [ -f '$SANDBOX/root/opt/tool/NOTICE' ]"

sandbox; zipped two.zip "a/tool=#!/bin/sh
echo tool 1.2.3" "b/extra=x"
feature <<<"$(standard | sed 's#url=.*#url="$REL/$tag/two.zip"#; s#checksums=.*#unverified="zip fixture"#; s#^install_program.*#install_program() { unpack /opt/tool; link_bin /opt/tool/a tool; }#')
feature_main"
run
check "unpack keeps a zip's several top folders apart" bash -c "[ -x '$SANDBOX/root/opt/tool/a/tool' ] && [ -f '$SANDBOX/root/opt/tool/b/extra' ]"

sandbox; feature <<<"$(standard | sed 's#url=.*#url="$REL/$tag/tool-linux64.zip"#; s#checksums=.*#unverified="zip fixture"#; s#^install_program.*#install_program() { unpack /opt/tool --exclude=README.md; }#')
feature_main"
run
check "unpack names archive options a zip can't take" has "tool: archive options apply to tarballs"

sandbox; ( cd "$SANDBOX/release/v1.2.3" && sha512sum tool-v1.2.3-linux-amd64.tar.gz > checksums512.txt )
feature <<<"$(standard | sed 's#checksums="\$REL/\$tag/checksums.txt"#checksums="\$REL/\$tag/checksums512.txt"#')
feature_main"
run
check "a checksum list of sha512 digests verifies the download" installed tool

sandbox; feature <<<"$(standard | sed 's#^install_program.*#install_program() { untar; install -d "$FEATURE_ROOT/opt/empty"; link_bin /opt/empty; }#')
feature_main"
run
check "link_bin names an empty tree and links nothing from it" bash -c "grep -qF 'tool: no commands in /opt/empty' '$SANDBOX/out' && [ -z \"\$(ls -A '$SANDBOX/root/usr/local/bin' 2>/dev/null)\" ]"

sandbox; feature <<<"$(standard)
settings() { write_file /usr/local/etc/tool/blank; }
feature_main"
run
check "write_file without content writes an empty file" bash -c "[ -f '$SANDBOX/root/usr/local/etc/tool/blank' ] && ! [ -s '$SANDBOX/root/usr/local/etc/tool/blank' ]"

# --- vendor installers ------------------------------------------------------------------

# The body for a tool whose vendor installer fetches and checks it, run as the dev user.
delegating() {
  cat <<'EOF'
resolve_version() { tag="$VERSION"; delegated="the vendor installer checks its own download"; }
install_program() { as_user "echo installed by the vendor installer"; }
EOF
}

sandbox; feature <<<"$(delegating)
confirm() { :; }
feature_main"
run _REMOTE_USER=dev
check "a delegated download needs no release file" has "installed by the vendor installer"
check "a delegated download states its reason" has "tool: delegating the download: the vendor installer checks its own download"
check "as_user runs the command as the dev user" grep -qxF "as dev: echo installed by the vendor installer" "$SANDBOX/su.log"

sandbox; feature <<<"$(delegating | sed 's#delegated="the vendor installer checks its own download"#delegated="x"; checksums="y"#')
feature_main"
run
check "a delegated download with a second declaration stops" has "tool: declare one of checksums, checksum, unverified or delegated"

sandbox; feature <<<"$(delegating)
confirm() { :; }
feature_main"
run
check "a version that names itself is logged once" bash -c "grep -qx 'tool: installing latest' '$SANDBOX/out'"

sandbox; feature <<<"$(delegating)
confirm() { :; }
settings() { record requested.json '{\"a\": 1}'; record empty ''; }
feature_main"
run
check "record keeps a setting for the feature's hooks" bash -c "[ \"\$(cat '$SANDBOX/root/usr/local/etc/tool/requested.json')\" = '{\"a\": 1}' ] && [ -f '$SANDBOX/root/usr/local/etc/tool/empty' ] && ! [ -s '$SANDBOX/root/usr/local/etc/tool/empty' ]"

# --- review follow-ups -------------------------------------------------------------------

sandbox; feature <<<"$(standard); echo \"lb=\$(release_tag github acme/tool latest --bare)\"; exit 0"
run
check "a bare tag drops the v for latest as well" has "lb=1.2.3"

sandbox; zipped hidden.zip ".hidden=x" "top/tool=#!/bin/sh
echo tool 1.2.3"
feature <<<"$(standard | sed 's#url=.*#url="$REL/$tag/hidden.zip"#; s#checksums=.*#unverified="zip fixture"#; s#^install_program.*#install_program() { unpack /opt/tool; }#')
confirm() { :; }
feature_main"
run
check "unpack keeps a zip's hidden root files beside its folder" bash -c "[ -f '$SANDBOX/root/opt/tool/.hidden' ] && [ -x '$SANDBOX/root/opt/tool/top/tool' ]"

sandbox; zipped two.zip "a/tool=#!/bin/sh
echo tool 1.2.3" "b/extra=x"
feature <<<"$(standard | sed 's#url=.*#url="$REL/$tag/two.zip"#; s#checksums=.*#unverified="zip fixture"#; s#^install_program.*#install_program() { unpack /opt/tool; unpack /opt/tool; link_bin /opt/tool/a tool; }#')
feature_main"
run
check "unpack replaces a tree from an earlier zip" bash -c "[ -x '$SANDBOX/root/opt/tool/a/tool' ] && grep -q 'tool 1.2.3' '$SANDBOX/out'"

sandbox; feature <<<"$(standard)
feature_main"
sed -i 's/tool-v1.2.3-linux-amd64.tar.gz/tool-renamed.tar.gz/' "$SANDBOX/release/v1.2.3/checksums.txt"
run
check "a checksum list without the asset names what it lacks" has "tool: no checksum for tool-v1.2.3-linux-amd64.tar.gz in the list"

sandbox; repo="$SANDBOX/repo"; mkdir -p "$repo/lib" "$repo/src/plain"
cp "$(dirname "$LIB")/sync.sh" "$LIB" "$(dirname "$LIB")/state-dir.sh" "$repo/lib/"
printf '#!/bin/sh\necho plain\n' > "$repo/src/plain/install.sh"; cp "$LIB" "$repo/src/plain/lib.sh"
bash "$repo/lib/sync.sh" --check > "$SANDBOX/out" 2>&1
check "the sync check reports a library copy its feature no longer sources" has "src/plain/lib.sh is a library copy its feature doesn't source"

# --- version format and delegated unpacks ------------------------------------------------

sandbox; feature <<<"$(delegating)
confirm() { :; }
feature_main"
sed -i 's/^resolve_version() { tag=/resolve_version() { require_version "^(latest|[0-9]+\\\\.[0-9]+\\\\.[0-9]+)\\$"; tag=/' "$SANDBOX/feature/install.sh"
run VERSION="latest'; touch $SANDBOX/pwned; echo '"
check "a version outside the format stops before any command runs" bash -c "grep -qF \"tool: unsupported version 'latest'\" '$SANDBOX/out' && ! [ -e '$SANDBOX/pwned' ] && ! [ -e '$SANDBOX/su.log' ]"

sandbox; feature <<<"$(delegating)
confirm() { :; }
feature_main"
sed -i 's/^resolve_version() { tag=/resolve_version() { require_version "^(latest|[0-9]+\\\\.[0-9]+\\\\.[0-9]+)\\$"; tag=/' "$SANDBOX/feature/install.sh"
run VERSION=2.1.0
check "a version in the format installs" has "tool: installing 2.1.0"

sandbox; feature <<<"$(delegating | sed 's#^install_program.*#install_program() { as_user "echo plugin $PLUGIN"; }#')
confirm() { :; }
feature_main"
sed -i 's/^resolve_version() { tag=/resolve_version() { require_version "^(latest|[0-9]+)\\$" "$PLUGIN" plugin; tag=/' "$SANDBOX/feature/install.sh"
run VERSION=2.1.0 PLUGIN="1; touch $SANDBOX/pwned"
check "a further version outside the format stops before any command runs" bash -c "! [ -e '$SANDBOX/pwned' ] && ! [ -e '$SANDBOX/su.log' ]"
check "a rejected further version names its option" has "tool: unsupported plugin '1; touch"

sandbox; feature <<<"$(delegating | sed 's#^install_program.*#install_program() { unpack /opt/tool; }#')
feature_main"
run
check "unpacking after a delegated download names what's missing" has "tool: nothing was downloaded to unpack"

# --- the shared hook --------------------------------------------------------------------

# Write the feature's hook: the shared hook, the feature's own part, then init_main.
hook() {
  cp "$(dirname "$LIB")/hook.sh" "$SANDBOX/feature/hook.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'set -euo pipefail'
    echo '. "$(dirname "$0")/hook.sh"'
    cat
    echo 'init_main tool "$@"'
  } > "$SANDBOX/feature/init.sh"
  mkdir -p "$SANDBOX/root/usr/local/etc/tool" "$SANDBOX/root/etc/profile.d" "$SANDBOX/home"
}

# Run the hook the way a container create does.
run_hook() {
  env _FEATURE_TEST_ROOT="$SANDBOX/root" HOME="$SANDBOX/home" bash "$SANDBOX/feature/init.sh" "$@" > "$SANDBOX/out" 2>&1
}

sandbox; hook <<<''; printf '%s' "$SANDBOX/state" > "$SANDBOX/root/usr/local/etc/tool/state-dir"
run_hook
check "the hook creates the recorded state dir, private to the dev user" bash -c "[ \"\$(stat -c %a '$SANDBOX/state')\" = 700 ]"
check "the hook warns about a state dir on the container filesystem" has "tool: $SANDBOX/state is on the container filesystem; mount a volume there to keep it across rebuilds"

sandbox; hook <<<''; printf '%s' "$SANDBOX/state" > "$SANDBOX/root/usr/local/etc/tool/state-dir"
run_hook --build
check "the hook stays quiet about the volume at build" bash -c "[ -d '$SANDBOX/state' ] && ! grep -q 'container filesystem' '$SANDBOX/out'"

sandbox; hook <<<'init_state() { echo "state=$STATE_DIR color=$TOOL_COLOR args=$*"; }'
printf '%s' "$SANDBOX/state" > "$SANDBOX/root/usr/local/etc/tool/state-dir"
echo 'export TOOL_COLOR=blue' > "$SANDBOX/root/etc/profile.d/tool.sh"
run_hook --build
check "init_state sees the state dir, the profile and the arguments" has "state=$SANDBOX/state color=blue args=--build"

sandbox; hook <<<'init_state() { echo "state=[$STATE_DIR]"; }'
run_hook
check "a hook without a recorded state dir still runs its own part" bash -c "grep -qx 'state=\[\]' '$SANDBOX/out' && ! grep -q 'container filesystem' '$SANDBOX/out'"

sandbox; hook <<<'init_state() { apply_config requested.toml "$HOME/conf/config.toml"; }'
printf '%s' 'a = 1\nb = 2' > "$SANDBOX/root/usr/local/etc/tool/requested.toml"
run_hook
check "apply_config writes the request with its escaped line breaks expanded" bash -c "[ \"\$(wc -l < '$SANDBOX/home/conf/config.toml')\" -eq 2 ]"

sandbox; hook <<<'init_state() { apply_config requested.json "$HOME/settings.json" "%s"; }'
printf '%s' '{"a":"x\\ny"}' > "$SANDBOX/root/usr/local/etc/tool/requested.json"
run_hook
check "apply_config can keep the request verbatim" bash -c "grep -qF '{\"a\":\"x\\\\ny\"}' '$SANDBOX/home/settings.json'"

sandbox; hook <<<'init_state() { apply_config requested.toml "$HOME/conf/config.toml"; }'
: > "$SANDBOX/root/usr/local/etc/tool/requested.toml"
run_hook
check "apply_config leaves the target alone for an empty request" bash -c "! [ -e '$SANDBOX/home/conf/config.toml' ]"

sandbox; repo="$SANDBOX/repo"; mkdir -p "$repo/lib" "$repo/src/plain"
cp "$(dirname "$LIB")/sync.sh" "$LIB" "$(dirname "$LIB")/state-dir.sh" "$(dirname "$LIB")/hook.sh" "$repo/lib/"
printf '#!/bin/sh\necho plain\n' > "$repo/src/plain/install.sh"; printf '#!/bin/sh\n' > "$repo/src/plain/init.sh"
cp "$(dirname "$LIB")/hook.sh" "$repo/src/plain/hook.sh"
bash "$repo/lib/sync.sh" --check > "$SANDBOX/out" 2>&1
check "the sync check reports a hook copy its feature's hook no longer sources" has "src/plain/hook.sh is a hook copy its feature's hook doesn't source"

sandbox; cp "$(dirname "$LIB")/hook.sh" "$SANDBOX/feature/hook.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\n. "$(dirname "$0")/hook.sh"\napply_config requested.toml "$HOME/x"\n' > "$SANDBOX/feature/init.sh"
env HOME="$SANDBOX" bash "$SANDBOX/feature/init.sh" > "$SANDBOX/out" 2>&1
check "apply_config outside init_main names where it belongs" has "apply_config runs inside init_main"

# --- the state-dir guard ----------------------------------------------------------------

# Claim a nested state dir as the CLI does, with the user switch and ownership changes recorded.
claim() {
  printf '#!/bin/sh\necho "$*" >> "%s/chown.log"\n' "$SANDBOX" > "$SANDBOX/bin/chown"
  printf '#!/bin/sh\necho "$*" >> "%s/runuser.log"\nshift 3\nexec "$@"\n' "$SANDBOX" > "$SANDBOX/bin/runuser"
  chmod +x "$SANDBOX/bin/chown" "$SANDBOX/bin/runuser"
  mkdir -p "$SANDBOX/home"
  env PATH="$SANDBOX/bin:$PATH" _REMOTE_USER=dev _REMOTE_USER_HOME="$SANDBOX/home" \
    bash "$(dirname "$LIB")/state-dir.sh" tool "$SANDBOX/home/$1" > "$SANDBOX/out" 2>&1
}

sandbox; mkdir -p "$SANDBOX/home/.local"; claim .local/state/tool
check "the dev user creates a nested state dir and the folders above it" \
  grep -qx -- "-u dev -- mkdir -p $SANDBOX/home/.local/state/tool" "$SANDBOX/runuser.log"
check "the state dir is handed to the dev user" grep -qx "dev: $SANDBOX/home/.local/state/tool" "$SANDBOX/chown.log"
check "the folders above the state dir stay open to read" bash -c "[ \"\$(stat -c %a '$SANDBOX/home/.local/state')\" = 755 ]"
check "the state dir stays private" bash -c "[ \"\$(stat -c %a '$SANDBOX/home/.local/state/tool')\" = 700 ]"

# --- options checked first ----------------------------------------------------------------

sandbox; feature <<<"$(standard)
require_version '^(latest|[0-9]+\\.[0-9]+\\.[0-9]+)$'
feature_main"
run VERSION="1.2; id"
check "a version checked where it is read stops before any package is installed" \
  bash -c "grep -qF \"tool: unsupported version '1.2; id'\" '$SANDBOX/out' && ! [ -e '$SANDBOX/apt.log' ]"

sandbox; mkdir -p "$SANDBOX/home"
env _REMOTE_USER="$(id -un)" _REMOTE_USER_HOME="$SANDBOX/home" \
  bash "$(dirname "$LIB")/state-dir.sh" tool "$SANDBOX/home/\$(touch $SANDBOX/pwned)" > "$SANDBOX/out" 2>&1
check "a state dir with shell syntax is refused" \
  bash -c "grep -qF 'tool: stateDir may hold letters, digits and ._@+- alone' '$SANDBOX/out' && ! [ -e '$SANDBOX/home/\$(touch $SANDBOX/pwned)' ]"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
