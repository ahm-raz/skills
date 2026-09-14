# Large Dataset Visualization Performance

## Summary
How to render and interact with large data (10k to hundreds of millions of rows) in the browser without freezing the UI. It covers the SVG vs Canvas vs WebGL/WebGPU decision by mark count, data reduction (aggregation, binning, LTTB/min-max downsampling, level-of-detail), columnar/binary data (typed arrays, Apache Arrow), off-main-thread work (Web Workers, OffscreenCanvas), progressive rendering, efficient hit-testing, and React/Next.js integration.

## Category
Data Visualization

## Subcategories
SVG vs Canvas vs WebGL, downsampling, LTTB, binning, Apache Arrow, typed arrays, Web Workers, OffscreenCanvas, deck.gl, uPlot, hit-testing

## Problem It Solves
Charts that work in demos collapse on production data. 50k SVG circles freeze scrolling, JSON object arrays blow memory, React re-renders every mark on hover, and tooltips do O(n) searches per mousemove. That hurts INP, battery, and trust.

## When To Use
- A chart or map with more than about 5k marks, or series longer than the pixel width.
- Time series from monitoring/IoT/finance, large scatter plots, point maps.
- Dashboards with many charts mounted simultaneously.

## When Not To Use
- Small data (< 1k marks): optimize for clarity and accessibility, not throughput.
- Tabular exploration of large data: list-virtualization / data-grids-ag-grid.

## Core Principles
1. **Pixels bound what's readable.** A 1,000px-wide line can show at most about 1,000 x-positions. Reduce to about 1–2× pixel width before rendering.
2. **Pick the renderer by mark count and interactivity** (table below). Don't fight SVG's DOM cost with memoization tricks.
3. **Aggregate as close to the data as possible:** the database/API first, then a worker, then the main thread.
4. **Columnar, binary data beats arrays of objects:** less memory, no GC churn, and zero-copy transfer to workers and GPU.
5. **Separate layers:** static data layer (redraw rarely), interaction layer (hover/crosshair redraws cheaply), and DOM for axes/labels/tooltips.
6. **Never block input.** Chunk work (progressive rendering) or move it off-thread. Keep main-thread tasks under 50ms (INP).
7. **Hit-test with spatial indexes** (quadtree, Delaunay, KD-bush, GPU picking), not linear scans.

## Best Practices
- **Downsampling:**
  - LTTB (Largest-Triangle-Three-Buckets) preserves visual shape for lines.
  - Min-max per pixel bucket preserves spikes (good for monitoring).
  - Average loses peaks.
- **Binning:** histograms, hexbin, 2D density grids (heatmap) for scatter over about 50k points. Use opacity/additive blending carefully.
- **Level of detail:** re-query or re-aggregate at the zoom range (dataZoom/brush). Serve pyramid aggregates (1m/1h/1d) from the API.
- **Transport:**
  - Apache Arrow IPC (`tableFromIPC`) or raw typed-array buffers instead of JSON for more than 100k rows.
  - Stream Arrow record batches for progressive display.
  - Compress over HTTP (brotli/zstd).
- **Parsing:** in a Web Worker, transfer `ArrayBuffer`s back (`postMessage(msg, [buf])`).
- **Canvas 2D:**
  - Batch into a single path per series/color, and avoid per-point `fillStyle` changes and `save/restore`.
  - Draw rects (`fillRect`) instead of arcs for tiny points.
  - Scale for DPR but cap at 2.
  - OffscreenCanvas in a worker for heavy redraws.
- **WebGL/WebGPU:** deck.gl (9.4: official layers on WebGPU with parity, binary attributes, GPU aggregation), regl, or ECharts-GL. Pass typed arrays as attributes.
- **Library settings:**
  - Chart.js: `parsing:false`, `normalized:true`, decimation plugin.
  - ECharts: `sampling:'lttb'`, `large`, `progressive`, dataZoom.
  - Recharts/nivo/visx SVG: pre-aggregate to under about 2–5k marks, or use nivo canvas variants.
  - uPlot for extremely fast time series (~50KB; per its benchmark, about 166k points cold render in ~34ms, streaming at 60fps with low CPU/RAM).
- **React:**
  - Keep large data out of React state when possible (refs, external stores).
  - Pass stable references, never deep-clone big arrays, and memoize derived data.
  - Hover state in a separate lightweight overlay component.
- **Many charts:** mount only visible charts (IntersectionObserver), share one WebGL context where the library allows (browsers cap active WebGL contexts, typically about 16), and dispose offscreen charts.

## Implementation Guidance
**Renderer by mark count (practitioner thresholds; measure on target devices)**

