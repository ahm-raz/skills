# Data Visualization Principles

## Summary
The perceptual and editorial rules that make a chart truthful and fast to read: pick the encoding people decode most accurately, strip non-data ink, assign color by the job it does, and label so the takeaway is obvious. Draws on Tufte (data-ink, lie factor, small multiples), Stephen Few, Cole Nussbaumer Knaflic (storytelling with data), Datawrapper Academy, and the FT Visual Vocabulary. Library-agnostic; every other W14 skill builds on it.

## Category
Data Visualization

## Subcategories
visual encoding, perception, color for data, annotation, chart integrity, storytelling

## Problem It Solves
Engineers often ship charts that are technically correct but misleading or slow to read: truncated bar axes, dual y-axes that suggest correlations that aren't there, rainbow palettes, 3D pies, legends far from their marks, and eight hues when the story is one number. This skill gives decision rules you can check.

## When To Use
- Before building any chart, dashboard tile, report graphic, or embedded analytics.
- When reviewing a chart PR or AI-generated chart for honesty and readability.
- When defining chart tokens (palette, gridlines, typography) for a design system.

## When Not To Use
- Picking a specific chart type: see chart-type-selection (this skill covers the rules underneath).
- Exploratory scratch plots in a notebook that nobody else will see. Rigor still helps, but polish does not.
- Scientific or specialist plots (for example, Q-Q plots or spectrograms) whose field conventions override general guidance.

## Core Principles
1. **Encode the most important comparison with position or length.** Accuracy ranking (Cleveland & McGill): position on a common scale > position on non-aligned scales > length > angle/slope > area > volume/color saturation/hue. NN/g reinforces that length and 2D position are preattentive and precise.
2. **Bars start at zero. Lines need not.** Bar length *is* the value. A line encodes change, so a tight domain is fine if the axis is labeled.
3. **Maximize data-ink and remove chartjunk** (Tufte). Keep gridlines as recessive hairlines, and drop borders, 3D, gradients, and shadows.
4. **Keep the lie factor near 1.** The size of the effect in the graphic should match the size of the effect in the data. Never scale icons or bubbles by radius when area encodes the value.
5. **Color does one job per chart:** categorical (identity), sequential (magnitude), diverging (polarity around a meaningful midpoint), or status (state). Never mix jobs in one chart.
6. **One chart, one message.** Put the takeaway in the title ("Churn fell 18% after onboarding redesign"), not a label ("Churn by month").
7. **Label directly; put legends last.** Label line ends or bar ends when there are 4 or fewer series, and keep a legend for 2 or more series.
8. **Compare like with like.** Use shared scales across small multiples, consistent units, and consistent time grain.
9. **Show uncertainty and context** when it matters: confidence bands, targets, prior period, n.
10. **Accessibility is a principle, not a feature.** Never rely on color alone, provide a text or table equivalent, and keep 3:1 contrast for marks.

## Best Practices
- **Titles state the finding.** Subtitles give unit, scope, and time range. A source/notes line sits at the bottom.
- **Number formatting:** use `Intl.NumberFormat` with `notation: 'compact'` for axes (1.2K, 3.4M) and full precision in tooltips and tables. Put units in the axis title, not on every tick.
- **Ticks:** aim for 3–7 "nice" ticks. Horizontal tick labels only; if they collide, switch to a horizontal bar chart instead of rotating 45 degrees.
- **Sorting:** sort nominal bars by value unless the categories have a natural order (months, stages, Likert).
- **Emphasis pattern:** draw the focus series in the accent color and all others in neutral gray. This is often the right fix for "make it clearer" (Knaflic).
- **Color rules:**
  - Categorical palettes use a fixed hue order, and color follows the entity. Filtering must not repaint the remaining series.
  - Beyond about 7 categories, fold the rest into "Other" or use small multiples.
  - Sequential scales use one hue from light to dark, or a perceptually uniform ramp (viridis, cividis).
  - Diverging scales use two opposite hues (for example blue/orange) with a neutral gray midpoint at a meaningful zero.
  - No rainbow (jet) palettes: they create false boundaries and fail for color-vision deficiency (CVD).
- **CVD safety (Datawrapper):** blue is the safest hue. Avoid red/green and green/orange pairs at similar lightness. Check that the chart works in grayscale, and add direct labels, shapes, or dash patterns.
- **Dark mode:** choose separate steps from the same ramps and re-validate contrast against the dark surface. Do not auto-invert.
- **Annotations:** mark events, targets, and thresholds with short text on the chart rather than in a footnote.
- **Aspect ratio:** "bank to 45°" for line charts. Avoid very tall, narrow line charts that exaggerate slope.
- **Don't** use dual y-axes. Use two aligned charts, or index both series to 100 at t0.

