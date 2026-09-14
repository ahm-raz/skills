# Tabs

## Summary
Tabs switch between peer panels of related content in the same place on a page. This skill covers the APG Tabs pattern: tablist/tab/tabpanel roles, arrow-key navigation, and automatic vs manual activation. It also covers when tabs are the wrong choice, the difference between in-page tabs and navigation tabs (links), URL-synced tabs in React and Next.js, and library choices (Radix/shadcn, Base UI, React Aria).

## Category
Components

## Subcategories
Tablist, tabpanel, activation modes, navigation tabs, URL state, responsive tabs, overflow

## Problem It Solves
Tabs hide content, and not everyone notices or understands them (GOV.UK). Implementations often mix up link navigation and in-page panels, and put every tab in the tab order. They also skip arrow keys, lose the selected tab on refresh or Back, or pack in so many tabs that they wrap into several rows.

## When To Use
- Content splits into clearly labelled, peer sections, and users rarely need to compare them side by side.
- The first section is the most relevant to most users.
- Settings pages, product details (Description / Specs / Reviews), dashboards with alternative views.

## When Not To Use
- Users need to read sections in sequence, or compare across tabs: use headings on one page or a table.
- Only one short section: show it inline.
- Page-level navigation between routes: use a `<nav>` of links styled as tabs (not `role="tablist"`).
- More than ~6–7 tabs or long labels: use a sidebar/secondary nav or a select.
- Steps in a process: use a stepper/wizard.

## Core Principles
1. One tab stop for the tablist; arrow keys move between tabs (roving tabindex).
2. Selected tab has `aria-selected="true"`; each tab `aria-controls` its panel; panel `aria-labelledby` its tab.
3. Use automatic activation when panels render instantly; use manual activation (Enter/Space) when switching is slow or costly.
4. The tab panel is reachable with Tab right after the tablist; if it has no focusable content, it gets `tabIndex={0}`.
5. Don't mix in-page tabs and navigation links in one control (NN/g).

## Best Practices
- Labels: 1–2 words, plain language, no all-caps. Order by frequency of use.
- Keep tabs in a single row. On overflow, scroll horizontally with visible affordance, or collapse into a select/menu on small screens.
- Use more than one selected-state cue (underline + weight/color), not color alone.
- Sync the selected tab to the URL (`?tab=reviews`) when users share, refresh, or navigate back.
- Preserve panel state (form input) when switching, or warn before discarding.
- Don't disable tabs without explanation; prefer hiding unavailable ones or explaining inline.

## Implementation Guidance

### Keyboard
| Key | Behavior |
|---|---|
| Tab | Into the tablist (focus goes to the selected tab), then out to the panel |
| Left/Right Arrow (horizontal) | Previous/next tab, wrapping; activates it in automatic mode |
| Up/Down Arrow (vertical, `aria-orientation="vertical"`) | Previous/next tab |
| Home / End | First / last tab (recommended) |
| Enter / Space | Activate the focused tab (manual mode) |
| Delete (optional) | Close a closable tab |

### Roles and attributes
| Element | Attributes |
|---|---|
| Container | `role="tablist"`, `aria-label` or `aria-labelledby`, `aria-orientation` if vertical |
| Tab | `<button role="tab" aria-selected aria-controls id tabIndex={selected ? 0 : -1}>` |
| Panel | `role="tabpanel" id aria-labelledby={tabId} tabIndex={0}` (when no focusable first element); hidden panels use `hidden` |

### Decision table
| Scenario | Build |
|---|---|
| In-page panels, React DS | shadcn/ui Tabs (Radix), Base UI Tabs, React Aria Tabs |
| Route-level sections (`/settings/profile`, `/settings/billing`) | `<nav aria-label="Settings">` + `next/link` with `aria-current="page"`, styled like tabs |
| Expensive panels (charts, fetches) | Manual activation (`activationMode="manual"` in Radix) or lazy-render panel content |
| Many sections on mobile | Accordion or select-driven view on small screens (same content component) |

## Recommended Workflow
1. Decide: in-page tabs or route navigation? Or should this be headings on one page?
2. Write labels and order; confirm the count fits one row at your smallest breakpoint.
3. Choose the primitive (DS first). Choose the activation mode.
4. Decide URL sync and panel mounting strategy (keep mounted vs lazy).
5. Implement the responsive overflow behavior.
6. Test keyboard, screen reader announcement ("tab, 2 of 4, selected"), Back/refresh.

## Patterns

