# ADR 0001 — CMake + Ninja as Build System

**Date:** (set when project is created)
**Status:** Accepted

## Context

This project's whole purpose is comparing two compilers on identical source. GNU Make can technically do this (separate `Makefile.gcc`/`Makefile.llvm`, or `TOOLPREFIX`/`CC` overrides), but it has real friction for this specific job:
- No built-in notion of parallel, isolated build directories for two toolchains — juggling object-file staleness between a GCC build and an LLVM build in the same tree invites subtle bugs (stale `.o` from the wrong compiler silently reused)
- No `compile_commands.json` generation, so clangd/IntelliSense can't reliably follow whichever toolchain is "current"
- Toolchain switching via flags/env vars is easy to get subtly wrong; a build-directory-per-toolchain model (which CMake gives for free) is harder to mess up

## Decision

**CMake + Ninja**, with **one build directory per toolchain** (`build/` for GCC, `build-llvm/` for LLVM), selected via `-DTOOLCHAIN=gcc|llvm`.

- `CMakeLists.txt` and `cmake/riscv64-elf-{gcc,llvm}.cmake` are added *inside* `kernel/xv6-riscv/`, alongside the untouched `.c`/`.h` files — this is the project's own private mirror (not upstream), so adding build infrastructure here doesn't touch the source itself
- The original `Makefile` is left in place as a fallback/reference until Stage 2 confirms the CMake build is a full behavioral match
- Each toolchain gets its own build directory, so there's never a question of which compiler produced which `.o` file — `build/` is unambiguously GCC's, `build-llvm/` is unambiguously LLVM's
- `scripts/build.sh <gcc|llvm>` wraps the CMake invocation so day-to-day usage never needs to remember which build directory maps to which toolchain

## Consequences

- Two full build directories exist side by side (more disk, trivial cost) rather than one directory that gets reconfigured back and forth
- `compile_commands.json` exists per build directory — clangd/VS Code should point at whichever one matches what you're currently working on
- No Makefile compatibility shim needed elsewhere — `scripts/build.sh`/`run.sh`/`debug.sh` are the only entry points documented to contributors
