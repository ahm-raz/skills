# Color Systems

## Summary
How to design and implement a UI color system in 2026: perceptual color spaces (OKLCH), scale construction (Radix-style 12-step functional scales, Material 3 tonal palettes/roles, Adobe Leonardo contrast-targeted generation), semantic roles, dark mode, and contrast. Contrast is WCAG 2.2 as the legal baseline, with APCA as an informative design aid only. Also covers CSS implementation with `oklch()`, `color-mix()`, relative color syntax, `contrast-color()`, and wide-gamut P3.

## Category
CSS & Styling

## Subcategories
OKLCH, color scales, semantic color roles, Radix Colors, Material 3 color roles, Adobe Leonardo, contrast (WCAG 2.2, APCA), P3 gamut, color-mix, relative colors, contrast-color(), data-vis palettes, state colors

## Problem It Solves
HSL-based palettes have uneven perceived lightness: yellow-500 looks far lighter than blue-500, so the same step gives unpredictable contrast. Ad-hoc hex values drift, dark mode is bolted on, and contrast failures ship. A systematic palette makes every step purposeful and every pairing predictable.

## When To Use
- Creating brand/product palettes and semantic tokens.
- Adding dark mode or high-contrast themes.
- Auditing contrast failures or inconsistent grays.
- Generating hover/active/subtle variants in CSS.

## When Not To Use
- Data visualization palettes (categorical/sequential/diverging) need specialized rules. See data-visualization-principles and accessible-data-visualization (principles here still apply).
- Runtime theme-switching mechanics. See theming-with-css-variables.

## Core Principles
1. **Use OKLCH for authoring.** L (perceived lightness 0–1 or 0–100%), C (chroma), H (hue). Equal L means similar perceived lightness across hues, which makes contrast predictable.
2. **Scales have jobs.** Each step has an intended use (background, hover, border, solid, text), so pairings are known in advance (Radix model).
3. **Semantic roles over raw scales.** Components use `accent`, `on-accent`, `surface`, `border`, `danger`, etc. (Material 3 model), mapped to scale steps per theme.
4. **Contrast is designed in.** Generate steps from target contrast ratios (Leonardo model) or verify every role pair.
5. **WCAG 2.2 is the compliance baseline.** 4.5:1 normal text, 3:1 large text and non-text UI. APCA was removed from WCAG 3 drafts in 2023 and is not normative, so use it only as a supplemental readability check.
6. **Never rely on color alone** to convey meaning (WCAG 1.4.1).
7. **Stay in gamut.** High-chroma OKLCH values can exceed sRGB. Browsers gamut-map, but design with `@media (color-gamut: p3)` enhancements intentionally.

## Best Practices
- Build neutrals with a slight hue tint matching the brand (chroma 0.005–0.02) for cohesion (Radix: slate/mauve/sage/olive/sand pair with specific accents).
- Keep per-step lightness consistent across hues so `red-9`, `green-9`, `blue-9` are interchangeable in contrast.
- Per scale, provide: app background, subtle background, component bg (normal/hover/active), borders (subtle/normal/strong), solid (normal/hover), low-contrast text, high-contrast text.
- Bright accents (yellow, lime, amber, sky, mint) need dark foreground text on solid fills. Record this as the `on-*` token.
- Separate dark scales, not inversions. In dark mode, lower chroma slightly and raise lightness of solids for text contrast.
- Provide alpha variants (`color-mix(in oklch, var(--accent) 12%, transparent)`) for overlays on unknown backgrounds.
- State colors: danger (red), warning (amber/orange), success (green/teal), info (blue). Pair each with icons/text.
- Focus ring color must reach 3:1 against adjacent colors in all themes.
- Document every role with allowed pairings and contrast values.

## Implementation Guidance

### Radix-style 12-step scale roles
| Step | Use |
|---|---|
| 1 | App background |
| 2 | Subtle background (cards, striped rows) |
| 3 | UI element background (normal) |
| 4 | UI element background (hover) |
| 5 | UI element background (active/selected) |
| 6 | Subtle borders, separators (non-interactive) |
| 7 | UI element border, focus rings |
| 8 | Hovered border, stronger focus |
| 9 | Solid backgrounds (highest chroma; buttons, badges) |
| 10 | Hovered solid |
| 11 | Low-contrast text (Radix targets APCA Lc 60 on step 2) |
| 12 | High-contrast text (APCA Lc 90 on step 2) |

