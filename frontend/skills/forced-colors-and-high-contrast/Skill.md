# Forced Colors and High Contrast

## Summary
Supporting Windows Contrast Themes (forced colors mode) and the `prefers-contrast` user preference in React/Next.js apps. In forced colors mode the browser replaces author colors with a small user-chosen system palette, removes box-shadows and background images, and breaks UIs that rely on color, shadows or backgrounds to show boundaries, focus, icons or state. This skill covers `@media (forced-colors: active)`, CSS system colors, `forced-color-adjust`, SVG icons, and testing.

## Category
Accessibility

## Subcategories
forced-colors, Windows Contrast Themes, prefers-contrast, CSS system colors, forced-color-adjust, SVG currentColor, focus indicators, Tailwind forced-colors variant

## Problem It Solves
Low-vision and light-sensitive users (and people with migraines or dyslexia) often use high-contrast themes. In forced colors mode:
- buttons styled only with background color lose their boundaries
- custom checkboxes and toggles vanish
- `box-shadow` focus rings disappear
- selected tabs become indistinguishable
- SVG icons with hard-coded fills may become invisible

These are WCAG failures (1.4.11, 2.4.7, 1.4.1) for those users.

## When To Use
- Design-system components: buttons, inputs, checkboxes, switches, tabs, badges, cards, focus styles, icons, charts.
- Any custom-styled control that replaces a native one.
- Reviewing Tailwind `ring-*`/`shadow-*` focus styles.

## When Not To Use
- Don't build a separate "high contrast theme" as a substitute for supporting forced colors. Users' OS themes should drive it.
- Don't blanket `forced-color-adjust: none`. It opts out of the user's needs.

