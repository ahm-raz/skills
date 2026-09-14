# Landmarks and Accessible Navigation

## Summary
Structuring React/Next.js layouts with HTML landmark regions (`header`, `nav`, `main`, `aside`, `footer`, `search`, labelled `section`/`form`), skip links, and accessible site navigation (current page, disclosure submenus, breadcrumbs). It lets screen reader and keyboard users orient themselves and jump straight to content.

## Category
Accessibility

## Subcategories
Landmark regions, skip links, bypass blocks, nav labelling, aria-current, disclosure navigation, breadcrumbs, consistent navigation, page titles

## Problem It Solves
Without landmarks and skip links, keyboard users tab through dozens of header links on every page, and screen reader users can't jump to the main content or the search. Unlabelled duplicate `<nav>`s announce as indistinguishable "navigation" regions, and menus built with `role="menu"` confuse users. WebAIM Million 2026: 84.3% of pages have at least one landmark, but quality varies widely.

## When To Use
- Designing root and nested layouts (`app/layout.tsx`, route-group layouts).
- Building headers, sidebars, footers, mega-menus, breadcrumbs and pagination.
- Auditing 2.4.1 Bypass Blocks, 1.3.1, 3.2.3 Consistent Navigation, and 3.2.6 Consistent Help.

## When Not To Use
- Don't wrap every component in `<section>` or `role="region"`. Too many landmarks are as unhelpful as none.
- Don't use `role="menu"`/`menubar` for website navigation; that's for application-style action menus.

## Core Principles
1. **All perceivable content lives inside a landmark.** Nothing stray outside `header`/`main`/`footer`/etc.
2. **Exactly one `<main>`** per page.
3. **Label duplicates.** Multiple `nav`/`aside`/`section` landmarks each get a unique `aria-label` or `aria-labelledby`.
4. **Don't say "navigation" in nav labels.** Screen readers already announce the role ("Primary navigation", not "Primary navigation navigation").
5. **Navigation is lists of links.** Submenus are disclosure buttons, not ARIA menus.
6. **Consistency.** Navigation order and help placement stay the same across pages (3.2.3, 3.2.6).
7. **A skip link is first**, visible on focus.

## Best Practices
- Element-to-landmark mapping:
  | Element | Landmark | Condition |
  |---|---|---|
  | `<header>` | banner | Only when not inside `article`/`aside`/`main`/`nav`/`section` |
  | `<nav>` | navigation | Always |
  | `<main>` | main | Always; one visible per page |
  | `<aside>` | complementary | At top level or labelled |
  | `<footer>` | contentinfo | Only when scoped to `body` |
  | `<section>` | region | Only when it has an accessible name |
  | `<form>` | form | Only when it has an accessible name |
  | `<search>` | search | Always |
- Mark the current page with `aria-current="page"` on its link (and style it with more than color).
- Breadcrumbs: `<nav aria-label="Breadcrumb"><ol>…</ol></nav>`, with `aria-current="page"` on the last item.
- Sidebar in-page nav (docs table of contents): `<nav aria-label="On this page">`.
- Mobile menu toggle: `<button aria-expanded aria-controls>`; the nav is `hidden` or `inert` when closed.
- Skip link target: `<main id="main" tabIndex={-1}>`. `tabIndex={-1}` guarantees focus moves in all browsers.
- Multiple skip links (e.g., "Skip to search") only when truly helpful.
- Page `<title>` follows "Page – Section – Site" and is unique (2.4.2).

## Implementation Guidance

### Root layout (Next.js App Router)
```tsx
// app/layout.tsx
import Link from 'next/link';
import { PrimaryNav } from './primary-nav';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <a href="#main" className="skip-link">Skip to main content</a>
        <header>
          <Link href="/" aria-label="Acme home"><Logo aria-hidden="true" /></Link>
          <PrimaryNav />
          <search>
            <form action="/search" role="search" aria-label="Site">{/* role optional inside <search> */}
              <label htmlFor="site-q" className="sr-only">Search</label>
              <input id="site-q" name="q" type="search" />
              <button type="submit">Search</button>
            </form>
          </search>
        </header>
        <main id="main" tabIndex={-1}>{children}</main>
        <footer>
          <nav aria-label="Footer"><ul role="list">…</ul></nav>
          <p><Link href="/help">Help and contact</Link></p>{/* 3.2.6 consistent help */}
        </footer>
      </body>
    </html>
  );
}
```
Simplify: if you use `<search>`, you don't need `role="search"` on the form. Choose one.

