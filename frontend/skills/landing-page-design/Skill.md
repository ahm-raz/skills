# Landing Page Design

## Summary
How to design and build single-purpose landing pages (campaign, product launch, waitlist, lead-gen, signup) that convert. It covers section anatomy and order, message match, trust and proof, the conversion mechanics of one primary call to action, and the technical side: static rendering, LCP-first hero, attribution capture, consent-aware analytics, and experimentation. It is aimed at engineers and coding agents who build these pages from a brief rather than from a finished design.

## Category
Product Patterns

## Subcategories
Conversion rate optimization, hero sections, social proof, lead capture, campaign pages, A/B testing, attribution/UTM, static rendering

## Problem It Solves
Landing pages are often built as generic "hero + three feature cards + footer" templates. The headline doesn't match the ad or email that brought the visitor. The page offers many competing actions, the proof is vague, and the hero loads slowly or shifts, so visitors bounce before they read. Attribution is also lost between the click and the signup. This skill gives a repeatable structure and technical baseline so each page has one job and does it measurably.

## When To Use
- Paid, email, social, or partner campaigns that send traffic to a dedicated URL.
- Product or feature launches, waitlists, beta signups, webinar or event registration.
- Lead-gen pages (demo request, content download) for B2B.
- Rebuilding a homepage hero or above-the-fold section with a conversion goal.

## When Not To Use
- Multi-page marketing site structure, navigation, and CMS modeling: use [marketing-website-architecture](../marketing-website-architecture/Skill.md).
- Pricing tables and plan comparison: use [pricing-page-patterns](../pricing-page-patterns/Skill.md).
- Editorial/blog content: use [content-and-blog-sites](../content-and-blog-sites/Skill.md).
- In-app upgrade prompts and activation flows: use [onboarding-ux](../onboarding-ux/Skill.md) and [saas-application-patterns](../saas-application-patterns/Skill.md).

## Core Principles
1. **One page, one goal.** Every section moves the visitor toward a single primary conversion. Any secondary action ("watch demo") must support that goal, not compete with it.
2. **Message match.** The H1 repeats the promise of the ad, email, or link that brought the visitor, in their words.
3. **Clarity before cleverness.** Within about five seconds a visitor should be able to answer three questions: what is it, who is it for, and what do I do next.
4. **Proof near claims.** Put a specific piece of evidence (a metric, logo, quote, or screenshot) next to each major claim.
5. **Reduce commitment.** Ask for the minimum (often only an email), and say what happens after the click.
6. **Fast and stable is part of the pitch.** The hero is the LCP element. It must render from HTML without waiting on client JavaScript, and it must not shift.
7. **Measure honestly.** Define the conversion event before building. Keep attribution through to the backend. Respect consent.
8. **No dark patterns.** No fake countdowns, fake scarcity, confirmshaming, or pre-checked marketing opt-ins (see [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md)).

## Best Practices
- Headline: outcome-focused, 6–12 words, and concrete ("Close your books in 3 days, not 10"), not generic ("The future of finance").
- Subheadline: one or two sentences that name the audience and the mechanism.
- Primary CTA: verb + value ("Start free trial", "Get the report"), not "Submit". Repeat it after major sections and at the end. Keep label and color consistent.
- Put microcopy under the CTA to remove risk: "No credit card required · Cancel anytime". Only say it if it is true.
- Hero visual: show the actual product UI or outcome. Avoid abstract stock art.
- Social proof strip directly under the hero: recognizable logos, a rating with its source, or a usage number with a date.
- Testimonials: real name, role, company, and photo, plus a specific result. Anonymous quotes carry little weight.
- Objection handling: an FAQ near the bottom covering price, security, switching cost, and time to value.
- Reduce navigation on paid-traffic pages. A logo linking home plus one CTA is common. Keep legal and privacy links in the footer.
- Forms: fewest fields possible. Enrich firmographics server-side instead of asking. Use correct `autocomplete` and `type` attributes.
- Mobile: the CTA should be visible without scrolling on common viewports (about 360×640). Consider a sticky bottom CTA after the hero scrolls out.
- Write for scanning: short paragraphs, meaningful subheads, and bullets that each hold one idea.

## Implementation Guidance

