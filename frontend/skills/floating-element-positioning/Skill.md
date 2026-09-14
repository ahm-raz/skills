# Floating Element Positioning

## Summary
How to place tooltips, popovers, menus, listboxes and hover cards next to their anchors so they stay visible, flip or shift at viewport edges, follow scrolling, and escape clipping containers. This skill compares CSS anchor positioning (Baseline 2026 core) plus the top layer against Floating UI's middleware, and covers containing-block pitfalls, virtual anchors (cursor, text selection), arrows, size constraints, and React/Next.js integration.

## Category
Components

## Subcategories
CSS anchor positioning, position-area, position-try-fallbacks, Floating UI, collision detection, top layer, portals, virtual elements

## Problem It Solves
Floating elements get clipped by `overflow: hidden` ancestors, trapped under stacking contexts, detached during scroll, pushed offscreen at viewport edges, or mispositioned by transformed ancestors. JS positioning adds bundle size and main-thread work. CSS anchor positioning now covers most cases natively, but support nuances and advanced needs still call for Floating UI.

## When To Use
- Building or customizing any anchored overlay (tooltip, popover, dropdown, combobox list, date picker, hover card, context menu at the cursor).
- Debugging clipped, misaligned, or jittery floating UI.
- Deciding whether to remove a positioning dependency.

## When Not To Use
- Modal dialogs and drawers: they're centered or edge-anchored, not trigger-anchored.
- Inline expanding content (accordions): no floating needed.
- Toasts: fixed regions, not anchors.
- If your component library (Radix, Base UI, React Aria) already positions the element, configure it (`side`, `align`, `sideOffset`, `collisionPadding`) instead of re-implementing.

## Core Principles
1. Render floating elements in the top layer (Popover API/`<dialog>`) or a portal to escape overflow clipping and stacking contexts.
2. Position with CSS anchor positioning when your support matrix allows; fall back to Floating UI or the OddBird polyfill otherwise.
3. Always define fallbacks for edges: flip on the main axis, shift/align on the cross axis, constrain size and scroll internally.
4. Keep position updated on scroll/resize/anchor-size changes (automatic in CSS; `autoUpdate` in Floating UI).
5. Hide or close floating elements when their anchor scrolls out of view (`position-visibility: anchors-visible` or Floating UI `hide`).

## Best Practices
- Offset 4–8px from the anchor; keep 8px collision padding from viewport edges.
- Match dropdown/listbox width to the trigger: `min-inline-size: anchor-size(inline)` (CSS) or the Floating UI `size` middleware.
- Constrain height to available space with internal scrolling (`max-block-size` + fallbacks, or `size` middleware `availableHeight`).
- Use logical placements (`block-end`, `inline-start`) for RTL correctness.
- Use `strategy: 'fixed'` in Floating UI when the reference sits in fixed or sticky contexts to reduce jumps.
- Arrow elements: position with Floating UI's `arrow` middleware. With CSS, position the arrow relative to the anchor center, and hide it when a fallback flips if it would point the wrong way.
- Avoid animating `top`/`left`; animate opacity/transform on an inner wrapper so positioning isn't disturbed.

## Implementation Guidance

### Support snapshot (Sept 2026)
| Feature | Status |
|---|---|
| `anchor-name`, `position-anchor`, `anchor()`, `position-area`, `anchor-size()`, `position-try-fallbacks` | Core shipped: Chrome/Edge 125+, Safari 26+, Firefox 147+ (Baseline 2026). caniuse marks only the newest engine versions fully compliant, so test fallbacks and sub-features |
| Implicit anchor for invoker-opened popovers | Supported alongside Popover API + anchor positioning in current engines; verify per engine |
| `anchor-scope` | Newer; verify before relying on it for repeated components |
| Popover API (top layer, light dismiss) | Baseline (newly available 2025) |
| Polyfill | `@oddbird/css-anchor-positioning` (load conditionally) |

