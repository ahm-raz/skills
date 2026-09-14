# Accordions and Disclosure

## Summary
Disclosure widgets show and hide one section of content. An accordion is a stack of disclosures, sometimes limited to one open at a time. This skill covers native `<details>`/`<summary>` (including exclusive accordions via `name`), the APG Accordion pattern (heading > button), animation, find-in-page with `hidden="until-found"`, and React implementations (shadcn/Radix, Base UI, React Aria).

## Category
Components

## Subcategories
Disclosure, accordion, details/summary, exclusive accordion, show more, FAQ, collapsible sections

## Problem It Solves
Long pages with many optional sections overwhelm users. Accordions help, but they hide content: users miss it, find-in-page can't reach it, and SEO/print suffer. Custom accordions often lack button semantics, `aria-expanded`, or heading structure, and exclusive accordions frustrate users who want to compare sections.

## When To Use
- FAQs, optional detail sections, settings groups, filter groups, long reference content where users need only a few sections.
- "Show more" on truncated descriptions.
- Mobile alternative to tabs or side navigation.

## When Not To Use
- Essential content every user must read (GOV.UK: not all users notice or understand accordions).
- Short content: just show it.
- Sequential steps: use a stepper/multi-page flow.
- Nested accordions inside accordions: restructure.
- Content users compare side by side: use a table or tabs.

## Core Principles
1. The toggle is a real button (native `<summary>` or `<button>`) with `aria-expanded` reflecting state.
2. For heading-structured content, wrap the button in a heading of the right level (APG).
3. Allow multiple sections open by default; use exclusive (single-open) only with a clear reason.
4. Collapsed content should still be findable (find-in-page, deep links) where possible.
5. Visual state (chevron rotation) matches `aria-expanded` state.

## Best Practices
- Header labels describe the content ("Delivery and returns"), not "More".
- Provide "Show all sections" / "Hide all sections" for long accordions (GOV.UK).
- Open the section targeted by a URL hash (`#returns`) on load.
- Keep the whole header row clickable, with a visible focus ring and a chevron icon marked `aria-hidden`.
- Don't move focus on expand; keep it on the toggle.
- Animate height subtly and respect `prefers-reduced-motion`.
- Use `role="region"` + `aria-labelledby` on panels only when there are few (≤ ~6) sections, per APG.

## Implementation Guidance

### Native vs library
| Need | Choose | Notes |
|---|---|---|
| Simple disclosure/FAQ | `<details><summary>` | Built-in button semantics, keyboard, find-in-page in supporting engines |
| Exclusive accordion | `<details name="group">` | Baseline 2024 (Chrome 120, Safari 17.2, Firefox 130); degrades to independent toggles |
| Animated open/close | `::details-content` + `interpolate-size`/`height` transitions | Support varies by engine (`interpolate-size` has been Chromium-first). Treat as an enhancement |
| Heading-navigable sections, "Show all", controlled state, DS styling | shadcn/ui Accordion (Radix), Base UI Accordion/Collapsible, React Aria Disclosure/DisclosureGroup | Radix renders heading > button structure |
| Custom panel hidden but findable | `hidden="until-found"` + `beforematch` | Chrome 102+, Firefox 139+; Safari support newer, so verify |

### Keyboard
| Key | Behavior |
|---|---|
| Tab / Shift+Tab | Move between headers and into open panel content |
| Enter / Space | Toggle the focused section; in exclusive mode, closes others |
| Down/Up Arrow, Home/End (optional) | Move between headers |

### ARIA (custom implementation)
| Element | Attributes |
|---|---|
| Heading | `<h3>` (level fits the page outline) |
| Button inside heading | `aria-expanded`, `aria-controls={panelId}` |
| Panel | `id`, `hidden` when collapsed; optional `role="region" aria-labelledby={buttonId}` |
| Non-collapsible open panel (forced one-open) | Button `aria-disabled="true"` |

Note: `<summary>` is exposed as a button. Headings placed *inside* `<summary>` may lose heading semantics in some screen readers. If heading navigation matters, use the heading > button pattern.

## Recommended Workflow
1. Confirm hiding content is justified; list sections and headings.
2. Choose native `<details>` unless you need heading structure, "Show all", or DS integration.
3. Decide single vs multiple open (default: multiple).
4. Add hash deep-linking and "Show all" where lists are long.
5. Add reduced-motion-safe animation.
6. Test keyboard, screen reader (button, expanded/collapsed), find-in-page, print.

