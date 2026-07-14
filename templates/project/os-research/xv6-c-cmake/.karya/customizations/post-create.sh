#!/usr/bin/env bash
# post-create.sh for kosh://project/os-research/xv6-c-cmake
# CMake+Ninja build of the unmodified xv6 C source, GCC and LLVM toolchains
# side by side, for benchmarking which one to use for kernel development.
set -euo pipefail
CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"

VARIANT="c-cmake"
GITHUB_REPO_SLUG="project-os-research-xv6-c-cmake-upstream"
KERNEL_DIR="$PROJECT_ROOT/kernel/xv6-riscv"
STAGE0_BRANCH="stage0/cmake-gcc"
TOOLCHAIN_LABEL=""
GITHUB_REPO_URL=""
LLVM_BIN=""
LLD_BIN=""

source "$(dirname "$(dirname "$(dirname "$CUSTOMIZATION_DIR")")")/.karya/customizations/lib.sh"

echo ""
echo "[xv6-c-cmake] ── Step 1/5: Guards ────────────────────────────────────────"
xv6_windows_guard
xv6_check_homebrew

echo ""
echo "[xv6-c-cmake] ── Step 2/5: Toolchains + QEMU ─────────────────────────────"
xv6_install_riscv_toolchain
xv6_install_llvm_toolchain
xv6_install_qemu

if ! command -v cmake &>/dev/null; then
    log "Installing CMake ..."
    brew install cmake
else
    log "CMake: $(command -v cmake) ($(cmake --version | head -1))"
fi
if ! command -v ninja &>/dev/null; then
    log "Installing Ninja ..."
    brew install ninja
else
    log "Ninja: $(command -v ninja)"
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
# Both toolchains stay installed side by side (see docs/adr/0002). But
# xv6_setup_toolchain_dir always repoints toolchain/current to whatever it
# just set up (llvm, last) — re-point it back to gcc explicitly as a sane
# default for tools that don't know about the -DTOOLCHAIN= flag; scripts/
# build.sh always passes it explicitly regardless.
ln -sfn "gcc-${GCC_VER%%.*}" "$PROJECT_ROOT/toolchain/current"

echo ""
echo "[xv6-c-cmake] ── Step 3/5: GitHub repo + clone ───────────────────────────"
xv6_github_setup
xv6_clone_kernel
xv6_checkout_stage0_branch "$KERNEL_DIR"

echo ""
echo "[xv6-c-cmake] ── Step 4/5: Project files ─────────────────────────────────"
xv6_install_files

echo ""
echo "[xv6-c-cmake] ── Step 5/5: SETUP.md ──────────────────────────────────────"
xv6_write_setup_md "| riscv64-unknown-elf-gcc $GCC_VER | $(command -v riscv64-unknown-elf-gcc &>/dev/null && echo '✓' || echo '✗') |
| clang (LLVM) $LLVM_VER | $([[ -x "$LLVM_BIN/clang" ]] && echo '✓' || echo '✗') |
| cmake | $(command -v cmake &>/dev/null && echo '✓' || echo '✗') |
| ninja | $(command -v ninja &>/dev/null && echo '✓' || echo '✗') |" \
    "build" \
    $'./scripts/build.sh gcc   # or: ./scripts/build.sh llvm\n./scripts/run.sh gcc     # Ctrl-a x to exit'

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  xv6-c-cmake setup complete! Next: read STAGES.md"
echo "  ./scripts/build.sh gcc && ./scripts/run.sh gcc"
echo "══════════════════════════════════════════════════════════════"