### Decision table
| Need | Choose |
|---|---|
| Tooltip/popover/menu anchored to a button, modern browsers | Popover API + CSS anchor positioning (`position-area` + `position-try-fallbacks`) |
| Repeated anchors in lists (many rows) | Implicit anchors via invokers, or unique `anchor-name` per row, or `anchor-scope` |
| Cursor-positioned context menu, text-selection toolbar, canvas coordinates | Floating UI with a virtual element (`getBoundingClientRect` from a point or `Range`) |
| "Prefer below only if ≥200px available" or pick the side with the most space | Floating UI `autoPlacement` / `size` (CSS fallbacks are fit/no-fit only) |
| Library components | Radix/Base UI Positioner props, React Aria `placement`/`offset`/`crossOffset`/`shouldFlip` |
| Older engines in the support matrix | Floating UI, or the polyfill |

### Floating UI middleware order
`offset()` → `flip()` (or `autoPlacement()`) → `shift({ padding })` → `size()` → `arrow()` → `hide()`. Use `whileElementsMounted: autoUpdate` to track scroll, resize and layout changes.

### Containing-block pitfalls
| Symptom | Cause | Fix |
|---|---|---|
| Floating element clipped | Ancestor `overflow: hidden/auto` | Top layer (popover) or portal to `body` |
| Positioned relative to wrong box | Ancestor with `transform`, `filter`, `perspective`, `contain: paint`, `will-change: transform` creates a containing block for fixed elements | Top layer / portal, or remove the property |
| Appears under other content | Stacking context with lower z-index | Top layer; avoid z-index escalation |
| Jumps during scroll | Absolute strategy inside a fixed header | `position: fixed` / Floating UI `strategy: 'fixed'` |
| Anchor positioning ignored | Anchor rendered after positioned element in a different containing block, or anchor hidden (`display:none`) | Ensure anchor is laid out before, and visible; check DevTools anchor overlays |

## Recommended Workflow
1. Check whether the component library already handles positioning; configure it first.
2. If custom: choose CSS anchor positioning vs Floating UI using the decision table and support matrix.
3. Put the floating element in the top layer (popover) or a portal.
4. Define placement, offset, fallbacks, and size constraints.
5. Handle anchor visibility and scroll containers.
6. Test at viewport edges, in scroll containers, with RTL, zoom 200–400%, and virtual keyboards on mobile.

## Patterns

### CSS anchor positioning with the Popover API (React)
```tsx
'use client';
import { useId } from 'react';

export function InfoPopover({ label, children }: { label: string; children: React.ReactNode }) {
  const id = useId();
  return (
    <>
      <button type="button" popoverTarget={id}>{label}</button>
      <div id={id} popover="auto" className="floating">{children}</div>
    </>
  );
}
```
```css
.floating {
  margin: 0; inset: auto;                       /* reset UA popover centering */
  position-area: block-end span-inline-end;     /* below, aligned to start edge */
  margin-block-start: 6px;
  min-inline-size: anchor-size(inline);
  max-block-size: 50dvh; overflow: auto;
  position-try-fallbacks: flip-block, flip-inline, flip-block flip-inline;
  position-visibility: anchors-visible;
}
```
This relies on the implicit anchor created by `popoverTarget`. For JS-opened popovers, set `anchor-name: --x` on the trigger and `position-anchor: --x` on the popover (unique per instance, e.g., via a CSS custom property set from `useId`-derived names without colons).

### Explicit per-instance anchor names in React
```tsx
const anchor = `--a-${useId().replace(/[^a-zA-Z0-9-]/g, '')}`;
<button style={{ anchorName: anchor } as React.CSSProperties}>Options</button>
<div popover="manual" style={{ positionAnchor: anchor } as React.CSSProperties} className="floating">…</div>
```
Check that your React/TypeScript version knows the `anchorName`/`positionAnchor` style keys; cast if not.

