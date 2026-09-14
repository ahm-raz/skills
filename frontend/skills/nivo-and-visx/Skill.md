# nivo and visx

## Summary
Two React visualization stacks built on d3. **nivo** (0.98.0, May 2026, React 19 support) is a high-level, batteries-included set of chart components (`@nivo/bar`, `@nivo/line`, `@nivo/heatmap`, `@nivo/sankey`, ...) with SVG/Canvas/HTML variants, react-spring motion, theming, patterns, and server-side rendering. **visx** (airbnb, v4.0.0 June 2026, React 18/19 peers) is a low-level collection of unopinionated primitives (`@visx/scale`, `@visx/shape`, `@visx/axis`, `@visx/tooltip`, `@visx/responsive`). Use visx to build your own chart library with React owning the DOM.

## Category
Data Visualization

## Subcategories
React charts, d3 primitives, custom chart libraries, canvas variants, react-spring, SSR charts

## Problem It Solves
It picks the right abstraction level in React. nivo gives rich, attractive charts (including sankey, chord, calendar, treemap, network) with minimal code. visx gives d3-level control without imperative DOM code, for teams building a design-system chart kit.

## When To Use
- **nivo:** dashboards needing many chart types quickly, polished defaults, patterns/gradients, and canvas variants for denser data.
- **visx:** a bespoke, brand-consistent chart system; unusual forms; tight bundle control (install only the primitives you use); full control of accessibility markup.

## When Not To Use
- **nivo:** you need deep custom interactions or exact markup control, or you're sensitive to bundle size across many chart packages.
- **visx:** you need finished charts next week without visualization engineering capacity. Use Recharts or nivo.
- **Either:** more than about 10k SVG marks. Use nivo canvas variants, a canvas library, or WebGL.

## Core Principles
1. **nivo: install per chart** (`@nivo/core` + `@nivo/bar`). Use `Responsive*` components inside a sized parent, or fixed-size components when you know dimensions (SSR).
2. **nivo: use the canvas variant** (`ResponsiveBarCanvas`, `ResponsiveLineCanvas`, `HeatMapCanvas`, `ScatterPlotCanvas`) for large data.
3. **visx: you compose everything.** Scales + shapes + axes + your own layout, tooltip, and a11y. It is closer to "d3 in React" than a chart library.
4. **visx v4 requires React 18+.** React 16/17 apps stay on visx v3.
5. **Size explicitly.** visx `ParentSize`/`useParentSize` or nivo Responsive wrappers need a parent with height.
6. **Motion is optional.** Disable nivo `animate` for reduced motion and live data.

## Best Practices
- **nivo theming:** one `theme` object (text color, grid stroke, tooltip container) from design tokens. Pass `colors={{ datum: 'data.color' }}` or a function for stable entity colors instead of the default scheme.
- **nivo a11y:** set `role`, `ariaLabel`, `ariaLabelledBy`, and `ariaDescribedBy` props where supported (bar and several others expose per-bar `barAriaLabel`), and `isFocusable` on bars where available. Otherwise wrap with `<figure>` and a table.
- **nivo:** `legends` can be interactive (toggle series). Add visible labels too.
- **nivo SSR:** fixed-dimension (non-Responsive) SVG components render on the server. `@nivo/static` offers an HTTP API to render charts as images/SVG.
- **visx:** `@visx/responsive` `ParentSize` for width; `@visx/tooltip` `useTooltip` + `TooltipWithBounds` (or `useTooltipInPortal`) for overflow-safe tooltips.
- **visx:** `@visx/voronoi` or `@visx/event` `localPoint` for nearest-point hover.
- **visx:** `@visx/xychart` gives a higher-level API (series, tooltip, theme) if full primitives are too low-level.
- **Both:** memoize data transforms and scales, and keep hover state local to a tooltip layer.

## Implementation Guidance
**Choosing between them (and neighbors)**

| Need | nivo | visx | Recharts | ECharts |
|---|---|---|---|---|
| Time to first chart | fast | slow | fast | medium |
| Custom forms | limited | excellent | limited | good (custom series) |
| Exotic types (sankey, chord, calendar) | built-in | build it | partial | built-in |
| Canvas for big data | per-chart canvas variants | DIY | no | yes |
| Bundle control | per chart pkg | per primitive | single pkg | on-demand imports |
| Accessibility markup control | props-limited | full | accessibilityLayer | aria module |

**Data size guidance**

