# Theming with CSS Variables

## Summary
CSS custom properties are the runtime theming mechanism for every modern React/Next.js styling approach (Tailwind v4, CSS Modules, shadcn/ui, vanilla-extract, StyleX, Panda). This skill covers token tiers expressed as variables, scoping themes with attributes, `@property` registration, derived colors (`color-mix()`, relative color syntax), sub-tree theming, user-customizable themes, and avoiding flashes and hydration mismatches in Next.js.

## Category
CSS & Styling

## Subcategories
Custom properties, @property, semantic tokens, data-theme scoping, multi-brand, white-label, color-mix, relative colors, runtime theme switching, SSR theming

## Problem It Solves
Hard-coded values and JS-driven themes (ThemeProvider context re-rendering the tree, duplicated stylesheets) are slow, flash on load, and break in Server Components. Variables let one attribute flip change every themed value instantly, from CSS, with no React re-render.

## When To Use
- Light/dark/high-contrast themes, brand or tenant themes, per-section themes (e.g. an inverted marketing band).
- User-customizable accent colors or density.
- Sharing tokens between CSS, Tailwind utilities, and JS (charts, canvas).

## When Not To Use
- Compile-time constants that never change and don't need to be inspectable (media query breakpoints can't use `var()`; use `@custom-media` via PostCSS/Lightning CSS or Tailwind `--breakpoint-*`).
- Values in selectors or media query conditions (unsupported).
- Per-element dynamic values that change every frame (animations are fine, but prefer `transform` for motion).

## Core Principles
1. **Tiered variables.** Primitive (`--blue-600`) → semantic (`--color-accent`) → component (`--button-bg`). Components read semantic or component variables only.
2. **Scope themes with attributes on a root.** `:root` holds defaults; `[data-theme="dark"]`, `[data-brand="x"]` or `.dark` override semantics. Any subtree can re-scope.
3. **Variables inherit.** Theming a subtree is just setting variables on its root element. No provider needed.
4. **Register when type matters.** `@property` gives syntax checking, non-inheritance when desired, initial values, and animatable interpolation.
5. **Derive, don't duplicate.** Hover/active/subtle variants come from `color-mix()` or `oklch(from …)` so brands need only a few base values.
6. **Theme state must be known before first paint.** Set the attribute server-side or via a blocking inline script.

## Best Practices
- Name semantics by role and pair foregrounds: `--color-bg`, `--color-fg`, `--color-surface`, `--color-surface-raised`, `--color-border`, `--color-accent`, `--color-on-accent`, `--color-danger`, `--color-on-danger`, `--color-focus`.
- Use `color-scheme: light dark` (or per theme) so native UI (scrollbars, form controls) matches.
- Use fallbacks for optional component variables: `background: var(--button-bg, var(--color-accent));`.
- Keep component variables "private" by convention (`--_btn-bg`) when they're internal implementation details.
- Store full color values, not channel fragments. Modern color functions and `color-mix()` make HSL channel tricks unnecessary.
- Expose JS access via `getComputedStyle(el).getPropertyValue("--color-accent")` for charts. Re-read on theme change (MutationObserver on the root attribute or theme context event).
- Validate and sanitize any user- or tenant-provided values before writing them as variables.

## Implementation Guidance

