# 14 — The Expert Development Loop

> High-quality teams run every change through the same loop: understand, model, design, decide, implement, verify, review, release, observe, learn, and improve. Each stage produces artifacts that make the next stage cheaper and safer. What separates amateurs from experts is not whether they "follow a process." Experts scale each stage to the risk of the change and turn the output of every loop into lasting improvements to their system.

---

## Table of Contents

1. [Why a Loop, Not a Line](#1-why-a-loop-not-a-line)
2. [The Improved Loop](#2-the-improved-loop)
3. [Stage-by-Stage Deep Dive](#3-stage-by-stage-deep-dive)
   - 3.1 Understand
   - 3.2 Model
   - 3.3 Design
   - 3.4 Decide
   - 3.5 Plan & Slice
   - 3.6 Specify Verification
   - 3.7 Implement
   - 3.8 Test
   - 3.9 Review
   - 3.10 Measure
   - 3.11 Release (Deploy)
   - 3.12 Observe
   - 3.13 Learn
   - 3.14 Improve
4. [Artifacts Master Table](#4-artifacts-master-table)
5. [Scaling the Loop to Risk](#5-scaling-the-loop-to-risk)
6. [Inner Loop vs Outer Loop](#6-inner-loop-vs-outer-loop)
7. [One Feature Traced Through the Whole Loop](#7-one-feature-traced-through-the-whole-loop)
8. [Amateur vs Professional vs Expert Loops](#8-amateur-vs-professional-vs-expert-loops)
9. [Key Takeaways](#key-takeaways)
10. [Self-Assessment Checklist](#self-assessment-checklist)

Related: [03-how-experts-design.md](03-how-experts-design.md), [04-architectural-decision-making.md](04-architectural-decision-making.md), [05-quality-engineering.md](05-quality-engineering.md), [09-invariants-and-correctness.md](09-invariants-and-correctness.md), [10-knowledge-into-systems.md](10-knowledge-into-systems.md), [13-ai-and-agents.md](13-ai-and-agents.md), [templates/design-doc.md](templates/design-doc.md), [templates/adr.md](templates/adr.md), [templates/definition-of-done.md](templates/definition-of-done.md), [templates/postmortem.md](templates/postmortem.md).

---

## 1. Why a Loop, Not a Line

### What

A development *line* ends at "deployed." A development *loop* feeds what happens in production (metrics, incidents, user behavior, review findings) back into understanding and into the engineering system.

```text
Line (amateur):   Idea → Code → Ship → (forget)

Loop (expert):    Understand → Model → Design → Decide → Plan → Specify verification
                        ↑                                                  ↓
                     Improve ← Learn ← Observe ← Release ← Measure ← Review ← Test ← Implement
```

### Why

1. **Software is never finished.** Most of a system's lifetime cost comes after first release.
2. **Your first understanding is always partly wrong.** Production is the only full test of your assumptions.
3. **Lessons that don't feed back get relearned at full price.** The same class of bug shows up every quarter.
4. **The loop compounds.** Each pass improves not only the product but the *process that builds the product*: templates, checks, conventions ([10-knowledge-into-systems.md](10-knowledge-into-systems.md)).

### How

Treat each stage as a transformation with defined **inputs**, **key questions**, **activities**, **artifacts (outputs)**, and **exit criteria**. Size each stage to the risk (Section 5).

### Example

Two teams build "coupon codes" for an e-commerce store.
- **Team Line** ships in 3 days. In week two, a coupon posted on a deal forum gets redeemed 40,000 times because "one per customer" was checked in the UI only. They patch it and move on. Three months later, a gift card feature has the same flaw.
- **Team Loop** ships in 5 days with redemption limits enforced by a DB unique constraint and a threat model entry for "coupon abuse." When a (different) abuse pattern appears, their monitoring alerts on redemption rate anomalies. The postmortem produces a reusable "promotional abuse" checklist that the gift card feature later uses.

### Expert Mental Model

> "Every change is an experiment on a live system. I run it on purpose: stated hypothesis, controlled rollout, measurement, and a written conclusion that changes how we work next time."

### Common Mistake

Treating process as ceremony. Stages exist to produce *decisions and evidence*. If a stage produces neither, it's either wrongly sized or pointless for that change.

---

## 2. The Improved Loop

The prompt's baseline loop is `Understand → Model → Design → Decide → Implement → Test → Review → Measure → Observe → Deploy → Learn → Improve`. Two refinements make it more accurate to how strong teams actually work:

1. **Add "Plan & Slice" and "Specify Verification" before Implement.** Experts decide *how to break the work into safe increments* and *how correctness will be proven* before writing code. This is where most rework is avoided, and it is essential with AI agents ([13-ai-and-agents.md](13-ai-and-agents.md)).
2. **Put Release before Observe, and split release from deploy.** You can't observe production behavior before deploying. Modern teams also separate *deploy* (code is in production) from *release* (users get the behavior) using feature flags.

```text
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                               THE EXPERT DEVELOPMENT LOOP                            │
│                                                                                      │
│   PROBLEM SPACE                  SOLUTION SPACE                 EVIDENCE SPACE       │
│   ─────────────                  ──────────────                 ──────────────       │
│   1. Understand                  3. Design                      8.  Test             │
│   2. Model                       4. Decide                      9.  Review           │
│                                  5. Plan & Slice                10. Measure          │
│                                  6. Specify Verification        11. Release          │
│                                  7. Implement                   12. Observe          │
│                                                                                      │
│                              SYSTEM SPACE (feeds everything)                         │
│                              ────────────                                            │
│                              13. Learn                                               │
│                              14. Improve  ──► conventions, templates, checks, skills │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

| # | Stage | One-line purpose | Primary artifact |
|---|---|---|---|
| 1 | Understand | Know the real problem and why it matters | Problem statement, acceptance criteria |
| 2 | Model | Capture domain concepts, invariants, and states | Domain model, invariant list, state diagram |
| 3 | Design | Generate and evaluate solution options | Design doc / sketch |
| 4 | Decide | Commit to trade-offs explicitly | ADR |
| 5 | Plan & Slice | Break into safe, shippable increments | Task breakdown, rollout plan |
| 6 | Specify Verification | Define how correctness is proven | Test plan, failing tests, SLO/metric targets |
| 7 | Implement | Build the smallest correct increment | Code, migrations, config |
| 8 | Test | Produce evidence of correctness | Green test suites, test reports |
| 9 | Review | Independent check of design, correctness, security | Approved PR, review notes |
| 10 | Measure | Quantify non-functional properties before release | Benchmarks, bundle/perf budgets, load test results |
| 11 | Release | Get to users safely and reversibly | Deployment record, flag rollout, release notes |
| 12 | Observe | Verify behavior in production | Dashboards, alerts, SLO reports |
| 13 | Learn | Extract conclusions from outcomes | Postmortem, retro notes, metric analysis |
| 14 | Improve | Change the system so lessons stick | New checks, templates, conventions, backlog items |

---

## 3. Stage-by-Stage Deep Dive

Every stage below uses the same structure: **What → Why → Key questions → Activities → Artifacts → Exit criteria → Amateur shortcut and its cost → Expert Mental Model → Common Mistake.**

### 3.1 Understand

**What:** Build a correct, shared understanding of the problem, the users, the business outcome, and the constraints before choosing any solution.

**Why:** The most expensive bug is building the wrong thing. A defect in requirements found in production can cost 10–100× what it costs to find in a conversation. It also usually can't be fixed with code alone, because it needs migrations, customer communication, and rework across layers.

**Key questions:**
```text
- Who has this problem, and what are they doing today instead?
- What outcome defines success? How will we measure it?
- What happens if we do nothing?
- What is explicitly out of scope?
- What constraints exist? (deadline, regulation, budget, existing contracts, team skills)
- Who else is affected? (support, finance, ops, other services, integrations)
- What are the non-functional expectations? (latency, volume, availability, audit, data retention)
- What's the smallest version that delivers the outcome?
```

**Activities:**
- Talk to the requester and, ideally, to a real user.
- Read the existing code paths and data involved.
- Pull real numbers: row counts, request rates, peak times, current error rates.
- Rewrite the request as a problem statement and acceptance criteria. Get agreement.

**Artifacts:**
- Problem statement (1 paragraph)
- Acceptance criteria (Given/When/Then or a bullet list)
- Non-goals list
- Constraints and known numbers

```markdown
## Problem
B2B customers pay large invoices in installments. Today finance manually marks invoices
"paid" after the last installment, so dashboards show outstanding balances wrongly for weeks,
and dunning emails go to customers who have partially paid (18 support tickets last month).

## Success
- Outstanding balance on dashboards is accurate within 1 minute of payment.
- Zero dunning emails sent for invoices with any payment in the last 7 days (policy TBD with finance).

## Acceptance criteria
- An invoice can receive multiple payments; balance = total − sum(successful payments − refunds).
- Status derives from balance: issued (no payments), partially_paid, paid, overpaid(flagged).
- Finance can see payment history per invoice.

## Non-goals
- Customer-facing installment plans/scheduling. Multi-currency payments on one invoice.

## Constraints & numbers
- invoices: 41M rows; payments: 12M rows; ~2,000 payments/day, peak 40/min at month end.
- Payment provider webhooks may be delivered more than once and out of order.
- SOX-relevant: payment and status changes must be auditable.
```

**Exit criteria:** The requester agrees with the problem statement and acceptance criteria. Non-goals are explicit. Key numbers are known or explicitly flagged as unknown.

**Amateur shortcut and cost:** Starts coding from the ticket title ("support partial payments"). Cost: builds installment *scheduling* (not asked for), misses the dunning problem (the actual pain), rewrites after the demo, and has to fix data already written in the wrong shape.

**Expert Mental Model:** "I'm not ready to design until I can explain the problem, the success measure, and the non-goals to someone else in two minutes."

**Common Mistake:** Treating the requested *solution* as the *problem*. "Add a 'partially paid' checkbox" is a solution. The problem is inaccurate balances and wrong dunning.

### 3.2 Model

**What:** Describe the domain precisely: entities, relationships, lifecycle states, legal transitions, invariants, and ownership of data. See [09-invariants-and-correctness.md](09-invariants-and-correctness.md).

**Why:** Code carries the model. A wrong model leaks into every layer (DB, API, UI, reports) and becomes very expensive to change. Invariants found at this stage can be enforced structurally. Invariants found in production get enforced with cleanup scripts.

**Key questions:**
```text
- What are the nouns (entities/value objects) and who owns each?
- What states can each entity be in? Which transitions are legal? Who triggers them?
- What must ALWAYS be true? (invariants)
- What is derived vs stored? What is the source of truth?
- What must be consistent immediately vs eventually?
- What must be auditable / immutable?
- What identifies each thing uniquely? (natural vs surrogate keys, idempotency keys)
```

**Activities:** Domain vocabulary list, state diagram, invariant list, entity-relationship sketch, event list (if relevant).

**Artifacts:**
```text
Entities: Invoice, Payment, Refund, AuditEvent
Invoice states: draft → issued → (partially_paid ⇄ paid) → void (only if no successful payments)
Payment states: pending → succeeded | failed; succeeded → (partially_)refunded

Invariants (→ invariant register):
  INV-1  sum(succeeded payments) − sum(refunds) = invoice.amount_paid          [stored, reconciled]
  INV-2  invoice.status is a pure function of (amount_total, amount_paid, voided)
  INV-3  a provider payment id is recorded at most once                         [idempotency]
  INV-4  refunds for a payment never exceed that payment's amount
  INV-5  an invoice with succeeded payments cannot be voided
  INV-6  every payment/refund/status change emits an immutable audit event
  INV-7  a tenant can never read or write another tenant's invoices or payments
```

**Exit criteria:** State diagram and invariants reviewed by someone who knows the domain (for example the finance lead). Source of truth for each fact is named.

**Amateur shortcut and cost:** Adds `status = 'partially_paid'` as a column updated by webhook handlers. Cost: status and balance drift apart under out-of-order webhooks, and finance reports stop reconciling. The fix needs a backfill across 41M rows and a painful audit explanation.

**Expert Mental Model:** "Data outlives code. I model the truth first and let the code follow it."

**Common Mistake:** Modeling the UI instead of the domain ("the screen has a 'paid' toggle, so we store a boolean").

### 3.3 Design

**What:** Generate at least two viable solution options, then evaluate them against requirements, invariants, failure modes, security, performance, and operational cost. See [03-how-experts-design.md](03-how-experts-design.md) and [04-architectural-decision-making.md](04-architectural-decision-making.md).

**Why:** The first idea is rarely the best. It's just the most available one. Comparing options exposes trade-offs that stay hidden when there is only one candidate.

**Key questions:**
```text
- What are 2–3 genuinely different approaches?
- How does each enforce the invariants?
- What can fail (dependency down, duplicate events, crashes mid-operation, concurrency)?
- What are the trust boundaries and abuse cases? (threat model)
- What are the performance and scale characteristics at 10× current load?
- How will it be migrated/rolled out without downtime? How is it rolled back?
- How will we observe it in production?
- What's the operational cost and who operates it?
```

**Activities:** Option sketches, sequence diagrams for the critical flows, failure mode analysis ([templates/failure-mode-analysis.md](templates/failure-mode-analysis.md)), threat model ([templates/threat-model.md](templates/threat-model.md)), rough capacity math, migration plan sketch.

**Artifacts:** Design doc ([templates/design-doc.md](templates/design-doc.md)) with options, trade-offs, failure modes, threat model entries, rollout/migration outline, and observability plan.

**Exit criteria:** At least two options compared in writing. Each invariant has an enforcement mechanism. Top failure modes have a mitigation. The design has been reviewed by at least one other engineer for T2/T3 changes.

**Amateur shortcut and cost:** Designs in the editor. Cost: discovers during implementation that webhooks arrive out of order, then bolts on locking. Discovers during deploy that adding a NOT NULL column to 41M rows locks the table, which means a 20-minute outage.

**Expert Mental Model:** "Design is where I get to be wrong cheaply. An hour here saves a week of implementation and a month of production pain."

**Common Mistake:** Writing a design doc that only describes the chosen solution. Without alternatives, it's documentation, not design.

### 3.4 Decide

**What:** Commit to one option, stating the trade-offs accepted, the risks, and the conditions that would make you revisit it. Record it in an ADR ([templates/adr.md](templates/adr.md)).

**Why:**
- Decisions without recorded reasons get re-argued forever or blindly reversed.
- Writing down "we accept X" forces you to notice that X is being accepted.
- Future maintainers (including agents and you in 8 months) need the *why*, not just the *what*.

**Key questions:**
```text
- Which option, and why this one over the others?
- What are we giving up?
- What risks remain, and how are they mitigated or monitored?
- Is this reversible? What would it cost to reverse?
- What signal would tell us this decision was wrong?
- Who needs to agree, and have they?
```

**Activities:** Short decision meeting or async review. Write the ADR. Get approvals proportional to risk.

**Artifacts:** ADR with context, options, decision, consequences, and revisit triggers.

**Exit criteria:** ADR merged (or accepted status). Stakeholders who own affected areas have signed off.

**Amateur shortcut and cost:** The decision lives in a Slack thread. Cost: six months later a new engineer "simplifies" derived status back into a stored column, reintroducing drift, because nobody knew why it was derived.

**Expert Mental Model:** "Reversible decisions I make fast. Irreversible ones I make slowly and write down."

**Common Mistake:** Writing ADRs *after* implementation to justify what was built. At that point they're just documentation of an outcome.

### 3.5 Plan & Slice

**What:** Break the work into small, independently deployable, independently verifiable increments, ordered to reduce risk early, with a rollout and rollback plan.

**Why:**
- Small increments give fast feedback and easy review, and they make bisecting and rollback possible.
- Ordering by risk surfaces the scariest unknown (the migration, the concurrency behavior) first, while it's still cheap to change course.
- Each slice can be verified alone, which is critical when agents implement slices ([13-ai-and-agents.md](13-ai-and-agents.md)).

**Key questions:**
```text
- What is the riskiest assumption, and how do we test it first?
- Can each slice deploy to production safely on its own (dark / behind a flag)?
- What's the expand/contract sequence for data changes?
- Where is the point of no return, and what must be true before crossing it?
- How do we roll back each slice?
```

**Activities:** Slice list, dependency ordering, migration choreography, feature flag plan, rollout stages.

**Artifacts:**
```text
Slice 1  Expand: create payments_v2 table, audit_events; no reads yet                 (deploy dark)
Slice 2  Domain: Payment/Invoice aggregate + invariants + property tests             (no wiring)
Slice 3  Webhook ingestion v2: idempotent upsert into payments_v2 (dual-write)       (flag: payments_v2_write)
Slice 4  Backfill historical payments (batched job) + reconciliation report          (ops runbook)
Slice 5  Read path: balance/status from derived model behind flag                   (flag: payments_v2_read, 1% → 100%)
Slice 6  Dunning uses derived status                                                 (flag: dunning_v2)
Slice 7  UI: payment history + partial status badges (Next.js)                      (flag)
Slice 8  Contract: remove legacy status writes; drop old columns (after 2 weeks stable)
Rollback: flags off for slices 3,5,6,7; slices 1,2 are inert; slice 8 is the point of no return.
```

**Exit criteria:** Each slice has a definition of done and verification method. Point of no return identified with preconditions.

**Amateur shortcut and cost:** One giant branch for three weeks. Cost: merge conflicts, a 4,000-line PR nobody properly reviews, a big-bang deploy, and a rollback that also reverts unrelated fixes.

**Expert Mental Model:** "I don't ship features. I ship a sequence of safe, reversible steps that add up to a feature."

**Common Mistake:** Slicing by layer (all DB, then all API, then all UI) instead of by deployable, verifiable value or risk reduction. Layer slices often can't be verified until the end.

### 3.6 Specify Verification

**What:** Before implementation, define *how* each slice will be proven correct and safe: test cases, invariant tests, concurrency tests, performance targets, security tests, and production success metrics.

**Why:**
- Tests written after code tend to describe the code, bugs included.
- Knowing the verification first shapes a testable design (pure domain logic, injectable clocks, idempotent handlers).
- It gives humans and agents an objective finish line.

**Key questions:**
```text
- What test cases prove each acceptance criterion?
- What property/invariant tests protect the model?
- What happens under concurrency and duplication — how do we test that?
- What security tests prove abuse is blocked (cross-tenant, replay, forged webhook)?
- What performance budget must be met, and how will we measure it?
- In production, what metric/alert tells us it works — or doesn't?
```

**Activities:** Test list, failing test skeletons, metric/SLO definitions, benchmark scenario definitions.

**Artifacts:**
```text
Test plan — Slice 3 (webhook ingestion v2)
  Unit:
    - payment.succeeded creates payment; invoice balance updated
    - duplicate provider_payment_id → no second payment (INV-3)
    - out-of-order: refund arrives before succeeded → held/retried, never negative (INV-4)
  Integration (real Postgres):
    - unique constraint rejects duplicate provider id even if app check is bypassed
    - 20 concurrent deliveries of same event → exactly 1 row
    - RLS: tenant A context cannot select tenant B payments (INV-7)
  Security:
    - invalid signature → 401, no DB writes
    - timestamp older than 5 min → 401 (replay)
  Property:
    - for any sequence of payment/refund events (any order, any duplication),
      final amount_paid = Σsucceeded − Σrefunded and ≥ 0
  Production success metrics:
    - webhook_processing_errors_total rate < 0.1%
    - reconciliation job: 0 mismatches between payments_v2 and provider report (daily)
    - p95 webhook handler latency < 300ms
```

**Exit criteria:** Test list approved (for T2/T3). Failing tests exist for the slice about to be implemented. Production metrics defined.

**Amateur shortcut and cost:** "I'll add tests after." Cost: tests never get written for the hard cases (concurrency, duplication). The first proof of the duplication bug is a customer charged twice.

**Expert Mental Model:** "If I can't say how I'll know it works, I don't understand it well enough to build it."

**Common Mistake:** Specifying only happy-path unit tests. Most production incidents come from duplicates, concurrency, partial failure, and abuse.

### 3.7 Implement

**What:** Write the smallest code that makes the slice's verification pass, following conventions, with operability (logging, metrics, timeouts, error handling) built in.

**Why:** Implementation is where design meets reality. Good implementation keeps the design's guarantees intact and stays easy to change.

**Key questions (while coding):**
```text
- Does this follow the existing pattern? If not, why?
- Where does untrusted input enter, and where is it validated?
- What happens if this line fails? If it runs twice? Concurrently?
- Is this the simplest thing that satisfies the tests and invariants?
- Will I be able to debug this at 3am from logs/traces alone?
```

**Activities:** Red-green-refactor, frequent small commits, running the inner loop (Section 6), updating docs next to code.

**Artifacts:** Code, migrations, config, feature flag definitions, updated reference docs, commits with meaningful messages.

```ts
// src/modules/billing/webhooks/handle-payment-event.ts (Slice 3 — excerpt)
export async function handlePaymentEvent(evt: VerifiedProviderEvent, deps: Deps) {
  const log = deps.logger.child({ eventId: evt.id, type: evt.type, tenantId: evt.tenantId });

  return deps.db.transaction().execute(async (trx) => {
    // INV-3: idempotency enforced by unique index on (provider, provider_event_id)
    const inserted = await trx.insertInto('processed_provider_events')
      .values({ provider: 'stripe', provider_event_id: evt.id, received_at: deps.clock.now() })
      .onConflict((oc) => oc.doNothing())
      .returning('provider_event_id')
      .executeTakeFirst();
    if (!inserted) {
      log.info('duplicate event ignored');
      deps.metrics.increment('webhook_duplicate_total');
      return { outcome: 'duplicate' as const };
    }

    // Lock the invoice row to serialize concurrent payment events for the same invoice.
    const invoice = await trx.selectFrom('invoices').selectAll()
      .where('tenant_id', '=', evt.tenantId).where('id', '=', evt.invoiceId)
      .forUpdate().executeTakeFirst();
    if (!invoice) throw new UnknownInvoiceError(evt.invoiceId); // → retried, then DLQ

    const aggregate = InvoicePayments.load(invoice, await loadPayments(trx, invoice.id));
    const change = aggregate.apply(evt);                         // pure domain logic, invariants checked
    await persist(trx, change);
    await appendAudit(trx, change.auditEvents);                  // INV-6
    log.info({ newStatus: change.invoice.status }, 'payment event applied');
    return { outcome: 'applied' as const };
  });
}
```

**Exit criteria:** Verification for the slice passes locally. Conventions followed. No TODOs hiding required behavior. Logging, metrics, and error handling present.

**Amateur shortcut and cost:** Copies a similar handler, tweaks it, and skips idempotency "because the provider rarely duplicates." Cost: rare × 2,000 payments/day = a duplicate every few days, which means double-counted balances and wrong dunning.

**Expert Mental Model:** "Implementation is translating decisions into code faithfully. If I'm making big new decisions while typing, I skipped a stage."

**Common Mistake:** Refactoring unrelated code in the same change. It makes review harder and rollback riskier.

### 3.8 Test

**What:** Run the full verification suite and make sure the evidence is real: tests fail when the behavior is wrong, cover the risky paths, and run in CI in a production-like setup.

**Why:** "Tests pass" is only meaningful if the tests can fail. Testing produces the *evidence* that review and release decisions depend on. See [05-quality-engineering.md](05-quality-engineering.md).

**Key questions:**
```text
- Did each new test fail before the implementation (red)?
- Do integration tests run against real infrastructure (Postgres, Redis), not mocks of them?
- Are concurrency/duplication/failure cases actually exercised?
- Is anything flaky? (Flaky = untrusted = ignored.)
- For critical logic: does mutation testing show tests catch injected faults?
```

**Activities:** Run unit/integration/e2e/property tests, mutation tests on critical modules, check coverage of *risk* (not only lines), fix flakiness at the root.

**Artifacts:** CI run results, coverage and mutation reports, test evidence summary in the PR.

**Exit criteria:** All suites green in CI. New tests proven to fail without the change. No new flaky tests. Critical module mutation score at or above the threshold.

**Amateur shortcut and cost:** Mocks the database in "integration" tests. Cost: the unique constraint, RLS policy, and `FOR UPDATE` behavior are never actually tested. The concurrency bug ships.

**Expert Mental Model:** "Tests are instruments. An instrument that always reads 'OK' is broken."

**Common Mistake:** Retrying flaky tests in CI instead of fixing them. It teaches everyone that red doesn't mean anything.

### 3.9 Review

**What:** An independent examination of the change for correctness, design fit, security, operability, and clarity by someone other than the author (human, with AI assist). See [templates/pull-request.md](templates/pull-request.md).

**Why:** Authors are blind to their own assumptions. Review is the last cheap point to catch design and security issues. It also spreads knowledge, which reduces bus factor.

**Key questions (reviewer):**
```text
- Does this solve the stated problem and match the design/ADR?
- Are invariants enforced where the design said they would be?
- Concurrency, duplication, partial failure: what happens?
- Authorization and tenant scoping: correct and tested?
- Is the migration safe for the table size? Is rollback possible?
- Would I be able to debug this in production?
- Is there anything simpler?
```

**Activities:** Author writes a PR description (context, what changed, how verified, risks, rollout). Reviewer does a structured review. Discussion, revisions, approval.

**Artifacts:** PR description, review comments, approvals, follow-up issues for non-blocking improvements.

```markdown
## PR: Slice 3 — Idempotent payment webhook ingestion (v2) behind flag

### Context
Implements ADR-0042 slice 3. Design doc: docs/design/partial-payments.md

### What changed
- New handler `handlePaymentEvent` with idempotency table + invoice row lock
- Migration: `processed_provider_events` (unique provider+event id)
- Flag `payments_v2_write` (default off) — dual-write alongside legacy path

### Verification
- Unit: 14 tests (all red before implementation — see commit a1b2c3)
- Integration: duplicate delivery ×20 concurrent → 1 row ✅; RLS cross-tenant ✅
- Property test: 1,000 random event sequences, INV-1/INV-4 hold ✅
- Mutation score (billing/domain): 88%

### Risks & rollout
- Row lock on invoices: hold time measured p99 4ms under 50 concurrent events
- Rollout: enable in staging 24h → prod 10% tenants → 100%; kill switch = flag off
- Rollback: flag off; table is additive

### Reviewer focus
- Lock ordering in `persist()` (payments then audit) — deadlock risk with refund handler?
```

**Exit criteria:** Required approvals received (code owners for sensitive paths). All blocking comments resolved. CI green on the final commit.

**Amateur shortcut and cost:** "LGTM" after 90 seconds on a 900-line PR. Cost: the deadlock between the payment and refund handlers (opposite lock order) is found during a month-end spike instead.

**Expert Mental Model:** "Review isn't gatekeeping. It's the cheapest point to find what the author couldn't see."

**Common Mistake:** Reviewing formatting and naming (which tools should enforce) while missing the transaction boundary.

### 3.10 Measure

**What:** Quantify non-functional properties *before* release: latency, throughput, query plans, memory, bundle size, Core Web Vitals, lock hold times, cost. Compare against budgets. See [06-performance-engineering.md](06-performance-engineering.md).

**Why:** Performance and capacity regressions are invisible in functional tests and expensive once they reach production. Measuring before release turns "I think it's fine" into data.

**Key questions:**
```text
- What's the baseline, and what's the new value?
- Do queries use the intended indexes at production data volume? (EXPLAIN ANALYZE on prod-like data)
- Does it meet the budget at expected peak (e.g., month-end 40 payments/min ×10 safety)?
- Did bundle size / LCP / INP regress for affected pages?
- What does it cost to run?
```

**Activities:** Benchmarks, load tests (k6), `EXPLAIN (ANALYZE, BUFFERS)` on a staging copy, Lighthouse CI / bundle analysis for Next.js pages, lock monitoring during load.

**Artifacts:**
```text
Measurement report — Slice 3/5
  Webhook handler (k6, 400 events/min, 10% duplicates, staging w/ prod-size data):
    p50 38ms | p95 121ms | p99 240ms (budget p95 < 300ms) ✅
    errors 0 | duplicates correctly ignored 100%
  Balance query (EXPLAIN ANALYZE):
    Index Scan using payments_invoice_id_idx — 0.4ms (41M invoices / 12M payments) ✅
  Invoice detail page (Lighthouse CI, median of 5):
    LCP 1.6s (budget 2.5s) ✅ | JS for route +3.1KB gz (budget +10KB) ✅
```

```yaml
# lighthouserc.yml (excerpt) — enforce frontend budgets in CI
ci:
  assert:
    assertions:
      largest-contentful-paint: [error, { maxNumericValue: 2500 }]
      interaction-to-next-paint: [warn, { maxNumericValue: 200 }]
      cumulative-layout-shift: [error, { maxNumericValue: 0.1 }]
      total-byte-weight: [warn, { maxNumericValue: 350000 }]
```

**Exit criteria:** Budgets met, or an exception recorded with a follow-up. No unexplained regressions.

**Amateur shortcut and cost:** Tests with 50 rows locally. Cost: the balance query does a sequential scan on 12M payments in production, the invoice list times out at month end, and sales demos fail.

**Expert Mental Model:** "Performance is a requirement with a number, verified with a measurement."

**Common Mistake:** Measuring on a laptop with a toy dataset and calling it done.

### 3.11 Release (Deploy)

**What:** Move the change to production safely, progressively, and reversibly. Separate **deploy** (code running in production) from **release** (behavior exposed to users).

**Why:** Every deploy is a production change, and most outages are caused by changes. Progressive delivery limits blast radius and makes failures cheap to reverse.

**Key questions:**
```text
- Is the deploy automated and repeatable (same pipeline every time)?
- What's the rollout sequence (staging → canary → percentage → all)?
- What automatic health checks gate promotion?
- How fast can we roll back or turn off the flag? Has that been tested?
- Do migrations run before code that depends on them, and are they backward-compatible?
- Who needs to know (support, customers, finance)?
```

**Activities:** Merge → pipeline builds an immutable artifact → deploy to staging → smoke tests → production canary → automated metric checks → promote → progressive flag rollout → release notes.

**Artifacts:** Deployment record (version, time, who/what), flag change log, release notes, updated runbook ([templates/runbook.md](templates/runbook.md)).

```yaml
# .github/workflows/deploy.yml (excerpt) — progressive deploy with automated gate
jobs:
  deploy-canary:
    environment: production
    steps:
      - run: ./scripts/deploy.sh --image "$IMAGE" --canary 10
      - name: Watch canary (10 min)
        run: ./scripts/check-slo.sh --service invoicing --window 10m \
               --max-error-rate 0.5 --max-p95-ms 400 --compare-baseline
  promote:
    needs: deploy-canary
    environment: production
    steps:
      - run: ./scripts/deploy.sh --image "$IMAGE" --promote
  rollback-on-failure:
    needs: deploy-canary
    if: failure()
    steps:
      - run: ./scripts/deploy.sh --rollback
```

**Exit criteria:** Full rollout complete *or* deliberately paused at a stage. Health checks green. Rollback path confirmed. Release communicated.

**Amateur shortcut and cost:** Deploys Friday 5 p.m. with a manual SSH script, migration and code at once, no flag. Cost: the migration takes locks longer than expected, the site is down during peak weekend traffic, and rollback is impossible because the migration dropped a column.

**Expert Mental Model:** "Deploying should be boring. Releasing is a business decision controlled by a flag."

**Common Mistake:** Treating feature flags as permanent. Stale flags are technical debt and a source of combinatorial bugs, so every flag needs a removal date.

### 3.12 Observe

**What:** Verify in production that the change behaves as intended and harms nothing else, using metrics, logs, traces, alerts, and business signals. See [05-quality-engineering.md](05-quality-engineering.md) and [07-designing-for-failure.md](07-designing-for-failure.md).

**Why:** Production has data, traffic patterns, integrations, and users you couldn't simulate. Without observation, "deployed" gets mistaken for "working."

**Key questions:**
```text
- Are the success metrics defined in Specify Verification moving as expected?
- Any new error groups, latency shifts, saturation (DB connections, CPU, queue depth)?
- Are business invariants holding in real data? (reconciliation checks)
- Are users actually using it? Any support tickets?
- Would we know within minutes if it broke?
```

**Activities:** Watch dashboards during rollout, run reconciliation queries/jobs, check error tracker, review alerts, sample traces, talk to support.

**Artifacts:** Dashboard for the feature, alerts with runbook links, reconciliation job output, SLO report.

```sql
-- Reconciliation check (scheduled daily, alerts on any row) — verifies INV-1 in real data
SELECT i.tenant_id, i.id, i.amount_paid_cents,
       COALESCE(SUM(p.amount_cents) FILTER (WHERE p.status = 'succeeded'), 0)
     - COALESCE(SUM(r.amount_cents), 0) AS computed_paid
FROM invoices i
LEFT JOIN payments p ON p.invoice_id = i.id
LEFT JOIN refunds  r ON r.payment_id = p.id
WHERE i.updated_at > now() - interval '2 days'
GROUP BY i.tenant_id, i.id, i.amount_paid_cents
HAVING i.amount_paid_cents <>
       COALESCE(SUM(p.amount_cents) FILTER (WHERE p.status = 'succeeded'), 0) - COALESCE(SUM(r.amount_cents), 0);
```
(Note: in production this join double-counts when a payment has multiple refunds. The real job pre-aggregates refunds per payment in a CTE. Reconciliation queries need tests too.)

**Exit criteria:** Success metrics confirmed over a representative window (for example through one month-end cycle). No unexplained anomalies. Alerts tested.

**Amateur shortcut and cost:** "No one complained, so it works." Cost: 0.3% of payments silently fail to update balances due to an unknown-invoice race. Finance finds it at quarter close, three months later.

**Expert Mental Model:** "I'm done when production data confirms it, not when the pipeline turns green."

**Common Mistake:** Only observing technical metrics (errors, latency) and never checking business correctness (reconciliation, conversion, invariant checks).

### 3.13 Learn

**What:** Extract explicit conclusions from what happened: what went well, what surprised you, what failed, which assumptions were wrong, and why.

**Why:** Experience only becomes expertise when it's reflected on. Teams that don't learn repeat incidents. Teams that do learn get steadily faster and safer.

**Key questions:**
```text
- Did we achieve the outcome defined in Understand? (metrics)
- Which estimates/assumptions were wrong, and why?
- What did review/testing/observation catch — and what escaped?
- For each escape: why didn't an earlier stage catch it?
- What was slow or painful in the loop itself?
```

**Activities:** Blameless postmortem for incidents ([templates/postmortem.md](templates/postmortem.md)), lightweight retro for features, metric review after 2–4 weeks, updating the decision log.

**Artifacts:** Postmortem or retro notes with contributing factors and action items. Updated ADR (for example "Consequences observed").

**Exit criteria:** Each significant surprise has a written contributing-factor analysis and at least one owned action item.

**Amateur shortcut and cost:** Fixes the bug and moves on. Cost: the same root cause (unordered webhook processing) hits the refund feature and the subscription feature later.

**Expert Mental Model:** "An incident I don't learn from is an incident I've scheduled again."

**Common Mistake:** Blame-oriented postmortems ("engineer X forgot"). They lead people to hide information and produce "be more careful" actions, which don't work.

### 3.14 Improve

**What:** Change the *engineering system* (conventions, templates, checks, tests, skills, docs, architecture) so the lesson is enforced automatically from now on. See [10-knowledge-into-systems.md](10-knowledge-into-systems.md) and [12-engineering-operating-system.md](12-engineering-operating-system.md).

**Why:** Action items like "be careful with webhook ordering" decay within weeks. Mechanisms don't.

**Key questions:**
```text
- Can this lesson become: a type? a lint rule? a DB constraint? a test? a template? a CI gate? a skill? an alert?
- Where in the loop should it be caught next time (earliest cheap stage)?
- Does this apply to other projects? → put it in the shared template/library.
- What should we STOP doing? (remove ceremony that didn't help)
```

**Activities:** Implement guardrails, update templates, update AGENTS.md/skills, add reusable library functions, prune useless process steps.

**Artifacts:** Merged guardrail PRs, updated templates/checklists, updated conventions, closed action items.

```text
Lesson: webhook handlers across modules each re-implemented idempotency (3 variants, 1 buggy)
Mechanisms:
  1. Library: `@acme/webhooks` → verifySignature(), processOnce(eventId, fn) with unique-index table
  2. Lint rule: route handlers under app/api/webhooks/** must import from @acme/webhooks
  3. Template: `pnpm gen webhook <provider> <event>` scaffolds handler + duplicate/concurrency tests
  4. Design doc template: new required section "Duplicate & out-of-order delivery"
  5. Project bootstrap checklist: webhooks section added (templates/project-bootstrap-checklist.md)
```

**Exit criteria:** Each action item is either implemented as a mechanism or explicitly rejected with a reason. Shared templates updated where relevant.

**Amateur shortcut and cost:** Writes action items nobody implements. Cost: action item backlogs become graveyards and trust in postmortems collapses.

**Expert Mental Model:** "The output of a mature loop is not only a better product. It's a better factory."

**Common Mistake:** Only adding. Improvement also means *removing* steps, checks, and docs that cost more than they catch.

<!-- CONTINUE -->
