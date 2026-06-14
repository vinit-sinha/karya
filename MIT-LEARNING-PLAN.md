# MIT Learning Plan — Session Handoff

**Last updated**: 2026-06-10  
**Status**: Workspace and all 6 course projects created. Git clones pending SSH key setup.

---

## What We Are Doing

Setting up **karya** as the workspace management tool for self-studying a curated list of MIT courses. The user is not an MIT student — all access is via public repos only.

The course list lives at:
`/Users/vinitsinna/Library/Mobile Documents/iCloud~md~obsidian/Documents/MIT/_Meta/00-Plan/MIT Courses for miiOS and Interviews.md`

---

## The MIT Courses

| # | Course | Code | Type | Git Needed? |
|---|--------|------|------|-------------|
| 1 | Computer Systems Engineering | 6.033 | Theory / design paper | No |
| 2 | Principles of Computer Systems | 6.826 | Theory / math (two blended versions: old handouts + new videos) | No |
| 3 | Distributed Algorithms | 6.852J | Theory / formal methods (Tempo lang) | No |
| 4 | Distributed Systems Engineering | 6.824 / 6.5840 | Lab-heavy (Go: MapReduce, Raft, KV) | Yes |
| 5 | Performance Engineering | 6.172 | Lab-heavy (C, parallelism) | Partially |
| 6 | OS Engineering | 6.S081 | Lab-heavy (xv6 kernel, RISC-V) | Yes |

---

## Confirmed Public Git Access (No MIT Login Needed)

Both CSAIL git servers are publicly accessible, verified working:

### 6.S081 — xv6 labs
```
git://g.csail.mit.edu/xv6-labs-2021
```
Per-lab branches confirmed: `util`, `syscall`, `pgtbl`, `traps`, `cow`, `thread`, `net`, `lock`, `fs`, `mmap`

### 6.5840 / 6.824 — Distributed Systems labs
```
git://g.csail.mit.edu/6.5840-golabs-2026
```
Single `master` branch. Labs are subdirectories (MapReduce, Raft, KV, Sharded KV).

> `gh` CLI is installed and authenticated (HTTPS protocol). Use it for repo creation and GitHub operations.

---

## Workspace Layout (Created)

```
~/workspace/mit/
├── WORKSPACE.md
├── customizations/
│   └── learning/
│       └── mit/
│           ├── post-create.sh       ← prints setup reminder for all MIT courses
│           ├── 6s081/
│           │   └── files/
│           │       └── LABS.md      ← xv6 lab tracker (10 labs)
│           └── 6824/
│               └── files/
│                   └── LABS.md      ← 6.824 lab tracker (4 labs)
└── learning/
    └── mit/
        ├── 6033/     ← karya project ✓
        ├── 6826/     ← karya project ✓
        ├── 6852j/    ← karya project ✓
        ├── 6s081/    ← karya project ✓ (has LABS.md)
        ├── 6824/     ← karya project ✓ (has LABS.md)
        └── 6172/     ← karya project ✓
```

---

## Git Workflow for Lab-Based Courses

```bash
# 1. Clone MIT's public repo into starter-code/
cd ~/workspace/mit/learning/mit/<course>/starter-code
git clone git://g.csail.mit.edu/<repo-name> <folder-name>

# 2. Create personal GitHub repo and push
cd <folder-name>
gh repo create <repo-name> --private --source=. --remote=personal --push

# 4. Per lab — work branch off MIT's lab branch (never modify MIT branches)
git checkout -b lab/util-work origin/util
# ... do work, commit to lab/util-work only ...
```

MIT's branches stay untouched as baselines. Your work lives entirely in `lab/<name>-work` branches.

---

## Karya Customizations System (Implemented)

`bin/karya` now has three new functions wired into `create_project`:

- **`discover_customizations(workspace_root, mps)`** — walks MPS segments, returns matching dirs in `customizations/` from general→specific
- **`run_custom_scripts(dirs, event, ...)`** — runs `pre-<event>.sh` / `post-<event>.sh` with env vars; pre-script failure aborts, post-script failure warns
- **`copy_custom_files(dirs, project_root)`** — overlays `files/` subdirectories into the project after template copy

Env vars passed to scripts: `KARYA_WORKSPACE_ROOT`, `KARYA_PROJECT_ROOT`, `KARYA_MPS`, `KARYA_TYPE`, `KARYA_PROJECT_NAME`

---

## GitHub Auth Status

- `gh` CLI installed and authenticated via HTTPS ✓ (`gh auth status` confirmed)
- No SSH key needed — `gh` handles all GitHub operations

---

## What Has NOT Been Done Yet

- [ ] No git clones of MIT starter repos yet
- [ ] No personal GitHub repos created yet

---

## Where to Start Next Session

1. **Clone 6.S081 starter code**:
   ```bash
   cd ~/workspace/mit/learning/mit/6s081/starter-code
   git clone git://g.csail.mit.edu/xv6-labs-2021 xv6-riscv
   cd xv6-riscv
   gh repo create xv6-labs-2021 --private --source=. --remote=personal --push
   ```
2. **Clone 6.824 starter code**:
   ```bash
   cd ~/workspace/mit/learning/mit/6824/starter-code
   git clone git://g.csail.mit.edu/6.5840-golabs-2026 6824-labs
   cd 6824-labs
   gh repo create 6.5840-golabs-2026 --private --source=. --remote=personal --push
   ```
3. **Start Lab 1 (Utilities) for 6.S081**:
   ```bash
   cd ~/workspace/mit/learning/mit/6s081/starter-code/xv6-riscv
   git checkout -b lab/util-work origin/util
   ```

---

## Key Files

- `/Users/vinit/workspace/tools/karya/bin/karya` — main CLI (customizations system added)
- `~/workspace/mit/learning/mit/6s081/LABS.md` — 6.S081 lab tracker
- `~/workspace/mit/learning/mit/6824/LABS.md` — 6.824 lab tracker
