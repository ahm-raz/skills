# Design Token Architecture

## Summary
Designing, storing, transforming, and consuming design tokens using the W3C Design Tokens Community Group (DTCG) Format Module 2025.10 (first stable version, Oct 2025) and its Resolver Module for themes/modes. Covers tiering (primitive -> semantic -> component), naming, aliasing, multi-brand/mode resolution, build pipelines (Style Dictionary v5, Terrazzo), and consumption in CSS/Tailwind/native.

## Category
Architecture

## Subcategories
DTCG format, token tiers, naming conventions, aliases, theming/modes, resolver, Style Dictionary, Terrazzo, Figma variables sync

## Problem It Solves
Visual decisions scattered across Figma, CSS, and native code drift apart; rebrands and dark mode require manual edits everywhere. A standard, tool-interoperable token source with a build pipeline makes design decisions change once and propagate to every platform.

## When To Use
- Any design system or multi-platform product.
- Implementing dark mode, high-contrast, density, or multi-brand theming.
- Syncing Figma variables with code.

## When Not To Use
- Very small apps: a handful of CSS custom properties is enough (still follow semantic naming).
- Don't tokenize one-off values used once (e.g., a hero illustration offset).

## Core Principles
1. **Three tiers:** primitive/base (raw palette, scale) -> semantic/alias (purpose: `color.bg.surface`) -> component (optional: `button.primary.bg`).
2. **Components consume semantic (or component) tokens only**, never primitives.
3. **Modes change values, not names.** `color.bg.surface` exists in light and dark; values differ per context.
4. **Types are explicit.** DTCG tools must not infer type from value; set `$type` on token or parent group.
5. **One source, many outputs.** JSON source -> CSS vars, TS, Tailwind theme, iOS, Android, Compose, Flutter.
6. **Tokens are versioned API.** Renames are breaking; use `$deprecated` with a message pointing to the replacement.

## Best Practices
- Use DTCG 2025.10 syntax: `$value`, `$type`, `$description`, `$deprecated`, `$extensions` (reverse-domain keys), group `$extends` and `$root`.
- Files: `.tokens.json` (or `.tokens`), media type `application/design-tokens+json`.
- Names must not start with `$` or contain `{`, `}`, `.`.
- Aliases: curly braces `"{color.blue.600}"` for whole-token references; JSON Pointer `$ref` for sub-values (e.g., a single color component).
- Colors as objects with `colorSpace` (srgb, display-p3, oklch, etc.), `components`, optional `alpha`, optional `hex` fallback. Author palettes in OKLCH for perceptual scales.
- Dimensions as `{ "value": 16, "unit": "px" }` or `rem`; durations `{ "value": 200, "unit": "ms" }`.
- Naming order: `category.concept.property.variant.state` e.g. `color.action.primary.bg.hover`. Keep it consistent and documented.
- Express themes via the Resolver module: sets (always included), modifiers with contexts (`theme: light|dark`, `brand: a|b`, `density: compact|comfortable`), and `resolutionOrder`.
- Generate CSS vars with a prefix (`--ds-`) and scope modes via attribute selectors or `light-dark()`.
- Keep Figma variables in sync via DTCG export/import (Figma, Tokens Studio, Penpot support DTCG); treat the repo as source of truth or define one direction explicitly.
- Validate tokens in CI (schema + contrast checks for semantic fg/bg pairs).

## Implementation Guidance

### Primitive tokens (`tokens/primitives.tokens.json`)
```json
{
  "color": {
    "$type": "color",
    "blue": {
      "600": { "$value": { "colorSpace": "oklch", "components": [0.55, 0.16, 255], "hex": "#2b63d9" } },
      "100": { "$value": { "colorSpace": "oklch", "components": [0.95, 0.03, 255], "hex": "#e6eeff" } }
    },
    "neutral": {
      "0":   { "$value": { "colorSpace": "srgb", "components": [1, 1, 1], "hex": "#ffffff" } },
      "900": { "$value": { "colorSpace": "srgb", "components": [0.09, 0.1, 0.12], "hex": "#17191f" } }
    }
  },
  "space": {
    "$type": "dimension",
    "2": { "$value": { "value": 0.5, "unit": "rem" } },
    "4": { "$value": { "value": 1, "unit": "rem" } }
  },
  "duration": { "$type": "duration", "fast": { "$value": { "value": 150, "unit": "ms" } } }
}
```

