# CSS Grid and Flexbox Layout

## Summary
Practical rules for choosing and using CSS Grid (two-dimensional, layout-in) and Flexbox (one-dimensional, content-out) in React/Next.js UIs. Covers intrinsic "no-breakpoint" patterns, subgrid (Widely available), named areas, alignment, `gap`, the notorious `min-width: auto` overflow issue, and grid-lanes masonry status (experimental outside Safari).

## Category
CSS & Styling

## Subcategories
Grid, Flexbox, subgrid, auto-fit/minmax, grid-template-areas, alignment, gap, intrinsic sizing, masonry/grid-lanes, app shells, holy grail layout, sticky footers

## Problem It Solves
Layouts built with floats, absolute positioning, margin hacks, or JS measurement are brittle. Wrong use of flex vs grid produces overflow bugs, misaligned cards, and many unnecessary breakpoints. This skill gives decision rules and battle-tested patterns.

## When To Use
- Building page shells (header/sidebar/main), card grids, forms, toolbars, media objects.
- Aligning content across sibling cards (subgrid).
- Debugging overflow, unequal columns, or items not shrinking.

## When Not To Use
- Text flow and inline formatting: normal flow is correct.
- Tabular data: use `<table>` (optionally styled with grid for layout of wrappers, not cells).
- Tooltip/popover placement: anchor positioning or Floating UI.

## Core Principles
1. **Grid for two dimensions or when the layout defines the tracks; Flexbox for a single row/column where content size drives distribution.**
2. **`gap` for spacing between items**, never margins on children.
3. **Intrinsic first:** `repeat(auto-fit, minmax(min(100%, 16rem), 1fr))` and `flex-wrap` remove most breakpoints.
4. **Flex/grid items default to `min-width: auto`**, so long content prevents shrinking. Set `min-inline-size: 0` (or `minmax(0, 1fr)`) where text truncation or overflow is needed.
5. **DOM order equals reading and focus order.** Visual reordering (`order`, grid placement, `row-reverse`) must not contradict it.
6. **Use `fr` and `minmax()` rather than percentages** so gaps are accounted for automatically.

## Best Practices
- Use `grid-template-areas` for app shells. It's readable and easy to redefine per breakpoint.
- Use `minmax(0, 1fr)` for main content tracks to prevent overflow from wide children (code blocks, tables).
- Use `subgrid` to align card headers/footers across a row: parent defines rows, cards span them with `grid-row: span 3; grid-template-rows: subgrid`.
- Use `place-items`/`place-content`/`place-self` shorthands for centering.
- Prefer `align-items: start` in grids with mixed-height content when stretching looks wrong.
- Use `flex: 1 1 0` (`flex: 1`) for equal distribution and `flex: 1 1 auto` to distribute remaining space proportionally to content.
- `margin-inline-start: auto` inside flex pushes an item to the end (toolbar pattern).
- Use `dvh`/`svh` rather than `100vh` for full-height mobile layouts.
- Use logical values (`inline-size`, `justify-content: start/end`) for RTL compatibility.

## Implementation Guidance

### Grid vs Flex decision table
| Need | Use |
|---|---|
| Page shell with regions | Grid (`grid-template-areas`) |
| Responsive card gallery with equal column widths | Grid `auto-fit`/`auto-fill` + `minmax` |
| Toolbar / nav items / tag list that wraps | Flex + `flex-wrap` + `gap` |
| Media object (icon + text) | Flex (or grid `auto 1fr`) |
| Form label/input alignment across rows | Grid (`max-content 1fr`), subgrid for nested groups |
| Align content across sibling cards | Grid + `subgrid` |
| Center one element | Grid `place-items: center` |
| Sidebar that wraps under content when narrow (no media query) | Flex with large `flex-grow` on main + `flex-basis` on sidebar |
| Pinterest/masonry | `display: grid-lanes` in `@supports`, fallback grid; or CSS columns for simple text-free tiles |

### auto-fit vs auto-fill
- `auto-fit`: empty tracks collapse, so items stretch to fill the row (good for few items).
- `auto-fill`: keeps empty tracks, so items keep their size (good for consistent tile sizes).
- Always wrap the minimum with `min(100%, X)` to avoid overflow on very narrow containers.

### Masonry status (Sept 2026)
`display: grid-lanes` ships in Safari 26.4+. Chrome and Firefox have it behind flags. Use:
```css
.masonry { display: grid; grid-template-columns: repeat(auto-fill, minmax(14rem, 1fr)); gap: 1rem; }
@supports (display: grid-lanes) { .masonry { display: grid-lanes; } }
```
Earlier proposals (`grid-template-rows: masonry`) are superseded, so don't use them.

