# Chart Type Selection

## Summary
A decision procedure for choosing the right visual form for a data question. It covers deviation, correlation, ranking, distribution, change over time, magnitude, part-to-whole, spatial, and flow (FT Visual Vocabulary), plus the frequent right answer of "not a chart" (a stat tile or table). Includes selection tables, series-count limits, and mobile substitutions.

## Category
Data Visualization

## Subcategories
visual vocabulary, chart taxonomy, form selection, small multiples, tables vs charts

## Problem It Solves
Teams default to whatever the chart library demo shows (pie, donut, gauge, radar) rather than what the data question needs. That produces slow-to-read or misleading visuals. This skill maps the reader's task to a default form and its safe alternates.

## When To Use
- Designing a new chart, report, or dashboard tile.
- Reviewing requests like "add a pie chart of X" or AI-generated chart choices.
- Choosing mobile substitutes for a desktop chart.

## When Not To Use
- The encoding and color details after the form is chosen: see data-visualization-principles.
- Interactive data exploration tools where users pick encodings (for example, a Vega-Lite or Tableau-style builder).

## Core Principles
1. **Start from the task verb:** compare, rank, show change, show distribution, show relationship, show composition, locate, or show flow.
2. **Ask "is it even a chart?"** A single value is a stat tile, a few headline numbers are a KPI row, and more than 7 meaningful categories or exact lookup calls for a table.
3. **Prefer the common form** (bar, line, dot, scatter). Familiarity beats novelty for operational UIs.
4. **Series count limits form.** 1–3 series use color comfortably. 4–6 need direct labels or a legend. Beyond 7, fold into "Other," use small multiples, or highlight one series.
5. **Time goes on the x-axis, left to right.** Categories with long names go on the y-axis (horizontal bars).
6. **Part-to-whole is only meaningful if the parts sum to a real whole.**
7. **Maps only when geography is the insight.** Otherwise a sorted bar by region reads better.

## Best Practices
- Pie/donut: 2–5 slices, a real whole, sorted clockwise from 12 o'clock, direct percentage labels. Otherwise use a bar.
- Line charts need roughly 4 or more ordered points. Fewer points read better as a column/dot chart.
- Stacked bars: only the bottom segment shares a baseline. If readers must compare the inner segments, use grouped bars or small multiples.
- Area charts: single series, or stacked when the *total* is the story. Never overlapping translucent areas with more than 2 series.
- Scatter with more than about 5k points: use hexbin, density contours, or opacity (see large-dataset-visualization-performance).
- Gauges and radial progress: only for a single value against a known limit. Prefer a bullet chart or meter bar.
- Radar charts: avoid. Axis order changes the shape. Use parallel coordinates or grouped bars.
- Heatmaps: good for two categorical dimensions × magnitude (hour × weekday). Use a sequential palette with a legend.
- Sankey/chord: flows between states. Limit to about 20 nodes and provide a table alternative.
- Waterfall: for explaining a change from start to end (P&L bridges).

## Implementation Guidance
**Task → form table (defaults first)**

| Task | Default | Alternates | Avoid |
|---|---|---|---|
| Single current value | Stat tile (+delta, sparkline) | Bullet chart vs target | One-bar chart |
| Compare magnitudes (nominal) | Sorted horizontal bar | Dot plot, lollipop | Pie, radar, 3D column |
| Rank | Ordered bar | Slopegraph (rank change), bump chart | Unsorted bar |
| Change over time (continuous) | Line | Area (1 series), column (≤ ~20 periods), calendar heatmap | Pie per period |
| Change for 2 time points | Slopegraph / dumbbell | Paired column | Two pies |
| Deviation from target/zero | Diverging bar | Line vs reference, bullet | Stacked around zero |
| Distribution | Histogram | Box/violin, beeswarm, strip, ECDF | Mean bar only |
| Correlation | Scatter | Connected scatter (time), bubble (3rd var), XY heatmap | Dual axis |
| Part-to-whole (static) | 100% stacked bar | Pie (≤5), treemap (hierarchy), waffle | Donut with 10 slices |
| Part-to-whole over time | Stacked area / stacked column | Small multiples of lines | Series of pies |
| Likert / sentiment | Diverging stacked bar centered on neutral | 100% stacked bar | Pie |
| Hierarchy | Treemap, sunburst (≤3 levels), icicle | Indented table | Deep sunburst |
| Spatial pattern | Choropleth (normalized rates) | Proportional symbol, hex/dot density | Choropleth of raw counts |
| Flow | Sankey | Chord, flow map, network | Spaghetti arrows |
| Schedule / duration | Gantt / timeline | Range bar | Stacked bar hack |
| Many series trend | Small multiples | Emphasis (1 colored, rest gray) | 12-color spaghetti |
| Exact lookup, many attributes | Table (with in-cell bars/sparklines) | | Any chart |

**Data-shape pre-check**
```ts
type FieldKind = 'nominal' | 'ordinal' | 'quantitative' | 'temporal' | 'geo';
interface Field { name: string; kind: FieldKind; cardinality: number }

export function suggestForm(x: Field, y?: Field, series?: Field): string {
  if (!y && x.kind === 'quantitative') return 'histogram';
  if (x.kind === 'temporal' && y?.kind === 'quantitative')
    return series && series.cardinality > 6 ? 'small-multiples-line' : 'line';
  if (x.kind === 'nominal' && y?.kind === 'quantitative')
    return x.cardinality > 25 ? 'table-or-top-n-bar' : 'sorted-horizontal-bar';
  if (x.kind === 'quantitative' && y?.kind === 'quantitative') return 'scatter';
  if (x.kind === 'geo') return 'choropleth-normalized';
  return 'table';
}
```
Use this as a lint for agents, not as a replacement for judgment.

