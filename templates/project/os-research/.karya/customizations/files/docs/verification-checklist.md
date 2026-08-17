# xv6 track verification checklist

Every track in this collection (`xv6-c`, `xv6-c-cmake`, `xv6-cpp`, `xv6-rust`)
must satisfy the same checklist, because the whole point of the program is
that they're comparable — a kernel that boots differently or fails different
tests on one track isn't a valid data point against the others. This doc is
collection-level (synced the same way as `CLAUDE.md`, see that file's "Karya
conventions") so the checklist itself only has to be written once.

The checklist is a set of **tiers**, cheapest/fastest first. Each tier
subsumes trust in the ones before it — there's no point running `usertests`
against a kernel that doesn't boot.

## Tiers

**1. Build**
- Clean build from scratch succeeds (no stale artifacts masking a failure)
- Zero warnings (warnings-as-errors — see each track's own constraints)
- Output kernel binary is actually RISC-V, not accidentally host-compiled
  (`file kernel` / `readelf -h kernel` should say `RISC-V`)
- Build is deterministic enough that re-running it twice doesn't change
  behavior

**2. Boot**
- Boots to `init: starting sh` and a `$ ` prompt with no kernel panic
- Boots within a sane time bound (catches infinite-loop regressions)

**3. Shell / functional smoke test**
- Core userland commands work: `ls`, `echo`, `mkdir`, `rm`
- Fork/exec works (running any user program at all proves this)
- Pipes work — see the `smoke` sentinel below
- Filesystem round-trip — see the `smoke` sentinel below

**4. xv6's own test suites** — the real correctness bar. This is userland
C/RISC-V code, identical across all four tracks, so it doubles as a
cross-track comparison point:
- `usertests` → must end with `ALL TESTS PASSED`
- `forktest` → must end with `fork test OK`
- `grind` — optional soak test. It runs forever by design (random syscalls
  in parallel); "pass" means no panic within a fixed wall-clock window, not
  a terminating success string.

**5. Debug tooling**
- The GDB-stub boot path starts a stub and a debugger can attach, breakpoint
  in kernel code, and single-step
- A deliberate panic produces a readable backtrace

**6. Cross-track parity**
- Same `usertests`/`forktest` pass/fail outcome as the `xv6-c` baseline
- Boot serial output diffs cleanly against the baseline, modulo expected
  track-specific banners

## Script contract

Because the four tracks have different build systems (GNU Make, CMake+Ninja,
Cargo), tiers 1–4 are run through a fixed script interface every track
implements at `scripts/`, rather than one script assuming `make`:

| Script | Contract |
|---|---|
| `scripts/build.sh [variant]` | Builds the kernel using `toolchain/current/` (or the track's own toolchain layout). `variant` is a no-op for tracks with a single toolchain. `xv6-c-cmake` is the one track where it's load-bearing: that track exists specifically to compare compilers, so its `build.sh [gcc\|llvm]` builds one of two side-by-side outputs (default `gcc`) — every tier for that track must be run against **both** variants, or the `llvm` half is never exercised. Exit 0 on success. |
| `scripts/run.sh [variant]` | Boots the built kernel in QEMU, `-nographic`, interactive. Same `variant` rule as `build.sh`. |
| `scripts/test.sh [tier] [variant]` | Drives `run.sh` non-interactively (e.g. via `expect`) and asserts on the sentinel strings below. `tier` is one of `boot`, `smoke`, `usertests`, `forktest`, `grind`, `all` (`all` = everything except `grind`, which is opt-in since it's a soak test, not a pass/fail check). Exit 0 = tier passed, non-zero = failed, with a `[PASS]`/`[FAIL]` line per assertion on stdout. **Not yet implemented in any track** — only `build.sh`, `run.sh`, and (except `xv6-rust`) `debug.sh` exist today. This row is the contract the first `test.sh` should satisfy, not a description of code already checked in. |

Sentinel strings every track's `test.sh` should key off (from upstream xv6
source or fixed by this doc, not track-specific):

- Boot success: `init: starting sh`, then `$ `
- Any-tier failure: `panic:` anywhere in output — always fails immediately,
  regardless of tier
- Smoke tier: pipe check runs `echo KARYA_PIPE_OK | cat` and matches
  `^KARYA_PIPE_OK$`; filesystem round-trip writes the token `KARYA_FS_OK` to
  a scratch file and matches the same token back on `cat`. These are fixed
  by this doc precisely so the four independently-authored `test.sh` scripts
  produce diffable output — don't invent per-track tokens.
- `usertests` success: `ALL TESTS PASSED`
- `forktest` success: `fork test OK`

No track has a `test.sh` yet — this section defines the contract the first
one written should satisfy. Once `xv6-c/scripts/test.sh` exists, treat it as
the reference implementation: the other tracks' `test.sh` should produce the
same tier names and PASS/FAIL output shape, even though the build step
underneath differs.
