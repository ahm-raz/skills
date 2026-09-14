# D3 Fundamentals

## Summary
D3 (v7, latest 7.9.0) is a modular toolkit for bespoke data-driven graphics: scales, shapes, axes, layouts (hierarchy, force, geo), array utilities, formatting, and DOM data joins. This skill covers **D3 inside React and Next.js**: D3 does the math (scales, shapes, layouts), React renders SVG/Canvas as JSX. D3's selection modules are used only through refs for what React doesn't own (axes, zoom, brush, drag). For standard charts, prefer Recharts, nivo, or visx.

## Category
Data Visualization

## Subcategories
d3-scale, d3-shape, d3-array, d3-hierarchy, d3-force, d3-geo, d3-zoom, d3-brush, data join, Observable Plot

## Problem It Solves
Chart libraries cap out when you need custom forms (beeswarm, sankey variant, radial timeline, custom interaction), exact control of encodings, or the primitives underneath other libraries (visx, nivo, and Recharts all use d3 modules). D3 gives those primitives, but it is easy to misuse by fighting React's DOM ownership.

## When To Use
- Custom or novel visual forms, editorial graphics, and data-journalism pieces.
- Building an internal chart component library on top of d3-scale/d3-shape.
- Layout algorithms: treemap, pack, partition, force simulation, geo projections, contours, Delaunay/Voronoi hit-testing.
- Zoom/brush interactions on custom SVG or Canvas.

## When Not To Use
- Standard bar/line/pie dashboards on a deadline: use Recharts, ECharts, Chart.js, or Observable Plot.
- Teams without visualization expertise who need built-in accessibility and tooltips.
- More than about 10k animated SVG nodes: use Canvas/WebGL (still with d3 scales).

## Core Principles
1. **Import only the modules you need** (`d3-scale`, `d3-shape`, `d3-array`), not the whole `d3` bundle, when shipping to production.
2. **React owns the DOM.** Compute paths and positions with D3 in `useMemo` and render with JSX. Use `d3-selection` inside a `useRef` + `useEffect` only for axes, zoom, brush, and drag, and never append nodes React also renders.
3. **Scales map domain to range.** Every visual channel is a scale: `scaleLinear`, `scaleTime`, `scaleBand`, `scaleOrdinal`, `scaleSqrt` (for area), `scaleSequential`/`scaleDiverging` with d3-scale-chromatic.
4. **Margin convention:** an inner plot area = width − margins, with axes in the margins.
5. **Data join** (`selection.join(enter, update, exit)`) is the vanilla-D3 update model. Key by a stable id.
6. **D3 v7 is ESM-only** (since v7.0). Use native ESM imports. Array utilities accept iterables (`d3.group`, `d3.rollup`, `d3.bin`).
7. **Events receive `(event, d)`** (since v6). Use `d3.pointer(event, node)` instead of the old `d3.mouse`.

## Best Practices
- Use `.nice()` on linear scales and `scaleBand().padding(0.2)` for bars.
- Time data: parse once (`d3.utcParse`) and use `scaleUtc` for server data to avoid DST artifacts.
- Use `d3.rollup`/`d3.group`/`d3.bin` to aggregate in JS before rendering.
- Memoize scales and generators on `[data, width, height]`.
- Measure containers with `ResizeObserver`. Never hardcode the width.
- Hit-testing dense marks: use `d3-delaunay` (`Delaunay.from(points).find(x, y)`) for nearest-point tooltips.
- Transitions: respect `prefers-reduced-motion` and skip `transition()` when it is set.
- Tick formatting: `axis.ticks(width / 80)` and `d3.format('~s')` or `Intl.NumberFormat`.

## Implementation Guidance
**Rendering choice with D3**

| Marks | Renderer | Notes |
|---|---|---|
| < ~1–5k | SVG via framework | Accessible, stylable, easy events |
| 5k–100k | Canvas 2D (draw loop with D3 scales) | Use Delaunay for picking; keep axes in SVG overlay |
| > 100k | WebGL (regl, deck.gl) | D3 for scales/layout only |

**Module map**

| Need | Module |
|---|---|
| Scales / color scales | d3-scale, d3-scale-chromatic |
| Line/area/arc/stack/pie paths | d3-shape |
| Axes | d3-axis (needs selection) |
| Aggregation, bins, extent | d3-array |
| Trees, treemap, pack | d3-hierarchy |
| Force networks | d3-force |
| Maps / projections | d3-geo (+ topojson-client) |
| Zoom / brush / drag | d3-zoom, d3-brush, d3-drag |
| Nearest point / Voronoi | d3-delaunay |
| Formats | d3-format, d3-time-format |

