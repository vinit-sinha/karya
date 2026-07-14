#!/usr/bin/env bash
# Boot xv6-rust in QEMU.  Ctrl-a x to exit.
# Same machine/CPU flags as the C and C++ tracks, for direct comparability.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/build.sh

KERNEL_ELF="src/target/riscv64imac-unknown-none-elf/release/xv6-rust"

exec qemu-system-riscv64 \
    -machine virt -bios none -kernel "$KERNEL_ELF" \
    -m 128M -smp 3 -nographic \
    "$@"
