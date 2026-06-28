#!/usr/bin/env bash
# post-create.sh for kosh://project/os-research/xv6-c++
#
# Goal: take upstream xv6-riscv, mirror it to a private GitHub repo,
# clone it as a submodule, install cross-compiler + QEMU, and set up
# VS Code so the project is immediately runnable.
#
# Idempotent — safe to re-run via:
#   karya create project --uri kosh://project/os-research/xv6-c++ --continue
set -euo pipefail

# ── Windows guard ─────────────────────────────────────────────────────────────
_OS="$(uname -s 2>/dev/null || echo unknown)"
if [[ "$_OS" == MINGW* || "$_OS" == MSYS* || "$_OS" == CYGWIN* ]]; then
    echo "This project requires Linux tools (QEMU, RISC-V/cross compiler)."
    echo "Use WSL2 on Windows — see README.md for instructions."
    exit 1
fi

CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"

# Walk up to workspace root
dir="$PROJECT_ROOT"
while [[ ! -f "$dir/.karya-workspace" && "$dir" != "/" ]]; do
    dir="$(dirname "$dir")"
done
WORKSPACE_ROOT="$dir"

echo "[xv6-c++] project root  = $PROJECT_ROOT"
echo "[xv6-c++] workspace     = $WORKSPACE_ROOT"

# ── helpers ───────────────────────────────────────────────────────────────────
read_marker_field() {
    python3 -c "
import json, sys
try:
    d = json.load(open('$PROJECT_ROOT/.karya-project'))
    print(d.get('$1', ''))
except Exception:
    print('')
" 2>/dev/null || echo ""
}

write_marker_field() {
    local key="$1" value="$2"
    python3 -c "
import json
path = '$PROJECT_ROOT/.karya-project'
try:
    d = json.load(open(path))
except Exception:
    d = {}
d['$key'] = '$value'
json.dump(d, open(path, 'w'), indent=2)
" 2>/dev/null || true
}

# ── Step 1: Toolchain + QEMU ──────────────────────────────────────────────────
echo ""
echo "[xv6-c++] ── Step 1/5: Toolchain + QEMU ─────────────────────────────────"

if ! command -v brew &>/dev/null; then
    echo "[xv6-c++] ERROR: Homebrew not found. Install from https://brew.sh then re-run with --continue"
    exit 1
fi

# RISC-V cross-compiler.
# We prefer riscv-gnu-toolchain (riscv64-unknown-elf-*) which gives us both gcc
# and g++ targeting the bare-metal RISC-V ELF ABI — exactly what xv6 needs.
if ! command -v riscv64-unknown-elf-gcc &>/dev/null; then
    echo "[xv6-c++] Installing RISC-V toolchain (gcc + g++) ..."
    brew tap riscv-software-src/riscv 2>/dev/null || true
    brew trust riscv-software-src/riscv 2>/dev/null || true
    brew install riscv-gnu-toolchain
else
    echo "[xv6-c++] RISC-V toolchain: $(command -v riscv64-unknown-elf-gcc)"
fi

# Verify g++ is available (same tap, same package — should always be present)
if ! command -v riscv64-unknown-elf-g++ &>/dev/null; then
    echo "[xv6-c++] WARNING: riscv64-unknown-elf-g++ not found — C++ compilation will fail."
    echo "          Try: brew reinstall riscv-gnu-toolchain"
else
    echo "[xv6-c++] RISC-V g++:  $(command -v riscv64-unknown-elf-g++)"
fi

if ! command -v qemu-system-riscv64 &>/dev/null; then
    echo "[xv6-c++] Installing QEMU ..."
    brew install qemu
else
    echo "[xv6-c++] QEMU: $(command -v qemu-system-riscv64)"
fi

# ── Step 2: GitHub repo + xv6-riscv mirror/clone ─────────────────────────────
echo ""
echo "[xv6-c++] ── Step 2/5: GitHub repo + xv6-riscv source ───────────────────"

KERNEL_DIR="$PROJECT_ROOT/kernel/xv6-riscv"
UPSTREAM_URL="https://github.com/mit-pdos/xv6-riscv.git"
GITHUB_REPO_URL="(not configured)"