### Semantic tokens per mode (`tokens/light.tokens.json`, `tokens/dark.tokens.json`)
```json
{
  "color": {
    "$type": "color",
    "bg": { "surface": { "$value": "{color.neutral.0}", "$description": "Default page/card background" } },
    "fg": { "default": { "$value": "{color.neutral.900}" } },
    "action": { "primary": { "bg": { "$value": "{color.blue.600}" } } }
  }
}
```

### Resolver (`tokens/resolver.json`)
```json
{
  "$schema": "https://www.designtokens.org/schemas/2025.10/resolver.json",
  "version": "2025.10",
  "sets": { "primitives": { "sources": [{ "$ref": "primitives.tokens.json" }] } },
  "modifiers": {
    "theme": {
      "contexts": {
        "light": [{ "$ref": "light.tokens.json" }],
        "dark":  [{ "$ref": "dark.tokens.json" }]
      },
      "default": "light"
    }
  },
  "resolutionOrder": [{ "$ref": "#/sets/primitives" }, { "$ref": "#/modifiers/theme" }]
}
```
Tool input selects contexts, e.g. `{ "theme": "dark" }`; later entries in `resolutionOrder` override earlier ones.

### Build output (CSS)
```css
:root, [data-theme="light"] {
  --ds-color-bg-surface: #ffffff;
  --ds-color-fg-default: #17191f;
  --ds-color-action-primary-bg: #2b63d9;
}
[data-theme="dark"] {
  --ds-color-bg-surface: #17191f;
  --ds-color-fg-default: #ffffff;
}
@supports (color: oklch(0 0 0)) {
  :root { --ds-color-action-primary-bg: oklch(0.55 0.16 255); }
}
```

### Tailwind v4 consumption
```css
@import "tailwindcss";
@import "@acme/tokens/css/variables.css";
@theme inline {
  --color-surface: var(--ds-color-bg-surface);
  --color-fg: var(--ds-color-fg-default);
  --color-primary: var(--ds-color-action-primary-bg);
}
```

### Pipeline tools
| Tool | Status (Sept 2026) | Notes |
|---|---|---|
| Style Dictionary v5 | Active | DTCG 2025.10 support; many platform formats (CSS, SCSS, iOS Swift, Android, Compose, Flutter) |
| Terrazzo (`@terrazzo/cli`) | Active | DTCG-native, modes/resolver focus, plugins for CSS/Tailwind/JS |
| Tokens Studio | Active | Figma plugin; DTCG export |
| Figma native variables | Active | DTCG import/export support announced alongside 2025.10 |

Verify resolver support level in your chosen tool version before relying on it; implementations were catching up through 2026.

## Recommended Workflow
1. Audit existing values (colors, spacing, radii, type, motion, shadows); dedupe into primitive scales.
2. Define semantic taxonomy with designers; document naming grammar.
3. Author DTCG JSON; add resolver for modes/brands.
4. Configure build (Style Dictionary v5/Terrazzo) to emit CSS vars + TS types + native outputs.
5. Add CI: schema validation, alias resolution, WCAG contrast check on semantic pairs.
6. Replace hard-coded values in components; add stylelint rule forbidding raw values.
7. Publish tokens package; version with Changesets; deprecate via `$deprecated`.

## Patterns
- **Tiered aliasing:** component -> semantic -> primitive references.
- **Mode modifiers:** theme x contrast x density x brand as independent modifiers.
- **`$root` base values:** `color.brand` group with `$root` plus `light`/`dark` children.
- **Group `$extends`:** `button-danger` extends `button` overriding only `background`.
- **Deprecation alias:** old token aliases new one with `$deprecated: "Use {color.bg.surface}"`.

## Anti-Patterns
- **Value-named semantic tokens** (`color-blue-bg`) — breaks on rebrand. Fix: purpose names (`color.action.primary.bg`).
- **Separate token names per mode** (`bg-light`, `bg-dark`) — components must branch. Fix: same name, mode contexts.
- **Components using primitives directly** — theming bypassed. Fix: lint `var(--ds-color-blue-*)` usage outside tokens.
- **Inferring types** from strings — not DTCG-compliant. Fix: `$type` on group/token.
- **Legacy pre-stable DTCG syntax** (`value`/`type` without `$`, color strings only) — outdated; Fix: migrate to 2025.10 object values (hex strings are still accepted by some tools but spec uses color objects).
- **Tokenizing everything** (hundreds of component tokens nobody overrides) — maintenance burden. Fix: add component tier only where theming needs it.
- **Figma and code both edited as sources** — drift. Fix: single source direction with automated sync PRs.

