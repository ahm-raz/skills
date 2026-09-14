# Stripe Payments in Next.js

## Summary
The server side of taking payments with Stripe in a Next.js 16.3.x App Router app: Checkout Sessions (hosted, embedded, or Elements-based) and Payment Element flows. It covers creating sessions in Server Actions, verifying webhook signatures in Route Handlers using the raw body, idempotent fulfillment, keeping subscription state in sync, the Customer Portal, PCI scope, and test mode. Checkout UX and pricing-page design live in checkout-flow-design and pricing-page-patterns. This skill covers the plumbing.

## Category
Product Patterns

## Subcategories
Payments, Subscriptions, Webhooks, Route Handlers, Server Actions, Security, SaaS Billing

## Problem It Solves
Payment bugs cost money and trust: double charges, orders never fulfilled because the success page didn't load, access granted from a spoofed webhook, entitlements drifting from Stripe's real subscription state, and secret keys leaking into client bundles. This skill gives a reliable, verifiable architecture where Stripe is the source of truth and your database is an idempotently synced projection.

## When To Use
- One-time purchases, donations, or pre-orders in a Next.js app.
- SaaS subscriptions with trials, upgrades or downgrades, and self-serve billing management.
- Replacing a fragile "fulfill on success page" integration with webhooks.
- Adding embedded checkout or a custom Elements checkout while keeping PCI scope low.

## When Not To Use
- Marketplaces paying out to third parties. You need Stripe Connect, which is out of scope here.
- In-app digital goods on native iOS/Android stores, which have store billing rules.
- Merchant-of-record needs (global tax remittance handled for you). Consider an MoR provider, and check current offerings.
- Pure UX questions about checkout steps or pricing layout. See checkout-flow-design and pricing-page-patterns.

## Core Principles
1. Prices, amounts, and products are decided on the server from IDs you control. Never trust client-sent amounts.
2. Webhooks are required for fulfillment. The success/return page is an optimization, not the trigger.
3. Fulfillment must be idempotent and safe under concurrent calls for the same Checkout Session or event.
4. Verify every webhook's `Stripe-Signature` against the unmodified raw body.
5. Stripe is the source of truth for payment and subscription state. Store a synced copy keyed by Stripe IDs.
6. Keep card data off your servers by using Stripe-hosted UI or Stripe.js iframes loaded from `js.stripe.com`.
7. Secret key, restricted keys, and webhook secret are server-only. Only the publishable key is `NEXT_PUBLIC_`.

## Best Practices
- Create a single `lib/stripe.ts` with `import 'server-only'` so the SDK can't be imported into Client Components.
- Map internal plan keys to Price IDs on the server (`PLANS.pro.monthly -> price_...` from env or DB).
- Link Stripe objects to your users: pass `client_reference_id` and `metadata.userId`, reuse `customer` for returning users, and store `stripeCustomerId` on the user.
- Use `success_url`/`return_url` with `{CHECKOUT_SESSION_ID}`, and on that page call the same idempotent `fulfillCheckout(sessionId)` the webhook uses.
- Handle `checkout.session.completed` and `checkout.session.async_payment_succeeded`, and optionally `async_payment_failed` to notify.
- For subscriptions, react to `customer.subscription.created|updated|deleted`, `invoice.paid`, `invoice.payment_failed`, and `customer.subscription.trial_will_end`. Re-fetch the subscription from the API rather than trusting event ordering.
- Return 2xx quickly. Stripe waits up to about 10s for your `checkout.session.completed` response before redirecting to `success_url`, and retries failures (live: up to 3 days; sandbox: 3 times over hours).
- Deduplicate by `event.id` in a `stripe_events` table with a unique constraint.
- Send `idempotencyKey` on POSTs that create money-moving or billing objects (UUID v4, no PII, retained at least 24h). Reusing a key with different params returns an error.
- Exclude the webhook path from auth redirects in `proxy.ts`. A 3xx counts as a delivery failure.
- Subscribe the endpoint only to the event types you handle.
- Configure CSP for Stripe.js/Checkout (`script-src https://js.stripe.com https://*.js.stripe.com`, `frame-src https://js.stripe.com https://*.js.stripe.com https://hooks.stripe.com`, `connect-src https://api.stripe.com`, plus `checkout.stripe.com` for Checkout).

## Implementation Guidance
**Choose the UI**

