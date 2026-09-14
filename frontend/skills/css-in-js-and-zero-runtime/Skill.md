# CSS-in-JS and Zero-Runtime Styling

## Summary
How to choose and use CSS-in-JS in React/Next.js in 2026. Runtime libraries (styled-components, Emotion) inject styles during render and clash with React Server Components and streaming. styled-components has been in maintenance mode since March 2025. Zero-runtime, compile-time libraries (vanilla-extract, StyleX, Panda CSS, Linaria/wyw-in-js, next-yak) keep the TypeScript authoring experience but emit static CSS. This skill covers selection, RSC compatibility, typed theming/variants, and migration.

## Category
CSS & Styling

## Subcategories
styled-components, Emotion, vanilla-extract, StyleX, Panda CSS, Linaria, next-yak, Pigment CSS, RSC compatibility, style registries, migration

## Problem It Solves
Teams on runtime CSS-in-JS face `'use client'` everywhere, style registries, hydration costs, INP regressions from render-time style generation, and an unmaintained dependency. New teams need a clear decision: Tailwind, CSS Modules, or a typed zero-runtime library.

## When To Use
- Choosing a styling solution for a new Next.js App Router / React project that wants TypeScript-typed styles.
- Migrating a styled-components/Emotion codebase to be RSC-compatible.
- Building a typed design-system package (themes as contracts, variant recipes).

## When Not To Use
- The team is happy with Tailwind v4 or CSS Modules. Don't add a compiler plugin for no gain.
- Tiny apps where plain CSS Modules suffice.
- Library-internal styles for MUI/Chakra/Mantine. Follow that library's own guidance (see its skill).

## Core Principles
1. **No new runtime CSS-in-JS.** Don't start new projects on styled-components or Emotion. Its maintainer explicitly advises against adopting styled-components for new projects.
2. **Static extraction requires static inputs.** Compile-time libraries analyze source at build time. Dynamic values become CSS custom properties, and variant sets must be enumerable.
3. **Dynamic = custom properties + data attributes.** Runtime values flow through `style={{ "--x": value }}`, never through regenerated class strings.
4. **Themes are CSS variables.** Every modern library compiles themes to custom properties scoped by a class/attribute, so switching needs no re-render.
5. **Match the library to the org shape.** Atomic + strict (StyleX) for huge orgs; typed CSS-Modules-like (vanilla-extract) for DS packages; config/codegen (Panda) for Chakra-like DX.

## Best Practices
- For React Server Components, choose a zero-runtime library whose styles work in Server Components (vanilla-extract, StyleX, Panda, Linaria, next-yak). Runtime libs only work inside Client Components with a registry.
- Keep style definitions at module top level (required by vanilla-extract `.css.ts`, StyleX `stylex.create`, Panda static analysis).
- Model variants as finite unions (`size: "sm" | "md" | "lg"`) that map to precompiled classes.
- Expose `className` (and for StyleX, `xstyle`/`style` props per its conventions) so consumers can extend.
- Wrap library output in a cascade layer when mixing with other CSS (Panda uses layers by default; vanilla-extract has `layer()` API; StyleX can emit layers via config).
- Pin compiler plugin versions and test builds on Next.js upgrades. Plugins couple to bundler internals (webpack vs Turbopack support varies).

## Implementation Guidance

### Decision table (Sept 2026)
| Library | Model | RSC / Server Components | Status | Choose when |
|---|---|---|---|---|
| **styled-components v6** | Runtime | Client Components only + registry | Maintenance mode (Mar 2025) | Existing apps only; plan migration |
| **Emotion** | Runtime | Client Components only; App Router support pending (Next.js docs) | Low activity | Existing apps only (often via MUI v5/v6 legacy) |
| **vanilla-extract** | Zero-runtime, `.css.ts` files, typed theme contracts, `recipes`, `sprinkles` | Yes | Mature, stable | DS packages, teams wanting typed CSS Modules |
| **StyleX** (Meta) | Zero-runtime atomic, `stylex.create` / `stylex.props`, `defineVars` / `createTheme` | Yes | Active | Large orgs, strict determinism, style-merge safety |
| **Panda CSS** | Zero-runtime atomic, config + codegen `styled-system`, `cva`/config recipes, JSX patterns | Yes | Active | Chakra-like DX, tokens/recipes config |
| **Linaria (wyw-in-js)** | Zero-runtime `styled`/`css` tagged templates | Yes (styles compiled; dynamic props become CSS vars) | Maintained | Drop-in-ish replacement for styled-components |
| **next-yak** | Zero-runtime styled-components syntax, Rust/SWC plugin | Yes | Active | Fastest styled-components to Next.js migration |
| **Pigment CSS** (MUI) | Zero-runtime | Yes | On hold (alpha) | Avoid for new work |
| **Tailwind v4 / CSS Modules** | Static CSS | Yes | Active | Default choices; no CSS-in-JS needed |