## Accessibility
- Validate contrast for every semantic fg/bg pair in each mode: WCAG 1.4.3 (4.5:1 text), 1.4.11 (3:1 non-text/UI).
- Provide a high-contrast modifier and honor `prefers-contrast` / `forced-colors`.
- Motion tokens should have reduced-motion variants (`prefers-reduced-motion`).
- Focus ring tokens must meet WCAG 2.4.13 Focus Appearance (AAA) guidance where targeted; at least 2.4.7 visible.

## Responsive Design
- Fluid type/space tokens using `clamp()` output from min/max dimension tokens.
- Density modifier for compact/comfortable layouts instead of breakpoint-specific tokens.

## Performance
- CSS variables are cheap; avoid emitting thousands of unused variables — tree-shake component tokens per package.
- Switch themes by attribute on `<html>` (no JS re-render); set it before first paint to avoid flash.

## Security
- Token packages are dependencies: publish with provenance; review generated artifacts in PRs.
- Don't put URLs/secrets in `$extensions`.

## Testing
- Schema validation against DTCG JSON schemas.
- Snapshot tests of generated outputs.
- Contrast tests per mode (e.g., culori/colorjs.io in a Vitest test).
- Visual regression of components across modes.

## Tooling
- Style Dictionary v5 — Active.
- Terrazzo — Active.
- Tokens Studio for Figma — Active.
- `dtcg-tools` (TS types for 2025.10 format/resolver) — Community.
- stylelint `declaration-strict-value` — Active (enforce var usage).
- colorjs.io / culori — Active (OKLCH conversions and contrast).

## Framework Notes
- **React (Vite SPA):** import generated `variables.css` in `main.tsx`; set `document.documentElement.dataset.theme` before render (inline script in `index.html`) to avoid flash; export a typed token map (`tokens.ts`) for rare JS needs (charts, canvas).
- **Next.js App Router:** import token CSS in `app/layout.tsx`; read the theme cookie with `cookies()` in the root layout and render `<html data-theme={theme}>` server-side (no flash, no client JS). Note this makes the layout dynamic — alternatively default to `prefers-color-scheme` via CSS `light-dark()`/media queries for fully static pages.
- **Tailwind v4 (both):** map token vars into `@theme inline` so utilities reference variables and theme switching needs no rebuild.
- **Never import token JSON into Client Components wholesale** — ship CSS variables; import individual TS constants only where JS needs a value.

## AI Agent Guidance
- Never hard-code colors, spacing, radii, or durations; find the semantic token.
- If no suitable token exists, propose one in the semantic tier (not a primitive) and flag it for design review.
- Use DTCG 2025.10 syntax (`$value`, `$type`, color objects); don't generate legacy non-`$` formats.
- Verify: token build succeeds, alias resolution has no cycles, contrast tests pass in all modes, no raw values introduced (stylelint).

## Examples
```ts
// contrast.test.ts — check semantic pairs per mode (colorjs.io)
import Color from 'colorjs.io';
import light from '../dist/light.json';
import dark from '../dist/dark.json';
for (const [name, t] of Object.entries({ light, dark })) {
  test(`${name}: fg on surface >= 4.5`, () => {
    const c = new Color(t['color.fg.default']).contrast(new Color(t['color.bg.surface']), 'WCAG21');
    expect(c).toBeGreaterThanOrEqual(4.5);
  });
}
```

## Related Skills
- [design-system-architecture](../design-system-architecture/Skill.md) — system layering
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — runtime consumption
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — mode switching
- [color-systems](../color-systems/Skill.md) — palette construction
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — `@theme` integration
- [design-to-code-figma-workflow](../design-to-code-figma-workflow/Skill.md) — Figma sync

## Sources
- [Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/drafts/format/) — Official (W3C CG) — properties, types, aliases, file format
- [Design Tokens Resolver Module 2025.10](https://www.designtokens.org/tr/drafts/resolver/) — Official (W3C CG) — sets/modifiers/resolutionOrder
- [DTCG: first stable version announcement](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/) — Official — status, adopters
- [Style Dictionary DTCG support](https://styledictionary.com/info/dtcg/) — Open Source — pipeline
- [Terrazzo: Modes + Theming](https://terrazzo.app/docs/guides/modes/) — Open Source — modes
- [dtcg-tools](https://github.com/jsxtools/dtcg-tools) — Community — TypeScript types

## License / Usage Notes
DTCG specs are W3C Community Group reports (W3C CLA/Software and Document License); summarized here. Tools are Apache-2.0/MIT.

## Quality Tier
S — based directly on the stable 2025.10 specification and reference implementations, verified Sept 2026.

## Status
Active

## Last Verified
2026-09-15
