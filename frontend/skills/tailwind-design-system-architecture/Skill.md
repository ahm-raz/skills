# Tailwind Design System Architecture

## Summary
How to build and scale a design system on Tailwind CSS v4. It covers layered tokens (primitive to semantic to component) expressed through `@theme` and CSS variables, runtime theming, variant APIs (cva / tailwind-variants), class merging, shared theme packages in monorepos, and governance so utilities don't become an ungoverned free-for-all.

## Category
CSS & Styling

## Subcategories
Design tokens, semantic colors, @theme inline, multi-brand theming, cva, tailwind-variants, tailwind-merge, shared presets, monorepo theme packages, shadcn-style theming

## Problem It Solves
Tailwind makes it trivial to use `bg-blue-500` everywhere. That hard-codes primitives, breaks dark mode and rebrands, and multiplies inconsistent one-offs. Teams need a token layer, semantic utilities (`bg-surface`, `text-muted`), consistent component variant APIs, and a way to share all of it across apps.

## When To Use
- Building a component library or multi-app product on Tailwind v4.
- Supporting dark mode, high-contrast, multi-brand, or white-label theming with Tailwind.
- Moving a v3 `tailwind.config.js` preset to a v4 CSS-first shared theme.
- Establishing conventions for agents and humans generating Tailwind UI.

## When Not To Use
- Small single-app sites. Default theme + a few `@theme` overrides is enough.
- Non-Tailwind design systems. See design-token-architecture and theming-with-css-variables.
- Basic Tailwind syntax questions. See tailwind-css-v4.

## Core Principles
1. **Three token tiers.** Primitives (`--color-blue-600`), semantic (`--color-primary`, `--color-surface`, `--color-fg-muted`), component (`--button-radius`, optional). Components use semantic utilities only.
2. **Runtime variables, compile-time utilities.** Semantic values live in `:root` / `[data-theme]` / `.dark` and are mapped into `@theme inline` so utilities reference variables that can change at runtime.
3. **Constrain the palette.** Clear or restrict default namespaces (`--color-*: initial`) in strict systems so off-system colors can't be used.
4. **One variant API.** Every component exposes typed variants through cva/tailwind-variants. Consumers override with `className`, merged by tailwind-merge.
5. **Themes in CSS, not JS.** Switching a theme flips an attribute. No re-render, SSR-safe.
6. **Source of truth is a token file** (DTCG JSON or CSS), and generated CSS is checked into a shared package.

## Best Practices
- Name semantic tokens by role: `background`, `foreground`, `surface`, `surface-raised`, `border`, `ring`, `primary`, `primary-foreground`, `muted`, `muted-foreground`, `accent`, `destructive`, `success`, `warning`.
- Pair every fill color with an `-foreground` partner to make contrast-safe combinations obvious.
- Keep primitives in oklch for predictable lightness steps. Define dark values by lightness, not by inverting.
- Use `@theme inline` for the semantic mapping so `bg-primary` compiles to `background-color: var(--primary)` (runtime-switchable).
- Expose non-color tokens too: `--radius-*`, `--shadow-*`, `--font-*`, `--text-*` (with `--text-*--line-height`), `--ease-*`, `--animate-*`.
- Ship the theme as a package (`@acme/tokens/theme.css`) imported after `@import "tailwindcss"`. Add `@source` for the component package's dist so its classes are generated in consuming apps.
- Use `tailwind-variants` when you need slots (multi-part components) or responsive variants; use `cva` for simple single-element variants.
- Configure `tailwind-merge` with `extendTailwindMerge` when you add custom namespaces (e.g. custom `text-*` sizes) so merges don't drop classes.
- Document tokens in Storybook with a generated swatch/type-scale page.

## Implementation Guidance

