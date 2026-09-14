# CSS Nesting and @scope

## Summary
Native CSS nesting (Baseline since late 2023, now effectively Widely available) lets you write Sass-like nested rules without a preprocessor. `@scope` (Baseline Newly available Dec 2025, Firefox 146) limits selectors to a DOM subtree, with optional lower "donut" boundaries and proximity-based cascade priority. This skill covers their exact semantics (which differ from Sass), when to prefer them over CSS Modules, and how they fit React/Next.js.

## Category
CSS & Styling

## Subcategories
Native nesting, & selector, relaxed syntax, nested at-rules, CSSNestedDeclarations, @scope, donut scope, :scope, scope proximity, inline scoped styles, Sass migration

## Problem It Solves
Sass is used mainly for nesting, and BEM exists mainly to avoid leaks. Native nesting removes the build dependency. `@scope` provides real subtree scoping (including "stop at this child component") without hashing class names, which helps content areas (CMS/MDX prose), third-party widgets, and component styles in plain CSS.

## When To Use
- Writing component or global CSS with nested states, pseudo-classes, and media/container queries.
- Migrating Sass partials to plain CSS.
- Styling CMS/MDX-rendered HTML (element selectors) without leaking into embedded components (donut scope).
- Theming regions where the nearest theme should win (scope proximity).

## When Not To Use
- Expecting Sass features: selector string concatenation (`&__elem`), mixins, loops, `@extend`. Use a preprocessor or restructure.
- Hard isolation from host page styles. Use Shadow DOM or CSS Modules. `@scope` limits where your selectors match; it doesn't block inherited or outside styles.
- Browsers older than 2025 for `@scope` without fallback acceptance.

## Core Principles
1. **`&` represents the parent selector as `:is(parent)`.** Specificity equals the most specific item in the parent list.
2. **Nesting isn't text substitution.** `&__title` is invalid (it becomes a type selector). Write full class names.
3. **Relaxed syntax:** nested selectors may start with any token, including element names (`.card { h2 { } }` works).
4. **Put declarations before nested rules.** Declarations after nested rules are wrapped as `CSSNestedDeclarations` in current engines; older engines hoisted them, changing order.
5. **`@scope (root) to (limit)` matches elements inside root but not inside limit.** Limits create "donut" holes.
6. **Scope proximity is a cascade step after specificity.** When specificity ties, the rule from the closer scope root wins, regardless of source order.
7. **`@scope` doesn't add specificity to selectors** (unlike nesting's `&`). `:scope` inside it has pseudo-class specificity (0,1,0).

## Best Practices
- Limit nesting depth to 2–3 levels. Deep nesting recreates specificity problems.
- Nest states and media/container queries inside the rule they modify for locality.
- Use `&` explicitly when appending (`&:hover`, `&.is-active`, `&[data-state=open]`) and for context reversal (`.dark & {}`).
- Use `@scope (.prose) to (.not-prose, [data-component])` for MDX/CMS content so embedded components are untouched.
- Use `@scope` with low-specificity element selectors inside instead of long class chains.
- Rely on proximity for nested theme regions: `@scope (.light) { a { color: … } } @scope (.dark) { a { color: … } }`, so the innermost wins.
- Keep CSS Modules or Tailwind for component-level isolation in React; use `@scope` for content regions and third-party markup.

## Implementation Guidance

### Nesting rules
```css
.card {
  padding: 1rem;                       /* declarations first */
  border: 1px solid var(--color-border);

  &:hover { border-color: var(--color-accent); }       /* .card:hover */
  &[data-selected] { outline: 2px solid var(--color-accent); }
  .title { font-weight: 600; }                          /* .card .title */
  > img { border-radius: inherit; }                     /* .card > img */
  h2 { margin: 0; }                                     /* relaxed: .card h2 */
  .dark & { background: var(--surface-2); }             /* .dark .card */

  @media (width >= 48rem) { padding: 1.5rem; }
  @container (inline-size >= 30rem) { display: grid; grid-template-columns: 8rem 1fr; }
}
```

### Nesting vs Sass differences
| Sass | Native CSS |
|---|---|
| `&__title` concatenation | Not possible; write `.card__title` separately |
| `#{$var}` interpolation | No; use custom properties |
| `.a, .b { .c {} }` gives `.a .c, .b .c` with each own specificity | `:is(.a, .b) .c`, where specificity = highest of list |
| `@extend`, mixins | None (use utility classes, `composes` in CSS Modules) |
| Compile-time | Parsed by the browser (or downleveled by Lightning CSS/PostCSS) |

