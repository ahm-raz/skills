# 05 — Quality Engineering: What "Quality Engineered" Actually Means

> "The code works" is one data point on one day, in one environment, for the inputs somebody happened to try. Quality is a set of properties the system keeps over time, under load, under attack, under change, and while someone other than the author runs it at 3 a.m.

This chapter breaks software quality into twelve measurable attributes. For each one it covers how professional teams measure it and how they enforce it, so quality comes from the process instead of one developer's discipline. It ends with a real CI pipeline full of quality gates, the trade-offs between attributes, and a way to tell amateur, professional, and expert quality engineering apart.

---

## Table of Contents

1. [The Core Idea: Quality Is a System Property, Not a Personality Trait](#1-the-core-idea-quality-is-a-system-property-not-a-personality-trait)
2. [The Quality Model: Twelve Attributes](#2-the-quality-model-twelve-attributes)
3. [Correctness](#3-correctness)
4. [Reliability](#4-reliability)
5. [Maintainability](#5-maintainability)
6. [Security](#6-security)
7. [Performance](#7-performance)
8. [Scalability](#8-scalability)
9. [Testability](#9-testability)
10. [Observability](#10-observability)
11. [Operability](#11-operability)
12. [Usability](#12-usability)
13. [Evolvability](#13-evolvability)
14. [Recoverability](#14-recoverability)
15. [Delivery Health: DORA Metrics as the Meta-Signal](#15-delivery-health-dora-metrics-as-the-meta-signal)
16. [The Enforcement Stack](#16-the-enforcement-stack)
17. [A Real CI Pipeline With Quality Gates](#17-a-real-ci-pipeline-with-quality-gates)
18. [Testing Strategy: Pyramid, Trophy, and What Actually Matters](#18-testing-strategy-pyramid-trophy-and-what-actually-matters)
19. [Human Gates: Review Checklists, Definition of Done, Release Gates](#19-human-gates-review-checklists-definition-of-done-release-gates)
20. [Quality Trade-offs Between Attributes](#20-quality-trade-offs-between-attributes)
21. [Right-Sizing Quality: Criticality Tiers](#21-right-sizing-quality-criticality-tiers)
22. [Amateur vs Professional vs Expert](#22-amateur-vs-professional-vs-expert)
23. [Common Mistakes](#23-common-mistakes)
24. [Key Takeaways](#key-takeaways)
25. [Self-Assessment Checklist](#self-assessment-checklist)

Related chapters: [03-how-experts-design.md](03-how-experts-design.md) · [06-performance-engineering.md](06-performance-engineering.md) · [07-designing-for-failure.md](07-designing-for-failure.md) · [08-security-engineering.md](08-security-engineering.md) · [09-invariants-and-correctness.md](09-invariants-and-correctness.md) · [10-knowledge-into-systems.md](10-knowledge-into-systems.md) · [templates/definition-of-done.md](templates/definition-of-done.md) · [templates/pull-request.md](templates/pull-request.md)

---

## 1. The Core Idea: Quality Is a System Property, Not a Personality Trait

### What

Quality engineering means designing the **process and the tooling** so that low-quality changes are hard to create, easy to detect, and cheap to reverse. It is the difference between:

```text
"Our developers are careful."
```

and

```text
"A change cannot reach production unless it type-checks, passes lint rules that encode
our conventions, passes unit/integration/contract tests, keeps mutation score above 70%
in the domain layer, adds no high-severity CVEs, respects the bundle budget, gets reviewed
against a checklist, deploys behind a canary that auto-rolls back when the error-rate SLO
burns too fast, and we rehearse database restores monthly."
```

### Why

Personal discipline fails in predictable ways:

| Discipline failure | Why it happens | Systemic replacement |
|---|---|---|
| Forgot to run tests | Friday, deadline, "tiny change" | CI required status check; branch protection |
| Missed an authorization check | Reviewer was tired | Framework makes routes deny-by-default; lint rule flags handlers without `authorize()` |
| Introduced a circular dependency | Nobody sees the whole graph | `dependency-cruiser` rule in CI |
| Shipped a 400 KB dependency | `npm install` is frictionless | Bundle size budget check on PR |
| Backups silently broken for 6 months | Nobody restores unless there's a disaster | Automated monthly restore drill with row-count checks |
| Slow query merged | Worked fine on 50 dev rows | Seeded perf dataset + `EXPLAIN` check for new queries; p95 alert |
| New hire doesn't know conventions | Knowledge lives in seniors' heads | Templates, generators, lint rules, ADRs ([10-knowledge-into-systems.md](10-knowledge-into-systems.md)) |

Discipline doesn't scale across people, time, projects, or tiredness. Systems do. A solo developer running five projects ([11-solo-developer-multiple-projects.md](11-solo-developer-multiple-projects.md)) has no choice: they can't keep five projects' quality rules in their head.

### How

Every quality attribute gets the same four-part treatment:

```text
Definition      → What exactly do we mean? (in terms of observable behavior)
Measurement     → Which number tells us? (SLI, metric, score)
Target          → What value is acceptable? (SLO, budget, threshold)
Enforcement     → What mechanism stops regressions? (gate, alert, drill, review)
```

If an attribute has no measurement, it is an aspiration. If it has a measurement but no enforcement, it is a dashboard nobody looks at. It becomes engineering only once all four exist.

### Example

A payments SaaS says "we value reliability." Here is what that looks like at three levels:

- **Aspiration:** "We try to keep the API up."
- **Measured:** "API availability last month was 99.87%."
- **Engineered:** "SLI = proportion of non-5xx responses to `POST /v1/charges` served within 800 ms, measured at the load balancer. SLO = 99.9% over 28 days (40 min error budget). A multi-window burn-rate alert pages when 2% of the monthly budget burns in 1 hour. When the budget is exhausted, feature deploys freeze and only reliability work ships. Canary deploys auto-roll back if the canary's error rate is 2× baseline."

### Expert Mental Model

> Every quality property I care about must have a sensor and an actuator. The sensor tells me the property is degrading; the actuator stops or reverses the degradation without relying on someone remembering.

### Common Mistake

Treating quality as a phase ("QA at the end") or a person ("the QA engineer"). By the time a phase-gate finds a problem, the design that caused it has been built on for weeks. Quality has to be enforced **at the moment of change**, as close to the author as possible: editor → pre-commit → PR → merge → deploy → runtime.

---

## 2. The Quality Model: Twelve Attributes

The attributes below overlap with ISO/IEC 25010 but are organized around how working engineers actually reason about them.

| # | Attribute | Question it answers | Primary sensor | Primary actuator |
|---|---|---|---|---|
| 1 | Correctness | Does it do the right thing for all valid inputs and reject invalid ones? | Tests, invariant checks, reconciliation jobs | Type system, DB constraints, CI tests |
| 2 | Reliability | Does it keep doing that over time, under real conditions? | SLIs, error rates, incident count | SLOs + error budget policy, canaries |
| 3 | Maintainability | Can someone change it safely and quickly? | Change lead time, complexity, churn×complexity hotspots | Lint, architecture tests, review |
| 4 | Security | Can it resist abuse? | Vulnerability scans, pentest findings, authz test coverage | SAST/SCA gates, deny-by-default design |
| 5 | Performance | Is it fast enough for its purpose? | p50/p95/p99 latency, Core Web Vitals | Perf budgets in CI, latency alerts |
| 6 | Scalability | Does performance hold as load/data/tenants grow? | Load test curves, cost per unit | Capacity tests, autoscaling policies |
| 7 | Testability | Can behavior be verified cheaply and deterministically? | Test runtime, flake rate, mutation score | Architecture (ports/adapters), DI |
| 8 | Observability | Can we answer new questions about production behavior without shipping code? | Time to diagnose, % of incidents detected by alerts vs users | Logging/tracing conventions, instrumentation libs |
| 9 | Operability | Can it be deployed, configured, scaled, and debugged routinely? | Deploy time, manual steps, toil hours | IaC, runbooks, one-command deploy |
| 10 | Usability | Can the intended users accomplish their goals? | Task success, a11y violations, support tickets | a11y CI checks, usability tests |
| 11 | Evolvability | Can the architecture absorb new requirements without rewrites? | Cost of representative changes, coupling metrics | Module boundaries, versioned contracts, ADRs |
| 12 | Recoverability | When something breaks or data is lost, how fast and how completely do we return? | RTO, RPO, MTTR, restore drill results | Backups, PITR, rollback automation, drills |

Two meta-points:

1. **They are not independent.** Testability drives correctness; observability drives recoverability; maintainability drives evolvability. Section 20 covers the tensions between them.
2. **Not every system needs every attribute at maximum.** An internal admin script and a ledger service have different targets. Section 21 covers tiers.

---

## 3. Correctness

### What

The system produces the right outputs and state transitions for every input in its domain, and rejects inputs outside it. Correctness is defined **relative to a specification**, even an informal one. Without a spec (requirements, invariants, examples) you can't call anything correct, only "unsurprising so far."

Correctness has layers:

- **Functional correctness:** the calculation is right (tax, totals, allocation).
- **State correctness:** the system never enters an illegal state (order `SHIPPED` without payment `CAPTURED`).
- **Concurrent correctness:** still correct when two requests interleave.
- **Boundary correctness:** handles empty, max, unicode, timezone, DST, leap day, currency rounding.
- **Integration correctness:** your understanding of a dependency's contract matches reality.

### Why

Most expensive failures are correctness failures, not crashes. A crash is loud. A wrong total on 0.3% of invoices is quiet, compounds, and damages trust and money. In banking, WMS, and payments, silent incorrectness is the worst kind of failure.

### How It's Measured

| Metric | How | Notes |
|---|---|---|
| Defect escape rate | Bugs found in production ÷ total bugs found | Trend matters more than the absolute value |
| Invariant violation count | Scheduled checks that query for illegal states (should be 0) | See [09-invariants-and-correctness.md](09-invariants-and-correctness.md) |
| Reconciliation deltas | Compare ledger vs PSP settlement, stock vs WMS counts | Non-zero delta = incident |
| **Mutation score** | % of injected code mutations killed by tests (Stryker, PIT) | Much better than line coverage at measuring test *strength* |
| Line/branch coverage | % of code executed by tests | Detects *untested* code; says nothing about *well-tested* code |
| Property-test counterexamples | fast-check/Hypothesis shrinking failures | Finds edge cases humans don't enumerate |

**Coverage vs mutation score, concretely:**

```ts
// src/pricing/discount.ts
export function applyDiscount(totalCents: number, percent: number): number {
  if (percent < 0 || percent > 100) throw new RangeError('percent out of range');
  return Math.round(totalCents * (1 - percent / 100));
}

// A test that gives 100% line coverage but kills almost no mutants:
test('applyDiscount runs', () => {
  expect(() => applyDiscount(1000, 10)).not.toThrow();
  expect(() => applyDiscount(1000, 150)).toThrow();
});
```

Stryker mutates `percent > 100` to `percent >= 100`, `1 - percent/100` to `1 + percent/100`, `Math.round` to `Math.floor`, and so on. Every mutant survives because the test never checks the result. Coverage: 100%. Mutation score: ~20%. The strong version:

```ts
test.each([
  [1000, 0, 1000],
  [1000, 10, 900],
  [1000, 100, 0],
  [999, 33, 669],     // rounding: 999 * 0.67 = 669.33 → 669
  [5, 50, 3],         // 2.5 → Math.round → 3 (kills Math.floor mutant)
])('applyDiscount(%i, %i) = %i', (total, pct, expected) => {
  expect(applyDiscount(total, pct)).toBe(expected);
});

test.each([-1, 100.01, 101])('rejects percent %p', (pct) => {
  expect(() => applyDiscount(1000, pct)).toThrow(RangeError);
});

test('boundary 100 is allowed', () => {
  expect(applyDiscount(1000, 100)).toBe(0); // kills `>` → `>=` mutant
});
```

**Property-based testing** for invariants humans don't enumerate:

```ts
import fc from 'fast-check';

test('discount never increases total and never goes negative', () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 10_000_000 }),
      fc.double({ min: 0, max: 100, noNaN: true }),
      (total, pct) => {
        const result = applyDiscount(total, pct);
        return result >= 0 && result <= total;
      },
    ),
  );
});
```

### How It's Enforced

1. **Make illegal states unrepresentable in types.**

```ts
// Amateur: stringly typed, any combination possible
type Order = { status: string; paidAt?: Date; shippedAt?: Date; trackingNo?: string };

// Expert: discriminated union; a SHIPPED order without tracking can't be constructed
type Order =
  | { status: 'PENDING'; id: OrderId }
  | { status: 'PAID'; id: OrderId; paidAt: Date; paymentId: PaymentId }
  | { status: 'SHIPPED'; id: OrderId; paidAt: Date; paymentId: PaymentId; shippedAt: Date; trackingNo: string }
  | { status: 'CANCELLED'; id: OrderId; reason: CancelReason };
```

2. **Parse, don't validate, at boundaries.** Turn untrusted input into trusted domain types exactly once.

```ts
import { z } from 'zod';

const CreateChargeInput = z.object({
  amountCents: z.number().int().positive().max(99_999_999),
  currency: z.enum(['USD', 'EUR', 'GBP']),
  idempotencyKey: z.string().uuid(),
});
export type CreateChargeInput = z.infer<typeof CreateChargeInput>;
```

3. **Database constraints as the last line of defense.**

```sql
ALTER TABLE inventory_allocations
  ADD CONSTRAINT qty_positive CHECK (quantity > 0);

ALTER TABLE stock_levels
  ADD CONSTRAINT allocated_le_on_hand CHECK (allocated_qty <= on_hand_qty);

CREATE UNIQUE INDEX uq_payments_idempotency ON payments (merchant_id, idempotency_key);
```

4. **CI gates:** tests required; mutation score threshold on domain modules (not the whole repo, which is slow and noisy).

```json
// stryker.config.json
{
  "mutate": ["src/domain/**/*.ts", "!src/domain/**/*.test.ts"],
  "testRunner": "vitest",
  "thresholds": { "high": 85, "low": 70, "break": 65 },
  "incremental": true
}
```

5. **Runtime invariant checks and reconciliation** (scheduled job; alerts on non-zero).

```sql
-- nightly: orders marked PAID with no captured payment
SELECT o.id FROM orders o
LEFT JOIN payments p ON p.order_id = o.id AND p.status = 'CAPTURED'
WHERE o.status IN ('PAID','SHIPPED') AND p.id IS NULL;
```

### Expert Mental Model

> Correctness is a defense-in-depth problem: types prevent whole classes of mistakes at compile time, parsing prevents bad data at the edge, domain logic enforces rules, the database enforces invariants no matter which code path writes, tests prove behavior, and reconciliation catches whatever slipped through everything else.

### Common Mistake

Chasing 100% line coverage as a proxy for correctness. It encourages assertion-free tests and tests of trivial getters, while the concurrent double-spend path never gets tested. Target **mutation score on the domain core** and **explicit invariant tests** instead.

---

## 4. Reliability

### What

The probability that the system performs its function correctly over a period of time under stated conditions. In practice: **the proportion of user-meaningful requests or jobs that succeed within an acceptable time.**

### Why

Users don't experience uptime of servers; they experience whether *their* checkout worked. Reliability also has a cost curve: each extra nine costs roughly 10× more. Without an explicit target you either over-invest (a blog with 99.99%) or under-invest (payments with "best effort").

### How It's Measured: SLIs, SLOs, Error Budgets

**SLI (Service Level Indicator):** a ratio of good events to valid events.

```text
availability SLI = good requests / valid requests
  good  = HTTP status < 500 AND not a timeout
  valid = all requests excluding health checks and 4xx caused by client

latency SLI = requests served under threshold / valid requests
  threshold = 800 ms for POST /v1/charges, 300 ms for GET /v1/charges/:id

freshness SLI (pipelines) = records available in warehouse within 15 min / records produced

correctness SLI (batch) = invoices matching reconciliation / invoices generated
```

**SLO (Service Level Objective):** target for the SLI over a window.

| SLO | Allowed bad per 28 days | Allowed downtime-equivalent |
|---|---|---|
| 99% | 1% | ~6 h 43 m |
| 99.5% | 0.5% | ~3 h 22 m |
| 99.9% | 0.1% | ~40 m |
| 99.95% | 0.05% | ~20 m |
| 99.99% | 0.01% | ~4 m |

**Error budget:** `1 − SLO`. It's the amount of unreliability you're *allowed* to spend on shipping features, running experiments, and doing risky migrations.

**SLA:** a contractual promise with penalties. It should always be looser than the internal SLO (SLO 99.9% → SLA 99.5%).

**Burn-rate alerting** (from the Google SRE Workbook) pages on how fast the budget is being consumed, not on raw thresholds:

```yaml
# Prometheus rules — 99.9% SLO for checkout API
groups:
- name: checkout-slo
  rules:
  - record: slo:checkout_errors:ratio_rate1h
    expr: |
      sum(rate(http_requests_total{service="checkout",code=~"5..|timeout"}[1h]))
      /
      sum(rate(http_requests_total{service="checkout"}[1h]))
  - record: slo:checkout_errors:ratio_rate5m
    expr: |
      sum(rate(http_requests_total{service="checkout",code=~"5..|timeout"}[5m]))
      /
      sum(rate(http_requests_total{service="checkout"}[5m]))
  - record: slo:checkout_errors:ratio_rate6h
    expr: |
      sum(rate(http_requests_total{service="checkout",code=~"5..|timeout"}[6h]))
      /
      sum(rate(http_requests_total{service="checkout"}[6h]))
  - record: slo:checkout_errors:ratio_rate30m
    expr: |
      sum(rate(http_requests_total{service="checkout",code=~"5..|timeout"}[30m]))
      /
      sum(rate(http_requests_total{service="checkout"}[30m]))

  # Page: 2% of 28-day budget in 1h  → burn rate 14.4
  - alert: CheckoutErrorBudgetFastBurn
    expr: |
      slo:checkout_errors:ratio_rate1h > (14.4 * 0.001)
      and
      slo:checkout_errors:ratio_rate5m > (14.4 * 0.001)
    labels: { severity: page }
    annotations:
      runbook: https://runbooks.internal/checkout/error-budget-burn

  # Ticket: 10% of budget in 3 days → burn rate 1 over 6h window (simplified)
  - alert: CheckoutErrorBudgetSlowBurn
    expr: |
      slo:checkout_errors:ratio_rate6h > (6 * 0.001)
      and
      slo:checkout_errors:ratio_rate30m > (6 * 0.001)
    labels: { severity: ticket }
```

Why two windows: the long window proves it's significant, and the short window proves it's still happening, so the alert resolves quickly once fixed.

### How It's Enforced

- **Error budget policy** (a written, agreed document):

```markdown
## Checkout API Error Budget Policy
- Budget remaining > 50%: normal feature velocity; risky migrations allowed.
- Budget 0–50%: risky changes require a rollback plan reviewed by a second engineer.
- Budget exhausted: feature deploys frozen for this service. Only reliability fixes,
  security patches, and rollbacks ship until the 28-day window recovers above 0.
- A single incident consuming > 20% of budget requires a postmortem within 5 business days.
```

- **Progressive delivery:** canary 1% → 10% → 50% → 100%, with automated analysis comparing canary vs baseline error rate and latency (Argo Rollouts, Flagger, or a feature-flag percentage rollout).
- **Timeouts, retries with jitter, circuit breakers, idempotency** as default library behavior, not per-call decisions ([07-designing-for-failure.md](07-designing-for-failure.md)).
- **Dependency SLO math:** a service that synchronously calls 5 dependencies each at 99.9% has at most ~99.5% availability. That pushes architecture toward fewer synchronous hops, async work, and graceful degradation.

```text
0.999^5 = 0.995  → your 99.9% target is mathematically impossible with that call graph
```

### Example

A logistics SaaS's label-printing endpoint depends on three carrier APIs. Carrier B has ~98% availability. Instead of promising 99.9% on the whole endpoint, the team:

1. Defines the SLI as "label request accepted and a label produced within 10 min" (async) instead of "synchronous 200 in 2 s."
2. Queues label generation with retries and fallback carrier routing.
3. Sets the SLO at 99.5% for acceptance and 99% for 10-min completion.
4. Alerts on queue age p99 > 5 min.

Result: user-visible reliability rises even though no dependency got more reliable.

### Expert Mental Model

> Reliability is a budget, not a virtue. I define it from the user's point of view, I pick a target that the business actually needs and the dependency graph can actually support, and I let the remaining budget decide how fast we're allowed to move.

### Common Mistake

- Alerting on causes (CPU > 80%) instead of symptoms (SLO burn). You get pages with no user impact and silence during real outages.
- 100% as a target. It freezes change and is impossible anyway.
- Measuring availability at the server when users hit a CDN, DNS, and client. Measure as close to the user as practical: load balancer logs at minimum, synthetic checks and RUM ideally.

---

## 5. Maintainability

### What

How cheaply and safely a competent engineer who **didn't** write the code can understand it, change it, and verify the change. It breaks down into analyzability, modifiability, modularity, and reusability.

### Why

Most of a system's lifetime cost comes after first release. Code is read and changed far more often than it's written. Poor maintainability shows up as: every feature takes longer than the last, fixes cause regressions, and only one person dares touch module X.

### How It's Measured

| Metric | Tool | Interpretation |
|---|---|---|
| Cyclomatic / cognitive complexity per function | ESLint `complexity`, SonarQube cognitive complexity | Functions > 15 cognitive complexity are review hotspots |
| **Hotspots = churn × complexity** | `code-maat`, CodeScene, `git log` scripts | The 5% of files that are both complex *and* changed often cause most defects; refactor those, ignore complex-but-stable code |
| Change coupling | files that always change together (git history) | Hidden dependencies; boundary in wrong place |
| Module dependency graph violations | dependency-cruiser, ArchUnit, eslint-plugin-boundaries | Layer/feature boundary erosion |
| Lead time for a change | DORA (Section 15) | Maintainability shows up here first |
| Dependency health | Renovate dashboard, `npm outdated`, libyear | Libyears > ~10 in a service = upgrade pain accumulating |
| Duplicated code % | jscpd, Sonar | Duplication of *knowledge* matters, not identical-looking lines |
| Onboarding time to first meaningful PR | internal tracking | Holistic proxy |

A quick hotspot script:

```bash
# Top 20 files by number of commits in the last 12 months
git log --since="12 months ago" --name-only --pretty=format: \
  | grep -E '\.(ts|tsx)$' | sort | uniq -c | sort -rn | head -20
# Cross-reference with complexity report (e.g., eslint --format json) to find churn × complexity
```

### How It's Enforced

**1. Type checking in strict mode as a gate.**

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "useUnknownInCatchVariables": true
  }
}
```

**2. Lint rules that encode conventions, not style.** Style goes to the formatter (Prettier/Biome) and is never discussed in review.

```js
// eslint.config.js (flat config, excerpt)
import tseslint from 'typescript-eslint';

export default tseslint.config(
  ...tseslint.configs.strictTypeChecked,
  {
    rules: {
      complexity: ['error', 15],
      'max-depth': ['error', 4],
      '@typescript-eslint/no-floating-promises': 'error',      // unawaited promise = lost error
      '@typescript-eslint/switch-exhaustiveness-check': 'error', // new enum member forces handling
      '@typescript-eslint/no-explicit-any': 'error',
      'no-restricted-imports': ['error', {
        patterns: [
          { group: ['@/features/*/internal/*'], message: 'Import from the feature public index only.' },
          { group: ['axios'], message: 'Use @/lib/http (timeouts, retries, tracing built in).' },
        ],
      }],
      'no-restricted-syntax': ['error', {
        selector: "CallExpression[callee.object.name='console'][callee.property.name='log']",
        message: 'Use the structured logger from @/lib/logger.',
      }],
    },
  },
);
```

**3. Architecture tests** make boundaries executable.

```js
// .dependency-cruiser.cjs
module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
    {
      name: 'domain-is-pure',
      comment: 'Domain layer must not depend on infrastructure, frameworks, or the web layer.',
      severity: 'error',
      from: { path: '^src/modules/[^/]+/domain' },
      to: { path: ['^src/modules/[^/]+/(infra|http)', 'node_modules/(pg|prisma|express|next)'] },
    },
    {
      name: 'modules-talk-through-public-api',
      comment: 'Module A may only import module B via src/modules/B/index.ts',
      severity: 'error',
      from: { path: '^src/modules/([^/]+)/' },
      to: {
        path: '^src/modules/([^/]+)/(?!index\\.ts$)',
        pathNot: '^src/modules/$1/',
      },
    },
    {
      name: 'no-orphans',
      severity: 'warn',
      from: { orphan: true, pathNot: ['\\.d\\.ts$', '(^|/)tsconfig\\.json$', '\\.test\\.ts$'] },
      to: {},
    },
  ],
  options: { tsConfig: { fileName: 'tsconfig.json' }, doNotFollow: { path: 'node_modules' } },
};
```

```bash
npx depcruise src --config .dependency-cruiser.cjs
```

**4. Ratchets for legacy codebases.** You can't fix 3,000 lint errors today, but you can stop the count from growing.

```bash
# scripts/ratchet.sh — fail if error count increased vs committed baseline
current=$(npx eslint src --format json | jq '[.[].errorCount] | add')
baseline=$(cat .quality/eslint-baseline.txt)
if [ "$current" -gt "$baseline" ]; then
  echo "ESLint errors increased: $baseline → $current"; exit 1
fi
if [ "$current" -lt "$baseline" ]; then
  echo "$current" > .quality/eslint-baseline.txt
  echo "Ratchet tightened to $current — commit the updated baseline."
fi
```

(ESLint's newer "bulk suppressions" feature and tools like `betterer` do the same thing.)

**5. Automated dependency updates** with Renovate: grouped, scheduled, automerged for patch-level updates when CI passes.

```json
{
  "extends": ["config:recommended"],
  "schedule": ["before 6am on monday"],
  "packageRules": [
    { "matchUpdateTypes": ["patch", "pin", "digest"], "automerge": true },
    { "matchPackagePatterns": ["^@types/"], "groupName": "types", "automerge": true },
    { "matchDepTypes": ["devDependencies"], "matchUpdateTypes": ["minor"], "automerge": true }
  ],
  "vulnerabilityAlerts": { "labels": ["security"], "schedule": ["at any time"] }
}
```

### Expert Mental Model

> Maintainability isn't about pretty code. It's about keeping the **cost of the next change** low and predictable. I invest where churn and complexity meet, I make boundaries machine-checked so they don't erode, and I let the formatter end style debates.

### Common Mistake

Refactoring for aesthetics across the whole codebase ("let's migrate everything to the new pattern") instead of targeting hotspots. Also: DRYing code that merely *looks* similar but represents different business concepts, which creates coupling that hurts evolvability.

---

## 6. Security

### What

The system's ability to preserve confidentiality, integrity, and availability against intentional misuse. Deep treatment lives in [08-security-engineering.md](08-security-engineering.md). This section covers only how security becomes a **measured and enforced quality attribute**.

### Why

Security failures are asymmetric: one missing authorization check can leak every tenant's data. They are also invisible to functional tests, since the feature "works."

### How It's Measured

| Metric | Source |
|---|---|
| Open vulnerabilities by severity and age (e.g., critical > 7 days = SLA breach) | SCA (Dependabot, Snyk, `npm audit`, OSV-Scanner), container scanning (Trivy, Grype) |
| SAST findings introduced per PR | Semgrep, CodeQL |
| Secrets detected in commits | gitleaks, GitHub push protection |
| % of endpoints with authorization tests | Custom: route inventory vs test inventory |
| Mean time to remediate (MTTR-vuln) | Issue tracker |
| Pentest/bug-bounty findings by severity | External |
| Security headers score | securityheaders.com / Mozilla Observatory in CI |
| SBOM completeness; unsigned artifacts count | Syft, Sigstore/cosign |

### How It's Enforced

- **Deny-by-default in the framework:** every route requires a policy declaration, and a route without one fails at startup or in a test.

```ts
// test/security/route-policy.test.ts — fails if any route lacks an authorization policy
import { app } from '@/http/app';

test('every route declares an authorization policy', () => {
  const routes = app.listRoutes(); // framework introspection
  const missing = routes.filter((r) => !r.meta?.policy && !r.meta?.public);
  expect(missing.map((r) => `${r.method} ${r.path}`)).toEqual([]);
});
```

- **Tenant-isolation tests** generated for every resource: create as tenant A, access as tenant B, expect 404.
- **PostgreSQL Row-Level Security** as a second layer for multi-tenant SaaS (see [08-security-engineering.md](08-security-engineering.md)).
- **CI gates:** Semgrep/CodeQL with blocking rules for high severity, `gitleaks`, SCA with fail-on-critical, container scan, IaC scan (Checkov/tfsec).
- **Supply chain:** lockfile required (`npm ci`), `ignore-scripts` where feasible, pinned GitHub Actions by SHA, provenance/signing for images.
- **Threat model** as part of the design doc for anything touching auth, money, PII, or tenancy ([templates/threat-model.md](templates/threat-model.md)).

### Expert Mental Model

> Security quality is measured by the absence of *classes* of vulnerabilities, enforced structurally, not by the absence of reported bugs. If authorization depends on every developer remembering a line of code, the system is insecure by construction.

### Common Mistake

Turning on every scanner at maximum sensitivity with blocking gates on day one. Developers drown in false positives, learn to click "ignore," and the gate becomes theater. Start with a small set of high-signal blocking rules, run everything else as non-blocking reports, and promote rules as you tune them.

---

## 7. Performance

### What

Time and resource behavior under expected load: latency, throughput, resource usage, and user-perceived speed. Full treatment is in [06-performance-engineering.md](06-performance-engineering.md).

### How It's Measured

- **Backend:** latency percentiles (p50, p95, p99, p99.9) per endpoint, throughput (RPS), saturation (CPU, pool wait time, queue depth).
- **Frontend (Core Web Vitals, measured at p75 of real users):**

| Metric | Good | Needs improvement | Poor |
|---|---|---|---|
| LCP (Largest Contentful Paint) | ≤ 2.5 s | ≤ 4.0 s | > 4.0 s |
| INP (Interaction to Next Paint) | ≤ 200 ms | ≤ 500 ms | > 500 ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

- **Cost efficiency:** cost per 1,000 requests, cost per tenant.

### How It's Enforced

- Per-route **performance budgets** checked in CI (bundle size, Lighthouse CI assertions).
- **Latency SLOs** with alerts (Section 4 applies to latency SLIs too).
- **Load tests** as a scheduled job or pre-release gate for critical flows (k6 with thresholds).
- **Query review:** any new query on a table > 1M rows must include `EXPLAIN (ANALYZE, BUFFERS)` output in the PR description.

```js
// lighthouserc.js
module.exports = {
  ci: {
    collect: { url: ['http://localhost:3000/', 'http://localhost:3000/products/sku-123'], numberOfRuns: 3 },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['warn', { maxNumericValue: 200 }],
        'resource-summary:script:size': ['error', { maxNumericValue: 180000 }],
      },
    },
  },
};
```

### Common Mistake

Measuring averages. A mean latency of 120 ms can hide a p99 of 4 s, and for a page that makes 20 backend calls, most users will hit that p99.

---

## 8. Scalability

### What

The ability to keep performance and cost acceptable as some dimension grows: requests, data volume, tenants, write rate, team size, number of features. **Scalability always names a dimension.** "Scalable" alone means nothing.

### Why

Systems rarely fail at average load. They fail at 10× load on Black Friday, when one tenant imports 40M rows, or when a table crosses the size where the planner switches from index scan to seq scan.

### How It's Measured

| Dimension | Measurement |
|---|---|
| Request load | Load test: throughput vs latency curve; find the "knee" where p99 bends upward |
| Data volume | Query latency at 1×, 10×, 100× production-like row counts |
| Tenant count / skew | Largest tenant's p95 vs median tenant's p95 |
| Cost | Cost per unit (per order, per active user) as volume grows; should be flat or falling |
| Horizontal scaling efficiency | Throughput at N instances ÷ (N × throughput at 1 instance); ideally > 0.8 |

```text
Throughput vs p99 latency (checkout API, 4 pods)

RPS    p99
200    180 ms
400    210 ms
600    260 ms
800    420 ms   ← knee (DB pool wait time starts rising)
1000   1900 ms
1100   timeouts

Capacity planning rule: operate below ~60-70% of the knee → 500-550 RPS per 4 pods.
Bottleneck: connection pool, not CPU → scaling pods alone would make it WORSE.
```

### How It's Enforced

- **Capacity tests before known peaks**, with explicit pass criteria.
- **Tenant-aware limits:** per-tenant rate limits, quotas, and job concurrency caps so one tenant can't degrade others.
- **Data growth rules:** every list endpoint paginated (keyset for large tables), every background job batched, and every table has an expected growth rate and a retention/partitioning plan in the design doc.
- **Autoscaling policies tested**, not assumed: scale on a signal that leads the bottleneck (queue depth, concurrency), not CPU if CPU isn't the constraint.

### Expert Mental Model

> Scalability questions are "which dimension, to what size, at what cost, by when?" I find the first bottleneck with a test, not a guess, and I remember that scaling one tier often just moves the bottleneck to the next one, usually the database.

### Common Mistake

Designing for "millions of users" with microservices and Kafka for a B2B product that will have 400 customers, while ignoring the actual scaling risk: a single customer with a 30M-row import running `OFFSET` pagination.

---

## 9. Testability

### What

The degree to which behavior can be verified **quickly, deterministically, and in isolation**. Testability is a property of the *design*, not of the test suite.

### Why

If testing a pricing rule requires a running database, a mocked Stripe, a Redis instance, and a 40-second boot, people will write fewer tests, run them less often, and trust them less. Low testability quietly destroys correctness and maintainability.

### How It's Measured

| Metric | Healthy target (typical service) |
|---|---|
| Unit test suite runtime | < 60 s locally |
| Full CI pipeline to merge-ready | < 10–15 min |
| Flaky test rate | < 1% of test runs; each flaky test has an owner and a quarantine ticket |
| Setup lines per test | Low; large fixtures are a design smell |
| Mutation score (domain layer) | ≥ 70% |
| % of business rules testable without I/O | High, ideally the whole domain core |

### How It's Enforced

**Design for testability: ports and adapters.**

```ts
// domain/allocation.ts — pure, no I/O, trivially testable
export interface StockView { onHand: number; allocated: number }

export function allocate(stock: StockView, requested: number):
  | { ok: true; newAllocated: number }
  | { ok: false; reason: 'INSUFFICIENT_STOCK'; available: number } {
  const available = stock.onHand - stock.allocated;
  if (requested <= 0) throw new RangeError('requested must be positive');
  if (requested > available) return { ok: false, reason: 'INSUFFICIENT_STOCK', available };
  return { ok: true, newAllocated: stock.allocated + requested };
}

// application/allocate-order.ts — orchestrates, depends on ports
export interface StockRepository {
  lockForUpdate(sku: string, warehouseId: string, tx: Tx): Promise<StockView>;
  saveAllocated(sku: string, warehouseId: string, allocated: number, tx: Tx): Promise<void>;
}
export interface Clock { now(): Date }
```

- Inject **time, randomness, and IDs** (`Clock`, `IdGenerator`). Hidden `new Date()` and `Math.random()` are the #1 cause of non-deterministic tests.
- **Integration tests against real dependencies** in containers (Testcontainers for PostgreSQL/Redis) rather than mocks of the ORM, which test your mock, not your SQL.

```ts
// test/integration/allocation.repo.test.ts
import { PostgreSqlContainer, StartedPostgreSqlContainer } from '@testcontainers/postgresql';

let pg: StartedPostgreSqlContainer;
beforeAll(async () => {
  pg = await new PostgreSqlContainer('postgres:16-alpine').start();
  await runMigrations(pg.getConnectionUri());
}, 60_000);
afterAll(() => pg.stop());

test('concurrent allocations never exceed on-hand stock', async () => {
  const repo = makeRepo(pg.getConnectionUri());
  await seedStock(repo, { sku: 'SKU-1', warehouseId: 'W1', onHand: 10, allocated: 0 });

  const attempts = Array.from({ length: 20 }, () => allocateOrder(repo, 'SKU-1', 'W1', 1));
  const results = await Promise.allSettled(attempts);

  const ok = results.filter((r) => r.status === 'fulfilled' && r.value.ok).length;
  expect(ok).toBe(10);
  expect((await repo.read('SKU-1', 'W1')).allocated).toBe(10);
});
```

- **Flaky test policy** in CI: auto-retry once and report the flake; a test that flakes 3× in a week is quarantined with a ticket and must be fixed or deleted within a sprint.

### Expert Mental Model

> If something is hard to test, the test is telling me the design is coupled. I fix the design (pull out pure logic, inject time and I/O) instead of piling on mocks.

### Common Mistake

Mocking everything, including the database, so tests pass while the real SQL has a bug, a missing index, or a constraint violation. Mock at **architectural boundaries you don't own** (third-party HTTP APIs), and use real instances of the things you do own (your database schema).

---

## 10. Observability

### What

The ability to understand a system's internal state from its external outputs, and in particular to answer **questions you didn't anticipate** without deploying new code. It rests on structured logs, metrics, and traces, all correlated by request/trace IDs, plus business events.

### Why

Monitoring tells you *that* something is wrong (known unknowns). Observability tells you *why* (unknown unknowns). Without it, MTTR is dominated by "add logging, redeploy, wait for it to happen again."

### How It's Measured

| Metric | Why it matters |
|---|---|
| % of incidents detected by alerts before users/customers report them | Target > 80–90% |
| Mean time to detect (MTTD) | Alert quality |
| Mean time to diagnose (part of MTTR) | Telemetry quality |
| % of services with RED metrics + tracing + structured logs | Coverage |
| % of alerts that are actionable (not noise) | Alert hygiene; target > 90% |
| Trace completeness (% spans with parent context propagated) | Tracing quality |

### How It's Enforced

- **A shared instrumentation library** (OpenTelemetry-based) that every service imports. Nobody configures tracing by hand.
- **Structured logging convention** enforced by lint (no `console.log`) and by the logger API:

```ts
// @/lib/logger — pino with required context
import pino from 'pino';
import { context, trace } from '@opentelemetry/api';

const base = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  redact: ['req.headers.authorization', '*.password', '*.cardNumber', '*.token'],
  formatters: { level: (label) => ({ level: label }) },
});

export function log() {
  const span = trace.getSpan(context.active());
  const ctx = span?.spanContext();
  return base.child({ trace_id: ctx?.traceId, span_id: ctx?.spanId, service: process.env.SERVICE_NAME });
}

// usage: events are named, fields are structured, never string-interpolated
log().info({ event: 'payment.captured', orderId, amountCents, pspLatencyMs }, 'payment captured');
```

- **Definition of Done includes observability:** a new endpoint has RED metrics automatically (middleware), a new background job emits `job.started/succeeded/failed` with duration, and a new external dependency has a client span and a timeout metric.
- **Dashboards as code** (Grafana JSON/Terraform) and **alerts as code**, reviewed in PRs.
- **"Could we debug this?" review question:** for every failure path, does the log/trace contain enough to find the cause without reproducing it?

### Expert Mental Model

> I instrument for the investigation I'll need to do during the incident I haven't had yet. Every request is traceable end-to-end; every business-significant event is a structured record; every alert links to a runbook.

### Common Mistake

Logging a lot and observing very little: unstructured strings, no correlation IDs, sensitive data in logs, and 2,000 alerts nobody reads. Volume is not observability.

---

## 11. Operability

### What

How easily the system can be deployed, configured, scaled, upgraded, and run day to day by the people on call, including people who didn't build it.

### Why

A system that needs a 14-step manual deploy, SSH access to fix config, and tribal knowledge to restart the queue consumer produces incidents *during operations*. Industry incident data consistently shows that a large share of outages are triggered by changes: deploys, config pushes, and migrations.

### How It's Measured

| Metric | Healthy |
|---|---|
| Manual steps in a deploy | 0 (one command or merge-to-deploy) |
| Deploy duration | Minutes, not hours |
| Rollback duration | < 5 min, rehearsed |
| Toil hours per week (manual, repetitive, automatable ops work) | < 50% of ops time (Google SRE guideline), ideally far less |
| Config changes requiring code deploy | Low; but config changes are still versioned and reviewed |
| % of alerts with a linked runbook | 100% for paging alerts |
| Time for a new engineer to run the system locally | < 30 min, one command |

### How It's Enforced

- **Infrastructure as Code** (Terraform/Pulumi/CDK) with `plan` output in PRs; no console clicks in production.
- **Twelve-factor config:** config via environment, validated at startup, fail fast:

```ts
// src/config.ts — the app refuses to boot with invalid config
import { z } from 'zod';

const Env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  DATABASE_URL: z.string().url(),
  DB_POOL_MAX: z.coerce.number().int().min(1).max(100).default(10),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  HTTP_TIMEOUT_MS: z.coerce.number().int().positive().default(3000),
  FEATURE_NEW_CHECKOUT: z.enum(['on', 'off']).default('off'),
});

export const config = Env.parse(process.env); // throws with a precise message on boot
```

- **Health endpoints with meaning:** `/livez` (process alive, no dependency checks), `/readyz` (can serve traffic: DB reachable, migrations applied), so orchestrators don't restart-loop healthy pods during a DB blip.
- **Graceful shutdown:** handle SIGTERM, stop accepting new work, finish in-flight requests, close pools.
- **Runbooks** for every paging alert ([templates/runbook.md](templates/runbook.md)).
- **Expand/contract database migrations** so deploys and rollbacks never require downtime.

### Expert Mental Model

> Operations is a user of the system. I design the deploy, rollback, config, and diagnosis paths with the same care as the product features, because that's where the system is most fragile.

### Common Mistake

"It works on my machine and I know how to deploy it." That is a bus-factor-1 system. A solo developer is especially exposed: the person on call in six months is future-you, who has forgotten everything.

---

## 12. Usability

### What

How effectively, efficiently, and satisfactorily the intended users achieve their goals, including users with disabilities, slow devices, poor networks, and different languages. For APIs and developer tools, usability means **developer experience**: consistency, clear errors, discoverability.

### Why

A correct, reliable system that users can't operate still fails. In enterprise software, poor usability shows up as support tickets, data-entry errors (which become correctness problems), and churn.

### How It's Measured

| Metric | Tool |
|---|---|
| Task success rate & time on task | Usability sessions, product analytics funnels |
| Accessibility violations | axe-core in CI (Playwright), Lighthouse a11y score, manual screen-reader passes |
| Error rate in forms (validation failures per submission) | Analytics events |
| Support tickets per 1,000 active users by feature | Support tooling |
| INP / responsiveness | RUM |
| API: time-to-first-successful-call for new integrators; % of 4xx by error code | API analytics |

### How It's Enforced

- **Automated a11y checks** in E2E tests (they catch only ~30–50% of issues, so manual audits are still required for key flows):

```ts
// e2e/checkout.a11y.spec.ts (Playwright + @axe-core/playwright)
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('checkout page has no serious a11y violations', async ({ page }) => {
  await page.goto('/checkout');
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag22aa']).analyze();
  const serious = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact ?? ''));
  expect(serious).toEqual([]);
});
```

- **Design system components** that are accessible by default (focus management, labels, keyboard support), so product engineers can't easily build inaccessible UI.
- **Consistent API error format** (RFC 9457 Problem Details) enforced by shared error middleware:

```json
{
  "type": "https://api.example.com/errors/insufficient-stock",
  "title": "Insufficient stock",
  "status": 409,
  "detail": "Requested 5 units of SKU-123 at warehouse W1; 2 available.",
  "instance": "/v1/orders/ord_8f2a/allocations",
  "code": "INSUFFICIENT_STOCK",
  "available": 2
}
```

### Common Mistake

Treating usability as visual polish. Error messages, empty states, loading states, keyboard navigation, and "what happens when the network drops mid-submit" matter more than gradients.

---

## 13. Evolvability

### What

The architecture's ability to absorb **new, unforeseen requirements** (new markets, currencies, channels, pricing models, integrations) without disproportionate rework. Maintainability is about changing code; evolvability is about changing *direction*.

### Why

Requirements will change in ways you can't predict. Evolvability doesn't mean predicting the future and building abstractions for it. It means **keeping the cost of the unknown change low** through boundaries, contracts, and reversible decisions.

### How It's Measured

- **Cost of representative change scenarios** (architecture evaluation à la ATAM): "Add a second currency," "Add a marketplace seller type," "Replace the PSP." Estimate how many modules and teams each one touches.
- **Change coupling across module boundaries** from git history. If a typical feature touches 6 modules, the boundaries are wrong.
- **Breaking API changes per quarter** and consumer impact.
- **Schema migration frequency and risk:** how many migrations needed a maintenance window.
- **Age of oldest un-actioned ADR "revisit" trigger.**

### How It's Enforced

- **Versioned, contract-tested interfaces** between modules/services and with external consumers.

```ts
// Consumer-driven contract test (Pact) — the web app states what it needs from the orders API
import { PactV4, MatchersV3 as M } from '@pact-foundation/pact';

const provider = new PactV4({ consumer: 'storefront-web', provider: 'orders-api' });

test('get order summary', () =>
  provider
    .addInteraction()
    .given('order ord_123 exists for customer cus_1')
    .uponReceiving('a request for an order summary')
    .withRequest('GET', '/v1/orders/ord_123', (b) => b.headers({ Authorization: M.like('Bearer t') }))
    .willRespondWith(200, (b) =>
      b.jsonBody({
        id: M.string('ord_123'),
        status: M.regex('PENDING|PAID|SHIPPED|CANCELLED', 'PAID'),
        totalCents: M.integer(4599),
        currency: M.string('USD'),
      }),
    )
    .executeTest(async (mock) => {
      const client = new OrdersClient(mock.url, 't');
      const order = await client.getSummary('ord_123');
      expect(order.totalCents).toBe(4599);
    }));
```

The provider pipeline verifies all consumer pacts. `can-i-deploy` blocks a provider release that would break a deployed consumer.

- **Additive-only API changes** by default; a breaking change requires a new version plus a deprecation period with usage metrics.
- **ADRs** that record the decision, the alternatives, and **the conditions under which to revisit** ([templates/adr.md](templates/adr.md)).
- **Expand/contract migrations** (add nullable column → dual write → backfill → switch reads → drop old).
- **Money, time, and identity modeled correctly from day one** (integer minor units + currency, UTC timestamps + zone where needed, opaque IDs). These are the most expensive things to retrofit.

### Expert Mental Model

> I don't build for every future. I keep decisions reversible where they're cheap to keep reversible, draw boundaries around things that change for different reasons, and invest up front only in the few decisions that are brutally expensive to change later (data model, identity, money, tenancy, public contracts).

### Common Mistake

Speculative generality: plugin systems, generic "entity" tables, and configuration engines for requirements nobody has. They make the *actual* future change harder because now you have to change the abstraction too.

---

## 14. Recoverability

### What

How quickly and completely the system returns to correct operation after failure: bad deploy, data corruption, region outage, accidental deletion, ransomware.

### Why

Every system eventually fails ([07-designing-for-failure.md](07-designing-for-failure.md)). The difference between a 5-minute blip and a company-ending event is usually recoverability: backups that actually restore, deploys that actually roll back, and data that can actually be reconstructed.

### How It's Measured

| Metric | Definition | Example targets (payments ledger / internal CMS) |
|---|---|---|
| **RPO** (Recovery Point Objective) | Max acceptable data loss, measured in time | ~0 (sync replica) / 24 h |
| **RTO** (Recovery Time Objective) | Max acceptable time to restore service | 15 min / 8 h |
| **MTTR** (Mean Time to Restore) | Average time from incident start to service restored | Tracked per quarter |
| Restore drill success rate & duration | Did last month's restore work, and how long did it take? | 100%; duration < RTO |
| Rollback time | Time from decision to previous version serving | < 5 min |
| Time to detect data corruption | Invariant check / reconciliation cadence | ≤ 24 h |

### How It's Enforced

- **Automated restore drills.** A backup you have never restored is a hypothesis.

```yaml
# .github/workflows/restore-drill.yml — monthly
name: restore-drill
on:
  schedule: [{ cron: '0 3 1 * *' }]
  workflow_dispatch: {}
jobs:
  drill:
    runs-on: ubuntu-latest
    timeout-minutes: 90
    steps:
      - uses: actions/checkout@v4
      - name: Restore latest snapshot to isolated instance
        run: ./ops/restore/restore-latest.sh --target drill-$(date +%Y%m%d) --pitr "$(date -u -d '-1 hour' +%FT%TZ)"
        env: { AWS_REGION: eu-west-1 }
      - name: Verify restored data
        run: |
          psql "$DRILL_DATABASE_URL" -v ON_ERROR_STOP=1 -f ops/restore/verify.sql
      - name: Record duration & result
        if: always()
        run: ./ops/restore/report.sh "${{ job.status }}"
      - name: Tear down
        if: always()
        run: ./ops/restore/teardown.sh
```

```sql
-- ops/restore/verify.sql — restored data must be plausible and internally consistent
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM orders WHERE created_at > now() - interval '48 hours';
  IF n = 0 THEN RAISE EXCEPTION 'restore looks stale: no orders in last 48h'; END IF;

  SELECT count(*) INTO n FROM ledger_entries GROUP BY transaction_id HAVING sum(amount_cents) <> 0 LIMIT 1;
  IF FOUND THEN RAISE EXCEPTION 'ledger does not balance after restore'; END IF;
END $$;
```

- **Rollback is a button, not a procedure:** immutable image tags, previous release retained, and migrations backward-compatible for at least one release (expand/contract).
- **Feature flags as kill switches** for risky features, so "recovery" can be a flag flip rather than a deploy.
- **Soft deletes / event logs / audit trails** for data that must be reconstructable; PITR for databases.
- **Game days / chaos experiments:** kill a pod, block the PSP, fill the disk, fail over the database. Do it in staging first, then in production during business hours with the team watching.

```text
Game day plan — "PSP outage"
Hypothesis: If Stripe returns 503 for 10 minutes, checkout degrades to "payment pending"
            with retries; no orders are lost; error-budget burn < 5%; alert fires within 3 min.
Method:     Toxiproxy injects 503 on egress to api.stripe.com for 10 min in staging (then prod canary).
Abort if:   Duplicate charges detected, or order creation failure > 10%.
Measure:    Time to alert, orders stuck, retries succeeded after recovery, duplicate charges (must be 0).
```

- **Postmortems** ([templates/postmortem.md](templates/postmortem.md)) with action items tracked to completion; recoverability improves through them.

### Expert Mental Model

> Prevention has limits; recovery doesn't depend on predicting the failure. I set RPO/RTO from business impact, then *prove* them regularly. An untested recovery path counts as no recovery path.

### Common Mistake

"We have daily backups" (never restored, same account as production so ransomware deletes both, and RPO silently 24 h for a system where losing 24 h of orders is catastrophic).

---

## 15. Delivery Health: DORA Metrics as the Meta-Signal

### What

The DORA research program (*Accelerate*, State of DevOps reports) identified delivery metrics that predict both organizational performance and stability:

| Metric | Measures | Elite (approximate, varies by report year) |
|---|---|---|
| **Deployment frequency** | How often you deploy to production | On demand, multiple per day |
| **Lead time for changes** | Commit → running in production | < 1 day |
| **Change failure rate** | % of deployments causing degraded service needing remediation (rollback, hotfix, incident) | ~0–15% |
| **Failed deployment recovery time** (formerly MTTR) | Time to restore after a failed change | < 1 hour |
| **Rework rate** (added in recent reports) | Share of deployments that are unplanned fixes | Low |

### Why

These are the **meta-quality** metrics. They measure whether your quality system works *without slowing you down*. The central finding of the research: **speed and stability are not trade-offs at the system level.** Teams that deploy small changes often have *lower* change failure rates, because small changes are easier to review, test, and roll back.

```text
Big batch, monthly release:
  400 changes → 1 deploy → something breaks → which of 400? → 6 h diagnosis → risky hotfix

Small batch, continuous:
  400 changes → 400 deploys → one breaks → it's the last one → auto-rollback in 3 min
```

### How

Compute them from data you already have:

```sql
-- Assuming a deployments table populated by CI and an incidents table linked to deploys
-- Change failure rate, last 90 days
SELECT
  count(*) FILTER (WHERE caused_incident OR rolled_back OR hotfix_followed_within_24h) ::float
  / NULLIF(count(*), 0) AS change_failure_rate
FROM deployments
WHERE environment = 'production' AND deployed_at > now() - interval '90 days';

-- Lead time p50 / p90 (first commit of PR → production deploy)
SELECT
  percentile_cont(0.5) WITHIN GROUP (ORDER BY deployed_at - first_commit_at) AS p50,
  percentile_cont(0.9) WITHIN GROUP (ORDER BY deployed_at - first_commit_at) AS p90
FROM deployments d JOIN pull_requests pr ON pr.merge_sha = d.sha
WHERE d.environment = 'production' AND d.deployed_at > now() - interval '90 days';
```

### Expert Mental Model

> If adding a quality gate increases lead time without lowering change failure rate, it's a bad gate. The goal is a pipeline that is both fast and safe, and small batches are how you get both.

### Common Mistake

Using DORA metrics to rank individuals or teams. Once they become targets, people game them (splitting deploys, not recording incidents). Use them as **diagnostics for the system**.

---

## 16. The Enforcement Stack

Quality enforcement works best as layers, each catching problems as early (cheap) as possible. The cost of fixing a defect rises steeply the later it's found.

```text
Layer                 Latency    Examples                                          Catches
────────────────────────────────────────────────────────────────────────────────────────────────────
0. Design             days       design doc, threat model, invariant register,     wrong problem, wrong
                                 ADR, failure-mode analysis                        architecture, missing invariants
1. Editor             ms         TypeScript, ESLint, Prettier on save              type errors, conventions
2. Pre-commit         seconds    lint-staged, gitleaks, typecheck changed files    secrets, obvious breakage
3. PR CI              minutes    full typecheck, unit, integration, contract,      regressions, boundary violations,
                                 arch tests, SAST, SCA, bundle budget, a11y,       vulns, perf/a11y regressions
                                 migration lint, mutation (incremental)
4. Human review       hours      checklist-driven review, CODEOWNERS               design fit, readability,
                                                                                   authz logic, missing cases
5. Merge/release      minutes    E2E on staging, smoke tests, can-i-deploy,        integration, deploy safety
                                 migration dry-run, image signing
6. Progressive deploy minutes    canary + automated analysis, feature flags        prod-only issues, scale effects
7. Runtime            continuous SLO burn alerts, invariant checks,                real-world degradation,
                                 reconciliation, RUM, anomaly detection            silent corruption
8. Learning           weeks      postmortems, game days, restore drills,           systemic weaknesses
                                 DORA review, hotspot review
```

Rules of thumb:

1. **Move checks left when they're deterministic and fast.** A formatting issue in review wastes a human; a missing index in production wastes a weekend.
2. **Keep checks right when they need real conditions.** You can't find tail latency under real traffic in a unit test.
3. **Every incident should add or strengthen an automated layer.** "Be more careful" isn't a valid postmortem action item.
4. **Every gate must be fast, deterministic, and explain how to fix the failure.** Gates that fail cryptically or flake get bypassed.

### Pre-commit example

```jsonc
// package.json (excerpt)
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "eslint . --max-warnings=0",
    "test": "vitest run",
    "test:int": "vitest run --config vitest.integration.config.ts",
    "arch": "depcruise src --config .dependency-cruiser.cjs",
    "mutation": "stryker run --incremental",
    "prepare": "husky"
  },
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix --max-warnings=0", "prettier --write"],
    "*.{json,md,yml,yaml}": ["prettier --write"]
  }
}
```

```bash
# .husky/pre-commit
npx lint-staged
npx gitleaks protect --staged --redact
```

Pre-commit hooks are a **convenience**, not a gate (they can be skipped with `--no-verify`). The CI checks are the real gate.

### Migration safety lint

Database migrations are among the highest-risk changes. Lint them automatically (e.g., `squawk` for PostgreSQL):

```bash
npx squawk migrations/*.sql
# flags e.g.:
#  - adding a column with a volatile DEFAULT (table rewrite on older PG)
#  - CREATE INDEX without CONCURRENTLY (blocks writes)
#  - adding NOT NULL without a prior validated CHECK constraint
#  - changing column type (rewrite + lock)
#  - renaming a column (breaks running app instances during rolling deploy)
```

---

## 17. A Real CI Pipeline With Quality Gates

Below is a realistic GitHub Actions pipeline for a TypeScript monorepo with a Next.js storefront (`apps/web`) and a Node.js API (`apps/api`) on PostgreSQL. It is organized so that **fast, cheap checks fail first**, jobs run in parallel, and every gate is a required status check under branch protection.

```yaml
# .github/workflows/ci.yml
name: ci

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

env:
  NODE_VERSION: '22'
  TURBO_TELEMETRY_DISABLED: '1'

jobs:
  # ───────────────────────────── Gate 1: static checks (fast, ~2 min) ─────────────────────────────
  static:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2 (pinned by SHA)
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
        with: { node-version: '${{ env.NODE_VERSION }}', cache: 'pnpm' }
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile

      - name: Format check
        run: pnpm prettier --check .

      - name: Typecheck (strict)
        run: pnpm turbo run typecheck

      - name: Lint (zero warnings)
        run: pnpm turbo run lint -- --max-warnings=0

      - name: Architecture rules
        run: pnpm depcruise apps packages --config .dependency-cruiser.cjs --output-type err-long

      - name: Lint migrations
        run: pnpm squawk apps/api/migrations/*.sql

      - name: Conventional commit PR title
        if: github.event_name == 'pull_request'
        uses: amannn/action-semantic-pull-request@v5
        env: { GITHUB_TOKEN: '${{ secrets.GITHUB_TOKEN }}' }

  # ───────────────────────────── Gate 2: security scanning (~3 min) ─────────────────────────────
  security:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with: { fetch-depth: 0 }
      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2
        env: { GITHUB_TOKEN: '${{ secrets.GITHUB_TOKEN }}' }
      - name: SAST (Semgrep, blocking on high-confidence rules)
        run: |
          pipx run semgrep ci --config p/typescript --config p/nextjs --config .semgrep/ \
            --severity ERROR --error
      - name: Dependency vulnerabilities (fail on critical/high with fix available)
        run: |
          npx --yes osv-scanner@latest --lockfile=pnpm-lock.yaml --format table || EXIT=$?
          node scripts/ci/osv-gate.mjs   # fails only on CRITICAL/HIGH that have a fixed version
      - name: License policy
        run: npx --yes license-checker-rseidelsohn --production --failOn "GPL-3.0;AGPL-3.0"

  # ───────────────────────────── Gate 3: unit tests + coverage (~3 min) ─────────────────────────────
  unit:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af
        with: { node-version: '${{ env.NODE_VERSION }}', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - name: Unit tests with coverage thresholds
        # vitest.config.ts sets thresholds per path: domain 90% branches, overall 70% lines.
        # Coverage is a floor that detects untested code — mutation testing measures strength.
        run: pnpm turbo run test -- --coverage
      - uses: actions/upload-artifact@v4
        with: { name: coverage, path: '**/coverage/lcov.info' }

  # ───────────────────────────── Gate 4: integration + contract (~6 min) ─────────────────────────────
  integration:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_PASSWORD: test, POSTGRES_DB: app_test }
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U postgres" --health-interval 5s --health-timeout 5s --health-retries 10
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
    env:
      DATABASE_URL: postgres://postgres:test@localhost:5432/app_test
      REDIS_URL: redis://localhost:6379
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af
        with: { node-version: '${{ env.NODE_VERSION }}', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile

      - name: Migrations apply cleanly from zero
        run: pnpm --filter api migrate:up

      - name: Migrations are reversible (down then up)
        run: pnpm --filter api migrate:down --all && pnpm --filter api migrate:up

      - name: Schema drift check (ORM model vs DB)
        run: pnpm --filter api db:diff --exit-code

      - name: Integration tests (real Postgres, concurrency + tenant isolation + authz suites)
        run: pnpm --filter api test:int

      - name: Provider contract verification (Pact)
        run: pnpm --filter api pact:verify
        env:
          PACT_BROKER_BASE_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}
          GIT_SHA: ${{ github.sha }}

  # ───────────────────────────── Gate 5: mutation testing on changed domain code ─────────────────────────────
  mutation:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with: { fetch-depth: 0 }
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af
        with: { node-version: '${{ env.NODE_VERSION }}', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - name: Restore Stryker incremental cache
        uses: actions/cache@v4
        with:
          path: apps/api/reports/stryker-incremental.json
          key: stryker-${{ github.base_ref }}-${{ hashFiles('apps/api/src/domain/**') }}
          restore-keys: stryker-${{ github.base_ref }}-
      - name: Mutation testing (break threshold 65% on domain layer)
        run: pnpm --filter api stryker run --incremental

  # ───────────────────────────── Gate 6: frontend build, budgets, a11y, E2E (~8 min) ─────────────────────────────
  web:
    runs-on: ubuntu-latest
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af
        with: { node-version: '${{ env.NODE_VERSION }}', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile

      - name: Build Next.js
        run: pnpm --filter web build
        env: { NEXT_TELEMETRY_DISABLED: '1' }

      - name: Bundle size budget
        # size-limit config: first-load JS for / ≤ 110 KB gz, /checkout ≤ 140 KB gz
        run: pnpm --filter web size-limit

      - name: Install Playwright browsers
        run: pnpm --filter web exec playwright install --with-deps chromium

      - name: E2E critical journeys + axe a11y checks
        run: pnpm --filter web test:e2e --project=chromium --grep "@critical|@a11y"

      - name: Lighthouse CI (LCP, CLS, TBT, perf score)
        run: pnpm --filter web exec lhci autorun

      - uses: actions/upload-artifact@v4
        if: failure()
        with: { name: playwright-report, path: apps/web/playwright-report }

  # ───────────────────────────── Aggregate required check ─────────────────────────────
  quality-gate:
    if: always()
    needs: [static, security, unit, integration, mutation, web]
    runs-on: ubuntu-latest
    steps:
      - name: All gates must pass (skipped mutation allowed on push to main)
        run: |
          results='${{ toJSON(needs) }}'
          echo "$results" | jq -e 'to_entries | map(select(.value.result != "success" and .value.result != "skipped")) | length == 0'
```

And the delivery pipeline that follows a merge to `main`:

```yaml
# .github/workflows/deploy.yml (excerpt)
name: deploy
on:
  push:
    branches: [main]

jobs:
  build-image:
    runs-on: ubuntu-latest
    permissions: { contents: read, id-token: write, packages: write }
    outputs: { digest: '${{ steps.push.outputs.digest }}' }
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - id: push
        uses: docker/build-push-action@v6
        with: { push: true, tags: 'ghcr.io/acme/api:${{ github.sha }}', provenance: true, sbom: true }
      - name: Scan image (fail on critical)
        uses: aquasecurity/trivy-action@0.28.0
        with: { image-ref: 'ghcr.io/acme/api:${{ github.sha }}', severity: CRITICAL, exit-code: '1', ignore-unfixed: true }
      - name: Sign image
        run: cosign sign --yes ghcr.io/acme/api@${{ steps.push.outputs.digest }}

  staging:
    needs: build-image
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - run: ./ops/deploy.sh staging ${{ needs.build-image.outputs.digest }}
      - name: Migration (expand phase only; contract migrations are separate, later releases)
        run: ./ops/migrate.sh staging --phase expand
      - name: Smoke tests
        run: pnpm test:smoke --base-url https://staging.acme.dev
      - name: Can I deploy? (contract compatibility with deployed consumers)
        run: pnpm pact-broker can-i-deploy --pacticipant orders-api --version ${{ github.sha }} --to-environment production

  production:
    needs: staging
    environment: production   # protected environment: required reviewers for tier-1 services, deploy windows
    runs-on: ubuntu-latest
    steps:
      - name: Check error budget (block if exhausted, per policy)
        run: ./ops/slo/check-budget.sh orders-api --min-remaining 0
      - name: Canary rollout with automated analysis
        # Argo Rollouts: 5% for 10 min → 25% for 10 min → 100%
        # AnalysisTemplate compares canary vs stable: 5xx ratio, p95 latency, business metric (orders/min)
        # Automatic abort + rollback on failure
        run: ./ops/rollout.sh production ${{ needs.build-image.outputs.digest }} --strategy canary --wait
      - name: Record deployment (for DORA metrics)
        if: always()
        run: ./ops/dora/record-deploy.sh --sha ${{ github.sha }} --status ${{ job.status }}
```

### Why this pipeline is structured this way

| Design choice | Reason |
|---|---|
| Actions pinned by SHA | A compromised tag can't inject code into your pipeline (supply-chain) |
| `--frozen-lockfile` | Builds are reproducible; no silent dependency drift |
| `--max-warnings=0` | Warnings that never fail accumulate into noise nobody reads |
| Migrations tested up/down/up and linted | Migration failures are among the most damaging deploy failures |
| Schema drift check | ORM model and actual DB can't silently diverge |
| Mutation testing only on PRs, incremental, domain-only | Keeps it fast enough to be a gate |
| Concurrency, tenant-isolation, and authz suites named explicitly | The most dangerous bugs get dedicated, visible suites |
| Budgets (bundle, Lighthouse) as errors | Performance regressions blocked at PR time, when the cause is obvious |
| Aggregate `quality-gate` job | Branch protection needs one stable required check even as jobs change |
| Error-budget check before prod | Enforces the reliability policy automatically |
| Canary with automated analysis | Catches problems only real traffic reveals, with automatic rollback |
| Deployment recording | DORA metrics become a by-product, not a spreadsheet |

### Scaling the pipeline down

A solo developer's side project doesn't need all of this. The minimum viable quality pipeline:

```text
typecheck + lint (zero warnings) + unit tests + integration tests against real DB
+ migration apply check + dependency vulnerability scan + secret scan
+ one-command deploy with health-check-gated rollback
+ uptime check + error tracking (e.g., Sentry) + automated backups with a quarterly restore test
```

Package it as a **template repository** so every new project starts with it ([10-knowledge-into-systems.md](10-knowledge-into-systems.md), [templates/project-bootstrap-checklist.md](templates/project-bootstrap-checklist.md)).

---

## 18. Testing Strategy: Pyramid, Trophy, and What Actually Matters

### What

A testing strategy decides **which kinds of tests verify which kinds of risk**, in what proportion, and at what cost.

### The models

```text
Test Pyramid (Cohn)             Testing Trophy (Dodds)          Honeycomb (Spotify, microservices)

        /\   E2E (few)                 ___  E2E                     ___ integrated (few)
       /  \                           /   \                        /   \
      /----\ Integration             | INT |  ← most value         |INTEG|  ← most tests
     /      \                         \___/                        |RATION|
    /--------\ Unit (many)            /___\  Unit                   \___/
   /__________\                      [_____] Static (types, lint)    \_/  implementation detail (few)
```

They're not in conflict. They reflect **different architectures**:

| System shape | Where bugs live | Emphasis |
|---|---|---|
| Rich domain logic (pricing, allocation, ledger) | Calculations and state transitions | Many **unit + property** tests on the pure domain core |
| CRUD-ish web app / Next.js frontend | Wiring: components + data + routing | **Integration** tests (React Testing Library, route handlers against real DB) |
| Microservices / heavy integrations | Contracts between services | **Contract** tests + integration tests per service; few E2E |
| Any system | Critical user journeys | A **small** number of E2E tests (login, checkout, payout) |

### Risk-based test design

Choose tests by asking **"what would hurt most if it broke, and what's the cheapest test that would catch it?"**

```text
Risk                                               Cheapest reliable test
──────────────────────────────────────────────────────────────────────────────────────────
Tax calculation wrong for EU reverse-charge          Unit + table-driven examples from accountant
Double allocation under concurrent orders            Integration test with real PG + parallel requests
Tenant A reads tenant B's invoice                    Generated authz integration test per resource
Mobile checkout button unreachable via keyboard      Playwright + axe on the checkout route
Orders API change breaks storefront                  Consumer-driven contract test
Stripe webhook replayed twice → double fulfillment   Integration test: deliver same event twice, assert one fulfillment
Migration locks orders table for 4 minutes           squawk lint + staging migration on production-sized data
Login broken after deploy                            Post-deploy smoke test + synthetic monitor
```

### Test quality rules that experts enforce

1. **Test behavior, not implementation.** Tests should survive refactoring. Asserting that `repo.save` was called with specific arguments couples the test to the implementation; asserting the resulting state doesn't.
2. **Deterministic or deleted.** Control time, randomness, network, and ordering.
3. **One reason to fail.** A failing test's name should tell you what's broken.
4. **Fast feedback tiers.** Unit < 1 min locally; the full PR pipeline < 15 min.
5. **Test data builders** instead of shared mutable fixtures:

```ts
// test/builders/order.ts
export const anOrder = (overrides: Partial<OrderProps> = {}): OrderProps => ({
  id: `ord_${crypto.randomUUID()}`,
  tenantId: 'ten_default',
  status: 'PENDING',
  lines: [{ sku: 'SKU-1', qty: 1, unitPriceCents: 1000 }],
  currency: 'USD',
  createdAt: new Date('2026-01-15T10:00:00Z'),
  ...overrides,
});

// usage: intention-revealing, only the relevant fields specified
const order = anOrder({ status: 'PAID', lines: [{ sku: 'SKU-9', qty: 3, unitPriceCents: 250 }] });
```

6. **Regression test first.** Every production bug gets a failing test before the fix.

### Common Mistake

The **ice-cream cone**: hundreds of slow, flaky Selenium/Cypress E2E tests, almost no unit or integration tests. The suite takes 90 minutes, fails randomly, and people stop trusting red builds, which is worse than having no tests.

---

## 19. Human Gates: Review Checklists, Definition of Done, Release Gates

Automation handles what's deterministic. Humans handle **judgment**: design fit, naming that matches the domain, missing cases, authorization logic, operational readiness. The trick is to make human gates **checklist-driven** so they're consistent, and to keep automatable items off the human checklist.

### Code review checklist (what humans check, not what CI checks)

```markdown
## Reviewer checklist (see templates/pull-request.md)

### Problem & design
- [ ] The PR solves the problem described in the linked issue — not a different one.
- [ ] The change fits the module's responsibility; no logic leaking across boundaries.
- [ ] Simplest design that meets requirements; no speculative abstraction.

### Correctness
- [ ] Invariants touched by this change are listed and still enforced (code + DB + test).
- [ ] Edge cases: empty, max, duplicate, concurrent, retry, partial failure, timezone, currency rounding.
- [ ] State transitions are legal; illegal transitions rejected.

### Security
- [ ] Every new endpoint/action has explicit authorization, scoped to tenant.
- [ ] No sensitive data in logs, errors, URLs, or client bundles.
- [ ] Untrusted input parsed at the boundary.

### Failure & operations
- [ ] Every external call has a timeout; retries are idempotent-safe.
- [ ] Failure paths are observable (structured log/metric/span with enough context).
- [ ] Migration is backward-compatible with the currently deployed version.
- [ ] Feature flag / rollback plan for risky changes.

### Tests
- [ ] Tests assert behavior and would fail if the feature broke (read them, don't just count them).
- [ ] Bug fixes include a regression test that failed before the fix.
```

**Review norms that make this work:**
- PRs < ~400 changed lines (review quality drops sharply beyond that).
- The author annotates non-obvious decisions in the PR description.
- Comments are labeled: `blocking:`, `suggestion:`, `nit:`, `question:`.
- CODEOWNERS require domain owners for high-risk paths (`/apps/api/src/modules/payments/`, `/migrations/`, `/infra/`).

### Definition of Done

A shared, explicit contract for what "done" means, so "done" doesn't mean "merged" to one person and "in production, monitored, documented" to another. Full template: [templates/definition-of-done.md](templates/definition-of-done.md).

```markdown
A change is DONE when:
1. Acceptance criteria met and demonstrated (screenshot/video/test for UI; example requests for API).
2. All CI quality gates green; no new lint suppressions without a linked ticket.
3. Tests: unit for domain logic, integration for persistence/authz, regression for bug fixes.
4. Observability: logs/metrics/traces for new paths; alert + runbook if it can page.
5. Security: authz on new endpoints; threat model updated if trust boundaries changed.
6. Data: migrations expand/contract-safe; backfill plan documented if needed.
7. Docs: API reference/changelog updated; ADR written if an architectural decision was made.
8. Deployed to production (behind flag if incomplete) and verified by smoke test/dashboard.
9. Feature flag cleanup ticket created (flags have an expiry).
```

### Release gates (for higher-risk systems)

```text
Release readiness review — tier-1 service (payments, ledger, auth)
□ Load test at 2× expected peak passed with p99 within SLO
□ Failure-mode analysis completed for new dependencies (templates/failure-mode-analysis.md)
□ Rollback tested in staging, including migration compatibility
□ On-call briefed; runbooks updated; dashboards exist
□ Security review sign-off if authN/authZ/money/PII touched
□ Error budget > 25% remaining
□ Launch plan: flag rollout percentages, success metrics, abort criteria, owner on duty
```

### Expert Mental Model

> Humans review what machines can't judge. If I keep leaving the same review comment, that comment should become a lint rule, a template, or a library. Review is where knowledge gets discovered; automation is where it gets enforced.

---

## 20. Quality Trade-offs Between Attributes

Quality attributes compete. Expert engineering means **making those trade-offs explicitly, per context**, not maximizing everything.

### The tension map

| Tension | Why they conflict | Typical resolution |
|---|---|---|
| **Performance vs Maintainability** | Optimized code is denormalized, cached, specialized, harder to read | Optimize measured hotspots only; isolate optimizations behind clean interfaces; document why |
| **Performance vs Correctness/Consistency** | Caches and async processing introduce staleness; skipping locks introduces races | Decide per data type: balances strongly consistent, product catalog eventually consistent with bounded staleness |
| **Security vs Usability** | MFA, short sessions, and strict validation add friction | Risk-based step-up auth (MFA for payouts, not for viewing dashboards); passkeys |
| **Security vs Observability** | Rich logs leak PII/secrets | Structured logs with redaction, tokenized identifiers, separate audit log with stricter access |
| **Reliability vs Velocity** | Every gate and approval slows delivery | Error budgets decide dynamically; small batches make both better |
| **Scalability vs Simplicity** | Sharding, queues, and distribution add operational complexity | Scale vertically and with read replicas first; distribute only when measured need arises |
| **Evolvability vs Simplicity** | Abstractions for future change add indirection now | Invest only in expensive-to-change decisions (data model, contracts); YAGNI elsewhere |
| **Availability vs Consistency** | Under network partition you pick one (CAP); in normal operation, latency vs consistency (PACELC) | Payments: consistency; social feed: availability |
| **Testability vs Performance** | Indirection for DI/ports can cost (usually negligibly) | Almost always choose testability; measure before claiming otherwise |
| **Recoverability vs Cost** | Multi-region, sync replication, and frequent snapshots cost money | Set RPO/RTO per data class from business impact |
| **Observability vs Cost** | High-cardinality metrics and 100% trace sampling are expensive | Tail-based sampling (keep errors and slow traces), log levels, retention tiers |

### How experts make the trade-off

```text
1. Name the attributes in tension explicitly.
2. Ask which failure is worse for THIS system and THIS data:
     stale product price for 60 s  vs  checkout 300 ms slower?
     occasional duplicate notification  vs  occasional missed notification?
3. Quantify where possible (cost of an hour of downtime, conversion loss per 100 ms, fraud cost).
4. Choose, and scope the choice (per endpoint / per data class, not globally).
5. Record it as an ADR with the revisit trigger ("revisit if cache staleness complaints > 5/month").
6. Add the sensor for the attribute you sacrificed, so you know if you sacrificed too much.
```

### Worked example: product catalog vs inventory in e-commerce

```text
Product catalog page
  Priority: performance, availability, SEO
  Accepts: staleness up to 5 min for descriptions, 60 s for price display
  Decision: Next.js ISR/cached RSC with revalidate tags on product update; CDN cache
  Sensor for sacrificed attribute: "price mismatch at checkout" event count

Add-to-cart availability badge
  Priority: perceived accuracy
  Accepts: staleness 30 s ("Only 3 left" may be slightly off)
  Decision: Redis-cached availability, updated on stock events
  Sensor: rate of "out of stock at checkout" errors

Checkout allocation
  Priority: correctness (never oversell), then reliability
  Accepts: +40 ms latency for row locks, lower max throughput
  Decision: PostgreSQL transaction with SELECT ... FOR UPDATE on stock row + CHECK constraint
  Sensor: allocation lock wait p99, oversell invariant check (must be 0)
```

One product, three different trade-off decisions, each scoped to a data class. That scoping is the expert pattern.

---

## 21. Right-Sizing Quality: Criticality Tiers

Applying tier-1 rigor to everything is as damaging as applying none. It burns time and makes gates feel bureaucratic. Classify components and scale requirements.

| Requirement | Tier 1 — Critical (money, auth, ledger, tenant data) | Tier 2 — Core product | Tier 3 — Internal / low-risk |
|---|---|---|---|
| Availability SLO | 99.9–99.99% | 99.5–99.9% | Best effort / 99% |
| RPO / RTO | ~0 / ≤ 15 min | ≤ 15 min / ≤ 1 h | ≤ 24 h / ≤ 1 day |
| Mutation score gate | ≥ 75% domain | ≥ 60% domain | None |
| Invariant register + reconciliation | Required | Recommended | — |
| Threat model | Required for every change touching boundaries | Per feature | Per project |
| Load test | Before each major release | Before known peaks | — |
| Human review | 2 reviewers incl. code owner | 1 reviewer | 1 reviewer or self-review with checklist (solo) |
| Deploy | Canary + automated analysis | Rolling + auto-rollback on health | Rolling |
| Restore drill | Monthly | Quarterly | Annually |
| Game days | Quarterly | Semi-annually | — |

Record each component's tier in its README or service catalog entry, so the pipeline template can read it and enable the right gates automatically.

---

## 22. Amateur vs Professional vs Expert

| Dimension | Amateur | Professional | Expert |
|---|---|---|---|
| Definition of quality | "It works when I try it" | "Tests pass, reviewed, deployed" | "Each attribute has a target, a sensor, and an enforcement mechanism scaled to criticality" |
| Testing | Manual clicking; some tests after the fact | Unit + some integration; coverage target | Risk-based strategy; mutation score on core; concurrency, authz, and contract suites; property tests for invariants |
| Coverage | Unknown or ignored | Chased to 80% | Used as a floor to find untested code; strength measured by mutation score |
| Reliability | "Is it up?" | Uptime monitoring, CPU alerts | User-centric SLIs, SLOs, burn-rate alerts, error budget policy |
| Conventions | In their head | Written in a wiki | Encoded in lint rules, architecture tests, generators, and templates |
| Code review | Approve if it looks fine | Line-level comments | Checklist-driven on judgment items; recurring comments turned into automation |
| Performance | Notices when it's slow | Load test occasionally | Budgets in CI, latency SLOs, capacity model with known knee |
| Security | Fixes reported vulnerabilities | Runs scanners | Deny-by-default structure, tenant-isolation tests, supply-chain controls, tuned blocking rules |
| Recovery | "We have backups" | Backups + documented restore | Restores drilled and timed against RTO/RPO; rollback is a button; game days |
| Incidents | Blame, hotfix, move on | Postmortem document | Blameless postmortem → automated guard added → tracked to closure |
| Trade-offs | Implicit, accidental | Discussed in meetings | Explicit, scoped per data class, recorded in ADRs with sensors on the sacrificed attribute |
| Delivery | Big releases, fear of deploys | Regular releases | Small batches, many deploys per day, low change-failure rate, DORA tracked |
| Legacy quality debt | Ignored or "big rewrite" | Occasional cleanup sprints | Ratchets that prevent growth; hotspot-targeted refactoring |

**How to recognize expert quality engineering quickly** (e.g., when joining a project):

```text
1. Can you run the whole system and its tests locally with one command in < 30 min?
2. Is there a written SLO and does anyone look at the error budget?
3. Open .github/workflows (or equivalent): are architecture, security, migration, and budget checks there?
4. When was the last restore drill, and how long did it take?
5. Pick a recent incident: what automated guard was added because of it?
6. Grep for a critical invariant (e.g., "allocated <= on_hand"): is it in code, DB, AND tests?
7. How long from merge to production, and how often does a deploy get rolled back?
```

---

## 23. Common Mistakes

| Mistake | Why it's harmful | What experts do instead |
|---|---|---|
| Quality as a final phase | Defects found late cost multiples; design flaws are baked in | Shift enforcement left; design-time reviews for invariants and threats |
| Coverage % as the quality target | Rewards assertion-free tests | Mutation score on core, risk-based suites |
| Too many flaky or slow gates | People bypass or stop trusting them | Every gate fast, deterministic, actionable; fix or remove flakes quickly |
| Alerting on causes, not symptoms | Noise pages, missed real outages | SLO burn-rate alerts; cause metrics on dashboards for diagnosis |
| Warnings allowed to accumulate | Signal drowns; real issues invisible | `--max-warnings=0`; ratchets for legacy |
| Uniform rigor everywhere | Bureaucracy on trivial code, fatigue | Criticality tiers |
| "Be more careful" postmortem actions | Doesn't change the system | Every action item is a mechanism: test, lint rule, alert, constraint, automation |
| Conventions only in docs | Drift immediately | Lint rules, architecture tests, generators, templates |
| Untested backups and rollbacks | False confidence | Scheduled drills with verification and timing |
| Maximizing one attribute globally | Sacrifices others unnecessarily | Scoped trade-offs per data class, recorded in ADRs |
| Big-batch releases "for safety" | Increases blast radius and diagnosis time | Small batches, progressive delivery, feature flags |
| Mocking the database | Tests pass while SQL, constraints, and locking are wrong | Real PostgreSQL in containers for integration tests |
| Metrics used to judge individuals | Gaming, hidden incidents | Metrics diagnose the system |

---

## Key Takeaways

1. **Quality is a set of properties**: correctness, reliability, maintainability, security, performance, scalability, testability, observability, operability, usability, evolvability, recoverability. "It works" covers only a sliver of the first one.
2. **Each property needs a definition, a measurement, a target, and an enforcement mechanism.** Without all four it's a hope, not engineering.
3. **Systems beat discipline.** Encode conventions in types, lint rules, architecture tests, database constraints, templates, CI gates, and runtime alerts, so quality holds when people are tired, new, or rushed.
4. **Layer enforcement from design to runtime**, catching each class of problem at the cheapest layer that reliably detects it.
5. **Use better proxies:** mutation score over line coverage, SLO burn over CPU alerts, p95/p99 over averages, change failure rate and lead time over "number of releases," timed restore drills over "we have backups."
6. **Speed and stability reinforce each other** through small batches, fast pipelines, progressive delivery, and quick rollback.
7. **Trade-offs are unavoidable; make them explicit, scoped, recorded, and monitored.**
8. **Right-size rigor by criticality tier.** Over-engineering quality is also a failure.
9. **Every incident and recurring review comment should turn into a mechanism**, so the system gets smarter over time ([10-knowledge-into-systems.md](10-knowledge-into-systems.md)).

## Self-Assessment Checklist

- [ ] For my most important system, I can state its SLIs, SLOs, and current error budget.
- [ ] I know my RPO and RTO, and I've **timed** a restore within the last quarter.
- [ ] My CI blocks on typecheck, lint (zero warnings), tests against a real database, architecture rules, secret scanning, and dependency vulnerabilities.
- [ ] I measure test strength (mutation score) on at least the domain core, not just coverage.
- [ ] Critical invariants are enforced in code, database constraints, and tests, and checked in production.
- [ ] Every paging alert is symptom-based and links to a runbook.
- [ ] I can deploy and roll back with one command in minutes.
- [ ] I have written criticality tiers and scale gates accordingly.
- [ ] My last three postmortems each produced at least one automated guard.
- [ ] I track lead time and change failure rate, and I know both numbers.
- [ ] Recurring review comments have been converted into lint rules, templates, or libraries.
- [ ] Trade-offs I made (consistency vs latency, security vs friction) are recorded in ADRs with a sensor on the sacrificed attribute.
