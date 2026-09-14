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

<!-- CONTINUE -->
