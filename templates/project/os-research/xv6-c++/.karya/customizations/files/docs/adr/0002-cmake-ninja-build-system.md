# ADR 0002 — CMake + Ninja as Build System (Stage 1)

**Date:** (set when decision is implemented)  
**Status:** Proposed — implement in Stage 1

## Context

GNU Make is sufficient for Stage 0 but has friction for C++ at scale:
- No automatic dependency scanning (requires manual `-MMD` flags)
- No `compile_commands.json` generation (needed for clangd / IntelliSense)
- Non-trivial to express cross-compilation targets cleanly
- IDE integration is ad-hoc

## Decision

Replace the primary build definition with **CMake + Ninja** in Stage 1.

- `CMakeLists.txt` defines all targets, compiler flags, and cross-compilation settings
- Ninja is the generator: `cmake -G Ninja -B build && cmake --build build`
- CMake generates `compile_commands.json` automatically → clangd works out of the box
- A thin `Makefile` shim remains at the root for muscle-memory compatibility:
  ```makefile
  all:
      cmake --build build
  qemu:
      ./scripts/run.sh
  clean:
      cmake --build build --target clean
  ```
- The cross-compilation toolchain file (`cmake/riscv64-elf.cmake`) sets:
  ```cmake
  set(CMAKE_SYSTEM_NAME Generic)
  set(CMAKE_SYSTEM_PROCESSOR riscv64)
  set(CMAKE_C_COMPILER   riscv64-unknown-elf-gcc)
  set(CMAKE_CXX_COMPILER riscv64-unknown-elf-g++)
  ```

## Consequences

- Stage 1 work is purely build infrastructure; no source changes
- After Stage 1, `cmake --build build` is the canonical build command
- clangd and VS Code C++ IntelliSense work correctly with the generated compile_commands.json
