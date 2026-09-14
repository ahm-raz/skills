# Progressive Disclosure

## Summary
Progressive disclosure defers advanced or rarely used features and information to secondary views, keeping the primary interface simple for most users while retaining power for experts (NN/g). Related: staged disclosure (wizard-like sequences) and contextual disclosure (reveal when relevant). This skill covers deciding the split, choosing disclosure mechanisms, and implementing them accessibly in React/Next.js.

## Category
UX

## Subcategories
staged disclosure, advanced settings, accordions, "show more", conditional fields, contextual reveal, layered help, complexity management

## Problem It Solves
Feature-rich products either overwhelm newcomers with every option at once, or hide important options so deeply that nobody finds them. Progressive disclosure balances learnability, efficiency and error reduction by showing the right amount at the right time.

## When To Use
- Forms and settings with many rarely used options.
- Detail pages with dense metadata; long content where summaries suffice for most.
- Features with novice and expert audiences (filters, query builders, export options).
- Conditional questions that apply only to some users.

## When Not To Use
- Information most users need for the task (hiding it adds clicks and missed info).
- Comparison tasks where users must see everything side by side (pricing tables, spec comparison).
- When the split is unknown — research frequency first; wrong splits are worse than none.

## Core Principles
1. **Get the split right**: primary view contains what most users need most of the time; use data (analytics, task analysis, field studies) plus observation.
2. **Strong information scent**: the trigger label must clearly say what's behind it ("Advanced shipping options", not "More").
3. **Max two levels** of disclosure; deeper nesting gets users lost (NN/g).
4. **Reveal in place** when possible (expand/collapse, conditional fields) to keep context.
5. **Never hide required inputs or critical warnings.**
6. **Remember disclosure state** where it helps experts (e.g., "Advanced" stays open).
7. **Staged disclosure only for linear, independent steps**; interdependent settings belong on one screen.

## Best Practices
- Label triggers with the content, and indicate count or state ("Advanced filters (2 active)").
- Show a summary of hidden values when collapsed ("Shipping: Standard, 3-5 days · Change").
- Conditional reveal directly under the controlling input (GOV.UK conditional radios), keep it short (one or two fields).
- Use "Show more" for long lists/text with a clear count ("Show 12 more"); don't truncate critical content.
- Keep defaults sensible so most users never need advanced options.
- Tooltips/popovers for definitions; inline "Learn more" for deeper help; docs for full detail (layered help).
- Don't reset hidden values silently when collapsing; decide explicitly and communicate.
- Validation errors inside collapsed sections must expand the section and be reachable from the error summary.

## Implementation Guidance

Mechanism decision table:

| Need | Mechanism | Notes |
|---|---|---|
| Few optional details on page | `<details>/<summary>` or disclosure button | Native, accessible, no JS |
| Multiple independent sections | Accordion | Allow multiple open |
| Alternative views of same object | Tabs | Not for sequential steps |
| Follow-up questions based on answer | Conditional reveal | Keep under the controlling input |
| Rare, complex configuration | Secondary page/dialog ("Advanced settings") | Summarize current values on primary |
| Long list/text | Show more / truncation with expand | Show count |
| Linear multi-step task | Staged disclosure (wizard) | Avoid if steps interdependent |
| Definitions / help | Tooltip -> popover -> docs link | Tooltips only for non-essential |
| Expert shortcuts | Command palette / keyboard shortcuts | Discoverable via hint |

```tsx
// Native disclosure: zero JS, works in Server Components
export function AdvancedOptions({ activeCount, children }: { activeCount: number; children: React.ReactNode }) {
  return (
    <details className="group rounded-md border" open={activeCount > 0}>
      <summary className="cursor-pointer list-none px-4 py-3 font-medium">
        Advanced options{activeCount > 0 ? ` (${activeCount} set)` : ""}
        <span aria-hidden className="float-right transition-transform group-open:rotate-180">▾</span>
      </summary>
      <div className="px-4 pb-4">{children}</div>
    </details>
  );
}
```

```tsx
// Conditional reveal under a radio (client)
"use client";
import { useState } from "react";
export function ContactPreference() {
  const [method, setMethod] = useState<"email" | "phone" | "">("");
  return (
    <fieldset>
      <legend className="font-medium">How should we contact you?</legend>
      <label className="block"><input type="radio" name="method" value="email" onChange={() => setMethod("email")} aria-controls="email-extra" /> Email</label>
      {method === "email" && (
        <div id="email-extra" className="ml-6 border-l-4 border-neutral-300 pl-4">
          <label htmlFor="email">Email address</label>
          <input id="email" name="email" type="email" autoComplete="email" />
        </div>
      )}
      <label className="block"><input type="radio" name="method" value="phone" onChange={() => setMethod("phone")} aria-controls="phone-extra" /> Phone</label>
      {method === "phone" && (
        <div id="phone-extra" className="ml-6 border-l-4 border-neutral-300 pl-4">
          <label htmlFor="phone">Phone number</label>
          <input id="phone" name="phone" type="tel" autoComplete="tel" />
        </div>
      )}
    </fieldset>
  );
}
```

```tsx
// Collapsed summary + edit (settings pattern)
<dl className="flex items-center justify-between rounded-md border p-4">
  <div><dt className="text-sm text-neutral-600">Export format</dt><dd className="font-medium">CSV, UTF-8, comma-separated</dd></div>
  <Link href="/exports/settings" className="text-sm underline">Change<span className="sr-only"> export format</span></Link>
</dl>
```