### Primary nav with current page and a disclosure submenu
```tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useId, useState } from 'react';

const items = [
  { href: '/pricing', label: 'Pricing' },
  { label: 'Products', children: [{ href: '/products/api', label: 'API' }, { href: '/products/sdk', label: 'SDK' }] },
  { href: '/docs', label: 'Docs' },
];

export function PrimaryNav() {
  const pathname = usePathname();
  return (
    <nav aria-label="Primary">
      <ul role="list" className="flex gap-4">
        {items.map(item => item.children
          ? <SubMenu key={item.label} label={item.label} links={item.children} pathname={pathname} />
          : <li key={item.href}>
              <Link href={item.href!} aria-current={pathname.startsWith(item.href!) ? 'page' : undefined}>{item.label}</Link>
            </li>)}
      </ul>
    </nav>
  );
}

function SubMenu({ label, links, pathname }: { label: string; links: { href: string; label: string }[]; pathname: string }) {
  const [open, setOpen] = useState(false);
  const id = useId();
  return (
    <li onKeyDown={e => { if (e.key === 'Escape' && open) { setOpen(false); (e.currentTarget.querySelector('button') as HTMLButtonElement).focus(); } }}
        onBlur={e => { if (!e.currentTarget.contains(e.relatedTarget as Node)) setOpen(false); }}>
      <button type="button" aria-expanded={open} aria-controls={id} onClick={() => setOpen(o => !o)}>{label}</button>
      <ul id={id} role="list" hidden={!open}>
        {links.map(l => <li key={l.href}><Link href={l.href} aria-current={pathname === l.href ? 'page' : undefined}>{l.label}</Link></li>)}
      </ul>
    </li>
  );
}
```
Keyboard: Tab moves through top-level links and buttons; Enter/Space toggles a submenu; Tab enters it; Esc closes and returns focus. Arrow-key support is optional enhancement, not required for disclosure navigation.

### Skip link CSS
```css
.skip-link { position: absolute; left: 1rem; top: -100vh; }
.skip-link:focus { top: 1rem; z-index: 1000; padding: .5rem 1rem; background: #fff; color: #000; outline: 3px solid #1a5fb4; }
```

## Recommended Workflow
1. Sketch regions per layout: banner, primary nav, search, main, complementary, contentinfo.
2. Implement in the root and nested layouts so every route inherits them.
3. Label duplicates. Add `aria-current` logic.
4. Add the skip link and `main` target.
5. Verify with the landmarks view: NVDA D key or NVDA+F7 "Landmarks"; VoiceOver rotor "Landmarks"; JAWS R or Insert+Ctrl+R. Use the Accessibility Insights "Landmarks" visualiser.
6. axe: `landmark-one-main`, `region`, `landmark-unique`, `bypass`, `landmark-no-duplicate-banner`/`contentinfo`.

## Patterns
- **Nested layout regions.** A dashboard layout adds `<nav aria-label="Dashboard">` sidebar and `<aside aria-label="Activity">`, and keeps one `<main>` (from the root layout) wrapping the page content.
- **Docs layout.** `nav "Docs"` (sidebar), `main` (article), `nav "On this page"` (TOC).
- **Pagination.** `<nav aria-label="Pagination">` with `aria-current="page"` on the current page link, and descriptive names ("Page 3").
- **Mobile off-canvas.** A toggle button with `aria-expanded`. When open, focus goes to the first link and the rest of the page is `inert`. Esc closes and returns focus.

## Anti-Patterns
- **Nested `<main>` in page components** when the layout already renders `<main>`. Duplicate main landmarks. Render `<main>` once in the layout.
- **`<nav aria-label="Main navigation">`.** Announced as "Main navigation navigation". Use "Main" or "Primary".
- **`role="menubar"`/`menuitem` on site navigation.** Forces application-mode arrow navigation. Use lists of links.
- **Hover-only mega-menus.** Fail keyboard and touch. Use click/Enter disclosure, and keep hover as an enhancement with delay.
- **Skip link to an element that isn't focusable** (some browsers don't move sequential focus). Add `tabIndex={-1}` to the target.
- **Content outside landmarks** (cookie banners, toasts, portals appended to `body`). Put banners in a labelled `section` or `aside`. Portals for dialogs are fine because dialogs are their own context.
- **Active link indicated only by color.** 1.4.1. Add underline, weight or a marker.

## Accessibility
- 1.3.1 Info and Relationships (A), 2.4.1 Bypass Blocks (A), 2.4.2 Page Titled (A), 2.4.5 Multiple Ways (AA: nav plus search or sitemap), 2.4.8 Location (AAA: breadcrumbs, current page), 3.2.3 Consistent Navigation (AA), 3.2.4 Consistent Identification (AA), 3.2.6 Consistent Help (A), 1.4.1 Use of Color.

