# Navigation Menus and Sidebars

## Summary
Site headers, mega menus, app sidebars and mobile nav. This skill covers the disclosure navigation pattern (why site nav is *not* `role="menu"`), landmarks and skip links, active-link indication with `aria-current`, collapsible and icon-rail sidebars (shadcn/ui Sidebar), Radix/Base UI NavigationMenu, responsive transitions to off-canvas drawers, and focus handling across route changes in Next.js.

## Category
Components

## Subcategories
Header navigation, mega menu, disclosure navigation, app sidebar, navigation rail, mobile nav, skip links, active state

## Problem It Solves
Navigation is the most-used UI and a frequent source of barriers. Common failures: menu roles on link lists, hover-only dropdowns, mega menus that close as the pointer crosses a gap, no current-page indication, sidebars that trap focus or disappear on mobile, and route changes that leave keyboard users stranded.

## When To Use
- Global site/app navigation, section (local) navigation, docs sidebars, admin app shells.

## When Not To Use
- Lists of *actions*: dropdown-menus.
- Switching views inside a page: tabs.
- Deep hierarchical file/object browsing with expand/collapse and selection: tree-views.
- Tiny sites: a simple list of links needs no dropdowns.

## Core Principles
1. Navigation is links inside `<nav aria-label>`; submenus are revealed by disclosure buttons (`aria-expanded`), not `role="menu"`.
2. Indicate the current page with `aria-current="page"` plus a non-color visual cue.
3. Everything works with keyboard: Tab through links, Enter/Space toggles submenus, Escape closes and returns focus to the toggle.
4. Hover can open a submenu but must never be the only way, and must tolerate diagonal movement.
5. Provide a skip link to main content; keep landmark structure (header/nav/main/footer).
6. Mobile nav is a modal drawer with a named close button; desktop sidebar is persistent and not a trap.

## Best Practices
- Label multiple navs distinctly: "Main", "Account", "Footer", "Breadcrumb", "Settings".
- Top-level items that have children: either make the label a toggle button (children include an "Overview" link), or place a separate chevron toggle next to a parent link. Never make a single element both link and toggle.
- Close open submenus on Escape, on focus leaving the nav, on outside click, and on route change.
- Mega menus: group links with headings. Keep them short enough to scan, and don't autoplay media.
- Sidebars: group with headings; collapsible groups use disclosure; an icon-only rail needs tooltips *and* accessible names.
- Persist the sidebar collapsed state (cookie so SSR renders correctly) and offer a keyboard shortcut (shadcn uses ⌘/Ctrl+B).
- On mobile: a hamburger button with `aria-expanded` and an accessible name ("Menu"). The drawer contains the full nav.
- Optional arrow-key support between top-level items (APG disclosure nav example) helps keyboard users but isn't required.

## Implementation Guidance

### Keyboard (disclosure navigation)
| Key | Behavior |
|---|---|
| Tab / Shift+Tab | Move through toggles and links in DOM order (open submenu links follow their toggle) |
| Enter / Space on toggle | Open/close submenu |
| Escape | Close open submenu, focus its toggle |
| Left/Right, Up/Down, Home/End (optional) | Move among top-level items / submenu links |

### ARIA and landmarks
| Element | Markup |
|---|---|
| Skip link | `<a href="#main" class="skip-link">Skip to main content</a>` first in body |
| Nav | `<nav aria-label="Main">` |
| Toggle | `<button aria-expanded aria-controls={submenuId}>Products</button>` |
| Submenu | `<ul id={submenuId} hidden={!open}>` of links |
| Current page | `aria-current="page"` on the active link; `aria-current="true"` on the parent section link, optional |
| Main | `<main id="main" tabIndex={-1}>` |

