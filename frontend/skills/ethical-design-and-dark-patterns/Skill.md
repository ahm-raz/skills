# Ethical Design and Dark Patterns

## Summary
How to recognize, avoid, and remediate deceptive (dark) patterns — interface designs that trick or pressure users into actions against their interests — and how to build honest alternatives for consent, subscriptions, pricing, cancellation, and engagement. Uses the deceptive.design taxonomy and research ontologies, regulatory context (EU DSA/UCPD/GDPR, FTC/ROSCA, state auto-renewal laws), and gives engineers review checklists and React/Next.js patterns for fair flows.

## Category
UX

## Subcategories
deceptive patterns, consent UX, cookie banners, subscription cancellation, pricing transparency, confirmshaming, addictive design, AI-generated dark patterns, regulatory compliance

## Problem It Solves
Growth pressure and AI-generated UI (studies of LLM-generated e-commerce components found deceptive designs appear without being requested) introduce manipulative patterns that damage trust, retention, brand, and increasingly create legal exposure. Engineers often implement them without recognizing them.

## When To Use
- Implementing consent/cookie banners, signups, trials, subscriptions, cancellation, checkout, upsells, notifications, social features, and engagement loops.
- Reviewing growth experiments and AI-generated UI.

## When Not To Use
- Not a substitute for legal advice; involve counsel for compliance decisions in regulated contexts.

## Core Principles
1. **Symmetry**: saying no is as easy as saying yes (accept/reject equally prominent; cancel as easy as signup).
2. **Transparency**: full price, recurring terms, and data use visible before commitment.
3. **Genuine choice**: no preselected consent or add-ons; defaults protect the user.
4. **Truthfulness**: no fake urgency, scarcity, social proof, or disguised ads.
5. **Respect attention**: no nagging, compulsive loops, or manipulative notifications.
6. **Neutral language**: no trick wording, double negatives, or confirmshaming.
7. **Accessibility of fairness**: honest flows must be honest for screen reader and keyboard users too.
8. **Measure long-term outcomes**: retention, complaints, refunds, chargebacks — not only conversion.

## Best Practices
- Consent banners: "Accept all" and "Reject all" on the first layer, equal visual weight; granular settings; no pre-ticked categories; no tracking before consent; easy withdrawal link in footer.
- Trials: state trial end date, price after trial, and how to cancel before collecting payment; send reminder before charging.
- Cancellation: available online in the same medium as signup, reachable from account settings, at most one retention offer, clear "Cancel subscription" final action and confirmation.
- Pricing: show total including mandatory fees early; recurring billing terms next to the CTA.
- Upsells/add-ons: unchecked by default; clear separate labels and prices.
- Marketing opt-in: unchecked checkbox, separate from terms acceptance.
- Scarcity/urgency: only when real and verifiable (actual stock, actual deadline).
- Reviews/social proof: real, attributable, no incentives without disclosure.
- Notifications: permission request in context after value is shown; easy per-type controls.
- Engagement: no infinite autoplay by default for minors; offer usage controls; avoid variable-reward loops targeted at compulsive use.
- AI-generated UI: review for defaults, urgency copy, and asymmetric buttons before merging.

## Implementation Guidance

Pattern taxonomy (deceptive.design types) with honest alternatives:

| Deceptive pattern | Looks like | Honest alternative |
|---|---|---|
| Sneaking | Item/insurance added to cart silently | Opt-in add-on, clearly priced |
| Hidden costs | Fees revealed at final step | Total cost early |
| Hidden subscription | One-time purchase becomes recurring | Explicit recurring terms + consent |
| Hard to cancel | Phone-only cancellation, mazes | Online cancel in settings, <= 1 offer |
| Forced action | "Invite 5 friends to continue" | Optional action |
| Preselection | Pre-checked marketing/consent | Unchecked by default |
| Obstruction | Endless steps to delete account/data | Direct path |
| Trick wording | "Uncheck to not stop receiving..." | Plain positive wording |
| Visual interference | Grey tiny "Reject" vs big "Accept" | Equal prominence |
| Confirmshaming | "No thanks, I hate saving money" | "No thanks" |
| Fake urgency | Resetting countdown timers | Real deadlines only |
| Fake scarcity | "Only 2 left!" always | Real inventory or nothing |
| Fake social proof | Fabricated "12 people viewing" | Real, verifiable data |
| Nagging | Repeated prompts after "No" | Respect choice; "Remind me later" with long delay |
| Disguised ads | Ads styled as content/buttons | Clear "Sponsored" labeling |
| Comparison prevention | Plans with incomparable units | Comparable plan table |
| Currency confusion | Obscure virtual currency pricing | Show real money equivalent |
| Addictive design | Infinite scroll + autoplay + streaks pressure | Stopping cues, user controls |