if ! command -v gh &>/dev/null; then
    echo "[xv6-c++] WARNING: gh CLI not found — skipping GitHub setup."
    echo "          Install: brew install gh && gh auth login, then re-run with --continue"
elif [[ -z "$(gh api user --jq '.login' 2>/dev/null)" ]]; then
    echo "[xv6-c++] WARNING: not authenticated with gh. Run: gh auth login, then re-run."
else
    GITHUB_USER=$(gh api user --jq '.login')
    gh auth setup-git 2>/dev/null || true

    # Karya convention: kosh://project/os-research/xv6-c++ → project-os-research-xv6-c++
    GITHUB_REPO="$GITHUB_USER/project-os-research-xv6-c++"
    # GitHub doesn't allow '+' in repo names — replace with 'p' (C++ → cpp)
    GITHUB_REPO="$GITHUB_USER/project-os-research-xv6-cpp"
    GITHUB_REPO_URL="https://github.com/$GITHUB_REPO.git"

    STORED_MIRROR=$(read_marker_field "github_mirror")

    if [[ -n "$STORED_MIRROR" ]]; then
        echo "[xv6-c++] Using stored GitHub repo: $STORED_MIRROR"
        GITHUB_REPO_URL="$STORED_MIRROR"
    else
        if gh repo view "$GITHUB_REPO" &>/dev/null 2>&1; then
            echo "[xv6-c++] Found existing GitHub repo: https://github.com/$GITHUB_REPO"
        else
            echo "[xv6-c++] Creating private GitHub repo: https://github.com/$GITHUB_REPO ..."
            gh repo create "$GITHUB_REPO" --private \
                --description "xv6-riscv modernisation to C++26" || {
                echo "[xv6-c++] ERROR: failed to create GitHub repo. Re-run with --continue."
                exit 1
            }
            echo "[xv6-c++] Mirroring mit-pdos/xv6-riscv → $GITHUB_REPO ..."
            MIRROR_TMP=$(mktemp -d)
            git clone --mirror "$UPSTREAM_URL" "$MIRROR_TMP/xv6.git" || {
                echo "[xv6-c++] ERROR: mirror clone from upstream failed."
                rm -rf "$MIRROR_TMP"; exit 1
            }
            git -C "$MIRROR_TMP/xv6.git" push --mirror "$GITHUB_REPO_URL" || {
                echo "[xv6-c++] ERROR: mirror push to GitHub failed."
                rm -rf "$MIRROR_TMP"; exit 1
            }
            rm -rf "$MIRROR_TMP"
            echo "[xv6-c++] Mirror complete."
        fi
        write_marker_field "github_mirror" "$GITHUB_REPO_URL"
    fi

    # Clone into kernel/xv6-riscv (or verify existing)
    if [[ ! -d "$KERNEL_DIR/.git" ]]; then
        mkdir -p "$(dirname "$KERNEL_DIR")"
        echo "[xv6-c++] Cloning xv6-riscv from your GitHub ..."
        git clone "$GITHUB_REPO_URL" "$KERNEL_DIR" || {
            echo "[xv6-c++] ERROR: clone failed. Re-run with --continue."
            exit 1
        }
    else
        echo "[xv6-c++] kernel/xv6-riscv already present."
        CURRENT_ORIGIN=$(git -C "$KERNEL_DIR" remote get-url origin 2>/dev/null || echo "")
        if [[ "$CURRENT_ORIGIN" != "$GITHUB_REPO_URL" ]]; then
            git -C "$KERNEL_DIR" remote set-url origin "$GITHUB_REPO_URL" 2>/dev/null || \
            git -C "$KERNEL_DIR" remote add origin "$GITHUB_REPO_URL"
            echo "[xv6-c++] Updated origin → $GITHUB_REPO_URL"
        fi
    fi

    # Add upstream as fetch-only remote
    cd "$KERNEL_DIR"
    if ! git remote get-url upstream &>/dev/null; then
        git remote add upstream "$UPSTREAM_URL"
        git remote set-url --push upstream no_push
        echo "[xv6-c++] Added upstream (fetch-only, push blocked)"
    fi

    # Create stage0 branch — all work starts here
    if ! git show-ref --quiet refs/heads/stage0/c-toolchain; then
        git checkout -b stage0/c-toolchain
        echo "[xv6-c++] Created branch stage0/c-toolchain"
    else
        git checkout stage0/c-toolchain
    fi
    cd "$PROJECT_ROOT"
