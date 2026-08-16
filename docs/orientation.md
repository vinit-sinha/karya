# Karya — Orientation

The document to read first, whether you are a human or an AI agent picking up this
repo. It explains what Karya is, what it is *for*, the ideas it is built on, how the
pieces fit together, and the things that will confuse you in the first hour.

For the formal spec of the URI scheme and template tree, see [design.md](design.md).
For end-user instructions, see [user-guide.md](user-guide.md). For an unsentimental
assessment of whether any of this is a good idea, see
[critical-review-2026-08.md](critical-review-2026-08.md).

---

## 1. What Karya is

Karya is a single-file Python CLI (`bin/karya`, ~1,200 lines, standard library only)
that manages a personal, git-backed workspace of learning material, experiments, and
projects.

It does exactly three things:

| Job | Mechanism |
|---|---|
| **Address** every piece of work | The `kosh://` URI scheme + marker files on disk |
| **Bootstrap** a project from encoded knowledge | The `templates/` tree + `pre-create.sh` / `post-create.sh` hooks |
| **Checkpoint and restore** work state across machines | `karya workstate save` / `resume`, backed by git |

Everything else in the repo — and by line count that is most of it — is *content*
for job 2: the accumulated setup knowledge for a handful of specific projects
(MIT 6.S081, and a set of xv6 reimplementation tracks in C, C++, and Rust).

### What Karya is not

- Not a build system, task runner, or package manager. It shells out to `git`, `gh`,
  `brew`, and `bash` and otherwise gets out of the way.
- Not multi-user, not a service, and has no daemon, database, or index. All state is
  files on disk.
- Not (yet) a generic scaffolder. The templates encode one person's specific projects,
  not a general catalogue.

### Origin and shape

Karya is the tool half of a two-part effort. The other half is a self-directed
operating-systems study program (MIT 6.S081, then xv6 reimplemented in C++26 and
Rust — see [mios-curriculum.md](mios-curriculum.md) and `MIT-LEARNING-PLAN.md`).
Karya exists because that program spans two machines, several toolchains, and setup
steps too fiddly to remember. Reading the git history in that light explains most of
the design: nearly every commit is a response to a concrete papercut hit while doing
the actual coursework.

---

## 2. Vocabulary

Learn these five words; the entire codebase is written in them.

| Term | Meaning | On disk |
|---|---|---|
| **Workspace** | The root directory Karya manages | `.karya-workspace` marker |
| **Domain** | Broad area of work — `learning`, `experiment`, `project` | `.karya-domain` |
| **Collection** | A body of work inside a domain — `mit`, `os-research` | `.karya-collection` |
| **Project** | The primary unit of work — `6s081`, `xv6-rust`. One git repo. | `.karya-project` |
| **Subproject** | Optional further subdivision | `.karya-subproject` |

A **`kosh://` URI** names a position in that hierarchy:

```
kosh://learning/mit/6s081
       └─domain └─coll └─project
```

`kosh` (कोश) is Hindi for *repository/treasury*; `karya` (कार्य) is Hindi for *work*.
Karya is what you do, kosh is where it lives.

Karya also accepts `file:///absolute/path` for things outside a workspace.

**MPS node** — a term you will meet in `bin/karya` and nowhere else. It means a
directory in `templates/` that has a `.karya/` child, i.e. a node that carries its own
customizations. The significance is negative: MPS nodes are *never* copied as content
during template expansion (see §5).

---

## 3. Design philosophy

These are the actual operating principles, stated with the trade-off each one buys.

### 3.1 The filesystem is the database

There is no index, no `~/.karya/state.json`, no registry. A directory's identity is a
JSON marker file sitting in it:

```json
{ "karya_version": "2.0", "level": "project",
  "uri": "kosh://learning/mit/6s081", "created_at": "2026-06-14",
  "setup_status": "complete" }
```

Anything that needs context walks *up* the tree until it finds the marker it wants.
That is how `find_workspace_root()` works in Python and how every hook script works in
bash. **Buys:** no state to corrupt, no sync problem, a workspace survives being moved,
copied, or partially restored; any tool in any language can participate by reading a
JSON file. **Costs:** no global queries ("list every project") without a full tree
walk, and no referential integrity — nothing notices when a marker's `uri` no longer
matches its path.

