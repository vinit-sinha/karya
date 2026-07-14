# ADR 0002 — Dual-Toolchain Strategy (GCC + LLVM, Side by Side)

**Date:** (set when project is created)
**Status:** Accepted — decision on *which one wins* is a separate, later ADR (0003, Stage 2)

## Context

We want to know whether GCC or LLVM/Clang is the better compiler for kernel development on this project (and, by extension, for [`xv6-cpp`](../xv6-cpp), which inherits this build system). Answering that requires both toolchains actually building the *same* source and being comparable on equal footing — not a one-time spot check.

## Decision

Install and keep **both toolchains permanently side by side** under `toolchain/`, rather than the single-active `toolchain/current` pattern every other track uses.

- **GCC:** `riscv64-unknown-elf-gcc`/`g++` from the `riscv-software-src/riscv` Homebrew tap — the same toolchain every other track already uses, so results are comparable across the whole `os-research` program, not just within this project
- **LLVM:** Homebrew's `llvm` formula (keg-only) — a single `clang` binary that cross-compiles to many targets via `--target=riscv64-unknown-elf`, no separate "riscv64-unknown-elf-clang" package needed. Paired with `ld.lld` for linking (GNU `ld` linker-script compatibility with `lld` is generally good but gets explicitly verified in Stage 1, not assumed). **`lld` is its own Homebrew formula**, separate from `llvm` (and, unlike `llvm`, linked directly onto `PATH` rather than keg-only) — don't assume `ld.lld` lives inside the `llvm` keg's `bin/`, it doesn't
- CMake toolchain files (`cmake/riscv64-elf-gcc.cmake`, `cmake/riscv64-elf-llvm.cmake`) select between them; both are always installed, so switching is a `-DTOOLCHAIN=` flag, never a reinstall

**Alternative considered:** install one toolchain at a time, benchmark, uninstall, install the other.
Rejected — brittle (easy to contaminate a "clean" measurement with leftover state), and it makes re-running the comparison later (e.g. after a new LLVM release) much more expensive than it needs to be.

## Consequences

- `post-create.sh` installs both toolchains unconditionally — expect Homebrew to pull two nontrivial packages (`riscv-gnu-toolchain`, `llvm`) the first time this project is set up
- Every future stage/session automatically has both compilers available with no re-setup — good for the "revisit if a new LLVM release changes the calculus" note in `STAGES.md`
- Diverges from the `toolchain/current` single-pointer convention used elsewhere in `os-research` — documented here specifically so it isn't "fixed" to match the other tracks by someone who hasn't read this ADR