## Implementation Guidance
**Encoding decision table**

| Data question | Preferred encoding | Avoid |
|---|---|---|
| Exact comparison of values | aligned position (dot plot, bar) | area, angle |
| Trend over continuous time | line (x=time) | bars for >~20 periods |
| Share of a whole (≤5 parts) | stacked bar, 100% bar; pie only if 2–5 slices and rough share is enough | 3D pie, donut with 10 slices |
| Relationship of 2 measures | scatter (+ trend line) | dual axis |
| Distribution | histogram, box/violin, beeswarm | mean-only bar |
| Deviation from baseline | diverging bar, line vs reference | stacked around zero without labels |

**Chart tokens (define once)**
```ts
export const chartTokens = {
  categorical: ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#4a3aa7', '#e34948'], // validate per brand
  neutral: '#9aa0a6',           // de-emphasis series
  grid: 'rgba(0,0,0,0.08)',      // hairline, solid
  axisText: '#5f6368',
  strokeWidth: 2,               // lines
  markerMin: 8,                 // px
  font: { family: 'system-ui, sans-serif', tickSize: 12, titleSize: 16 },
} as const;

export const fmtAxis = new Intl.NumberFormat(undefined, { notation: 'compact', maximumFractionDigits: 1 });
export const fmtExact = new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 });
```

**Stable color by entity (not by index)**
```ts
export function colorScale(entities: string[], palette = chartTokens.categorical) {
  const map = new Map<string, string>();
  [...entities].sort().forEach((e, i) => map.set(e, i < palette.length ? palette[i] : chartTokens.neutral));
  return (entity: string) => map.get(entity) ?? chartTokens.neutral;
}
```
Compute the map from the *full* entity universe once, not from the filtered view.

## Recommended Workflow
1. Write the question the chart answers and its one-sentence takeaway.
2. Identify the data types: nominal, ordinal, quantitative, temporal, geographic.
3. Choose the form (chart-type-selection) using the encoding ranking.
4. Set scales: zero baseline for bars, nice domains, and a shared scale for multiples.
5. Assign color by job, then validate CVD contrast (≥3:1 marks) in light and dark.
6. Add titles, a finding-first headline, direct labels, annotations, and source.
7. Add a text alternative and data table (accessible-data-visualization).
8. Render it at mobile and desktop widths and look at the result. Check for label collisions and overflow.
9. Run the anti-pattern checklist below.

## Patterns
- **Small multiples:** use the same chart per facet with shared axes. They beat spaghetti lines with more than 5 series.
- **Emphasis + context:** the focus series is colored, the rest are gray and thinner.
- **Reference lines/bands:** add a target line, prior-period ghost series, or confidence band.
- **Index to base:** `value / value[t0] * 100` to compare series of different magnitudes on one axis.
- **Slopegraph / dumbbell:** before and after per item.
- **Headline + chart + note** layout: title (finding), subtitle (units, period), plot, then source and notes.

## Anti-Patterns
- **Truncated bar axis.** It exaggerates differences. Fix: start at 0, or switch to a dot plot.
- **Dual y-axis.** The scale alignment is arbitrary and implies correlation. Fix: two charts or an indexed series.
- **3D and perspective effects.** They distort length and angle. Fix: flat 2D.
- **Rainbow sequential scales.** They create false boundaries and fail for CVD. Fix: one-hue or viridis-family ramp.
- **Pie with more than 5 slices or close values.** Angles are hard to compare. Fix: sorted bar.
- **Legend-only identification for many lines.** It forces eye travel. Fix: direct labels or small multiples.
- **Values printed on every point.** Clutter. Fix: label extremes and the endpoint, and use tooltip plus table for the rest.
- **Color by rank.** Filtering changes the colors. Fix: stable entity-to-color map.
- **Area/bubble sized by radius.** Squares the visual effect. Fix: scale radius with `sqrt` (`d3.scaleSqrt`).
- **Heavy dashed gridlines.** Noise that reads as thresholds. Fix: solid hairlines or none.

## Accessibility
- WCAG 1.4.1 Use of Color: pair color with labels, shape, or pattern.
- WCAG 1.4.11 Non-text Contrast: ≥3:1 for marks, gridlines that carry meaning, and focus indicators.
- WCAG 1.1.1: provide a text alternative (short summary plus a longer description or data table).
- Text in charts meets 4.5:1 (1.4.3). Text is real text, not paths, so it zooms and translates.
- Details in [accessible-data-visualization](../accessible-data-visualization/Skill.md).

