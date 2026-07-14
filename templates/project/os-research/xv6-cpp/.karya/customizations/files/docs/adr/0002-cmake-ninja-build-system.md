# ADR 0002 — CMake + Ninja as Build System (Inherited from xv6-c-cmake)

**Date:** (set when project is created)
**Status:** Accepted

## Context

This track builds a fresh C++26 kernel in `src/` from Stage 0 onward — it never reuses xv6-riscv's own `Makefile` (that stays in `kernel/xv6-riscv/` purely as a reference; `xv6-c` builds it directly instead). GNU Make has friction for C++ at scale regardless — no automatic dependency scanning, no `compile_commands.json`, ad-hoc IDE integration.

[`xv6-c-cmake`](../xv6-c-cmake) already solved this exact problem for C: CMake + Ninja, with GCC and LLVM as two toolchains built side by side (not a single switchable "current") so they can be benchmarked. Re-deriving that from scratch here would just reproduce work already done and already decided.

## Decision

**Bootstrap this track's build system by copying `xv6-c-cmake`'s `CMakeLists.txt` and `cmake/riscv64-elf-{gcc,llvm}.cmake`, then retarget from C to C++26.** No independent CMake design happens here.

- Same dual-toolchain, build-directory-per-toolchain shape as `xv6-c-cmake`: `build/` for GCC (`riscv64-unknown-elf-g++`), `build-llvm/` for LLVM (`clang++ --target=riscv64-unknown-elf`), selected via `-DTOOLCHAIN=gcc|llvm`
- `CMakeLists.txt` lives in `src/` (this track's own kernel source), not inside `kernel/xv6-riscv/` — unlike `xv6-c-cmake`, which builds the reference source directly, this track never builds `kernel/xv6-riscv/` at all, so the CMake files land next to the C++26 source they actually build
- Added on top of the inherited base: `-fno-exceptions -fno-rtti` (freestanding C++ constraints that don't apply to C), `--std=c++26`
- CMake generates `compile_commands.json` automatically → clangd works out of the box
- `scripts/build.sh <gcc|llvm>` wraps the CMake invocation, same interface as `xv6-c-cmake`'s

**Default toolchain:** follow `xv6-c-cmake`'s Stage 2 decision (`xv6-c-cmake/docs/adr/0003-gcc-vs-llvm-decision.md`) unless C++26 support specifically argues otherwise (e.g. one compiler's C++26 feature coverage is meaningfully ahead of the other's) — if so, say why in a follow-up ADR here rather than silently diverging.

## Consequences

- `./scripts/build.sh gcc` / `./scripts/build.sh llvm` (via `scripts/build.sh`) are the canonical build commands from the very first commit — both, not just one, since the point of inheriting `xv6-c-cmake`'s setup is keeping both toolchains available for this track too
- clangd and VS Code C++ IntelliSense work correctly with the generated `compile_commands.json` from Stage 0
- No Makefile compatibility shim to maintain
- If `xv6-c-cmake`'s build system changes later (e.g. a toolchain file bugfix), consider whether the same fix applies here — they started identical and drift is worth noticing, not necessarily worth eliminating
