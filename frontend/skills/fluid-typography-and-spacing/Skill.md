# Fluid Typography and Spacing

## Summary
Fluid type and space scales interpolate sizes smoothly between a minimum and maximum viewport (or container) width using `clamp()` with a `rem + vw` (or `cqi`) preferred value. This replaces stepwise breakpoint font sizes. The Utopia method generates a harmonious modular type scale and paired space scale as custom properties. This skill covers the math, the accessibility guardrails (zoom, WCAG 1.4.4), and React/Next.js/Tailwind integration.

## Category
CSS & Styling

## Subcategories
clamp(), Utopia, modular scale, type steps, space pairs, vw/cqi units, zoom accessibility, Tailwind theme tokens

## Problem It Solves
Breakpoint-based sizes produce jumps and many media queries, and designs look wrong between breakpoints. Naive `font-size: 5vw` breaks user zoom and accessibility. Fluid scales give continuous, designer-controlled sizing from a few tokens.

## When To Use
- Marketing/landing/editorial pages with large headings.
- Design systems wanting one set of type/space tokens for all screen sizes.
- Component-level fluid sizing (hero, card titles) via container units.

## When Not To Use
- Dense app UI (data tables, forms, admin panels): fixed rem sizes are more predictable. Fluid ranges there should be tiny or none.
- Body text in long-form content beyond a small range (e.g. 1rem → 1.125rem). Big body-size changes hurt readability.
- Anywhere you can't test zoom behavior.

## Core Principles
1. **Always mix `rem` into the preferred value.** `clamp(min-rem, base-rem + slope-vw, max-rem)`. Pure `vw` doesn't respond to browser text zoom (WCAG 1.4.4 failure risk).
2. **Keep the max/min ratio modest.** A rule of thumb: max size ≤ ~2.5× min size keeps 200% zoom achievable. Utopia's calculator warns when a step fails SC 1.4.4.
3. **Define scales, not one-offs.** Type steps (`--step--1 … --step-5`) and space tokens (`--space-3xs … --space-3xl`) plus pairs (`--space-s-l`).
4. **Min and max endpoints come from design.** Typical: 320–360px min viewport, 1240–1440px max; ratios e.g. 1.2 (minor third) at min, 1.25–1.333 at max.
5. **Units in rem at the endpoints** so user default font size preferences are respected.

## Best Practices
- Generate values with Utopia (type, space, clamp calculators) rather than hand math. Commit the generated CSS as tokens.
- Use space pairs (`--space-s-l`) for gaps/padding that should grow more aggressively than single steps.
- Use `cqi` instead of `vw` for component-scoped fluid values inside containers.
- Pair fluid font sizes with unitless line-heights that tighten as size grows (e.g. body 1.5–1.6, headings 1.1–1.2), or use `calc()`-based line-heights like `line-height: calc(1em + 0.5rem)`.
- Cap measure: `max-inline-size: 65ch` for body copy.
- Test at 200% and 400% zoom and with a 20px default browser font size.
- In Tailwind v4, expose steps as `--text-*` theme variables (with `--text-*--line-height`) and spaces as `--spacing-*` named values.

## Implementation Guidance

### The formula
For size range `minSize → maxSize` (px) across viewport `minVw → maxVw` (px), with 16px = 1rem:
```
slope        = (maxSize - minSize) / (maxVw - minVw)
intercept    = minSize - slope * minVw
preferred    = (intercept / 16)rem + (slope * 100)vw
font-size    = clamp(minSize/16 rem, preferred, maxSize/16 rem)
```
Example, 16px→20px over 360→1240px: slope = 4/880 = 0.004545; intercept = 16 − 1.636 = 14.364px → 0.8977rem; so `clamp(1rem, 0.8977rem + 0.4545vw, 1.25rem)`.

