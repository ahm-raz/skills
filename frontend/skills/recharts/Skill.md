# Recharts

## Summary
Recharts is a declarative React charting library that composes SVG charts from components (`<LineChart>`, `<XAxis>`, `<Tooltip>`). Version 3 (3.0 GA mid-2025, 3.x ongoing in 2026) rewrote internal state management with strict typing. It removed the `recharts-scale` and `react-smooth` dependencies, enabled `accessibilityLayer` by default, and exposes new hooks. All versions below 3.0 were deprecated on npm in May 2026. Docs now live at recharts.github.io.

## Category
Data Visualization

## Subcategories
React charts, SVG charts, Recharts 3 migration, shadcn/ui charts, tooltips, responsive containers

## Problem It Solves
It gives React teams standard business charts (line, area, bar, composed, pie, radar, scatter, funnel, treemap, sankey) quickly, with idiomatic JSX composition, theming via props/CSS, and reasonable accessibility. It is also the engine behind shadcn/ui charts and Tremor.

## When To Use
- React/Next.js dashboards with standard cartesian/polar charts and moderate data (hundreds to low thousands of points per chart).
- Teams using shadcn/ui charts, which wrap Recharts.
- When JSX composition and custom React tooltip/legend content matter.

## When Not To Use
- More than about 5k points per series, or real-time streams at high frequency: SVG DOM cost. Use uPlot, ECharts (canvas), or Chart.js with decimation.
- Maps, complex networks, bespoke forms: use d3/visx or ECharts.
- Non-React stacks.

## Core Principles
1. **Composition:** a chart container plus child components. Order of children = paint order (v3: z-index follows render order; later children draw on top).
2. **Size must be known.** Wrap in `<ResponsiveContainer width="100%" height={300}>` or give explicit `width`/`height`. A parent with 0 height renders nothing.
3. **Stable props.** Memoize `data`, `dataKey` functions, and custom components. A changed `dataKey` forces point recalculation.
4. **Client-only rendering.** Recharts measures the DOM and uses hooks, so it needs `'use client'` in the Next.js App Router.
5. **Upgrade to v3.** v2 receives no updates.

## Best Practices
- Keep `accessibilityLayer` (default true in v3). It adds keyboard arrow navigation across data points and ARIA to the chart surface. Add a title/description and a table alternative yourself.
- Set `isAnimationActive={false}` for dashboards with many charts, frequently refreshed data, or `prefers-reduced-motion`.
- Use `<YAxis width="auto" />` (v3) to fit tick labels instead of guessing widths.
- Use `tickFormatter` with `Intl.NumberFormat` compact notation, and `minTickGap` to prevent collisions.
- Custom tooltip: type props as `TooltipContentProps` (renamed from `TooltipProps` in v3).
- Multiple Y axes: give each `yAxisId`, and pass matching axis ids to `CartesianGrid` and `Tooltip` (v3 requirement). Prefer not using dual axes at all.
- Replace `<Customized>` hacks with v3 custom components or hooks that read chart state.
- Use `dot={false}` on dense lines, and `connectNulls` deliberately. In v3 Area charts treat nulls as 0 when connected, so check the semantics.
- Isolate hover-driven state (for example, a highlighted series) into small components so the whole chart doesn't re-render.
- Throttle mouse handlers for heavy composed charts (the docs suggest delays under 100ms still feel instant).

## Implementation Guidance
**v2 → v3 migration checklist**

| Change | Action |
|---|---|
| `CategoricalChartState` removed from events/`Customized` | Use v3 hooks / event payloads; refactor custom layers into components |
| `TooltipProps` → `TooltipContentProps` | Rename types in custom tooltips |
| `recharts-scale`, `react-smooth` removed | Delete direct imports; `getNiceTickValues` now exported from `recharts` |
| `alwaysShow`, `isFront` (Reference*), `animateNewValues`, Pie `blendStroke` removed | Use `ifOverflow`, reorder JSX, `stroke="none"` |
| Multiple Y axes render sorted by `yAxisId` | Name ids deliberately |
| Legend order not guaranteed | Provide explicit `payload` / custom legend content if order matters |
| `ref.current.current` on ResponsiveContainer | Use the ref directly |
| Keyboard events no longer via `onMouseMove` | Handle keyboard separately |
| Requires ES6 target, React 16.8+, TS 5 | Update toolchain |

**Data volume guidance (SVG)**

| Points rendered (all series) | Recommendation |
|---|---|
| < 1,000 | Default settings fine |
| 1k–5k | `dot={false}`, animations off, memoized data |
| > 5k | Aggregate/downsample (LTTB) before passing, or switch library |