### Floating UI with collision handling and arrow
```tsx
'use client';
import { useRef, useState } from 'react';
import { useFloating, autoUpdate, offset, flip, shift, size, arrow, hide, FloatingArrow, FloatingPortal } from '@floating-ui/react';

export function Floating({ anchor, children }: { anchor: React.ReactElement; children: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const arrowRef = useRef<SVGSVGElement>(null);
  const { refs, floatingStyles, context, middlewareData } = useFloating({
    open, onOpenChange: setOpen, placement: 'bottom-start', strategy: 'absolute',
    whileElementsMounted: autoUpdate,
    middleware: [
      offset(8), flip({ padding: 8 }), shift({ padding: 8 }),
      size({ padding: 8, apply({ availableHeight, rects, elements }) {
        Object.assign(elements.floating.style, { maxHeight: `${Math.max(120, availableHeight)}px`, minWidth: `${rects.reference.width}px` });
      } }),
      arrow({ element: arrowRef }), hide(),
    ],
  });
  return (
    <>
      <span ref={refs.setReference} onClick={() => setOpen((o) => !o)}>{anchor}</span>
      {open && (
        <FloatingPortal>
          <div ref={refs.setFloating} style={{ ...floatingStyles, visibility: middlewareData.hide?.referenceHidden ? 'hidden' : 'visible' }}>
            {children}
            <FloatingArrow ref={arrowRef} context={context} />
          </div>
        </FloatingPortal>
      )}
    </>
  );
}
```
This shows positioning only. Add interactions (`useClick`, `useDismiss`, `useRole`, focus management) or use a library component. Put the ref on an element that can hold a ref (a `span` wrapper here, or pass props into a button).

### Virtual anchor: context menu at the cursor
```tsx
const { refs } = useFloating({ placement: 'right-start', middleware: [offset(2), flip(), shift({ padding: 8 })], whileElementsMounted: autoUpdate });
const onContextMenu = (e: React.MouseEvent) => {
  e.preventDefault();
  refs.setPositionReference({
    getBoundingClientRect: () => ({ x: e.clientX, y: e.clientY, top: e.clientY, left: e.clientX, bottom: e.clientY, right: e.clientX, width: 0, height: 0 }),
  });
  setOpen(true);
};
```

## Anti-Patterns
- **z-index 99999 to escape clipping**: stacking contexts still win. Fix: top layer or portal.
- **Manual `getBoundingClientRect` on scroll without rAF**: jank and stale positions. Fix: CSS anchoring or `autoUpdate`.
- **No flip/shift**: menus render offscreen near edges. Fix: fallbacks/middleware.
- **Fixed width floating lists narrower than the trigger**: Fix: `anchor-size(inline)` / `size` middleware.
- **Popover UA styles left in place with anchor positioning**: centered in viewport. Fix: `margin: 0; inset: auto`.
- **Same `anchor-name` repeated across list rows**: every popover anchors to the last one. Fix: implicit anchors, unique names, or `anchor-scope`.
- **Removing Floating UI without checking engine support/sub-features**: Fix: verify matrix, keep polyfill/fallback.
- **Floating element stays visible when the anchor scrolls away inside a scroller**: Fix: `position-visibility` / `hide` middleware or close on scroll.

