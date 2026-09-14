# Apache ECharts (in React and Next.js)

## Summary
Apache ECharts (v6, latest 6.1.0 May 2026) is a declarative option-object charting library with Canvas and SVG renderers. It has 20+ series types (maps, graph, sankey, treemap, sunburst, candlestick, new chord), built-in dataZoom, visualMap, brush, a dataset/transform layer, an ARIA module, and server-side SVG rendering. v6 added a new default theme with dark-mode switching, a matrix coordinate system, axis breaks, scatter jitter, reusable custom series, and automatic axis-label overflow layout. In React, use **echarts-for-react** or a small custom hook over tree-shaken `echarts/core`.

## Category
Data Visualization

## Subcategories
canvas/SVG charts, echarts-for-react, option API, dataset, dataZoom, visualMap, geo, SSR SVG, ECharts 6 migration

## Problem It Solves
One library covers nearly every chart type an enterprise React dashboard needs, handles large data (sampling, large and progressive modes, dataZoom), and can pre-render SVG on the server in Next.js for fast, crawlable charts.

## When To Use
- BI, monitoring, and finance dashboards needing many chart types, zoom, brushing, and linked charts.
- Tens of thousands to hundreds of thousands of points on Canvas.
- Static charts rendered on the server (Route Handlers or Server Components) for reports, OG images, and emails.

## When Not To Use
- One or two simple charts with strict bundle budgets: Chart.js or uPlot.
- Bespoke visuals and markup-level accessibility: visx/d3.
- Teams wanting JSX composition (`<XAxis/>`): Recharts.

## Core Principles
1. **Everything is `option`.** Merges by default. Use `replaceMerge: ['series']` or `notMerge` when series are removed.
2. **Tree-shake:** `echarts/core` + `echarts.use([...])`. With echarts-for-react, import `ReactEChartsCore from 'echarts-for-react/lib/core'` and pass `echarts={echarts}`.
3. **Separate data from encoding** with `dataset` + `encode`.
4. **Lifecycle:** init on mount, `resize()` on container resize, `dispose()` on unmount (the wrapper does this).
5. **Choose the renderer deliberately:** Canvas for big data/effects, SVG for many small charts, low memory, crisp zoom, and SSR.
6. **Keep `aria.enabled: true`.** It generates a textual description, and `aria.decal` adds color-independent patterns.

## Best Practices
- **v6 upgrade:**
  - The default theme changed. For v5 visuals, `import 'echarts/theme/v5'` and use theme `'v5'`.
  - Axis label overflow prevention is on by default. Opt out with `grid.outerBoundsMode: 'none'` and `nameMoveOverlap: false`.
  - Rich text inherits plain label styles. Opt out with `richInheritPlainLabel: false`.
- Memoize `option` (`useMemo`). echarts-for-react calls `setOption` whenever the `option` reference changes.
- Large line series: `sampling: 'lttb'`, `showSymbol: false`, `animation: false`. Scatter/bar: `large: true`, and tune `progressive`/`progressiveThreshold` against the option reference.
- Use `dataZoom` (inside + slider) for long time ranges.
- Tooltip `trigger: 'axis'` with `valueFormatter` (`Intl.NumberFormat`).
- Theme from design tokens via `echarts.registerTheme('brand-light' | 'brand-dark', ...)`, and switch the `theme` prop on dark mode (re-inits the chart).
- `opts={{ renderer: 'canvas', useDirtyRect: true }}` for frequently updating charts.
- Linked charts: `echarts.connect(groupId)` after instances mount (get instances with `ref.getEchartsInstance()`).

## Implementation Guidance
**Renderer selection**

| Situation | Renderer |
|---|---|
| > ~1k elements, heatmap, big scatter, effects | canvas |
| Many small charts, low-end mobile, crisp zoom/print | svg |
| Server pre-render (Next.js) | svg with `ssr: true` + `renderToSVGString()` |

**Data volume ladder**

| Points | Setup |
|---|---|
| < 10k | defaults |
| 10k–200k | canvas, `showSymbol:false`, `sampling:'lttb'`, `large:true`, animation off |
| 200k+ | progressive + dataZoom windowing, server aggregation, or deck.gl/WebGL |

**Tree-shaken setup module**
```ts
// src/lib/charts/echarts-setup.ts
import * as echarts from 'echarts/core';
import { LineChart, BarChart, type LineSeriesOption, type BarSeriesOption } from 'echarts/charts';
import {
  GridComponent, TooltipComponent, DatasetComponent, DataZoomComponent, LegendComponent, AriaComponent,
  type GridComponentOption, type TooltipComponentOption, type DatasetComponentOption,
} from 'echarts/components';
import { CanvasRenderer, SVGRenderer } from 'echarts/renderers';

echarts.use([LineChart, BarChart, GridComponent, TooltipComponent, DatasetComponent, DataZoomComponent, LegendComponent, AriaComponent, CanvasRenderer, SVGRenderer]);
export type ECOption = echarts.ComposeOption<LineSeriesOption | BarSeriesOption | GridComponentOption | TooltipComponentOption | DatasetComponentOption>;
export { echarts };
```

