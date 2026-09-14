# Reflow, Zoom, and Text Spacing

## Summary
Build React/Next.js interfaces that still work when users zoom to 400%, raise the browser's default font size, or override text spacing. This skill covers four WCAG 2.2 AA success criteria: 1.4.4 Resize Text, 1.4.10 Reflow, 1.4.12 Text Spacing, and 1.4.13 Content on Hover or Focus. It explains how to test each one and which CSS habits break them. Use it for low-vision and zoom checks specifically. General responsive layout and WCAG program work have their own skills.

## Category
Accessibility

## Subcategories
Browser zoom, reflow at 320 CSS px, resize text 200%, text spacing overrides, hover/focus content, relative units, viewport meta, sticky headers, Tailwind v4 sizing

## Problem It Solves
Low-vision users zoom in. Dyslexic and cognitively disabled users often apply their own spacing stylesheets. Many layouts that look fine at 100% break under these conditions: text gets cut off inside fixed-height cards, the page scrolls sideways, sticky headers cover most of a short viewport, tooltips vanish before you can move the pointer onto them, and some sites block pinch-zoom completely. These failures are among the most common in AA audits and are cheap to prevent.

## When To Use
- Building or reviewing any layout, card, nav bar, modal, toolbar, or tooltip.
- Setting global CSS, the Tailwind theme, or the Next.js `viewport` export.
- Before an accessibility audit or VPAT/ACR, or when fixing audit findings for 1.4.4/1.4.10/1.4.12/1.4.13.
- Adding sticky or fixed elements, truncation, `line-clamp`, or fixed `height` on text containers.

## When Not To Use
- Content that needs a two-dimensional layout, such as data grids, maps, diagrams, video, games, or code with meaningful indentation. It is exempt from horizontal-scroll rules, but only that region is exempt. Each table cell still has to reflow.
- Canvas/WebGL content whose text can't be changed with CSS. Treat it as an image and give it a text alternative instead.
- Picking breakpoints or building a general responsive system. Use [responsive-design](../responsive-design/Skill.md).

## Core Principles
1. **400% zoom at 1280px width equals a 320 CSS px viewport.** Content must fit 320px wide with vertical scrolling only. For vertical writing modes, content must fit 256px tall with horizontal scrolling only.
2. **Text must scale to 200% with nothing lost or broken.** You can meet this with browser zoom, but relative units also respect the user's default font-size setting.
3. **Spacing overrides must not cut off or overlap text.** Test with line-height 1.5, paragraph spacing 2em, letter-spacing 0.12em, and word-spacing 0.16em. You don't have to ship those values. Your layout only has to survive them.
4. **Content that appears on hover or focus must be dismissible, hoverable, and persistent.** Escape closes it without moving focus. The pointer can move onto it. It stays until the user dismisses it or it no longer applies.
5. **Never block zoom.** Don't use `user-scalable=no` or `maximum-scale=1`.
6. **Let containers grow.** Use `min-height` and intrinsic sizing, never a fixed `height` on text containers.

## Best Practices
- Size fonts, and ideally media queries, in `rem`/`em`. Use `px` only for borders, hairlines, and shadows.
- Replace `height: X` with `min-height: X` on buttons, cards, banners, and inputs. Use padding to set the visual size.
- Use `overflow-wrap: anywhere` (or `break-word`) on user content, URLs, emails, and code-like tokens so long strings wrap instead of forcing sideways scroll.
- Put wide exempt content, such as tables and code, in its own scroll container. Never let `body` scroll horizontally.
- Make sticky headers and footers static below a height threshold, for example `@media (max-height: 30rem)`. At 400% zoom a 1080px-tall screen is only about 270 CSS px tall.
- Collapse multi-column layouts into one column at narrow widths using flex-wrap, `grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr))`, or container queries.
- If you truncate text (`truncate`, `line-clamp`), make the full text available another way: an expand control, a detail page, or a tooltip that meets 1.4.13. Truncation must not hide information permanently.
- Keep icon-only toolbars usable at 320px. Wrap them or move items into an overflow menu. Don't cut them off.
- Build tooltips and popovers on a primitive that already handles Escape, hover bridging, and focus. Don't hand-roll `onMouseLeave` hide logic.