### Utopia-style token output (360→1240px, 16→20px base, 1.2→1.25 ratio)
```css
:root {
  --step--1: clamp(0.8333rem, 0.7907rem + 0.1894vw, 0.9375rem);
  --step-0:  clamp(1rem, 0.8977rem + 0.4545vw, 1.25rem);
  --step-1:  clamp(1.2rem, 1.0517rem + 0.6591vw, 1.5625rem);
  --step-2:  clamp(1.44rem, 1.2301rem + 0.9330vw, 1.9531rem);
  --step-3:  clamp(1.728rem, 1.4362rem + 1.2971vw, 2.4414rem);
  --step-4:  clamp(2.0736rem, 1.6734rem + 1.7785vw, 3.0518rem);
  --step-5:  clamp(2.4883rem, 1.9457rem + 2.4116vw, 3.8147rem);

  --space-3xs: clamp(0.25rem, 0.2244rem + 0.1136vw, 0.3125rem);
  --space-2xs: clamp(0.5rem, 0.4489rem + 0.2273vw, 0.625rem);
  --space-xs:  clamp(0.75rem, 0.6733rem + 0.3409vw, 0.9375rem);
  --space-s:   clamp(1rem, 0.8977rem + 0.4545vw, 1.25rem);
  --space-m:   clamp(1.5rem, 1.3466rem + 0.6818vw, 1.875rem);
  --space-l:   clamp(2rem, 1.7955rem + 0.9091vw, 2.5rem);
  --space-xl:  clamp(3rem, 2.6932rem + 1.3636vw, 3.75rem);
  --space-2xl: clamp(4rem, 3.5909rem + 1.8182vw, 5rem);
  /* one-up pairs */
  --space-s-m: clamp(1rem, 0.6420rem + 1.5909vw, 1.875rem);
  --space-m-l: clamp(1.5rem, 1.0909rem + 1.8182vw, 2.5rem);
  --space-l-xl: clamp(2rem, 1.2841rem + 3.1818vw, 3.75rem);
}
```
(Computed with the formula above for these parameters, rounded to 4 decimals. Regenerate with the Utopia calculators for your own parameters.)

### Choosing ranges
| Content | Suggested range (min → max) |
|---|---|
| Body text | 1rem → 1.125–1.25rem |
| Small/meta | 0.8125rem → 0.875rem (or fixed) |
| H3 | 1.25rem → 1.5rem |
| H1 display | 2rem → 3.5–4rem (check ratio ≤ ~2.5) |
| Section padding | `--space-l` → `--space-2xl` pair |

