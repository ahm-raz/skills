# Manifest: G1 Gap Pass (Next.js full-stack gaps)

Last Verified: 2026-09-15. Next.js version confirmed from nextjs.org/docs front-matter: **16.3.5**.
Research method: WebFetch against official docs and READMEs only (WebSearch quota exhausted).

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| nextjs-draft-mode-and-cms-preview | Next.js Draft Mode and CMS Preview | Next.js | Next.js (App Router), React (Vite SPA) notes | A | Active | https://nextjs.org/docs/app/guides/draft-mode |
| nextjs-after-and-post-response-work | Next.js after() and Post-Response Work | Next.js | Next.js (App Router), React (Vite SPA) notes | A | Active | https://nextjs.org/docs/app/api-reference/functions/after |
| nextjs-mdx-content | MDX Content in Next.js | Next.js | Next.js (App Router), React (Vite SPA) notes | B | Active | https://nextjs.org/docs/app/guides/mdx |
| stripe-payments-in-nextjs | Stripe Payments in Next.js | Product Patterns | Next.js (App Router), React (Vite SPA) notes | A | Active | https://docs.stripe.com/webhooks |
| transactional-email-with-react-email | Transactional Email with React Email | Product Patterns | Next.js (App Router), React (Vite SPA) notes | B | Active | https://react.email/docs/getting-started/manual-setup |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Next.js Guide: Draft Mode | https://nextjs.org/docs/app/guides/draft-mode | Official | Enable route, secret + slug validation, CMS-sourced redirect, banner/exit via Server Action, Cache Components behavior, separate draft endpoint | Canonical Draft Mode behavior for 16.3.x | S | 2026-09-15 |
| Next.js API: draftMode | https://nextjs.org/docs/app/api-reference/functions/draft-mode | Official | Methods, `__prerender_bypass`, per-build cookie value, cache-scope rules, Link prefetch caveat | Security and cache-scope constraints | S | 2026-09-15 |
| Next.js API: after | https://nextjs.org/docs/app/api-reference/functions/after | Official | Callers, duration, request API rules per caller, Cache Components, platform support, waitUntil contract, version history | Canonical `after()` semantics | S | 2026-09-15 |
| Next.js Guide: Self-hosting | https://nextjs.org/docs/app/guides/self-hosting | Official | Graceful shutdown for `after`, Draft Mode Cache-Control header | Self-host correctness | S | 2026-09-15 |
| Next.js API: maxDuration | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration | Official | Syntax; page-level setting for Server Actions | Bounds `after` work | S | 2026-09-15 |
| Next.js Guide: MDX | https://nextjs.org/docs/app/guides/mdx | Official | @next/mdx setup, required mdx-components, frontmatter options, dynamic imports, Turbopack string plugins, sanitize pipeline, mdxRs experimental | Canonical MDX setup | S | 2026-09-15 |
| Vercel @vercel/functions reference | https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package | Official | `waitUntil` semantics and timeout, `getDeadline`, recommendation to use `after` on Next ≥15.1 | Platform behavior | A | 2026-09-15 |
| Inngest Next.js quick start | https://www.inngest.com/docs/getting-started/nextjs-quick-start | Official | `serve()` route, `createFunction`, `inngest.send`, steps | Durable queue alternative | A | 2026-09-15 |
| Upstash QStash Next.js quickstart | https://upstash.com/docs/qstash/quickstarts/vercel-nextjs | Official | `publishJSON`, `verifySignatureAppRouter`, env vars, retries | Durable queue alternative | A | 2026-09-15 |
| Trigger.dev Next.js guide | https://trigger.dev/docs/guides/frameworks/nextjs | Official | `tasks.trigger`, execution on Trigger.dev infra, `TRIGGER_SECRET_KEY` | Long-running job alternative | A | 2026-09-15 |
| Sanity Visual Editing with Next.js App Router | https://www.sanity.io/docs/visual-editing/visual-editing-with-next-js-app-router | Official | `defineEnableDraftMode`, `VisualEditing`, `defineLive`, stega, viewer token, Presentation previewUrl | CMS visual editing | A | 2026-09-15 |
| Payload Preview | https://payloadcms.com/docs/admin/preview | Official | `admin.preview`, preview secret route, `draft: isDraftMode`, Preview vs Live Preview | CMS preview | A | 2026-09-15 |
| Contentful Live Preview | https://www.contentful.com/developers/docs/tutorials/general/live-preview/ | Official | Not extracted (HTTP 429 twice); referenced with "Check current docs" | CMS preview coverage | C | 2026-09-15 |
| next-mdx-remote README | https://raw.githubusercontent.com/hashicorp/next-mdx-remote/main/README.md | Open Source | Archived status, RSC API, `blockJS`/`blockDangerousJS` defaults, user-input warning | Security and deprecation guidance | A | 2026-09-15 |
| content-collections README | https://raw.githubusercontent.com/sdorra/content-collections/main/README.md | Open Source | Purpose, collection definition, MDX packages, status | Content layer option | B | 2026-09-15 |
| Velite with Next.js | https://velite.js.org/guide/with-nextjs | Open Source | Config-based start, webpack plugin incompatible with Turbopack | Content layer option | B | 2026-09-15 |
| Fumadocs README | https://raw.githubusercontent.com/fuma-nama/fumadocs/main/README.md | Open Source | Scope, official Next.js support, ESM-only | Docs framework option | B | 2026-09-15 |
| Rehype Pretty Code | https://rehype-pretty.pages.dev/ | Open Source | Shiki-based build-time highlighting, dual themes, data attributes | Syntax highlighting | A | 2026-09-15 |
| Stripe: How Checkout works (Elements variant) | https://docs.stripe.com/payments/checkout/how-checkout-works | Official | Session lifecycle for hosted, embedded, Elements | Integration choice | S | 2026-09-15 |
| Stripe API: Create Checkout Session | https://docs.stripe.com/api/checkout/sessions/create | Official | `ui_mode` enum (`hosted_page` default, `embedded_page`, `form`, `elements`) | Exact parameter values | S | 2026-09-15 |
| Stripe Checkout quickstart (Next.js) | https://docs.stripe.com/checkout/quickstart?client=next | Official | server-only client, redirect 303, success page retrieve, env var names, CLI listen | Next.js-specific wiring | S | 2026-09-15 |
| Stripe Embedded Checkout quickstart (Next.js) | https://docs.stripe.com/checkout/embedded/quickstart?client=next | Official | `embedded_page`, Server Action client secret, `EmbeddedCheckoutProvider` | Embedded flow | S | 2026-09-15 |
| Stripe: Fulfill orders | https://docs.stripe.com/checkout/fulfillment | Official | Idempotent fulfill function, async payment events, landing-page trigger, 10s redirect wait | Reliable fulfillment | S | 2026-09-15 |
| Stripe: Webhooks | https://docs.stripe.com/webhooks | Official | Raw body, signature verification, 5-min tolerance, retries, ordering, duplicates, secret rolling, IP allowlist | Webhook security | S | 2026-09-15 |
| Stripe API: Idempotent requests | https://docs.stripe.com/api/idempotent_requests | Official | Key format, 24h pruning, param mismatch, POST-only | Prevent double charges | S | 2026-09-15 |
| Stripe: Subscription webhooks | https://docs.stripe.com/billing/subscriptions/webhooks | Official | Events, status meanings, access guidance | Subscription sync | S | 2026-09-15 |
| Stripe: Customer portal integration | https://docs.stripe.com/customer-management/integrate-customer-portal | Official | Portal session creation, auth requirement, events | Self-serve billing | S | 2026-09-15 |
| Stripe: Integration security guide | https://docs.stripe.com/security/guide | Official | PCI shared responsibility, TLS, CSP directives | PCI scope and CSP | S | 2026-09-15 |
| React Email: Manual setup | https://react.email/docs/getting-started/manual-setup | Official | Packages, `email dev`, folder layout | Setup | A | 2026-09-15 |
| React Email: Changelog | https://react.email/docs/changelog | Official | v6.0.0 (2026-04-16) unification, `@react-email/ui` rename, dark-mode switcher | Current package names | A | 2026-09-15 |
| React Email: render | https://react.email/docs/utilities/render | Official | Async render, plainText, toPlainText, data-skip-in-text | Rendering | A | 2026-09-15 |
| React Email: Tailwind | https://react.email/docs/components/tailwind | Official | pixelBasedPreset, Tailwind 4.1.12, limitations | Styling constraints | A | 2026-09-15 |
| React Email docs index | https://react.email/docs/llms.txt | Official | Component list, provider integrations | Coverage | A | 2026-09-15 |
| Resend: Send with Next.js | https://resend.com/docs/send-with-nextjs | Official | SDK usage, `RESEND_API_KEY`, `{data,error}`, idempotency key | Sending | A | 2026-09-15 |
| Resend: Domains | https://resend.com/docs/dashboard/domains/introduction | Official | Subdomain strategy, DMARC/BIMI, return path, TLS | Deliverability | A | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Post-response work on Vercel | Next.js `after()` API reference | `@vercel/functions` `waitUntil` docs | nextjs-after-and-post-response-work |
| Checkout fulfillment reliability | Stripe Fulfill orders guide | Stripe webhooks guide (duplicates/ordering), Checkout quickstart success page | stripe-payments-in-nextjs |
| Draft preview in CMSs | Next.js Draft Mode guide | Sanity visual editing, Payload preview (Contentful referenced) | nextjs-draft-mode-and-cms-preview |
| Remote MDX security | Next.js MDX guide (sanitize pipeline) | next-mdx-remote README security section | nextjs-mdx-content |
| Durable background jobs | (no single canonical) | Inngest, QStash, Trigger.dev quickstarts | nextjs-after-and-post-response-work (short section) |
| Checkout/pricing UX | checkout-flow-design / pricing-page-patterns (W10) | Not duplicated; linked only | stripe-payments-in-nextjs (links) |

