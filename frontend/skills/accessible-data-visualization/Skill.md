# Accessible Data Visualization

## Summary
How to make charts, graphs, and maps perceivable, operable, understandable, and robust for people using screen readers, keyboards, magnification, high-contrast modes, or with color-vision deficiency and cognitive disabilities. It combines WCAG 2.2 criteria, W3C WAI complex-image guidance, Chartability's POUR+CAF heuristics (Frank Elavsky), and library features (Recharts `accessibilityLayer`, ECharts `aria`, Highcharts accessibility module). Implemented in React and Next.js.

## Category
Data Visualization

## Subcategories
text alternatives, data tables, keyboard navigation, screen readers, color-vision deficiency, contrast, reduced motion, forced colors, sonification, Chartability audits

## Problem It Solves
Most web charts are a canvas or SVG with no name, no data access, color-only encoding, hover-only tooltips, and animations that can't be paused. Screen reader and keyboard users get nothing or noise, and CVD users can't match series to legends. This skill gives concrete requirements and React components to fix that.

## When To Use
- Every chart, dashboard tile, sparkline, and map shipped to users.
- Accessibility audits and remediation of existing dashboards.
- Selecting a chart library (compare built-in a11y).

## When Not To Use
- Decorative illustrations that look like charts but carry no data: mark them `aria-hidden` / `alt=""` instead.
- General table accessibility details: accessible-data-tables.

## Core Principles
1. **Equivalent access to the data and the insight.** Provide a short name, a summary of the takeaway, and the full data (table) for anyone who needs it (WCAG 1.1.1).
2. **Never color alone** (1.4.1). Use direct labels, shapes, dash patterns, textures, and position.
3. **Contrast:** marks and meaningful graphical objects ≥3:1 against adjacent colors/background (1.4.11). Text ≥4.5:1 (1.4.3).
4. **Operable without a mouse** (2.1.1). Anything available on hover (tooltips, drill-down, legend toggles) is available via keyboard, with visible focus (2.4.7, 2.4.11).
5. **Tooltips follow 1.4.13:** dismissible (Esc), hoverable, persistent.
6. **Motion and live updates can be controlled** (2.2.2 Pause/Stop/Hide). Respect `prefers-reduced-motion`.
7. **Robust semantics:** correct roles and names, and a structure that doesn't flood screen readers with hundreds of unlabeled nodes.
8. **Chartability's extra principles:** don't *compromise* user privacy or safety, *assist* comprehension (summaries, statistics), and stay *flexible* (user settings like zoom, contrast, text spacing, dark mode).

## Best Practices
- **Two-part text alternative (WAI):** short name (title) + long description (takeaway, trend, extremes, notable points) + data table. Put the summary in visible text when possible, which helps everyone.
- **Static chart:** `<figure>` with `<figcaption>` or a heading; SVG `role="img"` + `aria-labelledby` (title + desc); internal marks `aria-hidden`.
- **Explorable chart:**
  - The container is `role="group"` (or `application` only if essential) with a label and instructions.
  - One tab stop into the chart, arrow keys between points (roving tabindex), Home/End for first/last, and PageUp/PageDown or Up/Down between series.
  - Each point's accessible name includes series, x, y, and unit ("Revenue, March 2026, $1.2 million").
- **Data table alternative:** a real `<table>` with `<caption>`, `<th scope>`, formatted values. Toggle it visibly ("View as table"), or put it in `<details>`. Don't hide it only for screen readers, since sighted keyboard and low-vision users benefit too.
- **Legends:** HTML buttons with `aria-pressed` for toggles. Legend order matches visual order.
- **CVD:** validate palettes with simulation. Blue plus orange/red is the safest pair. Vary lightness. Add patterns/decals (ECharts `aria.decal`, nivo patterns) for fills.
- **Forced colors (Windows High Contrast):** use `@media (forced-colors: active)` so marks use `CanvasText`/`Highlight` system colors and aren't lost. Test canvas charts, which ignore forced colors, so the table alternative is essential.
- **Zoom/reflow:** charts remain usable at 200% zoom and 320px width (1.4.10), and text stays real text so it scales.
- **Reduced motion:** disable entry animations and transitions, and cap animated updates.
- **Live data:** don't announce every update. Offer an opt-in `aria-live="polite"` summary at a throttled cadence ("Error rate now 2.1%, up from 1.4%") and a pause button.
- **Cognitive:** plain-language titles stating the finding, consistent formats, no jargon abbreviations without expansion.
- **Sonification** (Highcharts, or custom Web Audio) can help trend perception for blind users. Treat it as an enhancement, not a replacement for tables.