## Implementation Guidance

**Decision table: what to do with each element at 320px / 200% text / spacing overrides**

| Element | Do | Avoid |
|---|---|---|
| Body text, headings | `rem` sizes, unitless line-height | `vw`-only font sizes (1.4.4 failure), fixed `height` |
| Cards / tiles | `min-height`, auto-fit grid | `h-48 overflow-hidden` with text inside |
| Buttons / chips | padding + `min-height`, allow wrapping | `h-10 whitespace-nowrap` on long labels |
| Sticky header | static on short viewports; keep it compact | `position: fixed` 120px header at all sizes |
| Data table | scroll region with label and keyboard focus | whole-page horizontal scroll |
| Side nav | collapses into a disclosure below the breakpoint | fixed 280px rail at 320px |
| Tooltip | Escape dismisses, hoverable, persistent | hides on `mouseleave` of the trigger only |
| Viewport meta | Next.js default | `maximumScale: 1`, `userScalable: false` |

**Clamp fluid type so zoom still enlarges it.** `font-size: 4vw` doesn't grow with zoom in a meaningful way. Add a `rem` term: `font-size: clamp(1.25rem, 1rem + 1.5vw, 2.5rem)`. Make sure the maximum is at least 2x the minimum, or check that 200% zoom still makes the text larger. See [fluid-typography-and-spacing](../fluid-typography-and-spacing/Skill.md).

**Tailwind v4.** Font-size utilities (`text-sm` = 0.875rem) and the spacing scale are rem-based, so they scale with the user's font setting. Watch for these:
- Fixed-height utilities on text containers: `h-*`, `max-h-*` combined with `overflow-hidden`. Prefer `min-h-*`.
- Arbitrary pixel values like `text-[14px]` and `leading-[20px]`. Pixel line-heights don't scale with the font. Use `text-sm/6` (a unitless or rem line-height) instead.
- `truncate`, `line-clamp-*`, and `whitespace-nowrap` on essential content.
- Breakpoint variants are rem-based in v4 (`md` = 48rem), so zooming correctly triggers mobile layouts. See [tailwind-css-v4](../tailwind-css-v4/Skill.md).

**The Next.js viewport.** The App Router already emits `width=device-width, initial-scale=1`. Don't export `maximumScale` or `userScalable: false`. Next's own API docs show those fields, so agents often copy them in.

## Recommended Workflow
1. Set globals: `rem` type scale, unitless line-heights, `overflow-wrap` on prose, and no zoom-blocking viewport.
2. Build components with `min-height` and wrapping. Mark exempt 2D regions explicitly.
3. **Zoom test.** Use a 1280px-wide desktop browser window. Zoom in steps (110, 125, 150, 175, 200, 300, 400%) and check at every step that nothing is cut off, nothing overlaps, and all functionality is still reachable. At 400%, the only horizontal scrolling should be inside exempt regions.
4. **Text-only resize test.** Set the browser's default font size to "Very large" (Chrome: Settings > Appearance > Font size) or use Firefox's "Zoom text only". This catches `px` font sizes that page zoom hides.
5. **Text spacing test.** At 100% zoom, inject the spacing CSS (Examples below) with a bookmarklet, extension, or Playwright. Look for cut-off or overlapping text. Repeat for each responsive layout.
6. **Hover/focus test.** Trigger each tooltip, popover, and mega-menu with the mouse and with the keyboard. Press Escape. Move the pointer onto the popup. Wait to confirm it doesn't auto-hide.
7. **Short viewport test.** Use DevTools device mode at 320x256 to approximate 400% zoom on a landscape screen. Confirm sticky UI doesn't cover content or trap it.
8. Automate the regressions you can (Testing). Record manual results in the audit log.

