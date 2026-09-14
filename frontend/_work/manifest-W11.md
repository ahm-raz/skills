# Manifest – W11 Accessibility

Scope: React + Next.js (TypeScript). All Framework Notes cover React (Vite SPA) and Next.js only. Last verified: 2026-09-15.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| wcag-2-2-compliance | WCAG 2.2 Compliance | Accessibility | React / Next.js | S | Active | https://www.w3.org/TR/WCAG22/ |
| aria-authoring-practices | ARIA Authoring Practices | Accessibility | React / Next.js | S | Active | https://www.w3.org/WAI/ARIA/apg/patterns/ |
| semantic-html | Semantic HTML | Accessibility | React / Next.js | S | Active | https://html.spec.whatwg.org/ |
| keyboard-navigation | Keyboard Navigation | Accessibility | React / Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/ |
| focus-management | Focus Management | Accessibility | React / Next.js | A | Active | https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element |
| screen-reader-testing | Screen Reader Testing | Accessibility | React / Next.js | A | Active | https://webaim.org/projects/screenreadersurvey10/ |
| accessible-forms | Accessible Forms | Accessibility | React / Next.js | S | Active | https://www.w3.org/WAI/tutorials/forms/ |
| landmarks-and-accessible-navigation | Landmarks and Accessible Navigation | Accessibility | React / Next.js | S | Active | https://www.w3.org/WAI/tutorials/page-structure/regions/ |
| color-contrast-and-non-color-cues | Color Contrast and Non-Color Cues | Accessibility | React / Next.js | S | Active | https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html |
| reduced-motion-and-vestibular-safety | Reduced Motion and Vestibular Safety | Accessibility | React / Next.js | A | Active | https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html |
| accessible-data-tables | Accessible Data Tables | Accessibility | React / Next.js | A | Active | https://www.w3.org/WAI/tutorials/tables/ |
| accessible-images-and-media | Accessible Images and Media | Accessibility | React / Next.js | S | Active | https://www.w3.org/WAI/tutorials/images/decision-tree/ |
| live-regions-and-announcements | Live Regions and Announcements | Accessibility | React / Next.js | A | Active | https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html |
| accessible-spa-routing | Accessible SPA Routing | Accessibility | React / Next.js | A | Active | https://nextjs.org/docs/architecture/accessibility |
| automated-accessibility-testing | Automated Accessibility Testing | Accessibility | React / Next.js | S | Active | https://playwright.dev/docs/accessibility-testing |
| accessibility-legal-compliance | Accessibility Legal Compliance | Accessibility | React / Next.js | A | Active | https://www.ada.gov/resources/web-rule-first-steps/ |
| touch-and-pointer-accessibility | Touch and Pointer Accessibility | Accessibility | React / Next.js | A | Active | https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html |
| cognitive-accessibility | Cognitive Accessibility | Accessibility | React / Next.js | A | Active | https://www.w3.org/TR/coga-usable/ |
| forced-colors-and-high-contrast (added) | Forced Colors and High Contrast | Accessibility | React / Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors |
| accessibility-audit-process (added) | Accessibility Audit Process | Accessibility | React / Next.js | A | Active | https://www.w3.org/TR/WCAG-EM/ |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| WCAG 2.2 | https://www.w3.org/TR/WCAG22/ | Official | Normative SC text, levels | The global technical benchmark | S | 2026-09-15 |
| What's New in WCAG 2.2 | https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/ | Official | 9 new SCs, 4.1.1 obsolete | Delta from 2.1 | S | 2026-09-15 |
| Understanding WCAG 2.2 (incl. 2.5.8 Target Size) | https://www.w3.org/WAI/WCAG22/Understanding/ | Official | Intent, exceptions, 24px spacing circle | Edge-case decisions | S | 2026-09-15 |
| WCAG 3 Working Draft news (Mar 2026) | https://www.w3.org/WAI/news/2026-03-03/wcag3 | Official | Draft status | Prevents premature adoption | A | 2026-09-15 |
| WAI-ARIA 1.2 | https://www.w3.org/TR/wai-aria-1.2/ | Official | Roles, states, live region semantics | Correct ARIA | S | 2026-09-15 |
| WAI-ARIA 1.3 Editor's Draft | https://w3c.github.io/aria/ | Experimental | New roles/attrs; CR targeted late 2026 (via W3C privacy review issue) | Forward-looking ARIA | B | 2026-09-15 |
| ARIA APG Patterns | https://www.w3.org/WAI/ARIA/apg/patterns/ | Official | Pattern list, keyboard contracts | Widget implementation | S | 2026-09-15 |
| HTML-AAM / AccName 1.2 | https://www.w3.org/TR/html-aam-1.0/ | Official | Native mappings, name computation | Semantics correctness | S | 2026-09-15 |
| HTML Living Standard | https://html.spec.whatwg.org/ | Official | dialog, popover, inert, details | Native-first primitives | S | 2026-09-15 |
| MDN button (command/commandfor/interestfor) | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/button | Official | Invoker command values; new support | Declarative dialogs/popovers | A | 2026-09-15 |
| MDN ariaNotify | https://developer.mozilla.org/en-US/docs/Web/API/Element/ariaNotify | Official | API, priority, limited availability | Future of announcements | A | 2026-09-15 |
| MDN reading-flow | https://developer.mozilla.org/en-US/docs/Web/CSS/reading-flow | Experimental | Values, not Baseline | Focus/visual order mismatch | B | 2026-09-15 |
| MDN forced-colors | https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors | Official | Overridden properties, system colors, Baseline | High contrast support | S | 2026-09-15 |
| Open UI focusgroup explainer | https://open-ui.org/components/scoped-focusgroup.explainer/ | Experimental | Syntax, in development in Chromium, no shipping impl | Future roving focus | B | 2026-09-15 |
| W3C WAI Tutorials (Forms, Tables, Images, Page Structure) | https://www.w3.org/WAI/tutorials/ | Official | Labels, headers, alt decision tree, regions | Implementation patterns | S | 2026-09-15 |
| W3C COGA Making Content Usable | https://www.w3.org/TR/coga-usable/ | Official | 8 objectives, design patterns | Cognitive accessibility beyond AA | A | 2026-09-15 |
| W3C WCAG-EM / Report Tool / ACT Rules | https://www.w3.org/TR/WCAG-EM/ | Official | 5-step evaluation, sampling | Defensible audits | A | 2026-09-15 |
| AccessibleEU: EN 301 549 v4.1.1 update | https://accessible-eu-centre.ec.europa.eu/content-corner/news/european-accessibility-standard-en-301-549-has-been-updated-2026-09-07_en | Official | v4.1.1 published Sept 2026, WCAG 2.2, not yet OJEU-cited (v3.2.1 remains reference) | EU compliance target | S | 2026-09-15 |
| Directive (EU) 2019/882 (EAA) | https://eur-lex.europa.eu/eli/dir/2019/882/oj | Official | Scope, 28 June 2025 application, exemptions | EU private-sector obligation | S | 2026-09-15 |
| ADA.gov Web Rule First Steps | https://www.ada.gov/resources/web-rule-first-steps/ | Official | WCAG 2.1 AA, extended dates Apr 2027/2028, exceptions | US public-sector obligation | S | 2026-09-15 |
| Federal Register: Title II extension IFR (Apr 2026) | https://www.federalregister.gov/documents/2026/04/20/2026-07663/extension-of-compliance-dates-for-nondiscrimination-on-the-basis-of-disability-accessibility-of-web | Official | Deadline extension | Current US dates | S | 2026-09-15 |
| Section508.gov Laws and Policies | https://www.section508.gov/manage/laws-and-policies/ | Official | 508 incorporates WCAG 2.0 AA | Federal procurement | A | 2026-09-15 |
| Jackson Lewis (Title II & HHS 504) | https://www.jacksonlewis.com/insights/doj-extends-public-entities-compliance-deadline-ada-related-website-accessibility-hhss-may-2026-deadline-still-looms | Community | HHS Section 504 May 2026 deadline context | Healthcare obligations | B | 2026-09-15 |
| WebAIM Million 2026 | https://webaim.org/projects/million/ | Community | 56.1 errors/page, 95.9% failures, top-6 percentages, ARIA correlation, heading/landmark stats | Prioritisation evidence | A | 2026-09-15 |
| WebAIM Screen Reader Survey #10 | https://webaim.org/projects/screenreadersurvey10/ | Community | JAWS 40.5% / NVDA 37.7% / VO 9.7% primary; mobile VO 70.6% | AT test matrix | A | 2026-09-15 |
| Adrian Roselli – WCAG3 Contrast as of April 2026 | https://adrianroselli.com/2026/04/wcag3-contrast-as-of-april-2026.html | Community | APCA removed 2023; WCAG 3 contrast TBD; dual-compliance advice | Avoid APCA-only risk | A | 2026-09-15 |
| axe-core (GitHub + releases) | https://github.com/dequelabs/axe-core | Open Source | ~57% issue coverage, tags, jsdom contrast limit, MPL-2.0, aria-tab-name rule, Element Internals | Core engine | S | 2026-09-15 |
| Playwright Accessibility Testing | https://playwright.dev/docs/accessibility-testing | Official | AxeBuilder API, fixture, exclude caveats | E2E a11y in CI | S | 2026-09-15 |
| eslint-plugin-jsx-a11y | https://github.com/jsx-eslint/eslint-plugin-jsx-a11y | Open Source | flatConfigs.recommended/strict, component mapping, MIT | Static checks in React | A | 2026-09-15 |
| vitest-axe | https://github.com/chaance/vitest-axe | Open Source | Setup, happy-dom incompatibility | Component a11y tests | B | 2026-09-15 |
| Storybook accessibility testing | https://storybook.js.org/docs/writing-tests/accessibility-testing | Official | addon-a11y, Vitest integration | Component state coverage | A | 2026-09-15 |
| Next.js Accessibility docs (route announcer) | https://nextjs.org/docs/architecture/accessibility | Official | Built-in route announcer behaviour | SPA routing in Next | A | 2026-09-15 |
| React Aria (FocusScope, usePress, announcer) | https://react-spectrum.adobe.com/react-aria/ | Open Source | APG-conformant hooks/components | Library-level a11y | A | 2026-09-15 |
| Radix Primitives (Dialog, Toast) | https://www.radix-ui.com/primitives | Open Source | Focus callbacks, toast politeness | Common primitives | A | 2026-09-15 |
| dnd-kit accessibility | https://docs.dndkit.com/guides/accessibility | Open Source | Keyboard sensor, announcements | 2.5.7 drag alternatives | A | 2026-09-15 |
| Motion for React accessibility | https://motion.dev/docs/react-accessibility | Open Source | MotionConfig reducedMotion | Reduced motion in React | A | 2026-09-15 |
| GOV.UK Design System | https://design-system.service.gov.uk/ | Official | Error summary, question pages, check answers | User-tested form patterns | A | 2026-09-15 |
| Gatsby/Marcy Sutton client routing user testing (2019) | https://www.gatsbyjs.com/blog/2019-07-11-user-testing-accessible-client-routing/ | Archived | Focus strategy evidence | SPA focus decisions | B | 2026-09-15 |
| NVDA / VoiceOver / JAWS / TalkBack vendor docs | https://www.nvaccess.org/files/nvda/documentation/userGuide.html | Official | Command references | SR testing procedure | A | 2026-09-15 |
| W3C ARIA-AT | https://aria-at.w3.org/ | Official | AT interoperability expectations | Pattern support evidence | A | 2026-09-15 |
| ITI VPAT | https://www.itic.org/policy/accessibility/vpat | Official | ACR editions | Procurement docs | A | 2026-09-15 |
| Community-Access/accessibility-agents | https://github.com/Community-Access/accessibility-agents | Community | Agent roles for WCAG 2.2 AA review (Claude Code, Copilot, etc.), MIT | Agent-rule reference | B | 2026-09-15 |
| mgifford/ACCESSIBILITY.md | https://github.com/mgifford/ACCESSIBILITY.md | Experimental | AGENTS.md-aligned a11y manifest format; self-declared AI-generated, not fully validated | Agent guidance format | C | 2026-09-15 |
| wshobson/agents wcag-audit-patterns SKILL.md | https://github.com/wshobson/agents/blob/main/plugins/accessibility-compliance/skills/wcag-audit-patterns/SKILL.md | Community | Existence of community audit skill (not deeply reviewed) | Duplicate-check reference | C | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Focus indicator styling (2.4.7/2.4.11/2.4.13) | WCAG Understanding docs | Keyboard-navigation and color-contrast notes | focus-management (others cross-reference) |
| Skip links / bypass blocks | W3C Page Structure tutorial | Keyboard-navigation skip link snippet | landmarks-and-accessible-navigation |
| Error summary + focus | GOV.UK Design System | Focus-management error example | accessible-forms |
| Route change announcements | Next.js docs + Gatsby research | Live-regions navigation note | accessible-spa-routing |
| Target size 2.5.8 | Understanding 2.5.8 | WCAG matrix row | touch-and-pointer-accessibility |
| Forced colors / system colors | MDN forced-colors, CSS Color Adjust spec | Color-contrast CSS helpers | forced-colors-and-high-contrast |
| Legal regimes (EAA, ADA, 508) | EUR-Lex, ADA.gov, Section508.gov | Standards-status bullets in wcag-2-2-compliance | accessibility-legal-compliance |
| ACR/VPAT production | ITI VPAT + WCAG-EM | Legal-compliance ACR section | accessibility-audit-process |
| Reflow / resize text / text spacing (1.4.4, 1.4.10, 1.4.12) | Understanding docs | Considered as a separate slug | wcag-2-2-compliance (not split; see Gaps) |

