# Typography Systems

## Summary
A typography system is the set of font families, a type scale, weights, line-heights, letter-spacing, measure and text roles (display, heading, body, label, caption, code) that make UI text consistent and readable. This skill covers building one for React/Next.js: variable fonts via `next/font`, fallback metric matching, semantic text tokens, modern text CSS (`text-wrap`, `text-box`, `font-variant-numeric`), and readability/accessibility requirements.

## Category
CSS & Styling

## Subcategories
Type scale, font pairing, variable fonts, next/font, font fallbacks, line-height, measure, letter-spacing, text roles, tabular numbers, text-wrap, text-box-trim, prose styling

## Problem It Solves
Ad-hoc font sizes (`text-[15px]`, `17px`), inconsistent weights, bad line lengths, layout shift from web fonts, misaligned numbers in tables, and orphaned headings make interfaces feel amateur and hurt readability. A typography system makes text decisions once.

## When To Use
- Setting up a new app or design system's text styles.
- Auditing inconsistent typography.
- Choosing fonts and loading strategy in Next.js.
- Styling long-form content (docs, blog, MDX).

## When Not To Use
- Fluid clamp math specifics. See fluid-typography-and-spacing.
- Font loading performance deep-dive (preload, subsetting internals). See font-loading-performance and nextjs-image-and-font-optimization.

## Core Principles
1. **Roles over sizes.** Components use roles (`text-heading-md`, `text-body`, `text-label`), which map to size + line-height + weight + tracking.
2. **One scale.** A modular ratio (1.125–1.25 for app UI, 1.25–1.333 for marketing) or a hand-tuned set of ~8–10 sizes.
3. **Line-height decreases as size increases.** Body 1.5–1.7, UI labels 1.25–1.4, headings 1.05–1.25.
4. **Measure matters.** Body text 45–75 characters per line (`max-inline-size: 65ch`).
5. **Fewer families, more axes.** 1–2 families (sans + mono, maybe a display/serif), preferably variable fonts.
6. **rem units** so user font-size preferences apply.
7. **No layout shift.** Self-hosted fonts with metric-adjusted fallbacks.

## Best Practices
- Load fonts with `next/font` (self-hosted, automatic `size-adjust` fallback, no external requests). Prefer variable fonts to avoid multiple weight files.
- Expose fonts as CSS variables (`variable: "--font-sans"`) and map them in Tailwind `@theme inline` or your tokens.
- Define a system font stack fallback for each role (`ui-sans-serif, system-ui, sans-serif`; `ui-monospace, SFMono-Regular, Menlo, monospace`).
- Tighten letter-spacing on large display text (−0.01 to −0.03em); loosen slightly for all-caps labels (+0.04 to +0.08em).
- Use `font-variant-numeric: tabular-nums` for tables, prices, timers, and stats; `slashed-zero` for codes.
- Use `text-wrap: balance` on headings (≤6 lines) and `text-wrap: pretty` on paragraphs.
- Use `text-box: trim-both cap alphabetic` for optically centered text in buttons/badges where supported (progressive enhancement); verify cross-browser before relying on it.
- Use `hanging-punctuation` (Safari) and `text-indent: hanging` (Baseline 2026) only as enhancements.
- Limit weights to ~3 (400, 500/600, 700). Avoid ultra-thin weights for body/UI text.
- Use `font-optical-sizing: auto` with fonts that have an `opsz` axis.
- Use `@tailwindcss/typography` (`prose`) or a scoped prose stylesheet for MDX/CMS content.

## Implementation Guidance

