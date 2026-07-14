#!/usr/bin/env bash
# post-create.sh for kosh://project/os-research/xv6-cpp
# C++26 reimplementation track — same dual GCC/LLVM toolchain setup as
# xv6-c-cmake (inherited, not independently designed), but never builds
# kernel/xv6-riscv directly. It's a read-only reimplementation reference;
# the real kernel lives in src/, built with CMake+Ninja.
set -euo pipefail
CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"

VARIANT="cpp"
GITHUB_REPO_SLUG="project-os-research-xv6-cpp-upstream"
KERNEL_DIR="$PROJECT_ROOT/kernel/xv6-riscv"
STAGE0_BRANCH="stage0/environment-bringup"
TOOLCHAIN_LABEL=""
GITHUB_REPO_URL=""
LLVM_BIN=""
LLD_BIN=""

source "$(dirname "$(dirname "$(dirname "$CUSTOMIZATION_DIR")")")/.karya/customizations/lib.sh"

echo ""
echo "[xv6-cpp] ── Step 1/5: Guards ────────────────────────────────────────────"
xv6_windows_guard
xv6_check_homebrew

echo ""
echo "[xv6-cpp] ── Step 2/5: Toolchains + QEMU ────────────────────────────────"
xv6_install_riscv_toolchain
xv6_install_llvm_toolchain
xv6_install_qemu

if ! command -v riscv64-unknown-elf-g++ &>/dev/null; then
    warn "riscv64-unknown-elf-g++ not found. Try: brew reinstall riscv-gnu-toolchain"
fi
if ! command -v cmake &>/dev/null; then
    log "Installing CMake ..."
    brew install cmake
fi
if ! command -v ninja &>/dev/null; then
    log "Installing Ninja ..."
    brew install ninja
fi

GCC_VER=$(riscv64-unknown-elf-gcc --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
LLVM_VER=$("$LLVM_BIN/clang" --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

RISCV_BIN="$(dirname "$(command -v riscv64-unknown-elf-gcc)")"
xv6_setup_toolchain_dir "gcc-${GCC_VER%%.*}" "$RISCV_BIN" "riscv64-unknown-elf-"
xv6_setup_toolchain_dir "llvm-${LLVM_VER%%.*}" "$LLVM_BIN" "" \
    "clang:$LLVM_BIN/clang" \
    "clang++:$LLVM_BIN/clang++" \
    "ld.lld:$LLD_BIN/ld.lld" \
    "llvm-ar:$LLVM_BIN/llvm-ar" \
    "llvm-nm:$LLVM_BIN/llvm-nm" \
    "llvm-objcopy:$LLVM_BIN/llvm-objcopy" \
    "llvm-objdump:$LLVM_BIN/llvm-objdump" \
    "llvm-ranlib:$LLVM_BIN/llvm-ranlib" \
    "llvm-strip:$LLVM_BIN/llvm-strip"
# xv6_setup_toolchain_dir always repoints toolchain/current to whatever it
# just set up — re-point it back to gcc explicitly rather than relying on
# call order above to leave it there.
ln -sfn "gcc-${GCC_VER%%.*}" "$PROJECT_ROOT/toolchain/current"

echo ""
echo "[xv6-cpp] ── Step 3/5: GitHub repo + reference clone ─────────────────────"
xv6_github_setup
xv6_clone_kernel
# Reimplementation track: the stage0 branch belongs to this project's own
# repo, not to kernel/xv6-riscv (which stays untouched as reference).
xv6_checkout_stage0_branch "$PROJECT_ROOT"

echo ""
echo "[xv6-cpp] ── Step 4/5: Project files ────────────────────────────────────"
xv6_install_files
# src/ is intentionally left as an empty placeholder — the Stage 0 kernel
# itself (CMakeLists.txt copied from xv6-c-cmake, entry point, toolchain
# files) is Stage 0 implementation work, not a template asset. See
# STAGES.md and docs/agentic-workflow.md.
mkdir -p "$PROJECT_ROOT/src"

echo ""
echo "[xv6-cpp] ── Step 5/5: SETUP.md ─────────────────────────────────────────"
xv6_write_setup_md "| riscv64-unknown-elf-gcc $GCC_VER | $(command -v riscv64-unknown-elf-gcc &>/dev/null && echo '✓' || echo '✗') |
| riscv64-unknown-elf-g++ | $(command -v riscv64-unknown-elf-g++ &>/dev/null && echo '✓' || echo '✗') |
| clang++ (LLVM) $LLVM_VER | $([[ -x "$LLVM_BIN/clang++" ]] && echo '✓' || echo '✗') |
| cmake | $(command -v cmake &>/dev/null && echo '✓' || echo '✗') |
| ninja | $(command -v ninja &>/dev/null && echo '✓' || echo '✗') |" \
    "reference" \
    $'./scripts/build.sh gcc   # or: ./scripts/build.sh llvm\n./scripts/run.sh gcc     # Ctrl-a x to exit'

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  xv6-cpp scaffold complete! Next: read STAGES.md"
echo "  ./scripts/build.sh gcc && ./scripts/run.sh gcc"
echo "══════════════════════════════════════════════════════════════"
