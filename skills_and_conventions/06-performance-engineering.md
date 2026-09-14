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

## 2. Defining "Fast Enough": Latency Budgets and Percentiles

### What

Before optimizing, experts define the **target**: a latency objective per user-facing operation, expressed as percentiles, and decomposed into a **budget** across the components on the path.

### Why percentiles, not averages

Latency distributions are long-tailed. Averages hide the tail, and the tail is what users feel.

```text
10,000 requests to GET /v1/orders
  mean   = 140 ms      ← "looks fine"
  p50    =  60 ms      ← typical request
  p95    = 380 ms
  p99    = 2,100 ms    ← 100 requests per 10k take > 2 s
  p99.9  = 6,800 ms    ← 10 users waited ~7 s
  max    = 30,000 ms   ← timeout
```

**Tail amplification (fan-out):** if a page makes N independent backend calls, the chance that at least one hits that call's p99 is `1 − 0.99^N`.

| Calls per page | P(at least one call ≥ its p99) |
|---|---|
| 1 | 1% |
| 10 | 9.6% |
| 50 | 39.5% |
| 100 | 63.4% |

That's why large systems care about p99 and p99.9 of internal services: a service's tail becomes the median experience of whatever aggregates it ("The Tail at Scale," Dean & Barroso).

**Percentiles can't be averaged.** The average of per-server p99s isn't the fleet p99. Aggregate histograms (Prometheus histograms, HDR histograms), then compute percentiles.

```promql
# Correct fleet-wide p99 from histogram buckets
histogram_quantile(0.99, sum by (le, route) (rate(http_server_duration_seconds_bucket{service="orders"}[5m])))
```

### Human perception thresholds (useful anchors)

| Latency | Perception |
|---|---|
| < 100 ms | Feels instant (direct manipulation, typing, hover) |
| 100–300 ms | Slight delay, still feels responsive |
| 300 ms–1 s | Noticeable; flow maintained |
| 1–10 s | Attention wanders; needs progress feedback |
| > 10 s | Task switching; needs background processing + notification |

Industry studies have repeatedly linked added latency to lower conversion in e-commerce. The exact numbers vary by study and era, but the direction is consistent.

### How: build a latency budget

Example: e-commerce "Place Order" must complete within **p95 ≤ 800 ms** measured at the edge.

```text
Budget for POST /checkout/place-order  (p95 target 800 ms)
────────────────────────────────────────────────────────────
Edge / TLS / load balancer                        30 ms
Auth + session lookup (Redis)                     10 ms
Validate cart + pricing (in-process)              20 ms
Inventory allocation transaction (PostgreSQL)     60 ms
Fraud check (external, timeout 250 ms)           200 ms
Payment authorization (PSP, timeout 3 s*)        350 ms
Write order + outbox event (same transaction)     30 ms
Response serialization                             5 ms
Headroom                                          95 ms
────────────────────────────────────────────────────────────
Total                                            800 ms

* PSP p95 is ~350 ms but its p99.9 is ~2.5 s. Decision: if auth takes > 1.5 s, return
  "payment processing" and complete asynchronously via webhook → keeps our p99 bounded.
Email, analytics, loyalty points, warehouse notification: NOT in the request path (async via outbox).
```

The budget does three things:
1. **Allocates** time to each component, so each owner knows their target.
2. **Exposes impossible designs early:** adding a synchronous call to a 400 ms recommendation service breaks the budget on paper.
3. **Sets timeouts** consistent with the budget ([07-designing-for-failure.md](07-designing-for-failure.md)).

### Typical targets by operation type (starting points, not laws)

| Operation | p95 target |
|---|---|
| Autocomplete / typeahead API | < 100 ms |
| Simple read API (by ID) | < 100–200 ms |
| List/search API | < 300–500 ms |
| Write with transaction | < 500 ms |
| Checkout / payment (with external PSP) | < 1–2 s |
| Report generation | Async if > 2–5 s |
| Page LCP (p75 real users) | ≤ 2.5 s |
| Interaction (INP, p75) | ≤ 200 ms |

### Expert Mental Model

> A performance goal without a percentile, a measurement point, and a load level is meaningless. "p95 < 300 ms at the load balancer at 500 RPS with production-sized data" is a goal. "Fast" isn't.

### Common Mistake

Setting targets only at the top level ("the page should be fast") without decomposing them, so every component team believes it's fine while the total is 3 s.

---

## 3. Measurement: USE, RED, and the Four Golden Signals

### What

Three complementary frameworks tell you *what* to measure so you're not staring at 400 random graphs.

**RED method** (Tom Wilkie), for **request-driven services**:

| Signal | Metric |
|---|---|
| **R**ate | Requests per second, per route |
| **E**rrors | Failed requests per second (or ratio) |
| **D**uration | Latency histogram (p50/p95/p99), per route |

**USE method** (Brendan Gregg), for **resources** (CPU, memory, disk, network, pools, queues, locks):

| Signal | Meaning | Examples |
|---|---|---|
| **U**tilization | % time the resource was busy | CPU 85%, pool 18/20 in use |
| **S**aturation | Extra work waiting | Run queue length, pool wait queue, queue depth, event loop lag |
| **E**rrors | Error events | Pool acquire timeouts, OOM kills, disk errors, dropped packets |

**Four Golden Signals** (Google SRE): latency, traffic, errors, **saturation**. RED plus saturation, essentially.

### Why

- RED tells you **that** users are experiencing slowness and **where** (which route).
- USE tells you **why** (which resource is the bottleneck).
- **Saturation is the leading indicator.** Utilization at 100% with no waiting is fine; any sustained waiting means latency is about to climb nonlinearly.

### Queueing intuition: why latency explodes near capacity

For a simple queue (M/M/1), average time in system is `service_time / (1 − utilization)`:

| Utilization | Latency multiplier |
|---|---|
| 50% | 2× |
| 70% | 3.3× |
| 80% | 5× |
| 90% | 10× |
| 95% | 20× |
| 99% | 100× |

That's why a service that's "only at 85% CPU" can have terrible p99, and why experts plan capacity to run critical resources at around **60–70%** at peak.

### How: instrument once, in shared middleware

```ts
// @/lib/http-metrics.ts — RED metrics for every route (Express/Fastify-style middleware)
import { metrics } from '@opentelemetry/api';

const meter = metrics.getMeter('http');
const duration = meter.createHistogram('http.server.request.duration', {
  unit: 's',
  advice: { explicitBucketBoundaries: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10] },
});

export function redMetrics() {
  return (req, res, next) => {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      const seconds = Number(process.hrtime.bigint() - start) / 1e9;
      duration.record(seconds, {
        'http.route': req.route?.path ?? 'unmatched',   // route template, NEVER raw URL (cardinality)
        'http.request.method': req.method,
        'http.response.status_code': res.statusCode,
      });
    });
    next();
  };
}
```

USE metrics for the resources that typically bottleneck Node + PostgreSQL services:

```text
Resource              Utilization                    Saturation                          Errors
────────────────────────────────────────────────────────────────────────────────────────────────────────
CPU (per pod)         container_cpu_usage / limit    CPU throttling (cfs_throttled)      —
Node event loop       event loop utilization (ELU)   event loop lag p99                  —
Memory                heap used / limit              GC pause time, major GC frequency   OOMKilled
DB pool (app side)    active / max                   waiting clients, acquire time p99   acquire timeouts
PostgreSQL            active connections / max       wait_event counts (Lock, IO)        deadlocks, conn refused
Disk (DB)             IOPS / provisioned             IO queue depth, await               —
Queue                 consumer busy %                queue depth, oldest message age     DLQ rate
External API          calls / rate limit             429s, client-side concurrency wait  timeouts, 5xx
```