### @scope syntax
```css
/* Scoped to .prose, excluding embedded components */
@scope (.prose) to (.not-prose, [data-component]) {
  :scope { max-inline-size: 65ch; }
  h2 { margin-block: 2em .5em; font-size: var(--step-3); }
  a { color: var(--color-accent); text-underline-offset: .2em; }
  img { border-radius: .5rem; }
}

/* Inline <style> scoped to its parent (prelude omitted) */
/* <div class="widget"><style>@scope { p { color: red } }</style><p>…</p></div> */
```
- The `to` limit is exclusive by default (the limit element itself isn't matched). Use `to (.limit > *)` patterns to make it inclusive.
- `@scope` rules can live inside `@layer`. Layer still beats proximity; proximity only breaks specificity ties.

### Where proximity changes outcomes
```css
@scope (.theme-light) { .button { background: white; } }
@scope (.theme-dark)  { .button { background: black; } }
```
For `<div class="theme-dark"><div class="theme-light"><button class="button">`, the button is white because `.theme-light` is the nearer root, even though the dark rule comes later.

## Recommended Workflow
1. Confirm the build pipeline doesn't mangle nesting (Lightning CSS/PostCSS preset-env targets based on browserslist; with modern targets it passes through).
2. Convert Sass nesting: replace `&__x` / `&--x` with explicit classes or data attributes; replace variables with custom properties.
3. Keep depth shallow; move declarations above nested rules.
4. For content regions, wrap rules in `@scope (.prose) to (.not-prose)`.
5. Test in Firefox 146+ and Safari 17.4+ for `@scope`; accept or provide a fallback (plain descendant selectors) for older browsers if required by policy.

## Patterns
**State and ARIA nesting**
```css
.accordion-trigger {
  &[aria-expanded="true"] .chevron { rotate: 180deg; }
  &:focus-visible { outline: 2px solid var(--color-focus); }
  @media (prefers-reduced-motion: no-preference) { .chevron { transition: rotate .2s; } }
}
```

**MDX prose with donut scope (Tailwind users: similar to `not-prose`)**
```css
@layer components {
  @scope (.mdx) to (.mdx-embed) {
    :scope > * + * { margin-block-start: 1em; }
    code:not(pre code) { background: var(--surface-2); padding: .1em .3em; border-radius: .25rem; }
    table { inline-size: 100%; border-collapse: collapse; }
  }
}
```

**Styling third-party widget markup without leaking**
```css
@scope (.editor-root) {
  .ProseMirror { min-block-size: 12lh; outline: none; }
  .ProseMirror:focus-visible { box-shadow: 0 0 0 2px var(--color-focus); }
}
```

## Anti-Patterns
- **`&-suffix` / `&__elem` BEM concatenation.** Silently invalid. Write full class names.
- **Deep nesting (`.page { .main { .card { .title { span {} } } } }`).** Specificity (0,4,1) and tight coupling. Flatten.
- **Declarations after nested rules in shared libraries.** Order differs in older engines. Declarations first.
- **Expecting `@scope` to block outside styles.** Global `p {}` still applies. Use Shadow DOM/Modules for isolation.
- **Using `@scope` for every React component in a Modules/Tailwind codebase.** Two scoping systems. Keep one per concern.
- **Nesting inside `:is()`-sensitive selector lists without checking specificity.** `.a, #b { .c {} }` gives `.c` ID-level specificity for both. Split the rules.

## Accessibility
Neither feature affects semantics. Use nesting to colocate `:focus-visible`, `prefers-reduced-motion`, and `forced-colors` rules with the component so they aren't forgotten. Scoped prose styles must keep link underlines/contrast (WCAG 1.4.1 Use of Color).

## Responsive Design
Nest `@media` and `@container` inside rules for locality. Nested at-rules inherit the parent selector, so no repetition is needed.

## Performance
- Native nesting removes a Sass build step. Output size is similar; browsers parse nesting efficiently.
- `@scope` matching adds a subtree check comparable to descendant selectors. Keep scope roots specific (classes/attributes), not `*`.

## Security
No specific concerns. Inline `<style>` with `@scope` in user-generated content is still CSS injection; sanitize UGC styles.

## Testing
- Visual regression for converted Sass files (before/after screenshots).
- Unit/visual test that MDX-embedded components are unaffected by prose scope.
- Cross-browser test `@scope` in WebKit/Gecko (Playwright).
- Stylelint `max-nesting-depth` (e.g. 3) and `selector-nested-pattern` checks.

## Tooling
- Native CSS; Lightning CSS (used by Tailwind v4, Vite option, Next.js via PostCSS/Turbopack) downlevels nesting for older targets.
- `postcss-nesting` (spec-compliant) vs `postcss-nested` (Sass-like, allows concatenation, not spec). Prefer `postcss-nesting` or Lightning CSS.
- Stylelint `max-nesting-depth`, `stylelint-config-standard` (supports nesting and `@scope`).
- Sass is still maintained. `@import` is deprecated in favor of `@use`/`@forward`; migrate or drop Sass.

## Framework Notes
- **Next.js App Router:** nesting works in `globals.css` and `*.module.css` (Turbopack/Lightning CSS handle it). In CSS Modules, class names inside nested rules are hashed normally. `@scope` roots using module classes must reference them as local classes (`@scope (.root)` inside the module works because `.root` is rewritten). For MDX (`@next/mdx`), wrap content in `<article className="mdx">` and use donut scope with `.mdx-embed` on interactive components.
- **React (Vite SPA):** same. Vite passes nesting through for modern targets or transforms via Lightning CSS when configured.
- **Inline scoped styles in React:** `<style>{"@scope { … }"}</style>` inside a component works (React 19 hoists `<style>` only when given `href`+`precedence`; without them it stays inline). Prefer modules/utilities for maintainability.
- **Tailwind v4:** supports native nesting in your CSS and `@variant` inside rules; `not-prose` in `@tailwindcss/typography` is the utility analog of donut scope.

## AI Agent Guidance
- Do use native nesting with explicit `&` for pseudo-classes/compound selectors and full class names for elements.
- Do keep nesting ≤3 levels and declarations before nested rules.
- Do use `@scope … to (…)` for CMS/MDX/third-party markup styling.
- Don't generate `&__element` or Sass-only syntax in `.css` files.
- Don't treat `@scope` as isolation from global CSS.
- Before done: inspect computed selectors in DevTools (confirm expected matches) and test in Firefox and Safari.

## Examples
```tsx
// app/blog/[slug]/page.tsx
import styles from "./post.module.css";
import { Callout } from "@/components/Callout";

export default async function Post({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { default: Content } = await import(`@/content/${slug}.mdx`);
  return (
    <article className={styles.mdx}>
      <Content components={{ Callout: (p: React.ComponentProps<typeof Callout>) => <div className={styles.embed}><Callout {...p} /></div> }} />
    </article>
  );
}
```
```css
/* post.module.css */
@layer components {
  @scope (.mdx) to (.embed) {
    :scope { max-inline-size: 70ch; margin-inline: auto; }
    :scope > * + * { margin-block-start: 1.25em; }
    h2 {
      font-size: var(--step-3); text-wrap: balance;
      &:target { scroll-margin-block-start: 5rem; }
    }
    a {
      color: var(--color-accent); text-decoration-thickness: .08em;
      &:hover { text-decoration-thickness: .15em; }
    }
    pre { overflow-x: auto; padding: 1rem; border-radius: .5rem; }
  }
}
```

## Related Skills
- [css-cascade-layers-and-specificity](../css-cascade-layers-and-specificity/Skill.md) — how scope proximity fits the cascade
- [css-modules](../css-modules/Skill.md) — build-time scoping alternative
- [css-architecture](../css-architecture/Skill.md) — choosing scoping strategies
- [modern-css-features](../modern-css-features/Skill.md) — support status
- [content-and-blog-sites](../content-and-blog-sites/Skill.md) — MDX prose styling
- [typography-systems](../typography-systems/Skill.md) — prose typography

## Sources
- [MDN — Using CSS nesting](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Nesting/Using) — Official — &, relaxed syntax, specificity, CSSNestedDeclarations, no concatenation
- [MDN — @scope](https://developer.mozilla.org/en-US/docs/Web/CSS/@scope) — Official — syntax, donut scope, proximity
- [Frontend Masters — How to @scope CSS now that it's Baseline](https://frontendmasters.com/blog/how-to-scope-css-now-that-its-baseline/) — Community — Firefox 146 Baseline, practical usage
- [CSS Nesting Module (W3C)](https://www.w3.org/TR/css-nesting-1/) — Official — spec
- [CSS Cascading Level 6 — scope](https://www.w3.org/TR/css-cascade-6/) — Official — scope proximity cascade step
- [web.dev — Baseline 2026](https://web.dev/baseline/2026) — Official — @scope listed
- [Lightning CSS](https://lightningcss.dev/) — Open Source — nesting transpilation

## License / Usage Notes
MDN is CC-BY-SA and the W3C specs are under the W3C document license. Content is summarized, and code is original.

## Quality Tier
A — Official semantics verified, with @scope Baseline confirmed. Proximity behavior is new to most teams and deserves testing.

## Status
Active

## Last Verified
2026-09-15