| Marks on screen | Renderer | Interaction approach | Libraries |
|---|---|---|---|
| < 1k | SVG | per-element events, focusable marks | Recharts, visx, nivo, d3 |
| 1k–5k | SVG (careful) or Canvas | event delegation / nearest-point | Recharts (dots off), ECharts svg |
| 5k–100k | Canvas 2D | quadtree/Delaunay picking, overlay canvas for hover | Chart.js, ECharts canvas, uPlot, nivo canvas, custom |
| 100k–10M | WebGL / WebGPU | GPU picking, aggregation layers | deck.gl, regl, ECharts-GL |
| > 10M | Server-side aggregation/tiles + WebGL | LOD re-query on zoom | deck.gl + vector/raster tiles, Arrow streaming |

**Data format by size**

| Rows | Format |
|---|---|
| < 50k | JSON is fine |
| 50k–1M | JSON columns (`{ts:[], v:[]}`) or typed arrays; parse in worker |
| > 1M | Arrow IPC / binary; stream batches; worker decode |

## Recommended Workflow
1. Measure: record a Performance profile (scripting vs rendering vs painting), heap size, and INP during hover/zoom.
2. Reduce: can the API return aggregates or downsampled series for the viewport and zoom level?
3. Choose the renderer per the table. Switch library if needed.
4. Move parse/aggregate to a worker and use transferable typed arrays.
5. Layer rendering: static data canvas, interaction overlay, DOM axes/tooltip.
6. Add spatial index hit-testing and throttle pointer handling to rAF.
7. Add LOD: re-aggregate on zoom/brush (debounced, abortable fetch).
8. Re-measure on a mid-range Android device with 4× CPU throttling. Set budgets (for example, redraw under 16ms, INP under 200ms).
9. Keep an accessible summary and aggregated table (not 1M-row tables).

## Patterns
- **LTTB in a worker** (see Examples).
- **Min-max envelope per pixel** for monitoring lines: draw the band plus the average line.
- **Two-canvas layering:** `<canvas data>` redraws on data/zoom; `<canvas overlay>` redraws the crosshair on pointer move.
- **Delaunay nearest point** (`d3-delaunay`), built once per data change, O(log n) queries.
- **Progressive draw:** render in chunks of about 10–50k per frame with `requestAnimationFrame` and show a progress hint.
- **Arrow → deck.gl binary attributes:** `data: { length, attributes: { getPosition: { value: Float32Array, size: 2 } } }`.
- **Viewport-driven fetch:** `useDeferredValue`/debounce on zoom range → `fetch('/api/series?from&to&px=1200')`.

## Anti-Patterns
- **50k SVG `<circle>` elements in React.** Seconds to render, janky hover. Fix: Canvas/WebGL or binning.
- **Sending raw 5M-row JSON to the client.** Fix: server aggregation and Arrow/binary streaming.
- **`array.find` over all points on every mousemove.** Fix: spatial index + rAF throttle.
- **Storing big datasets in React state and spreading on update.** Fix: refs/external store, immutable swap only on batch.
- **Averaging downsample for alerting charts.** Hides spikes. Fix: min-max or LTTB.
- **One WebGL context per small multiple (dozens).** Context loss. Fix: shared canvas/views (deck.gl multi-view) or Canvas 2D.
- **Animations on large charts.** Fix: disable.
- **Uncapped devicePixelRatio (3×) on full-screen canvases.** 9× pixels. Fix: cap at 2 or adapt dynamically.
- **Parsing large CSV/JSON on the main thread.** Long tasks. Fix: worker + streaming parser.

## Accessibility
- Don't expose 100k marks to assistive technology. Provide an aggregated summary, key statistics, and a table of aggregated bins with pagination/virtualization.
- Keyboard exploration over aggregated units (bins, clusters, time buckets) rather than raw points.
- Ensure density encodings (opacity, heatmaps) have legends and adequate contrast.
- The progress of progressive rendering is announced politely if it takes more than about 1s.

## Responsive Design
- Downsample targets derive from the actual plot width (`ResizeObserver`) × DPR (capped).
- Lower LOD on mobile (fewer points, coarser bins). Pause heavy layers when offscreen.
- Recompute aggregations on resize debounced (about 150ms), not per frame.

## Performance
- **Budgets:** redraw under 16ms for interaction, initial render of the primary chart under about 1s on a mid-tier device, INP under 200ms on hover/zoom, and a stable heap after repeated zooms.
- Transferables for worker messages. `structuredClone` of big arrays is expensive.
- GPU: minimize attribute re-uploads (`updateTriggers` in deck.gl) and use binary data.
- Use `content-visibility: auto` for offscreen chart cards in long dashboards.
- DuckDB-WASM or Arrow compute in a worker for client-side slicing of large local datasets (verify bundle cost, several MB).

