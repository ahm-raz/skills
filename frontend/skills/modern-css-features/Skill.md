# Modern CSS Features

## Summary
A current (Sept 2026) map of which modern CSS features you can use, which need fallbacks, and which are still experimental, based on Baseline and Interop 2026. It replaces "can I use X?" guesswork with a support-tier decision table plus the right code pattern for each tier. It also replaces JavaScript and preprocessor workarounds that native CSS now handles.

## Category
CSS & Styling

## Subcategories
Baseline, Interop 2026, progressive enhancement, @supports, :has(), container queries, anchor positioning, @scope, color functions, @starting-style, field-sizing, text-box, if(), grid-lanes

## Problem It Solves
AI agents and developers tend to reach for JS, Sass, or old hacks for things native CSS now does, like parent selection, component-aware responsiveness, tooltip positioning, entry animations, auto-growing textareas, and color derivation. The opposite mistake also happens: shipping Chromium-only features with no fallback. This skill fixes both by tying each feature to its real cross-browser status.

## When To Use
- Choosing between a native CSS feature and a JS/library solution.
- Reviewing code for outdated workarounds (JS height animations, Popper for simple tooltips, Sass color functions).
- Setting a browser-support policy (e.g. "Baseline Widely available + progressive enhancement for Newly available").
- Deciding whether a feature needs `@supports` or a fallback.

## When Not To Use
- Projects that must support legacy browsers (IE11, old embedded WebViews). Use a PostCSS/Lightning CSS downlevel strategy instead.
- Email HTML. Email clients lag years behind browsers.
- Deep dives on one feature. See the dedicated skills (container queries, nesting/scope, cascade layers, color systems).

## Core Principles
1. **Baseline is the support vocabulary.** "Newly available" means it works in the current Chrome, Edge, Firefox and Safari. "Widely available" means 30 months after that. Pick a tier as team policy.
2. **Progressive enhancement over polyfills.** Most new CSS degrades gracefully: unknown properties are ignored. Write the fallback first, then the enhancement.
3. **Use `@supports` for layout-critical features only.** Cosmetic enhancements (text-wrap, scrollbar-color) need no guard.
4. **Native first, JS second.** If CSS can express it declaratively, it is faster, SSR-safe, and hydration-free.
5. **Verify dates.** Support changes monthly. Re-check Baseline status before hard-committing to Newly available features.

## Best Practices
- Set a documented support target, e.g. "Baseline Widely available; Newly available allowed with graceful fallback". Enforce it with a linter (see Tooling).
- Prefer `:has()` over JS class toggling for parent/sibling state (`.card:has(img)`, `form:has(:user-invalid)`).
- Use `:user-valid` / `:user-invalid` instead of `:valid` / `:invalid` so errors don't show before the user interacts.
- Use `@starting-style` + `transition-behavior: allow-discrete` for entry/exit animations of `display: none` / popover / dialog elements.
- Use `field-sizing: content` for auto-growing textareas and inputs (Baseline 2026). Keep `min-block-size` / `max-block-size` limits.
- Use `text-wrap: balance` on headings and `text-wrap: pretty` on body text as zero-risk enhancements.
- Use `scrollbar-gutter: stable` to prevent layout shift when scrollbars appear.
- Use `inset`, `aspect-ratio`, `gap` on flex, and individual `translate`/`rotate`/`scale` properties. They are all widely available.

## Implementation Guidance