### Material 3 role model (names to borrow)
`primary / on-primary / primary-container / on-primary-container`, same for `secondary`, `tertiary`, `error`; `surface`, `on-surface`, `on-surface-variant`, `surface-container-lowest … highest`, `outline`, `outline-variant`, `inverse-surface`, `inverse-on-surface`. Tones come from HCT tonal palettes (0–100); dynamic color derives schemes from a seed color (`@material/material-color-utilities`).

### Leonardo model
Specify a key color plus target contrast ratios against a background (e.g. `[1.1, 1.3, 2, 3, 4.5, 7, 11]`). Leonardo solves the lightness for each ratio, and changing the background lightness regenerates the whole theme (adaptive dark mode). Use `@adobe/leonardo-contrast-colors` in build scripts.

### Decision table
| Situation | Approach |
|---|---|
| Product UI, fast start | Radix Colors scales (npm `@radix-ui/colors`, CSS files incl. dark and alpha, P3 variants) |
| Brand-specific palette with compliance targets | Leonardo contrast-ratio generation → tokens |
| Android/Material-aligned or seed-color theming | Material 3 roles + material-color-utilities |
| Tailwind project | Tailwind's oklch palette (incl. mauve/olive/mist/taupe in 4.2) mapped to semantic tokens |
| User-picked accent | Relative color syntax to derive steps + `contrast-color()`/precomputed on-color with lightness clamps |

### CSS building blocks
```css
:root {
  --accent-9:  oklch(56% 0.16 262);
  --accent-10: oklch(from var(--accent-9) calc(l - 0.04) c h);
  --accent-3:  oklch(from var(--accent-9) 95% calc(c * 0.25) h);
  --accent-a3: oklch(from var(--accent-9) l c h / 0.12);
  --accent-11: oklch(from var(--accent-9) 45% calc(c * 0.9) h);
  --on-accent: white;
}
/* contrast-color(): Baseline Newly available Apr 2026; black/white only */
@supports (color: contrast-color(red)) {
  .badge { color: contrast-color(var(--badge-bg)); }
}
/* Wide gamut enhancement */
@media (color-gamut: p3) {
  :root { --accent-9: oklch(56% 0.2 262); }
}
```

### Contrast rules (WCAG 2.2)
| Content | Minimum (AA) | Enhanced (AAA) |
|---|---|---|
| Body text (<24px regular, <18.66px bold) | 4.5:1 | 7:1 |
| Large text | 3:1 | 4.5:1 |
| UI component boundaries, icons, focus indicators, chart marks (1.4.11) | 3:1 | none |
| Disabled controls, logos, decorative | exempt | exempt |

## Recommended Workflow
1. Choose brand key colors (primary, optionally secondary) and a tinted neutral.
2. Generate scales (Radix-compatible 12 steps or Leonardo ratios) for neutral, accent, and state colors in light and dark.
3. Map semantic roles per theme; define `on-*` pairs.
4. Compute WCAG 2 contrast for every documented pair; fix failures by moving lightness, not hue.
5. Implement as CSS variables in oklch with hex/sRGB fallbacks only if old browsers matter.
6. Build a palette/roles page in Storybook; visual-regress it.
7. Add CI contrast tests for token pairs.

## Patterns
**Semantic roles mapped from scales**
```css
:root {
  --color-bg: var(--gray-1); --color-surface: var(--gray-2);
  --color-control: var(--gray-3); --color-control-hover: var(--gray-4);
  --color-border-subtle: var(--gray-6); --color-border: var(--gray-7);
  --color-accent: var(--blue-9); --color-accent-hover: var(--blue-10); --color-on-accent: white;
  --color-text-muted: var(--gray-11); --color-text: var(--gray-12);
  --color-danger: var(--red-9); --color-danger-text: var(--red-11); --color-danger-subtle: var(--red-3);
}
```

**Status message never color-only**
```tsx
<p role="alert" className="flex items-center gap-2 rounded-md bg-danger-subtle px-3 py-2 text-danger-text">
  <AlertIcon aria-hidden className="size-4" /> <strong>Error:</strong> Payment failed.
</p>
```

**Contrast check script (CI)**
```ts
import Color from "colorjs.io";
const pairs: [string, string, number][] = [
  ["oklch(21% .02 260)", "oklch(99% 0 0)", 4.5],
  ["oklch(99% 0 0)", "oklch(56% .16 262)", 4.5],
];
for (const [fg, bg, min] of pairs) {
  const ratio = new Color(fg).contrast(new Color(bg), "WCAG21");
  if (ratio < min) throw new Error(`${fg} on ${bg} = ${ratio.toFixed(2)} < ${min}`);
}
```

