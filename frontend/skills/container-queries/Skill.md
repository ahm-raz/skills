# Container Queries

## Summary
Container queries let a component adapt to the size of its container, or to custom-property "style" values set on it, instead of the viewport. Size queries and `cq*` units are Baseline Widely available. Style queries on custom properties became Baseline Newly available in May 2026 (Firefox 151). They are the default tool for reusable, responsive React components in 2026.

## Category
CSS & Styling

## Subcategories
@container, container-type, container-name, cqi/cqb units, style queries, name-only queries, Tailwind @container variants, component-level responsiveness

## Problem It Solves
A card component designed with viewport media queries breaks when placed in a sidebar, a modal, a dashboard tile, or a multi-column grid. Container queries make the component's layout depend on the space it actually has, so one component works in every slot.

## When To Use
- Reusable components rendered in slots of varying widths (cards, media objects, product tiles, table cells, dashboard widgets).
- Design-system components that must not know about page breakpoints.
- Theme/variant switching by a parent's custom property (`@container style(--variant: compact)`).
- Fluid sizing relative to a component (`font-size: clamp(1rem, 4cqi, 2rem)`).

## When Not To Use
- Page-level layout (header nav collapse, overall grid). Use viewport media queries.
- User preferences (`prefers-color-scheme`, `prefers-reduced-motion`, `hover`, `pointer`). Those are media features.
- Intrinsic layouts already solve it (`flex-wrap`, `repeat(auto-fit, minmax())`). Don't add queries unnecessarily.
- Style queries on standard properties (`style(display: flex)`). Unsupported in every engine.

## Core Principles
1. **A container can't query itself.** Styles inside `@container` apply to descendants of the container, never to the container element itself. Add a wrapper.
2. **`container-type: inline-size` is the default choice.** `size` needs an explicit block size (height) or it collapses.
3. **Containment has side effects.** `inline-size` applies size containment on the inline axis, so the container no longer sizes from its content's width (shrink-to-fit parents like `inline-flex` or floats can collapse to 0).
4. **Name containers in libraries.** Unnamed queries hit the nearest ancestor container, which may be a different component. Names make intent explicit.
5. **Query ranges, not devices.** Use content-driven thresholds in `rem`/`em` (`inline-size >= 30rem`).

## Best Practices
- Put `container: card / inline-size;` on a component's outer wrapper and query it from inner elements.
- Use modern range syntax: `@container card (inline-size >= 36rem)`, and `(20rem <= inline-size < 36rem)` for bands.
- Use `cqi` (inline) over `cqw` for writing-mode safety. Clamp fluid values: `clamp(1rem, 0.5rem + 3cqi, 1.75rem)`.
- Use style queries for parent-driven variants without prop drilling: parent sets `--density: compact`, children query `@container style(--density: compact)`.
- Register custom properties used in style queries with `@property` only if you need a typed initial value. Unregistered custom properties also work.
- In Tailwind v4, use `@container` + `@md:` etc. Name with `@container/card` + `@lg/card:`. Use `@container-size` (v4.3) for block-size queries.
- Keep a sensible default layout (narrowest) outside any query: mobile-first inside components.

## Implementation Guidance

### Syntax reference
```css
.card-wrap { container-type: inline-size; container-name: card; }  /* or shorthand */
.card-wrap { container: card / inline-size; }

@container card (inline-size >= 30rem) { .card { grid-template-columns: 10rem 1fr; } }
@container (width > 45rem) and (orientation: landscape) { /* nearest size container */ }

/* Style query: custom properties only (Baseline Newly available May 2026) */
.panel { --tone: danger; }
@container style(--tone: danger) { .panel-title { color: var(--color-danger); } }

/* Name-only query (Chrome 148, reported Baseline Newly available May 2026 — verify before relying) */
@container sidebar { .nav-label { display: none; } }

/* Units */
.title { font-size: clamp(1.125rem, 0.75rem + 2.5cqi, 2rem); }
```

### Units
| Unit | Meaning |
|---|---|
| `cqi` / `cqb` | 1% of container inline / block size |
| `cqw` / `cqh` | 1% of container width / height |
| `cqmin` / `cqmax` | smaller / larger of cqi and cqb |

Without an eligible ancestor container, `cq*` units fall back to the small viewport units.

### Container vs media query decision
| Question | Tool |
|---|---|
| Does the component's own slot width determine layout? | Container size query |
| Does a parent choose a variant/theme for a subtree? | Container style query (or data attribute) |
| Is it page shell structure (nav/sidebar visibility)? | Media query |
| Is it a user/device preference? | Media query (`prefers-*`, `hover`, `pointer`) |
| Can wrapping/auto-fit solve it with no breakpoints? | Intrinsic layout, no query |

