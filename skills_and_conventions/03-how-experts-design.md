# 03 — How Experts Actually Design Software

> Experts do not start by choosing a framework, a database, or a folder structure. They start by building a precise model of the problem, the rules that must never break, the ways the system will fail, and the forces (load, money, people, time) acting on it. Code is the *last* expression of a design that has already been reasoned through. This chapter makes that invisible pre-coding process explicit, question by question, and then walks one realistic feature through the entire sequence.

Related chapters: [01-engineering-skills.md](01-engineering-skills.md) · [04-architectural-decision-making.md](04-architectural-decision-making.md) · [07-designing-for-failure.md](07-designing-for-failure.md) · [08-security-engineering.md](08-security-engineering.md) · [09-invariants-and-correctness.md](09-invariants-and-correctness.md) · [14-expert-development-loop.md](14-expert-development-loop.md) · [19-complete-mental-model.md](19-complete-mental-model.md) · [templates/design-doc.md](templates/design-doc.md)

---

## Table of Contents

1. [The Core Difference: Designing the Problem Before the Solution](#1-the-core-difference-designing-the-problem-before-the-solution)
2. [How Much Design Is Enough? (Calibrating Depth)](#2-how-much-design-is-enough-calibrating-depth)
3. [The Pre-Coding Questions](#3-the-pre-coding-questions)
   - [3.1 What problem are we actually solving?](#31-what-problem-are-we-actually-solving)
   - [3.2 What are the business requirements?](#32-what-are-the-business-requirements)
   - [3.3 What are the constraints?](#33-what-are-the-constraints)
   - [3.4 What are the system boundaries?](#34-what-are-the-system-boundaries)
   - [3.5 What are the invariants?](#35-what-are-the-invariants)
   - [3.6 What data must remain consistent?](#36-what-data-must-remain-consistent)
   - [3.7 What can fail?](#37-what-can-fail)
   - [3.8 What happens under concurrency?](#38-what-happens-under-concurrency)
   - [3.9 What happens when dependencies are unavailable?](#39-what-happens-when-dependencies-are-unavailable)
   - [3.10 What are the security boundaries?](#310-what-are-the-security-boundaries)
   - [3.11 What needs to scale?](#311-what-needs-to-scale)
   - [3.12 What does NOT need to scale?](#312-what-does-not-need-to-scale)
   - [3.13 Where are the bottlenecks?](#313-where-are-the-bottlenecks)
   - [3.14 What should be synchronous?](#314-what-should-be-synchronous)
   - [3.15 What should be asynchronous?](#315-what-should-be-asynchronous)
   - [3.16 What should be transactional?](#316-what-should-be-transactional)
   - [3.17 What should be eventually consistent?](#317-what-should-be-eventually-consistent)
   - [3.18 Where should state live?](#318-where-should-state-live)
   - [3.19 What should be cached?](#319-what-should-be-cached)
   - [3.20 What should be immutable?](#320-what-should-be-immutable)
   - [3.21 What should be auditable?](#321-what-should-be-auditable)
   - [3.22 Additional questions experts ask](#322-additional-questions-experts-ask)
4. [The Mental Sequence: Problem → Operations](#4-the-mental-sequence-problem--operations)
5. [Worked Example: WMS Stock Reservation, End to End](#5-worked-example-wms-stock-reservation-end-to-end)
6. [Design Artifacts and Where They Live](#6-design-artifacts-and-where-they-live)
7. [Amateur vs Professional vs Expert](#7-amateur-vs-professional-vs-expert)
8. [Anti-Patterns in the Design Phase](#8-anti-patterns-in-the-design-phase)
9. [Key Takeaways](#9-key-takeaways)
10. [Self-Assessment Checklist](#10-self-assessment-checklist)

---

## 1. The Core Difference: Designing the Problem Before the Solution

**What.** Design is the activity of reducing uncertainty *before* it becomes expensive. Expert design is not drawing boxes; it is systematically answering questions whose answers would be costly to discover in production.

**Why.** The cost of a wrong decision grows with the amount of code, data, and users built on top of it:

```text
Cost of changing a decision
│
│                                              ● data migrated across 40M rows,
│                                            ●   3 clients depend on the API
│                                         ●
│                                    ●   shipped, users have data
│                             ●   merged, other code depends on it
│                  ●   code written
│   ●  whiteboard
└──────────────────────────────────────────────────────────────── time
```

A wrong column type on a whiteboard costs 10 seconds. The same wrong type in a 40-million-row table with three consumers costs a multi-week migration. Experts front-load thinking precisely where the curve is steep: **data models, public APIs, consistency guarantees, security boundaries, and module boundaries.** They deliberately do *not* front-load thinking where the curve is flat: internal function structure, UI layout details, variable names.

**How.** Experts classify every decision by its reversibility:

| Decision type | Examples | Design effort |
|---|---|---|
| **One-way door** (hard to reverse) | Primary data model, ID strategy, tenancy model, public API contract, money representation, event schema, choice of primary datastore | High: write it down, consider alternatives, get review |
| **Two-way door** (cheap to reverse) | Internal module layout, library for date formatting, caching TTL, UI component structure | Low: decide quickly, move on, change later |

**Example.** A SaaS team debates for two days whether to use Zustand or Redux Toolkit (two-way door; either can be replaced incrementally) while nobody discusses whether `tenant_id` should be on every table (one-way door; retrofitting tenant isolation onto 80 tables with production data is a quarter-long project). An expert reverses that allocation of attention.

**Expert Mental Model.** *"Spend design effort proportional to the cost of being wrong × the difficulty of reversing."*

**Common Mistake.** Treating design as a uniform phase ("we do a design doc for everything") or skipping it uniformly ("we're agile, we just build"). Both ignore that decisions have wildly different reversal costs.

---

## 2. How Much Design Is Enough? (Calibrating Depth)

Experts scale design depth to risk. A practical calibration:

| Work type | Risk signals | Design output |
|---|---|---|
| Bug fix, copy change, UI tweak | No data/contract change | None; PR description suffices |
| New CRUD screen on existing model | Uses existing invariants | Short PR description + tests |
| New feature touching one bounded context | New table, new endpoint | 1-page design note (problem, data, API, failure cases) |
| Feature touching money, inventory, permissions, or multiple contexts | Invariants, concurrency, security | Full design doc + invariant register entries + threat model delta |
| New system / new service / data migration | One-way doors everywhere | Design doc + ADRs + failure-mode analysis + rollout plan + review |

The trigger list experts use to escalate design depth:

```text
Escalate to a written design if ANY of these are true:
[ ] Money, inventory, credits, quotas, or any conserved quantity changes
[ ] A new public API or event schema is introduced
[ ] Data is migrated, backfilled, or its meaning changes
[ ] Authorization rules are added or changed
[ ] Two or more services/modules must agree on state
[ ] An external dependency is added to a critical path
[ ] Concurrency is possible on the same entity (two users, retries, workers)
[ ] Expected load exceeds anything the system currently handles
[ ] The change is hard to roll back (schema drops, external side effects, emails sent)
```

**Common Mistake.** Writing a 20-page design doc for a settings page, then shipping a "quick" refund endpoint with no design at all because "it's just one endpoint."

---

## 3. The Pre-Coding Questions

Each question below follows **What → Why → How → Example → Expert Mental Model → Common Mistake**. These questions are not a bureaucratic checklist to be answered in order; they are lenses. On a given feature, perhaps 6 of them matter enormously and the rest take ten seconds each to dismiss. The skill is knowing which ones dominate.

---

### 3.1 What problem are we actually solving?

**What.** Separating the *requested solution* from the *underlying problem*. Stakeholders almost always describe solutions ("add an export to CSV button"). The problem is behind it ("finance reconciles payouts in Excel every month and it takes them three days").

**Why.** Solving the stated solution instead of the problem produces software that is correct and useless. It also blocks cheaper solutions: the real problem may be solved by a scheduled report, an integration, or by fixing a data quality issue that made reconciliation hard in the first place.

**How.**
- Ask "what happens today without this?" and "what does success look like, measurably?"
- Apply "five whys" until you reach a business outcome (money, time, risk, compliance, retention).
- Write a **problem statement** that contains no solution words (no "button," "endpoint," "table").
- Identify who is affected, how often, and how badly.

```markdown
## Problem statement (template)
**Who:** Finance operations team (4 people)
**Situation:** Monthly payout reconciliation against bank statements
**Pain:** ~3 person-days per month; 2 incidents last quarter where mismatches were missed
**Root cause (hypothesis):** Payout records lack bank reference IDs; matching is manual
**Success metric:** Reconciliation < 2 hours/month; zero unmatched payouts older than 3 days
**Non-goals:** Replacing the accounting system; real-time reconciliation
```

**Example.** An e-commerce ops lead requests "a button to manually mark orders as shipped." Asking why reveals the carrier webhook silently fails ~2% of the time. The real problem is unreliable carrier status ingestion. The expert solution is idempotent webhook handling + a polling fallback + an alert on stale shipments. The manual button may still be built, but as an escape hatch, not as the solution.

**Expert Mental Model.** *"Requests are hypotheses about solutions. My job is to find the problem they are hypothesizing about."*

**Common Mistake.** Taking the ticket literally, shipping it fast, and being surprised when the stakeholder is still unhappy — or when the feature masks a deeper defect that then grows.

---

### 3.2 What are the business requirements?

**What.** The concrete, verifiable behaviors the system must exhibit, split into **functional requirements** (what it does) and **quality attributes / non-functional requirements** (how well: latency, availability, durability, compliance, cost).

**Why.** Architecture is driven far more by quality attributes than by features. "Users can place orders" fits any architecture. "Orders must be accepted even if the payment provider is down, and must never be double-charged" shapes the entire design.

**How.**
- Write functional requirements as scenarios with acceptance criteria (Given/When/Then).
- Write quality attributes as **measurable scenarios**, not adjectives. "Fast" is not a requirement; "p95 checkout API < 400 ms at 200 req/s" is.
- Ask for priorities explicitly. When two requirements conflict (consistency vs availability, speed vs auditability), someone must rank them.

```text
Quality attribute scenario format
Source:      Customer on mobile network
Stimulus:    Submits checkout
Environment: Black Friday peak, 10x normal traffic
Artifact:    Checkout API
Response:    Order accepted or explicit failure shown; never double charged
Measure:     p95 < 800ms; 99.95% success excluding card declines; 0 duplicate charges
```

**Example.** A banking feature "transfer between own accounts" has trivial functional requirements. The business requirements that matter: transfers must be atomic (no money created or destroyed), must appear in statements within 1 second, must be reversible only via compensating entries (never edits), and must be retained for 7 years for regulatory reasons. Those four sentences dictate a double-entry ledger, append-only storage, and an audit trail.

**Expert Mental Model.** *"Features tell me what to build. Quality attributes tell me how to build it. I don't design until I have both, with numbers."*

**Common Mistake.** Accepting "it should be scalable and secure" as a requirement. Unmeasurable requirements are unverifiable, so they are silently dropped.

---

### 3.3 What are the constraints?

**What.** Forces you cannot change (or can only change at high cost): deadlines, budget, team size and skills, existing systems, regulations, contractual SLAs, hosting restrictions, data residency, vendor contracts.

**Why.** Constraints eliminate options before any trade-off analysis. A design that is theoretically optimal but violates a constraint is not a design; it's a fantasy. Constraints are also frequently *assumed* rather than verified, and false constraints kill good options.

**How.** Enumerate constraints in categories and label each as **hard** (verified, non-negotiable) or **soft** (assumed, negotiable):

| Category | Questions | Example |
|---|---|---|
| Time | When must it ship? What's the cost of slipping? | Must be live before the October peak season |
| People | Who builds and operates it? What do they know? | 1 solo developer; strong in TypeScript/Postgres, no Kafka experience |
| Money | Infra budget? Per-transaction cost ceiling? | < $400/month infra |
| Existing systems | What must we integrate with or not break? | Legacy ERP exports inventory as nightly CSV via SFTP |
| Regulation | PCI-DSS, GDPR, HIPAA, SOX, data residency | EU customer data must stay in EU region |
| Contracts | SLAs promised to customers | 99.9% monthly availability for Enterprise tier |
| Technical | Platform limits, rate limits, legacy protocols | Carrier API: 10 req/s, no webhooks |

**Example.** A logistics startup wants real-time inventory sync with a customer's ERP. The constraint "ERP only exposes a nightly CSV" makes "real-time" impossible at the integration boundary. The design pivots: real-time *within* the WMS, nightly reconciliation *with* the ERP, and a visible "last synced" timestamp in the UI so users understand freshness.

**Expert Mental Model.** *"Constraints are design inputs, not obstacles. But I verify every constraint, because half of them are folklore."*

**Common Mistake.** Designing for a hypothetical team of 30 with a platform group when the actual team is 2 people — e.g., choosing Kubernetes + microservices + Kafka for a product that one person operates on weekends.

---

### 3.4 What are the system boundaries?

**What.** Where your system ends and others begin, and where *inside* your system one responsibility ends and another begins. Boundaries include: external systems (payment gateways, carriers, identity providers), user-facing surfaces, module/bounded-context boundaries, deployment boundaries, and data ownership boundaries.

**Why.** Boundaries determine coupling. Every boundary is a place where you must define a contract, handle failure, translate models, and enforce security. Wrong boundaries create "distributed monoliths" (services that must deploy together) or "big balls of mud" (everything touches everything).

**How.**
- Draw a **context diagram** (C4 level 1): your system in the middle, actors and external systems around it, labeled arrows with protocol and direction.
- For each external system, record: who owns it, SLA, rate limits, failure behavior, data it owns.
- Inside your system, identify **bounded contexts** by finding where the same word means different things. "Product" in Catalog (description, images, SEO) differs from "Product" in Inventory (SKU, bin location, quantity) and in Pricing (price lists, tax class).
- Assign **data ownership**: each piece of data has exactly one writer-of-record.

```text
                     ┌──────────────┐
   Shopper ──HTTPS──▶│  Storefront  │ (Next.js)
                     └──────┬───────┘
                            │ HTTPS/JSON
                     ┌──────▼─────────────────────────────────┐
                     │           Commerce Platform            │
                     │  ┌─────────┐ ┌──────────┐ ┌─────────┐  │
                     │  │ Catalog │ │ Ordering │ │Inventory│  │
                     │  └─────────┘ └────┬─────┘ └────┬────┘  │
                     └───────────────────┼────────────┼───────┘
                          webhooks+API   │            │ SFTP nightly CSV
                     ┌───────────────────▼──┐   ┌─────▼──────┐
                     │ Stripe (payments)    │   │ Legacy ERP │
                     └──────────────────────┘   └────────────┘
```

**Example.** A social platform puts "notifications" inside the "posts" module. Soon posts code imports email templates, push token logic, and user preference checks. Drawing boundaries reveals Notifications is its own context that *reacts* to events (`PostLiked`, `CommentAdded`) rather than being called inline. Posts no longer knows notifications exist.

**Expert Mental Model.** *"A boundary is a promise: what crosses it, in what shape, with what guarantees. I draw boundaries where change rates, ownership, or language differ."*

**Common Mistake.** Drawing boundaries around technical layers ("controllers service," "database service") or around nouns ("User service," "Product service") instead of around business capabilities and data ownership.

---

### 3.5 What are the invariants?

**What.** Statements that must *always* be true about the system's state, no matter what sequence of operations, failures, or concurrent requests occurs. (Deep treatment in [09-invariants-and-correctness.md](09-invariants-and-correctness.md).)

**Why.** Invariants are the definition of correctness. Features are a list of things that can happen; invariants are the list of things that must never happen. Most severe production bugs — oversold inventory, negative balances, cross-tenant data leaks, duplicate charges — are invariant violations.

**How.**
- For every entity, ask: *"What state would be a catastrophe?"* Then negate it.
- For every quantity, ask: *"Is it conserved? Can it go negative? Is it bounded?"*
- For every status field, draw the state machine and list illegal transitions.
- For every identifier, ask: *"Unique within what scope?"*
- For every row, ask: *"Who is allowed to see it?"*
- Decide the **enforcement layer(s)** for each invariant at design time, not after the incident.

```text
INV-ORD-01  An order's total = Σ(line totals) + shipping + tax − discounts
INV-ORD-02  An order in status SHIPPED has ≥ 1 shipment record
INV-ORD-03  Status transitions only: PENDING→PAID→FULFILLING→SHIPPED→DELIVERED,
            any non-terminal → CANCELLED; never back from SHIPPED to PAID
INV-PAY-01  Σ(captures) ≤ authorized amount
INV-PAY-02  Σ(refunds) ≤ Σ(captures)
INV-TEN-01  No query returns rows where tenant_id ≠ session tenant
```

**Example.** A coupon system: "each coupon code can be redeemed once per customer." Implemented only as an application check (`if (await hasRedeemed(...)) throw`), two concurrent checkout requests both pass the check and both redeem. The invariant needs a `UNIQUE (coupon_id, customer_id)` constraint on the redemption table.

**Expert Mental Model.** *"If I can't list the invariants, I don't understand the domain yet — and I'm not ready to write code."*

**Common Mistake.** Treating invariants as "validation" done in the UI form or the controller, where concurrency, retries, background jobs, and admin scripts bypass them.

---

### 3.6 What data must remain consistent?

**What.** Identifying which pieces of data must agree with each other **at all times** (strong consistency), which must agree **eventually**, and which may **legitimately differ** (derived, approximate, or historical).

**Why.** Consistency is expensive. Requiring every piece of data to be strongly consistent with every other forces everything into one transaction, one database, and one lock — killing scalability and availability. Requiring nothing to be consistent produces corruption. The design task is to draw the consistency map.

**How.** Build a consistency matrix:

| Data pair | Required consistency | Why | Mechanism |
|---|---|---|---|
| Account balance ↔ ledger entries | Strong, same transaction | Money must reconcile | Single DB transaction; balance derived or updated atomically |
| Order ↔ payment capture | Eventual, with reconciliation | External system; can't share transaction | Outbox + webhook + nightly reconciliation |
| Product stock ↔ search index "in stock" badge | Eventual, seconds acceptable | Display only; checkout re-validates | CDC/event → search indexer |
| Order history ↔ product name at time of order | Intentionally *not* consistent | Historical truth must not change | Snapshot product name/price into order line |
| Dashboard revenue totals ↔ orders | Eventual, minutes acceptable | Analytics | Materialized view refreshed every 5 min |

**Example.** An e-commerce order line stores `product_id` only and joins to `products.price` for display. When the price changes, historical orders show the new price, invoices no longer match payments, and accounting breaks. The expert recognizes that order lines require **snapshot consistency** (the price *as of purchase*), not live consistency.

**Expert Mental Model.** *"Consistency is a budget. I spend strong consistency only where an inconsistency would be a business incident, and I make everything else explicitly eventual with a known lag and a reconciliation path."*

**Common Mistake.** Assuming "we use Postgres, so everything is consistent" — while calling Stripe, sending emails, and updating Elasticsearch outside the transaction, creating silent divergence.

---

### 3.7 What can fail?

**What.** Enumerating failure modes of every component and interaction *before* building: process crashes, network partitions, timeouts, dependency outages, bad deploys, corrupt input, full disks, exhausted connection pools, clock skew, human error. (Deep treatment in [07-designing-for-failure.md](07-designing-for-failure.md).)

**Why.** Failures are not edge cases; at scale they are the steady state. A system processing 1M requests/day with a 0.01% network error rate sees 100 failures per day. If the design did not decide what happens on each, the code decides accidentally — usually by leaving half-completed state.

**How.** For each step in a flow, ask: *"What if this step fails? What if it succeeds but we never learn it succeeded?"* The second question is the one amateurs miss.

```text
Flow: Checkout
Step                         Fails how?                     If it fails            If it succeeds but response lost
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
1. Validate cart             DB timeout                     Return 503, retry OK   n/a (read-only)
2. Reserve stock             Deadlock, insufficient stock   Return 409 / retry     Client retries → must be idempotent
3. Create payment intent     Stripe 5xx / timeout           Release reservation    Stripe has intent, we don't → idempotency key
4. Confirm payment           Card declined / 3DS abandoned  Release after TTL      Charge happened, we think it didn't → webhook
5. Mark order PAID           Process crash                  Webhook re-delivers    n/a
6. Send confirmation email   Provider outage                Queue retry            Duplicate email → dedupe key
```

This table *is* the design. Every row becomes code, a test, or an explicit accepted risk.

**Example.** A payments team calls the provider's `charge` API with a 30s timeout. At 29.9s the provider charges the card; at 30s the client times out and marks the payment failed; the user retries and is charged twice. The expert design sends an **idempotency key** derived from the order attempt, so a retry returns the original charge instead of creating a new one.

**Expert Mental Model.** *"Every remote call has three outcomes: success, failure, and unknown. Designs that handle only two are broken."*

**Common Mistake.** Writing only the happy path and wrapping it in `try/catch { log(error) }`, which converts failures into silent inconsistency.

---

### 3.8 What happens under concurrency?

**What.** Reasoning about what happens when two or more operations touch the same data at overlapping times: two users, two tabs, a user and a background job, a retry and its original, two instances of the same worker.

**Why.** Code that is correct sequentially is frequently incorrect concurrently, and concurrency bugs don't show up in local development, unit tests, or low-traffic staging. They appear at peak load, on the most valuable day, and are hard to reproduce.

**How.**
- Identify **shared mutable state**: rows, counters, files, cache keys, external resources.
- Look for the **read-modify-write** pattern — the source of most races:

```ts
// ❌ Race: two requests read quantity=1, both write 0, both succeed → oversell
const item = await db.inventory.findUnique({ where: { sku } });
if (item.available < qty) throw new OutOfStock();
await db.inventory.update({ where: { sku }, data: { available: item.available - qty } });
```

- Choose a concurrency control strategy per hotspot:

| Strategy | How | Use when |
|---|---|---|
| Atomic conditional update | `UPDATE ... SET available = available - $1 WHERE sku = $2 AND available >= $1` | Single-row counters |
| Pessimistic lock | `SELECT ... FOR UPDATE` inside a transaction | Multi-row read-then-decide logic, low contention |
| Optimistic lock | `version` column; `UPDATE ... WHERE id = $1 AND version = $2` | User edits, low conflict rate |
| Unique constraint | `UNIQUE(...)` catches duplicates | "At most once" rules |
| Serializable isolation + retry | `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` | Complex invariants across many rows |
| Single-writer / partitioned queue | One consumer per key | Ordered processing per entity |
| Advisory lock | `pg_advisory_xact_lock(hashtext(key))` | Coordinating jobs, no natural row to lock |

```ts
// ✅ Atomic: the database evaluates the condition and the write together
const result = await sql`
  UPDATE inventory
     SET available = available - ${qty}
   WHERE sku = ${sku} AND warehouse_id = ${warehouseId} AND available >= ${qty}
  RETURNING available`;
if (result.length === 0) throw new OutOfStock(sku);
```

**Example.** A SaaS app enforces "max 5 seats on the Starter plan" by counting members before inserting. Two admins invite users simultaneously; both see 4 members; the tenant ends up with 6. Fix: lock the tenant's subscription row (`SELECT ... FOR UPDATE`) during the invite transaction, or maintain a `seats_used` counter with a `CHECK (seats_used <= seats_limit)` constraint.

**Expert Mental Model.** *"Assume every line of my code runs twice, simultaneously, on different machines — because eventually it will."*

**Common Mistake.** Using an in-memory mutex (`async-mutex`, a JS variable) to protect data shared across multiple server instances or serverless invocations.

---

### 3.9 What happens when dependencies are unavailable?

**What.** Deciding in advance the system's behavior when each dependency (database, cache, queue, third-party API, identity provider, feature-flag service, CDN) is slow, erroring, or completely down.

**Why.** A system's availability is bounded by its critical-path dependencies multiplied together. Five dependencies at 99.9% each give ~99.5% — about 3.6 hours of downtime per month — unless failures are isolated. Slow dependencies are worse than dead ones: they exhaust threads and connection pools and take down unrelated features.

**How.** Classify each dependency and define the degraded mode:

| Dependency | Critical? | Degraded behavior | Mechanism |
|---|---|---|---|
| Primary Postgres | Yes | Read-only mode page; accept nothing | Health check, fail fast |
| Redis cache | No | Serve from DB with higher latency; shed non-essential load | Cache-aside with fallback, short timeout (50 ms) |
| Recommendations API | No | Hide "You may also like" section | Timeout 200 ms, circuit breaker, empty fallback |
| Stripe | Yes for payment, no for browsing | Browsing and cart work; checkout shows "Payments temporarily unavailable" | Circuit breaker, status banner |
| Email provider | No | Queue emails; deliver later | Outbox + retry with backoff |
| Feature-flag service | No | Use last known flags / safe defaults | Local cached snapshot |
| Auth provider (OIDC) | Yes for login, no for existing sessions | Existing sessions continue | Validate JWTs locally with cached JWKS |

```ts
// Timeout + fallback for a non-critical dependency
async function getRecommendations(userId: string): Promise<Product[]> {
  try {
    return await withTimeout(recsClient.forUser(userId), 200);
  } catch (err) {
    metrics.increment('recs.fallback', { reason: classify(err) });
    return []; // UI renders nothing; page still works
  }
}
```

**Example.** A Next.js product page server-renders reviews by calling a reviews microservice with no timeout. The reviews service hits a GC pause storm; product pages hang for 30s; the Node event loop backs up; the entire storefront, including checkout, goes down. The expert design: timeout of 300ms, render reviews in a `<Suspense>` boundary streamed separately, and a circuit breaker so the product page never waits for reviews.

**Expert Mental Model.** *"For each dependency: is it on the critical path? If not, the system must work without it. If yes, how do I fail fast and visibly instead of slowly and silently?"*

**Common Mistake.** Default HTTP client timeouts (often infinite or minutes long) on calls to external services.

---

### 3.10 What are the security boundaries?

**What.** Identifying where trust changes: between the browser and the server, between tenants, between roles, between your system and third parties, between services, between application and database. (Deep treatment in [08-security-engineering.md](08-security-engineering.md).)

**Why.** Every vulnerability is a failure to enforce a check at a trust boundary. Designing security in after the fact means discovering boundaries by incident.

**How.**
- Mark trust boundaries on the context diagram (dashed lines).
- For each boundary crossing, define: authentication (who are you), authorization (may you do this, to *this* resource), input validation (is this data well-formed and within bounds), and output filtering (what may you see).
- Run a lightweight **STRIDE** pass on new flows (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege).
- Decide where authorization lives: centralized policy function, never ad hoc in UI.

```ts
// Authorization at the resource level, not only at the route level
export async function getInvoice(session: Session, invoiceId: string) {
  const invoice = await db.invoice.findFirst({
    where: { id: invoiceId, tenantId: session.tenantId }, // tenant scoping in the query
  });
  if (!invoice) throw new NotFound();                     // 404, not 403: don't confirm existence
  authorize(session, 'invoice:read', invoice);            // role/ownership policy
  return toInvoiceDTO(invoice, session);                  // field-level filtering
}
```

**Example.** A B2B SaaS API exposes `GET /api/invoices/:id`. The route requires login, so the team considers it secure. Any logged-in user of any tenant can enumerate invoice IDs and read other companies' invoices (IDOR / BOLA — the #1 API vulnerability class). The boundary that mattered was *tenant*, not *authenticated vs anonymous*.

**Expert Mental Model.** *"Authentication tells me who; authorization tells me whether, for this specific object. The client is hostile, IDs are guessable, and every boundary will be probed."*

**Common Mistake.** Hiding a button in the React UI and considering the action "restricted."

---

### 3.11 What needs to scale?

**What.** Identifying the specific dimensions along which load will grow, and the specific components that will feel it: requests/second, data volume, number of tenants, tenant size variance, fan-out, write rate, concurrent connections, events/second, background job volume.

**Why.** "Scalability" is not a property of a system; it is a property of a system *along a specific dimension*. A design that scales to 10,000 small tenants may collapse with one tenant that has 5M rows. Designing for the wrong dimension wastes effort and misses the real risk.

**How.**
- Build a **load model** with current numbers and 12–24 month projections.
- Identify the growth dimension with the steepest curve.
- Estimate the cost per unit of that dimension (queries per request, rows per tenant, fan-out per post).

```text
Load model — B2B WMS (per warehouse)
Dimension                     Today      18 months   Notes
─────────────────────────────────────────────────────────────────────
Warehouses (tenants)          40         400         10x
SKUs per warehouse            5k (p50)   5k (p50)    flat
                              200k (max) 2M (max)    one enterprise customer — skew!
Orders/day per warehouse      800        3k
Scan events/sec (peak, all)   50         1,500       handheld scanners; bursty at shift start
Stock movement rows/year      20M        400M        append-only ledger → partitioning needed
Concurrent WebSocket clients  300        6k
```

This model reveals the real scaling risks: the append-only stock ledger (partition by month), scan-event bursts (queue + batch writes), and tenant skew (one giant tenant needs per-tenant query plans, not a global cache). Requests/second for the admin UI is irrelevant.

**Example.** A social app designs "fan-out on write" for feeds (write each post into every follower's feed). Works well until a celebrity with 10M followers posts. The dimension that needed to scale was *follower count variance*. Expert design: hybrid — fan-out on write for normal users, fan-out on read for accounts above a follower threshold.

**Expert Mental Model.** *"Scale along which axis? What's the p50 and what's the max? Skew breaks systems more often than averages do."*

**Common Mistake.** Benchmarking with uniform synthetic data (every tenant the same size) and declaring the system scalable.

---

### 3.12 What does NOT need to scale?

**What.** Explicitly identifying parts of the system that will stay small and therefore should be built in the simplest possible way.

**Why.** Every scalability mechanism (sharding, queues, caches, replicas, microservices) adds cost, failure modes, and cognitive load. Applying them uniformly is a major source of overengineering. Most systems have one or two hot paths and dozens of cold ones.

**How.** For each component, estimate its 3-year ceiling. If it fits comfortably on one Postgres instance and one app process, write it as simple synchronous CRUD.

| Component | 3-year ceiling | Design |
|---|---|---|
| Admin settings | < 1 write/min | Plain CRUD, no cache |
| Tenant billing plans | < 50 rows | Config table, loaded at boot |
| Internal reporting | 5 users | Direct SQL on read replica |
| User invites | < 100/day | Synchronous email send via queue is fine; no dedicated service |
| Audit log writes | 50/s | Same DB, append-only table, partitioned monthly later |

**Example.** A dev-tools startup builds its "organization settings" page on an event-sourced CQRS pipeline because "the core product needs it." Settings changes happen twice a month per org. The pipeline adds projections, replay logic, and eventual consistency bugs ("I saved but it didn't change") to a feature that needed a single `UPDATE`.

**Expert Mental Model.** *"Scale is a cost I pay only where the load model forces me to. Everywhere else, boring and direct wins."*

**Common Mistake.** "We might need it later" applied to every component, producing a system that's uniformly complex and uniformly slow to change.

---

### 3.13 Where are the bottlenecks?

**What.** Predicting (and later measuring) the resource that will saturate first under the load model: database write throughput, a single hot row, connection pool, CPU on image processing, third-party rate limits, lock contention, a single-threaded consumer.

**Why.** System throughput equals the throughput of its narrowest point. Optimizing anything else produces no improvement (Theory of Constraints). Designing with the bottleneck in mind lets you put slack or horizontal scaling exactly there.

**How.**
- Trace a request/job through every resource it consumes and estimate per-unit cost.
- Look for **shared singletons**: one hot row (global counter), one queue partition, one lock, one external API key.
- Check external **rate limits** — frequently the real ceiling.
- Validate with a load test before launch; confirm with production metrics after (see [06-performance-engineering.md](06-performance-engineering.md)).

```text
Checkout at 200 req/s — capacity sketch
Resource                     Per request     At 200 rps      Limit           Headroom
────────────────────────────────────────────────────────────────────────────────────
App CPU (Node, 4 instances)  15 ms           3 cores         16 cores        5x
Postgres connections         1 for ~40 ms    8 concurrent    pool 20 × 4=80  10x
Inventory row locks          hot SKU lock    contention on   —               ⚠ launch SKU
                             ~5 ms           10 top SKUs
Stripe API                   1 call          200 rps         100 rps (live)  ❌ BOTTLENECK
Email provider               async           200/s queued    50/s            queue absorbs
```

**Example.** A flash-sale checkout is load-tested against a Stripe mock with no rate limit. In production, Stripe's rate limit becomes the ceiling at half the expected traffic. Expert design: queue-based checkout admission ("You're in line"), requesting a rate-limit increase from the provider weeks in advance, and reserving inventory before payment so the bottleneck doesn't cause overselling.

**Expert Mental Model.** *"There's always exactly one bottleneck right now. I find it on paper first, confirm it with measurement, and design slack around it."*

**Common Mistake.** Adding app servers when the database is the bottleneck, which increases connection pressure and makes things worse.

---

### 3.14 What should be synchronous?

**What.** Deciding which work must complete before responding to the caller.

**Why.** Synchronous work gives immediate, simple feedback and strong consistency for the caller — but couples the caller's latency and availability to every step in the chain. Too much synchronous work creates slow, fragile requests; too little creates confusing UX ("did it work?") and complex state management.

**How.** Make work synchronous when **the caller needs the result to proceed** or **the user needs a definitive answer now**:

```text
Synchronous if ANY:
  - The response depends on the result (reservation succeeded? payment authorized?)
  - An invariant must be checked before accepting (sufficient balance?)
  - The user cannot meaningfully continue without it (login)
  - It is fast (< ~100ms) and on a reliable dependency

Otherwise default to asynchronous.
```

**Example.** Bank transfer between own accounts: debit/credit ledger entries are synchronous (the user must see the result, and the balance invariant must be checked). Generating the PDF confirmation, sending the push notification, updating the spending-analytics dashboard, and fraud-scoring for pattern analysis are asynchronous.

**Expert Mental Model.** *"Synchronous = the minimum set of work required to give a truthful answer. Everything else is a consequence and can happen after."*

**Common Mistake.** Sending emails, generating thumbnails, calling analytics, and syncing to a CRM inside the HTTP request of a sign-up form.

---

### 3.15 What should be asynchronous?

**What.** Deciding which work is deferred to background jobs, queues, or event consumers.

**Why.** Asynchrony decouples latency and availability, absorbs bursts, enables retries, and isolates slow or unreliable work. It also introduces eventual consistency, ordering problems, duplicate delivery, poison messages, and operational burden (monitoring queues, dead-letter handling).

**How.** Make work asynchronous when:
- It's slow (> a few hundred ms) or depends on unreliable third parties.
- It's a side effect/consequence rather than the core decision.
- It fans out (notify 1,000 followers).
- It needs retries with backoff.
- The load is bursty and can be smoothed.

And for every async flow define: **delivery guarantee** (at-least-once is the realistic default), **idempotency strategy**, **ordering requirement**, **retry policy**, **dead-letter handling**, **user-visible status**.

```ts
// Transactional outbox: the side effect is recorded atomically with the state change
await db.$transaction(async (tx) => {
  const order = await tx.order.update({ where: { id }, data: { status: 'PAID' } });
  await tx.outbox.create({
    data: {
      id: crypto.randomUUID(),
      topic: 'order.paid',
      aggregateId: order.id,
      payload: { orderId: order.id, tenantId: order.tenantId, total: order.totalMinor },
    },
  });
});
// A relay process publishes outbox rows to the queue; consumers dedupe by outbox id.
```

**Example.** A dev-tools SaaS runs CI-like "analysis jobs" on customer repositories. Doing it synchronously in the webhook handler times out GitHub's 10-second webhook limit. Expert design: webhook handler validates signature, inserts a job row keyed by `(repo_id, commit_sha)` with a unique constraint (dedupes GitHub's redeliveries), returns 202 in < 100ms; workers pull jobs; UI shows job status via polling or server-sent events.

**Expert Mental Model.** *"Async is a trade: I buy decoupling and resilience, and I pay in duplicates, ordering, and visibility. I only buy it with a plan to pay."*

**Common Mistake.** `fireAndForget(sendEmail())` inside a request handler — async without a queue, retries, or durability. When the process restarts, the work vanishes.

---

### 3.16 What should be transactional?

**What.** Identifying groups of state changes that must all happen or none happen (atomicity), with defined isolation from concurrent operations.

**Why.** Partial writes are corruption. Without a transaction, a crash between "debit account A" and "credit account B" destroys money. But transactions have limits: they can't span external systems, long transactions hold locks and hurt throughput, and serializable isolation causes retries.

**How.**
- Define the **transaction boundary = the invariant boundary**. If an invariant involves rows X, Y, Z, they must be updated in one transaction (or the invariant must be relaxed to eventual with reconciliation).
- Keep transactions **short** and **free of network calls** to external services.
- Choose isolation deliberately (see [09-invariants-and-correctness.md](09-invariants-and-correctness.md)).
- For cross-system workflows, use **sagas** (sequence of local transactions with compensations) and the **outbox** pattern.

```ts
// ✅ Transaction contains only DB work that must be atomic
await db.$transaction(async (tx) => {
  await tx.ledgerEntry.createMany({ data: [
    { accountId: from, amountMinor: -amount, transferId },
    { accountId: to,   amountMinor: +amount, transferId },
  ]});
  await tx.$executeRaw`UPDATE accounts SET balance_minor = balance_minor - ${amount}
                       WHERE id = ${from} AND balance_minor >= ${amount}`;
  // ... check rowcount, credit destination, insert outbox event
}, { isolationLevel: 'Serializable' });

// ❌ Never: await stripe.charges.create(...) inside the transaction
```

**Example.** A marketplace payout job does: begin transaction → mark seller balances as paid → call bank payout API (8 seconds) → commit. Under load, row locks on seller balances are held for 8s, blocking sales from updating balances; deadlocks spike. Expert design: transaction 1 creates a `payout` row in `PENDING` and moves funds to a "payout in transit" ledger account; commit; call bank API with idempotency key = payout id; transaction 2 marks `SENT` or `FAILED` (and compensates).

**Expert Mental Model.** *"A transaction protects an invariant inside one database for a short time. For anything bigger, I use a state machine with compensations and reconciliation."*

**Common Mistake.** Believing a distributed workflow is atomic because the code is inside a `try` block with a `rollback()` in the `catch`.

---

### 3.17 What should be eventually consistent?

**What.** Deliberately choosing where the system may be temporarily inconsistent, bounding the inconsistency window, and guaranteeing convergence.

**Why.** Eventual consistency enables availability, performance, and decoupling across services, regions, caches, and search indexes. But "eventually" without bounds, monitoring, and reconciliation means "possibly never."

**How.** For each eventually consistent relationship specify:

```text
EC contract: Inventory → Storefront search "in stock" flag
  Source of truth:     inventory.available (Postgres)
  Propagation:         outbox → queue → search indexer
  Expected lag:        p99 < 5s
  Max tolerated lag:   60s (alert if exceeded)
  Stale-read impact:   User sees "in stock", checkout re-validates → shows "just sold out"
  Convergence proof:   Consumer is idempotent (upsert by sku, version-guarded)
  Reconciliation:      Hourly job compares DB vs index for changed SKUs; repairs diffs
  Monitoring:          Metric: indexer_lag_seconds; alert on > 60s for 5 min
```

The key technique: **authoritative checks at the point of commitment**. Eventually consistent data may be used for *display* and *hints*, but the decision that commits (checkout, withdrawal, permission grant) reads the source of truth.

**Example.** A social platform's like count is eventually consistent (a counter updated by a consumer, with periodic recount) — no one is harmed if it's off by 3 for 10 seconds. The *block list*, however, must not be eventually consistent for the check "can user A message user B?" — a blocked user being able to message for 10 seconds is a safety incident.

**Expert Mental Model.** *"Eventual consistency is acceptable when I can state the lag bound, the user impact of staleness, and the mechanism that guarantees convergence. If I can't state all three, it's not eventual consistency — it's a bug schedule."*

**Common Mistake.** Using a cache or read replica for a decision that requires the latest value (e.g., checking remaining API quota on a replica with 2s lag, allowing overuse).

---

### 3.18 Where should state live?

**What.** Deciding the authoritative location for every piece of state: database, cache, queue, object storage, client (browser memory, URL, localStorage, cookies), server session, third-party system, or derived on demand.

**Why.** State placement determines consistency, durability, scalability (stateless servers scale horizontally), security (client state is untrustworthy), and UX (URL state is shareable). Duplicated state without a clear owner is the root of synchronization bugs.

**How.** Use a state placement table:

| State | Lives in | Why |
|---|---|---|
| Orders, balances, inventory | Postgres (source of truth) | Durable, transactional, constrained |
| Session identity | HttpOnly Secure cookie (signed/encrypted) or server session store | Not accessible to JS; survives reloads |
| Filter/sort/page of a list | URL search params | Shareable, back-button works, SSR-able in Next.js |
| Unsaved form input | React component state | Ephemeral |
| Server data on client | TanStack Query / RSC cache | A *cache*, never a source of truth |
| Uploaded files | Object storage (S3/R2), metadata in DB | Cheap, durable, CDN-servable |
| Rate-limit counters | Redis | Fast, TTL-based, loss-tolerant |
| Job queue | Postgres (`SKIP LOCKED`) or SQS/Redis | Durable, retryable |
| Payment status | Stripe (truth) + local mirror | Local mirror reconciled with provider |
| Feature flags | Flag service + local cache | Fast evaluation, safe defaults |

Principles:
- **One writer-of-record per fact.** Everything else is a cache, projection, or snapshot — and is labeled as such.
- **Servers stateless**; state in durable stores. In-process memory holds only caches that can be lost.
- **Never trust client state** for authorization or pricing; recompute on the server.

**Example.** A Next.js e-commerce cart stores item prices in `localStorage` and sends them to the checkout API. An attacker edits the price to 0.01. The server must store only `{ sku, qty }` from the client and compute prices from the price table at checkout. The cart's *display* price in the browser is a cache.

**Expert Mental Model.** *"For every piece of state: who owns it, who may change it, where is the truth, and what are the copies? Copies must know they're copies."*

**Common Mistake.** Keeping authoritative state in a Node.js process (in-memory maps of sessions, rate limits, websocket rooms) and then scaling to two instances.

---

### 3.19 What should be cached?

**What.** Choosing data to store in a faster, closer, cheaper-to-read location, with explicit rules for freshness and invalidation.

**Why.** Caching is one of the highest-leverage performance tools and one of the most prolific sources of correctness bugs (stale data, cache stampedes, cross-tenant leaks via bad cache keys, inconsistency after writes).

**How.** Cache only when a measured problem exists (see [06-performance-engineering.md](06-performance-engineering.md)), and define a cache contract:

```text
Cache contract: Product detail page data
  Key:            product:{tenantId}:{productId}:v3        ← includes tenant + schema version
  Layer:          Next.js fetch cache / CDN (ISR) + Redis for API
  TTL:            5 min; revalidateTag('product:{id}') on update
  Staleness OK?:  Yes for description/images; NO for price & stock at checkout
  Invalidation:   On product update event → revalidateTag + DEL redis key
  Stampede:       Single-flight lock / stale-while-revalidate
  Failure:        Cache down → read DB (with circuit breaker to protect DB)
  Security:       Never cache personalized/authorized responses at shared CDN layer
```

Decision heuristics:

| Good cache candidates | Poor cache candidates |
|---|---|
| Read-heavy, rarely changing (catalog, config) | Data used for authoritative decisions (balance, stock at commit) |
| Expensive to compute (aggregates, rendered pages) | Highly personalized with low hit rate |
| Tolerant of seconds–minutes staleness | Data requiring read-your-writes immediately (without special handling) |
| Hot keys under heavy load | Data with complex, many-to-many invalidation |

**Example.** A multi-tenant SaaS caches `GET /api/dashboard` responses at the CDN keyed by URL only. Tenant A's dashboard is served to Tenant B. Expert rule: authenticated/personalized responses get `Cache-Control: private, no-store` at shared layers; server-side caches always include tenant and permission scope in the key.

**Expert Mental Model.** *"A cache is a second copy of the truth with a lie-duration. I choose the lie-duration per field, and I never let the cache make commitments."*

**Common Mistake.** Adding Redis "for performance" before measuring, then spending weeks debugging invalidation for data that took 3ms to query.

---

### 3.20 What should be immutable?

**What.** Identifying data that, once written, should never be updated or deleted — only superseded by new records.

**Why.** Immutability eliminates whole classes of bugs: lost updates, race conditions on edits, "who changed this and when?", historical reports changing retroactively. It enables audit, replay, caching forever, and safe concurrent reads. It costs storage and requires modeling corrections as new facts.

**How.**
- **Financial records**: ledger entries are append-only; corrections are reversing entries.
- **Events**: once published, events are never mutated; new versions are new event types or schema versions.
- **Snapshots**: order lines snapshot price, tax rate, product name at purchase time.
- **Artifacts**: build artifacts, container images tagged by digest, uploaded files addressed by content hash.
- **Configuration history**: each change is a new version row.

Enforce immutability in the database, not only by convention:

```sql
CREATE TABLE ledger_entries (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  transfer_id   uuid        NOT NULL,
  account_id    uuid        NOT NULL REFERENCES accounts(id),
  amount_minor  bigint      NOT NULL CHECK (amount_minor <> 0),
  currency      char(3)     NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Application role may only INSERT and SELECT
REVOKE UPDATE, DELETE, TRUNCATE ON ledger_entries FROM app_user;

-- Defense in depth: block updates even from roles that have the grant
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entries is append-only (op=%)', TG_OP;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_entries_immutable
BEFORE UPDATE OR DELETE ON ledger_entries
FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
```

**Example.** A payments dashboard shows "revenue last month." An admin "fixes" a mistaken order by editing its amount. Last month's revenue report changes after it was sent to investors, and nobody can explain why. With immutable orders plus adjustment records, the report for last month stays the same and the correction appears as an adjustment this month, attributed to the admin.

**Expert Mental Model.** *"Facts that happened don't change. If something was wrong, a new fact corrects it. Mutable state is a view derived from immutable facts where history matters."*

**Common Mistake.** Soft-deleting or updating financial and audit data in place, destroying the ability to explain the past.

---

### 3.21 What should be auditable?

**What.** Deciding which actions must produce a durable, tamper-resistant record of who did what, when, from where, to which resource, and with what result.

**Why.** Audit trails are required for compliance (SOX, PCI-DSS, HIPAA, SOC 2), incident investigation, dispute resolution ("I never changed that setting"), fraud detection, and customer trust in B2B software. Audit cannot be added retroactively — past actions are gone.

**How.**
- Audit **security-relevant** and **business-significant** actions: logins, permission changes, API key creation, data exports, money movement, configuration changes, admin impersonation, deletion.
- Record structured events, not log lines:

```ts
type AuditEvent = {
  id: string;                  // uuid
  occurredAt: string;          // ISO timestamp from server clock
  tenantId: string;
  actor: { type: 'user' | 'api_key' | 'system' | 'support_impersonation';
           id: string; impersonatorId?: string };
  action: string;              // 'member.role.changed'
  resource: { type: string; id: string };
  before?: Record<string, unknown>;  // redacted
  after?: Record<string, unknown>;   // redacted
  result: 'success' | 'denied' | 'error';
  requestId: string;
  ip?: string;
  userAgent?: string;
};
```

- Write audit events **in the same transaction** as the change they describe (or via outbox), so a change can't happen without its audit record.
- Store append-only; restrict read access; define retention; consider hash-chaining for tamper evidence in regulated domains.
- Expose audit logs to customers in B2B SaaS (enterprise buyers require it).

**Example.** An enterprise customer reports that a former employee exported their entire customer list before leaving. Without audit logs of `data.export.created` with actor and filters, the SaaS vendor cannot confirm or deny it, and the customer churns. With them, the vendor answers in minutes.

**Expert Mental Model.** *"If someone asks 'who did this and when?' six months from now, can the system answer without guessing? For security and money, the answer must be yes."*

**Common Mistake.** Relying on application logs (sampled, rotated after 14 days, unstructured, containing no before/after state) as the audit trail.

---

### 3.22 Additional questions experts ask

Beyond the core list, experts routinely add:

| Question | Why it matters | Example |
|---|---|---|
| **How will we migrate existing data?** | New models must coexist with old data | Adding `currency` to 10M orders: backfill strategy, default, dual-read period |
| **How will we roll this out and roll it back?** | Most incidents are caused by changes | Feature flag per tenant; expand/contract migrations; no destructive DDL in the same deploy |
| **How will we know it's working in production?** | Tests don't prove production behavior | Define SLIs and business metrics (reservations/min, oversell count = 0) before launch |
| **How will we test it?** | Untestable designs are unverifiable | Pure domain functions; injectable clock; contract tests for external APIs |
| **What's the identity strategy?** | IDs leak info, collide, or block merging | UUIDv7 for sortable, non-enumerable IDs; natural keys as unique constraints |
| **How do time and time zones behave?** | Billing periods, cutoffs, DST | Store UTC `timestamptz`; business day computed in warehouse's time zone |
| **What are the idempotency keys?** | Retries are inevitable | `Idempotency-Key` header on POST; `(tenant_id, key)` unique |
| **What's the data retention and deletion policy?** | GDPR erasure vs audit retention conflict | Pseudonymize PII in audit logs; retain ledger |
| **Who operates this at 3 a.m.?** | Operability is a design property | Runbook, dashboards, alert thresholds, admin repair tools |
| **What is the cost model?** | Cloud bills scale with bad design | Per-tenant cost of storage/compute; egress; per-call third-party fees |
| **What would make us regret this design in two years?** | Surfaces one-way doors | "If we need multi-currency, is money modeled with currency?" |
| **What is the simplest design that could possibly work?** | Guards against overengineering | Postgres queue with `SKIP LOCKED` before Kafka |

---

## 4. The Mental Sequence: Problem → Operations

Experts move through a sequence of models, each narrowing the solution space for the next. It is **iterative**, not waterfall: discoveries in "Data" regularly send you back to "Requirements." But the *order of first pass* matters, because each stage depends on the previous one.

```text
Problem ──▶ Requirements ──▶ Constraints ──▶ Domain ──▶ Data ──▶ Boundaries
                                                                     │
Operations ◀── Validation ◀── Implementation ◀── Trade-offs ◀── Architecture
     │
     └──────────────── learnings feed back into Problem/Requirements ───────┘
```

### Stage-by-stage table

| # | Stage | Core questions | Artifact produced | Exit criterion |
|---|---|---|---|---|
| 1 | **Problem** | Who hurts, how much, why? What does success look like? What's out of scope? | Problem statement, success metrics, non-goals | Stakeholder agrees problem statement is accurate, contains no solution |
| 2 | **Requirements** | What behaviors? What quality attributes with numbers? Priorities when they conflict? | Use cases / scenarios with acceptance criteria; quality attribute scenarios | Every requirement is testable |
| 3 | **Constraints** | What's fixed: time, people, money, systems, regulation, SLAs? Which are verified? | Constraints list (hard/soft) | Hard constraints verified with the owner |
| 4 | **Domain** | What are the concepts, their language, lifecycles, rules, invariants? | Glossary (ubiquitous language), domain model sketch, state machines, invariant list | Domain expert can read the model and agree |
| 5 | **Data** | What entities, relationships, ownership, cardinalities, volumes, consistency needs, retention? | Logical data model / ERD, consistency matrix, load model, retention policy | Every invariant has a data-level representation |
| 6 | **Boundaries** | Where are contexts, modules, trust boundaries, external systems? Who owns which data? | Context diagram, module map, trust boundary diagram, API/event contracts (draft) | Every datum has one owner; every crossing has a contract |
| 7 | **Architecture** | What structure satisfies quality attributes within constraints? Sync vs async? Where does state live? | Container/component diagrams, sequence diagrams for key flows, failure-mode table | Key quality scenarios traceable to mechanisms |
| 8 | **Trade-offs** | What did we give up? What alternatives were rejected and why? What risks remain? | ADRs, risk register, accepted-risk list | Decisions recorded with alternatives and consequences |
| 9 | **Implementation** | How do we build it in thin, verifiable slices? What order de-risks fastest? | Code, migrations, tests, feature flags, vertical slice plan | Slice passes tests and quality gates |
| 10 | **Validation** | Does it meet requirements and invariants under realistic load and failure? | Test suites (unit, integration, property, contract, load), threat model review, staging results | Acceptance criteria and quality scenarios demonstrated |
| 11 | **Operations** | How is it deployed, observed, alerted, recovered, and evolved? | Dashboards, SLOs, alerts, runbooks, rollout plan, postmortem process | On-call can detect and recover from top failure modes without the author |

### What each stage protects against

| Skipping this stage… | …produces |
|---|---|
| Problem | Well-built features nobody needed |
| Requirements | Architecture that can't meet the latency/availability actually required |
| Constraints | Designs the team can't build or afford to operate |
| Domain | Code full of wrong abstractions; renames and rewrites; invariant bugs |
| Data | Migrations of death; inconsistent data; unqueryable history |
| Boundaries | Tight coupling; distributed monoliths; security holes at unmarked trust boundaries |
| Architecture | Accidental architecture decided by the framework's defaults |
| Trade-offs | Repeated debates; decisions reversed by people who didn't know the reasons |
| Implementation slices | Big-bang integration; months without feedback |
| Validation | Production is the test environment |
| Operations | Systems that work until the first incident, then nobody can fix them |

### The iterative reality

A realistic expert loop looks like this:

```text
Problem → Requirements → Constraints → Domain
                                   ↑       ↓
                                   │     Data ── discovers skew (one tenant 100x) ──┐
                                   │       ↓                                         │
                                   └── Boundaries ← renegotiate requirement (per-    │
                                           ↓         tenant limits) ◀────────────────┘
                                     Architecture
                                           ↓
                                      Trade-offs ── spike needed? ──▶ timeboxed prototype
                                           ↓                              │
                                    Implementation ◀──────────────────────┘
                                           ↓
                                      Validation ── load test fails at 60% target ──▶ back to Architecture
                                           ↓
                                      Operations ── production metrics ──▶ next iteration's Problem
```

Two expert techniques make this iteration cheap:

1. **Spikes / tracer bullets.** When a stage has high uncertainty (Will `SKIP LOCKED` handle 1,500 scans/s? Does the carrier API really support batch?), timebox a throwaway prototype that answers exactly that question — before committing the design.
2. **Walking skeleton.** Build the thinnest end-to-end slice through every layer (UI → API → DB → queue → worker → external mock → observability) in the first days, so integration and deployment risks surface immediately.

---

## 5. Worked Example: WMS Stock Reservation, End to End

We walk a realistic feature through all eleven stages. The domain: a multi-tenant cloud **Warehouse Management System (WMS)** used by 3PL (third-party logistics) companies. The feature: **stock reservation for outbound orders**.

### 5.1 Stage 1 — Problem

**Initial request (from the product manager):** *"When an order comes in from Shopify, deduct the stock so we stop overselling."*

**Discovery questions and answers:**

| Question | Answer |
|---|---|
| What happens today? | Stock is deducted only when the picker scans the item at pick time. Between order import and pick (2–30 hours), the same units are sold again via other channels. |
| How bad is it? | ~1.8% of orders for fast-moving SKUs can't be fulfilled; each costs ~$14 in support + refunds + marketplace penalties. For the largest customer, 1,100 orders/month. Amazon suspended one client's seller account for cancellation rate. |
| Why not deduct at import? | Physical stock hasn't moved yet. If an order is cancelled, deducted stock must be restored; also picking may find the bin is short (damaged/miscounted). |
| What does success look like? | Oversell-caused cancellations < 0.1%; available-to-promise stock published to sales channels within 60 seconds of change. |

**Problem statement:**

```markdown
**Who:** 3PL operators and their merchant clients selling on multiple channels
**Pain:** Units already committed to unpicked orders are still reported as sellable,
causing ~1.8% unfulfillable orders on fast movers, marketplace penalties, and churn risk
**Root cause:** The system has only one quantity (on-hand); it lacks a concept of
commitment between order acceptance and physical pick
**Success metrics:**
  - Oversell cancellations < 0.1% of orders (measured weekly per tenant)
  - Available-to-promise (ATP) published to channels p95 < 60s after change
  - Zero cases where reserved > on-hand in the ledger
**Non-goals (this iteration):**
  - Forecasting / safety-stock optimization
  - Cross-warehouse transfer orders
  - Backorders (orders beyond ATP are held, not accepted as backorder)
```

Notice the reframing: the request said "deduct stock"; the problem is "the system lacks a commitment concept." That single insight changes the design from a mutation of one number to a new domain concept.

### 5.2 Stage 2 — Requirements

**Functional requirements (scenarios):**

```gherkin
Feature: Stock reservation

  Scenario: Reserve on order import
    Given SKU "TSHIRT-M-BLK" in warehouse "LDN-1" has on_hand 10 and reserved 0
    When order "SO-1001" for 3 units is imported
    Then a reservation for 3 units is created for SO-1001
    And ATP for "TSHIRT-M-BLK" at "LDN-1" is 7

  Scenario: Insufficient stock
    Given ATP is 2
    When an order for 3 units is imported
    Then no partial reservation is created (tenant setting: allow_partial=false)
    And the order goes to status ON_HOLD_STOCK with reason INSUFFICIENT_ATP
    And the tenant is notified

  Scenario: Cancellation releases stock
    Given SO-1001 holds a reservation of 3
    When SO-1001 is cancelled before picking
    Then the reservation is released and ATP increases by 3

  Scenario: Pick consumes reservation
    Given SO-1001 holds a reservation of 3
    When the picker confirms picking 3 units from bin A-12-03
    Then on_hand decreases by 3 and reserved decreases by 3 atomically

  Scenario: Short pick
    Given SO-1001 holds a reservation of 3 and the bin physically has 2
    When the picker confirms picking 2 and reports 1 missing
    Then on_hand decreases by 2, reservation consumes 2
    And an inventory adjustment of −1 (reason: SHORT_PICK) is recorded
    And the remaining 1 unit is re-reserved from another bin if ATP allows, otherwise ON_HOLD

  Scenario: Duplicate import
    Given SO-1001 has been imported and reserved
    When the Shopify webhook for SO-1001 is delivered again
    Then no additional reservation is created
```

**Quality attribute scenarios:**

| Attribute | Scenario | Measure |
|---|---|---|
| Correctness | Any interleaving of imports, cancels, picks, adjustments | `reserved ≤ on_hand` and `reserved ≥ 0` always; 0 violations |
| Performance | Order import during flash sale (largest tenant) | 50 orders/s sustained for 10 min; p95 reservation < 150 ms |
| Latency (propagation) | Stock change → channel ATP update | p95 < 60 s |
| Availability | Shopify/Amazon API down | Reservations continue; channel sync catches up automatically |
| Auditability | "Why is ATP 4?" | Every quantity change traceable to a movement with actor, reason, reference |
| Multi-tenancy | Any request | No tenant can read or affect another tenant's stock |

**Priority when conflicting (agreed with PM):** Correctness > Auditability > Tenant isolation > Availability of import > Propagation latency > Throughput.

### 5.3 Stage 3 — Constraints

| Constraint | Type | Verified? | Design impact |
|---|---|---|---|
| Team: 2 backend devs, 1 frontend (Next.js), no dedicated ops | Hard | Yes | No Kafka, no new services; operationally simple |
| Existing stack: Node.js/TypeScript, PostgreSQL 16 (managed), Next.js admin, BullMQ on Redis for jobs | Hard | Yes | Build inside existing monolith; Postgres is the transaction engine |
| Deadline: before November peak (10 weeks) | Hard | Yes | Phase it; ship core reservation first |
| Shopify webhooks: at-least-once, may arrive out of order, 5 s timeout | Hard | Yes (docs + observed) | Idempotent import; quick ack; async processing |
| Amazon SP-API inventory feed: rate-limited, batched | Hard | Yes | Batch ATP updates per SKU, debounce |
| Largest tenant: 2M SKUs, 30k orders/day, peaks at 50/s | Hard | Yes (data) | Hot-row contention on top SKUs; test with that tenant's distribution |
| "Picking must work offline on handheld scanners" | Soft | **No** — verified: scanners have Wi-Fi coverage; offline mode is a future wish | Removed from scope; saved weeks |
| Budget: no new managed services this quarter | Hard | Yes | Postgres + existing Redis only |

Verifying the "offline scanners" constraint eliminated a sync-conflict design problem that would have dominated the project.

### 5.4 Stage 4 — Domain

**Ubiquitous language (glossary):**

| Term | Meaning | Not to be confused with |
|---|---|---|
| **On-hand** | Physical units in a warehouse location, per ledger | "Stock" (ambiguous — banned in code) |
| **Reserved** | Units committed to specific orders but not yet picked | "Allocated" (in this company, *allocated* means assigned to a specific bin — a later step) |
| **ATP (Available-to-Promise)** | `on_hand − reserved − quarantined` | "Available" in UI copy — mapped to ATP |
| **Reservation** | A commitment of N units of a SKU in a warehouse to an order line | A bin allocation |
| **Movement** | An immutable record of a change to on-hand (receipt, pick, adjustment, transfer) | An event on the bus |
| **Quarantine** | Units physically present but not sellable (damaged, QC hold) | Reserved |

Writing this glossary exposed that ops staff used "allocated" and developers used "reserved" for the same thing in some places and different things in others — a bug waiting to happen.

**Lifecycle / state machine of a Reservation:**

```text
                 import & ATP ok
  (none) ───────────────────────────▶ ACTIVE
                                        │  │  │
                     order cancelled    │  │  │ pick confirmed (full)
         ┌──────────────────────────────┘  │  └───────────────────────▶ CONSUMED
         ▼                                 │
     RELEASED                              │ pick confirmed (partial)
                                           ▼
                                   PARTIALLY_CONSUMED ──(rest picked)──▶ CONSUMED
                                           │
                                           └──(rest cancelled/short)──▶ RELEASED (remaining qty)

  Terminal: CONSUMED, RELEASED. No transitions out of terminal states.
  Expiry: ACTIVE reservations for orders ON_HOLD_PAYMENT > 72h → RELEASED (system actor)
```

**Invariants (initial register — see [templates/invariant-register.md](templates/invariant-register.md)):**

| ID | Invariant | Severity |
|---|---|---|
| INV-STK-01 | For each (tenant, warehouse, sku): `reserved ≥ 0` | Critical |
| INV-STK-02 | For each (tenant, warehouse, sku): `on_hand ≥ 0` | Critical |
| INV-STK-03 | For each (tenant, warehouse, sku): `reserved + quarantined ≤ on_hand` | Critical |
| INV-STK-04 | `on_hand` = Σ movements.quantity for that key (ledger conservation) | Critical |
| INV-STK-05 | `reserved` = Σ remaining qty of ACTIVE/PARTIALLY_CONSUMED reservations for that key | Critical |
| INV-RES-01 | At most one active reservation per (tenant, order_line_id) | High |
| INV-RES-02 | `consumed_qty ≤ qty` for each reservation | Critical |
| INV-RES-03 | Reservation state transitions follow the state machine | High |
| INV-TEN-01 | Every stock read/write is scoped to the session's tenant | Critical |
| INV-AUD-01 | Every change to on_hand or reserved has a movement or reservation event with actor and reason | High |

**Domain rules discovered while modeling:**
- A reservation belongs to an **order line**, not an order (orders can have lines shipped from different warehouses).
- Quarantined units must not be reservable (found by asking a warehouse supervisor "what stock do you *not* want sold?").
- Tenant setting `allow_partial_reservation` exists for some merchants (B2B wholesale accepts partial).

### 5.5 Stage 5 — Data

**Key design choice:** store both the **immutable facts** (movements, reservation events) and **materialized balances** (`stock_levels`) updated in the same transaction. Facts give auditability and reconciliation; balances give O(1) reads and a place for database constraints on the hot path.

```sql
-- Tenancy on every table; composite keys lead with tenant_id for index locality and RLS.
CREATE TABLE stock_levels (
  tenant_id      uuid    NOT NULL,
  warehouse_id   uuid    NOT NULL,
  sku_id         uuid    NOT NULL,
  on_hand        integer NOT NULL DEFAULT 0,
  reserved       integer NOT NULL DEFAULT 0,
  quarantined    integer NOT NULL DEFAULT 0,
  version        bigint  NOT NULL DEFAULT 0,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, warehouse_id, sku_id),
  CONSTRAINT on_hand_non_negative  CHECK (on_hand >= 0),              -- INV-STK-02
  CONSTRAINT reserved_non_negative CHECK (reserved >= 0),             -- INV-STK-01
  CONSTRAINT quarantine_non_neg    CHECK (quarantined >= 0),
  CONSTRAINT commitments_le_onhand CHECK (reserved + quarantined <= on_hand) -- INV-STK-03
);

CREATE TYPE reservation_status AS ENUM ('ACTIVE','PARTIALLY_CONSUMED','CONSUMED','RELEASED');

CREATE TABLE reservations (
  id              uuid PRIMARY KEY,               -- UUIDv7 generated in app
  tenant_id       uuid NOT NULL,
  warehouse_id    uuid NOT NULL,
  sku_id          uuid NOT NULL,
  order_id        uuid NOT NULL,
  order_line_id   uuid NOT NULL,
  qty             integer NOT NULL CHECK (qty > 0),
  consumed_qty    integer NOT NULL DEFAULT 0 CHECK (consumed_qty >= 0),
  status          reservation_status NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT consumed_le_qty CHECK (consumed_qty <= qty),             -- INV-RES-02
  FOREIGN KEY (tenant_id, warehouse_id, sku_id)
    REFERENCES stock_levels (tenant_id, warehouse_id, sku_id)
);

-- INV-RES-01: one live reservation per order line
CREATE UNIQUE INDEX reservations_one_live_per_line
  ON reservations (tenant_id, order_line_id)
  WHERE status IN ('ACTIVE','PARTIALLY_CONSUMED');

CREATE TYPE movement_type AS ENUM ('RECEIPT','PICK','ADJUSTMENT','TRANSFER_IN','TRANSFER_OUT','RETURN');

-- Immutable ledger of physical changes (INV-STK-04, INV-AUD-01)
CREATE TABLE stock_movements (
  id              bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id       uuid NOT NULL,
  warehouse_id    uuid NOT NULL,
  sku_id          uuid NOT NULL,
  type            movement_type NOT NULL,
  quantity        integer NOT NULL CHECK (quantity <> 0),  -- signed
  reason_code     text NOT NULL,
  reference_type  text NOT NULL,           -- 'order_line', 'receipt', 'cycle_count'
  reference_id    uuid NOT NULL,
  actor_type      text NOT NULL,           -- 'user','system','integration'
  actor_id        text NOT NULL,
  idempotency_key text NOT NULL,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, occurred_at, id)
) PARTITION BY RANGE (occurred_at);

CREATE UNIQUE INDEX stock_movements_idem
  ON stock_movements (tenant_id, idempotency_key, occurred_at);
-- note: on a partitioned table, unique indexes must include the partition key;
-- therefore true idempotency is enforced in a separate non-partitioned table:

CREATE TABLE processed_commands (
  tenant_id       uuid NOT NULL,
  idempotency_key text NOT NULL,
  result          jsonb NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, idempotency_key)
);

-- Transactional outbox for ATP propagation
CREATE TABLE outbox (
  id            uuid PRIMARY KEY,
  tenant_id     uuid NOT NULL,
  topic         text NOT NULL,
  aggregate_key text NOT NULL,              -- 'wh:{id}:sku:{id}' for per-key coalescing
  payload       jsonb NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  published_at  timestamptz
);
CREATE INDEX outbox_unpublished ON outbox (created_at) WHERE published_at IS NULL;
```

**Consistency matrix:**

| Relationship | Consistency | Mechanism |
|---|---|---|
| `stock_levels.reserved` ↔ Σ live reservations | Strong (same tx) | Both written in one transaction; reconciliation job verifies nightly |
| `stock_levels.on_hand` ↔ Σ movements | Strong (same tx) | Same; plus reconciliation |
| Stock levels ↔ channel ATP (Shopify/Amazon) | Eventual, p95 < 60s | Outbox → coalescing publisher → channel sync worker |
| Stock levels ↔ admin dashboard | Eventual, seconds | TanStack Query polling 10s on Next.js admin; authoritative on refresh |
| Order ↔ reservation | Strong for creation; eventual for order status display | Reservation created in import tx; order status updated in same tx |

**Volume estimates:**

```text
stock_levels:     largest tenant 2M rows × 3 warehouses; total ~15M rows (fine, single table)
reservations:     ~600k/month (all tenants) → ~7M/year; archive terminal > 13 months
stock_movements:  ~25M/year now, ~250M in 3 years → monthly partitions from day one
outbox:           ~1.5M/day at peak; delete published rows after 7 days
```

### 5.6 Stage 6 — Boundaries

**Context map:**

```text
┌───────────────────────── WMS Monolith (modular) ─────────────────────────────┐
│                                                                              │
│  ┌──────────────┐  ReserveStock(cmd)  ┌──────────────────────┐              │
│  │  Orders      │ ──────────────────▶ │  Inventory           │              │
│  │ (order,      │ ◀────────────────── │ (stock_levels,       │              │
│  │  order_line) │  Reserved/OnHold    │  reservations,       │              │
│  └──────▲───────┘                     │  movements)          │              │
│         │                             └─────────┬────────────┘              │
│         │ OrderImported                         │ outbox: stock.atp_changed  │
│  ┌──────┴───────┐                     ┌─────────▼────────────┐              │
│  │ Channel      │ ◀── ATPChanged ──── │  Channel Sync        │              │
│  │ Integrations │                     │  (debounce, batch)   │              │
│  └──────▲───────┘                     └─────────┬────────────┘              │
│         │                                       │                            │
│  ┌──────┴───────┐                               │                            │
│  │ Picking      │ ─── ConfirmPick(cmd) ──▶ Inventory                         │
│  │ (scanner API)│                               │                            │
│  └──────────────┘                               │                            │
└─────────┬───────────────────────────────────────┼────────────────────────────┘
          │ HTTPS webhooks (at-least-once)        │ REST, rate limited
  ┌───────┴────────┐                      ┌───────▼────────────┐
  │ Shopify         │                      │ Amazon SP-API /    │
  └────────────────┘                      │ Shopify Inventory  │
                                          └────────────────────┘
```

**Boundary rules:**
- **Inventory owns** `stock_levels`, `reservations`, `stock_movements`. No other module writes them. Orders calls the Inventory module's public interface (`inventory.reserve(...)`), never its tables. Enforced by lint rule (see Stage 9).
- **Channel Integrations** translates external order formats (Shopify, Amazon) into the internal `OrderImported` model — an **anti-corruption layer**. Inventory never sees a Shopify payload.
- **Trust boundaries:** (1) external webhooks → verify HMAC signature, treat payload as hostile; (2) scanner devices → authenticated per device + user, authorized per warehouse; (3) tenant boundary → Postgres RLS + tenant-scoped repository.

**Public interface of the Inventory module (contract):**

```ts
// modules/inventory/public.ts — the ONLY file other modules may import
export interface InventoryApi {
  reserve(cmd: ReserveCommand): Promise<ReserveResult>;
  release(cmd: ReleaseCommand): Promise<void>;
  confirmPick(cmd: ConfirmPickCommand): Promise<ConfirmPickResult>;
  getAtp(q: { tenantId: TenantId; warehouseId: WarehouseId; skuIds: SkuId[] }): Promise<AtpView[]>;
}

export type ReserveCommand = {
  tenantId: TenantId;
  idempotencyKey: string;              // `order_line:${orderLineId}:reserve`
  warehouseId: WarehouseId;
  orderId: OrderId;
  lines: Array<{ orderLineId: OrderLineId; skuId: SkuId; qty: PositiveInt }>;
  allowPartial: boolean;
  actor: Actor;
};

export type ReserveResult =
  | { kind: 'reserved'; reservations: ReservationView[] }
  | { kind: 'partially_reserved'; reservations: ReservationView[]; shortages: Shortage[] }
  | { kind: 'insufficient'; shortages: Shortage[] };
```

### 5.7 Stage 7 — Architecture

**Structural decision:** implement in the existing **modular monolith**, inside the Inventory module, with Postgres as the consistency engine and the existing BullMQ/Redis for async propagation. (Rationale in the ADR, Stage 8. See [04-architectural-decision-making.md](04-architectural-decision-making.md) for the general reasoning.)

**Sync vs async decisions:**

| Work | Sync/Async | Reason |
|---|---|---|
| Webhook receipt → store raw event, verify HMAC, 200 OK | Sync (< 100ms) | Shopify 5s timeout; must ack fast |
| Order import → reservation | Async (job), but atomic internally | Decoupled from webhook; retries; burst smoothing |
| Reservation invariants check | Sync within transaction | Correctness |
| Pick confirmation → consume reservation + movement | Sync | Picker needs immediate confirmation; invariant-bearing |
| ATP publication to channels | Async via outbox | External, rate-limited, eventual OK |
| Tenant notification on ON_HOLD | Async | Side effect |
| Reconciliation | Async, scheduled | Verification |

**Sequence — order import to reservation:**

```text
Shopify        Webhook API        webhook_events   ImportJob(worker)     Inventory module          Postgres
   │ POST /wh      │                    │                 │                     │                      │
   │──────────────▶│ verify HMAC        │                 │                     │                      │
   │               │ INSERT (shop,      │                 │                     │                      │
   │               │  webhook_id) ON    │                 │                     │                      │
   │               │  CONFLICT DO NOTHING──────────────────────────────────────────────────────────────▶│
   │◀── 200 ───────│ enqueue(eventId)   │                 │                     │                      │
   │               │────────────────────────────────────▶ │                     │                      │
   │               │                    │                 │ map to OrderImported│                      │
   │               │                    │                 │ upsert order        │                      │
   │               │                    │                 │ reserve(cmd) ──────▶│ BEGIN                │
   │               │                    │                 │                     │ check processed_cmds │
   │               │                    │                 │                     │ lock stock rows      │
   │               │                    │                 │                     │  (ordered by sku_id) │
   │               │                    │                 │                     │ domain decide        │
   │               │                    │                 │                     │ UPDATE stock_levels  │
   │               │                    │                 │                     │ INSERT reservations  │
   │               │                    │                 │                     │ INSERT outbox        │
   │               │                    │                 │                     │ INSERT processed_cmd │
   │               │                    │                 │◀─── result ─────────│ COMMIT               │
```

**Concurrency design:**
- Lock `stock_levels` rows with `SELECT ... FOR UPDATE` **in a deterministic order (sorted by sku_id)** to prevent deadlocks between multi-line orders.
- Isolation: `READ COMMITTED` with explicit row locks (sufficient because all invariant-relevant rows are locked; avoids serialization-retry storms at 50 orders/s).
- Database `CHECK` constraints are the last line of defense: if the application logic has a bug, the transaction fails instead of corrupting data.
- Hot SKU contention: lock hold time budget < 20ms (no network calls inside the transaction).

**Failure-mode table (abbreviated; full template: [templates/failure-mode-analysis.md](templates/failure-mode-analysis.md)):**

| Failure | Effect | Detection | Mitigation |
|---|---|---|---|
| Duplicate webhook | Double reservation | — | `webhook_events` unique `(shop_id, webhook_id)`; `processed_commands` PK; partial unique index on live reservation per line |
| Out-of-order webhooks (cancel before create) | Cancel no-op, then reservation for a cancelled order | Order state check | Import job reads order's latest state from Shopify API before reserving; cancel tombstone recorded |
| Worker crash mid-transaction | Nothing committed | Job retry | Transaction atomicity; job retried with same idempotency key |
| Worker crash after commit, before job ack | Job re-runs | — | `processed_commands` returns stored result |
| Deadlock | Transaction aborted | Postgres error 40P01 | Ordered locking; retry with jitter (max 3) |
| Channel API down | ATP stale on channel | `channel_sync_lag_seconds` metric | Outbox persists; worker retries with backoff; coalesce to latest ATP |
| Reconciliation finds drift | Balance ≠ ledger | Nightly job | Alert (page if Critical); auto-freeze reservations for affected SKU; runbook |
| Bug in release path | reserved goes negative | CHECK constraint violation → error | Transaction fails loudly; error alert; no corrupt data |
| Largest tenant flash sale | Lock contention | p95 reservation latency | Per-tenant job concurrency limit; batch lines per order in one tx |

### 5.8 Stage 8 — Trade-offs

**ADR (abbreviated; template: [templates/adr.md](templates/adr.md)):**

```markdown
# ADR-042: Stock reservation uses materialized balances with row locks in Postgres

Status: Accepted — 2026-03-04
Deciders: Backend lead, CTO
Context:
  Need to prevent overselling with correctness as top priority, 50 orders/s peak for
  largest tenant, 2-person backend team, 10-week deadline, existing Postgres + BullMQ.

Options considered:
  A. Atomic conditional UPDATE per line (no explicit locks)
  B. SELECT FOR UPDATE on stock_levels rows (sorted), domain logic in TS, CHECK constraints ← chosen
  C. SERIALIZABLE isolation, compute ATP from movements + reservations on the fly
  D. Redis-based counters (DECRBY with Lua), async persistence to Postgres
  E. Event-sourced Inventory aggregate with separate event store

Decision: B

Consequences / trade-offs:
  + Correctness enforced in DB (CHECKs) and domain code; single transaction boundary
  + Supports multi-line orders + allow_partial logic in readable TypeScript
  + No new infrastructure; team knows Postgres well
  − Hot SKUs serialize on row locks; throughput ceiling per SKU ≈ 1/(lock hold time)
    (measured ~12ms → ~80 reservations/s per SKU; above peak need of ~15/s for top SKU)
  − Materialized balances can drift from ledger if a code path bypasses the module
    → mitigated by module boundary lint + nightly reconciliation + DB role permissions

Rejected:
  A: Simple for single-line, but multi-line all-or-nothing needs a transaction anyway;
     partial logic becomes contorted SQL.
  C: Serialization failures at peak load cause retry storms; aggregate queries over
     movements get slower as ledger grows.
  D: Fast, but Redis is not our durable source of truth; dual-write divergence risk
     violates top priority (correctness). Revisit only if load exceeds 10x.
  E: Strong auditability, but new paradigm for the team + projections + 10-week
     deadline. Movements ledger gives 80% of the audit benefit.

Revisit triggers:
  - Top-SKU reservation rate > 50/s sustained, or p95 lock wait > 50ms
  - Reconciliation drift > 0 more than once per quarter
```

**Risk register:**

| Risk | Likelihood | Impact | Response |
|---|---|---|---|
| Flash sale on single SKU exceeds lock throughput | Low | High | Load test with production distribution; revisit trigger; fallback: pre-sharded "sale buckets" |
| Shopify out-of-order events cause phantom reservations | Medium | Medium | Fetch-latest-state in import; nightly orphan reservation sweep |
| Channel sync lag during Amazon throttling | High at peak | Medium | Coalescing (latest value wins), safety buffer setting per tenant (publish ATP − N) |
| Developers bypass Inventory module and write tables directly | Medium | Critical | Lint boundary rule, DB permission for module-specific role (future), reconciliation |

**Accepted risks (explicit):** channel ATP can be up to ~60s stale → a small residual oversell rate on marketplaces is accepted, mitigated by per-tenant safety buffer.

### 5.9 Stage 9 — Implementation

**Slice plan (de-risk first, value early):**

| Slice | Contents | De-risks |
|---|---|---|
| 0. Walking skeleton (days 1–3) | Migration for `stock_levels` + CHECKs, `reserve()` for one line, job wiring, metric, feature flag, deploy to staging | Deployment, migration on 15M rows, job infra |
| 1. Core reservation (week 1–2) | Multi-line, allow_partial, idempotency, ordered locks, ON_HOLD status | Correctness + concurrency |
| 2. Release & pick consumption (week 3–4) | Cancel, full/partial/short pick, movements ledger | Full lifecycle |
| 3. Backfill (week 4) | Create reservations for existing unpicked orders per tenant, behind flag | Data migration |
| 4. ATP propagation (week 5–6) | Outbox, coalescing publisher, Shopify + Amazon sync | External integration |
| 5. Reconciliation + admin UI (week 7–8) | Nightly job, drift alert, Next.js "Stock explain" page | Operability |
| 6. Rollout (week 9–10) | Tenant-by-tenant flag enablement, largest tenant last | Production risk |

**Domain logic as pure functions (testable without DB):**

```ts
// modules/inventory/domain/reserve.ts
export type StockLevel = {
  skuId: SkuId; onHand: number; reserved: number; quarantined: number;
};

export type LineRequest = { orderLineId: OrderLineId; skuId: SkuId; qty: number };

export type ReservationDecision =
  | { kind: 'reserved'; allocations: Array<{ line: LineRequest; qty: number }> }
  | { kind: 'partially_reserved'; allocations: Array<{ line: LineRequest; qty: number }>;
      shortages: Array<{ orderLineId: OrderLineId; missing: number }> }
  | { kind: 'insufficient'; shortages: Array<{ orderLineId: OrderLineId; missing: number }> };

export const atp = (s: StockLevel) => s.onHand - s.reserved - s.quarantined;

export function decideReservation(
  levels: ReadonlyMap<SkuId, StockLevel>,
  lines: readonly LineRequest[],
  allowPartial: boolean,
): ReservationDecision {
  // Aggregate demand per SKU: an order may contain the same SKU on two lines.
  const remaining = new Map<SkuId, number>();
  for (const [skuId, level] of levels) remaining.set(skuId, Math.max(0, atp(level)));

  const allocations: Array<{ line: LineRequest; qty: number }> = [];
  const shortages: Array<{ orderLineId: OrderLineId; missing: number }> = [];

  for (const line of lines) {
    if (!Number.isInteger(line.qty) || line.qty <= 0) throw new InvalidQuantity(line);
    const avail = remaining.get(line.skuId) ?? 0;
    const granted = Math.min(avail, line.qty);
    if (granted < line.qty) shortages.push({ orderLineId: line.orderLineId, missing: line.qty - granted });
    if (granted > 0) allocations.push({ line, qty: granted });
    remaining.set(line.skuId, avail - granted);
  }

  if (shortages.length === 0) return { kind: 'reserved', allocations };
  if (!allowPartial) return { kind: 'insufficient', shortages };
  return allocations.length > 0
    ? { kind: 'partially_reserved', allocations, shortages }
    : { kind: 'insufficient', shortages };
}
```

**Application service (transaction, locks, idempotency):**

```ts
// modules/inventory/application/reserve-stock.ts
export async function reserveStock(db: Db, cmd: ReserveCommand): Promise<ReserveResult> {
  return withRetry({ on: [DEADLOCK, SERIALIZATION_FAILURE], attempts: 3 }, () =>
    db.transaction(async (tx) => {
      await tx.setTenant(cmd.tenantId); // SET LOCAL app.tenant_id = ... (RLS)

      const prior = await tx.one<{ result: ReserveResult }>(
        `SELECT result FROM processed_commands WHERE tenant_id = $1 AND idempotency_key = $2`,
        [cmd.tenantId, cmd.idempotencyKey]);
      if (prior) return prior.result;

      const skuIds = [...new Set(cmd.lines.map((l) => l.skuId))].sort(); // deterministic lock order
      const rows = await tx.many<StockLevelRow>(
        `SELECT sku_id, on_hand, reserved, quarantined
           FROM stock_levels
          WHERE tenant_id = $1 AND warehouse_id = $2 AND sku_id = ANY($3::uuid[])
          ORDER BY sku_id
          FOR UPDATE`,
        [cmd.tenantId, cmd.warehouseId, skuIds]);

      const levels = new Map(rows.map((r) => [r.sku_id, toStockLevel(r)]));
      const decision = decideReservation(levels, cmd.lines, cmd.allowPartial);

      if (decision.kind !== 'insufficient') {
        for (const { line, qty } of decision.allocations) {
          await tx.exec(
            `UPDATE stock_levels SET reserved = reserved + $4, version = version + 1, updated_at = now()
              WHERE tenant_id = $1 AND warehouse_id = $2 AND sku_id = $3`,
            [cmd.tenantId, cmd.warehouseId, line.skuId, qty]);   // CHECK constraints guard here
          await tx.exec(
            `INSERT INTO reservations (id, tenant_id, warehouse_id, sku_id, order_id, order_line_id, qty, status)
             VALUES ($1,$2,$3,$4,$5,$6,$7,'ACTIVE')`,
            [uuidv7(), cmd.tenantId, cmd.warehouseId, line.skuId, cmd.orderId, line.orderLineId, qty]);
        }
        for (const skuId of new Set(decision.allocations.map((a) => a.line.skuId))) {
          await tx.exec(
            `INSERT INTO outbox (id, tenant_id, topic, aggregate_key, payload)
             VALUES ($1,$2,'stock.atp_changed',$3,$4)`,
            [uuidv7(), cmd.tenantId, `wh:${cmd.warehouseId}:sku:${skuId}`,
             { warehouseId: cmd.warehouseId, skuId }]);
        }
      }

      const result = toResult(decision);
      await tx.exec(
        `INSERT INTO processed_commands (tenant_id, idempotency_key, result) VALUES ($1,$2,$3)`,
        [cmd.tenantId, cmd.idempotencyKey, result]);
      return result;
    }));
}
```

**Boundary enforcement in tooling:**

```js
// eslint.config.js (excerpt) — other modules may only import inventory's public API
import boundaries from 'eslint-plugin-boundaries';
export default [{
  plugins: { boundaries },
  settings: {
    'boundaries/elements': [
      { type: 'module-public', pattern: 'src/modules/*/public.ts', capture: ['module'] },
      { type: 'module-internal', pattern: 'src/modules/*/**', capture: ['module'] },
    ],
  },
  rules: {
    'boundaries/element-types': ['error', {
      default: 'disallow',
      rules: [
        { from: 'module-internal', allow: [['module-internal', { module: '${from.module}' }], 'module-public'] },
      ],
    }],
  },
}];
```

**Next.js admin "Stock explain" page (operability built into the product):**

```tsx
// app/(admin)/inventory/[warehouseId]/[skuId]/page.tsx
import { requireSession } from '@/lib/auth';
import { inventory } from '@/modules/inventory/public-server';

export default async function StockExplainPage({
  params,
}: { params: Promise<{ warehouseId: string; skuId: string }> }) {
  const { warehouseId, skuId } = await params;
  const session = await requireSession({ permission: 'inventory:read' });
  const view = await inventory.explain({ tenantId: session.tenantId, warehouseId, skuId });

  return (
    <section>
      <h1>{view.sku.code} — {view.warehouse.name}</h1>
      <dl>
        <dt>On hand</dt><dd>{view.onHand}</dd>
        <dt>Reserved</dt><dd>{view.reserved} ({view.activeReservations.length} orders)</dd>
        <dt>Quarantined</dt><dd>{view.quarantined}</dd>
        <dt>Available to promise</dt><dd>{view.atp}</dd>
        <dt>Ledger check</dt>
        <dd>{view.ledgerOnHand === view.onHand ? 'Balanced' : `DRIFT: ledger says ${view.ledgerOnHand}`}</dd>
      </dl>
      <MovementsTable rows={view.recentMovements} />
      <ReservationsTable rows={view.activeReservations} />
    </section>
  );
}
```

### 5.10 Stage 10 — Validation

**Test pyramid for this feature:**

| Level | What | Tooling |
|---|---|---|
| Unit | `decideReservation` examples: exact fit, shortage, same SKU on two lines, partial | Vitest |
| Property-based | For random stock levels and line sets: allocations never exceed ATP; Σ granted + Σ missing = Σ requested; `insufficient` never has allocations when `!allowPartial` | fast-check |
| Integration (real Postgres) | CHECK constraints reject violations; idempotent replay returns same result; RLS blocks cross-tenant | Testcontainers Postgres 16 |
| Concurrency | 200 parallel reservations on SKU with on_hand=50 → exactly 50 reserved, 150 insufficient, no errors except expected | Vitest + parallel promises against real DB |
| Contract | Shopify webhook fixtures (real captured payloads, redacted) map correctly | Fixture tests |
| Load | Replay largest tenant's Black Friday order distribution at 2x (100 orders/s) | k6 against staging |
| Chaos-lite | Kill worker mid-batch; drop Redis; throttle channel API | Staging scripts |
| Reconciliation | Seed drift, confirm job detects and alerts | Integration |

**Property test:**

```ts
import fc from 'fast-check';
import { decideReservation, atp } from './reserve';

const levelArb = fc.record({
  onHand: fc.integer({ min: 0, max: 100 }),
  reserved: fc.integer({ min: 0, max: 100 }),
  quarantined: fc.integer({ min: 0, max: 100 }),
}).filter((l) => l.reserved + l.quarantined <= l.onHand);

test('never allocates more than ATP per SKU, and accounts for every unit', () => {
  fc.assert(fc.property(
    fc.dictionary(fc.constantFrom('a', 'b', 'c'), levelArb, { minKeys: 1 }),
    fc.array(fc.record({ skuId: fc.constantFrom('a', 'b', 'c'), qty: fc.integer({ min: 1, max: 60 }) }),
             { minLength: 1, maxLength: 6 }),
    fc.boolean(),
    (levelsObj, rawLines, allowPartial) => {
      const levels = new Map(Object.entries(levelsObj).map(([k, v]) => [k, { skuId: k, ...v }]));
      const lines = rawLines.map((l, i) => ({ ...l, orderLineId: `L${i}` }));
      const d = decideReservation(levels as any, lines as any, allowPartial);

      const granted = new Map<string, number>();
      const allocs = d.kind === 'insufficient' ? [] : d.allocations;
      for (const a of allocs) granted.set(a.line.skuId, (granted.get(a.line.skuId) ?? 0) + a.qty);
      for (const [sku, g] of granted) {
        const lvl = levels.get(sku);
        expect(g).toBeLessThanOrEqual(lvl ? Math.max(0, atp(lvl)) : 0);
      }
      const requested = lines.reduce((s, l) => s + l.qty, 0);
      const missing = d.kind === 'reserved' ? 0 : d.shortages.reduce((s, x) => s + x.missing, 0);
      const grantedTotal = allocs.reduce((s, a) => s + a.qty, 0);
      if (d.kind !== 'insufficient') expect(grantedTotal + missing).toBe(requested);
      if (d.kind === 'insufficient' && !allowPartial) expect(missing).toBeGreaterThan(0);
    }));
});
```

**Concurrency test against real Postgres:**

```ts
test('200 concurrent single-unit reservations on 50 units reserve exactly 50', async () => {
  await seedStock({ tenantId, warehouseId, skuId, onHand: 50 });
  const results = await Promise.allSettled(
    Array.from({ length: 200 }, (_, i) =>
      reserveStock(db, cmdFor({ orderLineId: `line-${i}`, qty: 1, allowPartial: false }))));

  const reserved = results.filter((r) => r.status === 'fulfilled' && r.value.kind === 'reserved').length;
  const rejected = results.filter((r) => r.status === 'fulfilled' && r.value.kind === 'insufficient').length;
  const errors   = results.filter((r) => r.status === 'rejected');

  expect(errors).toHaveLength(0);
  expect(reserved).toBe(50);
  expect(rejected).toBe(150);
  expect(await getStock({ tenantId, warehouseId, skuId })).toMatchObject({ onHand: 50, reserved: 50 });
});
```

**Security validation:** threat model delta reviewed (webhook spoofing → HMAC; cross-tenant ATP read → RLS test; scanner device theft → device token revocation). See [templates/threat-model.md](templates/threat-model.md).

**Load test result (recorded in design doc):** 100 orders/s for 15 min, p95 reservation 41ms, p99 118ms, 0 invariant violations, top-SKU lock wait p99 22ms. Meets target with ~2x headroom.

### 5.11 Stage 11 — Operations

**SLIs/SLOs:**

| SLI | SLO | Alert |
|---|---|---|
| Reservation job success rate (excluding `insufficient`) | 99.9% / 30 days | Burn rate > 14.4x over 1h → page |
| Reservation p95 latency | < 150ms | > 300ms for 15 min → ticket |
| Order import lag (webhook received → reserved) | p95 < 30s | > 5 min for 10 min → page |
| Channel ATP sync lag | p95 < 60s | > 10 min → ticket; > 30 min → page |
| Reconciliation drift count | 0 | Any drift → page (Critical invariant) |
| CHECK constraint violations | 0 | Any → page (indicates code bug) |

**Business metric dashboard:** oversell cancellations per tenant per week (the success metric from Stage 1); reservations created/released/consumed per hour; ON_HOLD_STOCK orders count.

**Nightly reconciliation job (verifies INV-STK-04 and INV-STK-05):**

```sql
-- Drift between materialized balances and facts
WITH ledger AS (
  SELECT tenant_id, warehouse_id, sku_id, SUM(quantity) AS ledger_on_hand
    FROM stock_movements GROUP BY 1,2,3
), live_res AS (
  SELECT tenant_id, warehouse_id, sku_id, SUM(qty - consumed_qty) AS live_reserved
    FROM reservations WHERE status IN ('ACTIVE','PARTIALLY_CONSUMED') GROUP BY 1,2,3
)
SELECT s.tenant_id, s.warehouse_id, s.sku_id,
       s.on_hand,  COALESCE(l.ledger_on_hand, 0) AS ledger_on_hand,
       s.reserved, COALESCE(r.live_reserved, 0)  AS live_reserved
  FROM stock_levels s
  LEFT JOIN ledger   l USING (tenant_id, warehouse_id, sku_id)
  LEFT JOIN live_res r USING (tenant_id, warehouse_id, sku_id)
 WHERE s.on_hand  <> COALESCE(l.ledger_on_hand, 0)
    OR s.reserved <> COALESCE(r.live_reserved, 0);
```

**Runbook excerpt ([templates/runbook.md](templates/runbook.md)):**

```markdown
## Alert: inventory_reconciliation_drift > 0
Severity: SEV-2 (page business hours) / SEV-1 if tenant is Enterprise tier during peak

1. Open Grafana "Inventory Integrity" → drift table lists (tenant, warehouse, sku).
2. For each row open Admin → Inventory → Stock explain. Compare ledger vs balance.
3. Freeze reservations for affected SKUs: `pnpm ops inventory:freeze --tenant <id> --sku <id>`
   (sets stock_levels.frozen = true; reservation logic treats ATP as 0).
4. Identify cause: query movements and reservations updated in the last 24h for the key;
   check deploy log for changes to inventory module; check for direct SQL by support.
5. Repair ONLY via compensating movement (type ADJUSTMENT, reason RECONCILIATION_FIX,
   reference = incident id). Never UPDATE stock_levels directly.
6. Unfreeze; confirm ATP propagated to channels.
7. File postmortem if root cause is a code path (templates/postmortem.md).
```

**Rollout plan:** feature flag `inventory.reservations` per tenant; enable internal test tenant → 3 small tenants (1 week, compare oversell rate) → 50% → largest tenant after a load test replay of their data; kill switch returns to legacy pick-time deduction while keeping reservation tables for later backfill.

**Evolution learnings fed back (post-launch, week 4):**
- Oversell cancellations dropped from 1.8% to 0.07% (success metric met).
- Channel sync lag spikes during Amazon throttling → added per-tenant configurable safety buffer (new requirement discovered in Operations, fed back to Problem/Requirements).
- Support staff asked "why is this order on hold?" 40 times/week → added explain panel on the order page (operability as product feature).

---

## 6. Design Artifacts and Where They Live

| Artifact | Format | Location | Lifetime |
|---|---|---|---|
| Problem statement | Markdown section | Design doc (`docs/design/2026-03-stock-reservation.md`) | Frozen after approval |
| Requirements & quality scenarios | Gherkin + table | Design doc; Gherkin also as acceptance tests | Living (tests) |
| Glossary | Markdown table | `docs/domain/glossary.md` | Living |
| State machines | Mermaid / ASCII | `docs/domain/` + encoded in code | Living |
| Invariant register | Table | `docs/invariants.md` ([template](templates/invariant-register.md)) | Living; reviewed each quarter |
| Data model | SQL migrations (truth) + ERD | `db/migrations/`, generated ERD | Living (migrations are truth) |
| Context/container diagrams | C4 (Structurizr / Mermaid) | `docs/architecture/` | Living; updated when boundaries change |
| API/event contracts | OpenAPI / JSON Schema / TS types | `contracts/` | Versioned |
| ADRs | Markdown, numbered | `docs/adr/NNNN-title.md` ([template](templates/adr.md)) | Immutable; superseded by new ADRs |
| Failure-mode analysis | Table | Design doc + `docs/fmea/` ([template](templates/failure-mode-analysis.md)) | Updated after incidents |
| Threat model | STRIDE table | `docs/security/` ([template](templates/threat-model.md)) | Updated per feature |
| Test suites | Code | Repo | Living |
| SLOs, dashboards, alerts | Code (Terraform/Grafana JSON) | `ops/` | Living |
| Runbooks | Markdown | `docs/runbooks/` ([template](templates/runbook.md)) | Living; tested in game days |

The principle: **design artifacts that must stay true become code or checks** (migrations, types, tests, lint rules, alerts). Prose artifacts capture *why* (problem, trade-offs, ADRs). See [10-knowledge-into-systems.md](10-knowledge-into-systems.md).

---

## 7. Amateur vs Professional vs Expert

| Dimension | Amateur | Professional | Expert |
|---|---|---|---|
| Starting point | Opens the editor; picks a framework | Reads the ticket; asks clarifying questions | Reframes the request into a problem statement with metrics and non-goals |
| Requirements | Features only | Features + "should be fast/secure" | Features + measurable quality attribute scenarios + explicit priority order |
| Constraints | Unaware or imagined | Known but unverified | Enumerated, verified, labeled hard/soft; false constraints removed |
| Domain | Uses UI/DB names as domain concepts | Has entities and relationships | Ubiquitous language, lifecycles, state machines, invariants — validated with domain experts |
| Data | Tables mirror screens | Normalized schema | Ownership, consistency matrix, snapshots vs live refs, volume/skew projections, retention |
| Boundaries | Folders by file type | Services/modules by noun | Contexts by business capability and data ownership; contracts; trust boundaries marked |
| Failure | Happy path + `catch(log)` | Retries and error pages | Failure-mode table incl. "succeeded but unknown"; idempotency; compensation; reconciliation |
| Concurrency | Not considered | Aware of race conditions in theory | Identifies every read-modify-write; picks strategy per hotspot; tests concurrency explicitly |
| Scale | "Use microservices to scale" or ignores | Adds caching and replicas | Load model by dimension incl. skew; scales only the hot paths; keeps the rest boring |
| Trade-offs | Not recorded; "best practice" | Discussed in meetings | ADRs with rejected options, consequences, and revisit triggers |
| Validation | Manual click-through | Unit + integration tests | Property tests of invariants, concurrency tests on real DB, load tests with production distributions |
| Operations | "Ops will handle it" | Logs and a health check | SLOs tied to success metrics, reconciliation, runbooks, admin repair tools, staged rollout with kill switch |
| Output of design phase | None, or a big diagram nobody reads | A design doc | A small set of decisions and constraints that are enforced by code, DB, tests, and alerts |

---

## 8. Anti-Patterns in the Design Phase

| Anti-pattern | Symptom | Expert correction |
|---|---|---|
| **Solution-first design** | "We need Kafka" before anyone states the problem | Problem statement → requirements → then options |
| **Resume-driven architecture** | Choosing tech the team wants to learn | Constraints include team skills and operational capacity |
| **Diagram theater** | Beautiful diagrams, no invariants, no failure modes | Require invariant list and failure-mode table in every design doc |
| **Analysis paralysis** | Three weeks debating two-way-door decisions | Timebox; decide two-way doors fast; spike the uncertain one-way doors |
| **Framework-default architecture** | Structure is whatever `create-next-app` generated; business logic in route handlers | Explicit module boundaries and domain layer independent of framework |
| **Average-case design** | Tested with uniform data | Model skew; test with largest tenant's real distribution |
| **Invisible assumptions** | "Webhooks arrive once, in order" | Write assumptions down; verify against provider docs and observed behavior |
| **Design by consensus without decision** | Meeting ends with "let's think more" | Named decider; ADR with date |
| **Big design, no slices** | Six months before first deploy | Walking skeleton in week 1; vertical slices ordered by risk |
| **Design doc as write-only artifact** | Doc written, never updated, contradicts code | Enforce the durable parts as code; keep ADRs immutable and superseded properly |
| **Security & ops as later phases** | "We'll add auth/monitoring before launch" | Trust boundaries and SLIs are in Stage 6 and 7, not Stage 11 |

---

## 9. Key Takeaways

1. **Design effort should be proportional to the cost of being wrong times the difficulty of reversal.** Data models, public contracts, consistency guarantees, tenancy, and security boundaries deserve deep thought; most other decisions don't.
2. **Requests are solution hypotheses.** Reframe into a problem statement with measurable success and explicit non-goals before designing anything.
3. **Quality attributes drive architecture, not features.** Get numbers, and get a priority order for when they conflict.
4. **Verify constraints.** Half of them are folklore; removing a false constraint can eliminate the hardest part of a design.
5. **Invariants are the definition of correctness.** List them during domain modeling and assign enforcement layers before writing code (see [09-invariants-and-correctness.md](09-invariants-and-correctness.md)).
6. **Every remote call has three outcomes: success, failure, unknown.** Idempotency, outbox, and reconciliation exist to handle "unknown."
7. **Assume every line runs concurrently on multiple machines.** Identify read-modify-write patterns and choose a concurrency control strategy per hotspot.
8. **Consistency is a budget.** Spend strong consistency only where inconsistency is an incident; make the rest explicitly eventual with bounds and convergence mechanisms.
9. **Scale along a dimension, and model skew.** Explicitly decide what does *not* need to scale, and keep it boring.
10. **The mental sequence is iterative but ordered:** Problem → Requirements → Constraints → Domain → Data → Boundaries → Architecture → Trade-offs → Implementation → Validation → Operations — with each stage producing a concrete artifact.
11. **Durable design decisions should become enforcement:** migrations with constraints, lint rules for boundaries, property and concurrency tests, SLO alerts, reconciliation jobs.

---

## 10. Self-Assessment Checklist

Use this on your next non-trivial feature:

```text
[ ] I wrote a problem statement with no solution words, a success metric, and non-goals
[ ] Quality attributes are expressed as measurable scenarios, with a priority order
[ ] Constraints are listed and marked hard/soft; at least one assumption was verified
[ ] I have a glossary for ambiguous terms and a state machine for each lifecycle entity
[ ] I listed invariants and chose enforcement layers (code + DB + tests) for critical ones
[ ] I have a consistency matrix: strong vs eventual (with lag bound) vs snapshot
[ ] Every datum has a single owner; boundaries and trust boundaries are drawn
[ ] Failure-mode table covers success / failure / unknown for every remote call
[ ] Every read-modify-write has a named concurrency control strategy and a concurrency test
[ ] Each dependency has a defined degraded mode and a timeout
[ ] I have a load model with p50 and max (skew), and I named what does NOT need to scale
[ ] Sync vs async decisions are explicit; async flows have idempotency and DLQ plans
[ ] Immutable and auditable data are identified and enforced in the database
[ ] One-way-door decisions have ADRs with rejected alternatives and revisit triggers
[ ] Implementation starts with a walking skeleton; slices are ordered by risk
[ ] SLOs, dashboards, alerts, and a runbook exist before the feature reaches all users
```