## Responsive Design
- Mobile nav toggles must keep the same links in the same relative order as desktop (3.2.3 applies within a set of pages).
- Use `hidden` or `inert` for closed off-canvas menus. `transform: translateX(-100%)` alone leaves links focusable and readable.
- At 400% zoom the header collapses to the mobile pattern; ensure the skip link still works and the sticky header doesn't cover the focused content (2.4.11).

## Performance
- Keep nav in Server Components where possible; only the toggle and submenus need client JS. `usePathname` for `aria-current` requires a small client component.
- Prefetching (`<Link prefetch>`) doesn't affect accessibility, but avoid rendering huge hidden mega-menus on every page if they bloat the DOM for screen readers. Render on open.

## Security
- No specific concerns. Ensure `aria-label`s don't include user-generated content without escaping (JSX escapes by default).

## Testing
```ts
// Playwright
test('landmarks and skip link', async ({ page }) => {
  await page.goto('/docs');
  await expect(page.getByRole('main')).toHaveCount(1);
  await expect(page.getByRole('navigation', { name: 'Primary' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Docs' })).toHaveAttribute('aria-current', 'page');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.getByRole('main')).toBeFocused();
});
```
- axe with `region`, `landmark-*` and `bypass` rules; Accessibility Insights Landmarks; manual landmark lists in NVDA, JAWS and VoiceOver.

## Tooling
- Accessibility Insights for Web (Landmarks visualiser), axe DevTools, Landmarks browser extension (by David Todd / matatk).
- Radix `NavigationMenu` (implements disclosure-style navigation with keyboard support; verify labels); React Aria `Breadcrumbs`, `Link`.

## Framework Notes
- **Next.js App Router.**
  - Render `<main>` in the root layout (or in route-group layouts, but only once per rendered page).
  - Parallel routes (`@sidebar`) should render `nav`/`aside` with labels.
  - `usePathname` gives `aria-current`.
  - `not-found.tsx` and `error.tsx` render inside the layout, so landmarks persist.
- **React (Vite SPA).** Put landmarks in the router's root layout route. React Router's `NavLink` sets `aria-current="page"` automatically when active; TanStack Router's `Link` exposes `activeProps`, so add `aria-current` there.

## AI Agent Guidance
- Do: generate a layout with a skip link, `header`, labelled `nav`s, a single `main id="main" tabIndex={-1}`, and `footer`; add `aria-current="page"`.
- Do: build dropdown nav as disclosure buttons plus lists of links; close on Esc and return focus.
- Don't: use `role="menu"` for nav, add "navigation" to labels, render `<main>` in pages when the layout has one, or leave content outside landmarks.
- Verify before done:
  - landmarks list shows unique, labelled regions
  - skip link works
  - current page is exposed
  - mobile menu is inert when closed

## Examples
```tsx
// Breadcrumbs
export function Breadcrumbs({ trail }: { trail: { href: string; label: string }[] }) {
  return (
    <nav aria-label="Breadcrumb">
      <ol className="flex flex-wrap gap-2">
        {trail.map((c, i) => {
          const last = i === trail.length - 1;
          return (
            <li key={c.href} className="flex items-center gap-2">
              {last ? <a href={c.href} aria-current="page">{c.label}</a> : <Link href={c.href}>{c.label}</Link>}
              {!last && <span aria-hidden="true">/</span>}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
```

## Related Skills
- [semantic-html](../semantic-html/Skill.md) — element semantics
- [keyboard-navigation](../keyboard-navigation/Skill.md) — skip links and tab order
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — titles and focus on navigation
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md) — nav component design
- [breadcrumbs](../breadcrumbs/Skill.md) — breadcrumb component
- [pagination](../pagination/Skill.md) — pagination nav
- [information-architecture](../information-architecture/Skill.md) — what goes in navigation
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — layouts

## Sources
- [W3C WAI Page Structure Tutorial: Regions](https://www.w3.org/WAI/tutorials/page-structure/regions/) — Official — landmark usage
- [APG Landmarks pattern](https://www.w3.org/WAI/ARIA/apg/patterns/landmarks/) — Official — labelling and roles
- [HTML-AAM](https://www.w3.org/TR/html-aam-1.0/) — Official — header/footer/section scoping rules
- [APG Disclosure Navigation Menu example](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/) — Official — non-menu site navigation
- [Adrian Roselli: Don't Use ARIA Menu Roles for Site Nav](https://adrianroselli.com/2017/10/dont-use-aria-menu-roles-for-site-nav.html) — Community — rationale
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — landmark prevalence

## License / Usage Notes
Summarised from W3C (W3C Document License) and practitioner articles. Code is original.

## Quality Tier
S — official structure guidance with tested, React/Next-specific layouts.

## Status
Active

## Last Verified
2026-09-15