```ts
// Event loop metrics in Node
import { monitorEventLoopDelay, performance } from 'node:perf_hooks';

const h = monitorEventLoopDelay({ resolution: 10 });
h.enable();
let lastElu = performance.eventLoopUtilization();

setInterval(() => {
  const elu = performance.eventLoopUtilization(lastElu);
  lastElu = performance.eventLoopUtilization();
  gauge('nodejs.eventloop.lag.p99_ms', h.percentile(99) / 1e6);
  gauge('nodejs.eventloop.utilization', elu.utilization); // 0..1
  h.reset();
}, 10_000).unref();
```

### Distributed tracing: decomposing a single request

Metrics tell you p99 went up; traces tell you **which span** in **which requests** got slow. Auto-instrument HTTP, PostgreSQL, Redis, and fetch with OpenTelemetry, and add manual spans around significant business steps.

```ts
import { trace } from '@opentelemetry/api';
const tracer = trace.getTracer('checkout');

export async function placeOrder(cmd: PlaceOrder) {
  return tracer.startActiveSpan('checkout.placeOrder', async (span) => {
    span.setAttributes({ 'cart.lines': cmd.lines.length, 'tenant.id': cmd.tenantId });
    try {
      const priced = await tracer.startActiveSpan('checkout.price', (s) => price(cmd).finally(() => s.end()));
      const allocation = await allocate(priced);        // auto-instrumented pg spans nest here
      const auth = await psp.authorize(priced.total);    // auto-instrumented http span
      return await persistOrder(priced, allocation, auth);
    } finally {
      span.end();
    }
  });
}
```

Use **tail-based sampling** in the collector: keep 100% of error traces and slow traces (> p99 threshold), plus a small percentage of normal ones. That keeps cost down without losing the interesting traces.

### Expert Mental Model

> RED at every service boundary, USE for every constrained resource, traces to connect them. Saturation is the metric I care about most, because it moves before latency does.

### Common Mistake

High-cardinality labels (user ID, raw URL with IDs, order ID) on metrics. It blows up the metrics backend's memory and cost. Put high-cardinality data on **traces and logs**, not metric labels.

---

## 4. Profiling: Finding Where Time Actually Goes

### What

Profiling measures where CPU time, wall time, memory allocations, or lock waits are spent **inside** a process. Tracing shows time *between* components; profiling shows time *within* one.

| Profiler type | Answers | Node.js tools |
|---|---|---|
| CPU (sampling) | Which functions consume CPU? | `node --cpu-prof`, Chrome DevTools, `0x`, Clinic.js Flame, Pyroscope/Grafana continuous profiling |
| Wall-clock / off-CPU | Where are we *waiting* (I/O, locks)? | Traces, `clinic bubbleprof`, async hooks |
| Heap / allocation | What allocates memory, what leaks? | `--heapsnapshot-signal`, DevTools heap snapshots, allocation timeline, `--heap-prof` |
| Event loop | What blocks the loop? | `clinic doctor`, `blocked-at`, ELU metrics |
| Database | Which queries consume DB time? | `pg_stat_statements`, `auto_explain`, `EXPLAIN (ANALYZE, BUFFERS)` |
| Browser | Main-thread work, layout, paint | Chrome DevTools Performance panel, React DevTools Profiler, Lighthouse |

### How to read a flame graph

```text
            ┌──────────────────────────────────────────────────────────────────────┐
            │                           main / request handler                     │  ← bottom = entry point
            ├──────────────────────────────────┬───────────────────────────────────┤
            │        buildInvoiceReport        │        serializeResponse          │
            ├───────────────┬──────────────────┤                                   │
            │ computeTax    │  formatLines     │ JSON.stringify ███████████████    │
            │ ██            ├──────────────────┤                                   │
            │               │ Intl.NumberFormat│                                   │
            │               │ constructor █████│                                   │
            └───────────────┴──────────────────┴───────────────────────────────────┘
```

- **X axis = proportion of samples**, NOT time order. Width = share of CPU time.
- **Y axis = call stack depth.** Parents below, children above.
- Look for **wide plateaus at the top** (functions that consume CPU themselves, "self time").
- In the sketch above, `Intl.NumberFormat constructor` is wide: a formatter is being constructed per line item instead of once. Classic fix: hoist and reuse it. `JSON.stringify` is wide: the payload is too big. Fix: send less data.

### How to profile a Node service in production-like conditions

```bash
# 1. Reproduce load (k6 or autocannon) against a staging instance with production-sized data
npx autocannon -c 50 -d 60 http://staging-api:3000/v1/reports/invoices?month=2026-08

# 2. CPU profile during the load
node --cpu-prof --cpu-prof-dir=./profiles dist/server.js
# stop after the load run; open the .cpuprofile in Chrome DevTools → Performance, or speedscope.app

# 3. Or with clinic for a quick diagnosis of I/O vs CPU vs event loop issues
npx clinic doctor --autocannon [ -c 50 -d 30 /v1/reports/invoices?month=2026-08 ] -- node dist/server.js
npx clinic flame  --autocannon [ -c 50 -d 30 /v1/reports/invoices?month=2026-08 ] -- node dist/server.js
```

**Continuous profiling** (Pyroscope, Datadog, Grafana) samples production at around 1% overhead, so you can compare flame graphs before and after a deploy. That's the most reliable way to catch CPU regressions.

### Database profiling with pg_stat_statements

The first place to look in almost every backend performance investigation:

```sql
-- Top queries by total time (where the database actually spends its life)
SELECT
  round(total_exec_time::numeric / 1000, 1)            AS total_s,
  calls,
  round(mean_exec_time::numeric, 2)                    AS mean_ms,
  round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 1) AS pct,
  rows / NULLIF(calls, 0)                              AS rows_per_call,
  round(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS cache_hit_pct,
  left(query, 120)                                     AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 15;
```

How to interpret it:

| Pattern | Meaning | Typical fix |
|---|---|---|
| High `calls`, low `mean_ms`, high `total` | Chatty access, likely N+1 | Batch / join / DataLoader |
| Low `calls`, very high `mean_ms` | Expensive query | EXPLAIN ANALYZE → index / rewrite |
| High `rows_per_call` | Fetching too much | Pagination, projection, aggregate in SQL |
| Low `cache_hit_pct` | Reading from disk | Index to reduce pages read, more memory, or data model change |

Enable `auto_explain` to capture plans for slow queries automatically:

```sql
-- postgresql.conf (or ALTER SYSTEM)
shared_preload_libraries = 'pg_stat_statements,auto_explain'
auto_explain.log_min_duration = '250ms'
auto_explain.log_analyze = on
auto_explain.log_buffers = on
auto_explain.sample_rate = 0.1       -- sample to limit overhead
```

### Expert Mental Model

> Traces tell me which component; profiles tell me which function; `pg_stat_statements` tells me which query. I pick the tool that matches the question and profile under realistic load and data, because a profile of an idle dev server with 50 rows proves nothing.

### Common Mistake

Profiling in development with tiny datasets, where every query is an in-memory seq scan taking 0.1 ms. Performance problems in business systems are **data-size-dependent**. Use a staging dataset that matches production row counts and distributions (anonymized if needed).

