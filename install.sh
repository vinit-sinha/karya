#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/tools/karya"
mkdir -p "$HOME/tools"
rm -rf "$DEST"
cp -R "$ROOT" "$DEST"
grep -q 'karya/bin' "$HOME/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/tools/karya/bin:$PATH"' >> "$HOME/.zshrc"
grep -q 'karya/bin' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/tools/karya/bin:$PATH"' >> "$HOME/.bashrc"
echo "Installed to $DEST"
echo "Please restart your shell or run: source ~/.zshrc (or ~/.bashrc)"
