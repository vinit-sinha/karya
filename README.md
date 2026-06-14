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
karya create project --type learning --mps learning/mit/6s081
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
karya init workspace                          Create a new workspace in the current directory
karya create project --type TYPE --mps MPS   Create a new project from a template
karya publish project [--mps MPS]            Mark a project as published and wire up a git remote
karya remove project --mps MPS               Remove a project directory
karya workstate save [NAME]                  Save current git state as a named checkpoint
karya workstate resume [NAME]                Show or restore a saved checkpoint
karya workstate list                         List all saved checkpoints
```

## Customizations

Workspaces support hook scripts and file overlays that run automatically when projects are created.

Place scripts under `customizations/` in your workspace, mirroring the MPS path:

```
customizations/
└── learning/
    └── mit/
        ├── post-create.sh          # runs after every MIT project is created
        └── 6s081/
            └── files/
                └── LABS.md         # overlaid into every 6s081 project
```

Scripts receive these environment variables:

| Variable | Description |
|----------|-------------|
| `KARYA_WORKSPACE_ROOT` | Absolute path to the workspace |
| `KARYA_PROJECT_ROOT` | Absolute path to the new project |
| `KARYA_MPS` | MPS of the project (e.g. `learning/mit/6s081`) |
| `KARYA_TYPE` | Project type (e.g. `learning`) |
| `KARYA_PROJECT_NAME` | Project name (last segment of MPS) |

- `pre-create.sh` — runs before project creation; non-zero exit aborts the command
- `post-create.sh` — runs after project creation; non-zero exit warns but does not undo

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