### Token file structure
```css
@layer tokens {
  :root {
    /* primitives */
    --gray-0: oklch(99% 0.002 260); --gray-100: oklch(96% 0.004 260);
    --gray-800: oklch(27% 0.015 260); --gray-950: oklch(15% 0.01 260);
    --indigo-500: oklch(58% 0.16 275); --indigo-300: oklch(76% 0.1 275);

    /* semantic (light default) */
    color-scheme: light;
    --color-bg: var(--gray-0);
    --color-fg: var(--gray-950);
    --color-surface: var(--gray-100);
    --color-border: color-mix(in oklch, var(--color-fg) 12%, transparent);
    --color-accent: var(--indigo-500);
    --color-on-accent: white;
    --color-accent-hover: oklch(from var(--color-accent) calc(l - 0.06) c h);
    --color-accent-subtle: color-mix(in oklch, var(--color-accent) 12%, var(--color-bg));
    --color-focus: var(--color-accent);
    --radius-m: 0.5rem;
  }

  [data-theme="dark"] {
    color-scheme: dark;
    --color-bg: var(--gray-950);
    --color-fg: var(--gray-0);
    --color-surface: var(--gray-800);
    --color-accent: var(--indigo-300);
    --color-on-accent: var(--gray-950);
    --color-accent-hover: oklch(from var(--color-accent) calc(l + 0.06) c h);
  }
}
```
Derived tokens (`--color-border`, `--color-accent-subtle`) recompute automatically because they reference variables resolved on the same element. **Caveat:** a derived variable declared on `:root` resolves on `:root`. If a subtree overrides `--color-accent`, `--color-accent-subtle` declared on `:root` won't update for that subtree unless you redeclare the derived tokens on the subtree selector too (group them: `:root, [data-theme], [data-brand] { --color-accent-subtle: … }`).

### @property registration
```css
@property --color-accent {
  syntax: "<color>";
  inherits: true;
  initial-value: oklch(58% 0.16 275);
}
@property --progress { syntax: "<percentage>"; inherits: false; initial-value: 0%; }
```
Benefits: animatable (`transition: --color-accent .3s`), invalid values fall back to the initial value instead of `unset`, and `inherits: false` stops leakage into nested components.

### Scoping decision table
| Scope | Mechanism |
|---|---|
| App-wide mode | attribute/class on `<html>` |
| Tenant/brand | `data-brand` on `<html>` set server-side |
| Section (inverted band, embedded widget) | `data-theme` on the section element (redeclare derived tokens for that selector) |
| Component variant | component variables (`--button-bg`) set by variant class/attribute |
| User custom accent | inline `style={{ "--color-accent": value }}` on `<html>` from validated preference |

### Derivation cheat sheet
```css
--hover:   oklch(from var(--base) calc(l - .05) c h);
--muted:   oklch(from var(--base) l calc(c * .4) h);
--alpha50: oklch(from var(--base) l c h / 50%);
--tint:    color-mix(in oklch, var(--base) 15%, white);
--shade:   color-mix(in oklch, var(--base), black 25%);
--complement: oklch(from var(--base) l c calc(h + 180));
```
Relative color syntax has been Baseline Newly available since 2024. If older browsers matter, provide a static fallback declaration before the derived one.

## Recommended Workflow
1. Define primitives (oklch) and semantic roles with design.
2. Write `:root` defaults and theme overrides for each mode/brand.
3. Add derived tokens and verify they update in scoped subtrees.
4. Register key variables with `@property` where animation/type safety matters.
5. Wire the styling system (Tailwind `@theme inline`, CSS Modules `var()`, vanilla-extract contract) to semantic variables.
6. Set theme attributes before paint (server-side or inline script).
7. Automate contrast checks for every semantic pair in every theme.

## Patterns
**Component-level API via variables**
```css
.button {
  --_bg: var(--button-bg, var(--color-accent));
  --_fg: var(--button-fg, var(--color-on-accent));
  background: var(--_bg); color: var(--_fg);
}
.button:hover { --_bg: var(--button-bg-hover, var(--color-accent-hover)); }
.button[data-variant="danger"] { --button-bg: var(--color-danger); --button-fg: var(--color-on-danger); }
```

**Inverted section**
```tsx
<section data-theme="dark" className="bg-(--color-bg) text-(--color-fg)">…</section>
```

**Theme color for charts (client)**
```tsx
"use client";
import { useEffect, useState } from "react";
export function useCssVar(name: string) {
  const [value, setValue] = useState("");
  useEffect(() => {
    const read = () => setValue(getComputedStyle(document.documentElement).getPropertyValue(name).trim());
    read();
    const mo = new MutationObserver(read);
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ["class", "data-theme", "style"] });
    return () => mo.disconnect();
  }, [name]);
  return value;
}
```

