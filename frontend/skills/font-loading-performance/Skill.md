# Font Loading Performance

## Summary
Web fonts affect FCP/LCP (invisible or late text), CLS (reflow when fonts swap) and bytes. Fast font loading means self-hosting WOFF2, subsetting, loading few families/weights (variable fonts when many weights), choosing `font-display` deliberately, preloading only the critical file, and giving the fallback font matching metrics. In Next.js, `next/font` does most of this automatically; in a Vite SPA you assemble it from Fontsource, preload links and `fontaine`.

## Category
Performance

## Subcategories
font-display, WOFF2, subsetting, unicode-range, variable fonts, preload, size-adjust and metric overrides, next/font, Fontsource, icon fonts

## Problem It Solves
Flash of invisible text (FOIT) delaying text LCP up to 3 s, flash of unstyled text causing large layout shifts, third-party font CDNs adding DNS/TLS round trips and privacy issues, and hundreds of KB of unused glyphs and weights.

## When To Use
- Adding or changing brand typography.
- Text LCP is slow or CLS attribution points at text blocks shifting after load.
- Using Google Fonts or Adobe Fonts via third-party CSS.

## When Not To Use
- System font stacks only (`system-ui`) — nothing to load.
- Typography design decisions (scale, pairing) — see [typography-systems](../typography-systems/Skill.md).

## Core Principles
1. **Self-host WOFF2** on your origin/CDN with immutable caching; no third-party font CSS at runtime.
2. **Load less**: ≤ 2 families, ≤ 3–4 files on first render; variable font when you need many weights.
3. **Subset** to the scripts/characters you use (`unicode-range` splits by script).
4. **Pick `font-display` by priority**: `optional` for performance-first/no shift, `swap` for brand-critical text with metric-matched fallback.
5. **Match fallback metrics** (`size-adjust`, `ascent-override`, `descent-override`, `line-gap-override`) so swaps don't shift layout.

## Best Practices
- Preload only the font(s) used above the fold (typically the body regular or heading weight); `<link rel="preload" as="font" type="font/woff2" crossorigin>`—`crossorigin` is required even same-origin.
- Put `@font-face` in inline/critical CSS (or ensure the stylesheet is render-critical) so fonts are discovered early.
- Avoid faux bold/italic by loading the needed style or using a variable font with `wght`/`ital` axes.
- Replace icon fonts with SVG icons (smaller, accessible, no FOIT squares).
- Budget: first-render fonts ≤ ~100 KB total WOFF2.
- Cache: `Cache-Control: public, max-age=31536000, immutable` for hashed font URLs.
- Check Safari support for the `*-override` descriptors on your target versions; `size-adjust` alone still reduces shift.

## Implementation Guidance

### font-display decision
| Value | Behavior | Use when |
|---|---|---|
| `optional` | ~100 ms block; use font only if ready, else fallback for this page view (cached next time) | Performance-first sites; body text; zero-CLS goal |
| `swap` | ~0 block; swap when loaded | Brand-critical headings/logotype text; pair with metric overrides |
| `fallback` | ~100 ms block, ~3 s swap window | Middle ground |
| `block` | up to 3 s invisible | Avoid (icon fonts only, and you should replace those) |
| `auto` | browser default (usually block) | Avoid |

### Next.js: next/font
```tsx
// app/fonts.ts
import { Inter } from 'next/font/google';
import localFont from 'next/font/local';

export const inter = Inter({
  subsets: ['latin'],        // preloaded subset(s)
  display: 'swap',           // next/font default is 'swap'
  variable: '--font-inter',
  // adjustFontFallback: true (default) → metric-matched fallback generated at build
});

export const brand = localFont({
  src: [{ path: './fonts/Brand-Var.woff2', weight: '400 800', style: 'normal' }],
  display: 'optional',
  variable: '--font-brand',
  preload: true,             // default
  // adjustFontFallback: 'Arial' (default for local) | 'Times New Roman' | false
});

// app/layout.tsx
import { inter, brand } from './fonts';
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${brand.variable}`}>
      <body className="font-sans">{children}</body>
    </html>
  );
}
```
Google fonts are downloaded at build time and self-hosted—no browser requests to Google. Fonts defined in a page are preloaded only on that route; in the root layout, on all routes. Define each font once (fonts file) and import it; each loader call creates a separate instance.

Tailwind v4:
```css
@import 'tailwindcss';
@theme inline { --font-sans: var(--font-inter); --font-display: var(--font-brand); }
```

### React (Vite SPA)
```bash
npm i @fontsource-variable/inter
npm i -D fontaine
```
```ts
// main.tsx
import '@fontsource-variable/inter/wght.css'; // self-hosted, unicode-range subsets, font-display: swap
```
```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { FontaineTransform } from 'fontaine';

