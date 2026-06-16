# Karya User Guide

## What is Karya?

Karya (कार्य) is a Hindi word meaning *work*. Karya is a CLI tool for organising your personal work — learning, experiments, and projects — into a structured, git-backed workspace.

It does three things:
1. Gives every piece of work a **precise address** (`kosh://learning/mit/6s081`)
2. **Bootstraps projects** from built-in templates that encode everything karya knows about well-known courses, tools, and frameworks
3. **Saves and restores your work state** so you can context-switch cleanly

---

## Installation

### Prerequisites

| Prerequisite | Required for |
|---|---|
| Python 3.9+ | karya CLI |
| Git | all commands |
| `gh` CLI | GitHub integration (repo creation, auth) |
| `bash` | running hook scripts (pre/post-create) |

On **macOS and Linux**, bash is pre-installed. On **Windows**, use WSL2 — see [Windows users](#windows-users) below.

### Install

```bash
git clone https://github.com/vinit-sinha/karya.git
cd karya
bash install.sh
source ~/.zshrc    # or ~/.bashrc
```

Verify:
```bash
karya --help
```

---

## Windows users

The karya CLI itself (`bin/karya`) runs natively on Windows. However, **project templates that use hook scripts** (like `kosh://learning/mit/6s081`) require `bash`, `brew`, QEMU, and other Unix tools that are not available on native Windows.

**Use WSL2.** Microsoft ships it built into Windows 10/11:

```powershell
# In PowerShell (as administrator):
wsl --install
```

Then open an Ubuntu terminal and run karya from there. All commands and templates work as-is under WSL2.

If you run `karya create project` from Git Bash or MSYS2, the hook will detect this and print step-by-step WSL2 setup instructions.

---

## Core Concept: The Kosh URI

Every resource in karya has an address. Karya uses the standard [URI](https://www.rfc-editor.org/rfc/rfc3986) notation — the same notation used for web addresses — to identify resources.

Karya defines its own URI scheme called **kosh**.

### Why "kosh"?

Kosh (कोश) is a Hindi word meaning *repository* or *treasury*. If karya is the work, kosh is where the work lives. The name is one syllable, easy to pronounce for anyone, and pairs naturally with karya.

### kosh:// URIs

A `kosh://` URI identifies a location within your karya workspace:

```
kosh://domain/collection/project
```

The path segments have names:

| Position | Name | Example |
|----------|------|---------|
| 1 | Domain | `learning` |
| 2 | Collection | `mit` |
| 3 | Project | `6s081` |
| 4+ | Subproject | `lab1` |

**Real examples:**
```
kosh://learning/mit/6s081        ← MIT OS Engineering course
kosh://learning/mit/6824         ← MIT Distributed Systems course
kosh://experiments/llm/rag       ← an LLM experiment
kosh://projects/personal/karya   ← this tool itself
```

Karya resolves a `kosh://` URI relative to your **workspace root** — the directory where you ran `karya init workspace`.

### file:// URIs

Karya also understands `file://` for standard filesystem paths:

```
file:///Users/vinit/downloads/paper.pdf
```

Use `file://` when referencing something outside a karya workspace. Karya uses standard OS filesystem conventions to resolve it — no workspace needed.

---

## Your First Workspace

A workspace is a root directory that karya manages. Create one anywhere:

```bash
mkdir ~/workspace/personal && cd ~/workspace/personal
karya init workspace
```

This creates a `.karya-workspace` marker file and the standard domain directories:
```
~/workspace/personal/
├── .karya-workspace
├── learning/
├── experiments/
├── projects/
└── archive/
```

---

## Creating a Project

```bash
karya create project --uri kosh://learning/mit/6s081
```

Karya:
1. Looks up `templates/learning/` for the base template
2. Walks the URI path, running any `pre-create.sh` scripts it finds
3. Copies the template into `learning/mit/6s081/`
4. Places marker files at each level (`.karya-domain`, `.karya-collection`, `.karya-project`)
5. Initialises a git repository
6. Runs `post-create.sh` scripts — these can install tools, clone repos, create GitHub mirrors, and write VS Code tasks

### Built-in knowledge: 6s081

When you create `kosh://learning/mit/6s081`, karya's built-in hook already knows what to do:

**What the hook sets up automatically:**
- Installs the RISC-V toolchain and QEMU via Homebrew
- Creates (or reuses) a private GitHub repo and mirrors MIT's xv6 lab repo into it
- Clones from your GitHub repo as `origin`, and adds MIT's repo as a fetch-only `mit-upstream` remote (push blocked)
- Installs VS Code tasks for booting xv6, running tests, and managing labs
- Installs `scripts/lab-start.sh` and `scripts/lab-done.sh` for the per-lab workflow
- Writes `SETUP.md` with the full setup status table and next steps
- Writes `CLAUDE.md` with instructions for both humans and AI assistants

**The resulting project layout:**
```
learning/mit/6s081/
├── .karya-project          ← karya marker (setup_status, github_mirror)
├── CLAUDE.md               ← human + AI instructions; auto-read by Claude Code
├── README.md               ← getting started (shown by VS Code on first open)
├── SETUP.md                ← setup status and all VS Code task descriptions
├── LABS.md                 ← lab tracker — update as you complete each lab
├── PROJECT.md              ← karya project metadata
├── scripts/
│   ├── lab-start.sh        ← checkout lab branch, create notes.md, save checkpoint
│   └── lab-done.sh         ← make grade, create writeup.md, push, save checkpoint
├── .vscode/
│   ├── tasks.json          ← all VS Code tasks (boot, test, lab start/done, etc.)
│   └── settings.json       ← opens README.md on first VS Code launch
├── starter-code/
│   └── xv6-labs-2021/      ← MIT xv6 kernel (one branch per lab)
├── study_materials/        ← lecture slides, PDFs, reference docs
└── work/
    └── <lab>/
        ├── notes.md        ← created by "Lab: start"
        └── writeup.md      ← created by "Lab: done"
```

### Interrupted setup: --continue and --restart

Hook scripts can be slow (toolchain installs, git clones). If setup is interrupted, karya records `setup_status: in_progress` in `.karya-project` and tells you what to do:

```
Project setup was interrupted at /Users/you/workspace/mit/learning/mit/6s081
  Run with --continue to resume post-create hooks
  Run with --restart  to delete and start fresh
```

**Resume from where it stopped:**
```bash
karya create project --uri kosh://learning/mit/6s081 --continue
```

**Delete and start over:**
```bash
karya create project --uri kosh://learning/mit/6s081 --restart
```

A project already fully set up will refuse a plain `create` and suggest `--restart`.

### GitHub repo: no duplicates across machines

For templates that need their own GitHub repo (like 6s081's xv6 clone), karya stores the repo URL in `.karya-project` as `github_mirror`. On subsequent runs — whether `--continue`, a new directory on the same machine, or a fresh install on a different machine — karya reads this stored URL and reuses it instead of creating a new repo.

On a truly fresh machine with no stored URL, karya checks for an existing repo matching the expected name (e.g. `xv6-labs-2021`) under your GitHub account, and reuses it if found. Only if neither a stored URL nor an existing repo is found does it create a new private repo — mirroring the upstream source repo into it first.

Your GitHub repo is always the `origin` remote — read/write, the one you push to. If the template clones from an external upstream (MIT's `git://g.csail.mit.edu/xv6-labs-2021` for 6s081), that upstream is added as a separate fetch-only remote (`mit-upstream`) with push blocked via a `no_push` sentinel, so you never accidentally push to a repo you don't own.

---

## Saving and Resuming Work State

When switching contexts, save where you are:

```bash
cd learning/mit/6s081
karya workstate save
```

Later, pick up exactly where you left off:

```bash
karya workstate resume
```

Name checkpoints for important milestones:

```bash
karya workstate save lab1-complete
karya workstate resume lab1-complete
```

List all saved checkpoints:

```bash
karya workstate list
```

---

## Publishing a Project

When a project is ready to share:

```bash
karya publish project --uri kosh://learning/mit/6s081
```

This wires up a GitHub remote (using `gh` CLI if available) and updates `PROJECT.md` with the repository URL.

---

## Removing a Project

```bash
karya remove project --uri kosh://learning/mit/6s081
```

Karya removes the directory and prints the git cleanup steps needed.

---

## Open Topics

| Issue | Title |
|-------|-------|
| [#7](https://github.com/vinit-sinha/karya/issues/7) | Template versioning across karya upgrades |
| [#11](https://github.com/vinit-sinha/karya/issues/11) | Workstate save/resume hardening |
| [#12](https://github.com/vinit-sinha/karya/issues/12) | Obsidian integration (`obs://` URI scheme) |
| [#15](https://github.com/vinit-sinha/karya/issues/15) | Hook step-level lifecycle (`is_resumable`, resume/restart per step) |