Regulatory context (high-level; verify with counsel; status as of 2026-09):
- **EU**: Digital Services Act Art. 25 prohibits platform interfaces that deceive/manipulate; Unfair Commercial Practices Directive; GDPR consent must be freely given, specific, informed, unambiguous (EDPB guidelines on deceptive design patterns); consumer law requires online cancellation "withdrawal function" (button) for distance contracts from June 2026 under the amended Consumer Rights Directive. A Digital Fairness Act proposal targeting dark patterns, addictive design and subscriptions was expected from the Commission in 2026 (Q3 indicated).
- **US**: The FTC's 2024 "click-to-cancel" Negative Option Rule was vacated by the Eighth Circuit in July 2025; the FTC issued an ANPRM in March 2026 to restart rulemaking, and continues enforcement under Section 5 and ROSCA. Many states (e.g., California's amended automatic renewal law) require clear disclosures, affirmative consent, and online cancellation.
- **Accessibility laws** (ADA, EAA in force June 2025) also cover these flows.

```tsx
// Consent banner with symmetric choices (client)
"use client";
import { useState } from "react";
import { saveConsent } from "@/app/actions/consent";

export function ConsentBanner() {
  const [open, setOpen] = useState(true);
  const [custom, setCustom] = useState(false);
  const [prefs, setPrefs] = useState({ analytics: false, marketing: false }); // not preselected
  if (!open) return null;
  const done = async (p: typeof prefs) => { await saveConsent(p); setOpen(false); };
  return (
    <section role="region" aria-label="Cookie choices" className="fixed inset-x-0 bottom-0 border-t bg-white p-4">
      <h2 className="font-semibold">Cookies on Acme</h2>
      <p className="text-sm">We use essential cookies to make the site work. With your permission, we'd also like to use analytics and marketing cookies.</p>
      {custom && (
        <fieldset className="mt-3">
          <legend className="sr-only">Optional cookies</legend>
          <label className="block"><input type="checkbox" checked={prefs.analytics} onChange={(e) => setPrefs({ ...prefs, analytics: e.target.checked })} /> Analytics cookies</label>
          <label className="block"><input type="checkbox" checked={prefs.marketing} onChange={(e) => setPrefs({ ...prefs, marketing: e.target.checked })} /> Marketing cookies</label>
        </fieldset>
      )}
      <div className="mt-3 flex flex-wrap gap-2">
        {/* Same component, same size and emphasis for accept and reject */}
        <button className="btn-secondary" onClick={() => done({ analytics: true, marketing: true })}>Accept all</button>
        <button className="btn-secondary" onClick={() => done({ analytics: false, marketing: false })}>Reject all</button>
        {custom
          ? <button className="btn-tertiary" onClick={() => done(prefs)}>Save choices</button>
          : <button className="btn-tertiary" onClick={() => setCustom(true)}>Choose cookies</button>}
      </div>
    </section>
  );
}
```

