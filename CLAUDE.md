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
   This part is enforced by the machine.
2. **A review pass has run and its findings are posted on the PR.** Run it
   yourself before merging:

   ```bash
   /code-review ultra <PR#> --post
   ```

   `--post` puts the findings on the PR as a comment, which is the point: the
   review has to leave an artifact you can read later, not evaporate with the
   session. `/code-review <PR#> --comment` is the lighter, faster version.
   `/security-review` as well for anything touching subprocess calls, network,
   `gh`, or the install path.
3. **Reproduced findings are resolved.** A finding the reviewer *reproduced* is
   a blocker. A finding it merely suspects is a question you may answer and move
   on from. This distinction is the whole gate: it is what stops an automated
   reviewer from becoming either a rubber stamp or a source of busywork. Every
   finding gets a reply — fixed, or one line on why not. Silence is not an
   answer.

**Step 2 is not enforced by anything.** It depends on you running it, which is
the honest weak point of a one-person gate. `.github/workflows/claude-review.yml`
automates it and removes that dependency, but needs a `CLAUDE_CODE_OAUTH_TOKEN`
or `ANTHROPIC_API_KEY` repository secret; until one exists the job skips rather
than fails. Adding it is the single highest-value upgrade to this workflow.

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
