# Dashboard Design

## Summary
How to design and build dashboards that communicate the most important information at a glance and support the next action. It covers purpose (operational vs analytical vs strategic), information hierarchy, layout, KPI rows, chart density, shared filters and time ranges, drill-down, freshness and state handling, and implementation in React and Next.js. Grounded in Stephen Few's *Information Dashboard Design*, NN/g research on dashboards and preattentive attributes, and practitioner guidance.

## Category
Data Visualization

## Subcategories
operational dashboards, analytical dashboards, KPI rows, filter bars, drill-down, data freshness, dashboard layout, Next.js streaming dashboards

## Problem It Solves
Dashboards tend to become walls of gauges, donuts, and unrelated charts that are slow to scan, visually loud, and silent about what needs attention. They are also slow to load and inconsistent in filters and colors. This skill gives a structure that makes status, change, and exceptions obvious.

## When To Use
- Designing an admin, analytics, monitoring, or SaaS "home" dashboard.
- Refactoring an existing cluttered dashboard.
- Defining a reusable dashboard shell (filters, grid, tiles) for a product.

## When Not To Use
- Single-chart editorial stories: data-visualization-principles.
- Deep exploratory analysis tools (pivoting, ad-hoc queries): those are BI tools, not dashboards.
- Responsive grid mechanics alone: responsive-dashboard-layouts.

## Core Principles
1. **One purpose per dashboard.**
   - Operational: monitor now and act fast (live, alerts).
   - Analytical: find patterns and explain them (filters, drill-down).
   - Strategic: track goals over periods (KPIs vs targets).
2. **Fit the critical information on a single screen** (Few). Scrolling is for detail, not for the headline.
3. **Hierarchy by position:** the most important KPIs go top-left, supporting trends next, detail and tables last.
4. **Context makes numbers meaningful.** Every KPI needs a comparison: target, prior period, or range.
5. **Highlight exceptions, mute the normal.** Use color sparingly for state (status tokens with icon + label). Everything else stays neutral.
6. **Prefer high data-density, low-ink forms:** bullet charts, sparklines, small multiples, sorted bars, and tables with in-cell bars. Avoid gauges, 3D, and decorative donuts (NN/g, Few).
7. **One filter bar scopes everything below it.** Charts never silently use different time ranges.
8. **Always show freshness** ("Updated 2 min ago", with the timezone) and data state (loading, empty, error, partial).

## Best Practices
- **Layout:**
  - KPI row (3–6 stat tiles) → primary trend chart(s) → breakdowns → detail table.
  - Use a 12-column grid with consistent tile heights per row.
  - Aim for about 5–9 visual elements per view. Beyond that, split into tabs or pages by question.
- **Titles:** tile titles name the metric and unit ("Revenue, USD"). Dashboard-level insights can use callouts ("3 regions below target").
- **Consistency:** same metric = same color, number format, and time grain everywhere. Build a shared metric registry (label, unit, format, good direction).
- **Time range:** a global picker with presets (Today, 7d, 30d, QTD, Custom), the timezone shown, and comparison toggle (vs previous period / last year).
- **Filters:** in URL search params (shareable, back-button safe), applied to all tiles, with an active filter summary and a "Reset" action.
- **Drill-down:** click a mark or row to open a filtered detail view or side panel. Keep breadcrumbs back to the overview.
- **States per tile:** skeleton of the final size on first load. On refetch, keep the previous data at reduced opacity (no flashing). Show the error inline with retry and an empty state explaining why.
- **Alerts/thresholds:** a target line or band on charts, and status badge + icon on KPIs. Don't flood color.
- **Density modes:** comfortable vs compact for power users.
- **Export/share:** CSV of the underlying table, and copy link with filters.
- **Personalization with restraint:** reorder/hide tiles, but ship a strong default.

## Implementation Guidance
**Dashboard type → design choices**