### Style query vs data attribute
Style queries inherit through the tree and can be set from CSS (including inside other queries). Data attributes are explicit in markup and have broader support. Choose style queries when the variant is a CSS concern that cascades (density, surface tone); choose data attributes when React state already owns it.

## Recommended Workflow
1. Design the component at its narrowest supported width first.
2. Identify the slot widths where layout should change (measure content, not devices).
3. Add a wrapper with `container: <name> / inline-size`.
4. Add `@container <name> (...)` rules for wider layouts.
5. Place the component in every real slot (sidebar, main, modal, grid) in Storybook and verify.
6. Replace any JS `ResizeObserver` breakpoint logic with the query.

## Patterns
**Self-contained responsive card (CSS Module)**
```css
.root { container: card / inline-size; }
.card { display: grid; gap: var(--space-s); }
.media { aspect-ratio: 16/9; }
@container card (inline-size >= 32rem) {
  .card { grid-template-columns: minmax(10rem, 1fr) 2fr; align-items: start; }
  .media { aspect-ratio: 1; }
}
```

**Density via style query**
```css
.table-region { container-name: region; }
.table-region[data-density="compact"] { --density: compact; }
@container region style(--density: compact) { .cell { padding-block: 0.25rem; font-size: var(--text-sm); } }
```

**Tailwind v4 named container**
```tsx
<section className="@container/widget rounded-lg border p-4">
  <div className="flex flex-col gap-3 @md/widget:flex-row @md/widget:items-center">
    <h3 className="text-base @lg/widget:text-lg">Revenue</h3>
    <Stat className="@max-xs/widget:hidden" />
  </div>
</section>
```

**Fluid component typography**
```css
.hero { container-type: inline-size; }
.hero h1 { font-size: clamp(2rem, 1rem + 5cqi, 4.5rem); }
```

## Anti-Patterns
- **Querying the element that has `container-type`.** Rules never match. Query from children, or add a wrapper.
- **`container-type: size` on auto-height elements.** The element collapses to 0 height. Use `inline-size` unless the block size is explicit.
- **`container-type` on a shrink-to-fit element (`display: inline-block`, flex item with `flex: none`, `width: max-content`).** Width collapses. Give it a definite width or put containment on a block-level parent.
- **Setting `container-type` on every element "just in case".** Unnecessary containment affects layout and performance. Use it only where queried.
- **Unnamed queries in shared components.** They match an unexpected ancestor. Name the container.
- **`style(color: red)` or other standard-property style queries.** Not supported. Use custom properties.
- **Pure `cqi` font sizes (`font-size: 5cqi`).** Won't scale with user zoom. Always combine with `rem` inside `clamp()`.

## Accessibility
- Fluid type via `cq*` must include a `rem` component so text zooms (WCAG 1.4.4 Resize Text). Test at 200% zoom.
- Don't hide essential content at narrow container widths. Reflow it (WCAG 1.4.10 Reflow at 320 CSS px).
- Visual reordering via grid inside queries must not break reading/focus order (WCAG 1.3.2, 2.4.3). Keep DOM order logical.
- Container-driven hiding (`display:none`) removes content from assistive tech. Make sure an equivalent remains available.

## Responsive Design
Container queries complement viewport queries: page shell by media query, components by container query. Combined with intrinsic grid (`auto-fit/minmax`), most components need zero viewport breakpoints. Zoom increases `rem`-based thresholds' effective size, so rem-based container thresholds respond naturally to zoom.

## Performance
- Size containment is cheap and can improve layout isolation. Avoid it on huge numbers of tiny elements.
- Browsers resolve container queries during layout, which avoids ResizeObserver → setState → re-render loops that hurt INP and cause layout thrash in React.
- No hydration or JS needed, so it works in Server Components.

## Security
No specific concerns. Avoid putting untrusted values into custom properties used by style queries that feed `url()`.

## Testing
- Storybook: render components inside decorators of different widths (e.g. 280px, 480px, 800px) and snapshot each.
- Playwright: set the parent width via a test harness page (not just viewport) and assert computed styles or screenshots.
- Test in WebKit and Gecko for style queries (newest support).

## Tooling
- Native CSS. Tailwind v4 built-in `@container`/`@container-size` variants (plugin `@tailwindcss/container-queries` is obsolete).
- Chrome DevTools shows container badges and lets you jump to the queried container.
- `container-query-polyfill` (GoogleChromeLabs) is no longer needed for evergreen targets. Deprecated for new work.
- Stylelint supports the range syntax in recent versions.

