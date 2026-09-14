# Tailwind CSS v4

## Summary
Tailwind CSS v4 (current: v4.3.x, July 2026) is a utility-first CSS framework with CSS-first configuration. You configure it with `@import "tailwindcss"`, `@theme`, `@utility`, `@custom-variant`, `@source` and `@plugin` in CSS instead of `tailwind.config.js`. This skill covers correct v4 syntax, the v3 to v4 breaking changes that AI agents constantly get wrong, and idiomatic usage.

## Category
CSS & Styling

## Subcategories
Utility-first CSS, @theme, @utility, @custom-variant, @source, Vite/PostCSS/webpack plugins, v3 migration, container queries, dark mode

## Problem It Solves
Most LLM training data and older tutorials use Tailwind v3. Agents keep generating `tailwind.config.js`, `@tailwind base`, `bg-opacity-50`, `bg-gradient-to-r`, `!flex`, and `bg-[--var]`, which are broken or deprecated in v4. This skill gives the exact v4 conventions and a migration checklist.

## When To Use
- Any project with `tailwindcss@^4` in package.json or `@import "tailwindcss"` in CSS.
- Migrating v3 to v4.
- Writing custom utilities, variants, or theme tokens in Tailwind.

## When Not To Use
- Projects pinned to v3 that must support Safari < 16.4, Chrome < 111, or Firefox < 128. v4 requires `@property` and `color-mix()`, so stay on v3.4 there.
- Projects using Sass/Less/Stylus as the primary preprocessor. v4 is not designed to be combined with them.
- Token/design-system strategy on top of Tailwind. See tailwind-design-system-architecture.

## Core Principles
1. **CSS is the config.** Theme tokens live in `@theme` as CSS variables, which generate utilities and are available at runtime as `var(--color-*)`.
2. **Automatic content detection.** No `content` array. Use `@source` to add paths (e.g. packages in node_modules) or `@source not` to exclude.
3. **Mobile-first, left-to-right variants.** Unprefixed = all sizes. Stacked variants apply left to right (`*:first:pt-0`).
4. **Utilities in markup, abstractions in components.** Reuse via framework components, not `@apply` everywhere.
5. **Modern CSS underneath.** Cascade layers (`theme, base, components, utilities`), `oklch` colors, `@property`, container queries built in.

## Best Practices
- Use the first-party integration for your bundler: `@tailwindcss/vite` (preferred for Vite), `@tailwindcss/postcss`, `@tailwindcss/webpack` (v4.2+, faster than PostCSS for webpack/Next.js), or `@tailwindcss/cli`.
- Put design tokens in `@theme`. Put non-utility helper variables in `:root`.
- Use `@theme inline` when a token references another variable (e.g. a `next/font` variable), so utilities resolve correctly.
- Use `@utility` for custom utilities. They then work with all variants (`hover:`, `md:`).
- Use `@custom-variant` to redefine `dark` or add app-specific variants (`@custom-variant theme-brand (&:where([data-brand] *));`).
- In CSS Modules (`*.module.css`), add `@reference "../app/globals.css";` before using `@apply` or theme functions. Otherwise the module has no access to the theme, or duplicates Tailwind output if you `@import` instead.
- Merge conflicting classes with `tailwind-merge` (v3.x supports v4) and compose variants with `cva`/`tailwind-variants`.
- Install `prettier-plugin-tailwindcss` for class ordering. Point it at your CSS entry via `tailwindStylesheet`.
- Use `size-*` instead of `w-* h-*` pairs, and `gap` instead of `space-*` for flex/grid.
- Use logical utilities (`ps-*`, `pe-*`, `ms-*`, `inset-s-*`, `border-bs`, `inline-*`, `block-*`) for RTL-ready layouts.

## Implementation Guidance

### Setup (Vite)
```css
/* src/app.css */
@import "tailwindcss";
```
```ts
// vite.config.ts
import tailwindcss from "@tailwindcss/vite";
export default { plugins: [tailwindcss()] };
```

### PostCSS (Next.js, others)
```js
// postcss.config.mjs
export default { plugins: { "@tailwindcss/postcss": {} } };
```

