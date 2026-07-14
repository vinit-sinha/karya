# xv6-rust — Reimplementation Stages

This is a **reimplementation**, not a port: `kernel/xv6-riscv/` (private mirror of `mit-pdos/xv6-riscv`, and [`xv6-c`](../xv6-c)'s own toolchain-modernized build of it) is a read-only reference for *what the kernel needs to do*, not source to mechanically transform. Unlike C++, Rust has no compiler-compatibility bridge to C at all — every stage designs and writes idiomatic Rust from the start, there is no "port it ugly, refactor later" intermediate.

End goal: a fully idiomatic Rust RISC-V kernel, built with `cargo`, debuggable in QEMU, behaviorally equivalent to xv6 subsystem by subsystem.

Each stage below is worked through the six-phase process in [`../docs/agentic-workflow.md`](../docs/agentic-workflow.md) — this file is the backlog, that doc is the process. "Requirements Gathering" for a stage means reading the corresponding xv6 C source as the behavioral spec; "Design" means deciding the idiomatic Rust shape independently of how the C does it. Stage numbering and subsystem boundaries are shared with [`xv6-cpp/STAGES.md`](../xv6-cpp/STAGES.md) so the two tracks stay comparable.

Target: `riscv64imac-unknown-none-elf` (bare-metal, `no_std`) on **stable** Rust — see `docs/adr/0001-rust-toolchain-and-target.md` for why (no floating point needed in a kernel, better target-tier support than `riscv64gc`, avoids nightly churn).

---

## Stage 0 — Environment Bring-up
**Branch:** `stage0/environment-bringup`
**Goal:** Toolchain, build system, and QEMU/GDB all work, proven by a minimal hand-written kernel — no xv6 logic reimplemented yet.

- [ ] `rustup` stable + `riscv64imac-unknown-none-elf` target installed
- [ ] A `#![no_std] #![no_main]` binary that sets up a stack and prints over UART boots under `qemu-system-riscv64 -machine virt -bios none -kernel ... -m 128M -smp 3 -nographic`, same flags as the C and C++ tracks for direct comparability
- [ ] GDB attach works (`riscv64-unknown-elf-gdb`, `-s -S` QEMU flags), can set a breakpoint at the entry point
- [ ] Cargo project structure in place (`Cargo.toml` targeting `riscv64imac-unknown-none-elf`, `linker.ld` wired via `.cargo/config.toml`, `scripts/build.sh`/`run.sh`/`debug.sh` wrap `cargo build` / QEMU / QEMU+GDB using `toolchain/current/cargo` — no bare `rustc` calls day-to-day), VS Code + rust-analyzer configured

---

## Stage 1 — Boot & Entry
**Branch:** `stage1/boot-entry`
**Goal:** Idiomatic boot sequence: entry point, trap/exception vector table, machine-mode → supervisor-mode switch.

Reference: `kernel/xv6-riscv/kernel/entry.S`, `start.c`, `kernelvec.S` — read for *what* has to happen, not how the C/assembly expresses it.

- [ ] Boots to a `kmain`-equivalent entry point in supervisor mode
- [ ] Trap vector installed (`asm!`/naked-function boundary, kept small and documented), unhandled traps report cause/location instead of silently hanging
- [ ] No process, memory, or scheduling concepts yet — this stage is boot plumbing only

---

## Stage 2 — Core Primitives
**Branch:** `stage2/core-primitives`
**Goal:** Synchronization and a physical memory allocator — the primitives every later subsystem depends on.

Reference: `kernel/xv6-riscv/kernel/spinlock.c`, `kalloc.c`, `printf.c`, `uart.c`, `console.c`.

- [ ] `SpinlockGuard` — RAII lock guard, no manual lock/unlock pairs anywhere above this layer
- [ ] Physical page allocator (freelist-based, matching xv6's granularity) with a typed physical-address newtype, not raw `usize`
- [ ] UART/console driver sufficient for kernel logging via `core::fmt` (no `println!` — no standard library; write to UART MMIO directly)
- [ ] `const fn` / const generics for compile-time constants (page size, memory layout) — no `macro_rules!` where a `const fn` would do

---

## Stage 3 — Virtual Memory
**Branch:** `stage3/virtual-memory`
**Goal:** Page tables and address space management.

Reference: `kernel/xv6-riscv/kernel/vm.c`.

- [ ] Typed virtual/physical address newtypes (no implicit conversion between them)
- [ ] Page table walk/map/unmap with the same semantics as xv6's `walk()`/`mappages()`, expressed idiomatically (`Result<T, E>` instead of negative sentinel returns)
- [ ] Kernel page table installed; identity/offset mappings match xv6's memory layout so QEMU device MMIO still lines up

---

## Stage 4 — Processes & Scheduling
**Branch:** `stage4/proc-scheduling`
**Goal:** Process table, context switch, scheduler.

Reference: `kernel/xv6-riscv/kernel/proc.c`, `swtch.S`.

- [ ] Process control block designed idiomatically (not a 1:1 struct copy) — lean on ownership/lifetime where it replaces manual bookkeeping C needs
- [ ] Context switch (`unsafe`/naked-asm boundary, kept small and documented — the `unsafe` ground rule in `CLAUDE.md` still applies)
- [ ] Round-robin scheduler behaviorally equivalent to xv6's

---

## Stage 5 — Traps & System Calls
**Branch:** `stage5/traps-syscalls`
**Goal:** User/kernel trap handling and syscall dispatch.

Reference: `kernel/xv6-riscv/kernel/trap.c`, `syscall.c`, `sysproc.c`.

- [ ] Syscall dispatch via static dispatch (traits/generics resolved at compile time) over a runtime match where practical, per the "prefer compile-time dispatch" ground rule
- [ ] Timer interrupts drive preemption
- [ ] A minimal user program can make a syscall and get a result back

---

## Stage 6 — File System & Devices
**Branch:** `stage6/fs-devices`
**Goal:** Persistent storage and the virtio disk driver.

Reference: `kernel/xv6-riscv/kernel/fs.c`, `bio.c`, `log.c`, `virtio_disk.c`.

**Open design question, resolve via ADR before starting:** stay on-disk-format-compatible with xv6's `mkfs` (lets you reuse xv6's disk images and tooling, and cross-check against `xv6-cpp`) vs. design your own layout. Either is fine — write the decision down; ideally match whatever `xv6-cpp/STAGES.md` Stage 6 decides, for comparability.

- [ ] Buffer cache, logging/crash-recovery layer, inode layer — idiomatic shape, functionally equivalent
- [ ] virtio disk driver
- [ ] A file can be created, written, read back, and survive a reboot in QEMU

This is also the natural point to introduce a kernel allocator + `alloc` crate if the file system layer wants heap-backed collections — do it deliberately, behind an ADR, not implicitly.

---

## Stage 7 — Idiomatic Depth (open-ended)
**Branch:** `stage7/idiomatic-depth`
**Goal:** No fixed acceptance criteria — this is the ongoing research phase once the kernel is functionally whole.

Ideas to explore:
- Traits for interface contracts (`Lockable`, `Schedulable`) resolved via static dispatch, not `dyn Trait`, in hot paths (if not already established earlier)
- Const generics for compile-time-sized structures (fixed process tables, page tables)
- `core::fmt`-based structured logging refinements
- Async/await for I/O — genuinely open research, not a requirement

---

## Branch convention

```
stage0/environment-bringup
stage1/boot-entry
stage2/core-primitives
stage3/virtual-memory
stage4/proc-scheduling
stage5/traps-syscalls
stage6/fs-devices
stage7/idiomatic-depth        ← open-ended, ongoing
```

Merge each stage branch to `master` when its acceptance criteria are met. Before switching machines mid-stage, `karya workstate save` — see [`../docs/agentic-workflow.md`](../docs/agentic-workflow.md) for when to checkpoint.
