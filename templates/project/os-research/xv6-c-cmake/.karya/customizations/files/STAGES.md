# xv6-c-cmake — Stages

This track exists for exactly one question: **which toolchain should kernel
development on this project use, GCC or LLVM/Clang?** The C source is the
same xv6 source [`xv6-c`](../xv6-c) builds — untouched, no idioms, no
rewriting. Only the build system changes: GNU Make → CMake + Ninja, with a
`-DTOOLCHAIN=gcc|llvm` switch so the identical source builds under either
compiler and the two can be benchmarked head to head.

This is deliberately split out from [`xv6-c`](../xv6-c) rather than being a
later stage of that track — `xv6-c` stays boring and stable as the reference
baseline; this project is where build-system churn and a second compiler are
allowed to happen. See `xv6-c/STAGES.md` for why.

Once Stage 2 lands a decision, [`xv6-cpp`](../xv6-cpp) bootstraps its own
Stage 0 by copying this project's `CMakeLists.txt`/`cmake/` files rather than
building a CMake setup from scratch — see `xv6-cpp/STAGES.md`.

---

## Stage 0 — CMake + Ninja Bring-up (GCC)
**Branch:** `stage0/cmake-gcc`
**Goal:** Replace GNU Make with CMake + Ninja for the existing GCC toolchain. Source unchanged; behavior unchanged.

- [ ] `CMakeLists.txt` + `cmake/riscv64-elf-gcc.cmake` added inside `kernel/xv6-riscv/` (alongside the untouched `.c`/`.h` files and the original `Makefile`, which stays as a reference until Stage 2 confirms CMake fully replaces it)
- [ ] `cmake -G Ninja -B build -DTOOLCHAIN=gcc && cmake --build build` produces a kernel ELF using `toolchain/gcc-<ver>/riscv64-unknown-elf-*`
- [ ] Boots identically to the Make-built kernel under the same QEMU invocation used by every other track
- [ ] `compile_commands.json` generated → clangd/VS Code IntelliSense works
- [ ] `scripts/build.sh gcc` / `scripts/run.sh gcc` wrap this — no bare `cmake`/generator flags needed day to day

---

## Stage 1 — Add LLVM/Clang as a Second Toolchain
**Branch:** `stage1/cmake-llvm`
**Goal:** The *same* CMakeLists.txt builds the *same* unmodified source with Clang + lld instead of GCC.

- [ ] `cmake/riscv64-elf-llvm.cmake` toolchain file: `clang --target=riscv64-unknown-elf` matching upstream's `-march`/`-mabi`/`-mcmodel`, `ld.lld` as the linker, same `kernel.ld` linker script (verify lld's GNU-linker-script compatibility holds — flag as an ADR follow-up if it doesn't)
- [ ] `cmake -G Ninja -B build-llvm -DTOOLCHAIN=llvm && cmake --build build-llvm` produces a kernel ELF using `toolchain/llvm-<ver>/`
- [ ] Boots identically to both the Make-built and CMake+GCC-built kernels
- [ ] `scripts/build.sh llvm` / `scripts/run.sh llvm` work the same way Stage 0's did for `gcc`

**Acceptance:** both `build/` (gcc) and `build-llvm/` (llvm) exist side by side, both boot, from the same unmodified source tree.

---

## Stage 2 — Benchmark & Decide
**Branch:** `stage2/benchmark`
**Goal:** Produce an actual answer to "GCC or LLVM for this kernel," not just "both compile."

- [ ] `scripts/bench.sh` builds both, and reports at minimum: build time (clean build, both), kernel ELF / `.text` size, warning/diagnostic count
- [ ] Boot-time or instruction-count comparison in QEMU, if a reasonably cheap way to measure it exists — don't over-invest in benchmarking infrastructure for its own sake
- [ ] Findings written up as `docs/adr/0003-gcc-vs-llvm-decision.md` (Context/Decision/Alternatives/Consequences, per the standard ADR template) — this is the artifact [`xv6-cpp`](../xv6-cpp) and [`xv6-rust`](../xv6-rust) read when making their own toolchain calls

After Stage 2, this track's job is essentially done — it's not expected to track upstream xv6 changes indefinitely, just to have produced a decision. Revisit only if a toolchain question comes up again later (e.g. a new LLVM release changes the calculus).

---

## Branch convention

```
stage0/cmake-gcc
stage1/cmake-llvm
stage2/benchmark
```

Each stage is worked through the six-phase process in
[`../docs/agentic-workflow.md`](../docs/agentic-workflow.md).
