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

# ── 2. Clone xv6 lab repo ────────────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 2/5: Clone xv6-labs-2021 ───────────────────────────────"
# Directory layout:
#   starter-code/xv6-labs-2021/   ← MIT clone (one branch per lab)
#     origin   → git://g.csail.mit.edu/xv6-labs-2021  (MIT, read-only)
#     personal → https://github.com/<user>/<repo>      (your private mirror, HTTPS)
#
# You work directly on lab branches — MIT convention.
# All git operations against the personal remote use gh's HTTPS token; no SSH needed.

# Accept xv6-riscv as a legacy directory name and normalise to xv6-labs-2021
STARTER="$PROJECT_ROOT/starter-code/xv6-labs-2021"
STARTER_LEGACY="$PROJECT_ROOT/starter-code/xv6-riscv"
if [[ ! -d "$STARTER/.git" && -d "$STARTER_LEGACY/.git" ]]; then
    echo "[6s081] Renaming starter-code/xv6-riscv → starter-code/xv6-labs-2021 ..."
    mv "$STARTER_LEGACY" "$STARTER"
fi

if [[ ! -d "$STARTER/.git" ]]; then
    echo "[6s081] Cloning xv6-labs-2021 from MIT..."
    git clone git://g.csail.mit.edu/xv6-labs-2021 "$STARTER" || {
        echo "[6s081] ERROR: clone failed. Ensure network access to g.csail.mit.edu"
        echo "        Re-run: karya create project --uri kosh://learning/mit/6s081 --continue"
        exit 1
    }
else
    echo "[6s081] xv6-labs-2021 present at $STARTER"
fi

# MIT's remote HEAD is unset — ensure util is checked out as a local branch
# so that git push --all has at least one ref to push.
cd "$STARTER"
if ! git show-ref --verify --quiet refs/remotes/origin/util && \
   ! git show-ref --verify --quiet refs/heads/util; then
    echo "[6s081] ERROR: 'util' branch not found — clone may be incomplete."
    exit 1
fi
# git branch --show-current returns empty string in detached HEAD state
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" ]]; then
    git checkout util      # creates local tracking branch from origin/util
    echo "[6s081] Checked out branch: util (lab 0 — start here)"
else
    echo "[6s081] Current branch: $CURRENT_BRANCH"
fi

# Patch Makefile for newer GCC compatibility.
# xv6-labs-2021 was written for GCC 10; newer toolchains add -Winfinite-recursion
# which flags sh.c's intentional tail-calls as errors (-Werror turns them fatal).
MAKEFILE="$STARTER/Makefile"
if [[ -f "$MAKEFILE" ]] && ! grep -q "Wno-error=infinite-recursion" "$MAKEFILE"; then
    # Insert after the first CFLAGS := line
    sed -i.bak 's/\(CFLAGS :=.*\)/\1\nCFLAGS += -Wno-error=infinite-recursion/' "$MAKEFILE"
    rm -f "$MAKEFILE.bak"
    echo "[6s081] Patched Makefile: added -Wno-error=infinite-recursion (GCC compat)"
else
    echo "[6s081] Makefile already patched."
fi
cd "$PROJECT_ROOT"

# ── 3. GitHub private mirror ─────────────────────────────────────────────────
echo ""
echo "[6s081] ── Step 3/5: GitHub private mirror ─────────────────────────────"
PERSONAL_REMOTE_URL="(not configured)"

# Helper: normalise git remote URL to HTTPS
normalise_to_https() {
    echo "$1" | sed 's|^git@github\.com:\(.*\)$|https://github.com/\1|'
}

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
print('')
" 2>/dev/null || true
}

if ! command -v gh &>/dev/null; then
    echo "[6s081] WARNING: gh CLI not found — skipping GitHub mirror."
    echo "        Install: brew install gh && gh auth login, then re-run with --continue"