## Core Principles
1. **Let the browser do most of the work.** Semantic HTML and real borders and outlines survive forced colors.
2. **Boundaries must be borders or outlines, not backgrounds or shadows.** Add `border: 1px solid transparent`; transparent borders become visible in forced colors.
3. **Focus indicators use `outline`**, which stays and adopts system colors, not `box-shadow`.
4. **Use CSS system colors in forced-colors tweaks:** `Canvas`, `CanvasText`, `LinkText`, `ButtonFace`, `ButtonText`, `ButtonBorder`, `Highlight`, `HighlightText`, `GrayText`, `AccentColor`, `AccentColorText`, `Field`, `FieldText`, `SelectedItem`, `SelectedItemText`, `Mark`, `MarkText`, `VisitedText`.
5. **Icons inherit `currentColor`.**
6. **Small tweaks, not redesigns.** Target specific broken states.
7. **Only use `forced-color-adjust: none` where the author color is the content** (color swatches, charts' legend keys with pattern alternatives, brand logos), and scope it tightly.

## Best Practices
- Properties overridden in forced colors: `color`, `background-color`, `border-color`, `outline-color`, `text-decoration-color`, `column-rule-color`, `-webkit-tap-highlight-color`, SVG `fill`/`stroke`; `scrollbar-color` becomes `auto`. `box-shadow` and `text-shadow` are forced to `none`; `background-image` is removed except `url()` images; `color-scheme` becomes `light dark`.
- Selected and active states (tabs, nav items, listbox options) need a non-color indicator: underline, border, bold weight, or `Highlight`/`SelectedItem` background inside the forced-colors query.
- Disabled state: use `GrayText` for text and borders in forced colors.
- Custom checkboxes and switches: prefer native `accent-color` inputs. For fully custom ones, ensure borders and checked indicators use `CanvasText`/`Highlight`.
- Links styled as buttons: keep `LinkText` or `ButtonText` semantics consistent with the element type. The UA picks colors based on native semantics, not ARIA roles, so a `div role="button"` gets text colors, not button colors.
- Text over images: browsers draw a backplate behind text for readability. Don't fight it.
- Charts: rely on patterns, markers and labels (colors collapse to a few system colors).
- `prefers-contrast: more`: strengthen borders, darken muted text, remove translucency. `prefers-contrast: custom` matches forced colors in some browsers.
- `forced-colors` media feature is Baseline widely available (since 2022). Windows Contrast Themes are the main real-world trigger (Edge, Chrome, Firefox). macOS "Increase contrast" maps to `prefers-contrast: more`, not forced colors.

## Implementation Guidance

### Base component CSS
```css
.btn {
  background: var(--primary);
  color: var(--on-primary);
  border: 1px solid transparent;          /* becomes visible (ButtonBorder/CanvasText) in forced colors */
  border-radius: .5rem;
}
.btn:focus-visible {
  outline: 3px solid var(--focus);         /* outline survives; box-shadow would disappear */
  outline-offset: 2px;
}

.card { border: 1px solid transparent; box-shadow: var(--shadow-md); } /* shadow is decoration; border is the boundary */

.tab[aria-selected="true"] { background: var(--surface-selected); }
@media (forced-colors: active) {
  .tab[aria-selected="true"] { border-block-end: 3px solid Highlight; }  /* restore non-color selected cue */
  .switch[aria-checked="true"] .thumb { background: Highlight; }
  .switch .track { border: 1px solid CanvasText; }
  .badge { border: 1px solid CanvasText; }
  [aria-disabled="true"], :disabled { color: GrayText; border-color: GrayText; }
}

@media (prefers-contrast: more) {
  :root { --text-muted: var(--text-default); --border-subtle: var(--border-strong); }
}
```

### SVG icons
```tsx
export function CheckIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} aria-hidden="true" focusable="false" {...props}>
      <path d="M5 12l5 5L20 7" />
    </svg>
  );
}
```
Hard-coded `fill="#2563eb"` may be overridden or become invisible. Use `currentColor`. For multi-color illustrations that must keep colors, wrap them in `forced-color-adjust: none` and ensure they're not essential, or have text equivalents.

### Tailwind
- Tailwind v4 includes a `forced-colors:` variant and `contrast-more:` variant: `className="border border-transparent forced-colors:border-[CanvasText] aria-selected:forced-colors:border-b-[Highlight]"`.
- Replace `focus-visible:ring-2` (box-shadow based) with, or add, `focus-visible:outline-2 focus-visible:outline-offset-2`. Ring utilities disappear in forced colors.
- The `forced-color-adjust-none` / `forced-color-adjust-auto` utilities exist; use them sparingly.

### Color swatch exception
```tsx
<button type="button" aria-label="Color: Ocean blue" aria-pressed={selected}
  className="size-8 rounded-full border border-transparent forced-colors:border-[CanvasText]">
  <span className="block size-full rounded-full" style={{ background: '#1e6fd9', forcedColorAdjust: 'none' }} />
</button>
```

## Recommended Workflow
1. Enable emulation (Chrome/Edge DevTools > Rendering > "Emulate CSS media feature forced-colors: active"), or turn on Windows Settings > Accessibility > Contrast themes (test "Night sky" dark and "Desert" light).
2. Walk the component library: every control has a visible boundary; focus is visible; selected, checked and disabled states are distinguishable; icons are visible.
3. Fix with borders and outlines first, then targeted `@media (forced-colors: active)` rules with system colors.
4. Add Playwright screenshot tests in forced colors for key components.
5. Check `prefers-contrast: more` for muted text and subtle borders.

## Patterns
- **Transparent border trick** for any surface defined by background color.
- **Outline-based focus** tokens.
- **currentColor icons.**
- **Selected-state indicator** (border or underline) inside the forced-colors query.
- **Scoped `forced-color-adjust: none`** only on content-colored elements.

## Anti-Patterns
- **`box-shadow` or Tailwind `ring` as the only focus indicator.** Disappears (2.4.7 failure). Use outline.
- **Background-only buttons and inputs.** Become borderless text (1.4.11). Add a transparent border.
- **Global `forced-color-adjust: none`.** Overrides user needs. Scope it to swatches and logos.
- **Custom checkbox built from `div` background colors.** Invisible checked state. Use native inputs with `accent-color`, or system colors in the query.
- **Hard-coded SVG fills.** Invisible icons. Use `currentColor`.
- **Detecting high contrast via JS to swap a custom theme.** Unnecessary and brittle. Use CSS media queries.
- **Using `-ms-high-contrast`.** Legacy, removed. Use the standard `forced-colors`.

## Accessibility
- 1.4.11 Non-text Contrast (AA), 2.4.7 Focus Visible (AA), 2.4.13 Focus Appearance (AAA), 1.4.1 Use of Color (A), 1.4.3 Contrast (the UA handles text), 1.3.3 Sensory Characteristics.
- EN 301 549 v4.1.1 strengthens requirements to respect user preferences, so forced-colors support grows in compliance relevance.

## Responsive Design
- Forced colors applies at all breakpoints. Mobile off-canvas menus with background-only separation also need borders.
- Android and iOS don't expose `forced-colors` in the same way (iOS has "Increase contrast" as `prefers-contrast`; Android has high-contrast text). Test `prefers-contrast` there.

## Performance
- No runtime cost. CSS media queries only; avoid JS matchMedia listeners for styling.

## Security
- None specific.

## Testing
```ts
test('components remain distinguishable in forced colors', async ({ page }) => {
  await page.emulateMedia({ forcedColors: 'active', colorScheme: 'dark' });
  await page.goto('/storybook-iframe?id=components-tabs--default');
  await page.getByRole('tab', { name: 'Billing' }).focus();
  await expect(page).toHaveScreenshot('tabs-forced-colors.png');
});
```
- Manual on Windows with real Contrast Themes in Edge and Chrome, and Firefox (which has its own "Override colors" setting).
- Review focus visibility, boundaries, states and icons per component.

## Tooling
- Chrome/Edge DevTools Rendering emulation; Playwright `emulateMedia({ forcedColors: 'active' })`.
- Windows Contrast Themes; Firefox Settings > Colors > Manage Colors (Override).
- Tailwind v4 `forced-colors:` and `contrast-more:` variants.
- Polypane (side-by-side emulations).

## Framework Notes
- **Next.js / React.**
  - Global styles in `app/globals.css` should define outline-based focus and transparent borders in base component layers.
  - CSS Modules and Tailwind both support the media query.
  - Inline `style={{ forcedColorAdjust: 'none' }}` works in React (camelCase).
  - next-themes dark/light themes don't affect forced colors; the OS palette wins.
- **Component libraries.** Radix, shadcn/ui and Headless UI styles are yours to adjust. MUI and Fluent UI include some forced-colors handling (Fluent UI extensively), but verify custom variants.

## AI Agent Guidance
- Do: use outline for focus, add transparent borders to background-defined controls, use `currentColor` for icons, and add forced-colors rules for selected, checked and disabled states.
- Don't: rely on `box-shadow`/`ring` for focus, apply `forced-color-adjust: none` broadly, or hard-code SVG fills.
- Verify before done: emulated forced colors (light and dark contrast themes) show visible boundaries, focus, states and icons for changed components; a screenshot test is added for key components.

## Examples
See Implementation Guidance (base CSS, SVG icon, Tailwind usage, swatch exception) and Testing.

## Related Skills
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md) — contrast and non-color cues
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — author themes vs user themes
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — token-based styling
- [focus-management](../focus-management/Skill.md) — focus indicator styling
- [iconography-and-illustration](../iconography-and-illustration/Skill.md) — icon color handling
- [visual-regression-testing](../visual-regression-testing/Skill.md) — screenshot tests
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — variants