### Why runtime CSS-in-JS conflicts with RSC
- Server Components can't use Context or hooks, and runtime libraries need a ThemeProvider context plus render-time injection.
- The App Router requires a style registry (`useServerInsertedHTML`) in a Client Component to flush styles during streaming.
- Render-time serialization/hashing of styles adds main-thread work on every render (INP), and React's `useInsertionEffect` mitigates but doesn't eliminate it.

### Migration strategy (styled-components → zero-runtime)
1. Freeze new styled-components usage (ESLint `no-restricted-imports`).
2. Move theme values to CSS custom properties (`:root`/`[data-theme]`). Make `theme.colors.primary` read `var(--color-primary)` so both old and new code share tokens.
3. Replace interpolated props with data attributes + CSS vars: `${p => p.$active && css\`...\`}` becomes `&[data-active] {}`.
4. Choose the path: next-yak/Linaria for near-identical syntax; CSS Modules or vanilla-extract for a cleaner model.
5. Migrate leaf components first. Remove the registry when no runtime styled components remain.
6. Drop `'use client'` from components that only needed it for styling.

## Recommended Workflow
1. Decide: Tailwind / CSS Modules unless typed TS styles are a hard requirement.
2. If CSS-in-JS: pick with the table; verify the Next.js/Vite plugin supports your bundler (Turbopack vs webpack) today.
3. Define tokens as a theme contract (vanilla-extract `createThemeContract`, StyleX `defineVars`, Panda `tokens`/`semanticTokens`).
4. Build recipes for core components; enforce static variants.
5. Wire dynamic values through CSS variables.
6. Verify Server Components render styled output without `'use client'` and that CSS is extracted to files (check `.next/static/css`).

## Patterns
**vanilla-extract theme contract + recipe**
```ts
// theme.css.ts
import { createThemeContract, createTheme } from "@vanilla-extract/css";
export const vars = createThemeContract({ color: { bg: null, fg: null, primary: null }, radius: { md: null } });
export const lightTheme = createTheme(vars, { color: { bg: "white", fg: "#111", primary: "oklch(55% .16 260)" }, radius: { md: "8px" } });
export const darkTheme  = createTheme(vars, { color: { bg: "#111", fg: "#eee", primary: "oklch(72% .13 260)" }, radius: { md: "8px" } });

// button.css.ts
import { recipe } from "@vanilla-extract/recipes";
import { vars } from "./theme.css";
export const button = recipe({
  base: { borderRadius: vars.radius.md, padding: "0.5rem 1rem" },
  variants: { tone: { primary: { background: vars.color.primary, color: "white" }, ghost: { background: "transparent", color: vars.color.fg } } },
  defaultVariants: { tone: "primary" },
});
```

**StyleX component with themeable vars**
```tsx
// tokens.stylex.ts
import * as stylex from "@stylexjs/stylex";
export const colors = stylex.defineVars({ primary: "oklch(55% .16 260)", onPrimary: "white" });

// Button.tsx
import * as stylex from "@stylexjs/stylex";
import { colors } from "./tokens.stylex";
const s = stylex.create({
  base: { backgroundColor: colors.primary, color: colors.onPrimary, paddingBlock: 8, paddingInline: 16, borderRadius: 8 },
  disabled: { opacity: 0.5 },
});
export function Button({ disabled, ...p }: React.ComponentProps<"button">) {
  return <button {...stylex.props(s.base, disabled && s.disabled)} disabled={disabled} {...p} />;
}
```