## Implementation Guidance
**Requirement checklist by chart kind**

| Chart kind | Minimum | Better |
|---|---|---|
| Sparkline / tiny static | `role="img"` + `aria-label` with trend summary | Visible value + delta text next to it |
| Static SVG chart | figure + title + summary + table | Direct labels, patterns |
| Interactive SVG chart | above + keyboard point navigation + focus-visible tooltip | Series switching, announce selection |
| Canvas chart (Chart.js/ECharts canvas) | `aria-label` + fallback + table + HTML legend/controls | Table rows drive chart highlight |
| Map | text summary + table/list of regions + keyboard pan/zoom controls | Search/select a region by name |
| Live chart | above + pause + throttled polite summary | User-set announcement frequency |

**Library a11y features (verify per version)**

| Library | Built-in |
|---|---|
| Recharts 3 | `accessibilityLayer` default on: keyboard arrows move the active point, and the tooltip follows focus |
| ECharts 6 | `aria.enabled` auto description; `aria.decal` patterns |
| Chart.js 4 | none beyond canvas: add aria-label, fallback, table |
| Highcharts | accessibility module: keyboard nav, screen reader descriptions, data table export, sonification (commercial license) |
| nivo | per-chart `role`/`aria*` props, some focusable marks |
| visx / d3 | none: full control, you build it |

## Recommended Workflow
1. Write the chart's takeaway and a long description while designing, not after.
2. Choose a palette and validate CVD and contrast (≥3:1 marks) in light, dark, and forced-colors.
3. Build `ChartFigure` (caption, summary, table toggle) as the default wrapper.
4. Add keyboard interaction for interactive charts, and make tooltips appear on focus and close on Esc.
5. Add reduced-motion and pause controls for animated/live charts.
6. Test with automated tools (axe), then manually: keyboard only, NVDA+Firefox/Chrome, VoiceOver+Safari, 200% zoom, forced colors, and CVD emulation.
7. Run a Chartability quick audit (14 critical heuristics, 20–40 min) for key charts.
8. Document known limitations and alternatives.

## Patterns
- **ChartFigure wrapper** with a summary and table toggle (see Examples).
- **Roving tabindex points:** a single `tabIndex=0` on the active point, arrow keys move, `aria-label` per point.
- **Table-drives-chart:** focus/hover a table row to highlight the mark, which works for canvas charts.
- **Auto-summary generator:** compute min, max, first-to-last change, and trend direction from data for the description.
- **Pattern fills:** SVG `<pattern>` defs applied to the secondary series and exposed in the legend swatch.
- **Forced-colors override:** `@media (forced-colors: active) { .mark { fill: CanvasText; stroke: Canvas; } .mark--active { fill: Highlight; } }`.

## Anti-Patterns
- **Canvas/SVG with no name.** Invisible or "image" only. Fix: `role="img"` + a meaningful `aria-label`.
- **`aria-label="chart"` or "Line chart".** No information. Fix: the takeaway ("Signups doubled from June to September").
- **Every SVG path exposed to screen readers.** Hundreds of "graphic" stops. Fix: `aria-hidden` on marks, and navigable points only when intentionally interactive.
- **Hover-only tooltips.** Keyboard and touch users excluded. Fix: focus/tap triggers, Esc to dismiss.
- **Legend color swatches as the only identifier.** Fix: direct labels and shape/dash differences.
- **Table alternative with raw unformatted numbers (1234567.891).** Fix: same formatting as the chart, plus units in headers.
- **`aria-live="assertive"` on a live chart.** Constant interruption. Fix: opt-in polite, throttled summaries.
- **Low-contrast pastel series on white.** Fails 1.4.11. Fix: darker steps, or add outlines/labels.
- **Relying on `display:none` table for screen readers only.** It isn't announced when `display:none`. Fix: a visible toggle or visually-hidden (not display:none) content.

