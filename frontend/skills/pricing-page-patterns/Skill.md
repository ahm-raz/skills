# Pricing Page Patterns

## Summary
How to design and build pricing pages for SaaS, usage-based, and subscription products. It covers plan structure and tier presentation, billing interval toggles, feature comparison tables, usage and seat calculators, enterprise "contact sales" paths, localized currency, FAQs and objection handling, and the handoff into checkout or signup. The technical side covers Next.js rendering, a single source of truth for plan data shared with billing, structured data limits, and experiment safety. Honest, legally compliant price presentation is a first-class requirement.

## Category
Product Patterns

## Subcategories
Plan tiers, feature comparison, monthly/annual toggle, usage-based pricing, seat pricing, calculators, enterprise plans, localized pricing, free trials, subscription disclosures

## Problem It Solves
Pricing pages are among the most visited and most confusing pages on B2B sites. Differences between plans aren't explicit, and annual prices are shown as monthly without clarity. Usage costs can't be estimated, and "Contact us" hides everything. Plan data is also duplicated between marketing and billing, so the page drifts from what customers are charged. NN/g research on B2B sites repeatedly finds users want transparent pricing and explicit differences between options.

## When To Use
- Creating or redesigning a pricing page, plan comparison table, or in-app plan picker.
- Introducing usage-based components, annual discounts, or regional pricing.

## When Not To Use
- The payment step after plan selection: [checkout-flow-design](../checkout-flow-design/Skill.md).
- In-app billing management (upgrade/downgrade, invoices): [saas-application-patterns](../saas-application-patterns/Skill.md).
- Retail product prices: [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md).

## Core Principles
1. **Explicit differences.** Users should see at a glance what they gain by moving up a tier: highlight differentiators, not identical features.
2. **One source of truth.** Plans, prices, limits, and features come from the same config/billing catalog that powers entitlements and checkout.
3. **Honest price math.** State the billing interval, what "per seat" or "per unit" means, whether prices include tax, and the annual total when showing a monthly equivalent.
4. **Guide the choice.** 2–4 tiers, each labeled for a persona ("For small teams"), with at most one "Most popular" highlight based on real data.
5. **Estimate usage.** Usage-based pricing needs a calculator or worked examples.
6. **Every visitor has a next step.** Self-serve CTA per tier, plus a clear sales path for enterprise needs (SSO, compliance, volume).
7. **No manipulative tactics.** No fake strike-through prices, hidden auto-renewals, or cancel paths harder than signup.

## Best Practices

### Page anatomy
1. **Header:** outcome-oriented headline + short subhead; billing interval toggle (Monthly / Annual, "Save 20%") and currency selector if applicable.
2. **Plan cards (2–4):** name, persona line, price (with interval and unit), key limits, 3–6 differentiating features ("Everything in Pro, plus…"), CTA, trial/no-card microcopy.
3. **Enterprise card or band:** "Custom pricing" with explicit inclusions (SSO/SAML, SCIM, audit logs, SLA, DPA, dedicated support) and "Contact sales".
4. **Usage/add-ons:** metered prices table + calculator.
5. **Full comparison table:** grouped features, sticky plan header with CTAs, tooltips for jargon, and explicit "not included" marks.
6. **Social proof and trust:** logos, security/compliance badges (only real certifications), and a short testimonial about value.
7. **FAQ:** billing cycles, trials, overages, downgrades, cancellation, refunds, taxes/VAT, discounts (nonprofit/education), data on cancellation.
8. **Final CTA.**

### Price display
- Annual toggle: show `$20 /user/month, billed annually ($240/year)`. Don't show only the monthly equivalent.
- Default interval: whichever matches the majority of purchases, with the default made obvious. Don't default to annual just to show smaller numbers without labelling.
- Free tier: state limits plainly. "Free forever" only if true.
- Tax: "Prices exclude VAT/sales tax" where applicable. In some jurisdictions consumer prices must include VAT. Show tax-inclusive prices for B2C in the EU/UK.
- Currency: localize by selected or geo-suggested currency, and label the currency code when ambiguous.
- Strike-through "was" prices only for genuine prior prices.

