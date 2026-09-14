# Design System Architecture

## Summary
How to structure a design system as software: layers (tokens, primitives, components, patterns), package topology, styling strategy, theming, distribution and versioning, documentation, and multi-framework delivery. Draws on Brad Frost's Atomic Design as a mental model, headless-primitive composition as the 2026 default implementation strategy, and DTCG 2025.10 tokens as the foundation.

## Category
Architecture

## Subcategories
Atomic design, headless primitives, package structure, theming, multi-brand, versioning, distribution, documentation, copy-paste vs package

## Problem It Solves
Teams rebuild buttons and dialogs repeatedly, with inconsistent accessibility and visuals, and design changes require touching every app. A well-architected system centralizes decisions (tokens), behavior (accessible primitives), and components with a clear upgrade path.

## When To Use
- Two or more products/apps share a visual language.
- A single large app with many teams needs consistency.
- Rebranding or multi-brand/white-label requirements.

## When Not To Use
- A single small app: a local `ui/` folder plus tokens is enough.
- When an off-the-shelf library themed via tokens meets needs; don't build a system to avoid theming work.

## Core Principles
1. **Layered architecture:** tokens -> primitives (headless behavior) -> styled components -> patterns/recipes -> product templates.
2. **Tokens are the single source of visual truth**, exported to every platform.
3. **Don't reinvent accessible behavior.** Build on a proven headless layer (React Aria, Radix, Base UI, Ark UI/Zag) unless you have dedicated a11y expertise.
4. **Styling decoupled from behavior**, so themes and brands swap without code forks.
5. **Semantic versioning with changesets, codemods, and deprecation windows.**
6. **Documentation and code ship together** (stories, usage guidelines, a11y notes).
7. **Consumers can escape** — className merge, CSS variables, composition — without forking.

## Best Practices
- Atomic Design (atoms/molecules/organisms/templates/pages) is a vocabulary for thinking, not a folder mandate; most systems ship flat `components/<Name>/` folders.
- Pick one distribution model deliberately:
  | Model | Pros | Cons | Fit |
  |---|---|---|---|
  | Versioned npm package(s) | Central fixes, upgrade control | Upgrade lag, overrides harder | Multi-app orgs |
  | Copy-paste / registry (shadcn-style CLI) | Full ownership, easy customization | Fixes don't propagate | Single app, startups |
  | Hybrid (package primitives + registry recipes) | Balance | Two mechanisms | Mid/large orgs |
- Theme via CSS custom properties generated from tokens; components reference semantic variables (`--color-bg-surface`), never raw values.
- Multi-brand: brand x mode (light/dark) x density as token modifiers (DTCG Resolver module), not component props.
- Package layout: `tokens` (platform-agnostic outputs) + `core-css` (layers/utilities) + `react` (components) + `icons`. Keep styles framework-agnostic CSS so the same system serves Vite SPAs and Next.js apps.
- Ship ESM, `sideEffects` declared (CSS files marked as side effects), per-component entry points, and TypeScript types.
- Use Changesets for versioning and changelogs; automate releases with provenance (trusted publishing).
- Maintain an adoption dashboard (component usage scanning e.g. via AST or tools like Omlet/react-scanner).

## Implementation Guidance

### Repository topology
```
design-system/
  packages/
    tokens/            DTCG .tokens.json + resolver; builds CSS vars, TS, iOS, Android
    icons/             SVG sources -> React components + sprite
    core-css/          reset, CSS layers, utilities consuming token vars
    react/             components (built on headless primitives), 'use client' preserved in output
    codemods/          jscodeshift/ast-grep transforms per major
  apps/
    docs/              Storybook, or a Next.js docs site (e.g., Fumadocs/Nextra) embedding stories
  .changeset/
```

### Styling strategy decision table
| Constraint | Choice |
|---|---|
| Tailwind-based consumers | Tailwind v4 `@theme` from tokens + cva variants |
| Framework-agnostic CSS needed | CSS Modules or plain CSS with `@layer ds` + CSS vars |
| Zero-runtime typed styles | vanilla-extract, Panda CSS, StyleX |
| Must avoid runtime CSS-in-JS (RSC/streaming) | Avoid Emotion/styled-components runtime for new systems |