### Library decision table
| Need | Choose | Notes |
|---|---|---|
| Simple header with a few dropdowns | Hand-rolled disclosure nav (below) | ~50 lines, full control |
| Marketing mega menu with animated viewport | Radix NavigationMenu / Base UI NavigationMenu (shadcn/ui NavigationMenu) | Follows disclosure model, not menu role; `active` prop sets `aria-current` |
| App shell sidebar with collapse/rail/mobile sheet | shadcn/ui Sidebar | Provider, collapsible `offcanvas`/`icon`/`none`, variants, ⌘B, Sheet on mobile |
| Desktop-app menubar (File/Edit) | Menubar (dropdown-menus) | Not for site nav |

## Recommended Workflow
1. Define the IA: top-level items, groups, max depth (aim for ≤2 levels).
2. Choose the header pattern (links / disclosure dropdowns / mega menu) and the sidebar pattern.
3. Build semantic markup: skip link, `nav` labels, lists of links, disclosure toggles.
4. Implement active state from the router (pathname match rules).
5. Add close behaviors (Escape, outside click, focus-out, route change).
6. Build responsive behavior: drawer on mobile, persistent/collapsible sidebar on desktop.
7. Test keyboard, screen reader landmarks list, zoom/reflow, touch.

## Patterns

### Disclosure navigation (Next.js client component)
```tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useId, useRef, useState } from 'react';

type NavGroup = { label: string; links: { href: string; label: string }[] };

export function MainNav({ groups }: { groups: NavGroup[] }) {
  const pathname = usePathname();
  const [openIndex, setOpenIndex] = useState<number | null>(null);
  const navRef = useRef<HTMLElement>(null);
  const id = useId();

  useEffect(() => setOpenIndex(null), [pathname]); // close on navigation

  return (
    <nav aria-label="Main" ref={navRef}
      onKeyDown={(e) => {
        if (e.key === 'Escape' && openIndex !== null) {
          document.getElementById(`${id}-btn-${openIndex}`)?.focus();
          setOpenIndex(null);
        }
      }}
      onBlur={(e) => { if (!navRef.current?.contains(e.relatedTarget as Node)) setOpenIndex(null); }}>
      <ul className="nav-top">
        {groups.map((g, i) => {
          const open = openIndex === i;
          const sectionActive = g.links.some((l) => pathname.startsWith(l.href));
          return (
            <li key={g.label}>
              <button id={`${id}-btn-${i}`} type="button" aria-expanded={open} aria-controls={`${id}-sub-${i}`}
                data-active={sectionActive || undefined} onClick={() => setOpenIndex(open ? null : i)}>
                {g.label}
              </button>
              <ul id={`${id}-sub-${i}`} hidden={!open}>
                {g.links.map((l) => (
                  <li key={l.href}>
                    <Link href={l.href} aria-current={pathname === l.href ? 'page' : undefined}>{l.label}</Link>
                  </li>
                ))}
              </ul>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
```
Close on outside click with a `pointerdown` listener on `document` when `openIndex !== null`.

### Skip link + main target (root layout, Server Component)
```tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <a href="#main" className="skip-link">Skip to main content</a>
        <header><MainNav groups={navGroups} /></header>
        <main id="main" tabIndex={-1}>{children}</main>
      </body>
    </html>
  );
}
```

### App sidebar (shadcn/ui Sidebar)
```tsx
// app/(app)/layout.tsx (Server Component)
import { cookies } from 'next/headers';
import { SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar';
import { AppSidebar } from './app-sidebar';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const defaultOpen = (await cookies()).get('sidebar_state')?.value !== 'false';
  return (
    <SidebarProvider defaultOpen={defaultOpen}>
      <AppSidebar />
      <main id="main" tabIndex={-1}>
        <SidebarTrigger aria-label="Toggle sidebar" />
        {children}
      </main>
    </SidebarProvider>
  );
}
```
```tsx
// app-sidebar.tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Sidebar, SidebarContent, SidebarGroup, SidebarGroupLabel, SidebarMenu, SidebarMenuItem, SidebarMenuButton } from '@/components/ui/sidebar';

export function AppSidebar() {
  const pathname = usePathname();
  return (
    <Sidebar collapsible="icon" aria-label="Application">
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Workspace</SidebarGroupLabel>
          <SidebarMenu>
            {[{ href: '/projects', label: 'Projects', icon: FolderIcon }, { href: '/reports', label: 'Reports', icon: ChartIcon }].map((i) => (
              <SidebarMenuItem key={i.href}>
                <SidebarMenuButton asChild isActive={pathname.startsWith(i.href)} tooltip={i.label}>
                  <Link href={i.href} aria-current={pathname.startsWith(i.href) ? 'page' : undefined}>
                    <i.icon aria-hidden /><span>{i.label}</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            ))}
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>
    </Sidebar>
  );
}
```
Despite the "Menu" component names, shadcn's sidebar renders lists of links. Verify no `role="menu"` is emitted. Check that the `<Sidebar>` output is (or contains) a `<nav>` landmark, and add one if not.