## Recommended Workflow
1. Shape data as an array of flat objects (`{ date, revenue, cost }`) and memoize it.
2. Pick a chart container and add axes, grid, tooltip, and legend.
3. Wrap in `ResponsiveContainer` with a fixed height (reserve space to avoid CLS).
4. Apply theme tokens (stroke colors from CSS variables).
5. Add formatters, direct labels if 4 or fewer series, and reference lines for targets.
6. Verify keyboard navigation (accessibilityLayer), and add a figcaption and table toggle.
7. Test empty, single-point, and null data, and a narrow width.
8. Profile with React DevTools when more than 5 charts are on a page.

## Patterns
- **CSS-variable theming (shadcn style):** `stroke="var(--chart-1)"` so dark mode flips via tokens.
- **Chart card:** `<figure>` → title/subtitle → chart → `<details>` with a data table.
- **Top-N with Other** before passing data to BarChart.
- **Sync crosshair across charts:** give related charts the same `syncId`.
- **Brush for range selection:** `<Brush dataKey="date" height={24} />` on long series.
- **Tooltip portal (v3):** render the tooltip outside overflow-hidden cards.

## Anti-Patterns
- **ResponsiveContainer inside a flex/grid child without min-width/height.** The chart collapses or grows forever. Fix: give the parent explicit height and `min-width: 0`.
- **Inline arrow functions for `dataKey`/`tickFormatter` on every render with big data.** Fix: `useCallback` / module-level functions.
- **Passing 50k raw rows.** Fix: aggregate or LTTB downsample to about 2× pixel width.
- **Relying on legend color only.** Fix: direct labels, dash patterns (`strokeDasharray`) for secondary series.
- **Using `<Customized>` to read internal state (v2 pattern).** Breaks in v3. Fix: hooks/custom components.
- **Animations on a live-updating chart.** Jank. Fix: `isAnimationActive={false}`.
- **Server-rendering without `'use client'`.** Hook errors. Fix: client boundary, with a server-rendered skeleton of the same height.

## Accessibility
- v3 `accessibilityLayer` (default on): the chart becomes focusable, arrow keys move the active index, and the tooltip follows focus. Verify with a screen reader.
- Add `title`/`desc` (`<LineChart title="..." desc="...">` or an outer `aria-labelledby`) summarizing the takeaway.
- Provide a data table (visible toggle or `<details>`) for WCAG 1.1.1.
- Mark colors ≥3:1 against the background. Distinguish series by dash/shape too.
- Respect reduced motion: `isAnimationActive={!prefersReducedMotion}`.

## Responsive Design
- `ResponsiveContainer` observes parent size. Use `aspect` or a fixed `height`. Reserve the height in CSS so SSR placeholders don't shift layout.
- Reduce ticks at narrow widths (`interval="preserveStartEnd"`, `minTickGap={24}`).
- Switch `layout="vertical"` BarChart on mobile for long category names.
- Hide the legend on mobile in favor of direct labels or a list below.

## Performance
- SVG nodes scale with points × series. Keep dots off and aggregate.
- Memoize data and props, and split hover state into child components (official performance guide).
- Use `eslint-plugin-react-perf` rules `jsx-no-new-array-as-prop`, `jsx-no-new-function-as-prop`, and `jsx-no-jsx-as-prop` as the docs recommend.
- Lazy-load chart-heavy routes (`next/dynamic` with `ssr: false` if needed).

## Security
Custom tooltip/label components render React text by default (safe). Never inject `dangerouslySetInnerHTML` with series names from user data.

## Testing
- jsdom has no layout, so ResponsiveContainer reports 0 width. In unit tests, render with explicit `width`/`height` or mock `ResizeObserver` and element size.
- Test custom tooltip/formatter components in isolation.
- Playwright visual snapshots of chart stories. Disable animations for determinism.
- Keyboard test: focus the chart and press ArrowRight to assert tooltip content.

## Tooling
- recharts 3.x (active; 3.9 adding custom animations per 2026 status update). v2 deprecated on npm (May 2026).
- shadcn/ui `chart` component (Recharts wrapper with CSS-variable config).
- Tremor (Recharts-based dashboard components).
- LTTB downsampling: `downsample-lttb` or a hand-rolled implementation.

