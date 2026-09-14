# CSS Architecture

## Summary
How to organize CSS for a codebase so it stays predictable as it grows. That means file and layer structure, a naming or scoping strategy, and a choice between methodologies (CUBE CSS, BEM, utility-first, scoped/module CSS). Modern native features (`@layer`, `@scope`, nesting, custom properties) now replace most of the specificity hacks that old methodologies existed to avoid.

## Category
CSS & Styling

## Subcategories
CUBE CSS, BEM, ITCSS, utility-first, Every Layout primitives, CSS reset, defensive CSS, file organization, style ownership

## Problem It Solves
Unstructured CSS grows into specificity wars, `!important` chains, dead code nobody dares delete, and components that break when moved. A deliberate architecture gives every rule a predictable home, a predictable priority, and an owner.

## When To Use
- Starting a project or design system and choosing a styling strategy.
- Refactoring a legacy stylesheet with specificity/override problems.
- Mixing approaches (Tailwind + component CSS + third-party library CSS) and needing an ordering contract.
- Writing agent rules for how styles should be authored in a repo.

## When Not To Use
- One-page prototypes. Just write CSS.
- Tailwind-only codebases where the question is theme tokens rather than architecture. See tailwind-design-system-architecture.
- Picking a CSS-in-JS library. See css-in-js-and-zero-runtime.

## Core Principles
1. **Work with the cascade, not against it.** Global defaults and inheritance do most of the work. Components handle exceptions (CUBE CSS philosophy).
2. **Explicit priority via `@layer`.** Order is declared once (`reset, base, layout, components, utilities, overrides`). Specificity only matters within a layer.
3. **Low, flat specificity.** Single class selectors; `:where()` for zero-specificity defaults; no IDs; no `!important` except in a top utility/override layer.
4. **Composition over component bloat.** Layout primitives (stack, cluster, sidebar, switcher) handle arrangement. Components handle identity.
5. **Tokens over literals.** Every color, space, radius, font size and shadow comes from a custom property or theme token.
6. **Colocate and scope component styles.** CSS Modules, `@scope`, framework-scoped styles, or utilities. Styles live and die with the component.
7. **Defensive by default.** Assume content is longer, shorter, missing, or translated.

## Best Practices
- Declare the layer order in the very first stylesheet: `@layer reset, tokens, base, layouts, components, utilities;`.
- Import third-party CSS into a named low layer: `@import url("lib.css") layer(vendor);`.
- Keep the global base small: element defaults, typography, focus styles, `color-scheme`.
- Use a modern reset (Josh Comeau / Andy Bell style): `box-sizing: border-box`, margin reset, `line-height` ~1.5 for body, media `display:block; max-inline-size:100%`, form controls `font: inherit`, `overflow-wrap: break-word`, `text-wrap: balance/pretty`, `isolation: isolate` on the app root.
- Express component variants with data attributes or modifier classes (`[data-variant="primary"]`, `.btn--primary`), not deeper selectors.
- Use `gap` in flex/grid instead of margins between siblings. Use the "stack" pattern (`> * + *`) only for flow content.
- Name by purpose, not appearance (`.alert-danger`, not `.red-box`).
- Delete-safe CSS: if a component is removed, its styles go with it (colocated files).
- Document the architecture in the repo's AGENTS.md / CLAUDE.md so agents follow it.

## Implementation Guidance

### Methodology decision table
| Situation | Recommended approach |
|---|---|
| Next.js / React app, speed of iteration, team fluent in utilities | Tailwind v4 utilities + small `@layer components` + tokens in `@theme` |
| Next.js / React app, team prefers authoring CSS | CSS Modules + global tokens/base + layout primitives (RSC-safe, zero runtime) |
| Shared React component library consumed by many Next.js apps | CSS Modules or zero-runtime CSS-in-JS (vanilla-extract/StyleX) with token contracts, shipped in a named `@layer` |
| Content-heavy Next.js sites (MDX blogs, docs) | CUBE CSS: global flow typography (or `@tailwindcss/typography`) + composition primitives + small blocks |
| Legacy codebase with specificity chaos | Wrap legacy in `@layer legacy`, write new code in higher layers, migrate incrementally |
| Multi-team Next.js multi-zones / micro-frontends | Scoped styles (CSS Modules / `@scope`) + shared token package; no global element styles from remotes |