## Responsive Design
- Reduce the number of ticks and labels on narrow viewports. Don't shrink font below 11–12px.
- Switch forms at breakpoints: vertical columns become horizontal bars on mobile, and a wide multi-line chart becomes small multiples stacked vertically.
- Keep the takeaway title visible at all sizes. Hide secondary annotations first.

## Performance
Simpler charts are faster. Aggregate before plotting: humans can't read 50k points in a 600px wide line anyway. Thresholds are in [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md).

## Security
Titles, labels, and tooltips often contain user data. Render them as text nodes, not `innerHTML`. Sanitize any rich-text annotations.

## Testing
- Visual regression snapshots of charts with fixed data (Playwright `toHaveScreenshot`).
- Unit-test scale/format helpers: zero baseline, compact formatting, stable color map.
- Automated CVD simulation (Chrome DevTools rendering emulation) and contrast checks on palette tokens.
- Five-second test with a colleague: can they state the takeaway?

## Tooling
- Colorblind simulation: Chrome DevTools "Emulate vision deficiencies", Sim Daltonism, Coblis.
- Palettes: ColorBrewer, viridis/cividis (d3-scale-chromatic), Datawrapper's colorblind check, Carbon data-viz palettes.
- References: FT Visual Vocabulary (chart-doctor repo), Datawrapper Academy, Chartability.

## Framework Notes
- **React (Vite SPA):** keep chart tokens (`chartTokens`), formatters, and the entity-to-color map in one `src/lib/charts/` module. Feed them into Recharts/ECharts/react-chartjs-2/visx theme props so every chart reads as one system. Expose tokens as CSS variables (`--chart-1..8`, `--chart-grid`) so dark mode swaps without re-rendering.
- **Next.js (App Router):** tokens and formatters are plain TS and safe in Server Components. Compute the stable color map and finding-first titles on the server, and pass serializable props to `'use client'` chart components. Pin the `Intl.NumberFormat` locale (from the request/i18n config) so server and client format identically and avoid hydration mismatches.

## AI Agent Guidance
- DO decide the takeaway and chart form before writing code, and assign colors last.
- DO start bars at zero, use a single y-axis, and keep a stable entity-to-color map.
- DO add a finding-first title, units, source, and a table/text alternative.
- DON'T generate a 9th hue, a rainbow ramp, 3D effects, or dual axes.
- DON'T put a label on every point.
- Before done: render at 375px and 1280px, screenshot, check label collisions, and simulate deuteranopia.

## Examples
```ts
// Indexed comparison instead of dual axis
type Pt = { date: string; value: number };
export const indexTo100 = (s: Pt[]) => s.map(p => ({ ...p, value: (p.value / s[0].value) * 100 }));
```
```ts
// Finding-first title builder
export const titleFor = (metric: string, pct: number, period: string) =>
  `${metric} ${pct >= 0 ? 'rose' : 'fell'} ${Math.abs(pct).toFixed(0)}% ${period}`;
```

## Related Skills
- [chart-type-selection](../chart-type-selection/Skill.md): mapping questions to chart forms
- [accessible-data-visualization](../accessible-data-visualization/Skill.md): text alternatives, keyboard, CVD
- [dashboard-design](../dashboard-design/Skill.md): applying these rules across many charts
- [color-systems](../color-systems/Skill.md): underlying palette tokens
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md): contrast math and non-color encoding
- [kpi-and-stat-components](../kpi-and-stat-components/Skill.md): when the answer is a number, not a chart

## Sources
- [FT Visual Vocabulary (chart-doctor)](https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary): Community/Open Source; relationship categories
- [Datawrapper: colorblindness part 2](https://www.datawrapper.de/blog/colorblindness-part2): Community; CVD color rules
- [NN/g: Dashboards and preattentive attributes](https://www.nngroup.com/articles/dashboards-preattentive/): Community; encoding accuracy
- Edward Tufte, *The Visual Display of Quantitative Information*: Book; data-ink, lie factor, small multiples
- Cole Nussbaumer Knaflic, *Storytelling with Data*: Book; emphasis, decluttering, titles
- Cleveland & McGill (1984), *Graphical Perception*: Research; encoding accuracy ranking
- Claude Code bundled `dataviz` skill (references: choosing-a-form, color-formula, anti-patterns): Community agent skill; color-job and anti-pattern structure

## License / Usage Notes
Content is summarized and paraphrased from the sources above. Example palette hexes are illustrative and must be validated for your brand. Books are copyrighted and only their concepts are referenced.

## Quality Tier
A: Grounded in canonical research and practitioner guidance with actionable rules. Not empirically validated beyond those sources.

## Status
Active

## Last Verified
2026-09-15
