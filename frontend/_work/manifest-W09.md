# Manifest — W09 UX Foundations

Scope: React + Next.js (TypeScript) per TAXONOMY scope note. Last verified 2026-09-15.
Slugs written: 20 / 20. Added: 0. Skipped: 0.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| ui-design-principles-for-engineers | UI Design Principles for Engineers | UX | React, Next.js | A | Active | https://lawsofux.com/ |
| visual-hierarchy-and-layout | Visual Hierarchy and Layout | UX | React, Next.js | A | Active | https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/ |
| information-architecture | Information Architecture | UX | React, Next.js | A | Active | https://www.nngroup.com/topic/information-architecture/ |
| user-flow-design | User Flow Design | UX | React, Next.js | A | Active | https://www.gov.uk/service-manual/design/form-structure |
| onboarding-ux | Onboarding UX | UX | React, Next.js | A | Active | https://www.nngroup.com/articles/mobile-app-onboarding/ |
| empty-states | Empty States | UX | React, Next.js | A | Active | https://www.nngroup.com/articles/empty-state-interface-design/ |
| loading-states | Loading States | UX | React, Next.js | S | Active | https://www.nngroup.com/articles/skeleton-screens/ |
| error-states | Error States | UX | React, Next.js | S | Active | https://design-system.service.gov.uk/components/error-message/ |
| destructive-actions-and-confirmation | Destructive Actions and Confirmation | UX | React, Next.js | A | Active | https://www.nngroup.com/articles/confirmation-dialog/ |
| microcopy-ux-writing | Microcopy and UX Writing | UX | React, Next.js | S | Active | https://atlassian.design/foundations/content/designing-messages/error-messages |
| progressive-disclosure | Progressive Disclosure | UX | React, Next.js | A | Active | https://www.nngroup.com/articles/progressive-disclosure/ |
| usability-heuristics | Usability Heuristics | UX | React, Next.js | S | Active | https://www.nngroup.com/articles/ten-usability-heuristics/ |
| optimistic-ui | Optimistic UI | UX | React, Next.js | S | Active | https://react.dev/reference/react/useOptimistic |
| conversion-ux | Conversion UX | UX | React, Next.js | A | Active | https://baymard.com/learn/reduce-cart-abandonment |
| authentication-ux | Authentication UX | UX | React, Next.js | S | Active | https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html |
| settings-and-preferences-ux | Settings and Preferences UX | UX | React, Next.js | A | Active | https://www.nngroup.com/articles/toggle-switch-guidelines/ |
| ui-inspiration-and-reference-sources | UI Inspiration and Reference Sources | UX | React, Next.js | B | Active | https://component.gallery/ |
| iconography-and-illustration | Iconography and Illustration | UX | React, Next.js | A | Active | https://www.nngroup.com/articles/icon-usability/ |
| ai-chat-interface-ux | AI Chat Interface UX | UX | React, Next.js | A | Active | https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/ |
| ethical-design-and-dark-patterns | Ethical Design and Dark Patterns | UX | React, Next.js | A | Active | https://deceptive.design/types/ |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| NN/g 10 Usability Heuristics | https://www.nngroup.com/articles/ten-usability-heuristics/ | Community | Heuristic names/intent (updated 2024-01-30) | Canonical evaluation framework | S | 2026-09-15 |
| NN/g Progressive Disclosure | https://www.nngroup.com/articles/progressive-disclosure/ | Community | Split rules, two-level limit, staged disclosure | Complexity management | A | 2026-09-15 |
| NN/g Skeleton Screens / Progress Indicators | https://www.nngroup.com/articles/skeleton-screens/ | Community | Duration thresholds, skeleton use <10s | Loading indicator choice | A | 2026-09-15 |
| NN/g Empty States in Complex Apps | https://www.nngroup.com/articles/empty-state-interface-design/ | Community | Status, learnability, direct pathways | Empty-state purpose | A | 2026-09-15 |
| NN/g Confirmation Dialogs | https://www.nngroup.com/articles/confirmation-dialog/ | Community | Rarity, specificity, undo preference, separation | Destructive action design | A | 2026-09-15 |
| Laws of UX | https://lawsofux.com/ | Community | 30 laws (Doherty, Fitts, Hick, Jakob, Gestalt, Goal-Gradient, etc.) | Psychological rationale | A | 2026-09-15 |
| GOV.UK Design System — Error message / summary / validation | https://design-system.service.gov.uk/components/error-message/ | Official | Message patterns, words to avoid, focus summary, preserve input | Best-evidenced error guidance | S | 2026-09-15 |
| Atlassian Design — Error messages | https://atlassian.design/foundations/content/designing-messages/error-messages | Official | Structure, no sorry/please, likely fix first | Content design reference | A | 2026-09-15 |
| Mailchimp Content Style Guide | https://styleguide.mailchimp.com/ | Community | Accessible writing rules; CC BY-NC 4.0 license | Voice/tone reference (non-commercial license) | A | 2026-09-15 |
| Baymard Institute — cart abandonment | https://baymard.com/learn/reduce-cart-abandonment | Community | Extra costs ~39%, forced account ~19%, complexity ~18%, ~70% avg abandonment | Conversion evidence | A | 2026-09-15 |
| Vercel Web Interface Guidelines | https://github.com/vercel-labs/web-interface-guidelines | Open Source | Target sizes, optimistic updates, forms, nested radii (MIT) | Agent-ready UI rules | A | 2026-09-15 |
| React docs — useOptimistic | https://react.dev/reference/react/useOptimistic | Official | Signature, transition requirement, auto revert | Optimistic UI API | S | 2026-09-15 |
| AI SDK UI — useChat | https://ai-sdk.dev/docs/reference/ai-sdk-ui/use-chat | Open Source | status values, stop, regenerate, addToolApprovalResponse (v5+) | AI chat implementation | S | 2026-09-15 |
| vercel/ai-elements | https://github.com/vercel/ai-elements | Open Source | Component families for AI UIs on shadcn/ui | Prebuilt AI chat components | A | 2026-09-15 |
| shadcn/ui June 2026 chat components changelog | https://ui.shadcn.com/docs/changelog/2026-06-chat-components | Open Source | Message, Bubble, Attachment components | Current AI chat primitives | B | 2026-09-15 |
| shapeof.ai | https://www.shapeof.ai/ | Community | AI UX patterns: stream of thought, references, variations, modes, parameters | AI pattern vocabulary | B | 2026-09-15 |
| Microsoft HAX Toolkit | https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/ | Official | 18 human-AI guidelines organized by phase | Human-AI interaction baseline | S | 2026-09-15 |
| Google PAIR Guidebook | https://pair.withgoogle.com/guidebook-v2/ | Official | Calibrated trust, feedback + control, graceful failure (CC BY) | Trust calibration | A | 2026-09-15 |
| Apple HIG — Generative AI | https://developer.apple.com/design/human-interface-guidelines/generative-ai | Official | Transparency, user control (summary-level) | Platform AI guidance | B | 2026-09-15 |
| web.dev — Passkey form autofill | https://web.dev/articles/passkey-form-autofill | Official | `username webauthn`, conditional mediation, conditional create | Passkey UX implementation | S | 2026-09-15 |
| W3C WCAG 2.2 SC 3.3.8 | https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html | Official | Cognitive function test requirements | Auth accessibility compliance | S | 2026-09-15 |
| Auth0 — Guide to WCAG 3.3.8 | https://auth0.com/blog/an-accessible-guide-to-wcag-3-3-8-authentication-without-frustration/ | Community | Practical alternatives (passkeys, magic links) | Implementation angle | B | 2026-09-15 |
| deceptive.design types | https://deceptive.design/types/ | Community | 18 deceptive pattern types | Dark pattern taxonomy | S | 2026-09-15 |
| arXiv 2502.13499 — Deception at Scale (LLM-generated components) | https://arxiv.org/abs/2502.13499 | Experimental | LLM-generated e-commerce components include deceptive designs | Justifies agent guidance | B | 2026-09-15 |
| EU Parliament Legislative Train — Digital Fairness Act | https://www.europarl.europa.eu/legislative-train/theme-protecting-our-democracy-upholding-our-values/file-digital-fairness-act | Official | DFA scope (dark patterns, addictive design), proposal expected 2026 | Regulatory horizon | A | 2026-09-15 |
| Sidley / Jones Day — FTC click-to-cancel status | https://www.jonesday.com/en/insights/2026/05/ftc-revives-clicktocancel-rule-new-risks-for-subscription-businesses | Community | Vacated July 2025; ANPRM March 2026; ROSCA enforcement | US subscription UX risk | B | 2026-09-15 |
| Mobbin Terms of Service | https://mobbin.com/terms | Community | Personal non-commercial license; third-party IP | Inspiration licensing caveat | B | 2026-09-15 |
| Figma Community copyright and licensing | https://help.figma.com/hc/en-us/articles/360042296374-Figma-Community-copyright-and-licensing | Official | Free files CC BY 4.0; additional/paid licenses | Asset reuse rules | A | 2026-09-15 |
| SaaSUI comparison of inspiration sites | https://www.saasui.design/best-saas-ui-design-inspiration | Community | What each inspiration site is good for | Source map | C | 2026-09-15 |
| Component Gallery / Design Systems Surf / Page Flows / Godly / Land-book / Awwwards / Dribbble | https://component.gallery/ | Community | Purpose of each site (listing-level) | Reference source selection | B | 2026-09-15 |
| nextlevelbuilder/ui-ux-pro-max-skill | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | Community | Structure: searchable style/palette/UX-guideline data + pre-delivery checklist for agents (concept only; installs via npm CLI — not run) | Community agent UI skill reference | C | 2026-09-15 |
| Refactoring UI | https://www.refactoringui.com/ | Community | Principles only (constrained scales, de-emphasis, fewer borders) — commercial book, no content copied | Engineer-oriented visual design | A | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Error message wording | GOV.UK Design System error message | Atlassian error messages, NN/g error guidelines | error-states (wording formulas also referenced in microcopy-ux-writing) |
| Response-time / loading thresholds | NN/g response time limits & skeleton screens | Laws of UX Doherty Threshold, Carbon loading pattern | loading-states |
| Undo vs confirmation | NN/g confirmation dialogs | Vercel guidelines, GNOME HIG dialogs | destructive-actions-and-confirmation |
| Optimistic updates | React useOptimistic docs | TanStack Query optimistic updates, Vercel guidelines | optimistic-ui |
| Human-AI interaction guidelines | Microsoft HAX | Google PAIR, Apple HIG Generative AI, shapeof.ai | ai-chat-interface-ux |
| Dark pattern taxonomy | deceptive.design | NN/g deceptive patterns, Gray et al. ontology | ethical-design-and-dark-patterns |
| Gestalt / psychology laws | Laws of UX | Refactoring UI principles | ui-design-principles-for-engineers, visual-hierarchy-and-layout |
| Inspiration site descriptions | Individual site pages/terms | SaaSUI and other roundup articles | ui-inspiration-and-reference-sources |

## Gaps

- Web search budget was exhausted mid-research; several sources (Material 3 icons page, Apple HIG Generative AI, Polaris content pages, Microsoft Fluent settings, Awwwards/Dribbble/Godly/Land-book terms) were cited at summary level without full-page verification. Re-verify licensing columns in ui-inspiration-and-reference-sources before commercial reliance.
- EU Consumer Rights Directive "withdrawal button" (June 2026) and California auto-renewal law details were not re-verified directly; ethical-design-and-dark-patterns marks the legal section as informational.
- AI Elements component names and AI SDK tool-approval API evolve quickly (AI SDK 5/6); re-verify ai-chat-interface-ux quarterly. Screen reader behavior during token streaming lacks authoritative guidance.
- No first-party quantitative research cited for onboarding checklist effectiveness or settings save-model preference (relies on NN/g and platform HIGs).
- Community agent UI skills (ui-ux-pro-max and similar .cursor/rules) were reviewed only at README/SKILL.md-summary level; the CLI installer was not run by design.
- Possible future extra slugs (not added, overlap with other workstreams): "notification-permission-and-push-ux", "data-privacy-and-consent-ux" (partly covered in ethical-design-and-dark-patterns), "search-results-ux" (W07 search-and-autocomplete).
