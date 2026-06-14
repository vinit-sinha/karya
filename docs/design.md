# Karya — Design Reference

## Overview

Karya is a personal workspace management CLI. It organises work into a hierarchy of named locations — workspaces, domains, collections, projects — and encodes "what we know" about well-known projects directly into the tool via a hierarchical template and customisation system.

---

## URI Scheme: `kosh://`

### Why URIs

Karya uses the [IEEE / IETF URI](https://www.rfc-editor.org/rfc/rfc3986) notation to identify resources (workspaces, projects, files). A URI uniquely identifies a resource and carries enough information to locate it — which is exactly what karya needs when creating, publishing, or referencing projects.

### The `kosh://` scheme

Karya defines a custom URI scheme called **kosh**.

**Why "kosh"?** Karya is a Hindi word meaning *work*. Kosh (कोश) is a Hindi word meaning *repository* or *treasury* — the place where work lives. Together: karya is what you do, kosh is where it lives. The name is short, unambiguous to pronounce (one syllable: "kosh"), and pairs intuitively with karya.

A `kosh://` URI identifies a resource within a karya-managed workspace:

```
kosh://domain/collection/project/subproject/...
```

The first four path segments have explicit, named roles:

| Segment | Name | Example | Description |
|---------|------|---------|-------------|
| 1 | Domain | `learning` | Broad area of work (learning, experiments, projects) |
| 2 | Collection | `mit` | A body of work within the domain |
| 3 | Project | `6s081` | The primary unit of work |
| 4+ | Subproject | `lab1` | Further subdivisions within a project |

**Examples:**
```
kosh://learning/mit/6s081
kosh://experiments/llm/rag-prototype
kosh://projects/personal/karya
```

Resolution: karya walks up the filesystem from `cwd` looking for a `.karya-workspace` marker file to find the workspace root, then appends the URI path.

### The `file://` scheme

Karya also understands the standard `file://` scheme for referencing resources by absolute filesystem path, using standard OS and filesystem conventions — no workspace root needed.

```
file:///Users/vinit/notes/scratch
file:///tmp/experiment
```

Use `file://` when working with paths outside a karya workspace, or when the exact filesystem location matters more than the logical karya address.

### Scheme comparison

| | `kosh://` | `file://` |
|--|-----------|-----------|
| Requires workspace | Yes | No |
| Portable across machines | Yes (relative to workspace) | No (absolute path) |
| Carries semantic meaning | Yes (domain/collection/project) | No |
| Used for | All karya-managed projects | External files and paths |

---

## Workspace Hierarchy

A karya workspace is a filesystem tree where each level is marked by a hidden marker file. These marker files allow scripts and tools to understand the topology without any arguments or environment variables.

```
~/workspace/mit/                        .karya-workspace
└── learning/                           .karya-domain
    └── mit/                            .karya-collection
        └── 6s081/                      .karya-project
            └── lab1/                   .karya-subproject
```

Marker files contain metadata in JSON format:

```json
{
  "karya_version": "1.0",
  "template_version": "1.0",
  "created_at": "2026-06-14",
  "uri": "kosh://learning/mit/6s081"
}
```

> ⚠️ See [Issue #7](https://github.com/vinit-sinha/karya/issues/7): template version compatibility across karya upgrades is a known open problem. Marker file versioning is the foundation of the planned solution.

---

## Hierarchical Templates and Customisations

### Template tree

`templates/` is a knowledge tree. Each node can have a `.karya/customisations/` directory encoding what karya knows about that level:

```
templates/
├── .karya/
│   └── customisations/
│       ├── ROOT.md             ← documents what root hooks do
│       ├── pre-create.sh       ← runs for every project
│       ├── post-create.sh
│       └── files/              ← assets for root-level hooks only
├── learning/
│   ├── PROJECT.md              ← copied into project
│   ├── README.md               ← copied into project
│   ├── starter-code/           ← copied into project
│   ├── study_materials/        ← copied into project
│   ├── work/                   ← copied into project
│   ├── .karya/
│   │   └── customisations/
│   │       ├── learning.md     ← documents what domain hooks do
│   │       ├── pre-create.sh   ← runs for every learning/* project
│   │       ├── post-create.sh
│   │       └── files/          ← assets for domain-level hooks only
│   └── mit/                    ← MPS node (has .karya/ child — never copied)
│       ├── .karya/
│       │   └── customisations/
│       │       ├── mit.md
│       │       ├── pre-create.sh   ← runs for every learning/mit/* project
│       │       ├── post-create.sh
│       │       └── files/
│       └── 6s081/              ← MPS node
│           └── .karya/
│               └── customisations/
│                   ├── 6s081.md
│                   ├── pre-create.sh   ← runs only for learning/mit/6s081
│                   ├── post-create.sh
│                   └── files/
│                       └── LABS.md     ← overlaid by post-create.sh
```

### Rules

- `.karya/` directories are **never copied** into the project — they are karya's internal metadata
- Each `.karya/customisations/` encodes knowledge for **that node only**, not its children
- `files/` within a customisation is an asset store for the scripts at that level — scripts decide what to do with them; nothing is auto-copied
- Scripts are invoked in order from most-general to most-specific: root → domain → collection → project

### Hook scripts

`pre-create.sh` and `post-create.sh` are plain bash scripts. They receive no arguments and no environment variables. Instead they use filesystem conventions to derive context:

```bash
# Where am I? (the customisation directory containing this script)
CUSTOMISATION_DIR="$(cd "$(dirname "$0")" && pwd)"

# Where is the workspace root? (walk up looking for .karya-workspace)
dir="$CUSTOMISATION_DIR"
while [[ ! -f "$dir/.karya-workspace" && "$dir" != "/" ]]; do
    dir="$(dirname "$dir")"
done
WORKSPACE_ROOT="$dir"

# Assets for this level
FILES_DIR="$CUSTOMISATION_DIR/files"
```

- `pre-create.sh`: non-zero exit **aborts** project creation
- `post-create.sh`: non-zero exit **warns** but does not undo

---

## Commands

```
karya init workspace                         Initialise a workspace in the current directory
karya create project --uri kosh://...        Create a project from the template hierarchy
karya publish project [--uri kosh://...]     Publish a project to a remote repository
karya remove project --uri kosh://...        Remove a project
karya workstate save [NAME] [--description]  Save current git state as a named checkpoint
karya workstate resume [NAME] [--apply]      Restore or inspect a saved checkpoint
karya workstate list                         List all saved checkpoints
```

---

## Open Issues

- [#7 Versioning: karya template compatibility across upgrades](https://github.com/vinit-sinha/karya/issues/7)
