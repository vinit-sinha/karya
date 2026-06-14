#!/usr/bin/env bash
# Usage: bash scripts/lab-done.sh <lab>
# Run from the project root (VS Code workspaceFolder).
# Called by VS Code task "Lab: done".
set -euo pipefail

LAB="${1:-}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XV6="$PROJECT_ROOT/starter-code/xv6-labs-2021"

# If no lab given, detect from current xv6 branch
if [[ -z "$LAB" ]]; then
    LAB=$(git -C "$XV6" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -z "$LAB" || "$LAB" == "HEAD" ]]; then
        echo "Usage: bash scripts/lab-done.sh <lab>"
        echo "Labs:  util  syscall  pagetable  traps  cow  thread  net  lock  fs  mmap"
        exit 1
    fi
    echo "Detected current lab from xv6 branch: $LAB"
fi

if [[ ! -d "$XV6/.git" ]]; then
    echo "ERROR: xv6-labs-2021 not found at $XV6"
    exit 1
fi

echo "── Lab done: $LAB ──────────────────────────────────────────────────────"

# Run the test suite
echo "Running make grade..."
cd "$XV6"
make grade
cd "$PROJECT_ROOT"
echo "All tests passed for lab: $LAB"

# Create writeup template if it doesn't exist
NOTES_DIR="$PROJECT_ROOT/work/$LAB"
mkdir -p "$NOTES_DIR"
if [[ ! -f "$NOTES_DIR/writeup.md" ]]; then
    cat > "$NOTES_DIR/writeup.md" <<WRITEUP
# Lab: $LAB — Writeup

**Completed:** $(date +%Y-%m-%d)
**Instructions:** https://pdos.csail.mit.edu/6.828/2021/labs/$LAB.html

## What I implemented

## Design decisions

## Challenges and how I solved them

## What I learned

## Time spent
WRITEUP
    echo "Created work/$LAB/writeup.md — fill it in while it's fresh"
fi

# Push lab branch to personal remote
echo "Pushing $LAB to personal remote..."
cd "$XV6"
git push personal "$LAB" 2>&1 || echo "WARNING: push failed — run 'git push personal $LAB' manually when ready."
cd "$PROJECT_ROOT"

# Save a done checkpoint
karya workstate save "$LAB-done" --description "Completed lab: $LAB — all tests pass" 2>/dev/null || true

# Update LABS.md status hint
echo ""
echo "  Lab $LAB complete."
echo "  Fill in: work/$LAB/writeup.md"
echo "  Update:  LABS.md  (mark $LAB as done)"
echo ""
echo "  Next: Cmd+Shift+P → Tasks: Run Task → Lab: start → <next lab>"
