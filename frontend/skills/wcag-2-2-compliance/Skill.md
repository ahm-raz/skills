# WCAG 2.2 Compliance

## Summary
How to build and verify React and Next.js (TypeScript) UIs against WCAG 2.2 Level AA, the current W3C Recommendation and the de facto global benchmark for web accessibility. Covers the POUR structure, the success criteria (SC) that matter most for component and application code, the nine criteria new in 2.2, and a repeatable conformance workflow. WCAG 3 is still a Working Draft (March 2026) and is not a compliance target.

## Category
Accessibility

## Subcategories
WCAG 2.2, success criteria, conformance, POUR, Understanding documents, conformance testing, WCAG 3 roadmap

## Problem It Solves
Teams ship UI that "looks fine" but fails basic criteria. The WebAIM Million 2026 found detectable WCAG failures on 95.9% of the top one million home pages, with 56.1 errors per page on average (up 10% on 2025). Six issues made up 96% of detected errors: low-contrast text (83.9% of pages), missing alt text (53.1%), missing form labels (51%), empty links (46.3%), empty buttons (30.6%) and missing document language (13.5%). This skill turns WCAG into concrete engineering requirements and checks.

## When To Use
- Defining the "definition of done" for any user-facing React/Next.js UI.
- Building or reviewing design-system components.
- Preparing for an audit, ACR/VPAT, or a legal requirement (EAA, ADA Title II, Section 508, EN 301 549).
- Mapping an automated or manual finding to a specific SC and severity.

## When Not To Use
- As a substitute for usability testing with disabled people. Conformance does not guarantee a usable product.
- For React Native apps without adaptation. Use WCAG2ICT and the platform guidelines as well.
- To aim at WCAG 3 "Bronze/Silver/Gold". It is a draft with no conformance model you can claim yet.

## Core Principles
1. **POUR.** Content must be Perceivable, Operable, Understandable and Robust.
2. **Level AA is the target.** A and AA criteria are required. AAA is applied selectively.
3. **Conformance is per full page and per complete process.** One inaccessible checkout step fails the whole flow.
4. **Accessibility support.** The technique must work with current browsers and assistive technology (AT), not just be valid in the spec.
5. **WCAG 2.2 is backward compatible.** Meeting 2.2 AA meets 2.1 AA and 2.0 AA; 4.1.1 Parsing is obsolete.
6. **Read "Understanding SC x.y.z"** before deciding an edge case. It defines the intent and exceptions.

## Best Practices
- Keep a component-level SC matrix (below) and require every component PR to state which SCs it touches.
- Prefer native HTML in JSX. It satisfies 4.1.2 Name, Role, Value and 2.1.1 Keyboard for free.
- Treat the "top six" as blocking lint and CI failures. They are cheap to catch automatically.
- Record the AT and browser pairs you test with.
- Adopt cheap AAA wins: 2.4.13 Focus Appearance, 2.3.3 Animation from Interactions.

## Implementation Guidance