## Anti-Patterns
- **`role="menubar"`/`menu` on site nav**: screen readers switch modes, and links aren't announced as links. Fix: disclosure pattern.
- **Hover-only dropdowns**: keyboard and touch users can't open them. Fix: toggle buttons; hover as enhancement with delay and a safe area.
- **Parent label as both link and toggle**: tap opens or navigates unpredictably. Fix: separate toggle, or an "Overview" link inside.
- **No `aria-current`**: users don't know where they are. Fix: set it from pathname.
- **Icon-only rail without names**: Fix: visible labels on expand + `aria-label`/tooltip.
- **Mobile drawer stays open after navigation**: Fix: close on pathname change.
- **Sidebar collapsed state from localStorage**: layout flashes after hydration. Fix: cookie read on the server.
- **Mega menu in DOM but visually hidden with opacity**: links remain focusable. Fix: `hidden` or `inert` when closed.

## Accessibility
- WCAG 2.4.1 Bypass Blocks (skip link, landmarks), 2.4.5 Multiple Ways, 2.4.8 Location (AAA, aria-current helps), 3.2.3 Consistent Navigation, 3.2.4 Consistent Identification, 1.4.13 for hover-opened submenus, 2.1.1 Keyboard, 2.4.11 Focus Not Obscured (sticky headers must not cover focused content; use `scroll-padding-top`).
- Landmarks list should show uniquely labelled navs.

## Responsive Design
- Breakpoints by container/viewport: persistent sidebar ≥ lg; icon rail at md; off-canvas drawer below.
- Header: collapse to a hamburger when items no longer fit, not at an arbitrary device width.
- Touch targets ≥ 44px in mobile nav; avoid multi-level flyouts on mobile (use drill-down or accordions).
- Use logical properties so sidebars flip in RTL.

## Performance
- Server-render nav markup. Only the interactive shell is client JS.
- `next/link` prefetch: large mega menus with hundreds of links can trigger many prefetches when visible. Keep submenus `hidden` when closed, or set `prefetch={false}` for rarely used links.
- Avoid layout shift from sidebar state (SSR cookie).

## Security
- Hide nav items for unauthorized sections *and* protect the routes server-side (middleware/proxy + server checks).
- Don't leak internal route names or feature flags in client nav config for users who lack access.

## Testing
- Testing Library: `getByRole('navigation', {name:'Main'})`; toggle `aria-expanded`; Escape returns focus; `getByRole('link', {current:'page'})`.
- Playwright: skip link moves focus to main; mobile drawer closes on navigation; sidebar state persists across reloads without flash; hover submenu tolerates diagonal movement.
- Screen reader: landmarks rotor (VoiceOver) and NVDA elements list.
- axe: landmark-unique, region, duplicate ids.

## Tooling
- shadcn/ui Sidebar, NavigationMenu (Radix or Base UI), Sheet for mobile.
- Radix NavigationMenu (Viewport, Indicator, `active` link prop), Base UI NavigationMenu (v1.x).
- Floating UI `safePolygon` for custom hover menus.

