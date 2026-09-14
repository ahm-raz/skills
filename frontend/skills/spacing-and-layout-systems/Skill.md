# Spacing and Layout Systems

## Summary
A spacing system is a constrained scale of space tokens (commonly a 4px base) plus composable layout primitives (Stack, Cluster, Sidebar, Switcher, Center, Grid, Cover, Frame) that make layout consistent without per-component magic numbers. This skill covers scale design, semantic spacing, density modes, the "parent owns spacing" rule, and implementing primitives as typed React components, Tailwind utilities, or CSS Modules.

## Category
CSS & Styling

## Subcategories
Spacing scale, 4pt/8pt grid, space tokens, density, layout primitives, Every Layout, gap, margin strategy, page containers, gutters, vertical rhythm

## Problem It Solves
Random values (`mt-[13px]`, `padding: 22px`), components with baked-in outer margins, inconsistent gutters, and rebuilding the same flex/grid arrangements in every component. A system makes spacing predictable and layouts reusable.

## When To Use
- Defining design tokens for spacing and sizing.
- Creating layout components for a React design system.
- Adding compact/comfortable density modes to data-heavy apps.
- Auditing inconsistent spacing.

## When Not To Use
- Grid/flex mechanics. See css-grid-and-flexbox-layout.
- Fluid clamp math. See fluid-typography-and-spacing.
- Visual design judgment about whitespace. See visual-hierarchy-and-layout.

## Core Principles
1. **Constrained scale.** Every margin/padding/gap uses a token. Base unit 4px (0.25rem) with a geometric-ish progression.
2. **Parents own spacing between children** (`gap`, stack). Components have no outer margins.
3. **Proximity communicates grouping.** Related items are closer than unrelated ones; spacing increases with hierarchy level (Gestalt proximity).
4. **Primitives compose.** A small set of layout primitives covers most layouts; components rarely write raw flex/grid.
5. **Intrinsic over breakpoint-driven.** Primitives adapt via wrapping and `min()`/`minmax()`, not device breakpoints.
6. **Density is a token swap**, not a separate component set.

## Best Practices
- Tailwind v4: `--spacing: 0.25rem` gives `p-1 = 0.25rem`, `p-4 = 1rem`, and any integer multiple (`p-13`) is allowed. Constrain usage via lint/review to your approved steps, or define named spacing tokens.
- Define semantic spacing tokens on top of the scale: `--space-inset-card`, `--space-stack-section`, `--space-gutter-page`.
- Page container: `max-inline-size` (e.g. 80rem) + `margin-inline: auto` + fluid `padding-inline`.
- Use `gap` for flex/grid; use the Stack pattern (`> * + *`) or `flex-direction: column; gap` for vertical rhythm.
- Keep touch targets ≥24×24 CSS px (WCAG 2.5.8), ideally 44×44 for primary touch actions; padding contributes.
- Implement density via a data attribute that swaps semantic tokens: `[data-density="compact"] { --space-inset-cell: .25rem .5rem; }`.
- Use logical properties (`padding-inline`, `margin-block`) for RTL.
- Align icon + text with `gap` and `align-items: center`, not margins on icons.

## Implementation Guidance

### Scale (4px base)
| Token | rem | px | Typical use |
|---|---|---|---|
| space-0.5 | 0.125 | 2 | Hairline adjustments |
| space-1 | 0.25 | 4 | Icon-text gap (tight) |
| space-2 | 0.5 | 8 | Inline gaps, compact padding |
| space-3 | 0.75 | 12 | Input padding, small stacks |
| space-4 | 1 | 16 | Default gap, card padding (compact) |
| space-6 | 1.5 | 24 | Card padding, form field stacks |
| space-8 | 2 | 32 | Group separation |
| space-12 | 3 | 48 | Section gaps (app) |
| space-16 | 4 | 64 | Section gaps (marketing) |
| space-24 | 6 | 96 | Hero/section padding |

### Layout primitives
| Primitive | Purpose | Core CSS |
|---|---|---|
| Stack | Vertical rhythm | `display:flex; flex-direction:column; gap:var(--gap)` |
| Cluster | Wrapping inline group (tags, buttons) | `display:flex; flex-wrap:wrap; gap; align-items:center` |
| Inline/Split | Row with ends pushed apart | `display:flex; justify-content:space-between; align-items:center` |
| Center | Centered max-width column | `box-sizing:content-box; max-inline-size; margin-inline:auto; padding-inline` |
| Sidebar | Fixed-ish side + fluid main, wraps when narrow | flex-wrap + `flex-basis` + `flex-grow:999; min-inline-size:50%` |
| Switcher | Row → column when container < threshold | `flex-basis: calc((var(--threshold) - 100%) * 999)` |
| Grid | Auto-fill responsive grid | `grid-template-columns: repeat(auto-fill, minmax(min(100%, var(--min)), 1fr))` |
| Cover | Vertically centered principal element with header/footer | `display:flex; flex-direction:column; min-block-size:100dvh` + `margin-block:auto` |
| Frame | Aspect-ratio media crop | `aspect-ratio; overflow:hidden; > img {object-fit:cover}` |
| Box | Padding + border container | `padding:var(--inset); border` |

