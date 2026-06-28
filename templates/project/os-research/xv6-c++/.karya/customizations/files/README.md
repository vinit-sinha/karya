# xv6-c++

Modernising the [xv6-riscv](https://github.com/mit-pdos/xv6-riscv) teaching kernel from C to C++26, stage by stage.

See **[STAGES.md](STAGES.md)** for the roadmap.

## Quick start

```bash
cd kernel/xv6-riscv
make qemu          # boot xv6 in QEMU  →  Ctrl-a x to exit
make qemu-gdb      # boot with GDB stub (connect from another terminal)
```

Or use VS Code: **Cmd+Shift+P → Tasks: Run Task**.

## Directory layout

```
xv6-c++/
├── STAGES.md              ← roadmap: Stage 0 → 4
├── SETUP.md               ← environment status (generated on create)
├── CLAUDE.md              ← AI assistant guidelines
├── kernel/
│   └── xv6-riscv/         ← private fork of mit-pdos/xv6-riscv (submodule)
│       ├── kernel/        ← kernel source
│       ├── user/          ← user programs
│       └── Makefile
├── docs/
│   └── adr/               ← architecture decision records
├── scripts/
│   ├── build.sh           ← wraps make/cmake
│   ├── run.sh             ← starts QEMU
│   └── debug.sh           ← starts QEMU + GDB
└── work/                  ← notes, experiments, writeups per stage
```

## Cross-compiler

`riscv64-unknown-elf-gcc` / `g++` from Homebrew `riscv-software-src/riscv`.  
Install: `brew install riscv-gnu-toolchain`

## Upstream

Fetch-only remote `upstream` tracks `https://github.com/mit-pdos/xv6-riscv.git`.  
Push is blocked on `upstream`. All your work goes to `origin` (private GitHub repo).