## Framework Notes
- **React (Vite SPA):** import directly and lazy-load chart-heavy routes with `React.lazy`. React 19 is supported in v3. Keep data props referentially stable so React Compiler/memo can skip work.
- **Next.js (App Router):**
  - Chart components need `'use client'`; the recharts package touches hooks and DOM measurement.
  - Fetch and aggregate data in a Server Component and pass serializable props. Dates go as ISO strings or epoch numbers, not `Date`, and never pass functions.
  - `ResponsiveContainer` measures after mount, so the server HTML has no chart. Wrap it in a div with a fixed CSS height (or `aspect-ratio`) so the placeholder reserves space and there is no CLS. Show a same-size skeleton via Suspense/`loading.tsx`.
  - Use `next/dynamic(() => import('./RevenueChart'), { ssr: false, loading: () => <ChartSkeleton/> })` only inside a client component, when you want to defer the chart bundle or hit hydration warnings from locale-dependent formatting. Otherwise, a plain client component is fine.
  - Keep `Intl.NumberFormat` locale explicit to avoid server/client text mismatches in any server-rendered labels.

## AI Agent Guidance
- DO install `recharts@^3` and use v3 type names (`TooltipContentProps`).
- DO wrap in `ResponsiveContainer` with an explicit height, add `'use client'`, and memoize data.
- DO keep `accessibilityLayer` on and add a title/description plus a table alternative.
- DON'T use removed v2 APIs (`Customized` state props, `blendStroke`, `alwaysShow`, `isFront`).
- DON'T render more than 5k SVG points; downsample instead.
- Before done: check the chart renders non-zero size, keyboard arrows work, dark mode colors resolve, and no console warnings about width(0)/height(0).

## Examples
```tsx
'use client';
import { memo, useMemo } from 'react';
import {
  ResponsiveContainer, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine,
  type TooltipContentProps,
} from 'recharts';

type Row = { month: string; revenue: number; target: number };
const compact = new Intl.NumberFormat(undefined, { notation: 'compact' });
const currency = new Intl.NumberFormat(undefined, { style: 'currency', currency: 'USD' });

function RevenueTooltip({ active, payload, label }: TooltipContentProps<number, string>) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded border bg-background p-2 text-sm shadow">
      <div className="font-medium">{label}</div>
      {payload.map(p => <div key={String(p.dataKey)}>{p.name}: {currency.format(Number(p.value))}</div>)}
    </div>
  );
}

export const RevenueChart = memo(function RevenueChart({ rows }: { rows: Row[] }) {
  const data = useMemo(() => rows, [rows]);
  return (
    <figure aria-labelledby="rev-title">
      <figcaption id="rev-title">Revenue passed target in May</figcaption>
      <div style={{ height: 280 }}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: 16, bottom: 0, left: 0 }}>
            <CartesianGrid stroke="var(--chart-grid)" vertical={false} />
            <XAxis dataKey="month" minTickGap={24} />
            <YAxis width="auto" tickFormatter={v => compact.format(v)} />
            <Tooltip content={RevenueTooltip} />
            <ReferenceLine y={data[0]?.target} stroke="var(--muted-foreground)" label="Target" />
            <Line type="monotone" dataKey="revenue" name="Revenue" stroke="var(--chart-1)" strokeWidth={2} dot={false} isAnimationActive={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </figure>
  );
});
```

## Related Skills
- [shadcn-ui](../shadcn-ui/Skill.md): chart component built on Recharts
- [tremor](../tremor/Skill.md): dashboard kit on Recharts
- [nivo-and-visx](../nivo-and-visx/Skill.md): alternative React chart stacks
- [echarts](../echarts/Skill.md): canvas alternative for larger data
- [accessible-data-visualization](../accessible-data-visualization/Skill.md)
- [react-performance-optimization](../react-performance-optimization/Skill.md): memoization patterns

## Sources
- [Recharts 3.0 migration guide](https://github.com/recharts/recharts/wiki/3.0-migration-guide): Official; breaking changes and new features
- [Recharts status update 2026 (#7355)](https://github.com/recharts/recharts/issues/7355): Official; 3.9 roadmap, docs move
- [v2 deprecation notice (#7361)](https://github.com/recharts/recharts/issues/7361): Official; v2 unsupported
- [Recharts performance guide](https://recharts.github.io/en-US/guide/performance/): Official; memoization, isolation, eslint rules

## License / Usage Notes
Recharts is MIT licensed. Content is summarized. The code example is original. Exact prop availability varies across 3.x minors, so check the installed version's API docs.

## Quality Tier
A: Official migration and performance docs verified. Newest 3.x hooks and `responsive` sizing props not individually verified.

## Status
Active

## Last Verified
2026-09-15