### Directive reference
| Directive / function | Purpose |
|---|---|
| `@import "tailwindcss";` | Loads theme, preflight, utilities (replaces the three `@tailwind` lines) |
| `@theme { --color-brand-500: oklch(...); }` | Define tokens that generate utilities |
| `@theme inline { ... }` | Inline referenced values into utilities |
| `@theme static { ... }` | Always emit variables, even if unused |
| `--color-*: initial;` / `--*: initial;` | Clear a namespace / the whole default theme |
| `@source "../node_modules/@acme/ui";` | Add a content path; `@source not "./legacy";` excludes; `@source inline("...")` safelists |
| `@utility name { ... }` / `@utility tab-* { tab-size: --value(integer); }` | Custom static/functional utilities (`--default()` in v4.3) |
| `@custom-variant name (selector);` | Define or override variants |
| `@variant dark { ... }` | Apply a variant inside custom CSS (stacked/compound in v4.3) |
| `@apply` | Inline utilities in CSS (use sparingly) |
| `@reference "./app.css";` | Access theme in isolated style blocks without duplicating output |
| `@plugin "@tailwindcss/typography";` | Load a JS plugin |
| `@config "./tailwind.config.js";` | Legacy JS config (no `corePlugins`, `safelist`, `separator`) |
| `--alpha()`, `--spacing()` | CSS functions: `color: --alpha(var(--color-lime-300) / 50%)`, `margin: --spacing(4)` |

### v3 to v4 breaking-change table (most common agent errors)
| v3 (wrong in v4) | v4 |
|---|---|
| `@tailwind base; @tailwind components; @tailwind utilities;` | `@import "tailwindcss";` |
| `tailwind.config.js` `theme.extend` | `@theme { ... }` in CSS |
| `bg-opacity-50`, `text-opacity-*` | `bg-black/50`, `text-white/80` |
| `bg-gradient-to-r` | `bg-linear-to-r` (also `bg-linear-45`, `bg-radial`, `bg-conic`) |
| `shadow-sm` / `shadow` | `shadow-xs` / `shadow-sm` (same shift for `blur`, `rounded`, `drop-shadow`, `backdrop-blur`) |
| `outline-none` | `outline-hidden` (`outline-none` now sets `outline-style: none`) |
| `ring` (3px blue) | `ring-3` + explicit color; default ring is 1px `currentColor` |
| Default border color gray-200 | `currentColor`, so always specify `border-gray-200` |
| `!flex` | `flex!` |
| `bg-[--brand]` | `bg-(--brand)` |
| `grid-cols-[a,b]` | `grid-cols-[a_b]` |
| `first:*:pt-0` | `*:first:pt-0` |
| `flex-shrink-0` / `flex-grow` | `shrink-0` / `grow` |
| `@layer utilities { .x {} }` | `@utility x {}` |
| `theme(screens.xl)` | `theme(--breakpoint-xl)` or `var(--breakpoint-xl)` |
| `prefix: 'tw-'` → `tw-flex` | `@import "tailwindcss" prefix(tw);` → `tw:flex` |
| `container` `center`/`padding` config | `@utility container { margin-inline: auto; padding-inline: 2rem; }` |
| `transform-none` reset | `scale-none`, `rotate-none`, `translate-none` |
| `start-*` / `end-*` (deprecated 4.2) | `inset-s-*` / `inset-e-*` |
| `space-y-*` on flex/grid | `flex flex-col gap-*` (space-* selector changed to `:not(:last-child)`) |
| `@tailwindcss/container-queries` plugin | Built in: `@container`, `@md:`, `@max-md:`, `@container/name` |

Other behavior changes: `hover:` only applies under `@media (hover: hover)` (override with `@custom-variant hover (&:hover);`). Buttons get `cursor: default` in preflight. Placeholder color is current text at 50%. `hidden` attribute beats display utilities. `<dialog>` margins are reset.

Migrate with `npx @tailwindcss/upgrade` (Node 20+) on a clean branch, then review the diff manually. It won't fix dynamic class strings.

