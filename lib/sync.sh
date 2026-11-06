#!/usr/bin/env bash
# Keep each feature's copy of the shared scripts identical to its source, by syncing them or by
# reporting the copies that drift.
set -euo pipefail

cd "$(dirname "$0")/.."
mode="${1:-}"
status=0

# Pair each shared script with the features that carry it.
pairs=()
for feature in src/*/; do
  feature="${feature%/}"
  # The library goes to every feature whose install script sources it.
  if grep -q '/lib.sh"' "$feature/install.sh"; then pairs+=("lib/lib.sh $feature/lib.sh"); fi
  # The state-dir guard goes to every feature that ships one.
  if [ -f "$feature/state-dir.sh" ]; then pairs+=("lib/state-dir.sh $feature/state-dir.sh"); fi
done

for pair in "${pairs[@]}"; do
  source="${pair% *}"
  copy="${pair#* }"
  if [ "$mode" = --check ]; then
    if ! cmp -s "$source" "$copy"; then
      echo "$copy differs from $source; run lib/sync.sh" >&2
      status=1
    fi
  else
    cp "$source" "$copy"
  fi
done

if [ "$mode" = --check ] && [ "$status" -eq 0 ]; then echo "${#pairs[@]} copies match their source"; fi
exit "$status"
