<!--
One maintainer, no second approver. Step 2 below is the only part of the review
gate a machine does not enforce, which is exactly why it is a checkbox staring
at you. See CLAUDE.md.
-->

## What and why

<!-- What changed, and the problem it solves. Link the issue if there is one. -->

## Gate

- [ ] **CI green** — `tests` (3.9 + 3.13) and `shell`
- [ ] **Review pass run and posted** — `/code-review ultra <PR#> --post`, or the
      automated review if a credential is configured
- [ ] **Every finding answered** — fixed, or one line on why not
- [ ] **No reproduced finding left open**

## Tests

- [ ] Behaviour change has a test in `tests/test_karya.py`, **or** this is
      docs/config only
- [ ] If this fixes a defect pinned by `@unittest.expectedFailure`, the
      decorator is deleted in this PR

## Blast radius

- [ ] Touches `templates/**/.karya/customizations/` — hooks re-run on every
      `--continue` and every sibling project creation; confirmed still idempotent
- [ ] Touches anything that writes outside the workspace (`$HOME`, editor
      config, `brew`, GitHub repos) — confirmed prompted or flag-guarded
- [ ] Invalidates a doc (`README.md`, `docs/design.md`, `docs/user-guide.md`,
      `docs/orientation.md`, `.ai/README.md`) — updated in this PR
