#!/usr/bin/env bash
# post-create.sh for kosh://project/os-research/xv6-rust
# Rust reimplementation track — idiomatic Rust from Stage 0, bare-metal
# RISC-V. Never builds kernel/xv6-riscv directly; it's a read-only
# reimplementation reference. The real kernel lives in src/.
set -euo pipefail
CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"

VARIANT="rust"
GITHUB_REPO_SLUG="project-os-research-xv6-rust-upstream"
KERNEL_DIR="$PROJECT_ROOT/kernel/xv6-riscv"
STAGE0_BRANCH="stage0/environment-bringup"
TOOLCHAIN_LABEL=""
GITHUB_REPO_URL=""

source "$(dirname "$(dirname "$(dirname "$CUSTOMIZATION_DIR")")")/.karya/customizations/lib.sh"

echo ""
echo "[xv6-rust] ── Step 1/5: Guards ───────────────────────────────────────────"
xv6_windows_guard
xv6_check_homebrew

echo ""
echo "[xv6-rust] ── Step 2/5: Toolchain + QEMU ────────────────────────────────"
xv6_install_qemu

# Rust via rustup
if ! command -v rustup &>/dev/null; then
    log "Installing rustup ..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    source "$HOME/.cargo/env"
else
    log "rustup: $(rustup --version 2>/dev/null | head -1)"
fi

rustup toolchain install stable 2>/dev/null || true
rustup target add riscv64imac-unknown-none-elf

RUST_VER=$(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
log "rustc $RUST_VER, target riscv64imac-unknown-none-elf added"

# riscv bintools needed for linking and GDB
xv6_install_riscv_toolchain

TOOLCHAIN_LABEL="rust-${RUST_VER%%.*}"
RISCV_BIN="$(dirname "$(command -v riscv64-unknown-elf-gcc)")"
CARGO_BIN="$HOME/.cargo/bin"

xv6_setup_toolchain_dir "$TOOLCHAIN_LABEL" "$RISCV_BIN" "riscv64-unknown-elf-" \
    "cargo:$CARGO_BIN/cargo" \
    "rustc:$CARGO_BIN/rustc" \
    "rust-objdump:$CARGO_BIN/rust-objdump" \
    "rust-objcopy:$CARGO_BIN/rust-objcopy"

echo ""
echo "[xv6-rust] ── Step 3/5: GitHub repo + reference clone ─────────────────────"
xv6_github_setup
xv6_clone_kernel
# Reimplementation track: the stage0 branch belongs to this project's own
# repo, not to kernel/xv6-riscv (which stays untouched as reference).
xv6_checkout_stage0_branch "$PROJECT_ROOT"

echo ""
echo "[xv6-rust] ── Step 4/5: Project files ───────────────────────────────────"
xv6_install_files
# src/ is intentionally left as an empty placeholder — the Stage 0 kernel
# itself (Cargo.toml, entry point, linker script) is Stage 0 implementation
# work, not a template asset. See STAGES.md and docs/agentic-workflow.md.
mkdir -p "$PROJECT_ROOT/src"

echo ""
echo "[xv6-rust] ── Step 5/5: SETUP.md ────────────────────────────────────────"
xv6_write_setup_md "| rustc $RUST_VER | ✓ |
| riscv64imac-unknown-none-elf target | ✓ |
| riscv64-unknown-elf-gdb | $(command -v riscv64-unknown-elf-gdb &>/dev/null && echo '✓' || echo '✗') |" \
    "reference"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  xv6-rust scaffold complete! Next: read STAGES.md"
echo "  ./scripts/build.sh && ./scripts/run.sh"
echo "══════════════════════════════════════════════════════════════"
