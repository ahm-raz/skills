# Manifest — W10 Product-Type Patterns

Last Verified: 2026-09-15 · Scope: React + Next.js (App Router, TypeScript) per TAXONOMY scope note. Next.js 16.x APIs used: `proxy.ts` (renamed from `middleware.ts`), two-argument `revalidateTag(tag, "max")`, `updateTag`, `"use cache"` + `cacheTag`.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|------|-------|----------|-----------|---------|--------|----------------------|
| landing-page-design | Landing Page Design | Product Patterns | React, Next.js | A | Active | https://web.dev/articles/vitals |
| marketing-website-architecture | Marketing Website Architecture | Product Patterns | Next.js | A | Active | https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes |
| saas-application-patterns | SaaS Application Patterns | Product Patterns | React, Next.js | A | Active | https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html |
| ecommerce-ux-patterns | Ecommerce UX Patterns | Product Patterns | React, Next.js | A | Active | https://baymard.com/lists/cart-abandonment-rate |
| checkout-flow-design | Checkout Flow Design | Product Patterns | React, Next.js | S | Active | https://baymard.com/blog/current-state-of-checkout-ux |
| marketplace-ux-patterns | Marketplace UX Patterns | Product Patterns | React, Next.js | B | Active | https://docs.stripe.com/payments/online-payments |
| documentation-site-patterns | Documentation Site Patterns | Product Patterns | Next.js (Fumadocs, Nextra) | A | Active | https://diataxis.fr/ |
| developer-tool-ui-patterns | Developer Tool UI Patterns | Product Patterns | React, Next.js | B | Active | https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html |
| fintech-ui-patterns | Fintech UI Patterns | Product Patterns | React, Next.js | A | Active | https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants |
| healthcare-ui-patterns | Healthcare UI Patterns | Product Patterns | React, Next.js | A | Active | https://build.fhir.org/ig/HL7/smart-app-launch/app-launch.html |
| mobile-web-app-patterns | Mobile Web App Patterns | Product Patterns | React, Next.js | A | Active | https://www.w3.org/TR/WCAG22/ |
| progressive-web-apps | Progressive Web Apps | Product Patterns | React, Next.js | A | Active | https://web.dev/articles/install-criteria |
| pricing-page-patterns | Pricing Page Patterns | Product Patterns | React, Next.js | A | Active | https://www.nngroup.com/articles/explicit-differences/ |
| content-and-blog-sites | Content and Blog Sites | Product Patterns | Next.js | A | Active | https://developers.google.com/search/docs/appearance/structured-data/article |
| seo-for-frontend | SEO for Frontend | Product Patterns | React, Next.js | S | Active | https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|--------|-----|------|--------------------|----------------|---------|---------------|
| Baymard — Cart abandonment rate statistics | https://baymard.com/lists/cart-abandonment-rate | Official | 70.22% avg abandonment; extra costs #1 reason (~48%); forced account ~19%; long checkout ~18%; 23.48 avg form elements vs 12–14 ideal; ~35% conversion gain | Largest public ecommerce UX research base | A | 2026-09-15 |
| Baymard — Current state of checkout UX | https://baymard.com/blog/current-state-of-checkout-ux | Official | Guest prominence, delivery dates, required+optional marking, adaptive errors, phone explanation, quantity steppers | Concrete checkout guidelines with prevalence data | A | 2026-09-15 |
| Google Search Central — JavaScript SEO basics | https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics | Official | Render pipeline, `<a href>` requirement, soft 404 strategies, JS canonical/noindex rules | Authoritative crawl/render rules for React apps | S | 2026-09-15 |
| Google Search Central — Updates / structured data changes | https://developers.google.com/search/updates | Official | FAQ rich results stopped May 7, 2026; June 2025 retirement of 7 types; HowTo removed | Prevents stale structured-data advice | S | 2026-09-15 |
| Google Search Central Blog — Simplifying search results (2025) | https://developers.google.com/search/blog/2025/06/simplifying-search-results | Official | Retired rich result features | Rich result eligibility | A | 2026-09-15 |
| Google Search Central — Product structured data | https://developers.google.com/search/docs/appearance/structured-data/product | Official | Product snippet vs merchant listing, shipping/returns, variants | Ecommerce SEO | A | 2026-09-15 |
| PCI SSC blog — SAQ A eligibility FAQ | https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants | Official | SAQ A script-attack eligibility criterion replacing 6.4.3/11.6.1 in SAQ A; applies to embedded forms, not redirects | Payment page script control and scope | A | 2026-09-15 |
| Jscrambler / Compass IT / Hyperproof analyses of PCI DSS 4.0.1 | https://jscrambler.com/blog/pci-dss-4-0-1/ | Community | Interpretation of 6.4.3/11.6.1 changes | Corroborates official FAQ | B | 2026-09-15 |
| Stripe Docs — Online payments | https://docs.stripe.com/payments/online-payments | Official | Checkout Sessions recommended over PaymentIntents for most; hosted/embedded/Elements UI options; lifecycle webhooks | Payment integration boundary | A | 2026-09-15 |
| GPayments — 3DS & PSD2 SCA guide (2026) | https://www.gpayments.com/blog/article/3d-secure-and-psd2-strong-customer-authentication-a-guide-for-european-and-uk-psps/ | Community | Frictionless vs challenge, TRA exemption, PSD3/PSR trilogue status | SCA UX context | B | 2026-09-15 |
| web.dev — Install criteria | https://web.dev/articles/install-criteria | Official | Chromium manifest requirements, engagement heuristics, beforeinstallprompt | PWA installability | A | 2026-09-15 |
| W3C — Web Application Manifest | https://www.w3.org/TR/appmanifest/ | Official | Spec is Working Draft (Jan 2026), not CR | Spec maturity caveat | A | 2026-09-15 |
| firt.dev iOS PWA notes; MagicBell iOS PWA guide | https://firt.dev/notes/pwa-ios/ | Community | iOS 26 Home Screen web app default; no beforeinstallprompt; push only for installed apps (16.4+); Declarative Web Push (Safari 18.4) | iOS constraints | B | 2026-09-15 |
| web.dev — Core Web Vitals | https://web.dev/articles/vitals | Official | LCP 2.5s / INP 200ms / CLS 0.1 at p75 | Performance baselines across skills | S | 2026-09-15 |
| Next.js docs — revalidateTag | https://nextjs.org/docs/app/api-reference/functions/revalidateTag | Official | v16.3.5: `revalidateTag(tag, profile)`; single-arg deprecated; `{ expire: 0 }` for webhooks; `cacheTag` with "use cache" | Correct caching APIs in all Next.js examples | S | 2026-09-15 |
| Next.js docs — proxy.ts | https://nextjs.org/docs/app/api-reference/file-conventions/proxy | Official | middleware renamed to proxy in v16; Node runtime default; authz must be inside Server Functions | Auth/edge guidance | S | 2026-09-15 |
| Diátaxis | https://diataxis.fr/ | Official (framework) | Four documentation types and their user needs | Docs IA foundation | A | 2026-09-15 |
| Fumadocs docs | https://www.fumadocs.dev/docs | Open Source | Framework layers, Fumadocs MDX, OpenAPI, LLM integration by default | Primary Next.js docs framework | A | 2026-09-15 |
| Nextra docs | https://nextra.site/docs | Open Source | Nextra 4 is App Router-only; search; page map | Alternative docs framework | A | 2026-09-15 |
| Mintlify — llms.txt docs/blog | https://www.mintlify.com/docs/ai/llmstxt | Community | llms.txt, Accept: text/markdown content negotiation | Agent-readable docs | B | 2026-09-15 |
| HL7 SMART App Launch | https://build.fhir.org/ig/HL7/smart-app-launch/app-launch.html | Official | PKCE S256 mandatory, state entropy, token storage, EHR vs standalone launch, v2 scopes | Healthcare EHR integration security | S | 2026-09-15 |
| HIPAA Journal / law firm analyses of AHA v. Becerra | https://www.hipaajournal.com/ocr-to-appeal-district-court-ruling-in-aha-tracking-technology-case/ | Community | 2024 vacatur of unauthenticated-page portion of OCR tracking bulletin; OCR withdrew appeal | Tracking pixel guidance for health sites | B | 2026-09-15 |
| European Commission — European Accessibility Act | https://commission.europa.eu/strategy-and-policy/policies/justice-and-fundamental-rights/disability/union-equality-strategy-rights-persons-disabilities-2021-2030/european-accessibility-act_en | Official | Ecommerce and banking services in scope | Legal accessibility driver for commerce/fintech | A | 2026-09-15 |
| NN/g — Explicit differences; B2B usability report | https://www.nngroup.com/articles/explicit-differences/ | Official | State option differences explicitly; pricing transparency | Pricing/comparison design | A | 2026-09-15 |
| HTMHell — interactive-widget | https://www.htmhell.dev/adventcalendar/2024/4/ | Community | resizes-visual/resizes-content/overlays-content | Mobile keyboard handling | B | 2026-09-15 |
| WCAG 2.2 | https://www.w3.org/TR/WCAG22/ | Official | 2.4.11, 2.5.7, 2.5.8, 3.3.4, 3.3.7, 3.3.8 and others | Accessibility requirements in all skills | S | 2026-09-15 |
| Community agent skills (github/awesome-copilot premium-frontend-ui; joshuadavidthomas frontend-design-principles; taste-skill) | https://github.com/github/awesome-copilot/blob/main/skills/premium-frontend-ui/SKILL.md | Community | Separating marketing vs app guidance; anti-templated output; agent checklists | Shaped AI Agent Guidance sections | C | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|-------|------------------|-------------------|------------------|
| Cart abandonment statistics | Baymard cart abandonment list | Redstag, Zipchat, ZeroCart, CO Consulting summaries | checkout-flow-design, ecommerce-ux-patterns |
| PCI DSS 4.0.1 SAQ A change | PCI SSC FAQ blog | Hyperproof, Jscrambler, Compass IT, Top Floor, Feroot | checkout-flow-design, fintech-ui-patterns |
| Structured data deprecations 2025–2026 | Google Search Central updates/blog | Relevant Audience, Passionfruit, Elementera, Engage Coders, Proton Effect, SEJ | seo-for-frontend |
| iOS PWA support | firt.dev notes | MagicBell, MobiLoud, PushAlert, Pushly, MoEngage, Insider docs | progressive-web-apps |
| HIPAA tracking technologies ruling | HHS OCR bulletin + HIPAA Journal | Proskauer, Nixon Peabody, Quarles, Arnold & Porter, McDermott, Holland & Hart | healthcare-ui-patterns |
| llms.txt | Mintlify docs (vendor) + llmstxt.org convention | Fern, InfoQ Blume, DEV articles | documentation-site-patterns, seo-for-frontend |
| Dynamic viewport units / keyboard | web.dev viewport units + HTMHell | OpenReplay, savvy.co.il, frontend-tips | mobile-web-app-patterns |
| Landing page vs pricing CTA guidance | NN/g | Agency blogs on SaaS pricing | landing-page-design, pricing-page-patterns |

