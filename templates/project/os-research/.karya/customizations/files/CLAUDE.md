# os-research — AI Assistant Guidelines

## What this is

`os-research` is a Karya collection (`kosh://project/os-research`) for personal operating-systems research: code, papers, notes, and reference material the user produces or consumes while studying OS design. It sits under the `project` domain in the `~/workspace` Karya workspace — see [Karya conventions](#karya-conventions) below.

Every project in this collection is its own git repository. There is no repository at this collection root — don't `git init` here.

## Program map

The active research program is **xv6** — the MIT 6.S081 teaching kernel — implemented in parallel across languages so the same kernel can be studied C-idiomatically, C++26-idiomatically, and Rust-idiomatically. Two other tracks (Go, Zig) were explored and deliberately dropped — Go for its GC (unacceptable in kernel context), Zig for being too under-development to build on:

| Project | URI | Role | Status |
|---|---|---|---|
| `xv6-c` | `kosh://project/os-research/xv6-c` | C reference track: verify build on a modernized toolchain, then **frozen** — no build-system or compiler churn. The behavioral baseline every other track reimplements against | Designed, scaffold not yet run |
| `xv6-c-cmake` | `kosh://project/os-research/xv6-c-cmake` | Sibling of `xv6-c`, *not* a later stage of it: same unmodified C source, but GNU Make → CMake+Ninja with GCC and LLVM built side by side, purely to benchmark which compiler suits kernel dev. Produces the toolchain decision `xv6-cpp` inherits | Designed, not yet created |
| `xv6-cpp` | `kosh://project/os-research/xv6-cpp` | Staged **reimplementation** (not a port) of the C baseline in idiomatic C++26, subsystem by subsystem. Bootstraps its build system by copying `xv6-c-cmake`'s CMake+dual-toolchain setup rather than designing one from scratch | **Live** — scaffolded, committed, pushed. Real Stage 0 kernel code not yet written |
| `xv6-rust` | `kosh://project/os-research/xv6-rust` | Staged **reimplementation** (not a port) of the C baseline in idiomatic Rust, subsystem by subsystem. Own toolchain (`rustc` stable, `riscv64imac-unknown-none-elf`, single `toolchain/current/` — not affected by the CMake/dual-toolchain work, Cargo has no equivalent need) | **Live** — scaffolded, committed, pushed. Real Stage 0 kernel code not yet written |
| `kernel-bench` | `kosh://project/os-research/kernel-bench` | Future: cross-track (C / C++26 / Rust) performance comparison | Not yet designed |

Each track is opened as its own VS Code window/root (separate Karya projects, separate git repos) and carries its own `STAGES.md`/`CLAUDE.md` — see that project's `CLAUDE.md` for track-specific conventions. Two toolchain patterns coexist by design: `xv6-c` and `xv6-rust` use a single mutable `toolchain/current/` symlink; `xv6-c-cmake` and `xv6-cpp` keep GCC and LLVM installed **side by side** (`toolchain/gcc-<ver>/`, `toolchain/llvm-<ver>/`, no "current") since the whole point there is comparing both, not picking one. All of this lives in a shared `lib.sh` of `post-create.sh` setup functions at the collection's template level. `xv6-cpp` and `xv6-rust` treat `xv6-c`'s `kernel/xv6-riscv/` clone as a **read-only reference**, never building it directly — their own kernel lives in `src/`. `xv6-c-cmake` is the one exception that *does* build `kernel/xv6-riscv/` directly (same as `xv6-c`), since its whole purpose is building that real source under a new build system.

Each track's private GitHub mirror of `mit-pdos/xv6-riscv` is named `project-os-research-<track>-upstream` — **never** `project-os-research-<track>` without the suffix, which is the name Karya's own auto-publish picks for the track's own repo. The two colliding once already (see `xv6-cpp`'s git history) — don't reintroduce that when adding a new track.

## Process

All non-trivial work in this collection — a STAGES.md stage, an MIT lab, a research question — follows the six-phase workflow in **[docs/agentic-workflow.md](docs/agentic-workflow.md)**: Requirements Gathering → Requirement Analysis → Planning → Design → Implementation → Testing, each with its own iterate-then-review loop. Read that doc before starting a new stage of work.

## Karya conventions

This collection is managed by [Karya](https://github.com/vinit-sinha/karya), a personal workspace CLI. `~/workspace/tools/karya` is the one and only working copy — it's directly on `PATH` (`~/workspace/tools/karya/bin/karya`), so edits to its source take effect immediately with no separate install step. Quick reference:

```
karya create project --uri kosh://project/os-research/<name>   # scaffold a new project from its template
karya create project --uri ... --continue                      # re-run/resume a project's post-create hooks
karya publish project                                           # wire up a GitHub remote (run inside the project)
karya workstate save [name]                                     # checkpoint current git state for cross-machine resume
karya workstate resume [name] --apply                           # restore a checkpoint on another machine
```

Projects are addressed by `kosh://domain/collection/project` URIs. This collection's URI segment is `project/os-research` (domain `project`, collection `os-research`). Karya walks upward from any subdirectory to find `.karya-workspace` / `.karya-domain` / `.karya-collection` / `.karya-project` marker files — no environment variables needed.

Project-specific behavior (what gets cloned, which toolchain gets installed, which files get copied in) lives in `~/workspace/tools/karya/templates/project/os-research/<name>/.karya/customizations/` as `post-create.sh` hooks plus a `files/` asset directory — that is the actual source of truth for each new project's starting state, including its `CLAUDE.md`. A shared `templates/project/os-research/.karya/customizations/lib.sh` holds functions common to all `xv6-*` variants (toolchain install, GitHub mirror+clone, `toolchain/current/` symlink farm, `SETUP.md` generation). If you're about to hand-edit a freshly created project's `CLAUDE.md`/`STAGES.md`/`README.md`, edit the template in the karya repo instead so the next `--continue` or teammate re-create doesn't clobber your changes.

This file, `docs/agentic-workflow.md`, and `docs/verification-checklist.md` are collection-level, not project-level — they're synced (always overwritten from the template, same rule as above) by `templates/project/os-research/.karya/customizations/post-create.sh` regardless of *which* project under this collection you create or `--continue`. That hook runs on every `karya create project` invocation under `project/os-research/*`, walks up from the project root to find `.karya-collection`, and ensures these files exist there — so creating `xv6-c-cmake` for the first time on a fresh machine brings this file along too, not just `xv6-c-cmake`'s own content.

## Working across machines

Before switching machines or pausing for a while, run `karya workstate save` inside the project you were working in. Resume with `karya workstate resume --apply` on the other machine.
