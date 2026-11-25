#!/usr/bin/env bash
# Writes the package in the form the official Umbrel App Store expects, ready to copy into a fork of
# https://github.com/getumbrel/umbrel-apps for a pull request.
#
# The package in this repository is for a community app store, where every app's ID has to start with
# the store's ID, so it is called "hashforge-pool". In the official store it is plain "hashforge". The
# ID is part of the container names and variable names, so those change with it. The official store
# also hosts icons itself, so the icon line is dropped.
#
# Usage: tools/official-package.sh <output directory>
set -euo pipefail

output="${1:?usage: tools/official-package.sh <output directory>}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source="$repo/hashforge-pool"
target="$output/hashforge"

rm -rf "$target"
mkdir -p "$target"

for file in docker-compose.yml umbrel-app.yml exports.sh; do
    sed \
        -e 's/APP_HASHFORGE_POOL_/APP_HASHFORGE_/g' \
        -e 's/hashforge-pool/hashforge/g' \
        -e '/^icon:/d' \
        "$source/$file" > "$target/$file"
done

# The empty data folders have to exist in the package; umbrelOS removes the .gitkeep files on install.
(cd "$source" && find data -name .gitkeep) | while IFS= read -r keep; do
    mkdir -p "$target/$(dirname "$keep")"
    : > "$target/$keep"
done

echo "Wrote $target"
echo "Before opening the pull request, set 'submission:' in umbrel-app.yml to the pull request's address."
