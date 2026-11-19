#!/usr/bin/env bash
# Bump rakazo.nix to the latest GitHub release (version + hash).
# Usage: ./update-rakazo.sh [--rebuild]
set -euo pipefail

repo="elie222/rakazo"
file="$(dirname "$(readlink -f "$0")")/rakazo.nix"

current=$(rg -o 'version = "([^"]+)"' -r '$1' "$file")
latest=$(gh api "repos/$repo/releases/latest" --jq .tag_name)
latest="${latest#v}"

if [[ "$current" == "$latest" ]]; then
  echo "rakazo already at latest ($current)"
  exit 0
fi

echo "rakazo: $current -> $latest (downloading to compute hash...)"
url="https://github.com/$repo/releases/download/v$latest/Rakazo-$latest.AppImage"
hash=$(nix store prefetch-file --json "$url" | jaq -r .hash)

sd 'version = "[^"]+"' "version = \"$latest\"" "$file"
sd 'hash = "[^"]+"' "hash = \"$hash\"" "$file"
echo "updated $file (hash $hash)"

if [[ "${1:-}" == "--rebuild" ]]; then
  sudo nixos-rebuild switch -L
fi