## Patterns
- **Grow-to-fit card:** `min-height` plus padding, with the grid auto-placing rows.
- **Labelled scroll region:** `<div role="region" aria-labelledby="t-cap" tabindex="0" className="overflow-x-auto">` around wide tables or code. Keyboard users can scroll it, and screen readers announce the label.
- **Short-viewport de-sticky:** `@media (max-height: 30rem) { .site-header { position: static; } }`.
- **Wrap-first toolbar:** `flex flex-wrap gap-2` before reaching for an overflow menu.
- **Accessible tooltip:** a primitive such as Radix, React Aria, or Base UI that closes on Escape and stays open while hovered. See [tooltips](../tooltips/Skill.md).

## Anti-Patterns
- **`userScalable: false` / `maximum-scale=1` to stop iOS input zoom.** This blocks zoom, fails 1.4.4, and is a well-known audit failure. Fix: set input font size to at least `1rem` (16px), which stops the auto-zoom.
- **`h-12 overflow-hidden` on buttons and badges.** Text gets cut off at 200% or with spacing overrides. Fix: `min-h-12 py-2`.
- **Pixel line-height (`line-height: 20px`).** It doesn't scale with the font, and overrides make text overlap. Fix: unitless `1.5` or `text-sm/6`.
- **Tall fixed header plus fixed bottom bar.** At 400% zoom they can fill the whole viewport. Fix: make them static on short viewports and keep headers compact.
- **`width: 1200px` / `min-width` on layout wrappers.** This forces the whole page to scroll sideways. Fix: `max-width` with `width: 100%`.
- **Hiding content at small breakpoints (`hidden md:block`) with no alternative.** This fails 1.4.10 (F102). Fix: move the content into a disclosure, menu, or later in the page.
- **Tooltip that disappears when the pointer leaves the trigger.** It isn't hoverable, which fails 1.4.13. Fix: a primitive with a hover bridge or grace area.
- **Text inside images or SVG with fixed viewBox scaling.** It pixelates and ignores spacing overrides. Fix: real HTML text.
- **Testing reflow only with DevTools mobile emulation.** It doesn't catch problems that appear only with zoom or text-only resize. Fix: run real zoom and font-size tests too.

## Accessibility
- WCAG 2.2: 1.4.4 Resize Text (AA), 1.4.10 Reflow (AA), 1.4.12 Text Spacing (AA), 1.4.13 Content on Hover or Focus (AA). Related: 1.4.5 Images of Text, 2.4.11 Focus Not Obscured (Minimum), which sticky headers at zoom commonly break.
- Focused elements must not be completely hidden behind sticky headers when zoomed. Use `scroll-padding-top` equal to the header height, or remove stickiness on short viewports.
- Exempt scroll regions need a keyboard-focusable container and an accessible name.
- Native `title` tooltips are exempt from 1.4.13 because the browser controls them, but they are inaccessible to touch and keyboard users. Don't rely on them.
- For the overall conformance program, see [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) and [accessibility-audit-process](../accessibility-audit-process/Skill.md).

## Responsive Design
- Reflow is largely a responsive-design problem. Zoom shrinks the CSS viewport, so rem/em breakpoints and container queries trigger naturally. See [responsive-design](../responsive-design/Skill.md) and [container-queries](../container-queries/Skill.md).
- Also design for height: short landscape phones and zoomed desktops both produce viewports around 250px tall. Use `max-height` media queries and `dvh` units carefully. A `100dvh` hero with fixed content inside will cut off text.
- Use logical properties (`min-block-size`, `overflow-wrap`) so vertical writing modes reflow on the correct axis. See [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md).

## Performance
- No meaningful runtime cost. Avoid JavaScript resize listeners that recalculate font sizes. CSS `clamp()` and container queries are cheaper and respect user settings.
- `content-visibility: auto` with a fixed `contain-intrinsic-size` can cut off or jump when text grows. Use `contain-intrinsic-size: auto <estimate>`.

## Security
- No direct security concerns. Don't disable zoom to prevent "UI redressing". It doesn't protect anything.

