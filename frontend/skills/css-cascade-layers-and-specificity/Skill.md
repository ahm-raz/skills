# CSS Cascade Layers and Specificity

## Summary
How the cascade decides which declaration wins: origin and importance, then `@layer` order, then specificity, then source order. Also how to use cascade layers (Widely available) to make style priority explicit in React/Next.js apps that mix resets, Tailwind, CSS Modules, and third-party component CSS. Covers `:where()`/`:is()` specificity tools, unlayered-style gotchas, and `!important` inversion.

## Category
CSS & Styling

## Subcategories
Cascade, specificity, @layer, layer ordering, unlayered styles, !important, :where(), :is(), third-party CSS, Tailwind layers, CSS chunk ordering in Next.js

## Problem It Solves
"Why isn't my style applying?" Specificity wars, `!important` escalation, third-party CSS overriding your components, and Next.js CSS chunk order differing between dev and production. Layers turn implicit priority into an explicit, documented contract.

## When To Use
- Debugging overrides that don't apply.
- Integrating library CSS (date pickers, editors, carousels) with your design system.
- Combining Tailwind v4 (which uses native layers) with CSS Modules or legacy CSS.
- Establishing a CSS architecture's priority order.

## When Not To Use
- Inline style/JS-driven priority problems. Those are not cascade-layer issues (inline styles beat all normal layered/unlayered author rules).
- Shadow DOM encapsulation issues (different cascade context; use `::part` and custom properties).

## Core Principles
1. **Cascade order (normal declarations):** origin/importance → context (shadow) → **inline style** → **layer** → **specificity** → **order of appearance**.
2. **Layer order beats specificity.** An ID selector in an earlier layer loses to a single class in a later layer.
3. **Unlayered styles beat all layered styles** (for normal declarations). Legacy or third-party unlayered CSS will override your layered design system.
4. **`!important` reverses layer order.** Important declarations in earlier layers beat important ones in later layers, and important layered beats important unlayered. Layers let resets use `!important` safely for accessibility-critical rules.
5. **The first declaration of a layer name fixes its position.** Declare the full order once, early: `@layer reset, base, components, utilities;`.
6. **Keep specificity flat within layers.** Single classes; `:where()` for zero-specificity defaults.

## Best Practices
- Put the layer order statement at the very top of the first-loaded stylesheet (e.g. `app/globals.css`) before any imports that create layers.
- Import third-party CSS into a named low layer: `@import url("some-lib/styles.css") layer(vendor);`.
- Wrap legacy CSS in `@layer legacy` so new code in later layers wins without specificity hacks.
- Use nested layers for packages: `@layer components.datepicker { }` (referenced as `components.datepicker`).
- Use `:where()` in libraries/base styles so consumers override with any single class.
- Use `:is()` when you want grouping but keep the highest specificity in the list (be aware it can raise specificity).
- Reserve `!important` for utility-override classes and accessibility enforcement (e.g. reduced motion, `[hidden]`).
- Learn specificity notation (a, b, c) = (ID, class/attribute/pseudo-class, type/pseudo-element). Compare left to right.

## Implementation Guidance

### Specificity quick reference
| Selector | Specificity |
|---|---|
| `*`, `:where(...)` | (0,0,0) |
| `button`, `::before` | (0,0,1) |
| `.btn`, `[type=submit]`, `:hover` | (0,1,0) |
| `.card .title` | (0,2,0) |
| `#nav a` | (1,0,1) |
| `:is(#a, .b) span` | (1,0,1): takes the most specific argument |
| `:not(.x)`, `:has(.x)` | specificity of their argument, (0,1,0) |
| `&` in nesting | like `:is()` of the parent list |
| `style=""` attribute | beats all normal author rules (not part of specificity; separate cascade step) |

### Tailwind v4 layers
Tailwind v4 emits `@layer theme, base, components, utilities;`. Consequences:
- Your unlayered CSS (e.g. a CSS Module without `@layer`) beats Tailwind utilities regardless of specificity. `.card { padding: 1rem }` unlayered overrides `p-8` on the same element.
- To let utilities override component styles, put component CSS in `@layer components` (or a layer declared before `utilities`).
- To extend the order, declare it before importing Tailwind:
```css
@layer theme, base, vendor, components, utilities, overrides;
@import "tailwindcss";
@import url("react-day-picker/style.css") layer(vendor);
```

