# Color Contrast and Non-Color Cues

## Summary
Ensuring text, UI components, focus indicators and graphics have sufficient contrast (WCAG 1.4.3, 1.4.6, 1.4.11), and that information is never conveyed by color alone (1.4.1). Applied to React/Next.js design tokens, Tailwind themes, dark mode and data visualisation. Low-contrast text has been the #1 detected error in every WebAIM Million report, affecting 83.9% of home pages in 2026.

## Category
Accessibility

## Subcategories
Contrast ratio, large text, non-text contrast, focus indicator contrast, use of color, links in text, dark mode contrast, APCA, prefers-contrast, token validation

## Problem It Solves
Pale gray text, light placeholder text, low-contrast input borders, color-only error states, and red/green status badges exclude people with low vision, color vision deficiency (about 1 in 12 men), aging eyes, and anyone on a phone in sunlight.

## When To Use
- Defining color tokens and themes (light, dark, brand).
- Designing states: hover, focus, disabled, error, success, selected.
- Links in body text, charts, status badges, form field borders.
- Reviewing designs before handoff.

## When Not To Use
- Logotypes and incidental text (inactive/disabled controls, pure decoration, text in photos that isn't significant) are exempt from 1.4.3, but still consider legibility.
- Don't substitute APCA for WCAG 2 ratios for compliance. APCA is not part of any normative standard.

## Core Principles
1. **Text contrast (1.4.3 AA):** 4.5:1 for normal text; 3:1 for large text (at least 24px regular, or at least 18.66px bold).
2. **Enhanced (1.4.6 AAA):** 7:1 normal, 4.5:1 large.
3. **Non-text contrast (1.4.11 AA):** 3:1 for the visual information required to identify UI components and states (input borders if they're the only affordance, checkbox outlines, focus rings, icons conveying meaning) and meaningful graphic parts (chart lines and segments).
4. **Use of color (1.4.1 A):** color can't be the only way to convey information, indicate an action, prompt a response, or distinguish an element.
5. **No rounding up.** 4.49:1 fails.
6. **Test real rendered pairs,** including text over images and gradients, at all states and themes.

## Best Practices
- Build contrast into tokens. Define semantic pairs (`--text-default` on `--surface-default`) and validate every pair in CI.
- Minimum practical grays on white: `#767676` (4.54:1) for body text; on `#000`/near-black surfaces use at least `#8a8a8a`-ish. Always verify.
- Placeholder text must meet 4.5:1 if it conveys information. Better: don't put information in placeholders.
- Links within body text: underline them (recommended). If not underlined, you need 3:1 contrast against the surrounding text plus a non-color cue on hover and focus (WCAG technique G183). Underlines are simpler.
- Error and success states: color plus icon plus text ("Error: …").
- Charts: distinguish series with shape, pattern, direct labels or dash styles, not just hue. Provide a data table.
- Selected states (tabs, chips, calendar days): add weight, underline, check icon or border in addition to color.
- Focus rings: 3:1 against adjacent colors. A two-tone ring (outline plus offset or inner shadow) works on any background.
- Disabled controls are exempt, but "looks disabled but isn't" (low-contrast active controls) fails.
- Dark mode: re-validate every pair, since brand colors that pass on white often fail on dark surfaces. Avoid pure `#fff` on `#000` for long reading (halation); `#e6e6e6` on `#121212` is comfortable.
- Respect `prefers-contrast: more` (boost borders and text) and `forced-colors: active` (use system colors).

## Implementation Guidance

### Contrast ratio math (WCAG 2)
- Relative luminance `L = 0.2126 R + 0.7152 G + 0.0722 B`, where each channel is linearised: `c <= 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4`.
- Ratio = `(L1 + 0.05) / (L2 + 0.05)`, with L1 the lighter.

```ts
// scripts/contrast.ts
export function hexToRgb(hex: string): [number, number, number] {
  const n = parseInt(hex.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function lum([r, g, b]: [number, number, number]) {
  const f = (v: number) => { const c = v / 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; };
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}
export function contrast(a: string, b: string) {
  const [l1, l2] = [lum(hexToRgb(a)), lum(hexToRgb(b))].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
}
```

### Token pair validation in CI (Vitest)
```ts
// tokens.contrast.test.ts
import { contrast } from './scripts/contrast';
import { themes } from './tokens'; // { light: {...}, dark: {...} } resolved to hex

const pairs: [fg: string, bg: string, min: number][] = [
  ['text.default', 'surface.default', 4.5],
  ['text.muted', 'surface.default', 4.5],
  ['text.onPrimary', 'primary.default', 4.5],
  ['border.input', 'surface.default', 3],
  ['focus.ring', 'surface.default', 3],
  ['status.error', 'surface.default', 4.5],
];

for (const [name, t] of Object.entries(themes)) {
  test.each(pairs)(`${name}: %s on %s ≥ %d`, (fg, bg, min) => {
    expect(contrast(t[fg], t[bg])).toBeGreaterThanOrEqual(min);
  });
}
```
Tailwind v4 defines colors in OKLCH. Resolve to sRGB (e.g., with `culori`) before computing WCAG ratios, and clamp out-of-gamut values the way browsers do.

### Decision table: what needs 3:1 non-text contrast
| Element | Needs 3:1? |
|---|---|
| Text input border when it's the only indicator of the field | Yes |
| Input with a filled background distinguishable from the page | The background edge (or border) must be 3:1 |
| Button with a text label but no border/background | No (the text provides identification) |
| Checkbox or radio outline | Yes |
| Focus indicator | Yes (and 2.4.13 AAA recommends a 3:1 change of state) |
| Icon-only button glyph | Yes |
| Decorative icon next to text | No |
| Chart line or bar that conveys data | Yes (against adjacent colors), or has labels/patterns |
| Disabled control | No |

### APCA / WCAG 3 status (Sept 2026)
- APCA (Accessible Perceptual Contrast Algorithm) was removed from the WCAG 3 drafts in 2023. The March 2026 WCAG 3 draft states the contrast algorithm is undetermined.
- Chrome DevTools can show APCA experimentally. Use it as a secondary readability signal, and always also pass WCAG 2 ratios.

### CSS helpers
```css
@media (prefers-contrast: more) {
  :root { --text-muted: var(--text-default); --border-input: #3d3d3d; }
}
@media (forced-colors: active) {
  .badge { border: 1px solid CanvasText; }        /* backgrounds are overridden; keep a boundary */
  .icon  { forced-color-adjust: auto; fill: currentColor; }
}
/* contrast-color() picks black or white for a background: limited availability; doesn't guarantee 4.5:1 for mid-tones */
```

## Recommended Workflow
1. Define semantic color tokens with explicit fg/bg pairs per theme.
2. Validate the pairs in a unit test (above), and fail CI on regressions.
3. In design review, check every state (default/hover/focus/active/selected/error/disabled) in light, dark and high-contrast.
4. Audit for color-only meaning: links in text, errors, statuses, charts, required markers, selected items.
5. Run axe `color-contrast` in a real browser (Playwright). It doesn't run in jsdom.
6. Manually check text over images/gradients, focus rings, and non-text elements (axe doesn't check 1.4.11).
7. Simulate color vision deficiencies (Chrome DevTools Rendering > Emulate vision deficiencies) and grayscale.

## Patterns
- **Status badge.** Icon, text and color: `<span className="badge badge-error"><AlertIcon aria-hidden="true" /> Failed</span>`.
- **Inline link.** `a { text-decoration: underline; text-underline-offset: .15em }`; hover changes thickness.
- **Text over image.** A scrim gradient (`linear-gradient(rgb(0 0 0 / .6), transparent)`) or a solid text panel. Test the worst-case pixel.
- **Two-tone focus ring.** `outline: 2px solid #fff; box-shadow: 0 0 0 4px #1a5fb4;`. Box-shadow disappears in forced colors, where the outline remains.
- **Chart series.** Distinct markers and dash patterns, direct labels, and a table fallback.

## Anti-Patterns
- **Gray-on-gray "muted" text below 4.5:1.** Most common failure. Darken the token.
- **Brand color as body text or button text that fails.** Create an accessible shade (e.g., `primary-700` for text) and reserve the brand tint for large or decorative use.
- **Red/green only** for pass/fail, diff views or trends. Add icons, labels or +/- signs.
- **Links distinguished only by color** in paragraphs. Underline them.
- **Input borders at 1.5:1** (e.g., `#e5e7eb` on white) as the only field boundary. Use a 3:1 border (e.g., `#8c8c8c` on white) or a filled background with a 3:1 edge.
- **Relying on axe alone.** It doesn't evaluate non-text contrast, images, pseudo-elements, or complex backgrounds reliably ("needs review" results). Verify manually.
- **APCA-only palettes that fail WCAG 2.** Legal and audit risk.
- **Opacity-based text colors** (`text-black/50`) over variable backgrounds. Contrast becomes unpredictable. Use solid tokens.

## Accessibility
- 1.4.1 Use of Color (A), 1.4.3 Contrast Minimum (AA), 1.4.6 Contrast Enhanced (AAA), 1.4.11 Non-text Contrast (AA), 2.4.7 Focus Visible (AA), 2.4.13 Focus Appearance (AAA), 1.3.3 Sensory Characteristics (A: don't say "click the green button").

## Responsive Design
- Large-text thresholds are CSS px at 100% zoom; fluid type that shrinks below 24px on mobile loses the 3:1 allowance. Validate at the smallest size.
- Outdoor mobile use argues for AAA-level contrast on key content.
- Images with overlaid text crop differently per breakpoint, so recheck contrast on each crop.

## Performance
- Token-based colors have no runtime cost. Avoid runtime contrast calculation in render paths; compute at build time.

## Security
- None specific. Don't encode security-critical warnings (phishing, destructive actions) with color alone.

## Testing
```ts
// e2e/contrast.spec.ts
import AxeBuilder from '@axe-core/playwright';
test('no contrast violations in dark mode', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('/');
  const r = await new AxeBuilder({ page }).withRules(['color-contrast', 'link-in-text-block']).analyze();
  expect(r.violations).toEqual([]);
});
```
- Also run with `forcedColors: 'active'` and `contrast: 'more'` emulation (`page.emulateMedia({ forcedColors: 'active' })`) and screenshot-review.
- Manual: TPGi Colour Contrast Analyser eyedropper for non-text and image cases; Chrome DevTools color picker contrast line; grayscale check.

## Tooling
- TPGi Colour Contrast Analyser (free desktop), WebAIM Contrast Checker, Chrome DevTools (AA/AAA lines, experimental APCA), Polypane, Stark (Figma).
- axe-core `color-contrast`, `color-contrast-enhanced` (AAA, disabled by default), `link-in-text-block`.
- culori / colorjs.io for OKLCH to sRGB conversion and ratio computation in token pipelines.
- Leonardo (Adobe) for generating contrast-targeted palettes.

## Framework Notes
- **Next.js / React.**
  - Theme via CSS variables set on `<html data-theme>`. Avoid a flash of incorrect theme (next-themes injects a script) that briefly shows failing contrast.
  - Tailwind v4 `@theme` tokens: validate semantic tokens, not raw palette steps.
  - shadcn/ui's default `muted-foreground` on `muted` backgrounds: verify per theme after customisation.
- **Charts (Recharts, visx).** Pass `strokeDasharray` and markers per series and render a visually hidden table or a "View data" toggle.

## AI Agent Guidance
- Do: use semantic tokens with validated pairs; underline inline links; pair color with icon and text for status and errors.
- Do: compute and state contrast ratios for any new color pair you introduce, for both light and dark themes.
- Don't: introduce gray text lighter than ~4.5:1, borders under 3:1 as the sole affordance, color-only states, or opacity-based text colors on variable backgrounds.
- Don't: justify failing colors with APCA.
- Verify before done:
  - axe `color-contrast` in a real browser for light and dark
  - manual non-text contrast check of borders, icons and focus
  - grayscale review for color-only meaning

## Examples
```tsx
// Accessible status indicator
const statusMap = {
  success: { icon: CheckCircleIcon, label: 'Passed', cls: 'text-green-800 bg-green-50 border-green-700' },
  error:   { icon: XCircleIcon,     label: 'Failed', cls: 'text-red-800 bg-red-50 border-red-700' },
  pending: { icon: ClockIcon,       label: 'Pending', cls: 'text-slate-800 bg-slate-50 border-slate-600' },
} as const;

export function StatusBadge({ status }: { status: keyof typeof statusMap }) {
  const { icon: Icon, label, cls } = statusMap[status];
  return (
    <span className={`inline-flex items-center gap-1 rounded border px-2 py-0.5 text-sm ${cls}`}>
      <Icon aria-hidden="true" className="size-4" /> {label}
    </span>
  );
}
```

## Related Skills
- [color-systems](../color-systems/Skill.md) — palette and token construction
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — theme switching
- [design-token-architecture](../design-token-architecture/Skill.md) — semantic tokens
- [forced-colors-and-high-contrast](../forced-colors-and-high-contrast/Skill.md) — Windows high contrast support
- [accessible-data-visualization](../accessible-data-visualization/Skill.md) — non-color encodings in charts
- [focus-management](../focus-management/Skill.md) — focus indicator styling
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — overall conformance

## Sources
- [Understanding 1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) — Official — ratios, large text, exemptions
- [Understanding 1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) — Official — UI component and graphics requirements
- [Understanding 1.4.1 Use of Color](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html) — Official — links in text (G183)
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — 83.9% low contrast
- [Adrian Roselli: WCAG3 Contrast as of April 2026](https://adrianroselli.com/2026/04/wcag3-contrast-as-of-april-2026.html) — Community — APCA/WCAG 3 status and risk advice
- [MDN: forced-colors](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors) — Official (MDN) — system color overrides
- [axe-core rules](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md) — Open Source — color-contrast limitations (no jsdom)

## License / Usage Notes
Summarised from W3C, MDN and practitioner articles. The contrast formula is from WCAG (W3C Document License). Code is original.

## Quality Tier
S — normative ratios, current WCAG 3/APCA status, CI-enforceable token validation.

## Status
Active

## Last Verified
2026-09-15
