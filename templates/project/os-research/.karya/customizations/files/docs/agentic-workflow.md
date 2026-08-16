# Agentic Workflow

The process every non-trivial unit of work in this collection follows — a `STAGES.md` stage, an MIT lab, a research question, a bug fix that touches design. Trivial changes (typo fixes, a one-line config tweak) don't need the full ceremony; use judgment.

The workflow has six phases. Every phase runs the same inner loop:

```
   ┌──────────────────────────────┐
   │  Do  →  Iterate  →  Checkpoint │  → next phase
   └──────────────────────────────┘
```

- **Do** — produce the phase's artifact (a first pass).
- **Iterate** — refine it: the agent self-critiques, asks clarifying questions, surfaces ambiguity or risk it noticed while working.
- **Checkpoint** — the phase's artifact is *written down and shown*, not silently assumed accepted.

Skipping a phase should be a conscious, stated decision ("this is small enough to skip Design"), not an accident.

## Who reviews, now that it is one person

This workflow was written when two other people were reading the work. They are
no longer, so a checkpoint that means "wait for someone else to confirm" now
means "wait forever", and in practice means "skip it". Six such gates per stage
were never going to survive solo.

So there are exactly **two hard gates** — places where work stops until
something outside your own head has said yes:

| Gate | Where | What has to happen |
|---|---|---|
| **Plan approval** | End of Phase 3 | `ExitPlanMode`. You read the plan cold and approve it, or send it back. This is the cheapest place in the whole process to change your mind. |
| **PR review** | End of Phase 5 | CI green + the automated Claude review answered + reproduced findings resolved. See the karya repo's `CLAUDE.md`. |

Every other phase boundary is a **self-checkpoint**: write the artifact down,
re-read it, move on. Its value is that it exists in a file where you can find it
in three weeks — not that anyone signed it.

Two habits that recover most of what the second reader used to provide:

- **Read the diff cold.** Not in the session that wrote it, and preferably not
  on the same day. Fresh context is most of what a reviewer actually brings.
- **Reproduce, don't assert.** A concern you can demonstrate — a failing
  command, a boot that hangs, a test you wrote — is worth acting on. A concern
  you only feel is worth one sentence in the PR and no more. Hold an AI reviewer
  to the same standard you hold yourself.

## Cross-machine checkpointing

The user works across two machines. A phase boundary is the natural place to checkpoint: uncommitted work sitting only on one machine's disk when the session ends defeats the point of writing the artifact down at all. **Before ending a session, or whenever a phase boundary is crossed and the user might switch machines next, run `karya workstate save`** in whatever project is active — it's per-project (per git repo), so run it in `xv6-c`, `xv6-cpp`, or `xv6-rust` specifically, not at the collection root. On the other machine, `karya workstate resume --apply` restores it, including any nested reference clone (`kernel/xv6-riscv/`), which Karya tracks as a registered git submodule for exactly this reason. VS Code tasks named "Checkpoint: save" / "Checkpoint: resume" wrap these in every track.

---

## 1. Requirements Gathering

**Goal:** capture what is wanted and why, in the requester's own terms, before any technical framing.

- Source: the user directly, an MIT lab handout, or a `STAGES.md` stage's one-line goal.
- Artifact: a short requirements note — inline in the STAGES.md stage entry for small work, or a standalone `requirements.md` for anything spanning multiple sessions.
- Iterate: ask clarifying questions until the request is unambiguous. Don't assume — use `AskUserQuestion` or the plan-mode question loop rather than guessing silently.
- **Self-checkpoint:** the requirements note exists as a file and reads as unambiguous to you *after* you stop writing it. If you cannot state what "done" looks like, you are not finished with this phase.

## 2. Requirement Analysis

**Goal:** turn "what's wanted" into constraints, invariants, risks, and testable acceptance criteria.

- Break the requirement down: what must stay true (invariants), what's a hard constraint (e.g. "must still boot in QEMU with `-machine virt`"), what's unknown or risky, what's explicitly out of scope.
- Artifact: an acceptance-criteria list — the thing Phase 6 (Testing) will be checked against.
- Iterate: surface edge cases and ambiguities the requirements didn't cover.
- **Self-checkpoint:** every open question is either answered or explicitly deferred in writing. An unanswered question that survives into Planning becomes a rewrite later.

## 3. Planning

**Goal:** decide the sequence of work and its boundaries before touching code.

- Artifact: a plan — literally Claude Code's plan mode for anything nontrivial. Includes: ordered steps, the branch this work lands on (see stage/branch naming in each track's `STAGES.md`), an explicit out-of-scope list, and dependencies on other in-flight work.
- Iterate: revise the plan against feedback; consider at least one alternative approach and say why it was rejected.
- **HARD GATE — plan approval:** `ExitPlanMode`. Read the plan as if someone else wrote it, then approve or send it back. Do not approve a plan in the same breath as producing it.

## 4. Design

**Goal:** work out *how*, for decisions that are consequential or hard to reverse (toolchain choice, on-disk format, public interface shape, build system). Skip this phase for changes with one obvious implementation.

- Artifact: an ADR under the project's `docs/adr/`, using the standard template (`Context / Decision / Alternatives Considered / Consequences`).
- Iterate: weigh alternatives honestly, including "do nothing" or "defer."
- **Self-checkpoint:** the ADR is committed before code is written against it. A decision that is hard to reverse deserves a `/code-review` pass on the ADR itself — that is cheap and you will not get another chance.

## 5. Implementation

**Goal:** make the change, in small reviewable increments, on the branch decided in Planning.

- Keep commits scoped; don't bundle unrelated cleanup into a stage's implementation commit.
- Iterate: self-check continuously against the Phase 2 acceptance criteria, not just "does it compile."
- **HARD GATE — PR review:** CI green, the automated Claude review answered finding by finding, and every *reproduced* finding resolved. See the karya repo's `CLAUDE.md` for the full rule. Never merge straight off implementation. If you want a deeper pass than the automatic one, run `/code-review ultra <PR#>`.

## 6. Testing

**Goal:** verify the acceptance criteria from Phase 2, not just "it builds."

- For kernel work this typically means: it builds under the track's toolchain, it boots in QEMU, and — where applicable — it passes the relevant MIT 6.S081 lab test harness. Add new automated tests where the change introduces new behavior worth locking down.
- Artifact: a filled-in test report, or the relevant `STAGES.md` checkbox ticked with a one-line note on how it was verified.
- Iterate: fix-and-retest until acceptance criteria are met — don't declare done on the first red run.
- **Self-checkpoint:** every Phase 2 acceptance criterion is ticked with a one-line note on how it was verified — not "looks right". Then mark the stage/lab complete.

---

## How this maps onto `STAGES.md`

A track's `STAGES.md` (e.g. `xv6-cpp/STAGES.md`, `xv6-rust/STAGES.md`) is the concrete backlog — *what* to build, in what order, with what acceptance criteria per stage. This document is the general *process* — *how* each item on that backlog gets built. Read literally: **one Stage in `STAGES.md` is one full pass through all six phases above**, from "what does this stage need to be true" through "it's tested and merged."

For work with no `STAGES.md` yet (a fresh research question, a new track before its roadmap exists), Phase 1–3 of this workflow *is* how the `STAGES.md` itself gets written — the plan produced in Phase 3 for "figure out the roadmap" can literally be a draft `STAGES.md`.
