# 6.S081 Lab Tracker

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

## Workflow per lab

```bash
cd starter-code/xv6-labs-2021
git checkout <branch>          # e.g. util
git checkout -b work/<branch>  # your working branch

# implement, then test:
make grade

# when done:
git add -A && git commit -m "lab: <name> — all tests pass"
git push personal work/<branch>
karya workstate save <branch>-complete
```

## Resources

- Course: https://pdos.csail.mit.edu/6.828/2021/
- xv6 book: https://pdos.csail.mit.edu/6.828/2021/xv6/book-riscv-rev2.pdf
- Debug: `make qemu-gdb` in one terminal, `gdb` in another