## Sources
- [MDN: forced-colors media feature](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors) — Official (MDN) — overridden properties, system colors, Baseline status
- [MDN: forced-color-adjust](https://developer.mozilla.org/en-US/docs/Web/CSS/forced-color-adjust) — Official (MDN) — opt-out semantics
- [CSS Color Adjustment Module Level 1](https://www.w3.org/TR/css-color-adjust-1/) — Official — forced colors spec
- [CSS Color Module Level 4: system colors](https://www.w3.org/TR/css-color-4/#css-system-colors) — Official — system color keywords
- [Microsoft Edge blog: Styling for Windows high contrast with forced-colors](https://blogs.windows.com/msedgedev/2020/09/17/styling-for-windows-high-contrast-with-new-standards-for-forced-colors/) — Official (vendor) — practical guidance
- [Adrian Roselli / Sarah Higley / Eric Bailey on WHCM](https://adrianroselli.com/2021/02/whcm-and-system-colors.html) — Community — system color pitfalls and testing

## License / Usage Notes
Summarised from MDN (CC BY-SA), W3C specs, and vendor and practitioner articles. Code is original.

## Quality Tier
A — spec- and MDN-backed, Baseline feature, practical component fixes. System color rendering differs slightly across browsers.

## Status
Active

## Last Verified
2026-09-15