## Added / Skipped Slugs
- Added: none. Candidates considered: `booking-and-scheduling-ui`, `email-templates` (React Email), `social-feed-patterns`. They are distinct but were not added in this pass; see Gaps.
- Skipped: none.

## Gaps
- WebSearch budget was exhausted mid-research. Baymard product-page/PLP details, NN/g marketplace trust research, FTC fee-rule and click-to-cancel status, EAA microenterprise exemption, and HHS Section 504 compliance dates were written from prior knowledge plus partial fetches. Re-verify before promoting ecommerce/marketplace/pricing/healthcare to S.
- Baymard and NN/g detailed guidelines are paywalled, so only public summaries are used.
- Safari support for `interactive-widget` and iOS keyboard behavior is empirical and version-dependent. Needs real-device verification per iOS release.
- iOS standalone PWA behavior in the EU (DMA) is contradictory across community sources. Apple reversed its early-2024 removal, but a community source still claims removal. Not asserted in the skill; needs an official Apple statement check.
- Serwist compatibility with Turbopack production builds (Next.js 16 default) was not verified.
- Next.js `next/image` `priority` → `preload` rename is referenced loosely; confirm the exact version and deprecation status.
- PSD3/PSR not final (expected adoption H2 2026). Revisit the fintech SCA section after publication.
- No skill yet for booking/scheduling UIs (calendars, slot holds, timezones), transactional email templates (React Email), or social/community feeds. These are candidate slugs for a future pass.
- Healthcare: FDA/IEC 62366 usability engineering and ONC (HTI) certification UI requirements are not covered in depth.
- Marketplace: EU Digital Services Act trader traceability and notice-and-action UI obligations not covered.