## Recommended Workflow
1. Confirm the version (`package.json`). If v3, don't write v4 syntax (and vice versa).
2. Set up the bundler plugin and a single CSS entry with `@import "tailwindcss"`.
3. Define tokens in `@theme` (colors in oklch, fonts, breakpoints, radius). Clear defaults only when a strict design system requires it.
4. Configure dark mode (`@custom-variant dark` if class/attribute toggling is needed).
5. Build components with utilities. Extract variants with `cva`/`tailwind-variants` + `tailwind-merge`.
6. Add `@utility`/`@custom-variant` only for repeated needs.
7. Run Prettier with the Tailwind plugin, then build and check for missing classes (dynamic strings).
8. Verify in browsers at breakpoints, in dark mode, and with keyboard focus.

## Patterns
**Complete class names (static detection)**
```tsx
// ✅ scanner sees full strings
const tone = { danger: "bg-red-600 text-white", ok: "bg-green-600 text-white" }[variant];
// ❌ never: `bg-${color}-600`
```

**Functional custom utility**
```css
@theme { --tab-size-github: 8; }
@utility tab-* { tab-size: --value(--tab-size-*, integer, [integer]); }
```

**Data-attribute and group/peer state**
```html
<button data-state="open" class="data-[state=open]:bg-gray-100 group">
  <svg class="transition group-data-[state=open]:rotate-180"></svg>
</button>
<input class="peer" required /><p class="hidden peer-user-invalid:block text-red-600">Required</p>
```

**Container query card**
```html
<div class="@container">
  <article class="grid gap-4 @md:grid-cols-[10rem_1fr]">…</article>
</div>
```

**Scoped @apply in a CSS Module**
```css
@reference "../../app.css";
.prose-link { @apply text-brand-600 underline-offset-2 hover:underline; }
```

## Anti-Patterns
- **Generating `tailwind.config.js` for a v4 project.** Ignored unless `@config` is added. Use `@theme`.
- **Dynamic class interpolation (`text-${size}`).** Classes aren't generated. Use lookup maps of full class names or `@source inline()`.
- **`@apply` for everything.** It recreates a CSS framework with worse ergonomics. Use components; `@apply` only for third-party markup or tiny base styles.
- **Conflicting classes without merge (`p-2 p-4`).** Order in the stylesheet decides, not the class attribute order. Use `tailwind-merge` in component APIs.
- **`@layer components` for custom utilities.** Variants won't work. Use `@utility`.
- **Hard-coded arbitrary values everywhere (`text-[#3b82f6]`, `mt-[13px]`).** They bypass the design system. Add a token to `@theme`.
- **Using Sass with v4.** Unsupported pipeline. Use native nesting (supported via Lightning CSS).
- **`focus:outline-none` with no replacement.** Accessibility failure. Use `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600`.

## Accessibility
- Always provide `focus-visible:` styles. v4 `outline-hidden` keeps an outline in forced-colors mode, which `outline-none` does not.
- Use `sr-only` / `not-sr-only` for hidden labels.
- Use `motion-safe:` / `motion-reduce:` for animation; `contrast-more:`; `forced-colors:`.
- Tailwind's default palette steps don't guarantee contrast. Verify text/background pairs (e.g. gray-500 on white fails 4.5:1 for small text at some weights; check).
- Minimum target size (WCAG 2.5.8): ensure interactive elements are ≥24×24 CSS px (`min-h-6 min-w-6` or padding).

## Responsive Design
- Default breakpoints: `sm` 40rem, `md` 48rem, `lg` 64rem, `xl` 80rem, `2xl` 96rem. Customize with `--breakpoint-*`.
- Ranges: `md:max-lg:flex`; arbitrary: `min-[20rem]:`, `max-[60rem]:`.
- Container queries: `@container`, `@sm:` … `@7xl:` (16rem–80rem), `@max-md:`, named `@container/sidebar` + `@lg/sidebar:`, `@container-size` for block-size queries (v4.3).
- Prefer container variants for reusable components and viewport variants for page layout.