## Patterns

### Native FAQ (Server Component, zero JS)
```tsx
export function Faq({ items }: { items: { id: string; q: string; a: React.ReactNode }[] }) {
  return (
    <section aria-labelledby="faq-h">
      <h2 id="faq-h">Frequently asked questions</h2>
      {items.map((it) => (
        <details key={it.id} id={it.id} name="faq">
          <summary>{it.q}</summary>
          <div className="answer">{it.a}</div>
        </details>
      ))}
    </section>
  );
}
```
Remove `name="faq"` to allow multiple open (usually better for FAQs).

### Animation enhancement
```css
details::details-content {
  block-size: 0; overflow: clip;
  transition: block-size .25s ease, content-visibility .25s allow-discrete;
}
details[open]::details-content { block-size: auto; }
@supports (interpolate-size: allow-keywords) { :root { interpolate-size: allow-keywords; } }
@media (prefers-reduced-motion: reduce) { details::details-content { transition: none; } }
```

### Controlled details in React (sync state)
```tsx
'use client';
export function Section({ title, open, onOpenChange, children }: {
  title: string; open: boolean; onOpenChange: (o: boolean) => void; children: React.ReactNode;
}) {
  return (
    <details open={open} onToggle={(e) => onOpenChange(e.currentTarget.open)}>
      <summary>{title}</summary>
      {children}
    </details>
  );
}
```
Always sync from `onToggle`. Users toggle natively, so the DOM state can diverge from props.

### APG accordion with "Show all" (shadcn/ui on Radix)
```tsx
'use client';
import { useState } from 'react';
import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from '@/components/ui/accordion';

export function Sections({ sections }: { sections: { id: string; title: string; body: React.ReactNode }[] }) {
  const [open, setOpen] = useState<string[]>([]);
  const allOpen = open.length === sections.length;
  return (
    <>
      <button type="button" aria-expanded={allOpen}
        onClick={() => setOpen(allOpen ? [] : sections.map((s) => s.id))}>
        {allOpen ? 'Hide all sections' : 'Show all sections'}
      </button>
      <Accordion type="multiple" value={open} onValueChange={setOpen}>
        {sections.map((s) => (
          <AccordionItem key={s.id} value={s.id}>
            <AccordionTrigger>{s.title}</AccordionTrigger>
            <AccordionContent>{s.body}</AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </>
  );
}
```
Radix wraps each trigger in a heading (`h3` by default). Adjust the level via `AccordionPrimitive.Header` with `asChild` to match your outline.

### Show more (disclosure)
```tsx
<p id="bio" className={expanded ? '' : 'line-clamp-3'}>{bio}</p>
<button type="button" aria-expanded={expanded} aria-controls="bio" onClick={() => setExpanded(!expanded)}>
  {expanded ? 'Show less' : 'Show more'}
</button>
```

## Anti-Patterns
- **Clickable `<div>` headers**: no keyboard or role. Fix: `<summary>` or `<button>`.
- **Exclusive mode by default**: users can't compare, and content jumps. Fix: multiple open.
- **Headers styled as links**: users mistake them for navigation (GOV.UK research). Fix: button styling with chevron.
- **Essential legal or pricing info collapsed**: Fix: show it.
- **Chevron state not tied to `aria-expanded`**: Fix: style via `[aria-expanded="true"]` or `[open]`.
- **`display:none` panels with deep links**: hash targets don't open. Fix: open on `hashchange`, or `hidden="until-found"`.
- **Animating `max-height: 9999px`**: wrong timing. Fix: `interpolate-size`/`::details-content`, or measure height.
- **Nested accordions**: disorienting. Fix: flatten or split pages.

## Accessibility
- WCAG 1.3.1, 2.1.1, 2.4.6 Headings and Labels, 4.1.2 Name/Role/Value, 2.4.7 Focus Visible, 2.3.3 Animation from Interactions (reduced motion).
- Screen readers should announce "button, collapsed/expanded". Verify with NVDA and VoiceOver.
- Speech-control users need visible header labels that match the accessible names.

## Responsive Design
- Accordions often replace tabs or sidebars on mobile. Keep header targets ≥ 44px.
- Avoid sticky headers inside accordions unless tested; they can obscure focus (2.4.11).