### 3.2 Zero dependencies

`bin/karya` imports only the standard library. No `pip install`, no lockfile, no
virtualenv. Installation is "copy the directory, put `bin/` on `PATH`". **Buys:** it
works on a fresh machine at 2am, and it will still run in five years. **Costs:** things
you would get for free from a library — argument parsing niceties, TOML config, a
templating engine — are hand-rolled or absent. Placeholder substitution is
`str.replace()` on `{{PROJECT_NAME}}`, and metadata substitution is line-prefix
matching in `subst_project_metadata()`.

### 3.3 Convention over configuration; no arguments, no environment variables

Hook scripts receive **nothing** — no argv, no env vars. They locate themselves with
`$(dirname "$0")` and locate their context by walking up to a marker file:

```bash
CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="$CUSTOMIZATION_DIR/files"
PROJECT_ROOT="$PWD"                       # karya runs post-create with cwd = project root
dir="$PROJECT_ROOT"
while [[ ! -f "$dir/.karya-workspace" && "$dir" != "/" ]]; do dir="$(dirname "$dir")"; done
WORKSPACE_ROOT="$dir"
```

**Buys:** a hook is a plain script you can run by hand from the right directory; there
is no calling convention to keep in sync between Python and bash. **Costs:** the
contract is implicit and undocumented at the call site; every hook re-implements the
same upward walk (grep for `karya-workspace` to see how many times).

### 3.4 Knowledge belongs in the tool, not in your head

This is the load-bearing idea. When you work out that xv6-labs-2021 needs
`-Wno-error=infinite-recursion` on a modern GCC, that fact does not go into a wiki —
it goes into `templates/learning/mit/6s081/.karya/customizations/post-create.sh` as a
patch step, and every future creation of that project on every machine gets it. The
template tree is a *knowledge tree*, and hook scripts are executable documentation.

Corollary, and the single most important convention in this repo:

> **Edit the template, not the materialized copy.** If you hand-edit a generated
> project's `CLAUDE.md`, `STAGES.md`, `README.md`, or scripts, the next
> `karya create project --continue` overwrites it. Fix it in
> `templates/.../.karya/customizations/files/` instead.

### 3.5 Setup is long, flaky, and therefore resumable

Post-create hooks install cross-compilers and clone kernels over the network; they
*will* fail halfway. So the project marker carries `setup_status`:

- `in_progress` — set before hooks run
- `complete` — set only after **all** post-create hooks exit 0

which drives `--continue` (re-run post-create hooks in place) and `--restart`
(delete and start over). The corresponding obligation is on hook authors:
**every hook must be idempotent.** Look at how `xv6_clone_kernel` checks for
`$KERNEL_DIR/.git` before cloning, or how the Makefile patch greps for its own flag
before applying — that pattern is mandatory, not stylistic.

### 3.6 Git-native, and a project is a repo

`karya create project` runs `git init` and makes the first commit. Nested repos
created by hooks (a cloned xv6) are auto-registered as **submodules** with their
branch recorded in `.gitmodules`, so a second machine can follow the branch rather
than a pinned SHA. Publishing means creating a GitHub repo via `gh` and pushing.
Work state is a git branch + a saved patch, not a bespoke snapshot format.

### 3.7 Written to be read by agents

`CLAUDE.md` files are generated *into* projects alongside `README.md`; markers are
JSON rather than empty sentinels; `.ai/` ships prompt/skill/agent stubs; the
`os-research` collection carries a six-phase [agentic workflow](../templates/project/os-research/.karya/customizations/files/docs/agentic-workflow.md)
that an AI is expected to follow. Karya assumes its user is a human *and* a model, and
optimizes the on-disk layout for both.

### 3.8 Layered specificity

Everything — templates, hooks, docs — is arranged root → domain → collection →
project, applied in that order, most-general first. Shared behaviour lives at the
level where it is shared (`templates/project/os-research/.karya/customizations/lib.sh`
holds the functions all four xv6 tracks use), and each level only encodes knowledge
about itself, never about its children.