---

## 5. How Experts Know What to Optimize

This is the most important question in the chapter. Experts combine **four inputs**:

### Input 1: user/business impact

```text
Priority = (users affected) × (frequency) × (business value of the path) × (gap from target)
```

| Candidate | Users/day | Gap vs target | Value | Priority |
|---|---|---|---|---|
| Checkout p95 1.9 s (target 0.8 s) | 40k | 1.1 s | Revenue path | **Very high** |
| Admin CSV export 45 s | 20 | Async would fix | Internal | Low |
| Product page LCP 3.4 s (p75, mobile) | 900k | 0.9 s | SEO + conversion | **Very high** |
| Settings page 700 ms | 300 | Within target | Low | None |

### Input 2: where the time actually goes (measurement)

Traces + profiles + `pg_stat_statements` → find the dominant contributor (Amdahl).

### Input 3: saturation and scaling curves

Which resource saturates first as load or data grows? A query that's fine at 1M rows but seq-scans at 10M is a **future** priority with a known deadline based on growth rate.

```text
orders table: 18M rows, growing 1.2M/month
Query plan switches to seq scan at ~25M rows (tested with synthetic data at 30M)
→ deadline ≈ 6 months → schedule the index/partition work now, not during the incident
```

### Input 4: cost

Sometimes the right optimization target is **cost**, not latency: a job that runs fast enough but uses 40 vCPUs, or a query that does 10 GB of I/O per call on a provisioned-IOPS database.

### The decision

```text
Is there a measured gap between current and target performance on a path that matters?
├── No  → Don't optimize. Add a budget/alert so you'll know if it regresses. STOP.
└── Yes → Where does the time go? (trace / profile / pg_stat_statements)
          ├── One dominant contributor (> 50%) → optimize it, re-measure
          ├── Many small contributors         → architectural issue (chatty design, too many hops,
          │                                      oversized payloads) → redesign the path
          └── Waiting (queue/pool/lock)       → saturation problem → capacity, contention, or
                                                 concurrency design, NOT code micro-optimization
```

### Expert Mental Model

> I optimize the **measured, dominant** contributor on a path that **matters** to users or cost, until it meets a **defined target**, and then I stop. Everything else gets a regression guard, not an optimization.

### Common Mistake

Optimizing what's *interesting* (a clever algorithm) instead of what's *dominant* (a missing index). And not stopping once the target is met, which buys complexity with no user benefit.

---

## 6. Premature Optimization — and What You Must Decide Early

### What

Knuth's full quote: *"We should forget about small efficiencies, say about 97% of the time: premature optimization is the root of all evil. **Yet we should not pass up our opportunities in that critical 3%.**"*

People usually quote only the first half. Experts apply both halves.

### Why premature optimization hurts

