#!/usr/bin/env bash
# post-create.sh for kosh://learning/mit/6s081
# Idempotent — safe to re-run via:
#   karya create project --uri kosh://learning/mit/6s081            (first run)
#   karya create project --uri kosh://learning/mit/6s081 --continue  (resume)
set -euo pipefail

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

# ── Derive repo name from .karya-project URI ─────────────────────────────────
# kosh://learning/mit/6s081 → learning-mit-6s081
URI=$(python3 -c "
import json, sys
try:
    d = json.load(open('$PROJECT_ROOT/.karya-project'))
    print(d.get('uri', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

if [[ -n "$URI" ]]; then
    REPO_NAME=$(echo "$URI" | sed 's|kosh://||' | tr '/' '-')
else
    REPO_NAME="learning-mit-6s081"
fi
echo "[6s081] GitHub repo name derived from URI: $REPO_NAME"

# ── 1. Toolchain + QEMU ──────────────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 1/5: Toolchain + QEMU ──────────────────────────────────"
if ! command -v brew &>/dev/null; then
    echo "[6s081] ERROR: Homebrew not found. Install from https://brew.sh then re-run:"
    echo "        karya create project --uri kosh://learning/mit/6s081 --continue"
    exit 1
fi
if ! command -v riscv64-unknown-elf-gcc &>/dev/null; then
    echo "[6s081] Installing RISC-V toolchain (this may take several minutes)..."
    brew tap riscv-software-src/riscv 2>/dev/null || true
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

# ── 2. Clone xv6 lab repo ────────────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 2/5: Clone xv6-labs-2021 ───────────────────────────────"
# Directory layout:
#   starter-code/xv6-labs-2021/   ← MIT clone (one branch per lab)
#     origin  → git://g.csail.mit.edu/xv6-labs-2021  (MIT source, read-only)
#     personal → https://github.com/<user>/<repo>     (your private mirror)
#
# You work directly on lab branches (MIT convention).
# Push your work to the personal remote.
STARTER="$PROJECT_ROOT/starter-code/xv6-labs-2021"
if [[ ! -d "$STARTER/.git" ]]; then
    echo "[6s081] Cloning xv6-labs-2021 from MIT..."
    git clone git://g.csail.mit.edu/xv6-labs-2021 "$STARTER" || {
        echo "[6s081] ERROR: clone failed. Ensure network access to g.csail.mit.edu"
        echo "        Re-run after fixing: karya create project --uri kosh://learning/mit/6s081 --continue"
        exit 1
    }
else
    echo "[6s081] xv6-labs-2021 already cloned at $STARTER"
fi

# MIT's remote HEAD is unset — check out util explicitly so there's a ref
cd "$STARTER"
if ! git rev-parse --verify util &>/dev/null; then
    echo "[6s081] ERROR: 'util' branch not found in xv6 clone — clone may be corrupt."
    exit 1
fi
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" == "HEAD" || -z "$CURRENT_BRANCH" ]]; then
    git checkout util
    echo "[6s081] Checked out branch: util (lab 0 — starting point)"
else
    echo "[6s081] Current branch: $CURRENT_BRANCH"
fi
cd "$PROJECT_ROOT"

# ── 3. GitHub private mirror ─────────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 3/5: GitHub private mirror ─────────────────────────────"
PERSONAL_REMOTE_URL="(not configured)"
if ! command -v gh &>/dev/null; then
    echo "[6s081] WARNING: gh CLI not found — skipping GitHub mirror."
    echo "        Install: brew install gh && gh auth login, then re-run with --continue"
else
    GITHUB_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    if [[ -z "$GITHUB_USER" ]]; then
        echo "[6s081] WARNING: not authenticated with gh — skipping GitHub mirror."
        echo "        Run: gh auth login, then re-run with --continue"
    else
        FULL_REPO="$GITHUB_USER/$REPO_NAME"

        if gh repo view "$FULL_REPO" &>/dev/null 2>&1; then
            echo "[6s081] Repo already exists: https://github.com/$FULL_REPO"
            REPO_META=$(gh repo view "$FULL_REPO" --json visibility,description \
                --jq '"  Visibility: \(.visibility) | Description: \(.description)"')
            echo "  $REPO_META"
            echo ""
            echo "  What would you like to do?"
            echo "    [R] Reuse this repo as-is (recommended if it contains your lab work)"
            echo "    [N] Create under a different name"
            read -r -p "  Choice [R/N, default R]: " choice
            choice="${choice:-R}"
            if [[ "${choice^^}" == "N" ]]; then
                read -r -p "  New repo name: " REPO_NAME
                FULL_REPO="$GITHUB_USER/$REPO_NAME"
                echo "[6s081] Creating private repo: https://github.com/$FULL_REPO ..."
                gh repo create "$FULL_REPO" --private \
                    --description "MIT 6.S081 OS Engineering — personal lab repo"
            else
                echo "[6s081] Reusing https://github.com/$FULL_REPO"
            fi
        else
            echo "[6s081] Creating private GitHub repo: https://github.com/$FULL_REPO ..."
            gh repo create "$FULL_REPO" --private \
                --description "MIT 6.S081 OS Engineering — personal lab repo"
        fi

        PERSONAL_REMOTE_URL="https://github.com/$FULL_REPO.git"
        cd "$STARTER"
        if git remote get-url personal &>/dev/null 2>&1; then
            EXISTING=$(git remote get-url personal)
            if [[ "$EXISTING" != "$PERSONAL_REMOTE_URL" ]]; then
                git remote set-url personal "$PERSONAL_REMOTE_URL"
                echo "[6s081] Updated remote 'personal' → $PERSONAL_REMOTE_URL"
            else
                echo "[6s081] Remote 'personal' already set correctly."
            fi
        else
            git remote add personal "$PERSONAL_REMOTE_URL"
            echo "[6s081] Added remote 'personal' → $PERSONAL_REMOTE_URL"
        fi

        echo "[6s081] Pushing all lab branches to personal remote..."
        git push personal --all 2>&1 || \
            echo "[6s081] WARNING: push incomplete — run 'git push personal --all' from starter-code/xv6-labs-2021/ when ready."
        cd "$PROJECT_ROOT"
    fi
fi

# ── 4. Install VS Code tasks, scripts, and work docs ─────────────────────────
echo ""
echo "[6s081] ── Step 4/5: Install VS Code tasks + scripts ───────────────────"
mkdir -p "$PROJECT_ROOT/.vscode" "$PROJECT_ROOT/scripts"

if [[ -f "$FILES_DIR/.vscode/tasks.json" ]]; then
    cp "$FILES_DIR/.vscode/tasks.json" "$PROJECT_ROOT/.vscode/tasks.json"
    echo "[6s081] Installed .vscode/tasks.json"
fi

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
echo "[6s081] ── Step 5/5: Writing SETUP.md ──────────────────────────────────"
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
| GitHub mirror | $([ "$PERSONAL_REMOTE_URL" != "(not configured)" ] && echo "✓ configured" || echo "✗ not configured") | $PERSONAL_REMOTE_URL |
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
│       ├── remotes: origin (MIT, read-only), personal (your GitHub mirror)
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
