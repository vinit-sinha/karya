# AI Context — Karya v2.0

**Read this before doing anything.** Also read `CLAUDE.md` for the mandatory git workflow.

## What is Karya

Karya is a personal workspace management CLI (`bin/karya`, single Python file, pure stdlib, no dependencies). It manages workspaces, projects, and work state checkpoints with git integration. The design philosophy is zero-dependency, filesystem-first, and AI-friendly.

## Key Files

| File | Purpose |
|------|---------|
| `bin/karya` | The entire CLI — single Python script |
| `install.sh` | Copies repo to `~/tools/karya`, adds `bin/` to PATH |
| `templates/` | Knowledge tree — each node can have `.karya/customizations/` with hook scripts |
| `docs/design.md` | Full design reference — URI scheme, markers, template tree, hook system |
| `docs/user-guide.md` | User-facing guide |
| `CLAUDE.md` | Git workflow rules — read before making any changes |

## URI Scheme

Karya uses two URI schemes:

| Scheme | Example | Resolves to |
|--------|---------|-------------|
| `kosh://` | `kosh://learning/mit/6s081` | `<workspace-root>/learning/mit/6s081` |
| `file://` | `file:///Users/vinit/notes` | absolute filesystem path |

**Why "kosh"?** Karya = Hindi for *work*. Kosh (कोश) = Hindi for *repository/treasury*.

Segments: `kosh://domain/collection/project/subproject/...`

## Workspace Hierarchy & Marker Files

Every level of the hierarchy has a JSON marker file written by karya:

| Level | Marker file | Key fields |
|-------|-------------|------------|
| Workspace | `.karya-workspace` | `karya_version`, `uri: "kosh://"` |
| Domain | `.karya-domain` | `uri: "kosh://learning"` |
| Collection | `.karya-collection` | `uri: "kosh://learning/mit"` |
| Project | `.karya-project` | `uri`, `setup_status`, `completed_hooks` |
| Subproject | `.karya-subproject` | `uri` |

**`setup_status`** on `.karya-project` tracks project creation state:
- `"in_progress"` — set before post-create hooks run; left here if hooks fail
- `"complete"` — set only after ALL post-create hooks return success

This enables `karya create project --continue` and `--restart`.

## Commands

```
karya init workspace
karya create project --uri kosh://...               # fresh create
karya create project --uri kosh://... --continue    # resume interrupted setup
karya create project --uri kosh://... --restart     # delete and recreate
karya publish project [--uri kosh://...] [--owner GITHUB_USER]
karya remove project --uri kosh://...
karya workstate save [NAME] [--description TEXT]
karya workstate resume [NAME] [--apply]
karya workstate list
```

## Template & Hook System

`templates/` is a knowledge tree. Each node can optionally have a `.karya/customizations/` directory containing hook scripts.

**Hook execution order** for `karya create project --uri kosh://learning/mit/6s081`:
1. `templates/.karya/customizations/` — root (runs for every project)
2. `templates/learning/.karya/customizations/` — domain
3. `templates/learning/mit/.karya/customizations/` — collection
4. `templates/learning/mit/6s081/.karya/customizations/` — project-specific

**Hook scripts receive no arguments and no environment variables.** They self-locate using:
```bash
CUSTOMIZATION_DIR="$(cd "$(dirname "$0")" && pwd)"
# Walk up for workspace root:
dir="$PWD"
while [[ ! -f "$dir/.karya-workspace" && "$dir" != "/" ]]; do dir="$(dirname "$dir")"; done
WORKSPACE_ROOT="$dir"
```

`pre-create.sh` — non-zero exit aborts creation.  
`post-create.sh` — non-zero exit warns and leaves `setup_status: in_progress`. `run_hook()` returns bool; karya only marks complete when ALL hooks return True.

**`.karya/` directories are never copied into user projects.** MPS node dirs (dirs containing a `.karya/` child) are also excluded from template copy.

**`files/` inside a customization dir** is an asset store — scripts copy from it explicitly; nothing is auto-copied.

## Template .gitignore Exception

The root `.gitignore` excludes `.karya/` and `.vscode/` (correct for user project trees).  
`templates/.gitignore` un-excludes both so customizations and VS Code task files ship with the repo:
```
!.karya/
!.karya/**
!.vscode/
!.vscode/**
```

## README.md Placeholder Substitution

On `karya create project`, these placeholders in `README.md` are substituted:
- `{{PROJECT_NAME}}` → last URI segment (e.g. `6s081`)
- `{{DOMAIN}}` → first URI segment (e.g. `learning`)
- `{{COLLECTION}}` → second URI segment (e.g. `mit`)
- `{{PROJECT}}` → third URI segment (e.g. `6s081`)
- `PROJECT_NAME` → legacy support, same as `{{PROJECT_NAME}}`

`PROJECT.md` substitution is handled by `subst_project_metadata()` which fills Name, URI, Created, Status fields.

## Open Issues

| Issue | Title | Status |
|-------|-------|--------|
| [#7](https://github.com/vinit-sinha/karya/issues/7) | Template versioning across karya upgrades | Backlog |
| [#11](https://github.com/vinit-sinha/karya/issues/11) | Workstate save/resume hardening | Backlog |
| [#12](https://github.com/vinit-sinha/karya/issues/12) | Obsidian integration (`obs://` URI scheme, workspace-linked vault) | Backlog |
| [#13](https://github.com/vinit-sinha/karya/issues/13) | Fix stale docs, complete learning/mit/6s081 template | PR #14 open |
| [#15](https://github.com/vinit-sinha/karya/issues/15) | Hook class with step-level lifecycle (is_resumable, resume/restart per step) | Backlog |

**Issue #15 design summary**: Rejected Python Hook class in favour of per-hook completion tracking (`completed_hooks: [...]` in `.karya-project`). Bash scripts stay. If a step is not resumable, prompt user to do it manually and confirm. See issue for full design.

**Issue #12 design summary**: `obs://vault/path` scheme, `obsidian_root` in `.karya-workspace`, Obsidian content is reference-only (never versioned by karya). `karya promote` command to move a note into the karya project tree.

## Currently Open PR

[PR #14](https://github.com/vinit-sinha/karya/pull/14) — covers issues #13: template corrections, mit/6s081 customizations, VS Code tasks, setup_status tracking, --continue/--restart, GCC compat patch. Not yet merged to master.

## Git Workflow (MANDATORY)

1. Never commit directly to `master`
2. Always: `git checkout -b feature/<description>` first
3. Create a GitHub issue before starting work
4. Prefix every commit: `#<issue-number>: <message>`
5. Open a PR and merge via GitHub — never merge locally to master
6. Delete feature branch after merge

Current branch with open work: `feature/fix-template-and-docs` (PR #14).