## Testing
- **Manual (required):** the zoom steps, the text-only font-size setting, the text spacing injection, and the hover/focus checks from the workflow. Test in Chrome and Firefox. Test iOS Safari pinch-zoom on a real device.
- **Playwright reflow check:** use a 320x256 viewport and assert `document.documentElement.scrollWidth <= clientWidth`. Skip wrappers you've marked exempt.
- **Playwright text-spacing check:** inject the spacing CSS and assert that no element with text has `scrollHeight > clientHeight` while `overflow` is hidden or clipped.
- **Automated rules:** axe-core flags `meta-viewport` (zoom disabled) and `meta-viewport-large`. It can't detect clipping from reflow or spacing, so manual testing is still required. See [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).
- **Visual regression:** take snapshots at 320px width and with spacing CSS injected. See [visual-regression-testing](../visual-regression-testing/Skill.md).

## Tooling
- Browser zoom (Ctrl/Cmd +) and the default font-size setting. Firefox View > Zoom > Zoom Text Only.
- Text Spacing Bookmarklet by Steve Faulkner (CodePen, linked from the WCAG C36 technique) or equivalent extensions. Exact injected CSS: Check current docs.
- Chrome DevTools device toolbar (responsive 320px; custom 320x256).
- Playwright with `@axe-core/playwright` for automated guards.
- Accessible tooltip and popover primitives: Radix UI, React Aria, Base UI (Active).

## Framework Notes
- **Next.js (App Router, 16.x):** Leave the default viewport alone, or export only `themeColor`/`colorScheme` from `app/layout.tsx` using `export const viewport: Viewport`. Never ship `maximumScale: 1` or `userScalable: false`. Put the spacing-test CSS behind a dev-only query flag if you want an in-app toggle. Don't ship it in production CSS.
- **React (Vite SPA):** `index.html` should contain `<meta name="viewport" content="width=device-width, initial-scale=1">` and nothing more restrictive. Handle zoom through CSS only. Don't add a JS "font-size slider" that stores `px` values.
- **Both:** hover/focus popups should come from headless primitives. Check portal-mounted popovers at 400%, because their flip/shift logic must keep them inside a 320px viewport (see [floating-element-positioning](../floating-element-positioning/Skill.md)).

## AI Agent Guidance
- DO use `rem` for font sizes, unitless line-heights, `min-h-*` for text containers, and `flex-wrap`/auto-fit grids.
- DO wrap wide tables and code in a labelled, focusable `overflow-x-auto` region.
- DO add `scroll-padding-top` when adding a sticky header, and make it static on short viewports.
- DON'T add `maximumScale`, `userScalable: false`, or `maximum-scale` to any viewport configuration, even if a snippet or the user's older code uses it. Flag it instead.
- DON'T put `h-*` with `overflow-hidden`, or `truncate`, on essential text unless the full text is reachable another way.
- DON'T hand-roll hover tooltips.
- Before declaring done: run the Playwright reflow and spacing checks (or equivalent), confirm there's no page-level horizontal scroll at 320px, confirm Escape closes any new hover or focus content, and state which manual zoom checks remain for a human.

## Examples

```css
/* app/globals.css — reflow-safe defaults */
html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
body { font-size: 1rem; line-height: 1.5; overflow-wrap: anywhere; }
input, select, textarea { font-size: max(1rem, 16px); } /* prevents iOS focus zoom without blocking zoom */
.site-header { position: sticky; top: 0; }
html { scroll-padding-top: 4rem; }
@media (max-height: 30rem) {
  .site-header { position: static; }
  html { scroll-padding-top: 0; }
}
.card-grid { display: grid; gap: 1rem; grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr)); }
```

```tsx
// components/ScrollRegion.tsx — exempt 2D content keeps page reflow intact
import { useId, type ReactNode } from 'react';

export function ScrollRegion({ label, children }: { label: string; children: ReactNode }) {
  const id = useId();
  return (
    <div role="region" aria-labelledby={id} tabIndex={0} className="max-w-full overflow-x-auto focus-visible:outline-2">
      <span id={id} className="sr-only">{label}</span>
      {children}
    </div>
  );
}
```

```tsx
// app/layout.tsx — Next.js: never restrict scaling
import type { Viewport } from 'next';
export const viewport: Viewport = {
  themeColor: [{ media: '(prefers-color-scheme: dark)', color: '#0a0a0a' }],
  // no maximumScale / userScalable
};
```

