#!/usr/bin/env bash
# Usage: bash scripts/lab-start.sh <lab>
# Run from the project root (VS Code workspaceFolder).
# Called by VS Code task "Lab: start".
set -euo pipefail

LAB="${1:-}"
if [[ -z "$LAB" ]]; then
    echo "Usage: bash scripts/lab-start.sh <lab>"
    echo "Labs:  util  syscall  pagetable  traps  cow  thread  net  lock  fs  mmap"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XV6="$PROJECT_ROOT/starter-code/xv6-labs-2021"

if [[ ! -d "$XV6/.git" ]]; then
    echo "ERROR: xv6-labs-2021 not found at $XV6"
    echo "       Run setup: karya create project --uri kosh://learning/mit/6s081 --continue"
    exit 1
fi

echo "── Lab: $LAB ──────────────────────────────────────────────────────────"

# Checkout the lab branch in xv6.
# On a fresh clone, lab branches only exist as remote refs (refs/remotes/origin/<lab>),
# not local branches. Try to create a local tracking branch first; fall back to
# switching to an existing local branch if it's already been checked out before.
echo "Checking out branch '$LAB' in xv6..."
cd "$XV6"
if ! git show-ref --verify --quiet "refs/remotes/origin/$LAB" && \
   ! git show-ref --verify --quiet "refs/heads/$LAB"; then
    echo "ERROR: branch '$LAB' not found in xv6 repo."
    echo "Available branches:"
    git branch -a | grep -v HEAD
    exit 1
fi
git checkout -b "$LAB" --track "origin/$LAB" 2>/dev/null || git checkout "$LAB"
echo "xv6 is on branch: $LAB"

# Re-apply Makefile patch on every checkout — newer GCC treats infinite
# recursion in sh.c as a fatal error; the upstream Makefile doesn't include
# the suppression flag.
MAKEFILE="$XV6/Makefile"
if [[ -f "$MAKEFILE" ]] && ! grep -q "Wno-error=infinite-recursion" "$MAKEFILE"; then
    sed -i.bak 's/\(CFLAGS :=.*\)/\1\nCFLAGS += -Wno-error=infinite-recursion/' "$MAKEFILE"
    rm -f "$MAKEFILE.bak"
    echo "Patched Makefile: added -Wno-error=infinite-recursion"
fi

cd "$PROJECT_ROOT"

# Create work/<lab>/notes.md if it doesn't exist
NOTES_DIR="$PROJECT_ROOT/work/$LAB"
mkdir -p "$NOTES_DIR"
if [[ ! -f "$NOTES_DIR/notes.md" ]]; then
    cat > "$NOTES_DIR/notes.md" <<NOTES
# Lab: $LAB — Notes

**Started:** $(date +%Y-%m-%d)
**Instructions:** https://pdos.csail.mit.edu/6.828/2021/labs/$LAB.html
**xv6 branch:** \`$LAB\`

## Plan / approach

## Key observations

## Debugging notes

## Questions / blockers
NOTES
    echo "Created work/$LAB/notes.md"
fi

# Save a start checkpoint
karya workstate save "$LAB-start" --description "Starting lab: $LAB" 2>/dev/null || true

echo ""
echo "  Ready to work on lab: $LAB"
echo "  Notes:        work/$LAB/notes.md"
echo "  Instructions: https://pdos.csail.mit.edu/6.828/2021/labs/$LAB.html"
echo ""
echo "  Boot xv6:   Cmd+Shift+B  (task: xv6: boot)"
echo "  Run tests:  Cmd+Shift+P → Tasks: Run Task → xv6: run tests"
