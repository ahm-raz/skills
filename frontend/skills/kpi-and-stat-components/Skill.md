# KPI and Stat Components

## Summary
Design and implementation of stat tiles, KPI rows, hero numbers, deltas, sparklines, bullet charts, and meters: the "not a chart" components that lead most dashboards. It covers anatomy, comparison semantics (good vs bad direction), number formatting, sparkline rules, status encoding, loading and stale states, and accessible markup, built as zero-JS React Server Components where possible. It also covers sparklines, so no separate sparkline skill is needed.

## Category
Data Visualization

## Subcategories
stat tile, KPI row, delta badge, sparkline, bullet chart, meter/progress, hero number, number formatting, Tremor/shadcn stat cards

## Problem It Solves
KPI tiles often show a bare number with no context, color deltas red/green regardless of whether up is good, round inconsistently, jitter with `tabular-nums` misuse, and hide trends behind hover. Screen readers hear "12.4K up arrow 3.2%" without meaning. This skill standardizes KPIs so they are scannable, honest, and accessible.

## When To Use
- Dashboard headers, admin home pages, analytics summaries, and billing/usage pages.
- Any time the data is a single current value (plus trend/target) rather than a distribution.

## When Not To Use
- Comparing many categories: bar chart or table.
- Detailed time-series analysis: full line chart (the sparkline is only a hint).

## Core Principles
1. **A KPI = value + context.** Always show a comparison: prior period delta, target/progress, or benchmark.
2. **Color the delta by meaning, not by sign.** Up is good for revenue and bad for error rate. Use the metric's `goodDirection`, and always include an icon/text, not color alone.
3. **Consistent formatting per metric** (unit, precision, compact notation). Show full precision on hover/focus or in a detail view.
4. **Sparklines show shape, not values.** No axes; consistent time window across tiles. Optionally mark the last point or min/max. They are never the only carrier of meaning.
5. **Bullet charts or meters instead of gauges** for progress to target.
6. **Stable layout:** fixed tile heights. Loading skeletons match the final size, and refetch keeps the previous value (dimmed).
7. **Semantic, readable markup:** label, value, and comparison read in a sensible order by screen readers.

## Best Practices
- **Anatomy:** label (metric + unit) → value (large) → delta line (icon + % + comparison period) → optional sparkline/bullet → footnote (definition, freshness).
- **KPI row:** 3–6 tiles, equal widths, most important first. Don't mix unrelated time windows without labeling each.
- **Numbers:**
  - `Intl.NumberFormat` with `notation: 'compact'` for large values (1.2M), with `maximumFractionDigits` 1.
  - Currency with `style: 'currency'`, percent with `style: 'percent'`.
  - Negative values use a real minus sign (the formatter does this).
- **Delta calculation:**
  - `(current - previous) / |previous|`. When previous is 0 or null, show "New" or "—", not "∞%".
  - Percentage-point change for rates ("+1.2 pp", not "+15%") is less ambiguous for percentages.
- **Neutral zone:** changes within a noise threshold (for example, ±0.5%) are neutral gray "No significant change."
- **Digits:** proportional figures for large standalone hero numbers. `tabular-nums` for values that update live or align in columns (avoids jitter).
- **Sparklines:**
  - 2px stroke; about 80–160px wide × 24–40px tall.
  - Same y-domain logic across comparable tiles, or explicitly independent (note it).
  - Area fill light. Last-point dot. Aligned time windows.
- **Bullet chart:** measure bar (dark) + target tick + 2–3 qualitative background bands (light to dark gray, not traffic lights).
- **Status:** reserved status tokens (good/warning/critical) with icon + label, never reused as series colors.
- **Interaction:** the whole tile can link to a detail page. Use a real `<a>` wrapping content, or a stretched link, and avoid nested interactive elements.
- **Tooltips/definitions:** an info button with a popover explaining how the metric is calculated.

## Implementation Guidance
**Which KPI form**

| Situation | Component |
|---|---|
| Current value vs last period | Stat tile + delta |
| Current value + recent trend | Stat tile + sparkline |
| Progress to target (quota, budget) | Bullet chart or meter bar with target marker |
| Usage vs limit (storage, seats) | Meter (`<meter>` semantics) + "x of y" text |
| Headline number for a page | Hero figure (≥ 48px), same sans typeface |
| Status of a system | Status tile: icon + label + last-checked time |
| Many KPIs across segments | Table with in-cell sparklines, not 20 tiles |

