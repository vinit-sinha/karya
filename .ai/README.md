# AI Context — Karya

## What is Karya

Karya is a personal workspace management CLI (`bin/karya`, ~800 lines pure Python stdlib). It manages workspaces, projects, and work state checkpoints with git integration.

## Key Files

| File | Purpose |
|------|---------|
| `bin/karya` | The entire CLI — single Python script, no dependencies |
| `install.sh` | Copies repo to `~/tools/karya`, adds `bin/` to PATH |
| `templates/learning/` | Template for learning-type projects |
| `templates/experiment/` | Template for experiment-type projects |
| `templates/project/` | Template for project-type projects |
| `CLAUDE.md` | Git workflow rules — read this before making any changes |

## Architecture

- **Workspace**: a directory with `WORKSPACE.md` at its root
- **Project**: a directory with `PROJECT.md`, created from a type template
- **MPS** (Mount Path Slug): relative path of a project within the workspace (e.g. `learning/mit/6s081`)
- **Customizations**: `customizations/` dir in the workspace with per-MPS hook scripts and file overlays
- **Workstate**: git-based checkpoints stored in `.karya/state-checkpoints/`

## Commands

```
karya init workspace
karya create project --type [learning|experiment|project] --mps <mps>
karya publish project [--mps MPS] [--owner GITHUB_USER]
karya remove project --mps MPS
karya workstate save [NAME]
karya workstate resume [NAME]
karya workstate list
```

## Customizations System

`karya create project` auto-discovers and runs scripts from `<workspace>/customizations/<mps-segments>/`:
- `pre-create.sh` — runs before project creation; failure aborts
- `post-create.sh` — runs after project creation; failure warns only
- `files/` subdirectory — contents are overlaid into the project root

Env vars passed to scripts: `KARYA_WORKSPACE_ROOT`, `KARYA_PROJECT_ROOT`, `KARYA_MPS`, `KARYA_TYPE`, `KARYA_PROJECT_NAME`

## Git Workflow (MANDATORY)

Read `CLAUDE.md` at the repo root. Never commit directly to `master`. Always use feature branches and PRs.