## Security
- Large client-side datasets may contain sensitive rows: aggregate server-side to what the user may see, and enforce row-level security before export.
- Workers loaded from same origin. CSP `worker-src 'self' blob:` as required by libraries.
- Validate binary payload sizes to prevent memory exhaustion from malicious or buggy endpoints.

## Testing
- **Unit:** LTTB/min-max correctness (preserves first/last and extremes), binning totals equal input counts, index queries.
- **Benchmarks:** Vitest bench / tinybench for reduction functions with 1M points.
- **Playwright + CDP performance metrics:** trace hover/zoom interactions, and assert no long tasks above 100ms and JS heap under a budget.
- **Visual:** compare downsampled vs full rendering at the same width (should be pixel-similar for LTTB/min-max).
- **Device lab** or throttled CPU profiles.

## Tooling
- uPlot 1.6.x (fast canvas time series); Chart.js 4.5 decimation; ECharts 6 sampling/large/progressive.
- deck.gl 9.4 (WebGL2/WebGPU, binary attributes, GPU aggregation); regl; ECharts-GL.
- Apache Arrow JS 21.x (`apache-arrow`: `tableFromIPC`, typed columnar vectors).
- d3-delaunay, d3-quadtree, kdbush/flatbush (spatial indexes).
- downsample (LTTB implementations) or hand-rolled; Comlink for worker RPC.
- Chrome DevTools Performance panel, `performance.measureUserAgentSpecificMemory` (cross-origin isolated).

## Framework Notes
- **React (Vite SPA):**
  - Workers via `new Worker(new URL('./lttb.worker.ts', import.meta.url), { type: 'module' })`.
  - Keep large buffers in `useRef` and trigger renders with a version counter.
  - Use `useDeferredValue` for zoom-driven recomputation.
  - Canvas drawing in `useEffect`/`useLayoutEffect` keyed on version.
  - React Compiler won't fix O(n) render costs, so reduce data first.
- **Next.js (App Router):**
  - Aggregate in Server Components or Route Handlers close to the database, and return only viewport/LOD data.
  - Stream Arrow from a Route Handler (`Content-Type: application/vnd.apache.arrow.stream`).
  - Never pass multi-MB arrays as Server Component props: they serialize into the RSC payload and HTML, bloating the page. Fetch large series client-side from a route handler, or pass pre-aggregated small data.
  - Worker `new URL(..., import.meta.url)` works in client components with Turbopack/webpack.
  - WebGL/Canvas components are `'use client'`, optionally with `dynamic(..., { ssr: false })` to keep heavy libs out of the initial bundle.

## AI Agent Guidance
- DO ask for or estimate row counts and choose the renderer via the table.
- DO downsample to about pixel width (LTTB/min-max) and aggregate on the server for big data.
- DO use typed arrays/Arrow, workers with transferables, spatial-index hit-testing, and rAF-throttled pointer handling.
- DON'T render more than about 5k SVG marks, pass huge arrays through RSC props, or keep big data in React state with spreads.
- Before done: profile hover and zoom with 4× CPU throttling (no long tasks above 100ms), check heap after 20 zoom cycles, and verify spikes survive downsampling.

