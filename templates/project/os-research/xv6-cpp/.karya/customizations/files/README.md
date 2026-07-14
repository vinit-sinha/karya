# xv6-cpp

Reimplementing the [xv6-riscv](https://github.com/mit-pdos/xv6-riscv) teaching kernel in idiomatic C++26, subsystem by subsystem. xv6's C source is a behavioral reference here, not source to port — see [STAGES.md](STAGES.md) for why and for the roadmap.

Build system (CMake+Ninja, GCC and LLVM side by side) is inherited from [`xv6-c-cmake`](../xv6-c-cmake), not designed independently — see that project if you're wondering why the build looks the way it does.

## Quick start

```bash
./scripts/build.sh gcc    # build with GCC
./scripts/build.sh llvm   # build with LLVM/Clang
./scripts/run.sh gcc      # boot xv6-cpp in QEMU  →  Ctrl-a x to exit
./scripts/run.sh llvm     # boot the LLVM build
```

Or use VS Code: **Cmd+Shift+P → Tasks: Run Task**.

## Directory layout

```
xv6-cpp/
├── STAGES.md              ← roadmap: Stage 0 → 7
├── SETUP.md               ← environment status (generated on create)
├── CLAUDE.md              ← AI assistant guidelines
├── src/                   ← the C++26 kernel (CMake project)
├── kernel/
│   └── xv6-riscv/         ← private mirror of mit-pdos/xv6-riscv — reference only, not built
│       ├── kernel/        ← C kernel source (read for reference)
│       ├── user/          ← C user programs (read for reference)
│       └── Makefile
├── toolchain/
│   ├── gcc-<ver>/         ← GCC toolchain symlinks
│   └── llvm-<ver>/        ← LLVM toolchain symlinks (both present at once, no "current")
├── docs/
│   └── adr/               ← architecture decision records
├── scripts/
│   ├── build.sh <gcc|llvm>    ← cmake+ninja wrapper
│   ├── run.sh <gcc|llvm>       ← starts QEMU
│   └── debug.sh <gcc|llvm>      ← starts QEMU + GDB
└── work/                          ← notes, experiments, writeups per stage
```

## Cross-compilers

`riscv64-unknown-elf-gcc`/`g++` from Homebrew `riscv-software-src/riscv`, and `clang`/`lld` from Homebrew `llvm` — both installed automatically, both kept available (see `docs/adr/0001-cross-compiler-and-build-toolchain.md`).

## Upstream

Fetch-only remote `upstream` tracks `https://github.com/mit-pdos/xv6-riscv.git`, mirrored into `kernel/xv6-riscv/` as the C reference this track reimplements against.
Push is blocked on `upstream`. All your work goes to `origin` (private GitHub repo).
