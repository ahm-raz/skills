# CSS Modules

## Summary
CSS Modules are CSS files whose class names (and keyframe names) are locally scoped by default. At build time a bundler rewrites them to unique names and exports a JS mapping object. They are a build-tool convention (css-loader, Vite, Lightning CSS, Next.js, Parcel), not a browser standard, and they give zero-runtime, RSC-compatible component scoping with plain CSS.

## Category
CSS & Styling

## Subcategories
Local scope, composes, :global, TypeScript typings, Vite/Next.js integration, Lightning CSS, CSS Modules with Tailwind, migration from CSS-in-JS

## Problem It Solves
Global CSS class collisions and fear of deleting styles in component-based apps, without paying the runtime or RSC-compatibility cost of runtime CSS-in-JS and without adopting utility classes.

## When To Use
- Next.js App Router projects (including Server Components) or React Vite SPAs wanting plain CSS with guaranteed scoping.
- Migrating away from styled-components/Emotion to a zero-runtime solution with minimal new concepts.
- Shared React component packages that must not leak styles into host Next.js apps.
- Teams that prefer authoring real CSS (nesting, container queries, `@layer`) over utilities.

## When Not To Use
- Heavily dynamic, prop-driven styles with many permutations. Use data attributes + CSS variables, or a zero-runtime CSS-in-JS library with typed variants.
- Projects standardized on Tailwind. Mixing is fine for edge cases but should not be the default.
- Styling inside a Shadow DOM custom element rendered from React (the shadow root already scopes, and module classes can't cross it).

## Core Principles
1. **Local by default.** `.button` in `Button.module.css` becomes `Button_button__x7a2b`. Only the importing module references it.
2. **Class selectors only for scoping.** Element, attribute, and ID selectors are NOT rewritten, so they are global. Always anchor rules to a local class.
3. **Explicit global escape.** `:global(.foo)` for integrating third-party or state classes.
4. **Composition over duplication.** `composes:` reuses classes from the same file, another module, or `global`.
5. **Tokens via custom properties.** Modules scope class names, not variables. Custom properties remain global/inherited, which is ideal for theming.

## Best Practices
- Name files `Component.module.css` and colocate them with the component.
- Use camelCase class names (`.primaryButton`) so `styles.primaryButton` works without bracket access, or configure `localsConvention: 'camelCaseOnly'` (Vite `css.modules.localsConvention`).
- Model variants with data attributes or multiple local classes, not deep selectors: `<button className={styles.button} data-variant="primary">` + `.button[data-variant="primary"] {}`.
- Keep specificity flat and wrap module CSS in `@layer components { }` so utilities/overrides layers win predictably.
- Accept a `className` prop and concatenate (`clsx(styles.root, className)`) so consumers can adjust layout.
- Generate TypeScript typings for safety: `typescript-plugin-css-modules` (editor) or `typed-css-modules`/Vite plugin (build).
- Use native CSS nesting inside modules. Lightning CSS/PostCSS handle it and modern browsers parse it natively.
- Configure readable dev names: Vite `generateScopedName: '[name]__[local]__[hash:base64:5]'` in dev, short hashes in production.

## Implementation Guidance

### Syntax reference
```css
/* Button.module.css */
.base { display: inline-flex; gap: .5rem; border-radius: var(--radius-m); }

.primary {
  composes: base;                                     /* same file */
  background: var(--color-primary); color: var(--color-on-primary);
}

.link {
  composes: focusRing from "../shared/a11y.module.css"; /* other module */
  composes: sr-only from global;                        /* global class */
}

.base:global(.is-loading) { cursor: progress; }        /* mix local + global */
:global(.dark) .base { box-shadow: none; }             /* global ancestor */

@keyframes spin { to { rotate: 1turn; } }              /* keyframes are local too */
.spinner { animation: spin 1s linear infinite; }
```

```tsx
import styles from "./Button.module.css";
import clsx from "clsx";

type ButtonProps = React.ComponentProps<"button"> & { variant?: "primary" | "link" };

export function Button({ variant = "primary", className, ...props }: ButtonProps) {
  return <button className={clsx(styles[variant], className)} {...props} />;
}
```

### Rules for `composes`
- Must be in a rule with a single local class selector (not `.a:hover` or `.a .b`).
- Must appear before other declarations (convention; some tools require it).
- Order of composed classes in the final CSS is not guaranteed across files. Don't compose two modules that set the same property.

### Tooling configuration
| Bundler | Setup |
|---|---|
| Vite | Built in for `*.module.css`; options under `css.modules` (`localsConvention`, `generateScopedName`); `css.transformer: 'lightningcss'` optional |
| Next.js | Built in for `*.module.css` / `*.module.scss`; works in Server and Client Components |
| webpack | `css-loader` with `modules: { auto: true }` |
| Lightning CSS | `cssModules: true`. Supports `composes`, dashed-ident scoping option (`dashedIdents`) |
| Turbopack (Next.js default) / Rsbuild | Built in for `.module.css` |

### Using theme tokens from Tailwind v4 in modules
```css
@reference "../../app.css";   /* access @theme without re-emitting Tailwind */
.card { padding: --spacing(4); border-radius: var(--radius-lg); @apply shadow-sm; }
```

## Recommended Workflow
1. Define global tokens and base styles in a global stylesheet imported once (root layout).
2. Declare layer order globally (`@layer reset, base, components, utilities;`).
3. For each component, create `X.module.css`. Wrap in `@layer components`.
4. Use a single root class plus child classes. Express variants via data attributes or variant classes.
5. Add type generation and lint (`stylelint` with `selector-class-pattern` for camelCase).
6. Delete-safety check: removing a component deletes its module. Search for `:global` usage during review.

## Patterns
**Data-attribute variants (no class explosion)**
```css
.button { background: var(--bg, var(--color-neutral)); }
.button[data-variant="primary"] { --bg: var(--color-primary); }
.button[data-size="sm"] { padding: .25rem .5rem; }
```

**Dynamic values via custom properties (not inline style objects)**
```tsx
<div className={styles.progress} style={{ "--value": `${pct}%` } as React.CSSProperties} />
```
```css
.progress::after { inline-size: var(--value, 0%); }
```

**Styling third-party markup inside a local root**
```css
.editor :global(.ProseMirror) { min-block-size: 10lh; }
```

**Container-query-aware module**
```css
.root { container: card / inline-size; }
@container card (inline-size > 30rem) { .body { display: grid; grid-template-columns: 8rem 1fr; } }
```

## Anti-Patterns
- **Bare element selectors in a module (`h2 { }`).** Global leak. Anchor them: `.root h2 {}`.
- **Deep `:global` usage everywhere.** Defeats scoping. Restrict it to third-party integration and document why.
- **Importing one component's module into another to reuse classes.** Hidden coupling. Use `composes` from a shared module or extract a component.
- **Styling children of another component through its module class names.** Brittle. Expose a `className` prop or CSS custom properties.
- **Recomputing class strings with template literals of arbitrary names.** Undefined classes fail silently (`styles.undefined`). Use typed modules.
- **Relying on cross-file `composes` order for overrides.** Nondeterministic. Use layers or a single source.
- **Expecting CSS Modules to scope custom properties or `@font-face`.** They stay global. Namespace variable names (`--button-bg`) or enable Lightning CSS `dashedIdents` scoping deliberately.

## Accessibility
- Module scoping doesn't affect semantics. Still use real elements (`button`, `a`), `:focus-visible`, and ARIA state.
- Prefer styling ARIA/state attributes (`.tab[aria-selected="true"]`) so visual state follows accessible state.
- Keep a global `.sr-only`/`.visually-hidden` utility and compose it (`composes: sr-only from global`).
- Include `@media (prefers-reduced-motion: reduce)` and `forced-colors` handling inside component modules.

## Responsive Design
Modules support all CSS: media queries, container queries, `clamp()`. Put container queries in the component module so each component owns its breakpoints. Share breakpoint values via custom media (`@custom-media --md (width >= 48rem)` with PostCSS/Lightning CSS) or documented tokens.

## Performance
- Zero runtime; CSS is extracted to static files and code-split per route/chunk by most bundlers.
- Hashing adds minimal size. Enable minification and short hashes in production.
- Beware duplicated CSS when a shared module is imported by many chunks. Bundlers usually dedupe; check the build output.
- Next.js: CSS order across chunks can differ between dev and prod. Rely on layers and low specificity rather than import order.

## Security
- Class-name mapping exposes no secrets. Avoid putting user input into `style` custom properties that feed `url()` (CSS injection / data exfiltration).

## Testing
- Unit tests: Jest needs `identity-obj-proxy` (class names echo keys); Vitest supports CSS modules (`css.modules` config, or `test.css` option).
- Don't assert on hashed class names in tests; assert behavior/ARIA state or use visual regression.
- Visual regression (Playwright/Chromatic) for variants and states.

## Tooling
- css-loader, Vite, Next.js, Lightning CSS, Parcel, Rsbuild. Active, built-in support.
- `typescript-plugin-css-modules` (editor intellisense), `typed-css-modules` / `vite-plugin-css-modules-dts`-style generators. Community.
- `stylelint-config-css-modules`. Allows `composes`, `:global`.
- The `css-modules/css-modules` GitHub repo is the specification-by-documentation. It is low-activity but stable, and implementations evolve in bundlers (css-loader, Lightning CSS).
- `postcss-modules`. Still used for non-bundler pipelines.

## Framework Notes
- **Next.js App Router (16.x):** `*.module.css` (and `.module.scss` if `sass` is installed) is built in and works in Server Components and Client Components with no configuration, no `'use client'`, and no style registry. This makes it the recommended zero-runtime alternative to runtime CSS-in-JS in RSC trees. Import global (non-module) CSS such as `globals.css` in `app/layout.tsx`. Next.js may order CSS chunks differently between `next dev` and `next build` or across navigations, so use `@layer` + single-class specificity instead of depending on import order. Turbopack (default bundler) supports CSS Modules natively.
- **Next.js + Tailwind v4 in modules:** start the module with `@reference "../globals.css";` before `@apply`/`--spacing()`.
- **React (Vite SPA):** built in; configure `css.modules` in `vite.config.ts` (camelCase locals, readable dev names). Pair with `clsx`.
- **TypeScript:** add `declare module "*.module.css" { const classes: Readonly<Record<string, string>>; export default classes; }` if your template lacks it (Next.js and Vite templates include it). Add `typescript-plugin-css-modules` to `tsconfig` `compilerOptions.plugins` for per-class autocomplete.
- **Storybook (`@storybook/nextjs` or `@storybook/react-vite`):** modules work through the framework builder.

## AI Agent Guidance
- Do check whether the repo uses CSS Modules (`*.module.css`) before choosing a styling approach for a new component, and match it.
- Do anchor every selector to a local class, wrap in `@layer components`, and use tokens via `var()`.
- Do use data attributes for variants and CSS variables for dynamic values.
- Don't write bare element selectors or unnecessary `:global`.
- Don't hand-concatenate class strings with spaces and possible `undefined`. Use `clsx`.
- Before done: verify classes resolve (no `undefined` in DOM), no global leaks (check an unrelated page), typings compile, and dark theme tokens apply.

## Examples
```css
/* Card.module.css */
@layer components {
  .card {
    container: card / inline-size;
    display: grid; gap: var(--space-s); padding: var(--space-m);
    background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-l);
    &:has(.media) { padding-block-start: 0; }
    &[data-interactive]:hover { border-color: var(--color-primary); }
    &:focus-within { outline: 2px solid var(--color-focus); outline-offset: 2px; }
  }
  .media { aspect-ratio: 16 / 9; object-fit: cover; inline-size: 100%; border-radius: inherit; }
  .title { font-size: var(--step-1); text-wrap: balance; }
  @container card (inline-size >= 36rem) {
    .card { grid-template-columns: 14rem 1fr; }
  }
}
```
```tsx
import styles from "./Card.module.css";
export function Card({ title, img, interactive, children }) {
  return (
    <article className={styles.card} data-interactive={interactive || undefined}>
      {img && <img className={styles.media} src={img.src} alt={img.alt} />}
      <h3 className={styles.title}>{title}</h3>
      {children}
    </article>
  );
}
```

## Related Skills
- [css-architecture](../css-architecture/Skill.md) — where modules fit in the overall structure
- [css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md) — alternatives and migration
- [css-nesting-and-scope](../css-nesting-and-scope/Skill.md) — native @scope as an alternative
- [css-cascade-layers-and-specificity](../css-cascade-layers-and-specificity/Skill.md) — ordering modules with layers
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — styling in App Router
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — tokens consumed in modules

## Sources
- [css-modules/css-modules (GitHub)](https://github.com/css-modules/css-modules) — Open Source — local scope, composition, naming concepts
- [css-loader modules options](https://github.com/webpack-contrib/css-loader#modules) — Open Source — auto, localsConvention, naming
- [Vite CSS Modules](https://vite.dev/guide/features#css-modules) — Official — built-in support and options
- [Lightning CSS — CSS Modules](https://lightningcss.dev/css-modules.html) — Open Source — composes, dashed idents
- [Next.js CSS docs](https://nextjs.org/docs/app/getting-started/css) — Official — module support in App Router
- [Next.js CSS-in-JS guide](https://nextjs.org/docs/app/guides/css-in-js) — Official — context for zero-runtime preference
- [Tailwind upgrade guide (@reference)](https://tailwindcss.com/docs/upgrade-guide) — Official — using theme in modules

## License / Usage Notes
The CSS Modules spec repo, css-loader and Lightning CSS are MIT/MPL-licensed open source. Content is summarized, and code is original.

## Quality Tier
A — Stable, well-understood technology verified against bundler docs. The spec repo itself is low-activity.

## Status
Active

## Last Verified
2026-09-15