### Role table (app UI example, 16px base)
| Role | Size | Line-height | Weight | Tracking | Use |
|---|---|---|---|---|---|
| display | 3rem → 3.75rem (fluid) | 1.05 | 700 | −0.02em | Marketing hero |
| heading-xl | 2.25rem | 1.15 | 700 | −0.015em | Page title |
| heading-lg | 1.5rem | 1.25 | 600 | −0.01em | Section title |
| heading-md | 1.25rem | 1.3 | 600 | 0 | Card title |
| body-lg | 1.125rem | 1.6 | 400 | 0 | Lead paragraph |
| body | 1rem | 1.6 | 400 | 0 | Default |
| body-sm | 0.875rem | 1.5 | 400 | 0 | Secondary text, dense UI |
| label | 0.875rem | 1.3 | 500 | 0.005em | Form labels, buttons |
| caption | 0.75rem | 1.4 | 400 | 0.01em | Meta, helper text |
| overline | 0.75rem | 1.3 | 600 | 0.08em uppercase | Eyebrows |
| code | 0.875em | 1.5 | 400 | 0 | Inline/blocks (em-relative) |

### Choosing a scale
| Product | Ratio | Notes |
|---|---|---|
| Dense dashboards/admin | 1.125–1.2 | Small jumps; base 14–16px |
| General SaaS | 1.2–1.25 | Base 16px |
| Marketing/editorial | 1.25–1.333 (fluid) | Larger display range |

### Font pairing heuristics
- One neutral sans for UI (Inter, Geist, IBM Plex Sans, Source Sans 3, system-ui) plus a monospace (Geist Mono, JetBrains Mono, IBM Plex Mono).
- For personality, add a display or serif for headings only (Fraunces, Newsreader, Instrument Serif). Contrast in structure, similar x-height.
- Check language coverage (subsets, CJK/Arabic needs) before choosing.
- Avoid "AI default" sameness: pick fonts deliberately to match brand (see distinctive-frontend-design-for-agents).

### Tailwind v4 tokens
```css
@theme inline {
  --font-sans: var(--font-geist-sans), ui-sans-serif, system-ui, sans-serif;
  --font-mono: var(--font-geist-mono), ui-monospace, monospace;
}
@theme {
  --text-heading-lg: 1.5rem; --text-heading-lg--line-height: 1.25; --text-heading-lg--letter-spacing: -0.01em; --text-heading-lg--font-weight: 600;
  --text-body: 1rem; --text-body--line-height: 1.6;
  --text-label: 0.875rem; --text-label--line-height: 1.3; --text-label--font-weight: 500;
}
```
Usage: `className="text-heading-lg"` applies size, line-height, tracking and weight together.

## Recommended Workflow
1. Pick families (check licensing, language support, variable axes).
2. Choose base size and scale ratio per product type; define roles with design.
3. Load fonts via `next/font` with CSS variables; map to tokens.
4. Implement roles as tokens/utilities; set body defaults in the base layer.
5. Build a type specimen page/story (all roles, light/dark, narrow/wide).
6. Style prose separately (scoped) for MDX/CMS.
7. Test zoom 200%, text-spacing bookmarklet, long words, localization (German, Finnish), and RTL.

## Patterns
**Base typography layer**
```css
@layer base {
  html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
  body { font-family: var(--font-sans); font-size: var(--text-body); line-height: 1.6; font-optical-sizing: auto; }
  h1, h2, h3, h4 { line-height: 1.2; text-wrap: balance; }
  p, li, dd { text-wrap: pretty; }
  p, li { max-inline-size: 70ch; }
  code, kbd, samp, pre { font-family: var(--font-mono); font-size: .875em; }
  table, [data-numeric] { font-variant-numeric: tabular-nums; }
  :is(h1, h2, h3, p) { overflow-wrap: break-word; }
}
```

**Text component with role variants**
```tsx
import { cva, type VariantProps } from "class-variance-authority";
const text = cva("", {
  variants: {
    role: { "heading-xl": "text-heading-xl", "heading-lg": "text-heading-lg", body: "text-body", label: "text-label", caption: "text-caption text-muted" },
    tone: { default: "text-fg", muted: "text-muted", danger: "text-danger" },
  },
  defaultVariants: { role: "body", tone: "default" },
});
type TextProps<T extends React.ElementType> = { as?: T } & VariantProps<typeof text> & React.ComponentPropsWithoutRef<T>;
export function Text<T extends React.ElementType = "p">({ as, role, tone, className, ...p }: TextProps<T>) {
  const Comp = as ?? "p";
  return <Comp className={text({ role, tone, className })} {...p} />;
}
```
Separate visual role from semantic element: `<Text as="h2" role="heading-md">`.