## Examples
```ts
// lib/viz/lttb.ts: Largest-Triangle-Three-Buckets on typed arrays
export function lttb(xs: Float64Array, ys: Float32Array, threshold: number) {
  const n = xs.length;
  if (threshold >= n || threshold < 3) return { xs, ys };
  const outX = new Float64Array(threshold), outY = new Float32Array(threshold);
  const every = (n - 2) / (threshold - 2);
  let a = 0, o = 0;
  outX[o] = xs[0]; outY[o++] = ys[0];
  for (let i = 0; i < threshold - 2; i++) {
    const avgStart = Math.floor((i + 1) * every) + 1, avgEnd = Math.min(Math.floor((i + 2) * every) + 1, n);
    let avgX = 0, avgY = 0;
    for (let j = avgStart; j < avgEnd; j++) { avgX += xs[j]; avgY += ys[j]; }
    const len = avgEnd - avgStart || 1; avgX /= len; avgY /= len;
    const rStart = Math.floor(i * every) + 1, rEnd = Math.floor((i + 1) * every) + 1;
    let maxArea = -1, next = rStart;
    for (let j = rStart; j < rEnd; j++) {
      const area = Math.abs((xs[a] - avgX) * (ys[j] - ys[a]) - (xs[a] - xs[j]) * (avgY - ys[a]));
      if (area > maxArea) { maxArea = area; next = j; }
    }
    outX[o] = xs[next]; outY[o++] = ys[next]; a = next;
  }
  outX[o] = xs[n - 1]; outY[o] = ys[n - 1];
  return { xs: outX, ys: outY };
}
```
```ts
// workers/series.worker.ts: fetch Arrow, downsample, transfer
import { tableFromIPC } from 'apache-arrow';
import { lttb } from '@/lib/viz/lttb';

self.onmessage = async (e: MessageEvent<{ url: string; px: number }>) => {
  const res = await fetch(e.data.url);
  const table = tableFromIPC(new Uint8Array(await res.arrayBuffer()));
  const xs = Float64Array.from(table.getChild('ts')!.toArray() as ArrayLike<number>);
  const ys = Float32Array.from(table.getChild('value')!.toArray() as ArrayLike<number>);
  const out = lttb(xs, ys, Math.max(3, e.data.px * 2));
  (self as unknown as Worker).postMessage(out, [out.xs.buffer, out.ys.buffer]);
};
```
```tsx
// components/BigLine.tsx: canvas line fed by worker
'use client';
import { useEffect, useRef, useState } from 'react';

export function BigLine({ url, label }: { url: string; label: string }) {
  const wrap = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const [data, setData] = useState<{ xs: Float64Array; ys: Float32Array } | null>(null);

  useEffect(() => {
    const w = new Worker(new URL('../workers/series.worker.ts', import.meta.url), { type: 'module' });
    w.onmessage = e => setData(e.data);
    w.postMessage({ url, px: wrap.current?.clientWidth ?? 1000 });
    return () => w.terminate();
  }, [url]);

  useEffect(() => {
    const c = canvas.current, el = wrap.current; if (!c || !el || !data) return;
    const dpr = Math.min(devicePixelRatio, 2), W = el.clientWidth, H = 280;
    c.width = W * dpr; c.height = H * dpr; c.style.width = `${W}px`; c.style.height = `${H}px`;
    const ctx = c.getContext('2d')!; ctx.scale(dpr, dpr); ctx.clearRect(0, 0, W, H);
    const { xs, ys } = data; const n = xs.length;
    let yMin = Infinity, yMax = -Infinity; for (let i = 0; i < n; i++) { if (ys[i] < yMin) yMin = ys[i]; if (ys[i] > yMax) yMax = ys[i]; }
    const sx = (x: number) => ((x - xs[0]) / (xs[n - 1] - xs[0] || 1)) * W;
    const sy = (y: number) => H - ((y - yMin) / (yMax - yMin || 1)) * H;
    ctx.beginPath(); ctx.moveTo(sx(xs[0]), sy(ys[0]));
    for (let i = 1; i < n; i++) ctx.lineTo(sx(xs[i]), sy(ys[i]));
    ctx.lineWidth = 1.5; ctx.strokeStyle = '#2a78d6'; ctx.stroke();
  }, [data]);

  return <div ref={wrap} style={{ height: 280 }}><canvas ref={canvas} role="img" aria-label={label} /></div>;
}
```

## Related Skills
- [realtime-data-ui](../realtime-data-ui/Skill.md): streaming + bounded buffers
- [chartjs](../chartjs/Skill.md), [echarts](../echarts/Skill.md): built-in large data modes
- [maps-and-geospatial-ui](../maps-and-geospatial-ui/Skill.md): deck.gl and tile strategies
- [web-workers-offloading](../web-workers-offloading/Skill.md)
- [inp-optimization](../inp-optimization/Skill.md), [rendering-performance](../rendering-performance/Skill.md)
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md)
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md): when a grid is better than a chart

## Sources
- [uPlot](https://github.com/leeoniya/uPlot): Open Source; benchmark figures and limitations
- [Chart.js performance](https://www.chartjs.org/docs/latest/general/performance.html): Official; decimation, parsing, workers
- [ECharts Canvas vs SVG](https://echarts.apache.org/handbook/en/best-practices/canvas-vs-svg/): Official; renderer thresholds (>1k elements favors canvas)
- [deck.gl what's new](https://deck.gl/docs/whats-new) / [releases](https://github.com/visgl/deck.gl/releases): Official; 9.4 WebGPU parity, binary data
- [Apache Arrow JS](https://arrow.apache.org/docs/js/): Official; tableFromIPC, typed columnar vectors, v21.x
- Sveinn Steinarsson (2013), *Downsampling Time Series for Visual Representation* (LTTB thesis): Research; algorithm

## License / Usage Notes
uPlot (MIT), deck.gl (MIT), Apache Arrow (Apache-2.0), Chart.js (MIT), ECharts (Apache-2.0). Mark-count thresholds are practitioner estimates synthesized from library guidance, so measure on target devices. The LTTB code is an original implementation of the published algorithm.

## Quality Tier
A: Official library performance docs plus established algorithms and working code. Thresholds are indicative, not benchmarks.

## Status
Active

## Last Verified
2026-09-15
