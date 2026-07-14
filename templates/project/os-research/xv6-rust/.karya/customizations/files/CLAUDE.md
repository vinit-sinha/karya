# xv6-rust — AI Guidelines

## Project

Reimplementing xv6-riscv in idiomatic Rust, subsystem by subsystem. This is a **reimplementation, not a port**: unlike C++, Rust has no compiler-compatibility bridge to C at all, so every stage designs and writes idiomatic Rust from the start — there is no "port it ugly, refactor later" intermediate.
See `STAGES.md` for the full roadmap and acceptance criteria per stage.

Reference baseline: [`kosh://project/os-research/xv6-c`](../xv6-c) — the modernized-toolchain C reference (see its own `STAGES.md`), cloned read-only into `kernel/xv6-riscv/` in this project (never built directly). When in doubt about what upstream actually does, check there rather than re-deriving from memory.

## Process

Each stage in `STAGES.md` is worked through the six-phase workflow in [`kosh://project/os-research`'s `docs/agentic-workflow.md`](../docs/agentic-workflow.md) (Requirements Gathering → Requirement Analysis → Planning → Design → Implementation → Testing, each with an iterate-then-review loop). Don't jump straight to Implementation on a new stage without at least a quick pass through Requirements/Analysis/Planning — the ADRs in `docs/adr/` are what Design produces for consequential decisions.

## Kernel source

`kernel/xv6-riscv/` — private mirror of `mit-pdos/xv6-riscv`, kept as a **read-only reference** for subsystem behavior (never built with Rust).
Upstream changes can be fetched via the `upstream` remote (push blocked).

The actual Rust kernel lives in `src/` as a Cargo package targeting bare-metal RISC-V — see `docs/adr/0001-rust-toolchain-and-target.md`.

## Build

```bash
./scripts/build.sh   # toolchain/current/cargo build --target riscv64imac-unknown-none-elf
./scripts/run.sh       # boot in QEMU  (Ctrl-a x to exit)
./scripts/debug.sh       # boot with GDB stub
```

## Toolchain

| Tool | Binary |
|------|--------|
| Rust toolchain | `rustc` (stable), `cargo` — via `toolchain/current/` |
| Target         | `riscv64imac-unknown-none-elf` |
| Debugger       | `riscv64-unknown-elf-gdb` (shared with the C/C++ tracks) |

## What to keep in mind

- This is a **bare-metal RISC-V kernel**: `#![no_std]`, `#![no_main]`, `panic = "abort"`. No heap/`alloc` until a stage explicitly introduces a kernel allocator.
- The kernel runs in **machine mode** initially then drops to supervisor mode, same as the C/C++ tracks. No virtual memory until the kernel sets it up itself.
- No standard library — no `println!`; write to UART MMIO directly via `core::fmt`.
- **Minimize `unsafe`.** Confine it to a small, explicitly documented HAL/boot layer; every `unsafe` block gets a `// SAFETY:` comment explaining why it's sound.
- **Prefer compile-time over runtime, and prefer both over macros.** Use `const fn`, const generics, and compile-time evaluation ahead of runtime computation; reach for a `const fn`/generic before reaching for `macro_rules!`.
- **Prefer static dispatch over dynamic dispatch** in kernel hot paths — generics/traits resolved at compile time, not `dyn Trait`, unless there's a concrete reason (e.g. a genuinely heterogeneous device list) documented in an ADR.
- When suggesting changes, always check whether the change is scoped to the current stage (see STAGES.md). Don't skip ahead — a subsystem's first implementation should already be idiomatic, not a placeholder to clean up in a later stage.

## Git workflow

Follow karya's standard: feature branches off master, PR to merge.
Use the stage branch naming convention from STAGES.md.
`karya workstate save` auto-runs on push (post-push hook installed).
