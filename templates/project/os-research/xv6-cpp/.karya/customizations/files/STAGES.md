# xv6-cpp — Reimplementation Stages

This is a **reimplementation**, not a port: `kernel/xv6-riscv/` (private mirror of `mit-pdos/xv6-riscv`, and [`xv6-c`](../xv6-c)'s own toolchain-modernized build of it) is a read-only reference for *what the kernel needs to do*, not source to mechanically transform. Every stage designs and writes idiomatic C++26 from the start — there is no "make it compile as C++ first, clean it up later" intermediate.

End goal: a fully idiomatic C++26 RISC-V kernel, built with CMake+Ninja, debuggable in QEMU, behaviorally equivalent to xv6 subsystem by subsystem.

Each stage below is worked through the six-phase process in [`../docs/agentic-workflow.md`](../docs/agentic-workflow.md) — this file is the backlog, that doc is the process. "Requirements Gathering" for a stage means reading the corresponding xv6 C source as the behavioral spec; "Design" means deciding the idiomatic C++26 shape independently of how the C does it. Stage numbering and subsystem boundaries are shared with [`xv6-rust/STAGES.md`](../xv6-rust/STAGES.md) so the two tracks stay comparable.

---

## Stage 0 — Environment Bring-up (bootstrapped from xv6-c-cmake)
**Branch:** `stage0/environment-bringup`
**Goal:** Toolchain, build system, and QEMU/GDB all work, proven by a minimal hand-written kernel — no xv6 logic reimplemented yet. Don't design this build system from scratch — pull it.

- [ ] Copy [`xv6-c-cmake`](../xv6-c-cmake)'s `CMakeLists.txt` and `cmake/riscv64-elf-{gcc,llvm}.cmake` as the starting point (see `docs/adr/0002-cmake-ninja-build-system.md`) — that project already answered "how do we build this kernel with CMake+Ninja under both GCC and LLVM," don't re-derive it
- [ ] Retarget the copied CMake files from C to C++26: `riscv64-unknown-elf-g++`/`clang++ --std=c++26` instead of the C compilers, `-ffreestanding -nostdlib -fno-exceptions -fno-rtti` added
- [ ] Both toolchains build a `-ffreestanding -nostdlib -fno-exceptions -fno-rtti` "hello kernel" (C++, not C) that prints over UART and spins — `build/` for GCC, `build-llvm/` for LLVM, same directory-per-toolchain convention as `xv6-c-cmake`
- [ ] Boots under `qemu-system-riscv64 -machine virt -bios none -kernel ... -m 128M -smp 3 -nographic`, same flags as the C and Rust tracks for direct comparability
- [ ] GDB attach works (`riscv64-unknown-elf-gdb`, `-s -S` QEMU flags), can set a breakpoint at the entry point
- [ ] `compile_commands.json` generated automatically → clangd/VS Code IntelliSense works
- [ ] Which toolchain (GCC or LLVM) becomes this track's *default* for day-to-day work: follow `xv6-c-cmake`'s Stage 2 decision (`xv6-c-cmake/docs/adr/0003-gcc-vs-llvm-decision.md`) unless there's a C++26-specific reason to diverge — if there is, write that reasoning into this track's own ADR rather than silently picking differently

---

## Stage 1 — Boot & Entry
**Branch:** `stage1/boot-entry`
**Goal:** Idiomatic boot sequence: entry point, trap/exception vector table, machine-mode → supervisor-mode switch.

Reference: `kernel/xv6-riscv/kernel/entry.S`, `start.c`, `kernelvec.S` — read for *what* has to happen (stack setup, CSR configuration, mode switch, initial trap vector) not *how* the assembly/C expresses it.

- [ ] Boots to `kmain()`-equivalent entry point in supervisor mode
- [ ] Trap vector installed, unhandled traps report cause/location instead of silently hanging
- [ ] No process, memory, or scheduling concepts yet — this stage is boot plumbing only

**Design considerations:** how much of entry needs to stay raw assembly (linked via a small `.S` file) vs. what can move into typed C++ immediately — write this decision into an ADR if it's non-obvious.

---

## Stage 2 — Core Primitives
**Branch:** `stage2/core-primitives`
**Goal:** Synchronization and a physical memory allocator — the primitives every later subsystem depends on.

Reference: `kernel/xv6-riscv/kernel/spinlock.c`, `kalloc.c`, `printf.c`, `uart.c`, `console.c`.

- [ ] Lock type with RAII acquire/release (`SpinlockGuard`), no manual lock/unlock pairs anywhere above this layer
- [ ] Physical page allocator (freelist-based, matching xv6's granularity) with a typed physical-address wrapper, not raw `uintptr_t`
- [ ] UART/console driver sufficient for kernel logging
- [ ] `constexpr` for compile-time constants (page size, memory layout) instead of `#define`

---

## Stage 3 — Virtual Memory
**Branch:** `stage3/virtual-memory`
**Goal:** Page tables and address space management.

Reference: `kernel/xv6-riscv/kernel/vm.c`.

- [ ] Typed virtual/physical address newtypes (no implicit conversion between them)
- [ ] Page table walk/map/unmap with the same semantics as xv6's `walk()`/`mappages()`, expressed idiomatically (e.g. `std::expected`-style error returns instead of negative sentinel returns)
- [ ] Kernel page table installed; identity/offset mappings match xv6's memory layout so QEMU device MMIO still lines up

---

## Stage 4 — Processes & Scheduling
**Branch:** `stage4/proc-scheduling`
**Goal:** Process table, context switch, scheduler.

Reference: `kernel/xv6-riscv/kernel/proc.c`, `swtch.S`.

- [ ] Process control block designed idiomatically (not a 1:1 struct copy) — consider what ownership/lifetime C++ gives you that C's manual `struct proc[NPROC]` doesn't
- [ ] Context switch (raw asm boundary, kept small and documented)
- [ ] Round-robin scheduler behaviorally equivalent to xv6's

---

## Stage 5 — Traps & System Calls
**Branch:** `stage5/traps-syscalls`
**Goal:** User/kernel trap handling and syscall dispatch.

Reference: `kernel/xv6-riscv/kernel/trap.c`, `syscall.c`, `sysproc.c`.

- [ ] Syscall dispatch — consider a compile-time-generated dispatch table (template/`consteval`) over a runtime switch, per the "prefer compile-time dispatch" ground rule
- [ ] Timer interrupts drive preemption
- [ ] A minimal user program can make a syscall and get a result back

---

## Stage 6 — File System & Devices
**Branch:** `stage6/fs-devices`
**Goal:** Persistent storage and the virtio disk driver.

Reference: `kernel/xv6-riscv/kernel/fs.c`, `bio.c`, `log.c`, `virtio_disk.c`.

**Open design question, resolve via ADR before starting:** stay on-disk-format-compatible with xv6's `mkfs` (lets you reuse xv6's disk images and tooling) vs. design your own layout. Either is fine — write the decision down; ideally match whatever `xv6-rust/STAGES.md` Stage 6 decides, for comparability.

- [ ] Buffer cache, logging/crash-recovery layer, inode layer — idiomatic shape, functionally equivalent
- [ ] virtio disk driver
- [ ] A file can be created, written, read back, and survive a reboot in QEMU

---

## Stage 7 — Idiomatic Depth (open-ended)
**Branch:** `stage7/idiomatic-depth`
**Goal:** No fixed acceptance criteria — this is the ongoing research phase once the kernel is functionally whole.

Ideas to explore:
- `std::expected` throughout instead of negative-return-code conventions (if not already adopted earlier)
- Concepts for interface contracts (`Lockable`, `Schedulable`)
- Compile-time kernel configuration via `consteval`
- Modules (C++20/26) for subsystem boundaries
- `std::span` for safe buffer passing
- Coroutines for async I/O — genuinely open research, not a requirement

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