## Recommended Workflow
1. List all options/info on the screen; gather usage frequency (analytics, interviews).
2. Classify: essential (always visible), common (visible or one click), rare (secondary), expert (shortcut/advanced page).
3. Choose mechanism per group from the table; write specific trigger labels.
4. Ensure collapsed state summarizes hidden values; handle validation inside hidden areas.
5. Test with novices (can they finish without advanced?) and experts (can they find advanced fast?).
6. Monitor usage of disclosed features; re-promote frequently used ones.

## Patterns
- **Advanced section** collapsed by default, auto-open when values set.
- **Summary card + edit** for complex configuration.
- **Show more with count**.
- **Layered help**: hint -> "Learn more" popover -> docs.
- **Smart defaults + override**: "Use recommended settings" checked; uncheck reveals options.
- **Contextual toolbar**: actions appear when items are selected (bulk actions).

## Anti-Patterns
- **"More" / "Other" / "..." as the only label** — no scent. Fix: descriptive label.
- **Hiding frequently used options** — Fix: use data to split; promote.
- **Three+ nested levels** (accordion in tab in modal) — Fix: flatten or dedicated page.
- **Required field inside collapsed section** — submission fails mysteriously. Fix: never hide required fields; auto-expand on error.
- **Hover-only reveal** — invisible to keyboard/touch. Fix: click/focus triggers.
- **Staged wizard for interdependent settings** — endless back-and-forth. Fix: single page with sections and live preview.
- **Truncated critical text** (prices, legal terms) — Fix: show in full.

## Accessibility
- Disclosure buttons: `aria-expanded` + `aria-controls` (or native `<details>`); accordions per WAI-ARIA APG.
- Conditional content inserted directly after the controlling input so reading order is logical (1.3.2).
- Don't move focus on expand; keep focus on trigger.
- Content on hover or focus dismissible, hoverable, persistent (1.4.13) for tooltips.
- Hidden content must be truly hidden from AT (`hidden`, not just `opacity: 0`).
- Find-in-page: `hidden="until-found"` lets browser search reveal collapsed content (Chromium).

## Responsive Design
- Mobile benefits most: collapse secondary panels into accordions or sheets; keep primary actions visible.
- Don't collapse content on desktop just because it's collapsed on mobile.

## Performance
- Lazily render heavy hidden content (charts, editors) on first expand; keep lightweight content in DOM for find-in-page and SEO.
- `next/dynamic` for heavy advanced panels.

## Security
- Hiding a control is not access control; enforce permissions server-side for advanced/admin options.

## Testing
- Testing Library: toggle updates `aria-expanded`, content appears/disappears, errors inside collapsed sections expand it.
- Analytics on expand rates; usability tests for findability of advanced options.

## Tooling
- Native `<details>`, Radix Collapsible/Accordion, React Aria Disclosure, shadcn/ui Accordion/Collapsible.

## Framework Notes
- **Next.js (App Router)**: prefer native `<details>` in Server Components for zero JS; persist "advanced open" in URL (`?advanced=1`) or cookie when useful; use `next/dynamic` for heavy panels.
- **React (Vite SPA)**: controlled disclosure state in component or URL search params; lazy components with `React.lazy`.

## AI Agent Guidance
- Do: base the split on stated frequency/requirements; label triggers descriptively; show summaries when collapsed; use native `<details>` where possible.
- Don't: hide required fields or critical info; nest disclosures beyond two levels; use hover-only reveals.
- Verify: keyboard toggling, `aria-expanded` correctness, validation inside collapsed sections, find-in-page for important content.

## Examples
```tsx
// Show more with count
"use client";
import { useState } from "react";
export function ShowMoreList<T>({ items, initial = 5, render, noun }: { items: T[]; initial?: number; render: (i: T) => React.ReactNode; noun: string }) {
  const [expanded, setExpanded] = useState(false);
  const visible = expanded ? items : items.slice(0, initial);
  const remaining = items.length - initial;
  return (
    <>
      <ul id="sml">{visible.map(render)}</ul>
      {remaining > 0 && (
        <button aria-expanded={expanded} aria-controls="sml" onClick={() => setExpanded((e) => !e)} className="mt-2 text-sm underline">
          {expanded ? `Show fewer ${noun}` : `Show ${remaining} more ${noun}`}
        </button>
      )}
    </>
  );
}
```

## Related Skills
- [accordions-and-disclosure](../accordions-and-disclosure/Skill.md) — component implementation
- [tabs](../tabs/Skill.md) — alternative views
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md) — staged disclosure
- [settings-and-preferences-ux](../settings-and-preferences-ux/Skill.md) — advanced settings
- [usability-heuristics](../usability-heuristics/Skill.md) — aesthetic and minimalist design
- [cognitive-accessibility](../cognitive-accessibility/Skill.md) — reducing cognitive load
- [tooltips](../tooltips/Skill.md) — layered help

## Sources
- [NN/g: Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/) — Community (research) — split, scent, two-level limit, staged disclosure
- [GOV.UK Design System: Radios conditional reveal](https://design-system.service.gov.uk/components/radios/) — Official — conditional questions
- [WAI-ARIA APG: Disclosure, Accordion](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/) — Official
- [Laws of UX: Hick's Law, Tesler's Law, Cognitive Load](https://lawsofux.com/) — Community
- [MDN: hidden="until-found"](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/hidden) — Official (docs)

## License / Usage Notes
Summarized; code original. GOV.UK OGL v3.0.

## Quality Tier
A — clear research foundation and official ARIA patterns.

## Status
Active

## Last Verified
2026-09-15