**Optical centering in buttons (enhancement)**
```css
.button-label { text-box: trim-both cap alphabetic; }
```

## Anti-Patterns
- **Arbitrary sizes (`text-[15px]`, `font-size: 13.5px`).** Inconsistent. Use roles/tokens.
- **Heading level chosen for size.** Breaks document outline (WCAG 1.3.1). Pick the element semantically, style with a role.
- **`line-height: 1` on multiline text.** Clipped descenders, unreadable. Use roles.
- **Full-width paragraphs on desktop (150+ chars).** Poor readability. Cap measure.
- **Loading 6 static weights from Google Fonts CDN.** Slow, privacy leak, CLS. Use `next/font` variable fonts.
- **Light grey small text (`#999` on white).** Fails contrast. Use muted tokens that pass 4.5:1.
- **All caps for long text or ultra-thin weights for body.** Reduced legibility.
- **`px` font sizes on `html`.** Overrides user preference. Leave the root alone; use rem.
- **Justified text without hyphenation.** Rivers of whitespace. Use `text-align: start`, or `hyphens: auto` with `lang` set.

## Accessibility
- WCAG 1.4.3 contrast: 4.5:1 body, 3:1 for large text (≥24px regular or ≥18.66px bold).
- WCAG 1.4.4 resize text to 200%; 1.4.12 text spacing (line-height 1.5, paragraph spacing 2em, letter 0.12em, word 0.16em) must not break layout. Avoid fixed heights and `overflow: hidden` on text containers.
- WCAG 1.3.1: headings are semantic elements in order; don't skip levels for styling.
- Set `lang` on `<html>` (Next.js root layout) for correct hyphenation, screen reader pronunciation, and font selection.
- Avoid text in images; if unavoidable, provide equivalent text.
- Consider dyslexia-friendly defaults: sufficient line-height, left-aligned, no italics for long passages.

## Responsive Design
- Keep body size stable (1rem–1.125rem). Scale headings fluidly with `clamp()` tokens.
- Use container-relative sizing for components (`cqi`) mixed with rem.
- Reduce tracking/size of display text on narrow screens; balance headings to avoid orphans.
- Ensure long words/URLs wrap (`overflow-wrap: anywhere` for user content).

## Performance
- `next/font` self-hosts, subsets, and preloads fonts. It also generates fallback `@font-face` with `size-adjust`/`ascent-override` to reduce CLS.
- Use variable fonts (one file for all weights). Subset to needed scripts (`subsets: ["latin"]`).
- `display: "swap"` (default in next/font) avoids invisible text. Metric-matched fallback limits shift.
- Only preload fonts used above the fold; set `preload: false` for secondary fonts (e.g. mono used deep in docs).

## Security
- Self-hosting (next/font) avoids third-party requests and IP leakage to font CDNs (a GDPR concern established in German court rulings on Google Fonts).
- Check font licenses (OFL is fine; commercial fonts often restrict web embedding/self-hosting).

## Testing
- Storybook type specimen with visual regression in both themes.
- Playwright: assert no CLS from fonts (Lighthouse CI CLS budget), check `document.fonts.status === "loaded"` before screenshots.
- Text-spacing bookmarklet and 200% zoom manual checks; axe for contrast.
- Pseudo-localization (longer strings) to check wrapping.

## Tooling
- `next/font` (google/local). Official, Next.js.
- Fontsource (`@fontsource-variable/*`). Self-hosted npm fonts for Vite SPAs. Active.
- `@tailwindcss/typography`. Official prose styles (v4 via `@plugin`).
- Capsize. Community; leading-trim math (native `text-box` emerging).
- Wakamai Fondue. Inspect font axes/features. Community.
- Utopia type calculator for scales.