### Section anatomy (default order)
| # | Section | Job | Required content |
|---|---------|-----|------------------|
| 1 | Header | Orientation | Logo, optional minimal nav, CTA button |
| 2 | Hero | Value proposition | H1, subhead, primary CTA, risk-reducer microcopy, product visual |
| 3 | Proof strip | Credibility | 4–8 logos or a rating/usage stat |
| 4 | Problem / stakes | Relevance | 2–3 pain points in customer language |
| 5 | Benefits / how it works | Understanding | 3 steps or 3–4 benefits, each with a visual |
| 6 | Feature deep dives | Desire | Alternating media/text blocks tied to outcomes |
| 7 | Testimonials / case study | Trust | Named quotes with metrics |
| 8 | Objections / FAQ | Remove friction | 5–8 questions (use native disclosure) |
| 9 | Final CTA | Conversion | Restated promise + CTA |
| 10 | Footer | Compliance | Privacy, terms, cookie settings, contact |

Reorder by awareness level. Cold traffic needs sections 4–5 before features. Warm traffic (retargeting, existing users) can go almost straight from hero to CTA.

### Rendering decision table
| Situation | Strategy |
|-----------|----------|
| Static campaign copy | SSG/prerender at build; deploy to CDN |
| CMS-edited by marketing | SSG + on-demand revalidation (webhook) |
| Personalized by geo/segment | Static shell + edge variant selection; never personalize the H1 via client-side swap (causes CLS/flicker) |
| A/B test | Assign the variant at the edge or server (cookie) and render that variant's HTML; avoid client-side anti-flicker snippets that hide the page |

### Attribution capture
Capture UTM parameters and click IDs on first landing and persist them first-party, then send them with the conversion to your backend. Don't rely only on client analytics, which ad blockers and consent refusal remove.

```ts
// lib/attribution.ts — first-touch + last-touch capture, first-party storage
const KEYS = ["utm_source","utm_medium","utm_campaign","utm_term","utm_content","gclid","fbclid"] as const;

export function captureAttribution(url = new URL(location.href)) {
  const params = Object.fromEntries(
    KEYS.map(k => [k, url.searchParams.get(k)]).filter(([, v]) => v)
  );
  if (Object.keys(params).length === 0) return;
  const stamped = { ...params, landing_path: url.pathname, ts: Date.now() };
  if (!localStorage.getItem("attr_first")) localStorage.setItem("attr_first", JSON.stringify(stamped));
  localStorage.setItem("attr_last", JSON.stringify(stamped));
}

export function attributionPayload() {
  return {
    first: JSON.parse(localStorage.getItem("attr_first") ?? "null"),
    last: JSON.parse(localStorage.getItem("attr_last") ?? "null"),
  };
}
```

## Recommended Workflow
1. Write the brief: audience, traffic source, awareness level, single conversion event, and success metric.
2. Draft copy before layout: H1, subhead, CTA, three benefits, proofs, and FAQ.
3. Choose section order from the anatomy table based on awareness level.
4. Build a static, semantic page. Make the hero image the preloaded, high-priority LCP resource.
5. Wire the conversion: form → server action/API → CRM. Include attribution. Show a success state that sets expectations for what happens next.
6. Add analytics events for CTA click, form start, form submit success, and form error, gated by consent.
7. Check performance and accessibility: Lighthouse, keyboard pass, screen reader on hero and form.
8. Ship. Then run one A/B test at a time on the highest-leverage element (headline or offer before button color).

## Patterns
- **Hero split:** text column (H1, subhead, CTA) + product visual; stacks text-first on mobile.
- **Proof-adjacent claim:** `<p>Cut onboarding time by 40%</p><cite>— Acme, 1,200-seat rollout</cite>`.
- **Sticky mobile CTA:** appears after the hero CTA leaves the viewport (IntersectionObserver). Hide it when the final CTA is visible.
- **Inline email capture:** single `type="email"` field + button in the hero. Progressive profiling happens later.
- **Two-path CTA:** primary "Start free" + secondary text link "Talk to sales" for enterprise visitors.
- **Waitlist with position:** after submit, show queue position and a referral link (only if real).

## Anti-Patterns
- **Carousel hero with rotating messages.** Users miss most slides and it hurts LCP. Fix: one message; test alternatives with A/B.
- **Client-rendered hero (spinner, then content).** Delays LCP and hurts SEO. Fix: SSG/SSR the hero markup.
- **Anti-flicker snippet that hides `body` until the testing script loads.** Blank page for seconds. Fix: server/edge variant assignment.
- **"Learn more" everywhere.** The CTA is ambiguous. Fix: specific verb + object.
- **Gated demo with 11 form fields.** Fix: email + company; enrich server-side; qualify later.
- **Fake urgency timers that reset on reload.** Deceptive, erodes trust, and increases regulatory risk. Fix: real deadlines only.
- **Logo wall of companies that aren't customers.** Fix: use only logos you have permission to show.
- **Autoplay video with sound / huge background video.** Fix: poster image, muted, user-initiated, or no video on mobile.