## Recommended Workflow
1. Sketch regions; decide grid (regions/tracks) vs flex (flow of items).
2. Write the narrow layout first with intrinsic sizing.
3. Add `gap`, alignment, and `minmax(0, 1fr)` safeguards.
4. Add container/media queries only where intrinsic behavior isn't enough.
5. Test with long strings, many and few items, RTL, and 320px width.
6. Check keyboard tab order matches visual order.

## Patterns
**App shell**
```css
.shell {
  display: grid; min-block-size: 100dvh;
  grid-template: "header" auto "main" 1fr "footer" auto / minmax(0, 1fr);
}
@media (width >= 64rem) {
  .shell { grid-template: "header header" auto "nav main" 1fr "footer footer" auto / 16rem minmax(0, 1fr); }
}
.shell > header { grid-area: header; } .shell > nav { grid-area: nav; }
.shell > main { grid-area: main; } .shell > footer { grid-area: footer; }
```

**RAM (Repeat, Auto, Minmax) gallery**
```css
.grid { display: grid; gap: 1rem; grid-template-columns: repeat(auto-fill, minmax(min(100%, 15rem), 1fr)); }
```

**Subgrid aligned cards**
```css
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 18rem), 1fr)); gap: 1.5rem; }
.card { display: grid; grid-row: span 3; grid-template-rows: subgrid; gap: .75rem; }
/* card children: header, body, footer — footers line up across the row */
```

**Truncating text in flex**
```css
.row { display: flex; gap: .5rem; align-items: center; }
.row .label { min-inline-size: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
```

**Toolbar with trailing actions**
```css
.toolbar { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; }
.toolbar .spacer { margin-inline-start: auto; }
```

**Full-bleed inside a centered content grid**
```css
.content { display: grid; grid-template-columns: [full-start] minmax(1rem, 1fr) [content-start] minmax(0, 65ch) [content-end] minmax(1rem, 1fr) [full-end]; }
.content > * { grid-column: content; }
.content > .full-bleed { grid-column: full; }
```

## Anti-Patterns
- **Margins on children for spacing in flex/grid.** Double spacing, awkward first/last handling. Use `gap`.
- **`grid-template-columns: repeat(3, 33.33%)` with a gap.** Overflows. Use `repeat(3, 1fr)`.
- **`1fr` main track with wide `<pre>`/table children.** Page-wide horizontal scroll. Use `minmax(0, 1fr)` + `overflow-x: auto` on the wide child.
- **Using `order` / `row-reverse` to fix visual order.** Keyboard/screen reader order diverges (WCAG 1.3.2, 2.4.3). Change DOM order.
- **`height: 100vh` on mobile.** Content hidden behind browser UI. Use `100dvh` (or `svh` for stable min).
- **Absolute positioning for layout.** Breaks with content changes. Use grid overlap (`grid-area: 1 / 1`) for stacking.
- **Nested flex wrappers to fake two-dimensional alignment.** Misaligned rows. Use grid/subgrid.
- **JS measuring heights to equalize cards.** Layout thrash, CLS. Use grid stretch or subgrid.

## Accessibility
- Visual order must match DOM order (WCAG 1.3.2 Meaningful Sequence, 2.4.3 Focus Order). `reading-flow` (Chromium-only) is not a substitute yet.
- Layouts must reflow to a single column at 320 CSS px without horizontal scrolling (WCAG 1.4.10), except content that needs 2D scrolling (data tables, maps).
- Avoid fixed heights on text containers so text spacing overrides (1.4.12) don't clip.
- `display: contents` on semantic elements (lists, buttons) had accessibility-tree bugs historically; it's safer now, but still test lists and tables with screen readers.

## Responsive Design
Prefer intrinsic grid and flex-wrap. Redefine `grid-template-areas` at page breakpoints. Use container queries for component-internal grid changes. Use `dvh`/`svh`/`lvh` for viewport-height layouts.

## Performance
- Grid/flex layout is fast. Avoid deeply nested flex containers with percentage-based heights that cause repeated layout passes.
- `content-visibility: auto` on long grid lists with `contain-intrinsic-size: auto 20rem` reduces rendering cost.
- Avoid animating `grid-template-*` on large grids (layout per frame); animate transforms instead.

## Security
No specific concerns.

## Testing
- Visual regression at 320, 768, 1280px and in RTL.
- Stress data: 0, 1, 2 and 50 items; long unbroken words/URLs; missing images.
- Keyboard walk-through to confirm focus order matches the visual layout.
- Chrome/Firefox DevTools grid and flex overlays for debugging.

