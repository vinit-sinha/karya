# xv6-c-cmake — AI Guidelines

## Project

Single question: **GCC or LLVM/Clang for kernel development on this project?** The C source is unmodified xv6 (same as [`xv6-c`](../xv6-c)) — this track changes only the build system (GNU Make → CMake + Ninja) and adds a second compiler, so the identical source can be built and benchmarked under both. See `STAGES.md` for the roadmap and `docs/agentic-workflow.md` (collection-level) for the process each stage follows.

**Do not modernize or idiomize the C source here.** That's explicitly out of scope — this project answers a toolchain question, not a language question. If you find yourself wanting to change `.c`/`.h` logic, stop; that work belongs in [`xv6-cpp`](../xv6-cpp) or [`xv6-rust`](../xv6-rust) instead.

## Kernel source

`kernel/xv6-riscv/` — private mirror of `mit-pdos/xv6-riscv`, and the actual buildable working copy (unlike `xv6-cpp`/`xv6-rust`, this track builds it directly, same as `xv6-c`). `CMakeLists.txt` and `cmake/*.cmake` live inside it, alongside the untouched `.c`/`.h` files and the original `Makefile` (kept as a fallback/reference until Stage 2 confirms CMake fully replaces it).

## Build

```bash
./scripts/build.sh gcc    # cmake -B build -DTOOLCHAIN=gcc && cmake --build build
./scripts/build.sh llvm   # cmake -B build-llvm -DTOOLCHAIN=llvm && cmake --build build-llvm
./scripts/run.sh gcc      # boot the GCC build in QEMU (Ctrl-a x to exit)
./scripts/run.sh llvm     # boot the LLVM build
./scripts/bench.sh        # build both, report the comparison (Stage 2)
```

## Toolchains

| Tool | GCC | LLVM |
|------|-----|------|
| Compiler | `riscv64-unknown-elf-gcc` (`toolchain/gcc-<ver>/`) | `clang --target=riscv64-unknown-elf` (`toolchain/llvm-<ver>/`) |
| Linker | `riscv64-unknown-elf-ld` | `ld.lld` |
| Objcopy/dump | `riscv64-unknown-elf-obj{copy,dump}` | `llvm-obj{copy,dump}` |
| Debugger | `riscv64-unknown-elf-gdb` (both — GDB debugs either toolchain's ELF output) | |

Both toolchains are installed and kept side by side under `toolchain/` — unlike the other tracks' `toolchain/current` (a single active pointer), this project needs both simultaneously, so CMake's `-DTOOLCHAIN=` flag selects the label directly rather than going through a mutable "current" symlink.

## What to keep in mind

- This is a **bare-metal RISC-V kernel** — same `-ffreestanding -nostdlib` constraints as every other track.
- Source parity matters more than build speed here — if GCC and LLVM builds ever produce *behaviorally* different kernels from the same source, that's a bug to chase down, not something to route around.
- Stage discipline: don't skip ahead to Stage 2 benchmarking before Stage 1's LLVM build actually boots.

## Git workflow

Follow karya's standard: feature branches off master, PR to merge.
Use the stage branch naming convention from STAGES.md.
`karya workstate save` auto-runs on push (post-push hook installed).