## Accessibility
- One `<h1>`; logical heading order (WCAG 1.3.1). Landmarks: `header`, `main`, `footer`.
- CTA links vs buttons: navigation uses `<a>`, form submit uses `<button type="submit">`.
- Text contrast ≥ 4.5:1, including text over hero imagery (add a scrim) (1.4.3).
- Logos need `alt` with the company name, or the strip needs an accessible label such as "Trusted by Acme, Globex…".
- Video: captions, no autoplay with audio, pause control for motion over 5 seconds (2.2.2). Honor `prefers-reduced-motion`.
- Forms: visible labels, errors announced and tied to the field via `aria-describedby` (3.3.1, 3.3.3). See [accessible-forms](../accessible-forms/Skill.md).
- Sticky CTAs must not obscure focused elements (2.4.11 Focus Not Obscured).

## Responsive Design
- Design mobile first. Paid social traffic is typically mostly mobile.
- Hero: stack text above visual on narrow screens. Crop or art-direct the visual with `<picture>`.
- Tap targets ≥ 24×24 CSS px (WCAG 2.5.8), practically 44px for primary CTAs.
- Use `svh` for "full-height" heroes to avoid jumps when mobile browser UI appears.
- Logo strips: wrap into a grid rather than horizontal auto-scroll marquees.

## Performance
- Targets at p75: LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1.
- Hero image: responsive `srcset`, AVIF/WebP, `fetchpriority="high"`, never `loading="lazy"`. Set explicit width/height.
- Fonts: subset, `font-display: swap` or `optional`, preload only the hero font file.
- Third-party tags (pixels, chat, heatmaps) are the main regression source. Load them after consent and after first interaction or idle. See [third-party-script-management](../third-party-script-management/Skill.md).
- Target under 100 KB of JavaScript for a static landing page. Many need almost none.

## Security
- Forms: server-side validation, rate limiting, and bot protection (honeypot field + privacy-friendly challenge). Never trust client-side-only validation.
- Don't put CRM or API keys in client bundles. Post to your own endpoint, which forwards to the CRM.
- Consent: load marketing pixels only after consent where required (GDPR/ePrivacy, US state privacy laws).
- Set a CSP that allowlists analytics domains (see [content-security-policy](../content-security-policy/Skill.md)).

## Testing
- E2E (Playwright): the CTA submits the form, the success state appears, and the payload includes attribution.
- Visual regression on hero at 360, 768, and 1280 widths.
- Lighthouse CI budget on LCP/CLS and JS size.
- axe automated scan + manual keyboard and screen reader pass.
- Analytics QA: verify events fire once, only after consent, with correct variant labels.

## Tooling
- Next.js App Router (static routes by default; `output: "export"` only if you need a pure static host). Content-first alternatives like Astro exist but are out of scope for this library.
- Headless CMS (Sanity, Contentful, Payload, Storyblok) when marketing edits copy; MDX via `@next/mdx` for developer-edited pages.
- Experimentation: server or edge flags (GrowthBook, Statsig, LaunchDarkly, Vercel/Netlify edge config).
- Analytics: product analytics (PostHog, Amplitude) + ad platform conversion APIs sent server-side.
- Forms and bot protection: Cloudflare Turnstile or hCaptcha.

## Framework Notes
- **Next.js (App Router, primary):**
  - Page and sections are Server Components. Only the form, sticky CTA, and consent banner are `"use client"` islands.
  - Keep the route static: no `cookies()`/`headers()` in the page. Do variant assignment in `proxy.ts` (formerly `middleware.ts`) by rewriting to `/launch/a` or `/launch/b` static routes.
  - `export const metadata` (or `generateMetadata` for CMS pages) for title, description, `openGraph`, `alternates.canonical`. Add `opengraph-image.tsx` for generated OG images.
  - `next/image` with `loading="eager"` + `fetchPriority="high"` plus `sizes` on the hero (`priority` is deprecated since Next.js 16; use `preload` only for late-discovered images); `next/font` for self-hosted, subsetted fonts with no layout shift.
  - The form posts to a Server Action (`<form action={signup}>`), which works before hydration. Validate with Zod server-side, then `useActionState` for pending and error UI.
  - Campaign pages meant only for paid traffic: `robots: { index: false }` in metadata and exclude them from `sitemap.ts`.
  - `next/script` with `strategy="lazyOnload"` for non-critical tags, loaded only after consent.
