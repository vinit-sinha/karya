#!/usr/bin/env bash
# Boot xv6 in QEMU.  Ctrl-a x to exit.
set -euo pipefail
cd "$(dirname "$0")/../kernel/xv6-riscv"
exec make qemu "$@"