| Option (`ui_mode`) | You build | PCI surface | Use when |
|---|---|---|---|
| `hosted_page` (default) | Button that redirects | Lowest | Fastest launch; subscriptions; most SaaS |
| `embedded_page` | Page hosting `<EmbeddedCheckout>` | Low (Stripe iframe) | Keep users on your domain |
| `form` / `elements` | Your layout with Stripe Elements on Checkout Sessions | Low (iframes), more UI work | Custom branded checkout; still Sessions API |
| PaymentIntents + Payment Element | Full custom flow, your own totals/tax/discounts | Low (iframes), most logic | Unusual flows Checkout can't model |

The `ui_mode` enum values were verified from the API reference at research time. Stripe renames things over time, so check current docs.

**Architecture**
1. `lib/stripe.ts` (server-only client) and `lib/billing.ts` (plan map, `fulfillCheckout`, `syncSubscription`).
2. Server Action `startCheckout(planKey)`: auth, get or create the customer, create the session, `redirect(session.url)`.
3. `app/api/webhooks/stripe/route.ts`: raw body, verify, dedupe, dispatch, 2xx.
4. `app/billing/success/page.tsx`: read `session_id`, call `fulfillCheckout`, render status.
5. Server Action `openBillingPortal()`: auth, `billingPortal.sessions.create({ customer, return_url })`, redirect.
6. Entitlement check reads your synced DB (`subscriptions.status in ('active','trialing')` and `current_period_end` in the future).

**Subscription status handling**

| Status | Access |
|---|---|
| `trialing`, `active` | Grant |
| `past_due` | Grant with a dunning banner (policy choice) and prompt to update the payment method |
| `incomplete` | Don't grant yet (first payment pending or needs action) |
| `unpaid`, `canceled`, `incomplete_expired` | Revoke |
| `paused` | Revoke until resumed |

## Recommended Workflow
1. Model products and prices in a Stripe sandbox and store the Price IDs in env or config.
2. Build the Server Action and hosted Checkout, and pay with test card `4242 4242 4242 4242`.
3. Run `stripe listen --forward-to localhost:3000/api/webhooks/stripe` and put the printed secret in `.env.local` as `STRIPE_WEBHOOK_SECRET`.
4. Implement the webhook handler and idempotent fulfillment, then test with `stripe trigger checkout.session.completed`.
5. Add the success page (calls the same fulfillment) and the Customer Portal.
6. Add subscription sync and test upgrades, cancellation, and failed renewals (test clocks for time travel).
7. Register the live webhook endpoint (HTTPS), roll secrets, set CSP, and run a live-mode smoke test with a real low-value charge and refund.

## Patterns
**Server-only client**
```ts
// lib/stripe.ts
import 'server-only'
import Stripe from 'stripe'
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)
```

**Server Action: start hosted Checkout**
```ts
// app/billing/actions.ts
'use server'
import { redirect } from 'next/navigation'
import { randomUUID } from 'node:crypto'
import { stripe } from '@/lib/stripe'
import { requireUser } from '@/lib/auth'
import { getOrCreateCustomerId } from '@/lib/billing'

const PRICES = {
  'pro-monthly': process.env.STRIPE_PRICE_PRO_MONTHLY!,
  'pro-yearly': process.env.STRIPE_PRICE_PRO_YEARLY!,
} as const

export async function startCheckout(formData: FormData) {
  const user = await requireUser()
  const plan = formData.get('plan')
  if (typeof plan !== 'string' || !(plan in PRICES)) throw new Error('Unknown plan')

  const customer = await getOrCreateCustomerId(user) // stored stripeCustomerId
  const origin = process.env.APP_URL! // don't trust Host header for redirects
  const session = await stripe.checkout.sessions.create(
    {
      mode: 'subscription',
      customer,
      client_reference_id: user.id,
      metadata: { userId: user.id },
      line_items: [{ price: PRICES[plan as keyof typeof PRICES], quantity: 1 }],
      success_url: `${origin}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/pricing`,
    },
    { idempotencyKey: randomUUID() },
  )
  redirect(session.url!)
}
```

