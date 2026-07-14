# xv6-c — AI Guidelines

C reference track. Stays in C, stays on GNU Make, frozen after Stage 0. Purpose: clean modernised-toolchain baseline that [`xv6-cpp`](../xv6-cpp) and [`xv6-rust`](../xv6-rust) reimplement against — see `STAGES.md` for this track's own (single-stage) staging, and [`../docs/agentic-workflow.md`](../docs/agentic-workflow.md) for the process each stage follows.

Build-system exploration (CMake+Ninja, GCC-vs-LLVM benchmarking) is deliberately **not** this project's job — that's [`xv6-c-cmake`](../xv6-c-cmake), a separate sibling. Don't add CMake, don't add a second compiler here even if it seems convenient; keep this track boring and stable.

## Build

```bash
cd kernel/xv6-riscv
make TOOLPREFIX=$(pwd)/../../toolchain/current/riscv64-unknown-elf-
make qemu    # Ctrl-a x to exit
make qemu-gdb
```

## Constraints

- C only — no C++ introduced at any stage
- Makefile reads TOOLPREFIX from `toolchain/current/` (not system PATH)
- `-ffreestanding -nostdlib -fno-stack-protector` must remain
- Stage discipline: only toolchain/build changes, no source modernisation