## Accessibility
This entire skill is about accessibility. Key WCAG 2.2 criteria: 1.1.1, 1.3.1, 1.4.1, 1.4.3, 1.4.10, 1.4.11, 1.4.13, 2.1.1, 2.2.2, 2.4.7, 2.4.11 (Focus Not Obscured), 2.5.8 (Target Size Minimum), 4.1.2.

## Responsive Design
- At narrow widths, keep the summary and table toggle visible. A table can scroll horizontally within a labeled region (`role="region"` + `aria-label` + `tabIndex=0`).
- Touch: tap a point to show its tooltip, with touch targets ≥24px (use Voronoi/nearest-point hit areas).
- Text in charts must not become tiny: reduce ticks rather than font size.

## Performance
- The summary and table render as server HTML (cheap, immediately accessible even before the chart JS loads).
- Don't render thousands of focusable nodes. For big data, navigate aggregated bins or use the table with pagination/virtualization.

## Security
- Don't expose sensitive individual-level data in auto-generated descriptions or hidden tables that aren't shown visually (Chartability "Compromising": privacy).
- Escape user-provided labels in descriptions.

## Testing
- **Automated:** axe-core (`@axe-core/playwright`) catches missing names, contrast on text, and ARIA misuse. It does not validate chart meaning.
- **Unit (Testing Library):** `getByRole('img', { name: /signups doubled/i })`, `getByRole('table', { name: ... })`, keyboard `userEvent.keyboard('{ArrowRight}')` updates the active point name.
- **Manual:** NVDA + Chrome/Firefox, VoiceOver + Safari (macOS/iOS), TalkBack; keyboard-only; 200%/400% zoom; Windows forced colors; Chrome DevTools vision deficiency emulation.
- **Chartability audit** workbook for critical charts.

## Tooling
- Chartability (heuristics workbook). Chrome DevTools rendering emulation (CVD, forced-colors, reduced motion).
- axe DevTools / @axe-core/playwright. Accessibility Insights for Web.
- Highcharts accessibility module (commercial) as a reference implementation. Data Navigator (Frank Elavsky, experimental) for structured chart navigation.
- Palette validation: ColorBrewer, Viz Palette, and contrast checkers.

## Framework Notes
- **React (Vite SPA):** use a shared `ChartFigure` component and a `useReducedMotion` hook, and pass `isAnimationActive`/`animation:false` into chart libs. Manage roving focus with refs and state.
- **Next.js (App Router):**
  - Render `ChartFigure`'s caption, summary, and `<table>` in a **Server Component** so the accessible equivalent is present in initial HTML, before hydration and even if chart JS fails.
  - Only the interactive chart is a `'use client'` child.
  - Generate the summary on the server from data (deterministic, no hydration mismatch).
  - Avoid `dynamic(..., { ssr: false })` for the table or summary, only for the chart.

## AI Agent Guidance
- DO wrap every chart in a figure with a finding-first caption, generated summary, and table toggle.
- DO provide keyboard access to anything hover-based. Tooltips show on focus and close on Esc.
- DO validate palette contrast (≥3:1) and add non-color cues.
- DO respect `prefers-reduced-motion` and add pause for live charts.
- DON'T label charts generically, expose every path to assistive technology, or use assertive live regions.
- Before done: axe clean, Tab/arrow through the chart, screen-reader spot check (name + summary + table), forced-colors and deuteranopia emulation screenshots.