## Recommended Workflow
1. Shape the data (typed rows, parsed dates, aggregated).
2. Measure the container (`ResizeObserver`) to get width/height.
3. Build scales from the data extent and inner dimensions.
4. Generate paths/positions with d3-shape and layouts.
5. Render marks declaratively. Mount axes/zoom via refs.
6. Add interaction (pointer + Delaunay), a tooltip, and a keyboard alternative.
7. Add a text summary and table; test resize and reduced motion.
8. Tree-shake: verify the bundle includes only the used modules.

## Patterns
- **Declarative React + D3 math** (see Examples).
- **Axis via ref:** `useEffect(() => { select(ref.current).call(axisBottom(x).ticks(w/80)); }, [x, w])`.
- **Canvas draw loop:** clear, loop data with scales, `ctx.fill`; redraw in `requestAnimationFrame` on data/zoom change.
- **Zoom with rescale:** `zoom().on('zoom', e => setX(() => e.transform.rescaleX(xBase)))`.
- **Force layout off main thread:** run `forceSimulation` for N ticks in a Web Worker, then post positions.
- **Observable Plot for quick charts:** `Plot.plot({ marks: [Plot.lineY(data, {x: 'date', y: 'value'})] })` returns an SVG element.

## Anti-Patterns
- **`d3.select('body').append('svg')` inside a React component.** It duplicates on re-render and fights reconciliation. Fix: render `<svg>` in JSX, compute with D3.
- **Importing all of `d3`** in a client bundle for one scale (~280KB unminified). Fix: per-module imports.
- **Using `d3.event`/`d3.mouse`** (v5 API). Removed. Fix: `(event, d)` and `d3.pointer`.
- **Linear radius for bubble area.** Overstates values. Fix: `scaleSqrt`.
- **Unkeyed data joins.** Elements animate to the wrong datum. Fix: `.data(rows, d => d.id)`.
- **Running a force simulation on every render.** Fix: memoize, stop the simulation, or use a worker.
- **Local time scale for UTC data.** Shifted days around DST. Fix: `scaleUtc` / `utcParse`.

## Accessibility
- SVG root: `role="img"` + `aria-labelledby` (title + desc) for static charts, or `role="group"` with focusable marks for explorable ones.
- Marks that are interactive: `tabindex="0"`, `role="graphics-symbol"` or `role="img"`, `aria-label="March: 1,240 orders"`; arrow-key roving focus.
- Always provide an HTML table alternative; D3 won't do it for you.
- See [accessible-data-visualization](../accessible-data-visualization/Skill.md).

## Responsive Design
- Width from `ResizeObserver`, height from the aspect ratio or a container query. Recompute scales, not CSS scaling. `viewBox` scaling shrinks text too.
- `ticks(Math.max(2, Math.floor(width / 80)))`. Switch orientation below about 480px.
- SSR: D3 math runs on the server fine (no DOM needed for scale/shape). Render at a default width and correct after hydration without layout shift (reserve height).

## Performance
- SVG DOM nodes are the bottleneck: keep interactive SVG under about 5k elements.
- Canvas redraws of 100k points take a few ms with plain `fillRect`. Batch paths and avoid per-point `save/restore`.
- Debounce resize, and throttle pointer move to `requestAnimationFrame`.
- Delaunay `find` is O(log n)-ish per query: build once per data change.

## Security
- Never `.html(userString)`. Use `.text()`.
- Loading TopoJSON/CSV from third parties: validate shape, and restrict origins via CSP `connect-src`.

## Testing
- Unit-test scale domains, tick generation, and path strings with Vitest (d3-shape is pure).
- Component tests: render with fixed width and assert mark count and aria labels.
- Visual regression for layout (Playwright screenshots).
- Canvas: test the data-to-draw-command layer, not pixels.

## Tooling
- d3 7.9.0 (stable since Mar 2024; no v8 announced as of Sept 2026). Modules are individually versioned.
- Observable Plot 0.6.17: concise grammar-of-graphics built on D3, returns SVG, good for SSR-friendly static charts.
- @types/d3-* for TypeScript.
- visx: React wrappers around d3 primitives (see nivo-and-visx).
- topojson-client, d3-geo-projection for maps.

