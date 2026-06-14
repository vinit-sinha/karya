#!/usr/bin/env bash
# Runs after creating kosh://learning/mit/6s081.
# No args, no env vars — derives context from filesystem markers.
set -euo pipefail

CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$PWD"

# Walk up to workspace root
dir="$PROJECT_ROOT"
while [[ ! -f "$dir/.karya-workspace" && "$dir" != "/" ]]; do
    dir="$(dirname "$dir")"
done
WORKSPACE_ROOT="$dir"

echo "[6s081] post-create: project root = $PROJECT_ROOT"

# ── 1. Toolchain check ──────────────────────────────────────────────────────
echo "[6s081] Checking RISC-V toolchain and QEMU..."
if ! command -v riscv64-unknown-elf-gcc &>/dev/null; then
    echo "[6s081] WARNING: riscv64-unknown-elf-gcc not found."
    echo "        Install via Homebrew: brew install riscv-gnu-toolchain"
    echo "        Then re-run this hook: bash $0"
fi
if ! command -v qemu-system-riscv64 &>/dev/null; then
    echo "[6s081] WARNING: qemu-system-riscv64 not found."
    echo "        Install via Homebrew: brew install qemu"
    echo "        Then re-run this hook: bash $0"
fi

# ── 2. Clone xv6 lab repo ───────────────────────────────────────────────────
STARTER="$PROJECT_ROOT/starter-code/xv6-labs-2021"
if [[ ! -d "$STARTER/.git" ]]; then
    echo "[6s081] Cloning xv6-labs-2021..."
    git clone git://g.csail.mit.edu/xv6-labs-2021 "$STARTER" || {
        echo "[6s081] ERROR: clone failed. Check network / MIT VPN access."
        exit 1
    }
else
    echo "[6s081] xv6-labs-2021 already cloned, skipping."
fi

# ── 3. Mirror to personal GitHub ────────────────────────────────────────────
REPO_NAME="mit-6s081"
if gh repo view "$REPO_NAME" &>/dev/null 2>&1; then
    echo "[6s081] GitHub repo $REPO_NAME already exists, skipping creation."
else
    echo "[6s081] Creating private GitHub mirror: $REPO_NAME..."
    gh repo create "$REPO_NAME" --private --description "MIT 6.S081 OS Engineering — personal lab repo"
fi

PERSONAL_REMOTE="https://github.com/$(gh api user --jq '.login')/$REPO_NAME.git"
cd "$STARTER"

if ! git remote get-url personal &>/dev/null; then
    git remote add personal "$PERSONAL_REMOTE"
    echo "[6s081] Added remote 'personal' -> $PERSONAL_REMOTE"
fi

echo "[6s081] Pushing all lab branches to personal remote..."
git push personal --all || echo "[6s081] WARNING: push failed (may need auth or network)."

cd "$PROJECT_ROOT"
echo "[6s081] Setup complete."
echo ""
echo "  Next steps:"
echo "    cd starter-code/xv6-labs-2021"
echo "    git checkout util        # start lab 0"
echo "    make qemu                # boot xv6 (Ctrl-a x to exit)"