### Support tiers (verified 2026-09-15)
| Feature | Status | Guidance |
|---|---|---|
| Cascade layers `@layer`, `:has()`, `:is()/:where()`, container size queries + `cq*` units, subgrid, `oklch()`/`oklab()`, `color-mix()`, flex `gap`, `aspect-ratio`, `inset`, logical properties, `clamp()` | Widely available | Use freely |
| CSS nesting (incl. relaxed syntax) | Baseline since late 2023 | Use freely; put declarations before nested rules for older engines |
| `light-dark()` | Newly available (Widely ~Nov 2026) | Use; fallback via `@media (prefers-color-scheme)` only if you target older browsers |
| `@starting-style`, `transition-behavior`, relative color syntax (`oklch(from ...)`), Popover API, `text-wrap: balance` | Newly available (2024) | Use with graceful fallback (no animation / static color) |
| `@scope` (Firefox 146, Dec 2025) | Newly available | Use for component scoping; see css-nesting-and-scope |
| Anchor positioning (early 2026) | Newly available; Interop 2026 focus | Use for tooltips/popovers with `position-try` fallbacks; keep a JS lib if you need older Safari/Firefox |
| Container style queries on custom properties (Firefox 151, May 2026) | Newly available | Use for variant/theme switches; standard-property style queries unsupported everywhere |
| `contrast-color()` (Apr 2026) | Newly available | Use behind `@supports` with a manual token fallback |
| `field-sizing`, `:open`, `shape()`, custom highlights, `rcap/rch/rex/ric` units | Baseline 2026 | Progressive enhancement |
| Name-only container queries (Chrome 148) | Newly available per web.dev May 2026 | Verify before relying on it |
| `if()`, `@function`, typed `attr()`, `sibling-index()`, `interpolate-size`/`calc-size()`, customizable `<select>` (`appearance: base-select`), `reading-flow`, scroll-state queries | Limited (mostly Chromium) | Enhancement only; never load-bearing |
| `display: grid-lanes` (masonry) | Safari 26.4 stable; others flagged | `@supports (display: grid-lanes)` with a grid fallback |

### Interop 2026 CSS focus areas
These are the features browsers are actively converging on, so their support gaps are closing: anchor positioning, container style queries, dialogs/popovers (`closedby`, `:open`), scroll-driven animations, view transitions, `attr()`, `contrast-color()`, custom highlights, media pseudo-classes, scroll snap, `shape()`, `zoom`.

### Feature detection
```css
/* Layout-critical: guard it */
.gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(16rem, 1fr)); }
@supports (display: grid-lanes) {
  .gallery { display: grid-lanes; grid-template-columns: repeat(auto-fill, minmax(16rem, 1fr)); }
}

/* Selector support */
@supports selector(:has(a)) { /* ... */ }

/* Cosmetic: no guard needed */
h1, h2 { text-wrap: balance; }
```

## Recommended Workflow
1. Identify the UI requirement (e.g. "tooltip follows trigger", "card changes layout in sidebar").
2. Check this table, then MDN or webstatus.dev for the latest Baseline status.
3. If Widely available, implement natively.
4. If Newly available or Limited, write the baseline experience first, then layer the enhancement (unguarded if cosmetic, `@supports` if structural).
5. Test in current Safari and Firefox, not just Chrome.
6. Remove obsolete JS/polyfills that the native feature replaces.

## Patterns
**Parent-state styling with :has()**
```css
.field:has(input:user-invalid) .field__hint { color: var(--color-danger); }
.card:has(> img) { grid-template-rows: auto 1fr; }
body:has(dialog[open]) { overflow: hidden; }
```

**Entry/exit animation for popover**
```css
[popover] {
  opacity: 0; translate: 0 0.5rem;
  transition: opacity .2s, translate .2s, overlay .2s allow-discrete, display .2s allow-discrete;
}
[popover]:popover-open { opacity: 1; translate: 0 0; }
@starting-style { [popover]:popover-open { opacity: 0; translate: 0 0.5rem; } }
```

**Anchor-positioned tooltip with fallback**
```css
.trigger { anchor-name: --tip; }
.tooltip {
  position: absolute; position-anchor: --tip;
  position-area: block-start; margin-block-end: .5rem;
  position-try-fallbacks: flip-block, flip-inline;
}
```

**Auto-growing textarea**
```css
textarea { field-sizing: content; min-block-size: 3lh; max-block-size: 12lh; }
```

## Anti-Patterns
- **JS `ResizeObserver` for component breakpoints.** Use container queries instead.
- **Popper/Floating UI for a static tooltip in an evergreen-only app.** Anchor positioning covers it. Keep Floating UI when you need virtual elements or older browser support.
- **Sass `darken()`/`lighten()`.** They are compile-time and HSL-based, so perceptually uneven. Use `oklch(from var(--c) calc(l - .1) c h)` or `color-mix(in oklch, ...)`.
- **Using `if()` or customizable select as load-bearing.** They are Chromium-only, so other users get a broken UI. Use them only as enhancements.
- **Guarding every property with `@supports`.** That is noise. Guard only when the fallback path needs different declarations.
- **Assuming "Chrome shipped it" = usable.** Check Safari and Firefox (Baseline).

