#!/usr/bin/env bash
# Boot the xv6-c-cmake kernel (built with the given toolchain) in QEMU with a
# GDB stub, then connect GDB in the same terminal.
# Usage: debug.sh [gcc|llvm]
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

# GDB debugs either toolchain's output equally well — always use the shared
# riscv64-unknown-elf-gdb rather than trying to pick a "matching" one.
GDB=$(command -v riscv64-unknown-elf-gdb || echo "")
if [[ -z "$GDB" ]]; then
    for d in "$ROOT"/toolchain/gcc-*; do
        [[ -x "$d/riscv64-unknown-elf-gdb" ]] && GDB="$d/riscv64-unknown-elf-gdb" && break
    done
fi
if [[ -z "$GDB" ]]; then
    echo "riscv64-unknown-elf-gdb not found" >&2
    exit 1
fi

qemu-system-riscv64 \
    -machine virt -bios none -kernel "$KERNEL_ELF" \
    -m 128M -smp 3 -nographic \
    -s -S &
QEMU_PID=$!

sleep 1

"$GDB" "$KERNEL_ELF" -ex "target remote localhost:1234"

kill "$QEMU_PID" 2>/dev/null || true
