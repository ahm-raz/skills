# 01 — Software Engineering Skills: What They Actually Are

> A software engineering skill is not "knowing a technology." It is a **reliable ability to make good decisions under uncertainty in a specific problem space**, and to turn those decisions into systems that keep working after you stop looking at them. This document breaks engineering into 21 skill categories, shows how beginners, seniors, and experts differ in each, and separates **tool knowledge** (what an API does) from **engineering ability** (what the system needs).

Related: [02-engineering-conventions.md](02-engineering-conventions.md) · [03-how-experts-design.md](03-how-experts-design.md) · [16-maturity-model.md](16-maturity-model.md) · [17-common-failure-modes.md](17-common-failure-modes.md) · [glossary.md](glossary.md)

---

## Table of Contents

1. [What a "Skill" Actually Is](#1-what-a-skill-actually-is)
2. [The Anatomy of a Skill: Five Layers](#2-the-anatomy-of-a-skill-five-layers)
3. [How to Read the Category Sections](#3-how-to-read-the-category-sections)
4. [Skill Categories](#4-skill-categories)
   - [4.1 Programming](#41-programming)
   - [4.2 Algorithms and Data Structures](#42-algorithms-and-data-structures)
   - [4.3 System Design](#43-system-design)
   - [4.4 Software Architecture](#44-software-architecture)
   - [4.5 Database Engineering](#45-database-engineering)
   - [4.6 API Design](#46-api-design)
   - [4.7 Distributed Systems](#47-distributed-systems)
   - [4.8 Concurrency](#48-concurrency)
   - [4.9 Security](#49-security)
   - [4.10 Performance Engineering](#410-performance-engineering)
   - [4.11 Testing](#411-testing)
   - [4.12 Debugging](#412-debugging)
   - [4.13 DevOps](#413-devops)
   - [4.14 Cloud / Infrastructure](#414-cloud--infrastructure)
   - [4.15 Observability](#415-observability)
   - [4.16 Product Engineering](#416-product-engineering)
   - [4.17 Domain Modeling](#417-domain-modeling)
   - [4.18 Code Review](#418-code-review)
   - [4.19 Technical Leadership](#419-technical-leadership)
   - [4.20 Documentation](#420-documentation)
   - [4.21 Technical Decision-Making](#421-technical-decision-making)
5. [Tool Knowledge vs Engineering Ability](#5-tool-knowledge-vs-engineering-ability)
6. [How Skills Compound](#6-how-skills-compound)
7. [What Level Is Actually Necessary](#7-what-level-is-actually-necessary)
8. [A Deliberate Skill-Development Plan](#8-a-deliberate-skill-development-plan)
9. [Key Takeaways](#9-key-takeaways)
10. [Self-Assessment Checklist](#10-self-assessment-checklist)

---

## 1. What a "Skill" Actually Is

### What

A software engineering skill is the ability to **consistently produce a good outcome in a class of problems**, including problems you have not seen before. The operative words are:

- **Consistently** — not once, not when lucky, not only when a tutorial exists.
- **Outcome** — the system behaves correctly in production, not "the code compiles."
- **Class of problems** — transferable. Knowing how to add an index to `orders.customer_id` is a fact; knowing how to find *which* query is slow, *why*, and *what the cheapest durable fix is* is a skill.

### Why this definition matters

If you define skill as "knowing things," you will optimize for collecting technologies. Your résumé grows; your systems do not get better. If you define skill as "reliably producing outcomes," you optimize for **judgment, feedback loops, and mental models** — which transfer across every stack you will ever use.

### How experts think about it

Experts decompose a skill into:

| Component | Question it answers | Example (database engineering) |
|---|---|---|
| **Knowledge** | What exists? | B-tree vs GIN indexes, isolation levels, MVCC |
| **Mental model** | How does it behave? | "An UPDATE in Postgres writes a new tuple; heavy updates bloat tables and indexes" |
| **Judgment** | What should I do here? | "This table gets 5k updates/sec on a JSONB column — split the hot column out" |
| **Execution** | Can I do it correctly and quickly? | Writing a zero-downtime migration with `CREATE INDEX CONCURRENTLY` |
| **Verification** | How do I know it worked? | `EXPLAIN (ANALYZE, BUFFERS)` before and after, p95 latency dashboard |
| **Operationalization** | How do I make it repeatable? | A migration linter in CI that rejects non-concurrent index creation |

A beginner has fragments of *knowledge*. A senior has *knowledge + mental model + judgment + execution*. An expert adds *verification* as a reflex and *operationalization* as a habit — they turn what they know into something the team no longer has to remember (see [10-knowledge-into-systems.md](10-knowledge-into-systems.md)).

### Example

Two developers are asked to "add a discount code feature" to an e-commerce checkout.

- **Developer A (tool knowledge):** Adds a `discount_codes` table, an input field in the React checkout, a `POST /apply-discount` endpoint that subtracts the amount from the cart total. Ships in a day.
- **Developer B (engineering ability):** Asks: Can a code be used more than once? By the same user? Concurrently from two tabs? Is the discount applied before or after tax (jurisdiction-dependent)? What happens to a discount when an item is refunded? Can a code make the total negative? Who can create codes, and is creation audited? Can codes be brute-forced? Then implements: a `redemptions` table with a unique constraint `(code_id, user_id)` where single-use, a `CHECK (total_cents >= 0)`, rate limiting on the apply endpoint, discount lines stored on the order (not recomputed later), and tests for the concurrency case.

Both "know" the same tools. Only one has the skill.

### Expert Mental Model

> "A skill is a compressed set of failure experiences. Every expert rule of thumb is scar tissue from a production incident — theirs or someone else's."

### Common Mistake

Equating **familiarity** with **skill**. Having used Kafka on one project is familiarity. Being able to explain what happens to consumer offsets during a rebalance while a consumer is mid-batch — and designing for it — is skill.

---

## 2. The Anatomy of a Skill: Five Layers

Every category below can be assessed on five layers. Use this as a diagnostic.

```text
Layer 5  Operationalize   → I make the right behavior automatic for others (lint, template, CI gate)
Layer 4  Verify           → I can prove it works and detect when it stops working
Layer 3  Decide           → I choose correctly between options given constraints
Layer 2  Model            → I can predict behavior before running the code
Layer 1  Know             → I know what exists and roughly what it does
```

**Beginners** live at layers 1–2 and skip 4. **Seniors** reliably reach 3–4. **Experts** default to 5 — they are uncomfortable when correctness depends on someone remembering something.

A diagnostic question for any skill: *"If I left this team tomorrow, which of my good decisions would keep happening?"* Only the layer-5 ones.

---

## 3. How to Read the Category Sections

Each category follows this structure:

- **What it actually means** — the real scope, not the textbook one.
- **Why it matters (effect on quality)** — which quality attributes it drives (see [05-quality-engineering.md](05-quality-engineering.md)).
- **Inexperienced vs Senior vs Expert** — observable behaviors, so you can recognize the level in yourself and in code.
- **How it is developed** — concrete practice, not "read books."
- **Example** — a realistic scenario.
- **Expert Mental Model** — the compressed heuristic.
- **Common Mistake** — the most frequent trap.
- **Level necessary for professional work** — what's actually required to ship production software responsibly.

Levels referenced use the maturity model in [16-maturity-model.md](16-maturity-model.md): L1 Beginner, L2 Competent, L3 Senior, L4 Staff/Principal, L5 Elite System.

---

## 4. Skill Categories

### 4.1 Programming

**What it actually means.** Programming is not typing syntax. It is **expressing intent so precisely that a machine executes it correctly and a human understands it quickly** — including the next human, who may be you in eight months. It covers decomposition, naming, control flow, state management, error handling, type design, and making illegal states unrepresentable.

**Why it matters.** Programming skill directly drives **correctness, maintainability, testability, and evolvability**. Poor programming compounds: every unclear function costs every future reader.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Goal | "Make it work" | "Make it clear and correct" | "Make wrong usage hard or impossible" |
| Functions | Long, do many things, boolean flags change behavior | Small, single purpose, named for intent | Shaped around the domain; signatures document invariants |
| State | Mutable shared objects, globals | Localized state, immutability by default | State machines; illegal transitions unrepresentable |
| Errors | `try/catch` that logs and continues | Typed errors, fail fast, errors carry context | Errors are part of the API design (`Result` types, discriminated unions), expected vs unexpected clearly separated |
| Types | `any`, stringly typed | Interfaces for data shapes | Branded types, discriminated unions, parse-don't-validate at boundaries |
| Duplication | Copy-paste | DRY everything | Tolerates duplication until the abstraction is *proven* by 3+ real cases |
| Reading code | Reads only to modify | Reads to understand | Reads to find the model the author had, and where it breaks |

**How it is developed.**
- Read high-quality codebases (e.g., the Postgres source, TypeScript compiler, Stripe's public SDKs) and ask *why* things are shaped that way.
- Rewrite your own code from 6 months ago without looking at it; compare.
- Practice refactoring under test coverage — change structure without changing behavior.
- Learn one language with a strong type system deeply (TypeScript strict mode, Rust, Haskell, or OCaml) — it rewires how you model data.
- Code review from someone better than you, repeatedly.

**Example — making illegal states unrepresentable (TypeScript, payments).**

Naive:

```ts
type Payment = {
  status: string;            // "pending" | "captured" | "failed" ... hopefully
  capturedAt?: Date;
  failureReason?: string;
  amountCents: number;
};

// Nothing stops: { status: "failed", capturedAt: new Date() }
```

Expert:

```ts
type Cents = number & { readonly __brand: "Cents" };
const cents = (n: number): Cents => {
  if (!Number.isInteger(n) || n < 0) throw new Error(`Invalid cents: ${n}`);
  return n as Cents;
};

type Payment =
  | { status: "pending";  id: string; amount: Cents; createdAt: Date }
  | { status: "captured"; id: string; amount: Cents; createdAt: Date; capturedAt: Date }
  | { status: "failed";   id: string; amount: Cents; createdAt: Date; failureReason: FailureReason }
  | { status: "refunded"; id: string; amount: Cents; createdAt: Date; capturedAt: Date; refundedAt: Date };

type FailureReason = "card_declined" | "insufficient_funds" | "fraud_suspected" | "processor_error";

function capture(p: Extract<Payment, { status: "pending" }>, at: Date): Extract<Payment, { status: "captured" }> {
  return { ...p, status: "captured", capturedAt: at };
}

// capture() on a refunded payment is now a compile error, not a production incident.
```

**Expert Mental Model.** *"Code is read 10x more than written, and executed in states the author never imagined. Push errors left: from production → tests → compile time → impossible."*

**Common Mistake.** Premature abstraction. Building a `GenericEntityManager<T>` after seeing two similar entities, then fighting it forever when the third entity differs. Duplication is cheaper than the wrong abstraction.

**Level necessary for professional work.** Solid L3 on readability, error handling, and type modeling. You do not need to be a language lawyer; you do need to write code a teammate can safely change without asking you.

---

### 4.2 Algorithms and Data Structures

**What it actually means.** In professional work this is rarely "implement a red-black tree." It is **recognizing the computational shape of a problem** — that a "find related products" feature is a graph problem, that a leaderboard is a sorted set, that "has this idempotency key been seen" is a set membership check, that a nested loop over 50k orders × 50k shipments is 2.5 billion comparisons.

**Why it matters.** Drives **performance and scalability** most directly, but also **correctness** (off-by-one, overflow, floating point money) and **cost** (a quadratic job that costs $4,000/month in compute).

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Recognition | Doesn't notice complexity until it's slow | Notices O(n²) in review | Sees the data size growth curve at design time |
| Choice | Arrays for everything | Right built-in structure (Map, Set, heap) | Chooses structures that match access patterns, including on-disk (B-tree, LSM, bloom filter) |
| Scale thinking | "Works on my test data" | Tests with realistic volumes | Asks "what is n in 3 years?" and "is n bounded?" |
| Numbers | Floats for money | Integer cents | Knows rounding modes, currency exponents (JPY has 0, BHD has 3), banker's rounding rules |
| Tradeoffs | Optimal big-O only | Big-O + constants | Big-O + constants + memory + cache locality + I/O cost |

**How it is developed.**
- Learn the ~15 structures and ~20 algorithms that cover most real work: hash maps, sets, arrays, linked lists (and why you rarely want them), heaps/priority queues, trees, tries, graphs (BFS/DFS/topological sort/Dijkstra), sorting, binary search, two pointers, sliding windows, union-find, interval merging, bloom filters, consistent hashing, reservoir sampling, LRU caches.
- For each, learn **which database/infrastructure feature uses it** (B-trees → indexes; LSM trees → Cassandra/RocksDB; heaps → job schedulers; consistent hashing → sharding; bloom filters → read-path short-circuiting).
- Profile real code and map slow spots back to complexity.

**Example — logistics reconciliation.**

Naive (Node.js, matching 80k shipment events to 80k orders):

```ts
for (const event of events) {
  const order = orders.find(o => o.trackingNumber === event.trackingNumber); // O(n) inside O(n)
  if (order) apply(order, event);
}
// 6.4 billion comparisons worst case. Job takes 40 minutes and times out.
```

Expert:

```ts
const byTracking = new Map(orders.map(o => [o.trackingNumber, o] as const)); // O(n)
for (const event of events) {
  const order = byTracking.get(event.trackingNumber); // O(1)
  if (order) apply(order, event);
}
// Runs in ~200ms. Better still: push the join into SQL where an index exists.
```

The expert also asks: *why is this in application memory at all?* A `JOIN` on an indexed column in Postgres, processed in batches, avoids loading 160k rows into Node.

**Expert Mental Model.** *"Every loop has a hidden multiplier: the growth of n. Every data structure is a bet on the access pattern. Know which bet you're making."*

**Common Mistake.** Two opposite mistakes: (1) ignoring complexity until production traffic arrives, and (2) over-optimizing a loop over 12 items while the real cost is 400 sequential network calls.

**Level necessary for professional work.** L2–L3. You need fluent recognition of complexity classes and the standard structures. You rarely need competitive-programming depth unless you build databases, compilers, search, or routing engines.

---

### 4.3 System Design

**What it actually means.** Designing **how multiple components — services, databases, caches, queues, clients, third parties — cooperate to meet functional and non-functional requirements** under real load, real failures, and real cost constraints. It is the skill of placing boundaries, state, and communication paths.

**Why it matters.** Drives **scalability, reliability, recoverability, operability, and cost**. Most expensive production failures are system design failures, not code bugs: a single database that can't be migrated, a synchronous call chain that cascades, a cache that serves stale prices.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Starting point | Boxes and arrows from a blog post | Requirements and load estimates | Invariants, failure modes, and what must *not* be built |
| Data flow | Unclear where the source of truth is | Explicit source of truth per entity | Explicit ownership, consistency model, and staleness budget per data path |
| Scale | "Add Kubernetes" | Back-of-envelope estimates | Estimates + identifies the one component that will break first + the cheapest mitigation |
| Failure | Not considered | Timeouts and retries | Failure domains, blast radius, degradation modes, recovery procedures |
| Complexity | Adds components to look robust | Adds components when needed | Removes components; justifies each with a requirement |

**How it is developed.**
- Do back-of-envelope estimation for real systems you use: How many writes/sec does a food delivery app's order service need at dinner peak in one city?
- Read engineering postmortems (AWS, Cloudflare, GitHub, Stripe, Discord) — each is a free system design lesson.
- Write design docs ([templates/design-doc.md](templates/design-doc.md)) *before* building, and revisit them after launch to see which assumptions were wrong.
- Operate what you design. Being on call for your own system teaches more than any course.

**Example — flash sale on an e-commerce site.** 200,000 users try to buy 1,000 units at 12:00:00.

- **Naive:** Web servers read `stock` from Postgres, check `> 0`, then `UPDATE products SET stock = stock - 1`. Result: overselling due to races, database connection exhaustion, site down.
- **Expert design:**
  1. **Invariant:** units sold ≤ 1,000. Enforce with an atomic conditional update: `UPDATE inventory SET reserved = reserved + 1 WHERE sku = $1 AND reserved < total RETURNING reserved;` (0 rows = sold out), plus a `CHECK (reserved <= total)` constraint.
  2. **Admission control:** a virtual waiting room / token bucket in front, so only ~2,000 req/s reach the reservation path; the rest get a queue position.
  3. **Reservation, not purchase:** reserve for 10 minutes; payment happens async; expired reservations are released by a scheduled job.
  4. **Static everything else:** product page served from CDN with a short TTL; stock count on the page is *approximate* and labeled as such.
  5. **Degradation:** if payments provider is slow, reservations still succeed and checkout shows "processing."
  6. **Validation:** load test at 3× expected peak in staging, with the payment provider stubbed at p99 = 4s.

**Expert Mental Model.** *"Find the invariant, find the contention point, find the failure domain. Design those three; the rest is plumbing."* (See [03-how-experts-design.md](03-how-experts-design.md).)

**Common Mistake.** Designing for imaginary scale ("we'll need sharding") while ignoring real risks (no idempotency on the payment webhook).

**Level necessary for professional work.** L3 to own a feature end-to-end in production; L4 to own a system with multiple teams or significant revenue impact.

---

### 4.4 Software Architecture

**What it actually means.** Architecture is the set of **decisions that are expensive to change** — module boundaries, dependency direction, data ownership, deployment units, communication styles, and the principles that govern future decisions. System design asks "how do these components work together?"; architecture asks "how is this codebase and system *organized* so it can keep changing safely for years?"

**Why it matters.** Drives **maintainability, evolvability, testability**, and team velocity over time. Bad architecture doesn't fail loudly; it makes every change 20% slower each quarter until the team proposes a rewrite.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Choice driver | Fashion, tutorials | Past project experience | Explicit requirements, constraints, team topology, and reversibility |
| Boundaries | Folders by technical type (`controllers/`, `models/`) | Modules by feature | Modules by domain capability with enforced dependency rules |
| Dependencies | Everything imports everything | Layering rules | Dependency direction points toward stable policy; enforced by tooling |
| Change | Big-bang rewrites | Incremental refactors | Evolutionary architecture with fitness functions; strangler patterns |
| Documentation | None | Diagrams | ADRs capturing *why*, plus constraints that are checked in CI |

**How it is developed.**
- Maintain a system for 2+ years. Architecture skill mostly comes from living with the consequences of decisions.
- Write ADRs ([templates/adr.md](templates/adr.md)) and revisit them a year later: which decisions held? Which alternatives would have been better?
- Study architectures in their failure contexts: why Segment went from microservices back to a monolith; why Shopify invested in a modular monolith; why Amazon Prime Video consolidated a serverless pipeline.
- Practice drawing the *dependency graph* of a real codebase and finding cycles.

**Example — modular monolith boundary enforcement (Next.js + Node backend).**

```text
src/
  modules/
    catalog/
      index.ts          ← public API of the module (the ONLY importable file)
      domain/
      application/
      infrastructure/
    ordering/
      index.ts
      ...
    billing/
      index.ts
      ...
  shared/
    kernel/             ← Money, Id types, Result — no business logic
```

```js
// eslint.config.js — enforce "modules only talk through index.ts"
import boundaries from "eslint-plugin-boundaries";

export default [
  {
    plugins: { boundaries },
    settings: {
      "boundaries/elements": [
        { type: "module", pattern: "src/modules/*", capture: ["name"] },
        { type: "shared", pattern: "src/shared/*" },
      ],
    },
    rules: {
      "boundaries/entry-point": ["error", {
        default: "disallow",
        rules: [{ target: ["module"], allow: "index.ts" }],
      }],
      "boundaries/element-types": ["error", {
        default: "allow",
        rules: [{ from: ["shared"], disallow: ["module"] }], // kernel never depends on modules
      }],
    },
  },
];
```

Now "billing must not reach into ordering's database repository" isn't a hope in a wiki — it's a failing build.

**Expert Mental Model.** *"Architecture is the art of deciding what to make hard to change and what to keep easy to change. Make decisions reversible by default; make irreversible ones deliberately and document them."* (See [04-architectural-decision-making.md](04-architectural-decision-making.md).)

**Common Mistake.** Framework-driven architecture — letting Next.js's `app/` folder or an ORM's model classes become the domain model, so business rules end up spread across route handlers, React server components, and Prisma middleware.

**Level necessary for professional work.** L3 to structure a service or application well; L4 to set architecture across multiple systems or teams.

---

### 4.5 Database Engineering

**What it actually means.** Designing **data systems that preserve correctness under concurrency, failure, and evolution** — schema design, constraints, indexing, transactions and isolation, migrations, query planning, replication, backups and restore, data lifecycle, and choosing the right storage engine for the access pattern.

**Why it matters.** Data outlives code. You can rewrite a service in a quarter; migrating 4 billion rows of badly modeled data takes a year. Drives **correctness, reliability, recoverability, performance**.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Schema | Mirrors UI forms; nullable everything | Normalized, typed, NOT NULL by default | Schema encodes invariants: CHECK, UNIQUE, FK, exclusion constraints, partial indexes |
| Integrity | Enforced in app code only | App + FKs + unique | Database is the last line of defense for every critical invariant |
| Transactions | Doesn't use them, or wraps everything | Uses them for multi-step writes | Knows isolation level anomalies (lost update, write skew) and picks the level or locking strategy per operation |
| Indexes | None, or one per column | Indexes for known queries | Composite index column order matches predicates; covering indexes; measures write amplification |
| Migrations | `ALTER TABLE` at deploy time, locks prod | Reversible migrations | Expand/contract migrations, zero-downtime, backfills in batches, lock_timeout set |
| Backups | "The cloud does that" | Automated backups | *Tested restores* with measured RTO/RPO |

**How it is developed.**
- Read your database's documentation on concurrency control end to end (for Postgres: the MVCC, transaction isolation, and explicit locking chapters).
- Reproduce anomalies deliberately: open two `psql` sessions and create a lost update, then fix it with `SELECT ... FOR UPDATE` and with `SERIALIZABLE`.
- Run `EXPLAIN (ANALYZE, BUFFERS)` on every non-trivial query you write for a month.
- Do a restore drill: restore last night's backup to a fresh instance and time it.

**Example — banking: preventing negative balances under concurrency.**

Naive (application check):

```ts
const acct = await db.query("SELECT balance_cents FROM accounts WHERE id = $1", [id]);
if (acct.balance_cents >= amount) {
  await db.query("UPDATE accounts SET balance_cents = balance_cents - $1 WHERE id = $2", [amount, id]);
}
// Two concurrent withdrawals of 80 from a balance of 100 both pass the check → balance -60.
```

Expert (defense in depth):

```sql
-- 1. Schema invariant: the database refuses invalid state
ALTER TABLE accounts ADD CONSTRAINT balance_non_negative CHECK (balance_cents >= 0);

-- 2. Ledger, not a mutable balance, as the source of truth
CREATE TABLE ledger_entries (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id      BIGINT NOT NULL REFERENCES accounts(id),
  amount_cents    BIGINT NOT NULL CHECK (amount_cents <> 0),
  idempotency_key TEXT   NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (account_id, idempotency_key)
);

-- 3. Atomic conditional update inside one transaction
BEGIN;
UPDATE accounts
   SET balance_cents = balance_cents - $1
 WHERE id = $2 AND balance_cents >= $1
RETURNING balance_cents;               -- 0 rows → insufficient funds
INSERT INTO ledger_entries (account_id, amount_cents, idempotency_key)
VALUES ($2, -$1, $3);                  -- duplicate retry → unique violation → safe
COMMIT;
```

Plus a nightly reconciliation job asserting `accounts.balance_cents = SUM(ledger_entries.amount_cents)` per account, alerting on any mismatch. See [09-invariants-and-correctness.md](09-invariants-and-correctness.md).

**Expert Mental Model.** *"The database is the only component that sees every write. Put the invariants that must never break where every write must pass through."*

**Common Mistake.** Treating the ORM as the database skill. Knowing Prisma's `update()` is not knowing that it issues a read-modify-write that loses updates under concurrency.

**Level necessary for professional work.** L3. Database skill is disproportionately valuable; most backend production incidents in business software trace to data modeling, migrations, or query behavior.

---

### 4.6 API Design

**What it actually means.** Designing **contracts between components that are hard to misuse, stable under evolution, and honest about failure**. Includes resource modeling, naming, error semantics, pagination, idempotency, versioning, authentication, rate limiting, and backwards compatibility — across REST, GraphQL, gRPC, events, SDKs, and even internal module interfaces.

**Why it matters.** APIs are the most expensive thing to change because *other people's code* depends on them. Drives **usability (developer experience), evolvability, reliability, security**.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Shape | Mirrors database tables | Models resources and actions | Models consumer use cases; hides internal structure |
| Errors | `500` with a stack trace, or `200 {"success": false}` | Correct HTTP status + message | Stable machine-readable error codes, retryability signaled, request IDs, no data leakage |
| Changes | Renames fields, breaks clients | Versions the API | Additive evolution by default; deprecation policy with telemetry on usage of deprecated fields |
| Safety | No idempotency | Idempotent PUT/DELETE | `Idempotency-Key` on all non-idempotent mutations with stored responses |
| Lists | Returns all rows | Offset pagination | Cursor pagination with stable ordering, max page size enforced |
| Contract | Implicit | OpenAPI docs | Contract-first; schema is the source of truth; contract tests in CI |

**How it is developed.**
- Study APIs widely regarded as excellent: Stripe (idempotency, versioning via dated headers, expandable objects), GitHub (pagination via `Link` headers, conditional requests), Twilio.
- Write the client code *before* the server. If calling your API is awkward, the design is wrong.
- Maintain an API that external consumers use; experience a breaking-change incident once.

**Example — payment creation endpoint.**

```http
POST /v1/payments
Idempotency-Key: 3f1c9b2e-8a4d-4c1e-9f7a-1b2c3d4e5f60
Content-Type: application/json

{ "amount": 4999, "currency": "usd", "customer": "cus_123", "payment_method": "pm_456" }
```

Error response (see error envelope in [02-engineering-conventions.md](02-engineering-conventions.md#46-error-handling)):

```json
{
  "error": {
    "type": "card_error",
    "code": "insufficient_funds",
    "message": "The card has insufficient funds to complete the purchase.",
    "retryable": false,
    "request_id": "req_01J8ZK3Q7M2X"
  }
}
```

Server behavior on a retried request with the same `Idempotency-Key` and same body: return the *stored* original response, don't charge twice. With the same key and a *different* body: `409 idempotency_key_reused`.

**Expert Mental Model.** *"An API is a promise to strangers. Design it for the consumer's mistakes, the network's failures, and your own future changes."*

**Common Mistake.** Leaking internals: exposing auto-increment IDs (enumeration attacks, reveals business volume), database column names, or ORM validation messages.

**Level necessary for professional work.** L3 for public or cross-team APIs; L2 is tolerable only for internal endpoints consumed by a single client you control (e.g., a Next.js route handler used by its own frontend) — and even then, error semantics and authorization must be right.

---

### 4.7 Distributed Systems

**What it actually means.** Reasoning about systems where **components communicate over unreliable networks, fail independently, and have no shared clock**. Core concepts: partial failure, consistency models, consensus, replication, partitioning, ordering, exactly-once illusions, clock skew, and the CAP/PACELC trade-offs.

**Why it matters.** Any system with a web client, a database, and one third-party API is already distributed. Drives **reliability, correctness, recoverability**. Bugs here are the hardest class: nondeterministic, load-dependent, and invisible in tests.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Network | Assumes calls succeed or throw | Timeouts and retries | Treats every remote call as {success, failure, *unknown*}; designs for "unknown" |
| Delivery | Assumes events arrive once, in order | Handles duplicates | Designs for at-least-once + idempotent consumers; ordering only where required, by partition key |
| Consistency | Doesn't know there's a choice | Knows eventual vs strong | Chooses consistency per operation; quantifies staleness budget |
| Transactions across services | Hopes both succeed | Uses sagas | Avoids cross-service transactions by drawing boundaries around invariants; outbox pattern for reliable publishing |
| Time | `Date.now()` for ordering across machines | Knows clocks drift | Uses logical clocks, sequence numbers, or database-assigned ordering |

**How it is developed.**
- Read *Designing Data-Intensive Applications* (Kleppmann) with a notebook; reproduce examples.
- Read Jepsen analyses — they show real databases violating their stated guarantees.
- Build a toy: a replicated key-value store with leader election (e.g., follow the MIT 6.824 Raft labs).
- Inject failures in your own systems (kill a consumer mid-batch, add 2s latency with `toxiproxy`) and watch what breaks.

**Example — the dual-write problem (SaaS signup).**

Naive:

```ts
await db.users.insert(user);             // succeeds
await kafka.publish("user.created", user); // process crashes here → billing never creates the customer
```

Expert — transactional outbox:

```sql
BEGIN;
INSERT INTO users (...) VALUES (...);
INSERT INTO outbox (id, aggregate_type, aggregate_id, event_type, payload)
VALUES (gen_random_uuid(), 'user', $1, 'user.created', $2);
COMMIT;
```

A relay (polling or CDC via Debezium) publishes outbox rows and marks them sent. Delivery is at-least-once; the billing consumer deduplicates using the event `id`:

```sql
INSERT INTO processed_events (event_id) VALUES ($1) ON CONFLICT DO NOTHING RETURNING event_id;
-- no row returned → already processed → ack and skip
```

**Expert Mental Model.** *"The network is not a function call. Every remote interaction has three outcomes, and 'I don't know' is the one that corrupts data."* See [07-designing-for-failure.md](07-designing-for-failure.md).

**Common Mistake.** Adopting microservices without distributed systems skill — converting in-process function calls (reliable, fast, transactional) into network calls (unreliable, slow, non-transactional) and gaining nothing.

**Level necessary for professional work.** L2–L3 concepts (timeouts, idempotency, at-least-once, outbox) are necessary for *any* backend developer. Deep consensus/replication knowledge (L4) is needed only when building infrastructure or multi-region systems.

---

### 4.8 Concurrency

**What it actually means.** Reasoning correctly about **multiple things happening at overlapping times** — threads, async tasks, event loops, multiple processes, multiple server instances, multiple users, and multiple browser tabs — and the shared resources they contend for. Covers race conditions, locks, atomicity, deadlocks, starvation, backpressure, and concurrency limits.

**Why it matters.** Concurrency bugs pass every test, then corrupt data at 10× traffic. Drives **correctness and reliability** above all; also **performance** (throughput under parallelism).

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Awareness | "Node is single-threaded so no races" | Knows async interleaving causes races across `await` | Sees races across instances, tabs, retries, webhooks, cron overlaps |
| Tools | None | Mutexes, DB transactions | Chooses between optimistic concurrency, pessimistic locks, atomic ops, queues-as-serialization, CRDTs |
| Parallelism | `Promise.all` over 10,000 items | Batched concurrency | Bounded concurrency matched to downstream capacity; backpressure propagated |
| Locks | Distributed locks with no TTL | Locks with TTL | Avoids distributed locks where a DB constraint or fencing token does the job |
| Testing | None | Manual race reproduction | Deterministic concurrency tests; property-based tests with concurrent schedules |

**How it is developed.**
- Deliberately write race conditions and reproduce them: two HTTP requests at once with `Promise.all([fetch(), fetch()])` against a read-modify-write endpoint.
- Learn the concurrency model of each runtime you use (Node event loop and libuv thread pool, Go goroutines and channels, JVM threads, Postgres MVCC).
- Study classic problems (dining philosophers, producer/consumer) mainly to recognize them in business form.

**Example — WMS double allocation.** Two pickers' handheld scanners allocate the last 5 units of SKU `A-1002` in bin `B-07` at the same moment.

Naive: read `available = 5`, both allocate 5 → `available = -5`, one picker walks to an empty bin.

Expert, optimistic concurrency with a version column:

```sql
UPDATE bin_stock
   SET allocated = allocated + $qty, version = version + 1
 WHERE bin_id = $bin AND sku = $sku
   AND version = $expected_version
   AND on_hand - allocated >= $qty;
-- 0 rows updated → conflict or insufficient → reload and retry, or pick another bin
```

And bounded concurrency on a batch job calling a carrier API limited to 20 req/s:

```ts
import pLimit from "p-limit";
const limit = pLimit(10); // well under the carrier's limit, leaving headroom for other workers
await Promise.all(shipments.map(s => limit(() => carrier.createLabel(s))));
```

**Expert Mental Model.** *"Between every read and every write, assume the world changed. Either make the check-and-act atomic, or detect that it changed."*

**Common Mistake.** Using `Promise.all` on unbounded input — firing 50,000 concurrent requests, exhausting sockets or the database pool, and triggering a rate-limit ban.

**Level necessary for professional work.** L3 for anything touching money, inventory, bookings, or quotas. Concurrency errors in these domains are direct financial loss.

---

### 4.9 Security

**What it actually means.** Designing and building systems that **preserve confidentiality, integrity, and availability against intelligent adversaries**. Not a checklist of OWASP items, but a mindset: identifying trust boundaries, assuming hostile input, minimizing privilege, and making abuse expensive and detectable.

**Why it matters.** Security failures are the only failures where someone is *actively searching* for your bugs. Drives **security, reliability, auditability**, and legal/compliance exposure.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Question | "Does it work?" | "Is input validated? Is it authenticated?" | "How would I abuse this? What's the blast radius if this key leaks?" |
| Authorization | Hides buttons in the UI | Checks role on the server | Checks *object-level* access on every request; tenant scoping enforced by construction (e.g., Postgres RLS) |
| Secrets | In `.env` committed to git | Secret manager | Short-lived credentials, scoped per workload, rotated, access audited |
| Input | Trusts the client | Validates with a schema | Parses at every trust boundary, encodes on output by context, rejects unknown fields |
| Dependencies | `npm install anything` | Runs `npm audit` | Lockfiles, provenance, minimal deps, automated update PRs with CI, reviews install scripts |
| Response | Fixes when reported | Patches quickly | Threat models before building; security tests in CI; audit logs designed for investigation |

**How it is developed.**
- Attack your own applications: use Burp Suite or OWASP ZAP on a staging environment; change IDs in URLs; replay requests with another user's token.
- Do CTFs and PortSwigger Web Security Academy labs.
- Read breach reports and map each to the missing control.
- Threat model every new feature using [templates/threat-model.md](templates/threat-model.md).

**Example — SaaS IDOR (insecure direct object reference) in Next.js.**

Naive:

```ts
// app/api/invoices/[id]/route.ts
export async function GET(_: Request, { params }: { params: { id: string } }) {
  const invoice = await prisma.invoice.findUnique({ where: { id: params.id } });
  return Response.json(invoice); // any logged-in user of ANY tenant can read ANY invoice
}
```

Expert:

```ts
export async function GET(_: Request, { params }: { params: { id: string } }) {
  const session = await requireSession();                        // 401 if absent
  const invoice = await prisma.invoice.findFirst({
    where: { id: params.id, tenantId: session.tenantId },         // tenant scope is non-optional
    select: { id: true, number: true, totalCents: true, status: true }, // explicit projection, no leakage
  });
  if (!invoice) return Response.json({ error: { code: "not_found" } }, { status: 404 }); // 404, not 403: don't confirm existence
  await authorize(session, "invoice:read", invoice);             // policy check (role/ownership)
  return Response.json(invoice);
}
```

Plus a defense-in-depth layer at the database:

```sql
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON invoices
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

**Expert Mental Model.** *"Every boundary will be probed. Security is the property that holds even when every other assumption is wrong."* See [08-security-engineering.md](08-security-engineering.md).

**Common Mistake.** Authentication without authorization — verifying *who* the user is, then letting them access *anything*. Broken object-level authorization is the most common critical API vulnerability.

**Level necessary for professional work.** L3 for anyone writing server code, handling PII, or handling money. There is no "junior tier" of acceptable authorization bugs.

---

### 4.10 Performance Engineering

**What it actually means.** Making systems **fast enough and efficient enough for their users and budget, based on measurement** — defining latency/throughput targets, measuring, profiling, identifying the actual bottleneck, and verifying improvements. Performance is a requirement with numbers, not a feeling.

**Why it matters.** Drives **performance, scalability, cost, usability** (conversion rates fall measurably with latency), and often **reliability** (slow systems exhaust resources and fall over).

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Trigger | "It feels slow" | User complaint or dashboard | SLO burn rate alert; performance budget in CI |
| Method | Guesses and micro-optimizes | Profiles, then fixes | Measure → hypothesis → change → benchmark → compare → keep/revert |
| Metrics | Averages | p95 | p50/p95/p99/max with request rates; distributions, not points; coordinated omission aware |
| Scope | The function they're editing | The service | End-to-end: browser → CDN → edge → app → DB → disk; tail latency amplification across fan-out |
| Fix | Add a cache | Fix query/index | Remove work first, then batch, then cache — each with an invalidation and failure story |

**How it is developed.**
- Learn one profiler per layer deeply: Chrome DevTools Performance panel and React Profiler for the frontend, `clinic.js`/`--cpu-prof` flamegraphs for Node, `EXPLAIN ANALYZE` and `pg_stat_statements` for Postgres.
- Keep a performance journal: every optimization, its hypothesis, and measured before/after.
- Memorize latency numbers (L1 cache ~1ns, same-datacenter round trip ~0.5ms, SSD random read ~0.1ms, cross-continent round trip ~150ms).

**Example — Next.js product listing page with p95 TTFB of 2.8s.**

1. **Measure:** Server timing shows 2.4s in data fetching.
2. **Identify:** `pg_stat_statements` shows 48 queries per request — an N+1 fetching each product's price in a loop.
3. **Hypothesis:** Batching price lookups will cut data time below 300ms.
4. **Change:** Single query with `JOIN prices` and `WHERE product_id = ANY($1)`.
5. **Benchmark:** k6 at 200 VUs — p95 TTFB 2.8s → 410ms.
6. **Compare:** DB CPU down 60%. No correctness diff in snapshot tests.
7. **Keep.** Then consider caching the category page with `revalidate` tags invalidated on price change — as a *second*, separately measured step.

**Expert Mental Model.** *"You cannot optimize what you haven't measured, and you shouldn't optimize what isn't the bottleneck. The fastest code is code that doesn't run."* See [06-performance-engineering.md](06-performance-engineering.md).

**Common Mistake.** Caching as a first resort — hiding an N+1 behind Redis, creating a stale-data bug and a cold-cache outage while the underlying query stays broken.

**Level necessary for professional work.** L2–L3: always measure, understand percentiles, fix N+1s and missing indexes, respect Core Web Vitals. Deep systems-level tuning (L4) is needed for high-scale or latency-critical systems.

---

### 4.11 Testing

**What it actually means.** Building **evidence that the system behaves correctly, and an automated safety net that lets you change it confidently**. It's a strategy question — *which* risks are covered by *which* kind of test at *what* cost — not "write unit tests."

**Why it matters.** Drives **correctness, evolvability, maintainability**, and deployment frequency. Teams without trustworthy tests stop refactoring, then stop improving.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Purpose | Coverage number | Catch regressions | Enable fearless change; document behavior; target risk |
| What's tested | Getters, trivial code | Business logic | Invariants, boundaries, failure paths, concurrency, contracts |
| Mocks | Mocks everything, tests the mocks | Mocks external services | Real database in tests (Testcontainers); fakes over mocks; mocks only at true boundaries |
| Flakiness | Retries until green | Fixes flaky tests | Treats flakiness as a bug in test *or* system; quarantines with ownership and deadline |
| Techniques | Example-based | Example + integration + E2E | Property-based, contract, mutation, snapshot-with-intent, load, chaos tests where risk justifies |
| Speed | Suite takes 40 minutes | Parallelized | Fast feedback tier (< 5 min) gating merges; slow tier nightly |

**How it is developed.**
- Write a test *first* for the next bug you fix; confirm it fails; then fix.
- Run mutation testing (Stryker for TypeScript) on a module you think is well tested. The surviving mutants will humble you.
- Write property-based tests (`fast-check`) for anything with rules: money math, date ranges, state machines.
- Delete tests that never failed and never will; notice what that teaches about test value.

**Example — property-based test for a cart discount invariant.**

```ts
import fc from "fast-check";
import { describe, it, expect } from "vitest";
import { priceCart } from "./pricing";

describe("priceCart", () => {
  it("never produces a negative total and never discounts more than the subtotal", () => {
    fc.assert(
      fc.property(
        fc.array(fc.record({ unitCents: fc.integer({ min: 0, max: 1_000_000 }), qty: fc.integer({ min: 1, max: 100 }) })),
        fc.oneof(
          fc.record({ kind: fc.constant("percent" as const), value: fc.integer({ min: 0, max: 100 }) }),
          fc.record({ kind: fc.constant("fixed" as const), value: fc.integer({ min: 0, max: 10_000_000 }) }),
        ),
        (lines, discount) => {
          const r = priceCart(lines, discount);
          expect(r.totalCents).toBeGreaterThanOrEqual(0);
          expect(r.discountCents).toBeLessThanOrEqual(r.subtotalCents);
          expect(r.subtotalCents - r.discountCents).toBe(r.totalCents);
        },
      ),
    );
  });
});
```

This single test explores thousands of carts, including edge cases (empty cart, 100% discount, fixed discount larger than subtotal) that no one would write by hand.

**Expert Mental Model.** *"Tests are a risk-management portfolio. Spend test effort where failure is most likely and most expensive, and make the suite fast enough that people never skip it."* See [05-quality-engineering.md](05-quality-engineering.md).

**Common Mistake.** Mock-heavy unit tests that assert implementation details (`expect(repo.save).toHaveBeenCalledWith(...)`) — they break on every refactor and pass when the real integration is broken.

**Level necessary for professional work.** L3. You must be able to design a test strategy for your own features and write integration tests against real dependencies.

---

### 4.12 Debugging

**What it actually means.** **Systematically narrowing the gap between what the system does and what you believe it does**, using evidence. It's applied scientific method: observe, hypothesize, design an experiment that splits the hypothesis space, repeat.

**Why it matters.** Drives **recoverability** (mean time to resolve), **reliability** (root causes actually fixed), and velocity. Debugging skill is the largest single productivity multiplier between developers of equal knowledge.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Approach | Changes random things until it works | Reads logs, adds print statements, forms a hypothesis | Bisects the hypothesis space; each experiment eliminates half |
| Reproduction | Skips it | Reproduces locally | Builds minimal reproduction; captures production state (traces, core dumps, request replay) |
| Assumptions | Trusts "that part definitely works" | Verifies suspicious assumptions | Verifies *every* assumption on the path, especially "obvious" ones |
| Tools | `console.log` | Debugger, logs | Debugger, `git bisect`, distributed traces, `strace`/`tcpdump`, DB logs, heap snapshots |
| End state | Symptom disappears | Root cause fixed | Root cause fixed + regression test + detection added + class of bug prevented |

**How it is developed.**
- Keep a debugging log: symptom, hypotheses tried, what the cause was, and how you could have found it faster.
- Use `git bisect run` at least once on a real regression.
- Practice reading stack traces, flamegraphs, and query plans without help.
- Pair with an expert debugger and watch the *order* in which they check things.

**Example — intermittent 502s in a Node API behind an AWS ALB, ~0.3% of requests.**

1. **Observe:** 502s correlate with low traffic periods, not high. Not load-related.
2. **Hypothesis space:** app crash? ALB? Keep-alive mismatch? DNS?
3. **Split:** App logs show no errors for those request IDs → requests never reached the handler.
4. **Narrow:** ALB idle timeout = 60s; Node's `server.keepAliveTimeout` default = 5s. Node closes idle connections the ALB believes are open; ALB reuses one → 502.
5. **Fix:** `server.keepAliveTimeout = 65_000; server.headersTimeout = 66_000;`
6. **Prevent:** Add to the service template ([10-knowledge-into-systems.md](10-knowledge-into-systems.md)) and a runbook entry.

**Expert Mental Model.** *"The bug is in the assumption you're most confident about. Don't guess; design experiments that cut the search space in half."*

**Common Mistake.** Fixing the symptom — adding a retry around a failing call without understanding why it fails, turning a visible bug into a hidden, load-amplifying one.

**Level necessary for professional work.** L3. You must be able to debug production issues with logs, traces, and metrics, not only local reproduction.

---

### 4.13 DevOps

**What it actually means.** DevOps is not a job title or a tool; it is the practice of **making the path from commit to production fast, safe, repeatable, and owned by the people who write the code**. Covers CI/CD, build reproducibility, deployment strategies, environment parity, release management, rollback, and on-call ownership.

**Why it matters.** Drives **operability, reliability, recoverability**, and delivery speed. The DORA research consistently links deployment frequency, lead time, change failure rate, and time-to-restore with organizational performance — high performers deploy more often *and* fail less.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Deployment | Manual SSH/FTP, Friday nights | CI/CD pipeline to prod | Continuous delivery with progressive rollout, automated rollback on SLO regression |
| Builds | "Works on my machine" | Dockerized | Reproducible, pinned, cached builds; same artifact promoted across environments |
| Rollback | Revert and pray | Documented rollback | Rollback is a one-click, tested, routine operation; DB migrations are backward-compatible so rollback is always safe |
| Config | Hardcoded per environment | Env vars | Config validated at startup; feature flags decouple deploy from release |
| Ownership | "Ops will handle it" | Team is on call | Team owns SLOs, runbooks, and error budgets for their services |

**How it is developed.**
- Build a pipeline from scratch for a side project: lint → typecheck → test → build → deploy preview → deploy production → smoke test → rollback.
- Measure your own DORA metrics for a month.
- Practice a rollback when nothing is broken.

**Example — GitHub Actions pipeline for a Next.js app with gated deploy.**

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_PASSWORD: postgres }
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 5s --health-timeout 5s --health-retries 10
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version-file: .nvmrc, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm typecheck
      - run: pnpm db:migrate
        env: { DATABASE_URL: postgres://postgres:postgres@localhost:5432/postgres }
      - run: pnpm test -- --coverage
        env: { DATABASE_URL: postgres://postgres:postgres@localhost:5432/postgres }
      - run: pnpm build

  deploy:
    needs: verify
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production        # requires approval rules / protected environment
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh --strategy=canary --percent=10
      - run: ./scripts/smoke-test.sh https://app.example.com
      - run: ./scripts/promote-or-rollback.sh --slo-window=10m
```

**Expert Mental Model.** *"Deployment should be boring. If it's scary, deploy more often in smaller pieces until it isn't."*

**Common Mistake.** Coupling deploy and release: merging a half-finished feature means it's live. Feature flags and backward-compatible migrations decouple them.

**Level necessary for professional work.** L2–L3: every engineer should be able to understand, modify, and debug their CI/CD pipeline and perform a rollback.

---

### 4.14 Cloud / Infrastructure

**What it actually means.** Designing and managing **the compute, network, storage, and identity foundations** that software runs on — with attention to reliability, security, cost, and reproducibility. Includes networking (VPCs, DNS, TLS, load balancers), IAM, managed services selection, infrastructure as code, capacity, and cost management.

**Why it matters.** Drives **reliability, security, scalability, cost, recoverability**. Misconfigured infrastructure is behind a large share of data breaches (public buckets, over-privileged IAM) and outages (single-AZ databases, expired certificates).

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Provisioning | Console click-ops | Terraform/Pulumi for main resources | Everything in code, reviewed, with drift detection; no human write access to prod by default |
| Choice | Most powerful/popular service | Managed services where sensible | Chooses the least operationally expensive option that meets requirements; knows exit costs |
| IAM | `AdministratorAccess` | Role per service | Least privilege, scoped per workload, short-lived credentials via OIDC, no long-lived keys |
| Reliability | Single instance | Multi-AZ | Failure domains mapped; tested failover; dependencies on control planes minimized |
| Cost | Surprise bill | Budgets and alerts | Unit economics (cost per tenant/order), tagging, rightsizing, reserved capacity decisions |

**How it is developed.**
- Build and destroy an environment entirely from code; repeat until `terraform destroy && terraform apply` is uneventful.
- Read your cloud provider's Well-Architected Framework pillars.
- Trace a single request through DNS → CDN → load balancer → container → database and name every hop.
- Audit IAM policies of an existing account and reduce them.

**Example — OIDC deploy credentials instead of long-lived keys (Terraform + GitHub Actions + AWS).**

```hcl
resource "aws_iam_role" "deploy" {
  name = "gh-deploy-web-prod"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:acme/web:environment:production" }
      }
    }]
  })
}
```

No AWS secret keys exist in GitHub. Only the `production` environment of the `acme/web` repo can assume this role, and the credentials expire in an hour.

**Expert Mental Model.** *"Infrastructure is code with a blast radius. Prefer boring, managed, reproducible, and least-privileged — and know what happens when each piece disappears."*

**Common Mistake.** Adopting Kubernetes for a single small application because it is industry standard — taking on a full-time platform-operations burden without the scale that justifies it.

**Level necessary for professional work.** L2 for application developers (understand deploy target, env config, IAM basics, networking basics). L3–L4 for anyone owning production infrastructure.

---

### 4.15 Observability

**What it actually means.** The ability to **answer arbitrary questions about what your system is doing in production — especially questions you didn't anticipate — without shipping new code**. Built from structured logs, metrics, distributed traces, profiles, and events, tied together by correlation IDs and meaningful dimensions (tenant, route, version, region).

**Why it matters.** Drives **operability, reliability, recoverability**. Without observability, incidents are resolved by guessing, and performance work is done blind. The mean time to detect and resolve issues is mostly an observability problem.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Logs | `console.log("here")`, unstructured strings | Structured JSON logs with levels | Structured, correlated (trace_id), PII-safe, sampled wisely, with high-cardinality fields for debugging |
| Metrics | CPU and memory | RED (rate, errors, duration) per endpoint | SLIs tied to user journeys; SLOs with error budgets; business metrics (orders/min) alongside technical ones |
| Traces | None | APM auto-instrumentation | OpenTelemetry end-to-end including queues and background jobs; spans annotated with domain attributes |
| Alerts | Alerts on everything → alert fatigue | Alerts on symptoms | Alerts on SLO burn rate; every alert is actionable and linked to a runbook |
| Questions answered | "Is the server up?" | "Which endpoint is slow?" | "Why are checkout failures elevated for tenants on plan X using payment method Y since deploy v412?" |

**How it is developed.**
- Instrument a service with OpenTelemetry; view a trace spanning HTTP → DB → queue → worker.
- During every bug investigation, note which question you *couldn't* answer from telemetry; add that instrumentation.
- Define SLOs for a real service and review them weekly for a month.
- Read Google's SRE book chapters on monitoring and alerting.

**Example — structured, correlated log in a Node payment service (pino).**

```ts
logger.info({
  event: "payment.capture.succeeded",
  trace_id: span.spanContext().traceId,
  request_id: req.id,
  tenant_id: ctx.tenantId,
  payment_id: payment.id,
  amount_cents: payment.amount,
  currency: payment.currency,
  processor: "stripe",
  processor_latency_ms: elapsed,
  attempt: attempt,
  service_version: process.env.GIT_SHA,
}, "payment captured");
```

With this, "p99 processor latency by processor and version for tenant T in the last hour" is a query, not a code change.

SLO-based alert (Prometheus multi-window burn rate):

```yaml
- alert: CheckoutAvailabilityFastBurn
  expr: |
    (
      sum(rate(http_requests_total{route="/api/checkout",status=~"5.."}[5m]))
      / sum(rate(http_requests_total{route="/api/checkout"}[5m]))
    ) > (14.4 * 0.001)
    and
    (
      sum(rate(http_requests_total{route="/api/checkout",status=~"5.."}[1h]))
      / sum(rate(http_requests_total{route="/api/checkout"}[1h]))
    ) > (14.4 * 0.001)
  for: 2m
  labels: { severity: page }
  annotations:
    summary: "Checkout burning 99.9% SLO error budget 14x too fast"
    runbook: "https://runbooks.example.com/checkout-availability"
```

**Expert Mental Model.** *"If I can't see it, I can't operate it. Instrument for the questions I'll ask at 3 a.m., not the ones I can think of now."*

**Common Mistake.** Logging volume instead of logging value — gigabytes of `DEBUG` noise, no request IDs, and the one field you need (tenant, version, idempotency key) missing.

**Level necessary for professional work.** L3 for anyone on call. At minimum: structured logs with correlation IDs, RED metrics, and one actionable alert per critical user journey.

---

### 4.16 Product Engineering

**What it actually means.** Building **the right thing, not just building the thing right** — understanding users, business goals, and economics well enough to shape requirements, propose simpler solutions, choose scope, and measure whether shipped work achieved its purpose.

**Why it matters.** Drives **usability** and the value of every other quality attribute. A perfectly engineered feature nobody uses is pure cost: maintenance, surface area, security exposure.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Input | Implements the ticket literally | Clarifies ambiguous requirements | Challenges the requirement: "What outcome do you want? Could we get 80% with 10% of the work?" |
| Scope | Everything in the spec | Prioritized scope | Smallest shippable slice that tests the riskiest assumption |
| Success | "Merged" | "Released" | "The metric moved" — defines instrumentation before building |
| Trade-offs | Hidden from stakeholders | Communicated | Framed in business terms: cost, risk, time-to-value, reversibility |
| Users | Imagined | Occasionally consulted | Watches session recordings, reads support tickets, talks to users |

**How it is developed.**
- Read support tickets for your product weekly.
- Before each feature, write the one-line hypothesis: "We believe X will cause Y, measured by Z."
- Ship something small, measure it, and kill it if it didn't work.
- Learn basic unit economics of your business (CAC, LTV, gross margin, cost per transaction).

**Example — B2B SaaS "export to PDF" request.** Sales asks for fully customizable PDF report exports; estimate is 6 weeks (headless Chrome rendering, template builder, storage).

Expert product engineer asks: *who* needs it and *why*? Answer: finance teams at 3 enterprise prospects need to attach monthly usage reports to invoices for audit. Proposal: a fixed, well-designed printable report page (Next.js route with `@media print` CSS) plus a CSV export — 4 days. Instrument usage. Two of three prospects sign; the third needs a logo, added in half a day. The 6-week template builder never gets built, and nobody misses it.

**Expert Mental Model.** *"Code is a liability; outcomes are the asset. The best feature is often a smaller one, and the best code is often none."*

**Common Mistake.** Gold-plating — adding configurability, edge-case handling, and abstractions for requirements nobody stated, delaying feedback on the core assumption.

**Level necessary for professional work.** L2–L3 for all engineers; critical (L3–L4) for solo developers and small-team engineers who have no product manager buffering them from ambiguity (see [11-solo-developer-multiple-projects.md](11-solo-developer-multiple-projects.md)).

---

### 4.17 Domain Modeling

**What it actually means.** **Capturing the concepts, rules, language, and invariants of a business domain in software** so that code structure mirrors how the business actually works. Includes identifying entities, value objects, aggregates, state machines, events, bounded contexts, and a ubiquitous language shared with domain experts.

**Why it matters.** Drives **correctness, maintainability, evolvability**. When the model is wrong, every feature fights it: business rules scatter, special cases pile up, and "simple" changes touch 30 files.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Model source | Database tables or UI screens | Business entities | Business *behaviors*, rules, events, and invariants — discovered with domain experts |
| Language | Code terms (`status_flag_2`) | Business-ish terms | Ubiquitous language: code, docs, and conversations use identical terms with identical meanings |
| Rules | Scattered in controllers, UI, SQL | Service layer | Encapsulated in domain objects/aggregates that cannot be put in invalid states |
| States | Booleans (`isPaid`, `isShipped`, `isCancelled`) | Status enum | Explicit state machine with legal transitions and transition side effects |
| Same word, different meaning | One `Product` model for everything | Notices tension | Bounded contexts: `Product` in Catalog ≠ `StockItem` in Warehouse ≠ `LineItem` in Billing |

**How it is developed.**
- Interview domain experts (warehouse supervisors, accountants, support staff) and write a glossary; notice where people use the same word differently.
- Run an Event Storming session: list domain events in orange sticky notes on a timeline.
- Model a domain as a state machine before writing code.
- Read *Domain-Driven Design Distilled* (Vernon) and *Domain Modeling Made Functional* (Wlaschin).

**Example — WMS order fulfillment state machine.**

Naive: `orders` table with `is_picked`, `is_packed`, `is_shipped`, `is_cancelled` booleans. Result: orders that are both cancelled and shipped; nobody knows whether a picked order can be cancelled.

Expert:

```ts
type FulfillmentState =
  | "received" | "allocated" | "picking" | "picked"
  | "packed" | "shipped" | "delivered" | "cancelled" | "exception";

const transitions: Record<FulfillmentState, readonly FulfillmentState[]> = {
  received:  ["allocated", "cancelled"],
  allocated: ["picking", "cancelled"],          // cancel releases allocation
  picking:   ["picked", "exception"],           // cannot cancel mid-pick; must resolve first
  picked:    ["packed", "exception"],
  packed:    ["shipped", "exception"],
  shipped:   ["delivered", "exception"],
  delivered: [],
  cancelled: [],
  exception: ["allocated", "cancelled"],        // supervisor resolution
};

export function transition(from: FulfillmentState, to: FulfillmentState): FulfillmentState {
  if (!transitions[from].includes(to)) {
    throw new IllegalTransitionError(from, to);
  }
  return to;
}
```

Backed by a database guard:

```sql
CREATE TABLE fulfillment_transitions (
  from_state TEXT NOT NULL,
  to_state   TEXT NOT NULL,
  PRIMARY KEY (from_state, to_state)
);
-- A trigger on orders rejects UPDATEs whose (OLD.state, NEW.state) pair isn't in this table.
```

And every transition emits a domain event (`OrderPicked`, `OrderShipped`) to an audit table — because warehouses get asked "who moved this and when?"

**Expert Mental Model.** *"The domain model is a theory of the business. When the code feels awkward, the theory is wrong — go back to the domain experts, not to a new framework."* See [09-invariants-and-correctness.md](09-invariants-and-correctness.md).

**Common Mistake.** Anemic domain models — "entities" that are just bags of getters/setters, with all rules duplicated across API handlers, background jobs, and admin scripts that each enforce them slightly differently.

**Level necessary for professional work.** L3 for business-critical systems (finance, logistics, healthcare, marketplaces). Lower complexity CRUD apps need less, but still need explicit state machines where states exist.

---

### 4.18 Code Review

**What it actually means.** **A quality gate and a knowledge-distribution mechanism** — verifying that a change is correct, safe, understandable, and consistent with the system's design, while spreading context across the team. It is also the skill of *receiving* review productively and of *authoring* reviewable changes.

**Why it matters.** Drives **correctness, security, maintainability, consistency**, and reduces bus factor. Poor review is either a rubber stamp (no protection) or a bottleneck (no velocity).

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Focus | Style, formatting, naming nits | Logic bugs, test coverage | Design fit, invariants, failure modes, security, operability, what's *missing* |
| Automation | Humans comment on formatting | Linters handle style | Everything automatable is automated; humans review only what requires judgment |
| Tone | Vague ("this is weird") or harsh | Specific | Specific, labeled by severity (`blocking:`, `nit:`, `question:`), explains *why*, suggests alternatives |
| As author | 2,000-line PRs | Focused PRs with description | Small stacked PRs; description explains intent, risks, testing, rollout, and rollback |
| Speed | Reviews sit for days | Same-day turnaround | Review latency is a tracked team metric |

**How it is developed.**
- Use a written review checklist until it's internalized (see [templates/pull-request.md](templates/pull-request.md)).
- Review code in open-source projects you depend on.
- After each production incident, ask: "What would a reviewer have needed to notice to prevent this?" Add that to the checklist.
- Ask for review of your reviews from a senior engineer.

**Example — reviewing a "simple" PR adding a webhook handler for Stripe `invoice.paid`.**

Expert review comments:

```text
blocking: The handler verifies the signature (good) but isn't idempotent. Stripe delivers
at-least-once; a retry will extend the subscription twice. Suggest recording event.id in
processed_webhook_events with a unique constraint inside the same transaction.

blocking: We return 500 when our DB is slow, which triggers Stripe retries with backoff for up
to 3 days — fine — but we also do the heavy provisioning work inline. If provisioning takes
>10s Stripe times out and retries while the first attempt is still running. Suggest: persist
event, return 200, process asynchronously.

question: Events can arrive out of order (invoice.paid before customer.subscription.updated).
Does provisioning depend on subscription state being current? If so, fetch the latest object
from the API instead of trusting the payload.

suggestion: Add structured log with event.id, event.type, tenant_id so we can trace a customer
complaint to a specific delivery.

nit: `handleIt` → `handleInvoicePaid`.
```

**Expert Mental Model.** *"Review the change as the system will experience it: under retries, concurrency, bad input, partial failure, and the next developer's misunderstanding."*

**Common Mistake.** Spending review attention on formatting and naming while approving missing authorization checks, because humans are doing the linter's job.

**Level necessary for professional work.** L3 to be a trusted approver on production code.

---

### 4.19 Technical Leadership

**What it actually means.** **Multiplying the effectiveness of other engineers and aligning technical work with business goals** — setting direction, making and communicating decisions, creating standards, unblocking people, growing skills, managing technical risk, and building consensus without necessarily having authority.

**Why it matters.** Beyond a certain size, system quality is limited not by individual skill but by *coordination*: consistent decisions, shared understanding, and managed debt. Drives **maintainability, evolvability**, and team throughput.

| | Inexperienced | Senior | Expert (Staff/Principal) |
|---|---|---|---|
| Impact | Own tasks | Own features/services | Multiple teams/systems; the organization's technical trajectory |
| Decisions | Makes them alone, implicitly | Documents and discusses | Designs *decision processes*; knows which decisions to make, delegate, or defer |
| Standards | Enforces personal preferences | Proposes team conventions | Creates paved roads so the right way is the easy way |
| Conflict | Wins arguments | Seeks agreement | Disagrees and commits; separates reversible from irreversible decisions and argues only about the latter |
| Debt | Complains about it | Fixes it opportunistically | Quantifies it, ties it to business risk, and gets it prioritized |
| Growth | Answers questions | Mentors | Builds systems (docs, templates, review culture) that grow engineers without them |

**How it is developed.**
- Write and drive an RFC to adoption across people who don't report to you.
- Lead an incident response and its postmortem ([templates/postmortem.md](templates/postmortem.md)).
- Mentor a junior engineer for six months; measure their growth.
- Read *Staff Engineer* (Larson) and *The Staff Engineer's Path* (Reilly).

**Example — standardizing error handling across 6 services.** Inconsistent error formats cause the Next.js frontend to have 6 different error parsers and poor user messaging.

- **Weak leadership:** Posts "everyone please use this format" in Slack. Adoption: 1 of 6 services.
- **Expert leadership:** Writes an ADR with examples and rationale; builds a tiny `@acme/errors` package with `AppError` classes and an Express/Next.js middleware; adds a contract test in the shared CI template that validates error responses against a JSON schema; migrates the first service personally, pairs on the second; tracks adoption on a dashboard; retires the frontend's legacy parsers when adoption reaches 100%. See [10-knowledge-into-systems.md](10-knowledge-into-systems.md).

**Expert Mental Model.** *"My output is the output of the systems and people I influence. Make good decisions cheap to make and bad decisions hard to make."*

**Common Mistake.** Mistaking technical leadership for being the best coder — becoming the bottleneck who reviews every PR and makes every decision, rather than scaling judgment through others.

**Level necessary for professional work.** L2 elements (clear communication, owning outcomes) are needed by everyone. L3–L4 for tech leads; for solo developers, leadership becomes self-leadership: decision logs, standards, and prioritization discipline.

---

### 4.20 Documentation

**What it actually means.** **Transferring understanding across time and people at lower cost than rediscovery**. The right documentation types for the right audiences: READMEs (how to run), ADRs (why decisions were made), design docs (how something will work), runbooks (what to do when it breaks), API references (how to use), onboarding guides, and inline comments explaining *why*, not *what*.

**Why it matters.** Drives **maintainability, operability, recoverability**, and onboarding speed. For a solo developer juggling multiple projects, documentation *is* the memory (see [11-solo-developer-multiple-projects.md](11-solo-developer-multiple-projects.md)).

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Amount | None, or a wiki novel that's outdated | README + API docs | Minimal, high-value, typed documentation (Diátaxis: tutorials, how-tos, reference, explanation) |
| Content | Describes *what* the code does | Describes how to use | Captures *why*, constraints, rejected alternatives, and operational knowledge |
| Location | Separate wiki that drifts | In repo | Docs-as-code next to what they describe; generated where possible (OpenAPI, schema docs); checked in CI (links, examples compile) |
| Maintenance | Written once | Updated occasionally | Doc changes required in the PR that changes the behavior (Definition of Done) |
| Comments | `// increment i` | Explains complex logic | Explains non-obvious *why*: `// Carrier API rejects weights with >2 decimals; round here, not in UI.` |

**How it is developed.**
- Write a runbook for a service, then hand it to someone else during a staged incident and watch where they get stuck.
- Write ADRs for your next five decisions.
- Try onboarding onto one of your own projects after 3 months away using only its docs.

**Example — a useful README section vs a useless one.**

Useless:

```md
## Setup
Install dependencies and run the app.
```

Useful:

```md
## Local development

Prerequisites: Node 20 (see `.nvmrc`), pnpm 9, Docker.

    pnpm install
    cp .env.example .env.local        # all vars documented in src/config/env.ts
    docker compose up -d postgres redis
    pnpm db:migrate && pnpm db:seed   # seed creates tenant "acme" / user admin@acme.test / password "local-only"
    pnpm dev                          # http://localhost:3000

Common problems:
- `ECONNREFUSED 5432` → Docker isn't running or port 5432 is used by a local Postgres.
- Stripe webhooks locally: `stripe listen --forward-to localhost:3000/api/webhooks/stripe`

Architecture overview: docs/architecture.md · Decisions: docs/adr/ · Runbooks: docs/runbooks/
```

**Expert Mental Model.** *"Document the things that are expensive to rediscover: decisions, constraints, operational procedures, and the reason something looks wrong but is right."*

**Common Mistake.** Documenting *what* the code does (which rots and which the code already says) instead of *why* (which the code can never say).

**Level necessary for professional work.** L3. At minimum: a runnable README, ADRs for significant decisions, runbooks for production services.

---

### 4.21 Technical Decision-Making

**What it actually means.** **Choosing between options under uncertainty, with incomplete information, in a way that is explicit, proportional, reversible where possible, and reviewable later**. It is the meta-skill that governs how every other skill gets applied.

**Why it matters.** Every system is the accumulated result of thousands of decisions. Drives *all* quality attributes, but especially **evolvability** and **cost**. Bad decision-making manifests as fashion-driven stacks, analysis paralysis, and repeatedly relitigating settled questions.

| | Inexperienced | Senior | Expert |
|---|---|---|---|
| Basis | Familiarity, hype, what a blog used | Experience and comparison | Requirements, constraints, trade-offs, cost, risk, reversibility — explicit |
| Speed | Either instant or paralyzed | Deliberate | Proportional: fast for reversible (two-way door) decisions, rigorous for irreversible (one-way door) ones |
| Options | One option considered | 2–3 options | Includes "do nothing" and "buy/managed" as options; identifies what evidence would change the decision |
| Record | None | Discussed in meetings | ADR with context, options, decision, consequences, and revisit triggers |
| Hindsight | Blames circumstances | Reflects occasionally | Reviews decision *quality* separately from outcome quality (good decisions can have bad outcomes) |

**How it is developed.**
- Write an ADR for every non-trivial decision ([templates/adr.md](templates/adr.md)); set a calendar reminder to review it in 6 months.
- Practice pre-mortems: "It's a year from now and this decision failed. Why?"
- Explicitly classify decisions as one-way or two-way doors before debating them.
- Build tiny spikes to buy information cheaply before committing.

**Example — choosing a job queue for a SaaS app on Postgres.**

```text
Requirement:   Send ~50k emails/day, run nightly billing, retry failures, no lost jobs.
Constraints:   Solo developer; already running Postgres; low ops budget; ~99.9% target.
Options:       (a) Postgres-backed queue (pg-boss / graphile-worker)  (b) Redis + BullMQ
               (c) AWS SQS + Lambda  (d) Kafka
Trade-offs:    (a) transactional enqueue with business writes, no new infra, fine to ~1k jobs/s
               (b) fast, rich features, new stateful infra to operate, not transactional with DB
               (c) managed and scalable, more moving parts, vendor coupling, local dev harder
               (d) massive overkill; high ops cost
Cost:          (a) ~$0 extra  (b) +$30–100/mo + ops  (c) low $ but higher complexity  (d) high
Risk:          (a) Postgres load if volume grows 50x — mitigated by monitoring queue depth
Reversibility: High — jobs are behind a small `enqueue()` interface
Decision:      (a) graphile-worker. Revisit trigger: sustained > 300 jobs/s or queue lag p95 > 60s.
```

**Expert Mental Model.** *"Make the decision at the last responsible moment, with the evidence available, record why, and define what would make you change your mind."* See [04-architectural-decision-making.md](04-architectural-decision-making.md).

**Common Mistake.** Resume-driven development — choosing a technology because it is interesting or career-enhancing, then the team pays its operational cost for years.

**Level necessary for professional work.** L3 for decisions within a service; L4 for decisions spanning systems or organizations. Solo developers need L3–L4 because there's nobody else to catch a bad decision.

---

## 5. Tool Knowledge vs Engineering Ability

### What

- **Tool knowledge** is knowing *what a specific technology does and how to operate it*: APIs, syntax, configuration flags, CLI commands, framework conventions.
- **Engineering ability** is knowing *what the system needs and why*, independent of any tool: invariants, boundaries, failure modes, trade-offs, data flow, and how to verify behavior.

Tool knowledge answers **"How do I do X in Y?"**
Engineering ability answers **"Should we do X at all? What happens when X fails? What must remain true while X happens?"**

### Why the distinction matters

1. **Tools change every few years; engineering fundamentals change every few decades.** Transactions, idempotency, caching trade-offs, and least privilege were as true in 1995 as today.
2. **Tool knowledge is now cheap.** Documentation, search, and AI assistants can produce correct API usage in seconds. Engineering judgment — knowing that the generated code has a race condition — is not cheap. See [13-ai-and-agents.md](13-ai-and-agents.md).
3. **Hiring and self-assessment get distorted.** A list of 25 technologies says little about whether someone can design a system that doesn't lose money under retries.
4. **Tool-first thinking produces framework-driven architecture** — where the shape of the system is dictated by a library's tutorials rather than the domain (see [17-common-failure-modes.md](17-common-failure-modes.md)).

### How to recognize the difference

Ask a question that the tool's documentation doesn't answer.

| Question | Tool-knowledge answer | Engineering-ability answer |
|---|---|---|
| "How do you prevent duplicate orders?" | "Disable the submit button after click." | "The button helps UX, but the guarantee must be server-side: client-generated idempotency key, unique constraint, stored response replay. Networks retry; users open two tabs." |
| "How do you make this page faster?" | "Use `React.memo` and `useMemo`." | "Measure first. Is it TTFB, JS execution, hydration, or layout shift? The flamegraph says 70% is a 900KB charting library loaded on first paint — lazy-load it." |
| "How do you secure this API?" | "Add JWT middleware." | "Authentication proves identity; the vulnerability class that matters is object-level authorization. Every query is tenant-scoped; RLS as a backstop; tests that try cross-tenant access." |
| "How do you handle a failing third-party API?" | "Wrap it in try/catch and retry." | "Timeout budget smaller than our own SLO, retries only for idempotent calls with jittered backoff, circuit breaker, a degraded mode, and an alert when fallback rate exceeds 5%." |
| "Should we use Kafka?" | "Yes, it's scalable." | "What's the event volume, ordering need, retention need, and who operates it? At 20 events/sec with a single consumer, a Postgres outbox + worker is simpler and transactional." |

### Contrast pairs

These pairs illustrate the gap. The left side is valuable — but insufficient.

**Frontend (React / Next.js)**

> Knowing React is not the same as knowing how to architect a frontend.

| Tool knowledge | Engineering ability |
|---|---|
| Knows hooks, context, Server Components, `use client` | Decides where state lives: server state (cached, refetched) vs URL state (shareable, back-button safe) vs local UI state vs global client state — and why mixing them causes bugs |
| Knows `fetch` with `revalidate` in Next.js | Designs a cache invalidation strategy tied to domain events; knows which data may be stale for 60s (catalog) and which may never be (cart total, stock at checkout) |
| Knows how to build a form with React Hook Form + Zod | Knows client validation is UX only; shares the Zod schema with the server action but still re-validates and authorizes server-side; handles double submits and optimistic updates rollback |
| Knows Tailwind and a component library | Builds a design system with tokens, accessible primitives, and composition rules so 40 screens stay consistent |
| Can make a component render | Designs component boundaries to minimize client JS, isolate re-renders, and keep the server/client boundary intentional |
| Knows `next/image` | Sets performance budgets (LCP < 2.5s, INP < 200ms, CLS < 0.1) and fails CI when exceeded |

**Databases (PostgreSQL)**

> Knowing PostgreSQL syntax is not the same as knowing how to design a reliable data system.

| Tool knowledge | Engineering ability |
|---|---|
| Writes `JOIN`s, CTEs, window functions | Designs schemas where invariants are constraints, not comments |
| Knows `CREATE INDEX` | Knows index column order, partial indexes, write amplification, and when an index won't be used |
| Knows `BEGIN/COMMIT` | Knows which anomalies `READ COMMITTED` allows and designs each critical write accordingly |
| Knows `pg_dump` | Has a tested restore procedure with measured RTO/RPO and point-in-time recovery |
| Knows `ALTER TABLE` | Runs expand/contract migrations on a 500M-row table without downtime |
| Knows Prisma/Drizzle APIs | Knows the SQL those APIs emit and when it's wrong |

**Backend (Node.js)**

> Knowing Node.js is not the same as knowing how to design a resilient backend.

| Tool knowledge | Engineering ability |
|---|---|
| Knows Express/Fastify/NestJS routing | Designs the request lifecycle: auth → validation → authorization → domain → persistence → events → response, with consistent errors at each step |
| Knows `async/await` | Knows that an `await` is a point where other requests interleave; designs atomic operations |
| Knows `setTimeout`, workers | Designs graceful shutdown: stop accepting, drain in-flight requests, finish or requeue jobs, close pools |
| Knows `axios` | Sets timeouts, retry policy, circuit breaking, connection reuse, and propagates deadlines |
| Knows `process.env` | Validates config at startup and fails fast with clear errors |

**Infrastructure and operations**

| Tool knowledge | Engineering ability |
|---|---|
| Knows Docker and Kubernetes manifests | Knows what liveness vs readiness probes should actually check, and how a bad probe causes cascading restarts |
| Knows Terraform syntax | Designs state isolation, blast radius per workspace, and safe apply workflows |
| Knows how to set up Datadog/Grafana | Defines SLIs that reflect user experience and alerts that are actionable |
| Knows GitHub Actions YAML | Designs a pipeline whose gates correspond to real risks, runs under 10 minutes, and supports instant rollback |
| Knows Redis commands | Knows Redis is not durable by default, knows eviction policies, and never makes it the source of truth for money |

**Security**

| Tool knowledge | Engineering ability |
|---|---|
| Knows how to configure NextAuth/Auth.js, Clerk, or Cognito | Knows session fixation, token lifetime trade-offs, refresh token rotation, and where authorization decisions belong |
| Knows `bcrypt` | Knows password storage is one control among many: rate limiting, credential stuffing defense, MFA, breach detection |
| Knows `helmet()` | Knows what each header mitigates and designs a CSP that doesn't need `unsafe-inline` |

**Testing**

| Tool knowledge | Engineering ability |
|---|---|
| Knows Jest/Vitest/Playwright APIs | Designs a test portfolio mapped to risk: what fails most expensively, and what's the cheapest test that catches it |
| Can mock modules | Knows when mocks make tests lie and uses real dependencies (Testcontainers) instead |

### The layered relationship

Tool knowledge is not useless — it is the **execution layer** of engineering ability.

```text
Engineering ability  →  decides WHAT must be true and WHY
        │
        ▼
Design/architecture  →  decides WHERE and HOW it is enforced
        │
        ▼
Tool knowledge       →  implements it correctly and efficiently in a specific technology
```

An engineer with ability but weak tool knowledge is slow for a few weeks. An engineer with tool knowledge but weak ability is fast until production, then expensive for years.

### Example — same requirement, two engineers, same stack

**Requirement (logistics SaaS):** "Customers can upload a CSV of up to 50,000 shipments to create them in bulk."

**Tool-knowledge implementation (Next.js route handler):**

```ts
export async function POST(req: Request) {
  const text = await req.text();
  const rows = parse(text);                  // loads entire file into memory
  for (const row of rows) {
    await prisma.shipment.create({ data: row }); // 50,000 sequential inserts, no validation
  }
  return Response.json({ ok: true });         // request times out at 60s on the platform
}
```

Problems: platform timeout, memory spikes, partial imports with no way to know which rows succeeded, re-upload creates duplicates, no validation, no per-tenant limits, no progress.

**Engineering-ability implementation:**

1. **Upload** directly to object storage via presigned URL (file never passes through the app server).
2. **Create an `import_jobs` row** (`status: pending`, `tenant_id`, `file_key`, `checksum`). Unique on `(tenant_id, checksum)` → the same file can't be imported twice accidentally.
3. **Worker** streams the CSV, validates each row with a Zod schema, writes in batches of 500 inside transactions, and upserts on `(tenant_id, external_reference)` for idempotency.
4. **Row-level results** stored in `import_job_errors` (row number, field, code) so the UI can show "49,812 created, 188 rejected — download error report."
5. **Progress** exposed via polling endpoint; the Next.js page shows a progress bar.
6. **Limits:** max file size, max rows, per-tenant concurrency of 1 import.
7. **Observability:** job duration, rows/sec, rejection rate metrics; logs include `import_job_id`.
8. **Tests:** a 50k-row fixture in CI's slow tier; a test that re-running a partially completed job produces no duplicates.

Same tools. Entirely different system.

### Expert Mental Model

> "Tools are how I express a decision. They are never the decision. If I can't describe the solution without naming a product, I don't understand the problem yet."

### Common Mistake

Measuring growth by *number of technologies learned*. The fastest path to seniority is to go deep on the **transferable concepts underneath** the tools you already use — the transaction model underneath Prisma, the rendering model underneath Next.js, the delivery semantics underneath your queue.

---

## 6. How Skills Compound

Skills are not independent. They form clusters where weakness in one caps the value of the others.

```text
                 ┌──────────────────────────────┐
                 │ Technical Decision-Making    │  governs how all skills are applied
                 └──────────────┬───────────────┘
        ┌───────────────────────┼────────────────────────┐
        ▼                       ▼                        ▼
 ┌─────────────┐        ┌──────────────┐         ┌──────────────┐
 │ Domain      │───────▶│ Architecture │────────▶│ System Design│
 │ Modeling    │        └──────┬───────┘         └──────┬───────┘
 └─────┬───────┘               │                        │
       ▼                       ▼                        ▼
 ┌─────────────┐        ┌──────────────┐         ┌──────────────┐
 │ Database    │◀──────▶│ API Design   │◀───────▶│ Distributed  │
 │ Engineering │        └──────────────┘         │ Systems      │
 └─────┬───────┘                                 └──────┬───────┘
       └──────────────┬──────────────────────────────────┘
                      ▼
       Programming · Concurrency · Algorithms   (execution)
                      ▼
       Testing · Security · Performance         (verification of properties)
                      ▼
       DevOps · Infrastructure · Observability  (operation)
                      ▼
       Debugging · Documentation · Code Review  (feedback & knowledge)
                      ▼
       Product Engineering · Technical Leadership (direction & scale)
```

**Compounding examples:**

- **Domain modeling × Database engineering:** A correct state machine in code *plus* a database constraint on legal transitions is dramatically stronger than either alone.
- **Observability × Debugging:** Debugging skill without telemetry is guesswork; telemetry without debugging skill is unread dashboards.
- **Testing × Architecture:** Good boundaries make testing cheap; good tests make architectural refactoring safe.
- **Security × API design:** Most API vulnerabilities (IDOR, mass assignment, excessive data exposure) are API design choices.
- **Product engineering × Everything:** The cheapest reliable, secure, fast system is the one where unnecessary features were never built.

**Bottleneck rule:** Your system's quality is limited by your weakest skill that the system *actually exercises*. A payments system exercises concurrency, database, security, and distributed systems heavily — weakness in any is fatal. A marketing site exercises frontend performance and accessibility — weakness in distributed systems is irrelevant there.

---

## 7. What Level Is Actually Necessary

Not every skill needs expert depth for professional work. The required level depends on **what the system you build demands** and **whether someone else covers the gap**.

### Baseline for a professional full-stack engineer shipping production business software

| Skill | Minimum professional level | Why that level |
|---|---|---|
| Programming | L3 | Others must safely change your code |
| Algorithms & data structures | L2 | Recognize complexity; rarely implement novel algorithms |
| System design | L3 | Own features end-to-end in production |
| Software architecture | L2–L3 | Structure services/apps well; org-level architecture is L4 |
| Database engineering | L3 | Data correctness and migrations cause most business-software incidents |
| API design | L3 | Contracts are expensive to change |
| Distributed systems | L2–L3 | Timeouts, idempotency, at-least-once, outbox are mandatory; consensus is not |
| Concurrency | L3 | Money, inventory, bookings, quotas all require it |
| Security | L3 | No acceptable junior tier for authorization bugs |
| Performance | L2–L3 | Measure-first discipline; deep tuning only when required |
| Testing | L3 | Must design your own test strategy |
| Debugging | L3 | Must resolve production issues with telemetry |
| DevOps | L2–L3 | Understand and fix your pipeline; roll back safely |
| Cloud / infrastructure | L2 | Understand your runtime environment; L3 if you own it |
| Observability | L3 if on call | Can't operate what you can't see |
| Product engineering | L2–L3 | Avoid building the wrong thing |
| Domain modeling | L3 in complex domains | Model errors are the most expensive to fix later |
| Code review | L3 to approve | Reviews are a quality gate |
| Technical leadership | L2 | Communicate clearly and own outcomes |
| Documentation | L3 | Future you is a stranger |
| Technical decision-making | L3 | Explicit, proportional, recorded decisions |

### Adjustments by context

| Context | Raise | Can lower |
|---|---|---|
| **Solo developer / multiple projects** | Decision-making, documentation, DevOps, product engineering, security (no one else will catch it) | Leadership of others, deep algorithms |
| **Fintech / payments / banking** | Concurrency, database, distributed systems, security, testing | Frontend animation polish |
| **High-traffic consumer / social** | Performance, distributed systems, observability, infrastructure | Heavy domain modeling |
| **Enterprise B2B SaaS** | Domain modeling, authorization/tenancy, API design, data migrations | Extreme performance tuning |
| **Logistics / WMS** | Domain modeling (state machines), concurrency, integrations, offline/unreliable networks | Global-scale infra |
| **Developer tools** | API design, documentation, backwards compatibility, DX | Heavy product analytics |
| **Early-stage startup** | Product engineering, decision-making (reversibility), pragmatic security | Architecture sophistication, scale |

---

## 8. A Deliberate Skill-Development Plan

Skills develop through **deliberate practice with feedback**, not accumulated hours.

### The loop

```text
Pick one skill at the edge of your ability
  ↓
Find a real problem that exercises it (at work, side project, or reproduction)
  ↓
Predict the outcome before acting (forces a mental model)
  ↓
Act and measure
  ↓
Compare prediction vs reality (the gap IS the learning)
  ↓
Write down the lesson (journal, ADR, runbook)
  ↓
Operationalize it (template, lint rule, checklist, test)
```

### Twelve-week plan example (backend-leaning full-stack developer)

| Weeks | Skill focus | Practice | Artifact produced |
|---|---|---|---|
| 1–2 | Database concurrency | Reproduce lost update & write skew in two `psql` sessions; fix with constraints, `FOR UPDATE`, `SERIALIZABLE` | Notes + a test suite demonstrating each anomaly |
| 3–4 | Failure design | Add timeouts/retries/idempotency to a side project's external calls; inject latency with toxiproxy | Failure mode analysis ([templates/failure-mode-analysis.md](templates/failure-mode-analysis.md)) |
| 5–6 | Observability | OpenTelemetry end-to-end; define two SLOs; build a burn-rate alert | Dashboard + runbook |
| 7–8 | Security | PortSwigger labs on access control and auth; threat-model your own app | Threat model ([templates/threat-model.md](templates/threat-model.md)) + fixed findings |
| 9–10 | Testing | Property-based tests for pricing/state machine; mutation testing on one module | Mutation score before/after |
| 11–12 | Decision-making & docs | Write ADRs for 5 existing decisions; write a design doc for next feature before building | ADR log + design doc |

### Feedback sources ranked by signal quality

1. **Production behavior** (incidents, metrics, user behavior) — highest signal, highest cost.
2. **Code review from someone stronger** — high signal, cheap.
3. **Automated verification** (tests, mutation testing, load tests, security scanners) — objective, repeatable.
4. **Predict-then-measure experiments** — cheap and underused.
5. **Reading postmortems and expert code** — vicarious experience.
6. **Courses and books** — useful for knowledge layer; weakest for judgment.

---

## 9. Key Takeaways

1. **A skill is a reliable ability to produce good outcomes in a class of problems** — knowledge + mental model + judgment + execution + verification + operationalization.
2. **Experts differ from seniors mostly at the verification and operationalization layers**: they prove things work and make the right behavior automatic.
3. **Tool knowledge is the execution layer, not the engineering.** It is increasingly cheap; engineering judgment is not.
4. **The highest-leverage skills for business software** are database engineering, concurrency, security (especially authorization), domain modeling, testing strategy, and decision-making — because their failures are silent until they're expensive.
5. **Skills compound and bottleneck.** Your system is limited by the weakest skill it actually exercises.
6. **Required depth depends on context.** A solo developer must raise decision-making, documentation, security, and DevOps because no one else covers the gaps.
7. **Develop skills through prediction and measurement**, then encode lessons into conventions and tooling ([02-engineering-conventions.md](02-engineering-conventions.md), [10-knowledge-into-systems.md](10-knowledge-into-systems.md)).
8. **Recognize level by questions asked, not technologies listed.** Beginners ask "how do I do this in X?"; experts ask "what must stay true, what can fail, and how will we know?"

---

## 10. Self-Assessment Checklist

Answer honestly. Each "no" is a development target.

**Programming & modeling**
- [ ] I model states as discriminated unions/state machines rather than boolean flags.
- [ ] I can explain the difference between expected and unexpected errors in my codebase and how each is handled.
- [ ] I resist abstractions until there are at least three concrete cases.

**Data & concurrency**
- [ ] I can reproduce a lost-update anomaly in Postgres and name three ways to prevent it.
- [ ] Every critical business invariant in my current project is enforced by a database constraint, not only application code.
- [ ] I have performed and timed a real backup restore.

**Distributed systems & failure**
- [ ] Every outbound network call I own has an explicit timeout.
- [ ] Every non-idempotent mutation endpoint or webhook handler I own is safe to receive twice.
- [ ] I can explain the dual-write problem and the outbox pattern.

**Security**
- [ ] Every data access in my API is scoped by tenant/owner at the query level.
- [ ] I have tried to access another user's data in my own app, deliberately.
- [ ] No long-lived production secrets are stored in CI or developer machines.

**Verification & operations**
- [ ] I measure before optimizing and keep before/after numbers.
- [ ] My test suite uses a real database for data-access code.
- [ ] I can answer "what's the p95 latency and error rate of my most important endpoint right now?" in under a minute.
- [ ] I can roll back my production deployment in under 5 minutes, and I've done it.

**Judgment & knowledge**
- [ ] My last three significant technical decisions are written down with alternatives and revisit triggers.
- [ ] I can describe my system's architecture without naming a single framework.
- [ ] At least one lesson I learned the hard way this year is now enforced by a tool, template, or test.

Next: [02-engineering-conventions.md](02-engineering-conventions.md) — how teams turn recurring decisions into shared defaults.