### High-impact SCs for React/Next.js engineers (A/AA)
| SC | Level | Engineering meaning |
|---|---|---|
| 1.1.1 Non-text Content | A | `alt` on `next/image` and `<img>`, names on icon buttons and SVGs |
| 1.3.1 Info and Relationships | A | Semantics: headings, lists, tables, `<label htmlFor>`, fieldset/legend |
| 1.3.2 Meaningful Sequence | A | DOM order matches visual reading order |
| 1.3.5 Identify Input Purpose | AA | `autoComplete` tokens on personal-data fields |
| 1.4.1 Use of Color | A | Never color alone (errors, inline links, chart series) |
| 1.4.3 Contrast (Minimum) | AA | 4.5:1 text, 3:1 large text (24px, or 18.66px bold) |
| 1.4.4 Resize Text | AA | 200% zoom without loss |
| 1.4.10 Reflow | AA | No 2-D scroll at 320 CSS px width (400% zoom) |
| 1.4.11 Non-text Contrast | AA | 3:1 for control boundaries, focus rings, icons, chart marks |
| 1.4.12 Text Spacing | AA | Survives line-height 1.5, letter 0.12em, word 0.16em, paragraph 2em |
| 1.4.13 Content on Hover or Focus | AA | Tooltips dismissible (Esc), hoverable, persistent |
| 2.1.1 Keyboard / 2.1.2 No Keyboard Trap | A | Everything keyboard-operable; can always leave |
| 2.4.1 Bypass Blocks | A | Skip link or landmarks in root layout |
| 2.4.2 Page Titled | A | `metadata.title` / `generateMetadata` per route |
| 2.4.3 Focus Order | A | Logical; managed on dialogs and client-side route changes |
| 2.4.4 Link Purpose | A | No bare "click here" `<Link>`s |
| 2.4.7 Focus Visible | AA | Never `outline: none` / Tailwind `outline-none` without a `focus-visible:` replacement |
| 2.4.11 Focus Not Obscured (Min) | AA | Sticky headers and cookie banners must not hide focus |
| 2.5.3 Label in Name | A | Accessible name contains the visible label |
| 2.5.7 Dragging Movements | AA | Single-pointer alternative to drag (dnd-kit sortable + buttons) |
| 2.5.8 Target Size (Min) | AA | 24x24 CSS px, or the 24px spacing-circle exception |
| 3.1.1 Language of Page | A | `<html lang>` in `app/layout.tsx` |
| 3.2.2 On Input | A | No navigation on `<select onChange>` without warning |
| 3.2.6 Consistent Help | A | Help link in the same place in the shared layout |
| 3.3.1 / 3.3.3 Error Identification / Suggestion | A/AA | Text errors tied to fields |
| 3.3.7 Redundant Entry | A | Don't re-ask within a multi-step flow |
| 3.3.8 Accessible Authentication (Min) | AA | Allow paste and password managers; passkeys; no puzzles |
| 4.1.2 Name, Role, Value | A | Custom widgets expose role, name and state |
| 4.1.3 Status Messages | AA | Live regions for toasts, "saved", result counts |

### New in WCAG 2.2
| SC | Level | Quick fix |
|---|---|---|
| 2.4.11 Focus Not Obscured (Minimum) | AA | `html { scroll-padding-top: var(--header-h) }` |
| 2.4.12 Focus Not Obscured (Enhanced) | AAA | Focused item fully visible |
| 2.4.13 Focus Appearance | AAA | Indicator at least a 2px perimeter with 3:1 change contrast |
| 2.5.7 Dragging Movements | AA | Move up/down buttons or menu in sortable lists |
| 2.5.8 Target Size (Minimum) | AA | `min-h-6 min-w-6` (24px) or spacing |
| 3.2.6 Consistent Help | A | Help and contact in the shared layout |
| 3.3.7 Redundant Entry | A | Prefill or "same as shipping" |
| 3.3.8 Accessible Authentication (Minimum) | AA | No `onPaste` blocking; `autoComplete="one-time-code"`; passkeys |
| 3.3.9 Accessible Authentication (Enhanced) | AAA | No object or image recognition |

4.1.1 Parsing is obsolete and always satisfied in 2.2.

### Standards status (as of 2026-09-15)
- **WCAG 2.2**: W3C Recommendation (Oct 2023, with errata). Adopted by EN 301 549 v4.1.1 (published September 2026).
- **WCAG 2.1 AA**: legal reference for ADA Title II and EN 301 549 v3.2.1 (still the harmonised EAA reference until v4.1.1 is cited in the OJEU).
- **WCAG 2.0 AA**: US Section 508 (2017 refresh).
- **WCAG 3.0**: Working Draft (March 2026) with an outcome-based model and Bronze/Silver/Gold levels. CR is not expected before about 2027–2028, and its contrast algorithm is undetermined.

## Recommended Workflow
1. Set the scope: route templates plus complete processes (sign-up, checkout).
2. Design review against the matrix: contrast, target size, focus styles, error design.
3. Implement native-first JSX; for complex widgets use an APG-conformant headless library (React Aria, Radix, Base UI).
4. Automated gate:
   - eslint-plugin-jsx-a11y `strict`
   - vitest-axe component tests
   - @axe-core/playwright E2E with `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa` tags against `next build && next start`