## Anti-Patterns
- **HSL lightness steps (`hsl(h s 50%)`) across hues.** Uneven perceived lightness breaks contrast. Use OKLCH.
- **Sass `darken($c, 10%)` for hovers.** Muddy, hue-shifting results. Use `oklch(from …)` or `color-mix(in oklch, …)`.
- **Mid-gray text on tinted backgrounds without checking.** Contrast failures. Use scale text steps (11/12) and verify.
- **Inverting light palette for dark mode.** Glaring solids, low-contrast borders. Build dark scales.
- **Treating APCA as compliance.** Not normative; legal risk. Meet WCAG 2.2 ratios; use APCA optionally.
- **Relying on `contrast-color()` for brand-mid-tones.** It returns black/white only and may not hit 4.5:1 for mid-lightness backgrounds. Verify or constrain background lightness.
- **Red/green only for status or diffs.** Color-blind users can't distinguish them. Add icons/text/patterns.
- **Too many accent hues.** Visual noise. Use 1 accent + neutrals + state colors.
- **Maximum chroma everywhere.** Out-of-gamut clipping and fatigue. Moderate chroma for large areas.

## Accessibility
- WCAG 1.4.3 (text contrast), 1.4.6 (AAA), 1.4.11 (non-text contrast 3:1), 1.4.1 (use of color), 2.4.13 (focus appearance, AAA).
- Support `prefers-contrast: more` (stronger borders, steps 8/12) and `forced-colors: active` (system colors; avoid background-only distinctions).
- Test with color-vision-deficiency emulation (Chrome DevTools Rendering → Emulate vision deficiencies).
- Don't place text on busy images without a scrim that guarantees contrast.

## Responsive Design
Color is viewport-independent, but outdoor/mobile use benefits from higher contrast. Consider slightly stronger borders on small screens, and use `@media (color-gamut: p3)` / `(dynamic-range: high)` for capable displays.

## Performance
Color functions resolve at style computation, so runtime cost is negligible. Avoid thousands of derived variables. Precompute scales at build time when they don't change at runtime.

## Security
Validate user-supplied colors (parse with colorjs.io/culori and re-serialize) before writing them to CSS variables; never inject raw strings.

## Testing
- CI contrast checks on token pairs per theme (colorjs.io `contrast(…, "WCAG21")`).
- axe-core / Playwright accessibility scans (color-contrast rule) on key pages in both themes.
- Visual regression of palette pages; CVD emulation screenshots for status UIs.

## Tooling
- Radix Colors (`@radix-ui/colors`). Open source, active: 12-step light/dark/alpha/P3 scales.
- Adobe Leonardo (`@adobe/leonardo-contrast-colors`, leonardocolor.io). Open source: contrast-targeted generation.
- Material Theme Builder / `@material/material-color-utilities`. Official Google: HCT, dynamic color.
- oklch.com (Evil Martians) picker; Huetone; Atmos. Community palette tools.
- colorjs.io / culori. Color math and contrast libraries.
- APCA calculator (apcacontrast.com). Informative only.
- Tailwind v4 default oklch palette. Official.

## Framework Notes
- **Next.js App Router:** define palette/roles in `app/globals.css` (Tailwind `@theme` + `:root`/`.dark`). Colors are static CSS, so there's no client cost. For tenant or user colors, validate on the server and render variables on `<html>` in the layout. Chart libraries (Recharts etc., client components) should read CSS variables (`var(--color-accent)` works directly as SVG `fill`/`stroke` values in most chart libs).
- **React (Vite SPA):** import Radix Colors CSS files (`@radix-ui/colors/blue.css`, `blue-dark.css`) or your generated tokens in `main.tsx`; toggle `.dark` on `<html>`.
- **shadcn/ui:** uses oklch semantic variables (`--primary`, `--primary-foreground`, `--muted`, `--destructive`). Adapt generated palettes into those names.