| Type | Refresh | Key elements | Avoid |
|---|---|---|---|
| Operational | seconds–minutes (live) | status tiles, sparkline trends, alert list, thresholds | heavy drill-down on the main view; animations |
| Analytical | on demand / hourly | filters, comparisons, breakdown bars, scatter, tables, drill-down | auto-refresh resetting user context |
| Strategic/executive | daily–monthly | KPIs vs targets, bullet charts, period-over-period | raw event streams |

**Tile anatomy**
```
┌ Title (metric, unit) ········ [info] [⋯ menu: export, view table] ┐
│ Value / chart area (fixed height)                                   │
│ Comparison line: ▲ 12% vs prior 30d · Target 1.2M                   │
└ Footnote: source · updated 09:42 UTC ───────────────────────────────┘
```

**Metric registry (single source of truth)**
```ts
export type MetricDef = {
  id: 'revenue' | 'activeUsers' | 'errorRate';
  label: string;
  unit: 'USD' | 'count' | 'percent';
  goodDirection: 'up' | 'down';
  format: (n: number) => string;
};
export const METRICS: Record<MetricDef['id'], MetricDef> = {
  revenue: { id: 'revenue', label: 'Revenue', unit: 'USD', goodDirection: 'up',
    format: n => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', notation: 'compact' }).format(n) },
  activeUsers: { id: 'activeUsers', label: 'Active users', unit: 'count', goodDirection: 'up',
    format: n => new Intl.NumberFormat('en-US', { notation: 'compact' }).format(n) },
  errorRate: { id: 'errorRate', label: 'Error rate', unit: 'percent', goodDirection: 'down',
    format: n => new Intl.NumberFormat('en-US', { style: 'percent', maximumFractionDigits: 2 }).format(n) },
};
```

## Recommended Workflow
1. Interview users: which decisions, how often, what triggers action? Classify the dashboard type.
2. List the 3–6 questions it must answer, and map each to a metric and comparison.
3. Choose a form per question (chart-type-selection). Prefer stat tiles, bullets, and sparklines.
4. Sketch a wireframe with real numbers, and check that the headline fits one screen at 1366×768.
5. Define the metric registry, color and status tokens, and the filter model (URL params).
6. Build the shell (filter bar, grid, tile component with states), then the tiles.
7. Stream tiles independently (Suspense) and set cache/revalidation per data freshness.
8. Accessibility pass: headings per tile, table alternatives, keyboard drill-down.
9. Test with real data extremes: zero, huge numbers, missing periods, many categories.
10. Usability test: can a user state status and the top issue in 5 seconds?

## Patterns
- **KPI row + trend + breakdown + table** (the default analytical layout).
- **Bullet chart instead of gauge:** actual bar, target tick, and qualitative bands.
- **Small multiples grid** for the same metric across segments, with shared scales.
- **Exception list:** "Needs attention" list sorted by severity, beside or above charts.
- **URL-driven filters:** `?range=30d&region=emea&compare=prev`, parsed on the server and passed to tiles.
- **Independent tile streaming:** each tile is an async Server Component wrapped in `<Suspense fallback={<TileSkeleton/>}>`.
- **Side-panel drill-down:** keeps overview context and uses `aria-modal` dialog/drawer semantics.

## Anti-Patterns
- **Gauge/donut walls.** Low data density, slow to read. Fix: stat tiles + bullets + sparklines.
- **KPIs without comparison.** "1,204". Is that good? Fix: delta vs period/target with direction semantics.
- **Rainbow categorical colors across tiles, the same color meaning different things.** Fix: shared palette, entity-stable colors, status colors reserved.
- **Per-tile time pickers with different defaults.** Contradictory numbers. Fix: global filter bar.
- **Auto-refresh that resets scroll, zoom, or open tooltips.** Fix: background updates, preserve interaction state, pause live when the user interacts.
- **Spinners replacing the whole dashboard on filter change.** Fix: per-tile loading, keep stale data visible.
- **Unlabeled freshness/timezone.** Fix: "Updated 09:42 UTC", and a stale badge when older than expected.
- **Everything above the fold crammed into tiny charts.** Fix: prioritize, and split by question.
- **Client-side fetching of 12 endpoints causing waterfalls.** Fix: parallel server fetches and streaming.