```ts
// e2e/reflow.spec.ts — Playwright guards for 1.4.10 and 1.4.12
import { test, expect } from '@playwright/test';

const SPACING_CSS = `*{line-height:1.5!important;letter-spacing:.12em!important;word-spacing:.16em!important}
p{margin-bottom:2em!important}`;

test('no page-level horizontal scroll at 320px', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 256 });
  await page.goto('/');
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

test('text spacing override does not clip text', async ({ page }) => {
  await page.goto('/');
  await page.addStyleTag({ content: SPACING_CSS });
  const clipped = await page.evaluate(() =>
    [...document.querySelectorAll<HTMLElement>('body *')]
      .filter((el) => {
        const s = getComputedStyle(el);
        const hides = ['hidden', 'clip'].includes(s.overflowY) || ['hidden', 'clip'].includes(s.overflowX);
        return hides && el.innerText.trim() && (el.scrollHeight > el.clientHeight + 1 || el.scrollWidth > el.clientWidth + 1);
      })
      .filter((el) => !el.closest('[data-allow-clip], .sr-only'))
      .map((el) => el.outerHTML.slice(0, 80)),
  );
  expect(clipped).toEqual([]);
});
```

```tsx
// Tailwind v4 fix: fixed-height badge -> grow-to-fit
// Before: <span className="h-6 overflow-hidden whitespace-nowrap text-[12px] leading-[24px]">{label}</span>
<span className="inline-flex min-h-6 items-center px-2 py-0.5 text-xs/5">{label}</span>
```

## Related Skills
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md): the conformance program these criteria belong to
- [responsive-design](../responsive-design/Skill.md): layout system that makes reflow work
- [fluid-typography-and-spacing](../fluid-typography-and-spacing/Skill.md): making `clamp()` type zoom-safe
- [tailwind-css-v4](../tailwind-css-v4/Skill.md): rem-based utilities and breakpoints
- [tooltips](../tooltips/Skill.md): 1.4.13-compliant hover content
- [popovers](../popovers/Skill.md): dismissible and persistent popups
- [accessible-data-tables](../accessible-data-tables/Skill.md): the exempt 2D content pattern
- [container-queries](../container-queries/Skill.md): component-level reflow
- [floating-element-positioning](../floating-element-positioning/Skill.md): keeping popups in narrow viewports
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md): axe rules and limits
- [accessibility-audit-process](../accessibility-audit-process/Skill.md): recording manual zoom and spacing results
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md): vertical writing-mode reflow

## Sources
- [Understanding SC 1.4.10 Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html): Official. 320/256 CSS px rationale, 2D exceptions, F102, techniques C31/C32/C33.
- [Understanding SC 1.4.4 Resize Text](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html): Official. 200% requirement, exceptions, viewport-unit and clipping failures.
- [Understanding SC 1.4.12 Text Spacing](https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html): Official. The four spacing metrics and failure modes.
- [Understanding SC 1.4.13 Content on Hover or Focus](https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html): Official. Dismissible, hoverable, and persistent requirements, and the `title` exception.
- [Technique C36: Allowing for text spacing override](https://www.w3.org/WAI/WCAG22/Techniques/css/C36): Official. Avoid fixed heights; bookmarklet test procedure.
- [Next.js generateViewport](https://nextjs.org/docs/app/api-reference/functions/generate-viewport): Official (v16.3.5). Default viewport tag and `Viewport` fields.
- [Tailwind CSS font-size](https://tailwindcss.com/docs/font-size): Official. rem-based sizes and `text-size/line-height` syntax.

## License / Usage Notes
W3C documents are under the W3C Document License. Content is summarized and paraphrased, not copied. Code examples are original and free to reuse. Planned TPGi and Adrian Roselli articles could not be fetched (403/404), so none of their content is used here.

## Quality Tier
A: grounded directly in the W3C Understanding documents and current Next.js/Tailwind docs. Third-party practitioner articles couldn't be fetched, and bookmarklet internals are unverified.

## Status
Active

## Last Verified
2026-09-15