## Accessibility
- `:focus-visible` (widely available) is the right focus-ring hook. Never remove outlines without a replacement (WCAG 2.4.7, 2.4.11 Focus Not Obscured, 2.4.13 Focus Appearance AAA).
- Wrap motion enhancements (`@starting-style`, view transitions, scroll-driven animations) in `@media (prefers-reduced-motion: no-preference)`.
- `contrast-color()` only picks black or white. It doesn't guarantee WCAG 4.5:1 on mid-tone backgrounds, so still verify with a checker.
- `:has()`-driven visual state must be mirrored by real semantics (`aria-invalid`, `aria-expanded`). CSS state is invisible to assistive tech.
- Popover API and `<dialog>` give correct top-layer and focus behavior for free. Prefer them to hand-rolled overlays.

## Responsive Design
Container queries (size and custom-property style queries) are the modern default for component-level adaptation. Viewport media queries remain for page-level layout and user preferences (`prefers-*`, `hover`, `pointer`). See responsive-design and container-queries.

## Performance
- Native CSS features run in the style/layout engine: no hydration, no main-thread JS.
- `:has()` with broad subjects (`body:has(...)`, `*:has(...)`) can cause expensive invalidation on large DOMs. Scope the subject tightly.
- `content-visibility: auto` + `contain-intrinsic-size` can speed up long pages.
- Removing JS positioning/animation libraries reduces bundle size.

## Security
- `attr()` with types can read attribute values into styles. Never put untrusted user data into `style` attributes or CSS custom properties that feed `url()`.
- CSS injection (untrusted class names/styles) can exfiltrate data via attribute selectors + `background: url()`. Sanitize user-supplied CSS and use CSP `style-src`.

## Testing
- Cross-browser test in Playwright with chromium, firefox and webkit projects. Visual-regression snapshots per engine for enhanced features.
- Test the fallback path by disabling the feature (e.g. temporarily rename the property) or run an older engine in CI.
- Lint for support with `stylelint-plugin-use-baseline` or browserslist-aware tools.

## Tooling
- **webstatus.dev / web-features explorer / MDN Baseline badges.** The authoritative status sources.
- **caniuse.com.** Includes `wf-*` Baseline-mapped entries.
- **Lightning CSS / PostCSS Preset Env.** Downlevel nesting, color functions, logical properties per browserslist.
- **stylelint-plugin-use-baseline.** Flags non-Baseline features (community, ESLint CSS also offers `use-baseline`).
- **@eslint/css `use-baseline` rule.** Official ESLint CSS language plugin.

## Framework Notes
- **Next.js (App Router, v16.x):** native CSS features need no client JS, so styles keyed to `:has()`, `:open`, `[popover]`, container queries and `@starting-style` work inside Server Components with zero hydration cost. Global CSS is imported in `app/layout.tsx`; component CSS is in CSS Modules or Tailwind. React attribute names apply: `popover`, `popoverTarget`, `popoverTargetAction` (typed in `@types/react` 19). Use `closedby` only as a lowercase attribute if types lag.
- **React (Vite SPA):** same CSS. Prefer CSS state (`:has`, `:user-invalid`, `[aria-expanded]`) over `useState` + className toggles when the state is purely visual. Keep React state for anything that affects semantics or data.
- **Tailwind v4 in either:** exposes many modern features as utilities/variants (`@container`, `has-*`, `not-*`, `starting:`, `open:`, `field-sizing-content`, `text-balance`, logical utilities in 4.2+).
- **Hydration caveat:** customizable `<select>` markup (`<button><selectedcontent>`) inside `<select>` may trigger hydration warnings in some React/Next versions (MDN notes framework friction). Test before shipping; treat it as enhancement only.

## AI Agent Guidance
- Do check the support table (or MDN) before using any feature newer than 2023.
- Do write a fallback first for Newly available/Limited features that affect layout.
- Do replace JS workarounds (height animation, auto-grow textarea, parent class toggles) with native CSS when the support policy allows.
- Don't use `if()`, `@function`, `sibling-index()`, `appearance: base-select`, or `grid-lanes` without a working fallback.
- Don't assume style queries work on standard properties. Custom properties only.
- Before declaring done, confirm the UI works in WebKit and Gecko (Playwright), that reduced-motion is respected, and that there is no console CSS parse noise.

