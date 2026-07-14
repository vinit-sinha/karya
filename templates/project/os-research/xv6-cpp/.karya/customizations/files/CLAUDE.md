# xv6-cpp — AI Guidelines

## Project

Reimplementing xv6-riscv in idiomatic C++26, subsystem by subsystem. This is a **reimplementation, not a port**: xv6's C source is the behavioral spec, not source to mechanically transform — every stage designs and writes idiomatic C++26 from the start, there is no "compile as C++ first, clean up later" step.
See `STAGES.md` for the full roadmap and acceptance criteria per stage.

Reference baseline: [`kosh://project/os-research/xv6-c`](../xv6-c) — the modernized-toolchain C reference (see its own `STAGES.md`), cloned read-only into `kernel/xv6-riscv/` in this project (never built directly). When in doubt about what upstream actually does, check there rather than re-deriving from memory.

## Process

Each stage in `STAGES.md` is worked through the six-phase workflow in [`kosh://project/os-research`'s `docs/agentic-workflow.md`](../docs/agentic-workflow.md) (Requirements Gathering → Requirement Analysis → Planning → Design → Implementation → Testing, each with an iterate-then-review loop). Don't jump straight to Implementation on a new stage without at least a quick pass through Requirements/Analysis/Planning — the ADRs in `docs/adr/` are what Design produces for consequential decisions.

## Kernel source

`kernel/xv6-riscv/` — private mirror of `mit-pdos/xv6-riscv`, kept as a **read-only reference** for subsystem behavior. Never built directly; upstream changes can be fetched via the `upstream` remote (push blocked).

The actual C++26 kernel lives in `src/`, built with CMake+Ninja from Stage 0 onward — the build system is inherited from [`xv6-c-cmake`](../xv6-c-cmake), not designed independently. See `docs/adr/0001-cross-compiler-and-build-toolchain.md` and `docs/adr/0002-cmake-ninja-build-system.md`.

## Build

```bash
./scripts/build.sh gcc    # cmake -B build -DTOOLCHAIN=gcc && cmake --build build
./scripts/build.sh llvm   # cmake -B build-llvm -DTOOLCHAIN=llvm && cmake --build build-llvm
./scripts/run.sh gcc      # boot the GCC build in QEMU  (Ctrl-a x to exit)
./scripts/run.sh llvm     # boot the LLVM build
```

## Cross-compilers

Both GCC and LLVM are available side by side (not a single switchable `toolchain/current`) — same as [`xv6-c-cmake`](../xv6-c-cmake), for the same reason: keep both comparable rather than commit to one early.

| Tool | GCC | LLVM |
|------|-----|------|
| C++ compiler | `riscv64-unknown-elf-g++` (`toolchain/gcc-<ver>/`) | `clang++ --target=riscv64-unknown-elf` (`toolchain/llvm-<ver>/`) |
| Linker | `riscv64-unknown-elf-ld` | `ld.lld` |
| Debugger | `riscv64-unknown-elf-gdb` (both) | |

## What to keep in mind

- This is a **bare-metal RISC-V kernel**. No OS, no libc, no exceptions (until we explicitly add freestanding versions).
- The kernel runs in **machine mode** initially then drops to supervisor mode. No virtual memory until it's set up by the kernel itself.
- `-ffreestanding -nostdlib -fno-exceptions -fno-rtti` must remain set for kernel code.
- C++ standard library headers are NOT available in kernel context (no `<vector>`, no `<string>`). Freestanding headers (`<type_traits>`, `<concepts>`, `<utility>`, `<cstdint>`) are fine.
- When suggesting changes, always check whether the change is scoped to the current stage (see STAGES.md). Don't skip ahead.

## Git workflow

Follow karya's standard: feature branches off master, PR to merge.
Use the stage branch naming convention from STAGES.md.
`karya workstate save` auto-runs on push (post-push hook installed).
