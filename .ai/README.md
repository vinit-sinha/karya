# AI Context — Karya

## What is Karya

Karya is a personal workspace management CLI (`bin/karya`, ~500 lines pure Python stdlib). It manages workspaces, projects, and work state checkpoints with git integration.

## Key Files

| File | Purpose |
|------|---------|
| `bin/karya` | The entire CLI — single Python script, no dependencies |
| `install.sh` | Copies repo to `~/tools/karya`, adds `bin/` to PATH |
| `templates/learning/` | Template for learning-type projects (files copied to project) |
| `templates/experiment/` | Template for experiment-type projects |
| `templates/project/` | Template for project-type projects |
| `docs/design.md` | Full design reference — read this to understand architecture |
| `docs/user-guide.md` | User-facing guide |
| `CLAUDE.md` | Git workflow rules — read before making any changes |

## Architecture

- **Workspace**: a directory with a `.karya-workspace` JSON marker at its root
- **Project**: a directory with a `.karya-project` JSON marker, created from a domain template
- **URI**: resources are identified by `kosh://domain/collection/project` URIs (see docs/design.md)
- **kosh://** scheme: karya's own URI scheme — resolved relative to workspace root
- **file://** scheme: standard absolute filesystem paths, no workspace needed
- **Marker files**: `.karya-workspace`, `.karya-domain`, `.karya-collection`, `.karya-project`, `.karya-subproject` — JSON files written at each level, scripts use these to locate context without env vars
- **Hierarchical templates**: `templates/` is a knowledge tree; each node can have `.karya/customizations/pre-create.sh` and `post-create.sh`; `.karya/` dirs are never copied into user projects
- **Workstate**: git-based checkpoints stored in `.karya/state-checkpoints/`

## Commands

```
karya init workspace
karya create project --uri kosh://domain/collection/project
karya publish project [--uri kosh://...] [--owner GITHUB_USER]
karya remove project --uri kosh://...
karya workstate save [NAME] [--description TEXT]
karya workstate resume [NAME] [--apply]
karya workstate list
```

## Template & Hook System

`karya create project --uri kosh://learning/mit/6s081` runs hooks from:
1. `templates/.karya/customizations/` — root (all projects)
2. `templates/learning/.karya/customizations/` — domain (all learning/*)
3. `templates/learning/mit/.karya/customizations/` — collection (all learning/mit/*)
4. `templates/learning/mit/6s081/.karya/customizations/` — project (this project only)

Scripts receive **no arguments and no environment variables**. They use:
- `$(dirname "$0")` — to locate their own customizations dir and `files/` assets
- Walk up from `$PWD` looking for `.karya-workspace` — to find workspace root
- `$PWD` in post-create — is the project root

`.karya/` directories are never copied into user projects. MPS node subdirectories (dirs with a `.karya/` child) are also excluded from template copy.

## Git Workflow (MANDATORY)

Read `CLAUDE.md` at the repo root. Never commit directly to `master`. Always use feature branches and PRs. Prefix every commit message with the GitHub issue number (e.g. `#9: feat: ...`).