---

## 4. Repository map

```
karya/
├── bin/karya                  ← the entire CLI (single Python file, stdlib only)
├── install.sh                 ← copies repo to ~/tools/karya, appends to PATH in shell rc
├── CLAUDE.md                  ← MANDATORY git workflow (branch → PR → merge; never on master)
├── docs/
│   ├── design.md              ← formal spec: URIs, markers, template tree, hooks
│   ├── user-guide.md          ← end-user manual
│   ├── orientation.md         ← this file
│   ├── critical-review-*.md   ← adversarial assessment of the repo
│   └── mios-curriculum.md     ← personal OS-study reading plan (content, not tool docs)
├── MIT-LEARNING-PLAN.md       ← 2026-06 session handoff note (historical)
├── .ai/                       ← AI context for working on karya itself (see §7 caveat)
└── templates/                 ← the knowledge tree — most of the repo by volume
    ├── learning/              ← domain template (copied into learning/* projects)
    │   └── mit/               ← collection: shared MIT hooks
    │       └── 6s081/         ← project: toolchain install, xv6 mirror, VS Code tasks,
    │                             lab scripts, and a local HTML courseware site
    ├── project/               ← domain template
    │   └── os-research/       ← collection: shared lib.sh, collection-level CLAUDE.md
    │       ├── xv6-c/         ← C reference track
    │       ├── xv6-c-cmake/   ← same source, CMake+Ninja, GCC vs LLVM benchmark
    │       ├── xv6-cpp/       ← staged C++26 reimplementation
    │       └── xv6-rust/      ← staged Rust reimplementation
    └── experiment/            ← domain template
```

Rough proportions: CLI ~1.2k lines; template shell hooks ~1.7k lines; template
HTML/JS/CSS/Python (the 6.S081 courseware site) ~2.6k lines; template Markdown ~3.2k
lines. **The tool is the small part.**

---

## 5. How `karya create project` actually works

This is the heart of the system. Tracing it once explains most of the code.
For `karya create project --uri kosh://learning/mit/6s081`:

1. **Parse and resolve.** `parse_uri` → scheme `kosh`, path `learning/mit/6s081`.
   `find_workspace_root(cwd)` walks up for `.karya-workspace`. Project path =
   workspace root + URI segments.

2. **Detect existing state.** If the directory exists, branch on the marker's
   `setup_status`: refuse (already complete), or advise `--continue` / `--restart`.

3. **Machine-2 shortcut.** `_clone_from_remote()` asks GitHub whether
   `<user>/learning-mit-6s081` already exists. If it does, Karya *clones instead of
   creating*, initialises submodules with `--remote` (follow the branch, not a pinned
   SHA), writes the intermediate markers, and offers to apply the latest workstate
   checkpoint. This is how the same URI produces a working tree on a second machine.

4. **Discover hooks.** `discover_hooks()` collects, in order:
   `templates/.karya/customizations/` (root, if present) → `templates/learning/…` →
   `templates/learning/mit/…` → `templates/learning/mit/6s081/…`.

5. **Run `pre-create.sh`** for each, cwd = workspace root, in that order. Non-zero
   exit **aborts**.

6. **Copy the template.** `copy_template()` copies **`templates/<domain>/`** — note:
   the *domain* template only — into the project directory, excluding (a) any `.karya/`
   directory and (b) any first-level subdirectory that is an MPS node. That exclusion
   is what stops `templates/learning/mit/` from being copied into the project as
   content. Deeper template levels contribute **hooks only**, never files.

7. **Write markers** at each level, project marker seeded with
   `setup_status: in_progress`.

8. **Substitute metadata** in `PROJECT.md` (`Name:`, `URI:`, `Created:`, `Status:`)
   and placeholders in `README.md` (`{{PROJECT_NAME}}`, `{{DOMAIN}}`, `{{COLLECTION}}`,
   `{{PROJECT}}`).

9. **`git init`** + `git add .` + initial commit; install the workstate hook.