else
    GITHUB_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    if [[ -z "$GITHUB_USER" ]]; then
        echo "[6s081] WARNING: not authenticated with gh."
        echo "        Run: gh auth login, then re-run with --continue"
    else
        # Wire gh as the HTTPS credential helper so no SSH keys are needed
        gh auth setup-git 2>/dev/null || true

        # ── Priority 1: use URL already stored in .karya-project (idempotent across re-runs)
        STORED_MIRROR=$(read_marker_field "github_mirror")
        cd "$STARTER"
        EXISTING_REMOTE=$(git remote get-url personal 2>/dev/null || echo "")

        if [[ -n "$STORED_MIRROR" ]]; then
            # Already set up on a previous run — just make sure the local remote matches
            echo "[6s081] Using stored mirror: $STORED_MIRROR"
            if [[ -z "$EXISTING_REMOTE" ]]; then
                git remote add personal "$STORED_MIRROR"
                echo "[6s081] Added personal remote → $STORED_MIRROR"
            elif [[ "$(normalise_to_https "$EXISTING_REMOTE")" != "$STORED_MIRROR" ]]; then
                git remote set-url personal "$STORED_MIRROR"
                echo "[6s081] Updated personal remote → $STORED_MIRROR"
            fi
            PERSONAL_REMOTE_URL="$STORED_MIRROR"

        elif [[ -n "$EXISTING_REMOTE" ]]; then
            # ── Priority 2: personal remote already in clone — normalise and store it
            HTTPS_REMOTE=$(normalise_to_https "$EXISTING_REMOTE")
            echo "[6s081] Found existing personal remote: $EXISTING_REMOTE"
            if [[ "$EXISTING_REMOTE" != "$HTTPS_REMOTE" ]]; then
                git remote set-url personal "$HTTPS_REMOTE"
                echo "[6s081] Converted SSH → HTTPS: $HTTPS_REMOTE"
            fi
            PERSONAL_REMOTE_URL="$HTTPS_REMOTE"
            cd "$PROJECT_ROOT"
            write_marker_field "github_mirror" "$PERSONAL_REMOTE_URL"
            cd "$STARTER"

        else
            # ── Priority 3: nothing known — check derived name, then ask user
            cd "$PROJECT_ROOT"
            DEFAULT_REPO="$GITHUB_USER/$REPO_NAME"
            DEFAULT_URL="https://github.com/$DEFAULT_REPO.git"

            if gh repo view "$DEFAULT_REPO" &>/dev/null 2>&1; then
                # Derived repo exists — use it without prompting
                echo "[6s081] Found existing GitHub repo: https://github.com/$DEFAULT_REPO"
                PERSONAL_REMOTE_URL="$DEFAULT_URL"
            else
                # Unknown — prompt once, store forever
                echo ""
                echo "[6s081] No GitHub mirror found for this project."
                echo "        Default: https://github.com/$DEFAULT_REPO (will be created as private)"
                echo -n "        Enter existing mirror URL, or press Enter to create the default: "
                read -r USER_INPUT </dev/tty
                if [[ -n "$USER_INPUT" ]]; then
                    PERSONAL_REMOTE_URL=$(normalise_to_https "$USER_INPUT")
                    echo "[6s081] Using provided mirror: $PERSONAL_REMOTE_URL"
                else
                    echo "[6s081] Creating private GitHub repo: https://github.com/$DEFAULT_REPO ..."
                    gh repo create "$DEFAULT_REPO" --private \
                        --description "MIT 6.S081 OS Engineering — personal lab repo"
                    PERSONAL_REMOTE_URL="$DEFAULT_URL"
                fi
            fi

            write_marker_field "github_mirror" "$PERSONAL_REMOTE_URL"
            cd "$STARTER"
            git remote add personal "$PERSONAL_REMOTE_URL"
            echo "[6s081] Added remote 'personal' → $PERSONAL_REMOTE_URL"
        fi

        echo "[6s081] Pushing all lab branches to personal remote..."
        git push personal --all 2>&1 \
            || echo "[6s081] WARNING: push incomplete — re-run with --continue when network is available."
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
if [[ -f "$FILES_DIR/.vscode/settings.json" ]]; then
    cp "$FILES_DIR/.vscode/settings.json" "$PROJECT_ROOT/.vscode/settings.json"
    echo "[6s081] Installed .vscode/settings.json (opens README.md on launch)"
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