### Token layering in v4
```css
/* packages/tokens/theme.css */
@custom-variant dark (&:where(.dark, .dark *));

/* 1. Primitives: generate utilities only if you want them available */
@theme {
  --color-*: initial;                       /* strict: remove default palette */
  --color-white: #fff; --color-black: #000;
  --color-gray-50: oklch(98.5% 0.002 260);
  --color-gray-500: oklch(55% 0.01 260);
  --color-gray-900: oklch(21% 0.02 260);
  --color-indigo-600: oklch(51% 0.18 275);
  --color-indigo-400: oklch(68% 0.14 275);
}

/* 2. Semantic runtime variables (switchable) */
:root {
  --background: var(--color-white);
  --foreground: var(--color-gray-900);
  --muted-foreground: var(--color-gray-500);
  --primary: var(--color-indigo-600);
  --primary-foreground: var(--color-white);
  --border: oklch(92% 0.004 260);
  --radius: 0.625rem;
}
.dark {
  --background: oklch(16% 0.01 260);
  --foreground: var(--color-gray-50);
  --muted-foreground: oklch(70% 0.01 260);
  --primary: var(--color-indigo-400);
  --primary-foreground: var(--color-gray-900);
  --border: oklch(30% 0.01 260);
}

/* 3. Map semantics to utilities */
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-muted-foreground: var(--muted-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-border: var(--border);
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
}
```
```css
/* apps/web/app.css */
@import "tailwindcss";
@import "@acme/tokens/theme.css";
@source "../../node_modules/@acme/ui/dist";
```

### Multi-brand
```css
[data-brand="acme"]   { --primary: oklch(55% .17 25); }
[data-brand="globex"] { --primary: oklch(52% .14 160); }
```
Brands and modes compose, because a brand sets hue tokens and `.dark` sets lightness tokens. Use relative color syntax to derive them: `.dark { --primary: oklch(from var(--brand-base) 72% c h); }`.

### Decision table: variant tooling
| Need | Tool |
|---|---|
| Simple variants, framework-agnostic | `cva` (class-variance-authority) |
| Slots, compound slots, responsive variants, built-in merge | `tailwind-variants` |
| Consumer overrides via `className` | `tailwind-merge` (`twMerge` / `cn()` helper with `clsx`) |
| Headless component states | Style data attributes from Radix/Base UI/React Aria (`data-[state=open]:`, `aria-selected:`) |

### v3 preset to v4 migration
- `presets: [require('@acme/preset')]` becomes a shared CSS file with `@theme` imported by each app.
- `theme.extend.colors.primary: 'hsl(var(--primary))'` becomes `@theme inline { --color-primary: var(--primary); }`. Store full colors in variables (not bare HSL channels), since v4 opacity modifiers use `color-mix()`.
- JS plugins that add utilities become `@utility`. Keep `@plugin` only for complex ones.
- `safelist` becomes `@source inline("bg-red-{500,600}")`.

## Recommended Workflow
1. Inventory brand primitives (colors, fonts, radii, shadows) from design (Figma variables / DTCG tokens).
2. Define semantic roles with designers and document each role's intended pairing.
3. Generate primitives in oklch; generate dark/high-contrast values; verify contrast pairs.
4. Write the shared `theme.css` (primitives → semantic vars → `@theme inline`).
5. Build primitives-level components (Button, Input, Card) with cva/tailwind-variants + `cn()`.
6. Publish tokens + UI packages; configure `@source` in consuming apps.
7. Add guardrails: ESLint rule banning raw palette classes in app code (e.g. `bg-indigo-600`), Storybook token docs, visual regression per theme.
8. Govern changes: semver the token package; changelog token renames.

## Patterns
**`cn` helper**
```ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
export const cn = (...inputs: ClassValue[]) => twMerge(clsx(inputs));
```

**Slot recipe (tailwind-variants)**
```ts
import { tv } from "tailwind-variants";
export const card = tv({
  slots: { base: "rounded-lg border border-border bg-background", header: "p-4 font-semibold", body: "p-4 text-muted-foreground" },
  variants: { elevated: { true: { base: "shadow-md" } } },
});
const { base, header, body } = card({ elevated: true });
```