**Webhook Route Handler (raw body and signature)**
```ts
// app/api/webhooks/stripe/route.ts
import type Stripe from 'stripe'
import { stripe } from '@/lib/stripe'
import { fulfillCheckout, syncSubscription, recordEventOnce } from '@/lib/billing'

export async function POST(req: Request) {
  const body = await req.text() // raw, unparsed
  const signature = req.headers.get('stripe-signature')
  if (!signature) return new Response('Missing signature', { status: 400 })

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch {
    return new Response('Invalid signature', { status: 400 })
  }

  if (!(await recordEventOnce(event.id, event.type))) return new Response('Duplicate', { status: 200 })

  try {
    switch (event.type) {
      case 'checkout.session.completed':
      case 'checkout.session.async_payment_succeeded':
        await fulfillCheckout(event.data.object.id)
        break
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        await syncSubscription(event.data.object.id)
        break
      case 'invoice.payment_failed':
        // notify the customer (queue an email), don't revoke here; status sync handles access
        break
    }
  } catch (err) {
    await markEventFailed(event.id) // allow the retry to reprocess
    return new Response('Handler error', { status: 500 }) // Stripe retries
  }
  return new Response('ok', { status: 200 })
}
```
`markEventFailed` must delete or flag the dedupe row so the retry isn't skipped. If handlers are slow, persist the event and process it from a durable queue, then return 200.

**Idempotent fulfillment**
```ts
// lib/billing.ts (excerpt)
export async function fulfillCheckout(sessionId: string) {
  const session = await stripe.checkout.sessions.retrieve(sessionId, { expand: ['line_items'] })
  if (session.payment_status === 'unpaid') return { status: 'pending' as const }

  // unique index on orders.stripe_checkout_session_id makes concurrent calls safe
  const inserted = await db.order.createIfAbsent({
    stripeCheckoutSessionId: session.id,
    userId: session.client_reference_id,
    amountTotal: session.amount_total,
  })
  if (inserted) await grantPurchase(session)
  return { status: 'fulfilled' as const }
}

export async function syncSubscription(subscriptionId: string) {
  const sub = await stripe.subscriptions.retrieve(subscriptionId) // fresh state; ignore event order
  await db.subscription.upsert({
    stripeSubscriptionId: sub.id,
    stripeCustomerId: typeof sub.customer === 'string' ? sub.customer : sub.customer.id,
    status: sub.status,
    priceId: sub.items.data[0]?.price.id,
  })
}
```
The field that holds the billing period end has moved between API versions (subscription vs subscription item), so check current docs for your pinned version.

## Anti-Patterns
- **Fulfilling only on the success page.** Users who close the tab paid but got nothing. Fix: webhook plus the same idempotent function on the success page.
- **`await req.json()` before verification, or re-stringifying the body.** The signature fails, or someone disables verification to "fix" it. Fix: `await req.text()` and `constructEvent`.
- **Skipping signature verification in production.** Attackers can POST fake `checkout.session.completed` events. Fix: always verify, and optionally also allowlist Stripe IPs.
- **Trusting `amount` or `price` from the client.** People tamper with the price. Fix: server-side plan-to-Price map.
- **Using event `created` timestamps to order processing.** Stripe doesn't guarantee order, and timestamps collide. Fix: re-fetch objects and dedupe by `event.id`.
- **`NEXT_PUBLIC_STRIPE_SECRET_KEY`.** Full account compromise. Fix: server-only env vars, restricted keys where possible, `server-only` import.
- **Doing the fulfillment in `after()`.** Timeouts lose orders silently. Fix: inline or a durable queue.
- **Portal session for whatever customer ID the form posts.** Account takeover of billing. Fix: derive the customer from the authenticated user.

## Accessibility
- Checkout and Elements UIs are Stripe-maintained. Your surrounding page still needs labeled buttons ("Subscribe to Pro, $20/month"), clear error text, and focus moved to status messages on the return page (WCAG 3.3.1, 4.1.3).
- Submit buttons: disable-and-announce during pending Server Actions (`useFormStatus`), and don't hide state changes behind color alone (1.4.1).
- Payment Element: pass `appearance` variables that keep contrast at 4.5:1 or better and visible focus rings (2.4.7).
- Don't set short session timeouts without warning. Checkout Sessions expire (the default is about 24h in API responses), so let users restart gracefully (2.2.1).

## Responsive Design
- Hosted Checkout is responsive. For embedded or Elements, give the container full width on mobile and don't nest it inside another iframe or scroll-locked modal, because 3DS and redirect-based methods need room. Order-summary layout lives in checkout-flow-design.

