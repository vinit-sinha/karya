#!/usr/bin/env bash
# Runs after creating any learning/mit/* project.
# No args, no env vars — derives context from filesystem markers.
set -euo pipefail

CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"

# Walk up to workspace root
dir="$PWD"
while [[ ! -f "$dir/.karya-workspace" && "$dir" != "/" ]]; do
    dir="$(dirname "$dir")"
done
WORKSPACE_ROOT="$dir"

echo "[mit] post-create: workspace root = $WORKSPACE_ROOT"
echo "[mit] post-create: project root   = $PWD"
# Collection-level hook — add shared MIT setup steps here if needed.