export default defineConfig({
  plugins: [
    react(),
    FontaineTransform.vite({
      fallbacks: ['Arial', 'Helvetica Neue', 'system-ui'],
      resolvePath: (id) => new URL(`./node_modules/@fontsource-variable/inter/files/${id.split('/').pop()}`, import.meta.url),
    }),
  ],
});
```
```html
<!-- index.html: preload the single most critical file (use the hashed URL from the build or a fixed public/ path) -->
<link rel="preload" href="/fonts/inter-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
```

### Manual metric-matched fallback
```css
@font-face {
  font-family: 'Brand';
  src: url('/fonts/brand-var.9c1e.woff2') format('woff2-variations');
  font-weight: 400 800;
  font-display: swap;
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+2000-206F, U+20AC;
}
@font-face {
  font-family: 'Brand Fallback';
  src: local('Arial');
  size-adjust: 104.5%;
  ascent-override: 92%;
  descent-override: 24%;
  line-gap-override: 0%;
}
:root { --font-brand: 'Brand', 'Brand Fallback', system-ui, sans-serif; }
```
Compute override values with `fontaine`/Capsize (`@capsizecss/metrics`), not by eye.

### Subsetting
- Google-hosted families via `next/font`/Fontsource come pre-split by `unicode-range`.
- Custom fonts: `pyftsubset Brand.ttf --unicodes="U+0000-00FF,U+2000-206F" --flavor=woff2 --layout-features='kern,liga'` (fonttools) or glyphhanger to crawl used glyphs. Keep a fallback subset for user-generated content in other scripts.

## Recommended Workflow
1. Inventory fonts in Network panel (type: font): count files, sizes, origins, whether preloaded, when they load vs FCP/LCP.
2. Remove unused families/weights; switch to variable where ≥ 3 weights of one family.
3. Self-host (next/font or Fontsource); subset.
4. Choose `font-display` per role; generate metric-matched fallbacks.
5. Preload the one critical file; remove other font preloads.
6. Verify: text visible at FCP, no text-block layout shifts (DevTools layout shift culprits—"web font" is a flagged cause), font bytes within budget.

## Patterns
- **Single variable font** covering body + headings via `wght` axis.
- **Critical subset first**: preload Latin subset; other scripts load on demand via `unicode-range`.
- **`optional` for body, `swap` + metrics for display headings.**
- **CSS variable font tokens** so fonts swap centrally ([design-token-architecture](../design-token-architecture/Skill.md)).

## Anti-Patterns
- **`<link href="https://fonts.googleapis.com/css2?...">` in production** → extra origins, render-blocking CSS, privacy concerns. Fix: `next/font/google` or Fontsource.
- **Preloading every weight/style** → priority contention, wasted bytes. Fix: preload one.
- **Missing `crossorigin` on font preload** → double download. Fix: add `crossorigin`.
- **Icon fonts** → FOIT boxes, poor a11y. Fix: SVG icons.
- **`font-display: block`** on body text → invisible text up to 3 s. Fix: `swap`/`optional`.
- **Calling `Inter()` in many components** (Next.js) → multiple instances. Fix: one fonts module.

## Accessibility
- Honor user font-size settings: use `rem`; don't lock sizes in px on `html`.
- Ensure fallback fonts remain legible (x-height similar) — metric overrides help readability during swap.
- Some users override fonts (dyslexia-friendly fonts, high-contrast modes); don't break layouts that assume exact glyph widths.
- Avoid icon fonts: screen readers may read private-use glyphs; SVG with `aria-hidden` or labels is correct.

## Responsive Design
- Text wrapping on narrow viewports amplifies swap shifts—test metric overrides at 320–390 px.
- Fluid type (`clamp()`) doesn't change font loading, but large display sizes make mismatched fallbacks more visible ([fluid-typography-and-spacing](../fluid-typography-and-spacing/Skill.md)).

## Performance
- WOFF2 is ~30% smaller than WOFF; ship WOFF2 only (universal support).
- Variable fonts pay off when replacing ≥ 2–3 static files of the same family.
- Font preloads are high priority—each one competes with the LCP image.

## Security
- Self-hosting removes third-party requests (and IP leakage to font CDNs—relevant to GDPR rulings on Google Fonts).
- Fonts are fetched in CORS mode; keep `font-src 'self'` in CSP when self-hosting ([content-security-policy](../content-security-policy/Skill.md)).
- Check font licenses permit self-hosting/web embedding and subsetting.

## Testing
- Lighthouse / DevTools insights: "Font display" and layout shift culprits (web fonts).
- Playwright with `document.fonts.ready` for deterministic screenshots in visual regression tests.
- Slow 3G + cache-disabled run to observe swap behavior and shift.

## Tooling
- `next/font` (google & local; defaults: `display: 'swap'`, `preload: true`, `adjustFontFallback` on) — Active.
- Fontsource (`@fontsource/*`, `@fontsource-variable/*`) — Active.
- `fontaine` (unjs; Vite plugin for metric fallbacks) — Active.
- Capsize (`@capsizecss/core`, `@capsizecss/metrics`) — Active.
- fonttools `pyftsubset`, glyphhanger — Active/Maintenance.

## Framework Notes
- **Next.js**: use `next/font` exclusively; define fonts in one module; expose via CSS variables for Tailwind v4 `@theme`; use `display: 'optional'` for zero-shift body text if brand allows. See [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md).
- **React (Vite SPA)**: Fontsource imports in `main.tsx` (CSS bundled and hashed by Vite) + `fontaine` plugin + one manual preload in `index.html`. Because CSR delays render anyway, `optional` often shows fallback on first visit—accept or prerender HTML.

## AI Agent Guidance
- Do: replace Google Fonts `<link>` tags with `next/font` (Next) or Fontsource (Vite).
- Do: limit to needed weights/subsets; generate fallback metrics via tooling.
- Don't: add multiple font preloads, `font-display: block`, or icon fonts.
- Don't: hand-guess override percentages.
- Before declaring done: Network shows only same-origin WOFF2 fonts, ≤ 1–2 preloaded; no layout shift from text on load (DevTools); font license allows self-hosting.

## Examples
```tsx
// Using a display font only on marketing routes (preloaded only there)
// app/(marketing)/layout.tsx
import { brand } from '@/app/fonts';
export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return <div className={brand.className}>{children}</div>;
}
```

## Related Skills
- [cls-prevention](../cls-prevention/Skill.md) — font swap shifts
- [lcp-optimization](../lcp-optimization/Skill.md) — text LCP render delay
- [typography-systems](../typography-systems/Skill.md) — type design decisions
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — next/font deep dive
- [resource-hints-and-network-optimization](../resource-hints-and-network-optimization/Skill.md) — preload/preconnect trade-offs
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) — immutable font caching

## Sources
- [web.dev: Best practices for fonts](https://web.dev/articles/font-best-practices) — Official — preconnect, inlining @font-face, WOFF2, unicode-range, font-display, preload caution
- [Next.js Font Module API](https://nextjs.org/docs/app/api-reference/components/font) — Official — options/defaults (display swap, preload, adjustFontFallback), preloading scope (docs v16.3.5)
- [MDN: @font-face descriptors](https://developer.mozilla.org/en-US/docs/Web/CSS/@font-face) — Official — size-adjust, overrides
- [fontaine](https://github.com/unjs/fontaine) — Open Source — automatic fallback metrics
- [Fontsource](https://fontsource.org/) — Open Source — self-hosted font packages
- [Zach Leatherman: font loading strategies](https://www.zachleat.com/web/comprehensive-webfonts/) — Community — FOIT/FOUT strategy background (older; principles valid)

## License / Usage Notes
Summarized. Fontsource packages carry each font's own license (often OFL). Examples original.

## Quality Tier
A — Official guidance and verified next/font defaults; Safari override descriptor support should be rechecked per target.

## Status
Active

## Last Verified
2026-09-15