## Performance
- v4's Oxide engine gives full builds ~3–5× faster and incremental builds in microseconds versus v3.
- Output contains only used utilities. Keep class strings static so detection is exact.
- Exclude large irrelevant directories via `@source not` if scanning is slow.
- Don't import the full theme twice (use `@reference`, not `@import`, in component style blocks). Duplicate imports duplicate CSS.

## Security
- Never build class names from user input (CSS injection or unexpected styling). Map to allow-listed classes.
- Plugins loaded via `@plugin` execute at build time. Treat them as dependencies (audit, pin versions).

## Testing
- Visual regression per breakpoint and theme (Playwright `toHaveScreenshot`, Chromatic).
- Unit tests for variant helpers (cva/tailwind-variants) asserting class output.
- CI build check that no v3-only syntax exists: grep for `@tailwind `, `bg-opacity-`, `bg-gradient-to-`, `!` prefix patterns, `tailwind.config` (unless intentional).
- Lint with `eslint-plugin-better-tailwindcss` (community) for unknown/conflicting classes.

## Tooling
- `tailwindcss` v4.3.x, `@tailwindcss/vite`, `@tailwindcss/postcss`, `@tailwindcss/webpack` (4.2+), `@tailwindcss/cli`. Active.
- `@tailwindcss/upgrade`. Official migration codemod.
- `@tailwindcss/typography`, `@tailwindcss/forms`. Official plugins (load via `@plugin`).
- `prettier-plugin-tailwindcss`. Official class sorting.
- Tailwind CSS IntelliSense (VS Code). Official. Needs the CSS entry file detected.
- `tailwind-merge`, `cva`, `tailwind-variants`. Community, widely used.
- Community agent rules: ofershap/tailwind-best-practices, shamiul-anik/tailwindcss-skills, Lombiq/Tailwind-Agent-Skills. Useful v3→v4 anti-pattern lists; verify against official docs.
- Deprecated: `@tailwindcss/container-queries` plugin (built in), `@tailwindcss/line-clamp` (built in since v3.3), JIT mode flags.

## Framework Notes
- **Next.js (App Router, 16.x):** install `tailwindcss @tailwindcss/postcss`, add `postcss.config.mjs`, put `@import "tailwindcss";` in `app/globals.css`, and import it in `app/layout.tsx`. Webpack builds can use `@tailwindcss/webpack` (v4.2+). Tailwind utilities are plain classes, so they work in Server Components with no client boundary.
- **next/font + Tailwind v4:** call the font loader with `variable: "--font-inter"`, put `inter.variable` on `<html>`, and map it with `@theme inline { --font-sans: var(--font-inter); }`. `inline` is required, because without it `font-sans` would resolve `var(--font-sans)` at the wrong scope. Full example below.
- **Dark mode in Next.js:** `next-themes` with `attribute="class"` (or `"data-theme"`) plus `@custom-variant dark (&:where(.dark, .dark *));` and `suppressHydrationWarning` on `<html>`. The next-themes README still shows the v3 `darkMode: 'selector'` config, which doesn't apply to v4. See dark-mode-implementation.
- **CSS Modules in Next.js:** add `@reference "../globals.css";` at the top of a `.module.css` before using `@apply`, `theme()` or `--spacing()`.
- **React (Vite SPA):** `@tailwindcss/vite` in `vite.config.ts`; import `./index.css` in `main.tsx`.
- **shadcn/ui:** current CLI generates v4 CSS-first config with `@theme inline` mapping to `:root`/`.dark` variables and a `cn()` helper.

