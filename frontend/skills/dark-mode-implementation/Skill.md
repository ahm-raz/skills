# Dark Mode Implementation

## Summary
How to ship light/dark/system themes in React and Next.js with no flash of incorrect theme (FOUC), no hydration errors, correct native UI (`color-scheme`), accessible contrast, and a well-designed dark palette. Covers `prefers-color-scheme`, `light-dark()`, next-themes, Tailwind v4 `@custom-variant dark`, cookie-based SSR, images, and `theme-color`.

## Category
CSS & Styling

## Subcategories
prefers-color-scheme, color-scheme, light-dark(), next-themes, Tailwind dark variant, FOUC prevention, hydration, theme toggle UX, dark palette design, media in dark mode

## Problem It Solves
Typical bugs: white flash on load for dark users, hydration mismatch warnings from theme toggles, form controls and scrollbars staying light, pure-black backgrounds with vibrating text, logos invisible on dark, toggle icons rendering wrong on the server, and hundreds of `dark:` classes to maintain.

## When To Use
- Any Next.js or React app offering system/light/dark themes.
- Adding dark mode to an existing Tailwind or CSS Modules design system.
- Fixing flash or hydration issues in an existing theme toggle.

## When Not To Use
- Brand/tenant theming in general. See theming-with-css-variables.
- A single forced theme (just set `color-scheme` and tokens).

## Core Principles
1. **Default to the system.** Respect `prefers-color-scheme` unless the user explicitly overrides; offer Light / Dark / System.
2. **Decide before paint.** The theme attribute must be on `<html>` before first render, via a blocking inline script (next-themes) or server-rendered from a cookie.
3. **Tokens switch, components don't.** Semantic variables change under `.dark` / `[data-theme=dark]`. Components use tokens, not `dark:` everywhere.
4. **Set `color-scheme`.** It flips UA defaults: canvas, form controls, scrollbars, and makes `light-dark()` work.
5. **Dark is designed, not inverted.** Elevated surfaces get lighter, saturation drops, pure black and pure white are avoided for large areas.
6. **Theme-dependent UI renders after mount.** Anything that displays the current theme (toggle icon) can't know it on the server.

## Best Practices
- `:root { color-scheme: light dark; }` for system-only; with a toggle, set `color-scheme: light` / `dark` on the theme selector.
- Use `light-dark(light, dark)` for simple token definitions (Newly available; Widely available ~Nov 2026). It follows `color-scheme`, so it also works with a class toggle if the class sets `color-scheme`.
- Dark backgrounds around `oklch(14–20% 0.01–0.02 h)`; body text around `oklch(90–95% …)`, not `#fff`.
- Express elevation with lighter surfaces (`surface-1` < `surface-2` < `surface-3`), not only shadows.
- Desaturate accents in dark (lower chroma, higher lightness) to keep contrast without glare.
- Provide dark variants for images/logos: `<picture><source srcset="logo-dark.svg" media="(prefers-color-scheme: dark)">`, or CSS-toggled SVG `currentColor`. With a manual toggle, render both and hide via theme class.
- Update `<meta name="theme-color">` with media variants for browser chrome.
- Use `disableTransitionOnChange` (next-themes) to avoid everything animating during a switch.
- Persist explicit choice in `localStorage` (next-themes default) or a cookie (enables SSR theme, analytics-free).

## Implementation Guidance

### Strategy decision table
| Requirement | Approach |
|---|---|
| System only, no toggle | `color-scheme: light dark` + `light-dark()` or `@media (prefers-color-scheme: dark)` tokens; zero JS |
| Toggle, static/ISR pages (most Next.js apps) | `next-themes` (inline blocking script, localStorage) + `suppressHydrationWarning` |
| Toggle, must be correct in server HTML (no script, e.g. strict CSP or email previews) | Cookie read in `app/layout.tsx` → `<html className={theme}>`; forces dynamic rendering of the layout |
| Vite SPA | Inline script in `index.html` + small context |
| Tailwind v4 with toggle | `@custom-variant dark (&:where(.dark, .dark *));` (or data attribute) |

### Tailwind v4
```css
@import "tailwindcss";
@custom-variant dark (&:where(.dark, .dark *));
/* or: @custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *)); */
```
Without this, `dark:` follows `prefers-color-scheme` only. The next-themes README's `darkMode: 'selector'` refers to Tailwind v3 config and does not apply to v4.