## Recommended Workflow
1. Agree min/max viewport, base size and ratios with design (Utopia's type calculator supports a Figma plugin workflow).
2. Generate type and space tokens; commit them to the tokens layer / Tailwind `@theme`.
3. Map semantic roles: `h1 → --step-5`, `body → --step-0`, `section gap → --space-l-xl`.
4. Replace breakpoint font-size overrides with tokens.
5. Test zoom (200%/400%), large default font size, and narrow and wide viewports.
6. Document the scale in Storybook (type specimen at multiple widths).

## Patterns
**Fluid heading with container units**
```css
.hero { container-type: inline-size; }
.hero h1 { font-size: clamp(2rem, 1.25rem + 4cqi, 4rem); line-height: 1.05; text-wrap: balance; }
```

**Flow spacing that scales with the text**
```css
.prose > * + * { margin-block-start: var(--flow-space, 1em); }
.prose :is(h2, h3) { --flow-space: var(--space-l); }
```

**Tailwind v4 theme tokens**
```css
@theme {
  --text-step-0: clamp(1rem, 0.8977rem + 0.4545vw, 1.25rem);
  --text-step-0--line-height: 1.6;
  --text-step-5: clamp(2.4883rem, 1.9457rem + 2.4116vw, 3.8147rem);
  --text-step-5--line-height: 1.1;
  --spacing-section: clamp(3rem, 2.6932rem + 1.3636vw, 3.75rem);
}
```
Usage: `className="text-step-5 py-section"`.

**Line-height that adapts to size**
```css
h1, h2, h3 { line-height: calc(1em + 0.4rem); }
```

## Anti-Patterns
- **`font-size: 4vw`.** Ignores zoom and user font preferences; tiny on phones, huge on ultrawide. Use `clamp()` with rem.
- **Huge ranges (`clamp(1rem, …, 6rem)`).** Zoom can't reach 200% text size (1.4.4). Narrow the range or use a larger minimum.
- **px endpoints (`clamp(16px, …, 20px)`).** Ignores the user's default font size setting. Use rem.
- **Fluid body text in dense app UIs.** Inconsistent table/forms alignment. Use fixed rem tokens.
- **Hand-tuned per-component clamps.** Inconsistent rhythm. Use a scale.
- **Setting `html { font-size: 62.5% }` or vw on `html`.** Breaks user preferences and every rem. Leave root size alone.

## Accessibility
- WCAG 1.4.4 Resize Text (AA): text must scale to 200% without loss. Verify with browser zoom; Utopia warns on failing steps.
- WCAG 1.4.10 Reflow and 1.4.12 Text Spacing: fluid spacing must not clip content. Avoid fixed heights.
- Respect user default font size (rem everywhere; don't set root px).
- Keep body text ≥ 1rem and line length ≈ 45–75 characters.

## Responsive Design
Fluid scales reduce breakpoints to layout changes only. Use `vw` for page-level tokens and `cqi` for component-level tokens. Combine with container queries when a component needs discrete layout shifts plus continuous sizing.

## Performance
- `clamp()` is resolved in CSS with no JS or resize listeners.
- Font-size changes on resize trigger layout, which is normal for resizing, but avoid transitions on font-size.
- Fewer media queries give smaller CSS.

## Security
No specific concerns.

## Testing
- Playwright screenshots at 360, 768, 1240, 1920px for type specimen pages.
- Zoom test: Chrome zoom 200% plus Firefox "Zoom text only" (catches vw-only sizes).
- Unit test token generation scripts (if generating clamps in code) against known Utopia output.

## Tooling
- **Utopia** (utopia.fyi): type/space/clamp calculators, Figma plugin. Community, active.
- `utopia-core` npm package for generating scales in build scripts. Community.
- `tailwind-utopia` / `tailwind-clamp`. Community plugins, mostly v3-oriented; prefer plain `@theme` tokens in v4.
- Modern Font Stacks; Capsize (`@capsizecss/core`) for trimming leading if needed (CSS `text-box-trim` is the native path).

## Framework Notes
- **Next.js App Router:** define fluid tokens in `app/globals.css` (or the Tailwind `@theme`). Load fonts with `next/font` so metric-matched fallbacks (`adjustFontFallback`) prevent CLS as fluid sizes render. No client code is needed; tokens work in Server Components.
- **React (Vite SPA):** import the tokens stylesheet in `main.tsx`. Avoid `window.innerWidth`-based font-size calculations in hooks; clamp does it without re-renders.
- **MDX content (Next.js `@next/mdx`):** map MDX components (`h1`, `p`) to classes using the step tokens via `mdx-components.tsx`.

## AI Agent Guidance
- Do use existing step/space tokens. If none exist, generate a scale (Utopia math) rather than ad-hoc clamps.
- Do include rem in every preferred value and keep max/min ≤ ~2.5×.
- Don't use raw `vw` font sizes or px clamp endpoints; don't change the root font size.
- Don't apply fluid sizes to dense data UI unless the design system specifies it.
- Before done: check 360px and 1440px widths and 200% zoom; confirm headings don't overflow (long words, `overflow-wrap: anywhere` if needed).

## Examples
```tsx
// mdx-components.tsx (Next.js) — map prose elements to fluid tokens
import type { MDXComponents } from "mdx/types";

export function useMDXComponents(components: MDXComponents): MDXComponents {
  return {
    h1: (props) => <h1 className="text-step-5 font-bold tracking-tight text-balance" {...props} />,
    h2: (props) => <h2 className="mt-(--space-l) text-step-3 font-semibold text-balance" {...props} />,
    p: (props) => <p className="mt-(--space-s) max-w-[65ch] text-step-0 text-pretty" {...props} />,
    ...components,
  };
}
```
```tsx
// app/components/Section.tsx — fluid vertical rhythm via space pairs
export function Section({ children }: { children: React.ReactNode }) {
  return <section className="px-(--space-s-m) py-(--space-l-xl)">{children}</section>;
}
```

## Related Skills
- [typography-systems](../typography-systems/Skill.md) — font choice, scales, line-height, measure
- [spacing-and-layout-systems](../spacing-and-layout-systems/Skill.md) — space tokens usage
- [container-queries](../container-queries/Skill.md) — cqi-based fluid values
- [responsive-design](../responsive-design/Skill.md) — where fluid sizing fits
- [font-loading-performance](../font-loading-performance/Skill.md) — avoiding CLS with web fonts
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — resize text and reflow criteria

## Sources
- [Utopia — Fluid type scale calculator](https://utopia.fyi/type/calculator/) — Community — scale parameters, generated tokens
- [Utopia — Clamp blog post](https://utopia.fyi/blog/clamp/) — Community — clamp formula, zoom caveat
- [Trys Mudford — Utopia WCAG warnings](https://www.trysmudford.com/blog/utopia-wcag-warnings/) — Community — SC 1.4.4 checks in the calculator
- [OddBird — Reimagining fluid typography](https://www.oddbird.net/2025/02/12/fluid-type/) — Community — critique and user-preference considerations
- [LogRocket — Fluid vs responsive typography](https://blog.logrocket.com/fluid-vs-responsive-typography-css-clamp/) — Community — vw zoom problem
- [MDN — clamp()](https://developer.mozilla.org/en-US/docs/Web/CSS/clamp) — Official — function semantics
- [Tailwind — Theme variables](https://tailwindcss.com/docs/theme) — Official — --text-* with line-height

## License / Usage Notes
Utopia is by Clearleft (James Gilyead, Trys Mudford). Concepts are summarized, and the token values shown are computed independently for illustration. MDN is CC-BY-SA.

## Quality Tier
A — Established method with verified accessibility guidance. Exact values should be regenerated per project.

## Status
Active

## Last Verified
2026-09-15
