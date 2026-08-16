# Karya — Critical Review

**Date:** 2026-08-16 · **Commit reviewed:** `943060f` · **Stance:** deliberately
adversarial. This document argues the case *against* the repo as it stands, on the
theory that the case for it is already written down everywhere else. Findings marked
**[verified]** were reproduced by running the code; the rest are read from source.

---

## Verdict

The engineering is better than the product. `bin/karya` is a clean, dependency-free,
readable 1,200-line script with an unusually coherent set of conventions, and the
template hooks encode real, hard-won knowledge that would otherwise evaporate. But:

- **Two of the three headline features do not survive contact with their own code.**
  The auto-checkpoint mechanism is wired to a git hook that does not exist, and the
  workstate patch format corrupts itself on the second save. Both **[verified]**.
- **The tool is a minority of the repo.** ~1.2k lines of CLI carry ~7.5k lines of
  content, most of it one person's MIT coursework, including a bespoke HTML courseware
  web app with its own HTTP server.
- **The abstraction that justifies the project — `kosh://` — buys less than it costs.**
  It is a relative path with a scheme prefix, and the layer it enables is mostly
  used to run bash scripts that would work identically without it.
- **There are no tests, no CI, and no way to verify a change** other than creating a
  throwaway workspace by hand and reading the output.

None of this makes the repo a mistake. It makes it a personal tool with a distribution
story (README, install script, "Prerequisites", Windows/WSL2 instructions) that its
implementation cannot currently honour. The gap between those two things is where
every finding below lives.

---

## Part A — The premise

### A1. Does the addressing layer earn its keep?

`kosh://learning/mit/6s081` resolves to `<workspace>/learning/mit/6s081`. That is a
relative path with ceremony. The design doc claims three benefits — let's test them:

- *"Portable across machines"* — so is a relative path.
- *"Carries semantic meaning"* — the meaning is carried by the directory names, which
  a plain path also has. The four segment *roles* (domain/collection/project/subproject)
  are enforced only by position in a list, `SEGMENT_MARKERS`, and are not validated at
  all. **[verified]** `kosh://learning/solo` (two segments — explicitly permitted by
  `parse_kosh_path`) produces a directory carrying a `.karya-collection` marker *and* a
  degenerate `.karya-project` containing nothing but `{"setup_status": "complete"}` —
  no `uri`, no `karya_version`. Every hook that does `read_marker_field "uri"` silently
  gets an empty string. The scheme's core promise (segments have named roles) is
  unenforced in the one place it matters.
- *"Uniquely identifies a resource"* — only within one workspace, and nothing prevents
  a marker's recorded `uri` from disagreeing with its actual path after any `mv`.

What `kosh://` genuinely buys is a **key into the template tree**, which is real but
much narrower than "a URI scheme for personal work". The honest framing would be
"template selector", and it would then be obvious that a plain path (`learning/mit/6s081`)
serves identically. The `file://` scheme, meanwhile, is accepted by the parser and
supported by `remove` and `publish`, but `create` rejects it — so half the scheme
comparison table in `design.md` describes something the primary command cannot do.

**Adversarial summary:** the URI is the repo's central intellectual claim, and it is
the part with the least implementation behind it.

### A2. Does the bootstrapping layer earn its keep?

Yes — but not as *Karya*. The value is concentrated in
`templates/learning/mit/6s081/.karya/customizations/post-create.sh` and
`templates/project/os-research/.karya/customizations/lib.sh`: ~1,700 lines of bash that
know how to install a RISC-V toolchain, mirror a git:// repo into a private GitHub
repo without tripping over `refs/pull/*`, patch a 2021 Makefile for a 2026 GCC, and
lay out a symlinked toolchain farm. The comments in `lib.sh` are the best writing in
the repo — they explain *why*, including three bugs that cost real time.