### Folder structure (vanilla / CSS Modules)
```
styles/
  index.css          # @layer order + @imports
  reset.css          # layer(reset)
  tokens.css         # layer(tokens) — custom properties
  base.css           # layer(base) — element defaults, typography
  layouts/           # layer(layouts) — stack, cluster, sidebar, switcher, grid
  utilities.css      # layer(utilities) — visually-hidden, flow, text-balance
components/
  Button/Button.tsx
  Button/Button.module.css   # component-owned, scoped
```

```css
/* styles/index.css */
@layer reset, vendor, tokens, base, layouts, components, utilities, overrides;
@import url("./reset.css") layer(reset);
@import url("./tokens.css") layer(tokens);
@import url("./base.css") layer(base);
@import url("./layouts/index.css") layer(layouts);
@import url("./utilities.css") layer(utilities);
```

### CUBE CSS in brief
- **Composition:** layout skeleton, e.g. `.flow`, `.cluster`, `.wrapper`, `.grid`.
- **Utility:** single-job classes, often token-generated (`.text-step-2`, `.bg-primary`).
- **Block:** component-specific styles, kept small because composition and utilities did the heavy lifting.
- **Exception:** state/variant via data attributes: `.card[data-state="reversed"]`.
- Grouping in markup: `class="[ card ] [ flow ] [ bg-surface radius-m ]"` (brackets are optional readability aids).

### Every Layout primitives (intrinsic layout)
Stack (vertical rhythm), Box (padding/border), Center (max-width + auto margins), Cluster (wrapping inline group), Sidebar (fixed + fluid sibling that wraps), Switcher (row to column at a container threshold), Cover (vertically centered hero), Grid (auto-fill minmax), Frame (aspect-ratio media), Reel (horizontal scroller), Imposter (overlay centering), Icon (text-relative icon sizing).

## Recommended Workflow
1. Define the tokens (color, space, type, radius, shadow, motion).
2. Declare the layer order and wire third-party CSS into low layers.
3. Write reset + base (element typography, links, focus, forms).
4. Build layout primitives before components.
5. Build components with scoped styles that consume tokens. Variants use data attributes.
6. Add utilities for one-off adjustments. Keep an `overrides` layer for rare escapes.
7. Add stylelint rules (no IDs, max specificity, no `!important` outside utilities, token-only colors).
8. Review regularly: unused CSS, duplicated values that should be tokens.

## Patterns
**Stack (flow spacing)**
```css
.flow > * + * { margin-block-start: var(--flow-space, 1em); }
```

**Cluster**
```css
.cluster { display: flex; flex-wrap: wrap; gap: var(--gutter, var(--space-s)); align-items: center; }
```

**Sidebar (no media query)**
```css
.with-sidebar { display: flex; flex-wrap: wrap; gap: var(--space-m); }
.with-sidebar > :first-child { flex-basis: 20rem; flex-grow: 1; }
.with-sidebar > :last-child { flex-basis: 0; flex-grow: 999; min-inline-size: 60%; }
```

**Zero-specificity defaults for libraries**
```css
:where(.ds-button) { padding: var(--space-xs) var(--space-s); }
```

**Defensive CSS snippets (Ahmad Shadeed)**
```css
.flex-item { min-inline-size: 0; }                /* allow text truncation in flex */
.grid { grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr)); }
img { max-inline-size: 100%; block-size: auto; object-fit: cover; }
.title { overflow-wrap: anywhere; }
.bg { background-repeat: no-repeat; }
.scroller { overscroll-behavior: contain; scrollbar-gutter: stable; }
```