### Decision rules
- Space inside a component (padding) comes from component/semantic tokens.
- Space between components comes from the parent primitive's `gap`.
- Space between page sections comes from the page layout / section component.
- One-off exceptions: use a scale token in a utility class, never a raw value.

## Recommended Workflow
1. Agree base unit and scale steps with design; mirror Figma spacing variables.
2. Create tokens (Tailwind `--spacing` + named semantic tokens, or CSS variables).
3. Build primitives (Stack, Cluster, Sidebar, Switcher, Grid, Center) as components.
4. Refactor components to remove outer margins; wrap usages in primitives.
5. Add density tokens and a toggle if needed.
6. Enforce with lint (ban arbitrary spacing values) and review checklist.

## Patterns
**Switcher (container-agnostic row/column)**
```css
.switcher { display: flex; flex-wrap: wrap; gap: var(--gap, 1rem); }
.switcher > * { flex-grow: 1; flex-basis: calc((var(--threshold, 40rem) - 100%) * 999); }
```

**Center with gutters**
```css
.center { box-sizing: content-box; max-inline-size: var(--measure, 80rem); margin-inline: auto; padding-inline: var(--gutter, clamp(1rem, 4vw, 2rem)); }
```

**Density tokens**
```css
:root { --space-inset-cell: .75rem 1rem; --space-stack-form: 1.5rem; --control-h: 2.5rem; }
[data-density="compact"] { --space-inset-cell: .375rem .5rem; --space-stack-form: 1rem; --control-h: 2rem; }
```

**Tailwind semantic spacing names**
```css
@theme {
  --spacing: 0.25rem;
  --spacing-gutter: clamp(1rem, 0.5rem + 2vw, 2rem);
  --spacing-section: clamp(3rem, 2rem + 4vw, 6rem);
}
```
Usage: `px-gutter py-section gap-6`.

## Anti-Patterns
- **Outer margins on reusable components (`.card { margin-bottom: 24px }`).** Breaks in grids/stacks. Remove them; parent `gap`.
- **Arbitrary values (`mt-[13px]`, `gap: 18px`).** Drift. Use scale tokens.
- **Spacer `<div>`s / `<br>`.** Semantic noise, fragile. Use `gap`/stack.
- **Margin collapsing surprises used intentionally.** Hard to reason about. Use flex/grid gap.
- **Media queries for every spacing change.** Bloat. Use fluid tokens or container-aware primitives.
- **Separate "compact" components.** Duplication. Use density tokens.
- **`space-y-*` inside flex/grid (Tailwind).** Changed selector in v4 and ignores wrapping. Use `gap-*`.

## Accessibility
- Target size: WCAG 2.5.8 (AA) 24×24 CSS px minimum or sufficient spacing; spacing between small targets counts.
- Text spacing overrides (1.4.12) must not cause overlap. Avoid fixed heights, use min-heights.
- Reflow (1.4.10): primitives must collapse to one column at 320px.
- Compact density must keep targets and focus outlines intact (outline-offset needs room; avoid `overflow: hidden` clipping focus rings).

## Responsive Design
Use fluid gutter/section tokens (`clamp`) and intrinsic primitives (Sidebar, Switcher, Grid) so layouts adapt without breakpoints. Container queries adjust component-internal spacing where needed.

## Performance
Primitives are static CSS, so there's no runtime cost. Avoid deeply nested wrapper components that bloat the DOM; allow primitives to render `as` semantic elements (`ul`, `nav`, `section`).

## Security
No specific concerns.

## Testing
- Storybook stories for each primitive with many/few/long children and at multiple container widths.
- Visual regression for density modes.
- Lint: `eslint-plugin-better-tailwindcss` or custom rule to forbid arbitrary spacing; stylelint `declaration-property-value-allowed-list` for spacing props requiring `var(--space-*)`.

## Tooling
- Tailwind v4 spacing scale. Official.
- Every Layout primitives. Community reference (book/site).
- Figma variables → Style Dictionary/Terrazzo tokens pipeline.
- Radix Themes / Braid / Chakra `Stack`/`Flex` as reference implementations of primitives.

