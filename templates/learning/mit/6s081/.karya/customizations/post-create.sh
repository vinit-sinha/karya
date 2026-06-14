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

# ── 1. Toolchain + QEMU install ─────────────────────────────────────────────
echo "[6s081] Checking RISC-V toolchain and QEMU..."
if ! command -v brew &>/dev/null; then
    echo "[6s081] ERROR: Homebrew not found. Install it from https://brew.sh then re-run: bash $0"
    exit 1
fi
if ! command -v riscv64-unknown-elf-gcc &>/dev/null; then
    echo "[6s081] Installing riscv-gnu-toolchain via Homebrew (this may take a few minutes)..."
    brew install riscv-gnu-toolchain
fi
if ! command -v qemu-system-riscv64 &>/dev/null; then
    echo "[6s081] Installing qemu via Homebrew..."
    brew install qemu
fi
echo "[6s081] Toolchain OK."

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
# MIT's remote HEAD is unset; check out util explicitly so there's a ref to push.
git checkout util 2>/dev/null || true
git push personal --all || echo "[6s081] WARNING: push failed (may need auth or network)."

cd "$PROJECT_ROOT"

# ── 4. VS Code tasks ────────────────────────────────────────────────────────
VSCODE_DIR="$PROJECT_ROOT/.vscode"
TASKS_SRC="$CUSTOMIZATION_DIR/files/.vscode/tasks.json"
if [[ -f "$TASKS_SRC" ]]; then
    mkdir -p "$VSCODE_DIR"
    cp "$TASKS_SRC" "$VSCODE_DIR/tasks.json"
    echo "[6s081] Installed .vscode/tasks.json (xv6 + karya tasks)"
fi

# ── 5. Copy lab tracker ─────────────────────────────────────────────────────
cp "$CUSTOMIZATION_DIR/files/LABS.md" "$PROJECT_ROOT/LABS.md"
echo "[6s081] Installed LABS.md"

echo "[6s081] Setup complete."
echo ""
echo "  Next steps:"
echo "    cd starter-code/xv6-labs-2021"
echo "    git checkout util        # start lab 0"
echo "    make qemu                # boot xv6 (Ctrl-a x to exit)"
echo "    Open in VS Code and use Cmd+Shift+B to run 'make qemu'"