| Marks | nivo | visx |
|---|---|---|
| < 2k | SVG components | SVG |
| 2k–50k | Canvas variants | Render marks to `<canvas>` via ref, keep axes SVG |
| > 50k | aggregate, or move to WebGL | WebGL (deck.gl/regl) with visx scales |

## Recommended Workflow
1. Decide the abstraction: nivo (finished charts) or visx (design-system kit).
2. Install only the needed packages and check React peer ranges (nivo ≥0.98 / visx ≥4 for React 19).
3. Create a theme/tokens module shared by all charts.
4. Build a `ChartFrame` wrapper: figure, title, description, table toggle, fixed height.
5. Implement the chart, tooltip, and legend with stable colors.
6. Add keyboard access (focusable marks or a table/list alternative).
7. Test at narrow widths, with reduced motion, and in SSR (no window access during render).

## Patterns
- **nivo Responsive + fixed height parent:** `<div style={{height: 320}}><ResponsiveLine .../></div>`.
- **visx composition:** `ParentSize` → `scaleBand`/`scaleLinear` → `<Group>` → `<Bar>` → `<AxisBottom>` → `TooltipWithBounds`.
- **Shared chart kit:** wrap visx primitives into `<BarChart data x y />` components for app teams.
- **Canvas marks + SVG axes (visx):** a stacked `<canvas>` and `<svg>` in a relative container, sharing scales.
- **nivo patterns for CVD:** `defs={[patternLinesDef('lines', {...})]}` + `fill` rules to add texture to key series.

## Anti-Patterns
- **nivo Responsive component in a parent with `height: auto`.** Renders 0 height. Fix: explicit height.
- **Installing every @nivo package "just in case."** Bundle bloat. Fix: per-chart installs and lazy routes.
- **visx without a tooltip portal inside `overflow:hidden` cards.** Clipped tooltips. Fix: `useTooltipInPortal` / `TooltipWithBounds`.
- **Animating live-updating nivo charts.** Constant spring work. Fix: `animate={false}`.
- **Treating visx as a chart library and expecting a11y/legend defaults.** Fix: budget for building them.
- **Forcing `--legacy-peer-deps` for React 19.** Hides real incompatibilities. Fix: upgrade to nivo ≥0.98 / visx 4.

## Accessibility
- nivo: use the available `role`/`aria*` props and focusable bars. Canvas variants are not accessible, so pair them with tables.
- visx: add `role="img"` + `aria-labelledby` on `<svg>` for static charts, or focusable `<g tabIndex={0} aria-label>` marks with arrow-key navigation.
- Tooltips must also appear on focus, not hover only (WCAG 1.4.13: dismissible, hoverable, persistent).
- Provide a data table and a text summary. Don't encode by color alone (use nivo patterns, visx `@visx/pattern`).

## Responsive Design
- nivo `Responsive*` wrappers or visx `ParentSize` / `useParentSize` (debounced).
- Derive tick counts from width, and flip bar layout (`layout="horizontal"` in nivo) on narrow screens.
- Move legends below the chart on mobile. Reduce margins, which nivo requires to be explicit.

## Performance
- SVG + react-spring animation cost grows with mark count. Disable animation and use canvas variants beyond a few thousand marks.
- visx primitives are thin: performance is what you render. Memoize scales and avoid re-rendering all marks on hover (render the hover layer separately).
- Lazy-load chart packages per route.

## Security
Both render React text nodes by default. Custom tooltip components must not use `dangerouslySetInnerHTML` with data. The `@nivo/static` HTTP API, if self-hosted, must validate input and rate-limit (it renders server-side).

## Testing
- Render fixed-size (non-responsive) components in unit tests. Responsive wrappers measure 0 in jsdom.
- Assert aria labels and mark counts. Snapshot SVG for visx primitives.
- Playwright visual tests with `animate={false}`.

## Tooling
- nivo 0.98.0 (React 19 via react-spring upgrade); pre-1.0 versioning, so minor versions may break.
- visx 4.0.0 (React 18/19); `@visx/xychart` for a higher-level API.
- Storybook for chart kit development.

## Framework Notes
- **React (Vite SPA):** install per-chart nivo packages or per-primitive visx packages, and lazy-load chart routes. React 19 needs nivo ≥0.98 / visx ≥4.
- **Next.js (App Router):**
  - Interactive charts (tooltips, `Responsive*`, `ParentSize`, react-spring motion) need `'use client'`.
  - nivo *fixed-size* SVG components (`<Bar width height>`) and visx scale/shape math can render in Server Components for static, zero-JS charts in reports.
  - `ResponsiveX` / `ParentSize` render nothing until measured, so reserve height with CSS to avoid CLS.
  - `dynamic(() => import('./HeavySankey'), { ssr: false })` (from a client component) is reasonable for rarely-viewed, heavy nivo charts to keep them out of the initial bundle.
  - Check that `transpilePackages` isn't needed. Both ship ESM, and current releases work with Turbopack.