**Semantic state styling with headless primitives**
```html
<button class="data-[state=open]:bg-primary/10 aria-disabled:opacity-50 focus-visible:ring-2 focus-visible:ring-primary">
```

**Text size tokens with paired line-height**
```css
@theme {
  --text-body: 1rem; --text-body--line-height: 1.6;
  --text-display: clamp(2.5rem, 1.8rem + 3vw, 4rem); --text-display--line-height: 1.05;
}
```

## Anti-Patterns
- **Primitive classes in product code (`bg-blue-600`).** Rebrands and dark mode require a find-and-replace. Use semantic utilities (`bg-primary`).
- **`dark:` on every element.** Doubles class count and misses cases. Switch semantic variables under `.dark`; reserve `dark:` for true exceptions.
- **Bare HSL channel variables (`--primary: 222 47% 11%`) from v3 shadcn patterns.** Unnecessary in v4. Store full colors (`oklch(...)`); opacity modifiers work via `color-mix`.
- **`@theme` (not inline) for variables referencing runtime vars.** Can resolve at the wrong scope. Use `@theme inline`.
- **`@apply`-built component classes as the design system.** Loses variant typing and merge. Use components + cva.
- **Forgetting `@source` for packaged components.** Classes are missing in production. Add `@source` pointing to the package output.
- **Unconfigured tailwind-merge with custom scales.** Silently drops classes. Use `extendTailwindMerge`.

## Accessibility
- Validate every semantic pair (`foreground/background`, `primary-foreground/primary`, `muted-foreground/background`) at ≥4.5:1 for body text and ≥3:1 for large text and UI boundaries (WCAG 1.4.3, 1.4.11), in every theme.
- Provide a `--ring` token and use `focus-visible:ring-*` or outline on all interactive components.
- Offer a high-contrast theme (`@media (prefers-contrast: more)` or `[data-contrast=more]`) by swapping semantic tokens.
- Ensure `forced-colors` mode keeps borders visible (use `border` rather than shadows-only for boundaries).

## Responsive Design
Put responsive behavior inside components with container variants (`@container`, `@md:`) so library components adapt to their slot. Theme typography can use fluid `clamp()` tokens so fewer breakpoint classes are needed.

## Performance
- Semantic variables add negligible cost. Theme switching is a single attribute change with no re-render.
- `--color-*: initial` shrinks generated variables and IntelliSense noise.
- Avoid huge `@source inline` safelists; they bloat CSS.

## Security
- Don't allow tenants to inject arbitrary CSS for white-labeling. Accept validated token values (e.g. parse and clamp colors to oklch) and write them as custom properties.
- Pin and audit `@plugin` dependencies.

## Testing
- Visual regression matrix: component × theme (light/dark/high-contrast) × brand.
- Automated contrast checks on token pairs (script using culori/colorjs.io computing WCAG 2 ratios) in CI.
- Unit test variant functions for class output; ESLint rule tests for banned raw palette usage.

## Tooling
- Tailwind CSS v4.3, `tailwind-merge` v3, `tailwind-variants`, `class-variance-authority`, `clsx`. Active.
- Style Dictionary v4 / Terrazzo for DTCG tokens → CSS variables. Active.
- `eslint-plugin-better-tailwindcss` (community) for class validation / restricting classes.
- Storybook + Chromatic for docs/visual tests.
- Community: wshobson/agents `tailwind-design-system` SKILL.md. Reference patterns, verify.

## Framework Notes
- **shadcn/ui:** exemplifies this architecture (`:root`/`.dark` variables + `@theme inline`, `cn()`, cva). Follow its naming if the repo uses shadcn.
- **Next.js (App Router):** apply `class="dark"` / `data-theme` / `data-brand` on `<html>` before paint. Use `next-themes` (`attribute="class"`) for light/dark and set `data-brand` server-side in `app/layout.tsx` (from tenant config, cookies, or host) so brand tokens are correct in the first HTML with no client flash. Add `suppressHydrationWarning` on `<html>`. Semantic utilities work in Server Components; only the theme toggle needs `'use client'`.
- **React (Vite SPA):** toggle the attribute with an inline `<script>` in `index.html` before the app bundle, then manage it from a small `ThemeProvider` context.
- **Monorepos (Turborepo/pnpm):** the token package should have no runtime JS dependency. CSS-only exports via `"exports": { "./theme.css": "./theme.css" }`. The UI package ships TSX compiled to `dist`, and each Next.js app adds `@source "../../node_modules/@acme/ui/dist";`. With Next.js `transpilePackages: ["@acme/ui"]` you may instead point `@source` at the package's `src`.

