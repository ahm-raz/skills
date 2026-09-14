# Responsive Dashboard Layouts

## Summary
Layout engineering for admin and analytics dashboards in React/Next.js. It covers the app shell (sidebar collapsing to rail and drawer), CSS Grid widget areas where widgets adapt with container queries, optional user-customizable grids (react-grid-layout), priority-based content on small screens, table-to-card transformation, and per-widget streaming with Suspense and parallel routes in the App Router.

## Category
Enterprise UI

## Subcategories
app shell, sidebar, CSS grid, container queries, widget grid, drag-to-arrange, streaming, parallel routes, layout persistence

## Problem It Solves
Dashboards built for one 1440px monitor break everywhere else: charts overflow, KPI rows wrap badly, tables become unusable on tablets, and one slow query blocks the whole page. Enterprise users run dashboards on ultrawide monitors, laptops, wall TVs and phones, and increasingly expect to arrange widgets themselves.

## When To Use
- Home/overview dashboards, operations consoles, analytics pages.
- Any admin screen with a persistent navigation shell plus a multi-panel content area.
- Products offering "customize your dashboard" (add, remove, resize, reorder widgets).

## When Not To Use
- Single-task pages (forms, detail records). Use dense-form-screens or master-detail-layouts.
- Choosing what to visualize. See dashboard-design and chart-type-selection.
- Pixel-fixed wallboards. You can still use this, but lock the layout.

## Core Principles
1. Widgets respond to their container, not the viewport: use `@container` queries inside widgets and grid tracks outside.
2. Mobile shows priority, not everything shrunk. Order widgets by importance and collapse secondary ones.
3. Every widget is an independent loading, error and empty boundary. One slow query must not block the page.
4. The shell stays stable: fixed header height, sidebar width transitions without layout shift (CLS).
5. User customization is an enhancement: sensible default layouts per breakpoint, persisted server-side per user (and optionally per role/tenant defaults).
6. Tables transform deliberately on narrow screens: priority columns, card list, or horizontal scroll with a sticky first column. Pick per table.