- Adds complexity (caches, denormalization, custom data structures) before knowing it's needed.
- Optimizes the wrong thing (you can't know the bottleneck before real usage).
- Makes the code harder to change exactly when requirements are least stable.
- Caching introduced early creates correctness bugs (staleness, invalidation) for zero benefit.

### Why "we'll optimize later" also fails

Some performance characteristics are set by **structural decisions** that are extremely expensive to change once data and consumers exist. Getting them wrong isn't a tuning problem; it means a migration or a rewrite.

### The critical 3%: decide these early

| Decision | Why it's expensive later | Early default |
|---|---|---|
| **Data model and access patterns** | Schema reshapes require data migrations across millions of rows and every consumer | Model around the main queries; know your top 10 read/write patterns; normalize first, denormalize with purpose |
| **Pagination on every list endpoint** | Adding pagination to an API later is a breaking change for all consumers | Every collection endpoint paginated from v1, with a max page size; keyset (cursor) for large or unbounded collections |
| **N+1-free API shapes** | Clients built on chatty APIs force hundreds of calls per screen | Design endpoints/RSC data loaders around screens or use cases; batch-load relations |
| **Payload size discipline** | Consumers depend on every field you ever returned | Return what the use case needs; sparse fieldsets or explicit DTOs; never serialize ORM entities wholesale |
| **Sync vs async boundaries** | Converting a synchronous API to async changes the contract | Anything slow, unreliable, or non-essential to the response goes async from the start (email, webhooks, reports, exports) |
| **Tenant/partition key in IDs and indexes** | Retrofitting tenant scoping to every query/index is enormous | `tenant_id` first column in composite indexes for multi-tenant tables |
| **Identifier strategy** | Changing ID types touches every table and API | Time-ordered IDs (UUIDv7/ULID) or bigint; avoid random UUIDv4 as clustered PK on huge write-heavy tables (index locality) |
| **Unbounded growth tables** | Partitioning a 2 TB table live is painful | Identify event/log/audit tables with retention; plan partitioning (by time) from the design |
| **Hot-path round trips** | Architectures with 6 synchronous hops per request can't be tuned into speed | Minimize synchronous service-to-service calls on user paths |
| **Frontend rendering strategy** | Switching a whole app between client-side rendering and server rendering is a rewrite | Next.js App Router: Server Components by default, client components only where interactive |

### Example: pagination as a day-one decision

```ts
// v1 API — "we'll add pagination later"
GET /v1/customers/:id/orders   → returns ALL orders (fine at launch, ~12 orders per customer)

// 18 months later: B2B customers with 250k orders; response = 180 MB; mobile app crashes.
// Adding ?limit breaks every existing integration that expects the full list.
```

```ts
// Day-one design: paginated, capped, cursor-based
GET /v1/customers/:id/orders?limit=50&cursor=eyJjIjoiMjAyNi0wOS0wMVQxMDowMDowMFoiLCJpZCI6Im9yZF85In0
{
  "data": [ ... up to 50 ... ],
  "page": { "nextCursor": "eyJ...", "hasMore": true }
}
```

It costs almost nothing extra on day one and saves a breaking migration later.

### Expert Mental Model

> I refuse to optimize **code** before measuring, and I refuse to postpone **structural** performance decisions: data model, access patterns, pagination, payload shape, sync/async boundaries. Code is cheap to change later; shapes that consumers and data depend on aren't.

### Common Mistake

Using "premature optimization" as a reason to skip thinking about data access. Unbounded queries, no pagination, and ORM lazy loading everywhere aren't avoiding premature optimization; they're postponing structural decisions.

---

## 7. Database Performance

### What

In most business systems the database is the **shared, stateful bottleneck**. App servers scale horizontally with little effort; the primary database doesn't. Database performance is mostly about **doing less work per query** and **issuing fewer queries**, not about exotic tuning.

### The hierarchy of database performance fixes (most to least leverage)

```text
1. Don't query at all         → it's already in the request context, cache, or can be computed
2. Query less often           → fix N+1, batch, cache results
3. Touch less data            → right index, selective predicates, projection (no SELECT *), pagination
4. Do the work in the DB      → aggregate/filter/join in SQL instead of shipping rows to the app
5. Reduce contention          → shorter transactions, correct lock granularity, avoid hot rows
6. Change the data model      → denormalize read models, materialized views, partitioning
7. Tune the server            → memory (shared_buffers, work_mem), autovacuum, I/O
8. Scale the hardware/topology → bigger instance, read replicas, then (rarely) sharding
```

Amateurs start at step 8 ("we need a bigger database" or "we need to shard"). Experts start at step 1.

### Key PostgreSQL facts that drive performance

| Fact | Consequence |
|---|---|
| Each connection is a backend **process** (~5–10 MB+ memory, context-switch cost) | Hundreds of direct connections hurt throughput; use pooling (Section 17) |
| MVCC: updates create new row versions; dead tuples need VACUUM | Update-heavy tables bloat; tune autovacuum per table; avoid "update a counter row on every request" |
| Planner uses statistics (`ANALYZE`) | Stale or insufficient stats → bad plans; raise `default_statistics_target` for skewed columns, use extended statistics for correlated columns |
| Buffer cache + OS page cache | Working set in memory is fast; exceeding it means disk reads, which can be 100×+ slower |
| Long-running transactions block vacuum and hold locks | A 2-hour analytics query on the primary can cause bloat and replication lag; send analytics to a replica or warehouse |
| `work_mem` is per sort/hash operation, per query node | Sorts spilling to disk ("external merge") are slow; set it per role/query rather than globally huge |

### Transaction design for performance

```ts
// ❌ Long transaction holding row locks across a network call
await db.transaction(async (tx) => {
  const stock = await tx.query('SELECT * FROM stock WHERE sku=$1 FOR UPDATE', [sku]);
  const auth = await psp.authorize(amount);   // 300 ms – 3 s while holding the lock!
  await tx.query('UPDATE stock SET allocated = allocated + $1 WHERE sku=$2', [qty, sku]);
  await tx.query('INSERT INTO orders ...');
});
// Under load: lock waits pile up, pool exhausts, p99 explodes.

// ✅ Keep transactions short; no network I/O inside them
const reservation = await db.transaction(async (tx) => {
  // single statement with guard; row lock held for milliseconds
  const { rowCount } = await tx.query(
    `UPDATE stock SET allocated = allocated + $1
     WHERE sku = $2 AND warehouse_id = $3 AND on_hand - allocated >= $1`,
    [qty, sku, warehouseId],
  );
  if (rowCount === 0) throw new InsufficientStock(sku);
  return tx.query(`INSERT INTO reservations (...) VALUES (...) RETURNING id, expires_at`, [...]);
});
const auth = await psp.authorize(amount, { idempotencyKey: reservation.id });
await db.query(`UPDATE reservations SET status='CONFIRMED', payment_ref=$1 WHERE id=$2`, [auth.id, reservation.id]);
// Reservation expiry job releases stock if payment never confirms.
```

### Read replicas: benefits and traps

- ✅ Offload heavy reads (reports, search, dashboards) from the primary.
- ⚠️ **Replication lag**: reading your own write from a replica may return stale data. Route reads-after-write to the primary for that user/session for N seconds, or use LSN-based consistency.
- ⚠️ Long queries on replicas can conflict with vacuum replay (`hot_standby_feedback` trade-offs).

### Expert Mental Model

> The database is where performance, correctness, and scalability meet. I minimize the number of queries, the rows each touches, and the time each holds locks, and I never let network I/O happen inside a transaction.

### Common Mistake

Adding Redis caching in front of a slow query instead of fixing the query. Now you have a slow query **and** a cache invalidation problem.

---

## 8. Query Optimization and Reading EXPLAIN ANALYZE

### What

`EXPLAIN` shows the planner's intended plan and estimates. `EXPLAIN (ANALYZE, BUFFERS)` **executes** the query and shows actual timings, row counts, and pages read. It's the single most useful performance tool for SQL.

> ⚠️ `ANALYZE` executes the statement. For `INSERT/UPDATE/DELETE`, wrap it in `BEGIN; ... ROLLBACK;`.

### Example: slow order search in a multi-tenant SaaS

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, number, status, total_cents, created_at
FROM orders
WHERE tenant_id = 'ten_42' AND status = 'PENDING'
ORDER BY created_at DESC
LIMIT 50;
```

**Before** (only a single-column index on `tenant_id` exists):

```text
Limit  (cost=48211.55..48211.68 rows=50 width=64) (actual time=812.402..812.419 rows=50 loops=1)
  Buffers: shared hit=2112 read=38490
  ->  Sort  (cost=48211.55..48398.20 rows=74660 width=64) (actual time=812.399..812.409 rows=50 loops=1)
        Sort Key: created_at DESC
        Sort Method: top-N heapsort  Memory: 32kB
        Buffers: shared hit=2112 read=38490
        ->  Bitmap Heap Scan on orders  (cost=1402.33..45731.77 rows=74660 width=64) (actual time=41.118..790.552 rows=81233 loops=1)
              Recheck Cond: (tenant_id = 'ten_42'::text)
              Filter: (status = 'PENDING'::text)
              Rows Removed by Filter: 1106412
              Heap Blocks: exact=39870
              Buffers: shared hit=2112 read=38490
              ->  Bitmap Index Scan on idx_orders_tenant  (cost=0.00..1383.67 rows=1180000 width=0) (actual time=33.201..33.202 rows=1187645 loops=1)
                    Index Cond: (tenant_id = 'ten_42'::text)
                    Buffers: shared hit=3250
Planning Time: 0.211 ms
Execution Time: 812.488 ms
```

### How to read it (bottom-up, inside-out)

| Line / field | What it says | Diagnosis |
|---|---|---|
| `Bitmap Index Scan ... rows=1187645` | Index found 1.19M rows for this tenant (big tenant) | Index isn't selective enough by itself |
| `Filter: (status = 'PENDING') Rows Removed by Filter: 1106412` | Fetched 1.19M heap rows, threw away 93% | **Filtering after fetching is the core waste** |
| `Heap Blocks: exact=39870`, `Buffers: read=38490` | ~38k pages (~300 MB) read **from disk** | I/O-bound, cold cache |
| `Sort ... top-N heapsort` on 81k rows | Sorted everything to return 50 | Index should provide the order |
| `actual time=...790` on the heap scan | Most of the 812 ms is here | Target this node |
| `cost=` vs `actual time=` | Planner units vs real ms; not comparable to each other | Compare **estimated rows vs actual rows** instead |
| `rows=74660` (est.) vs `rows=81233` (actual) | Estimate reasonably close | Stats are OK; problem is indexing, not statistics |

**Red flags to scan for in any plan:**

```text
Seq Scan on a large table with a selective WHERE      → missing/unused index
Rows Removed by Filter: (large)                        → index doesn't cover the predicate
estimated rows off by 10×–1000× from actual            → stale/insufficient statistics, correlated columns
Sort Method: external merge  Disk: ...                 → work_mem too small, or missing index for ORDER BY
Nested Loop with a large loops= count on inner side    → join order/estimate problem, N+1 inside SQL
Buffers: read= (large)                                 → disk I/O; reduce pages touched
Hash Join with Batches > 1                             → hash spilled to disk
Index Scan ... Heap Fetches: (large) on Index Only Scan → visibility map stale, needs VACUUM
```

### Fix: composite index matching filter + order

```sql
CREATE INDEX CONCURRENTLY idx_orders_tenant_status_created
  ON orders (tenant_id, status, created_at DESC)
  INCLUDE (number, total_cents);   -- enables index-only scan for this projection
```

Column order rule of thumb: **equality predicates first, then range/sort columns**.

**After:**

```text
Limit  (cost=0.56..14.88 rows=50 width=64) (actual time=0.041..0.162 rows=50 loops=1)
  Buffers: shared hit=54
  ->  Index Only Scan using idx_orders_tenant_status_created on orders  (cost=0.56..21387.10 rows=74660 width=64) (actual time=0.039..0.151 rows=50 loops=1)
        Index Cond: ((tenant_id = 'ten_42'::text) AND (status = 'PENDING'::text))
        Heap Fetches: 3
        Buffers: shared hit=54
Planning Time: 0.302 ms
Execution Time: 0.188 ms
```

```text
812 ms → 0.19 ms (≈ 4,300×), 40,602 pages → 54 pages, no sort, no filter waste.
```

### Common query rewrites

```sql
-- ❌ Function on indexed column defeats the index
WHERE lower(email) = 'a@b.com'
-- ✅ Expression index, or store normalized value (citext / generated column)
CREATE INDEX idx_users_email_lower ON users (lower(email));

-- ❌ Implicit cast (param as text vs bigint column) may prevent index use
WHERE customer_id = '123'
-- ✅ Match types in the driver/ORM

-- ❌ OR across different columns often → seq scan
WHERE sender_id = $1 OR recipient_id = $1
-- ✅ UNION ALL of two indexed queries (dedupe if needed)
SELECT ... FROM messages WHERE sender_id = $1
UNION ALL
SELECT ... FROM messages WHERE recipient_id = $1 AND sender_id <> $1;

-- ❌ NOT IN with a subquery (NULL semantics + poor plans)
WHERE id NOT IN (SELECT order_id FROM refunds)
-- ✅ NOT EXISTS
WHERE NOT EXISTS (SELECT 1 FROM refunds r WHERE r.order_id = o.id)

-- ❌ Counting everything for "total pages" on big tables
SELECT count(*) FROM events WHERE tenant_id = $1;      -- scans millions
-- ✅ Don't show exact totals; use hasMore, an estimate, or a maintained counter
SELECT reltuples::bigint FROM pg_class WHERE relname = 'events';   -- table-level estimate

-- ❌ Aggregating in the application
const rows = await db.query('SELECT amount_cents FROM ledger WHERE account_id=$1', [id]); // 2M rows
const balance = rows.reduce((s, r) => s + r.amount_cents, 0);
-- ✅ Aggregate in SQL (or maintain a balance snapshot + recent entries)
SELECT coalesce(sum(amount_cents), 0) FROM ledger WHERE account_id = $1;
```

### Statistics problems

```sql
-- Correlated columns (e.g., city and postal_code) → planner multiplies selectivities → underestimates
CREATE STATISTICS st_addresses_city_zip (dependencies, ndistinct) ON city, postal_code FROM addresses;
ANALYZE addresses;

-- Skewed distribution (one tenant owns 40% of rows)
ALTER TABLE orders ALTER COLUMN tenant_id SET STATISTICS 1000;
ANALYZE orders;
```

### Expert Mental Model

> I read plans bottom-up and look for the node where **actual time** and **buffers** concentrate, then ask: are we fetching rows we throw away, sorting rows we don't return, or estimating wrong? The fix is almost always an index that matches filter+order, a rewrite that lets an index be used, or better statistics.

### Common Mistake

Testing `EXPLAIN` on a dev database with 1,000 rows. The planner will choose seq scans (correctly, for that size), and you'll either miss the problem or "fix" something that isn't broken. Plans depend on data volume and distribution.

---

## 9. Indexing: Types, Strategy, and When Indexes Hurt

### What

An index is a secondary data structure that trades **write cost, storage, and memory** for **read speed** on specific access patterns.

### PostgreSQL index types

| Type | Good for | Example |
|---|---|---|
| **B-tree** (default) | Equality, range, sorting, prefix `LIKE 'abc%'` | `(tenant_id, created_at DESC)` |
| **Hash** | Equality only; rarely better than B-tree | Large equality-only keys |
| **GIN** | Multi-valued: JSONB containment, arrays, full-text, trigram | `USING gin (tags)`, `USING gin (to_tsvector('english', title))`, `gin_trgm_ops` for `ILIKE '%term%'` |
| **GiST** | Geometric, ranges, nearest-neighbor, exclusion constraints | `EXCLUDE USING gist (room_id WITH =, during WITH &&)` for no-double-booking |
| **SP-GiST** | Partitioned search spaces (IP ranges, quadtrees) | `inet` lookups |
| **BRIN** | Very large, naturally ordered append-only tables; tiny size | `USING brin (created_at)` on a 2 TB event log |
| **Partial** | Index a subset of rows | `WHERE status = 'PENDING'` (small hot set in a huge table) |
| **Expression** | Computed values | `(lower(email))`, `((payload->>'externalId'))` |
| **Covering (`INCLUDE`)** | Index-only scans without widening the key | `INCLUDE (total_cents)` |
| **Unique** | Enforce invariants + fast lookup | `UNIQUE (tenant_id, idempotency_key)` |
| **pgvector HNSW / IVFFlat** | Approximate nearest neighbor for embeddings | `USING hnsw (embedding vector_cosine_ops)` |

### Index design strategy

```text
1. Start from the top queries (pg_stat_statements), not from the schema.
2. For each query: equality columns → range column → sort column; INCLUDE projected columns if hot.
3. Prefer one composite index serving several queries (leftmost-prefix rule) over many single-column ones.
4. Use partial indexes for hot subsets (queues, pending states, soft-deleted exclusion).
5. Enforce uniqueness invariants with unique indexes (correctness + speed).
6. Every foreign key used in joins/deletes gets an index on the referencing column
   (otherwise DELETE on the parent scans the child table).
7. Create indexes CONCURRENTLY in production; check for INVALID indexes if it fails.
8. Review unused indexes quarterly and drop them.
```

```sql
-- Partial index for a job/outbox queue: tiny, always hot, always in memory
CREATE INDEX CONCURRENTLY idx_outbox_unpublished
  ON outbox (created_at)
  WHERE published_at IS NULL;

-- Exclude soft-deleted rows from the index most queries use
CREATE INDEX CONCURRENTLY idx_products_tenant_sku_active
  ON products (tenant_id, sku)
  WHERE deleted_at IS NULL;

-- Trigram index for "contains" search in an admin panel
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX CONCURRENTLY idx_customers_name_trgm ON customers USING gin (name gin_trgm_ops);
```

### When indexes hurt

| Cost | Detail |
|---|---|
| **Write amplification** | Every INSERT updates every index; UPDATEs that change indexed columns (or any column when HOT updates aren't possible) update indexes too. A table with 12 indexes can be several times slower to write than one with 3. |
| **Lost HOT updates** | PostgreSQL "heap-only tuple" updates avoid index writes only if no indexed column changes and there's free space in the page. Indexing a frequently updated column (`updated_at`, `last_seen_at`, counters) kills HOT → more bloat + write I/O. |
| **Memory pressure** | Indexes compete with table data for `shared_buffers`/page cache. Unused indexes push hot data out of memory. |
| **Planner confusion** | Many overlapping indexes → more planning time and occasional worse choices. |
| **Bloat and vacuum cost** | More indexes to vacuum; bloated indexes on high-churn tables. |
| **Low selectivity** | Index on `status` with 3 values where 90% are `ACTIVE` won't be used for `ACTIVE` (seq scan is cheaper). Use a partial index for the rare values. |
| **Lock/migration risk** | `CREATE INDEX` without `CONCURRENTLY` blocks writes on large tables for minutes. |

```sql
-- Find unused indexes (since stats reset) — candidates to drop
SELECT s.schemaname, s.relname AS table, s.indexrelname AS index,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size, s.idx_scan
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0 AND NOT i.indisunique AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- Check HOT update ratio on hot tables
SELECT relname, n_tup_upd, n_tup_hot_upd,
       round(100.0 * n_tup_hot_upd / NULLIF(n_tup_upd, 0), 1) AS hot_pct
FROM pg_stat_user_tables ORDER BY n_tup_upd DESC LIMIT 10;
```

(Check replicas too before dropping: an index unused on the primary may serve replica queries.)

### Example: the "last_seen_at" trap in a social app

```text
users table: 40M rows, 9 indexes, including idx_users_last_seen_at.
Every authenticated request: UPDATE users SET last_seen_at = now() WHERE id = $1.
Result: HOT updates ~0%, massive WAL volume, index bloat, replication lag, write latency p99 180 ms.

Fix:
1. Drop idx_users_last_seen_at (only used by a weekly "inactive users" job → run that on a replica/warehouse).
2. Throttle: update only if last_seen_at < now() - interval '5 minutes' (in the WHERE clause).
3. Move presence to Redis; persist to DB in batches every minute.
Result: WAL volume −70%, HOT updates ~95%, replication lag gone.
```

### Expert Mental Model

> Every index is a write-time tax paid to speed up specific reads. I index for measured query patterns, combine them into composite and partial indexes, and remove indexes that don't pay rent.

### Common Mistake

"Index every column that appears in a WHERE clause." That creates many single-column indexes that don't match real composite predicates, slow down writes, and bloat memory, while the actual hot query still sorts 80k rows.

---

## 10. The N+1 Problem

### What

Fetching a list with 1 query, then running 1 more query **per item** for related data: N+1 queries total. Each query is fast; the sum is slow, and it grows linearly with data.

### Why it's so common

ORMs and component-driven data fetching make it invisible: `order.customer.name` inside a loop looks like property access but is a network round trip. GraphQL resolvers and React components that each fetch their own data produce the same pattern.

### Example (TypeScript + Prisma-style ORM)

```ts
// ❌ N+1: 1 query for orders + 50 for customers + 50×lines for products
const orders = await db.order.findMany({ where: { tenantId }, take: 50 });
for (const o of orders) {
  o.customer = await db.customer.findUnique({ where: { id: o.customerId } });
  o.lines = await db.orderLine.findMany({ where: { orderId: o.id } });
  for (const l of o.lines) {
    l.product = await db.product.findUnique({ where: { id: l.productId } });
  }
}
// 50 orders × ~4 lines → 1 + 50 + 50 + 200 = 301 queries × ~1.5 ms RTT = ~450 ms+ (and pool pressure)
```

```ts
// ✅ Batched: constant number of queries regardless of N
const orders = await db.order.findMany({
  where: { tenantId },
  take: 50,
  orderBy: { createdAt: 'desc' },
  select: {
    id: true, number: true, totalCents: true, createdAt: true,
    customer: { select: { id: true, name: true } },
    lines: { select: { qty: true, product: { select: { sku: true, name: true } } } },
  },
});
// Prisma issues a handful of IN (...) queries → 3–4 queries total
```

```sql
-- ✅ Or a single SQL query shaped for the screen (JSON aggregation in PostgreSQL)
SELECT o.id, o.number, o.total_cents, o.created_at,
       json_build_object('id', c.id, 'name', c.name) AS customer,
       coalesce(json_agg(json_build_object('sku', p.sku, 'name', p.name, 'qty', l.qty))
                FILTER (WHERE l.id IS NOT NULL), '[]') AS lines
FROM orders o
JOIN customers c ON c.id = o.customer_id
LEFT JOIN order_lines l ON l.order_id = o.id
LEFT JOIN products p ON p.id = l.product_id
WHERE o.tenant_id = $1
GROUP BY o.id, c.id
ORDER BY o.created_at DESC
LIMIT 50;
```

### N+1 across service/API boundaries (the worse version)

```ts
// ❌ Frontend or BFF calling a microservice per item: 50 × 40 ms network RTT = 2 s
const enriched = await Promise.all(orders.map((o) => shippingApi.getTracking(o.id)));
// Even parallelized, 50 concurrent requests hit rate limits and the dependency's tail latency (Section 2).

// ✅ Batch endpoint
const tracking = await shippingApi.getTrackingBatch(orders.map((o) => o.id)); // POST /tracking:batchGet
```

### DataLoader for GraphQL / resolver-style code

```ts
import DataLoader from 'dataloader';

// Per-request loader: collects all .load(id) calls in one tick, issues one query
export const makeLoaders = (db: Db, tenantId: string) => ({
  customerById: new DataLoader<string, Customer | null>(async (ids) => {
    const rows = await db.query<Customer>(
      'SELECT id, name FROM customers WHERE tenant_id = $1 AND id = ANY($2)',
      [tenantId, ids],
    );
    const byId = new Map(rows.map((r) => [r.id, r]));
    return ids.map((id) => byId.get(id) ?? null);  // must preserve input order
  }),
});
```

### React Server Components / Next.js

```tsx
// ❌ Each <OrderRow> is an async server component fetching its own customer → N+1 on the server
async function OrderRow({ order }: { order: Order }) {
  const customer = await getCustomer(order.customerId);
  return <tr><td>{order.number}</td><td>{customer.name}</td></tr>;
}

// ✅ Fetch at the list level, shaped for the screen; or dedupe with a batched loader + React cache()
export default async function OrdersPage() {
  const orders = await getOrdersWithCustomers(); // one batched query
  return <OrdersTable orders={orders} />;
}
```

### Detection and enforcement

- **Metric:** queries per request (histogram). Alert or fail tests if a route exceeds a threshold.
- **Test-time guard:**

```ts
// test helper: assert query count for an endpoint
test('GET /v1/orders issues a bounded number of queries', async () => {
  await seed({ orders: 50, linesPerOrder: 4 });
  const counter = countQueries(db);             // wraps the pg client's query method
  await request(app).get('/v1/orders?limit=50').expect(200);
  expect(counter.count).toBeLessThanOrEqual(5); // constant, not proportional to N
});
```

- **Traces:** a waterfall of dozens of identical `SELECT` spans is the visual signature of N+1.
- **pg_stat_statements:** high `calls`, tiny `mean_ms`, same query shape.

### Expert Mental Model

> Query count per request must be **constant** with respect to the number of items displayed. I design data loading per screen or use case, and I add a test that fails when a query count grows with N.

### Common Mistake

"Fixing" N+1 with `Promise.all` on per-item queries. It's faster in dev, but it turns 300 sequential queries into 300 concurrent ones that exhaust the connection pool under load.

---

## 11. Caching

### What

Storing the result of expensive work so later requests can reuse it. Caching is **trading freshness and correctness complexity for speed and load reduction.** It's one of the most powerful optimizations and one of the most common sources of bugs.

### Why

- Reduces latency on repeated reads (ms → µs).
- Shields the database from read load; absorbs traffic spikes.
- Reduces cost of expensive computation or external API calls (and rate limits).

### The caching layers

```text
Browser cache (HTTP Cache-Control)          ← free, closest to user
  ↓
CDN / edge cache (Vercel, Cloudflare, CloudFront)
  ↓
Next.js server caches (Data Cache / fetch cache / "use cache", Full Route Cache, React cache() per request)
  ↓
Application in-process cache (LRU in memory)   ← fastest, per-instance, not shared
  ↓
Distributed cache (Redis / Memcached)          ← shared across instances
  ↓
Database buffer cache / materialized views / read models
```

### Cache strategies

| Strategy | How | Good for | Risk |
|---|---|---|---|
| **Cache-aside (lazy)** | App reads cache → miss → load from DB → set cache | General read caching | Stale after writes unless invalidated; stampede on miss |
| **Read-through** | Cache library loads on miss | Same, encapsulated | Same |
| **Write-through** | Write to cache and DB together | Read-after-write consistency | Write latency; dual-write failure modes |
| **Write-behind** | Write to cache, flush to DB asynchronously | Counters, presence, high-rate metrics | Data loss on crash; not for money |
| **Refresh-ahead** | Refresh popular keys before expiry | Hot keys with expensive loads | Wasted refreshes |
| **Stale-while-revalidate** | Serve stale immediately, refresh in background | Pages, product data, config | Bounded staleness must be acceptable |
| **Materialized view / read model** | Precompute query results in DB, refresh on schedule or events | Dashboards, aggregates | Refresh cost and lag |

### Deciding what to cache

```text
Cache if ALL hold:
  ✓ Read frequency ≫ write frequency for this data
  ✓ The load is expensive (measured) or rate-limited
  ✓ Staleness has a known, acceptable bound for this use case
  ✓ You can define the key precisely (including tenant, locale, currency, permissions)
  ✓ You have a plan for invalidation OR a TTL that satisfies the staleness bound

Do NOT cache:
  ✗ Balances, inventory used for allocation decisions, authorization decisions with long TTLs
  ✗ Per-user data in shared caches without the user/tenant in the key
  ✗ Things that are already fast (you add a network hop to Redis for a 0.2 ms indexed PK lookup)
```

### Invalidation

"There are only two hard things in computer science: cache invalidation and naming things." (Phil Karlton)

| Approach | How | Trade-off |
|---|---|---|
| TTL only | Expire after N seconds | Simple; staleness up to TTL |
| Explicit delete on write | After commit, `DEL product:{id}` | Race: concurrent reader may re-populate stale value between DB write and delete |
| Versioned keys | Key includes version: `product:{id}:v{version}` | Old entries just expire; no race on read |
| Event-driven invalidation | Outbox/CDC event → consumer invalidates/refreshes | Decoupled and reliable; small lag |
| Tag-based (Next.js) | `revalidateTag('product:123')` after mutation | Framework-integrated |

**The classic race with delete-on-write:**

```text
t1  Reader A: cache miss for product:1
t2  Reader A: SELECT price → 100 (old)
t3  Writer B: UPDATE price = 120; COMMIT
t4  Writer B: DEL product:1
t5  Reader A: SET product:1 = 100   ← stale value written AFTER invalidation; stays until TTL
```

Mitigations: short TTL as a safety net always; versioned keys; delete **after** commit and again after a short delay ("double delete"); or have the writer set the new value with a version check.

### Cache stampede (thundering herd)

A popular key expires; 5,000 concurrent requests miss simultaneously and all hit the database.

```ts
// Mitigation 1: single-flight (in-process request coalescing)
const inflight = new Map<string, Promise<unknown>>();

export async function singleFlight<T>(key: string, load: () => Promise<T>): Promise<T> {
  const existing = inflight.get(key) as Promise<T> | undefined;
  if (existing) return existing;
  const p = load().finally(() => inflight.delete(key));
  inflight.set(key, p);
  return p;
}

// Mitigation 2: distributed lock so only one instance recomputes; others serve stale or wait briefly
// Mitigation 3: TTL jitter so keys written together don't expire together
const ttlSeconds = 300 + Math.floor(Math.random() * 60);

// Mitigation 4: stale-while-revalidate with a soft TTL
type Entry<T> = { value: T; softExpiresAt: number };

export async function getWithSWR<T>(redis: Redis, key: string, softTtlMs: number, hardTtlS: number, load: () => Promise<T>) {
  const raw = await redis.get(key);
  if (raw) {
    const entry = JSON.parse(raw) as Entry<T>;
    if (Date.now() > entry.softExpiresAt) {
      // serve stale now, refresh in background (only one refresher via SET NX lock)
      void (async () => {
        const gotLock = await redis.set(`${key}:lock`, '1', 'PX', 10_000, 'NX');
        if (!gotLock) return;
        const value = await load();
        await redis.set(key, JSON.stringify({ value, softExpiresAt: Date.now() + softTtlMs }), 'EX', hardTtlS);
      })().catch((err) => log().warn({ err, key }, 'swr refresh failed'));
    }
    return entry.value;
  }
  const value = await singleFlight(key, load);
  await redis.set(key, JSON.stringify({ value, softExpiresAt: Date.now() + softTtlMs }), 'EX', hardTtlS);
  return value;
}
```

(Mitigation 5 is probabilistic early expiration, the "XFetch" algorithm: refresh early with a probability that rises as expiry approaches.)

### Cache keys: correctness traps

```ts
// ❌ Leaks one tenant's prices to another; ignores currency and permissions
const key = `pricing:${productId}`;

// ✅ Key includes every dimension that changes the result
const key = `v3:pricing:${tenantId}:${productId}:${currency}:${priceListId}`;
```

### Next.js caching (App Router)

```tsx
// app/products/[slug]/page.tsx
import { unstable_cacheTag as cacheTag } from 'next/cache';  // API names vary across Next.js versions — check your version's docs

async function getProduct(slug: string) {
  'use cache';
  cacheTag(`product:${slug}`);
  return db.product.findUnique({ where: { slug }, select: { id: true, name: true, priceCents: true, images: true } });
}

// app/admin/products/actions.ts
'use server';
import { revalidateTag } from 'next/cache';

export async function updateProduct(slug: string, input: ProductInput) {
  await authorize('product:update');
  await db.product.update({ where: { slug }, data: parse(input) });
  revalidateTag(`product:${slug}`);   // precise invalidation after commit
}
```

Older/stable pattern: `fetch(url, { next: { revalidate: 60, tags: ['product:123'] } })` and route-level `export const revalidate = 60`. Whichever API your version uses, the principles are the same: cache by default where staleness is acceptable, tag precisely, invalidate on mutation, and **never cache personalized data in a shared cache**.

### HTTP caching headers

```ts
// Public, CDN-cacheable product JSON: fresh for 60 s at CDN, serve stale up to 5 min while revalidating
res.setHeader('Cache-Control', 'public, max-age=0, s-maxage=60, stale-while-revalidate=300');

// Immutable static assets with content hash in filename
res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

// Personalized data
res.setHeader('Cache-Control', 'private, no-store');
```

### Measure cache effectiveness

| Metric | Healthy |
|---|---|
| Hit ratio per keyspace | Depends; < 50% often means wrong keys or TTLs too short |
| Latency on hit vs miss | Hit should be ≫ faster, or the cache isn't worth it |
| Evictions | Frequent evictions of hot keys → undersized |
| Memory per keyspace | Watch for unbounded key growth (keys with timestamps/IDs) |
| Stale-read incidents | Business-level sensor (e.g., price mismatch at checkout) |

### Expert Mental Model

> A cache is a replicated copy of data with weaker consistency. Before I add one, I define the key dimensions, the acceptable staleness, the invalidation path, the stampede protection, and the sensor that tells me when staleness hurts users. If the underlying query can be made fast, I do that first.

### Common Mistake

Caching as the first performance fix, without a key strategy or invalidation plan, then spending weeks debugging "sometimes the old price shows up" and cross-tenant data leaks.

---

## 12. Network Latency

### What

Every network round trip costs time that no amount of code optimization removes: physics (distance), protocol handshakes, and queuing.

### Numbers every engineer should roughly know

| Operation | Approx. latency |
|---|---|
| L1 cache reference | ~1 ns |
| Main memory reference | ~100 ns |
| Read 1 MB sequentially from memory | ~0.1–0.25 ms |
| SSD random read | ~0.02–0.1 ms |
| Round trip within same datacenter / AZ | ~0.2–0.5 ms |
| Round trip across AZs in same region | ~1–2 ms |
| Redis GET (same AZ, incl. network) | ~0.3–1 ms |
| Simple indexed PostgreSQL query (same AZ) | ~0.5–2 ms |
| TLS handshake (new connection) | +1–2 RTTs (TLS 1.3: 1 RTT; with 0-RTT resumption: 0) |
| US East ↔ US West round trip | ~60–80 ms |
| US East ↔ Europe round trip | ~80–100 ms |
| Europe ↔ Southeast Asia/Australia round trip | ~150–300 ms |
| Mobile 4G added latency | ~30–100 ms+, highly variable |

### Why it matters

```text
A page served from us-east-1 to a user in Sydney: RTT ≈ 220 ms.
If the page needs: DNS + TCP + TLS (≈ 3 RTT) + HTML + 3 sequential API calls (4 RTT)
→ ≥ 7 × 220 ms = 1.5 s before any server processing time.

A server that queries a database in another region on each request:
50 queries × 70 ms = 3.5 s. Co-locate app and database, always.
```

### How experts reduce network cost

1. **Reduce round trips:** batch endpoints, screen-shaped APIs, server-side composition (RSC/BFF), `Promise.all` for independent calls, SQL joins instead of per-row fetches.
2. **Reuse connections:** HTTP keep-alive, connection pools for DB/Redis, HTTP/2 multiplexing.

```ts
// Node.js: reuse connections to upstream APIs (undici is Node's built-in fetch engine)
import { Agent, setGlobalDispatcher } from 'undici';
setGlobalDispatcher(new Agent({
  keepAliveTimeout: 30_000,
  keepAliveMaxTimeout: 60_000,
  connections: 50,          // per origin
  connect: { timeout: 2_000 },
  headersTimeout: 5_000,
  bodyTimeout: 10_000,
}));
```

3. **Move work closer to the user:** CDN for static assets and cacheable responses; edge for auth checks/redirects; regional read replicas for global read-heavy apps.
4. **Parallelize independent I/O:**

```ts
// ❌ Sequential: 120 + 90 + 150 = 360 ms
const user = await getUser(id);
const plan = await getPlan(id);
const usage = await getUsage(id);

// ✅ Parallel: max(120, 90, 150) = 150 ms
const [user, plan, usage] = await Promise.all([getUser(id), getPlan(id), getUsage(id)]);
```

5. **Compress:** Brotli/gzip for text responses (JSON compresses 5–10×). Skip compression for tiny payloads (< ~1 KB) and already-compressed media.
6. **Preconnect / DNS-prefetch** to critical third-party origins on the frontend.
7. **Avoid chatty protocols across regions:** a service in eu-west calling a database in us-east is an architecture bug, not a tuning problem.

### Expert Mental Model

> Round trips multiply, and distance is physics. I count round trips per user operation the same way I count queries per request, and I design to keep that count small and local.

### Common Mistake

Deploying the Next.js app to an edge/serverless region near users while the database stays in one distant region. Every server render then pays multiple cross-continent round trips, which is slower than a single-region deployment.

---

## 13. Serialization

### What

Converting in-memory objects to bytes (JSON, Protobuf, MessagePack) and back. In Node.js, `JSON.stringify`/`JSON.parse` are **synchronous and block the event loop**, and their cost scales with payload size.

### Why it matters

```text
Approximate costs in V8 (order of magnitude; measure on your hardware):
  JSON.stringify ~ 100–400 MB/s for typical nested objects
  JSON.parse     ~ 200–600 MB/s

A 20 MB response:
  stringify ≈ 50–200 ms of blocked event loop
  + gzip ≈ 100+ ms CPU
  + transfer on mobile ≈ seconds
  + JSON.parse in the browser main thread ≈ 50–150 ms (jank, poor INP)
During those ~100 ms, EVERY other request on that Node process waits.
```

### How experts handle it

1. **Send less.** The biggest win by far. Project only the needed fields, paginate, and don't serialize ORM entities with all relations.

```ts
// ❌ 4.1 MB: entire entities, nested relations, audit fields, internal flags
return res.json(await db.project.findMany({ include: { tasks: { include: { comments: true, attachments: true } } } }));

// ✅ 38 KB: screen-shaped DTO
return res.json(
  await db.project.findMany({
    where: { tenantId },
    select: { id: true, name: true, _count: { select: { tasks: { where: { status: 'OPEN' } } } } },
    take: 50,
  }),
);
```

2. **Use a schema-based fast serializer** for hot, stable response shapes (e.g., Fastify's `fast-json-stringify` with response schemas can be ~2–5× faster than `JSON.stringify` for known shapes).

```ts
fastify.get('/v1/orders/:id', {
  schema: {
    response: {
      200: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          status: { type: 'string' },
          totalCents: { type: 'integer' },
          createdAt: { type: 'string', format: 'date-time' },
        },
        additionalProperties: false,   // also prevents accidental data exposure
      },
    },
  },
}, handler);
```

3. **Stream large exports** instead of building giant strings:

```ts
import { pipeline } from 'node:stream/promises';
import QueryStream from 'pg-query-stream';
import { stringify } from 'csv-stringify';