**Panda CSS config recipe usage**
```tsx
import { button } from "styled-system/recipes";
import { css } from "styled-system/css";
<button className={button({ size: "sm", visual: "solid" })} />
<div className={css({ display: "grid", gap: "4", md: { gridTemplateColumns: "2" } })} />
```

**Dynamic value without runtime CSS generation**
```tsx
<div className={styles.bar} style={{ "--progress": `${value}%` } as React.CSSProperties} />
```

## Anti-Patterns
- **Starting a new Next.js App Router project on styled-components/Emotion.** Forces client boundaries and depends on a maintenance-mode library. Use Tailwind, CSS Modules, or zero-runtime.
- **Passing arbitrary runtime values into `css()` / `stylex.create`.** The compiler can't extract them, leading to broken or missing styles. Use CSS variables.
- **`button({ size })` with `size` from unconstrained state in Panda.** Only defaults get emitted. Use literal union types, or `staticCss` for the needed combinations.
- **Putting `'use client'` on a layout just to make styled-components work.** Destroys RSC benefits. Isolate the registry in a small client wrapper, and migrate.
- **Mixing two CSS-in-JS systems.** Double tooling, unpredictable order. Pick one; layer the other during migration.
- **Relying on Pigment CSS for new work.** Paused in alpha. Choose a maintained library.

## Accessibility
Styling libraries don't change semantics. Still:
- Style from ARIA/data state (`[aria-expanded="true"]`, `[data-state=open]`) so visuals match accessibility state.
- Provide `:focus-visible` in base recipes and reduced-motion conditions (StyleX: `'@media (prefers-reduced-motion: reduce)'` keys; vanilla-extract: `'@media'` object).
- Verify theme contracts produce ≥4.5:1 text contrast in all themes.

## Responsive Design
- vanilla-extract/StyleX support `@media` and `@container` keys in style objects. Panda supports responsive object/array syntax and container query conditions.
- Prefer container queries for DS components. Define breakpoints as shared constants (StyleX `defineConsts`, vanilla-extract exported strings, Panda `theme.breakpoints`).

## Performance
- Zero-runtime libraries emit static CSS with no render-time style work. Atomic output (StyleX, Panda) plateaus in size as the app grows.
- Runtime CSS-in-JS costs: JS bundle size (styled-components ~12–16 kB gz), serialization per render, style recalculation on insertion, and larger RSC client boundaries.
- Watch build performance. Babel-based extraction can slow Next.js builds; prefer SWC/Rust-based plugins where offered.

## Security
- Never interpolate untrusted input into style templates or variables used in `url()` (CSS injection).
- Compiler plugins run at build time with full access. Pin versions and review supply chain.
- CSP: zero-runtime libraries don't need `style-src 'unsafe-inline'` for injected `<style>` tags (inline `style` attributes for CSS vars may still need `'unsafe-inline'` for `style-src-attr` if you use strict CSP; a nonce doesn't cover style attributes).

## Testing
- Test behavior and ARIA, not generated class names (which are hashed/atomic).
- Visual regression per theme for recipes.
- Build-level test: production build succeeds and emits CSS; smoke E2E checks computed styles for a few key components.
- Jest: vanilla-extract provides `@vanilla-extract/jest-transform`. Vitest works via the Vite plugin.

## Tooling
- `@vanilla-extract/css`, `@vanilla-extract/recipes`, `@vanilla-extract/sprinkles`, `@vanilla-extract/next-plugin`, `@vanilla-extract/vite-plugin`. Active.
- `@stylexjs/stylex` + official bundler plugins (Next.js via Babel/PostCSS plugin, Vite plugin), `@stylexjs/eslint-plugin`. Active.
- `@pandacss/dev` (PostCSS plugin + codegen). Active.
- `@linaria/*` + `@wyw-in-js/*`. Maintained. `next-yak`. Active.
- `styled-components` v6. Maintenance mode. `@emotion/*`. Low activity. `@pigment-css/*`. On hold.