10. **Run `post-create.sh`** for each customization level, cwd = **project root**
    (not the hook's own level — collection hooks that want to write at the collection
    level must walk up, as `os-research/post-create.sh` does). Non-zero exit **warns**
    and leaves `setup_status: in_progress`.

11. **Register embedded repos** as submodules, mark `setup_status: complete`, and
    **auto-publish to GitHub** unless `--no-publish` was passed.

### The hook contract in one box

```
pre-create.sh    cwd = workspace root   non-zero → abort creation
post-create.sh   cwd = project root     non-zero → warn, setup stays in_progress
both             no argv, no env vars   must be idempotent
files/           asset store for that level — nothing is auto-copied; the script copies
```

---

## 6. Work state, and the two-machine story

`karya workstate save [name]` records, for the project's repo *and every registered
submodule*: the current branch, the remote URL, and a patch of all uncommitted work
(staged + unstaged + untracked, the last via `git diff --no-index /dev/null <file>`).
It writes `.karya/state-checkpoints/<name>.json` plus `<name>.patch`.

`karya workstate resume [name] [--apply]` checks out the recorded branch (creating a
tracking branch from `origin/` if needed), pulls fast-forward, and either reports or
applies the patch.

The intended loop: work on machine A → `workstate save` → on machine B,
`karya create project --uri <same-uri>` detects the remote and clones → offers to apply
the checkpoint → you continue. Karya's answer to "what was I doing?" is a git branch
plus a patch, deliberately, so nothing is locked inside a Karya-specific format.

> Note: this subsystem is the least sound part of the codebase. Read
> [the critical review](critical-review-2026-08.md) §B before relying on it.

---

## 7. Things that will confuse you in the first hour

These are real, currently-true inconsistencies. Knowing them up front saves an
afternoon.

1. **`init workspace` creates domain directories that have no templates.** It creates
   `learning/`, `experiments/`, `projects/`, `archive/`, but the templates are named
   `learning`, `experiment`, `project` (singular). `kosh://experiments/...` and
   `kosh://projects/...` both fail; the working domains are `learning`, `experiment`,
   `project`.

2. **`gh` is documented as optional but is effectively required.** Without it on
   `PATH`, `karya create project` aborts with a Python traceback.

3. **Spelling.** `docs/design.md` writes `.karya/customisations/` (British). The code
   and every real directory use `customizations` (American). The code wins.

4. **Two install locations.** `install.sh` copies to `~/tools/karya`, but the
   `os-research` collection docs state that `~/workspace/tools/karya` is the one and
   only working copy, run directly off `PATH`. If both exist you will edit one and run
   the other. Check `which karya` before debugging anything.

5. **`.ai/README.md` is stale.** It describes an open PR #14, a feature branch that no
   longer exists, and a `completed_hooks` marker field that was never implemented.
   Treat this file as historical; `docs/design.md` and the code are authoritative.

6. **A documented root-level hook does not exist.** `design.md` shows
   `templates/.karya/customizations/`. There is no such directory; the code handles its
   absence fine.

7. **Karya mutates global machine state.** Post-create hooks run `brew install` and —
   in the 6.S081 hook — rewrite your *user-level* VS Code `keybindings.json`, rebinding
   `Cmd+Shift+B` for every project you open, not just this one. Read a hook before you
   run it.

---

## 8. Working on this repo

- **Git workflow is mandatory and enforced by convention, not tooling**
  (`CLAUDE.md`): branch off `master`, commit only on the branch, open a PR with
  `gh pr create`, merge on GitHub, delete the branch. Never commit to `master`.
  Historically commits are prefixed with the issue number: `#42: <message>`.
- **Changing project behaviour means changing a template**, not a generated project.
- **Test by creating a throwaway workspace** — there is no test suite, so the only
  verification available is `karya init workspace` in a temp directory followed by
  `karya create project --uri ... --no-publish`. Always pass `--no-publish` when
  testing; without it, Karya will try to create a real GitHub repo.
- **Hooks must stay idempotent** — they are re-run by `--continue` and by every
  subsequent create of any sibling project in the same collection.