## Accessibility
- Each tile is a `<section aria-labelledby>` with a heading (h2/h3). The dashboard has a logical heading order and landmarks.
- Every chart has a text summary and table alternative (accessible-data-visualization).
- The filter bar uses accessible form controls, and filter changes announce results politely ("Showing 30 days, EMEA"), not each tile update.
- Status is never color-only: icon + text ("Critical").
- Live dashboards: no auto-announcing every refresh. Provide a pause control (WCAG 2.2.2) for auto-updating content.
- Drill-down targets are keyboard reachable, with focus management into and out of side panels.
- Target size ≥24×24 CSS px for tile menus and chart controls (WCAG 2.5.8).

## Responsive Design
- Desktop: 12-column grid. Tablet: 2 columns. Mobile: a single column in priority order (KPIs first).
- On mobile, transform charts (fewer ticks, horizontal bars, sparklines instead of full charts) and collapse filters into a sheet with an active filter summary.
- Use container queries on tiles so the same tile adapts within any grid slot.
- See [responsive-dashboard-layouts](../responsive-dashboard-layouts/Skill.md).

## Performance
- Aggregate on the server. Send tile-ready data, not raw rows.
- Fetch in parallel and stream per tile. Cache by filter key (Next.js `use cache`/revalidate or TanStack Query `staleTime`).
- Lazy-load below-the-fold chart bundles. Render static tiles (KPIs, tables, sparkline SVG) as Server Components.
- Budget: first meaningful KPIs visible in under about 1.5s. Avoid more than about 10 canvas/SVG charts mounted at once. Virtualize long tile lists.

## Security
- Enforce authorization per metric/tile on the server. Hiding a tile is not access control.
- Filters in URLs must be validated (zod) before querying. Prevent query injection in custom report builders.
- Exports: apply the same row-level security. Watermark or log sensitive exports.
- Multi-tenant: cache keys must include the tenant id.

## Testing
- Unit: metric registry formatting, delta/direction logic, filter param parsing.
- Component: tile states (loading, empty, error, stale) in Storybook with MSW mocks.
- E2E (Playwright): filter change updates all tiles, URL shareable, drill-down and back preserves filters.
- Visual regression of the default dashboard with fixed data and a frozen clock.
- Performance: Lighthouse/RUM on the dashboard route; track LCP and INP when filters change.

## Tooling
- Chart libs: Recharts 3 / shadcn charts, Tremor (dashboard components), ECharts 6, visx.
- URL state: nuqs. Data: TanStack Query or Next.js server fetching with caching.
- Grid: CSS grid + container queries; react-grid-layout for user-arrangeable tiles.
- Mocking: MSW. Stories: Storybook.

## Framework Notes
- **React (Vite SPA):**
  - TanStack Query per tile (`useQuery({ queryKey: ['revenue', filters] })`) with `placeholderData: keepPreviousData` to avoid flicker.
  - URL filters via nuqs or React Router search params.
  - `React.lazy` heavy chart tiles.
- **Next.js (App Router):**
  - `page.tsx` reads `searchParams` (async in Next 15+) and validates it with zod.
  - Each tile is an async Server Component fetching in parallel, wrapped in `<Suspense>` with a same-size skeleton, which gives streaming with no waterfalls.
  - Charts are `'use client'` leaves receiving serialized data.
  - Filter bar is a client component updating the URL (`router.replace` inside `startTransition`, or nuqs with `shallow: false`).
  - Use `revalidate`/cache tags per data freshness, and `export const dynamic = 'force-dynamic'` only for truly live tiles.
  - Live operational tiles subscribe client-side (see realtime-data-ui).

## AI Agent Guidance
- DO clarify the dashboard type and the 3–6 key questions before building.
- DO create a metric registry, a global URL-driven filter bar, and a tile component with loading/empty/error/stale states.
- DO put KPIs with comparisons at top-left, and prefer bullets, sparklines, and sorted bars over gauges and donuts.
- DO stream tiles with Suspense in Next.js and keep charts as client leaves.
- DON'T add per-tile date pickers, decorative colors, or auto-refresh that steals focus.
- Before done: render at 1366×768 and 375px, change filters (all tiles update, URL updates), throttle network (skeletons sized correctly, no CLS), keyboard through tiles and drill-down.