### Subscription disclosure
- State near the CTA: renewal cadence, trial end behavior ("You'll be charged $240 on Oct 1 unless you cancel"), and how to cancel.
- US: the FTC's 2024 "click-to-cancel" rule was vacated by a federal appeals court in July 2025, but ROSCA and state automatic renewal laws (e.g., California) still require clear disclosure, affirmative consent, and simple cancellation. EU consumer rules also apply to B2C. Verify with counsel.

### Comparison table
- Group features by category with collapsible groups on mobile.
- Checkmarks with accessible text; show limits as values ("10 projects", "Unlimited").
- Only include features that differ, or that buyers commonly ask about. Remove noise rows.
- Sticky header row with plan names and CTAs while scrolling.

## Implementation Guidance

### Single source of truth
```ts
// config/plans.ts — shared by pricing page, entitlements, and checkout
export const plans = [
  { id: "free", name: "Free", persona: "For individuals getting started",
    prices: { month: { USD: 0 }, year: { USD: 0 } },
    limits: { seats: 1, projects: 3 }, highlights: ["3 projects", "Community support"],
    cta: { label: "Start free", href: "/signup?plan=free" } },
  { id: "pro", name: "Pro", persona: "For growing teams", popular: true,
    prices: { month: { USD: 2500, EUR: 2400 }, year: { USD: 24000, EUR: 23000 } }, // minor units per seat
    unit: "seat",
    stripePriceIds: { month: "price_pro_monthly_ref", year: "price_pro_yearly_ref" }, // refs resolved server-side
    limits: { seats: null, projects: 50 }, highlights: ["Everything in Free, plus:", "50 projects", "Advanced reports", "Email support"],
    cta: { label: "Start 14-day trial", href: "/signup?plan=pro" } },
  { id: "enterprise", name: "Enterprise", persona: "For security & scale", custom: true,
    highlights: ["SAML SSO & SCIM", "Audit log", "99.9% SLA", "DPA & security review"],
    cta: { label: "Contact sales", href: "/contact-sales" } },
] as const;
```
Feature rows for the comparison table live in the same module and map to entitlement keys. A test asserts that every entitlement flag appears in the table or is intentionally hidden.

### Rendering
| Aspect | Approach (Next.js) |
|--------|--------------------|
| Page | Static Server Component; revalidate via tag when plans change |
| Interval toggle | URL param `?billing=annual` (shareable, analytics-friendly) or a small client island; server renders default interval so HTML has real prices |
| Currency | Default by geo in `proxy.ts` rewrite to `/pricing/[currency]` static variants, or query param with user override; never flash-swap prices after load |
| Calculator | Client component; math shared with server billing code |
| Experiments | Assign variant at the edge; don't show different prices for identical plans to similar users without legal review |

### Structured data
There's no dedicated Google rich result for SaaS pricing tables. Use `Product`/`Offer` markup only where it truthfully describes a purchasable product, and keep it consistent with visible prices. Don't rely on FAQ rich results: Google stopped showing FAQ rich results for nearly all sites as of May 7, 2026.

## Recommended Workflow
1. Align with product/finance on tiers, limits, prices, currencies, tax treatment, and trial rules. Encode in the plans config.
2. Draft copy: persona lines, differentiators, enterprise inclusions, FAQ.
3. Build cards + toggle with server-rendered default prices.
4. Build comparison table from feature config; add calculator for usage components.
5. Wire CTAs to signup/checkout with plan and interval params validated server-side.
6. Add disclosures near CTAs; compliance review.
7. Accessibility and mobile pass; analytics events (`pricing_view`, `interval_toggle`, `plan_cta_click`, `calculator_used`).
8. Experiment carefully: test layout and copy before price points; ensure consistent charge vs displayed price.

## Patterns
- **"Everything in X, plus…"** card lists to emphasize deltas.
- **Seat stepper on card:** live total ("5 seats · $125/month").
- **Usage calculator:** sliders plus number inputs for key meters, with estimated monthly cost and a breakdown. Link to the detailed rate table.
- **Plan recommender:** 2–3 questions → highlight a plan (without hiding others).
- **Sticky mobile plan switcher:** segmented control to view one plan at a time in the comparison table.
- **Nonprofit/education/startup program** link under FAQ.