```tsx
// app/layout.tsx — brand from server, mode from next-themes
import { ThemeProvider } from "next-themes";
import { getTenant } from "@/lib/tenant";
import "./globals.css";

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const tenant = await getTenant(); // e.g. derived from headers()
  return (
    <html lang="en" data-brand={tenant.brand} suppressHydrationWarning>
      <body className="bg-background text-foreground">
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

## AI Agent Guidance
- Do look for existing semantic tokens (`bg-background`, `text-foreground`, `bg-primary`) and use them before any palette class.
- Do add new tokens to the shared theme file rather than arbitrary values.
- Do use the repo's variant helper (cva/tv) and `cn()` for new components.
- Don't add `dark:` variants when semantic tokens already switch.
- Don't create `tailwind.config.js` presets for v4.
- Before done: component renders correctly in light and dark (and each brand), contrast pairs pass, `className` overrides merge correctly, no raw palette classes introduced.

## Examples
```tsx
// packages/ui/src/badge.tsx
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "./cn";

const badge = cva("inline-flex items-center rounded-sm px-2 py-0.5 text-xs font-medium ring-1 ring-inset", {
  variants: {
    tone: {
      neutral: "bg-muted text-muted-foreground ring-border",
      primary: "bg-primary/10 text-primary ring-primary/30",
      danger: "bg-destructive/10 text-destructive ring-destructive/30",
    },
  },
  defaultVariants: { tone: "neutral" },
});

export function Badge({ tone, className, ...props }: React.ComponentProps<"span"> & VariantProps<typeof badge>) {
  return <span className={cn(badge({ tone }), className)} {...props} />;
}
```

## Related Skills
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — v4 syntax and migration
- [design-token-architecture](../design-token-architecture/Skill.md) — token tiers and pipelines
- [design-system-architecture](../design-system-architecture/Skill.md) — overall DS structure
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — runtime theme mechanics
- [color-systems](../color-systems/Skill.md) — building accessible palettes
- [shadcn-ui](../shadcn-ui/Skill.md) — reference implementation of this pattern
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — shared packages

## Sources
- [Theme variables — Tailwind docs](https://tailwindcss.com/docs/theme) — Official — @theme, inline, namespace reset, sharing themes
- [Upgrade guide — Tailwind docs](https://tailwindcss.com/docs/upgrade-guide) — Official — preset/config migration
- [Dark mode — Tailwind docs](https://tailwindcss.com/docs/dark-mode) — Official — custom variants
- [Tailwind v4.3 release](https://tailwindcss.com/blog/tailwindcss-v4-3) — Official — `--default()`, compound @variant
- [wshobson/agents tailwind-design-system SKILL.md](https://github.com/wshobson/agents/blob/main/plugins/frontend-mobile-development/skills/tailwind-design-system/SKILL.md) — Community — agent skill patterns
- [tailwind-variants](https://www.tailwind-variants.org/) — Open Source — slots API
- [class-variance-authority](https://cva.style/) — Open Source — variant API
- [shadcn/ui theming](https://ui.shadcn.com/docs/theming) — Open Source — semantic variable naming convention

## License / Usage Notes
Tailwind CSS, cva, tailwind-variants, tailwind-merge and shadcn/ui are MIT. Content is summarized, and code is original illustrative examples.

## Quality Tier
A — Official v4 mechanics plus widely adopted community patterns. Multi-brand specifics vary by org.

## Status
Active

## Last Verified
2026-09-15