## Recommended Workflow
1. Create the setup module with on-demand imports and the `ECOption` type.
2. Write pure `buildXOption(rows, t): ECOption` functions (unit-testable, server-safe).
3. Render with `ReactEChartsCore` in a `'use client'` component with explicit height.
4. Memoize the option. Use `notMerge`/`replaceMerge` when series sets change.
5. Enable aria and decals, and add a caption and table.
6. For static/SEO charts, render SVG on the server instead.
7. Test resize, theme switch, route navigation (dispose), and 375px width.

## Patterns
- **Option builder + thin client component** (see Examples).
- **Server SVG in a Server Component:** `renderToSVGString()` inside a server-only module, output inline. Zero client JS for static report charts.
- **Hybrid:** server SVG first, then `dynamic()` import the interactive client chart on user intent (click "Explore").
- **Drilldown:** `onEvents={{ click: (p) => router.push(`/regions/${p.name}`) }}` (memoize the `onEvents` object).
- **Linked zoom:** set `group` on each instance and `echarts.connect('ops')`.

## Anti-Patterns
- **`import ReactECharts from 'echarts-for-react'` (full build).** Pulls in all of echarts (~1MB min). Fix: `echarts-for-react/lib/core` + tree-shaken core.
- **Inline `option={{...}}` or `onEvents={{...}}` objects.** `setOption` on every render. Fix: `useMemo`.
- **Removing a series with default merge.** A stale series remains. Fix: `notMerge` or `replaceMerge`.
- **Container without height.** A 0px chart. Fix: `style={{ height: 320 }}`.
- **Importing echarts-for-react in a Server Component.** Error. Fix: `'use client'`, or use SSR SVG.
- **HTML tooltip `formatter` concatenating user strings.** XSS. Fix: `echarts.format.encodeHTML` or `valueFormatter`.
- **Rainbow `visualMap`.** Fix: sequential single-hue `inRange.color`.

## Accessibility
- `aria: { enabled: true, label: { description } }` gives an auto or custom description. `aria.decal.show: true` adds patterns.
- The canvas isn't keyboard-navigable. Put the takeaway in visible text, provide an HTML data table, and keep filters and legend toggles as real buttons outside the chart (`dispatchAction({ type: 'legendToggleSelect', name })`).
- Tooltip info must also be reachable without hover (table/detail panel).
- `animation: false` under `prefers-reduced-motion`.

## Responsive Design
- echarts-for-react auto-resizes on container size changes (verify `autoResize` in your wrapper version). With a custom hook, use `ResizeObserver` → `chart.resize()`.
- The `media` queries option (`baseOption` + `media: [{ query: { maxWidth: 500 }, option }]`) moves the legend and flips orientation.
- v6 automatic label overflow handling reduces clipping.
- `dataZoom` `type: 'inside'` for touch pan/pinch.

## Performance
- Canvas + sampling + `large` + `progressive` for big data. SVG (VDOM since 5.3) for many small charts.
- Typed/2D-array `dataset.source` instead of object arrays.
- Throttle live `setOption` calls to about 1–4 Hz on dashboards. Use `lazyUpdate: true`.
- Code-split: `next/dynamic` the chart component so echarts stays out of the initial route bundle.