## Framework Notes
- **Next.js App Router:** declare fonts in a module (e.g. `app/fonts.ts`) and apply `font.variable` classes on `<html>` in `app/layout.tsx`. Local brand fonts via `next/font/local` with `src` array for multiple files or one variable file, plus `declarations` for `font-feature-settings` if needed. Use `adjustFontFallback` (default on) to reduce CLS. Set `lang` on `<html>`, and dynamic `lang` in `[locale]` layouts for i18n.
- **React (Vite SPA):** use Fontsource variable packages imported in `main.tsx`, or self-host with `@font-face` + `font-display: swap` + `size-adjust` fallback overrides (tools like fontaine/`@capsizecss/unpack` generate these). Preload the primary WOFF2 in `index.html`.
- **MDX:** map heading/paragraph components to roles in `mdx-components.tsx`; or wrap in `prose` with `@tailwindcss/typography`.

## AI Agent Guidance
- Do use existing text roles/tokens; never introduce arbitrary px sizes.
- Do load fonts with `next/font` (Next.js) or Fontsource/self-hosting (Vite), never a Google Fonts `<link>` in Next.js.
- Do keep semantic heading order independent of visual size.
- Do apply `tabular-nums` to numeric columns and stats.
- Don't set root font size or use viewport-only font sizes.
- Before done: check type specimen at 360px and 1440px, 200% zoom, dark mode contrast, no font-related CLS.

## Examples
```tsx
// app/fonts.ts
import { Geist, Geist_Mono } from "next/font/google";
import localFont from "next/font/local";

export const sans = Geist({ subsets: ["latin"], variable: "--font-geist-sans" });
export const mono = Geist_Mono({ subsets: ["latin"], variable: "--font-geist-mono", preload: false });
export const display = localFont({ src: "./fonts/BrandDisplay-Variable.woff2", variable: "--font-display", weight: "400 800" });
```
```tsx
// app/layout.tsx
import { sans, mono, display } from "./fonts";
import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable} ${display.variable}`}>
      <body className="font-sans text-body text-fg antialiased">{children}</body>
    </html>
  );
}
```
```tsx
// app/pricing/PriceTable.tsx
export function PriceCell({ amount }: { amount: number }) {
  return (
    <td className="text-end font-mono tabular-nums">
      {new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(amount)}
    </td>
  );
}
```

## Related Skills
- [fluid-typography-and-spacing](../fluid-typography-and-spacing/Skill.md) — fluid scale math
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — next/font details
- [font-loading-performance](../font-loading-performance/Skill.md) — loading strategy and CLS
- [visual-hierarchy-and-layout](../visual-hierarchy-and-layout/Skill.md) — typographic hierarchy in design
- [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md) — avoiding generic font choices
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md) — text contrast
- [css-nesting-and-scope](../css-nesting-and-scope/Skill.md) — scoped prose styles

## Sources
- [Next.js — Font optimization (v16.3 docs)](https://nextjs.org/docs/app/getting-started/fonts) — Official — next/font google/local usage
- [Next.js — Font API reference](https://nextjs.org/docs/app/api-reference/components/font) — Official — variable, adjustFontFallback, preload
- [Tailwind CSS — Theme variables (--text-* sub-properties)](https://tailwindcss.com/docs/theme) — Official — text tokens with line-height
- [MDN — text-wrap](https://developer.mozilla.org/en-US/docs/Web/CSS/text-wrap) — Official — balance/pretty
- [MDN — font-variant-numeric](https://developer.mozilla.org/en-US/docs/Web/CSS/font-variant-numeric) — Official — tabular nums
- [web.dev — Baseline 2026](https://web.dev/baseline/2026) — Official — text-indent hanging/each-line, rcap/rch units
- [Josh W. Comeau — CSS reset](https://www.joshwcomeau.com/css/custom-css-reset/) — Community — text defaults rationale
- [W3C — WCAG 2.2 Understanding 1.4.12 Text Spacing](https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html) — Official — spacing requirements

## License / Usage Notes
Next.js docs are MIT and MDN is CC-BY-SA. Font licenses vary: verify OFL or commercial terms before self-hosting. Content is summarized, and code is original.

## Quality Tier
A — Official Next.js/Tailwind/MDN grounding plus established typographic practice. Role values are recommendations to tune per brand.

## Status
Active

## Last Verified
2026-09-15