### CSS layering for safe overrides
```css
@layer reset, ds-tokens, ds-components, app;
@layer ds-components {
  .ds-button { background: var(--ds-color-action-primary-bg); border-radius: var(--ds-radius-control); }
  .ds-button[data-variant="secondary"] { background: var(--ds-color-action-secondary-bg); }
}
/* App styles in @layer app always win without !important */
```

### package.json for a component package
```json
{
  "name": "@acme/ds-react",
  "type": "module",
  "sideEffects": ["**/*.css"],
  "exports": {
    ".": { "types": "./dist/index.d.ts", "import": "./dist/index.js" },
    "./button": { "types": "./dist/button/index.d.ts", "import": "./dist/button/index.js" },
    "./styles.css": "./dist/styles.css"
  },
  "peerDependencies": { "react": "^19.0.0", "react-dom": "^19.0.0" }
}
```

## Recommended Workflow
1. Audit UI inventory (screenshots/usage scan); identify top 15 components by frequency.
2. Define token taxonomy (see design-token-architecture) and build pipeline.
3. Choose headless foundation and styling strategy; write ADRs.
4. Build components in priority order with stories, a11y tests, and docs.
5. Pilot with one product team; iterate API.
6. Publish with Changesets; set support policy (N-1 majors).
7. Establish governance and contribution model; track adoption.

## Patterns
- **Headless + skin:** `@acme/ds-react/Dialog` wraps Radix/Base UI/React Aria and applies tokens.
- **Recipes/patterns layer:** composed patterns (e.g., FilterBar, EmptyState) documented with code but shipped as registry items.
- **Theme provider as CSS scope:** `<div data-theme="brand-b" data-mode="dark">` switching variable sets; no JS re-render.
- **Codemod per breaking change:** `npx @acme/ds-codemods v5/button-variant`.
- **Component status labels:** Alpha / Beta / Stable / Deprecated shown in docs and exported metadata.

## Anti-Patterns
- **Building behavior from scratch** (custom combobox) — a11y bugs. Fix: wrap a headless library.
- **Hard-coded values in components** — theming impossible. Fix: semantic token vars only; lint with stylelint `declaration-strict-value`.
- **One mega-package including charts/editors** — consumer bundles bloat. Fix: separate heavy packages.
- **Runtime CSS-in-JS in a new system** — RSC incompatibility and runtime cost. Fix: zero-runtime or CSS vars.
- **Design system as a product team bottleneck** — Fix: federated contribution model (see governance).
- **Forking to customize** — Fix: expose composition, className merge, and token overrides.
- **Global CSS without layers/prefixes** — collisions with app CSS. Fix: `@layer` + prefix.

## Accessibility
- Every component meets WCAG 2.2 AA; document keyboard support and ARIA per APG pattern.
- Bake in focus-visible styles via tokens (`--ds-focus-ring`), target sizes (WCAG 2.5.8 Target Size Minimum 24x24 CSS px), and reduced-motion variants of transition tokens.
- Ship automated axe checks in Storybook CI and manual screen reader test notes per component.

## Responsive Design
- Components adapt via container queries rather than viewport breakpoints.
- Provide layout primitives (Stack, Grid, Cluster) using spacing tokens; density modes as token modifiers.

## Performance
- Per-component entry points and ESM for tree-shaking; avoid barrel side effects.
- Ship CSS as static files (or Tailwind utilities) rather than runtime injection.
- Icons as individual imports or SVG sprite, not a single icon-font bundle.

## Security
- Publish via trusted publishing (OIDC) with provenance; restrict tokens.
- Components rendering rich content must sanitize or require trusted input.

## Testing
- Unit/interaction tests per component (Vitest + Testing Library or Storybook test runner).
- Visual regression on stories (Chromatic, Playwright screenshots) across themes/modes.
- Accessibility: axe on every story; keyboard E2E for complex widgets.
- Contract tests: exports snapshot (API extractor) to catch accidental breaking changes.