## Framework Notes
- **Next.js App Router:** Next.js docs list Panda, StyleX, vanilla-extract, styled-components, styled-jsx and others as working in Client Components. Zero-runtime libraries additionally produce static CSS usable from Server Components. Runtime libraries require a `'use client'` registry using `useServerInsertedHTML` (styled-components: `ServerStyleSheet` + `StyleSheetManager`, plus `compiler: { styledComponents: true }` in `next.config`). Emotion is still listed as "working on support". Check plugin compatibility with Turbopack (default in Next.js 16) before adopting; some extraction plugins still require webpack (`next build --webpack`).
- **React (Vite SPA):** all libraries work. The runtime cost still matters for INP, and zero-runtime Vite plugins exist for vanilla-extract, StyleX, Panda (PostCSS) and Linaria (wyw-in-js).
- **MUI:** MUI v7 still uses Emotion by default. Treat it per the material-ui skill; don't attempt Pigment migration now.

## AI Agent Guidance
- Do detect the existing styling system (package.json: `styled-components`, `@emotion/*`, `@vanilla-extract/*`, `@stylexjs/stylex`, `@pandacss/dev`) and follow it.
- Do use CSS variables for runtime values and finite variant unions.
- Don't introduce styled-components/Emotion into a new or RSC-based codebase. Don't add `'use client'` solely for styling.
- Don't generate style objects from runtime data in compile-time libraries.
- Before done: production build passes; styles present with JS disabled on server-rendered pages (zero-runtime); no hydration warnings; theme switch works without re-render.

## Examples
```tsx
// Next.js App Router Server Component styled with vanilla-extract (no 'use client')
// app/components/Callout.css.ts
import { style, styleVariants } from "@vanilla-extract/css";
import { vars } from "../theme.css";
export const root = style({
  display: "grid", gap: 8, padding: 16, borderRadius: vars.radius.md, borderInlineStart: "4px solid",
  "@container": { "(inline-size > 40rem)": { gridTemplateColumns: "auto 1fr" } },
});
export const tone = styleVariants({
  info: { borderColor: vars.color.primary },
  danger: { borderColor: "oklch(58% .2 27)" },
});

// app/components/Callout.tsx
import { root, tone } from "./Callout.css";
export function Callout({ kind = "info", children }: { kind?: keyof typeof tone; children: React.ReactNode }) {
  return <aside role="note" className={`${root} ${tone[kind]}`}>{children}</aside>;
}
```
```ts
// next.config.ts
import type { NextConfig } from "next";
import { createVanillaExtractPlugin } from "@vanilla-extract/next-plugin";
const withVanillaExtract = createVanillaExtractPlugin();
const config: NextConfig = {};
export default withVanillaExtract(config);
```

## Related Skills
- [css-modules](../css-modules/Skill.md) — simplest zero-runtime alternative
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — utility-first alternative
- [react-server-components](../react-server-components/Skill.md) — why runtime styling conflicts with RSC
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) — client boundary placement
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — themes compiled to variables
- [material-ui](../material-ui/Skill.md) — Emotion-based library context
- [inp-optimization](../inp-optimization/Skill.md) — runtime styling cost on interactions

## Sources
- [Next.js — CSS-in-JS guide (v16.3.5 docs)](https://nextjs.org/docs/app/guides/css-in-js) — Official — supported libraries, registry pattern, Emotion status
- [styled-components maintenance mode discussion #5568](https://github.com/orgs/styled-components/discussions/5568) — Open Source — maintenance status, RSC rationale
- [vanilla-extract theming docs](https://vanilla-extract.style/documentation/theming/) — Official — contracts, createTheme, assignInlineVars
- [StyleX — defining variables](https://stylexjs.com/docs/learn/theming/defining-variables/) — Official — defineVars, .stylex.ts rules
- [Panda CSS — recipes](https://panda-css.com/docs/concepts/recipes) — Official — cva vs config recipes, static extraction limits
- [The state of zero-runtime CSS-in-JS, mid-2026 (DEV)](https://dev.to/anber/the-state-of-zero-runtime-css-in-js-mid-2026-5ci6) — Community (Linaria author) — library status, Pigment on hold, next-yak
- [Sanity — styled-components fork post](https://www.sanity.io/blog/cut-styled-components-into-pieces-this-is-our-last-resort) — Community — performance context

## License / Usage Notes
All libraries referenced are MIT. Content is summarized, and code examples are original using public APIs.

## Quality Tier
A — Official docs for each library plus Next.js guidance. Ecosystem status is volatile, so recheck plugin/Turbopack compatibility.

## Status
Active

## Last Verified
2026-09-15