## Framework Notes
- **Next.js App Router:** layout primitives are ideal Server Components (no state). Keep them in `components/layout/`. Use them in `layout.tsx` for page containers and section spacing. Parallel route slots can sit inside `Sidebar`/`Switcher` primitives.
- **React (Vite SPA):** same components. Ensure they forward refs (React 19: `ref` as a prop) and accept `as` for semantics.
- **Polymorphic typing:** use `React.ComponentPropsWithoutRef<T>` with an `as` generic, or use Radix `Slot` (`asChild`) to avoid wrapper divs.

## AI Agent Guidance
- Do use existing primitives (`Stack`, `Cluster`, etc.) or `gap` utilities; don't add margins to reusable components.
- Do use scale tokens only; no arbitrary spacing values.
- Do render primitives as semantic elements where appropriate (`as="ul"`).
- Don't add spacer divs or `space-y-*` in flex/grid.
- Before done: check narrow (320px) and wide layouts, compact density if present, and that focus outlines aren't clipped.

## Examples
```tsx
// components/layout/Stack.tsx
type Gap = 1 | 2 | 3 | 4 | 6 | 8 | 12 | 16;
const gapClass: Record<Gap, string> = { 1: "gap-1", 2: "gap-2", 3: "gap-3", 4: "gap-4", 6: "gap-6", 8: "gap-8", 12: "gap-12", 16: "gap-16" };

type StackProps<T extends React.ElementType> = { as?: T; gap?: Gap; align?: "start" | "center" | "stretch" } &
  Omit<React.ComponentPropsWithoutRef<T>, "as">;

export function Stack<T extends React.ElementType = "div">({ as, gap = 4, align = "stretch", className = "", ...rest }: StackProps<T>) {
  const Comp = as ?? "div";
  const alignClass = { start: "items-start", center: "items-center", stretch: "items-stretch" }[align];
  return <Comp className={`flex flex-col ${gapClass[gap]} ${alignClass} ${className}`} {...rest} />;
}
```
```tsx
// components/layout/Sidebar.tsx — intrinsic sidebar, no media queries
export function WithSidebar({ side, children, sideWidth = "18rem", contentMin = "55%" }:
  { side: React.ReactNode; children: React.ReactNode; sideWidth?: string; contentMin?: string }) {
  return (
    <div className="flex flex-wrap gap-6">
      <aside className="grow" style={{ flexBasis: sideWidth }}>{side}</aside>
      <div className="grow-[999] basis-0" style={{ minInlineSize: contentMin }}>{children}</div>
    </div>
  );
}
```
```tsx
// app/settings/page.tsx
import { Stack } from "@/components/layout/Stack";
import { WithSidebar } from "@/components/layout/Sidebar";

export default function SettingsPage() {
  return (
    <div className="mx-auto max-w-7xl px-gutter py-section">
      <WithSidebar side={<nav aria-label="Settings">…</nav>}>
        <Stack as="section" gap={8} aria-labelledby="profile-h">
          <h1 id="profile-h" className="text-heading-lg">Profile</h1>
          <Stack as="form" gap={6}>…</Stack>
        </Stack>
      </WithSidebar>
    </div>
  );
}
```

## Related Skills
- [css-grid-and-flexbox-layout](../css-grid-and-flexbox-layout/Skill.md) — underlying layout mechanics
- [fluid-typography-and-spacing](../fluid-typography-and-spacing/Skill.md) — fluid space tokens
- [design-token-architecture](../design-token-architecture/Skill.md) — spacing token tiers
- [visual-hierarchy-and-layout](../visual-hierarchy-and-layout/Skill.md) — whitespace and grouping judgment
- [dense-form-screens](../dense-form-screens/Skill.md) — compact density needs
- [component-api-design](../component-api-design/Skill.md) — polymorphic primitive APIs
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — target sizes

## Sources
- [Every Layout](https://every-layout.dev/) — Community (Pickering & Bell) — Stack, Cluster, Sidebar, Switcher, Center, Cover, Frame primitives
- [CUBE CSS](https://cube.fyi/) — Community — composition layer concept
- [Tailwind CSS — Theme variables (--spacing)](https://tailwindcss.com/docs/theme) — Official — spacing namespace
- [Utopia — space calculator](https://utopia.fyi/space/calculator/) — Community — space pairs
- [W3C — Understanding SC 2.5.8 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) — Official — 24px targets
- [Defensive CSS](https://defensivecss.dev/) — Community (Ahmad Shadeed) — spacing safeguards
- [Material Design 3 — Layout spacing](https://m3.material.io/foundations/layout/understanding-layout/spacing) — Official — 4dp grid rationale

## License / Usage Notes
Every Layout concepts are summarized in original words, and the primitive CSS shown is independently written. Tailwind is MIT. W3C documents are under the W3C license.

## Quality Tier
A — Well-established practice with official accessibility criteria. Scale values are recommendations.

## Status
Active

## Last Verified
2026-09-15
