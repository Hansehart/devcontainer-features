#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser the CLI may remap at build time. The state dir sits in
# that user's home, the one place the remap chowns, so it stays theirs without a group.
check "state dir pre-created" test -d /home/ubuntu/tea
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/tea/.probe && rm /home/ubuntu/tea/.probe'

# install.sh makes the link at build and the hook re-asserts it; this harness runs
# postCreateCommand, so both are in play here. Test -L on the path itself, which catches a
# link nested as tea/tea (what ln -sfn does over a real dir).
check "config dir is a link to the state dir" \
  bash -c '[ -L "$HOME/.config/tea" ] && [ "$(readlink "$HOME/.config/tea")" = /home/ubuntu/tea ]'

# Run the hook here, as a create does.
/usr/local/share/tea/init.sh

# tea resolves its config from XDG, so the hook links its config dir at the state dir.
check "config dir linked at the state dir" \
  bash -c '[ -L "$HOME/.config/tea" ] && [ "$(readlink -f "$HOME/.config/tea")" = /home/ubuntu/tea ]'
check "config writes land in the state dir" \
  bash -c 'touch "$HOME/.config/tea/config.yml" && test -f /home/ubuntu/tea/config.yml'

# The hook reruns on every create, so relinking an already linked config dir has to keep working.
/usr/local/share/tea/init.sh
check "link survives a rerun of the hook" \
  bash -c '[ "$(readlink -f "$HOME/.config/tea")" = /home/ubuntu/tea ] && test -f "$HOME/.config/tea/config.yml"'

# Leave a link the user pointed somewhere themselves where they put it.
mkdir -p "$HOME/own-tea"
ln -sfn "$HOME/own-tea" "$HOME/.config/tea"
/usr/local/share/tea/init.sh
check "a link of the user's own is left in place" \
  bash -c '[ "$(readlink "$HOME/.config/tea")" = "$HOME/own-tea" ]'
check "the hook says why it left it" \
  bash -c '/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep -q "already links to"'

# A relative target resolves against the link's own directory.
ln -sfn ../own-tea "$HOME/.config/tea"
/usr/local/share/tea/init.sh
check "a relative link of the user's own is left in place" \
  bash -c '[ "$(readlink "$HOME/.config/tea")" = ../own-tea ]'

# A broken link is the hook's to claim.
ln -sfn /nowhere/tea "$HOME/.config/tea"
/usr/local/share/tea/init.sh
check "a broken link is pointed back at the state dir" \
  bash -c '[ "$(readlink "$HOME/.config/tea")" = /home/ubuntu/tea ]'

# The binary still resolves now that its config lives on the volume.
check "tea runs against the state dir" bash -lc "tea --version"

# The scenario mounts no volume, so the hook reports where the state dir really is.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# The state dir standing as tea's own config dir leaves nothing to link. Moving
# XDG_CONFIG_HOME onto its parent is what makes the two paths meet, and an empty state dir
# is what reaches the branch that would otherwise replace it with a link to itself.
find /home/ubuntu/tea -mindepth 1 -delete
check "a state dir that is already the config dir is left alone" \
  bash -c 'XDG_CONFIG_HOME="$HOME" /usr/local/share/tea/init.sh \
           && [ -d /home/ubuntu/tea ] && [ ! -L /home/ubuntu/tea ]'

# tea reads the older path until the config dir holds a config, so the hook names it.
rm -f "$HOME/.config/tea/config.yml"
mkdir -p "$HOME/.tea" && touch "$HOME/.tea/tea.yml"
check "the hook reports the legacy config path" \
  bash -c '/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep -q "is the config tea will read"'

# A config in the config dir is what tea reads, so the older path goes unmentioned.
touch "$HOME/.config/tea/config.yml"
check "the hook stays quiet once the config dir holds a config" \
  bash -c '[ -z "$(/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep "is the config tea will read")" ]'
rm -rf "$HOME/.tea"

# Report result
reportResults