fi

# ── Step 3: VS Code config ────────────────────────────────────────────────────
echo ""
echo "[xv6-c++] ── Step 3/5: VS Code config ───────────────────────────────────"
mkdir -p "$PROJECT_ROOT/.vscode"

for f in tasks.json settings.json extensions.json; do
    if [[ -f "$FILES_DIR/.vscode/$f" ]]; then
        cp "$FILES_DIR/.vscode/$f" "$PROJECT_ROOT/.vscode/$f"
        echo "[xv6-c++] Installed .vscode/$f"
    fi
done

# ── Step 4: Project files ─────────────────────────────────────────────────────
echo ""
echo "[xv6-c++] ── Step 4/5: Project files ────────────────────────────────────"

for f in README.md CLAUDE.md STAGES.md; do
    if [[ -f "$FILES_DIR/$f" ]]; then
        cp "$FILES_DIR/$f" "$PROJECT_ROOT/$f"
        echo "[xv6-c++] Installed $f"
    fi
done

mkdir -p "$PROJECT_ROOT/scripts"
for script in build.sh run.sh debug.sh; do
    if [[ -f "$FILES_DIR/scripts/$script" ]]; then
        cp "$FILES_DIR/scripts/$script" "$PROJECT_ROOT/scripts/$script"
        chmod +x "$PROJECT_ROOT/scripts/$script"
        echo "[xv6-c++] Installed scripts/$script"
    fi
done

mkdir -p "$PROJECT_ROOT/docs/adr" "$PROJECT_ROOT/work"

# ── Step 5: Write SETUP.md ────────────────────────────────────────────────────
echo ""
echo "[xv6-c++] ── Step 5/5: SETUP.md ─────────────────────────────────────────"

TOOLCHAIN_OK="$(command -v riscv64-unknown-elf-gcc &>/dev/null && echo '✓' || echo '✗ missing')"
GPP_OK="$(command -v riscv64-unknown-elf-g++ &>/dev/null && echo '✓' || echo '✗ missing')"
QEMU_OK="$(command -v qemu-system-riscv64 &>/dev/null && echo '✓' || echo '✗ missing')"

cat > "$PROJECT_ROOT/SETUP.md" <<SETUP
# xv6-c++ — Setup Status

**Last updated:** $(date +%Y-%m-%d)
**URI:** kosh://project/os-research/xv6-c++

## Environment

| Component | Status |
|-----------|--------|
| riscv64-unknown-elf-gcc | $TOOLCHAIN_OK |
| riscv64-unknown-elf-g++ | $GPP_OK |
| qemu-system-riscv64     | $QEMU_OK |
| GitHub repo (origin)    | $GITHUB_REPO_URL |
| Upstream (fetch-only)   | $UPSTREAM_URL |

## Kernel source

\`kernel/xv6-riscv/\` — your private fork of mit-pdos/xv6-riscv.
Current branch: \`$(git -C "$KERNEL_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')\`

## Quick start

\`\`\`bash
cd kernel/xv6-riscv
make qemu          # boot in QEMU  (Ctrl-a x to exit)
make qemu-gdb      # boot with GDB stub
\`\`\`

Or use VS Code tasks (Cmd+Shift+P → Tasks: Run Task).

## Re-run setup

\`\`\`bash
karya create project --uri kosh://project/os-research/xv6-c++ --continue
\`\`\`
SETUP

echo "[xv6-c++] Wrote SETUP.md"
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  xv6-c++ setup complete!"
echo "  Next: read STAGES.md, then open VS Code:"
echo "    code $PROJECT_ROOT"
echo "══════════════════════════════════════════════════════════════════"