## Security
- Escape user data in HTML tooltips and rich labels (`echarts.format.encodeHTML`).
- Serve map GeoJSON from trusted origins.
- AI-generated options (ECharts MCP): validate against the typed `ECOption`, and never eval function strings.
- Inline server SVG output only from trusted option input (it's markup).

## Testing
- Snapshot option builders (Vitest).
- Server SVG snapshots in Node (deterministic, `animation: false`).
- Playwright screenshots of client charts. Navigate away and back to catch dispose leaks.
- Assert the table alternative and aria description exist.

## Tooling
- echarts 6.1.x (active).
- echarts-for-react (community React wrapper; confirm React 19 compatibility and recent releases before adopting; a ~40-line custom hook is a valid alternative).
- echarts-gl (3D/WebGL series). ECharts MCP server (experimental).

## Framework Notes
- **React (Vite SPA):** `ReactEChartsCore` with the tree-shaken core, `React.lazy` for chart routes, and `useMemo` options. Theme switch = change the `theme` prop (re-init).
- **Next.js (App Router):**
  - Interactive charts: `'use client'` + echarts-for-react. Reserve height to avoid CLS.
  - Defer heavy charts with `dynamic(() => import('./OpsChart'), { ssr: false, loading: Skeleton })` from a client parent.
  - Static charts: build the option in a Server Component and call `init(null, null, { renderer: 'svg', ssr: true, width, height })` → `renderToSVGString()` in a `server-only` module, then inline the SVG. It is instant, crawlable, and ships zero JS.
  - The SVG also works from a Route Handler (`Content-Type: image/svg+xml`) for emails and OG images.
  - Keep `Intl` locales explicit so server-rendered text matches the client.

## AI Agent Guidance
- DO use `echarts/core` on-demand imports with `echarts-for-react/lib/core`, a typed `ECOption`, and memoized options/events.
- DO pick the renderer consciously, and configure sampling/large/dataZoom for big data.
- DO enable aria and decals, and add a caption and table.
- DO consider server SVG for non-interactive charts in Next.js.
- DON'T assume v5 visuals; note the v6 theme change.
- DON'T build HTML tooltips from unescaped data.
- Before done: resize, dark mode, series add/remove, route away and back without errors, bundle check (no full echarts).

## Examples
```tsx
'use client';
import { useMemo } from 'react';
import ReactEChartsCore from 'echarts-for-react/lib/core';
import { echarts, type ECOption } from '@/lib/charts/echarts-setup';

type Row = { ts: number; errors: number; requests: number };
const compact = new Intl.NumberFormat('en-US', { notation: 'compact' });

export function buildErrorsOption(rows: Row[]): ECOption {
  return {
    aria: { enabled: true, decal: { show: true } },
    animation: false,
    dataset: { source: rows.map(r => [r.ts, r.errors]), dimensions: ['ts', 'errors'] },
    grid: { left: 8, right: 16, top: 24, bottom: 48, containLabel: true },
    tooltip: { trigger: 'axis', valueFormatter: v => compact.format(Number(v)) },
    xAxis: { type: 'time' },
    yAxis: { type: 'value', min: 0 },
    dataZoom: [{ type: 'inside' }, { type: 'slider', height: 20 }],
    series: [{ type: 'line', name: 'Errors', encode: { x: 'ts', y: 'errors' }, showSymbol: false, sampling: 'lttb' }],
  };
}

export function ErrorsChart({ rows, summary }: { rows: Row[]; summary: string }) {
  const option = useMemo(() => buildErrorsOption(rows), [rows]);
  return (
    <figure>
      <figcaption>{summary}</figcaption>
      <ReactEChartsCore
        echarts={echarts}
        option={option}
        notMerge
        lazyUpdate
        opts={{ renderer: 'canvas' }}
        style={{ height: 320, width: '100%' }}
        aria-label={summary}
      />
    </figure>
  );
}
```
```tsx
// app/reports/weekly/ErrorsSvg.tsx: Server Component, zero client JS
import 'server-only';
import * as echarts from 'echarts';

export async function ErrorsSvg({ rows, title }: { rows: { ts: number; errors: number }[]; title: string }) {
  const chart = echarts.init(null, null, { renderer: 'svg', ssr: true, width: 640, height: 280 });
  chart.setOption({
    animation: false, aria: { enabled: true },
    xAxis: { type: 'time' }, yAxis: { type: 'value', min: 0 },
    series: [{ type: 'line', showSymbol: false, data: rows.map(r => [r.ts, r.errors]) }],
  });
  const svg = chart.renderToSVGString();
  chart.dispose();
  return (
    <figure>
      <figcaption>{title}</figcaption>
      <div role="img" aria-label={title} dangerouslySetInnerHTML={{ __html: svg }} />
    </figure>
  );
}
```
(The inlined SVG is generated from trusted, typed numeric data. Do not pass untrusted strings into labels without escaping.)

## Related Skills
- [chartjs](../chartjs/Skill.md): lighter canvas alternative
- [recharts](../recharts/Skill.md): JSX-composable SVG alternative
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md)
- [maps-and-geospatial-ui](../maps-and-geospatial-ui/Skill.md): ECharts geo vs tile maps
- [dashboard-design](../dashboard-design/Skill.md)
- [accessible-data-visualization](../accessible-data-visualization/Skill.md)
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md): static vs dynamic chart rendering

## Sources
- [ECharts 6 features](https://echarts.apache.org/handbook/en/basics/release-note/v6-feature/): Official; new features
- [Migration v5 → v6](https://echarts.apache.org/handbook/en/basics/release-note/v6-upgrade-guide/): Official; theme/overflow/rich text
- [ECharts releases](https://github.com/apache/echarts/releases): Official; 6.1.0
- [Canvas vs SVG](https://echarts.apache.org/handbook/en/best-practices/canvas-vs-svg/): Official; renderer choice
- [Server-side rendering](https://echarts.apache.org/handbook/en/how-to/cross-platform/server/): Official; `ssr`, `renderToSVGString`, client runtime
- [echarts-for-react](https://github.com/hustcc/echarts-for-react): Open Source/Community; React wrapper (core import, props)

## License / Usage Notes
ECharts is Apache-2.0. echarts-for-react is MIT. Map data has separate licenses. Content is summarized. Examples are original. The wrapper's React 19 status and `large`/`progressive` defaults were not re-verified this cycle.

## Quality Tier
A: Official v6, renderer, and SSR docs verified. Wrapper details from its established API.

## Status
Active

## Last Verified
2026-09-15