## Accessibility
- Positioning shouldn't change DOM order. Keep floating content adjacent to its trigger in the DOM or manage focus explicitly (portals break natural Tab order; libraries compensate).
- WCAG 1.4.10 Reflow (at 320px, floating content must fit or become a sheet), 1.4.13 Content on Hover or Focus (don't cover the trigger in a way that makes the tooltip unhoverable), 2.4.11 Focus Not Obscured (floating layers must not hide the focused element).
- Don't hide floating content visually but leave it focusable.

## Responsive Design
- Below small container widths, convert large floating panels to bottom sheets or full-screen dialogs.
- Use `dvh` and `size`-constrained heights to account for mobile browser UI and virtual keyboards (VisualViewport API if needed).
- Logical placements for RTL; test flip behavior in RTL.

## Performance
- CSS anchor positioning runs in layout with no JS per frame, which is the best option for many simultaneous tooltips.
- Floating UI: `autoUpdate` has options (`animationFrame: false` by default). Avoid `animationFrame: true` unless the anchor moves via transforms.
- Lazy-load Floating UI only where needed; the OddBird polyfill should load conditionally (`if (!CSS.supports('anchor-name: --a'))`).

## Security
- No direct concerns. Avoid rendering untrusted HTML in floating content, and keep sensitive hover data out of the DOM until authorized.

## Testing
- Playwright visual tests at viewport edges (top/bottom/left/right), inside scroll containers, RTL, and zoom. Assert bounding boxes stay within the viewport.
- Cross-engine runs (Chromium, Firefox, WebKit), since anchor positioning sub-feature differences show up here.
- Unit tests in jsdom can't validate layout; use browser-mode tests or Playwright component tests.

## Tooling
- Native: CSS anchor positioning, Popover API, `<dialog>`. Chrome DevTools anchor positioning badges/overlays.
- `@floating-ui/react` (positioning + interactions: `useInteractions`, `useDismiss`, `useRole`, `FloatingFocusManager`, `FloatingPortal`), `@floating-ui/react-dom` (positioning only), `@floating-ui/dom`.
- `@oddbird/css-anchor-positioning` polyfill.
- Radix/Base UI/shadcn positioners use Floating UI internally.

## Framework Notes
- **React (Vite SPA)**: Prefer library props (`side`, `align`, `sideOffset`, `collisionPadding`, `avoidCollisions`) over custom code. Floating UI hooks need refs on DOM elements, so custom trigger components must accept `ref`. Portals render to `document.body`; wrap in a themed container if CSS variables are scoped.
- **Next.js (App Router)**: Positioning needs the DOM, so floating logic lives in Client Components (`'use client'`). Server HTML for closed popovers is fine. Never render an open, JS-positioned element on the server (initial `top:0;left:0` flash, hydration mismatch); open only after hydration. Portals require `document`, so render them only when open, or after mount. CSS anchor positioning works in server-rendered markup with no JS. Load the OddBird polyfill with `next/script` `strategy="afterInteractive"` only when unsupported. Close floating elements on route change if their anchor unmounts.

## AI Agent Guidance
- DO use the library's positioning props before writing custom positioning.
- DO prefer top layer + CSS anchor positioning in modern-only matrices; DO add fallbacks and size constraints.
- DON'T fight clipping with z-index; DON'T reuse one anchor name across instances.
- Verify: edges (flip/shift), scroll containers, RTL, 320px width, zoom, anchor scrolled out of view, Firefox and WebKit rendering.

## Examples
Radix/shadcn popover positioning configuration:
```tsx
<PopoverContent side="bottom" align="start" sideOffset={6} collisionPadding={8} avoidCollisions
  className="w-[var(--radix-popover-trigger-width)] max-h-[var(--radix-popover-content-available-height)] overflow-auto">
  …
</PopoverContent>
```

## Related Skills
- [popovers](../popovers/Skill.md): Popover API behavior
- [tooltips](../tooltips/Skill.md): hint overlays
- [dropdown-menus](../dropdown-menus/Skill.md): menus and submenus
- [select-and-combobox](../select-and-combobox/Skill.md): listbox width matching
- [modern-css-features](../modern-css-features/Skill.md): anchor positioning in the CSS toolkit
- [css-cascade-layers-and-specificity](../css-cascade-layers-and-specificity/Skill.md): stacking and layering
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md): logical placements

## Sources
- [MDN: Using CSS anchor positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Anchor_positioning/Using) — Official — syntax, fallbacks, implicit anchors, anchor-scope
- [MDN: position-anchor](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/position-anchor) — Official — property reference
- [caniuse: CSS anchor positioning](https://caniuse.com/css-anchor-positioning) — Community (data) — full/partial support by engine version
- [OddBird: Anchor Positioning Updates for Fall 2025](https://www.oddbird.net/2025/10/13/anchor-position-area-update/) — Community (spec contributors) — cross-browser status and polyfill
- [Floating UI: useFloating](https://floating-ui.com/docs/useFloating) — Open Source — placement, strategy, middleware, autoUpdate
- [MDN: Popover API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using) — Official — top layer and implicit anchor

## License / Usage Notes
Summarized in original wording; code original. Floating UI MIT; OddBird polyfill BSD-3-Clause (verify).

## Quality Tier
A — official specs/MDN plus library docs; cross-engine sub-feature data conflicted between sources, which is flagged in the text.

## Status
Active

## Last Verified
2026-09-15
