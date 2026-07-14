# xv6-c-cmake

Answers one question: **GCC or LLVM/Clang for kernel development?** Same unmodified [xv6](https://github.com/mit-pdos/xv6-riscv) C source as [`xv6-c`](../xv6-c) — only the build system changes, from GNU Make to CMake + Ninja, with both compilers wired in side by side so they can be benchmarked head to head.

See **[STAGES.md](STAGES.md)** for the roadmap.

## Quick start

```bash
./scripts/build.sh gcc    # build with GCC
./scripts/build.sh llvm   # build with LLVM/Clang
./scripts/run.sh gcc      # boot the GCC build in QEMU  →  Ctrl-a x to exit
./scripts/run.sh llvm     # boot the LLVM build
./scripts/bench.sh        # build both, report the comparison
```

Or use VS Code: **Cmd+Shift+P → Tasks: Run Task**.

## Directory layout

```
xv6-c-cmake/
├── STAGES.md              ← roadmap: Stage 0 → 2
├── SETUP.md                ← environment status (generated on create)
├── CLAUDE.md                ← AI assistant guidelines
├── kernel/
│   └── xv6-riscv/             ← private mirror of mit-pdos/xv6-riscv — the actual build target
│       ├── kernel/              ← unmodified C kernel source
│       ├── CMakeLists.txt         ← added here, source stays untouched
│       ├── cmake/
│       │   ├── riscv64-elf-gcc.cmake
│       │   └── riscv64-elf-llvm.cmake
│       └── Makefile               ← original, kept as fallback/reference
├── toolchain/
│   ├── gcc-<ver>/              ← GCC toolchain symlinks
│   └── llvm-<ver>/               ← LLVM toolchain symlinks (both present at once, no "current")
├── docs/
│   └── adr/                        ← architecture decision records, including the eventual GCC-vs-LLVM decision
├── scripts/
│   ├── build.sh <gcc|llvm>           ← cmake+ninja wrapper
│   ├── run.sh <gcc|llvm>               ← starts QEMU
│   ├── debug.sh <gcc|llvm>               ← starts QEMU + GDB
│   └── bench.sh                            ← builds both, reports comparison (Stage 2)
└── work/                                     ← notes, benchmark results, writeups per stage
```

## Toolchains

`riscv64-unknown-elf-gcc`/`g++` from Homebrew `riscv-software-src/riscv` (`brew install riscv-gnu-toolchain`), and `clang`/`lld`/`llvm-*` from Homebrew `llvm` (`brew install llvm`, keg-only). Both installed automatically by project setup.

## Upstream

Fetch-only remote `upstream` tracks `https://github.com/mit-pdos/xv6-riscv.git`.
Push is blocked on `upstream`. All your work (the CMake files, not the original source) goes to `origin` (private GitHub repo).
