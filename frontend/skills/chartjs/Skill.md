# Chart.js (with react-chartjs-2)

## Summary
Chart.js (v4, latest 4.5.1, Oct 2025) is a Canvas-based charting library with 8 core chart types (line, bar, radar, doughnut/pie, polarArea, bubble, scatter), mixed charts, plugins, and tree-shakeable registration. In React and Next.js it is used through **react-chartjs-2** (`<Line>`, `<Bar>`, `<Chart>`), which manages the instance lifecycle. It is small and handles tens of thousands of points with decimation. Canvas output means accessibility must be added manually.

## Category
Data Visualization

## Subcategories
canvas charts, react-chartjs-2, plugins, decimation, tree-shaking, OffscreenCanvas, Next.js client components

## Problem It Solves
It gives React apps lightweight standard charts, with more data headroom than SVG libraries like Recharts thanks to Canvas rendering and built-in LTTB/min-max decimation. No d3 dependency.

## When To Use
- React/Next.js pages needing a few standard charts with a small bundle.
- Line/scatter with 1k–100k points (with `parsing: false` + decimation).
- Teams already familiar with the Chart.js options model.

## When Not To Use
- Rich built-in accessibility (focusable marks): consider Recharts v3 (`accessibilityLayer`) or build with visx.
- Sankey, treemap, maps, graph without plugins: use ECharts.
- Millions of points or high-frequency streams: uPlot or WebGL (see large-dataset-visualization-performance).
- JSX-composable chart APIs: Recharts.

## Core Principles
1. **Register only what you use** (`ChartJS.register(...)`) once in a client module. `chart.js/auto` is for prototypes.
2. **Let react-chartjs-2 own the lifecycle.** It creates, updates, and destroys the instance. Don't create `new Chart()` manually on the same canvas.
3. **Stable `data`/`options` references.** New objects every render trigger updates. Memoize them.
4. **Canvas is opaque to assistive technology.** Provide `aria-label`, `role="img"`, fallback content, and a table.
5. **The parent sizes the chart.** With `responsive: true`, place the chart in a dedicated relatively positioned container with explicit height, and set `maintainAspectRatio: false`.
6. **Client-only.** Needs `'use client'` in the Next.js App Router.

## Best Practices
- Time axes: register `TimeScale` and import a date adapter (`chartjs-adapter-date-fns`). Pass numeric timestamps.
- Large data (official performance guide):
  - Pre-parsed `{x, y}` with `parsing: false`.
  - `normalized: true` for sorted, unique data.
  - `decimation` plugin (`lttb` or `min-max`), which requires a line chart, a linear/time x-axis, and `parsing: false`.
  - `animation: false`, `pointRadius: 0`, `spanGaps: true`.
  - Fixed `ticks.minRotation`/`maxRotation`, `ticks.sampleSize`, and explicit `min`/`max`.
- `interaction: { mode: 'index', intersect: false }` for time series gives larger hit areas.
- Get the instance with `ref` (`useRef<ChartJS<'line'>>`) to call `setActiveElements`, `toBase64Image`, or `update('none')`.
- Theming: read CSS variables (`getComputedStyle(document.documentElement)`) in a hook and build options from them. Recompute on theme change.
- Plugins: chartjs-plugin-annotation (targets), chartjs-plugin-zoom, chartjs-plugin-datalabels. Register them alongside core components.
- react-chartjs-2 `updateMode="none"` for live data without animation. Use `redraw` only when you truly need to re-create the instance.

## Implementation Guidance
**Config by data size**

| Points per chart | Config |
|---|---|
| < 1k | Defaults fine |
| 1k–10k | `pointRadius: 0`, `animation: false`, memoized data |
| 10k–100k+ | `parsing: false`, `normalized: true`, decimation (LTTB, `samples` ≈ plot px width), fixed tick rotation, explicit min/max |
| Streaming | mutate a windowed array via ref, `chart.update('none')` at ≤ 10–30 fps |

**Registration module (import once)**
```ts
// src/lib/charts/chartjs-setup.ts
'use client';
import {
  Chart as ChartJS, LineElement, PointElement, LinearScale, TimeScale, CategoryScale, BarElement,
  Tooltip, Legend, Filler, Decimation,
} from 'chart.js';
import 'chartjs-adapter-date-fns';

ChartJS.register(LineElement, PointElement, LinearScale, TimeScale, CategoryScale, BarElement, Tooltip, Legend, Filler, Decimation);
export { ChartJS };
```
react-chartjs-2 typed components (`Line`, `Bar`) register their controllers, but elements, scales, and plugins must be registered.

