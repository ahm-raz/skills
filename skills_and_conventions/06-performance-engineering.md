# 06 — Performance Engineering: How Experts Design for Speed

> Performance engineering is the discipline of making systems fast **enough**, for the **right** users, on the **right** paths, at an acceptable **cost**, and proving it with measurements instead of intuition.

This chapter explains how experienced engineers approach performance across the stack: measurement and profiling, databases and indexes, caching, network and serialization, memory and CPU, concurrency and pools, async processing, queues and batching, pagination, and frontend performance in React/Next.js. The core lesson: experts don't know what's slow ahead of time; they have a **loop** that finds out. They also know which few decisions *must* be made early because they're nearly impossible to fix later.

---

## Table of Contents

1. [Guessing ≠ Performance Engineering](#1-guessing--performance-engineering)
2. [Defining "Fast Enough": Latency Budgets and Percentiles](#2-defining-fast-enough-latency-budgets-and-percentiles)
3. [Measurement: USE, RED, and the Four Golden Signals](#3-measurement-use-red-and-the-four-golden-signals)
4. [Profiling: Finding Where Time Actually Goes](#4-profiling-finding-where-time-actually-goes)
5. [How Experts Know What to Optimize](#5-how-experts-know-what-to-optimize)
6. [Premature Optimization — and What You Must Decide Early](#6-premature-optimization--and-what-you-must-decide-early)
7. [Database Performance](#7-database-performance)
8. [Query Optimization and Reading EXPLAIN ANALYZE](#8-query-optimization-and-reading-explain-analyze)
9. [Indexing: Types, Strategy, and When Indexes Hurt](#9-indexing-types-strategy-and-when-indexes-hurt)
10. [The N+1 Problem](#10-the-n1-problem)
11. [Caching](#11-caching)
12. [Network Latency](#12-network-latency)
13. [Serialization](#13-serialization)
14. [Memory and Garbage Collection](#14-memory-and-garbage-collection)
15. [CPU and the Node.js Event Loop](#15-cpu-and-the-nodejs-event-loop)
16. [Concurrency](#16-concurrency)
17. [Connection Pools](#17-connection-pools)
18. [Async Processing and Queues](#18-async-processing-and-queues)
19. [Batching](#19-batching)
20. [Pagination: Offset vs Keyset](#20-pagination-offset-vs-keyset)
21. [Frontend Performance (React + Next.js)](#21-frontend-performance-react--nextjs)
22. [Backend Performance Checklist](#22-backend-performance-checklist)
23. [Infrastructure Performance](#23-infrastructure-performance)
24. [Load Testing With k6](#24-load-testing-with-k6)
25. [Performance Budgets in CI](#25-performance-budgets-in-ci)
26. [The Optimization Loop — A Fully Worked Example](#26-the-optimization-loop--a-fully-worked-example)
27. [Amateur vs Professional vs Expert](#27-amateur-vs-professional-vs-expert)
28. [Common Mistakes](#28-common-mistakes)
29. [Key Takeaways](#key-takeaways)
30. [Self-Assessment Checklist](#self-assessment-checklist)

Related chapters: [05-quality-engineering.md](05-quality-engineering.md) · [07-designing-for-failure.md](07-designing-for-failure.md) · [03-how-experts-design.md](03-how-experts-design.md) · [04-architectural-decision-making.md](04-architectural-decision-making.md) · [18-real-world-examples.md](18-real-world-examples.md) · [templates/design-doc.md](templates/design-doc.md)

---

## 1. Guessing ≠ Performance Engineering

### What

Performance engineering is a **scientific loop**: measure, find the bottleneck, form a hypothesis, change one thing, benchmark, compare, keep or revert. Guessing is changing code based on beliefs ("`forEach` is slow," "we need Redis," "let's rewrite in Go").

```text
Measure
↓
Identify bottleneck
↓
Hypothesis
↓
Change (one variable)
↓
Benchmark (same conditions)
↓
Compare (statistically meaningful)
↓
Keep / Revert
↑___________________________ repeat until target met, then STOP
```

### Why guessing fails

1. **Intuition about where time goes is unreliable.** In practice, performance problems in business software cluster in a few places: database queries (missing indexes, N+1, scanning), network round trips (chatty calls, serial awaits), serialization of oversized payloads, lock/pool contention, and on the frontend, JavaScript size, render-blocking resources, and unoptimized images. Micro-level code ("loops," "string concat") is rarely the cause.
2. **Amdahl's law:** speeding up a part that accounts for 5% of latency by 10× improves the total by about 4.5%.

```text
Total speedup = 1 / ((1 − p) + p / s)
p = fraction of time in the optimized part, s = speedup of that part

p = 0.05, s = 10 → 1 / (0.95 + 0.005) = 1.047  → 4.7% faster
p = 0.70, s = 10 → 1 / (0.30 + 0.07)  = 2.70   → 170% faster
```

3. **Optimizations have costs:** complexity, caching bugs, staleness, memory, and maintainability. A guess that doesn't help still carries its full cost.
4. **Bottlenecks move.** Fixing the DB query may reveal that JSON serialization is now dominant. Without measurement you don't notice the shift.

### Example

A SaaS dashboard takes 3.2 s to load. The team's guess: "React is re-rendering too much. Let's add `useMemo` everywhere." A trace shows the actual breakdown:

```text
Server: GET /api/dashboard                     2,700 ms
  ├─ auth middleware                               12 ms
  ├─ SELECT projects (1 query)                     18 ms
  ├─ SELECT tasks WHERE project_id = $1  ×140   2,380 ms   ← N+1
  ├─ compute aggregates in JS                     160 ms
  └─ JSON.stringify (4.1 MB payload)              130 ms
Network transfer (4.1 MB, uncompressed)          380 ms
Client render                                     120 ms
```

Memoizing React would have saved at most ~120 ms. The N+1 fix plus a smaller payload saved ~2,600 ms.

### Expert Mental Model

> I don't know where the time goes until I measure it. My first job is to make latency *visible* and *decomposed*. The fix is usually obvious once the trace is in front of me.

### Common Mistake

Micro-benchmarking a function in isolation (`for` vs `map`) and concluding the system will get faster. Benchmarks must reflect the **real workload, real data sizes, and real call paths**.

---
