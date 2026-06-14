# 6.S081 — Instructions for Humans and AI

## What this project is

Self-study of [MIT 6.S081 Operating System Engineering](https://pdos.csail.mit.edu/6.828/2021/).  
You extend **xv6**, a small Unix-like kernel running on RISC-V, through 10 labs.

- **Workspace tool:** karya (`kosh://learning/mit/6s081`)
- **Kernel source:** `starter-code/xv6-labs-2021/` — one git branch per lab
- **Your notes:** `work/<lab>/notes.md` and `work/<lab>/writeup.md`
- **Lab tracker:** `LABS.md` — update as you complete labs
- **Setup status:** `SETUP.md` — read this if anything seems broken

---

## For humans — how to work

### Starting a lab
1. `Cmd+Shift+P → Tasks: Run Task → Lab: start` → pick the lab (e.g. `util`)
2. Read the instructions: `https://pdos.csail.mit.edu/6.828/2021/labs/<lab>.html`
3. Take notes in `work/<lab>/notes.md` as you go

### During a lab
- **Boot xv6:** `Cmd+Shift+P → Tasks: Run Task → xv6: boot` (Ctrl-a x to exit)
- **Run tests:** `Cmd+Shift+T → xv6: run tests`
- **Save progress:** `Cmd+Shift+P → Tasks: Run Task → Checkpoint: save`

### Finishing a lab
1. `Cmd+Shift+T → Lab: done` — runs all tests, creates writeup, pushes branch, saves checkpoint
2. Fill in `work/<lab>/writeup.md` while the lab is fresh
3. Mark the lab done in `LABS.md`

### Switching machines
```bash
karya workstate save <name> --description "where I left off"
# on the other machine:
karya workstate resume <name> --apply
```

### If setup seems broken
```bash
cd ~/workspace/mit
karya create project --uri kosh://learning/mit/6s081 --continue
```
Or: `Cmd+Shift+P → Tasks: Run Task → Setup: re-run post-create`

### Windows users
QEMU and the RISC-V toolchain don't run natively on Windows. **WSL2 is required** — MIT recommends it for the course.

```powershell
# In PowerShell (admin):
wsl --install
```

Run karya and all lab work from inside the Ubuntu WSL terminal. VS Code's WSL extension (`ms-vscode-remote.remote-wsl`) lets you open the project in VS Code while the filesystem and terminal stay in WSL.

MIT's Windows setup guide: https://pdos.csail.mit.edu/6.828/2021/tools.html

---

## For AI — context and rules

### Session start checklist
1. Read `SETUP.md` — confirms setup status and next steps
2. Read `LABS.md` — shows which labs are done
3. Read `work/<current-lab>/notes.md` — shows where work left off
4. Check `git -C starter-code/xv6-labs-2021 branch --show-current` — confirms active lab

### Directory rules
| Directory | Rule |
|-----------|------|
| `starter-code/xv6-labs-2021/` | All kernel code changes go here |
| `work/<lab>/` | Notes and writeups only — no kernel code |
| `study_materials/` | Reference only — never modify |
| `scripts/` | Lab workflow scripts — do not modify without asking |

### Behaviour rules
- When user says "save" or "checkpoint": run `karya workstate save`
- When resuming: run `karya workstate list` first, then `karya workstate resume <name> --apply`
- Suggest committing kernel work with `git add -A && git commit` inside `starter-code/xv6-labs-2021/`
- Do not create files outside this project tree without asking
- Do not run `make qemu` unattended — it boots an interactive OS; let the user do it via VS Code task

### Known quirks
- **Makefile GCC patch:** `starter-code/xv6-labs-2021/Makefile` has `-Wno-error=infinite-recursion` — needed for newer `riscv64-unknown-elf-gcc`. Applied by setup hook, not upstream.
- **Branch naming:** MIT docs say `pagetable` but the actual git branch is `pgtbl`
- **Auth:** All git operations use gh's HTTPS credential helper — no SSH key needed

### Resources
- Course: https://pdos.csail.mit.edu/6.828/2021/schedule.html
- xv6 book: https://pdos.csail.mit.edu/6.828/2021/xv6/book-riscv-rev2.pdf
- Lab instructions: https://pdos.csail.mit.edu/6.828/2021/labs/