## AI Agent Guidance
- DO check React version compatibility (nivo ≥0.98, visx ≥4 for React 19).
- DO give Responsive wrappers a sized parent, and disable animation for live data.
- DO use nivo canvas variants or aggregation for big data.
- DON'T pick visx when the task is "add a standard chart fast," or nivo when bespoke interaction and markup control are required.
- Before done: check the tooltip isn't clipped, keyboard/focus alternative, dark theme, 375px width, and a clean SSR build.

## Examples
```tsx
'use client';
import { ResponsiveBar } from '@nivo/bar';

type Row = { region: string; revenue: number };
export function RegionBar({ data }: { data: Row[] }) {
  return (
    <figure aria-labelledby="rb-title" style={{ margin: 0 }}>
      <figcaption id="rb-title">EMEA leads revenue in Q3</figcaption>
      <div style={{ height: 320 }}>
        <ResponsiveBar
          data={data}
          keys={['revenue']}
          indexBy="region"
          layout="horizontal"
          margin={{ top: 8, right: 24, bottom: 32, left: 96 }}
          colors={['var(--chart-1)']}
          enableGridY={false}
          animate={false}
          role="img"
          ariaLabel="Revenue by region"
          barAriaLabel={d => `${d.indexValue}: ${d.formattedValue}`}
          valueFormat=">-.3~s"
          theme={{ text: { fill: 'var(--foreground)' }, grid: { line: { stroke: 'var(--chart-grid)' } } }}
        />
      </div>
    </figure>
  );
}
```
```tsx
'use client';
import { ParentSize } from '@visx/responsive';
import { scaleBand, scaleLinear } from '@visx/scale';
import { Bar } from '@visx/shape';
import { AxisBottom } from '@visx/axis';
import { Group } from '@visx/group';

type Row = { label: string; value: number };
function Bars({ data, width, height }: { data: Row[]; width: number; height: number }) {
  const m = { t: 8, b: 28, l: 8, r: 8 };
  const x = scaleBand({ domain: data.map(d => d.label), range: [m.l, width - m.r], padding: 0.2 });
  const y = scaleLinear({ domain: [0, Math.max(...data.map(d => d.value))], range: [height - m.b, m.t], nice: true });
  return (
    <svg width={width} height={height} role="group" aria-label="Values by label">
      <Group>
        {data.map(d => (
          <Bar key={d.label} x={x(d.label)} y={y(d.value)} width={x.bandwidth()} height={y(0) - y(d.value)}
               fill="var(--chart-1)" tabIndex={0} role="img" aria-label={`${d.label}: ${d.value}`} />
        ))}
      </Group>
      <AxisBottom top={height - m.b} scale={x} />
    </svg>
  );
}
export const VisxBars = ({ data }: { data: Row[] }) => (
  <div style={{ height: 280 }}><ParentSize>{({ width, height }) => <Bars data={data} width={width} height={height} />}</ParentSize></div>
);
```

## Related Skills
- [d3-fundamentals](../d3-fundamentals/Skill.md): the primitives underneath
- [recharts](../recharts/Skill.md): mid-level React alternative
- [design-system-architecture](../design-system-architecture/Skill.md): building a chart kit on visx
- [accessible-data-visualization](../accessible-data-visualization/Skill.md)
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md)

## Sources
- [nivo releases](https://github.com/plouc/nivo/releases): Official; 0.98.0 React 19 support
- [nivo repository](https://github.com/plouc/nivo): Official; packages, SVG/canvas/HTML variants, @nivo/static
- [visx releases](https://github.com/airbnb/visx/releases) and [MIGRATION.md](https://github.com/airbnb/visx/blob/master/MIGRATION.md): Official; v4 React peer ranges
- [nivo React 19 issue #2618](https://github.com/plouc/nivo/issues/2618): Official issue tracker; compatibility notes

## License / Usage Notes
nivo and visx are MIT licensed. Content is summarized. Code is original. Exact nivo aria prop availability differs per chart package, so verify on nivo.rocks per component.

## Quality Tier
B: Versions and compatibility verified. Per-component nivo a11y props and visx v4 API details not individually verified.

## Status
Active

## Last Verified
2026-09-15
