#!/usr/bin/env bash
# Build the xv6-rust kernel.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CARGO="$ROOT/toolchain/current/cargo"
cd "$ROOT/src"
exec "$CARGO" build --release --target riscv64imac-unknown-none-elf "$@"