## Gaps
- Contentful Live Preview docs returned HTTP 429 twice. Contentful-specific APIs (`@contentful/live-preview` provider, hooks, inspector mode) are unverified and marked "Check current docs".
- The Velite GitHub README returned 404 (repo path may have moved). Only the Velite Next.js guide page was verified. The `s.mdx()` schema API was not re-checked.
- The content-collections schema API form (function vs Standard Schema object) and `@content-collections/next` / `MDXContent` import paths were not fully verified.
- A maintained successor to the archived `next-mdx-remote` (e.g. `next-mdx-remote-client`) was not verified.
- Stripe: the PCI SAQ type per integration, the current field location for subscription billing period end, and `constructEventAsync` for edge runtimes were not verified this pass.
- Resend: where `idempotencyKey` goes (second options argument vs payload), the bounce/complaint test addresses, and the webhook signature scheme were not verified.
- Email dark-mode and client-quirk guidance (color-scheme meta support, Gmail clipping threshold, Outlook inversion) relies on community knowledge (caniemail.com), not fetched official sources.
- Inngest `createFunction` config shape differs across SDK versions (triggers inside options vs a separate argument). Flagged.
- CMS visual-editing iframe cookie `SameSite` requirements for Draft Mode are not documented in the fetched Next.js pages. Flagged as "Check current docs".
- Possible future slugs: `nextjs-background-jobs-and-queues` (a deeper treatment of Inngest, Trigger.dev, QStash, and Vercel Workflow) and `webhook-receiver-patterns` (generic signature verification and idempotency beyond Stripe).
