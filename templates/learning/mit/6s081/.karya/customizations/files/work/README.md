# work — Lab Notes & Writeups

This directory holds your **thinking, notes, and writeups** for each lab. The actual kernel code you modify lives in `starter-code/xv6-labs-2021/` — this is where you record your process.

## Why this separation?

`starter-code/xv6-labs-2021/` is the kernel source, tracked in its own git repo (one branch per lab, synced to your private GitHub mirror). Notes and writeups here are tracked in the *project* repo, keeping your thinking separate from your code changes and readable without checking out any branch.

## Structure

```
work/
├── README.md          ← this file
├── util/
│   ├── notes.md       ← working notes during the lab  (created by "Lab: start")
│   └── writeup.md     ← post-completion reflection    (created by "Lab: done")
├── syscall/
│   ├── notes.md
│   └── writeup.md
└── <lab>/...
```

## Workflow

**Starting a lab** — run VS Code task **"Lab: start"**, pick a lab:
- Checks out the lab branch in `starter-code/xv6-labs-2021/`
- Creates `work/<lab>/notes.md` from a template
- Saves a start checkpoint

**During the lab** — edit `work/<lab>/notes.md` as you go:
- Record your approach before you start coding
- Note observations and surprises as you debug
- Use **"xv6: boot"** (`Cmd+Shift+B`) to boot xv6
- Use **"xv6: run tests"** to run `make grade`
- Use **"Checkpoint: save"** before switching machines or taking a break

**Completing a lab** — run VS Code task **"Lab: done"**, pick the lab:
- Runs `make grade` (fails fast if tests don't pass)
- Creates `work/<lab>/writeup.md` from a template — fill it in while it's fresh
- Pushes the lab branch to your personal GitHub mirror
- Saves a done checkpoint

## Tips

- Write your approach in `notes.md` *before* you start coding — it clarifies thinking and makes debugging easier
- If you're stuck, the notes file is the right place to dump what you know and what you've tried
- Writeups don't have to be long — a few sentences per section is enough to cement learning