## Performance
- Load Stripe.js only on payment routes (call `loadStripe` at module scope in the checkout Client Component, not in the root layout).
- Create the Checkout Session on click (Server Action), not on page render, to avoid wasted API calls and expired sessions.
- Webhook handler: verify, dedupe, and act fast. Offload slow work to a queue. The success redirect can wait up to about 10s on your webhook response.
- Cache price and product catalog reads (`'use cache'` + tag, revalidated from `product.updated`/`price.updated` events).

## Security
- **Keys:** `STRIPE_SECRET_KEY` (or a restricted key scoped to needed resources) and `STRIPE_WEBHOOK_SECRET` stay server-only. Only `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` is public. Roll webhook secrets periodically. Stripe supports overlapping secrets for up to 24h.
- **Webhooks:** verify the signature with the default 5-minute tolerance (never 0), use HTTPS with TLS 1.2+, dedupe by event ID, and treat event data as hints (re-fetch).
- **PCI:** Checkout, Embedded Checkout, and Elements send card data directly to Stripe, which minimizes your PCI DSS scope. You still attest annually. The exact SAQ depends on the integration, so check current Stripe and PCI guidance. Store only non-sensitive card data (brand, last4, expiry) returned by the API.
- **Authorization:** billing portal and subscription changes are scoped to the authenticated user's stored customer ID.
- **Server Actions** are public POST endpoints. Validate input and authenticate inside every action.
- **Open redirects:** build success, cancel, and return URLs from a configured `APP_URL`, not request headers.
- **CSP:** add the Stripe directives listed in Best Practices, plus `https://hooks.stripe.com` in `frame-src` for 3DS.

## Testing
- **Local webhooks:** `stripe listen --forward-to localhost:3000/api/webhooks/stripe`, `stripe trigger checkout.session.completed`, `stripe events resend <id>`.
- **Test cards:** success `4242424242424242`, 3DS required `4000002500003155`, declined `4000000000009995`.
- **Unit test the webhook handler** with a correctly signed payload generated by `stripe.webhooks.generateTestHeaderString({ payload, secret })`. Assert 400 on a bad signature and 200 on a duplicate.
- **Idempotency test:** call `fulfillCheckout` twice concurrently and assert one order row.
- **Subscriptions:** use test clocks to advance through trial end, renewal, and failed payment, and assert the synced status and access.
- **E2E (Playwright):** pricing, then hosted Checkout (sandbox), then return page shows success, then gated feature unlocked. Isolate from live keys.
- **Mock Stripe HTTP in component tests** with MSW. Don't hit the network in unit tests.

## Tooling
- `stripe` (stripe-node): server SDK. Active. The Stripe docs samples referenced v22.x at research time.
- `@stripe/stripe-js` (`loadStripe`) and `@stripe/react-stripe-js` (`EmbeddedCheckoutProvider`, `EmbeddedCheckout`, Elements). Active.
- Stripe CLI (`stripe listen`, `stripe trigger`) and Workbench (webhook deliveries, secret rolling).

## Framework Notes
- **Next.js (App Router, 16.3.x):** Server Actions create sessions and portal links. Route Handlers receive webhooks (`req.text()` for the raw body, no body-parser config needed). Use the Node.js runtime for `constructEvent`, or `constructEventAsync` with Web Crypto on edge runtimes (check current docs). Keep the webhook path out of `proxy.ts` auth. Success pages are dynamic (they read `searchParams`).
- **React (Vite SPA):** session creation and webhooks must live on a backend (Express, Hono, serverless functions). The SPA calls the backend to get `session.url` or `client_secret` and uses `@stripe/react-stripe-js` for embedded or Elements. Never put the secret key in `import.meta.env.VITE_*`.

## AI Agent Guidance
- Do: create `lib/stripe.ts` with `server-only`, a server-side price map, the webhook route with `req.text()` + `constructEvent`, event dedupe, idempotent fulfillment, and success-page fulfillment.
- Do: use placeholders (`process.env.STRIPE_SECRET_KEY`), and never write real keys or `whsec_` values.
- Do: link to checkout-flow-design and pricing-page-patterns for UI decisions instead of redesigning the UX.
- Don't: parse JSON before verification, fulfill in `after()`, trust client amounts, or expose customer IDs from form input.
- Don't: invent Stripe parameter names. Check the API reference for the pinned API version (fields like period end moved between versions).
- Verify before done: `stripe trigger` events return 200, a bad signature returns 400, duplicate events are no-ops, a closed-tab purchase is still fulfilled, the portal only opens for the signed-in user's customer, and `next build` shows no Stripe secret in client chunks (search `.next/static` for `sk_`).

