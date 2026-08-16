# Karya — AI Assistant Guidelines

## Git Workflow (MANDATORY)

**Never work directly on `master`.** Every piece of work must follow this flow:

1. **Create a feature branch** before making any changes:
   ```bash
   git checkout master && git pull
   git checkout -b feature/<short-description>
   ```
2. **All commits go on the feature branch** — never commit directly to `master`
3. **When work is complete**, create a PR:
   ```bash
   gh pr create --title "..." --body "..."
   ```
4. **Clear the review gate** (below), then merge to `master` via GitHub (or `gh pr merge`)
5. **Delete the feature branch** after merge

This applies to all changes — bug fixes, features, documentation, configuration.

## The Review Gate

This repository has one maintainer. There is no second person to approve a PR,
and GitHub will not let an author approve their own — so "wait for approval" is
not an available step, and pretending otherwise just means merging unreviewed.
The gate is therefore automated, and it is not optional:

**A PR may merge when all three hold:**

1. **CI is green.** `.github/workflows/ci.yml` — the test suite passes on both
   the advertised Python floor and current Python, and every hook script parses.
2. **The Claude review has run and been answered.**
   `.github/workflows/claude-review.yml` posts findings on every PR. Every
   finding gets a reply: fixed, or a one-line reason it is not being fixed.
   Silence is not an answer. Use `@claude` in a comment to push back — a review
   you disagree with is a conversation, not a verdict.
3. **Reproduced findings are resolved.** A finding the reviewer *reproduced* is
   a blocker. A finding it merely suspects is a question you may answer and move
   on from. This distinction is the whole gate: it is what stops an automated
   reviewer from becoming either a rubber stamp or a source of busywork.

**Behaviour changes need a test.** `tests/test_karya.py` is the only safety net
this repo has. Run it before pushing:

```bash
python3 -m unittest discover -s tests -v
```

Tests marked `@unittest.expectedFailure` document known, reproduced defects (see
`docs/critical-review-2026-08.md`). If your change fixes one, **delete the
decorator in the same PR** — unittest reports an unexpected success as a
failure, so leaving it will turn CI red.

**What the gate cannot do.** It will not notice that a feature is a bad idea,
that a project is drifting from its purpose, or that you are working on the
wrong thing. That judgement has no automated substitute and remains yours.

## Suggested branch protection

Enable **require status checks to pass** on `master` for the `tests` and
`shell` checks. Do **not** enable "require approvals" — with one maintainer it
is unsatisfiable and will lock the repo.
