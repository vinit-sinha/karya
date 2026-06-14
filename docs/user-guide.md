# Karya User Guide

## What is Karya?

Karya (कार्य) is a Hindi word meaning *work*. Karya is a CLI tool for organising your personal work — learning, experiments, and projects — into a structured, git-backed workspace.

It does three things:
1. Gives every piece of work a **precise address** (`kosh://learning/mit/6s081`)
2. **Bootstraps projects** from built-in templates that encode everything karya knows about well-known courses, tools, and frameworks
3. **Saves and restores your work state** so you can context-switch cleanly

---

## Installation

**Prerequisites:** Python 3.9+, Git, `gh` CLI (optional)

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
6. Runs `post-create.sh` scripts

The result:
```
learning/mit/6s081/
├── .karya-project
├── PROJECT.md
├── README.md
├── LABS.md              ← overlaid by karya's built-in 6s081 knowledge
├── starter-code/        ← for cloning MIT's upstream repo
├── study_materials/
└── work/
```

### Built-in knowledge

Karya ships with built-in knowledge for well-known projects. When you create `kosh://learning/mit/6s081`, karya already knows:
- The upstream git repo to clone (`git://g.csail.mit.edu/xv6-labs-2021`)
- The 10 lab branches and their work branch naming convention
- The `LABS.md` tracker to drop into your project

You don't need to look any of this up.

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

- **Template versioning** — how karya handles upgrades without breaking existing workspaces: [Issue #7](https://github.com/vinit-sinha/karya/issues/7)