## Anti-Patterns
- **Specificity escalation (`.page .sidebar .nav ul li a`).** Brittle and order-dependent. Use a single class and `@layer`.
- **`!important` to win fights.** Hides the real ordering problem. Move the rule to the right layer. Reserve `!important` for utilities/accessibility overrides.
- **BEM concatenation expectations in native nesting (`&__elem`).** Invalid in native CSS. Write the full class name, or use a preprocessor/CSS Modules.
- **Global styles from components.** A component that styles `h2` globally breaks others. Scope it.
- **Margins on reusable components.** They can't be reused in other contexts. The parent/layout controls spacing (`gap`, `.flow`).
- **Magic numbers (`top: 37px`).** They break with content/font changes. Use tokens, intrinsic sizing, grid alignment.
- **One giant `styles.css` with no ownership.** Dead code accumulates. Colocate component CSS.
- **Mixing 3+ styling systems without layer contracts.** Unpredictable overrides. Pick a primary system; put others in declared layers.

## Accessibility
- Base layer must include visible `:focus-visible` styles (WCAG 2.4.7) and never `outline: none` without a replacement.
- Keep a `.visually-hidden` utility for screen-reader-only text.
- Respect `prefers-reduced-motion`, `prefers-contrast`, and `forced-colors` in the base layer. Test Windows High Contrast (use `outline` or transparent borders so boundaries survive forced colors).
- Line-height ≥1.5 for body and room for text-spacing overrides (WCAG 1.4.12). Avoid fixed heights on text containers.

## Responsive Design
Prefer intrinsic layouts (flex-wrap, auto-fit grids, `clamp()`) and container queries so components adapt anywhere. Reserve viewport media queries for page-level structure. Architecture should place responsive logic inside the component or layout primitive that owns it.

## Performance
- Fewer, flatter selectors are cheaper to match. Avoid universal descendant selectors in hot paths.
- Critical CSS: global base + above-the-fold layout should ship in the first stylesheet. Component CSS can be split per route (CSS Modules/bundlers do this automatically).
- Purge/tree-shake unused CSS (Tailwind does it by design; for vanilla, audit with Chrome DevTools Coverage).
- `@import` in production CSS without bundling causes serial requests. Bundle it.

## Security
- Never interpolate untrusted input into CSS (class names, style attributes, custom properties with `url()`).
- Third-party CSS can restyle and hide UI (clickjacking-style deception). Load it from trusted sources with SRI and constrain it via CSP `style-src`.

## Testing
- Visual regression (Playwright screenshots, Chromatic) for layout primitives and components across themes and viewports.
- Stylelint in CI: `selector-max-specificity`, `declaration-no-important`, `selector-max-id: 0`, `color-no-hex` (force tokens), `stylelint-order`.
- Stress tests: long strings, RTL, 200% zoom, missing images, empty states.

## Tooling
- **Stylelint** (+ `stylelint-config-standard`), Active.
- **Lightning CSS / PostCSS.** Bundling, nesting downlevel, autoprefixing.
- **Chrome DevTools.** Layers pane, Coverage tab, CSS overview.
- **Every Layout** (layout primitives reference), **CUBE CSS** (methodology), **Defensive CSS** (patterns).
- **Sass.** Still maintained, but native nesting, custom properties and color functions cover most needs. `@import` in Sass is deprecated in favor of `@use`.

## Framework Notes
- **Next.js (App Router):** import the global entry (`app/globals.css` containing the `@layer` order, reset, tokens, base) once in `app/layout.tsx`. Component styles come from CSS Modules (`*.module.css`, works in Server Components) or Tailwind v4. Next.js can reorder CSS chunks between dev and production and across routes, so rely on `@layer` + low specificity, never on import order. Avoid runtime CSS-in-JS (styled-components/Emotion) in RSC trees, because it forces `'use client'` and style registries.
- **React (Vite SPA):** import `src/styles/index.css` in `main.tsx`; use `*.module.css` or Tailwind via `@tailwindcss/vite`. Vite preserves import order in dev but code-split CSS can still arrive in different orders. Layers solve it.
- **Component APIs:** accept `className` and merge (`clsx`/`cn`), and expose variants as typed props that map to `data-*` attributes. Never let consumers pass arbitrary style objects for design values.
- **Third-party React libraries' CSS** (e.g. `react-day-picker/style.css`): import via `@import url("react-day-picker/style.css") layer(vendor);` in the global CSS rather than in a component, so it sits in a low layer.

