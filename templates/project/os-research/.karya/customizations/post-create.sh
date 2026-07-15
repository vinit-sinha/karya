#!/usr/bin/env bash
# Collection-level hook for project/os-research — runs on every
# `karya create project` (and `--continue`) for ANY project under this
# collection (xv6-c, xv6-cpp, xv6-c-cmake, xv6-rust, future ones too).
#
# karya invokes every post-create hook (root/domain/collection/project) with
# cwd = the *project* root, not this hook's own level — so first we walk up
# to find the actual collection root (.karya-collection), then sync
# collection-wide files there. This is what guarantees os-research/CLAUDE.md
# and docs/agentic-workflow.md exist regardless of *which* project under the
# collection happens to be the first one created on a given machine.
set -euo pipefail

CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"

echo "[os-research] post-create: project root = $PROJECT_ROOT"

dir="$PROJECT_ROOT"
while [[ ! -f "$dir/.karya-collection" && "$dir" != "/" ]]; do
    dir="$(dirname "$dir")"
done
COLLECTION_ROOT="$dir"

if [[ ! -f "$COLLECTION_ROOT/.karya-collection" ]]; then
    echo "[os-research] WARNING: no .karya-collection marker found walking up from $PROJECT_ROOT — skipping collection-level file sync"
    exit 0
fi

echo "[os-research] collection root = $COLLECTION_ROOT"

if [[ ! -d "$FILES_DIR" ]]; then
    exit 0
fi

# Sync every file under files/ into the collection root, preserving relative
# structure. Always overwrite — the template is the source of truth for
# these files, same rule as every project-level file (see CLAUDE.md's
# "Karya conventions"). Edit the template, not the materialized copy.
( cd "$FILES_DIR" && find . -type f ) | while read -r rel; do
    rel="${rel#./}"
    mkdir -p "$COLLECTION_ROOT/$(dirname "$rel")"
    cp "$FILES_DIR/$rel" "$COLLECTION_ROOT/$rel"
    echo "[os-research] synced $rel"
done