```tsx
// app/layout.tsx
import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-jetbrains" });

export const metadata: Metadata = { title: "App" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${mono.variable}`} suppressHydrationWarning>
      <body className="bg-background font-sans text-foreground antialiased">{children}</body>
    </html>
  );
}
```
```css
/* app/globals.css */
@import "tailwindcss";
@theme inline {
  --font-sans: var(--font-inter), ui-sans-serif, system-ui, sans-serif;
  --font-mono: var(--font-jetbrains), ui-monospace, monospace;
}
```

## AI Agent Guidance
- Do check the Tailwind major version before writing any class or config.
- Do use `@theme`, `@utility`, `@custom-variant`, `@source`, `@plugin` for v4. Never create `tailwind.config.js` unless the repo already uses `@config`.
- Do use v4 names: `shadow-xs`, `rounded-xs`, `outline-hidden`, `ring-3`, `bg-linear-*`, `bg-black/50`, `flex!`, `bg-(--var)`, `inset-s-*`.
- Do specify border colors explicitly.
- Don't construct class names dynamically. Don't use `space-*` inside flex/grid (use `gap-*`).
- Don't remove focus outlines without `focus-visible:` replacements.
- Before done: run the build, confirm new classes render (inspect computed styles), run Prettier plugin sort, and check dark mode and at least `sm`/`lg` widths.

## Examples
```css
/* app.css — complete v4 entry */
@import "tailwindcss";
@plugin "@tailwindcss/typography";
@source "../node_modules/@acme/ui/dist";

@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));

@theme {
  --font-sans: "Inter Variable", ui-sans-serif, system-ui, sans-serif;
  --color-brand-50: oklch(97% 0.02 260);
  --color-brand-500: oklch(58% 0.16 260);
  --color-brand-600: oklch(51% 0.16 260);
  --breakpoint-3xl: 120rem;
  --radius-card: 0.75rem;
  --animate-fade-in: fade-in .2s ease-out;
  @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
}

@utility container-page {
  margin-inline: auto; max-inline-size: 80rem; padding-inline: --spacing(4);
}

@layer base {
  html { color-scheme: light dark; }
}
```
```tsx
import { cva } from "class-variance-authority";
import { twMerge } from "tailwind-merge";

const button = cva(
  "inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600 disabled:opacity-50",
  { variants: { intent: {
      primary: "bg-brand-600 text-white hover:bg-brand-500",
      ghost: "bg-transparent hover:bg-black/5 dark:hover:bg-white/10",
  } }, defaultVariants: { intent: "primary" } }
);

export function Button({ intent, className, ...p }: React.ComponentProps<"button"> & { intent?: "primary" | "ghost" }) {
  return <button className={twMerge(button({ intent }), className)} {...p} />;
}
```

## Related Skills
- [tailwind-design-system-architecture](../tailwind-design-system-architecture/Skill.md) — tokens, variants, and scaling Tailwind
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — theme toggling without FOUC
- [container-queries](../container-queries/Skill.md) — @container variants
- [shadcn-ui](../shadcn-ui/Skill.md) — v4-based component distribution
- [tailwind-component-kits](../tailwind-component-kits/Skill.md) — prebuilt Tailwind components
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md) — logical utilities

## Sources
- [Tailwind CSS v4.0 announcement](https://tailwindcss.com/blog/tailwindcss-v4) — Official — CSS-first config, engine
- [Upgrade guide](https://tailwindcss.com/docs/upgrade-guide) — Official — breaking changes, browser requirements
- [Theme variables](https://tailwindcss.com/docs/theme) — Official — namespaces, inline/static, reset
- [Tailwind CSS v4.3 blog](https://tailwindcss.com/blog/tailwindcss-v4-3) — Official — v4.2/4.3 features, deprecations
- [Dark mode docs](https://tailwindcss.com/docs/dark-mode) — Official — @custom-variant
- [Responsive design docs](https://tailwindcss.com/docs/responsive-design) — Official — breakpoints, container queries
- [GitHub releases](https://github.com/tailwindlabs/tailwindcss/releases) — Open Source — v4.3.3 (2026-07-16)
- [ofershap/tailwind-best-practices](https://github.com/ofershap/tailwind-best-practices) — Community — agent anti-pattern list
- [shamiul-anik/tailwindcss-skills](https://github.com/shamiul-anik/tailwindcss-skills) — Community — SKILL.md reference for v4.2
- [Next.js CSS-in-JS / styling docs](https://nextjs.org/docs/app/guides/css-in-js) — Official — framework context

## License / Usage Notes
Tailwind CSS is MIT licensed. Documentation is summarized, not copied, and code examples are original or minimal illustrative syntax.

## Quality Tier
S — Verified directly against official v4 docs and v4.3 release notes, with complete migration mapping and agent-specific guidance.

## Status
Active

## Last Verified
2026-09-15
