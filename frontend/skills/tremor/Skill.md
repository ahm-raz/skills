# Tremor

## Summary
Tremor is a React + Tailwind CSS library for dashboards and charts, built on Recharts for visualization and Radix UI for accessible primitives. It exists in two forms: the npm package `@tremor/react` (3.18.7, Apache-2.0, peers React ^18, Recharts ^2) and the copy-paste Tremor components (35+ components, 250-300 blocks and templates). Vercel acquired Tremor in January 2025 and made the formerly paid Blocks free and open source. As of September 2026, the npm package's peer ranges lag React 19, so prefer the copy-paste distribution for new React 19/Tailwind v4 projects and verify compatibility.

## Category
UI Libraries

## Subcategories
Dashboards, charts (Recharts), KPI cards, copy-paste components, Tailwind theming, Vercel/v0, blocks and templates

## Problem It Solves
Teams building analytics dashboards need consistent, good-looking chart and KPI components (area/bar/line/donut charts, bar lists, trackers, progress, spark charts) wired to Tailwind styling without learning raw Recharts or D3.

## When To Use
- SaaS analytics pages, internal dashboards, usage/billing screens in Tailwind projects.
- Teams wanting prebuilt dashboard blocks (now free) as a starting point.
- Projects already on Recharts that want Tailwind-consistent wrappers.

## When Not To Use
- Very large or real-time datasets (tens of thousands of SVG points). Recharts SVG rendering becomes slow, so use canvas or WebGL charting (ECharts, visx with canvas).
- Highly custom visualizations (maps, network graphs). Use D3/visx.
- Strict React 19 projects wanting npm installs. `@tremor/react` peers React ^18 (verify before installing, or use copy-paste).
- shadcn/ui projects already using shadcn's chart components (also Recharts-based). Avoid two chart systems.

## Core Principles
1. **Chart components are data-first**: `data` array, `index` (x key), `categories` (series keys), `colors`, `valueFormatter`.
2. **Tailwind for styling and theming**: colors map to Tailwind palette names. Copy-paste versions expose the source for token changes.
3. **Recharts underneath**: responsive containers, tooltips and legends follow Recharts constraints (SVG, client-side).
4. **Own the code where possible**: the copy-paste distribution avoids version lock and eases React/Tailwind upgrades.
5. **Charts are client components**: data fetching stays on the server.

## Best Practices
- Fetch and aggregate data server-side (Server Components/route handlers). Send only the points needed to the chart.
- Always pass `valueFormatter` (Intl.NumberFormat) for axis and tooltip values (currency, percent, units).
- Provide a data table or summary text alternative for each chart (accessibility and export).
- Keep series count small (≤ 5-7) and use consistent category colors across the dashboard.
- Set explicit chart heights (`className="h-72"`) to prevent CLS.
- When using the copy-paste components with Tailwind v4, check the Tremor docs for v4 theme setup and ensure Recharts' current major matches the component code (not verified here).

## Implementation Guidance
| Distribution | Pros | Cons |
|---|---|---|
| Copy-paste components (tremor.so) | Own the code; adapt to React 19/Tailwind v4; tokens | Manual updates |
| `@tremor/react` npm (3.18.7) | Quick install | Peers React ^18, Recharts ^2, tailwind-merge ^2 (older); upgrade lag |
| shadcn charts (alternative) | Same Recharts base, shadcn tokens | Fewer dashboard-specific components |

Typical dashboard layout:
- KPI row: Card + metric + delta badge + spark chart.
- Primary trend: AreaChart with date index.
- Breakdown: BarList or DonutChart plus a table alternative.
- Filters: date range and segments synced to URL.

## Recommended Workflow
1. Define metrics, aggregation and the time grain on the server. Shape data as `{ date, seriesA, seriesB }[]`.
2. Choose the distribution (copy-paste recommended for new stacks) and install components or blocks.
3. Build a chart wrapper that standardizes formatters, colors, empty/loading states and the table alternative.
4. Compose the dashboard layout responsively.
5. Test with realistic data volumes and check INP when interacting with tooltips and filters.

## Patterns
- **Server data + client chart**: `page.tsx` (RSC) queries the DB, then passes a serialized array to `<RevenueChart data={rows} />` (client).
- **KPI card with delta**: compute the delta server-side, render the badge with semantic color plus text ("+12% vs last month").
- **Empty state**: when `data.length === 0`, render a message instead of an empty axis.
- **URL-driven filters**: date range in search params, so the server refetches and charts stay stateless.

## Anti-Patterns
- **Fetching in the chart component with useEffect**: waterfalls and spinners. Fetch on the server.
- **Color as the only differentiator**: add labels and legends and pattern or text cues.
- **Thousands of points in an SVG line chart**: downsample server-side (e.g. LTTB) or switch library.
- **Mixing `@tremor/react` npm with copy-paste components**: duplicated styles and versions.
- **Installing `@tremor/react` into a React 19 project with `--force`/`--legacy-peer-deps`** without testing.

## Accessibility
- Charts are SVG with limited screen-reader semantics. Provide `aria-label`/`role="img"` summaries and an adjacent data table or "view as table" toggle (WCAG 1.1.1, 1.3.1).
- Ensure series colors meet non-text contrast 3:1 (1.4.11) and don't rely on color alone (1.4.1).
- Tooltips on hover must have keyboard alternatives (a table, or focusable points if implemented).
- Radix-based interactive components (Select, Tabs, etc.) inherit Radix keyboard support.

