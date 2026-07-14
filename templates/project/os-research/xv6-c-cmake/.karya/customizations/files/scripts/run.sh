#!/usr/bin/env bash
# Boot the xv6-c-cmake kernel (built with the given toolchain) in QEMU.
# Usage: run.sh [gcc|llvm]   Ctrl-a x to exit.
set -euo pipefail
TOOLCHAIN="${1:-gcc}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "$TOOLCHAIN" in
    gcc)  BUILD_DIR="build" ;;
    llvm) BUILD_DIR="build-llvm" ;;
    *) echo "usage: $0 [gcc|llvm]" >&2; exit 1 ;;
esac

"$ROOT/scripts/build.sh" "$TOOLCHAIN"

KERNEL_ELF="$ROOT/kernel/xv6-riscv/$BUILD_DIR/kernel"

exec qemu-system-riscv64 \
    -machine virt -bios none -kernel "$KERNEL_ELF" \
    -m 128M -smp 3 -nographic