## Tooling
- Storybook 9/10 — Active (component workshop/docs; verify current major).
- Changesets — Active.
- Style Dictionary v5 / Terrazzo — Active (DTCG 2025.10 token builds).
- Headless: React Aria, Radix Primitives, Base UI 1.x, Ark UI (Zag) — Active.
- vanilla-extract, Panda CSS, StyleX — Active zero-runtime.
- Emotion/styled-components — maintenance-mode for new systems (styled-components announced maintenance mode in 2025).
- API Extractor — Active (public API reports).

## Framework Notes
- **React (Vite SPA):** consume the package as ESM; import `@acme/ds-react/styles.css` once in `main.tsx`; `'use client'` directives are harmless no-ops.
- **Next.js App Router:** RSC-friendly means (1) no runtime CSS-in-JS, (2) `'use client'` at the top of each interactive component module in the published output (bundlers like tsup/Rollup strip directives unless configured — verify `dist` files), (3) display-only components stay directive-free so they render on the server with zero client JS. Import global CSS in `app/layout.tsx`. In a monorepo, add workspace packages to `transpilePackages` in `next.config.ts` if they ship untranspiled TS.
- **Theme without flash in Next.js:** read theme cookie in the root layout (Server Component) and set `<html data-theme>`; for system preference, use a tiny inline script with the CSP nonce or CSS `light-dark()`.
- **Headless bases that fit React/Next:** Radix Primitives, Base UI, React Aria Components, Ark UI (React). shadcn/ui registry for copy-paste recipes.

## AI Agent Guidance
- Use existing design-system components and tokens; never hard-code colors/spacing.
- Do: check docs/stories for the component status and correct API; add stories and a11y tests with any new component.
- Don't: create a parallel component with a similar name; don't add runtime CSS-in-JS; don't bypass `@layer` ordering.
- Verify: token lint passes, stories render in all themes, axe passes, exports snapshot updated intentionally, changeset added.

## Examples
```tsx
// packages/react/src/dialog/Dialog.tsx — skinning a headless primitive
'use client';
import { Dialog as Base } from '@base-ui-components/react/dialog';
import styles from './dialog.module.css';
export const Dialog = {
  Root: Base.Root,
  Trigger: Base.Trigger,
  Content: ({ className, ...p }: React.ComponentProps<typeof Base.Popup>) => (
    <Base.Portal><Base.Backdrop className={styles.backdrop} />
      <Base.Popup className={[styles.popup, className].filter(Boolean).join(' ')} {...p} /></Base.Portal>
  ),
  Title: Base.Title,
  Close: Base.Close,
};
```
(Check the installed Base UI package name/part names; the package was renamed around its 1.0 release.)

## Related Skills
- [design-token-architecture](../design-token-architecture/Skill.md) — token foundation
- [design-system-governance](../design-system-governance/Skill.md) — process and contribution
- [component-api-design](../component-api-design/Skill.md) — component interfaces
- [tailwind-design-system-architecture](../tailwind-design-system-architecture/Skill.md) — Tailwind-specific delivery
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — runtime theming
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) — docs and tests
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md) — buy vs build

## Sources
- [Brad Frost: Atomic Design](https://atomicdesign.bradfrost.com/) — Community (respected) — layered mental model
- [Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/drafts/format/) — Official (W3C CG) — token format
- [Design Tokens Resolver Module 2025.10](https://www.designtokens.org/tr/drafts/resolver/) — Official (W3C CG) — themes/brands
- [Radix composition guide](https://www.radix-ui.com/primitives/docs/guides/composition) — Official — headless skinning
- [Changesets](https://github.com/changesets/changesets) — Open Source — versioning
- [MDN: CSS cascade layers](https://developer.mozilla.org/en-US/docs/Web/CSS/@layer) — Official — override strategy

## License / Usage Notes
Summarized; code examples original. Referenced libraries MIT/Apache-2.0. Atomic Design book content paraphrased only.

## Quality Tier
A — combines official specs and tool docs with established community models; some package names (Base UI) and Storybook major should be rechecked at use.

## Status
Active

## Last Verified
2026-09-15
