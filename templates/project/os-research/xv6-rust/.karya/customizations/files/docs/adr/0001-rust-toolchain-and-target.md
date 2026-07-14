# ADR 0001 — Rust Toolchain and Target

**Date:** (set when project is created)
**Status:** Accepted

## Context

xv6-rust needs a Rust toolchain and compilation target that:

1. Produces bare-metal RISC-V ELF binaries (`no_std`, `no_main`, no OS underneath)
2. Can share a QEMU + GDB setup with the C and C++26 tracks for direct comparison
3. Works on macOS (primary dev machine) and Linux
4. Gives enough language surface for the idiomatic-Rust goals throughout this track (const generics, traits, `core::fmt`) without requiring unstable features that are likely to churn

## Decision

**Target:** `riscv64imac-unknown-none-elf` — **not** `riscv64gc-unknown-none-elf`.

Rationale:
- A kernel has no business touching floating point in its core paths — `gc` (general + compressed, includes the `F`/`D` float extensions) buys nothing here and adds a real cost: any FP use forces the kernel to save/restore FP register state on every context switch, or carefully forbid FP everywhere and hope nothing pulls it in transitively. `imac` (integer, multiply, atomic, compressed) has no float extension, so the problem doesn't exist.
- `riscv64imac-unknown-none-elf` has better Rust target-tier support than `riscv64gc-unknown-none-elf` for `no_std` work — `core` is available without `-Z build-std`, which is what makes stable Rust viable here (see below).

**Toolchain:** `rustc` **stable**, installed via `rustup` — not nightly.

Rationale:
- With `riscv64imac-unknown-none-elf`'s tier support, `core` doesn't need `-Z build-std`, removing the main reason to require nightly
- Avoids nightly-toolchain churn risk entirely — a real concern for a project developed across two machines over a long timeline
- **Revisit if** a stage genuinely needs a nightly-only feature (e.g. a specific `alloc` capability at Stage 6) — cross that bridge with its own ADR when it happens, don't pre-emptively take on nightly risk now

**Panic strategy:** `panic = "abort"` (no unwinding — standard for `no_std` kernels; matches the C/C++ tracks having no exception support).

## Alternatives Considered

- **`riscv64gc-unknown-none-elf` + nightly:** the more "standard-looking" choice, but pulls in float support the kernel doesn't want and forces nightly for `build-std`. Rejected.
- **Custom target JSON:** more control, but no known requirement `riscv64imac-unknown-none-elf`'s built-in target doesn't already satisfy. Rejected; will add if a later stage hits a wall.

## Consequences

- `rustup target add riscv64imac-unknown-none-elf` (stable toolchain) is the required setup step (automated in `post-create.sh`)
- Any code that would need floating point (there shouldn't be any in a kernel) is a hard compile error, not a runtime surprise — treat that as a feature, not a limitation to work around
- `toolchain/current/` carries `cargo`/`rustc`/`rust-objdump`/`rust-objcopy` alongside the shared `riscv64-unknown-elf-gdb`, same symlink-farm pattern as `xv6-c`