- **React (Vite SPA):** a poor fit for SEO-relevant landing pages because the hero depends on client JS. If you must, prerender the route at build time (e.g., a static prerender plugin), inline critical CSS, and keep the form a plain `<form>` posting to an API.

## AI Agent Guidance
- Ask for or infer: audience, traffic source, the one conversion event, and real proof assets. Never invent testimonials, logos, metrics, or ratings. Use clearly marked placeholders instead.
- Don't default to generic gradient hero + three icon cards. Derive layout and visuals from the product (see [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md)).
- Before declaring done, verify:
  - [ ] Single H1 matching the stated campaign promise
  - [ ] One primary CTA label used consistently; the form works end to end
  - [ ] Hero renders in HTML without client JS; LCP image not lazy-loaded
  - [ ] No layout shift on load (fonts, images, consent banner)
  - [ ] Keyboard and screen reader pass on hero and form
  - [ ] Analytics fire after consent; attribution reaches the backend
  - [ ] No fake urgency or pre-checked opt-ins

## Examples

```tsx
// app/(campaign)/launch/page.tsx — Next.js App Router, static
import Image from "next/image";
import { SignupForm } from "./signup-form"; // client component, small

export const dynamic = "force-static";
export const metadata = { title: "Close your books in 3 days | Ledgerly", description: "Automated reconciliation for finance teams of 5–50." };

export default function Page() {
  return (
    <main>
      <section aria-labelledby="hero-title" className="hero">
        <div>
          <h1 id="hero-title">Close your books in 3 days, not 10</h1>
          <p>Ledgerly reconciles bank, card, and ERP data automatically for finance teams of 5–50.</p>
          <SignupForm cta="Start free trial" />
          <p className="risk">No credit card required · 14-day trial</p>
        </div>
        <Image src="/hero-dashboard.png" alt="Reconciliation dashboard showing 98% auto-matched transactions"
               width={1200} height={800} priority sizes="(min-width: 1024px) 50vw, 100vw" />
      </section>
      <section aria-label="Customers">{/* logos with alt text */}</section>
      {/* problem → how it works → testimonials → FAQ → final CTA */}
    </main>
  );
}
```

```html
<!-- FAQ with native disclosure: accessible, zero JS -->
<details>
  <summary>Do I need a credit card to start?</summary>
  <p>No. You'll only be asked for payment if you choose a paid plan after the trial.</p>
</details>
```

## Related Skills
- [conversion-ux](../conversion-ux/Skill.md) — general conversion heuristics applied here
- [pricing-page-patterns](../pricing-page-patterns/Skill.md) — often the next step after the landing page
- [marketing-website-architecture](../marketing-website-architecture/Skill.md) — site-level structure, CMS, routing
- [seo-for-frontend](../seo-for-frontend/Skill.md) — metadata, indexability of evergreen landing pages
- [lcp-optimization](../lcp-optimization/Skill.md) — hero performance
- [feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md) — A/B testing infrastructure
- [third-party-script-management](../third-party-script-management/Skill.md) — pixels and tags
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — urgency/scarcity limits
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — CTA and headline writing

## Sources
- [Nielsen Norman Group — articles on scanning, headlines, and B2B website usability](https://www.nngroup.com/reports/b2b-websites-usability/) — Official research — scanning behavior, explicit differences, headline clarity
- [web.dev — Core Web Vitals](https://web.dev/articles/vitals) — Official — LCP/INP/CLS thresholds at p75
- [web.dev — Optimize LCP](https://web.dev/articles/optimize-lcp) — Official — hero image priority and discoverability
- [Google Search Central — JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics) — Official — render HTML, real links
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — contrast, focus not obscured, target size
- Community agent skills (e.g., [github/awesome-copilot premium-frontend-ui](https://github.com/github/awesome-copilot/blob/main/skills/premium-frontend-ui/SKILL.md), [joshuadavidthomas frontend-design-principles](https://github.com/joshuadavidthomas/agent-skills/blob/main/frontend-design-principles/SKILL.md)) — Community — separate marketing vs app guidance; avoid templated output

## License / Usage Notes
Principles are summarized and paraphrased from the listed sources; no proprietary text copied. Code examples are original and may be used freely. Framework names are trademarks of their owners.

## Quality Tier
A — Grounded in official performance/accessibility guidance and established usability research; conversion rules are well-established heuristics rather than a single controlled study.

## Status
Active

## Last Verified
2026-09-15
