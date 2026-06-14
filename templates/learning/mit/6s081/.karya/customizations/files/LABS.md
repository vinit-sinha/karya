# 6.S081 Lab Tracker

Update the Status column as you work. Use VS Code tasks for all lab operations.

| # | Branch | Lab | Status | Notes |
|---|--------|-----|--------|-------|
| 0 | util | Unix utilities (sleep, pingpong, primes, find, xargs) | | |
| 1 | syscall | Add trace + sysinfo system calls | | |
| 2 | pagetable | Per-process kernel page tables | | |
| 3 | traps | RISC-V traps, backtrace, alarm | | |
| 4 | cow | Copy-on-write fork | | |
| 5 | thread | Green threads (uthread), barrier | | |
| 6 | net | UDP network stack + E1000 driver | | |
| 7 | lock | Lock contention — kalloc, buffer cache | | |
| 8 | fs | Large files, symbolic links | | |
| 9 | mmap | Memory-mapped files | | |

## Per-lab workflow — all via VS Code tasks (Cmd+Shift+P → Tasks: Run Task)

### Starting a lab
1. **"Lab: start"** → pick the lab from the dropdown
   - Checks out the lab branch in `starter-code/xv6-labs-2021/`
   - Creates `work/<lab>/notes.md` — write your plan before you code
   - Saves a start checkpoint

### During the lab
2. Read the instructions: https://pdos.csail.mit.edu/6.828/2021/labs/\<lab\>.html
3. Edit kernel source in `starter-code/xv6-labs-2021/`
4. **"xv6: boot"** (`Cmd+Shift+B`) — boot xv6 in QEMU, test manually
5. **"xv6: run tests"** — run `make grade`
6. **"Checkpoint: save"** — save state before breaks or machine switches

### Completing a lab
7. **"Lab: done"** → pick the lab
   - Runs `make grade` (fails if tests don't pass)
   - Creates `work/<lab>/writeup.md`
   - Pushes the lab branch to your personal GitHub mirror
   - Saves a done checkpoint
8. Mark lab as done in the table above

## Debugging

- **"xv6: debug"** — starts QEMU in GDB mode
- In another terminal: `riscv64-unknown-elf-gdb kernel/kernel`
- In GDB: `target remote localhost:26000`
- The xv6 book chapter for each lab is the best reference: https://pdos.csail.mit.edu/6.828/2021/xv6/book-riscv-rev2.pdf

## Resources

| Resource | URL |
|----------|-----|
| Course (2021) | https://pdos.csail.mit.edu/6.828/2021/ |
| Schedule + slides | https://pdos.csail.mit.edu/6.828/2021/schedule.html |
| xv6 book | https://pdos.csail.mit.edu/6.828/2021/xv6/book-riscv-rev2.pdf |
| xv6 source | https://github.com/mit-pdos/xv6-riscv |
