# 07 — Designing for Failure

> Production systems do not fail "if" — they fail "when", "how often", "how much", and "how visibly". Expert engineers treat failure as a normal input to the design, the same way they treat user requests. This chapter explains the failure mindset, walks through every major failure class with concrete scenarios, detection, and mitigation, and gives working code for the core reliability mechanisms: idempotency, outbox/inbox, timeouts, retries, circuit breakers, bulkheads, backpressure, queues, sagas, safe deployments, backups, and lock discipline.

Related chapters: [03-how-experts-design.md](03-how-experts-design.md) (asking "what can fail?" early), [09-invariants-and-correctness.md](09-invariants-and-correctness.md) (what must stay true despite failure), [05-quality-engineering.md](05-quality-engineering.md) (reliability as a measured property), [06-performance-engineering.md](06-performance-engineering.md) (capacity and saturation), [08-security-engineering.md](08-security-engineering.md) (abuse is a failure mode too), [templates/failure-mode-analysis.md](templates/failure-mode-analysis.md), [templates/runbook.md](templates/runbook.md), [templates/postmortem.md](templates/postmortem.md).

---

## Table of Contents

1. [The Mindset: Everything Eventually Fails](#1-the-mindset-everything-eventually-fails)
2. [A Taxonomy of Failure](#2-a-taxonomy-of-failure)
3. [Failure Classes: Scenario → Detection → Mitigation](#3-failure-classes-scenario--detection--mitigation)
4. [Idempotency](#4-idempotency)
5. [Transactions, Atomicity, and Consistency](#5-transactions-atomicity-and-consistency)
6. [Transactional Outbox and Inbox (Duplicate Events)](#6-transactional-outbox-and-inbox-duplicate-events)
7. [Timeouts and Deadline Propagation](#7-timeouts-and-deadline-propagation)
8. [Retries: Backoff, Jitter, Budgets — and When Retries Kill You](#8-retries-backoff-jitter-budgets--and-when-retries-kill-you)
9. [Circuit Breakers](#9-circuit-breakers)
10. [Bulkheads](#10-bulkheads)
11. [Backpressure and Load Shedding](#11-backpressure-and-load-shedding)
12. [Queues, Dead-Letter Queues, and Redrive](#12-queues-dead-letter-queues-and-redrive)
13. [Graceful Degradation](#13-graceful-degradation)
14. [Sagas and Compensation](#14-sagas-and-compensation)
15. [Deployments as a Failure Source: Zero-Downtime and Expand/Contract](#15-deployments-as-a-failure-source-zero-downtime-and-expandcontract)
16. [Feature Flags and Rollbacks](#16-feature-flags-and-rollbacks)
17. [Backups, Verified Restores, RTO and RPO](#17-backups-verified-restores-rto-and-rpo)
18. [Race Conditions and Deadlocks in PostgreSQL](#18-race-conditions-and-deadlocks-in-postgresql)
19. [Capacity Exhaustion: Pools, Disk, File Descriptors, Memory](#19-capacity-exhaustion-pools-disk-file-descriptors-memory)
20. [Recovery: Detect, Contain, Repair, Learn](#20-recovery-detect-contain-repair-learn)
21. [Worked FMEA: Payment/Checkout Flow](#21-worked-fmea-paymentcheckout-flow)
22. [Amateur vs Professional vs Expert](#22-amateur-vs-professional-vs-expert)
23. [Key Takeaways](#23-key-takeaways)
24. [Self-Assessment Checklist](#24-self-assessment-checklist)

---

## 1. The Mindset: Everything Eventually Fails

### What

The failure mindset is the habit of asking, for every line that crosses a boundary (process, network, disk, database, human), **"what happens if this does not complete, completes twice, completes slowly, or completes and I never find out?"**

Those four outcomes are the complete vocabulary of distributed failure:

| Outcome | Example | Naive assumption it breaks |
|---|---|---|
| Does not complete | Payment provider returns 503 | "The call either works or throws a clear error" |
| Completes twice | Client retries after a timeout, the first request actually succeeded | "Each request is processed once" |
| Completes slowly | DB query takes 28s under lock contention | "Calls return quickly" |
| Completes, but you never learn it | Charge succeeded, response lost on the network | "No response means it didn't happen" |

The fourth case is the one that separates experts from everyone else. A timeout is **not** a failure — it is **an unknown outcome**. Any design that treats a timeout as "it failed, try again" without idempotency will eventually double-charge someone.

### Why

At small scale, rare events feel impossible. At scale they are scheduled:

```text
P(failure per request) = 0.0001 (one in ten thousand)
Requests per day       = 5,000,000
Expected failures/day  = 500
```

A "one in a million" race condition in a system doing 50 requests/second happens about **four times a day**. Hardware fails, cloud zones degrade, deploys restart processes mid-request, certificates expire, DNS misbehaves, and people run the wrong migration. You cannot prevent these. You can only decide in advance **what the system does when they happen**.

The cost asymmetry drives the mindset: designing idempotency into a payment endpoint costs a day. Reconciling 300 double charges, refunding them, and handling support tickets and chargebacks costs weeks and customer trust.

### How

Experts operationalize failure thinking with a small set of repeatable questions applied to every boundary crossing:

```text
For each call / write / message:
1. What is the timeout, and who chose it?
2. If it times out, is the outcome unknown? How do we resolve the unknown?
3. Is it safe to retry? (Idempotent? Deduplicated?)
4. If it's retried by someone else (client, queue, load balancer), what happens?
5. If the process crashes between step N and N+1, what state is left behind?
6. What does the user see while this dependency is down?
7. How do we detect this failure — metric, log, alert, reconciliation?
8. How do we repair the damage — automatically, via runbook, via script?
```

They then encode the answers as mechanisms (idempotency keys, outbox, circuit breakers), tests (fault injection, crash tests), and operations (alerts, runbooks, reconciliation jobs).

### Example

A logistics WMS service reserves stock and then calls a carrier API to buy a shipping label:

```ts
// Naive
async function fulfil(orderId: string) {
  await db.query(`UPDATE orders SET status = 'fulfilling' WHERE id = $1`, [orderId]);
  const label = await carrier.createLabel(orderId);          // may hang, fail, or succeed silently
  await db.query(`UPDATE orders SET label_url = $1, status = 'labelled' WHERE id = $2`, [label.url, orderId]);
}
```

Failure walk-through:

| Crash / failure point | Resulting state | Consequence |
|---|---|---|
| After first UPDATE, before carrier call | `fulfilling`, no label | Order stuck forever; nobody retries |
| Carrier call hangs | Request thread blocked, pool slot held | Under load, pool exhausts; whole service stalls |
| Carrier succeeds, response lost | Label purchased (money spent), DB still `fulfilling` | Retry buys a **second** label |
| Second UPDATE fails | Same as above | Same |

Expert version (sketched; each mechanism is detailed later):

```ts
async function fulfil(orderId: string, deadline: Deadline) {
  // 1. Durable intent, with a deterministic idempotency key for the external side effect
  await db.tx(async (tx) => {
    await tx.query(
      `UPDATE orders SET status = 'label_requested', label_idem_key = COALESCE(label_idem_key, $2)
        WHERE id = $1 AND status IN ('paid', 'label_requested')`,
      [orderId, `label:${orderId}`],
    );
    await tx.query(`INSERT INTO outbox (topic, payload) VALUES ('label.requested', $1)`, [{ orderId }]);
  });
  // 2. A worker consumes label.requested with a timeout, retry w/ backoff, and the idempotency key
  //    passed to the carrier ("Idempotency-Key: label:<orderId>").
  // 3. A reconciliation job finds orders in 'label_requested' older than 15 minutes and re-queries
  //    the carrier by idempotency key to resolve unknown outcomes.
}
```

### Expert Mental Model

> "Every arrow in my architecture diagram is a place where a message can be lost, duplicated, delayed, or reordered. Every box can crash between any two lines. My job is to make each of those outcomes either harmless or detectable and repairable."

### Common Mistake

Treating the **happy path plus a try/catch** as failure handling. A `catch` that logs and rethrows does nothing about partial state, unknown outcomes, or duplicates. Error handling is local; failure design is systemic.

---

## 2. A Taxonomy of Failure

Classifying failures makes them tractable because each class has a known family of mitigations.

| Class | Characteristics | Examples | Primary mitigations |
|---|---|---|---|
| **Crash / fail-stop** | Component stops entirely | OOM kill, node loss, deploy restart | Redundancy, health checks, durable state, idempotent resume |
| **Omission** | Messages/requests lost | Dropped packets, lost response, consumer crash before ack | Timeouts, retries, acks, outbox, reconciliation |
| **Timing / latency** | Correct result, too late | GC pause, lock wait, slow dependency | Timeouts, deadlines, bulkheads, load shedding |
| **Duplication** | Same work applied twice | Client retry, at-least-once delivery | Idempotency keys, inbox dedup, unique constraints |
| **Ordering** | Events arrive out of order | Parallel consumers, partition rebalances | Versioning, sequence numbers, state machines that reject illegal transitions |
| **Partial** | Some steps succeed, others fail | Charge OK, order write fails | Transactions, outbox, sagas, compensation |
| **Byzantine-ish / corruption** | Wrong data, silently | Bad migration, bug writing wrong totals, bit rot | Constraints, checksums, audits, reconciliation, PITR |
| **Resource exhaustion** | System degrades as a whole | Pool, disk, FD, memory, queue depth | Limits, quotas, backpressure, capacity alerts |
| **Correlated / cascading** | One failure triggers others | Retry storms, thundering herd, shared dependency | Circuit breakers, retry budgets, jitter, isolation |
| **Human / operational** | Wrong action by a person | Dropped table, wrong config, expired cert | Guardrails, reviews, automation, least privilege, backups |

**Key insight:** most large outages are **cascading** failures: a small latency increase in one dependency causes retries, which increase load, which exhausts pools, which causes health checks to fail, which removes instances, which increases load on the survivors. Designing for failure is largely designing to **break the cascade**.

```text
Slow DB (p99 200ms → 3s)
  → requests hold connections longer
  → pool exhausted (max 20)
  → new requests wait for a connection → time out at the LB (30s)
  → clients retry (x3)
  → 3x load on an already saturated service
  → health checks time out → instances marked unhealthy → removed
  → remaining instances get even more load
  → total outage
```

Each arrow is a place for a mechanism: query timeouts, pool acquisition timeouts, deadline propagation, retry budgets, health checks that don't depend on the DB, load shedding.

---

## 3. Failure Classes: Scenario → Detection → Mitigation

This section treats each failure type from the brief as an operational playbook entry.

### 3.1 Database failures

**Scenario (SaaS billing):** The primary PostgreSQL instance fails over to a replica during the monthly invoice run. For ~30 seconds, all connections error with `terminating connection due to administrator command` or `the database system is in recovery mode`. Some transactions committed right before the failover; some did not; some connections hang on dead TCP sockets.

**Detection:**
- Error-rate metric on DB client errors by SQLSTATE class (`08*` connection, `57P*` operator intervention, `40001` serialization, `40P01` deadlock).
- Replication lag metric; failover events from the managed DB provider forwarded to alerting.
- Synthetic "canary write" every 30s to a heartbeat table.

**Mitigation:**
- Configure TCP keepalives and `connectionTimeoutMillis`, `statement_timeout`, `idle_in_transaction_session_timeout` so dead connections don't hang forever.
- Retry **only retryable** errors (connection errors before commit, serialization failures, deadlocks) and only for idempotent units of work.
- Make the batch job resumable: process invoices in chunks, record progress, use unique constraints (`UNIQUE (subscription_id, period_start)`) so a rerun can't double-invoice.
- Use `COMMIT` outcome awareness: if the connection dies *during* `COMMIT`, the outcome is unknown — re-read by natural key before redoing.

```ts
const RETRYABLE_SQLSTATE = new Set(['40001', '40P01', '57P01', '08006', '08003', '08001']);

export function isRetryableDbError(err: unknown): boolean {
  const code = (err as { code?: string })?.code;
  return typeof code === 'string' && RETRYABLE_SQLSTATE.has(code);
}
```

```sql
-- Server-side safety nets (per role, so batch jobs can get different values)
ALTER ROLE app_web  SET statement_timeout = '5s';
ALTER ROLE app_web  SET idle_in_transaction_session_timeout = '15s';
ALTER ROLE app_web  SET lock_timeout = '2s';
ALTER ROLE app_batch SET statement_timeout = '120s';
```

### 3.2 Network failures

**Scenario (social platform):** A service mesh sidecar restarts; for 4 seconds, 2% of requests between `feed-service` and `graph-service` get connection resets. Others experience packet loss causing 1–3s TCP retransmit delays.

**Detection:** Client-side metrics per dependency: request count, error count by type (`ECONNRESET`, `ETIMEDOUT`, `EAI_AGAIN`), latency histogram. Server-side metrics alone can't see requests that never arrived.

**Mitigation:** Short connect timeouts (e.g. 1s) separate from request timeouts; retry once on connection-establishment errors (the request was never sent, so it's safe even for non-idempotent operations); keep-alive connection pools; hedged requests for idempotent reads at p95 latency.

### 3.3 API (third-party) failures

**Scenario (e-commerce):** The tax-calculation API starts returning HTTP 200 with a body `{"error":"rate limited"}` instead of a 429. The checkout code parses `body.tax` as `undefined`, coerces to `0`, and orders ship with zero tax for two hours.

**Detection:** Schema validation on every response (treat third-party responses as untrusted input), business metric alerts ("average tax per order dropped 100%"), reconciliation against provider reports.

**Mitigation:**

```ts
import { z } from 'zod';

const TaxResponse = z.object({
  tax: z.object({ amountMinor: z.number().int().nonnegative(), currency: z.string().length(3) }),
});

export async function getTax(req: TaxRequest, signal: AbortSignal) {
  const res = await fetch(TAX_URL, { method: 'POST', body: JSON.stringify(req), signal });
  if (res.status === 429 || res.status >= 500) throw new RetryableUpstreamError('tax', res.status);
  if (!res.ok) throw new UpstreamError('tax', res.status);
  const parsed = TaxResponse.safeParse(await res.json());
  if (!parsed.success) throw new UpstreamContractError('tax', parsed.error); // never default to 0
  return parsed.data.tax;
}
```

Rule: **a dependency's malformed success is a failure.** Never let parsing defaults turn a failure into wrong data.

### 3.4 Timeouts

**Scenario (banking):** A transfer endpoint calls the core-banking system with no explicit timeout. Node's `fetch` has no default overall timeout. The core system hangs on a lock; 400 requests pile up in memory; the pod OOMs; all in-flight transfers are left in unknown states.

**Detection:** Latency histograms with p99/p99.9 and max; "in-flight requests" gauge; event-loop lag metric.

**Mitigation:** Explicit timeouts on every I/O call, derived from a request deadline (Section 7). Treat timeout as unknown outcome for non-idempotent calls → resolve via status query or reconciliation.

### 3.5 Retries

**Scenario (developer tools):** A CI service's artifact upload client retries 5 times with a fixed 100ms delay. Object storage has a brief throttling event. 10,000 CI jobs simultaneously retry in lockstep, turning a 10-second throttle into a 10-minute outage.

**Detection:** Retry-count metrics (`client_retries_total{dependency}`); ratio of retries to first attempts; upstream 429/503 rate.

**Mitigation:** Exponential backoff, full jitter, retry budget, respect `Retry-After`, retry at one layer only (Section 8).

### 3.6 Duplicate requests

**Scenario (payments):** A mobile client on a train submits "Pay $120". The request reaches the server and succeeds; the response is lost when the train enters a tunnel. The app shows "Network error — try again". The user taps again.

**Detection:** Count of idempotency-key replays; count of charges with same (customer, amount, merchant) within 60s (a heuristic detector for missing idempotency).

**Mitigation:** Client-generated idempotency key per *intent* (generated when the payment screen opens, not per tap), server-side idempotency table (Section 4), unique constraints on business keys.

### 3.7 Duplicate events

**Scenario (logistics):** A Kafka consumer processing `ShipmentDelivered` events commits offsets every 5 seconds. It crashes after processing 300 events but before committing. On restart, it reprocesses them and sends 300 duplicate "Your package was delivered" emails and increments "delivered count" twice.

**Detection:** Inbox dedup-hit metric; downstream sanity checks (delivered count > shipped count violates an invariant).

**Mitigation:** Assume **at-least-once** delivery always. Inbox table keyed by event ID in the same transaction as the side effect (Section 6); make handlers idempotent by design (`SET status='delivered'` instead of `count = count + 1`).

### 3.8 Partial failures

**Scenario (e-commerce):** Checkout: (1) charge card, (2) insert order, (3) decrement inventory, (4) send email. Step 3 fails due to a constraint violation. The card is charged, the order exists, inventory is wrong, no email.

**Detection:** Reconciliation jobs comparing payment provider records with orders; orders in intermediate states past their SLA.

**Mitigation:** Collapse local steps into one DB transaction; externalize remote steps via outbox; model the flow as a state machine or saga with compensations (Section 14).

### 3.9 Crashes

**Scenario (SaaS):** A worker generating monthly PDF reports is OOM-killed on report #4,112 of 9,000. The job was written as a single loop over an in-memory list; restart begins from #1 and re-emails 4,111 customers.

**Detection:** Container restart counts, OOMKilled reason, job progress metrics that stop advancing.

**Mitigation:** Checkpointed, resumable jobs; per-item idempotency (`report_deliveries UNIQUE(customer_id, period)`); graceful shutdown handling `SIGTERM`; memory limits and streaming instead of loading everything.

```ts
// Graceful shutdown: stop accepting, finish in-flight, then exit
let shuttingDown = false;
process.on('SIGTERM', async () => {
  shuttingDown = true;
  server.close();                               // stop accepting new connections
  await worker.stopPolling();                   // stop taking new jobs
  await Promise.race([inFlight.drain(), sleep(25_000)]); // k8s default grace period is 30s
  await pool.end();
  process.exit(0);
});
```

### 3.10 Deployments

**Scenario (SaaS):** A deploy renames column `users.name` to `users.full_name` in the same release as the code change. During the rolling deploy, old pods query `name` and error for 6 minutes. Rollback is impossible because the migration already ran.

**Detection:** Error-rate SLO burn alert correlated with deploy markers; canary analysis.

**Mitigation:** Expand/contract migrations, backward-compatible releases, canaries, automatic rollback on SLO breach (Section 15).

### 3.11 Data corruption

**Scenario (WMS):** A bug in unit conversion stores quantities in "each" where "cases of 12" were expected for one warehouse. Inventory counts are wrong for 3 days before a cycle count notices.

**Detection:** Domain invariants checked continuously (`on_hand >= 0`, `sum(movements) = on_hand`), anomaly detection on business metrics, periodic reconciliation with physical counts.

**Mitigation:** Append-only movement ledger (derived balance can be recomputed), CHECK constraints, point-in-time recovery, audit logs identifying affected rows, data repair scripts reviewed like code. See [09-invariants-and-correctness.md](09-invariants-and-correctness.md).

```sql
CREATE TABLE stock_movements (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sku_id       bigint NOT NULL REFERENCES skus(id),
  location_id  bigint NOT NULL REFERENCES locations(id),
  qty_each     integer NOT NULL CHECK (qty_each <> 0),
  reason       text NOT NULL CHECK (reason IN ('receipt','pick','adjust','transfer_in','transfer_out')),
  source_ref   text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reason, source_ref, sku_id, location_id)   -- makes replays harmless
);

-- Nightly invariant check: derived balance must match cached balance
SELECT b.sku_id, b.location_id, b.on_hand, COALESCE(SUM(m.qty_each), 0) AS ledger
FROM stock_balances b
LEFT JOIN stock_movements m USING (sku_id, location_id)
GROUP BY b.sku_id, b.location_id, b.on_hand
HAVING b.on_hand <> COALESCE(SUM(m.qty_each), 0);
```

### 3.12 Dependency outages

**Scenario (e-commerce):** The recommendations service is down. Product pages call it synchronously with a 10s timeout. Product pages now take 10s and eventually time out — the store is "down" because a non-essential widget is down.

**Detection:** Per-dependency availability and latency dashboards; circuit breaker state metric.

**Mitigation:** Classify dependencies as **critical** (payment for checkout) vs **optional** (recommendations, reviews). Optional dependencies get short timeouts (200–300ms), circuit breakers, cached/static fallbacks, and are rendered in a way that doesn't block the page (in Next.js, a `<Suspense>` boundary with a fallback, fetched in a separately streamed server component).

### 3.13 Race conditions

**Scenario (ticketing / e-commerce flash sale):** Two requests read `stock = 1`, both pass `if (stock > 0)`, both write `stock = 0`, both create orders. One item sold twice.

**Detection:** Invariant checks (`orders_for_sku > initial_stock`), constraint violation metrics, negative stock alerts.

**Mitigation:** Atomic conditional updates, row locks, constraints, serializable isolation (Section 18).

### 3.14 Deadlocks

**Scenario (banking):** Transfer A→B locks A then B; concurrent transfer B→A locks B then A. PostgreSQL detects the cycle after `deadlock_timeout` (1s default) and aborts one with SQLSTATE `40P01`.

**Detection:** `log_lock_waits = on`, deadlock count from `pg_stat_database.deadlocks`, error metrics on `40P01`.

**Mitigation:** Consistent lock ordering, short transactions, retry the aborted transaction (Section 18).

### 3.15 Capacity exhaustion

**Scenario (SaaS analytics):** A customer uploads a 4 GB CSV. The import endpoint buffers it into memory, the pod OOMs; meanwhile the temp directory fills the node disk, evicting other pods; the log volume spikes and fills the logging agent buffer.

**Detection:** Saturation metrics (USE method: Utilization, Saturation, Errors) for CPU, memory, disk, FDs, pool, queue depth; alerts at 80% with time-to-exhaustion projection.

**Mitigation:** Limits everywhere (upload size, request body, concurrency, per-tenant quotas), streaming, direct-to-object-storage uploads with presigned URLs, disk usage alerts, log sampling (Section 19).

---

## 4. Idempotency

### What

An operation is **idempotent** if performing it multiple times has the same effect as performing it once. `SET status = 'shipped'` is naturally idempotent; `balance = balance - 100` is not. An **idempotency key** is a client-supplied identifier for an *intent* that allows the server to recognize and safely replay a repeated request.

### Why

Retries are unavoidable: clients retry on timeout, load balancers retry on connection failure, queues redeliver, users double-click, and your own workers restart. Since you cannot prevent duplicates, you must make them harmless. Idempotency is the mechanism that turns **at-least-once delivery** into **effectively-once processing**.

### How

Three layers, strongest last:

1. **Natural idempotency** — design writes as absolute state (`SET`) or upserts rather than deltas.
2. **Business-key uniqueness** — `UNIQUE (order_id)` on `payments`, so a second insert fails.
3. **Idempotency-key store** — records request fingerprint and stored response; replays return the stored response; concurrent duplicates are blocked.

Rules for a correct idempotency-key implementation:

- Key scope: per **tenant/user + endpoint**, so keys from different users can't collide or be probed.
- Store a **request fingerprint** (hash of method, path, canonical body). Same key + different body → `422`, not replay.
- Handle **concurrency**: the second request arriving while the first is in progress must not execute; return `409` (with `Retry-After`) or wait.
- Store the **final response** (status + body) and replay it exactly.
- Record the key **in the same transaction** as the local side effects when possible.
- For **external side effects** (calling Stripe), pass a derived idempotency key downstream too.
- Expire keys after a documented window (e.g. 24h–7 days).
- Do **not** store responses for failures that are safe to retry (5xx caused before side effects), or clients get stuck replaying a transient error.

### Example — schema

```sql
CREATE TABLE idempotency_keys (
  tenant_id        uuid        NOT NULL,
  key              text        NOT NULL CHECK (length(key) BETWEEN 8 AND 255),
  endpoint         text        NOT NULL,             -- e.g. 'POST /v1/payments'
  request_hash     bytea       NOT NULL,             -- sha256 of canonical request
  status           text        NOT NULL CHECK (status IN ('in_progress', 'completed')),
  response_status  integer,
  response_body    jsonb,
  locked_until     timestamptz,                      -- lease for in-progress execution
  created_at       timestamptz NOT NULL DEFAULT now(),
  completed_at     timestamptz,
  PRIMARY KEY (tenant_id, endpoint, key)
);

CREATE INDEX idempotency_keys_created_at_idx ON idempotency_keys (created_at);
-- Cleanup job: DELETE FROM idempotency_keys WHERE created_at < now() - interval '7 days';
```

### Example — middleware (Express-style, TypeScript, `pg`)

```ts
import crypto from 'node:crypto';
import type { Request, Response, NextFunction } from 'express';
import { pool } from './db';

const LEASE_SECONDS = 60;

function canonicalHash(req: Request): Buffer {
  const canonical = JSON.stringify({ method: req.method, path: req.path, body: sortKeys(req.body) });
  return crypto.createHash('sha256').update(canonical).digest();
}

export function idempotent(endpoint: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const key = req.header('Idempotency-Key');
    if (!key) return res.status(400).json({ error: 'Idempotency-Key header required' });

    const tenantId = req.auth.tenantId;          // from authenticated context, never from the body
    const hash = canonicalHash(req);

    // Try to claim the key atomically.
    const claim = await pool.query(
      `INSERT INTO idempotency_keys (tenant_id, key, endpoint, request_hash, status, locked_until)
       VALUES ($1, $2, $3, $4, 'in_progress', now() + make_interval(secs => $5))
       ON CONFLICT (tenant_id, endpoint, key) DO NOTHING
       RETURNING key`,
      [tenantId, key, endpoint, hash, LEASE_SECONDS],
    );

    if (claim.rowCount === 0) {
      const { rows: [existing] } = await pool.query(
        `SELECT request_hash, status, response_status, response_body, locked_until
           FROM idempotency_keys WHERE tenant_id = $1 AND endpoint = $2 AND key = $3`,
        [tenantId, endpoint, key],
      );

      if (!existing.request_hash.equals(hash)) {
        return res.status(422).json({ error: 'Idempotency-Key reused with a different request' });
      }
      if (existing.status === 'completed') {
        res.setHeader('Idempotent-Replayed', 'true');
        return res.status(existing.response_status).json(existing.response_body);
      }
      // In progress. If lease expired, the original worker probably crashed: allow takeover.
      const takeover = await pool.query(
        `UPDATE idempotency_keys
            SET locked_until = now() + make_interval(secs => $4)
          WHERE tenant_id = $1 AND endpoint = $2 AND key = $3
            AND status = 'in_progress' AND locked_until < now()
          RETURNING key`,
        [tenantId, endpoint, key, LEASE_SECONDS],
      );
      if (takeover.rowCount === 0) {
        res.setHeader('Retry-After', '2');
        return res.status(409).json({ error: 'A request with this Idempotency-Key is in progress' });
      }
    }

    // Capture the response so we can persist it.
    const originalJson = res.json.bind(res);
    res.json = (body: unknown) => {
      const status = res.statusCode;
      const persist = status < 500; // 4xx are deterministic outcomes; 5xx may be retried
      const write = persist
        ? pool.query(
            `UPDATE idempotency_keys
                SET status = 'completed', response_status = $4, response_body = $5, completed_at = now()
              WHERE tenant_id = $1 AND endpoint = $2 AND key = $3`,
            [tenantId, endpoint, key, status, body],
          )
        : pool.query(
            `DELETE FROM idempotency_keys WHERE tenant_id = $1 AND endpoint = $2 AND key = $3`,
            [tenantId, endpoint, key],
          );
      write.catch((err) => req.log.error({ err }, 'failed to persist idempotency result'));
      return originalJson(body);
    };

    next();
  };
}
```

Important caveat visible in this code: persisting the response happens *after* the handler's transaction. If the process crashes between the handler's commit and the idempotency update, the key stays `in_progress`; a later retry takes over after the lease and re-executes the handler. That is why the handler **must still be protected by business-key uniqueness** (`UNIQUE (tenant_id, client_reference)` on `payments`) or the idempotency record must be written in the **same transaction** as the business write. The strongest pattern passes the transaction into the handler:

```ts
await db.tx(async (tx) => {
  const payment = await createPayment(tx, input);               // business write
  await tx.query(
    `UPDATE idempotency_keys SET status='completed', response_status=201, response_body=$4, completed_at=now()
      WHERE tenant_id=$1 AND endpoint=$2 AND key=$3`,
    [tenantId, endpoint, key, toDto(payment)],
  );
});
```

### Example — client side (React / Next.js)

```tsx
'use client';
import { useMemo, useState } from 'react';

export function PayButton({ orderId, amountMinor }: { orderId: string; amountMinor: number }) {
  // One key per payment *intent*: stable across re-renders and retries, new if the page is reopened.
  const idempotencyKey = useMemo(() => crypto.randomUUID(), [orderId]);
  const [state, setState] = useState<'idle' | 'pending' | 'done' | 'error'>('idle');

  async function pay() {
    setState('pending');
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const res = await fetch('/api/payments', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Idempotency-Key': idempotencyKey },
          body: JSON.stringify({ orderId, amountMinor }),
          signal: AbortSignal.timeout(15_000),
        });
        if (res.status === 409) { await sleep(1000 * (attempt + 1)); continue; }
        setState(res.ok ? 'done' : 'error');
        return;
      } catch {
        await sleep(500 * 2 ** attempt); // network error/timeout: outcome unknown; same key makes retry safe
      }
    }
    setState('error');
  }

  return (
    <button onClick={pay} disabled={state === 'pending' || state === 'done'}>
      {state === 'pending' ? 'Processing…' : 'Pay'}
    </button>
  );
}
```

Disabling the button is a UX nicety, **not** the safety mechanism. The server-side key is the safety mechanism.

### Expert Mental Model

> "A request is an *intent*, not an event. The intent has an identity. The system's job is to apply each intent exactly once no matter how many times it's delivered."

### Common Mistake

- Generating a new idempotency key **per attempt** (defeats the purpose).
- Checking "does a key exist?" with `SELECT` then `INSERT` (race condition — two requests both see "no").
- Caching a 500 response forever, so the client can never succeed.
- Using an idempotency key but not comparing request bodies, so a buggy client reusing keys gets wrong responses silently.
- Relying on the frontend disabled button as protection.

---

## 5. Transactions, Atomicity, and Consistency

### What

- **Atomicity:** all writes in a transaction commit together or none do.
- **Consistency (ACID sense):** a transaction moves the DB from one valid state to another, as defined by constraints.
- **Isolation:** concurrent transactions don't see each other's intermediate state — to a degree set by the isolation level.
- **Durability:** committed data survives crashes.
- **Consistency (distributed sense, CAP/eventual):** whether all readers see the same data at the same time. Different concept, same word — be precise.

### Why

Transactions are the cheapest, most powerful failure-handling tool you have: they turn "crash between step 2 and step 3" into a non-issue for everything **inside one database**. Most partial-failure bugs in monoliths come from not using them, or from putting a network call inside them.

### How

Rules experts follow:

1. **Group all writes that must be consistent into one transaction.**
2. **Never call external services inside a DB transaction.** It holds locks and connections while waiting on the network, and a rollback cannot undo the external call.
3. **Keep transactions short** — milliseconds, not seconds.
4. **Know your isolation level.** PostgreSQL default is `READ COMMITTED`, which allows lost updates and write skew in read-then-write logic.
5. **Retry serialization failures** (`40001`) and deadlocks (`40P01`) — the DB is telling you "try again".

PostgreSQL isolation summary:

| Level | Dirty read | Non-repeatable read | Phantom | Lost update (read-modify-write) | Write skew |
|---|---|---|---|---|---|
| READ COMMITTED (default) | No | Possible | Possible | **Possible** | Possible |
| REPEATABLE READ | No | No | No (in PG) | Detected → `40001` | **Possible** |
| SERIALIZABLE | No | No | No | Detected → `40001` | Detected → `40001` |

### Example — transfer between accounts (banking)

```ts
export async function transfer(input: { fromId: string; toId: string; amountMinor: number; transferId: string }) {
  return withRetry(() => db.tx({ isolation: 'serializable' }, async (tx) => {
    // Insert the transfer first: UNIQUE(transfer_id) makes a duplicate request fail fast.
    await tx.query(
      `INSERT INTO transfers (id, from_account, to_account, amount_minor) VALUES ($1, $2, $3, $4)`,
      [input.transferId, input.fromId, input.toId, input.amountMinor],
    );
    const debit = await tx.query(
      `UPDATE accounts SET balance_minor = balance_minor - $2
        WHERE id = $1 AND balance_minor >= $2 AND status = 'active'`,
      [input.fromId, input.amountMinor],
    );
    if (debit.rowCount !== 1) throw new InsufficientFundsError();
    await tx.query(`UPDATE accounts SET balance_minor = balance_minor + $2 WHERE id = $1 AND status = 'active'`,
      [input.toId, input.amountMinor]);
    await tx.query(
      `INSERT INTO ledger_entries (transfer_id, account_id, amount_minor) VALUES ($1, $2, $3), ($1, $4, $5)`,
      [input.transferId, input.fromId, -input.amountMinor, input.toId, input.amountMinor],
    );
  }), { retryOn: isRetryableDbError, maxAttempts: 5 });
}
```

Plus a database-level backstop:

```sql
ALTER TABLE accounts ADD CONSTRAINT balance_non_negative CHECK (balance_minor >= 0);
```

### Expert Mental Model

> "Inside one database, I get atomicity for free — I should use it aggressively. The moment a second system is involved, atomicity is gone and I need a different tool: outbox, saga, or reconciliation."

### Common Mistake

```ts
await db.tx(async (tx) => {
  await tx.query('INSERT INTO orders ...');
  await stripe.charges.create(...);   // network call holding locks + connection; rollback won't refund
  await tx.query('UPDATE inventory ...');
});
```

---

## 6. Transactional Outbox and Inbox (Duplicate Events)

### What

- **Outbox:** Instead of writing to the DB and then publishing to a broker (two systems, no atomicity), write the event into an `outbox` table **in the same transaction** as the business change. A separate relay publishes outbox rows to the broker and marks them sent.
- **Inbox:** On the consuming side, record each processed message ID in an `inbox` table **in the same transaction** as the handler's side effects. A duplicate delivery hits the primary key and is skipped.

Together: **at-least-once publishing + idempotent consumption = effectively-once processing.**

### Why

The dual-write problem:

```ts
await db.query('INSERT INTO orders ...');     // succeeds
await kafka.send('order.created', ...);       // process crashes before this → event lost forever
```

Reverse the order and you get events for orders that don't exist. There is no ordering of two independent writes that is safe. The outbox makes the event part of the DB commit.

### How — outbox schema and relay

```sql
CREATE TABLE outbox (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id       uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  aggregate_type text        NOT NULL,
  aggregate_id   text        NOT NULL,
  event_type     text        NOT NULL,
  payload        jsonb       NOT NULL,
  headers        jsonb       NOT NULL DEFAULT '{}',
  created_at     timestamptz NOT NULL DEFAULT now(),
  published_at   timestamptz,
  attempts       integer     NOT NULL DEFAULT 0,
  last_error     text
);
CREATE INDEX outbox_unpublished_idx ON outbox (id) WHERE published_at IS NULL;
```

Writing the event with the business change:

```ts
await db.tx(async (tx) => {
  const { rows: [order] } = await tx.query(
    `INSERT INTO orders (id, customer_id, total_minor, status) VALUES ($1, $2, $3, 'placed') RETURNING *`,
    [orderId, customerId, totalMinor],
  );
  await tx.query(
    `INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload)
     VALUES ('order', $1, 'order.placed.v1', $2)`,
    [order.id, { orderId: order.id, customerId, totalMinor }],
  );
});
```

Relay (polling; multiple relay instances safe thanks to `SKIP LOCKED`):

```ts
export async function relayOnce(batchSize = 100): Promise<number> {
  return db.tx(async (tx) => {
    const { rows } = await tx.query(
      `SELECT id, event_id, aggregate_id, event_type, payload, headers
         FROM outbox
        WHERE published_at IS NULL
        ORDER BY id
        LIMIT $1
        FOR UPDATE SKIP LOCKED`,
      [batchSize],
    );
    if (rows.length === 0) return 0;

    // Publish with key = aggregate_id so events for the same order keep partition ordering.
    await producer.send({
      topic: 'orders',
      messages: rows.map((r) => ({
        key: r.aggregate_id,
        value: JSON.stringify(r.payload),
        headers: { ...r.headers, 'event-id': r.event_id, 'event-type': r.event_type },
      })),
    });

    await tx.query(`UPDATE outbox SET published_at = now() WHERE id = ANY($1)`, [rows.map((r) => r.id)]);
    return rows.length;
  });
}
```

If the relay crashes after `producer.send` but before the `UPDATE` commits, the rows are republished. **That's intended** — the consumer inbox handles it. Alternatives to polling: logical replication / CDC (Debezium) reading the outbox table from the WAL.

Operational notes:
- Alert on `max(now() - created_at) WHERE published_at IS NULL` (outbox lag).
- Delete or partition published rows (e.g. drop partitions older than 7 days).
- Use `ORDER BY id` plus a single relay per partition key range if strict per-aggregate ordering matters.

### How — inbox (consumer dedup)

```sql
CREATE TABLE inbox (
  consumer     text        NOT NULL,       -- e.g. 'email-service.order-confirmation'
  event_id     uuid        NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (consumer, event_id)
);
```

```ts
export async function handleOrderPlaced(msg: KafkaMessage) {
  const eventId = msg.headers['event-id'].toString();
  const event = OrderPlacedV1.parse(JSON.parse(msg.value.toString()));

  await db.tx(async (tx) => {
    const inserted = await tx.query(
      `INSERT INTO inbox (consumer, event_id) VALUES ('loyalty.order-placed', $1)
       ON CONFLICT DO NOTHING RETURNING event_id`,
      [eventId],
    );
    if (inserted.rowCount === 0) {
      metrics.inboxDuplicate.inc({ consumer: 'loyalty.order-placed' });
      return; // already processed
    }
    await tx.query(
      `INSERT INTO loyalty_points (customer_id, order_id, points) VALUES ($1, $2, $3)`,
      [event.customerId, event.orderId, Math.floor(event.totalMinor / 100)],
    );
  });
  // Commit offset only after the transaction commits.
}
```

When the side effect is **not** in your database (sending an email), the inbox can't be atomic with it. Options: record the send intent in your DB (outbox again) and use the email provider's idempotency key; or accept rare duplicates for low-stakes effects and document that decision.

### Expert Mental Model

> "The database commit is my single source of truth for 'did this happen'. Everything else — brokers, emails, webhooks — is derived from committed state, delivered at least once, and consumed idempotently."

### Common Mistake

- Publishing to the broker inside the DB transaction ("it's fine, it's quick").
- Using the broker's "exactly-once" feature and believing side effects in *other* systems are now exactly-once. Kafka EOS covers Kafka-to-Kafka; your Postgres write and your email are outside it.
- Dedup via an in-memory LRU set — lost on restart, not shared across replicas.

---

## 7. Timeouts and Deadline Propagation

### What

A **timeout** bounds how long one operation may take. A **deadline** is an absolute point in time by which the whole request must finish; it is propagated to every downstream call so each gets only the **remaining** budget.

### Why

Without timeouts, a slow dependency converts into resource exhaustion (threads, connections, memory, event-loop tasks) and cascades. Without deadline propagation, timeouts at different layers don't compose: if the edge gives up after 10s but the backend calls a service with its own 30s timeout, the backend keeps working for 20s on a request nobody is waiting for — "zombie work" that amplifies overload.

### How

1. Set a request deadline at the edge (e.g. API gateway 10s, or per-route SLO-based).
2. Propagate it (header like `X-Request-Deadline: <epoch ms>` or gRPC's native deadline).
3. Every I/O call uses `min(localTimeout, deadline - now - safetyMargin)`.
4. Check the deadline before starting expensive work; fail fast if already expired.
5. Configure timeouts at **every** layer: connect, TLS, request, idle, pool acquisition, DB statement, lock wait.
6. Choose values from **measured latency** (e.g. timeout ≈ p99.9 of healthy latency × ~1.5–2), not round numbers.
7. Order: inner timeouts must be **shorter** than outer ones.

```text
Browser/edge:   15s
Load balancer:  12s
App request:    10s  (deadline set here)
  → DB statement:  min(3s, remaining)
  → Payment API:   min(8s, remaining)
  → Recommendations (optional): min(300ms, remaining)
```

### Example — TypeScript deadline utility

```ts
export class Deadline {
  private constructor(readonly at: number) {}

  static fromNow(ms: number) { return new Deadline(Date.now() + ms); }

  static fromHeader(value: string | undefined, fallbackMs: number, maxMs: number) {
    const parsed = Number(value);
    const now = Date.now();
    // Never trust a caller to grant more than our own maximum.
    if (!Number.isFinite(parsed)) return new Deadline(now + fallbackMs);
    return new Deadline(Math.min(parsed, now + maxMs));
  }

  remaining() { return Math.max(0, this.at - Date.now()); }
  expired() { return this.remaining() === 0; }

  /** Budget for a sub-call: capped by a local timeout and leaving margin for our own work. */
  budget(localTimeoutMs: number, marginMs = 50) {
    return Math.max(0, Math.min(localTimeoutMs, this.remaining() - marginMs));
  }

  signal(localTimeoutMs: number) {
    const ms = this.budget(localTimeoutMs);
    if (ms === 0) throw new DeadlineExceededError();
    return AbortSignal.timeout(ms);
  }

  toHeader() { return String(this.at); }
}
```

Using it:

```ts
app.use((req, _res, next) => {
  req.deadline = Deadline.fromHeader(req.header('x-request-deadline'), 10_000, 10_000);
  next();
});

app.post('/checkout', async (req, res) => {
  const d = req.deadline;

  const cart = await db.query({
    text: 'SELECT ... FROM carts WHERE id = $1',
    values: [req.body.cartId],
    // pg supports per-query timeout via statement_timeout on the connection or query_timeout in config
  });

  const tax = await fetch(TAX_URL, {
    method: 'POST',
    headers: { 'x-request-deadline': d.toHeader() },
    body: JSON.stringify(cart),
    signal: d.signal(2_000),
  });

  if (d.expired()) return res.status(503).json({ error: 'deadline exceeded' });
  // ...
});
```

Per-query DB timeouts with `pg`:

```ts
export async function queryWithDeadline<T>(d: Deadline, text: string, values: unknown[], maxMs = 3000) {
  const client = await pool.connect();                 // pool configured with connectionTimeoutMillis
  try {
    const ms = d.budget(maxMs);
    if (ms === 0) throw new DeadlineExceededError();
    await client.query(`SET statement_timeout = ${Math.floor(ms)}`);
    return (await client.query<T>(text, values)).rows;
  } finally {
    await client.query('RESET statement_timeout').catch(() => {});
    client.release();
  }
}
```

(In a transaction, prefer `SET LOCAL statement_timeout` so it resets automatically at commit.)

### Expert Mental Model

> "Time is a resource with a budget. Every hop spends from the same budget. When the budget is gone, all work for that request should stop everywhere."

### Common Mistake

- No timeout at all (Node `fetch` and many SDKs default to none or to minutes).
- Only a request timeout, no connect timeout or pool acquisition timeout.
- Inner timeout longer than outer (`LB 30s`, `service→DB 60s`).
- Treating a timeout on a **write** as "failed" and not resolving the unknown outcome.

---

## 8. Retries: Backoff, Jitter, Budgets — and When Retries Kill You

### What

A retry re-attempts a failed operation hoping the failure was transient. **Exponential backoff** increases wait time between attempts; **jitter** randomizes it so clients don't synchronize; a **retry budget** caps retries as a fraction of total traffic so retries can't multiply load during an outage.

### Why

Retries convert transient failures (a single dropped connection, a failover blip) into successes. But retries are also **load amplifiers**. If each of 4 layers retries 3 times, a single failing leaf call becomes up to `4^4 = 256` attempts (with 1 original + 3 retries per layer). During an outage caused by overload, retries make overload worse and delay recovery.

### How — what to retry

| Retry? | Condition |
|---|---|
| Yes | Connection refused/reset before request sent; DNS temporary failure; 503 with `Retry-After`; 429 (respect `Retry-After`); PG `40001`/`40P01`; timeouts **on idempotent operations** |
| Only with idempotency key | Timeouts/5xx on non-idempotent writes (POST payment) |
| No | 400, 401, 403, 404, 409 (business conflict), 422; validation errors; `23505` unique violation (it's an answer, not a glitch); deadline already expired |

### How — backoff with full jitter

```text
sleep = random_between(0, min(cap, base * 2^attempt))
```

"Full jitter" (from the AWS Architecture Blog analysis) spreads retries best and typically minimizes total work under contention.

```ts
export interface RetryOptions {
  maxAttempts: number;          // total attempts including the first
  baseMs: number;
  capMs: number;
  retryOn: (err: unknown) => boolean;
  deadline?: Deadline;
  budget?: RetryBudget;
  onRetry?: (err: unknown, attempt: number, delayMs: number) => void;
}

export async function withRetry<T>(fn: (attempt: number) => Promise<T>, opts: RetryOptions): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt < opts.maxAttempts; attempt++) {
    try {
      const result = await fn(attempt);
      opts.budget?.recordSuccess();
      return result;
    } catch (err) {
      lastErr = err;
      const isLast = attempt === opts.maxAttempts - 1;
      if (isLast || !opts.retryOn(err)) throw err;
      if (opts.budget && !opts.budget.tryAcquireRetry()) throw err;       // budget exhausted: fail fast

      const retryAfterMs = getRetryAfterMs(err);
      const backoff = Math.random() * Math.min(opts.capMs, opts.baseMs * 2 ** attempt);
      const delay = Math.max(backoff, retryAfterMs ?? 0);

      if (opts.deadline && opts.deadline.remaining() <= delay) throw err; // no time left to retry usefully
      opts.onRetry?.(err, attempt + 1, delay);
      await sleep(delay);
    }
  }
  throw lastErr;
}
```

### How — retry budget (token bucket)

A retry budget allows retries up to, say, 10% of requests plus a small minimum rate. Pattern used by Finagle, Envoy (`retry_budget`), and gRPC retry throttling.

```ts
export class RetryBudget {
  private tokens: number;
  constructor(
    private readonly maxTokens = 100,
    private readonly retryCost = 10,      // each retry costs 10 tokens
    private readonly successReward = 1,   // each success earns 1 token → ~10% retry ratio
  ) { this.tokens = maxTokens; }

  recordSuccess() { this.tokens = Math.min(this.maxTokens, this.tokens + this.successReward); }

  tryAcquireRetry(): boolean {
    if (this.tokens < this.retryCost) return false;
    this.tokens -= this.retryCost;
    return true;
  }
}

// One budget per dependency, per process
export const budgets = { payments: new RetryBudget(), tax: new RetryBudget(), search: new RetryBudget() };
```

When the dependency is healthy, occasional failures get retried. When it's failing broadly, the budget drains and the client stops amplifying load.

### Where to retry

**Retry at one layer**, ideally the one closest to the failure that has enough context to know it's safe. Typical choice:

```text
Browser        → no automatic retry for writes (show "try again" with same idempotency key)
Edge / LB      → retry only connection failures on idempotent methods
Service A      → retry dependency calls with budget + jitter
Service B      → no retries of its own dependencies' failures upward; return 503 quickly
Queue consumer → queue-level redelivery with backoff; handler itself doesn't loop
```

### When retries make outages worse

1. **Overload failures.** If a dependency fails because it's saturated, retries add load. Budgets + circuit breakers.
2. **Synchronized retries (thundering herd).** Fixed delays cause waves. Jitter.
3. **Multi-layer retries.** Multiplicative amplification. Retry at one layer.
4. **Retrying non-idempotent writes.** Duplicates. Idempotency keys.
5. **Retrying after the deadline.** Zombie work. Deadline checks.
6. **Retrying deterministic failures.** Poison messages loop forever. Classify errors; DLQ.
7. **Long retry chains in the request path.** A 3-attempt retry with 5s timeouts turns a 5s timeout into 15s+ of held resources. Budget time, not just attempts.

### Expert Mental Model

> "A retry is a bet that the failure is transient and that my extra load won't make it worse. I only place that bet when the operation is safe to repeat, when there's time left, and when the system as a whole isn't already failing."

### Common Mistake

```ts
// Retries everything, forever-ish, in lockstep, with no idempotency
for (let i = 0; i < 5; i++) {
  try { return await createOrder(input); } catch { await sleep(1000); }
}
```

---

## 9. Circuit Breakers

### What

A circuit breaker wraps calls to a dependency and tracks failures. When failures exceed a threshold, it **opens** and fails calls immediately without contacting the dependency. After a cool-down it goes **half-open** and lets a few trial calls through; success **closes** it, failure reopens it.

```text
            failure rate > threshold (within window, min requests met)
   ┌────────┐ ─────────────────────────────────────────────▶ ┌────────┐
   │ CLOSED │                                                 │  OPEN  │
   └────────┘ ◀──────────┐                          ┌──────── └────────┘
        ▲                │ trial calls succeed      │ cool-down elapsed
        │                │                          ▼
        │            ┌───────────┐  trial call fails
        └────────────│ HALF-OPEN │ ──────────────────▶ back to OPEN
                     └───────────┘
```

### Why

- **Protects the caller:** fail in 1ms instead of waiting for a 2s timeout on every request, freeing threads/connections/event-loop time.
- **Protects the dependency:** gives it room to recover rather than being hammered.
- **Enables fallbacks:** an open breaker is a clear signal to degrade gracefully.

### How

Key parameters and sensible starting points:

| Parameter | Typical value | Why |
|---|---|---|
| Rolling window | 10–30s | Responsive but not noisy |
| Minimum request volume | 20 requests in window | Avoid opening on 1 of 2 failures at low traffic |
| Failure rate threshold | 50% | Clear signal of dependency trouble |
| Slow-call threshold | Calls > p99 healthy latency count as failures | Slowness is failure too |
| Open duration | 5–30s (with jitter) | Let dependency recover |
| Half-open trial calls | 1–5 | Probe carefully |

What counts as failure: timeouts, connection errors, 5xx, 429. **Not** 4xx business errors (a 404 means the dependency is working).

### Example — using `opossum` in Node

```ts
import CircuitBreaker from 'opossum';

async function fetchRecommendations(userId: string, signal: AbortSignal) {
  const res = await fetch(`${RECS_URL}/users/${userId}/recs`, { signal });
  if (res.status >= 500 || res.status === 429) throw new RetryableUpstreamError('recs', res.status);
  if (!res.ok) return [];                                  // 4xx: not a dependency failure
  return RecsResponse.parse(await res.json()).items;
}

export const recsBreaker = new CircuitBreaker(
  (userId: string) => fetchRecommendations(userId, AbortSignal.timeout(300)),
  {
    timeout: 400,                   // breaker-level timeout (belt and braces)
    errorThresholdPercentage: 50,
    rollingCountTimeout: 10_000,
    volumeThreshold: 20,
    resetTimeout: 15_000,
  },
);

recsBreaker.fallback(() => POPULAR_ITEMS_CACHE.get() ?? []);
recsBreaker.on('open', () => logger.warn({ dep: 'recs' }, 'circuit opened'));
recsBreaker.on('halfOpen', () => logger.info({ dep: 'recs' }, 'circuit half-open'));
recsBreaker.on('close', () => logger.info({ dep: 'recs' }, 'circuit closed'));

// usage
const recs = await recsBreaker.fire(userId);
```

### Example — minimal hand-rolled breaker (to understand the states)

```ts
type State = 'closed' | 'open' | 'half_open';

export class SimpleBreaker {
  private state: State = 'closed';
  private failures = 0;
  private successes = 0;
  private openedAt = 0;
  private halfOpenInFlight = 0;

  constructor(private cfg = { failureThreshold: 10, openMs: 15_000, halfOpenMax: 2 }) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.openedAt < this.cfg.openMs) throw new CircuitOpenError();
      this.state = 'half_open';
      this.halfOpenInFlight = 0;
    }
    if (this.state === 'half_open' && this.halfOpenInFlight >= this.cfg.halfOpenMax) throw new CircuitOpenError();

    if (this.state === 'half_open') this.halfOpenInFlight++;
    try {
      const out = await fn();
      this.onSuccess();
      return out;
    } catch (e) {
      this.onFailure();
      throw e;
    } finally {
      if (this.state === 'half_open') this.halfOpenInFlight--;
    }
  }

  private onSuccess() {
    if (this.state === 'half_open') { this.state = 'closed'; }
    this.failures = 0;
  }

  private onFailure() {
    this.failures++;
    if (this.state === 'half_open' || this.failures >= this.cfg.failureThreshold) {
      this.state = 'open';
      this.openedAt = Date.now();
    }
  }
}
```

(Production breakers use rolling windows with failure *rates*, not consecutive counts.)

### Expert Mental Model

> "If a dependency is clearly broken, the fastest and kindest thing to do is stop calling it and do the next best thing."

### Common Mistake

- Breaker around a **critical** dependency with no fallback, so "open" just means a faster error — sometimes right, but decide consciously.
- Counting 4xx as failures, opening the breaker because users typed bad input.
- One global breaker for a dependency that has independent partitions (e.g. per-region endpoints or per-tenant shards) — one bad shard blacks out all.
- Breaker state not exported as a metric, so nobody knows it's open.

---

## 10. Bulkheads

### What

Bulkheads isolate resources so failure or saturation in one area can't sink the whole system — named after ship compartments. Concretely: **separate pools, concurrency limits, queues, or deployments per dependency, per workload type, or per tenant tier.**

### Why

Shared resources couple failure domains. If the slow reporting endpoint and the checkout endpoint share one DB pool of 20 connections, 20 slow report queries block every checkout.

### How

| Resource | Bulkhead technique |
|---|---|
| Connection pool | Separate pools per workload (`web`, `reports`, `jobs`) with separate DB roles and `statement_timeout`s |
| Outbound calls | Per-dependency concurrency limiter (semaphore) |
| Workers | Separate queues and worker deployments for critical vs bulk jobs |
| Tenants | Per-tenant rate limits and concurrency; noisy tenants on dedicated shards |
| Compute | Separate deployments for public API vs internal admin vs batch |
| Read vs write | Read replicas for analytics/reporting |

### Example — per-dependency concurrency limit

```ts
import pLimit from 'p-limit';

const limits = {
  payments: pLimit(50),
  tax: pLimit(30),
  recommendations: pLimit(10),   // optional dep gets a small compartment
};

export async function callWithBulkhead<T>(dep: keyof typeof limits, fn: () => Promise<T>, maxQueue = 100) {
  const limit = limits[dep];
  if (limit.pendingCount >= maxQueue) {
    metrics.bulkheadRejected.inc({ dep });
    throw new BulkheadFullError(dep);          // reject rather than queue unboundedly
  }
  return limit(fn);
}
```

### Example — separate DB pools

```ts
export const webPool = new Pool({
  connectionString: process.env.DATABASE_URL_WEB,   // role app_web: statement_timeout 5s
  max: 15, connectionTimeoutMillis: 1000, idleTimeoutMillis: 10_000,
});
export const reportPool = new Pool({
  connectionString: process.env.DATABASE_URL_REPORTS, // role app_reports: replica, statement_timeout 60s
  max: 5, connectionTimeoutMillis: 5000,
});
```

### Expert Mental Model

> "Which things share a fate? If I don't want them to fail together, they must not share a finite resource."

### Common Mistake

Bulkheads that only exist in code while everything shares the same database primary, same Redis, same node pool. Look for the shared resource at the bottom of the stack.

---

## 11. Backpressure and Load Shedding

### What

- **Backpressure:** a downstream component signals upstream to slow down when it can't keep up (bounded buffers, `429`, stream `highWaterMark`, consumer pull rates).
- **Load shedding:** deliberately rejecting some work early when overloaded, so the work you accept succeeds within its deadline.

### Why

An overloaded system that accepts everything serves **no one** well: latency climbs past every client's timeout, so all work is wasted ("goodput" collapses to zero even though throughput is high). Rejecting 20% quickly lets 80% succeed.

```text
Without shedding:  1,200 req/s offered, capacity 1,000 → queues grow → p50 latency 12s → nearly all time out → goodput ≈ 0
With shedding:     1,200 req/s offered, shed 200 fast with 503 → p50 80ms → goodput ≈ 1,000
```

### How

1. **Bound every queue and buffer.** Unbounded queues are just delayed OOMs and delayed timeouts.
2. **Limit concurrency** at the entry point (in-flight request limit).
3. **Shed by priority:** health checks and payments before search suggestions; paying tenants before free tier; interactive before batch.
4. **Shed early and cheaply** — before parsing big bodies or hitting the DB.
5. **Reject stale work:** if a request's deadline has already passed or it has waited in queue longer than its budget, drop it.
6. **Signal properly:** `503 Service Unavailable` or `429 Too Many Requests` with `Retry-After`.
7. **Use adaptive concurrency limits** (e.g. gradient/AIMD algorithms like Netflix's `concurrency-limits`, Envoy adaptive concurrency) when load is unpredictable.

### Example — in-flight limit with priority (Node/Express)

```ts
const MAX_INFLIGHT = Number(process.env.MAX_INFLIGHT ?? 200);
let inflight = 0;

const PRIORITY: Record<string, number> = {
  '/healthz': 0,             // never shed
  '/api/checkout': 1,
  '/api/payments': 1,
  '/api/products': 2,
  '/api/search/suggest': 3,  // shed first
};

app.use((req, res, next) => {
  const priority = PRIORITY[req.path] ?? 2;
  const lagMs = eventLoopLag.p99();                    // from perf_hooks.monitorEventLoopDelay
  const pressure = Math.max(inflight / MAX_INFLIGHT, lagMs / 200);

  const shedThreshold = { 0: Infinity, 1: 1.0, 2: 0.85, 3: 0.6 }[priority]!;
  if (pressure >= shedThreshold) {
    metrics.shed.inc({ route: req.path, priority });
    res.setHeader('Retry-After', '1');
    return res.status(503).json({ error: 'overloaded' });
  }

  inflight++;
  res.on('close', () => { inflight--; });
  next();
});
```

### Example — stream backpressure (large export)

```ts
import { pipeline } from 'node:stream/promises';
import QueryStream from 'pg-query-stream';
import { stringify } from 'csv-stringify';

app.get('/exports/orders.csv', async (req, res) => {
  const client = await reportPool.connect();
  try {
    const query = new QueryStream('SELECT id, created_at, total_minor FROM orders WHERE tenant_id = $1', [req.auth.tenantId], { batchSize: 1000 });
    res.setHeader('Content-Type', 'text/csv');
    // pipeline respects backpressure: if the client reads slowly, the DB cursor pauses.
    await pipeline(client.query(query), stringify({ header: true }), res);
  } finally {
    client.release();
  }
});
```

### Example — queue consumer backpressure

```ts
// Pull-based: only fetch as many messages as you can process concurrently
const consumer = new Worker('emails', processEmail, {
  connection: redis,
  concurrency: 20,                          // never more than 20 in flight
  limiter: { max: 100, duration: 1000 },    // and never more than provider's 100/s rate limit
});
```

### Expert Mental Model

> "Capacity is finite. The only question is whether I choose which work to drop, or the system drops work randomly by timing everything out."

### Common Mistake

- Autoscaling as the only overload plan (scaling takes minutes; the spike takes seconds; and the DB doesn't autoscale).
- `await Promise.all(items.map(process))` over 100,000 items.
- Returning `500` for overload (clients treat it as a bug, not as "back off").

---

## 12. Queues, Dead-Letter Queues, and Redrive

### What

- **Queue:** durable buffer decoupling producers from consumers in time and rate.
- **Dead-letter queue (DLQ):** where messages go after exceeding max delivery attempts, so they don't block or loop forever.
- **Redrive:** moving messages from the DLQ back to the main queue after the underlying problem is fixed.

### Why

Queues absorb spikes, isolate slow work from the request path, and enable retries without holding user connections. But queues introduce new failure modes: poison messages, unbounded backlog, stale messages, ordering issues, and invisible failures if no one watches the DLQ.

### How

Design checklist for every queue:

| Question | Typical answer |
|---|---|
| Delivery semantics? | At-least-once → idempotent consumer (inbox) |
| Visibility timeout / ack deadline? | > p99.9 processing time (e.g. 6× average), extended for long jobs |
| Max receive count before DLQ? | 3–10 depending on transient-failure likelihood |
| Backoff between attempts? | Exponential with jitter (SQS: change visibility; BullMQ: `backoff`) |
| Ordering required? | Usually per-entity only (FIFO message group / Kafka key) |
| Message TTL / staleness? | Drop or divert notifications older than their usefulness |
| Payload size? | Small; store large payloads in object storage and pass a reference |
| Schema versioning? | `event_type.v1`, consumers tolerate unknown fields |
| Alerting? | Queue age of oldest message, DLQ depth > 0, consumer error rate |
| Redrive process? | Runbook + tooling, with fix deployed first |

Classify errors in the consumer:

```ts
export async function processMessage(msg: Message) {
  try {
    await handle(msg);
  } catch (err) {
    if (err instanceof ValidationError || err instanceof UnknownEventTypeError) {
      // Deterministic: retrying won't help. Send straight to DLQ with reason.
      await dlq.send({ ...msg, headers: { ...msg.headers, 'x-dlq-reason': err.message } });
      return ack(msg);
    }
    // Transient: let the queue redeliver with backoff.
    throw err;
  }
}
```

### Example — AWS SQS with redrive policy (Terraform)

```hcl
resource "aws_sqs_queue" "order_events_dlq" {
  name                      = "order-events-dlq"
  message_retention_seconds = 1209600 # 14 days: enough time to notice and fix
}

resource "aws_sqs_queue" "order_events" {
  name                       = "order-events"
  visibility_timeout_seconds = 180     # > 6x typical processing time
  message_retention_seconds  = 345600  # 4 days
  receive_wait_time_seconds  = 20      # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_events_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq_allow" {
  queue_url = aws_sqs_queue.order_events_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.order_events.arn]
  })
}

resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "order-events-dlq-not-empty"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.order_events_dlq.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [var.oncall_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "queue_age" {
  alarm_name          = "order-events-oldest-message-age"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = aws_sqs_queue.order_events.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 600 # 10 minutes behind
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [var.oncall_sns_topic_arn]
}
```

### Example — BullMQ (Redis) job options

```ts
await ordersQueue.add('send-confirmation', { orderId }, {
  jobId: `send-confirmation:${orderId}`,   // dedup at enqueue time
  attempts: 6,
  backoff: { type: 'exponential', delay: 2000 },
  removeOnComplete: { age: 86_400, count: 10_000 },
  removeOnFail: false,                     // keep failed jobs as the "DLQ" for inspection/retry
});
```

### Redrive runbook (abbreviated)

```text
1. Inspect DLQ: sample 20 messages; group by x-dlq-reason / error signature.
2. Identify root cause; ship the fix (or confirm the dependency recovered).
3. Verify consumers are idempotent for these message types (inbox in place).
4. Redrive a small batch (e.g. 10) → watch error rate and business metrics.
5. Redrive the rest at a controlled rate (SQS StartMessageMoveTask with MaxNumberOfMessagesPerSecond).
6. Messages that are permanently invalid: archive to object storage with reason; do not delete silently.
7. Record in the incident/postmortem doc.
```

See [templates/runbook.md](templates/runbook.md).

### Expert Mental Model

> "A queue doesn't make work reliable; it makes work *deferred*. Reliability comes from idempotent consumers, bounded retries, a watched DLQ, and a practiced redrive."

### Common Mistake

- DLQ exists but has no alarm — discovered months later with 80,000 messages.
- Visibility timeout shorter than processing time → every long job processed twice concurrently.
- Blindly redriving before fixing the cause → messages bounce straight back.
- Treating the queue as a database (querying it, relying on it for state).

---

## 13. Graceful Degradation

### What

Graceful degradation means the system **keeps delivering its most important function** when parts fail, with reduced features or freshness, rather than failing completely.

### Why

Users tolerate "reviews are temporarily unavailable" far better than a blank page. Revenue-critical paths should not depend on non-critical features.

### How

1. **Classify features/dependencies** by criticality per user journey.
2. **Define the degraded behavior in advance** for each (product decision, not an engineering improvisation during an incident).
3. **Implement fallbacks:** stale cache, static defaults, queue for later, reduced functionality, read-only mode.
4. **Make degraded mode visible** in metrics and, when appropriate, to the user.
5. **Test degraded modes** (fault injection, game days).

Degradation matrix example (e-commerce):

| Dependency down | Product page | Cart | Checkout | Degraded behavior |
|---|---|---|---|---|
| Recommendations | Works | Works | Works | Hide carousel / show cached "popular items" |
| Reviews | Works | — | — | Show cached average rating, hide review list |
| Search | Browse by category only | Works | Works | Show category nav + "search is having trouble" |
| Inventory service | Show "availability updating" | Works | Re-check at payment; if still down, allow order with backorder flag under threshold value | |
| Tax API | — | Estimated tax | **Blocked** or use cached rate table with post-hoc reconciliation (business decision, legal review) | |
| Payment provider A | — | — | Fail over to provider B | |
| Email provider | — | — | Order succeeds; email queued | |
| Primary DB | Read-only mode from replica + CDN cache | Local storage cart | **Unavailable** — honest error page | |

### Example — Next.js App Router: isolate optional sections

```tsx
// app/products/[slug]/page.tsx
import { Suspense } from 'react';
import { ErrorBoundary } from 'react-error-boundary'; // client wrapper component
import { getProduct } from '@/server/products';
import { Recommendations } from './recommendations';
import { Reviews } from './reviews';

export default async function ProductPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const product = await getProduct(slug);           // critical: if this fails, error.tsx renders
  return (
    <>
      <ProductDetails product={product} />
      <Suspense fallback={<ReviewsSkeleton />}>
        <Reviews productId={product.id} />           {/* streams in; never blocks the main content */}
      </Suspense>
      <Suspense fallback={null}>
        <Recommendations productId={product.id} />
      </Suspense>
    </>
  );
}
```

```tsx
// app/products/[slug]/recommendations.tsx (server component)
export async function Recommendations({ productId }: { productId: string }) {
  try {
    const items = await recsBreaker.fire(productId);   // 300ms timeout + breaker + cached fallback
    if (items.length === 0) return null;
    return <RecommendationCarousel items={items} />;
  } catch (err) {
    logger.warn({ err, productId }, 'recommendations degraded');
    return null;                                        // degrade silently: optional feature
  }
}
```

### Example — read-only mode flag

```ts
// middleware for mutating routes
if (flags.isEnabled('read_only_mode') && req.method !== 'GET') {
  return res.status(503).json({
    error: 'maintenance',
    message: 'We are performing maintenance. Browsing works; changes are temporarily disabled.',
  });
}
```

### Expert Mental Model

> "For each user journey: what is the one thing that must work, and what can quietly disappear?"

### Common Mistake

- Fallbacks that silently produce **wrong** data (tax = 0, price = cached from last month without bounds) — degradation must never violate invariants.
- Fallback code paths that have never executed in production and are broken when needed.
- Making every dependency "critical" by fetching everything in one `Promise.all` that rejects if any fails.

---

## 14. Sagas and Compensation

### What

A **saga** is a sequence of local transactions across multiple services or systems, where each step has a **compensating action** that semantically undoes it if a later step fails. Two styles:

- **Orchestration:** a central coordinator (state machine) tells each participant what to do.
- **Choreography:** participants react to each other's events.

### Why

You can't have an ACID transaction spanning your DB, Stripe, a warehouse API, and a shipping carrier. Two-phase commit across these is unavailable or impractical. Sagas give you **eventual** atomicity: either all steps complete, or completed steps are compensated.

### How

1. List the steps and, for each: action, compensation, idempotency key, retryability, timeout.
2. Order steps so that **hard-to-compensate steps come last** (e.g. authorize payment early but capture late; ship last).
3. Prefer **reservations** (authorize, reserve, hold) that expire over irreversible actions.
4. Persist saga state durably; every transition is a DB transaction + outbox message.
5. Compensations must be idempotent and retried until they succeed (or escalate to a human).
6. Accept that intermediate states are visible (`pending`), and design UI/API for them.

Order fulfillment saga (orchestrated):

| # | Step | Action | Compensation | Notes |
|---|---|---|---|---|
| 1 | Create order | `orders.status = 'pending'` | `status = 'cancelled'` | Local tx |
| 2 | Reserve inventory | WMS `POST /reservations` (idem key `res:<orderId>`) | `DELETE /reservations/<id>` | Reservation auto-expires in 30 min |
| 3 | Authorize payment | PSP authorize (idem key `auth:<orderId>`) | Void authorization | Auth expires in ~7 days |
| 4 | Confirm order | `status = 'confirmed'`, outbox `order.confirmed` | — | Point of no return for customer |
| 5 | Capture payment | PSP capture (idem key `cap:<orderId>`) | Refund | Done at shipment |
| 6 | Create shipment | Carrier label | Void label (if allowed) | |

### Example — orchestrator state machine

```ts
type SagaState =
  | 'started' | 'inventory_reserved' | 'payment_authorized' | 'confirmed'
  | 'compensating' | 'cancelled' | 'failed_needs_attention';

interface SagaRow { id: string; order_id: string; state: SagaState; data: Record<string, string>; version: number }

export async function advance(sagaId: string) {
  const saga = await loadSaga(sagaId);
  try {
    switch (saga.state) {
      case 'started': {
        const r = await wms.reserve({ orderId: saga.order_id, items: saga.data.items }, { idempotencyKey: `res:${saga.order_id}` });
        return transition(saga, 'inventory_reserved', { reservationId: r.id });
      }
      case 'inventory_reserved': {
        const a = await psp.authorize({ orderId: saga.order_id, amountMinor: Number(saga.data.amountMinor) }, { idempotencyKey: `auth:${saga.order_id}` });
        if (a.status === 'declined') return transition(saga, 'compensating', { reason: 'payment_declined' });
        return transition(saga, 'payment_authorized', { authorizationId: a.id });
      }
      case 'payment_authorized':
        return transition(saga, 'confirmed', {}, { outboxEvent: 'order.confirmed.v1' });
      case 'compensating':
        if (saga.data.authorizationId) await psp.void(saga.data.authorizationId, { idempotencyKey: `void:${saga.order_id}` });
        if (saga.data.reservationId) await wms.release(saga.data.reservationId, { idempotencyKey: `rel:${saga.order_id}` });
        return transition(saga, 'cancelled', {}, { outboxEvent: 'order.cancelled.v1' });
    }
  } catch (err) {
    if (isRetryable(err)) throw err;                   // job queue retries with backoff
    if (saga.state === 'compensating') return transition(saga, 'failed_needs_attention', { error: String(err) });
    return transition(saga, 'compensating', { reason: String(err) });
  }
}

async function transition(saga: SagaRow, to: SagaState, patch: Record<string, string>, opts?: { outboxEvent?: string }) {
  await db.tx(async (tx) => {
    const r = await tx.query(
      `UPDATE sagas SET state = $1, data = data || $2::jsonb, version = version + 1, updated_at = now()
        WHERE id = $3 AND version = $4`,                      // optimistic concurrency: no double-advance
      [to, patch, saga.id, saga.version],
    );
    if (r.rowCount !== 1) throw new ConcurrentModificationError();
    await tx.query(`INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload) VALUES ('saga', $1, 'saga.advance', $2)`,
      [saga.id, { sagaId: saga.id }]);
    if (opts?.outboxEvent) {
      await tx.query(`INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload) VALUES ('order', $1, $2, $3)`,
        [saga.order_id, opts.outboxEvent, { orderId: saga.order_id }]);
    }
  });
}
```

Plus a **stuck-saga detector**: `SELECT * FROM sagas WHERE state NOT IN ('confirmed','cancelled') AND updated_at < now() - interval '30 minutes'` → alert and re-enqueue.

### Expert Mental Model

> "In a distributed workflow I don't prevent inconsistency; I bound it in time, make every intermediate state explicit and legal, and guarantee that every path ends in a terminal state — automatically or via a human."

### Common Mistake

- Compensations that aren't idempotent or aren't retried (so a failed refund is lost).
- Irreversible steps first (capture payment, then discover no stock).
- Choreography across 7 services with no single place to see a flow's state — debugging requires reading four logs.
- No `failed_needs_attention` terminal state and no human workflow for it.

---

## 15. Deployments as a Failure Source: Zero-Downtime and Expand/Contract

### What

Deployments are the **single most common trigger of incidents** in most organizations (Google SRE literature and many public postmortems attribute a large share of outages to changes). Zero-downtime deployment means releasing new versions without dropping requests or breaking compatibility, using rolling/blue-green/canary strategies and **backward-compatible** schema and API changes.

### Why

During any non-atomic rollout, **old and new code run simultaneously** against **the same database** and **the same message formats**. Any change that isn't compatible in both directions breaks something for the duration of the rollout — and makes rollback unsafe.

### How — deployment mechanics checklist

- Readiness probe only passes when the app can serve (warm caches, DB reachable) — but **liveness must not depend on dependencies** (or a DB blip restarts every pod).
- Graceful shutdown: handle `SIGTERM`, stop accepting, drain, exit; `preStop` sleep to let the load balancer deregister.
- `maxUnavailable: 0`, `maxSurge: 25%` for rolling updates.
- Canary: 1–5% traffic for N minutes with automated SLO comparison before proceeding.
- Deploy markers in dashboards; automatic rollback on error-budget burn.
- Migrations run as a separate step, **before** the code that needs them, and are **backward compatible with the currently running code**.

```yaml
# Kubernetes Deployment excerpt
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxUnavailable: 0, maxSurge: 25% }
  template:
    spec:
      terminationGracePeriodSeconds: 40
      containers:
        - name: api
          readinessProbe:
            httpGet: { path: /readyz, port: 3000 }
            periodSeconds: 5
            failureThreshold: 2
          livenessProbe:
            httpGet: { path: /livez, port: 3000 }   # process-only check, no DB
            periodSeconds: 10
            failureThreshold: 3
          lifecycle:
            preStop:
              exec: { command: ["sh", "-c", "sleep 10"] }   # allow endpoints to deregister
```

### How — expand/contract (parallel change) migrations

Example: rename `users.name` → split into `users.first_name` / `users.last_name`. Each numbered step is a **separate deploy**.

```text
Step 1  EXPAND schema     Add nullable first_name, last_name.                     Old code: unaffected.
Step 2  DUAL WRITE        New code writes name AND first/last; reads name.        Rollback to step 1 code: safe.
Step 3  BACKFILL          Batch job fills first/last from name for old rows.      Idempotent, throttled.
Step 4  SWITCH READS      Code reads first/last (fallback to name if null).       Rollback: safe (still dual-writing).
Step 5  STOP OLD WRITES   Code stops writing name. Verify no readers remain.      Rollback to step 4: requires name to be written… so wait a full release cycle first.
Step 6  CONTRACT          Drop column name (after confirming via query logs/pg_stat_statements).
```

SQL for the dangerous parts done safely in PostgreSQL:

```sql
-- Step 1: adding a nullable column without a volatile default is metadata-only (fast)
ALTER TABLE users ADD COLUMN first_name text, ADD COLUMN last_name text;

-- Always protect DDL from waiting behind long transactions and blocking everyone else
SET lock_timeout = '3s';

-- Adding NOT NULL safely on a big table: use a NOT VALID check, validate separately
ALTER TABLE users ADD CONSTRAINT users_first_name_not_null CHECK (first_name IS NOT NULL) NOT VALID;
ALTER TABLE users VALIDATE CONSTRAINT users_first_name_not_null;   -- takes a weaker lock (SHARE UPDATE EXCLUSIVE)
-- (PG12+ can then use SET NOT NULL, which skips the scan when a valid CHECK exists)
ALTER TABLE users ALTER COLUMN first_name SET NOT NULL;
ALTER TABLE users DROP CONSTRAINT users_first_name_not_null;

-- Indexes on big tables: never block writes
CREATE INDEX CONCURRENTLY users_last_name_idx ON users (last_name);

-- Foreign keys on big tables
ALTER TABLE orders ADD CONSTRAINT orders_user_fk FOREIGN KEY (user_id) REFERENCES users(id) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT orders_user_fk;
```

Backfill in batches:

```sql
-- Run repeatedly until 0 rows updated; sleep between batches; monitor replication lag
WITH batch AS (
  SELECT id FROM users
   WHERE first_name IS NULL AND name IS NOT NULL
   ORDER BY id
   LIMIT 5000
   FOR UPDATE SKIP LOCKED
)
UPDATE users u
   SET first_name = split_part(u.name, ' ', 1),
       last_name  = NULLIF(substr(u.name, length(split_part(u.name, ' ', 1)) + 2), '')
  FROM batch
 WHERE u.id = batch.id;
```

Migration lint in CI (e.g. `squawk` for PostgreSQL):

```yaml
- name: Lint migrations
  run: npx squawk-cli migrations/*.sql
  # flags: adding NOT NULL without default, CREATE INDEX without CONCURRENTLY,
  # changing column types, renaming columns, missing lock_timeout, etc.
```

The same principle applies to **APIs and events**: add fields before using them; consumers ignore unknown fields; never change a field's meaning; version (`order.placed.v2`) for breaking changes and publish both during transition.

### Expert Mental Model

> "Every deploy is a period where two versions of my system coexist. Every change must be safe for the old version, the new version, and a rollback."

### Common Mistake

- Migration and code change in one deploy that isn't backward compatible.
- `CREATE INDEX` (non-concurrent) on a 200M-row table during business hours → writes blocked for 20 minutes.
- Rollback plan = "revert the commit" when the migration already dropped a column.
- Friday-afternoon deploys with no canary and no one watching.

---

## 16. Feature Flags and Rollbacks

### What

- **Feature flag:** a runtime switch that separates **deploying** code from **releasing** behavior.
- **Rollback:** returning to a previous known-good state — of code (redeploy previous artifact), config (revert flag), or data (restore / repair).
- **Roll forward:** shipping a fix instead of reverting, when rollback is unsafe or slower.

### Why

Rolling back a binary takes minutes and may be blocked by migrations; flipping a flag takes seconds. Flags also enable progressive exposure (internal users → 1% → 10% → 100%), which turns a potential full outage into a small, detectable one.

### How

Flag types and lifecycle:

| Type | Purpose | Lifetime | Example |
|---|---|---|---|
| Release flag | Hide incomplete/new feature | Days–weeks, then delete | `new_checkout_flow` |
| Ops / kill switch | Disable expensive or risky behavior under incident | Permanent | `disable_recommendations`, `read_only_mode` |
| Experiment | A/B test | Weeks | `pricing_page_variant` |
| Permission / entitlement | Plan-based access | Permanent (but belongs in authz, not flags) | `plan_has_sso` |

Rules:
- Flags are evaluated **server-side** for anything security- or money-relevant.
- Every release flag has an owner and a removal ticket; CI warns on flags older than N days.
- Kill switches are **tested** (flip them in staging regularly).
- The flag service itself can fail: define a **safe default** in code for each flag when the flag provider is unreachable.
- Log flag evaluations (or at least flag state changes) so incidents can correlate "what changed".

```ts
// Safe defaults when the flag service is down
const DEFAULTS = {
  new_checkout_flow: false,         // new feature: default off
  disable_recommendations: false,   // kill switch: default "feature on"
  read_only_mode: false,
} as const;

export async function flag<K extends keyof typeof DEFAULTS>(key: K, ctx: { tenantId: string; userId?: string }) {
  try {
    return await flagClient.boolVariation(key, ctx, DEFAULTS[key], { timeoutMs: 50 });
  } catch {
    metrics.flagFallback.inc({ key });
    return DEFAULTS[key];
  }
}
```

Progressive rollout with automated guardrail:

```text
Stage       Exposure   Duration   Guardrail (auto-revert if breached)
internal    staff      1 day      error rate, manual QA
canary      1%         1 hour     checkout success rate within -0.5% of control; p95 latency +10% max
early       10%        1 day      same + payment decline rate
general     50%→100%   2 days     same
cleanup     remove flag and old code path within 2 weeks
```

Rollback decision tree:

```text
Incident correlated with a change?
├─ Change behind a flag → flip flag off (seconds). Done; investigate calmly.
├─ Code deploy, no incompatible migration → roll back to previous artifact.
├─ Code deploy with expand-only migration → roll back code; leave schema (it's backward compatible).
├─ Destructive migration or data already written in new format → ROLL FORWARD with fix;
│   if data damaged → repair script or PITR to side database + targeted restore.
└─ Config change (env var, infra) → revert via IaC (git revert + apply), not console clicks.
```

### Expert Mental Model

> "Every risky change should have an 'off' switch that is faster than the damage it can cause."

### Common Mistake

- Flags that never get removed → combinatorial explosion of untested code paths (Knight Capital's 2012 $440M loss involved repurposing an old flag that reactivated dead code on one server that missed a deploy).
- Client-side-only flags guarding server behavior.
- Rollback never practiced → the artifact for the previous version was garbage-collected, or the deploy pipeline can only go forward.

---

## 17. Backups, Verified Restores, RTO and RPO

### What

- **Backup:** a copy of data from which you *might* be able to restore.
- **Verified restore:** a backup you have *actually restored* recently, measured, and checked for correctness. Only this counts.
- **RPO (Recovery Point Objective):** maximum acceptable data loss, measured in time ("we can lose at most 5 minutes of writes").
- **RTO (Recovery Time Objective):** maximum acceptable time to restore service ("back within 1 hour").

### Why

Replication is not backup: a `DELETE FROM orders` without `WHERE` replicates to every replica in milliseconds. Ransomware, a compromised credential, a buggy migration, or a cloud-account deletion can destroy both primary and replicas. Untested backups routinely fail when needed: wrong retention, missing WAL segments, encryption keys lost, restore takes 14 hours instead of 1.

### How

Define RPO/RTO **per data class**, driven by business impact:

| Data | RPO | RTO | Mechanism |
|---|---|---|---|
| Payments ledger, orders | ≤ 1 min | ≤ 1 h | Managed PG with PITR (continuous WAL archiving), cross-region replica, daily snapshot copied to separate account |
| User uploads (S3) | ≤ 15 min | ≤ 4 h | Versioning + Object Lock + cross-region replication |
| Analytics warehouse | 24 h | 24 h | Rebuild from source events |
| Cache (Redis) | N/A | Minutes | Rebuildable; no backup needed |
| Search index | N/A | Hours | Reindex from primary DB |

Backup principles:
- **3-2-1:** 3 copies, 2 different media/services, 1 offsite — plus **1 immutable/air-gapped** copy (separate cloud account, object lock, different credentials).
- **Point-in-time recovery (PITR)** for transactional databases: base backups + WAL archive (pgBackRest, WAL-G, or managed RDS/Cloud SQL/Neon PITR).
- **Encrypt** backups; store keys separately; ensure key access survives the loss of the primary account.
- **Restore drills** on a schedule, automated, with measured duration and data validation.

### Example — automated restore verification job (conceptual, AWS RDS)

```bash
#!/usr/bin/env bash
set -euo pipefail
# Runs weekly in CI/scheduler. Restores latest PITR to a temp instance, validates, records RTO, tears down.

START=$(date +%s)
RESTORE_ID="restore-verify-$(date +%Y%m%d%H%M)"

aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier prod-orders \
  --target-db-instance-identifier "$RESTORE_ID" \
  --use-latest-restorable-time \
  --db-instance-class db.r6g.large \
  --no-publicly-accessible \
  --db-subnet-group-name restore-verify-subnets

aws rds wait db-instance-available --db-instance-identifier "$RESTORE_ID"
HOST=$(aws rds describe-db-instances --db-instance-identifier "$RESTORE_ID" --query 'DBInstances[0].Endpoint.Address' --output text)

# Validation queries: freshness, row-count sanity, invariants
psql "host=$HOST dbname=orders user=restore_verifier sslmode=require" -v ON_ERROR_STOP=1 <<'SQL'
SELECT CASE WHEN max(created_at) > now() - interval '15 minutes' THEN 'ok' ELSE 'STALE' END AS freshness FROM orders;
SELECT count(*) > 1000000 AS plausible_row_count FROM orders;
-- Ledger invariant must hold on the restored copy too
SELECT count(*) = 0 AS ledger_balanced FROM (
  SELECT transfer_id FROM ledger_entries GROUP BY transfer_id HAVING sum(amount_minor) <> 0
) x;
SQL

END=$(date +%s)
echo "restore_duration_seconds $((END-START))" | curl --data-binary @- "$PUSHGATEWAY/metrics/job/restore_verify"

aws rds delete-db-instance --db-instance-identifier "$RESTORE_ID" --skip-final-snapshot
```

Alert if the job fails or if `restore_duration_seconds` exceeds the RTO.

### Targeted data recovery (the common real case)

Full restores are rare. The common incident is "a bug corrupted 3,000 rows yesterday at 14:02". Procedure:

```text
1. Stop the bleeding: disable the feature / flag; confirm no further corruption.
2. Scope: identify affected rows via audit log / updated_at / deploy time window.
3. PITR restore to a SIDE instance at 14:01 (never overwrite production).
4. Extract correct values for affected rows from the side instance.
5. Write a repair script: idempotent, dry-run mode, outputs a diff, reviewed by a second engineer.
6. Apply in batches with an audit entry per change; verify invariants.
7. Postmortem: why did constraints/tests/reconciliation not catch it earlier?
```

### Expert Mental Model

> "Nobody cares about backups. They care about restores. A restore I haven't timed and validated is a hope, not a capability."

### Common Mistake

- Backups in the same account/credentials as production (one compromised key deletes both).
- Only daily snapshots when the business assumes near-zero data loss (RPO mismatch nobody wrote down).
- Never restoring until a real disaster.
- Forgetting non-DB state: object storage, secrets, DNS config, IaC state files, queue contents.

---

## 18. Race Conditions and Deadlocks in PostgreSQL

### What

- **Race condition:** correctness depends on the timing/interleaving of concurrent operations.
- **Lost update:** two transactions read the same value and both write based on it; one write is lost.
- **Write skew:** two transactions read overlapping data, each makes a decision valid in isolation, and together they violate an invariant (e.g. two doctors both go off-call because each saw the other on call).
- **Deadlock:** two or more transactions each wait for locks held by the other. PostgreSQL detects cycles after `deadlock_timeout` and aborts one (`40P01`).

### Why

Under `READ COMMITTED` (PostgreSQL's default), the classic read-modify-write code is broken. It works in development (one user) and fails in production (concurrency). These bugs are rare per request, catastrophic in effect (overselling, double-spending, negative balances), and hard to reproduce.

### How — techniques for race conditions (ranked by preference)

**1. Atomic conditional update (best for counters/balances):**

```sql
-- Oversell-proof stock decrement: the check and the write happen atomically in one statement
UPDATE inventory
   SET available = available - $2
 WHERE sku_id = $1 AND warehouse_id = $3 AND available >= $2
RETURNING available;
-- rowCount = 0 → insufficient stock (no race possible)
```

**2. Constraints (the backstop that can't be forgotten):**

```sql
ALTER TABLE inventory ADD CONSTRAINT available_non_negative CHECK (available >= 0);
CREATE UNIQUE INDEX one_active_subscription_per_account ON subscriptions (account_id) WHERE status = 'active';
-- No overlapping bookings for the same room (requires btree_gist)
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE bookings ADD CONSTRAINT no_overlap EXCLUDE USING gist (room_id WITH =, during WITH &&);
```

**3. Pessimistic locking (`SELECT ... FOR UPDATE`) when logic can't be one statement:**

```ts
await db.tx(async (tx) => {
  const { rows: [acct] } = await tx.query(
    `SELECT id, balance_minor, daily_limit_minor, spent_today_minor FROM accounts WHERE id = $1 FOR UPDATE`,
    [accountId],
  );
  if (acct.spent_today_minor + amount > acct.daily_limit_minor) throw new LimitExceededError();
  // complex rule evaluation in application code, row is locked meanwhile
  await tx.query(`UPDATE accounts SET balance_minor = balance_minor - $2, spent_today_minor = spent_today_minor + $2 WHERE id = $1`,
    [accountId, amount]);
});
```

**4. Optimistic concurrency (version column) for user-facing edits with long think time:**

```sql
UPDATE documents SET body = $1, version = version + 1, updated_at = now()
 WHERE id = $2 AND version = $3;
-- rowCount = 0 → someone else saved first → return 409 Conflict, UI shows merge/reload
```

**5. `SERIALIZABLE` isolation for complex invariants across rows (write skew), with retry:**

```ts
await withRetry(() => db.tx({ isolation: 'serializable' }, async (tx) => {
  const { rows: [{ on_call }] } = await tx.query(
    `SELECT count(*)::int AS on_call FROM shifts WHERE ward_id = $1 AND on_call = true`, [wardId]);
  if (on_call <= 1) throw new InvariantViolation('ward must have at least one doctor on call');
  await tx.query(`UPDATE shifts SET on_call = false WHERE doctor_id = $1 AND ward_id = $2`, [doctorId, wardId]);
}), { maxAttempts: 5, baseMs: 20, capMs: 500, retryOn: (e) => (e as any).code === '40001' });
```

**6. Advisory locks for "only one of this job at a time":**

```sql
SELECT pg_try_advisory_xact_lock(hashtext('monthly-invoicing:2026-09'));  -- false → another run is active
```

**7. Job queue claiming with `FOR UPDATE SKIP LOCKED`:**

```sql
WITH next AS (
  SELECT id FROM jobs
   WHERE status = 'queued' AND run_at <= now()
   ORDER BY priority DESC, run_at
   LIMIT 10
   FOR UPDATE SKIP LOCKED
)
UPDATE jobs j SET status = 'running', locked_by = $1, locked_at = now(), attempts = attempts + 1
  FROM next WHERE j.id = next.id
RETURNING j.*;
```

### How — deadlocks

Deadlock example:

```text
T1: UPDATE accounts SET ... WHERE id = 'A';   -- locks A
T2: UPDATE accounts SET ... WHERE id = 'B';   -- locks B
T1: UPDATE accounts SET ... WHERE id = 'B';   -- waits for T2
T2: UPDATE accounts SET ... WHERE id = 'A';   -- waits for T1 → cycle → PG aborts one with 40P01
```

Prevention by **consistent lock ordering**:

```ts
export async function transfer(fromId: string, toId: string, amount: number) {
  const [first, second] = [fromId, toId].sort();         // always lock in ascending id order
  await withRetry(() => db.tx(async (tx) => {
    await tx.query(`SELECT id FROM accounts WHERE id = ANY($1) ORDER BY id FOR UPDATE`, [[first, second]]);
    const debit = await tx.query(
      `UPDATE accounts SET balance_minor = balance_minor - $2 WHERE id = $1 AND balance_minor >= $2`, [fromId, amount]);
    if (debit.rowCount !== 1) throw new InsufficientFundsError();
    await tx.query(`UPDATE accounts SET balance_minor = balance_minor + $2 WHERE id = $1`, [toId, amount]);
  }), { maxAttempts: 3, baseMs: 10, capMs: 200, retryOn: isRetryableDbError });
}
```

Other deadlock sources and fixes:

| Source | Fix |
|---|---|
| Batch updates touching rows in arbitrary order | `ORDER BY id` in the locking `SELECT ... FOR UPDATE` or the CTE driving the update |
| Foreign-key checks taking `FOR KEY SHARE` on parent rows while another tx updates parent | Lock parent first consistently; avoid updating parent key columns |
| Long transactions holding locks while doing app work | Shorten transactions; no network calls inside |
| DDL waiting for `ACCESS EXCLUSIVE` behind long reads, blocking everything behind it | `SET lock_timeout = '3s'` on migrations; retry |
| Upserts on multiple unique keys in different orders | Sort input rows by key before multi-row `INSERT ... ON CONFLICT` |

Diagnostics:

```sql
-- postgresql.conf / parameter group
-- log_lock_waits = on          (logs waits longer than deadlock_timeout)
-- deadlock_timeout = 1s

-- Who is blocking whom right now
SELECT blocked.pid AS blocked_pid, blocked.query AS blocked_query,
       blocking.pid AS blocking_pid, blocking.query AS blocking_query,
       now() - blocking.xact_start AS blocking_tx_age
FROM pg_stat_activity blocked
JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(pid) ON true
JOIN pg_stat_activity blocking ON blocking.pid = b.pid;

-- Deadlock counter (graph this)
SELECT datname, deadlocks FROM pg_stat_database;
```

### Testing race conditions

Don't hope — hammer it:

```ts
test('cannot oversell last unit under concurrency', async () => {
  await seedInventory({ skuId: 'SKU-1', available: 1 });
  const results = await Promise.allSettled(
    Array.from({ length: 50 }, () => placeOrder({ skuId: 'SKU-1', qty: 1 })),
  );
  const succeeded = results.filter((r) => r.status === 'fulfilled');
  expect(succeeded).toHaveLength(1);
  expect(await getAvailable('SKU-1')).toBe(0);
});
```

Run against a real PostgreSQL (Testcontainers), with a pool size > 1, not against mocks or SQLite.

### Expert Mental Model

> "Any read that informs a write is a potential race. I either make the check and the write one atomic statement, lock what I read, or let the database detect conflicts and retry — and I put a constraint underneath all of them."

### Common Mistake

```ts
const { available } = await db.one('SELECT available FROM inventory WHERE sku_id = $1', [sku]);
if (available >= qty) {
  await db.none('UPDATE inventory SET available = $1 WHERE sku_id = $2', [available - qty, sku]); // lost update
}
```

And: using Redis `GET`/`SET` "locks" without fencing tokens for correctness-critical mutual exclusion; or an application-level mutex in a single Node process, which does nothing across replicas.

---

## 19. Capacity Exhaustion: Pools, Disk, File Descriptors, Memory

### What

Every system has finite resources. Capacity exhaustion occurs when a resource reaches its limit, typically causing sudden, non-linear failure (a cliff, not a slope).

### Why

Resource limits create **cliffs**: at 95% pool usage everything is fine; at 100% requests queue, latency explodes, timeouts trigger retries, and the system falls over. Many resources also **fail far from the cause**: a full disk manifests as "PostgreSQL refuses writes" or "the logging agent crashed".

### How — the resource inventory

| Resource | Typical failure | Signals to monitor | Mitigations |
|---|---|---|---|
| **DB connections** (server `max_connections`) | `FATAL: sorry, too many clients already` | `numbackends` / max, pool waiting count | PgBouncer (transaction pooling), right-size per-instance pools: `instances × pool.max < max_connections − reserved` |
| **App connection pool** | Requests wait for connection, then time out | pool `waitingCount`, acquisition latency | `connectionTimeoutMillis`, fix slow queries, don't hold connections across awaits of network calls |
| **Disk** | DB stops, logs lost, container evicted | % used, **time-to-full** projection, inode usage | Alerts at 80%/90% + growth rate, log rotation, autovacuum health, retention jobs, separate volumes for data/logs |
| **File descriptors** | `EMFILE: too many open files` | open FDs vs `ulimit -n` | Raise limits (`LimitNOFILE`), keep-alive agents with max sockets, close streams in `finally` |
| **Ephemeral ports** | `EADDRNOTAVAIL` on outbound connects | TIME_WAIT sockets count | Connection reuse (keep-alive), pooling |
| **Memory** | OOM kill, GC thrash | RSS vs limit, heap used, GC pause time | Streaming, bounded caches (LRU with max), size limits on inputs, `--max-old-space-size` aligned with container limit |
| **CPU / event loop** | Latency spikes, health check failures | CPU throttling, event-loop lag | Offload CPU work to worker threads/jobs, concurrency limits |
| **Queue depth** | Growing lag, stale work | Age of oldest message | Scale consumers, shed/expire, producer rate limits |
| **Transaction IDs (PostgreSQL)** | Wraparound protection → DB refuses writes | `age(datfrozenxid)` | Healthy autovacuum, no long-running transactions |
| **Third-party quotas** | 429s, account suspension | Quota usage headers | Client-side rate limiting, caching, request batching |
| **Sequences / ID space** | `integer` PK overflow at 2,147,483,647 | `max(id)` / type limit | Use `bigint` for PKs from day one |
| **Certificates / tokens** | TLS failures when certs expire | Days to expiry | Automated renewal (ACME), expiry alerts at 30/14/7 days |

### Example — pool sizing arithmetic

```text
PostgreSQL max_connections        = 200
Reserved (superuser, admin, repl) = 20
Available for apps                = 180

Web:     12 pods × pool.max 10 = 120
Workers:  4 pods × pool.max  8 =  32
Cron:     1 pod  × pool.max  5 =   5
Migrations/one-off             =   5
Total                          = 162  ✓ (headroom for surge during rolling deploy?)

Rolling deploy with maxSurge 25%: web temporarily 15 pods × 10 = 150 → total 192 ✗ over 180
→ Fix: PgBouncer in transaction mode, or reduce pool.max to 8, or maxSurge 1 pod.
```

### Example — Node pool instrumentation

```ts
setInterval(() => {
  metrics.dbPoolTotal.set(pool.totalCount);
  metrics.dbPoolIdle.set(pool.idleCount);
  metrics.dbPoolWaiting.set(pool.waitingCount);   // > 0 sustained = saturation
}, 5000).unref();
```

### Example — Prometheus alerts for exhaustion

```yaml
groups:
  - name: capacity
    rules:
      - alert: DiskWillFillIn6Hours
        expr: predict_linear(node_filesystem_avail_bytes{mountpoint="/var/lib/postgresql"}[1h], 6 * 3600) < 0
        for: 10m
        labels: { severity: page }
      - alert: DbPoolSaturated
        expr: max_over_time(db_pool_waiting[5m]) > 0 and avg_over_time(db_pool_waiting[5m]) > 2
        for: 5m
        labels: { severity: page }
      - alert: FileDescriptorsHigh
        expr: process_open_fds / process_max_fds > 0.8
        for: 10m
        labels: { severity: ticket }
      - alert: PostgresXidWraparoundRisk
        expr: pg_database_age_datfrozenxid > 1.0e9
        labels: { severity: page }
      - alert: CertificateExpiresSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 14 * 86400
        labels: { severity: ticket }
```

### Expert Mental Model

> "For every finite resource: what's the limit, how close are we, how fast are we approaching it, and what fails first when we hit it?"

### Common Mistake

- Monitoring **utilization** but not **saturation** (CPU 60% average hides 100% bursts; pool "total = max" isn't alarming but "waiting > 0" is).
- Static "disk > 90%" alerts that fire at 3 a.m. for a disk that takes 3 months to fill, and miss a disk that fills from 50% to 100% in 20 minutes. Use time-to-full.
- Increasing `max_connections` to 2,000 to "fix" pool exhaustion (each PostgreSQL connection is a process with memory overhead; performance collapses).

---

## 20. Recovery: Detect, Contain, Repair, Learn

### What

Recovery is everything from "something is wrong" to "we're back, the damage is repaired, and it's less likely to recur".

### Why

Mean time to recovery (MTTR) often matters more than mean time between failures (MTBF). Systems that fail occasionally but recover in 2 minutes beat systems that fail rarely but take 2 days to recover and repair data.

### How

```text
DETECT     SLO burn-rate alerts, business-metric alerts, reconciliation jobs, synthetic checks, customer reports (worst)
   ↓
TRIAGE     Severity, blast radius (which tenants/regions/journeys), recent changes (deploys, flags, config)
   ↓
CONTAIN    Flip kill switch, roll back, shed load, fail over, block abusive tenant, pause consumers
   ↓
RESTORE    Service back within SLO (may be degraded)
   ↓
REPAIR     Fix data: replay from outbox/DLQ, reconcile with provider, repair scripts, targeted PITR
   ↓
VERIFY     Invariant checks pass, reconciliation clean, customer-facing state correct
   ↓
LEARN      Blameless postmortem, action items with owners, new tests/alerts/constraints/runbooks
```

Automated recovery mechanisms worth building:

| Mechanism | What it recovers |
|---|---|
| Reconciliation job (e.g. hourly compare PSP charges ↔ orders) | Unknown outcomes, lost webhooks, partial failures |
| Stuck-state sweeper (entities in intermediate states past SLA) | Crashed workflows, lost messages |
| Outbox lag alert + relay restart | Event publication stalls |
| DLQ alert + redrive tooling | Poison messages after fix |
| Self-healing orchestration (k8s restarts, autoscaling) | Crashed processes, load growth |
| Automatic rollback on canary failure | Bad deploys |

Example reconciliation (payments):

```sql
-- Charges captured at the PSP (imported hourly into psp_charges) with no matching paid order
SELECT c.psp_charge_id, c.amount_minor, c.metadata->>'order_id' AS order_id, c.created_at
FROM psp_charges c
LEFT JOIN payments p ON p.psp_charge_id = c.psp_charge_id
WHERE c.status = 'succeeded'
  AND c.created_at < now() - interval '15 minutes'
  AND p.id IS NULL;
-- Each row → attach to order if order exists and is awaiting payment, else auto-refund + alert.
```

Every alert links to a runbook ([templates/runbook.md](templates/runbook.md)); every significant incident gets a postmortem ([templates/postmortem.md](templates/postmortem.md)) whose action items become **mechanisms** (constraints, tests, CI checks, alerts), not "be more careful" — see [10-knowledge-into-systems.md](10-knowledge-into-systems.md).

### Expert Mental Model

> "Assume some failures will slip past every defense. The last line of defense is a system that notices inconsistency on its own and a team that has practiced repairing it."

### Common Mistake

- Declaring an incident resolved when the error rate drops, without repairing data created during the incident.
- Postmortem action items like "add more logging" and "be careful with migrations".

---

## 21. Worked FMEA: Payment/Checkout Flow

FMEA (Failure Mode and Effects Analysis) systematically lists how each step can fail, the effect, how likely it is, how severe, how detectable, and what mitigates it. A simple **Risk Priority Number (RPN) = Severity × Occurrence × Detection** (each 1–10; for Detection, 10 = hardest to detect) helps rank what to fix first. Use [templates/failure-mode-analysis.md](templates/failure-mode-analysis.md).

### System under analysis

```text
[Browser: Next.js checkout page]
      │ POST /api/checkout (Idempotency-Key)
      ▼
[Checkout API] ──► [PostgreSQL: carts, orders, inventory, payments, outbox]
      │
      ├──► [Tax service]            (sync, 2s timeout)
      ├──► [PSP: create PaymentIntent / confirm]  (sync, 8s timeout, idem key)
      │
      ◄─── [PSP webhooks: payment_intent.succeeded / failed]  (async, at-least-once, signed)
      │
[Outbox relay] ──► [Queue] ──► [Fulfillment worker] ──► [WMS]
                          └──► [Email worker] ──► [Email provider]
```

Flow: validate cart → reserve inventory (tx) → compute tax → create order `pending_payment` + PaymentIntent with idem key → client confirms (3DS if needed) → webhook marks order `paid` (inbox dedup) → outbox `order.paid` → fulfillment and email.

### FMEA table

| # | Step | Failure mode | Effect | S | O | D | RPN | Mitigations (existing → added) |
|---|---|---|---|---|---|---|---|---|
| 1 | Submit checkout | User double-clicks / client retries after timeout | Duplicate orders & charges | 9 | 7 | 4 | 252 | Idempotency-Key per intent; `UNIQUE(cart_id)` on orders; PSP idempotency key `pi:<orderId>` |
| 2 | Price calculation | Client-supplied price trusted | Undercharging / fraud | 9 | 4 | 7 | 252 | Server recomputes all prices from DB; amounts in integer minor units; see [08-security-engineering.md](08-security-engineering.md) |
| 3 | Reserve inventory | Concurrent last-unit purchases | Oversell | 7 | 6 | 5 | 210 | Atomic conditional `UPDATE ... WHERE available >= qty`; `CHECK (available >= 0)`; concurrency test |
| 4 | Reserve inventory | Reservation never released (abandoned checkout, crash) | Phantom out-of-stock | 5 | 8 | 6 | 240 | Reservations with `expires_at`; sweeper releases expired every minute; metric of expired reservations |
| 5 | Tax API | Timeout / 5xx | Checkout blocked | 7 | 4 | 2 | 56 | 2s timeout, 1 retry w/ jitter, breaker; fallback to cached rate table **only** if legal approves + flag order for reconciliation |
| 6 | Tax API | Malformed 200 response | Wrong tax collected | 8 | 2 | 8 | 128 | zod schema validation; reject instead of default; business alert on tax/order ratio anomaly |
| 7 | Create PaymentIntent | PSP timeout — outcome unknown | Possible orphan intent | 6 | 4 | 5 | 120 | Same idem key on retry returns same intent; reconciliation job |
| 8 | Confirm payment | Charge succeeds; response lost; client shows error | User retries, or thinks payment failed | 8 | 5 | 5 | 200 | Idempotent confirm; order page polls order status (source of truth = webhook-updated DB); "payment processing" UI state |
| 9 | Webhook | Webhook delivered twice | Double fulfillment / double email | 7 | 8 | 3 | 168 | Inbox dedup on PSP event ID; state machine only allows `pending_payment → paid` |
| 10 | Webhook | Webhook lost / endpoint down for hours | Paid order stuck `pending_payment`; may be auto-cancelled while money taken | 9 | 3 | 6 | 162 | PSP retries for days; our reconciliation polls PSP for intents in `pending_payment` > 10 min; never auto-cancel without checking PSP |
| 11 | Webhook | Forged webhook | Free goods | 10 | 3 | 7 | 210 | Signature verification with raw body + timestamp tolerance; re-fetch event from PSP API for high-value orders |
| 12 | Webhook | Out-of-order events (`failed` arrives after `succeeded`) | Paid order marked failed | 8 | 3 | 6 | 144 | State machine rejects illegal transitions; use event `created` timestamp / re-fetch current PaymentIntent status |
| 13 | Mark paid + outbox | Process crash between DB update and publish | Order paid, never fulfilled | 9 | 3 | 7 | 189 | Outbox in same tx; outbox lag alert; stuck `paid` without `fulfillment_started` sweeper |
| 14 | Fulfillment worker | Poison message (unknown SKU in WMS) | Consumer loops, blocks partition | 6 | 3 | 4 | 72 | Error classification → DLQ; DLQ alert; redrive runbook |
| 15 | Email | Provider outage | No confirmation emails | 3 | 4 | 3 | 36 | Queue with retries (24h); degraded but order unaffected |
| 16 | Database | Primary failover mid-checkout | Some checkouts error; some commit with unknown outcome | 7 | 2 | 3 | 42 | Retry on connection errors with idempotency; client re-checks order status |
| 17 | Database | Pool exhaustion from slow report queries | All checkouts time out | 9 | 3 | 3 | 81 | Bulkhead: separate pool/role/replica for reports; `statement_timeout` |
| 18 | Deploy | Incompatible migration during rollout | Checkout 500s for minutes | 8 | 3 | 2 | 48 | Expand/contract; squawk lint; canary with checkout success-rate guardrail |
| 19 | Refund/cancel | Cancel after capture fails to refund | Customer charged for cancelled order | 9 | 2 | 6 | 108 | Saga compensation with retry; `refund_pending` state; daily reconciliation cancelled-but-captured |
| 20 | Currency/amounts | Floating-point rounding | Totals don't reconcile | 7 | 3 | 7 | 147 | Integer minor units; `numeric` in SQL; invariant: `sum(line totals) + tax + shipping − discounts = order total` checked in code + nightly |
| 21 | Traffic spike (flash sale) | Overload | Everyone times out | 9 | 4 | 2 | 72 | Waiting room / load shedding by priority; pre-scaling; inventory reservations limit concurrency |
| 22 | Fraud | Card testing via checkout endpoint | PSP fees, account risk | 7 | 5 | 4 | 140 | Rate limits per IP/account/card fingerprint; CAPTCHA on anomalies; PSP Radar rules |

### What the FMEA tells you to build first

Sorted by RPN, the top items are idempotency (1), server-side pricing (2), reservation expiry (4), oversell protection (3), and webhook authenticity (11). Notice most high-RPN items share two properties: **high severity (money)** and **poor detectability without deliberate reconciliation**. That's why mature payment systems invest disproportionately in reconciliation — it converts "undetectable" (D=8) into "detected within an hour" (D=3) for an entire class of failures at once.

### Test plan derived from the FMEA

| FMEA # | Test type | Test |
|---|---|---|
| 1 | Integration | Same Idempotency-Key ×20 concurrent → 1 order, 1 PaymentIntent, identical responses |
| 3 | Concurrency | 50 parallel checkouts for last unit → exactly 1 succeeds |
| 9 | Integration | Deliver same webhook event 3× → 1 state change, 1 outbox event |
| 10 | Fault injection | Drop webhooks; reconciliation marks order paid within 15 min |
| 11 | Security | Tampered signature / stale timestamp → 400, no state change |
| 12 | Unit (state machine) | `paid → failed` transition rejected |
| 13 | Crash test | Kill process after commit before relay → event still published after restart |
| 17 | Load | Run report load + checkout load → checkout p95 unaffected |
| 20 | Property-based | Random carts/discounts/taxes → totals always reconcile |

---

## 22. Amateur vs Professional vs Expert

| Topic | Amateur | Professional | Expert |
|---|---|---|---|
| Mindset | Codes the happy path; errors are exceptions | Adds try/catch, retries, and logging | Enumerates failure outcomes per boundary; designs so each is harmless, detectable, and repairable |
| Timeouts | Library defaults (often none) | Sets timeouts on HTTP calls | Deadline propagated end-to-end; timeouts derived from measured latency; layered correctly |
| Retries | `for` loop with fixed sleep | Exponential backoff | Backoff + full jitter + retry budget + single retry layer + retry only idempotent/classified errors |
| Duplicates | Doesn't consider them | Disables the button; checks "exists" before insert | Idempotency keys, inbox dedup, unique constraints; treats every delivery as at-least-once |
| Multi-system writes | Write DB then publish | Wraps in try/catch and "rolls back" manually | Transactional outbox; sagas with idempotent compensations; reconciliation |
| Concurrency | Read-then-write in app code | `SELECT ... FOR UPDATE` sometimes | Atomic statements, constraints as backstop, deliberate isolation levels, concurrency tests against real DB |
| Dependencies | All dependencies are critical | Circuit breaker on some | Criticality classification per journey; bulkheads; defined degraded modes that are tested |
| Overload | "We'll autoscale" | Rate limits | Bounded queues, priority load shedding, backpressure, adaptive concurrency |
| Deploys | Big-bang, migration + code together | Rolling deploy, sometimes breaks | Expand/contract, migration lint, canaries with automatic rollback, flags as kill switches |
| Data safety | "The cloud backs it up" | Daily snapshots | RPO/RTO per data class, PITR, immutable cross-account copies, automated restore verification |
| Detection | Customers report problems | Error-rate alerts | SLO burn alerts + business-metric alerts + reconciliation + stuck-state sweepers |
| After incidents | Fix the bug | Postmortem with action items | Action items become mechanisms (constraints, tests, CI gates, alerts); FMEA updated |

How to recognize the level in a code review:
- **Amateur PR:** `await externalCall()` with no timeout inside a transaction.
- **Professional PR:** timeout and retry added, but POST retried without an idempotency key.
- **Expert PR:** description includes "failure modes considered", links the FMEA row, adds a concurrency test and an alert, and the migration is expand-only.

---

## 23. Key Takeaways

1. **A timeout is an unknown outcome, not a failure.** Design ways to resolve unknowns: idempotency keys, status queries, reconciliation.
2. **Assume at-least-once everywhere.** Make every consumer and every write path idempotent; back it with unique constraints.
3. **Inside one database, use transactions aggressively; across systems, use outbox + inbox + sagas.** Never make a network call inside a DB transaction.
4. **Every I/O has a timeout derived from a propagated deadline.** Zombie work after the client gave up is pure waste that amplifies overload.
5. **Retries are load amplifiers.** Use backoff with jitter, a retry budget, a single retry layer, and only retry classified transient errors.
6. **Break cascades** with circuit breakers, bulkheads, bounded queues, and priority load shedding. Rejecting some work quickly beats failing all work slowly.
7. **Define degraded modes as product decisions in advance** and test them; fallbacks must never violate invariants.
8. **Deployments are the top incident trigger.** Old and new code coexist: expand/contract, lint migrations, canary, and keep kill switches.
9. **Only verified restores count.** Set RPO/RTO per data class, keep an immutable copy outside the blast radius, and drill restores automatically.
10. **Race conditions are guaranteed under concurrency.** Prefer atomic statements, lock ordering, constraints, and serializable-with-retry; test with real parallelism.
11. **Watch saturation and time-to-exhaustion**, not just utilization.
12. **Reconciliation is the universal safety net** that converts undetectable failures into detected, repairable ones.

---

## 24. Self-Assessment Checklist

Use this against a real service you own:

- [ ] Every outbound HTTP/DB/queue call has an explicit timeout, and inner timeouts are shorter than outer ones.
- [ ] Request deadlines propagate to downstream services and DB statement timeouts.
- [ ] All non-idempotent public write endpoints accept an `Idempotency-Key`, compare request hashes, and handle concurrent duplicates.
- [ ] No network calls happen inside database transactions.
- [ ] Events are published via a transactional outbox; consumers deduplicate via an inbox or natural idempotency.
- [ ] Retries use exponential backoff with jitter, respect `Retry-After`, have a budget, and happen at one layer only.
- [ ] Optional dependencies have circuit breakers and tested fallbacks; critical dependencies are explicitly listed.
- [ ] DB pools are separated by workload, and total connections stay under `max_connections` even during deploy surge.
- [ ] Every queue has a DLQ, a DLQ-not-empty alert, an oldest-message-age alert, and a redrive runbook.
- [ ] Multi-step cross-system workflows have explicit states, compensations, and a stuck-state sweeper.
- [ ] Migrations are expand/contract, linted in CI, and use `CONCURRENTLY` / `NOT VALID` / `lock_timeout` where needed.
- [ ] Risky features ship behind flags with safe defaults and a removal date; kill switches are tested.
- [ ] RPO/RTO are written down per data class; a restore was performed, timed, and validated in the last 30 days.
- [ ] Balance/stock/uniqueness invariants are enforced by DB constraints and tested under real concurrency.
- [ ] Lock ordering is consistent for multi-row updates; deadlocks and lock waits are logged and graphed.
- [ ] Alerts exist for pool saturation, disk time-to-full, FD usage, XID age, and certificate expiry.
- [ ] Reconciliation jobs compare your records with external providers and alert on mismatches.
- [ ] An FMEA exists for the most critical user journey, and its top-RPN items have tests.
