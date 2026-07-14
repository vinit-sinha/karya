# ADR 0001 — Cross-compiler and Build Toolchain

**Date:** (set when project is created)
**Status:** Accepted — supersedes an earlier draft of this ADR that picked GCC as the sole compiler; see ADR 0002 for why that changed

## Context

This track reimplements xv6 in idiomatic C++26 from Stage 0 onward — it never builds xv6-riscv's own Makefile/C source, only reads it (and `xv6-c`'s own build of it) as a reference. We need cross-compiler(s) that:

1. Produce bare-metal RISC-V ELF binaries (`-ffreestanding -nostdlib -fno-exceptions -fno-rtti`)
2. Have solid C++26 support
3. Integrate well with QEMU for run and debug
4. Work on macOS (primary dev machine) and Linux

## Decision

**Both `riscv64-unknown-elf-g++` (GCC) and `clang++ --target=riscv64-unknown-elf` (LLVM) are available from Stage 0**, inherited directly from [`xv6-c-cmake`](../xv6-c-cmake)'s build system (see ADR 0002) rather than choosing one compiler up front and revisiting later.

Rationale for not picking just one:
- `xv6-c-cmake` exists specifically to answer "GCC or LLVM for kernel dev" empirically (build time, size, diagnostics) rather than by a priori argument — reusing its build system means this track gets that answer for free instead of re-litigating the question in C++ terms
- Both toolchains target the `elf` (bare-metal) ABI, so QEMU/GDB setup is directly comparable across tracks either way
- `riscv64-unknown-elf-gdb` debugs either toolchain's output — no separate debugger story per compiler

**Default for day-to-day work:** follow `xv6-c-cmake`'s Stage 2 decision (`xv6-c-cmake/docs/adr/0003-gcc-vs-llvm-decision.md`) unless C++26 feature support specifically argues otherwise (Clang has historically tracked new C++ standards faster than GCC — worth rechecking once this track reaches features from later stages that actually need it). If C++26 support forces a different default than what `xv6-c-cmake` picked for C, write that reasoning into a follow-up ADR rather than silently diverging.

**Build system:** CMake + Ninja, inherited from Stage 0 — see ADR 0002.

## Consequences

- Both Homebrew `riscv-gnu-toolchain` and Homebrew `llvm` are required dependencies (installed automatically by `post-create.sh`)
- `toolchain/gcc-<ver>/` and `toolchain/llvm-<ver>/` both exist side by side, same as `xv6-c-cmake` — no single `toolchain/current` pointer, CMake's `-DTOOLCHAIN=` flag selects explicitly
- GDB binary: `riscv64-unknown-elf-gdb`, shared across both toolchains
