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

# Checkout the lab branch in xv6
echo "Checking out branch '$LAB' in xv6..."
cd "$XV6"
if ! git rev-parse --verify "$LAB" &>/dev/null; then
    echo "ERROR: branch '$LAB' not found."
    echo "Available branches:"
    git branch -a | grep -v HEAD
    exit 1
fi
git checkout "$LAB"
echo "xv6 is on branch: $LAB"
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
