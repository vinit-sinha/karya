# ADR 0001 — Cross-compiler and Build Toolchain

**Date:** (set when project is created)  
**Status:** Accepted

## Context

xv6-riscv upstream uses GNU Make + `riscv64-unknown-elf-gcc`. We need to choose a cross-compiler and build system that:

1. Supports C (Stage 0) and eventually C++26 (Stage 4)
2. Produces bare-metal RISC-V ELF binaries (`-ffreestanding -nostdlib`)
3. Integrates well with QEMU for run and debug
4. Works on macOS (primary dev machine) and Linux

## Decision

**Compiler:** `riscv64-unknown-elf-gcc` / `riscv64-unknown-elf-g++` from the `riscv-software-src/riscv` Homebrew tap.

Rationale:
- Same toolchain prefix as upstream xv6 — Makefile works without changes in Stage 0
- Includes both `gcc` and `g++` targeting the `elf` (bare-metal) ABI
- Includes `gdb` for debugging
- Actively maintained by the RISC-V Software Collaboration

**Alternative considered:** LLVM/Clang with `--target=riscv64-unknown-elf`  
- Pro: Better C++26 support (Clang tracks the standard faster than GCC)  
- Con: Requires separate `lld` linker configuration; less tested for RISC-V bare-metal; GDB is separate  
- **Revisit at Stage 2** — if C++26 features we need aren't in GCC yet, switch to Clang

**Build system (Stage 0-1):** GNU Make (unchanged from upstream)  
**Build system (Stage 1+):** CMake + Ninja  
See ADR 0002.

## Consequences

- Homebrew `riscv-gnu-toolchain` is a required dependency
- `TOOLPREFIX = riscv64-unknown-elf-` is assumed throughout
- GDB binary: `riscv64-unknown-elf-gdb`
