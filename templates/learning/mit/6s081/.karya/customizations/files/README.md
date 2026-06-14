# MIT 6.S081 — Operating System Engineering

Self-study of [MIT 6.S081](https://pdos.csail.mit.edu/6.828/2021/). You implement OS features in **xv6**, a small Unix-like kernel on RISC-V, through 10 labs.

---

## Getting started

Everything runs through **VS Code tasks** — no command memorization needed.

1. Open the Command Palette: **Cmd+Shift+P → Tasks: Run Task**
2. Pick **"Lab: start"** → select `util` (Lab 0)
3. Read the lab: https://pdos.csail.mit.edu/6.828/2021/labs/util.html
4. Edit kernel code in `starter-code/xv6-labs-2021/`
5. **Cmd+Shift+T → "xv6: run tests"** to run tests
6. **Cmd+Shift+T → "Lab: done"** when all tests pass

See `SETUP.md` for full setup status and all available tasks.

---

## Key files

| File | What it is |
|------|-----------|
| `SETUP.md` | Setup status, all VS Code tasks, directory layout |
| `LABS.md` | Lab tracker — update as you complete each lab |
| `CLAUDE.md` | Full instructions for humans and AI |
| `starter-code/xv6-labs-2021/` | xv6 kernel source — your code goes here |
| `work/<lab>/notes.md` | Your notes during a lab (created by "Lab: start") |
| `work/<lab>/writeup.md` | Post-completion reflection (created by "Lab: done") |

---

## If setup seems broken

```bash
karya create project --uri kosh://learning/mit/6s081 --continue
```