**Delta semantics**
```ts
export type Direction = 'up' | 'down';
export type Tone = 'positive' | 'negative' | 'neutral';

export function deltaInfo(current: number, previous: number | null, good: Direction, noise = 0.005) {
  if (previous === null || previous === 0) return { pct: null, tone: 'neutral' as Tone, dir: null };
  const pct = (current - previous) / Math.abs(previous);
  if (Math.abs(pct) < noise) return { pct, tone: 'neutral' as Tone, dir: null };
  const dir: Direction = pct > 0 ? 'up' : 'down';
  return { pct, dir, tone: (dir === good ? 'positive' : 'negative') as Tone };
}
```

## Recommended Workflow
1. Define metrics in a registry: label, unit, format, `goodDirection`, comparison period, and definition.
2. Fetch the current value, previous value, and a small trend series (about 12–30 points) server-side.
3. Build `StatTile` (Server Component) with a delta and an optional `Sparkline` (pure SVG).
4. Build `KpiRow` with a responsive grid and a skeleton of identical dimensions.
5. Add accessible text for the delta and trend, and ensure status never relies on color.
6. Test edge cases: zero/null previous, negative values, huge numbers, long labels, and missing trend points.
7. Visual regression in light/dark and compact/comfortable densities.

## Patterns
- **Server-rendered StatTile + SVG sparkline:** zero client JS (see Examples).
- **Skeleton-matched tile:** the same component in `loading` mode renders placeholder blocks at identical sizes.
- **Stretched link tile:** `<a className="after:absolute after:inset-0">` inside a `relative` card.
- **Comparison toggle:** a global "vs previous period / vs last year" in the filter bar feeds all tiles.
- **Live KPI:** a client island subscribing to updates, throttled to 1 Hz, `tabular-nums`, and no animated count-up on every tick.
- **Count-up animation:** only on first reveal, disabled under reduced motion, and never for live values.

## Anti-Patterns
- **Bare number without comparison.** Meaningless. Fix: delta or target.
- **Green for any increase.** Error rate up shown green. Fix: `goodDirection` per metric.
- **Color-only deltas.** Fails WCAG 1.4.1. Fix: arrow icon + sign + text.
- **"∞%" or "NaN%" deltas.** Fix: "New" / "—" with an explanation.
- **Percent change on percentages** (3% → 4% shown as +33%) without clarity. Fix: "+1.0 pp".
- **Gauges/donuts for single values.** Low density. Fix: bullet or meter.
- **Sparklines with axes, gridlines, and tooltips crammed in.** Fix: minimal sparkline, detail on click.
- **Tiles changing height when data loads.** CLS. Fix: fixed heights and matched skeletons.
- **Count-up animations replaying on every refetch.** Fix: animate once, or never.
- **Different rounding for the same metric across pages.** Fix: registry formatter.

## Accessibility
- Markup: `<section aria-labelledby>` or a `<dl>` pair (`<dt>` label, `<dd>` value). Keep the DOM order label → value → comparison.
- Delta text for screen readers: a visually-hidden full sentence ("Up 3.2% compared with previous 30 days, which is good"). Decorative arrow icons `aria-hidden`.
- Sparkline: `role="img"` + `aria-label` summarizing the trend ("Trend over 30 days: rising, low 1.1K, high 1.6K"). Or `aria-hidden` if the adjacent text already states it.
- Meter: native `<meter min max value>` or `role="meter"` with `aria-valuenow/min/max` and `aria-valuetext` ("7.2 of 10 GB used").
- Contrast: value text ≥4.5:1. Delta colors must pass contrast for text (status colors often fail as text on light backgrounds, so use darker text steps).
- Live KPIs: no `aria-live` per tick; offer a throttled polite summary if needed.
- Reduced motion: no count-up/pulse animations.

## Responsive Design
- KPI row: `grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr))`. On mobile, 2 columns for short values or 1 column for long labels.
- Use container queries on the tile: hide the sparkline under about 14rem width, keep value + delta.
- Fluid value size (`clamp(1.5rem, 4cqi, 2.5rem)`) that never truncates numbers. Wrap long labels to 2 lines, then ellipsize with a full label in a tooltip/title.