## Framework Notes
- **React (Vite SPA)**: Use React Router `NavLink` (it sets `aria-current="page"` automatically when active) or TanStack Router `Link` with `activeProps`. SPA route changes aren't announced by default, so move focus to `<main>` or the page `<h1>` and update `document.title` on navigation. Persist sidebar state in localStorage (no SSR flash concern).
- **Next.js (App Router)**: Put nav in the layout so it persists across navigations. Only the interactive parts are Client Components (`'use client'`); `usePathname` drives active state and close-on-navigate. Next.js's route announcer reads the new page title, but focus is not moved, so consider focusing `<main>` or the `<h1>` for keyboard users in app shells. Read sidebar state from `cookies()` in the layout to avoid hydration flashes; `SidebarProvider` writes the cookie. Use route groups (`(marketing)`, `(app)`) for different nav shells.

## AI Agent Guidance
- DO use `<nav aria-label>` + lists of links + disclosure toggles; DO set `aria-current`.
- DO include a skip link and `main` target in the root layout if missing.
- DON'T use menu/menubar roles for site navigation; DON'T rely on hover.
- Verify: keyboard-only traversal; Escape closes submenus; mobile drawer closes on navigation; active state correct on nested routes; no hidden focusable links; no SSR flash for sidebar state.

## Examples
Radix/shadcn NavigationMenu for a marketing mega menu:
```tsx
'use client';
import Link from 'next/link';
import {
  NavigationMenu, NavigationMenuList, NavigationMenuItem, NavigationMenuTrigger,
  NavigationMenuContent, NavigationMenuLink,
} from '@/components/ui/navigation-menu';

export function MarketingNav() {
  return (
    <NavigationMenu aria-label="Main">
      <NavigationMenuList>
        <NavigationMenuItem>
          <NavigationMenuTrigger>Products</NavigationMenuTrigger>
          <NavigationMenuContent>
            <ul className="grid gap-2 p-4 md:w-[32rem] md:grid-cols-2">
              <li><NavigationMenuLink asChild><Link href="/analytics">Analytics</Link></NavigationMenuLink></li>
              <li><NavigationMenuLink asChild><Link href="/billing">Billing</Link></NavigationMenuLink></li>
            </ul>
          </NavigationMenuContent>
        </NavigationMenuItem>
        <NavigationMenuItem>
          <NavigationMenuLink asChild><Link href="/pricing">Pricing</Link></NavigationMenuLink>
        </NavigationMenuItem>
      </NavigationMenuList>
    </NavigationMenu>
  );
}
```

## Related Skills
- [landmarks-and-accessible-navigation](../landmarks-and-accessible-navigation/Skill.md): landmarks and skip links
- [drawers-and-sheets](../drawers-and-sheets/Skill.md): mobile off-canvas nav
- [dropdown-menus](../dropdown-menus/Skill.md): action menus vs nav
- [breadcrumbs](../breadcrumbs/Skill.md): secondary location navigation
- [information-architecture](../information-architecture/Skill.md): nav structure
- [accessible-spa-routing](../accessible-spa-routing/Skill.md): focus on route change
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md): layouts and route groups
- [admin-panel-architecture](../admin-panel-architecture/Skill.md): app shells
- [tree-views](../tree-views/Skill.md): hierarchical browsing

## Sources
- [WAI-ARIA APG: Disclosure Navigation Menu example](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/) — Official — markup, Escape, optional arrows, why not menu role
- [WAI-ARIA APG: Menu and Menubar](https://www.w3.org/WAI/ARIA/apg/patterns/menubar/) — Official — caution on navigation menubars
- [Radix NavigationMenu](https://www.radix-ui.com/primitives/docs/components/navigation-menu) — Open Source — disclosure model, viewport, active links
- [shadcn/ui Sidebar](https://ui.shadcn.com/docs/components/sidebar) — Open Source — provider, collapsible modes, ⌘B, mobile sheet
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Community (agent skill) — links are links, deep linking, scroll-margin

## License / Usage Notes
Summarized in original wording; code original. Radix/shadcn MIT.

## Quality Tier
A — APG + leading library docs + complete Next.js implementations; Material 3 nav rail guidance not retrieved.

## Status
Active

## Last Verified
2026-09-15
