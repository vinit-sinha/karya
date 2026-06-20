#!/usr/bin/env bash
# post-create.sh for kosh://learning/mit/6s081
# Idempotent — safe to re-run via:
#   karya create project --uri kosh://learning/mit/6s081            (first run)
#   karya create project --uri kosh://learning/mit/6s081 --continue  (resume)
set -euo pipefail

# ── Windows guard ─────────────────────────────────────────────────────────────
# Git Bash / MSYS2 on Windows: bash runs but brew/QEMU don't exist.
# WSL reports as Linux — that's fine, fall through.
# Native Windows (no bash): karya's run_hook() catches this before we ever get here.
_OS="$(uname -s 2>/dev/null || echo "unknown")"
if [[ "$_OS" == MINGW* || "$_OS" == MSYS* || "$_OS" == CYGWIN* ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  6.S081 requires Linux tools (QEMU, RISC-V toolchain, make).   ║"
    echo "║  On Windows, use WSL2 — MIT recommends this for the course.    ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Setup steps:"
    echo "  1. Install WSL2 + Ubuntu (run in PowerShell as admin):"
    echo "       wsl --install"
    echo "  2. Open an Ubuntu terminal, then install karya inside WSL:"
    echo "       git clone https://github.com/vinit-sinha/karya ~/tools/karya"
    echo "       echo 'export PATH=\"\$HOME/tools/karya/bin:\$PATH\"' >> ~/.bashrc"
    echo "       source ~/.bashrc"
    echo "  3. Initialise your workspace inside WSL and re-run:"
    echo "       mkdir -p ~/workspace/mit && cd ~/workspace/mit"
    echo "       karya init workspace"
    echo "       karya create project --uri kosh://learning/mit/6s081"
    echo ""
    echo "  Why WSL? QEMU and the RISC-V toolchain don't run natively on Windows."
    echo "  MIT's own instructions for Windows: https://pdos.csail.mit.edu/6.828/2021/tools.html"
    echo ""
    exit 1
fi

CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"
SETUP_MD="$PROJECT_ROOT/SETUP.md"

# Walk up to workspace root
dir="$PROJECT_ROOT"
while [[ ! -f "$dir/.karya-workspace" && "$dir" != "/" ]]; do
    dir="$(dirname "$dir")"
done
WORKSPACE_ROOT="$dir"

echo "[6s081] project root = $PROJECT_ROOT"

# ── Read project URI from .karya-project (used in SETUP.md) ──────────────────
URI=$(python3 -c "
import json, sys
try:
    d = json.load(open('$PROJECT_ROOT/.karya-project'))
    print(d.get('uri', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# ── 1. Toolchain + QEMU ──────────────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 1/6: Toolchain + QEMU ──────────────────────────────────"
if ! command -v brew &>/dev/null; then
    echo "[6s081] ERROR: Homebrew not found. Install from https://brew.sh then re-run:"
    echo "        karya create project --uri kosh://learning/mit/6s081 --continue"
    exit 1
fi
if ! command -v riscv64-unknown-elf-gcc &>/dev/null; then
    echo "[6s081] Installing RISC-V toolchain (this may take several minutes)..."
    brew tap riscv-software-src/riscv 2>/dev/null || true
    brew trust riscv-software-src/riscv 2>/dev/null || true
    brew install riscv-gnu-toolchain
else
    echo "[6s081] RISC-V toolchain already installed."
fi
if ! command -v qemu-system-riscv64 &>/dev/null; then
    echo "[6s081] Installing QEMU..."
    brew install qemu
else
    echo "[6s081] QEMU already installed."
fi
TOOLCHAIN_PATH=$(command -v riscv64-unknown-elf-gcc)
QEMU_PATH=$(command -v qemu-system-riscv64)
echo "[6s081] Toolchain: $TOOLCHAIN_PATH"
echo "[6s081] QEMU:      $QEMU_PATH"

# ── helpers ──────────────────────────────────────────────────────────────────

# Helper: read a field from .karya-project JSON
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

# Helper: write a field into .karya-project JSON
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

# ── 2. GitHub repo + xv6 clone ───────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 2/6: GitHub repo + xv6 clone ───────────────────────────"
# Remote layout:
#   origin       → https://github.com/<user>/xv6-labs-2021  (your repo, read/write)
#   mit-upstream → git://g.csail.mit.edu/xv6-labs-2021       (MIT, fetch-only)
#
# Your GitHub repo is the canonical origin. MIT's repo is upstream-only.
# push is blocked on mit-upstream via 'no_push' sentinel.

STARTER="$PROJECT_ROOT/starter-code/xv6-labs-2021"
STARTER_LEGACY="$PROJECT_ROOT/starter-code/xv6-riscv"
GITHUB_REPO_URL="(not configured)"

# Normalise legacy directory name
if [[ ! -d "$STARTER/.git" && -d "$STARTER_LEGACY/.git" ]]; then
    echo "[6s081] Renaming starter-code/xv6-riscv → starter-code/xv6-labs-2021 ..."
    mv "$STARTER_LEGACY" "$STARTER"
fi

if ! command -v gh &>/dev/null; then
    echo "[6s081] WARNING: gh CLI not found — skipping GitHub setup."
    echo "        Install: brew install gh && gh auth login, then re-run with --continue"
elif [[ -z "$(gh api user --jq '.login' 2>/dev/null)" ]]; then
    echo "[6s081] WARNING: not authenticated with gh. Run: gh auth login, then re-run with --continue"
else
    GITHUB_USER=$(gh api user --jq '.login')
    gh auth setup-git 2>/dev/null || true

    # ── Determine GitHub repo URL (stored → existing → create) ───────────────
    STORED_MIRROR=$(read_marker_field "github_mirror")

    if [[ -n "$STORED_MIRROR" ]]; then
        echo "[6s081] Using stored GitHub repo: $STORED_MIRROR"
        GITHUB_REPO_URL="$STORED_MIRROR"
    else
        # Derive repo name: kosh://learning/mit/6s081 → xv6-labs-2021 (use standard name)
        GITHUB_REPO="$GITHUB_USER/xv6-labs-2021"
        GITHUB_REPO_URL="https://github.com/$GITHUB_REPO.git"

        if gh repo view "$GITHUB_REPO" &>/dev/null 2>&1; then
            echo "[6s081] Found existing GitHub repo: https://github.com/$GITHUB_REPO"
        else
            echo "[6s081] Creating private GitHub repo: https://github.com/$GITHUB_REPO ..."
            gh repo create "$GITHUB_REPO" --private \
                --description "MIT 6.S081 OS Engineering — personal lab repo" || {
                echo "[6s081] ERROR: failed to create GitHub repo. Re-run with --continue after fixing."
                exit 1
            }
            echo "[6s081] Mirroring MIT xv6 → https://github.com/$GITHUB_REPO ..."
            MIRROR_TMP=$(mktemp -d)
            git clone --mirror git://g.csail.mit.edu/xv6-labs-2021 "$MIRROR_TMP/xv6.git" || {
                echo "[6s081] ERROR: mirror clone from MIT failed. Check network access to g.csail.mit.edu"
                rm -rf "$MIRROR_TMP"
                exit 1
            }
            git -C "$MIRROR_TMP/xv6.git" push --mirror "$GITHUB_REPO_URL" || {
                echo "[6s081] ERROR: mirror push to GitHub failed."
                rm -rf "$MIRROR_TMP"
                exit 1
            }
            rm -rf "$MIRROR_TMP"
            echo "[6s081] Mirror complete."
        fi
        write_marker_field "github_mirror" "$GITHUB_REPO_URL"
    fi

    # ── Clone from YOUR GitHub (or verify existing clone) ────────────────────
    if [[ ! -d "$STARTER/.git" ]]; then
        echo "[6s081] Cloning xv6-labs-2021 from your GitHub..."
        git clone "$GITHUB_REPO_URL" "$STARTER" || {
            echo "[6s081] ERROR: clone failed. Re-run with --continue when network is available."
            exit 1
        }
    else
        echo "[6s081] xv6-labs-2021 already present at $STARTER"
        # Ensure origin points to your GitHub (not MIT or legacy personal remote)
        CURRENT_ORIGIN=$(git -C "$STARTER" remote get-url origin 2>/dev/null || echo "")
        if [[ "$CURRENT_ORIGIN" != "$GITHUB_REPO_URL" ]]; then
            git -C "$STARTER" remote set-url origin "$GITHUB_REPO_URL" 2>/dev/null || \
            git -C "$STARTER" remote add origin "$GITHUB_REPO_URL"
            echo "[6s081] Updated origin → $GITHUB_REPO_URL"
        fi
        # Remove legacy 'personal' remote if present
        git -C "$STARTER" remote remove personal 2>/dev/null && \
            echo "[6s081] Removed legacy 'personal' remote (now origin)" || true
    fi

    # ── Add MIT as fetch-only upstream (push blocked) ─────────────────────────
    cd "$STARTER"
    MIT_URL="git://g.csail.mit.edu/xv6-labs-2021"
    if ! git remote get-url mit-upstream &>/dev/null; then
        git remote add mit-upstream "$MIT_URL"
        git remote set-url --push mit-upstream no_push
        echo "[6s081] Added mit-upstream (fetch-only, push blocked)"
    fi

    # ── Checkout util (lab 0) ─────────────────────────────────────────────────
    git checkout -b util --track origin/util 2>/dev/null || git checkout util
    echo "[6s081] xv6 on branch: util (lab 0 — start here)"
    cd "$PROJECT_ROOT"
fi

# ── 3. Patch Makefile for newer GCC ──────────────────────────────────────────
echo ""
echo "[6s081] ── Step 3/6: Patch Makefile ────────────────────────────────────"
# xv6-labs-2021 was written for GCC 10; newer toolchains treat sh.c tail-calls
# as infinite recursion errors (-Werror turns -Winfinite-recursion fatal).
MAKEFILE="$STARTER/Makefile"
if [[ -f "$MAKEFILE" ]] && ! grep -q "Wno-error=infinite-recursion" "$MAKEFILE"; then
    sed -i.bak 's/\(CFLAGS :=.*\)/\1\nCFLAGS += -Wno-error=infinite-recursion/' "$MAKEFILE"
    rm -f "$MAKEFILE.bak"
    echo "[6s081] Patched Makefile: added -Wno-error=infinite-recursion"
else
    echo "[6s081] Makefile already patched."
fi

# ── 4. Install VS Code tasks, scripts, and work docs ─────────────────────────
echo ""
echo "[6s081] ── Step 4/6: Install VS Code tasks + scripts ───────────────────"
mkdir -p "$PROJECT_ROOT/.vscode" "$PROJECT_ROOT/scripts"

if [[ -f "$FILES_DIR/.vscode/tasks.json" ]]; then
    cp "$FILES_DIR/.vscode/tasks.json" "$PROJECT_ROOT/.vscode/tasks.json"
    echo "[6s081] Installed .vscode/tasks.json"
fi
if [[ -f "$FILES_DIR/.vscode/settings.json" ]]; then
    cp "$FILES_DIR/.vscode/settings.json" "$PROJECT_ROOT/.vscode/settings.json"
    echo "[6s081] Installed .vscode/settings.json (opens README.md on launch)"
fi
if [[ -f "$FILES_DIR/.vscode/extensions.json" ]]; then
    cp "$FILES_DIR/.vscode/extensions.json" "$PROJECT_ROOT/.vscode/extensions.json"
    echo "[6s081] Installed .vscode/extensions.json (Live Preview recommendation)"
fi

# Install local courseware (tools, schedule, labs) — opened via "Open Courseware Home Page" task
if [[ -d "$FILES_DIR/docs" ]]; then
    cp -R "$FILES_DIR/docs" "$PROJECT_ROOT/docs"
    echo "[6s081] Installed docs/ (local courseware — open via VS Code task)"
fi

# Install project README and CLAUDE.md (human + AI instructions)
for f in README.md CLAUDE.md; do
    if [[ -f "$FILES_DIR/$f" ]]; then
        cp "$FILES_DIR/$f" "$PROJECT_ROOT/$f"
        echo "[6s081] Installed $f"
    fi
done

for script in lab-start.sh lab-done.sh; do
    if [[ -f "$FILES_DIR/scripts/$script" ]]; then
        cp "$FILES_DIR/scripts/$script" "$PROJECT_ROOT/scripts/$script"
        chmod +x "$PROJECT_ROOT/scripts/$script"
        echo "[6s081] Installed scripts/$script"
    fi
done

cp "$FILES_DIR/LABS.md" "$PROJECT_ROOT/LABS.md"
if [[ -f "$FILES_DIR/work/README.md" ]]; then
    cp "$FILES_DIR/work/README.md" "$PROJECT_ROOT/work/README.md"
fi

# ── 5. Write SETUP.md ────────────────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 6/6: Writing SETUP.md ──────────────────────────────────"
cat > "$SETUP_MD" <<SETUP
# 6.S081 — Setup Status

**Last updated:** $(date +%Y-%m-%d)
**URI:** $URI
**Workspace:** $WORKSPACE_ROOT

## What was set up

| Component | Status | Path / URL |
|-----------|--------|------------|
| RISC-V toolchain | $(command -v riscv64-unknown-elf-gcc &>/dev/null && echo "✓ installed" || echo "✗ missing") | $(command -v riscv64-unknown-elf-gcc 2>/dev/null || echo "run setup again") |
| QEMU | $(command -v qemu-system-riscv64 &>/dev/null && echo "✓ installed" || echo "✗ missing") | $(command -v qemu-system-riscv64 2>/dev/null || echo "run setup again") |
| xv6 source | ✓ cloned | \`starter-code/xv6-labs-2021/\` (on branch \`$(git -C "$STARTER" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")\`) |
| GitHub repo (origin) | $([ "$GITHUB_REPO_URL" != "(not configured)" ] && echo "✓ configured" || echo "✗ not configured") | $GITHUB_REPO_URL |
| MIT upstream (fetch-only) | ✓ configured | \`git://g.csail.mit.edu/xv6-labs-2021\` |
| VS Code tasks | ✓ installed | \`.vscode/tasks.json\` |
| Lab scripts | ✓ installed | \`scripts/lab-start.sh\`, \`scripts/lab-done.sh\` |

## How to start working

\`\`\`bash
# Open in VS Code
code $PROJECT_ROOT
\`\`\`

Then from VS Code (**Cmd+Shift+P → Tasks: Run Task**):

1. **"Lab: start"** → select \`util\` to begin Lab 0
2. Read the lab: https://pdos.csail.mit.edu/6.828/2021/labs/util.html
3. Implement your solution in \`starter-code/xv6-labs-2021/\`
4. **"xv6: run tests"** → runs \`make grade\`
5. **"Lab: done"** → select \`util\` when all tests pass

## All VS Code tasks

| Task | What it does |
|------|-------------|
| **Lab: start** | Checkout lab branch in xv6, create \`work/<lab>/notes.md\` |
| **Lab: done** | \`make grade\`, create \`work/<lab>/writeup.md\`, save checkpoint, push |
| **xv6: boot** | \`make qemu\` — boot xv6 in QEMU *(Ctrl-a x to exit)* |
| **xv6: run tests** | \`make grade\` — run all tests for current lab |
| **xv6: debug** | \`make qemu-gdb\` — start QEMU in debug mode for GDB attach |
| **xv6: clean** | \`make clean\` |
| **Checkpoint: save** | \`karya workstate save\` |
| **Checkpoint: list** | \`karya workstate list\` |
| **Checkpoint: resume** | \`karya workstate resume --apply\` |
| **Setup: re-run** | Re-run this setup (idempotent, picks up where it left off) |

## Directory layout

\`\`\`
learning/mit/6s081/
├── SETUP.md                      ← you are here
├── LABS.md                       ← lab tracker (update as you go)
├── PROJECT.md                    ← project metadata
├── scripts/
│   ├── lab-start.sh              ← called by "Lab: start" task
│   └── lab-done.sh               ← called by "Lab: done" task
├── starter-code/
│   └── xv6-labs-2021/            ← MIT xv6 kernel (one branch per lab)
│       ├── remotes: origin (your GitHub, read/write), mit-upstream (MIT, fetch-only)
│       └── [util, syscall, pagetable, traps, cow, thread, net, lock, fs, mmap]
├── study_materials/              ← lecture slides, PDFs, reference docs
└── work/
    ├── README.md                 ← explains this directory
    ├── util/
    │   ├── notes.md              ← created by "Lab: start"
    │   └── writeup.md            ← created by "Lab: done"
    └── <lab>/...
\`\`\`

## If setup was interrupted or needs re-running

\`\`\`bash
karya create project --uri kosh://learning/mit/6s081 --continue
\`\`\`
SETUP

echo "[6s081] Wrote SETUP.md"

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  6.S081 setup complete!"
echo ""
echo "  Open in VS Code:"
echo "    code $PROJECT_ROOT"
echo ""
echo "  Then: Cmd+Shift+P → Tasks: Run Task → Lab: start → util"
echo "  Lab 0 instructions: https://pdos.csail.mit.edu/6.828/2021/labs/util.html"
echo "══════════════════════════════════════════════════════════════════"