## AI Agent Guidance
- Do read existing styling conventions (AGENTS.md, stylelint config, existing components) before adding CSS. Match the established system.
- Do use tokens/custom properties, never hard-coded hex/px for design values.
- Do put new rules in the correct layer. Never add `!important` to fix an override; find the layer/specificity cause.
- Don't introduce a new styling paradigm (e.g. styled-components into a Tailwind repo).
- Don't add margins to reusable components; use `gap` in the parent.
- Before done: no new stylelint errors, no specificity > (0,2,0) in components, verified at narrow width, long content, dark theme, and 200% zoom.

## Examples
```css
/* tokens.css */
@layer tokens {
  :root {
    --space-xs: .5rem; --space-s: 1rem; --space-m: 1.5rem; --space-l: 2.5rem;
    --radius-m: .5rem;
    --color-surface: light-dark(oklch(99% 0 0), oklch(20% .01 260));
    --color-text: light-dark(oklch(22% .02 260), oklch(94% .01 260));
    --color-primary: oklch(55% .15 260);
  }
}

/* components/card.css */
@layer components {
  .card {
    display: grid; gap: var(--space-s); padding: var(--space-m);
    background: var(--color-surface); border-radius: var(--radius-m);
  }
  .card[data-variant="featured"] { border: 2px solid var(--color-primary); }
}
```
```tsx
// app/components/Card.tsx — Server Component using global layout primitives + component layer
import Link from "next/link";

type CardProps = { title: string; href: string; featured?: boolean; children: React.ReactNode };

export function Card({ title, href, featured, children }: CardProps) {
  return (
    <article className="card flow" data-variant={featured ? "featured" : undefined}>
      <h2>{title}</h2>
      {children}
      <div className="cluster">
        <Link href={href}>Read</Link>
        <Link href={`${href}#share`}>Share</Link>
      </div>
    </article>
  );
}
```
```tsx
// app/layout.tsx — the single global entry declares layer order, tokens, base, primitives
import "./styles/index.css";
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (<html lang="en"><body>{children}</body></html>);
}
```

## Related Skills
- [css-cascade-layers-and-specificity](../css-cascade-layers-and-specificity/Skill.md) — layer mechanics
- [css-nesting-and-scope](../css-nesting-and-scope/Skill.md) — native scoping
- [css-modules](../css-modules/Skill.md) — build-time scoping
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — utility-first alternative
- [spacing-and-layout-systems](../spacing-and-layout-systems/Skill.md) — layout primitives and tokens
- [design-token-architecture](../design-token-architecture/Skill.md) — token tiers
- [linting-and-formatting](../linting-and-formatting/Skill.md) — stylelint setup

## Sources
- [CUBE CSS](https://cube.fyi/) — Community (Andy Bell) — methodology layers and philosophy
- [Every Layout](https://every-layout.dev/) — Community (Heydon Pickering, Andy Bell) — intrinsic layout primitives
- [Defensive CSS](https://defensivecss.dev/) — Community (Ahmad Shadeed) — defensive snippets
- [A Modern CSS Reset — Josh W. Comeau](https://www.joshwcomeau.com/css/custom-css-reset/) — Community — reset rules and rationale
- [Cascade layers — MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/@layer) — Official — layer syntax
- [@scope Baseline — Frontend Masters](https://frontendmasters.com/blog/how-to-scope-css-now-that-its-baseline/) — Community — scoping status

## License / Usage Notes
Methodology concepts summarized in original words. Every Layout and CUBE CSS are copyrighted works by their authors, so only concept names and short illustrative code are used. Snippets are original.

## Quality Tier
A — Synthesizes respected methodologies with current native-CSS capabilities. Architecture choices remain context-dependent.

## Status
Active

## Last Verified
2026-09-15
