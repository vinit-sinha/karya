#!/usr/bin/env bash
# Boot xv6-rust in QEMU with a GDB stub, then connect GDB in the same terminal.
# In VS Code, use the "xv6-rust: debug" task instead, which opens QEMU in one
# panel and leaves your terminal free for GDB.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/build.sh

KERNEL_ELF="src/target/riscv64imac-unknown-none-elf/release/xv6-rust"
GDB="$ROOT/toolchain/current/riscv64-unknown-elf-gdb"

qemu-system-riscv64 \
    -machine virt -bios none -kernel "$KERNEL_ELF" \
    -m 128M -smp 3 -nographic \
    -s -S &
QEMU_PID=$!

sleep 1

"$GDB" "$KERNEL_ELF" -ex "target remote localhost:1234"

kill "$QEMU_PID" 2>/dev/null || true
