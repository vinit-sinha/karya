#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../kernel/xv6-riscv"
TOOLCHAIN="$(dirname "$0")/../toolchain/current"
exec make TOOLPREFIX="$TOOLCHAIN/riscv64-unknown-elf-" "$@"