## Anti-Patterns
- **Monthly-equivalent price with annual billing hidden in small print.** Fix: show billed-annually total adjacent.
- **"Contact us" for all tiers.** Loses self-serve buyers. Fix: publish self-serve prices; reserve contact for enterprise.
- **Identical feature lists across cards.** Fix: differentiators only; full table below.
- **Client-side price swap after hydration (currency/interval).** Flicker, CLS, wrong prices for crawlers. Fix: server-render the chosen variant.
- **Hard-coded prices in JSX separate from billing.** Drift. Fix: shared config/catalog + tests.
- **Fake "Most popular" or fake discounts.** Deceptive. Fix: data-backed labels; genuine reference prices.
- **Cancellation info missing.** Fix: FAQ + near-CTA disclosure.
- **Tooltips as the only place key limits are explained.** Fix: visible text for important limits.

## Accessibility
- Billing toggle: a real radio group or switch with a visible label ("Billing period"). Price changes announced via polite live region ("Prices now shown billed annually").
- Price text readable by screen readers: "$20 per user per month, billed annually at $240 per year". Avoid splitting "$" and "20" into separate elements that announce oddly. Check with a screen reader.
- Comparison table: real `<table>` with `<th scope="col">` plan headers and `<th scope="row">` features; icons have text alternatives ("Included", "Not included") (WCAG 1.3.1, 1.1.1).
- "Most popular" badge not conveyed by color/border alone.
- Calculator sliders paired with number inputs (see [sliders-and-range-inputs](../sliders-and-range-inputs/Skill.md)).
- Sticky table headers must not obscure focused cells (2.4.11).

## Responsive Design
- Cards stack vertically on mobile, with the recommended plan first or clearly marked. Alternatively, a horizontal snap carousel with visible indicators (less discoverable, so test).
- Comparison table on mobile: one plan column at a time with a plan switcher, or collapsed feature groups. Avoid 4-column tables squeezed to 360px.
- Keep CTA and price visible together on each card.

## Performance
- Static HTML with prices; the toggle island is tiny.
- Avoid heavy animation libraries for the toggle; CSS transitions suffice.
- Lazy-render the full comparison table below the fold (still server-rendered HTML for SEO; hydrate only interactive parts).

## Security
- Never trust plan, price, or interval from the query string at checkout. Resolve server-side from plan ID against the catalog.
- Discount/coupon params validated server-side; rate-limit coupon checks.
- Don't expose internal price IDs that allow purchasing unlisted plans without server authorization rules.

## Testing
- Unit: price formatting per currency and interval; annual total math; calculator math parity with billing module.
- Contract test: pricing config matches billing provider catalog (script comparing IDs/amounts in CI against test mode).
- E2E: toggle interval → prices and CTA hrefs update; CTA leads to checkout with correct plan.
- Visual regression on cards and table at mobile/desktop.
- Accessibility: table semantics, toggle announcements, keyboard operation.

## Tooling
- Billing catalogs: Stripe Products/Prices, Paddle, Chargebee, Lemon Squeezy, Orb/Metronome (usage-based).
- Embeddable tables: Stripe Pricing Table (fast, less control; loads third-party script).
- Formatting: `Intl.NumberFormat`.
- URL state: nuqs for `billing` and `currency` params.

## Framework Notes
- **Next.js App Router (primary):**
  - `app/(marketing)/pricing/page.tsx` as a Server Component reading plans config (or cached catalog fetch with `cacheTag("plans")`, revalidated from billing webhooks via `revalidateTag("plans", "max")`).
  - Interval via `searchParams` makes the page dynamic per request. For fully static pages, render both intervals in HTML and toggle visibility with CSS/radio state, or use static `/pricing` + `/pricing/annual` routes.
  - `generateMetadata` with clear title ("Pricing | Acme"), canonical to `/pricing`.
  - CTA → Server Action that validates plan ID and creates a checkout session.
- **React (Vite SPA):** pricing pages should be prerendered for SEO. If in-app only (plan picker), read plans from the API used by billing, never a duplicated constant.