## Examples
```tsx
// components/charts/ChartFigure.tsx (Server Component compatible)
import type { ReactNode } from 'react';

export type Column<T> = { key: keyof T; header: string; format?: (v: T[keyof T]) => string };

export function summarizeSeries(label: string, points: { x: string; y: number }[], fmt: (n: number) => string) {
  if (points.length === 0) return `${label}: no data.`;
  const first = points[0], last = points[points.length - 1];
  const max = points.reduce((a, b) => (b.y > a.y ? b : a));
  const min = points.reduce((a, b) => (b.y < a.y ? b : a));
  const change = first.y === 0 ? null : ((last.y - first.y) / Math.abs(first.y)) * 100;
  return `${label} went from ${fmt(first.y)} (${first.x}) to ${fmt(last.y)} (${last.x})` +
    (change === null ? '' : `, ${change >= 0 ? 'up' : 'down'} ${Math.abs(change).toFixed(0)}%`) +
    `. Highest ${fmt(max.y)} in ${max.x}; lowest ${fmt(min.y)} in ${min.x}.`;
}

export function ChartFigure<T extends Record<string, unknown>>({ id, title, summary, rows, columns, children }: {
  id: string; title: string; summary: string; rows: T[]; columns: Column<T>[]; children: ReactNode;
}) {
  return (
    <figure aria-labelledby={`${id}-title`} aria-describedby={`${id}-summary`}>
      <h3 id={`${id}-title`}>{title}</h3>
      <p id={`${id}-summary`}>{summary}</p>
      <div aria-hidden="false">{children}</div>
      <details>
        <summary>View data as table</summary>
        <div role="region" aria-label={`${title} data`} tabIndex={0} style={{ overflowX: 'auto' }}>
          <table>
            <caption>{title}</caption>
            <thead><tr>{columns.map(c => <th key={String(c.key)} scope="col">{c.header}</th>)}</tr></thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={i}>{columns.map((c, j) => {
                  const v = r[c.key];
                  const text = c.format ? c.format(v) : String(v);
                  return j === 0 ? <th key={j} scope="row">{text}</th> : <td key={j}>{text}</td>;
                })}</tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </figure>
  );
}
```
```tsx
// Keyboard-navigable points for a custom SVG chart (client)
'use client';
import { useState, useRef, type KeyboardEvent } from 'react';

export function NavigablePoints({ pts, label }: { pts: { cx: number; cy: number; name: string }[]; label: string }) {
  const [active, setActive] = useState(0);
  const refs = useRef<(SVGCircleElement | null)[]>([]);
  const move = (i: number) => { const n = Math.max(0, Math.min(pts.length - 1, i)); setActive(n); refs.current[n]?.focus(); };
  const onKey = (e: KeyboardEvent) => {
    const map: Record<string, number> = { ArrowRight: active + 1, ArrowLeft: active - 1, Home: 0, End: pts.length - 1 };
    if (e.key in map) { e.preventDefault(); move(map[e.key]); }
  };
  return (
    <g role="group" aria-label={`${label}. Use arrow keys to move between points.`} onKeyDown={onKey}>
      {pts.map((p, i) => (
        <circle key={i} ref={el => { refs.current[i] = el; }} cx={p.cx} cy={p.cy} r={i === active ? 6 : 4}
          tabIndex={i === active ? 0 : -1} role="img" aria-label={p.name}
          className="fill-[var(--chart-1)] focus-visible:outline-2 focus-visible:outline-offset-2" />
      ))}
    </g>
  );
}
```

## Related Skills
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md)
- [accessible-data-tables](../accessible-data-tables/Skill.md): table alternative details
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md)
- [keyboard-navigation](../keyboard-navigation/Skill.md): roving tabindex
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md): live chart announcements
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md)
- [screen-reader-testing](../screen-reader-testing/Skill.md)
- [accessible-images-and-media](../accessible-images-and-media/Skill.md): complex image alternatives
- [data-visualization-principles](../data-visualization-principles/Skill.md)

## Sources
- [Chartability](https://chartability.fizz.studio/): Community (research-based); POUR+CAF, quick (14) vs full (50) heuristics audit
- [W3C WAI Complex Images tutorial](https://www.w3.org/WAI/tutorials/images/complex/): Official; short + long description approaches
- [Highcharts Accessibility module](https://www.highcharts.com/docs/accessibility/accessibility-module): Official vendor docs; keyboard nav, descriptions, data table, sonification
- [Chart.js Accessibility](https://www.chartjs.org/docs/latest/general/accessibility.html): Official; canvas aria + fallback
- [Recharts 3.0 migration guide](https://github.com/recharts/recharts/wiki/3.0-migration-guide): Official; accessibilityLayer default on
- [Datawrapper: colorblindness](https://www.datawrapper.de/blog/colorblindness-part2): Community; CVD strategies
- WCAG 2.2 (W3C Recommendation): Official; success criteria listed

## License / Usage Notes
WCAG/WAI content © W3C, summarized. Chartability is openly published by Frank Elavsky/Fizz Studio. Highcharts requires a commercial license for commercial use. Code is original.

## Quality Tier
A: Official W3C and research-backed Chartability guidance with working React patterns. Library a11y features should be re-verified per version.

## Status
Active

## Last Verified
2026-09-15
