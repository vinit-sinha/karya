# xv6-c++ — Modernisation Stages

Source: `kernel/xv6-riscv/` (private fork of mit-pdos/xv6-riscv)  
End goal: A fully C++26 RISC-V kernel, built with modern toolchain and debuggable in QEMU.

---

## Stage 0 — xv6 in C, New Toolchain  
**Branch:** `stage0/c-toolchain`  
**Goal:** Verify the upstream xv6 builds and runs correctly under the new cross-compiler and QEMU setup, without changing any source.

- [ ] `make qemu` boots xv6 shell in QEMU
- [ ] `make qemu-gdb` starts GDB stub; GDB connects and can set breakpoints
- [ ] Cross-compiler and GDB available inside the kernel (user programs can be built)
- [ ] Implement MIT 6.S081 Lab 1 (util) using this toolchain as a baseline sanity check

**Notes:**
- Toolchain: `riscv64-unknown-elf-gcc` / `riscv64-unknown-elf-gdb` (from Homebrew `riscv-gnu-toolchain`)
- QEMU: `-machine virt -bios none -kernel kernel -m 128M -smp 3 -nographic`
- GDB stub via `make qemu-gdb` — connects on `localhost:$(GDBPORT)` (port derived from UID)
- Upstream Makefile already handles TOOLPREFIX detection — should just work

---

## Stage 1 — Build Toolchain Modernisation  
**Branch:** `stage1/build-toolchain`  
**Goal:** Choose and adopt the best modern build system for the C++26 end state.

**Decision point:** GNU Make (current) vs CMake + Ninja  
- CMake + Ninja is the right call: language-server integration (clangd), incremental builds,
  better IDE support, and industry standard for C++ kernel/embedded work
- Keep GNU Make as a thin wrapper (`make` → `cmake --build`) for muscle-memory compatibility

- [ ] CMakeLists.txt replaces Makefile as the primary build definition
- [ ] `cmake -G Ninja -B build && cmake --build build` produces the kernel ELF
- [ ] QEMU run/debug targets preserved (either in CMake or thin Makefile shim)
- [ ] clangd-compatible `compile_commands.json` generated automatically

---

## Stage 2 — C → C++ Compiler Switch  
**Branch:** `stage2/cxx-compiler`  
**Goal:** Compile all `.c` files with `g++` instead of `gcc`, C standard unchanged, minimal source changes only.

C++ is mostly source-compatible with C but has stricter rules. Expected changes:
- Explicit casts where C allows implicit void* conversion
- Remove VLAs (variable-length arrays — not in standard C++)
- `struct` keyword not required in declarations — remove or leave (both valid)
- `inline` for functions defined in headers (avoid ODR violations)
- Function prototypes that differ from definitions

**Acceptance:** All Stage 0 tests still pass. No new functionality.

---

## Stage 3 — Source Modernisation (.c → .cpp)  
**Branch:** `stage3/rename-and-refactor`  
**Goal:** Rename files, adopt C++ idioms where straightforward. Code still reads like C, but uses C++ where it's a clear improvement.

Changes in scope:
- Rename `*.c` → `*.cpp`, `*.h` → adjust includes
- Namespaces for subsystems (`kernel::`, `fs::`, `proc::`)
- Replace `#define` constants with `constexpr`
- Replace C-style casts with `static_cast` / `reinterpret_cast`
- Replace `typedef struct` patterns with `struct` + type alias
- RAII wrappers for spinlocks (`SpinlockGuard`)

**Out of scope for this stage:** templates, exceptions, STL, virtual dispatch.

---

## Stage 4 — C++26 Kernel  
**Branch:** `stage4/cpp26`  
**Goal:** Rewrite/refactor to pure idiomatic C++26. This is the open-ended research phase.

Ideas to explore:
- `std::expected` for error propagation instead of negative return codes
- Compile-time kernel configuration with `consteval`
- Concepts for interface contracts (e.g. `Lockable`, `Schedulable`)
- Modules (C++20) for subsystem boundaries
- Coroutines for async I/O in the kernel?
- `std::span` for safe buffer passing
- Formatted output via `std::format` (or freestanding equivalent)

---

## Branch convention

```
stage0/c-toolchain          ← Stage 0 work
stage0/lab1-util            ← Stage 0 verification (MIT lab 1)
stage1/build-toolchain      ← Stage 1 work
stage2/cxx-compiler         ← Stage 2 work
stage3/rename-and-refactor  ← Stage 3 work
stage4/cpp26                ← Stage 4 work (long-running)
```

Merge each stage branch to `master` when the acceptance criteria are met.