## Performance
- Native `<details>` costs no JS and works as a Server Component.
- Lazy-render heavy panel content on first open for large sets. Note that lazy-rendered content isn't findable by find-in-page or crawlers.

## Security
- Don't hide sensitive data in collapsed panels on the assumption it's private; it's in the DOM.

## Testing
- Testing Library: `getByRole('button', {name:'Delivery and returns'})`, click → `aria-expanded="true"` and region visible.
- Playwright: hash deep link opens section; "Show all" toggles all; exclusive group closes others.
- Manual: Ctrl/Cmd+F finds collapsed text (engines with until-found/details search support).
- axe: button names; no nested interactive.

## Tooling
- Native `<details name>`, `::details-content`, `hidden="until-found"`.
- shadcn/ui Accordion + Collapsible (Radix), Base UI Accordion/Collapsible, React Aria Components `Disclosure`/`DisclosureGroup`, Headless UI Disclosure.

## Framework Notes
- **React (Vite SPA)**: React treats `open` on `<details>` as controlled only if you sync `onToggle`. Prefer uncontrolled `<details>` for static content. For hash deep-linking, open the matching section in an effect on mount and on `hashchange`.
- **Next.js (App Router)**: Native `<details>` works in Server Components with zero JS (FAQ pages, docs). Radix accordions need `'use client'`. Pass server-rendered bodies as children. A `defaultValue` from `searchParams` must match on server and client to avoid hydration mismatch. Collapsed-but-rendered content is still in the HTML for SEO; lazy-mounted content is not. If you add FAQ structured data, do it via JSON-LD in the page.

## AI Agent Guidance
- DO default to `<details>/<summary>` for simple disclosure; use DS Accordion when heading structure or controlled state is needed.
- DO default to multiple-open; justify exclusive mode.
- DON'T build clickable divs or put interactive elements inside `<summary>`.
- Verify: Enter/Space toggles; `aria-expanded`/`open` in sync; heading levels correct; reduced motion; hash deep links; no essential content hidden.

## Examples
React Aria Components DisclosureGroup:
```tsx
import { DisclosureGroup, Disclosure, Heading, Button, DisclosurePanel } from 'react-aria-components';

<DisclosureGroup allowsMultipleExpanded>
  <Disclosure id="personal">
    <Heading level={3}><Button slot="trigger">Personal details</Button></Heading>
    <DisclosurePanel><PersonalForm /></DisclosurePanel>
  </Disclosure>
  <Disclosure id="billing">
    <Heading level={3}><Button slot="trigger">Billing address</Button></Heading>
    <DisclosurePanel><BillingForm /></DisclosurePanel>
  </Disclosure>
</DisclosureGroup>
```

## Related Skills
- [tabs](../tabs/Skill.md): alternative for peer sections
- [progressive-disclosure](../progressive-disclosure/Skill.md): when to hide content
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md): height animation
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md): motion preferences
- [semantic-html](../semantic-html/Skill.md): details/summary
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md): collapsible filter groups
- [documentation-site-patterns](../documentation-site-patterns/Skill.md): FAQs and reference content

## Sources
- [WAI-ARIA APG: Accordion Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/accordion/) — Official — heading/button, aria-expanded, region guidance
- [GOV.UK Design System: Accordion](https://design-system.service.gov.uk/components/accordion/) — Official design system — when to use, show all sections, research
- [Chrome for Developers: Exclusive accordion](https://developer.chrome.com/docs/css-ui/exclusive-accordion) — Official — details name
- [MDN Blog: details exclusive accordions](https://developer.mozilla.org/en-US/blog/html-details-exclusive-accordions) — Official — Baseline support
- [MDN: beforematch event](https://developer.mozilla.org/en-US/docs/Web/API/Element/beforematch_event) — Official — hidden=until-found
- [CSS-Tricks: Covering hidden=until-found](https://css-tricks.com/covering-hiddenuntil-found/) — Community — support history

## License / Usage Notes
Summarized in original wording; code original. Radix/shadcn MIT; React Aria Apache-2.0.

## Quality Tier
A — APG + GOV.UK + verified Baseline data; `::details-content`/`interpolate-size` cross-engine support not re-verified.

## Status
Active

## Last Verified
2026-09-15
