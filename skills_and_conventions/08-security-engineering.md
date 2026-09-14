# 08 — Security Engineering

> Amateurs ask "does this feature work?" Experts also ask "how can this feature be abused, by whom, and what would it cost?" This chapter explains the attacker mindset and turns it into an engineering process: threat modeling with STRIDE, trust boundaries, authentication, authorization, tenant isolation, validation, data exposure, secrets, API and database security, supply-chain security, audit logging, Next.js-specific pitfalls, and security enforced as automated gates rather than good intentions.

Related chapters: [03-how-experts-design.md](03-how-experts-design.md) (security boundaries during design), [07-designing-for-failure.md](07-designing-for-failure.md) (abuse and failure overlap), [09-invariants-and-correctness.md](09-invariants-and-correctness.md) ("users cannot access another tenant's data" is an invariant), [10-knowledge-into-systems.md](10-knowledge-into-systems.md) (turning security knowledge into CI gates), [02-engineering-conventions.md](02-engineering-conventions.md) (auth, validation, logging conventions), [templates/threat-model.md](templates/threat-model.md).

---

## Table of Contents

1. [The Attacker Mindset](#1-the-attacker-mindset)
2. [Assume the Client Is Hostile: Core Principles](#2-assume-the-client-is-hostile-core-principles)
3. [Trust Boundaries](#3-trust-boundaries)
4. [Threat Modeling with STRIDE — Fully Worked Example](#4-threat-modeling-with-stride--fully-worked-example)
5. [Authentication](#5-authentication)
6. [Sessions, Cookies, and CSRF](#6-sessions-cookies-and-csrf)
7. [Authorization: RBAC, ABAC, ReBAC, and Centralized Policy](#7-authorization-rbac-abac-rebac-and-centralized-policy)
8. [IDOR / BOLA: The Most Common Serious API Bug](#8-idor--bola-the-most-common-serious-api-bug)
9. [Least Privilege: Database Roles and Cloud IAM](#9-least-privilege-database-roles-and-cloud-iam)
10. [Tenant Isolation and PostgreSQL Row-Level Security](#10-tenant-isolation-and-postgresql-row-level-security)
11. [Input Validation at Boundaries and Output Encoding](#11-input-validation-at-boundaries-and-output-encoding)
12. [Data Exposure: DTO Allowlists and Over-Fetching](#12-data-exposure-dto-allowlists-and-over-fetching)
13. [Secrets Management](#13-secrets-management)
14. [API Security: Rate Limiting, Mass Assignment, SSRF, Webhooks, OWASP API Top 10](#14-api-security-rate-limiting-mass-assignment-ssrf-webhooks-owasp-api-top-10)
15. [Database Security](#15-database-security)
16. [Supply-Chain Security](#16-supply-chain-security)
17. [Audit Logging](#17-audit-logging)
18. [Next.js-Specific Security Pitfalls](#18-nextjs-specific-security-pitfalls)
19. [Security as Automated Gates in CI/CD](#19-security-as-automated-gates-in-cicd)
20. [Amateur vs Professional vs Expert](#20-amateur-vs-professional-vs-expert)
21. [Key Takeaways](#21-key-takeaways)
22. [Self-Assessment Checklist](#22-self-assessment-checklist)

---

## 1. The Attacker Mindset

### What

The attacker mindset is the discipline of reading every feature as an **attack surface**: an input channel, a capability, and a set of assumptions that someone may deliberately violate. For each feature, you ask:

```text
Who can call this?            (anonymous, any user, tenant admin, internal service, attacker with stolen token)
What can they control?        (every field, header, cookie, file, URL, timing, order, volume)
What do they gain if it breaks? (money, data, access, disruption, reputation damage, pivot to other systems)
What assumption am I making?  ("the UI hides this button", "IDs are unguessable", "only our app calls this")
How would I know it was abused? (logs, alerts, audit trail)
```

### Why

Functional testing proves a feature works for **cooperative** users. Attackers are not cooperative: they replay requests, change IDs, send negative quantities, upload SVGs with scripts, call endpoints the UI never calls, and automate at thousands of requests per second. Security failures are also **asymmetric**: defenders must cover every path; attackers need one. And the cost is non-linear: a single IDOR in an export endpoint can leak every customer's data, triggering breach notification laws, regulatory fines, and lost enterprise deals.

### How

Build abuse cases alongside use cases:

| Use case | Abuse cases |
|---|---|
| "User applies a discount code" | Brute-force codes; apply same single-use code in 20 parallel requests (race); apply code to another tenant's cart; stack codes via API that UI forbids |
| "User uploads a profile picture" | Upload 2 GB file; upload HTML/SVG with JS served from your origin; path traversal in filename; polyglot file; EXIF GPS leakage |
| "Invite teammate by email" | Invite yourself into another org by guessing invite tokens; enumerate which emails have accounts; spam arbitrary emails from your domain |
| "Export invoices as CSV" | Export another tenant's invoices by changing `tenantId`; CSV formula injection (`=HYPERLINK(...)`) executed in Excel; export 10M rows to DoS |
| "Webhook URL configuration" | SSRF to `http://169.254.169.254/` cloud metadata; internal port scanning via response timing |
| "Password reset" | Account enumeration via different messages; token not expiring; token in `Referer` to third-party analytics; Host-header poisoning of reset links |

### Example — a discount-code endpoint through the attacker lens

```ts
// Looks fine functionally
export async function POST(req: Request) {
  const { cartId, code } = await req.json();
  const promo = await db.promo.findUnique({ where: { code } });
  if (!promo || promo.usedCount >= promo.maxUses) return Response.json({ error: 'Invalid code' }, { status: 400 });
  await db.cart.update({ where: { id: cartId }, data: { promoId: promo.id } });
  await db.promo.update({ where: { id: promo.id }, data: { usedCount: promo.usedCount + 1 } });
  return Response.json({ ok: true });
}
```

Attack analysis:
1. **No authentication/ownership check** on `cartId` → attach promos to any cart (BOLA).
2. **Race condition:** 50 parallel requests all read `usedCount = 0` → single-use code used 50 times.
3. **Enumeration:** unlimited attempts → brute-force short codes.
4. **Input:** `code` not validated → could be an object in some ORMs (`{ "not": "" }`-style operator injection in query builders that accept objects).
5. **No audit trail** of who applied what.

Hardened version:

```ts
const Body = z.object({ cartId: z.string().uuid(), code: z.string().trim().toUpperCase().regex(/^[A-Z0-9]{6,20}$/) });

export async function POST(req: Request) {
  const session = await requireSession();                                  // authN
  await rateLimit(`promo:${session.userId}`, { limit: 10, windowSec: 600 }); // anti-enumeration
  const { cartId, code } = Body.parse(await req.json());                    // validation

  const result = await db.$transaction(async (tx) => {
    const cart = await tx.cart.findFirst({ where: { id: cartId, userId: session.userId, status: 'open' } }); // ownership
    if (!cart) throw new NotFound();                                         // 404, not 403: don't confirm existence

    // Atomic claim: check-and-increment in one statement
    const claimed = await tx.$executeRaw`
      UPDATE promos SET used_count = used_count + 1
       WHERE code = ${code} AND used_count < max_uses AND now() BETWEEN starts_at AND ends_at
       RETURNING id`;
    if (claimed === 0) throw new InvalidPromo();

    const promo = await tx.promo.findUniqueOrThrow({ where: { code } });
    await tx.promoRedemption.create({ data: { promoId: promo.id, userId: session.userId, cartId } }); // UNIQUE(promo_id, user_id)
    await tx.cart.update({ where: { id: cart.id }, data: { promoId: promo.id } });
    return promo;
  });

  await audit({ actor: session.userId, action: 'promo.applied', target: cartId, meta: { promoId: result.id } });
  return Response.json({ ok: true });
}
```

### Expert Mental Model

> "Every input is chosen by someone who may want to hurt me. Every check the UI performs, the server must perform again. Every capability I expose, I must bound by identity, ownership, rate, and size."

### Common Mistake

Security thinking deferred to "a pentest before launch". Pentests find a sample of bugs; they don't create a secure design. By the time a pentest finds that authorization is scattered across 140 route handlers, fixing it is a rewrite.

---

## 2. Assume the Client Is Hostile: Core Principles

```text
Assume the client can be hostile.
Assume inputs can be malicious.
Assume boundaries will be tested.
Assume credentials will leak.
Assume dependencies can be compromised.
Assume insiders can make mistakes (or worse).
```

These translate into concrete engineering principles:

| Principle | Meaning | Concrete practice |
|---|---|---|
| **Never trust the client** | Browser, mobile app, CLI, and partner integrations can be modified or replaced by `curl` | Server recomputes prices, permissions, totals, eligibility; client-side validation is UX only |
| **Validate at every trust boundary** | Parse untrusted data into typed, constrained values at entry | zod schemas on every route, webhook, queue message, and third-party response |
| **Deny by default** | Absence of an explicit allow = deny | Route-level auth required unless marked public; policy engine returns `deny` for unknown actions |
| **Least privilege** | Every identity gets the minimum permissions needed | Separate DB roles; scoped cloud IAM; short-lived tokens; per-tenant API keys with scopes |
| **Defense in depth** | Multiple independent layers, so one bug isn't a breach | App authz + RLS + network policies + encryption + monitoring |
| **Minimize attack surface** | Fewer endpoints, fields, dependencies, and privileges = fewer bugs | Remove unused routes; DTO allowlists; disable debug endpoints in prod |
| **Secure defaults** | The easy path is the secure path | Framework wrapper where `authedAction()` is shorter to write than raw `'use server'` |
| **Fail closed** | When a security check errors, deny | If the policy service times out → 503, not "allow" |
| **Complete mediation** | Every access is checked, every time — no caching of decisions past their validity | Check authz per request and per object, not once at login |
| **Separation of duties** | Critical actions require more than one person or factor | Refunds > $10k require second approval; production DB access requires break-glass with audit |
| **Assume breach** | Design so that one compromise is contained and detected | Tenant isolation; encrypted secrets; audit logs shipped off-host; anomaly alerts |
| **Don't roll your own crypto/auth** | Use vetted libraries and protocols | argon2id via libraries, OIDC providers, `crypto.timingSafeEqual`, platform KMS |

### Example — "hidden" fields and prices

```tsx
// Client component: the price here is DISPLAY ONLY
<form action={addToCart}>
  <input type="hidden" name="productId" value={product.id} />
  <input type="hidden" name="price" value={product.priceMinor} />   {/* attacker sets to 1 */}
  <button>Add to cart</button>
</form>
```

```ts
// Server: never read price from the client
'use server';
export async function addToCart(formData: FormData) {
  const session = await requireSession();
  const { productId, quantity } = AddToCart.parse(Object.fromEntries(formData));
  const product = await db.product.findFirstOrThrow({ where: { id: productId, active: true } });
  await db.cartItem.upsert({
    where: { cartId_productId: { cartId: session.cartId, productId } },
    create: { cartId: session.cartId, productId, quantity, unitPriceMinor: product.priceMinor },
    update: { quantity: { increment: quantity } },
  });
}
```

---

## 3. Trust Boundaries

### What

A **trust boundary** is any line where data or control passes between components with different levels of trust. Crossing a boundary is exactly where validation, authentication, authorization, and encoding must happen.

### Why

Most vulnerabilities are a failure to re-establish trust at a boundary: SQL injection (user → DB query), XSS (user data → HTML), SSRF (user URL → internal network), IDOR (user → object access), deserialization (network bytes → objects).

### How — common boundaries in a Next.js + API + PostgreSQL SaaS

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│  UNTRUSTED: Internet                                                              │
│   Browser (user, possibly attacker)   Partner systems   PSP webhooks   Scrapers   │
└───────────────┬──────────────────────────────┬───────────────┬───────────────────┘
                │ TB1: HTTPS → edge/CDN/WAF      │ TB1           │ TB1
┌───────────────▼──────────────────────────────▼───────────────▼───────────────────┐
│  SEMI-TRUSTED: Edge / Next.js server (authenticated context established here)     │
│   Middleware (coarse checks) → Route handlers / Server Actions / RSC              │
└───────────────┬───────────────────────────────────────────────┬──────────────────┘
                │ TB2: app → data layer (authz per object)       │ TB3: app → third parties
┌───────────────▼────────────────────┐              ┌────────────▼─────────────────┐
│  TRUSTED: PostgreSQL (RLS), Redis,  │              │  EXTERNAL: PSP, email, tax,  │
│  object storage, queue              │              │  AI APIs (responses untrusted)│
└───────────────┬────────────────────┘              └──────────────────────────────┘
                │ TB4: workers consume queue messages (validate again)
┌───────────────▼────────────────────┐
│  Workers / cron (service identity)  │
└────────────────────────────────────┘
TB5: Server Components → Client Components (serialization boundary: what data leaves the server)
TB6: CI/CD → production (who can deploy, which secrets pipelines hold)
TB7: Tenant A ↔ Tenant B (logical boundary inside shared infrastructure)
```

At each boundary, record: **what identity is established, what is validated, what is authorized, what is encoded, what is logged.**

| Boundary | Establish identity | Validate | Authorize | Encode/sanitize | Log |
|---|---|---|---|---|---|
| TB1 Browser → server | Session cookie / bearer token | zod on body, query, params, headers | Route policy | — | Request ID, user, tenant |
| TB1 Webhook → server | HMAC signature + timestamp | zod on event | Event type allowlist | — | Event ID |
| TB2 App → DB | DB role; `app.tenant_id` session var | Parameterized queries | RLS + app policy | — | Slow/failed queries |
| TB3 App → third party | Our API key | Validate responses (zod) | Egress allowlist | URL-encode params | Dependency call metrics |
| TB4 Queue → worker | Service identity | Validate message schema | Worker acts with tenant scope from message, re-checked | — | Message ID |
| TB5 Server → Client component | — | — | Only pass DTOs | React auto-escapes; avoid `dangerouslySetInnerHTML` | — |
| TB6 CI → prod | OIDC federation, no static keys | Signed artifacts | Protected environments, required reviewers | — | Deploy audit |
| TB7 Tenant ↔ tenant | Tenant from session, never from input | — | Tenant scoping + RLS | — | Cross-tenant access attempts |

### Expert Mental Model

> "Data doesn't become trustworthy by being inside my network. It becomes trustworthy only after it has been authenticated, validated, and authorized at the boundary it just crossed."

### Common Mistake

Treating internal services, queue messages, or data from your own database as trusted by default. Stored XSS is exactly "data from our own database rendered unsafely". Internal endpoints without auth become the pivot after one SSRF.

---

## 4. Threat Modeling with STRIDE — Fully Worked Example

### What

**Threat modeling** is a structured way to find security design flaws before writing code, by answering four questions (Adam Shostack's framing):

1. What are we building?
2. What can go wrong?
3. What are we going to do about it?
4. Did we do a good job?

**STRIDE** is a checklist of threat categories, each violating a security property:

| Letter | Threat | Property violated | Typical examples |
|---|---|---|---|
| **S** | Spoofing | Authentication | Stolen session, forged webhook, fake service identity |
| **T** | Tampering | Integrity | Modified price in request, altered file in storage, MITM |
| **R** | Repudiation | Non-repudiation | "I never approved that refund" and no audit log proves otherwise |
| **I** | Information disclosure | Confidentiality | IDOR, verbose errors, leaky logs, over-fetched API fields |
| **D** | Denial of service | Availability | Unbounded exports, regex DoS, login flooding |
| **E** | Elevation of privilege | Authorization | Member promotes self to admin via mass assignment |

### Why

Design-level flaws (missing tenant isolation, trusting client-provided roles, no webhook authenticity) are expensive to fix after implementation and are not found by linters. A 60–90 minute threat model for a significant feature is one of the highest-ROI security activities available.

### How

1. **Scope** a feature or system; draw a data-flow diagram (DFD): external entities, processes, data stores, data flows.
2. **Mark trust boundaries** on the DFD.
3. **For each element and each flow crossing a boundary, walk STRIDE.**
4. **Rate** each threat (likelihood × impact, or DREAD-lite, or simply High/Med/Low).
5. **Decide:** mitigate, eliminate (remove feature), transfer (use a provider), or accept (documented, owned).
6. **Turn mitigations into tickets, tests, and CI checks.**
7. **Revisit** when the design changes.

Use [templates/threat-model.md](templates/threat-model.md).

### Worked example — "Invoicing SaaS: shareable invoice links and online payment"

**Feature:** Tenants (small businesses) create invoices in a Next.js dashboard. They can send customers a public link to view the invoice and pay by card. Customers can download a PDF. Payments go through a PSP (Stripe-like) with webhooks. Tenant admins can issue refunds.

#### Step 1 — Data-flow diagram

```text
                               TB1 (Internet)
  ┌───────────────┐   HTTPS    ┌──────────────────────────────────────────────┐
  │ Tenant user   │──────────▶ │ P1: Next.js app (dashboard, server actions)  │
  │ (browser)     │◀────────── │                                              │
  └───────────────┘            │ P2: Public invoice page /i/[token]           │
  ┌───────────────┐   HTTPS    │                                              │
  │ Invoice payer │──────────▶ │ P3: Webhook handler /api/webhooks/psp        │
  │ (anonymous)   │◀────────── └──────┬────────────────┬────────────────┬─────┘
  └───────────────┘                   │ TB2            │ TB3            │ TB3
                                      ▼                ▼                ▼
                         ┌─────────────────────┐  ┌──────────┐   ┌──────────────┐
                         │ DS1: PostgreSQL     │  │ DS2: S3  │   │ E1: PSP API  │
                         │ tenants, users,     │  │ PDFs     │   │              │
                         │ invoices, payments, │  └──────────┘   └──────┬───────┘
                         │ audit_log           │                        │ webhooks (TB1)
                         └─────────┬───────────┘                        ▼
                                   │ TB4                          back to P3
                         ┌─────────▼───────────┐
                         │ P4: PDF worker      │
                         │ (queue consumer)    │
                         └─────────────────────┘
```

Flows:
- F1 Tenant user ↔ P1 (session cookie)
- F2 Payer → P2 (invoice token in URL)
- F3 P2 → E1 create checkout session
- F4 E1 → P3 webhook `payment_succeeded`
- F5 P1/P2/P3 ↔ DS1
- F6 P4 → DS2 upload PDF; P2 → payer presigned download URL
- F7 P1 → E1 refunds

#### Step 2 — STRIDE walk (abridged to the meaningful threats)

| ID | Element / flow | STRIDE | Threat | Likelihood | Impact | Risk |
|---|---|---|---|---|---|---|
| T1 | P2 invoice link | I | Invoice tokens guessable (sequential IDs `/i/1043`) → anyone enumerates all invoices (names, addresses, amounts) | High | High | **Critical** |
| T2 | P2 invoice link | I | Link leaked via `Referer` to third-party scripts, browser history, email forwarding; never expires | Med | Med | High |
| T3 | P3 webhook | S | Attacker POSTs fake `payment_succeeded` → invoice marked paid without payment | High | High | **Critical** |
| T4 | P3 webhook | T/R | Replay of old genuine webhook for a different invoice amount | Med | Med | Medium |
| T5 | F3 checkout creation | T | Payer modifies amount/currency in request to pay $1 | High | High | **Critical** |
| T6 | P1 dashboard | E | Tenant member (role `viewer`) calls refund server action directly (UI hides button only) | High | High | **Critical** |
| T7 | P1 dashboard | I/E | Tenant A user fetches Tenant B invoice via `getInvoice(id)` server action (BOLA) | High | High | **Critical** |
| T8 | P1 update invoice | E | Mass assignment: body includes `tenantId` or `status: 'paid'` | Med | High | High |
| T9 | F7 refunds | R | Admin issues refund and denies it; no record of who | Med | Med | Medium |
| T10 | F7 refunds | T | Refund amount > paid amount; repeated refunds via double-submit | Med | High | High |
| T11 | P4 PDF worker | E/I | Invoice notes containing HTML rendered by headless browser → SSRF to cloud metadata / local file read | Med | High | High |
| T12 | DS2 S3 | I | Bucket or objects public; predictable keys | Low | High | Medium |
| T13 | P2 public page | D | Scraping/brute force of tokens; PDF generation flood | Med | Med | Medium |
| T14 | DS1 | I | SQL injection via invoice search filter | Low | High | Medium |
| T15 | P1 login | S | Credential stuffing against tenant users | High | High | High |
| T16 | P1 | S/T | CSRF: malicious site triggers refund while admin is logged in | Low (SameSite) | High | Medium |
| T17 | Logs | I | Full card/PII or invoice tokens written to logs; logs broadly accessible | Med | Med | Medium |
| T18 | CSV export | T | CSV formula injection in customer name executed in admin's Excel | Med | Med | Medium |
| T19 | Supply chain | E | Compromised npm dependency in PDF worker exfiltrates env secrets | Low | Critical | High |

#### Step 3 — Mitigations

| ID | Mitigation | Verification (test / check) |
|---|---|---|
| T1 | Public token = 32 bytes random (base64url, 256 bits), stored as **SHA-256 hash**; lookup by hash; separate from internal UUID | Unit test: token entropy/length; integration: sequential ID route returns 404 |
| T2 | `Referrer-Policy: no-referrer` on `/i/*`; no third-party scripts on public page; token expires (e.g. 90 days) and is revocable; page shows limited PII (no full address) | Header test in e2e; expiry test |
| T3 | Verify PSP signature with raw body and timestamp tolerance ≤ 5 min; handle only allowlisted event types; **re-fetch** the payment object from PSP API before marking paid | Test: invalid signature → 400, no DB change; test: unsigned event rejected |
| T4 | Inbox dedup on PSP event ID; match PSP amount/currency/metadata `invoice_id` against DB invoice before transition | Test: replayed event → no-op; mismatched amount → alert |
| T5 | Server derives amount/currency from DB invoice; request body contains only token | Test: extra `amount` field ignored (strict zod schema rejects unknown keys) |
| T6 | Centralized policy `can(user, 'invoice.refund', invoice)`; every server action wrapped by `authedAction` requiring permission | Authz matrix test: each role × action; lint rule forbidding raw `'use server'` exports without wrapper |
| T7 | All queries scoped by `tenant_id` from session; PostgreSQL RLS as backstop | Cross-tenant test suite: user from tenant A attempts every read/write on tenant B resources → 404 |
| T8 | zod `.strict()` DTO with allowlisted fields; `status` only changes through state-machine commands | Test: payload with `tenantId`/`status` rejected |
| T9 | Append-only `audit_log` with actor, action, target, before/after, IP, user agent, request ID | Test: refund creates audit row; DB role can't UPDATE/DELETE audit_log |
| T10 | Refund amount ≤ `captured − refunded` enforced in tx + CHECK constraint; idempotency key; refunds > threshold require second approver | Concurrency test: 10 parallel refunds → total ≤ captured |
| T11 | Render PDFs from structured data with a template engine that escapes; headless browser (if used) runs with JS disabled, network egress blocked, no file:// access, in isolated container | Test: note `<img src="http://169.254.169.254/...">` → rendered as text, no outbound request |
| T12 | Bucket Block Public Access; SSE-KMS; keys `tenant/<uuid>/invoice/<uuid>.pdf`; short-lived presigned URLs (5 min) generated after token check | IaC policy check (Checkov/tfsec); test presigned expiry |
| T13 | Rate limit `/i/*` per IP (e.g. 60/min) and failed-token lookups (10/min, then CAPTCHA); cache generated PDFs | Load test; rate-limit test |
| T14 | Parameterized queries only; search filters mapped from allowlisted enum of columns | Semgrep rule blocking string-concatenated SQL; SQLi test cases |
| T15 | Rate limiting + breached password check + MFA for admins (TOTP/WebAuthn); login anomaly alerts | Test: 11th failed login within window → throttled |
| T16 | `SameSite=Lax` session cookie; server actions (Next.js checks Origin vs Host); explicit CSRF token/Origin check for custom route handlers accepting cookies | Test: cross-origin POST rejected |
| T17 | Structured logging with redaction list (`authorization`, `cookie`, `token`, `password`, `card*`); PSP handles card data (no PAN touches our servers — reduces PCI scope to SAQ A) | Log redaction unit test |
| T18 | CSV export prefixes cells starting with `= + - @ \t \r` with `'` | Unit test |
| T19 | Lockfile + `npm ci`; `ignore-scripts` by default; Dependabot/Renovate with review; worker has only S3-put permission for its prefix, no DB superuser | CI: `npm audit signatures`, OSV scan; IAM policy review |

#### Step 4 — Residual risk & accepted risks

| Risk | Decision | Owner | Review date |
|---|---|---|---|
| Invoice link forwarded by the payer to others | **Accepted**: equivalent to forwarding a paper invoice; mitigated by limited PII and expiry | Product lead | 2027-03 |
| PSP outage prevents payments | **Transferred/accepted**: PSP SLA; show "try later" | Eng lead | — |

#### Step 5 — Did we do a good job?

- All Critical/High threats have a mitigation **and** a verification.
- Tests T3, T6, T7, T10 are in CI as a "security regression" suite.
- The threat model is linked from the design doc ([templates/design-doc.md](templates/design-doc.md)) and the ADR for "public invoice tokens" ([templates/adr.md](templates/adr.md)).

### Expert Mental Model

> "Threat modeling isn't a document; it's a disciplined conversation that produces tests. If a threat doesn't end in a mitigation with a verification, or an explicitly accepted risk with an owner, the exercise isn't finished."

### Common Mistake

- A 40-page threat model for the whole company, done once, never updated.
- Listing generic threats ("hackers could attack") without tying them to specific flows and controls.
- Mitigations without verification ("we'll validate input") — nobody checks it happened.

<!-- CONTINUE -->