## Framework Notes
- **Next.js App Router:** container queries are pure CSS, so responsive Server Components need no `'use client'` and no `useMediaQuery` hook, and there's no hydration mismatch from server/client width guesses. Prefer them over JS width detection in shared components.
- **React (Vite SPA):** replace `useResizeObserver` + conditional rendering with CSS queries when only presentation changes. Keep JS measurement only when you must render different component trees (e.g. a chart library needing pixel width); then debounce and use `useSyncExternalStore`.
- **Component APIs:** expose `containerName` only if consumers must query it; otherwise keep containers internal. Don't accept breakpoint props like `isMobile`. Let CSS decide.
- **CSS Modules / Tailwind / vanilla-extract / StyleX:** all support container queries (`@container` keys in style objects for vanilla-extract/StyleX).

## AI Agent Guidance
- Do default to container queries for reusable components and media queries for page shell.
- Do add a wrapper element with `container: name / inline-size` and query from children.
- Do use range syntax and rem thresholds; combine `cqi` with `rem` in `clamp()`.
- Don't query the container element itself; don't use `container-type: size` without a height.
- Don't write `isMobile` JS hooks for layout changes CSS can handle.
- Before done: verify the component in at least three container widths, in Firefox and Safari, and at 200% zoom.

## Examples
```tsx
// app/components/ProductTile.tsx (Server Component)
import Image from "next/image";
import styles from "./ProductTile.module.css";

type Product = { name: string; price: string; image: string; alt: string };

export function ProductTile({ product, density }: { product: Product; density?: "compact" }) {
  return (
    <div className={styles.root} data-density={density}>
      <article className={styles.tile}>
        <Image className={styles.media} src={product.image} alt={product.alt} width={600} height={600}
               sizes="(min-width: 64rem) 25vw, (min-width: 40rem) 50vw, 100vw" />
        <div className={styles.body}>
          <h3 className={styles.name}>{product.name}</h3>
          <p className={styles.price}>{product.price}</p>
        </div>
      </article>
    </div>
  );
}
```
```css
/* ProductTile.module.css */
.root { container: tile / inline-size; }
.root[data-density="compact"] { --density: compact; }
.tile { display: grid; gap: .75rem; }
.media { inline-size: 100%; block-size: auto; border-radius: .5rem; }
.name { font-size: clamp(1rem, .85rem + 1.2cqi, 1.375rem); text-wrap: balance; }
@container tile (inline-size >= 28rem) {
  .tile { grid-template-columns: 9rem 1fr; align-items: center; }
}
@container tile style(--density: compact) {
  .tile { gap: .375rem; }
  .price { font-size: .875rem; }
}
```

## Related Skills
- [responsive-design](../responsive-design/Skill.md) — overall responsive strategy
- [css-grid-and-flexbox-layout](../css-grid-and-flexbox-layout/Skill.md) — intrinsic layouts that pair with queries
- [fluid-typography-and-spacing](../fluid-typography-and-spacing/Skill.md) — cqi-based fluid values
- [modern-css-features](../modern-css-features/Skill.md) — support status context
- [responsive-dashboard-layouts](../responsive-dashboard-layouts/Skill.md) — widgets in variable slots
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — @container variants

## Sources
- [MDN — Container size and style queries](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Containment/Container_size_and_style_queries) — Official — syntax, style query limits
- [web.dev — New to the web platform in May 2026](https://web.dev/blog/web-platform-05-2026) — Official — Firefox 151 style queries, name-only queries
- [web.dev — Interop 2026](https://web.dev/blog/interop-2026) — Official — style queries as focus area
- [Tailwind CSS — Responsive design (container queries)](https://tailwindcss.com/docs/responsive-design) — Official — @container variants, named containers
- [Tailwind CSS v4.3 blog](https://tailwindcss.com/blog/tailwindcss-v4-3) — Official — @container-size
- [LogRocket — Container queries in 2026](https://blog.logrocket.com/container-queries-2026/) — Community — practical caveats
- [MDN content PR #45709 — style queries custom properties only](https://github.com/mdn/content/pull/45709) — Open Source — confirmation of limitation

## License / Usage Notes
MDN content is CC-BY-SA and web.dev is CC-BY 4.0. Content is summarized, and examples are original.

## Quality Tier
S — Official specs/docs with fresh 2026 support confirmation and complete React/Next.js guidance.

## Status
Active

## Last Verified
2026-09-15
