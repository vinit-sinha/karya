# xv6-rust

Reimplementing the [xv6-riscv](https://github.com/mit-pdos/xv6-riscv) teaching kernel in idiomatic Rust, subsystem by subsystem. xv6's C source is a behavioral reference here, not source to port — see [STAGES.md](STAGES.md) for why and for the roadmap. Bare-metal, `no_std`, targeting `riscv64imac-unknown-none-elf` on stable Rust.

## Quick start

```bash
./scripts/build.sh   # toolchain/current/cargo build --target riscv64imac-unknown-none-elf
./scripts/run.sh      # boot xv6-rust in QEMU  →  Ctrl-a x to exit
./scripts/debug.sh     # boot with GDB stub (connects automatically)
```

Or use VS Code: **Cmd+Shift+P → Tasks: Run Task**.

## Toolchain

`toolchain/current/` — symlinks to the active toolchain (rustup-managed, keg-only style), shared pattern with `xv6-c`.

## Directory layout

```
xv6-rust/
├── STAGES.md              ← roadmap: Stage 0 → 7
├── SETUP.md                ← environment status (generated on create)
├── CLAUDE.md                ← AI assistant guidelines
├── src/                      ← the Rust kernel (Cargo package)
├── kernel/
│   └── xv6-riscv/             ← private mirror of mit-pdos/xv6-riscv — reference only, not built
│       ├── kernel/             ← C kernel source (read for reference)
│       ├── user/                ← C user programs (read for reference)
│       └── Makefile
├── toolchain/
│   └── current -> ...             ← active toolchain symlink
├── docs/
│   └── adr/                       ← architecture decision records
├── scripts/
│   ├── build.sh                     ← cargo build wrapper
│   ├── run.sh                        ← starts QEMU
│   └── debug.sh                       ← starts QEMU + GDB
└── work/                                ← notes, experiments, writeups per stage
```

## Upstream

Fetch-only remote `upstream` tracks `https://github.com/mit-pdos/xv6-riscv.git`, cloned into `kernel/xv6-riscv/` as the C reference this track reimplements against.
Push is blocked on `upstream`. All your work goes to `origin` (private GitHub repo).
