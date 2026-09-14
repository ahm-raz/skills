# Checkout Flow Design

## Summary
How to design and implement a high-converting, secure checkout: flow structure (guest-first, one-page vs multi-step), field minimization, address and delivery, payment method presentation, order review, error recovery, and confirmation. On the technical side it covers the payment integration boundary (hosted vs embedded vs custom fields), PCI DSS scope, Strong Customer Authentication/3-D Secure, idempotency, and webhook-driven fulfillment.

## Category
Product Patterns

## Subcategories
Guest checkout, form field reduction, address autocomplete, shipping and delivery selection, payment methods, wallets, 3-D Secure/SCA, PCI DSS scope, order confirmation, subscription checkout

## Problem It Solves
About 70% of carts are abandoned (Baymard's average across 50 studies). Much of that abandonment comes from fixable checkout problems: surprise costs, forced account creation, long forms, poor error messages, and distrust at payment. Engineering mistakes add their own failures: client-trusted totals, duplicate charges on retry, fulfillment triggered by a redirect page, and payment pages that pull third-party scripts into PCI scope. Baymard estimates large sites can gain about 35% conversion through better checkout design.

## When To Use
- Building a new checkout (physical goods, digital goods, subscriptions, donations, bookings).
- Choosing between hosted checkout, embedded payment forms, and fully custom UI.
- Auditing an existing checkout for conversion, accessibility, or PCI/SCA issues.

## When Not To Use
- Cart and product browsing: [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md).
- SaaS plan selection pages: [pricing-page-patterns](../pricing-page-patterns/Skill.md) (then use this skill for payment).
- Money movement UIs such as transfers and payouts: [fintech-ui-patterns](../fintech-ui-patterns/Skill.md).
- Generic multi-step form mechanics: [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md).

## Core Principles
1. **No surprises.** Show the full total, including shipping, taxes, and fees, before the payment step. Show it continuously in an order summary.
2. **Guest checkout is the most prominent option.** Offer account creation after purchase (just set a password), since forced accounts cause about 1 in 5 abandonments.
3. **Ask only what fulfillment needs.** Baymard's benchmark average checkout has about 23 form elements, while 12–14 is achievable. Default billing to the shipping address, and use one full-name field where the locale allows.
4. **Let the provider own card data.** Collect card details only through provider-hosted fields or pages, never raw `<input>` on your origin.
5. **The server is the source of truth.** It computes prices, taxes, discounts, and inventory. The client only displays them.
6. **Fulfill from webhooks, not redirects.** The success page may never load, so order fulfillment is triggered by a verified server event.
7. **Every submit is idempotent.** Double clicks, retries, and back-button resubmits must never double-charge.
8. **Errors are specific and recoverable.** Say what's wrong and how to fix it, and never clear entered data.

## Best Practices

### Structure
- Remove the global nav and footer clutter in checkout ("enclosed checkout"). Keep the logo (link back to cart with confirmation), help/contact, and a security/returns reassurance line.
- Steps: **Contact** (email) → **Delivery** (address + method with dates) → **Payment** → **Review & place order**. One-page accordion or multi-page both work. What matters is the field count, clarity, and preserved data.
- Put express wallets (Apple Pay, Google Pay, PayPal, Shop Pay, Link) at the top of checkout and in the cart. They skip most fields.
- Show a persistent order summary (collapsible on mobile, with total visible in the collapsed header).

### Fields
- Email first. It enables abandoned-checkout recovery, which requires consent where applicable.
- Address: country first (it drives field set and validation), then address autocomplete with a manual-entry fallback. Postal code can prefill city/state.
- Mark both required and optional fields explicitly. Baymard found many users skip required fields when only optional ones are marked.
- Phone: only if carrier needs it; explain why ("For delivery issues only").
- Hide rarely used fields behind links: "Add company name", "Add address line 2", "Have a gift card or promo code?".
- Use correct `autocomplete` tokens (`shipping given-name`, `shipping postal-code`, `email`, `cc-*` handled by the provider's fields), `inputmode`, and `type`.
- Validate inline on blur (not per keystroke). Use adaptive messages ("Card number is incomplete" vs "invalid").

### Delivery
- Show delivery dates ("Arrives Thu, Sep 18"), not just "3–5 business days".
- Show all fulfillment options (ship, pickup, local delivery) in one choice, with prices.
- A cutoff countdown ("Order within 2 h 10 min for delivery Friday") is useful if accurate.

### Payment
- Present the most relevant methods for the buyer's country and currency first. Payment providers' dynamic ordering does this.
- Card form: number, expiry, CVC, postal code (only if required); card brand detection; no "card type" dropdown.
- SCA/3DS: handled by the provider SDK (challenge in modal/iframe or redirect). Show a brief "Verifying with your bank" state; handle failure with retry or alternate method.
- Show trust signals near payment: padlock + "Secure payment", accepted card logos, return policy link. Visual reassurance matters even though users can't judge security technically.

### Review and confirmation
- Before placing an order: items, addresses, delivery method and date, payment method (last 4 digits), and the full total. The button reads "Place order · $123.45" or "Pay $123.45".
- Legal checkboxes only where legally needed. Terms can be linked text near the button in many jurisdictions (check local law). Never pre-check marketing consent.
- Confirmation page: order number, what happens next, delivery estimate, email sent to …, "Create account" with a password field only, and a manage-order link.

### Subscriptions
- State price, billing interval, trial end date, and the first charge date and amount before payment.
- State how to cancel. Auto-renewal disclosure and consent rules apply in many jurisdictions (e.g., US state auto-renewal laws, EU consumer law). Verify with counsel.

## Implementation Guidance

### Integration boundary decision table
| Option | UI control | PCI DSS validation (typical) | Effort | Use when |
|--------|-----------|------------------------------|--------|----------|
| Redirect to hosted checkout page (e.g., Stripe Checkout, Shopify checkout, Adyen Hosted Payment Pages) | Low–medium (branding) | Smallest scope, SAQ A | Low | Most merchants; fastest path with wallets, tax, SCA built in |
| Embedded provider form (iframe/components) | Medium–high | SAQ A with the added eligibility criterion that your page isn't susceptible to script attacks (PCI DSS v4.0.1 FAQ) | Medium | Branded on-site checkout |
| Custom UI + provider fields (Stripe Elements, Adyen Components, Braintree Hosted Fields) | High | Commonly SAQ A or A-EP depending on how fields load; script integrity controls (Req. 6.4.3, 11.6.1) likely relevant | High | Complex flows, marketplaces |
| Raw card inputs posting to your server | Full | SAQ D | Very high | Almost never; don't |

Scope determinations belong to your QSA or acquirer. The frontend's job is to keep card data inside provider-controlled frames and to control every script on payment pages.

### Server-authoritative checkout session
```ts
// POST /api/checkout — create session from server-side cart (never client prices)
import Stripe from "stripe";
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(req: Request) {
  const user = await getOptionalUser(req);
  const cart = await loadCartFromCookie(req);            // server-owned cart
  const priced = await priceCart(cart);                  // server pricing, inventory check
  if (priced.unavailable.length) return Response.json({ error: "items_unavailable", items: priced.unavailable }, { status: 409 });

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    line_items: priced.lines.map(l => ({ price: l.stripePriceId, quantity: l.qty })),
    automatic_tax: { enabled: true },
    shipping_address_collection: { allowed_countries: ["US", "CA"] },
    customer_email: user?.email,
    success_url: `${process.env.APP_URL}/order/confirmed?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.APP_URL}/cart`,
    metadata: { cartId: cart.id },
  }, { idempotencyKey: `checkout-${cart.id}-${cart.version}` });

  return Response.json({ url: session.url });
}
```

### Webhook-driven fulfillment
```ts
// POST /api/webhooks/stripe — verify signature, fulfill idempotently
export async function POST(req: Request) {
  const sig = req.headers.get("stripe-signature")!;
  const body = await req.text(); // raw body required for signature verification
  let event: Stripe.Event;
  try { event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!); }
  catch { return new Response("Bad signature", { status: 400 }); }

  if (event.type === "checkout.session.completed" || event.type === "checkout.session.async_payment_succeeded") {
    const s = event.data.object as Stripe.Checkout.Session;
    if (s.payment_status === "paid") await fulfillOrderOnce(s.id); // unique constraint on session id
  }
  return new Response("ok");
}
```
The confirmation page reads order status from your DB, showing "Processing…" and polling if the webhook hasn't arrived yet. It does not fulfill.

### Submit button state machine
`idle → submitting (disabled, aria-busy, spinner + "Processing…") → requires_action (3DS) → succeeded | failed (re-enable, show error, keep data)`.

## Recommended Workflow
1. Decide integration boundary (hosted/embedded/custom) with compliance owner.
2. Map required data per fulfillment type; remove everything else.
3. Build server-side cart pricing, tax, shipping rates, inventory reservation.
4. Build steps with persistent summary, express wallets, guest-first.
5. Integrate provider; handle SCA/`requires_action`, declines, async methods (bank debits, BNPL, vouchers).
6. Implement webhooks, idempotent fulfillment, confirmation page with status polling.
7. Lock down payment page scripts (inventory, CSP, SRI/monitoring).
8. Test with provider test cards (success, decline, 3DS challenge, insufficient funds), accessibility pass, mobile device tests.
9. Instrument funnel (`begin_checkout`, step views, `add_shipping_info`, `add_payment_info`, `purchase` server-side) and monitor per-step drop-off and payment error codes.

## Patterns
- **Express checkout first:** wallets row above "Or pay with card".
- **Collapsed summary header (mobile):** "Show order summary · $123.45".
- **Address suggestion on validation mismatch:** "We found a slightly different address" with both options; never silently replace.
- **Decline recovery:** map provider decline codes to human messages ("Your bank declined this payment. Try another card or contact your bank."), without exposing fraud-rule details.
- **Save-for-next-time opt-in:** unchecked checkbox "Save my info for faster checkout" after payment details.
- **Post-purchase account creation:** single password field on confirmation page.

## Anti-Patterns
- **Forced account creation before checkout.** Fix: guest default; account optional after purchase.
- **Shipping cost revealed on the last step.** Fix: estimate in cart; show in summary from delivery step.
- **Clearing the form (or card fields) after a validation error.** Fix: preserve all non-sensitive input; only card fields may need re-entry per provider rules.
- **Fulfilling on the success URL.** Users close tabs, and the URL can be forged. Fix: verified webhooks.
- **Client-computed totals sent to the payment API.** Fix: server prices from the cart ID.
- **Chat widgets, heatmaps, and A/B scripts on payment pages.** They enlarge the attack surface (Magecart-style skimming). Fix: minimal script inventory on checkout; CSP; integrity monitoring.
- **Disabled "Place order" button with no explanation.** Fix: enabled button that validates and focuses the first error.
- **Generic "Something went wrong".** Fix: specific cause + next step + preserved state.
- **Pre-checked marketing or add-on insurance.** Dark pattern and unlawful in many regions. Fix: unchecked opt-in.

## Accessibility
- Each step has a heading; step progress conveyed textually ("Step 2 of 4: Delivery") (WCAG 1.3.1, 2.4.6).
- Error summary at top on submit, linked to fields; focus moves to it; each field error via `aria-describedby` (3.3.1, 3.3.3).
- Error prevention for financial transactions: review step before commit (3.3.4).
- Don't ask again for information already entered in the same process (3.3.7 Redundant Entry). "Billing same as shipping" satisfies this.
- Accessible authentication (3.3.8): allow password managers and paste in login/OTP; 3DS challenges are the provider's UI, so choose providers with accessible challenge flows.
- Provider iframes: set `title` attributes; verify labels and error announcements in screen readers.
- Session timeouts: warn and allow extension (2.2.1); don't expire cart without notice.

## Responsive Design
- Single column on mobile; summary collapsed at top; primary button full width.
- Numeric keypads for postal code (where numeric) and card numbers (`inputmode="numeric"`).
- Keep the primary action visible, but don't let a sticky button cover focused fields when the keyboard opens.
- Wallet buttons render natively sized per provider guidelines.

## Performance
- Checkout JS budget small; preload provider SDK only on checkout routes.
- Avoid layout shift when provider fields mount; reserve height.
- Shipping rate/tax recalculation: debounce, show inline pending state, prevent submit until totals settled.
- Keep INP low on "Place order": immediate visual response before network work.

## Security
- PCI DSS v4.0.1: for payment pages with embedded provider forms, SAQ A merchants must confirm their site isn't susceptible to script attacks that could affect the ecommerce system. Requirements 6.4.3 (authorize, justify, and integrity-check payment page scripts) and 11.6.1 (detect unauthorized changes to scripts and headers) remain in the standard for other validation types. Satisfy them yourself or obtain confirmation from your PCI-compliant provider.
- Strict CSP on checkout: allowlist provider domains only; `frame-src` for provider iframes; report-only first.
- Webhook signature verification; replay protection via event IDs; secrets only in server env.
- Idempotency keys on payment creation; unique DB constraints on fulfillment.
- Rate-limit promo code and card attempts (card-testing attacks); enable provider fraud tooling; add challenge on anomalies.
- Never log full PAN, CVC, or full provider payloads containing sensitive data.
- EU/UK: SCA required for most customer-initiated card payments; exemptions (low value, TRA, merchant-initiated) are applied by provider/issuer. Design for challenge flows anyway.

## Testing
- E2E with provider test mode: success, generic decline, insufficient funds, 3DS challenge pass/fail, async payment pending → succeeded.
- Double-submit test: rapid clicks and network retry produce one order.
- Webhook tests: replayed events don't double-fulfill; out-of-order events handled.
- Totals tests: tampered client price ignored.
- Accessibility: keyboard-only full purchase; screen reader pass including provider iframes.
- Script inventory check in CI for payment routes (no unexpected third-party scripts).

## Tooling
- Payments: Stripe (Checkout Sessions recommended by Stripe for most integrations; Payment Element for custom), Adyen (Drop-in/Components), Braintree, PayPal, Shopify Checkout, Mollie.
- Address autocomplete: Google Places, Loqate, Smarty, provider address elements.
- Tax: Stripe Tax, Avalara, TaxJar.
- Script integrity monitoring: CSP reporting, vendor client-side protection tools.
- Testing: Playwright + provider test cards; Stripe CLI for local webhooks.

## Framework Notes
- **Next.js App Router (primary):**
  - Route group `app/(checkout)/` with its own `layout.tsx`: the enclosed header, and none of the root layout's analytics, chat, or A/B scripts. Put those scripts in `app/(marketing)/layout.tsx` instead of the root layout so checkout never inherits them.
  - Session creation in a Server Action (`redirect(session.url)`) or a Route Handler. Both re-read the cart from the cookie and re-price server-side.
  - Webhook in `app/api/webhooks/stripe/route.ts`. Read the raw body with `await req.text()`, and don't wrap it in anything that parses JSON first. It runs on the Node.js runtime (the default).
  - Checkout routes are dynamic (they read cookies), so never add caching directives to them.
  - Confirmation page `app/(checkout)/order/confirmed/page.tsx` reads `searchParams.session_id`, loads the order from your DB, and shows a polling client component while `status === "processing"`.
  - Secrets only in server env (no `NEXT_PUBLIC_` prefix except the publishable key); use `import "server-only"` in the Stripe client module.
  - Non-payment steps (contact, address) as `<form action={serverAction}>` with `useActionState` so validation errors render without a client round-trip library.
  - CSP with nonces set in `proxy.ts` for checkout routes, allowlisting the provider domains.
- **React (Vite SPA):** load `@stripe/react-stripe-js` only on the checkout route (lazy import). All session creation and webhook handling live in a separate backend. The SPA never holds secret keys.
- **Wallets:** Apple Pay requires domain verification with the provider. Wallet buttons need HTTPS (localhost excepted in dev).

## AI Agent Guidance
- Never create raw card number inputs. Use the provider's hosted page or fields.
- Never trust client amounts; never fulfill outside a verified webhook; always add idempotency.
- Never place secrets in client code or commit test keys. Reference env var names only.
- Don't add analytics, chat, or experimentation scripts to payment routes without explicit approval.
- Verify before done:
  - [ ] Guest path works end to end; account creation optional
  - [ ] Total with shipping/tax visible before payment step
  - [ ] Decline and 3DS test cards handled with clear messages and preserved data
  - [ ] Webhook verified, idempotent fulfillment, confirmation reads server state
  - [ ] Double-click produces one order
  - [ ] Error summary + field errors accessible; keyboard-only purchase possible
  - [ ] Payment route script inventory reviewed; CSP present

## Examples

```tsx
// Error summary component (focus on submit failure)
export function ErrorSummary({ errors }: { errors: { field: string; message: string }[] }) {
  const ref = React.useRef<HTMLDivElement>(null);
  React.useEffect(() => { if (errors.length) ref.current?.focus(); }, [errors]);
  if (!errors.length) return null;
  return (
    <div ref={ref} tabIndex={-1} role="alert" aria-labelledby="err-title" className="error-summary">
      <h2 id="err-title">Please fix {errors.length} {errors.length === 1 ? "problem" : "problems"}</h2>
      <ul>{errors.map(e => <li key={e.field}><a href={`#${e.field}`}>{e.message}</a></li>)}</ul>
    </div>
  );
}
```

```html
<!-- Address fields with correct autocomplete tokens -->
<label for="ship-name">Full name</label>
<input id="ship-name" name="name" autocomplete="shipping name" required>
<label for="ship-postal">ZIP code</label>
<input id="ship-postal" name="postal" autocomplete="shipping postal-code" inputmode="numeric" required>
<label for="phone">Phone <span>(optional, only used for delivery issues)</span></label>
<input id="phone" name="phone" type="tel" autocomplete="tel">
```

## Related Skills
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md) — cart and product flows before checkout
- [form-design-ux](../form-design-ux/Skill.md) — field design fundamentals
- [form-validation-patterns](../form-validation-patterns/Skill.md) — inline and summary validation
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md) — step mechanics
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md) — amounts and formatting
- [fintech-ui-patterns](../fintech-ui-patterns/Skill.md) — regulated money movement
- [content-security-policy](../content-security-policy/Skill.md) — payment page script control
- [third-party-script-management](../third-party-script-management/Skill.md) — script inventory
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — pre-checked add-ons, drip pricing

## Sources
- [Baymard Institute — Cart abandonment rate statistics](https://baymard.com/lists/cart-abandonment-rate) — Official research — 70.22% abandonment; extra costs, account creation, long checkout; form element averages; 35% improvement potential
- [Baymard Institute — Current state of checkout UX](https://baymard.com/blog/current-state-of-checkout-ux) — Official research — guest prominence, delivery dates, required/optional marking, adaptive errors, phone explanation
- [Stripe Docs — Online payments](https://docs.stripe.com/payments/online-payments) — Official — Checkout Sessions vs PaymentIntents, UI options, webhook lifecycle
- [PCI SSC blog — FAQ clarifies new SAQ A eligibility criteria](https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants) — Official — SAQ A script-attack criterion; 6.4.3/11.6.1 context
- [EBA/PSD2 SCA context via GPayments guide](https://www.gpayments.com/blog/article/3d-secure-and-psd2-strong-customer-authentication-a-guide-for-european-and-uk-psps/) — Community/vendor — frictionless vs challenge, exemptions; PSD3/PSR pending
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — 3.3.4, 3.3.7, 3.3.8
- [HTML autocomplete tokens (WHATWG)](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill) — Official — autofill field names

## License / Usage Notes
Research findings paraphrased from public summaries; PCI and payment regulatory notes are informational, not legal or compliance advice. Stripe code patterns are original examples following public docs.

## Quality Tier
S — Directly grounded in Baymard's public checkout research, PCI SSC official clarification, provider docs, and WCAG 2.2; actionable with code for the critical safety boundaries.

## Status
Active

## Last Verified
2026-09-15
