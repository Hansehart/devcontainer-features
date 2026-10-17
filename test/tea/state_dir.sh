#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/tea
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/tea/.probe && rm /home/ubuntu/tea/.probe'

# The build and the hook both link the config dir, so check that the path itself is the link.
check "config dir is a link to the state dir" \
  bash -c '[ -L "$HOME/.config/tea" ] && [ "$(readlink "$HOME/.config/tea")" = /home/ubuntu/tea ]'

# Run the hook here, as a create does.
/usr/local/share/tea/init.sh

# The hook links the tool's config dir at the state dir.
check "config dir linked at the state dir" \
  bash -c '[ -L "$HOME/.config/tea" ] && [ "$(readlink -f "$HOME/.config/tea")" = /home/ubuntu/tea ]'
check "config writes land in the state dir" \
  bash -c 'touch "$HOME/.config/tea/config.yml" && test -f /home/ubuntu/tea/config.yml'

# Every create reruns the hook, which keeps an existing link working.
/usr/local/share/tea/init.sh
check "link survives a rerun of the hook" \
  bash -c '[ "$(readlink -f "$HOME/.config/tea")" = /home/ubuntu/tea ] && test -f "$HOME/.config/tea/config.yml"'

# Respect a link the user pointed elsewhere.
mkdir -p "$HOME/own-tea"
ln -sfn "$HOME/own-tea" "$HOME/.config/tea"
/usr/local/share/tea/init.sh
check "a link of the user's own is left in place" \
  bash -c '[ "$(readlink "$HOME/.config/tea")" = "$HOME/own-tea" ]'
check "the hook says why it left it" \
  bash -c '/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep -q "already links to"'

# A relative target counts from the link's own directory.
ln -sfn ../own-tea "$HOME/.config/tea"
/usr/local/share/tea/init.sh
check "a relative link of the user's own is left in place" \
  bash -c '[ "$(readlink "$HOME/.config/tea")" = ../own-tea ]'

# The hook repoints a link whose target is gone.
ln -sfn /nowhere/tea "$HOME/.config/tea"
/usr/local/share/tea/init.sh
check "a broken link is pointed back at the state dir" \
  bash -c '[ "$(readlink "$HOME/.config/tea")" = /home/ubuntu/tea ]'

# The binary keeps running with its config on the volume.
check "tea runs against the state dir" bash -lc "tea --version"

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A state dir that is the config dir itself stays as it is; pointing the config home at
# its parent sets that up.
find /home/ubuntu/tea -mindepth 1 -delete
check "a state dir that is already the config dir is left alone" \
  bash -c 'XDG_CONFIG_HOME="$HOME" /usr/local/share/tea/init.sh \
           && [ -d /home/ubuntu/tea ] && [ ! -L /home/ubuntu/tea ]'

# The hook points out a config file the tool reads ahead of the config dir.
rm -f "$HOME/.config/tea/config.yml"
mkdir -p "$HOME/.tea" && touch "$HOME/.tea/tea.yml"
check "the hook reports the legacy config path" \
  bash -c '/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep -q "is the config tea will read"'

# A config in the config dir takes precedence, so the hook stays quiet.
touch "$HOME/.config/tea/config.yml"
check "the hook stays quiet once the config dir holds a config" \
  bash -c '[ -z "$(/usr/local/share/tea/init.sh 2>&1 >/dev/null | grep "is the config tea will read")" ]'
rm -rf "$HOME/.tea"

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/tea/state-dir.sh tea /var/tea'
check "the refusal names the home" \
  bash -c '/usr/local/share/tea/state-dir.sh tea /var/tea 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