## Performance
- Render tiles as Server Components with inline SVG sparklines: no chart library, no hydration.
- Precompute trend series server-side (downsample to 30 points). Cache per filter key.
- Stream the KPI row with Suspense so it doesn't wait on slow charts below.

## Security
- Metric values can leak sensitive business data: authorize per metric server-side.
- Tooltips/definitions rendered as text, not HTML from a CMS without sanitizing.

## Testing
- **Unit:** `deltaInfo` (zero/null previous, noise band, direction semantics), formatters per locale, sparkline path generation (flat series, single point, negative values).
- **Component (Testing Library):** accessible name of the tile, delta sentence present, sparkline `aria-label`.
- **Visual regression:** tiles with long labels, huge numbers, and dark mode.
- **CLS check:** loading → loaded transition has no layout shift (Playwright + PerformanceObserver layout-shift).

## Tooling
- Tremor (KPI cards, BadgeDelta, SparkChart; Recharts-based); shadcn/ui cards + charts.
- Native `Intl.NumberFormat`, `Intl.RelativeTimeFormat` (for "updated 2 min ago").
- d3-shape (`line`, `area`) for sparkline paths, or hand-rolled path builders (below).
- Lucide icons for delta arrows (`aria-hidden`).

## Framework Notes
- **React (Vite SPA):** the same components work client-side. Format with a fixed locale from app settings. Use TanStack Query with `placeholderData: keepPreviousData` to avoid tile flicker on filter change.
- **Next.js (App Router):**
  - `StatTile` and `Sparkline` are Server Components (no `'use client'`): pure SVG, zero JS.
  - Pass the locale explicitly (from i18n config/headers) to `Intl` so server output is deterministic.
  - Wrap `KpiRow` in `<Suspense fallback={<KpiRowSkeleton/>}>`.
  - Only live-updating or interactive tiles (popover definitions) become client islands.
  - Relative times ("2 min ago") computed on the server go stale in cached pages. Render an absolute timestamp, or a small client component that updates relative time after hydration (use `suppressHydrationWarning` only on that text node if needed).

## AI Agent Guidance
- DO use a metric registry with `goodDirection`, unit, and formatter, and compute deltas with zero/null handling and a neutral band.
- DO render stat tiles and sparklines as Server Components with SVG, and give tiles fixed heights with matched skeletons.
- DO include icon + text for deltas and accessible summaries for sparklines and meters.
- DON'T color by sign alone, use gauges for single values, show ∞%/NaN%, or animate live values.
- Before done: test with previous = 0, negative values, 10-digit values, long labels at 320px width, dark mode contrast, and a screen reader reading order.

