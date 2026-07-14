# xv6-c

C reference track for the xv6-riscv OS research project. Stays in C throughout — the clean baseline against which all other language tracks are compared.

See **[STAGES.md](STAGES.md)** for the roadmap.

## Quick start

```bash
./scripts/build.sh   # build kernel
./scripts/run.sh     # boot in QEMU  (Ctrl-a x to exit)
./scripts/debug.sh   # boot with GDB stub
```

## Toolchain

`toolchain/current/` — symlinks to the active toolchain (Homebrew, keg-only). This track only ever uses `riscv64-unknown-elf-gcc` — for a CMake build with a GCC/LLVM toggle, see [`xv6-c-cmake`](../xv6-c-cmake) instead.

## Directory layout

```
xv6-c/
├── STAGES.md            ← roadmap
├── SETUP.md             ← environment status (generated)
├── kernel/
│   └── xv6-riscv/       ← your private fork (submodule)
├── toolchain/
│   └── current -> ...   ← active toolchain symlink
├── scripts/
│   ├── build.sh
│   ├── run.sh
│   └── debug.sh
├── docs/adr/            ← architecture decisions
└── work/                ← notes per stage
```