## Anti-Patterns
- **JS ThemeProvider passing color objects through Context to style props.** Re-renders the whole tree and needs client components. Put values in CSS variables and switch an attribute.
- **Primitive variables used directly in components (`var(--indigo-500)`).** Rebrand/dark mode requires edits everywhere. Use semantic variables.
- **HSL channel variables (`--primary: 220 90% 56%`) as a pattern.** Legacy workaround. Use full colors + `color-mix()` / relative colors.
- **Derived tokens declared only on `:root` but overridden bases in subtrees.** Stale derived colors. Redeclare derived tokens on every theme scope selector.
- **`var()` in media queries.** Invalid. Use `@custom-media` (build-time) or Tailwind breakpoints.
- **Writing unvalidated tenant CSS strings into `<style>`.** CSS injection. Accept typed values, validate, and set specific variables.
- **Toggling theme in `useEffect` after hydration.** Flash of wrong theme. Set before paint.

## Accessibility
- Verify contrast for every semantic pair in every theme (WCAG 1.4.3 text 4.5:1, 1.4.11 non-text 3:1).
- Provide a high-contrast theme via `@media (prefers-contrast: more)` that overrides semantic variables (stronger borders, darker fg).
- In `forced-colors: active`, variables are overridden by system colors for many properties. Use system color keywords (`CanvasText`, `LinkText`, `Highlight`) for critical boundaries.
- User-chosen accent colors must be clamped to accessible lightness, or paired with `contrast-color()` / precomputed on-colors.

## Responsive Design
Variables can change inside media/container queries (`@media (width >= 64rem) { :root { --space-section: 6rem; } }`), which keeps components breakpoint-agnostic. Style container queries can read custom properties to switch variants by parent.

## Performance
- Changing a variable on `<html>` restyles all dependents in one style recalc, far cheaper than re-rendering React trees.
- Very large numbers of variables on `:root` (thousands) add some style-recalc cost. Tailwind v4 emits only used theme variables by default.
- Registered `@property` with `inherits: false` limits recalc scope for frequently updated values (e.g. pointer-driven effects).

## Security
- Treat variable values from users/tenants as untrusted: only allow parsed colors/lengths; never allow `url(` or `;`/`}` characters; set via `element.style.setProperty` or React `style` (which escapes) rather than string-concatenated CSS.
- CSP: React inline `style` attributes with variables need `style-src-attr 'unsafe-inline'` under strict CSP. Alternatively set variables from a nonce'd `<style>` block rendered server-side.

## Testing
- Visual regression per theme/brand; include a scoped inverted section in the stories.
- Unit test color derivation/contrast with colorjs.io or culori in CI.
- E2E: toggle theme and assert computed `background-color` on key elements; reload and assert no flash (screenshot at first paint with `page.goto(..., { waitUntil: "commit" })`).

## Tooling
- Native CSS; Chrome DevTools shows computed variable values and `@property` registrations.
- Style Dictionary v4 / Terrazzo for generating variables from DTCG tokens.
- colorjs.io / culori for contrast and color math in scripts.
- `next-themes` for Next.js theme attribute management.

## Framework Notes
- **Next.js App Router:** set brand/tenant attributes on `<html>` in `app/layout.tsx` (Server Component) from request data (`headers()`/`cookies()`, which opts the layout into dynamic rendering), or statically per deployment. Use `next-themes` for user light/dark choice (it injects a blocking script); add `suppressHydrationWarning` on `<html>`. User-custom accent colors can be stored in a cookie and rendered as `style={{ "--color-accent": safeColor }}` on `<html>` for flash-free SSR.
- **React (Vite SPA):** put an inline script in `index.html` that reads `localStorage` and sets `data-theme` before the bundle loads. Expose a small context for toggling that only writes the attribute (no color values in context).
- **Tailwind v4:** map semantic variables with `@theme inline { --color-bg: var(--color-bg-val); }` (avoid name collisions: Tailwind `--color-*` names create utilities, so either define semantics directly in `@theme inline` pointing to differently-named runtime vars, or follow shadcn naming `--background` → `--color-background`).
- **CSS Modules / vanilla-extract / StyleX:** all consume variables. vanilla-extract `createThemeContract` and StyleX `defineVars`/`createTheme` generate hashed variable names; use their APIs rather than raw strings.