app.get('/v1/exports/orders.csv', async (req, res) => {
  const client = await pool.connect();
  try {
    res.setHeader('Content-Type', 'text/csv');
    const query = new QueryStream(
      'SELECT id, number, total_cents, created_at FROM orders WHERE tenant_id = $1 ORDER BY id',
      [req.tenantId], { batchSize: 1000 },
    );
    await pipeline(client.query(query), stringify({ header: true }), res);
  } finally {
    client.release();
  }
});
// Constant memory, no event-loop-blocking giant stringify, first byte in ms.
// For very large exports: generate async to object storage and email a signed link (Section 18).
```

4. **Binary formats (Protobuf, gRPC, MessagePack, Avro)** for high-volume internal service-to-service traffic or event streams where schema evolution and size matter. They're rarely worth it for public browser-facing APIs, where JSON + compression + HTTP caching is usually sufficient.
5. **Avoid double serialization:** caching JSON strings in Redis and then `JSON.parse` + `JSON.stringify` again on every hit. If the cached payload is the response, send the string directly.
6. **Watch number and date handling:** `bigint` doesn't serialize to JSON; money as integer minor units; dates as ISO-8601 strings.

### Next.js / RSC specifics

Props passed from Server Components to Client Components are serialized into the RSC payload and embedded in the HTML. Passing a 2 MB object to a client component bloats the document and slows hydration. Pass only what the client component needs.

```tsx
// ❌ Entire product object (with descriptions, all variants, reviews) serialized to the client
<AddToCartButton product={product} />

// ✅ Only what the interactive component needs
<AddToCartButton productId={product.id} variantIds={product.variants.map((v) => v.id)} priceCents={product.priceCents} />
```

### Expert Mental Model

> Serialization cost is proportional to payload size, and in Node it blocks everyone. The best serializer is the one serializing less data.

### Common Mistake

Switching to a binary protocol to fix slow APIs whose real problem is returning 50× more data than the screen displays.

---
