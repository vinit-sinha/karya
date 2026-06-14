# Project Context Prompt

## What this project is

This is a **learning project** managed by [karya](https://github.com/vinit-sinha/karya).

- **URI:** `kosh://{{DOMAIN}}/{{COLLECTION}}/{{PROJECT}}`
- **Workspace tool:** karya CLI (`karya --help`)
- **Checkpoint tool:** `karya workstate save / resume / list`

## Directory layout

```
starter-code/        upstream source repos — treat as read-only reference
study_materials/     lectures, assignments, reference docs
work/                your solutions and experiments (commit here)
.ai/                 AI context — prompts, skills, tools
```

## Working conventions

- All meaningful work goes in `work/`. Keep `starter-code/` pristine.
- Save a checkpoint before switching machines or contexts:
  ```bash
  karya workstate save <name> --description "where I am"
  ```
- Resume a checkpoint:
  ```bash
  karya workstate resume <name> --apply
  ```

## AI assistant guidance

- Treat `study_materials/` and `starter-code/` as reference — never modify them unless the user explicitly asks.
- When the user asks to "save" or "checkpoint", run `karya workstate save`.
- When resuming a session, run `karya workstate list` first to show available checkpoints.
- Suggest committing work to git regularly; this project has a local git repo.
- Do not create files outside this project tree without asking.
