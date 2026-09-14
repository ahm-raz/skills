# 10 — How Experts Turn Knowledge Into Systems

> Individual expertise does not scale; systems do. Mature engineers and organizations systematically convert lessons that live in someone's head into conventions, templates, libraries, automated checks, tests, and quality gates, so that the *correct* way becomes the *default* way and the *wrong* way becomes hard or impossible. This chapter explains the "knowledge ladder", when to climb each rung, what each rung costs, and how to keep the resulting system alive instead of letting it rot.

---

## Table of Contents

1. [The Core Idea: Memory Is Not a Control](#1-the-core-idea-memory-is-not-a-control)
2. [The Knowledge Ladder](#2-the-knowledge-ladder)
3. [Rung 1 — Knowledge](#3-rung-1--knowledge)
4. [Rung 2 — Convention](#4-rung-2--convention)
5. [Rung 3 — Documentation](#5-rung-3--documentation)
6. [Rung 4 — Template](#6-rung-4--template)
7. [Rung 5 — Library](#7-rung-5--library)
8. [Rung 6 — Automation](#8-rung-6--automation)
9. [Rung 7 — CI Check](#9-rung-7--ci-check)
10. [Rung 8 — Test](#10-rung-8--test)
11. [Rung 9 — Quality Gate](#11-rung-9--quality-gate)
12. [When to Climb: The Economics of Encoding](#12-when-to-climb-the-economics-of-encoding)
13. [Worked Trace #1: "Every tenant query must filter by tenant_id"](#13-worked-trace-1-every-tenant-query-must-filter-by-tenant_id)
14. [Worked Trace #2: "Always paginate list endpoints"](#14-worked-trace-2-always-paginate-list-endpoints)
15. [Worked Trace #3: "Money is never a float"](#15-worked-trace-3-money-is-never-a-float)
16. [The Incident → Postmortem → Guardrail Loop](#16-the-incident--postmortem--guardrail-loop)
17. [Keeping the System From Rotting](#17-keeping-the-system-from-rotting)
18. [Poka-Yoke: Designing Mistakes Out](#18-poka-yoke-designing-mistakes-out)
19. [Amateur vs Professional vs Expert](#19-amateur-vs-professional-vs-expert)
20. [Common Mistakes](#20-common-mistakes)
21. [Key Takeaways](#key-takeaways)
22. [Self-Assessment Checklist](#self-assessment-checklist)

---

## 1. The Core Idea: Memory Is Not a Control

### What

A **control** is a mechanism that reliably prevents or detects an undesired outcome. Human memory, vigilance, and "being careful" are *not* controls — they are hopes. Turning knowledge into systems means replacing hopes with controls.

### Why

- **People forget.** You will not remember in 14 months why `orders.status` must never go from `shipped` back to `pending`.
- **People change.** New teammates, contractors, AI agents, and future-you did not experience the incident that taught the lesson.
- **Attention is finite.** A reviewer looking at a 900-line PR will miss the one query without `tenant_id`.
- **Scale multiplies error.** A 1-in-200 mistake rate is fine for 10 changes a month; it is a guaranteed incident at 400 changes a month.
- **Parallel work fragments context.** A solo developer running five projects (see [11-solo-developer-multiple-projects.md](11-solo-developer-multiple-projects.md)) literally cannot hold every rule of every project in working memory.

### How

For every important lesson, ask:

```text
1. Where does this knowledge currently live?        (head / chat / doc / code / CI)
2. What happens if the person holding it is absent? (nothing / slower / incident)
3. How often is the rule exercised?                  (daily / weekly / rarely)
4. What does a violation cost?                       (cosmetic / rework / data breach)
5. Can a machine detect a violation?                 (yes, cheaply / yes, expensively / no)
6. Can the violation be made impossible by design?   (yes / partially / no)
```

Then move the knowledge to the lowest-cost rung that makes the failure acceptably unlikely.

### Example

A payments engineer learns — painfully — that a webhook provider retries deliveries and a handler without an idempotency check double-credited 41 wallets.

| Where the lesson lives | Protection level |
|---|---|
| In the engineer's head | Only protects code this engineer writes, while they remember |
| In a Slack thread | Protects nobody; unsearchable in 3 months |
| In `docs/conventions/webhooks.md` | Protects people who read it before writing a handler |
| In a `createWebhookHandler()` library that requires an idempotency key | Protects everyone who uses the library |
| In a lint rule forbidding raw route handlers under `/webhooks/**` | Protects everyone, including people who didn't know the library exists |
| In a contract test that replays every webhook twice and asserts one side effect | Detects regressions even if someone bypasses the lint rule |
| In a merge gate requiring that test to pass | Makes shipping a violation impossible without an explicit override |

### Expert Mental Model

> "If a rule matters and I'm relying on someone remembering it, I don't have a rule — I have a wish. The question is not *whether* to encode it, but *how far up the ladder* the cost of failure justifies."

### Common Mistake

Writing a long wiki page after every incident and calling it "fixed". Documentation is the weakest durable rung; it only works when someone reads it at exactly the right moment.

---

## 2. The Knowledge Ladder

```text
                    ┌──────────────────────────────┐
   strongest   9    │ Quality Gate                 │  cannot merge/deploy unless satisfied
   enforcement 8    │ Test                         │  executable proof of behavior
               7    │ CI Check                     │  machine verifies every change
               6    │ Automation                   │  machine does the work for you
               5    │ Library                      │  correct behavior is a function call
               4    │ Template                     │  correct structure is the starting point
               3    │ Documentation                │  explained, findable, reviewable
               2    │ Convention                   │  agreed default ("we do it this way")
   weakest     1    │ Knowledge                    │  someone knows
                    └──────────────────────────────┘
```

Each rung changes **who is responsible for correctness**:

| Rung | Correctness depends on | Failure mode |
|---|---|---|
| Knowledge | A specific person remembering | Person absent / forgets |
| Convention | Team agreeing and remembering | Newcomers don't know it |
| Documentation | Someone reading at the right time | Not read, outdated |
| Template | Starting from the template | Code written from scratch or copied from old project |
| Library | Using the library | Library bypassed; library has a bug |
| Automation | Automation running | Automation not run; automation drift |
| CI Check | CI pipeline being configured | Check disabled, false positives cause ignores |
| Test | Test covering the scenario | Scenario untested; flaky test ignored |
| Quality Gate | Branch protection / deploy policy | Admin override abuse |

Two important properties:

1. **The rungs are not mutually exclusive — they stack.** A critical invariant typically lives on 4–6 rungs simultaneously (see defense-in-depth in [09-invariants-and-correctness.md](09-invariants-and-correctness.md)).
2. **The ladder is not strictly linear.** Sometimes you jump straight from Knowledge to Library (e.g., a `Money` type), skipping a convention doc entirely because the type *is* the documentation.

A useful reframing: the ladder moves knowledge along two axes.

```text
                  Detect ──────────────────────► Prevent
                    │                                │
  Human-dependent   │  code review checklist        │  convention, template
                    │                                │
  Machine-enforced  │  CI check, test, monitoring   │  library/type system, quality gate,
                    │                                │  database constraint
```

The top-right quadrant ("machine-enforced prevention") is the most valuable and usually the most expensive to build. Experts aim for it only for high-cost failures.

---

## 3. Rung 1 — Knowledge

### What

Tacit understanding held by a person: "don't call the ERP sync during business hours", "the `legacy_orders` table has duplicates before 2021", "Stripe amounts are in minor units".

### Why it matters

Every system starts here. Knowledge is where lessons originate: incidents, code reviews, customer bugs, profiling sessions, security findings. It is not bad — it is **unfinished**.

### How to capture it (cheaply)

Keep a friction-free capture channel so knowledge doesn't evaporate before you decide what to do with it:

```markdown
<!-- docs/lessons/INBOX.md — append-only, triaged weekly -->
## 2026-09-02 — WMS: pick list generation timed out
- Symptom: /api/picklists took 38s for warehouse DAL-2
- Cause: N+1 loading bin locations per line item
- Lesson: list endpoints that expand relations must batch-load
- Candidate rung: library (dataloader helper) + perf test
- Status: untriaged
```

### Example

A developer notices that `new Date('2026-03-08')` parses as UTC midnight while `new Date('2026-03-08T00:00')` parses as local time, causing a shipping cutoff bug in a logistics app. Right now, only they know.

### Expert Mental Model

> "Knowledge is inventory. Unprocessed inventory spoils. I capture it immediately and triage it on a schedule."

### Common Mistake

Letting lessons live only in commit messages, PR comments, or chat. They're technically "written down" but effectively lost.

---

## 4. Rung 2 — Convention

### What

An explicit agreement on a default: "all timestamps are stored as `timestamptz` in UTC", "all IDs are UUIDv7", "all list endpoints are cursor-paginated". (For how conventions differ from standards, rules, and principles, see [02-engineering-conventions.md](02-engineering-conventions.md).)

### Why

Conventions **eliminate decisions**. Each decision you don't have to make is time saved and a divergence prevented. Conventions also make violations *visible*: once "we always do X" is agreed, a PR that doesn't do X stands out.

### How

A convention is good when it is:

- **Short** — one sentence of rule plus one sentence of rationale.
- **Checkable** — someone (or something) can tell whether it's followed.
- **Owned** — someone can change it.
- **Scoped** — it says where it applies ("all public HTTP APIs", not "everything").

```markdown
### CONV-API-007: List endpoints are cursor-paginated
- Rule: Every endpoint returning a collection accepts `limit` (default 50, max 200)
  and `cursor`, and returns `{ data, nextCursor }`.
- Why: Unbounded lists caused the 2026-04 order-export outage (INC-112); offset
  pagination degrades on large tables and skips rows under concurrent inserts.
- Applies to: all HTTP/JSON APIs, internal and public.
- Enforcement: lint rule `api/require-pagination` (see ladder rung 7).
- Owner: platform
- Exceptions: enumerations with a hard cap < 100 rows (e.g. `/currencies`), documented in ADR.
```

### Example

In a SaaS codebase, three engineers implement soft delete three different ways: `deleted boolean`, `deleted_at timestamptz`, and a separate `archived_orders` table. A convention ("soft delete = nullable `deleted_at timestamptz`; queries use the `active_*` views") ends the divergence.

### Expert Mental Model

> "A convention is a decision made once so it never has to be made again. If I'm arguing about it in a PR, it should have been a convention."

### Common Mistake

Conventions without rationale. When nobody remembers *why*, conventions either get cargo-culted forever or discarded casually the first time they're inconvenient.

---

## 5. Rung 3 — Documentation

### What

Written, findable, versioned explanation: convention files, ADRs (see [templates/adr.md](templates/adr.md)), runbooks ([templates/runbook.md](templates/runbook.md)), architecture docs, onboarding guides, `AGENTS.md`/`CLAUDE.md` context files.

### Why

Documentation makes knowledge **transferable asynchronously**. It is the rung that onboards humans and AI agents, explains *why* higher rungs exist, and records exceptions.

### How

Put documentation **where the work happens**, not in a separate wiki:

```text
repo/
├── AGENTS.md                      # rules AI agents and humans must follow in this repo
├── ARCHITECTURE.md                # boundaries, data flow, invariants summary
├── docs/
│   ├── conventions/
│   │   ├── api.md
│   │   ├── database.md
│   │   └── errors.md
│   ├── adr/
│   │   ├── 0001-modular-monolith.md
│   │   └── 0014-row-level-security-for-tenancy.md
│   ├── invariants.md              # see templates/invariant-register.md
│   └── runbooks/
│       └── payment-webhook-backlog.md
└── src/
```

Documentation quality rules experts actually use:

1. **Link docs from the code they govern.** `// See docs/conventions/api.md#pagination` near the pagination helper; lint error messages link to the doc.
2. **Docs are reviewed in PRs** like code. A behavior change without a doc change is an incomplete PR (put it in [templates/definition-of-done.md](templates/definition-of-done.md)).
3. **Every doc has an owner and a `last-reviewed` date.**
4. **Prefer reference + rationale over tutorial prose.** People scan; they don't read.

### Example

The error message of a custom lint rule:

```text
error  api/require-pagination  Route GET /v1/orders returns an array without pagination.
       Use `paginate()` from @acme/http. Why: docs/conventions/api.md#pagination (INC-112)
```

That single line connects Rung 7 (CI check) back to Rung 3 (documentation) and Rung 5 (library). This is what a coherent system looks like.

### Expert Mental Model

> "Documentation is the *explanation layer* of the system, not the enforcement layer. I write docs so people understand why the machine is saying no."

### Common Mistake

Treating documentation as the final step. A 40-page "engineering standards" PDF that nobody reads before coding protects nothing.

---

## 6. Rung 4 — Template

### What

A starting point that already embodies the conventions: repository templates, service skeletons, module generators, PR templates, issue templates, ADR templates, test file templates.

### Why

People **copy what's nearest**. If the nearest example is correct, correctness spreads for free. Templates convert "remember to do X" into "X is already there; delete it if you really don't need it" — flipping the default from opt-in to opt-out.

### How

Templates come in three flavors:

| Flavor | Tooling | Best for |
|---|---|---|
| Repository template | GitHub template repos, `degit`, `create-*` CLI | New projects |
| Code generator | Plop, Hygen, Nx generators, custom scripts | New modules/endpoints/components inside a project |
| Document template | Markdown files in `templates/` | ADRs, PRs, postmortems, design docs |

Example — a Plop generator for a new API resource that bakes in pagination, tenant scoping, validation, and tests:

```js
// plopfile.mjs
export default function (plop) {
  plop.setGenerator('resource', {
    description: 'Tenant-scoped, paginated REST resource',
    prompts: [{ type: 'input', name: 'name', message: 'Resource name (singular, e.g. shipment)' }],
    actions: [
      { type: 'add', path: 'src/modules/{{kebabCase name}}/{{kebabCase name}}.routes.ts',
        templateFile: 'generators/resource/routes.ts.hbs' },
      { type: 'add', path: 'src/modules/{{kebabCase name}}/{{kebabCase name}}.repo.ts',
        templateFile: 'generators/resource/repo.ts.hbs' },
      { type: 'add', path: 'src/modules/{{kebabCase name}}/{{kebabCase name}}.schema.ts',
        templateFile: 'generators/resource/schema.ts.hbs' },
      { type: 'add', path: 'src/modules/{{kebabCase name}}/{{kebabCase name}}.test.ts',
        templateFile: 'generators/resource/test.ts.hbs' },
      { type: 'add', path: 'migrations/{{timestamp}}_create_{{snakeCase name}}s.sql',
        templateFile: 'generators/resource/migration.sql.hbs' },
    ],
  });
  plop.setHelper('timestamp', () => new Date().toISOString().replace(/\D/g, '').slice(0, 14));
}
```

```handlebars
{{!-- generators/resource/routes.ts.hbs --}}
import { router, paginate, requireTenant } from '@acme/http';
import { {{camelCase name}}Repo } from './{{kebabCase name}}.repo';
import { list{{pascalCase name}}Query, create{{pascalCase name}}Body } from './{{kebabCase name}}.schema';

export const {{camelCase name}}Routes = router()
  .use(requireTenant())
  .get('/{{kebabCase name}}s', { query: list{{pascalCase name}}Query }, async (ctx) =>
    paginate(ctx, (page) => {{camelCase name}}Repo.list(ctx.tenant, page)))
  .post('/{{kebabCase name}}s', { body: create{{pascalCase name}}Body, idempotent: true }, async (ctx) =>
    {{camelCase name}}Repo.create(ctx.tenant, ctx.body));
```

```handlebars
{{!-- generators/resource/migration.sql.hbs --}}
CREATE TABLE {{snakeCase name}}s (
  id          uuid PRIMARY KEY DEFAULT uuidv7(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);
CREATE INDEX {{snakeCase name}}s_tenant_created_idx ON {{snakeCase name}}s (tenant_id, created_at DESC, id);
ALTER TABLE {{snakeCase name}}s ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON {{snakeCase name}}s
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

Running `pnpm plop resource shipment` produces an endpoint that is paginated, tenant-scoped, RLS-protected, validated, idempotent on create, indexed for its default sort, and tested — without the author needing to remember any of those conventions.

### Example (React + Next.js)

A Next.js App Router route-segment generator that always emits `loading.tsx`, `error.tsx`, and a server-side auth check, because the team repeatedly shipped pages with blank loading states and client-only auth checks:

```text
pnpm plop page "settings/billing"
  → app/(dashboard)/settings/billing/page.tsx      (server component, calls requireSession())
  → app/(dashboard)/settings/billing/loading.tsx   (skeleton)
  → app/(dashboard)/settings/billing/error.tsx     ('use client' error boundary with reset)
  → app/(dashboard)/settings/billing/page.test.tsx (renders, asserts redirect when signed out)
```

### Expert Mental Model

> "The easiest path must be the correct path. I don't want people to *choose* to paginate; I want them to have to *delete* pagination to avoid it."

### Common Mistake

**Template drift.** Projects generated from `template v1` never get the improvements in `template v7`. Templates are copy-at-creation; without an update mechanism (see §17), each generated project forks. For things that must stay synchronized, climb to Rung 5 (library) instead.

---

## 7. Rung 5 — Library

### What

Shared, versioned code that encapsulates the correct behavior: an HTTP toolkit, a database access layer, a `Money` type, a logger preconfigured with redaction, a retry helper with jitter and budgets, a React form component with accessible error handling.

### Why

Templates copy knowledge **once**; libraries **keep delivering** it. Fix the bug in the library, bump the version, and every consumer gets the fix. Libraries also let you encode knowledge in the **type system**, which is the cheapest always-on enforcement that exists.

### How

Design shared libraries so the correct usage is the only usage that compiles:

```ts
// packages/db/src/tenant-scoped.ts
declare const TenantIdBrand: unique symbol;
export type TenantId = string & { readonly [TenantIdBrand]: true };

/** The ONLY way to get a TenantId: from an authenticated request context. */
export function tenantFromSession(session: VerifiedSession): TenantId {
  return session.tenantId as TenantId;
}

export interface TenantDb {
  readonly tenantId: TenantId;
  query<T>(sql: SqlFragment): Promise<T[]>;
}

/** Opens a transaction with app.tenant_id set, so RLS applies to every statement. */
export async function withTenant<T>(tenantId: TenantId, fn: (db: TenantDb) => Promise<T>): Promise<T> {
  return pool.transaction(async (tx) => {
    await tx.query(sql`SELECT set_config('app.tenant_id', ${tenantId}, true)`);
    return fn({ tenantId, query: (q) => tx.query(q) });
  });
}
```

Now a repository function *cannot* be called without a `TenantId`, and a `TenantId` cannot be fabricated from an arbitrary string without an explicit, greppable, lint-flaggable cast.

Library design rules that matter for knowledge encoding:

| Rule | Why |
|---|---|
| Make the safe option the default, the unsafe option explicit and named (`unsafeRawQuery`) | Unsafe usage becomes greppable and reviewable |
| Encode units and invariants in types (`Money`, `TenantId`, `NonEmptyArray`) | Compiler enforces them on every keystroke |
| Keep the surface small | Large surfaces are misused and hard to evolve |
| Version with SemVer and a changelog | Consumers can upgrade deliberately |
| Ship codemods with breaking changes | Lowers upgrade cost, prevents version sprawl |
| Don't build a library before the third use | Premature abstraction encodes the wrong knowledge (see [15-standardize-vs-flexible.md](15-standardize-vs-flexible.md)) |

### Example

A banking team replaces `amount: number` everywhere with:

```ts
export class Money {
  private constructor(readonly minor: bigint, readonly currency: CurrencyCode) {}
  static of(minor: bigint, currency: CurrencyCode) { return new Money(minor, currency); }
  add(other: Money): Money {
    if (other.currency !== this.currency) throw new CurrencyMismatchError(this.currency, other.currency);
    return new Money(this.minor + other.minor, this.currency);
  }
  allocate(ratios: readonly number[]): Money[] { /* largest-remainder; sums exactly to this.minor */ }
  toJSON() { return { minor: this.minor.toString(), currency: this.currency }; }
}
```

"Don't use floats for money", "don't add different currencies", and "splitting must reconcile to the cent" are no longer things anyone has to remember.

### Expert Mental Model

> "A library is a lesson that executes. The best libraries make the lesson invisible — people get the right behavior without ever learning why."

### Common Mistake

The **god library** — `@company/utils` with 300 unrelated helpers, no owner, and breaking changes shipped in patch versions. It becomes a dependency everyone fears to upgrade, which freezes the knowledge it was meant to spread.

---

## 8. Rung 6 — Automation

### What

Scripts, bots, and tools that **perform** the correct procedure so humans don't: database migration runners, release scripts, dependency update bots (Renovate), secret rotation jobs, preview environment creation, `make bootstrap`, code formatters, schema-to-client code generation, and AI agents executing well-defined skills.

### Why

Procedures with many steps are where humans skip steps. Automation turns a 14-step checklist into one command that never forgets step 11.

### How

Automate when a procedure is **repeated**, **multi-step**, **error-prone**, or **time-sensitive**. Good automation is:

- **Idempotent** — safe to re-run.
- **Observable** — prints what it's doing, fails loudly.
- **Dry-runnable** — `--dry-run` shows the plan.
- **Versioned** — lives in the repo, reviewed like code.

```bash
#!/usr/bin/env bash
# scripts/release.sh — the release procedure, executable
set -euo pipefail

VERSION="${1:?usage: release.sh <version>}"
DRY_RUN="${DRY_RUN:-0}"
run() { echo "+ $*"; [[ "$DRY_RUN" == "1" ]] || "$@"; }

git diff --quiet || { echo "working tree dirty"; exit 1; }
[[ "$(git branch --show-current)" == "main" ]] || { echo "must release from main"; exit 1; }

run pnpm install --frozen-lockfile
run pnpm typecheck
run pnpm test
run pnpm db:migrate:check          # fails if migrations are not backward compatible
run pnpm changeset version
run git commit -am "release: v${VERSION}"
run git tag "v${VERSION}"
run git push origin main --tags     # CI deploys tags to staging, then prod after smoke tests
```

Examples of knowledge encoded as automation:

| Lesson | Automation |
|---|---|
| "We forgot to rotate the webhook secret for 2 years" | Scheduled job rotates secrets every 90 days and alerts on failure |
| "Someone ran migrations against prod from their laptop" | Migrations run only in the deploy pipeline with a dedicated role |
| "Dependency upgrades pile up and become scary" | Renovate groups minor/patch weekly, auto-merges when CI is green |
| "API client drifted from the server" | `openapi-typescript` regenerates the client in CI; diff fails the build |
| "New devs take 2 days to get running" | `pnpm bootstrap` sets up env, DB, seed data, and verifies with a smoke test |

### Expert Mental Model

> "A runbook is a script that hasn't been written yet. Every time I follow a checklist by hand, I ask what it would take to make the checklist execute itself."

### Common Mistake

Automating a process you don't understand yet. Automating a broken process makes it fail faster and more confidently. Do it by hand two or three times, write the runbook, *then* automate.

---

## 9. Rung 7 — CI Check

### What

A static or dynamic check that runs on every change and reports violations: type checking, linters (including custom rules), formatting, dependency audits, secret scanning, migration safety checks, bundle size budgets, OpenAPI breaking-change detection, license checks.

### Why

CI checks are **universal**: they apply to every author, including those who never read the docs, never used the template, and don't know the library exists. They also apply at the cheapest possible moment — before merge.

### How

#### Custom lint rules encode project-specific knowledge

```ts
// tools/eslint-plugin-acme/rules/no-raw-tenant-table-access.ts
import { ESLintUtils } from '@typescript-eslint/utils';

const TENANT_TABLES = new Set(['orders', 'invoices', 'shipments', 'customers']);

export default ESLintUtils.RuleCreator((name) => `https://github.com/acme/eng/docs/rules/${name}.md`)({
  name: 'no-raw-tenant-table-access',
  meta: {
    type: 'problem',
    docs: { description: 'Tenant tables must be accessed through withTenant()' },
    messages: {
      raw: 'Query touches tenant table "{{table}}" outside withTenant(). ' +
           'Use withTenant(tenantId, db => ...). Why: docs/conventions/database.md#tenancy (INC-087)',
    },
    schema: [],
  },
  defaultOptions: [],
  create(context) {
    return {
      TaggedTemplateExpression(node) {
        if (node.tag.type !== 'Identifier' || node.tag.name !== 'sql') return;
        const text = node.quasi.quasis.map((q) => q.value.raw).join(' ').toLowerCase();
        for (const table of TENANT_TABLES) {
          if (!new RegExp(`\\b(from|join|update|into)\\s+${table}\\b`).test(text)) continue;
          const insideWithTenant = context.sourceCode.getAncestors(node).some(
            (a) => a.type === 'CallExpression' && a.callee.type === 'Identifier' && a.callee.name === 'withTenant',
          );
          if (!insideWithTenant) context.report({ node, messageId: 'raw', data: { table } });
        }
      },
    };
  },
});
```

#### Architecture boundary checks

```js
// .dependency-cruiser.cjs — modular monolith boundaries (see 04-architectural-decision-making.md)
module.exports = {
  forbidden: [
    {
      name: 'no-cross-module-internals',
      comment: 'Modules may only import each other via their public index.ts',
      severity: 'error',
      from: { path: '^src/modules/([^/]+)/' },
      to: { path: '^src/modules/([^/]+)/(?!index\\.ts$)', pathNot: '^src/modules/$1/' },
    },
    {
      name: 'domain-has-no-infra',
      severity: 'error',
      from: { path: '^src/modules/[^/]+/domain/' },
      to: { path: '(^src/infra/|node_modules/(pg|@aws-sdk|stripe))' },
    },
  ],
};
```

#### Migration safety checks

```yaml
# .github/workflows/ci.yml (excerpt)
  migration-safety:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Lint new migrations with squawk
        run: |
          FILES=$(git diff --name-only origin/main...HEAD -- 'migrations/*.sql')
          [ -z "$FILES" ] && exit 0
          npx squawk-cli $FILES
        # Catches: adding NOT NULL without default on big tables, non-concurrent index creation,
        # changing column types with table rewrite, dropping columns still read by old code.
```

#### A CI check portfolio (typical expert setup)

| Check | Tool examples | Knowledge encoded |
|---|---|---|
| Types | `tsc --noEmit` | Contracts between modules |
| Lint (generic) | ESLint, `typescript-eslint`, `eslint-plugin-react-hooks` | Language pitfalls |
| Lint (custom) | Local ESLint plugin, Semgrep rules | Project/incident-specific lessons |
| Boundaries | dependency-cruiser, Nx module boundaries | Architecture |
| Format | Prettier / Biome | Style debates (ended) |
| Secrets | gitleaks, GitHub secret scanning | "Never commit credentials" |
| Dependencies | `pnpm audit`, OSV-Scanner, Socket | Supply-chain hygiene ([08-security-engineering.md](08-security-engineering.md)) |
| Migrations | squawk, custom backward-compat check | Zero-downtime deploy rules |
| API contracts | oasdiff, buf breaking | "Don't break clients" |
| Bundle size | size-limit, Next.js bundle analyzer budget | Frontend performance budget ([06-performance-engineering.md](06-performance-engineering.md)) |
| Accessibility | axe via Playwright | WCAG basics |

### Expert Mental Model

> "Review is for judgment; CI is for rules. If a reviewer is leaving the same comment for the third time, that comment should be a lint rule."

### Common Mistake

**Noisy checks.** A rule with 20% false positives gets disabled via `// eslint-disable-next-line` everywhere within a month, and then it encodes nothing. Tune for precision first; require a justification comment for suppressions (`eslint-comments/require-description`).

---

## 10. Rung 8 — Test

### What

Executable specifications that verify behavior: unit, integration, contract, property-based, end-to-end, migration, load, and chaos tests. In the knowledge ladder, the most valuable tests are **regression tests that encode a specific lesson** and **invariant tests that encode a rule that must always hold**.

### Why

Static checks verify *form*. Tests verify *behavior*. Many critical lessons ("a replayed webhook must not double-credit") can only be verified by running code.

### How

#### Encode the incident as a test, named after it

```ts
// src/modules/wallet/webhooks.test.ts
describe('INC-131: provider retries webhook deliveries', () => {
  it('credits the wallet exactly once when the same event is delivered 3 times concurrently', async () => {
    const event = fakeProviderEvent({ type: 'payment.succeeded', amountMinor: 2500n, currency: 'USD' });

    await Promise.all([deliver(event), deliver(event), deliver(event)]);

    const entries = await ledger.entriesFor(event.data.walletId);
    expect(entries).toHaveLength(1);
    expect(await wallet.balance(event.data.walletId)).toEqual(Money.of(2500n, 'USD'));
  });
});
```

#### Encode an invariant as a property-based test

```ts
import fc from 'fast-check';

test('INV-LEDGER-01: allocations always reconcile to the original amount', () => {
  fc.assert(
    fc.property(
      fc.bigInt({ min: 0n, max: 10n ** 12n }),
      fc.array(fc.integer({ min: 1, max: 1000 }), { minLength: 1, maxLength: 20 }),
      (minor, ratios) => {
        const parts = Money.of(minor, 'EUR').allocate(ratios);
        const total = parts.reduce((a, b) => a.add(b));
        expect(total.minor).toBe(minor);
      },
    ),
  );
});
```

#### Encode a cross-cutting rule as a meta-test

Meta-tests inspect the system itself — routes, schemas, migrations — and fail when a rule is violated anywhere, including in code written next year:

```ts
// test/meta/tenant-isolation.meta.test.ts
import { db } from '../helpers/db';

test('CONV-DB-003: every table with tenant_id has RLS enabled and a tenant policy', async () => {
  const rows = await db.query<{ table_name: string; rls: boolean; policies: number }>(sql`
    SELECT c.relname AS table_name,
           c.relrowsecurity AS rls,
           (SELECT count(*) FROM pg_policies p WHERE p.tablename = c.relname)::int AS policies
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
    JOIN information_schema.columns col ON col.table_name = c.relname AND col.column_name = 'tenant_id'
    WHERE c.relkind = 'r'
  `);
  const violations = rows.filter((r) => !r.rls || r.policies === 0).map((r) => r.table_name);
  expect(violations).toEqual([]);
});
```

### Expert Mental Model

> "A bug fix without a test is a bug postponed. A rule without a test is a rule until the next refactor."

### Common Mistake

Writing tests that assert implementation details (mock call counts, private method outputs) instead of the lesson itself. When the implementation is refactored, those tests break for no reason and get deleted — taking the lesson with them. Test the *outcome* the lesson protects.

---

## 11. Rung 9 — Quality Gate

### What

A **policy** that blocks progression — merge, deploy, release, or promotion — unless defined criteria are met. Gates turn checks and tests from "information" into "requirements".

### Why

A CI check that can be merged over while red is advisory. A gate makes the system's knowledge **non-negotiable by default**, with explicit, auditable override when truly necessary.

### How

Gates exist at several points:

```text
 Commit ─► PR ─► Merge ─► Build ─► Staging ─► Production ─► Post-deploy
   │        │      │        │         │           │              │
 pre-commit │   branch    artifact  smoke +     progressive     SLO/error-budget
 hooks      │   protection signing  e2e tests   rollout gates   auto-rollback
         PR template,
         CODEOWNERS review
```

#### Merge gate (GitHub branch protection / rulesets)

```jsonc
// Applied via `gh api` or Terraform (github_repository_ruleset)
{
  "name": "main-protection",
  "target": "branch",
  "conditions": { "ref_name": { "include": ["refs/heads/main"] } },
  "rules": [
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "typecheck" }, { "context": "lint" }, { "context": "test" },
          { "context": "migration-safety" }, { "context": "meta-tests" }, { "context": "gitleaks" } ] } },
    { "type": "non_fast_forward" }
  ]
}
```

#### CODEOWNERS as a knowledge gate

```text
# .github/CODEOWNERS — changes to sensitive areas require the people who hold that knowledge
/migrations/                      @acme/data-platform
/packages/db/src/tenant-scoped.ts @acme/security
/src/modules/payments/            @acme/payments
/.github/workflows/               @acme/platform
```

For a solo developer, CODEOWNERS is irrelevant, but the equivalent gate is a **self-review checklist enforced by the PR template** plus required checks (see [11-solo-developer-multiple-projects.md](11-solo-developer-multiple-projects.md)).

#### Deploy gate with automatic rollback

```yaml
# deploy/rollout.yaml (Argo Rollouts-style canary with analysis)
strategy:
  canary:
    steps:
      - setWeight: 5
      - pause: { duration: 10m }
      - analysis:
          templates: [{ templateName: http-error-rate }, { templateName: p95-latency }]
      - setWeight: 50
      - pause: { duration: 10m }
      - analysis:
          templates: [{ templateName: http-error-rate }, { templateName: p95-latency }]
---
kind: AnalysisTemplate
metadata: { name: http-error-rate }
spec:
  metrics:
    - name: error-rate
      interval: 1m
      failureLimit: 2
      successCondition: result[0] < 0.01
      provider:
        prometheus:
          query: |
            sum(rate(http_requests_total{app="api",status=~"5..",track="canary"}[2m]))
            / sum(rate(http_requests_total{app="api",track="canary"}[2m]))
```

#### Override policy

Gates need an escape hatch, or people will route around the whole system:

```markdown
## Gate override policy
- Who: repo admins only.
- When: active incident mitigation, or false-positive check blocking a critical fix.
- How: label PR `gate-override`, write the reason in the PR body, link the incident.
- After: within 2 business days, open an issue to fix the check or add the missing test.
- Audit: weekly report of overridden merges (GitHub audit log query).
```

### Expert Mental Model

> "A gate is where the organization says: this knowledge is no longer optional. I place gates only where the cost of failure is high enough to justify slowing everyone down."

### Common Mistake

Gating on vanity metrics — "coverage must be ≥ 90%" — produces tests that execute lines without asserting anything. Gate on checks that directly encode important knowledge, and on *coverage of critical modules* rather than a global number (see [05-quality-engineering.md](05-quality-engineering.md)).

---

## 12. When to Climb: The Economics of Encoding

### What

Deciding **how high** a given lesson should go. Not every lesson deserves a lint rule; some deserve only a sentence in `AGENTS.md`.

### Why

Every rung has a build cost and an ongoing maintenance cost. Over-encoding creates bureaucracy, slow CI, false positives, and brittle tooling. Under-encoding creates repeated incidents.

### How

#### The core formula

```text
Expected cost of NOT encoding (per period)
  = frequency of the situation
  × probability a human gets it wrong
  × cost of the error (including detection delay and blast radius)

Encode at rung R if:
  expected cost avoided by R  >  build cost of R + maintenance cost of R + friction cost of R
```

You rarely compute this numerically, but thinking in these terms prevents both extremes.

#### The rule of three

```text
1st time  → do it, capture the lesson (Rung 1)
2nd time  → notice the repetition, write the convention/doc (Rungs 2–3)
3rd time  → template, library, or automation (Rungs 4–6)
Incident  → skip the counting; go straight to a check/test/gate for that failure (Rungs 7–9)
```

#### The decision matrix

| | **Low cost of error** (cosmetic, easy rework) | **Medium** (bugs, rework days) | **High** (data loss, security, money, compliance) |
|---|---|---|---|
| **Rare** (monthly or less) | Knowledge / doc | Doc + checklist | Test + gate, or design it out |
| **Occasional** (weekly) | Convention | Template or library | Library + CI check + test |
| **Frequent** (daily) | Formatter / autofix | Library + lint rule | Type system + DB constraint + test + gate |

#### Cost of each rung

| Rung | Build cost | Maintenance cost | Friction for developers | Enforcement strength |
|---|---|---|---|---|
| Knowledge | ~0 | ~0 | 0 | None |
| Convention | Minutes | Low | Low | Social |
| Documentation | Hours | Medium (goes stale) | Low | Weak |
| Template | Hours–days | Medium (drift) | Negative (saves time) | Medium at creation, zero after |
| Library | Days–weeks | High (versioning, bugs, support) | Negative if good, high if bad | Strong where used |
| Automation | Hours–days | Medium (breaks with env changes) | Negative | Strong where run |
| CI check | Hours–days | Medium (false positives, perf) | Low–medium | Strong, universal |
| Test | Hours | Medium (flakiness) | Low | Strong for covered scenarios |
| Quality gate | Minutes to configure | Low–medium (override policy) | Medium–high | Strongest |

#### Prefer "design it out" when possible

The best encoding is often **not a check at all**, but making the wrong thing unrepresentable:

| Instead of... | Design it out with... |
|---|---|
| Lint rule "don't forget tenant filter" | Row-Level Security + `withTenant()` as the only DB accessor |
| Test "status transitions are legal" | State machine type where illegal transitions don't compile, plus DB check/trigger |
| Doc "don't store money as float" | `Money` class + `bigint` columns + `CHECK (amount_minor >= 0)` |
| Review comment "handle null user" | `strictNullChecks` + parsing at the boundary with Zod |
| Checklist "remember to add index" | Generator creates the index with the table |

### Example

A developer-tools SaaS decides what to do with three lessons:

1. *"Button labels should be sentence case."* Frequent, cosmetic. → Convention in the design system docs; no gate. Maybe a Storybook review.
2. *"Server Actions in Next.js must re-check authorization; the UI hiding a button is not security."* Occasional, high cost. → Library (`authorizedAction(permission, handler)` wrapper), custom lint rule forbidding exported `'use server'` functions not wrapped by it, integration test calling each action unauthenticated, merge gate.
3. *"The CSV import for the Acme customer has quirky encoding."* Rare, medium, single-customer. → Documented in the import module's README and a fixture-based test. No library.

### Expert Mental Model

> "I climb the ladder in proportion to frequency × blast radius. I prefer designs where the mistake is impossible over checks that detect it, and checks that detect it over docs that describe it."

### Common Mistake

Building a heavy platform (custom generators, internal CLI, 40 lint rules) before there is enough repetition to justify it — encoding guesses instead of lessons.

---

## 13. Worked Trace #1: "Every tenant query must filter by tenant_id"

This trace follows one lesson up the entire ladder in a multi-tenant B2B SaaS (think: a logistics platform where each shipper is a tenant).

### Rung 1 — Knowledge (the incident)

```text
INC-087 (2026-02-11): A customer support engineer at Tenant A saw 3 shipments belonging to
Tenant B in the "Recent exceptions" widget. Root cause: a new query for the widget joined
shipments → exceptions and filtered exceptions.tenant_id but not shipments.tenant_id.
Exposure: 3 records, 1 tenant, 26 minutes. Reported by the customer.
```

The senior engineer who fixes it now *knows*: every table in a join needs tenant filtering.

### Rung 2 — Convention

```markdown
### CONV-DB-003: Tenant isolation
- Every table containing tenant-owned data has `tenant_id uuid NOT NULL`.
- Every query against such a table is tenant-scoped, including every table in a JOIN.
- Why: INC-087.
```

### Rung 3 — Documentation

`docs/conventions/database.md#tenancy` explains the model, shows correct and incorrect SQL, and `ARCHITECTURE.md` lists tenant isolation as invariant `INV-SEC-01` in the invariant register ([templates/invariant-register.md](templates/invariant-register.md)). `AGENTS.md` gets one line:

```markdown
- All DB access to tenant tables goes through `withTenant()` from `@acme/db`. Never write raw SQL
  against tenant tables outside it. See docs/conventions/database.md#tenancy.
```

### Rung 4 — Template

The resource generator (see §6) creates every new table with `tenant_id`, a tenant-leading composite index, RLS enabled, and a tenant policy.

### Rung 5 — Library

`withTenant()` and the branded `TenantId` type (see §7). Repositories accept a `TenantDb`, never a raw pool.

### Rung 5b — Design it out at the database

```sql
-- migrations/20260214_enable_rls_for_tenant_tables.sql
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments FORCE ROW LEVEL SECURITY;   -- applies even to table owner
CREATE POLICY tenant_isolation ON shipments
  USING (tenant_id = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid);

-- The application role is NOT a superuser and does NOT have BYPASSRLS.
ALTER ROLE app_user NOBYPASSRLS;
```

Now, even if application code forgets a filter, the database returns zero foreign rows. Missing `app.tenant_id` yields `NULL`, which matches nothing — failing closed.

### Rung 6 — Automation

- A codegen script regenerates `TENANT_TABLES` for the lint rule from the live schema (`information_schema.columns WHERE column_name = 'tenant_id'`), so the rule never goes stale.
- The migration runner refuses to apply a migration that creates a table with `tenant_id` but without RLS.

```ts
// scripts/check-migration-rls.ts — run by `pnpm db:migrate`
const created = parseCreateTables(migrationSql);           // tables created in this migration
for (const t of created.filter((t) => t.columns.includes('tenant_id'))) {
  if (!new RegExp(`ALTER TABLE ${t.name} ENABLE ROW LEVEL SECURITY`, 'i').test(migrationSql)) {
    throw new Error(`Migration creates tenant table "${t.name}" without RLS. See CONV-DB-003.`);
  }
}
```

### Rung 7 — CI Check

The `no-raw-tenant-table-access` ESLint rule (see §9), plus a Semgrep rule for code paths ESLint misses:

```yaml
# .semgrep/tenant.yml
rules:
  - id: pool-query-outside-tenant-scope
    languages: [typescript]
    severity: ERROR
    message: Direct pool.query() bypasses withTenant(); tenant isolation (CONV-DB-003) is not guaranteed.
    patterns:
      - pattern: $POOL.query(...)
      - metavariable-regex: { metavariable: $POOL, regex: '^(pool|db|pg)$' }
      - pattern-not-inside: withTenant(...)
    paths:
      exclude: [packages/db/src/**, migrations/**, scripts/admin/**]
```

### Rung 8 — Test

1. The meta-test asserting RLS on every tenant table (see §10).
2. A cross-tenant integration test harness that runs for **every** list/read endpoint automatically:

```ts
// test/meta/cross-tenant-read.meta.test.ts
import { allRoutes } from '../../src/http/registry';

const readRoutes = allRoutes().filter((r) => r.method === 'GET' && r.tenantScoped);

describe.each(readRoutes)('INV-SEC-01 cross-tenant isolation: GET $path', (route) => {
  it('never returns resources owned by another tenant', async () => {
    const { tenantA, tenantB } = await seedTwoTenantsWithFullFixtures();
    const res = await request(app).get(route.examplePath(tenantB.fixtures)).set(authAs(tenantA.user));
    const leaked = collectIds(res.body).filter((id) => tenantB.ownedIds.has(id));
    expect(leaked).toEqual([]);
  });
});
```

Because this test iterates over the route registry, **new endpoints are covered without anyone writing a new test**.

### Rung 9 — Quality Gate

- `lint`, `semgrep`, `meta-tests` are required status checks on `main`.
- `packages/db/**` and `migrations/**` require security-owner review (or, for a solo developer, a mandatory checklist item in the PR template).
- A production **detective control**: a nightly job samples API access logs and verifies `response.tenant_id == session.tenant_id`; mismatches page someone.

### Result

| Before INC-087 | After |
|---|---|
| Isolation depends on every developer writing correct joins forever | Isolation enforced by DB policy, type system, lint, Semgrep, meta-tests, auto-covering endpoint tests, merge gate, and production detection |
| New developer or AI agent can reintroduce the bug in one PR | Reintroduction requires bypassing ≥ 4 independent controls |

---

## 14. Worked Trace #2: "Always paginate list endpoints"

Domain: e-commerce back office. Incident: `GET /admin/orders` returned 1.8 M rows for a large merchant, the Node process hit its memory limit, the pod OOM-looped, and the admin was down for 40 minutes.

| Rung | Artifact |
|---|---|
| Knowledge | "Unbounded lists kill the API process." |
| Convention | `CONV-API-007` (see §4) |
| Documentation | `docs/conventions/api.md#pagination` with cursor format, sort stability rules (`ORDER BY created_at DESC, id DESC`), max limits |
| Template | Resource generator emits paginated `list` handler and `(tenant_id, created_at DESC, id)` index |
| Library | `paginate()` helper + `Page<T>` type |
| Automation | OpenAPI generator adds `limit`/`cursor` params to every collection response schema |
| CI check | Custom ESLint rule `api/require-pagination`; OpenAPI lint (Spectral) rule |
| Test | Meta-test: every GET route returning an array rejects `limit=10000` and returns ≤ 200 items |
| Gate | Required checks; runtime guard in production |

### Library

```ts
// packages/http/src/paginate.ts
export interface Page<T> { data: T[]; nextCursor: string | null }
export interface PageRequest { limit: number; after?: { createdAt: string; id: string } }

const MAX_LIMIT = 200;
const DEFAULT_LIMIT = 50;

export async function paginate<T extends { id: string; createdAt: Date }>(
  ctx: RequestContext,
  fetch: (page: PageRequest) => Promise<T[]>,
): Promise<Page<T>> {
  const limit = Math.min(Number(ctx.query.limit ?? DEFAULT_LIMIT), MAX_LIMIT);
  if (!Number.isInteger(limit) || limit < 1) throw new ValidationError('limit must be 1..200');
  const after = ctx.query.cursor ? decodeCursor(String(ctx.query.cursor)) : undefined;

  const rows = await fetch({ limit: limit + 1, after });        // fetch one extra to detect next page
  const hasMore = rows.length > limit;
  const data = hasMore ? rows.slice(0, limit) : rows;
  const last = data.at(-1);
  return { data, nextCursor: hasMore && last ? encodeCursor({ createdAt: last.createdAt.toISOString(), id: last.id }) : null };
}
```

```sql
-- Keyset query the repository uses; stable under concurrent inserts, O(limit) with the index
SELECT id, created_at, status, total_minor
FROM orders
WHERE tenant_id = $1
  AND ($2::timestamptz IS NULL OR (created_at, id) < ($2::timestamptz, $3::uuid))
ORDER BY created_at DESC, id DESC
LIMIT $4;
```

### Spectral rule for the OpenAPI spec

```yaml
# .spectral.yaml
rules:
  collection-must-paginate:
    description: Array responses must be wrapped in { data, nextCursor } and accept limit/cursor.
    severity: error
    given: "$.paths[*].get.responses['200'].content['application/json'].schema"
    then:
      - field: type
        function: pattern
        functionOptions: { notMatch: "^array$" }
```

### Runtime guard (defense in depth)

```ts
// packages/http/src/middleware/response-size-guard.ts
export const responseSizeGuard = (maxItems = 500) => (ctx, next) =>
  next().then(() => {
    if (Array.isArray(ctx.body) || (Array.isArray(ctx.body?.data) && ctx.body.data.length > maxItems)) {
      logger.error({ route: ctx.routePath, size: ctx.body?.data?.length ?? ctx.body.length }, 'unpaginated response');
      metrics.increment('api.unpaginated_response', { route: ctx.routePath });
      if (process.env.NODE_ENV !== 'production') throw new Error(`Unpaginated response on ${ctx.routePath}`);
    }
  });
```

Note the progression: in dev/test the guard **fails**; in production it **alerts** rather than breaking customers. That distinction is itself encoded knowledge.

### React + Next.js consumer side

```tsx
// app/(admin)/orders/page.tsx — server component uses the same contract
import { listOrders } from '@/lib/api/orders';
import { OrdersTable } from './orders-table';

export default async function OrdersPage({ searchParams }: { searchParams: Promise<{ cursor?: string }> }) {
  const { cursor } = await searchParams;
  const page = await listOrders({ limit: 50, cursor });
  return <OrdersTable rows={page.data} nextCursor={page.nextCursor} />;
}
```

The generated API client's type is `Page<Order>`; a component literally cannot treat the response as a bare array.

---

## 15. Worked Trace #3: "Money is never a float"

Domain: marketplace payouts. Incident: seller payouts computed with `0.1 + 0.2`-style float arithmetic across 12,000 line items drifted by $0.03 from the ledger; finance reconciliation failed and payouts were held for 2 days.

```text
Knowledge     "Floats can't represent currency exactly."
Convention    CONV-MONEY-001: amounts are integer minor units + ISO currency code.
Documentation docs/conventions/money.md: rounding mode (banker's vs half-up per jurisdiction),
              allocation algorithm, FX conversion rules, display formatting via Intl.NumberFormat.
Template      Migration template column pair: amount_minor bigint NOT NULL, currency char(3) NOT NULL.
Library       Money class (see §7); formatMoney() for React; Zod schema moneySchema.
Automation    Codegen of DB types maps bigint → bigint (not number).
CI check      ESLint no-restricted-syntax: forbid identifiers /amount|price|total/i typed as number
              in src/modules/{billing,payouts,ledger}; forbid parseFloat in those modules.
Test          fast-check properties: allocation sums, add/subtract associativity, currency mismatch throws.
DB constraint CHECK (currency ~ '^[A-Z]{3}$'); CHECK (amount_minor >= 0) where applicable;
              nightly reconciliation query: SUM(entries) per account = balance.
Quality gate  Required checks; reconciliation job failing blocks the payout batch (runtime gate).
```

```js
// eslint.config.mjs (excerpt)
{
  files: ['src/modules/{billing,payouts,ledger}/**/*.ts'],
  rules: {
    'no-restricted-globals': ['error', { name: 'parseFloat', message: 'Use Money.parse(). CONV-MONEY-001' }],
    'no-restricted-syntax': ['error', {
      selector: "TSPropertySignature[key.name=/^(amount|price|total|fee|subtotal)$/i] > TSTypeAnnotation > TSNumberKeyword",
      message: 'Monetary fields must be Money, not number. CONV-MONEY-001',
    }],
  },
}
```

```sql
-- Runtime gate: payout batch refuses to run if ledger doesn't reconcile
CREATE OR REPLACE FUNCTION assert_ledger_reconciles(p_batch uuid) RETURNS void AS $$
DECLARE v_diff bigint;
BEGIN
  SELECT COALESCE(SUM(e.amount_minor), 0) - (SELECT total_minor FROM payout_batches WHERE id = p_batch)
    INTO v_diff
  FROM ledger_entries e WHERE e.payout_batch_id = p_batch;
  IF v_diff <> 0 THEN
    RAISE EXCEPTION 'Payout batch % does not reconcile (diff % minor units)', p_batch, v_diff
      USING ERRCODE = 'check_violation';
  END IF;
END $$ LANGUAGE plpgsql;
```

---

## 16. The Incident → Postmortem → Guardrail Loop

### What

The operational engine that feeds the ladder: every incident, near-miss, escaped bug, or painful review produces at least one **guardrail** — an artifact on some rung that prevents recurrence of that *class* of failure.

### Why

Incidents are the most expensive lessons you'll ever pay for. Organizations that fix the instance but not the class pay for the same lesson repeatedly. Elite teams measure themselves partly by **how rarely the same class of incident recurs**.

### How

```text
┌──────────┐   ┌───────────┐   ┌─────────────┐   ┌───────────────┐   ┌───────────────┐
│ Incident │──►│ Mitigate  │──►│ Postmortem  │──►│ Guardrail(s)  │──►│ Verify & share│
│ /near    │   │ (stop the │   │ (blameless, │   │ (class-level, │   │ (test proves  │
│  miss    │   │  bleeding)│   │  causes)    │   │  on a rung)   │   │  it catches)  │
└──────────┘   └───────────┘   └─────────────┘   └───────────────┘   └───────┬───────┘
      ▲                                                                      │
      └──────────────────── fewer recurrences, faster detection ◄────────────┘
```

#### Step 1: Mitigate

Restore service first. Capture a timeline while it's fresh (timestamps, commands run, dashboards seen).

#### Step 2: Blameless postmortem

Use [templates/postmortem.md](templates/postmortem.md). The key section is **contributing factors**, framed as *system* questions, not person questions:

| Blameful question | Systemic question |
|---|---|
| Who forgot the tenant filter? | Why was it *possible* to write a query without a tenant filter? |
| Why didn't the reviewer catch it? | Why did detection depend on a human reviewer noticing one line? |
| Why did they deploy on Friday? | Why didn't the deploy process detect elevated errors and roll back? |
| Why didn't they read the docs? | Why wasn't the rule surfaced at the moment the code was written? |

#### Step 3: Generate guardrails at the class level

For each contributing factor, ask the **five guardrail questions**:

```text
1. PREVENT   — Can we make this impossible?              (type, library, DB constraint, permission)
2. DETECT    — Can we catch it before merge?             (lint, test, CI check)
3. CONTAIN   — Can we limit blast radius if it ships?    (feature flag, canary, RLS, rate limit)
4. ALERT     — Can we notice it in production faster?    (SLO alert, anomaly detection, audit job)
5. RECOVER   — Can we restore faster next time?          (runbook, automated rollback, backfill script)
```

#### Step 4: Verify the guardrail works

A guardrail you haven't seen fail is unverified. Reintroduce the original bug on a branch and confirm the guardrail catches it:

```bash
git checkout -b verify/INC-087-guardrail
git revert --no-commit <fix-sha>         # reintroduce the original bug
pnpm lint && pnpm test:meta              # expect: FAIL with CONV-DB-003 messages
git checkout main && git branch -D verify/INC-087-guardrail
```

Record the verification in the postmortem ("Guardrail verified: lint + meta-test fail on reintroduced bug, 2026-02-15").

#### Step 5: Track action items to completion

Postmortem action items rot faster than any other backlog. Treat them as first-class:

```markdown
| ID | Guardrail | Rung | Type | Owner | Due | Status | Verified |
|----|-----------|------|------|-------|-----|--------|----------|
| INC-087-A1 | RLS on all tenant tables | Design-out | Prevent | data | 02-18 | Done | ✅ 02-19 |
| INC-087-A2 | ESLint no-raw-tenant-table-access | CI check | Detect | platform | 02-20 | Done | ✅ 02-20 |
| INC-087-A3 | Cross-tenant meta-test for all GET routes | Test | Detect | platform | 02-25 | Done | ✅ 02-26 |
| INC-087-A4 | Nightly tenant-mismatch log audit | Monitoring | Alert | security | 03-05 | In progress | — |
```

#### Near-misses count

A PR comment that says "whoa, this would have leaked tenant data" is a free incident. Treat near-misses and repeated review comments as inputs to the same loop.

### Example: repeated review comments as a signal

```bash
# Mine your own PR review comments for repeated feedback (GitHub CLI)
gh api --paginate "repos/acme/app/pulls/comments?per_page=100" \
  --jq '.[].body' | tr 'A-Z' 'a-z' | grep -oE 'use (paginate|withtenant|money)|missing (index|loading state|error boundary)' \
  | sort | uniq -c | sort -rn
```

```text
  23 missing error boundary
  17 use withtenant
   9 missing loading state
```

Twenty-three identical review comments is a generator or lint rule waiting to be written.

### Expert Mental Model

> "An incident is only 'closed' when the class of failure is guarded, the guardrail has been proven to catch it, and the lesson is findable by someone who wasn't there."

### Common Mistake

Action items like "be more careful", "add more tests", or "improve monitoring". These are not guardrails; they're intentions. A guardrail names a specific artifact on a specific rung that a reviewer can verify exists.

---

## 17. Keeping the System From Rotting

### What

The systems you build to encode knowledge are themselves software. They have bugs, go stale, accumulate false positives, and outlive their reasons. Without maintenance, they become a burden that people bypass — and a bypassed system is worse than none because it creates false confidence.

### Why

Common rot patterns:

| Rot | Symptom | Consequence |
|---|---|---|
| Stale docs | Docs describe the architecture from two years ago | People stop trusting all docs |
| Template drift | 7 projects on 5 different template versions | Fixes don't propagate; each project is a snowflake |
| Library version sprawl | Consumers pinned to v2, v3, v5 of `@acme/http` | Security fixes need 3 backports |
| Noisy checks | `eslint-disable` count grows monthly | Rule effectively disabled |
| Flaky tests | CI re-run culture | Real failures ignored |
| Orphaned automation | Cron job nobody owns fails silently | Secrets unrotated, backups untested |
| Obsolete rules | Rule exists for a system that was removed | Friction without benefit |

### How

#### 1. Ownership

Every artifact has an owner — a person for a solo dev (you, with a review date), a team for an organization.

```yaml
# eng-os/registry/guardrails.yaml — a registry of the knowledge system itself
- id: CONV-DB-003
  title: Tenant isolation
  owner: security
  origin: INC-087
  artifacts:
    - docs/conventions/database.md#tenancy
    - packages/db/src/tenant-scoped.ts
    - tools/eslint-plugin-acme/rules/no-raw-tenant-table-access.ts
    - test/meta/cross-tenant-read.meta.test.ts
  last_reviewed: 2026-08-01
  review_every: 6 months
  status: active
- id: CONV-FE-011
  title: Class components must implement getSnapshotBeforeUpdate for scroll restoration
  owner: frontend
  origin: INC-042
  last_reviewed: 2024-03-10
  status: deprecated   # superseded — codebase is fully function components
  removal_date: 2026-10-01
```

A scheduled CI job fails (or opens an issue) when `last_reviewed + review_every` is in the past.

#### 2. Versioning of shared libraries

- **SemVer strictly.** Breaking change → major. Use Changesets to force a changelog entry per PR.
- **Support window.** "We support the current and previous major; older majors get security fixes for 6 months."
- **Codemods for breaking changes** so upgrades are cheap:

```ts
// codemods/http-v4-to-v5/paginate-signature.ts (jscodeshift)
export default function transform(file, api) {
  const j = api.jscodeshift;
  return j(file.source)
    .find(j.CallExpression, { callee: { name: 'paginate' } })
    .filter((p) => p.node.arguments.length === 3)          // v4: paginate(ctx, fetch, opts)
    .forEach((p) => {
      const [ctx, fetch, opts] = p.node.arguments;
      p.node.arguments = [j.objectExpression([             // v5: paginate({ ctx, fetch, ...opts })
        j.property('init', j.identifier('ctx'), ctx),
        j.property('init', j.identifier('fetch'), fetch),
        j.spreadElement(opts),
      ])];
    })
    .toSource();
}
```

- **Automated upgrade PRs** (Renovate) across all consuming repos, grouped per library, so no repo silently falls behind.
- **Fleet visibility**: a script that reports which version of each shared package every repo uses.

```bash
# eng-os/scripts/fleet-versions.sh
for repo in ~/code/{shipfast,ledgerly,wms-core,devhooks,storefront}; do
  printf "%-12s " "$(basename "$repo")"
  jq -r '[.dependencies["@acme/http"], .dependencies["@acme/db"], .devDependencies["@acme/eslint-config"]] | @tsv' \
    "$repo/package.json"
done
```

#### 3. Template updates that propagate

Options, from simplest to most robust:

| Mechanism | How it works | Trade-off |
|---|---|---|
| Manual diff | Periodically diff project against template | Doesn't scale past 2–3 projects |
| Copier / Cruft | Template tool records template version; `copier update` applies a 3-way merge | Needs discipline to run updates |
| Move shared parts to packages | CI config, lint config, tsconfig become versioned packages | Best for things that must stay synced |
| Reusable workflows | GitHub Actions `workflow_call` referenced by tag | CI logic lives in one place |

Rule of thumb: **templates for the parts that should diverge, packages for the parts that should stay in sync.**

#### 4. Deprecation process

```text
1. Mark deprecated (registry status, @deprecated JSDoc, lint warning — not error)
2. Announce with migration path and removal date
3. Provide codemod or automated PRs
4. Track remaining usages (grep/dashboard) to zero
5. Remove, and remove the guardrail if the risk no longer exists
```

```ts
/** @deprecated since @acme/db 6.0 — use withTenant(). Removal in 7.0 (2026-12). See docs/migrations/db-7.md */
export function scopedQuery(/* ... */) { /* ... */ }
```

#### 5. Measure the health of the system itself

| Metric | Healthy signal |
|---|---|
| Suppression count per rule (`eslint-disable` with rule name) | Flat or decreasing |
| Flaky test rate | < 1% of runs; each flaky test has an issue |
| Median CI duration | Stable; budget e.g. < 10 min for PR checks |
| Repos on latest major of shared libs | > 80% |
| Guardrails past review date | 0 |
| Gate overrides per month | Low, each justified |
| Recurrence of incident classes | Trending to zero |

#### 6. Prune

Once or twice a year, walk the guardrail registry and ask for each item: *Does the risk still exist? Is this the cheapest effective rung? Is it producing false positives?* Delete what no longer earns its keep. Removing obsolete rules builds trust in the ones that remain.

### Expert Mental Model

> "My guardrails are a product with users — me, my future self, teammates, and AI agents. Products need owners, versions, changelogs, deprecations, and pruning. Otherwise they become the legacy system everyone works around."

### Common Mistake

Only ever adding rules. A system that grows monotonically eventually drowns in friction, and people start disabling rules wholesale — destroying the important ones along with the obsolete ones.

---

## 18. Poka-Yoke: Designing Mistakes Out

### What

*Poka-yoke* (Japanese: "mistake-proofing") comes from the Toyota Production System: design processes so errors are impossible or immediately obvious. It is the philosophical top of the knowledge ladder.

### Why

Every rung below "design it out" still permits the mistake and relies on catching it. Mistake-proofing removes the category.

### How — a catalogue of software poka-yoke techniques

| Technique | Example |
|---|---|
| Branded/nominal types | `TenantId`, `UserId`, `OrderId` can't be swapped accidentally |
| Parse, don't validate | Zod parses request into a typed object at the boundary; inner code never sees raw input |
| Make illegal states unrepresentable | Discriminated union `{ status: 'shipped'; trackingNo: string } | { status: 'pending' }` |
| Database constraints | `UNIQUE (tenant_id, sku)`, `CHECK (quantity_allocated <= quantity_on_hand)`, FKs, exclusion constraints |
| Capability-scoped handles | Repositories receive a `TenantDb`, not a pool |
| Least-privilege roles | App DB role cannot `DROP`, cannot `BYPASSRLS`; CI deploy role can't read prod data |
| Safe defaults with explicit unsafe escape | `html` template escapes; `dangerouslySetInnerHTML` is loudly named |
| Required-by-construction config | Config schema parsed at boot; app refuses to start if `DATABASE_URL` missing |
| Idempotency at the boundary | Middleware rejects POSTs to money-moving endpoints without `Idempotency-Key` |
| Framework-level server boundaries | Next.js `server-only` package import makes secrets modules fail to build if imported client-side |

```ts
// lib/env.server.ts — Next.js: config that cannot leak to the client and cannot be missing
import 'server-only';
import { z } from 'zod';

export const env = z.object({
  DATABASE_URL: z.string().url(),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  NEXT_PUBLIC_APP_URL: z.string().url(),
}).parse(process.env);
```

```ts
// Illegal WMS states unrepresentable
type Allocation =
  | { state: 'reserved'; orderId: OrderId; binId: BinId; qty: PositiveInt; reservedAt: Date }
  | { state: 'picked'; orderId: OrderId; binId: BinId; qty: PositiveInt; pickedBy: UserId; pickedAt: Date }
  | { state: 'released'; orderId: OrderId; releasedAt: Date; reason: 'cancelled' | 'expired' };
// A 'picked' allocation without pickedBy is a compile error, not a runtime surprise.
```

### Expert Mental Model

> "Before I write a check for a mistake, I ask whether I can change the shape of the system so the mistake can't be expressed."

### Common Mistake

Over-applying type gymnastics where the cost of error is low, making ordinary code painful to write. Reserve heavy mistake-proofing for invariants listed in the invariant register ([09-invariants-and-correctness.md](09-invariants-and-correctness.md)).

---

## 19. Amateur vs Professional vs Expert

| Dimension | Amateur | Professional | Expert |
|---|---|---|---|
| Where lessons live | Head, chat | Wiki, PR comments | Types, libraries, checks, tests, gates — with docs explaining why |
| Response to a bug | Fix the line | Fix + regression test | Fix + test + guardrail for the *class* + verify guardrail catches it |
| Repeated review comments | Keep leaving them | Add to review checklist | Convert to lint rule/generator; retire the comment |
| New project setup | Copy last project, delete stuff | Use a template | Template for divergent parts, versioned packages for shared parts, update mechanism |
| Shared code | Copy-paste | `utils` package | Small, owned, versioned libraries with codemods and support windows |
| CI | Build + tests | Lint, types, tests, audit | Plus custom rules, boundary checks, migration safety, meta-tests, budgets |
| Gates | None, or "don't merge if red" (by honor) | Branch protection | Branch protection + deploy analysis + auto rollback + audited override policy |
| Postmortems | None or blameful | Blameless doc, action items | Class-level guardrails on explicit rungs, verified, tracked to done, recurrence measured |
| System maintenance | Never | When it breaks | Registry with owners, review dates, deprecation, pruning, health metrics |
| AI agents | Paste code into chat | Agent writes code, human reviews | Agents constrained by AGENTS.md, skills, generators, and the same CI gates as humans (see [13-ai-and-agents.md](13-ai-and-agents.md)) |

### How to recognize the difference in a codebase within 30 minutes

```text
□ Is there a generator or template for the most common unit of work (endpoint, page, table)?
□ Do lint error messages link to a doc or incident?
□ Are there tests named after incidents or invariants (INC-xxx, INV-xxx)?
□ Are there meta-tests that iterate over routes/tables/components?
□ Does the DB schema enforce the most important invariants (constraints, RLS)?
□ Are shared configs (eslint, tsconfig, CI) versioned packages or reusable workflows?
□ Does main have required checks, and are overrides rare and justified?
□ Is there a list of past incidents with linked guardrails?
```

Zero or one checked: amateur. Three to five: professional. Seven or more, *and they're maintained*: expert.

---

## 20. Common Mistakes

| Mistake | Why it hurts | Better approach |
|---|---|---|
| "Fixed" = wrote a doc | Docs don't enforce | Climb to the cheapest rung that actually prevents/detects |
| Encoding everything at the top rung | Friction, slow CI, bypass culture | Match rung to frequency × cost |
| Premature libraries | Encodes guesses; wrong abstraction spreads | Rule of three; extract from real repetition |
| Templates for things that must stay in sync | Drift across projects | Versioned packages / reusable workflows |
| Lint rules with false positives | Suppressions everywhere | Precision over recall; require suppression reasons |
| Tests coupled to implementation | Deleted during refactors, lesson lost | Test outcomes and invariants |
| Unverified guardrails | False confidence | Reintroduce the bug and confirm it's caught |
| Action items without owners/dates | Never done | Track guardrails like product work |
| Never removing rules | Friction accumulates | Registry + review dates + pruning |
| Gates without override policy | People bypass the whole system under pressure | Explicit, audited override |
| Blameful postmortems | People hide near-misses; you lose free lessons | Blameless, system-focused questions |
| Building an internal platform before having products | No real lessons to encode | Encode lessons as they arrive (see [12-engineering-operating-system.md](12-engineering-operating-system.md)) |

---

## Key Takeaways

1. **Memory is not a control.** Anything important that depends on someone remembering will eventually fail.
2. **The knowledge ladder** — Knowledge → Convention → Documentation → Template → Library → Automation → CI Check → Test → Quality Gate — moves responsibility for correctness from people to systems.
3. **Rungs stack.** Critical invariants live on multiple rungs at once; docs explain, libraries enable, checks detect, tests prove, gates enforce.
4. **Climb in proportion to frequency × cost of error.** Rule of three for repetition; incidents jump straight to checks, tests, and gates.
5. **Design the mistake out when you can.** Types, database constraints, RLS, capability-scoped handles, and safe defaults beat any detector.
6. **Every incident, near-miss, and repeated review comment feeds the loop** — and the loop isn't closed until a class-level guardrail exists *and has been shown to catch the original bug*.
7. **Templates for divergence, packages for synchronization.** Otherwise templates drift and fixes don't propagate.
8. **Your guardrail system is a product.** It needs owners, versions, deprecations, health metrics, and pruning — or it rots into something people bypass.

---

## Self-Assessment Checklist

```text
□ I can name the top 5 lessons in my current project and the rung each lives on.
□ My most common unit of work (endpoint/page/table) starts from a generator or template.
□ My most critical invariant is enforced in at least 3 independent places.
□ At least one custom lint rule or Semgrep rule exists that came from a real incident or repeated review comment.
□ I have at least one meta-test that automatically covers new routes/tables/components.
□ My main branch has required status checks, and I know how many times I overrode them last month.
□ My last postmortem produced class-level guardrails, and I verified each one catches the original bug.
□ Shared config (lint, tsconfig, CI) is consumed as a versioned package or reusable workflow, not copied.
□ I have a list of guardrails with owners and review dates, and I've deleted at least one obsolete rule.
□ Lint and CI error messages point to the doc that explains why.
```