5. Manual checks:
   - keyboard only
   - 200% and 400% zoom
   - text spacing
   - forced colors
   - NVDA+Chrome and VoiceOver+Safari passes, including client-side navigation
6. Log each failure as SC, element, impact, fix and owner.
7. Re-test and document conformance (ACR or accessibility statement) with the date and AT tested.

## Patterns
- **SC-tagged tickets.** `[2.4.7 AA] Focus ring missing on IconButton`.
- **Component acceptance checklist in Storybook.** Keyboard map, name/role/value, focus visible, contrast, target size, reduced motion, 400% reflow. Use the addon-a11y panel for axe.
- **Conformance by route template.** Audit representative `page.tsx` templates plus complete flows.

## Anti-Patterns
- **Overlay widgets ("one script makes you compliant").** They don't fix source semantics and are criticised by practitioners and litigated. Fix the components.
- **Treating a clean axe run as conformance.** Automation finds only a subset (Deque: about 57% of issues by volume). Add manual testing.
- **WCAG 3 drafts or APCA-only contrast as the basis.** Not normative. Meet WCAG 2 ratios.
- **Separate "accessible version" routes.** They go stale. Fix the main UI.

## Accessibility
This skill is the umbrella. See the tables above. Keyboard: 2.1.1, 2.1.2, 2.4.3, 2.4.7, 2.4.11. ARIA: 4.1.2, 4.1.3. Focus: 2.4.3, 2.4.7, 2.4.11, 2.4.13.

## Responsive Design
- 1.4.10 Reflow at 320 CSS px. Exceptions: data tables, maps, diagrams, toolbars.
- 1.3.4 Orientation: never lock orientation in the PWA manifest without an essential reason.
- 2.5.8 applies at every breakpoint, including dense desktop tables.

## Performance
- Less client JS (Server Components, native elements) means fewer broken custom widgets and faster AT response.
- Streaming and Suspense boundaries must not steal focus or produce announcement floods.

## Security
- 3.3.8: don't block paste on password or OTP fields. Support password managers and passkeys (WebAuthn).
- CAPTCHAs need non-cognitive alternatives.
- Session timeouts (2.2.1) need a warning and an extension, balanced with security policy.

## Testing
- **Automated.** axe rules tagged `wcag22aa` (includes `target-size`). Lighthouse Accessibility is an axe subset.
- **Semi-automated.** Accessibility Insights for Web "Assessment" walks every AA criterion.
- **Manual.** Keyboard, zoom/reflow, text spacing, screen readers, forced colors, reduced motion, cognitive review of errors and auth.
- Keep an SC to method (auto/manual) to owner coverage sheet.

## Tooling
- axe-core (MPL-2.0; active 4.1x releases in 2026), @axe-core/playwright, axe DevTools extension.
- eslint-plugin-jsx-a11y (`flatConfigs.recommended` / `strict`); eslint-config-next enables only a small subset of jsx-a11y rules, so add the plugin explicitly.
- vitest-axe (jsdom only; incompatible with happy-dom) or jest-axe.
- Storybook `@storybook/addon-a11y`.
- Accessibility Insights for Web, WAVE, W3C WCAG-EM Report Tool, TPGi Colour Contrast Analyser.

## Framework Notes
- **Next.js (App Router).**
  - Set `<html lang>` in `app/layout.tsx`; use `metadata`/`generateMetadata` for a unique title per route (2.4.2).
  - `next/image` requires `alt` (use `alt=""` for decorative images).
  - Next's built-in route announcer reads the new page title on client navigation, but focus is not moved. Add focus management (see accessible-spa-routing).
  - `loading.tsx` skeletons need accessible busy states.
- **React (Vite SPA).** No built-in route announcer: implement title updates, focus and announcement per route change with React Router or TanStack Router. Set `lang` in `index.html`.
- **Both.**
  - React 19 supports `inert` as a boolean prop.
  - `useId()` generates stable ids for `htmlFor`/`aria-describedby`.
  - Tailwind users must pair `outline-none` with `focus-visible:ring-*`.

