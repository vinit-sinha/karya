# xv6-c — Stages

The C reference track. Stays in C, stays on GNU Make, throughout. Its purpose
is to provide a clean, modernised-toolchain baseline against which all other
tracks are compared — nothing more.

Build-system and dual-toolchain (GCC vs LLVM) exploration happens in the
sibling project [`xv6-c-cmake`](../xv6-c-cmake), not here — see that
project's `STAGES.md` for why it's split out on its own rather than being a
later stage of this track.

---

## Stage 0 — Verify Build with New Toolchain
**Branch:** `stage0/c-toolchain`

- [ ] `make qemu` boots xv6 shell with `riscv64-unknown-elf-gcc` from `toolchain/current/`
- [ ] `make qemu-gdb` starts GDB stub; `riscv64-unknown-elf-gdb` connects
- [ ] Makefile reads `TOOLPREFIX` from `toolchain/current/` (not system PATH)
- [ ] All warnings treated as errors; no suppressions beyond upstream's

---

## This track's role

This track is frozen after Stage 0 — no build-system changes, no compiler
switching, no language evolution. It receives only what's needed to keep it
booting on a current toolchain. All build-system experimentation happens in
[`xv6-c-cmake`](../xv6-c-cmake); all language evolution happens in the
reimplementation tracks — [`xv6-cpp`](../xv6-cpp) and
[`xv6-rust`](../xv6-rust) — which treat this track's `kernel/xv6-riscv/` (and
this track's own build) as their behavioral reference, not as source to
transform.

The future `kernel-bench` project uses this track's built kernel as one of
its baselines.

Stage 0 is worked through the six-phase process in
[`../docs/agentic-workflow.md`](../docs/agentic-workflow.md).