## AI Agent Guidance
- Never invent prices, discounts, or "most popular" labels. Pull from config or mark placeholders clearly.
- Always show the billing interval and the annual total when displaying monthly equivalents.
- Render default prices on the server; no hydration swaps.
- Flag subscription disclosures and tax statements for legal review.
- Verify before done:
  - [ ] Prices come from the shared plans config/catalog
  - [ ] Interval toggle accessible and announced; CTAs carry plan + interval
  - [ ] Comparison table uses proper table semantics with text for icons
  - [ ] Renewal/trial/cancellation disclosures near CTAs
  - [ ] No CLS or flicker from currency/interval changes
  - [ ] Checkout re-validates plan server-side

## Examples

```tsx
// Accessible billing interval toggle (radio group, URL-synced)
"use client";
import { useRouter, useSearchParams } from "next/navigation";

export function BillingToggle() {
  const params = useSearchParams(); const router = useRouter();
  const value = params.get("billing") === "annual" ? "annual" : "monthly";
  const set = (v: string) => { const p = new URLSearchParams(params); p.set("billing", v); router.replace(`?${p}`, { scroll: false }); };
  return (
    <fieldset className="billing-toggle">
      <legend>Billing period</legend>
      {[{ v: "monthly", l: "Monthly" }, { v: "annual", l: "Annual (save 20%)" }].map(o => (
        <label key={o.v}><input type="radio" name="billing" value={o.v} checked={value === o.v} onChange={() => set(o.v)} />{o.l}</label>
      ))}
      <p role="status" className="sr-only">{value === "annual" ? "Prices shown billed annually" : "Prices shown billed monthly"}</p>
    </fieldset>
  );
}
```

```tsx
// Price text that reads well to screen readers
function Price({ perSeatMinor, currency, interval }: { perSeatMinor: number; currency: string; interval: "monthly" | "annual" }) {
  const fmt = (m: number) => new Intl.NumberFormat("en-US", { style: "currency", currency, maximumFractionDigits: 0 }).format(m / 100);
  const monthly = interval === "annual" ? perSeatMinor / 12 : perSeatMinor;
  return (
    <p className="price">
      <span className="amount">{fmt(monthly)}</span> per user / month
      {interval === "annual" && <span className="billed">, billed annually at {fmt(perSeatMinor)} per user</span>}
    </p>
  );
}
```

## Related Skills
- [landing-page-design](../landing-page-design/Skill.md) — upstream traffic and CTA patterns
- [checkout-flow-design](../checkout-flow-design/Skill.md) — payment after plan selection
- [saas-application-patterns](../saas-application-patterns/Skill.md) — entitlements and in-app upgrades
- [accessible-data-tables](../accessible-data-tables/Skill.md) — comparison table semantics
- [conversion-ux](../conversion-ux/Skill.md) — decision and CTA heuristics
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — honest pricing, cancellation
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — interval/currency URL state
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md) — calculator inputs

## Sources
- [NN/g — Explicitly state the difference between options](https://www.nngroup.com/articles/explicit-differences/) — Official research — explicit option differences for expensive decisions
- [NN/g — B2B Website Usability report](https://www.nngroup.com/reports/b2b-websites-usability/) — Official research — pricing transparency expectations (summary level)
- [Google Search Central — structured data updates (FAQ rich results no longer shown as of May 7, 2026)](https://developers.google.com/search/updates) — Official — structured data expectations
- [Stripe Docs — Online payments / Checkout Sessions](https://docs.stripe.com/payments/online-payments) — Official — catalog-driven checkout
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — table semantics, status messages, focus not obscured
- FTC ROSCA guidance and state automatic renewal laws (ftc.gov; state statutes) — Official — subscription disclosure/cancellation (summary; the 2024 click-to-cancel rule was vacated in 2025)

## License / Usage Notes
Principles paraphrased; code original. Legal notes are informational, not legal advice.

## Quality Tier
A — Grounded in NN/g research, official Google/Stripe docs, and WCAG; subscription law summary is jurisdiction-dependent and must be verified.

## Status
Active

## Last Verified
2026-09-15
