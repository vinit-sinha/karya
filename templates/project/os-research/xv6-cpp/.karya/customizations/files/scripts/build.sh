#!/usr/bin/env bash
# Build the xv6-cpp kernel with the given toolchain (default: gcc).
# Usage: build.sh [gcc|llvm]
set -euo pipefail
TOOLCHAIN="${1:-gcc}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "$TOOLCHAIN" in
    gcc)  BUILD_DIR="build" ;;
    llvm) BUILD_DIR="build-llvm" ;;
    *) echo "usage: $0 [gcc|llvm]" >&2; exit 1 ;;
esac

cd "$ROOT"
cmake -G Ninja -B "$BUILD_DIR" -S src \
    -DTOOLCHAIN="$TOOLCHAIN" \
    -DCMAKE_TOOLCHAIN_FILE="$ROOT/src/cmake/riscv64-elf-${TOOLCHAIN}.cmake"
exec cmake --build "$BUILD_DIR"