## Examples
```tsx
// components/kpi/Sparkline.tsx (Server Component)
export function Sparkline({ values, width = 120, height = 32, label }: {
  values: number[]; width?: number; height?: number; label?: string;
}) {
  if (values.length < 2) return null;
  const min = Math.min(...values), max = Math.max(...values), pad = 2;
  const x = (i: number) => pad + (i / (values.length - 1)) * (width - pad * 2);
  const y = (v: number) => height - pad - ((v - min) / (max - min || 1)) * (height - pad * 2);
  const d = values.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join('');
  const last = values.length - 1;
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}
         role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <path d={`${d}L${x(last)},${height}L${x(0)},${height}Z`} fill="var(--chart-1)" opacity={0.12} />
      <path d={d} fill="none" stroke="var(--chart-1)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={x(last)} cy={y(values[last])} r={2.5} fill="var(--chart-1)" />
    </svg>
  );
}
```
```tsx
// components/kpi/StatTile.tsx (Server Component)
import { ArrowDownRight, ArrowUpRight, Minus } from 'lucide-react';
import { Sparkline } from './Sparkline';
import { deltaInfo, type Direction } from './delta';

export function StatTile({ id, label, value, previous, trend, goodDirection, format, periodLabel, locale = 'en-US' }: {
  id: string; label: string; value: number; previous: number | null; trend?: number[];
  goodDirection: Direction; format: (n: number) => string; periodLabel: string; locale?: string;
}) {
  const { pct, tone, dir } = deltaInfo(value, previous, goodDirection);
  const pctText = pct === null ? 'New' : new Intl.NumberFormat(locale, { style: 'percent', maximumFractionDigits: 1, signDisplay: 'exceptZero' }).format(pct);
  const toneClass = tone === 'positive' ? 'text-emerald-700 dark:text-emerald-400' : tone === 'negative' ? 'text-red-700 dark:text-red-400' : 'text-muted-foreground';
  const Icon = dir === 'up' ? ArrowUpRight : dir === 'down' ? ArrowDownRight : Minus;
  const meaning = tone === 'positive' ? 'favorable' : tone === 'negative' ? 'unfavorable' : 'no significant change';
  const trendLabel = trend && trend.length > 1
    ? `Trend: ${trend.at(-1)! >= trend[0] ? 'rising' : 'falling'}, low ${format(Math.min(...trend))}, high ${format(Math.max(...trend))}`
    : undefined;

  return (
    <section aria-labelledby={`${id}-label`} className="flex h-36 flex-col justify-between rounded-lg border p-4">
      <h3 id={`${id}-label`} className="text-sm font-medium text-muted-foreground">{label}</h3>
      <div className="flex items-end justify-between gap-3">
        <p className="text-3xl font-semibold">{format(value)}</p>
        {trend && <Sparkline values={trend} label={trendLabel} />}
      </div>
      <p className={`flex items-center gap-1 text-sm ${toneClass}`}>
        <Icon className="size-4" aria-hidden />
        <span aria-hidden>{pctText}</span>
        <span className="text-muted-foreground" aria-hidden>vs {periodLabel}</span>
        <span className="sr-only">{pct === null ? `New metric, no ${periodLabel} data` : `${pctText} versus ${periodLabel}, ${meaning}`}</span>
      </p>
    </section>
  );
}
```
```tsx
// Bullet chart (Server Component)
export function Bullet({ value, target, max, bands = [0.6, 0.9], label }: { value: number; target: number; max: number; bands?: number[]; label: string }) {
  const w = 200, h = 16, s = (v: number) => (Math.min(v, max) / max) * w;
  return (
    <svg width={w} height={h} role="img" aria-label={`${label}: ${value} of target ${target}`}>
      <rect width={w} height={h} fill="var(--muted)" />
      {bands.map((b, i) => <rect key={i} width={s(b * max)} height={h} fill="var(--muted-foreground)" opacity={0.12 * (bands.length - i)} />)}
      <rect y={h / 4} width={s(value)} height={h / 2} fill="var(--foreground)" />
      <rect x={s(target) - 1} width={2} height={h} fill="var(--foreground)" />
    </svg>
  );
}
```

## Related Skills
- [dashboard-design](../dashboard-design/Skill.md): where KPI rows fit
- [chart-type-selection](../chart-type-selection/Skill.md): "is it even a chart?"
- [cards](../cards/Skill.md): card container patterns
- [tremor](../tremor/Skill.md): prebuilt KPI components
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md)
- [loading-states](../loading-states/Skill.md), [cls-prevention](../cls-prevention/Skill.md)
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md): shared formatting conventions
- [realtime-data-ui](../realtime-data-ui/Skill.md): live KPIs

## Sources
- Stephen Few, *Information Dashboard Design*: Book; bullet graphs, sparklines, context for KPIs
- Edward Tufte, *Beautiful Evidence*: Book; sparklines as word-sized graphics
- [NN/g: dashboards & preattentive attributes](https://www.nngroup.com/articles/dashboards-preattentive/): Community; avoid gauges
- [MDN: `<meter>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meter): Official; meter semantics (not re-fetched this cycle)
- Claude Code bundled `dataviz` skill (choosing-a-form, anti-patterns: stat tile/hero figure/tabular-nums guidance): Community agent skill

## License / Usage Notes
Concepts are paraphrased from books. Code is original. Tailwind class names assume shadcn-style tokens, so adapt to your design system. Status color steps must be validated for text contrast.

## Quality Tier
A: Canonical sources, careful edge-case semantics, zero-JS server implementation. Tremor API specifics not verified.

## Status
Active

## Last Verified
2026-09-15