### Recommended layer stack
```css
@layer reset, vendor, tokens, base, layouts, components, utilities, overrides;
```
| Layer | Contents |
|---|---|
| reset | box-sizing, margin resets, media defaults |
| vendor | third-party library CSS |
| tokens | custom properties |
| base | element typography, links, focus styles |
| layouts | stack/cluster/grid primitives |
| components | component styles (CSS Modules wrapped in `@layer components`) |
| utilities | single-purpose classes (Tailwind utilities) |
| overrides | rare, documented escapes; print styles |

### Layering existing CSS you don't control
- `@import url(lib.css) layer(vendor);` in CSS (bundlers preserve this).
- For JS-imported CSS (`import "lib/styles.css"` in a component), layers can't be applied from the import. Move it into the global stylesheet with `@import … layer()`, or postprocess with PostCSS (`@csstools/postcss-cascade-layers` for downleveling, or a custom plugin to wrap).
- Styles injected at runtime by JS libraries (Emotion/MUI) are unlayered, so they will beat your layered styles. MUI v6/v7 offers `enableCssLayer` on its Next.js AppRouterCacheProvider to emit into `@layer mui`.

## Recommended Workflow
1. Inventory style sources: reset, Tailwind, global CSS, CSS Modules, library CSS, runtime-injected CSS.
2. Write the layer order statement and place it first.
3. Move each source into its layer (imports with `layer()`, wrap modules in `@layer components`).
4. Remove `!important` and specificity hacks that the new order makes unnecessary.
5. Debug with DevTools: Styles pane groups rules by layer; Elements → "Layers" view shows order.
6. Add stylelint rules to keep specificity flat and forbid unlayered rules in component files (custom rule or review checklist).

## Patterns
**Zero-specificity library defaults**
```css
@layer components {
  :where(.ds-input) { border: 1px solid var(--color-border); padding: .5rem .75rem; }
}
/* Consumer: any class in a later layer or even same layer later wins */
```

**Accessibility enforcement via important in the reset layer**
```css
@layer reset {
  [hidden] { display: none !important; }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { animation-duration: .01ms !important; animation-iteration-count: 1 !important; transition-duration: .01ms !important; scroll-behavior: auto !important; }
  }
}
```
Because `!important` reverses layer order, these beat `!important` in later layers, making them hard to accidentally override.

**Legacy containment**
```css
@layer legacy, components, utilities;
@import url("./legacy/site.css") layer(legacy);
```

**Anonymous layer for one-off isolation (use sparingly)**
```css
@layer { .experiment { … } }  /* can't be referenced or reordered later */
```

## Anti-Patterns
- **Mixing unlayered component CSS with layered Tailwind and expecting utilities to override.** Unlayered always wins. Wrap component CSS in `@layer components`.
- **Declaring layers implicitly in random files.** The first appearance fixes the order, which then depends on chunk load order in Next.js. Declare the full order once, in the root stylesheet.
- **`!important` to override a vendor.** Escalation. Put the vendor in a lower layer.
- **ID selectors for styling.** (1,0,0) specificity is hard to override. Use classes.
- **Over-qualifying (`div.card.card--active`).** Unnecessary specificity. Use `.card[data-active]`.
- **Assuming `:is()` is zero-specificity.** It takes the highest argument. Use `:where()` for zero.
- **Relying on import order in Next.js.** CSS chunk order may vary between routes/dev/prod. Rely on layers.

## Accessibility
- Focus styles belong in `base` with enough priority to survive component overrides. Test that no component removes them.
- User stylesheets and forced-colors mode sit in the cascade too: important user styles beat all author styles. Don't fight them (no `!important` on colors in components).
- Use layered `!important` in `reset` for reduced-motion and `[hidden]` enforcement.

## Responsive Design
Media and container queries don't change priority; rules inside them follow the same layer/specificity rules. Keep responsive overrides in the same layer as the base rule they modify.

## Performance
Layers have negligible runtime cost. Removing specificity hacks simplifies selectors slightly. Avoid thousands of anonymous layers generated by tooling.

## Security
Third-party CSS placed in a low layer can't override your security-relevant UI (e.g. hiding a consent banner) through normal declarations. `!important` in vendor layers can still, since importance reverses order, so audit vendor CSS for `!important`.