## Examples
**Customer Portal action**
```ts
// app/billing/portal-action.ts
'use server'
import { redirect } from 'next/navigation'
import { stripe } from '@/lib/stripe'
import { requireUser } from '@/lib/auth'

export async function openBillingPortal() {
  const user = await requireUser()
  if (!user.stripeCustomerId) redirect('/pricing')
  const portal = await stripe.billingPortal.sessions.create({
    customer: user.stripeCustomerId,
    return_url: `${process.env.APP_URL}/settings/billing`,
  })
  redirect(portal.url)
}
```

**Embedded Checkout (client) with a Server Action providing the client secret**
```tsx
// app/checkout/embedded-checkout.tsx
'use client'
import { loadStripe } from '@stripe/stripe-js'
import { EmbeddedCheckoutProvider, EmbeddedCheckout } from '@stripe/react-stripe-js'
import { createEmbeddedSession } from './actions' // server: ui_mode 'embedded_page', returns client_secret

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

export function Checkout({ plan }: { plan: string }) {
  return (
    <EmbeddedCheckoutProvider stripe={stripePromise} options={{ fetchClientSecret: () => createEmbeddedSession(plan) }}>
      <EmbeddedCheckout />
    </EmbeddedCheckoutProvider>
  )
}
```
The server side uses `ui_mode: 'embedded_page'` and `return_url: \`${APP_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}\``, and returns `session.client_secret`. The success page reads `session_id` from `searchParams`, calls `fulfillCheckout(session_id)`, and renders a `role="status"` message ("Plan active" or "Payment processing").

## Related Skills
- [checkout-flow-design](../checkout-flow-design/Skill.md): checkout UX, steps, trust signals (not duplicated here)
- [pricing-page-patterns](../pricing-page-patterns/Skill.md): plan presentation and CTAs (not duplicated here)
- [saas-application-patterns](../saas-application-patterns/Skill.md): entitlements and billing settings
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): session and portal creation
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md): webhook endpoints
- [nextjs-authentication](../nextjs-authentication/Skill.md): mapping users to customers
- [nextjs-database-integration](../nextjs-database-integration/Skill.md): orders, events, subscription tables
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md): key handling
- [content-security-policy](../content-security-policy/Skill.md): Stripe CSP directives
- [transactional-email-with-react-email](../transactional-email-with-react-email/Skill.md): receipts and dunning emails

## Sources
- [Stripe: How Checkout works](https://docs.stripe.com/payments/checkout/how-checkout-works) (Official): lifecycle across hosted, embedded, and Elements
- [Stripe API: Create a Checkout Session](https://docs.stripe.com/api/checkout/sessions/create) (Official): `ui_mode` enum and default
- [Stripe: Checkout quickstart (Next.js)](https://docs.stripe.com/checkout/quickstart?client=next) (Official): server-only client, Route Handler redirect, success page, env var names
- [Stripe: Embedded Checkout quickstart (Next.js)](https://docs.stripe.com/checkout/embedded/quickstart?client=next) (Official): `embedded_page`, Server Action client secret, React components
- [Stripe: Fulfill orders](https://docs.stripe.com/checkout/fulfillment) (Official): idempotent fulfill function, async payment events, landing-page trigger, 10s redirect wait
- [Stripe: Webhooks](https://docs.stripe.com/webhooks) (Official): raw body, signature verification, tolerance, retries, ordering, duplicates, secret rolling
- [Stripe API: Idempotent requests](https://docs.stripe.com/api/idempotent_requests) (Official): key rules and retention
- [Stripe: Subscription webhooks](https://docs.stripe.com/billing/subscriptions/webhooks) (Official): events and status semantics
- [Stripe: Customer portal integration](https://docs.stripe.com/customer-management/integrate-customer-portal) (Official): portal sessions, events to handle
- [Stripe: Integration security guide](https://docs.stripe.com/security/guide) (Official): PCI shared responsibility, TLS, CSP directives

## License / Usage Notes
Stripe documentation is proprietary and summarized here, not copied. stripe-node and Stripe.js React bindings are MIT (verify in each repo). Code examples are original. Never commit real keys.

## Quality Tier
A: grounded in current official Stripe docs fetched at research time plus Next.js 16.3.x conventions. Version-sensitive fields (billing period end, SAQ type) are flagged.

## Status
Active

## Last Verified
2026-09-15