## Tooling
- Browser DevTools grid/flex inspectors (Firefox's is excellent for subgrid).
- Tailwind v4 utilities: `grid-cols-[repeat(auto-fill,minmax(min(100%,15rem),1fr))]`, `grid-rows-subgrid`, `col-span-*`, `place-items-center`, `min-w-0`.
- Every Layout primitives (Sidebar, Switcher, Cluster, Grid) as reference patterns.

## Framework Notes
- **Next.js App Router:** put the app shell grid in `app/layout.tsx` (or a route-group layout) so it persists across navigations without re-render. Parallel routes (`@sidebar`, `@modal`) map neatly to grid areas. Use `100dvh` and remember `<body>` margins are reset by your reset/preflight.
- **React (Vite SPA):** same patterns. Avoid wrapper `<div>`s that break grid parent-child relationships; use fragments or `display: contents` carefully, or pass `className` through so the grid item is the component's root.
- **Component APIs:** layout components (`<Stack gap="md">`, `<Grid min="16rem">`) should map props to CSS custom properties, e.g. `style={{ "--grid-min": min }}`, rather than generating classes per value.
- **next/image in grids:** use `fill` with a sized, `position: relative` parent, or width/height + `inline-size: 100%; block-size: auto` to avoid CLS.

## AI Agent Guidance
- Do pick grid for 2D/regions and flex for 1D flows; use `gap`.
- Do add `min-inline-size: 0` / `minmax(0, 1fr)` whenever children may contain long text, code, or tables.
- Do use intrinsic `auto-fill/minmax(min(100%, X), 1fr)` before adding breakpoints.
- Don't reorder visually against DOM order; don't use `100vh` for mobile full height.
- Don't use `grid-lanes` without `@supports` fallback.
- Before done: check 320px width (no horizontal scroll), long content, RTL, and keyboard order.

## Examples
```tsx
// app/(dashboard)/layout.tsx
import styles from "./layout.module.css";

export default function DashboardLayout({ children, sidebar }: { children: React.ReactNode; sidebar: React.ReactNode }) {
  return (
    <div className={styles.shell}>
      <header className={styles.header}>…</header>
      <nav aria-label="Primary" className={styles.nav}>{sidebar}</nav>
      <main id="main" className={styles.main}>{children}</main>
    </div>
  );
}
```
```css
/* layout.module.css */
.shell {
  display: grid; min-block-size: 100dvh;
  grid-template: "header" auto "main" 1fr / minmax(0, 1fr);
}
.header { grid-area: header; position: sticky; inset-block-start: 0; z-index: 10; }
.nav { display: none; grid-area: nav; }
.main { grid-area: main; padding: var(--space-m); }
@media (width >= 64rem) {
  .shell { grid-template: "header header" auto "nav main" 1fr / 16rem minmax(0, 1fr); }
  .nav { display: block; overflow-y: auto; block-size: calc(100dvh - var(--header-h, 4rem)); position: sticky; inset-block-start: var(--header-h, 4rem); }
}
```
```tsx
// Reusable intrinsic grid primitive
type AutoGridProps = { min?: string; gap?: string; children: React.ReactNode } & React.ComponentProps<"div">;
export function AutoGrid({ min = "16rem", gap = "1rem", style, children, ...rest }: AutoGridProps) {
  return (
    <div
      {...rest}
      style={{ display: "grid", gap, gridTemplateColumns: `repeat(auto-fill, minmax(min(100%, ${min}), 1fr))`, ...style }}
    >
      {children}
    </div>
  );
}
```

## Related Skills
- [spacing-and-layout-systems](../spacing-and-layout-systems/Skill.md) — layout primitives and spacing tokens
- [container-queries](../container-queries/Skill.md) — component-level adaptation
- [responsive-design](../responsive-design/Skill.md) — overall responsive approach
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md) — direction-aware layout
- [responsive-dashboard-layouts](../responsive-dashboard-layouts/Skill.md) — dashboard grids
- [master-detail-layouts](../master-detail-layouts/Skill.md) — two-pane layouts
- [cls-prevention](../cls-prevention/Skill.md) — layout stability

## Sources
- [MDN — CSS grid layout](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_grid_layout) — Official — grid, subgrid, areas
- [MDN — Flexbox](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout) — Official — flex sizing, min-width auto
- [WebKit — When will CSS Grid Lanes arrive?](https://webkit.org/blog/17758/when-will-css-grid-lanes-arrive-how-long-until-we-can-use-it/) — Official — masonry syntax and status
- [web.dev — Interop 2026](https://web.dev/blog/interop-2026) — Official — subgrid/layout interop context
- [Every Layout](https://every-layout.dev/) — Community — intrinsic Sidebar/Switcher/Grid concepts
- [Defensive CSS](https://defensivecss.dev/) — Community (Ahmad Shadeed) — min-width, auto-fit safeguards
- [Josh W. Comeau — Interactive Guide to Grid / Flexbox](https://www.joshwcomeau.com/css/interactive-guide-to-grid/) — Community — mental models

## License / Usage Notes
MDN is CC-BY-SA. Community sources summarized in original words. Code is original.

## Quality Tier
A — Stable, well-documented layout fundamentals. Masonry status is time-sensitive.

## Status
Active

## Last Verified
2026-09-15