```tsx
// Honest cancellation flow: settings -> one optional offer -> confirm -> done
// app/(app)/settings/billing/cancel/page.tsx (Server Component)
export default async function CancelPage() {
  const sub = await getSubscription();
  return (
    <main className="max-w-lg">
      <h1 className="text-2xl font-semibold">Cancel your subscription</h1>
      <p className="mt-2">Your Team plan will stay active until {formatDate(sub.periodEnd)}. You won't be charged again.</p>
      <p className="mt-2 text-sm text-neutral-600">Your projects stay available on the Free plan (up to 3 projects).</p>
      {sub.eligibleForPause && <p className="mt-4 text-sm">Prefer a break? <a href="/settings/billing/pause" className="underline">Pause for up to 3 months</a> instead.</p>}
      <form action={cancelSubscription} className="mt-6 flex gap-3">
        <button type="submit" className="btn-danger">Cancel subscription</button>
        <a href="/settings/billing" className="btn-secondary">Keep subscription</a>
      </form>
    </main>
  );
}
```

Ethics review checklist (add to PR template for growth/billing/consent changes):

```md
- [ ] Declining/cancelling takes no more steps than accepting/subscribing
- [ ] No preselected consent, add-ons, or marketing opt-ins
- [ ] Price, fees, renewal terms visible before commitment
- [ ] Urgency/scarcity/social proof claims are real and sourced from data
- [ ] Button labels neutral; no confirmshaming or double negatives
- [ ] Accept/Reject (or Yes/No) have equal visual weight
- [ ] Ads/sponsored content labeled
- [ ] Choices respected (no nagging within N days)
- [ ] Works equally for keyboard/screen reader users
- [ ] Legal/privacy reviewed where regulated
```