### Accessible tabs from scratch (React)
```tsx
'use client';
import { useId, useRef, useState } from 'react';

type Tab = { id: string; label: string; content: React.ReactNode };

export function Tabs({ tabs, label }: { tabs: Tab[]; label: string }) {
  const base = useId();
  const [selected, setSelected] = useState(tabs[0].id);
  const refs = useRef<(HTMLButtonElement | null)[]>([]);

  const onKeyDown = (e: React.KeyboardEvent, i: number) => {
    const last = tabs.length - 1;
    const next = e.key === 'ArrowRight' ? (i === last ? 0 : i + 1)
      : e.key === 'ArrowLeft' ? (i === 0 ? last : i - 1)
      : e.key === 'Home' ? 0 : e.key === 'End' ? last : null;
    if (next === null) return;
    e.preventDefault();
    refs.current[next]?.focus();
    setSelected(tabs[next].id); // automatic activation
  };

  return (
    <div>
      <div role="tablist" aria-label={label}>
        {tabs.map((t, i) => (
          <button key={t.id} ref={(el) => { refs.current[i] = el; }} type="button" role="tab"
            id={`${base}-tab-${t.id}`} aria-controls={`${base}-panel-${t.id}`}
            aria-selected={selected === t.id} tabIndex={selected === t.id ? 0 : -1}
            onClick={() => setSelected(t.id)} onKeyDown={(e) => onKeyDown(e, i)}>
            {t.label}
          </button>
        ))}
      </div>
      {tabs.map((t) => (
        <div key={t.id} role="tabpanel" id={`${base}-panel-${t.id}`} aria-labelledby={`${base}-tab-${t.id}`}
          tabIndex={0} hidden={selected !== t.id}>
          {t.content}
        </div>
      ))}
    </div>
  );
}
```

### Navigation tabs (Next.js, links not tablist)
```tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const items = [{ href: '/settings/profile', label: 'Profile' }, { href: '/settings/billing', label: 'Billing' }];

export function SettingsNav() {
  const pathname = usePathname();
  return (
    <nav aria-label="Settings">
      <ul className="tabs">
        {items.map((i) => (
          <li key={i.href}>
            <Link href={i.href} aria-current={pathname.startsWith(i.href) ? 'page' : undefined}>{i.label}</Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
```

### URL-synced tabs with shadcn/ui (Radix)
```tsx
'use client';
import { useRouter, useSearchParams, usePathname } from 'next/navigation';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';

export function ProductTabs({ description, specs, reviews }: Record<'description' | 'specs' | 'reviews', React.ReactNode>) {
  const params = useSearchParams(); const router = useRouter(); const pathname = usePathname();
  const tab = params.get('tab') ?? 'description';
  return (
    <Tabs value={tab} onValueChange={(v) => {
      const p = new URLSearchParams(params); p.set('tab', v);
      router.replace(`${pathname}?${p}`, { scroll: false });
    }}>
      <TabsList aria-label="Product information">
        <TabsTrigger value="description">Description</TabsTrigger>
        <TabsTrigger value="specs">Specs</TabsTrigger>
        <TabsTrigger value="reviews">Reviews</TabsTrigger>
      </TabsList>
      <TabsContent value="description">{description}</TabsContent>
      <TabsContent value="specs">{specs}</TabsContent>
      <TabsContent value="reviews">{reviews}</TabsContent>
    </Tabs>
  );
}
```
Use `replace` so every tab switch doesn't add history entries. Use `push` only if tabs are primary navigation users expect Back to undo. Pass server-rendered panels as props so they stay Server Components.

## Anti-Patterns
- **`role="tablist"` around route links**: announces tabs but navigates pages. Fix: nav + `aria-current`.
- **Every tab tabbable**: tedious. Fix: roving tabindex.
- **No arrow key support**: breaks screen reader expectations. Fix: implement or use a primitive.
- **Tabs wrapping into two rows**: users misread which panel belongs to which tab. Fix: horizontal scroll, fewer tabs, or a select on mobile.
- **Critical info in non-default tabs** (e.g., fees in "Details"): users miss it. Fix: surface it on the default view.
- **Unmounting panels with unsaved form input**: data loss. Fix: keep mounted (`forceMount`) or persist state.
- **Automatic activation on panels that fetch**: arrowing past triggers requests. Fix: manual activation or cached data.