## Recommended Workflow
1. Write the question and the task verb.
2. Classify fields: kind and cardinality.
3. Check "is it a chart?" first (stat tile, table).
4. Pick the default form from the table and check series-count limits.
5. Decide the mobile substitute (for example, grouped column → horizontal bar or small multiples).
6. Sketch with real data. Test extreme values, nulls, and a single category.
7. Hand off to the implementation library skill.

## Patterns
- **Top-N + Other:** show the top 7 sorted and aggregate the tail.
- **Small multiples grid:** use CSS grid with a shared domain computed across all facets.
- **Bullet chart:** actual bar + target tick + qualitative bands. Replaces gauges.
- **Table with micro-charts:** inline bars/sparklines inside table cells for dense comparison.
- **Chart + table toggle:** the same data in both forms, which also serves accessibility.

## Anti-Patterns
- **Pie for more than 5 categories or close values.** Fix: sorted bar.
- **Gauge wall on dashboards.** Low data density. Fix: bullet charts or a KPI row.
- **Radar for comparing products.** Shape depends on axis order. Fix: grouped bar or dot plot.
- **Stacked bars for comparing middle segments.** No shared baseline. Fix: small multiples.
- **Line chart for unordered categories.** Implies continuity. Fix: bar/dot.
- **Choropleth of absolute counts.** It just maps population. Fix: normalize per capita or use proportional symbols.
- **Word clouds for frequencies.** Size is inaccurate and word length biases it. Fix: bar chart.
- **Donut with the total in the middle as the only KPI.** Fix: stat tile plus a small bar.

## Accessibility
- Simpler forms are easier to describe and navigate. Bars and lines map cleanly to tables.
- Complex forms (sankey, chord, network) must ship a table or structured list alternative.
- Avoid forms that rely only on hue distinctions (dense heatmaps without values, many-slice pies).

## Responsive Design
| Desktop | Mobile substitute |
|---|---|
| Grouped vertical columns | Horizontal bars, or one group per small chart |
| Multi-line (6 series) | Small multiples stacked, or 1 highlighted + selector |
| Wide heatmap | Transpose axes, or aggregate to coarser bins |
| Sankey | Table of flows, or a simplified 2-level bar |
| Scatter with labels | Scatter with tap-to-reveal and a top-N list below |

## Performance
Form selection is the biggest performance lever. Aggregating 1M events into a 60-bin histogram beats any renderer optimization.

## Security
None specific to form selection. Treat category names as untrusted text when rendering labels.

## Testing
- Storybook stories per chart form with edge-case datasets: empty, 1 item, 100 items, negatives, nulls.
- Review checklist: task verb, form, and series count are documented in the story description.

## Tooling
- FT Visual Vocabulary poster; Datawrapper chart-type guide; data-to-viz.com decision tree.
- Vega-Lite (v6.4.x) for rapid prototyping of alternative forms from the same spec.
- Observable Plot (0.6.x) for quick exploratory comparisons.

## Framework Notes
- **React (Vite SPA):** keep form choice in a typed `ChartSpec` (`form: 'bar' | 'line' | 'stat' | 'table'`) rendered by a `<ChartRenderer spec data />` switch component. Swap form per breakpoint with a `useMediaQuery` hook or container queries, without rewriting data code.
- **Next.js (App Router):** decide the form and pre-aggregate data (top-N, bins) in the Server Component. Render stat tiles and tables as Server Components (zero JS). Only the chart forms that need interactivity become `'use client'` leaves. Prefer CSS/container-query layout switches over JS breakpoints to avoid hydration mismatch.

## AI Agent Guidance
- DO state the task verb and chart form in a code comment or PR description.
- DO default to sorted horizontal bars for nominal comparisons, lines for time, and scatter for correlation.
- DO propose a stat tile or table when the data is a single number or needs exact lookup.
- DON'T use pie, donut, gauge, radar, or 3D unless explicitly justified and within limits.
- Before done: test with 1 category, many categories, and a 375px width; confirm the form still works.

## Examples
```ts
// Top-N + Other aggregation
export function topN<T extends { label: string; value: number }>(rows: T[], n = 7) {
  const sorted = [...rows].sort((a, b) => b.value - a.value);
  const head = sorted.slice(0, n);
  const rest = sorted.slice(n).reduce((s, r) => s + r.value, 0);
  return rest > 0 ? [...head, { label: 'Other', value: rest } as T] : head;
}
```

## Related Skills
- [data-visualization-principles](../data-visualization-principles/Skill.md): encoding and color rules after choosing a form
- [kpi-and-stat-components](../kpi-and-stat-components/Skill.md): the "not a chart" answer
- [maps-and-geospatial-ui](../maps-and-geospatial-ui/Skill.md): spatial forms
- [enterprise-data-tables](../enterprise-data-tables/Skill.md): when a table beats a chart
- [dashboard-design](../dashboard-design/Skill.md): combining forms on one screen

## Sources
- [FT Visual Vocabulary](https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary): Open Source/Community; nine relationship categories and example forms
- [NN/g: dashboards & preattentive attributes](https://www.nngroup.com/articles/dashboards-preattentive/): Community; avoid pies, gauges, 3D
- [Datawrapper Academy](https://academy.datawrapper.de/): Community; chart-type guidance
- Claude Code bundled `dataviz` skill (choosing-a-form, series-count ladder): Community agent skill

## License / Usage Notes
FT Visual Vocabulary is openly published by the Financial Times. Categories are paraphrased here. All tables are original syntheses.

## Quality Tier
A: Well-sourced decision tables consistent across FT, NN/g, and Datawrapper. Heuristic rather than exhaustive.

## Status
Active

## Last Verified
2026-09-15