## Examples
```tsx
// app/(app)/dashboard/page.tsx
import { Suspense } from 'react';
import { z } from 'zod';
import { FilterBar } from './FilterBar';
import { KpiRow, RevenueTrendTile, RegionBreakdownTile, TileSkeleton } from './tiles';

const Filters = z.object({
  range: z.enum(['7d', '30d', '90d', 'qtd']).default('30d'),
  region: z.string().regex(/^[a-z-]+$/).optional(),
  compare: z.enum(['prev', 'yoy']).default('prev'),
});

export default async function DashboardPage({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const filters = Filters.parse(await searchParams);
  const key = JSON.stringify(filters);
  return (
    <main aria-labelledby="dash-title" className="space-y-6">
      <header className="flex items-center justify-between">
        <h1 id="dash-title">Sales overview</h1>
        <FilterBar initial={filters} />
      </header>
      <Suspense key={`kpi-${key}`} fallback={<TileSkeleton height={112} />}>
        <KpiRow filters={filters} />
      </Suspense>
      <div className="grid gap-6 lg:grid-cols-12">
        <Suspense key={`trend-${key}`} fallback={<TileSkeleton height={320} className="lg:col-span-8" />}>
          <RevenueTrendTile filters={filters} className="lg:col-span-8" />
        </Suspense>
        <Suspense key={`region-${key}`} fallback={<TileSkeleton height={320} className="lg:col-span-4" />}>
          <RegionBreakdownTile filters={filters} className="lg:col-span-4" />
        </Suspense>
      </div>
    </main>
  );
}
```
```tsx
// tiles/Tile.tsx: shared tile shell
export function Tile({ id, title, updatedAt, children, className }: {
  id: string; title: string; updatedAt: Date; children: React.ReactNode; className?: string;
}) {
  const time = new Intl.DateTimeFormat('en-US', { timeStyle: 'short', timeZone: 'UTC' }).format(updatedAt);
  return (
    <section aria-labelledby={`${id}-h`} className={`rounded-lg border p-4 ${className ?? ''}`}>
      <h2 id={`${id}-h`} className="text-sm font-medium text-muted-foreground">{title}</h2>
      <div className="mt-2">{children}</div>
      <p className="mt-2 text-xs text-muted-foreground">Updated {time} UTC</p>
    </section>
  );
}
```

## Related Skills
- [kpi-and-stat-components](../kpi-and-stat-components/Skill.md): KPI row and stat tiles
- [chart-type-selection](../chart-type-selection/Skill.md): form per question
- [responsive-dashboard-layouts](../responsive-dashboard-layouts/Skill.md): grid mechanics
- [realtime-data-ui](../realtime-data-ui/Skill.md): operational live tiles
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md): filter bar UX
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): URL-driven filters
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md): Suspense tile streaming
- [loading-states](../loading-states/Skill.md), [empty-states](../empty-states/Skill.md), [error-states](../error-states/Skill.md)
- [admin-panel-architecture](../admin-panel-architecture/Skill.md)

## Sources
- Stephen Few, *Information Dashboard Design* (2nd ed.): Book; single-screen, data density, bullet graphs, sparklines
- [NN/g: Dashboards: Making Charts and Graphs Easier to Understand](https://www.nngroup.com/articles/dashboards-preattentive/): Community research; operational vs analytical, preattentive attributes
- [FT Visual Vocabulary](https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary): Community; form selection
- Claude Code bundled `dataviz` skill (interaction and anti-patterns: filter row, hold previous render on refetch): Community agent skill

## License / Usage Notes
Book concepts are paraphrased. Code is original. Next.js `searchParams` as a Promise applies to Next 15+.

## Quality Tier
A: Canonical design sources plus concrete Next.js/React implementation. Dashboard usability claims are sourced but not independently tested.

## Status
Active

## Last Verified
2026-09-15