### Token-based switching (preferred over dark: everywhere)
```css
:root { color-scheme: light; --bg: oklch(99% 0 0); --fg: oklch(20% .02 260); --surface-2: oklch(96% .004 260); --border: oklch(90% .006 260); }
.dark { color-scheme: dark; --bg: oklch(17% .012 260); --fg: oklch(93% .008 260); --surface-2: oklch(23% .014 260); --border: oklch(32% .014 260); }
@theme inline { --color-bg: var(--bg); --color-fg: var(--fg); --color-surface-2: var(--surface-2); --color-border: var(--border); }
```

### Equivalent with light-dark() (no class needed for system mode)
```css
:root {
  color-scheme: light dark;
  --bg: light-dark(oklch(99% 0 0), oklch(17% .012 260));
  --fg: light-dark(oklch(20% .02 260), oklch(93% .008 260));
}
.light { color-scheme: light; }  /* manual override still works */
.dark  { color-scheme: dark; }
```

### next-themes key facts
- `<ThemeProvider attribute="class" | "data-theme" defaultTheme="system" enableSystem disableTransitionOnChange>`.
- `useTheme()` returns `theme` (may be `"system"`), `resolvedTheme` (actual light/dark), `systemTheme`, `setTheme`, `themes`.
- Supports `forcedTheme` per page, `storageKey`, `value` mapping, `nonce` for CSP, `scriptProps`.
- On the server `theme` is `undefined`, so gate theme-dependent rendering until mounted.

## Recommended Workflow
1. Design dark tokens (surfaces, text, borders, accents, states) and check contrast.
2. Implement tokens under the theme selector; set `color-scheme`.
3. Configure Tailwind `@custom-variant dark` (if Tailwind) to match the attribute strategy.
4. Add next-themes ThemeProvider (client component) in the root layout, with `suppressHydrationWarning` on `<html>`.
5. Build the toggle (Light/Dark/System) with mounted gating; set `aria-pressed` or use a radio group/menu.
6. Handle images, logos, code highlighting themes, charts, embedded iframes, `theme-color`.
7. Test: first load in dark OS (no flash), reload after choosing, system change while open, JS disabled.

## Patterns
**Providers (client boundary kept tiny)**
```tsx
// app/providers.tsx
"use client";
import { ThemeProvider } from "next-themes";
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      {children}
    </ThemeProvider>
  );
}
```

**Accessible three-way toggle**
```tsx
"use client";
import { useTheme } from "next-themes";
import { useSyncExternalStore } from "react";

const useMounted = () => useSyncExternalStore(() => () => {}, () => true, () => false);

export function ThemeSwitcher() {
  const { theme, setTheme } = useTheme();
  const mounted = useMounted();
  const options = ["light", "dark", "system"] as const;
  return (
    <fieldset className="inline-flex gap-1 rounded-md border border-border p-1">
      <legend className="sr-only">Color theme</legend>
      {options.map((opt) => (
        <label key={opt} className="cursor-pointer rounded px-2 py-1 text-sm has-checked:bg-surface-2">
          <input type="radio" name="theme" value={opt} className="sr-only"
                 checked={mounted && theme === opt} onChange={() => setTheme(opt)} />
          {opt[0].toUpperCase() + opt.slice(1)}
        </label>
      ))}
    </fieldset>
  );
}
```

**Theme-aware image without JS**
```tsx
<>
  <img src="/logo-light.svg" alt="Acme" className="dark:hidden" width={120} height={32} />
  <img src="/logo-dark.svg" alt="" aria-hidden className="hidden dark:block" width={120} height={32} />
</>
```

**Cookie-based SSR theme (no inline script)**
```tsx
// app/layout.tsx
import { cookies } from "next/headers";
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const pref = (await cookies()).get("theme")?.value; // "light" | "dark" | undefined(system)
  const cls = pref === "dark" ? "dark" : pref === "light" ? "light" : undefined;
  return <html lang="en" className={cls}><body>{children}</body></html>;
}
// System users: rely on light-dark()/prefers-color-scheme CSS when no class is set.
// Toggle: Server Action sets the cookie and revalidates; optimistically set the class client-side.
```