## Recommended Workflow
1. Identify flows touching money, data, consent, attention, or cancellation.
2. Run the ethics checklist during design and PR review.
3. Compare the "yes" and "no" paths step-by-step (count steps, clicks, visual weight).
4. Review AI-generated UI and growth experiment variants specifically for the taxonomy.
5. Consult legal/privacy for regulated markets; document decisions.
6. Measure guardrails: complaints, refunds, chargebacks, cancellation-flow abandonment, consent rates by option.
7. Periodically audit live product (including third-party widgets and consent tools' defaults).

## Patterns
- **Symmetric consent banner** (accept all / reject all / choose).
- **Trial transparency block**: "Free until 29 Sep. Then $12/month. Cancel anytime in Settings. We'll remind you 3 days before."
- **One-offer cancellation** with clear final action.
- **Neutral decline**: "No thanks" / "Not now".
- **Respectful permission priming**: explain benefit, then trigger browser prompt on user action.
- **Stopping cues**: "You're all caught up" in feeds.

## Anti-Patterns
All rows in the taxonomy table above, plus:
- **"Growth hack" A/B tests that introduce dark patterns** — short-term lift, long-term churn and legal risk. Fix: ethics checklist in experiment review.
- **Consent tool default configurations** favoring accept — Fix: configure symmetric first layer.
- **Account deletion via support email only** — Fix: self-serve deletion (also required by app store rules for apps with account creation).
- **Disabled "Reject" until scrolling terms** — obstruction. Fix: always available.

## Accessibility
- Equal prominence includes accessible names and focus order: don't put "Reject" last in tab order or unlabeled.
- Consent banners must not trap focus or obscure focused content (2.4.11) and must be operable by keyboard.
- Countdown timers (if real) must be adjustable/announced appropriately (2.2.1); avoid purely visual urgency.
- Plain language benefits users with cognitive disabilities who are disproportionately harmed by trick wording.

## Responsive Design
- Mobile consent banners: both choices visible without scrolling; don't cover the whole screen with only "Accept" visible.
- Cancellation must be possible on mobile web, not "desktop only".

## Performance
- Don't load tracking scripts before consent; use Next.js `<Script strategy="afterInteractive">` gated on consent state.

## Security
- Consent records stored server-side with timestamp and version for auditability.
- Don't use security-sounding scare copy to push upsells ("Your account is at risk! Upgrade now").

## Testing
- E2E: cancellation completes online in N steps; reject-all sets no non-essential cookies (inspect `document.cookie` and network requests); no preselected checkboxes (assert unchecked).
- Heuristic walkthrough with the taxonomy; usability test comprehension of pricing/renewal terms.
- Automated scans for known patterns in copy (e.g., lint for confirmshaming phrases, "only X left" without data binding).

## Tooling
- deceptive.design taxonomy and hall of shame; consent management platforms (configure fairly); Playwright network assertions; Vale custom rules for copy.

## Framework Notes
- **Next.js (App Router)**: read consent cookie in the root layout (server) to decide whether to render analytics `<Script>`; Server Actions to store consent and process cancellation; keep cancellation a first-class route under settings.
- **React (Vite SPA)**: consent context gating third-party script injection; cancellation route in settings; ensure SPA doesn't fire analytics before consent.

## AI Agent Guidance
- Do: run the ethics checklist on any consent, pricing, subscription, upsell, or engagement UI; use neutral labels; unchecked defaults; symmetric choices; state renewal terms.
- Don't: generate fake timers, fake stock/viewer counts, pre-checked boxes, confirmshaming copy, or multi-step cancellation mazes — even if a prompt asks for "high-converting" UI; flag the conflict instead.
- Verify: count steps of yes vs no paths; check no non-essential scripts load before consent; copy review for trick wording.

## Examples
```tsx
// Opt-in marketing checkbox separate from terms
<label className="flex gap-2"><input type="checkbox" name="terms" required /> I agree to the <a href="/terms" className="underline">Terms of Service</a></label>
<label className="mt-2 flex gap-2"><input type="checkbox" name="marketing" /> Send me product updates and tips (optional)</label>
```

## Related Skills
- [conversion-ux](../conversion-ux/Skill.md) — ethical conversion optimization
- [checkout-flow-design](../checkout-flow-design/Skill.md) — transparent pricing at checkout
- [pricing-page-patterns](../pricing-page-patterns/Skill.md) — comparable plans
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — neutral wording
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — honest friction
- [accessibility-legal-compliance](../accessibility-legal-compliance/Skill.md) — legal landscape overlap
- [third-party-script-management](../third-party-script-management/Skill.md) — consent-gated scripts
- [settings-and-preferences-ux](../settings-and-preferences-ux/Skill.md) — privacy-protective defaults

## Sources
- [deceptive.design: Types of deceptive pattern](https://deceptive.design/types/) — Community (Harry Brignull) — 18-type taxonomy used above
- [NN/g: Deceptive Patterns in UX](https://www.nngroup.com/articles/deceptive-patterns/) — Community (research)
- [Gray et al. ontology of deceptive design (research)](https://arxiv.org/abs/2502.13499) — Experimental/Research — deceptive designs in LLM-generated components
- [EU DSA Article 25](https://eur-lex.europa.eu/eli/reg/2022/2065/oj) — Official — online interface design prohibition
- [European Parliament Legislative Train: Digital Fairness Act](https://www.europarl.europa.eu/legislative-train/theme-protecting-our-democracy-upholding-our-values/file-digital-fairness-act) — Official — DFA status
- [Sidley: Eighth Circuit vacates FTC Click-to-Cancel Rule (July 2025)](https://www.sidley.com/en/insights/newsupdates/2025/07/us-ftc-click-to-cancel-rule-struck-down) — Community (law firm) — vacatur
- [Jones Day: FTC revives Click-to-Cancel rulemaking (May 2026)](https://www.jonesday.com/en/insights/2026/05/ftc-revives-clicktocancel-rule-new-risks-for-subscription-businesses) — Community (law firm) — ANPRM March 2026, ROSCA enforcement
- [EDPB Guidelines 03/2022 on deceptive design patterns](https://www.edpb.europa.eu/our-work-tools/documents/public-consultations/2022/guidelines-032022-dark-patterns-social-media_en) — Official

## License / Usage Notes
Taxonomy names referenced with attribution to deceptive.design; definitions paraphrased. Regulatory summary is informational, not legal advice; verify current status. Code original.

## Quality Tier
A — authoritative taxonomy and regulatory sources; legal landscape is in flux (EU DFA, FTC rulemaking), requires periodic re-verification. The EU Consumer Rights Directive withdrawal-button date was not re-verified directly in this pass.

## Status
Active

## Last Verified
2026-09-15