## Responsive Design
- Charts fill their container width (Recharts ResponsiveContainer). Set heights per breakpoint.
- Reduce ticks, hide the legend and rotate or shorten labels on small screens (`startEndOnly`-style options where available).
- Dashboard grids: `grid-cols-1 md:grid-cols-2 xl:grid-cols-4` for KPI rows. Consider container queries in resizable panels.

## Performance
- Recharts + D3 modules add notable client JS. Lazy-load below-fold charts and avoid charts in initial app shell.
- Memoize data transformations and keep `data` reference-stable to avoid re-rendering SVG.
- Downsample on the server. Avoid animating large datasets.

## Security
- Don't embed raw data from untrusted sources into tooltips as HTML. Render as text.
- Apache-2.0 (npm package). Copy-paste blocks are MIT per Vercel's acquisition announcement. Keep attribution and license notes.

## Testing
- Unit test data shaping and formatters (pure functions).
- Component tests: assert the empty state and table alternative. SVG chart internals are brittle to test in jsdom (ResizeObserver needed).
- Visual regression with fixed data for charts (Playwright screenshots).

## Tooling
- `@tremor/react` 3.18.7 (Apache-2.0), copy-paste Tremor components and blocks (free since the Vercel acquisition), Recharts, Radix UI, Tailwind.
- v0 (Vercel) uses Tremor components to generate dashboard UIs.
- Alternative: shadcn/ui charts (Recharts-based).

## Framework Notes
- **Next.js App Router**: chart components need `"use client"`. Keep them leaves under Server Component pages that fetch data. Use `loading.tsx`/Suspense skeletons with fixed heights. Avoid passing functions (formatters) from Server to Client Components; define formatters inside the client module.
- **React (Vite SPA)**: fetch with TanStack Query, render charts. Same accessibility and performance guidance.
- React 19: the npm package peers React ^18 (unverified runtime compatibility). Copy-paste components can be adapted.

## AI Agent Guidance
- DO check whether the repo uses `@tremor/react` (npm) or copied Tremor components, and don't mix them.
- DO keep formatters in client modules and data fetching on the server.
- DO add a table or text alternative for each chart.
- DON'T install `@tremor/react` in React 19 projects without flagging the peer mismatch.
- Verify before done: fixed chart heights (no CLS), formatted values, empty state, contrast of series colors, no client-side data waterfalls.

## Examples
```tsx
// app/(dashboard)/revenue/page.tsx: Server Component
import { RevenueChart } from "./revenue-chart";
import { getMonthlyRevenue } from "@/server/metrics";

export default async function RevenuePage() {
  const rows = await getMonthlyRevenue(); // [{ month: "2026-01", Subscriptions: 12000, Services: 3400 }, ...]
  return (
    <section className="space-y-4">
      <h1 className="text-xl font-semibold">Revenue</h1>
      <RevenueChart data={rows} />
    </section>
  );
}
```
```tsx
// app/(dashboard)/revenue/revenue-chart.tsx
"use client";
import { AreaChart } from "@/components/tremor/area-chart"; // copy-paste Tremor component (or "@tremor/react")

const usd = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });

type Row = { month: string; Subscriptions: number; Services: number };

export function RevenueChart({ data }: { data: Row[] }) {
  if (data.length === 0) return <p className="text-sm text-muted-foreground">No revenue data for this period.</p>;
  return (
    <figure>
      <AreaChart
        className="h-72"
        data={data}
        index="month"
        categories={["Subscriptions", "Services"]}
        valueFormatter={(v: number) => usd.format(v)}
      />
      <figcaption className="sr-only">
        Monthly revenue by stream. Latest month: {usd.format(data.at(-1)!.Subscriptions)} subscriptions,{" "}
        {usd.format(data.at(-1)!.Services)} services.
      </figcaption>
    </figure>
  );
}
```

## Related Skills
- [recharts](../recharts/Skill.md): underlying chart library
- [dashboard-design](../dashboard-design/Skill.md): layout and metric design
- [kpi-and-stat-components](../kpi-and-stat-components/Skill.md): KPI cards
- [accessible-data-visualization](../accessible-data-visualization/Skill.md): chart accessibility
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md): when to switch libraries
- [shadcn-ui](../shadcn-ui/Skill.md): shadcn charts alternative
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [Vercel acquires Tremor](https://vercel.com/blog/vercel-acquires-tremor): Official. Acquisition, Blocks free under MIT, v0 integration
- [Tremor site](https://www.tremor.so/): Official. Copy-paste vs npm, component and block counts, Recharts and Radix
- [tremorlabs/tremor](https://github.com/tremorlabs/tremor): Open Source. Apache-2.0, copy-paste positioning
- [@tremor/react registry metadata](https://registry.npmjs.org/@tremor/react/latest): Official. Version 3.18.7, React ^18 and Recharts ^2
- [Tremor NPM docs](https://npm.tremor.so/): Official. npm distribution
- [Vercel community: Tremor, shadcn and Vercel](https://community.vercel.com/t/tremor-shadcn-and-vercel/17242): Community. Ecosystem discussion

## License / Usage Notes
`@tremor/react` is Apache-2.0. Blocks were made MIT/open source after the acquisition. Summarized content; code examples are original. Tailwind v4 and React 19 support of the copy-paste components were not verified.

## Quality Tier
B: acquisition and distribution facts verified, but the current Tailwind v4/React 19 status and recent maintenance cadence of Tremor components are unverified.

## Status
Active (npm package lagging; copy-paste preferred; verify maintenance)

## Last Verified
2026-09-15