**theme-color metadata (Next.js)**
```tsx
import type { Viewport } from "next";
export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#0b0d12" },
  ],
  colorScheme: "light dark",
};
```

## Anti-Patterns
- **Reading `localStorage` in `useEffect` then setting the class.** Flash of light theme on every load. Use a blocking script (next-themes) or SSR cookie.
- **Rendering `theme === "dark" ? <Moon/> : <Sun/>` on the server.** Hydration mismatch. Gate on mounted or render both icons toggled via CSS `dark:` classes.
- **Missing `suppressHydrationWarning` on `<html>` with next-themes.** Console hydration warnings. Add it (it applies one level deep only).
- **`dark:` classes on every element.** Maintenance burden, inconsistencies. Switch semantic tokens.
- **`filter: invert(1)` on the page.** Inverts images, breaks brand colors. Design tokens.
- **Pure `#000` background with `#fff` text.** Halation/eye strain for many users. Use near-black and off-white.
- **Forgetting `color-scheme`.** White scrollbars/inputs in dark mode. Set it per theme.
- **Only `prefers-color-scheme` media in CSS while offering a toggle.** Toggle has no effect. Use class/attribute strategy (with `light-dark()` + `color-scheme` or the custom variant).
- **Transitions on `background-color` for everything.** Janky theme switch. `disableTransitionOnChange`.

## Accessibility
- Contrast in both themes: text 4.5:1 (1.4.3), UI components/focus indicators 3:1 (1.4.11). Dark-mode focus rings often fail, so test them.
- The toggle must be keyboard-operable with a proper name and state (radio group, `aria-pressed` button, or menu with `menuitemradio`).
- Respect `prefers-contrast: more` with stronger borders/text in both themes.
- In `forced-colors: active`, don't rely on background colors for meaning; use borders/outlines.
- Don't auto-switch theme based on time of day without user consent.

