#!/usr/bin/env bash
# Build the xv6 kernel.
# Stage 0-1: delegates to GNU Make.
# Stage 2+: replace with cmake --build build once CMake is in place.
set -euo pipefail
cd "$(dirname "$0")/../kernel/xv6-riscv"
exec make "$@"
