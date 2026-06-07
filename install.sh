#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/tools/karya-bootstrap"
mkdir -p "$HOME/tools"
rm -rf "$DEST"
cp -R "$ROOT" "$DEST"
grep -q 'karya-bootstrap/bin' "$HOME/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/tools/karya-bootstrap/bin:$PATH"' >> "$HOME/.zshrc"
echo "Installed. Run: source ~/.zshrc"