## Best Practices
- Shell breakpoints (typical): ≥1280px expanded sidebar (240–280px), 768–1279px icon rail (56–72px) with flyout labels, <768px off-canvas drawer opened from a header button.
- Persist sidebar collapsed state in a cookie so the Server Component layout renders the correct width on first paint (no flash).
- Widget grid: `grid-template-columns: repeat(auto-fill, minmax(min(100%, 320px), 1fr))` for fluid cards. Use explicit named areas for curated layouts.
- KPI rows: `auto-fit` with a `minmax` so 4 tiles become 2 columns and then 1 without media queries.
- Charts: size from the container (ResizeObserver or the library's responsive container). Set an `aspect-ratio` or min-height to avoid CLS.
- Offer density modes (comfortable/compact) through CSS variables that the shell and tables share.
- Let users maximize a widget (fullscreen or dedicated route) rather than cramming detail into a small card.
- Keep global filters (date range, region) in the URL (nuqs) so every widget reads the same state and links are shareable.

## Implementation Guidance
**Layout approach decision table**

| Need | Approach |
|---|---|
| Curated, fixed composition | CSS Grid with named areas per breakpoint plus container queries in widgets |
| Fluid list of similar cards | `auto-fill`/`minmax` grid |
| User-arrangeable, resizable widgets | `react-grid-layout` (MIT, npm latest 2.2.4; check v2 API/migration notes) with per-breakpoint layouts |
| Sortable but not resizable | dnd-kit sortable over a CSS grid |
| Independent loading per panel | Suspense boundary per widget, or parallel routes (`@slot`) with their own `loading.tsx`/`error.tsx` |

**Shell CSS**
```css
.shell { display: grid; grid-template-columns: var(--sidebar-w, 264px) 1fr; grid-template-rows: 56px 1fr; min-height: 100dvh; }
.shell[data-sidebar='rail'] { --sidebar-w: 64px; }
@media (max-width: 767px) { .shell { grid-template-columns: 1fr; } .sidebar { position: fixed; inset: 0 auto 0 0; translate: -100% 0; } .sidebar[data-open] { translate: 0 0; } }
.content { container-type: inline-size; overflow: auto; padding: clamp(12px, 2vw, 24px); }
.widgets { display: grid; gap: 16px; grid-template-columns: repeat(12, minmax(0, 1fr)); }
.w-kpis { grid-column: span 12; } .w-chart { grid-column: span 8; } .w-list { grid-column: span 4; }
@container (max-width: 1100px) { .w-chart, .w-list { grid-column: span 12; } }
.widget { container-type: inline-size; min-width: 0; }
@container (max-width: 420px) { .widget .legend { display: none; } .widget .stat { font-size: 1.5rem; } }
```

## Recommended Workflow
1. List widgets with priority (P1 must show on mobile, P2 collapsible, P3 desktop only or behind "More").
2. Build the shell layout with the cookie-persisted sidebar state and a skip link.
3. Define the grid per container width. Implement container queries inside each widget.
4. Wrap each widget in Suspense plus an error boundary, and fetch data per widget in Server Components.
5. Put global filters in the URL. Widgets read them via the `searchParams` promise or nuqs.
6. Optionally add customization: default layouts per breakpoint, edit mode, persist via Server Action.
7. Test at 360, 768, 1024, 1440 and 2560px widths, at 200% zoom, and with slow network (streaming order).

## Patterns
**Per-widget streaming (App Router)**
```tsx
// app/(app)/dashboard/page.tsx
import { Suspense } from 'react';
import { ErrorBoundary } from 'react-error-boundary';
import { RevenueWidget, OrdersWidget, TicketsWidget } from './widgets';
import { WidgetSkeleton, WidgetError } from '@/components/widget-frame';

export default async function Dashboard({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams; // validated inside each widget loader
  return (
    <div className="widgets">
      <section className="w-kpis" aria-labelledby="kpi-h"><h2 id="kpi-h" className="sr-only">Key metrics</h2>
        <Suspense fallback={<WidgetSkeleton rows={1} />}><RevenueWidget sp={sp} /></Suspense>
      </section>
      <section className="w-chart widget" aria-labelledby="orders-h">
        <ErrorBoundary FallbackComponent={WidgetError}>
          <Suspense fallback={<WidgetSkeleton height={320} />}><OrdersWidget sp={sp} /></Suspense>
        </ErrorBoundary>
      </section>
      <section className="w-list widget" aria-labelledby="tickets-h">
        <Suspense fallback={<WidgetSkeleton rows={6} />}><TicketsWidget sp={sp} /></Suspense>
      </section>
    </div>
  );
}
```
`react-error-boundary` is a Client Component library. Alternatively, use parallel routes `app/(app)/dashboard/@orders/page.tsx` with their own `loading.tsx` and `error.tsx` so each slot streams and fails independently.

**Sidebar state from cookie (no flash)**
```tsx
// app/(app)/layout.tsx
import { cookies } from 'next/headers';
import { Sidebar } from '@/components/shell/sidebar'; // 'use client', writes cookie on toggle

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const collapsed = (await cookies()).get('sidebar')?.value === 'rail';
  return (
    <div className="shell" data-sidebar={collapsed ? 'rail' : 'expanded'}>
      <a href="#main" className="skip-link">Skip to content</a>
      <header className="topbar">…</header>
      <Sidebar initialCollapsed={collapsed} />
      <main id="main" className="content">{children}</main>
    </div>
  );
}
```

**Customizable grid (react-grid-layout)**: load saved layouts in the Server Component (DAL, per user) and pass them to a client `DashboardGrid` using the responsive layout component with `breakpoints` and `cols`. Only enable drag/resize in an explicit "Edit layout" mode. Debounce `onLayoutChange` and persist through a Server Action that validates widget ids against the user's allowed widgets. Always offer "Reset to default". Check the current react-grid-layout v2 docs for exact component and prop names.

**Table to card list**
```tsx
<div className="orders">{/* container-type: inline-size */}
  <table className="orders-table">…</table>
  <ul className="orders-cards">{rows.map((r) => <li key={r.id}><OrderCard row={r} /></li>)}</ul>
</div>
/* CSS: @container (max-width: 640px) { .orders-table { display: none } } @container (min-width: 641px) { .orders-cards { display: none } } */
```
Render only one variant when rows are many (decide server-side from a cookie/UA hint, or client-side with a container-size hook) to avoid doubling DOM.

## Anti-Patterns
- **Viewport media queries inside widgets.** The widget breaks when placed in a narrow column on a wide screen. Fix: container queries.
- **A single `await Promise.all` for all widgets in the page.** The slowest query blocks everything. Fix: Suspense per widget or parallel routes.
- **Sidebar state in `localStorage` only.** Layout jumps after hydration (CLS). Fix: a cookie read in the server layout.
- **Shrinking everything on mobile** (12 tiny charts). Fix: priority ordering, collapse P2/P3, and "View details" routes.
- **Always-on drag handles.** Accidental rearranging. Fix: an explicit edit mode with Save/Cancel/Reset.
- **Persisting layouts containing widgets the user may no longer access.** Fix: filter the saved layout against permissions on load and save.
- **Charts without reserved height.** CLS as data streams in. Fix: skeletons with the same dimensions.

## Accessibility
- Landmarks: `header`, `nav` (sidebar, labelled), `main` with a skip link. Each widget is a `section` with a heading (WCAG 1.3.1, 2.4.1).
- The rail sidebar needs accessible names and tooltips for icon-only items. The drawer on mobile follows dialog/drawer focus rules.
- Visual order must match DOM order when the grid rearranges (WCAG 1.3.2, 2.4.3). Avoid `order`/`grid-auto-flow: dense` shuffles that confuse keyboard users.
- The customizable grid needs a keyboard/non-drag alternative: "Move up/down", "Resize: small/medium/large" menu (WCAG 2.5.7).
- Reflow at 320 CSS px / 400% zoom without two-dimensional scrolling except for data tables (WCAG 1.4.10).
- Loading skeletons: `aria-busy` on the widget region, with the content announced once loaded only if user-initiated.

## Responsive Design
- Breakpoints for the shell come from the viewport. Breakpoints for widgets come from the container.
- Use `dvh` for the full-height shell on mobile browsers with dynamic toolbars.
- Large and ultrawide: cap content width for reading-heavy widgets, or allow more columns (`repeat(auto-fill, minmax(360px,1fr))`) for monitoring.
- Touch: minimum 24×24px targets (WCAG 2.5.8), larger for drawer toggles.
- Wallboard/TV mode: a route with hidden chrome, larger type and auto-refresh.

## Performance
- Stream widgets. Place the heaviest queries last in reading order. Cache widget queries (see nextjs-caching-and-revalidation).
- Lazy-load chart libraries per widget (`next/dynamic` in Client Components) and below-the-fold widgets on visibility.
- Avoid ResizeObserver feedback loops: debounce and set a `min-width: 0` on grid children.
- react-grid-layout: memoize children and avoid rerendering all widgets on drag.
- Reserve space (skeleton dimensions) to keep CLS near 0.

## Security
- Widget data is fetched in the DAL with the user's permissions. Hiding a widget in the layout is not access control.
- Validate saved layout JSON (Zod) and widget ids server-side, and never render arbitrary component names from stored data without an allow-list map.
- Tenant/role default layouts are writable only by admins (server check).

## Testing
- Playwright visual snapshots at key widths (360/768/1280/1920) and with sidebar expanded, rail and drawer.
- Streaming: mock a slow widget and assert others render first and the error boundary isolates failures.
- A11y: axe on the dashboard, keyboard through the shell and drawer, and a non-drag layout alternative.
- Layout persistence: edit, save, reload (server-rendered layout matches), reset.
- CLS check with Lighthouse or web-vitals in CI.

## Tooling
- CSS Grid, container queries (baseline in modern browsers), `dvh` units.
- `react-grid-layout` (MIT, 2.2.4 on npm; confirm React 19 compatibility and v2 API in docs).
- dnd-kit for sortable-only arrangements.
- `react-error-boundary` for client error isolation, or App Router `error.tsx`.
- Component kits with shells: shadcn/ui sidebar, MUI, Mantine AppShell (see the respective skills).

## Framework Notes
- **React (Vite SPA):** no streaming SSR by default. Use TanStack Query per widget with Suspense or skeletons, and persist the sidebar in `localStorage` (accept a brief flash) or read it before render from a synchronous inline script.
- **Next.js App Router:** layouts hold the shell (not remounted on navigation). The cookie-based sidebar state is read in the server layout. Suspense per widget or parallel routes (`@kpis`, `@orders`) with slot-level `loading.tsx`/`error.tsx`. `searchParams` is a Promise in Next.js 15+/16, so await it. Dashboard filters via nuqs with `shallow: false` when server widgets must refetch.

## AI Agent Guidance
- Do: use container queries in widgets, Suspense or error boundaries per widget, cookie-persisted sidebar, landmarks and headings, URL global filters, and an edit mode for customization.
- Don't: add viewport media queries inside reusable widgets, await all widget data at the page top, or trust a stored layout without validation.
- Verify: no horizontal scroll at 320px (except intentional table scroll), CLS about 0 on load, a slow widget doesn't block others, keyboard reaches every widget, and a saved layout reloads identically.

## Examples
```tsx
// Server Action persisting a customized layout
'use server';
import { z } from 'zod';
import { saveDashboardLayout } from '@/data/dashboard'; // server-only: authz + allowed widget filter

const Item = z.object({ i: z.string(), x: z.number().int().min(0), y: z.number().int().min(0), w: z.number().int().min(1).max(12), h: z.number().int().min(1).max(12) });
const Layouts = z.record(z.enum(['lg', 'md', 'sm']), z.array(Item).max(50));

export async function saveLayoutAction(input: unknown) {
  const layouts = Layouts.parse(input);
  await saveDashboardLayout(layouts);
  return { ok: true };
}
```

## Related Skills
- [dashboard-design](../dashboard-design/Skill.md) — what to show and hierarchy
- [kpi-and-stat-components](../kpi-and-stat-components/Skill.md) — KPI tile behavior
- [container-queries](../container-queries/Skill.md) — widget-level responsiveness
- [css-grid-and-flexbox-layout](../css-grid-and-flexbox-layout/Skill.md) — grid mechanics
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md) — sidebar/rail/drawer navigation
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — Suspense streaming
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md) — parallel routes for slots
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — global dashboard filters
- [admin-panel-architecture](../admin-panel-architecture/Skill.md) — overall shell structure
- [cls-prevention](../cls-prevention/Skill.md) — reserving space for streamed widgets
- [drag-and-drop](../drag-and-drop/Skill.md) — accessible rearranging

## Sources
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL-based fetching per widget, Server Action validation
- [react-grid-layout on npm](https://www.npmjs.com/package/react-grid-layout) — Open Source — version 2.2.4, MIT
- [NN/g: 8 Design Guidelines for Complex Applications](https://www.nngroup.com/articles/complex-application-design/) — Community (research) — reduce clutter without reducing capability, secondary information access
- [NN/g: Data Tables](https://www.nngroup.com/articles/data-tables/) — Community (research) — table tasks informing narrow-screen transformation
- [EUI Data Grid](https://eui.elastic.co/docs/components/tabular-content/data-grid/) — Official — density and fullscreen controls for data widgets

## License / Usage Notes
react-grid-layout MIT, dnd-kit MIT, react-error-boundary MIT (verify). Guidance is summarized from the listed sources. CSS and TSX are original.

## Quality Tier
B — sound, standards-based layout guidance with working code. react-grid-layout v2 API details and parallel-route specifics were not re-fetched this session.

## Status
Active

## Last Verified
2026-09-15