## Gaps

- **Added slugs:** `forced-colors-and-high-contrast` and `accessibility-audit-process` (neither owned by another workstream). No slugs skipped.
- **Web search budget ran out** partway through research. The following could not be re-verified against primary sources and are stated with hedges:
  - exact axe-core latest version (4.12.x vs 4.13.x)
  - `eslint-config-next` jsx-a11y subset and `next lint` removal timing
  - cross-browser Baseline status of invoker commands and `closedby`
  - Sonner/React Aria Toast internals
  - Guidepup maturity
- **WebAIM Screen Reader Survey #10 is from 2024.** A newer survey may exist. Re-check.
- **ARIA 1.3 CR transition** was expected in Sept 2026 per the W3C privacy review. Confirm the publication status.
- **EN 301 549 v4.1.1** is not yet cited in the OJEU. Re-check periodically. EAA national transposition and penalty details are not covered per member state.
- **HHS Section 504 web rule** (May 2026 date) came from a law-firm source. Verify on HHS.gov. Section 508 has no confirmed plan to adopt WCAG 2.1/2.2.
- **No dedicated skill** for reflow, zoom and text spacing (1.4.4/1.4.10/1.4.12); currently only covered in the WCAG matrix and in responsive notes. Candidate future slug.
- **Accessible PDFs/documents** (PDF/UA) and **accessible email** are not covered. They are out of the React/Next.js scope, but relevant for EAA/Title II.
- **`ariaNotify`, `focusgroup`, `reading-flow` and cross-root ARIA (Reference Target)** are evolving and need re-verification within ~6 months.
- **Community agent skills** (accessibility-agents, ACCESSIBILITY.md, wshobson wcag-audit-patterns) were only surveyed at the README level, not deeply evaluated. W17 (`ai-accessibility-audit-workflow`) should assess them.
