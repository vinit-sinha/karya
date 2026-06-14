# Karya

A lightweight CLI for managing personal workspaces — learning, experiments, and projects — with structured project templates and git integration.

## Prerequisites

- Python 3.9+
- Git
- `gh` CLI (optional, for publishing projects to GitHub)

## Installation

```bash
git clone https://github.com/vinit-sinha/karya.git
cd karya
bash install.sh
source ~/.zshrc   # or ~/.bashrc
```

Verify:

```bash
karya --help
```

## Concepts

| Concept | Description |
|---------|-------------|
| **Workspace** | A root directory managed by Karya, containing all your projects |
| **Project** | A structured directory with templates, git repo, and metadata |
| **MPS** | Mount Path Slug — the relative path of a project within the workspace (e.g. `learning/mit/6s081`) |
| **Type** | Project category: `learning`, `experiment`, or `project` |

## Quick Start

**1. Create a workspace:**
```bash
mkdir ~/workspace/my-workspace && cd ~/workspace/my-workspace
karya init workspace
```

**2. Create a project:**
```bash
karya create project --uri kosh://learning/mit/6s081
```

**3. Save your work state:**
```bash
cd learning/mit/6s081
karya workstate save
```

**4. Resume later:**
```bash
karya workstate resume
```

## Commands

```
karya init workspace                        Create a new workspace in the current directory
karya create project --uri kosh://...       Create a new project from the template hierarchy
karya publish project [--uri kosh://...]    Publish a project and wire up a git remote
karya remove project --uri kosh://...       Remove a project directory
karya workstate save [NAME]                 Save current git state as a named checkpoint
karya workstate resume [NAME]               Show or restore a saved checkpoint
karya workstate list                        List all saved checkpoints
```

Projects are addressed using the `kosh://` URI scheme — see [docs/user-guide.md](docs/user-guide.md) for details.

## Customizations

Karya ships with built-in knowledge for well-known projects, encoded directly in the `templates/` hierarchy. Each template node can have a `.karya/customizations/` directory containing `pre-create.sh` and `post-create.sh` hook scripts and a `files/` asset directory.

When you run `karya create project --uri kosh://learning/mit/6s081`, hooks run automatically from most-general to most-specific (root → domain → collection → project). Scripts need no arguments or environment variables — they locate context by walking up the filesystem via marker files.

See [docs/design.md](docs/design.md) for the full customization system design.

## Project Structure

After `karya create project --type learning --mps learning/mit/6s081`:

```
learning/mit/6s081/
├── PROJECT.md          # project metadata (name, type, MPS, status)
├── README.md
├── starter-code/       # for cloning upstream repos (lab-based courses)
├── study_materials/    # lectures, assignments, notes
└── work/               # your solutions and experiments
```

## Contributing

See [CLAUDE.md](CLAUDE.md) for the git workflow used in this repo.