## Responsive Design
Theme is orthogonal to viewport, but check dark mode at mobile widths: `theme-color` affects the mobile browser UI; OLED phones make pure black tempting (fine for large surfaces only if text isn't pure white).

## Performance
- The next-themes script is tiny and runs synchronously before paint. Keep it; don't replace it with async logic.
- Cookie-based SSR theme makes the root layout dynamic (no full static optimization). Weigh that against the script approach.
- Duplicate images for themes: use `<picture>` + media (system mode) so only one downloads. The CSS-hidden `<img>` approach may download both (use `loading="lazy"` on the hidden variant or SVG with `currentColor`).

## Security
- Inline theme script plus strict CSP: pass `nonce` to next-themes (read the nonce from the proxy/middleware-set header in the layout), or use the cookie SSR approach.
- Validate the theme cookie value against an allow-list before using it as a class.

## Testing
- Playwright `test.use({ colorScheme: "dark" })` for system dark; set `localStorage` via `addInitScript` for explicit choice.
- Flash test: capture a screenshot immediately after `goto` with `waitUntil: "commit"`, or assert `document.documentElement.classList` in `addInitScript`-observed first frame.
- Visual regression of key pages in both themes; axe contrast checks per theme.
- Check console for hydration warnings in dev.

## Tooling
- `next-themes`. Community, active, de facto for Next.js.
- Tailwind v4 `@custom-variant`. Official.
- `light-dark()`, `color-scheme`. Native CSS.
- Shiki (dual themes via CSS variables) for code blocks. Active.
- Radix Colors / Leonardo for dark palettes (see color-systems).

## Framework Notes
- **Next.js App Router:** ThemeProvider must be a Client Component (`app/providers.tsx`) wrapping `children` in `app/layout.tsx`. Server Components below it still render on the server. Add `suppressHydrationWarning` to `<html>`. Use the `viewport` export for `themeColor`/`colorScheme`. Per-route forced themes: `<ThemeProvider forcedTheme="dark">` in a nested layout segment via a client wrapper.
- **React (Vite SPA):** inline in `index.html` `<head>`: `<script>document.documentElement.classList.toggle("dark", localStorage.theme === "dark" || (!("theme" in localStorage) && matchMedia("(prefers-color-scheme: dark)").matches))</script>`, then a context that updates the class, `localStorage`, and listens to `matchMedia("(prefers-color-scheme: dark)").addEventListener("change", …)` for system mode.
- **shadcn/ui:** uses next-themes with `attribute="class"` and `.dark` token overrides. Follow that if present.

## AI Agent Guidance
- Do check for existing next-themes/theme context before adding one; never add a second mechanism.
- Do use semantic tokens and `color-scheme`; add Tailwind `@custom-variant dark` when a class/attribute toggle exists.
- Do gate theme-dependent rendering on mount; add `suppressHydrationWarning` on `<html>`.
- Don't set the theme in `useEffect` from storage; don't use `filter: invert`.
- Before done: load with OS dark (no flash), toggle all three options, reload, check console for hydration warnings, run contrast checks in both themes, verify form controls/scrollbars are dark.

## Examples
```tsx
// app/layout.tsx
import type { Metadata, Viewport } from "next";
import { Providers } from "./providers";
import "./globals.css";

export const metadata: Metadata = { title: "Acme" };
export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#fcfcfd" },
    { media: "(prefers-color-scheme: dark)", color: "#0f1117" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="bg-bg text-fg antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
```
```css
/* app/globals.css */
@import "tailwindcss";
@custom-variant dark (&:where(.dark, .dark *));

:root {
  color-scheme: light;
  --bg: oklch(99.2% .002 260); --fg: oklch(21% .02 260); --muted: oklch(50% .015 260);
  --surface-1: oklch(97.5% .003 260); --surface-2: oklch(95% .005 260);
  --border: oklch(90% .006 260); --accent: oklch(52% .16 265); --on-accent: oklch(99% 0 0);
}
.dark {
  color-scheme: dark;
  --bg: oklch(16% .01 260); --fg: oklch(93% .006 260); --muted: oklch(72% .012 260);
  --surface-1: oklch(20% .012 260); --surface-2: oklch(24% .014 260);
  --border: oklch(31% .014 260); --accent: oklch(72% .12 265); --on-accent: oklch(18% .02 265);
}
@theme inline {
  --color-bg: var(--bg); --color-fg: var(--fg); --color-muted: var(--muted);
  --color-surface-1: var(--surface-1); --color-surface-2: var(--surface-2);
  --color-border: var(--border); --color-accent: var(--accent); --color-on-accent: var(--on-accent);
}
```

## Related Skills
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — token scoping mechanics
- [color-systems](../color-systems/Skill.md) — designing dark palettes
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — @custom-variant dark
- [settings-and-preferences-ux](../settings-and-preferences-ux/Skill.md) — preference UI
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md) — contrast in both themes
- [content-security-policy](../content-security-policy/Skill.md) — nonce for inline theme script
- [shadcn-ui](../shadcn-ui/Skill.md) — common dark mode setup

## Sources
- [Tailwind CSS — Dark mode](https://tailwindcss.com/docs/dark-mode) — Official — @custom-variant class/data attribute, three-way toggle script
- [next-themes (GitHub)](https://github.com/pacocoursey/next-themes) — Open Source — provider props, useTheme, suppressHydrationWarning, mounted pattern
- [web.dev — Color themes with Baseline CSS](https://web.dev/articles/baseline-in-action-color-theme) — Official — color-scheme, light-dark()
- [MDN — light-dark()](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/light-dark) — Official — function semantics
- [MDN — color-scheme](https://developer.mozilla.org/en-US/docs/Web/CSS/color-scheme) — Official — UA theming
- [Next.js — generateViewport / themeColor](https://nextjs.org/docs/app/api-reference/functions/generate-viewport) — Official — theme-color metadata
- [Josh W. Comeau — The Quest for the Perfect Dark Mode](https://www.joshwcomeau.com/react/dark-mode/) — Community — flash-free approach rationale
- [Radix Colors — dark scales](https://www.radix-ui.com/colors) — Open Source — dark palette design

## License / Usage Notes
Tailwind and next-themes are MIT, MDN is CC-BY-SA, and web.dev is CC-BY 4.0. Content is summarized, and code is original.

## Quality Tier
S — Verified against Tailwind v4 and next-themes docs, with complete Next.js-specific flash/hydration handling and tests.

## Status
Active

## Last Verified
2026-09-15
