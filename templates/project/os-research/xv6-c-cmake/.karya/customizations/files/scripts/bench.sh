#!/usr/bin/env bash
# Build with both toolchains from a clean tree and report a build-time /
# size comparison. Stage 2 — extend with boot-time or instruction-count
# comparisons if a reasonably cheap way to measure them turns up; don't
# over-invest in benchmarking infrastructure for its own sake.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for tc in gcc llvm; do
    echo "=== $tc ==="
    build_dir="build"
    [[ "$tc" == "llvm" ]] && build_dir="build-llvm"
    rm -rf "$ROOT/kernel/xv6-riscv/$build_dir"

    start=$(date +%s)
    "$ROOT/scripts/build.sh" "$tc" >/dev/null
    end=$(date +%s)

    elf="$ROOT/kernel/xv6-riscv/$build_dir/kernel"
    echo "  build time: $((end - start))s"
    echo "  size:       $(du -h "$elf" | cut -f1)"
    size "$elf" 2>/dev/null || true
    echo
done