## Accessibility
- WCAG 1.3.1 Info and Relationships, 2.1.1 Keyboard, 2.4.3 Focus Order, 2.4.7 Focus Visible, 4.1.2 Name/Role/Value, 1.4.1 Use of Color (selected state), 1.4.10 Reflow.
- Screen readers announce role, position and selection. Verify with NVDA (focus mode) and VoiceOver.
- Hidden panels use `hidden`, not just `opacity`, so they aren't read.

## Responsive Design
- Horizontal scroll of the tablist with `overflow-x: auto`, `scroll-snap-type`, and scroll-into-view of the selected tab.
- Or switch to an accordion/select below a container-query breakpoint. Keep the content component shared.
- Touch targets ≥ 44px tall on mobile.

## Performance
- Lazy-render heavy panels; don't compute all panels at mount.
- In Next.js, server-render panel content and pass it as props. Client JS only drives selection.
- Avoid layout shift when switching: reserve min-height or animate height carefully.

## Security
- Tabs showing permission-gated content must be enforced server-side; hiding a tab isn't access control.
- Validate `?tab=` values against an allowlist before using them.

## Testing
- Testing Library: `getByRole('tab', {name:'Specs'})`, `user.keyboard('{ArrowRight}')`, assert `aria-selected` and visible `tabpanel`.
- Playwright: refresh preserves `?tab=`; Back behavior; horizontal overflow at 320px.
- axe: `aria-required-children` for tablist; valid `aria-controls`.

## Tooling
- shadcn/ui Tabs (Radix Tabs; `activationMode` automatic/manual), Base UI Tabs (v1.x), React Aria Components Tabs (`keyboardActivation="manual"`), Ariakit Tab, Headless UI TabGroup.
- nuqs for typed URL search-param state.

## Framework Notes
- **React (Vite SPA)**: Keep selection in the URL via React Router `useSearchParams` or TanStack Router search params when shareable. Use `useId` for tab/panel ids. For panels that fetch, TanStack Query with `enabled` tied to selection plus prefetch-on-hover avoids waterfalls.
- **Next.js (App Router)**: Tab controls are Client Components (`'use client'`). Panels can be Server Components passed as props/children. `useSearchParams` requires a `<Suspense>` boundary. For route-level tabs use nested layouts plus a client nav with `usePathname`. After a route change, focus should go to the new content heading (Next.js announces route changes). If the server reads `searchParams` to pick the default tab, use the same value on the client to avoid hydration mismatch.

## AI Agent Guidance
- DO decide between tabs, nav links, accordion or plain headings before building.
- DO use the project's Tabs primitive; ensure a label on the tablist.
- DON'T wrap links in `role="tab"`; DON'T put every tab in the tab order.
- Verify: arrows/Home/End work; one tab stop; `aria-selected` correct; panel labelled; URL state survives refresh; no wrapping at 320px; selected state not color-only.

## Examples
React Aria Components tabs with manual activation:
```tsx
import { Tabs, TabList, Tab, TabPanel } from 'react-aria-components';

<Tabs keyboardActivation="manual">
  <TabList aria-label="Report views">
    <Tab id="summary">Summary</Tab><Tab id="chart">Chart</Tab>
  </TabList>
  <TabPanel id="summary"><Summary /></TabPanel>
  <TabPanel id="chart"><ExpensiveChart /></TabPanel>
</Tabs>
```

## Related Skills
- [accordions-and-disclosure](../accordions-and-disclosure/Skill.md): mobile alternative and sequential content
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md): route-level navigation
- [keyboard-navigation](../keyboard-navigation/Skill.md): roving tabindex
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): URL-synced selection
- [progressive-disclosure](../progressive-disclosure/Skill.md): hiding content responsibly
- [radix-ui-primitives](../radix-ui-primitives/Skill.md): Tabs primitive

## Sources
- [WAI-ARIA APG: Tabs Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/tabs/) — Official — keyboard, roles, activation modes, panel tabindex
- [GOV.UK Design System: Tabs](https://design-system.service.gov.uk/components/tabs/) — Official design system — when to use/not use, mobile
- [NN/g: Tabs, Used Right](https://www.nngroup.com/articles/tabs-used-right/) — Research — labels, single row, don't mix nav/in-page
- [Radix Tabs](https://www.radix-ui.com/primitives/docs/components/tabs) — Open Source — activationMode API

## License / Usage Notes
Summarized in original wording; code original. Radix/shadcn MIT; React Aria Apache-2.0.

## Quality Tier
A — APG + two design-system research sources + React/Next.js implementation paths.

## Status
Active

## Last Verified
2026-09-15