## AI Agent Guidance
- Do: map each UI change to the affected SCs and cite SC numbers in PR descriptions.
- Do: default to native elements, visible labels, `lang`, alt text, 4.5:1 contrast, visible focus and 24px targets.
- Do: run jsx-a11y and axe (WCAG 2.2 tags) and fix all violations before claiming done.
- Don't: claim "WCAG compliant" from automated results. State what was automated and what was manually checked.
- Don't: recommend overlays or WCAG 3/APCA as the compliance basis.
- Verify before done:
  - keyboard walkthrough
  - focus visible and not obscured
  - 400% reflow
  - name, role and state in the accessibility tree
  - errors and status messages announced

## Examples
```tsx
// app/layout.tsx
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: { template: '%s | Acme', default: 'Acme' }, // 2.4.2
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">{/* 3.1.1 */}
      <body>
        <a className="skip-link" href="#main">Skip to main content</a>{/* 2.4.1 */}
        <SiteHeader />
        <main id="main" tabIndex={-1}>{children}</main>
        <SiteFooter />{/* 3.2.6: help link lives here on every page */}
      </body>
    </html>
  );
}
```

```tsx
// app/checkout/shipping/page.tsx (excerpt)
export const metadata = { title: 'Shipping address – Checkout' };

export default function ShippingPage() {
  return (
    <>
      <h1>Shipping address</h1>
      <form action={saveShipping}>
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" autoComplete="email" required
               aria-describedby="email-hint" />{/* 1.3.5, 3.3.2 */}
        <p id="email-hint">We send your receipt here.</p>
        <label><input type="checkbox" name="sameBilling" defaultChecked /> Billing address same as shipping</label>{/* 3.3.7 */}
        <button type="submit" className="min-h-6 min-w-6">Continue to payment</button>{/* 2.5.8 */}
      </form>
    </>
  );
}
```

```css
/* globals.css */
:focus-visible { outline: 3px solid #1a5fb4; outline-offset: 2px; } /* 2.4.7 / 2.4.13 */
html { scroll-padding-block-start: 5rem; }                            /* 2.4.11 with sticky header */
```

## Related Skills
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) — CI enforcement of the automatable SCs
- [screen-reader-testing](../screen-reader-testing/Skill.md) — manual verification of 1.3.1, 4.1.2 and 4.1.3
- [accessibility-legal-compliance](../accessibility-legal-compliance/Skill.md) — which WCAG version each law requires
- [accessibility-audit-process](../accessibility-audit-process/Skill.md) — structured evaluation and ACR reporting
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md) — 1.4.1, 1.4.3, 1.4.11
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — 2.5.x criteria
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — 2.4.2/2.4.3 on client navigation
- [ai-accessibility-audit-workflow](../ai-accessibility-audit-workflow/Skill.md) — agent-driven audits

## Sources
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — normative SC text
- [What's New in WCAG 2.2](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/) — Official — nine new SCs, 4.1.1 removal
- [Understanding WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — intent and exceptions (e.g., 2.5.8 spacing test)
- [WCAG 3 Working Draft news, March 2026](https://www.w3.org/WAI/news/2026-03-03/wcag3) — Official — draft status
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — failure prevalence
- [axe-core](https://github.com/dequelabs/axe-core) — Open Source — tag coverage, ~57% claim
- [AccessibleEU: EN 301 549 v4.1.1](https://accessible-eu-centre.ec.europa.eu/content-corner/news/european-accessibility-standard-en-301-549-has-been-updated-2026-09-07_en) — Official — WCAG 2.2 in the EU standard

## License / Usage Notes
W3C documents are under the W3C Document License. Content here is summarised, not copied. axe-core is MPL-2.0; eslint-plugin-jsx-a11y and vitest-axe are MIT.

## Quality Tier
S — grounded in normative W3C sources and 2026 prevalence data, with an actionable SC matrix for React/Next.js.

## Status
Active

## Last Verified
2026-09-15