## Recommended Workflow
1. Install `chart.js`, `react-chartjs-2`, and a date adapter if needed.
2. Create the registration module and import it from chart components.
3. Build `data` and `options` with `useMemo` from props and theme tokens.
4. Render inside a sized wrapper with an `aria-label` and fallback content.
5. Add a figure caption (takeaway) and a data table toggle.
6. For live data, use a ref and `update('none')`, throttled.
7. Test: resize, dark mode, unmount/remount (no "Canvas is already in use"), 375px width.

## Patterns
- **Chart card:** `<figure>` → `<figcaption>` → sized div → `<Line>` → `<details><table>`.
- **Theme-aware options hook:** `useChartTheme()` returns colors from CSS variables and listens for theme class changes.
- **External HTML tooltip:** `plugins.tooltip.external` → set React state with `tooltip.dataPoints` and render an accessible tooltip in JSX (no innerHTML).
- **HTML legend with buttons:** `chart.setDatasetVisibility(i, !visible); chart.update()` from `<button aria-pressed>`.
- **Keyboard exploration via table:** focusing a table row calls `chart.setActiveElements([{datasetIndex, index}])` + `chart.tooltip?.setActiveElements(...)`.
- **Export:** `chartRef.current?.toBase64Image()` for PNG download.

## Anti-Patterns
- **Inline `options={{...}}` on every render with large data.** Constant updates. Fix: `useMemo`.
- **Chart in a flex child without a sized, relatively positioned wrapper.** Resize loops or wrong size. Fix: wrapper with height, `maintainAspectRatio: false`.
- **`import 'chart.js/auto'` in production.** Ships everything. Fix: explicit registration.
- **Creating `new Chart()` in `useEffect` without destroy, under StrictMode double-invoke.** "Canvas is already in use." Fix: react-chartjs-2, or destroy in cleanup.
- **Importing chart components into a Server Component.** Build/runtime error. Fix: `'use client'` leaf.
- **Fallback text "Canvas not supported."** Fix: describe the data.
- **Bézier `tension` on dense data.** Slower and can overshoot. Fix: `tension: 0`.

## Accessibility
- react-chartjs-2 passes extra props to `<canvas>`: `aria-label="Signups rose from 1.2K to 3.4K"`, `role="img"`, and `fallbackContent={<p>…</p>}`.
- Provide an HTML table alternative (WCAG 1.1.1). The canvas legend isn't keyboard-operable, so use an HTML legend.
- Colors ≥3:1 against the background. Add `borderDash` or `pointStyle` for series distinction (1.4.1).
- `animation: false` when `prefers-reduced-motion: reduce`.

## Responsive Design
- `responsive: true` + `maintainAspectRatio: false` + CSS height on the wrapper (or `aspect-ratio`). Set `resizeDelay: 100`.
- Scriptable tick limits: `ticks: { maxTicksLimit: 6, autoSkip: true }`, or compute from container width via a `ResizeObserver` hook.
- Cap `devicePixelRatio: Math.min(window.devicePixelRatio, 2)` for large canvases.

## Performance
- Decimation reduces drawn points to about the pixel width. `parsing: false` skips parsing overhead.
- `updateMode="none"` for data refreshes.
- Lazy-mount charts below the fold (IntersectionObserver or `next/dynamic`).
- OffscreenCanvas in a worker is possible but requires manual event forwarding and is outside react-chartjs-2. Use only for very heavy dashboards.

## Security
- External tooltips/legends render via React (escaped). Never `innerHTML` series labels.
- Pin plugin versions (supply chain). Avoid CDN script tags in Next.js; bundle via npm.

## Testing
- Unit-test `buildOptions`/`buildData` pure functions with Vitest.
- jsdom has no canvas: mock with `vitest-canvas-mock` for smoke render tests. Assert `aria-label` and table content.
- Playwright visual snapshots with `animation: false` and a fixed viewport/DPR.
- StrictMode mount/unmount test to catch lifecycle leaks.

## Tooling
- chart.js 4.5.1 (stable; no v5 as of Sept 2026).
- react-chartjs-2 (React wrapper; supports Chart.js v4).
- chartjs-adapter-date-fns, chartjs-plugin-annotation, chartjs-plugin-zoom, chartjs-plugin-datalabels (check v4 compatibility per plugin).
- vitest-canvas-mock for unit tests.