## AI Agent Guidance
- Do find the repo's semantic variables and use them; add new semantic tokens in the tokens file, not inline literals.
- Do derive hover/subtle states with `color-mix()`/relative colors from semantic bases.
- Do ensure theme attributes are set before paint (server or blocking script) and add `suppressHydrationWarning` where next-themes is used.
- Don't pass colors through React context or props for theming.
- Don't write user-provided strings into CSS without validation.
- Before done: check every theme (including a nested scoped theme), run contrast checks, and reload to confirm no flash.

## Examples
```tsx
// app/layout.tsx — tenant brand + user accent (validated) rendered on the server
import { cookies } from "next/headers";
import { ThemeProvider } from "next-themes";
import "./globals.css";

const OKLCH = /^oklch\(\s*(0?\.\d+|[0-9.]+%)\s+[0-9.]+\s+[0-9.]+\s*\)$/;

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const jar = await cookies();
  const brand = jar.get("brand")?.value === "globex" ? "globex" : "acme";
  const accent = jar.get("accent")?.value;
  const style = accent && OKLCH.test(accent) ? ({ "--color-accent": accent } as React.CSSProperties) : undefined;

  return (
    <html lang="en" data-brand={brand} style={style} suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="data-theme" defaultTheme="system" enableSystem disableTransitionOnChange>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```
```css
/* globals.css (excerpt) */
:root, [data-theme], [data-brand] {
  --color-accent-hover: oklch(from var(--color-accent) calc(l - 0.06) c h);
  --color-accent-subtle: color-mix(in oklch, var(--color-accent) 12%, var(--color-bg));
}
[data-brand="acme"]   { --color-accent: oklch(56% .17 25); }
[data-brand="globex"] { --color-accent: oklch(52% .13 160); }
```

## Related Skills
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — mode switching specifics
- [color-systems](../color-systems/Skill.md) — building accessible palettes
- [design-token-architecture](../design-token-architecture/Skill.md) — token tiers and pipelines
- [tailwind-design-system-architecture](../tailwind-design-system-architecture/Skill.md) — variables in Tailwind v4
- [multi-tenant-ui](../multi-tenant-ui/Skill.md) — tenant branding
- [content-security-policy](../content-security-policy/Skill.md) — style-src implications
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md) — contrast verification

## Sources
- [web.dev — Color themes with Baseline CSS features](https://web.dev/articles/baseline-in-action-color-theme) — Official — oklch, relative colors, color-mix, light-dark, @property approach
- [MDN — Using CSS custom properties](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties) — Official — inheritance, fallbacks
- [MDN — @property](https://developer.mozilla.org/en-US/docs/Web/CSS/@property) — Official — registration semantics
- [MDN — Using relative colors](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Colors/Using_relative_colors) — Official — syntax
- [Ahmad Shadeed — CSS relative colors](https://ishadeed.com/article/css-relative-colors/) — Community — practical derivations
- [next-themes](https://github.com/pacocoursey/next-themes) — Open Source — attribute switching, suppressHydrationWarning
- [Tailwind — Theme variables](https://tailwindcss.com/docs/theme) — Official — @theme inline mapping
- [vanilla-extract theming](https://vanilla-extract.style/documentation/theming/) — Official — typed contracts

## License / Usage Notes
MDN is CC-BY-SA, web.dev is CC-BY 4.0, and next-themes is MIT. Content is summarized, and code is original.

## Quality Tier
A — Official specs plus proven Next.js patterns. The derived-token scoping caveat is well tested but worth verifying per setup.

## Status
Active

## Last Verified
2026-09-15