## Examples
```css
/* Modern base layer using only widely/newly available features */
@layer reset, base, components, utilities;

@layer base {
  :root { color-scheme: light dark; interpolate-size: allow-keywords; /* Chromium-only enhancement */ }
  body { background: light-dark(oklch(99% 0 0), oklch(18% 0.01 260)); color: light-dark(oklch(20% 0.02 260), oklch(94% 0.01 260)); }
  h1, h2, h3 { text-wrap: balance; }
  p { text-wrap: pretty; }
  :focus-visible { outline: 2px solid var(--color-focus, Highlight); outline-offset: 2px; }
  html { scrollbar-gutter: stable; }
}

@layer components {
  details::details-content { block-size: 0; overflow: clip; transition: block-size .25s, content-visibility .25s allow-discrete; }
  details[open]::details-content { block-size: auto; } /* animates only where interpolate-size is supported */
  @media (prefers-reduced-motion: reduce) { details::details-content { transition: none; } }
}
```

```tsx
// app/components/HelpPopover.tsx — Server Component: no JS, native popover + anchor positioning
import styles from "./HelpPopover.module.css";

export function HelpPopover({ id, label, children }: { id: string; label: string; children: React.ReactNode }) {
  return (
    <>
      <button type="button" popoverTarget={id} className={styles.trigger} style={{ anchorName: `--${id}` } as React.CSSProperties}>
        {label}
      </button>
      <div id={id} popover="auto" className={styles.panel} style={{ positionAnchor: `--${id}` } as React.CSSProperties}>
        {children}
      </div>
    </>
  );
}
```
```css
/* HelpPopover.module.css */
.panel {
  position-area: block-end span-inline-end; margin: 0; margin-block-start: .5rem;
  position-try-fallbacks: flip-block;
  opacity: 0; transition: opacity .15s, display .15s allow-discrete, overlay .15s allow-discrete;
  &:popover-open { opacity: 1; }
}
@starting-style { .panel:popover-open { opacity: 0; } }
/* Fallback when anchor positioning is unsupported: popover centers in the top layer (still usable) */
```

## Related Skills
- [container-queries](../container-queries/Skill.md) — component-level responsiveness details
- [css-nesting-and-scope](../css-nesting-and-scope/Skill.md) — nesting and @scope in depth
- [css-cascade-layers-and-specificity](../css-cascade-layers-and-specificity/Skill.md) — @layer strategy
- [color-systems](../color-systems/Skill.md) — oklch, relative color, contrast-color
- [floating-element-positioning](../floating-element-positioning/Skill.md) — anchor positioning vs Floating UI
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md) — @starting-style and discrete transitions
- [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md) — verifying support

## Sources
- [Baseline 2026 — web.dev](https://web.dev/baseline/2026) — Official — list of features reaching Baseline in 2026
- [Interop 2026 — web.dev](https://web.dev/blog/interop-2026) — Official — focus areas list
- [New to the web platform in May 2026 — web.dev](https://web.dev/blog/web-platform-05-2026) — Official — container style queries Firefox 151, :open, name-only CQs
- [Announcing Interop 2026 — WebKit](https://webkit.org/blog/17818/announcing-interop-2026/) — Official — cross-check
- [How to @scope CSS now that it's Baseline — Frontend Masters](https://frontendmasters.com/blog/how-to-scope-css-now-that-its-baseline/) — Community — @scope status
- [contrast-color() — MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value/contrast-color) — Official — status and limits
- [if() — MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/if) — Official — not Baseline
- [Customizable select — MDN](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Customizable_select) — Official — limited availability
- [When will CSS Grid Lanes arrive? — WebKit](https://webkit.org/blog/17758/when-will-css-grid-lanes-arrive-how-long-until-we-can-use-it/) — Official — masonry status
- [Anchor positioning — web.dev Learn CSS](https://web.dev/learn/css/anchor-positioning) — Official — syntax

## License / Usage Notes
Content summarized from MDN (CC-BY-SA), web.dev (CC-BY 4.0), and WebKit blog. Code examples are original. Support data changes frequently, so re-verify.

## Quality Tier
A — Grounded in official Baseline/Interop data as of Sept 2026. Fast-moving support facts require periodic re-verification.

## Status
Active

## Last Verified
2026-09-15
