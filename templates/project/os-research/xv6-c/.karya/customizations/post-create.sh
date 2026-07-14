#!/usr/bin/env bash
# post-create.sh for kosh://project/os-research/xv6-c
# C reference track — modernised toolchain, stays in C throughout.
set -euo pipefail
CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"

VARIANT="c"
GITHUB_REPO_SLUG="project-os-research-xv6-c-upstream"
KERNEL_DIR="$PROJECT_ROOT/kernel/xv6-riscv"
STAGE0_BRANCH="stage0/c-toolchain"
TOOLCHAIN_LABEL=""   # set after version detection below
GITHUB_REPO_URL=""

source "$(dirname "$(dirname "$(dirname "$CUSTOMIZATION_DIR")")")/.karya/customizations/lib.sh"

echo ""
echo "[xv6-c] ── Step 1/5: Guards ──────────────────────────────────────────────"
xv6_windows_guard
xv6_check_homebrew

echo ""
echo "[xv6-c] ── Step 2/5: Toolchain + QEMU ───────────────────────────────────"
xv6_install_riscv_toolchain
xv6_install_qemu

GCC_VER=$(riscv64-unknown-elf-gcc --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
TOOLCHAIN_LABEL="gcc-${GCC_VER%%.*}"

RISCV_BIN="$(dirname "$(command -v riscv64-unknown-elf-gcc)")"
xv6_setup_toolchain_dir "$TOOLCHAIN_LABEL" "$RISCV_BIN" "riscv64-unknown-elf-"

echo ""
echo "[xv6-c] ── Step 3/5: GitHub repo + clone ─────────────────────────────────"
xv6_github_setup
xv6_clone_kernel
xv6_checkout_stage0_branch "$KERNEL_DIR"

echo ""
echo "[xv6-c] ── Step 4/5: Project files ──────────────────────────────────────"
xv6_install_files

echo ""
echo "[xv6-c] ── Step 5/5: SETUP.md ───────────────────────────────────────────"
xv6_write_setup_md "| riscv64-unknown-elf-gcc $GCC_VER | $(command -v riscv64-unknown-elf-gcc &>/dev/null && echo '✓' || echo '✗') |" "build"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  xv6-c setup complete!"
echo "  cd kernel/xv6-riscv && make qemu"
echo "══════════════════════════════════════════════════════════════"
