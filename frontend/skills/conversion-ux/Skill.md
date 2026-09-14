# Conversion UX

## Summary
Conversion UX is the practice of removing friction and uncertainty from the paths where users commit: signup, trial start, upgrade, purchase, lead forms, and key in-app actions. It combines research-backed friction removal (Baymard, NN/g), clear value communication, trust signals, and disciplined experimentation — without manipulation. This skill covers funnel diagnosis, friction checklists, CTA and form design, trust, and experiment implementation in Next.js.

## Category
UX

## Subcategories
funnels, CTAs, signup conversion, trial-to-paid, checkout friction, trust signals, social proof, A/B testing, CRO, form optimization

## Problem It Solves
Teams chase conversion with pop-ups, urgency timers and button-color tests while the real causes are unexpected costs, forced account creation, long forms, unclear value, slow pages and missing trust information. Baymard's research finds extra costs (~39%), mandatory account creation (~19%) and complicated processes (~18%) among top abandonment reasons; average documented cart abandonment is ~70%.

## When To Use
- Optimizing signup, onboarding-to-activation, upgrade, checkout, demo request, or lead-gen flows.
- Designing CTAs and pricing/plan selection moments.
- Planning A/B tests.

## When Not To Use
- As justification for dark patterns (fake urgency, hidden costs, confirmshaming) — they raise short-term numbers, harm retention and trust, and carry regulatory risk.
- When sample sizes are too small for experiments: use qualitative research instead.

## Core Principles
1. **Diagnose before optimizing**: find where and why users drop (analytics + session replays + usability tests + surveys).
2. **Reduce friction**: fewer fields, fewer steps, fewer decisions, faster pages.
3. **Reduce uncertainty**: total cost, what happens next, cancellation terms, data use — shown before commitment.
4. **Clear value proposition near the CTA**: what they get, in user terms.
5. **One primary CTA per view**, specific label, visually dominant.
6. **Trust is earned with real evidence**: real reviews, security info, recognizable payment methods, clear policies.
7. **Measure the right metric**: downstream (activation, retention, revenue, refunds), not just clicks.
8. **Ethical persuasion only**: help users decide, never trick them.

## Best Practices
- Guest checkout / try-before-signup; offer account creation after completion (prefilled).
- Show full price including taxes/shipping/fees as early as possible.
- Signup: SSO + passkey/email; ask only what's needed now; no password confirmation field (use show password).
- CTA labels state outcome: "Start free trial", "Get my quote", "Add to cart" — not "Submit".
- Microcopy next to CTAs removing risk: "No credit card required", "Cancel anytime in Settings".
- Inline validation on blur, autofill attributes (`autocomplete`), correct input types for mobile keyboards.
- Show accepted payment methods and support wallets (Apple Pay, Google Pay, Link) where relevant.
- Keep users in the flow: no site nav distractions in checkout; clear progress.
- Page speed: every conversion page must meet Core Web Vitals "good".
- Pricing: highlight a recommended plan honestly; monthly/annual toggle states savings plainly; feature comparison accessible.
- Social proof must be real and attributable (named customers, verified reviews with counts).
- Exit-intent and pop-ups: avoid on mobile; never block the task; easy close.
- Test one hypothesis at a time; pre-register metric, sample size, and duration.

## Implementation Guidance

Friction audit checklist:

```md
- [ ] Steps from landing to commit counted; any removable/deferrable?
- [ ] Fields: each required field justified; optional fields marked "(optional)"
- [ ] Autocomplete attributes and input types on every field
- [ ] Total cost visible before final step; no surprise fees
- [ ] Guest path available; account creation not forced
- [ ] Primary CTA specific, visible without scrolling on mobile
- [ ] Risk-reducers near CTA (trial terms, cancellation, refund)
- [ ] Errors specific, inputs preserved
- [ ] LCP < 2.5s, INP < 200ms on p75 mobile
- [ ] Trust: security, contact, policies, real reviews
- [ ] No dark patterns (see ethical-design-and-dark-patterns)
```

Diagnosis-to-fix table:

| Symptom | Likely cause | Fix to test |
|---|---|---|
| High drop at signup form | Too many fields, forced password rules | SSO/passkey, email-only first step |
| Drop at shipping/total step | Unexpected costs | Show costs earlier; free shipping threshold on cart |
| Pricing page exits | Unclear plan fit | Plan recommendations by use case; FAQ near plans |
| Trial started, not activated | Onboarding gap | Checklist, templates, empty states |
| Mobile conversion << desktop | Form/keyboard issues, slow | Input types, autofill, wallets, performance |
| High form error rate on a field | Format strictness | Accept flexible formats (Postel's Law) |

Experiment implementation (Next.js App Router, server-side assignment to avoid flicker):

```ts
// lib/experiments.ts
import { cookies } from "next/headers";
export async function getVariant(experiment: string, variants: readonly string[]) {
  const store = await cookies();
  const key = `exp_${experiment}`;
  const existing = store.get(key)?.value;
  if (existing && variants.includes(existing)) return existing;
  // Assign deterministically via your flag provider in real apps (PostHog, Statsig, LaunchDarkly, Vercel Flags SDK)
  return variants[Math.floor(Math.random() * variants.length)];
}
```

```tsx
// app/(marketing)/pricing/page.tsx — variant decided on server; no client flicker
import { getVariant } from "@/lib/experiments";
export default async function Pricing() {
  const variant = await getVariant("pricing_cta_copy", ["control", "risk_reducer"] as const);
  return (
    <PlanCard
      cta="Start free trial"
      ctaNote={variant === "risk_reducer" ? "14 days free. No credit card required." : undefined}
      data-experiment={`pricing_cta_copy:${variant}`}
    />
  );
}
```

Note: set assignment cookies in a Server Action, Route Handler, or proxy (cookies can't be set during Server Component render), and log exposure events server-side.

## Recommended Workflow
1. Define macro conversion and guardrail metrics (refunds, churn, activation, support contacts).
2. Instrument funnel steps; segment by device, source, new vs returning.
3. Qualitative: 5-8 usability sessions on the funnel, session replays, on-exit survey ("What stopped you today?").
4. Prioritize issues (impact x confidence x effort).
5. Fix obvious usability defects directly (no test needed for broken things).
6. A/B test uncertain changes with adequate power; run full business cycles (>= 1-2 weeks).
7. Ship winners; check guardrails over 30-90 days.

## Patterns
- **Value-CTA-reassurance stack**: headline benefit -> primary CTA -> risk reducer line.
- **Sticky mobile CTA bar** on long product/pricing pages.
- **Deferred account creation** on confirmation page with prefilled email.
- **Express checkout** buttons above the form.
- **Plan recommender**: 2-3 questions -> recommended plan (honest).
- **Transparent cost breakdown** in cart/drawer.
- **Save for later / resume** emails with explicit consent.

## Anti-Patterns
- **Fake urgency/scarcity timers** — erodes trust, regulatory action. Fix: real deadlines/stock only.
- **Hidden fees at the last step** — top abandonment cause. Fix: show totals early.
- **Forced account creation** — Fix: guest checkout.
- **Pre-checked add-ons/insurance** — sneaking. Fix: opt-in.
- **Button-color test theater** — tiny effects, false positives. Fix: test meaningful hypotheses.
- **Peeking and stopping tests early** — inflated results. Fix: fixed horizon or sequential testing methods.
- **Client-side A/B flicker** (content swaps after paint) — hurts CLS and validity. Fix: server-side assignment.
- **Optimizing click-through that increases refunds/churn** — Fix: guardrail metrics.

## Accessibility
- Accessible forms (labels, errors, autocomplete — 1.3.5 identify input purpose) directly raise conversion.
- Target size (2.5.8) for CTAs; focus visible; no time limits on checkout without extension (2.2.1).
- Pop-ups/modals must be dismissible with keyboard and not trap users.
- Accessible authentication (3.3.8) and redundant entry (3.3.7) apply to signup/checkout.

## Responsive Design
- Mobile-first funnel: CTA in thumb zone, correct keyboards (`inputmode`, `type="email"`/`tel`), wallets, minimal typing.
- Avoid interstitials covering content on mobile.

## Performance
- Conversion pages: prioritize LCP (hero/CTA), minimize third-party tags (analytics, chat widgets) or load after interaction.
- Server-render experiment variants; avoid anti-flicker snippets that hide the page.

## Security
- Payment fields via PCI-compliant hosted fields (Stripe Elements/Checkout); never handle raw card data.
- Bot protection with low friction (invisible challenges, rate limiting) instead of CAPTCHAs that hurt conversion and accessibility.
- Consent for tracking per GDPR/ePrivacy; experiments must respect consent choices.

## Testing
- Funnel E2E tests (Playwright) for each variant to prevent broken experiments.
- Statistical rigor: power analysis, sample ratio mismatch checks.
- Lighthouse CI budgets on conversion pages.

## Tooling
- PostHog, Amplitude, GA4 for funnels; Statsig, LaunchDarkly, GrowthBook, Vercel Flags SDK for experiments; Hotjar/PostHog/Microsoft Clarity for replays (mask PII); Baymard premium research (paid) for checkout benchmarks.

## Framework Notes
- **Next.js (App Router)**: server-side flag evaluation (Flags SDK / provider SDK) in Server Components or proxy; static variants via precomputed flags for cached marketing pages; Server Actions for form submission with progressive enhancement (forms work before hydration — improves conversion on slow devices).
- **React (Vite SPA)**: bootstrap flags before first render (inline config or blocking fetch) to avoid flicker; lazy-load analytics.

## AI Agent Guidance
- Do: run the friction audit; write specific CTAs with honest risk reducers; add `autocomplete`/input types; keep one primary CTA; respect consent.
- Don't: add fake urgency, pre-checked upsells, hidden fees, confirmshaming, or exit pop-ups; don't implement client-side flicker experiments.
- Verify: full funnel on mobile emulation; totals visible early; performance budgets pass; no dark patterns.

## Examples
```tsx
// Value-CTA-reassurance stack
export function TrialCta() {
  return (
    <div className="flex flex-col items-start gap-3">
      <h2 className="text-2xl font-semibold">Ship docs your team actually updates</h2>
      <a href="/signup" className="btn-primary min-h-12 px-6">Start free trial</a>
      <p className="text-sm text-neutral-600">14 days free · No credit card required · Cancel anytime in Settings</p>
    </div>
  );
}
```

## Related Skills
- [checkout-flow-design](../checkout-flow-design/Skill.md) — commerce checkout specifics
- [pricing-page-patterns](../pricing-page-patterns/Skill.md) — plan presentation
- [landing-page-design](../landing-page-design/Skill.md) — top-of-funnel pages
- [form-design-ux](../form-design-ux/Skill.md) — form friction
- [authentication-ux](../authentication-ux/Skill.md) — signup friction
- [feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md) — experiment infrastructure
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — boundaries of persuasion
- [core-web-vitals](../core-web-vitals/Skill.md) — speed as conversion factor

## Sources
- [Baymard Institute: Reasons for Cart Abandonment / Reduce Cart Abandonment](https://baymard.com/learn/reduce-cart-abandonment) — Community (research) — extra costs ~39%, forced account ~19%, complexity ~18%, ~70% average abandonment
- [Baymard: Cart Abandonment Rate statistics](https://baymard.com/lists/cart-abandonment-rate) — Community (research)
- [NN/g: Conversion Rate definitions and usability](https://www.nngroup.com/articles/conversion-rates/) — Community
- [GOV.UK Service Manual: Measuring success](https://www.gov.uk/service-manual/measuring-success) — Official — completion rate
- [Vercel Flags SDK](https://flags-sdk.dev/) — Open Source — server-side flag evaluation
- [deceptive.design](https://deceptive.design/types/) — Community — patterns to avoid

## License / Usage Notes
Baymard statistics cited as published summaries (full research is paywalled; do not reproduce). Code original.

## Quality Tier
A — strong research backing; specific lift numbers are context-dependent and must be validated per product.

## Status
Active

## Last Verified
2026-09-15
