# Karya v1.0 Implementation Prompt

## Overview

Karya is a workspace and project management tool intended to support:

* Learning projects
* Experimental projects
* Long-term research and engineering projects

The tool must be implemented in Python 3.12+.

The implementation should prioritize:

* Simplicity
* Readability
* Extensibility
* Cross-machine portability
* Human-readable metadata
* AI-friendly project structure

The implementation should avoid unnecessary frameworks.

Use:

* argparse
* pathlib
* subprocess
* shutil
* datetime

Prefer standard library solutions whenever possible.

---

# CLI Design

The command grammar is:

```
karya <command> <entity> [options]
```

Examples:

```
karya init workspace

karya create project \
    --type learning \
    --mps learning/mit/6.828

karya publish project
```

Future commands may be added later.

Do not implement speculative future commands.

Implement only:

* init workspace
* create project
* publish project

---

# Workspace Model

A workspace is identified by:

```
WORKSPACE.md
```

Example:

```
Workspace/
├── WORKSPACE.md
├── learning/
├── experiments/
├── projects/
└── archive/
```

The tool must automatically discover the workspace root by walking upward from the current directory.

Pseudo logic:

```
current = cwd

while current != filesystem_root:
    if WORKSPACE.md exists:
        return current

    current = parent(current)
```

If no workspace is found:

```
fail with a clear error
```

No environment variables should be required.

No workspace path should be hardcoded.

---

# Project Model

Every project contains:

```
PROJECT.md
```

This file is the authoritative source of project metadata.

Example:

```
# Project

Name: cs162

Type: learning

MPS: learning/mit/6.828

Created: 2026-06-07

Status: Active

## Description

TODO

## Publication

Repository:

Visibility:
```

Project discovery should walk upward looking for:

```
PROJECT.md
```

exactly as workspace discovery does.

---

# MPS

Every project must be created using:

```
--mps
```

Example:

```
learning/mit/6.828

learning/berkeley/cs162

projects/miios/research

projects/miios/product
```

MPS stands for:

```
MetaProject/Project/SubProject
```

The full path should be created under the workspace root.

Example:

```
karya create project \
    --type learning \
    --mps learning/mit/6.828
```

creates:

```
Workspace/
└── learning/
    └── mit/
        └── 6.828/
```

The final path component becomes the project name.

---

# Project Types

Supported types:

```
learning
experiment
project
```

The type determines which template is used.

The type does NOT determine the target location.

Location comes exclusively from MPS.

---

# Template Layout

Templates reside under:

```
templates/
```

There are three templates:

```
templates/learning
templates/experiment
templates/project
```

## Learning Template

Contains:

```
course-material/
starter-code/
assignments/
solutions/
notes/
journal/
references/
.ai/
```

The starter-code directory exists specifically for externally supplied code such as:

* xv6
* Pintos
* JOS
* lab skeletons
* course starter repositories

## Experiment Template

Contains:

```
docs/
notes/
src/
tests/
scripts/
results/
.ai/
```

## Project Template

Contains:

```
docs/
    adr/
    architecture/
    specs/
    research/

experiments/
src/
tests/
scripts/
notes/
results/
.ai/
```

---

# ADR

Only the project template contains:

```
docs/adr
```

Provide:

```
docs/adr/0000-template.md
```

ADR format:

```
Context
Decision
Alternatives Considered
Consequences
```

---

# AI Directory

Every template contains:

```
.ai/
```

Containing:

```
README.md
agents/
hooks/
prompts/
skills/
tools/
```

These files should be created by default.

The .ai directory is intended to be committed to git.

---

# Git Ignore

Provide a reasonable .gitignore.

Must include:

```
.DS_Store
.AppleDouble
.Spotlight-V100
.Trashes
```

Also ignore:

```
.vscode
.idea
```

and common build artifacts.

---

# Command: init workspace

Example:

```
karya init workspace
```

Creates:

```
WORKSPACE.md
```

and:

```
learning/
experiments/
projects/
archive/
```

If already initialized:

```
do not overwrite
```

---

# Command: create project

Example:

```
karya create project \
    --type learning \
    --mps learning/mit/6.828
```

Requirements:

1. Discover workspace root automatically.

2. Resolve template from type.

3. Create target directory from MPS.

4. Copy template.

5. Replace PROJECT_NAME in README.md.

6. Generate PROJECT.md.

7. Initialize git.

8. Run:

   ```
   git add .
   ```

9. Create commit:

   ```
   Initial project skeleton for <project-name>
   ```

10. Provide clear status output.

---

# Command: publish project

Requirements:

1. Must be executed from inside a project.

2. Discover project root automatically.

3. Require GitHub CLI.

4. Verify:

   ```
   gh auth status
   ```

5. Ask:

   repository name
   visibility

6. Run:

   ```
   gh repo create
   ```

7. Configure remote.

8. Push initial branch.

9. Update PROJECT.md:

   ```
   Repository:
   Visibility:
   ```

10. Commit metadata update.

---

# Installation

Provide:

```
install.sh
```

Install under:

```
~/tools/karya
```

Add:

```
~/tools/karya/bin
```

to PATH.

---

# Quality Requirements

The implementation should:

* Use pathlib
* Use argparse
* Use subprocess safely
* Use type hints
* Be modular
* Avoid global mutable state
* Avoid hardcoded paths
* Produce helpful error messages

Provide:

* source tree
* implementation
* tests
* README

The final result should be suitable for long-term maintenance and daily use by an individual researcher working across multiple machines.
