# 02 — Engineering Conventions: How Teams Stop Re-Deciding Everything

> An engineering convention is an **agreed default answer to a recurring question**, so nobody spends judgment on problems that are already solved. Conventions turn thousands of micro-decisions — file names, error shapes, commit formats, log fields — into predictable structure that humans can navigate and machines can verify. This document explains why conventions exist, gives concrete, copy-ready conventions for 22 areas, and precisely distinguishes conventions from best practices, patterns, standards, rules, guidelines, architecture decisions, and principles.

Related: [01-engineering-skills.md](01-engineering-skills.md) · [10-knowledge-into-systems.md](10-knowledge-into-systems.md) · [15-standardize-vs-flexible.md](15-standardize-vs-flexible.md) · [templates/pull-request.md](templates/pull-request.md) · [templates/adr.md](templates/adr.md) · [glossary.md](glossary.md)

---

## Table of Contents

1. [What a Convention Actually Is](#1-what-a-convention-actually-is)
2. [Why Experienced Teams Use Conventions](#2-why-experienced-teams-use-conventions)
3. [Properties of a Good Convention](#3-properties-of-a-good-convention)
4. [Conventions by Area](#4-conventions-by-area)
   - [4.1 Repository Structure](#41-repository-structure)
   - [4.2 Naming](#42-naming)
   - [4.3 Code Organization](#43-code-organization)
   - [4.4 API Conventions](#44-api-conventions)
   - [4.5 Database Conventions](#45-database-conventions)
   - [4.6 Error Handling](#46-error-handling)
   - [4.7 Validation](#47-validation)
   - [4.8 Authentication](#48-authentication)
   - [4.9 Authorization](#49-authorization)
   - [4.10 Logging](#410-logging)
   - [4.11 Testing](#411-testing)
   - [4.12 Git](#412-git)
   - [4.13 Branching](#413-branching)
   - [4.14 Commits](#414-commits)
   - [4.15 Pull Requests](#415-pull-requests)
   - [4.16 Code Review](#416-code-review)
   - [4.17 Documentation](#417-documentation)
   - [4.18 Configuration](#418-configuration)
   - [4.19 Environment Management](#419-environment-management)
   - [4.20 Dependency Management](#420-dependency-management)
   - [4.21 Deployment](#421-deployment)
   - [4.22 Monitoring](#422-monitoring)
5. [Convention vs Best Practice vs Pattern vs Standard vs Rule vs Guideline vs Architecture Decision vs Principle](#5-the-taxonomy-of-engineering-guidance)
6. [How One Idea Moves Between Categories](#6-how-one-idea-moves-between-categories)
7. [Enforcement: From Hope to Guarantee](#7-enforcement-from-hope-to-guarantee)
8. [Adopting, Evolving, and Retiring Conventions](#8-adopting-evolving-and-retiring-conventions)
9. [Amateur vs Professional vs Expert Conventions](#9-amateur-vs-professional-vs-expert-conventions)
10. [Key Takeaways](#10-key-takeaways)
11. [Self-Assessment Checklist](#11-self-assessment-checklist)

---

## 1. What a Convention Actually Is

### What

A convention is a **shared, usually arbitrary-but-consistent choice** among several acceptable options, adopted so that everyone makes the same choice without deliberating.

Key property: **the value comes mostly from consistency, not from the specific choice.** `snake_case` vs `camelCase` for database columns barely matters. Having *both* in the same schema matters a lot.

### Why

Software engineering involves an enormous number of decisions that are:

1. **Recurring** — every new endpoint needs an error format; every new table needs a primary key type.
2. **Low individual stakes** — any reasonable choice works.
3. **High collective stakes** — inconsistency multiplies cognitive load, bugs, and tooling complexity.

Conventions pre-answer these decisions once.

### How

A convention is typically: **proposed** (someone notices a recurring decision), **decided** (team chooses, often recorded in an ADR or `CONVENTIONS.md`), **encoded** (template, generator, lint rule, CI check), and **maintained** (revisited when it stops serving).

### Example

Without convention, a SaaS codebase ends up with:

```text
GET /api/getUsers
GET /api/user-list
GET /api/v1/Customers
POST /api/orders/create
POST /api/createInvoice
```

With the convention *"plural kebab-case resource nouns, HTTP verbs express the action, version prefix `/v1`"*:

```text
GET  /v1/users
GET  /v1/customers
POST /v1/orders
POST /v1/invoices
```

Any developer can now predict an endpoint's URL without looking it up, and an API gateway rule, OpenAPI linter (Spectral), or generated client can rely on the pattern.

### Expert Mental Model

> "Every decision a developer makes costs attention. Conventions are how a team spends attention once on questions that don't deserve it twice — and saves it for the questions that do."

### Common Mistake

Treating conventions as matters of taste to be debated endlessly. The point of a convention is to *end* the debate. Pick a reasonable option, write it down, automate it, move on.

---

## 2. Why Experienced Teams Use Conventions

> Why do experienced teams use conventions instead of making every developer decide everything from scratch?

### 2.1 Decision fatigue and judgment budget

**What.** Every developer has a limited daily budget of high-quality judgment.

**Why it matters.** If a developer spends 20 small decisions per feature on naming files, choosing log formats, and designing error JSON, those decisions draw from the same budget needed for "is this transaction boundary correct?" Conventions **reserve judgment for the problems that actually require it**.

**Example.** A developer adding a new `refunds` module in a codebase with conventions runs `pnpm gen module refunds`. They get the folder structure, a router with the standard error middleware, a test file with a real-DB fixture, and a migration stub. Their first real decision is: *"Can a partially-captured payment be partially refunded?"* — which is the question that matters.

### 2.2 Review cost

**What.** Code review time grows with how much of the change is *surprising*.

**Why.** When structure is conventional, reviewers skip everything that follows the pattern and focus on deviations and logic. When nothing is conventional, every line needs evaluation, and reviewers either burn out or rubber-stamp.

**Example.** Reviewing a PR where every handler validates input with the same `parseBody(schema)` call: the reviewer checks the schema. Reviewing one where each handler validates ad hoc: the reviewer must verify each validation approach is correct and complete.

### 2.3 Onboarding speed

**What.** Time until a new developer (or you, returning after 3 months) can make safe changes.

**Why.** Conventions make knowledge **transferable across files, modules, and projects**. Learning one module teaches you all modules.

**Example.** Across 5 projects that share a structure (see [11-solo-developer-multiple-projects.md](11-solo-developer-multiple-projects.md)), a solo developer opens project #4 after 10 weeks and immediately knows: migrations are in `db/migrations`, env schema is in `src/config/env.ts`, runbooks are in `docs/runbooks`, `pnpm verify` runs every check.

### 2.4 Automation

**What.** Machines can only act on predictable structure.

**Why.** Conventional commits enable automated changelogs and semantic version bumps. Consistent error codes enable frontend i18n mappings and alert grouping. Consistent log fields enable dashboards across services. Consistent folder structure enables lint rules for architecture boundaries. **No convention, no automation.**

**Example.**

```text
Convention: commit messages follow Conventional Commits
  ↓ enables
semantic-release computes next version (feat → minor, fix → patch, BREAKING CHANGE → major)
  ↓ enables
CHANGELOG.md generated automatically
  ↓ enables
release notes posted to customers without manual writing
```

### 2.5 Correctness by default

**What.** Well-designed conventions encode safety.

**Why.** A convention like *"all tenant-owned tables have `tenant_id NOT NULL` and an RLS policy"* makes the secure path the default path. A convention like *"all money is `BIGINT` minor units with a `currency` column"* eliminates a whole class of float rounding bugs.

### 2.6 Searchability and tooling

Consistent naming makes `grep` a reliable tool. If every domain event is named `<Aggregate><PastTenseVerb>` (`OrderShipped`, `PaymentCaptured`), then `rg "class \w+Captured"` finds all capture events. If events are named randomly, knowledge lives only in people's heads.

### 2.7 Reduced coordination

In a team of N people, pairwise coordination paths grow as N(N−1)/2. Conventions are **pre-negotiated coordination** — people stay consistent without talking.

### 2.8 AI and agent effectiveness

AI coding agents perform much better in conventional codebases: they infer patterns from neighboring files and replicate them. In inconsistent codebases, they replicate *whichever* inconsistent pattern they saw first. An `AGENTS.md`/`CLAUDE.md` that states conventions explicitly turns them into agent instructions. See [13-ai-and-agents.md](13-ai-and-agents.md).

### Summary table — cost of no convention

| Area without convention | Visible symptom | Hidden cost |
|---|---|---|
| Error format | Frontend has multiple error parsers | Users see "Something went wrong" for recoverable errors |
| Log fields | Can't build cross-service dashboard | Incidents take hours instead of minutes |
| Migrations | Occasional locked production tables | Deploys become feared and infrequent |
| Commits | Unreadable history | No automated changelog; archaeology is slow |
| Folder structure | "Where does this go?" questions | Architectural boundaries erode silently |
| Config | Crashes from missing env vars in prod | Errors discovered at runtime, not startup |

---

## 3. Properties of a Good Convention

| Property | Meaning | Bad example | Good example |
|---|---|---|---|
| **Unambiguous** | Two people applying it get the same result | "Use descriptive names" | "Boolean columns are prefixed `is_`/`has_`; timestamps suffixed `_at`" |
| **Automatable** | A tool can check or generate it | "Keep functions small" | "ESLint `max-lines-per-function: 80` (warn)" |
| **Justified** | Its reason is written down | "Always use UUIDs" | "Use UUIDv7 PKs: non-enumerable, index-friendly ordering, generatable client-side for idempotent creation" |
| **Scoped** | Clear where it applies | "No ORMs" | "Reporting queries use raw SQL via `sql` tagged templates; transactional writes use repository layer" |
| **Cheap to follow** | Easier than not following | Manual checklist of 40 items | Generator creates compliant scaffold |
| **Escapable** | Has a documented way to deviate | Hard ban, no exceptions | `// eslint-disable-next-line <rule> -- reason: <link to ADR>` required |
| **Discoverable** | New people can find it | Tribal knowledge | `CONVENTIONS.md` linked from README and `AGENTS.md` |

---

## 4. Conventions by Area

Each area gives: **What · Why · Concrete convention · Enforcement · Expert mental model · Common mistake.** These are strong defaults suitable for a TypeScript/Node + PostgreSQL + React/Next.js stack; adapt, but *choose explicitly*.

### 4.1 Repository Structure

**What.** The top-level layout of a repository: where source, tests, docs, infrastructure, scripts, and configuration live.

**Why.** Structure is the first thing every human and agent sees. Predictable structure makes navigation automatic, enables tooling (path-based lint rules, CODEOWNERS, CI path filters), and — across multiple projects — lets you switch contexts cheaply.

**Concrete convention — single application (Next.js + API in one repo, modular monolith):**

```text
.
├── .github/
│   ├── workflows/            # ci.yml, deploy.yml, codeql.yml
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── docs/
│   ├── architecture.md       # C4 context + container diagrams, key flows
│   ├── adr/                  # 0001-record-architecture-decisions.md, 0002-...
│   ├── runbooks/             # one file per alert
│   └── invariants.md         # invariant register (see templates/invariant-register.md)
├── db/
│   ├── migrations/           # 20260915T101500_create_orders.sql
│   └── seeds/
├── infra/                    # terraform/ or pulumi/
├── scripts/                  # one-off & operational scripts, each with --dry-run
├── src/
│   ├── app/                  # Next.js routes ONLY: thin, delegate to modules
│   ├── modules/
│   │   ├── orders/
│   │   │   ├── index.ts      # public API of module
│   │   │   ├── domain/       # entities, value objects, state machines, pure rules
│   │   │   ├── application/  # use cases (commands/queries), transaction boundaries
│   │   │   ├── infrastructure/ # repositories, external clients
│   │   │   └── ui/           # React components specific to this module
│   │   └── billing/
│   ├── shared/
│   │   ├── kernel/           # Money, Id, Result, errors
│   │   ├── ui/               # design-system primitives
│   │   └── lib/              # logger, http client, db client
│   └── config/
│       └── env.ts            # validated environment schema
├── tests/
│   ├── e2e/                  # Playwright
│   └── fixtures/
├── .env.example
├── .nvmrc
├── AGENTS.md                 # instructions for AI agents (conventions, commands)
├── CONVENTIONS.md
├── README.md
└── package.json
```

**Concrete convention — monorepo (multiple deployables + shared packages):**

```text
.
├── apps/
│   ├── web/                  # Next.js customer app
│   ├── admin/                # Next.js internal admin
│   └── worker/               # Node background jobs
├── packages/
│   ├── ui/                   # design system
│   ├── domain/               # shared domain types (only if truly shared)
│   ├── config-eslint/
│   ├── config-typescript/
│   └── errors/
├── infra/
├── docs/
├── turbo.json
└── pnpm-workspace.yaml
```

**Rules that make it a convention, not just a layout:**
- Unit/integration tests are **colocated**: `order-pricing.ts` → `order-pricing.test.ts`. E2E tests live in `tests/e2e`.
- `src/app/` (Next.js routes) contains no business logic; handlers call `modules/*/index.ts`.
- Every repo has the same root commands: `dev`, `build`, `test`, `lint`, `typecheck`, `verify` (runs all checks), `db:migrate`.

**Enforcement.** Project generator/template; `eslint-plugin-boundaries`; CI check that required files exist:

```bash
#!/usr/bin/env bash
# scripts/check-repo-shape.sh
set -euo pipefail
required=(README.md AGENTS.md .env.example .nvmrc docs/adr docs/runbooks src/config/env.ts)
for f in "${required[@]}"; do
  [[ -e "$f" ]] || { echo "Missing required path: $f"; exit 1; }
done
```

**Expert mental model.** *"Structure should make the architecture visible and the wrong placement awkward."*

**Common mistake.** Organizing only by technical layer (`controllers/`, `services/`, `models/`) — a single feature change touches five distant folders and module boundaries are invisible.

---

### 4.2 Naming

**What.** Rules for naming files, variables, functions, types, database objects, events, endpoints, environment variables, branches, and infrastructure resources.

**Why.** Names are the primary interface to understanding. Consistent names make code searchable, predictable, and mappable across layers (the `orders` table ↔ `Order` type ↔ `/v1/orders` endpoint ↔ `orders` module).

**Concrete convention:**

| Thing | Convention | Example |
|---|---|---|
| TS files | kebab-case | `order-pricing.ts`, `use-cart.ts` |
| React component files | PascalCase matching component | `CheckoutSummary.tsx` |
| Types / interfaces / classes | PascalCase, no `I` prefix | `Order`, `PaymentGateway` |
| Functions / variables | camelCase, verb-first for functions | `calculateTax()`, `reserveStock()` |
| Booleans | `is/has/can/should` prefix | `isActive`, `hasShipped`, `canRefund` |
| Constants | UPPER_SNAKE for true constants | `MAX_IMPORT_ROWS = 50_000` |
| React hooks | `use` prefix | `useInvoiceFilters` |
| Event handlers (props) | `on<Event>`; implementations `handle<Event>` | `onSubmit={handleSubmit}` |
| DB tables | snake_case, plural | `orders`, `order_lines` |
| DB columns | snake_case; `_at` timestamps, `_id` FKs, `is_` booleans, `_cents` minor units | `created_at`, `customer_id`, `is_archived`, `total_cents` |
| DB indexes | `idx_<table>_<cols>`; unique `uq_`; check `ck_`; FK `fk_` | `idx_orders_tenant_id_created_at`, `uq_users_email` |
| API paths | plural kebab-case nouns | `/v1/purchase-orders/{id}/line-items` |
| JSON fields | camelCase (or snake_case — pick one per API forever) | `createdAt` |
| Domain events | `<Aggregate><PastTenseVerb>`; topic `domain.aggregate.verb` | `OrderShipped`, `billing.invoice.paid` |
| Error codes | lower_snake, stable, domain-specific | `insufficient_funds`, `order_not_cancellable` |
| Env vars | UPPER_SNAKE, prefixed by concern | `DATABASE_URL`, `STRIPE_SECRET_KEY`, `NEXT_PUBLIC_APP_URL` |
| Metrics | `<namespace>_<noun>_<unit>` (Prometheus) | `checkout_requests_total`, `payment_capture_duration_seconds` |
| Feature flags | `<area>.<feature>` + owner + expiry | `checkout.apple-pay` |
| Cloud resources | `<org>-<env>-<service>-<resource>` | `acme-prod-orders-db` |

**Domain language rule:** use the business's words. If warehouse staff say "wave," the code says `Wave`, not `PickBatch`. Maintain `docs/glossary.md` per project.

**Enforcement.** ESLint `@typescript-eslint/naming-convention`; `unicorn/filename-case`; SQL migration linter (e.g., `squawk` plus a custom naming check); Spectral rules for OpenAPI paths.

```js
// eslint.config.js (excerpt)
rules: {
  "unicorn/filename-case": ["error", { cases: { kebabCase: true, pascalCase: true } }],
  "@typescript-eslint/naming-convention": ["error",
    { selector: "typeLike", format: ["PascalCase"] },
    { selector: "variable", types: ["boolean"], format: ["PascalCase"], prefix: ["is", "has", "can", "should"] },
  ],
}
```

**Expert mental model.** *"A name is a compressed specification. If naming is hard, the concept is unclear."*

**Common mistake.** Generic names that hide meaning (`data`, `info`, `handle`, `manager`, `utils.ts`, `process()`), and synonyms for one concept (`client`, `customer`, `account`, `user` all meaning the same thing).

---

### 4.3 Code Organization

**What.** How code is split into modules, layers, and files, and which dependencies are allowed between them.

**Why.** Organization determines the cost of change. When dependency direction is consistent, you can change infrastructure without touching domain rules and test domain rules without infrastructure.

**Concrete convention — dependency rule within a module:**

```text
ui ──────────▶ application ──────────▶ domain
infrastructure ─▶ application / domain (implements ports)
domain ──▶ (nothing except shared/kernel)
```

- **domain/**: pure TypeScript. No imports from `next`, `prisma`, `pg`, `fetch`, `process.env`. Deterministic; time and IDs are passed in.
- **application/**: use cases — one exported function per command/query (`placeOrder`, `cancelOrder`, `getOrderSummary`). Owns transaction boundaries and authorization calls.
- **infrastructure/**: database repositories, external API clients, queue publishers.
- **ui/**: React components; server components call application queries; client components call server actions/route handlers.
- **Cross-module access** only via the other module's `index.ts`.

**Example — use case shape:**

```ts
// src/modules/orders/application/cancel-order.ts
import { z } from "zod";
import type { Deps } from "./deps";
import { AppError } from "@/shared/kernel/errors";

export const CancelOrderInput = z.object({
  orderId: z.string().uuid(),
  reason: z.enum(["customer_request", "fraud", "out_of_stock"]),
});

export async function cancelOrder(deps: Deps, actor: Actor, raw: unknown) {
  const input = CancelOrderInput.parse(raw);
  return deps.db.transaction(async (tx) => {
    const order = await deps.orders.getForUpdate(tx, actor.tenantId, input.orderId);
    if (!order) throw new AppError("order_not_found", 404);
    await deps.authz.assert(actor, "order:cancel", order);
    const cancelled = order.cancel(input.reason, deps.clock.now()); // domain enforces legal transition
    await deps.orders.save(tx, cancelled);
    await deps.outbox.add(tx, { type: "orders.order.cancelled", payload: { orderId: order.id } });
    return cancelled.toSummary();
  });
}
```

Every use case in every module has this shape: **parse → load → authorize → domain operation → persist → emit → return**. Reviewers check deviations.

**File size and function conventions:**
- One exported use case per file in `application/`.
- Files > 400 lines trigger a lint warning, not an error.
- No barrel files (`index.ts` re-exporting everything) except the module's public API.

**Enforcement.** `eslint-plugin-boundaries` or `dependency-cruiser`:

```js
// .dependency-cruiser.cjs (excerpt)
forbidden: [
  { name: "domain-is-pure",
    from: { path: "^src/modules/[^/]+/domain" },
    to:   { path: "(^src/modules/[^/]+/(infrastructure|application|ui))|node_modules/(next|@prisma|pg)" } },
  { name: "no-cross-module-internals",
    from: { path: "^src/modules/([^/]+)/" },
    to:   { path: "^src/modules/(?!$1)[^/]+/(?!index\\.ts$)" } },
]
```

**Expert mental model.** *"Dependencies should point toward the things that change least: business rules."*

**Common mistake.** Business logic in React components or Next.js route handlers, so the same rule is reimplemented in the admin app, the worker, and the public API.

---

### 4.4 API Conventions

**What.** Uniform rules for HTTP/JSON (or GraphQL/gRPC) APIs: URLs, methods, status codes, pagination, filtering, errors, idempotency, versioning, and field formats.

**Why.** Consumers (your frontend, mobile apps, partners, agents) learn the API once. Generated clients, gateways, and monitoring depend on consistency. Breaking changes are the most expensive changes in software.

**Concrete convention (REST/JSON):**

| Concern | Convention |
|---|---|
| Resources | Plural nouns: `/v1/orders`, `/v1/orders/{orderId}` |
| Actions that aren't CRUD | Sub-resource with verb: `POST /v1/orders/{id}/cancel` |
| Methods | `GET` read (safe), `POST` create/action, `PATCH` partial update, `PUT` full replace (idempotent), `DELETE` remove (idempotent) |
| IDs | Opaque, prefixed strings: `ord_01J8ZK...`, never auto-increment integers |
| Timestamps | RFC 3339 UTC strings: `"2026-09-15T10:15:00Z"` |
| Money | Integer minor units + ISO 4217 currency: `{ "amount": 4999, "currency": "USD" }` |
| Enums | lower_snake strings; clients must tolerate unknown values |
| Pagination | Cursor-based: `?limit=50&cursor=...`; response `{ data: [...], nextCursor: "..." | null }`; max `limit` 100 |
| Filtering | `?status=shipped&createdAfter=2026-09-01T00:00:00Z` |
| Sorting | `?sort=-createdAt,number` (minus = descending) |
| Idempotency | `Idempotency-Key` header required on `POST` that creates or charges; responses stored 24h |
| Concurrency | `ETag` on reads; `If-Match` required on `PATCH` of contended resources → `412` on mismatch |
| Versioning | URL major version `/v1`; additive changes don't bump; breaking changes require new version + deprecation window (≥ 6 months for external) |
| Rate limits | `429` + `Retry-After`; `RateLimit-*` headers |
| Request tracing | Accept `traceparent`; always return `X-Request-Id` |
| Status codes | `200` ok, `201` created (+`Location`), `202` accepted async, `204` no content, `400` malformed, `401` unauthenticated, `403` forbidden, `404` not found (also for unauthorized-to-know), `409` conflict/state, `412` precondition failed, `422` validation, `429` rate limited, `500` bug, `502/503/504` dependency/unavailable |

**Example — list response:**

```json
{
  "data": [
    {
      "id": "ord_01J8ZK3Q7M2X4B",
      "status": "shipped",
      "total": { "amount": 12999, "currency": "USD" },
      "createdAt": "2026-09-14T18:22:05Z"
    }
  ],
  "nextCursor": "eyJjcmVhdGVkQXQiOiIyMDI2LTA5LTE0VDE4OjIyOjA1WiIsImlkIjoib3JkXzAxSjhaSzNRN00yWDRCIn0"
}
```

**Compatibility rules (written into `CONVENTIONS.md`):**
- ✅ Allowed without version bump: adding optional request fields, adding response fields, adding endpoints, adding enum values (clients must tolerate).
- ❌ Breaking: removing/renaming fields, changing types, making optional fields required, changing error codes, changing default sort, tightening validation on existing fields.

**Enforcement.** OpenAPI spec in repo as source of truth; Spectral lint in CI; `oasdiff breaking` against `main` blocks breaking changes:

```yaml
- name: Detect breaking API changes
  run: |
    git show origin/main:openapi.yaml > /tmp/base.yaml
    npx @useoptic/optic diff /tmp/base.yaml openapi.yaml --check || \
    oasdiff breaking /tmp/base.yaml openapi.yaml --fail-on ERR
```

**Expert mental model.** *"An API convention is a promise that knowledge of one endpoint transfers to all others."*

**Common mistake.** `200 OK` with `{ "success": false }` — breaks HTTP semantics, caches, monitoring, retries, and every client's error handling.

---

### 4.5 Database Conventions

**What.** Rules for schema design, keys, types, constraints, indexes, migrations, and data lifecycle.

**Why.** Data outlives code. Inconsistent schemas produce integrity bugs, painful migrations, and incorrect analytics. Migration conventions prevent production outages.

**Concrete convention (PostgreSQL):**

| Concern | Convention |
|---|---|
| Primary keys | `id UUID PRIMARY KEY DEFAULT uuidv7()` (or app-generated UUIDv7); external IDs prefixed at API layer |
| Tenant scoping | Every tenant-owned table has `tenant_id UUID NOT NULL REFERENCES tenants(id)`; composite indexes lead with `tenant_id`; RLS enabled |
| Timestamps | `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()` (trigger-maintained). Never `TIMESTAMP` without time zone |
| Money | `BIGINT` minor units `*_cents` / `amount_minor` + `currency CHAR(3)`; never `FLOAT`/`REAL`; `NUMERIC` only for rates/FX |
| Nullability | `NOT NULL` by default; nullable columns require a reason in the migration comment |
| Status fields | `TEXT` + `CHECK (status IN (...))` or a lookup table; transitions guarded (see [09-invariants-and-correctness.md](09-invariants-and-correctness.md)) |
| Soft delete | Only where business requires recovery/audit: `deleted_at TIMESTAMPTZ NULL` + partial unique indexes `WHERE deleted_at IS NULL` |
| Foreign keys | Always declared; `ON DELETE RESTRICT` by default; `CASCADE` requires justification |
| JSONB | For genuinely schemaless attributes only; never for fields you filter/join on regularly |
| Audit | Critical tables have an append-only `<table>_history` or domain event table |
| Migrations | Forward-only SQL files, timestamp-prefixed, one concern per file, run in CI against a real DB |
| Zero downtime | Expand → migrate/backfill → contract. Never rename/drop a column in the same deploy that stops using it |
| Locks | Every migration sets `SET lock_timeout = '5s'`; indexes created `CONCURRENTLY`; constraints added `NOT VALID` then `VALIDATE` |
| Backfills | In batches (e.g., 5k rows) via scripts, not in schema migrations |

**Example — a conventional migration:**

```sql
-- db/migrations/20260915T101500_create_shipments.sql
SET lock_timeout = '5s';

CREATE TABLE shipments (
  id                  UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  order_id            UUID NOT NULL REFERENCES orders(id)  ON DELETE RESTRICT,
  external_reference  TEXT NOT NULL,
  carrier             TEXT NOT NULL CHECK (carrier IN ('ups','fedex','dhl','usps')),
  status              TEXT NOT NULL DEFAULT 'label_pending'
                        CHECK (status IN ('label_pending','label_created','in_transit','delivered','exception','cancelled')),
  weight_grams        INTEGER NOT NULL CHECK (weight_grams > 0),
  shipping_cost_cents BIGINT  NOT NULL CHECK (shipping_cost_cents >= 0),
  currency            CHAR(3) NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_shipments_tenant_external_reference UNIQUE (tenant_id, external_reference)
);

CREATE INDEX idx_shipments_tenant_id_status_created_at ON shipments (tenant_id, status, created_at DESC);

ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON shipments USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

**Example — expand/contract rename of `customers.name` → `customers.full_name`:**

```text
Deploy 1 (expand):   ADD COLUMN full_name TEXT NULL; app writes both, reads name
Script:              backfill full_name = name in batches
Deploy 2:            app reads full_name (fallback to name), writes both
Migration:           ALTER ... ADD CONSTRAINT ck_full_name_not_null CHECK (full_name IS NOT NULL) NOT VALID; VALIDATE CONSTRAINT
Deploy 3 (contract): app stops writing name
Migration:           DROP COLUMN name
```

**Enforcement.** `squawk` (Postgres migration linter) in CI; a test that applies all migrations to an empty DB; a schema test asserting every table with `tenant_id` has RLS enabled:

```sql
-- tests/sql/every_tenant_table_has_rls.sql  (fails if any rows returned)
SELECT c.relname
FROM pg_class c
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'tenant_id'
WHERE c.relkind = 'r' AND c.relnamespace = 'public'::regnamespace AND NOT c.relrowsecurity;
```

**Expert mental model.** *"The schema is the most durable documentation of business rules. Make it strict, because it will outlive every service that writes to it."*

**Common mistake.** Letting the ORM generate schema with defaults (nullable everything, no check constraints, `timestamp without time zone`, cascade deletes), then discovering invalid data years later.

---

### 4.6 Error Handling

**What.** A consistent model for classifying, propagating, logging, and presenting errors across code, APIs, and UI.

**Why.** Inconsistent error handling is where systems lose data silently (swallowed exceptions), leak internals (stack traces to clients), confuse users ("Something went wrong"), and page on-call engineers for non-issues.

**Concrete convention — two classes of errors:**

| | Expected (domain/operational) | Unexpected (bugs/defects) |
|---|---|---|
| Examples | Validation failure, not found, insufficient funds, conflict, rate limited, dependency timeout | Null dereference, invariant violation, unhandled case |
| Representation | `AppError` with stable `code`, HTTP status, `retryable` flag, safe message | Plain `Error` / thrown exceptions |
| Logging | `info`/`warn`, no stack trace needed | `error` with stack, alerts if rate elevated |
| Client sees | Specific code + message + details | Generic `internal_error` + `requestId` only |
| Handling | Caught and translated at boundary | Crash the request (not the process); fix the bug |

**Error envelope (all HTTP APIs):**

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Some fields are invalid.",
    "status": 422,
    "retryable": false,
    "requestId": "req_01J8ZMCZ4T6Q",
    "details": [
      { "path": "shippingAddress.postalCode", "code": "invalid_format", "message": "Postal code is not valid for country US." },
      { "path": "lines[2].quantity", "code": "too_large", "message": "Maximum quantity is 99." }
    ],
    "docUrl": "https://docs.example.com/errors/validation_failed"
  }
}
```

**Implementation:**

```ts
// src/shared/kernel/errors.ts
export type ErrorCode =
  | "validation_failed" | "unauthenticated" | "forbidden" | "not_found"
  | "conflict" | "precondition_failed" | "rate_limited"
  | "insufficient_funds" | "order_not_cancellable" | "idempotency_key_reused"
  | "dependency_unavailable" | "internal_error";

export class AppError extends Error {
  constructor(
    public readonly code: ErrorCode,
    public readonly status: number,
    message?: string,
    public readonly details?: ReadonlyArray<{ path: string; code: string; message: string }>,
    public readonly retryable = false,
    options?: { cause?: unknown },
  ) {
    super(message ?? code, options);
    this.name = "AppError";
  }
}

// src/shared/lib/http/error-response.ts
export function toErrorResponse(err: unknown, requestId: string, log: Logger): Response {
  if (err instanceof AppError) {
    log.warn({ err_code: err.code, status: err.status }, "request failed with expected error");
    return Response.json(
      { error: { code: err.code, message: err.message, status: err.status, retryable: err.retryable, requestId, details: err.details } },
      { status: err.status },
    );
  }
  if (err instanceof ZodError) {
    return toErrorResponse(new AppError("validation_failed", 422, "Some fields are invalid.", zodToDetails(err)), requestId, log);
  }
  log.error({ err }, "unhandled error");
  return Response.json(
    { error: { code: "internal_error", message: "An unexpected error occurred.", status: 500, retryable: true, requestId } },
    { status: 500 },
  );
}
```

**Rules:**
1. Never `catch` and ignore. Every `catch` either handles (with a specific recovery), translates (adds context and rethrows with `cause`), or is at a top-level boundary.
2. Wrap errors with context: `throw new AppError("dependency_unavailable", 503, "Carrier API timeout", undefined, true, { cause: err })`.
3. Error codes are part of the API contract — never change or reuse them.
4. The frontend maps `code` → user message and action (retry button only if `retryable`); field `details` map to form fields.
5. Process-level: `unhandledRejection` and `uncaughtException` log and exit; the orchestrator restarts. Don't limp on in unknown state.

**Frontend (Next.js) mapping:**

```ts
const USER_MESSAGES: Partial<Record<ErrorCode, string>> = {
  insufficient_funds: "Your card was declined for insufficient funds. Try another payment method.",
  order_not_cancellable: "This order has already shipped and can no longer be cancelled.",
  rate_limited: "Too many attempts. Please wait a moment and try again.",
};
```

**Enforcement.** Lint rule banning empty catch blocks (`no-empty`, custom rule for `catch {}` without rethrow/log); contract tests validating error responses against a JSON schema; typed `ErrorCode` union shared with the frontend.

**Expert mental model.** *"Errors are data. Classify them, give them stable identities, and decide at design time who handles each kind."*

**Common mistake.** `catch (e) { console.log(e) }` followed by continuing as if the operation succeeded — the most common cause of silent data loss.

---

### 4.7 Validation

**What.** Where, how, and with what tool input is checked and converted into trusted types.

**Why.** Every trust boundary (HTTP request, webhook, queue message, file upload, env var, third-party response, database JSONB) can deliver malformed or malicious data. Inconsistent validation causes crashes, injection, mass assignment, and corrupted data.

**Concrete convention — "parse, don't validate" at every boundary:**

| Boundary | Tool | Behavior on failure |
|---|---|---|
| HTTP body/query/params | Zod schema per endpoint | `422 validation_failed` with field details |
| Server actions (Next.js) | Same Zod schema as form | Return typed field errors |
| Client forms | Same Zod schema via `@hookform/resolvers/zod` | Inline errors (UX only, not security) |
| Webhooks | Signature verification **then** Zod | `400`; log + metric |
| Queue messages | Zod with schema version | Dead-letter after N attempts |
| Env vars | Zod at startup | Process exits with list of invalid vars |
| Third-party API responses | Zod (lenient: `passthrough`) | `AppError("dependency_unavailable")`, alert on rate |
| DB JSONB columns | Zod on read | Error log; treat as data corruption |

**Rules:**
1. Schemas are `strict()` for inbound requests: unknown fields are rejected (prevents mass assignment like `{"role":"admin"}`).
2. Validation produces **typed domain values** (branded types), so downstream code can't receive unvalidated data.
3. **Three layers, three purposes:**
   - *Shape* validation (types, formats, lengths) → at boundary schema.
   - *Business* validation (stock available, order cancellable) → in domain/application.
   - *Integrity* (unique, FK, check) → database constraints.
4. Limits are always explicit: max string length, max array length, max file size, numeric ranges.

**Example:**

```ts
// src/modules/orders/application/place-order.schema.ts
export const PlaceOrderInput = z.object({
  lines: z.array(z.object({
    sku: z.string().regex(/^[A-Z0-9-]{3,32}$/),
    quantity: z.number().int().min(1).max(99),
  })).min(1).max(200),
  shippingAddress: AddressSchema,
  couponCode: z.string().trim().toUpperCase().max(32).optional(),
}).strict();

export type PlaceOrderInput = z.infer<typeof PlaceOrderInput>;
```

```ts
// src/config/env.ts
const Env = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]),
  DATABASE_URL: z.string().url(),
  STRIPE_SECRET_KEY: z.string().startsWith("sk_"),
  NEXT_PUBLIC_APP_URL: z.string().url(),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
});
export const env = Env.parse(process.env); // throws at boot, not at 3 a.m.
```

**Enforcement.** Handler wrapper that requires a schema (`defineRoute({ input: Schema, handler })`) — routes without a schema don't type-check; lint rule banning direct `req.json()` outside the wrapper.

**Expert mental model.** *"Untrusted data gets converted into trusted types exactly once, at the edge. Inside, the type system carries the proof."*

**Common mistake.** Validating only in the React form, so any `curl` bypasses every rule.

---

### 4.8 Authentication

**What.** Conventions for establishing identity: users, services, API clients, webhooks, and agents.

**Why.** Authentication is security-critical and easy to get subtly wrong. Hand-rolled variations across endpoints produce gaps. Convention concentrates auth in one audited path.

**Concrete convention:**

| Concern | Convention |
|---|---|
| Implementation | Use an established provider/library (Auth.js, Clerk, Auth0, Cognito, WorkOS); no custom crypto or password storage unless required |
| Browser sessions | HTTP-only, `Secure`, `SameSite=Lax` cookies; session ID opaque; server-side session store or short-lived signed token + rotation. No tokens in `localStorage` |
| Session lifetime | Idle timeout 30 min for admin/finance apps, 7–30 days for consumer; absolute lifetime cap; re-auth for sensitive actions (change email, payout details) |
| Passwords | Argon2id or bcrypt (cost ≥ 12); breached-password check; rate limiting + lockout backoff per account and per IP |
| MFA | Required for admin/internal and financial roles; TOTP/WebAuthn; SMS discouraged |
| Service-to-service | Workload identity (cloud IAM, mTLS, or short-lived JWTs); no shared static API keys between internal services |
| API keys (customers) | Prefixed (`sk_live_`, `sk_test_`), shown once, stored hashed (SHA-256), scoped, revocable, `last_used_at` tracked |
| Webhooks (inbound) | Verify provider signature with constant-time compare + timestamp tolerance (e.g., 5 min) |
| Auth middleware | One `requireSession()` / `requireApiKey()` entry point; routes are **authenticated by default** — public routes explicitly opted out |
| Auth events | Login success/failure, MFA changes, password reset, key creation — all written to audit log |

**Example — authenticated-by-default Next.js middleware:**

```ts
// middleware.ts
import { NextResponse, type NextRequest } from "next/server";

const PUBLIC_PATHS = [/^\/$/, /^\/login/, /^\/signup/, /^\/api\/webhooks\//, /^\/_next\//, /^\/favicon\.ico$/];

export function middleware(req: NextRequest) {
  const isPublic = PUBLIC_PATHS.some((re) => re.test(req.nextUrl.pathname));
  if (isPublic) return NextResponse.next();
  const session = req.cookies.get("__Host-session");
  if (!session) {
    if (req.nextUrl.pathname.startsWith("/api/")) {
      return NextResponse.json({ error: { code: "unauthenticated", status: 401 } }, { status: 401 });
    }
    return NextResponse.redirect(new URL(`/login?next=${encodeURIComponent(req.nextUrl.pathname)}`, req.url));
  }
  return NextResponse.next(); // cookie presence only; the server still verifies the session in requireSession()
}
```

Note the convention: middleware is a *coarse* gate; **every** server handler still calls `requireSession()`, which verifies the session server-side. Defense in depth.

**Enforcement.** Test that enumerates all route files and asserts each either calls `requireSession`/`requireApiKey` or is in an explicit `PUBLIC_ROUTES` allowlist; security headers checked in E2E.

**Expert mental model.** *"Authentication is a single well-guarded door, not a lock on each window. Default closed; opening requires a named exception."*

**Common mistake.** Relying on middleware or client-side route guards alone, and forgetting that server actions and API routes are directly callable.

---

### 4.9 Authorization

**What.** Conventions for deciding *what an authenticated identity may do to which resource*.

**Why.** Broken authorization (especially object-level, "can user A read invoice B?") is consistently the top API security risk. It's rarely a missing library — it's inconsistency: one endpoint forgets the tenant filter.

**Concrete convention:**

1. **Deny by default.** No policy match → `403` (or `404` when existence must not be revealed).
2. **Centralized policy.** All decisions go through `authz.assert(actor, action, resource)` / `authz.can(...)`. No inline `if (user.role === "admin")` in handlers.
3. **Action naming:** `<resource>:<verb>` — `invoice:read`, `invoice:refund`, `member:invite`, `settings:billing:update`.
4. **Tenant scoping by construction.** Repositories require `tenantId` as the first parameter; there is no method that queries tenant data without it. Postgres RLS as a backstop.
5. **Authorize in the application layer**, after loading the resource and before mutating it — not in the UI, not only in middleware.
6. **UI hides what's not allowed** using the same policy (`can()` results sent to the client), but the server is the enforcement point.
7. **Role model:** RBAC for coarse roles (`owner`, `admin`, `member`, `viewer`) + attribute checks for ownership/state (e.g., `member` can edit own drafts only). Move to ReBAC (OpenFGA/SpiceDB) only when sharing/hierarchy demands it.
8. **Privileged operations** (impersonation, refunds > threshold, data export) require explicit permission, reason capture, and audit log.
9. **Internal admin tools** follow the same rules — they are not exempt.

**Example — policy module:**

```ts
// src/shared/authz/policy.ts
type Role = "owner" | "admin" | "member" | "viewer";
type Actor = { userId: string; tenantId: string; role: Role };

type Rule<R> = (actor: Actor, resource: R) => boolean;

const sameTenant = (a: Actor, r: { tenantId: string }) => a.tenantId === r.tenantId;

export const policies = {
  "invoice:read":   ((a, r) => sameTenant(a, r)) as Rule<{ tenantId: string }>,
  "invoice:refund": ((a, r) => sameTenant(a, r) && (a.role === "owner" || a.role === "admin")) as Rule<{ tenantId: string }>,
  "draft:update":   ((a, r) => sameTenant(a, r) && (a.role !== "viewer") && (a.role !== "member" || r.authorId === a.userId)) as Rule<{ tenantId: string; authorId: string }>,
} as const;

export type Action = keyof typeof policies;

export function assert<A extends Action>(actor: Actor, action: A, resource: Parameters<(typeof policies)[A]>[1]) {
  if (!policies[action](actor, resource as never)) {
    throw new AppError("forbidden", 403);
  }
}
```

**Example — authorization test matrix (generated, not hand-written per endpoint):**

```ts
describe.each([
  ["owner",  "invoice:refund", true],
  ["admin",  "invoice:refund", true],
  ["member", "invoice:refund", false],
  ["viewer", "invoice:refund", false],
])("%s → %s", (role, action, allowed) => {
  it(allowed ? "is allowed" : "is denied", () => { /* ... */ });
});

it("denies cross-tenant access for every role", async () => {
  for (const role of ROLES) {
    const res = await api.as(role, tenantA).get(`/v1/invoices/${invoiceOfTenantB.id}`);
    expect(res.status).toBe(404);
  }
});
```

**Enforcement.** Repository type signatures requiring `tenantId`; RLS test from 4.5; cross-tenant E2E tests for every resource route; code review checklist item "authorization happens after load, before mutation."

**Expert mental model.** *"Authentication asks who you are. Authorization must be asked for every object, every time, in one place."*

**Common mistake.** Checking role but not ownership/tenant: "admins can refund" becomes "admins of *any* tenant can refund *any* invoice."

---

### 4.10 Logging

**What.** Conventions for log format, levels, fields, correlation, sensitive-data handling, and retention.

**Why.** Logs are the primary forensic tool during incidents and audits. Unstructured, uncorrelated, inconsistent logs make investigations slow and dashboards impossible.

**Concrete convention:**

**Format:** JSON, one event per line, via `pino` (Node). Human-pretty formatting only in local dev.

**Required fields (every log line):**

| Field | Example | Source |
|---|---|---|
| `timestamp` | `2026-09-15T10:15:00.123Z` | logger |
| `level` | `info` | logger |
| `service` | `orders-api` | config |
| `env` | `production` | config |
| `version` | `git sha` | build |
| `trace_id` / `span_id` | `4bf92f3577b34da6a3ce929d0e0e4736` | OpenTelemetry context |
| `request_id` | `req_01J8ZM...` | middleware |
| `event` | `order.placed` | call site (stable, dot-namespaced) |
| `msg` | `order placed` | call site (human readable) |

**Contextual fields (when applicable):** `tenant_id`, `user_id` (internal ID, never email), `order_id`/resource IDs, `job_id`, `attempt`, `duration_ms`, `http.method`, `http.route` (template, not raw path), `http.status`, `err.code`, `err.stack`.

**Levels:**

| Level | Use | Example |
|---|---|---|
| `error` | A bug or failure requiring attention; would page if rate elevated | Unhandled exception, invariant violation, DLQ message |
| `warn` | Expected failure or degraded operation | Validation error, retrying dependency, fallback used |
| `info` | Significant business/lifecycle events | `order.placed`, `job.completed`, server started |
| `debug` | Diagnostic detail; off in production by default | Cache hit/miss details |

**Never log:** passwords, tokens, API keys, session IDs, full card numbers (PAN), CVV, full request bodies of auth/payment endpoints, government IDs, raw emails/phones where avoidable. Use redaction:

```ts
// src/shared/lib/logger.ts
import pino from "pino";

export const logger = pino({
  level: env.LOG_LEVEL,
  base: { service: env.SERVICE_NAME, env: env.NODE_ENV, version: env.GIT_SHA },
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: [
      "req.headers.authorization", "req.headers.cookie", "*.password", "*.token",
      "*.apiKey", "*.cardNumber", "*.cvv", "*.secret", "*.email",
    ],
    censor: "[REDACTED]",
  },
  formatters: { level: (label) => ({ level: label }) },
});
```

**Audit logs are not application logs.** Security- and business-relevant actions (role changed, refund issued, data exported, impersonation started) go to an append-only `audit_events` table with actor, action, target, before/after, IP, and reason — retained per compliance needs, queryable by support.

**Enforcement.** Logger is the only allowed output (`no-console` lint rule outside scripts); log schema test in CI for key events; redaction test that logs a fixture with secrets and asserts they're censored.

**Expert mental model.** *"Log events, not prose. Every log line should be queryable by the question I'll ask during an incident."*

**Common mistake.** Interpolating values into message strings (`"Order " + id + " failed for " + email`) — unqueryable, and leaks PII.

---

### 4.11 Testing

**What.** Conventions for test types, locations, naming, data setup, dependencies, and what "tested" means.

**Why.** Without conventions, test suites become inconsistent (some mock the DB, some don't), slow, flaky, and untrusted — and untrusted tests are ignored.

**Concrete convention — test portfolio:**

| Type | Scope | Tool | Dependencies | Location | Runs |
|---|---|---|---|---|---|
| Unit | Pure domain logic, utilities | Vitest | None (no I/O) | Colocated `*.test.ts` | Every commit, < 30s |
| Property | Invariants of domain functions | Vitest + fast-check | None | Colocated `*.property.test.ts` | Every commit |
| Integration | Use cases, repositories, route handlers | Vitest + Testcontainers Postgres | Real DB, fake external APIs (MSW) | Colocated `*.int.test.ts` | Every PR |
| Contract | API schema, consumer/provider, error envelope | Schemathesis / Pact / JSON schema | Running app | `tests/contract` | Every PR |
| Component | React components behavior | Vitest + Testing Library | MSW | Colocated `*.test.tsx` | Every PR |
| E2E | Critical user journeys (≤ 15) | Playwright | Full stack, seeded DB | `tests/e2e` | Every PR (smoke), full nightly |
| Accessibility | Pages & components | axe via Playwright | Full stack | `tests/e2e/a11y` | Every PR |
| Load | Critical endpoints | k6 | Staging | `tests/load` | Before major releases / weekly |
| Migration | All migrations apply cleanly | Custom script | Empty Postgres | CI job | Every PR |

**Naming:** describe behavior, not implementation.

```ts
describe("cancelOrder", () => {
  it("releases reserved stock when an allocated order is cancelled", ...);
  it("rejects cancellation once the order has shipped with order_not_cancellable", ...);
  it("is idempotent when the same cancellation is submitted twice", ...);
  it("returns not_found for orders belonging to another tenant", ...);
});
```

**Data setup:** factories, not shared fixtures.

```ts
const tenant = await factories.tenant();
const order = await factories.order({ tenantId: tenant.id, status: "allocated", lines: [{ sku: "A-1", quantity: 2 }] });
```

**Rules:**
1. Each test creates its own data; tests run in parallel; no ordering dependencies.
2. Mock only what you don't own and can't run (payment processors, carriers) — using MSW at the HTTP layer, not by mocking your own modules.
3. Every bug fix ships with a test that failed before the fix.
4. Every critical invariant in `docs/invariants.md` links to at least one test.
5. Flaky test → quarantined within 24h with an owner and an issue; quarantine > 14 days is escalated.
6. Coverage is a *signal*, not a goal: enforce a floor (e.g., 80% on `domain/` and `application/`), don't reward chasing 100%.
7. Time and randomness are injected (`clock`, `idGenerator`) — no `Date.now()` in domain code.

**Enforcement.** CI jobs per tier; Vitest coverage thresholds per path; `--retry=0` in CI (retries hide flakiness); lint rule preventing `.only`.

```ts
// vitest.config.ts (excerpt)
coverage: {
  provider: "v8",
  thresholds: {
    "src/modules/**/domain/**": { lines: 90, branches: 85 },
    "src/modules/**/application/**": { lines: 80, branches: 75 },
  },
},
```

**Expert mental model.** *"Test conventions exist so a green build means the same thing in every module: the behaviors that matter still hold."*

**Common mistake.** Mocking the database in "integration" tests, so constraint violations, transaction behavior, and SQL errors only appear in production.

---

### 4.12 Git

**What.** Conventions for repository hygiene: what is committed, history policy, ignored files, large files, tags, and protections.

**Why.** Git history is an audit trail and a debugging tool (`git bisect`, `git blame`). Committed secrets are effectively permanent leaks. Messy history destroys both uses.

**Concrete convention:**

| Concern | Convention |
|---|---|
| Default branch | `main`, protected: no direct pushes, required status checks, required review (for teams), linear history |
| Merge strategy | Squash-merge PRs (one commit per PR on `main`) *or* rebase-merge with clean commits — pick one per repo |
| Never committed | `.env*` (except `.env.example`), credentials, build output, `node_modules`, large binaries, local DB dumps, customer data |
| Secrets scanning | Pre-commit `gitleaks` + GitHub push protection; leaked secret → **rotate first**, then purge history |
| Large files | Git LFS or object storage; nothing > 5MB in repo |
| Line endings | `.gitattributes` with `* text=auto eol=lf` (critical for Windows + Linux teams) |
| Signed commits | Required for `main` in regulated contexts |
| Tags | Releases tagged `vMAJOR.MINOR.PATCH` by automation only |
| Force push | Never on `main`/release branches; allowed on your own feature branches |
| Hooks | Managed via `lefthook` or `husky`: pre-commit (format staged, lint staged, gitleaks), commit-msg (commitlint) |

```gitattributes
# .gitattributes
* text=auto eol=lf
*.png binary
*.jpg binary
*.pdf binary
pnpm-lock.yaml -diff linguist-generated
```

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    format:   { glob: "*.{ts,tsx,js,json,md,css}", run: "pnpm prettier --write {staged_files}", stage_fixed: true }
    lint:     { glob: "*.{ts,tsx}", run: "pnpm eslint --max-warnings=0 {staged_files}" }
    secrets:  { run: "gitleaks protect --staged --redact" }
commit-msg:
  commands:
    commitlint: { run: "pnpm commitlint --edit {1}" }
```

**Enforcement.** Branch protection rules (as code via Terraform GitHub provider or rulesets), hooks, push protection.

**Expert mental model.** *"History is a production artifact. Keep it clean enough to bisect and safe enough to publish."*

**Common mistake.** Committing a secret, deleting it in the next commit, and assuming it's gone. It's in history, forks, and CI caches — rotate it.

---

### 4.13 Branching

**What.** The model for how work flows through branches to production.

**Why.** Branching strategy determines integration frequency, merge conflict pain, release flexibility, and how quickly fixes reach users.

**Concrete convention — trunk-based development (default recommendation):**

```text
main ────●────●────●────●────●────●────▶  (always deployable; deploys continuously)
          \  /      \  /      \  /
  feat/ORD-142   fix/PAY-88   chore/deps
  (hours–2 days)
```

- Short-lived branches off `main`; merge within 1–2 days.
- Incomplete features merged behind **feature flags**, not held in long branches.
- `main` is always releasable; every merge deploys to staging, production by automated promotion or one click.
- **Branch names:** `<type>/<ticket>-<short-description>` → `feat/ORD-142-partial-refunds`, `fix/PAY-88-webhook-idempotency`, `chore/upgrade-next-15`.
- **Hotfixes:** same flow (branch from `main`, fast-track review). If a deployed version must be patched while `main` has unreleased risky changes, cut `release/v2.14` from the tag, cherry-pick, and merge fix back to `main`.

**When a different model is justified:**

| Model | Justified when | Cost |
|---|---|---|
| Trunk-based | Web apps/services with CI/CD and feature flags | Requires good tests and flags |
| Release branches | Mobile apps (store review), on-prem software, multiple supported versions | Cherry-pick overhead, drift |
| GitFlow (develop/release/hotfix) | Rarely today; scheduled releases with long stabilization | Long-lived branches, merge pain, slow feedback |
| Environment branches (`staging`, `prod`) | Almost never — deploy artifacts, not branches | Divergent code per environment |

**Enforcement.** Branch name check in CI; stale branch bot (warn at 3 days, close at 30); required up-to-date with `main` before merge (or merge queue).

**Expert mental model.** *"Integration pain grows with branch age. Merge small, merge often, hide incomplete work behind flags, not branches."*

**Common mistake.** Long-lived feature branches ("the big refactor branch") that diverge for weeks and become impossible to merge safely.

---

### 4.14 Commits

**What.** Conventions for commit size, content, and message format.

**Why.** Commit messages feed changelogs, semantic versioning, `git blame` archaeology, and incident timelines. Atomic commits make revert and bisect precise.

**Concrete convention — Conventional Commits:**

```text
<type>(<scope>): <imperative summary, ≤ 72 chars, no period>

<body: WHY this change, what problem, notable trade-offs; wrap at 72>

<footer: BREAKING CHANGE: ..., Refs: ORD-142, Co-authored-by: ...>
```

**Types:** `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`, `revert`, `security`.
**Scopes:** module names — `orders`, `billing`, `auth`, `ui`, `infra`, `db`.

**Examples:**

```text
feat(billing): support partial refunds on captured payments

Customers could only refund full orders, forcing support to issue
manual credits for single returned items (≈40 tickets/week).

Refunds are recorded as ledger entries; the sum of refunds is
constrained to never exceed the captured amount (ck_refunds_le_capture).

Refs: BILL-311
```

```text
fix(orders): make webhook handler idempotent on duplicate delivery

Stripe retried invoice.paid after a 12s timeout, extending two
subscriptions twice. Events are now recorded in processed_webhook_events
(unique event_id) in the same transaction as the side effect.

Refs: PAY-88
```

```text
feat(api)!: return money as {amount, currency} objects

BREAKING CHANGE: `totalCents` and `currency` fields on Order are replaced
by `total: { amount, currency }`. v1 clients remain on the old shape
until 2027-03-31 via the /v1 compatibility serializer.
```

**Rules:**
1. One logical change per commit; refactors separate from behavior changes.
2. Every commit on `main` builds and passes tests (bisectable).
3. The body explains **why**; the diff explains what.
4. No "wip", "fix stuff", "address review comments" on `main` (squash them).

**Enforcement.** `commitlint` with `@commitlint/config-conventional` in `commit-msg` hook and in CI for PR titles (when squash-merging, the PR title becomes the commit):

```js
// commitlint.config.js
export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "scope-enum": [2, "always", ["orders", "billing", "auth", "catalog", "ui", "api", "db", "infra", "deps", "ci"]],
    "subject-case": [2, "never", ["upper-case", "pascal-case", "start-case"]],
    "header-max-length": [2, "always", 72],
  },
};
```

Then `semantic-release` or `changesets` generates versions and changelogs.

**Expert mental model.** *"A commit message is a note to the engineer debugging an incident in two years. Tell them why."*

**Common mistake.** Mixing a formatting sweep, a refactor, and a bug fix in one commit — impossible to review, impossible to revert selectively.

---

### 4.15 Pull Requests

**What.** Conventions for PR size, description, readiness, checks, and merge criteria.

**Why.** The PR is where code becomes shared responsibility. Good PR conventions make review fast and effective; bad ones make it a formality.

**Concrete convention:**

| Concern | Convention |
|---|---|
| Size | Target < 400 changed lines of non-generated code; > 800 requires justification or splitting |
| Scope | One purpose per PR; no "while I was here" changes |
| Title | Conventional Commit format (becomes squash commit) |
| Draft | Open as draft early for design feedback; mark ready when checks pass |
| Description | Template: context, change summary, risk, testing evidence, rollout/rollback, screenshots for UI |
| Checks | All required CI green before requesting review |
| Self-review | Author reviews own diff first and annotates non-obvious parts |
| Migrations | Called out explicitly; backward compatible with currently deployed code |
| Review SLA | First response within 1 business day (4h target) |
| Approval | ≥ 1 approval; CODEOWNERS for sensitive paths (`auth/`, `billing/`, `db/migrations/`, `infra/`) |
| Merge | Author merges after approval (they own the rollout) |

**PR template** (full version in [templates/pull-request.md](templates/pull-request.md)):

```md
## Why
<!-- Problem, user impact, link to issue/ADR -->

## What changed
<!-- Bullet summary; point reviewers to the important files -->

## Risk
- [ ] Touches authentication/authorization
- [ ] Touches money, inventory, or other invariants (list them)
- [ ] Database migration (backward compatible with current prod? Y/N)
- [ ] Changes a public API/contract
- [ ] New dependency (name, why, license, maintenance status)

## How I verified
<!-- Tests added, manual steps, screenshots, query plans, load test numbers -->

## Rollout & rollback
<!-- Feature flag? Canary? What to watch (dashboard link)? How to roll back? -->
```

**Enforcement.** Template auto-applied; CI "PR size" check labels large PRs; `danger.js` rules (e.g., migration changed but no mention in description → fail; `package.json` changed without lockfile → fail):

```ts
// dangerfile.ts
import { danger, fail, warn } from "danger";
const touched = [...danger.git.modified_files, ...danger.git.created_files];
if (touched.some(f => f.startsWith("db/migrations/")) && !/migration/i.test(danger.github.pr.body)) {
  fail("This PR adds a migration. Describe backward compatibility in the Risk section.");
}
if (touched.includes("package.json") && !touched.includes("pnpm-lock.yaml")) {
  fail("package.json changed without pnpm-lock.yaml.");
}
const { additions, deletions } = danger.github.pr;
if (additions + deletions > 800) warn("Large PR (>800 lines). Consider splitting.");
```

**Expert mental model.** *"A PR is a request for someone to share responsibility for a production change. Make it cheap for them to do that well."*

**Common mistake.** Descriptions like "fixes bug" — the reviewer must reverse-engineer intent from the diff, so they review the syntax instead of the design.

---

### 4.16 Code Review

**What.** Conventions for how reviewers review: priorities, comment labels, tone, turnaround, and what's delegated to automation.

**Why.** Review conventions keep review focused on high-value issues, prevent both rubber-stamping and bikeshedding, and make feedback unambiguous.

**Concrete convention:**

**Review priority order** (spend attention top-down):

```text
1. Correctness & invariants     — Does it do the right thing? What must stay true?
2. Security                     — AuthZ on every path? Input parsed? Data exposure?
3. Failure handling             — Timeouts? Retries safe? Idempotent? Partial failure?
4. Data & migrations            — Constraints? Backward compatible? Locks?
5. Design fit                   — Right module? Right boundary? Follows conventions?
6. Tests                        — Do tests prove the risky behavior? Would they fail if it broke?
7. Operability                  — Logs/metrics for new paths? Rollback plan?
8. Readability                  — Could someone else safely change this?
9. Style                        — Should be automated; humans shouldn't comment on it
```

**Comment labels** (inspired by Conventional Comments):

| Label | Meaning | Blocks merge? |
|---|---|---|
| `blocking:` | Must be addressed | Yes |
| `question:` | Reviewer needs understanding; may become blocking | Until answered |
| `suggestion:` | Improvement worth considering | No |
| `nit:` | Minor, optional | No |
| `praise:` | Something done well, worth repeating | No |
| `followup:` | Valid but out of scope → create issue | No |

**Tone rules:** comment on code, not people; explain *why*; offer a concrete alternative; ask before assuming ("Is there a reason we don't lock here?").

**Reviewer checklist for high-risk areas:**

```text
□ Every new data access is tenant/owner scoped
□ Every new external call has a timeout
□ Every new mutation reachable by retry/webhook/queue is idempotent
□ Every new status transition is legal per the state machine
□ Migration is safe to run while the old version is still serving traffic
□ No secrets, PII, or tokens in logs, errors, or client bundles
□ New env vars added to env schema and .env.example
□ Errors use AppError codes; no swallowed exceptions
□ Tests would fail if the core behavior regressed
```

**Enforcement.** CODEOWNERS; required reviews; formatting/lint/type/security checks automated so humans skip them; review latency dashboard; AI review bots as first pass (not approval) — see [13-ai-and-agents.md](13-ai-and-agents.md).

**Expert mental model.** *"Review what machines can't: intent, invariants, failure, and fit. If a human comments on formatting, a tool is missing."*

**Common mistake.** Approving large PRs quickly because "it's too big to review properly" — the largest changes carry the most risk and get the least scrutiny.

---

<!-- CONTINUE -->