But observe what Karya contributes to that value: it `cd`s into a directory and runs
`bash post-create.sh`. That is a `Makefile` target. The features that would justify a
purpose-built runner — dependency ordering, per-step resumption, dry-run, rollback,
logging, versioned re-application — are all absent (per-step resumption is
[issue #15](https://github.com/vinit-sinha/karya/issues/15), still open). What exists
is coarse: one boolean `setup_status` for the whole hook chain.

Compare against the obvious alternatives the repo never mentions: `cookiecutter` and
`copier` do templating with variables, versioning, and *update* semantics; `copier
update` in particular solves the exact problem Karya's "edit the template, not the
copy" rule is a manual workaround for. Not adopting them is defensible (zero deps is a
real goal), but the README should say so rather than imply no alternative exists.

### A3. Does the workstate layer earn its keep?

This is the weakest claim. Git already has four mechanisms for "save where I am":
branches, `stash`, WIP commits, and `worktree`. Karya adds a fifth that is strictly
less reliable than any of them (see §B2), stores it *inside the repo it is snapshotting*,
and does not commit it — so the snapshot does not travel with the push it is supposed
to complement. The one genuinely additive idea here is **submodule-aware** save/resume:
recording branch-per-submodule and following `.gitmodules` branches with
`--remote` on clone. That idea is good and is not free elsewhere. It deserves to be
extracted from the patch machinery that surrounds it.

### A4. Scope — what is this repository *of*?

The repo cannot decide whether it is a tool or a study program.

Living in a tool repo right now: `MIT-LEARNING-PLAN.md` (a session-handoff note from
2026-06-10, opening with "Status: Git clones pending SSH key setup" — a status that was
resolved twenty commits ago, and which references a personal iCloud Obsidian path);
`docs/mios-curriculum.md` (a reading list for Tanenbaum and Hennessy & Patterson);
and a complete 6.S081 courseware web application — 11 lab HTML pages, a dashboard, a
schedule view, `nav.js`, `style.css`, and a 253-line Python HTTP server that shells out
to `gh pr list` to detect lab completion.

That server is a second program with its own network surface, its own persistence
files, and zero relationship to workspace management. It ships inside a template's
`files/` directory. Nothing about "personal workspace CLI" predicts it.

The cost is not aesthetic. It is that **`templates/` cannot be forked, versioned, or
shared independently of the tool** — so anyone else adopting Karya inherits one
person's MIT curriculum, and the author cannot upgrade Karya without also shipping
curriculum changes. Issue #7 (template versioning across upgrades) is filed as an open
problem; the structural cause is this coupling, and no marker-file scheme will fix it
while the two live in one repo with one version number.

### A5. Audience

Every artifact says "distribute this": a README with Prerequisites, an `install.sh`, a
Windows/WSL2 section, a user guide, a "Contributing" heading. Every implementation
detail says "audience of one": templates hardcode `mit-pdos/xv6-riscv` and the author's
own repo-naming scheme, hooks `brew install` global packages and rewrite the user's
personal VS Code keybindings, `install.sh` writes to two shell rc files and `rm -rf`s
its own destination without asking, and there is no uninstall. Pick one. If it is
"audience of one" — which is a perfectly good answer — then the README's promises stop
being bugs, and about half of Part B stops mattering.

---

## Part B — Defects, ranked

### B1. `create project` crashes on any machine without `gh` **[verified]** — *critical*

`README.md` lists `gh` as "optional, for publishing projects to GitHub". It is not
optional. `gh_available()` calls `subprocess.run(["gh", "--version"], ...)` with no
`FileNotFoundError` handling (`bin/karya:1081`), and `_clone_from_remote()` calls it
**before anything is created**. Reproduced with `gh` removed from `PATH`:

```
  File "bin/karya", line 1081, in gh_available
    result = subprocess.run(["gh", "--version"], capture_output=True, text=True)
FileNotFoundError: [Errno 2] No such file or directory: 'gh'
```

The command dies with a traceback and creates nothing. The same pattern exists in
`gh_get_authenticated_user()`, `gh_repo_exists()`, `gh_create_repo()`, and
`run_git_command()` (which would do the same for a missing `git`). Note that the code
*clearly intends* graceful degradation — `gh_available()` returns `False` on auth
failure — so this is a one-line omission, not a design choice.
**Fix:** `shutil.which("gh")` guard, or wrap in `try/except FileNotFoundError`.

### B2. The workstate patch includes itself and grows without bound **[verified]** — *critical*

`_capture_repo_state()` writes its patch to `.karya/state-checkpoints/<name>.patch`
*inside the repository being snapshotted*, and nothing gitignores `.karya/`. So the
checkpoint files are untracked, which means the **next** save's untracked-file sweep
(`git ls-files --others` → `git diff --no-index /dev/null <file>`) captures the previous
checkpoint's `.json` and `.patch` into the new patch. Three consecutive saves with one
trivial change in the tree:

```
save 1 → latest.patch =  331 bytes
save 2 → latest.patch = 1441 bytes
save 3 → latest.patch = 2592 bytes     ('state-checkpoints' appears 10× inside it)
```

Growth is quadratic in the number of saves. Two further consequences:

- `uncommitted_changes` is **permanently `true`** after the first save, because the
  checkpoint files themselves are always dirty. The flag stops meaning anything.
- `resume --apply` cannot succeed on the machine that saved. Verified output:
  ```
  error: .karya-project: already exists in working directory
  error: .karya/state-checkpoints/latest.json: already exists in working directory
  error: .karya/state-checkpoints/latest.patch: already exists in working directory
  error: note.txt: already exists in working directory
  ```
  `git apply --index` is used with no `--3way` and no reverse/clean check, so a patch
  containing any file that already exists fails wholesale — and it always contains at
  least its own metadata.

**Fix:** store checkpoints outside the working tree (or gitignore `.karya/` in every
project template and exclude it from the untracked sweep), and use `git stash create`
or `git apply --3way` rather than hand-rolled patch concatenation.

### B3. The auto-checkpoint hook is attached to a git hook that does not exist **[verified]** — *high*

`_install_post_push_hook()` (`bin/karya:376`) writes `.git/hooks/post-push` on the
project and on every registered submodule, prints `Installed post-push workstate hook`,
and is described in commit `b31a06c` as the mechanism that keeps machines in sync.

**Git has no `post-push` hook.** It is absent from `man githooks` and from the sample
hooks shipped with git (`pre-push.sample` exists; there is no post-push counterpart).
The file is written, made executable, and never executed. Every "auto-checkpoint after
push" the user believes is happening is not happening — and because the failure is
silent, the first symptom is a stale checkpoint on the other machine.
**Fix:** use `pre-push` (accepting that it runs before the push succeeds), or drop the
mechanism and call `workstate save` explicitly from the wrapper scripts that already
exist (`lab-done.sh` already does exactly this).

### B4. `init workspace` creates domains that cannot be used **[verified]** — *high*

`init_workspace()` creates `learning/`, `experiments/`, `projects/`, `archive/`.
The templates are `learning/`, `experiment/`, `project/`. Two of the three offered
domains are dead on arrival:

```
$ karya create project --uri kosh://experiments/foo/bar
Error: No template found for domain 'experiments'. …
       Available domains: experiment, learning, project
```

Meanwhile the repo's own real work lives at `kosh://project/os-research/...`, which
creates a *fourth* directory (`project/`) next to the unused `projects/`. Every
document in the repo is inconsistent about this: `README.md` and `design.md` say the
domains are "learning, experiments, projects"; the code says otherwise. A brand-new
user following the README hits this within ninety seconds.
**Fix:** pick one set of names and make `init_workspace` derive the directories from
`templates/` rather than a hardcoded list.

### B5. `publish` force-pushes by default — *high*

`git_push_current_branch()` runs `git push -u origin HEAD --force-with-lease`.
`--force-with-lease` is the safe *kind* of force push, but it is still a force push,
performed by a command whose user-facing description is "wire up a git remote and
update metadata". A user who runs `karya publish project` on a branch whose remote has
commits they fetched earlier in the session will lose the difference. There is no flag
to opt out and no prompt naming the risk (the prompt says only "Push now?").
**Fix:** plain `git push -u`; add `--force` as an explicit opt-in.

### B6. Remote-detection can clone the wrong repository — *medium*

`_clone_from_remote()` derives a repo name by joining URI segments with `-`
(`kosh://learning/mit/6s081` → `learning-mit-6s081`) and, if `gh repo view` succeeds,
**clones it instead of creating the project**, with no confirmation and no verification
that the repo was produced by Karya. Any pre-existing repo whose name collides is
silently adopted as the user's project. Relatedly, `gh_repo_exists()` returns `None`
for indeterminate errors (rate limit, network, unexpected `gh` output) and the caller
treats `None` as "does not exist" — so a transient GitHub failure on machine 2 makes
Karya create a fresh project that will then collide with the real remote at publish
time.
**Fix:** confirm before adopting a remote; check for a Karya marker in the clone;
treat `None` as fatal, not as `False`.

### B7. No validation of URI segments — path traversal out of the workspace — *medium*

`parse_kosh_path()` filters empty segments and checks the count. It does not reject
`.`, `..`, absolute-looking segments, or anything else. `resolve_uri()` then joins them
onto the workspace root, so `kosh://learning/../../../tmp/x` resolves outside the
workspace and `create` will happily scaffold there — writing marker files, running
`git init`, and executing hooks in a directory the user did not intend. Self-inflicted
only (there is no untrusted input path today), but it is three lines to close and the
`remove` command's `shutil.rmtree` sits on the same resolver.

### B8. Shell hooks interpolate values into Python source — *medium*

`read_marker_field` / `write_marker_field` (duplicated in the 6.S081 hook and in
`lib.sh`) build Python programs by string interpolation:

```bash
python3 -c "
d['$key'] = '$value'
json.dump(d, open(path, 'w'), indent=2)
"
```

`$value` is a GitHub URL derived from `gh api user` output. A value containing a quote
or newline produces a syntax error at best and executes attacker-influenced Python at
worst. Both wrappers also swallow every failure with `2>/dev/null || true`, so a
corrupted marker is written silently.
**Fix:** pass values via `argv` (`python3 - "$key" "$value" <<'EOF'`), which the same
hook already does correctly for the Makefile patch a hundred lines below.

### B9. `--continue` silently overwrites user edits — *medium*

`xv6_install_files()` and the collection-level sync hook copy over `CLAUDE.md`,
`README.md`, `STAGES.md`, `.vscode/*`, and `scripts/*` unconditionally, on every create
*and* every `--continue`, for every project in the collection. The repo is explicit that
this is intentional ("the template is the source of truth… edit the template, not the
materialized copy"), and the reasoning is sound. But the mechanism is a policy written
in a doc, not a guard in the code: there is no diff, no backup, no `--force`, no
warning that N files were replaced. A user who spent an hour on `STAGES.md` and then
re-ran `--continue` to fix a toolchain problem loses it with no message beyond
`Installed STAGES.md`.
**Fix:** skip files whose content differs from both the template and the last-installed
version, or at minimum print "overwriting locally modified X".

### B10. Untestable by construction — *medium, and the root cause of several above*

Every error path calls `fail()`, which prints to stderr and `sys.exit(1)`. There are no
exceptions, no return codes, no injectable filesystem or subprocess layer, no
`if __name__` guard around anything importable, and no tests, CI, or linting anywhere in
the repo. The only way to exercise `create_project()` is to create a real workspace,
hit the real network, and read stdout. This is why B1 (a missing `try/except`), B2
(a patch that never applies), B3 (a hook that never runs), and B4 (a hardcoded list that
disagrees with the filesystem) all shipped: each is the kind of bug a single smoke test
would have caught on the first run.
**Fix:** raise a `KaryaError` instead of exiting; move `main()`'s dispatch into a
function that takes `argv`; add a dozen `tmp_path` tests. Nothing else in this list is
worth doing before this one.

### B11. Global machine mutation from a project scaffolder — *medium*

`karya create project` will, without a confirmation prompt: `brew install` a RISC-V
toolchain, QEMU, LLVM, lld, CMake, and Ninja; `brew tap` and `brew trust` a third-party
tap; create a private GitHub repository; mirror an external repository into it; and
rewrite `~/Library/Application Support/Code/User/keybindings.json` to rebind
`Cmd+Shift+B` and `Cmd+Shift+T` **globally, for every VS Code project on the machine**.
The last one is the sharpest: a workspace tool has no business editing the user's
editor configuration outside the workspace, and the code even acknowledges the
constraint it is working around ("VS Code keybindings are user-level only"). The right
response to "there is no project-level version of this setting" is to not set it.

### B12. Documentation drift — *low individually, corrosive together*

- `design.md` documents `.karya/customisations/` (British spelling) throughout. Every
  real directory and all code use `customizations`. Anyone following the design doc to
  add a customization creates a directory Karya ignores, with no error.
- `design.md` documents a root-level `templates/.karya/customizations/` with a
  `ROOT.md`. Neither exists.
- `.ai/README.md` — the file that says "**Read this before doing anything**" — describes
  PR #14 as open, names a current working branch deleted 40 commits ago, and documents a
  `completed_hooks` marker field that was never implemented. It is a trap for exactly
  the audience it targets.
- `design.md`'s marker example shows a `template_version` field the code never writes.
- The 6.S081 hook prints "Step 1/6" … "Step 4/6" and then "Step 6/6"; there is no
  step 5 and there are five sections.
- `lab-done.sh`'s usage line lists `pagetable` as a lab name; the generated `CLAUDE.md`
  correctly notes the actual branch is `pgtbl`. The usage text is wrong in the one place
  a stuck user reads it.
- README, user-guide, and `design.md` each list a different command surface (`--continue`
  / `--restart` / `--no-publish` appear in some and not others).

### B13. Duplication that will drift — *low*

Four byte-identical copies of the `.ai/` scaffold (repo root + three domain templates —
verified by checksum), three byte-identical `.gitignore` files, and two independent
copies of `read_marker_field`/`write_marker_field`. The two marker helpers are the
dangerous pair: a fix to one (see B8) will not reach the other.

### B14. Marker files are written once and never reconciled — *low*

`write_marker()` no-ops when the marker exists and no `extra` is supplied. Move or
rename a project directory and its marker keeps the old `uri` forever, with nothing to
detect the mismatch. `karya_version` is written into every marker and read by nothing —
the stated foundation of the issue-#7 versioning plan is, today, a decorative field.

---

## Part C — What I would actually do

**Cut:**
- `MIT-LEARNING-PLAN.md` and `docs/mios-curriculum.md` — personal content, not tool
  docs. They belong in the workspace Karya manages, which is the whole point of Karya.
- The VS Code global keybinding rewrite (B11).
- `.ai/README.md`, or rewrite it to point at `docs/` rather than restate it. Duplicated
  documentation with no owner always loses to the code.

**Fix, in this order:**
1. B10 (make it testable) — then B1, B4 as the first two tests.
2. B2 + B3 together: workstate is currently a feature that reports success and does
   nothing. Either make it work or remove it from the README until it does.
3. B5, B6 — the two commands that can lose data or adopt the wrong repo.
4. B12 — one pass reconciling `design.md`, `README.md`, `user-guide.md`, and `.ai/`
   against the code, and a rule that the code is authoritative.

**Decide, then write down:**
- **Is this shipped or personal?** Everything downstream follows. If personal: delete
  `install.sh`'s distribution posture, say so in the README, and stop paying for
  Windows/WSL2 guidance. If shipped: `templates/` must split into its own repo (which
  also unblocks issue #7), the xv6 courseware app must move out entirely, and B1/B4
  become release blockers.
- **What is `kosh://` for?** If the answer is "selecting a template", say that and drop
  the URI framing — the tool loses nothing and the docs get half as long. If it is
  meant to be a real addressing scheme, then segment roles need validation (B/A1),
  `file://` needs to work in `create`, and marker/path reconciliation (B14) needs to
  exist.

**Keep, and be proud of:**
- The single-file, zero-dependency, stdlib-only CLI. It is genuinely portable and
  genuinely readable.
- Marker files as an upward-walkable, language-agnostic context protocol. Hooks in bash
  and code in Python sharing one convention with no env vars is elegant, and it works.
- `lib.sh`'s comments. Three of them document bugs that cost hours and would otherwise
  have been rediscovered — `--bare` vs `--mirror` and `refs/pull/*`, `lld` living at a
  different Homebrew prefix than `llvm`, relative vs absolute symlink targets in a
  committed tree. That is the knowledge-capture thesis working exactly as intended, and
  it is the best argument in the repo for Karya continuing to exist.
