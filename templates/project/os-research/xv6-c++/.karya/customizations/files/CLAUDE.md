# xv6-c++ — AI Guidelines

## Project

Modernising the xv6-riscv teaching kernel from C to C++26, stage by stage.  
See `STAGES.md` for the full roadmap and acceptance criteria per stage.

## Kernel source

`kernel/xv6-riscv/` — private fork of `mit-pdos/xv6-riscv`.  
Upstream changes can be fetched via the `upstream` remote (push blocked).

## Build

```bash
cd kernel/xv6-riscv
make            # build kernel ELF
make qemu       # boot in QEMU  (Ctrl-a x to exit)
make qemu-gdb   # boot with GDB stub on localhost:$(GDBPORT)
```

After Stage 1: `cmake --build build` replaces `make`.

## Cross-compiler

| Tool | Binary |
|------|--------|
| C compiler   | `riscv64-unknown-elf-gcc` |
| C++ compiler | `riscv64-unknown-elf-g++` |
| Debugger     | `riscv64-unknown-elf-gdb` |
| Linker       | `riscv64-unknown-elf-ld` |

All from Homebrew `riscv-gnu-toolchain` tap.

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