## AI Agent Guidance
- Do use existing semantic color tokens; if adding colors, add scale steps and roles, not one-off hex values.
- Do author new colors in `oklch()`; derive states with relative color syntax or `color-mix(in oklch, …)`.
- Do verify WCAG 2.2 contrast for any new text/background or UI/boundary pair in light and dark.
- Don't convey status by color alone; don't claim APCA compliance as WCAG compliance.
- Don't use pure `#000`/`#fff` for large dark-mode surfaces/text.
- Before done: run a contrast check (script or axe), view in both themes, and emulate deuteranopia for status UI.

## Examples
```css
/* app/globals.css — Tailwind v4 semantic mapping using Radix-like steps in oklch */
@import "tailwindcss";
@custom-variant dark (&:where(.dark, .dark *));

:root {
  --gray-1: oklch(99.1% .002 265); --gray-2: oklch(98% .003 265); --gray-3: oklch(95.5% .005 265);
  --gray-6: oklch(90% .008 265); --gray-7: oklch(86.5% .01 265); --gray-11: oklch(50% .015 265); --gray-12: oklch(22% .015 265);
  --blue-3: oklch(95.5% .025 255); --blue-9: oklch(58% .18 255); --blue-10: oklch(54% .18 255); --blue-11: oklch(50% .15 255);
}
.dark {
  --gray-1: oklch(17% .005 265); --gray-2: oklch(19.5% .006 265); --gray-3: oklch(23% .008 265);
  --gray-6: oklch(32% .012 265); --gray-7: oklch(37% .014 265); --gray-11: oklch(74% .012 265); --gray-12: oklch(94% .005 265);
  --blue-3: oklch(27% .06 255); --blue-9: oklch(58% .18 255); --blue-10: oklch(63% .17 255); --blue-11: oklch(78% .11 255);
}
@theme inline {
  --color-bg: var(--gray-1); --color-surface: var(--gray-2); --color-control: var(--gray-3);
  --color-border: var(--gray-6); --color-border-strong: var(--gray-7);
  --color-muted: var(--gray-11); --color-fg: var(--gray-12);
  --color-accent: var(--blue-9); --color-accent-hover: var(--blue-10); --color-accent-subtle: var(--blue-3); --color-accent-text: var(--blue-11);
  --color-on-accent: oklch(99% 0 0);
}
```
```tsx
export function PrimaryButton(props: React.ComponentProps<"button">) {
  return (
    <button
      {...props}
      className="rounded-md bg-accent px-4 py-2 text-on-accent hover:bg-accent-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:opacity-50"
    />
  );
}
```
(Values are illustrative; verify each pair with a contrast checker before shipping.)

## Related Skills
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — runtime scoping of color tokens
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — dark palettes and switching
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md) — contrast and color-independent meaning
- [design-token-architecture](../design-token-architecture/Skill.md) — token tiers and pipelines
- [data-visualization-principles](../data-visualization-principles/Skill.md) — chart palettes
- [tailwind-design-system-architecture](../tailwind-design-system-architecture/Skill.md) — semantic utilities
- [modern-css-features](../modern-css-features/Skill.md) — color function support

## Sources
- [Radix Colors — Understanding the scale](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale) — Open Source — 12-step use cases, APCA targets
- [Radix Colors — Composing a palette](https://www.radix-ui.com/colors/docs/palette-composition/composing-a-palette) — Open Source — gray pairing, semantic colors
- [Adobe Leonardo (GitHub)](https://github.com/adobe/leonardo) — Open Source — contrast-ratio generation, adaptive themes
- [Material Design 3 — Color roles](https://m3.material.io/styles/color/roles) — Official — role names, tonal palettes
- [web.dev — Color themes with Baseline CSS](https://web.dev/articles/baseline-in-action-color-theme) — Official — oklch, relative colors, color-mix
- [MDN — contrast-color()](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value/contrast-color) — Official — Baseline Apr 2026, limitations
- [Adrian Roselli — WCAG3 Contrast as of April 2026](https://adrianroselli.com/2026/04/wcag3-contrast-as-of-april-2026.html) — Community — APCA not normative
- [W3C — Understanding SC 1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) — Official — 3:1 UI contrast
- [Tailwind CSS v4.3 blog](https://tailwindcss.com/blog/tailwindcss-v4-3) — Official — new neutral palettes

## License / Usage Notes
Radix Colors and Leonardo are MIT/Apache-2.0. Material Design guidance is © Google (concepts referenced). MDN is CC-BY-SA. Palette values in examples are original and illustrative.

## Quality Tier
A — Grounded in three major official color systems and current contrast standards status. Exact palette values require per-project verification.

## Status
Active

## Last Verified
2026-09-15
