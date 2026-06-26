# miOS Learning Curriculum

Cross-session knowledge artifact. Update as books are completed and artifacts produced.

Last updated: 2026-06-25

---

## Active Curriculum

### 01 — Modern Operating Systems
**Author**: Tanenbaum  
**Mode**: Deep read — in progress  
**Estimate**: 4–6 weeks remaining  

**Artifacts**:
- Annotated OS goals map — each Tanenbaum concept cross-referenced to miOS G1–G12 invariants
- Gap register — where Tanenbaum's treatment is shallow or absent relative to miOS design

---

### 02 — Principles of Computer System Design
**Author**: Saltzer & Kaashoek  
**Mode**: Deep read, close annotation  
**Estimate**: 4–5 weeks  

**Artifacts**:
- Design principles map — end-to-end argument, naming, layering, modularity traced to specific miOS design decisions
- miOS design rationale doc — each major architectural choice grounded in a Saltzer/Kaashoek principle or deliberate deviation

---

### 03 — Computer Architecture: A Quantitative Approach
**Author**: Hennessy & Patterson  
**Mode**: Selective — Ch 4, 5, Appendix B  
**Estimate**: 3–4 weeks  

**Artifacts**:
- Hardware constraint register — what the silicon actually guarantees vs assumes, mapped to G12 (temporal determinism) and SMP design
- Memory ordering cheatsheet — TSO, SC, acquire-release, and where C++26 atomics sit on the hardware model

---

### 04 — A Primer on Memory Consistency and Cache Coherence
**Author**: Sorin, Hill & Wood  
**Mode**: Cover to cover — short book  
**Estimate**: 2–3 weeks  

**Artifacts**:
- Consistency model taxonomy — SC, TSO, relaxed models with formal definitions and what each costs in hardware
- miOS memory contract — what consistency guarantees the OS can and cannot make at each layer boundary

---

### 05 — Distributed Algorithms
**Author**: Nancy Lynch  
**Mode**: Deep read — dense, non-linear  
**Estimate**: 6–8 weeks  

**Note**: "Distributed" here means algorithms spread across multiple independently-running processes with only local knowledge — correctness is a property of the composition, not any individual process. Concurrency and message passing are the medium, not the subject. The subject is computability under uncertainty. Directly models the miOS kernel/process/hardware boundary.

**Artifacts**:
- I/O automata model of miOS kernel/process boundary — kernel and user process as composable automata with formal interface contracts
- Impossibility register — FLP and related results translated to single-node implications for G8 (Liveness) and G12
- Synchrony assumption audit — what assumptions miOS implicitly makes and what breaks if they are violated

---

### 06 — The Art of Multiprocessor Programming
**Author**: Herlihy & Shavit  
**Mode**: Deep read — theoretical core  
**Estimate**: 5–6 weeks  

**Note**: Despite the title, this is rigorous concurrency theory — progress conditions, consensus numbers, computability hierarchy of synchronisation primitives. Not a craft book.

**Artifacts**:
- Progress condition map — wait-free, lock-free, obstruction-free applied to each miOS synchronisation point
- Consensus number analysis — which miOS primitives require which synchronisation strength, and whether any are over-specified
- Linearisability proofs (sketches) for SPSC and any miOS shared data structures

---

### 07 — C++ Concurrency in Action
**Author**: Anthony Williams  
**Mode**: Reference + selective deep read  
**Estimate**: 3–4 weeks  

**Artifacts**:
- C++ memory model to hardware model bridge — happens-before, synchronises-with, and where C++26 model sits relative to Sorin's taxonomy
- miOS C++ concurrency patterns — approved patterns for each class of synchronisation problem with rationale

---

### 08 — Types and Programming Languages (TAPL)
**Author**: Pierce  
**Mode**: Deferred — begin when ABI design intensifies  
**Estimate**: 6–8 weeks  

**Artifacts**:
- Type identity analysis — formal treatment of the three ABI identity candidates (name-based, UUID, structural fingerprinting) grounded in type theory
- G11 formal contract sketch — what a fully typed interface contract means in type-theoretic terms

---

## Total Active Curriculum Estimate

~33–44 weeks. Pace calibrated against Tanenbaum progress.

---

## Deferred

| Book | Author | Reason |
|---|---|---|
| Designing Data-Intensive Applications | Kleppmann | Peripheral to current miOS scope |
| Dijkstra EWD manuscripts | Dijkstra | Low overhead — dip in anytime alongside main curriculum |

---

## Notes on Formal Modeling

Formal toolchains (Coq, TLA+) are explicitly out of scope for now. A different perspective on formal modeling and its relationship to implementation will be discussed and captured separately when the time is right. Do not assume any specific formal verification toolchain in miOS design discussions.

---

## Key Principles for This Curriculum

- Judge books by content, not title. "Distributed Algorithms" is about computability under uncertainty. "Art of Multiprocessor Programming" is rigorous theory. Titles mislead; authors and publishers signal better.
- Every book must produce its artifacts. If the artifact isn't produced, the reading hasn't landed.
- Hardware reality before software abstraction. Always know what the silicon actually guarantees before reasoning about what the OS can promise.