## Framework Notes
- **React (Vite SPA):** import the registration module once (for example, from the chart component). Memoize `data`/`options`, and code-split chart routes with `React.lazy`. StrictMode double effects are handled by react-chartjs-2.
- **Next.js (App Router):**
  - Every file importing `react-chartjs-2`/`chart.js` must be (or be imported by) a `'use client'` component.
  - Fetch and shape data in the Server Component and pass numbers/ISO strings.
  - The canvas has no server HTML, so reserve its height to prevent CLS and render the `<figcaption>` and data table on the server for immediate, crawlable content.
  - Use `dynamic(() => import('./SignupsChart'), { ssr: false, loading: () => <div style={{height:300}} /> })` from a client component to defer the Chart.js bundle for below-the-fold charts.
  - Date adapters that read locale at import are client-only.

## AI Agent Guidance
- DO use react-chartjs-2 with explicit `ChartJS.register`, `'use client'`, a memoized `data`/`options`, and a sized wrapper.
- DO set `parsing: false` + decimation for large series and `updateMode="none"` for live data.
- DO add `aria-label`, `role="img"`, `fallbackContent`, and an HTML table.
- DON'T use `chart.js/auto` in production, or manage `new Chart()` manually alongside react-chartjs-2.
- Before done: no console errors on navigation back and forth, dark mode colors update, 375px layout OK, table alternative present.

## Examples
```tsx
'use client';
import { useMemo, useRef } from 'react';
import { Line } from 'react-chartjs-2';
import type { ChartData, ChartOptions } from 'chart.js';
import { ChartJS } from '@/lib/charts/chartjs-setup';

type Pt = { t: number; v: number };
const compact = new Intl.NumberFormat('en-US', { notation: 'compact' });

export function LatencyChart({ points, summary }: { points: Pt[]; summary: string }) {
  const ref = useRef<ChartJS<'line', { x: number; y: number }[]>>(null);
  const reduced = typeof window !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

  const data = useMemo<ChartData<'line', { x: number; y: number }[]>>(() => ({
    datasets: [{
      label: 'p95 latency (ms)',
      data: points.map(p => ({ x: p.t, y: p.v })),
      borderColor: 'rgb(42,120,214)', borderWidth: 2, pointRadius: 0, tension: 0,
    }],
  }), [points]);

  const options = useMemo<ChartOptions<'line'>>(() => ({
    responsive: true, maintainAspectRatio: false, resizeDelay: 100,
    animation: reduced ? false : undefined,
    parsing: false, normalized: true, spanGaps: true,
    interaction: { mode: 'index', intersect: false },
    scales: {
      x: { type: 'time', ticks: { maxRotation: 0, minRotation: 0, autoSkip: true, maxTicksLimit: 6 } },
      y: { beginAtZero: true, ticks: { callback: v => compact.format(Number(v)) } },
    },
    plugins: { decimation: { enabled: true, algorithm: 'lttb', samples: 600 }, legend: { display: false } },
  }), [reduced]);

  return (
    <figure>
      <figcaption>{summary}</figcaption>
      <div style={{ position: 'relative', height: 300 }}>
        <Line ref={ref} data={data} options={options} updateMode="none"
              role="img" aria-label={summary} fallbackContent={<p>{summary}</p>} />
      </div>
    </figure>
  );
}
```
```tsx
// app/(dash)/latency/page.tsx (Server Component)
import { LatencyChart } from './LatencyChart';
export default async function Page() {
  const points = await getLatencySeries(); // [{ t: epochMs, v: number }]
  return <LatencyChart points={points} summary="p95 latency stayed under 180ms except a 9:40 spike" />;
}
declare function getLatencySeries(): Promise<{ t: number; v: number }[]>;
```

## Related Skills
- [echarts](../echarts/Skill.md): richer chart types on canvas/SVG
- [recharts](../recharts/Skill.md): SVG, JSX-composable alternative
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md)
- [realtime-data-ui](../realtime-data-ui/Skill.md): streaming updates
- [accessible-data-visualization](../accessible-data-visualization/Skill.md)
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md): server/client boundaries

## Sources
- [Chart.js Performance](https://www.chartjs.org/docs/latest/general/performance.html): Official; parsing, decimation, workers
- [Chart.js Accessibility](https://www.chartjs.org/docs/latest/general/accessibility.html): Official; role/aria/fallback content
- [Chart.js releases](https://github.com/chartjs/Chart.js/releases): Official; 4.5.1 current
- [react-chartjs-2](https://react-chartjs-2.js.org/): Open Source; React wrapper API (ref, fallbackContent, updateMode)

## License / Usage Notes
Chart.js and react-chartjs-2 are MIT licensed. Content is summarized. Examples are original. react-chartjs-2 docs were not re-fetched this cycle, so verify prop names against the installed version.

## Quality Tier
A: Official Chart.js performance and a11y docs verified. Wrapper specifics from established API but not re-fetched.

## Status
Active

## Last Verified
2026-09-15
