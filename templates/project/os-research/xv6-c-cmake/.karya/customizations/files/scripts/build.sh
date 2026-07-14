#!/usr/bin/env bash
# Build the xv6-c-cmake kernel with the given toolchain (default: gcc).
# Usage: build.sh [gcc|llvm]
set -euo pipefail
TOOLCHAIN="${1:-gcc}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_DIR="$ROOT/kernel/xv6-riscv"

case "$TOOLCHAIN" in
    gcc)  BUILD_DIR="build" ;;
    llvm) BUILD_DIR="build-llvm" ;;
    *) echo "usage: $0 [gcc|llvm]" >&2; exit 1 ;;
esac

cd "$KERNEL_DIR"
cmake -G Ninja -B "$BUILD_DIR" \
    -DTOOLCHAIN="$TOOLCHAIN" \
    -DCMAKE_TOOLCHAIN_FILE="$KERNEL_DIR/cmake/riscv64-elf-${TOOLCHAIN}.cmake"
exec cmake --build "$BUILD_DIR"