## Testing
- Regression test: a story that renders a component with utility overrides (`<Card className="p-8">`) and asserts computed padding.
- Visual regression after reordering layers.
- CI grep for `!important` outside allowed layers/files.

## Tooling
- Chrome/Firefox/Safari DevTools layer inspectors. Native.
- `@csstools/postcss-cascade-layers`. Downlevel for older browsers (rarely needed now).
- Stylelint: `selector-max-specificity`, `selector-max-id`, `declaration-no-important`.
- Polypane/Specificity calculators (e.g. specificity.keegan.st). Community.

## Framework Notes
- **Next.js App Router:** put `@layer …;` order first in `app/globals.css`, imported in `app/layout.tsx`. CSS Modules should wrap rules in `@layer components { }`. Import third-party CSS via `@import … layer(vendor)` in globals rather than `import "lib.css"` in components, since component-level imports can load in varying order across routes. MUI with Emotion: enable CSS layer output (`AppRouterCacheProvider options={{ enableCssLayer: true }}`) so MUI styles go into `@layer mui`.
- **React (Vite SPA):** same approach in `src/index.css`. Vite inlines `@import` so `layer()` works.
- **Tailwind v4 + shadcn/ui:** shadcn components are pure utilities, so overrides via `className` work through tailwind-merge. Any custom CSS you add must be layered to not accidentally beat utilities.

## AI Agent Guidance
- Do diagnose override issues by checking layer membership first, then specificity, then order.
- Do wrap new component CSS in the project's components layer.
- Don't add `!important` or increase specificity to fix an override without explaining why layers can't solve it.
- Don't import third-party CSS from components when a global layered import is possible.
- Before done: confirm in DevTools which layer the winning rule comes from, and that utilities/`className` overrides still work.

## Examples
```css
/* app/globals.css */
@layer theme, base, vendor, components, utilities, overrides;
@import "tailwindcss";
@import url("react-day-picker/style.css") layer(vendor);

@layer base {
  :focus-visible { outline: 2px solid var(--color-accent); outline-offset: 2px; }
}

@layer vendor {
  /* adapt vendor variables to tokens, still beneath components */
  .rdp-root { --rdp-accent-color: var(--color-accent); }
}
```
```css
/* app/components/Card.module.css */
@layer components {
  .card { padding: 1rem; border-radius: var(--radius-lg); background: var(--color-surface-1); }
}
```
```tsx
// app/page.tsx — utility override wins because utilities layer > components layer
import styles from "./components/Card.module.css";
export default function Page() {
  return <div className={`${styles.card} p-8`}>Padding is 2rem</div>;
}
```

## Related Skills
- [css-architecture](../css-architecture/Skill.md) — overall structure using layers
- [css-nesting-and-scope](../css-nesting-and-scope/Skill.md) — scope proximity in the cascade
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — Tailwind's native layers
- [css-modules](../css-modules/Skill.md) — wrapping modules in layers
- [material-ui](../material-ui/Skill.md) — Emotion and CSS layer integration
- [modern-css-features](../modern-css-features/Skill.md) — support context

## Sources
- [MDN — @layer](https://developer.mozilla.org/en-US/docs/Web/CSS/@layer) — Official — syntax, nested/anonymous layers
- [MDN — Cascade layers guide](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Styling_basics/Cascade_layers) — Official — unlayered and !important behavior
- [MDN — Specificity](https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity) — Official — :is/:where/:not rules
- [CSS Cascading and Inheritance Level 5 (W3C)](https://www.w3.org/TR/css-cascade-5/) — Official — cascade sort order
- [Tailwind CSS — Adding custom styles (layers)](https://tailwindcss.com/docs/adding-custom-styles) — Official — v4 layer names
- [web.dev — Interop 2026](https://web.dev/blog/interop-2026) — Official — cascade layer interop work
- [MUI — Next.js integration (CSS layers)](https://mui.com/material-ui/integrations/nextjs/) — Official — enableCssLayer option

## License / Usage Notes
MDN is CC-BY-SA and the W3C specs are under the W3C document license. Content is summarized, and code is original.

## Quality Tier
S — Spec-grounded cascade mechanics with verified Tailwind v4 layer interactions and practical Next.js guidance.

## Status
Active

## Last Verified
2026-09-15