## Framework Notes
- **React (Vite SPA):** math in `useMemo` (scales, generators, layouts), marks rendered as JSX. `d3-selection` only inside `useEffect` on a `useRef` node for axes, zoom, brush, and drag, and clean up listeners (`selection.on('.zoom', null)`) on unmount. Store zoom transforms in state and derive rescaled scales rather than mutating the DOM. With React Compiler, keep D3 objects created inside memo/effects rather than mutated across renders.
- **Next.js (App Router):** d3-scale/d3-shape/d3-array/d3-hierarchy/d3-geo are DOM-free. Use them in **Server Components** to emit static, zero-JS SVG (sparklines, report charts, maps). Anything using `d3-selection`, `d3-zoom`, `d3-brush`, `ResizeObserver`, or pointer events must be in a `'use client'` component. Render the server SVG at a default width with `viewBox` + reserved height, then let a client wrapper measure and re-render to avoid CLS. Avoid `dynamic(..., { ssr: false })` for D3 math; it's only needed for code touching `window` at import time.

## AI Agent Guidance
- DO import specific d3 modules and use them for math; render with the framework.
- DO use `scaleUtc`, `scaleSqrt` for area, keyed joins, and a `ResizeObserver`.
- DO consider Observable Plot or a chart library first for standard charts.
- DON'T use removed v5 APIs (`d3.event`, `d3.mouse`) or `innerHTML` with data.
- Before done: resize the window, check the bundle for unused d3 modules, keyboard-tab through marks, and verify a table alternative exists.

## Examples
```tsx
import { useMemo, useRef, useEffect, useState } from 'react';
import { scaleUtc, scaleLinear } from 'd3-scale';
import { line } from 'd3-shape';
import { extent, max } from 'd3-array';
import { select } from 'd3-selection';
import { axisBottom, axisLeft } from 'd3-axis';

type Row = { date: Date; value: number };
const M = { t: 16, r: 16, b: 28, l: 44 };

export function LineChart({ data, height = 240, label }: { data: Row[]; height?: number; label: string }) {
  const wrap = useRef<HTMLDivElement>(null);
  const gx = useRef<SVGGElement>(null);
  const gy = useRef<SVGGElement>(null);
  const [width, setWidth] = useState(600);

  useEffect(() => {
    const ro = new ResizeObserver(([e]) => setWidth(e.contentRect.width));
    if (wrap.current) ro.observe(wrap.current);
    return () => ro.disconnect();
  }, []);

  const { x, y, d } = useMemo(() => {
    const x = scaleUtc().domain(extent(data, r => r.date) as [Date, Date]).range([M.l, width - M.r]);
    const y = scaleLinear().domain([0, max(data, r => r.value) ?? 0]).nice().range([height - M.b, M.t]);
    const d = line<Row>().x(r => x(r.date)).y(r => y(r.value))(data) ?? '';
    return { x, y, d };
  }, [data, width, height]);

  useEffect(() => { if (gx.current) select(gx.current).call(axisBottom(x).ticks(width / 80)); }, [x, width]);
  useEffect(() => { if (gy.current) select(gy.current).call(axisLeft(y).ticks(5)); }, [y]);

  return (
    <div ref={wrap} style={{ height }}>
      <svg width={width} height={height} role="img" aria-label={label}>
        <g ref={gx} transform={`translate(0,${height - M.b})`} aria-hidden="true" />
        <g ref={gy} transform={`translate(${M.l},0)`} aria-hidden="true" />
        <path d={d} fill="none" stroke="currentColor" strokeWidth={2} />
      </svg>
    </div>
  );
}
```
```ts
// Nearest-point hover with d3-delaunay
import { Delaunay } from 'd3-delaunay';
const delaunay = Delaunay.from(points, p => x(p.date), p => y(p.value));
const onMove = (e: PointerEvent) => { const i = delaunay.find(e.offsetX, e.offsetY); setActive(points[i]); };
```

## Related Skills
- [nivo-and-visx](../nivo-and-visx/Skill.md): React abstractions over d3
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md): Canvas/WebGL with d3 scales
- [maps-and-geospatial-ui](../maps-and-geospatial-ui/Skill.md): d3-geo vs tile maps
- [accessible-data-visualization](../accessible-data-visualization/Skill.md): making custom SVG accessible
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md): ref patterns for axes/zoom
- [data-visualization-principles](../data-visualization-principles/Skill.md)

## Sources
- [D3 Getting Started](https://d3js.org/getting-started): Official; install, ESM, React integration guidance
- [d3 releases](https://github.com/d3/d3/releases): Official; v7.9.0 current
- [Observable Plot releases](https://github.com/observablehq/plot/releases): Official; 0.6.17 features (Arrow support, difference mark)
- [d3-delaunay](https://d3js.org/d3-delaunay): Official; nearest-point picking

## License / Usage Notes
D3 and Observable Plot are ISC licensed. Examples are original. Documentation is summarized, not copied.

## Quality Tier
A: Official docs verified; version and integration guidance current. Canvas/WebGL thresholds are practitioner estimates.

## Status
Active

## Last Verified
2026-09-15
