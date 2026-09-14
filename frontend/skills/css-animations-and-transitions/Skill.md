# CSS Animations and Transitions

## Summary
CSS transitions and `@keyframes` animations are the baseline animation layer of the web. They're zero-JS, declarative, interruptible (transitions), and often compositor-accelerated. The modern toolkit (all Baseline by 2026) adds `@starting-style` for entry animations, `transition-behavior: allow-discrete` for animating `display`/`overlay`, individual transform properties (`translate`, `scale`, `rotate`), and `linear()` easing for spring and bounce approximations. `interpolate-size`/`calc-size()` for animating to `height: auto` remains Chromium-only.

## Category
Animation

## Subcategories
Transitions, keyframes, easing functions, entry/exit animation, popover/dialog animation, discrete properties, custom properties (@property)

## Problem It Solves
Most UI motion (hover, focus, open/close, loading indicators) doesn't need a JS library. Historically, entry/exit animation of `display: none` elements, dialogs, and popovers required JS timers. Modern CSS solves this natively with fewer bugs and less code.

## When To Use
- State changes driven by classes, attributes, or pseudo-classes (`:hover`, `:focus-visible`, `[aria-expanded]`, `:popover-open`, `[open]`).
- Entry/exit animations for `<dialog>`, `[popover]`, `<details>`, and `display`-toggled elements.
- Looping indicators (spinners, skeleton shimmer) and simple sequences.
- Design-system primitives where each component should work without a runtime.

## When Not To Use
- Gesture-driven motion that needs velocity or drag physics: use Motion or WAAPI.
- Layout reordering (FLIP) and shared-element morphs: use the View Transitions API or Motion `layout`.
- Complex scroll choreography with pinning: use GSAP, or CSS scroll-driven animations with care.
- Dynamic values computed at runtime per frame: use WAAPI or JS.

## Core Principles
1. Transitions for state changes (A↔B, interruptible); keyframes for multi-step or looping motion.
2. Animate `transform`, `opacity` (and `filter`/`clip-path` with care). Avoid layout properties.
3. Never use `transition: all`. List properties explicitly.
4. Entering elements use ease-out; on-screen movement uses ease-in-out; avoid ease-in for UI.
5. Keep UI motion short: 100–300ms. Exits should be faster than entries.
6. Wrap non-essential motion in `@media (prefers-reduced-motion: no-preference)`, or neutralize it under `reduce`.

## Best Practices
- Define motion tokens as custom properties: `--ease-out: cubic-bezier(0.23, 1, 0.32, 1); --dur-fast: 150ms;`.
- Use individual transform properties (`scale: 0.97`) so hover/press don't overwrite each other's `transform`.
- Put `@starting-style` after the base rule (same specificity), or nest it inside the rule.
- For `display`/`overlay` transitions, include them with `allow-discrete` in the transition list.
- Use `animation-fill-mode: both` for keyframes with delays to avoid a flash of the final state.
- Gate hover animations with `@media (hover: hover) and (pointer: fine)` to avoid sticky hover on touch.
- Use `@property` to register custom properties so they interpolate (gradients, angles, counters).
- Set `transform-origin` to the trigger side for popovers/menus (many libraries expose `--transform-origin` vars).

## Implementation Guidance

### Transition vs keyframes decision
| Situation | Use |
|---|---|
| Hover/focus/active/state class toggles | `transition` |
| Element appears (from DOM insert or `display:none`) | `transition` + `@starting-style` |
| Rapid toggles (toasts stacking, accordions) | `transition` (retargets smoothly) |
| Looping, multi-step, or one-shot attention | `@keyframes` |
| Needs to play regardless of state | `@keyframes` |

### Easing tokens
| Token | Value | Use |
|---|---|---|
| `--ease-out` | `cubic-bezier(0.23, 1, 0.32, 1)` | Enter, feedback |
| `--ease-in-out` | `cubic-bezier(0.77, 0, 0.175, 1)` | Move on screen |
| `--ease-drawer` | `cubic-bezier(0.32, 0.72, 0, 1)` | iOS-like sheets |
| `--ease-standard` (M3) | `cubic-bezier(0.2, 0, 0, 1)` | General |
| `--ease-emph-decel` (M3) | `cubic-bezier(0.05, 0.7, 0.1, 1)` | Large entrances |
| `--ease-spring` | `linear(0, 0.36 9%, 0.83 20%, 1.02 31%, 1.05 38%, 1.01 52%, 1 100%)` | Gentle overshoot (approximate; generate with a linear() tool) |

### Duration tokens
| Token | ms | Typical use |
|---|---|---|
| `--dur-instant` | 0–100 | Color/opacity feedback |
| `--dur-fast` | 150 | Buttons, tooltips |
| `--dur-base` | 200–250 | Menus, popovers |
| `--dur-slow` | 300–400 | Dialogs, sheets |
| `--dur-page` | 400–500 | Large surface transitions (rare) |

### Support snapshot (Sept 2026)
| Feature | Status |
|---|---|
| `@starting-style` | Baseline 2024 (Chrome 117, Firefox 119, Safari 17.2) |
| `transition-behavior: allow-discrete` | Baseline 2024 |
| `linear()` easing | Baseline widely available |
| Individual transforms (`translate`/`scale`/`rotate`) | Baseline widely available |
| `@property` | Baseline (all engines) |
| `interpolate-size` / `calc-size()` | Chromium only; progressive enhancement |

## Recommended Workflow
1. Define motion tokens (durations, easings) in the design system.
2. Write the static final state first, then the starting state (`@starting-style`) and exit state.
3. Add a transition list with explicit properties and discrete properties.
4. Add a reduced-motion override.
5. Test rapid toggling, keyboard toggling, and touch devices.
6. Check the DevTools Animations panel (slow to 10%) and the Performance panel for layout/paint.

## Patterns

### Animated popover (enter + exit, no JS)
```css
[popover] {
  opacity: 0;
  scale: 0.96;
  transition:
    opacity 150ms var(--ease-out),
    scale 150ms var(--ease-out),
    overlay 150ms allow-discrete,
    display 150ms allow-discrete;
}
[popover]:popover-open {
  opacity: 1;
  scale: 1;
  @starting-style { opacity: 0; scale: 0.96; }
}
```

### Dialog with backdrop
```css
dialog, dialog::backdrop {
  transition: opacity 200ms var(--ease-out), translate 200ms var(--ease-out),
              overlay 200ms allow-discrete, display 200ms allow-discrete;
  opacity: 0;
}
dialog { translate: 0 8px; }
dialog[open] { opacity: 1; translate: 0 0; }
dialog[open]::backdrop { opacity: 1; }
@starting-style {
  dialog[open] { opacity: 0; translate: 0 8px; }
  dialog[open]::backdrop { opacity: 0; }
}
```

### Accordion height to auto (progressive)
```css
:root { interpolate-size: allow-keywords; } /* Chromium; others snap */
details::details-content {
  block-size: 0; overflow: clip;
  transition: block-size 250ms var(--ease-out), content-visibility 250ms allow-discrete;
}
details[open]::details-content { block-size: auto; }
```
Fallback for all engines: a grid-rows trick, `grid-template-rows: 0fr → 1fr` with an inner `min-height: 0` wrapper.

### Press feedback
```css
.button { transition: scale 120ms var(--ease-out); }
.button:active { scale: 0.97; }
```

### Registered custom property animation
```css
@property --angle { syntax: "<angle>"; inherits: false; initial-value: 0deg; }
.ring { background: conic-gradient(from var(--angle), #6366f1, transparent 40%); animation: spin 2s linear infinite; }
@keyframes spin { to { --angle: 360deg; } }
```

### Reduced motion baseline
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```
Use `0.01ms`, not `0`, so `transitionend`/`animationend` still fire. Better still, author motion inside `no-preference` and keep opacity fades for reduced motion.

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| `transition: all 0.3s` | Animates unintended properties (layout, colors on theme switch) | List properties |
| `setTimeout` to remove class after exit | Desyncs with duration tokens | `allow-discrete` + `display`, or `transitionend` |
| Animating `height`, `top`, `margin` | Layout per frame | `transform`, grid-rows trick, `interpolate-size` enhancement |
| `ease-in` on entering menus | Feels delayed | `ease-out` custom curve |
| Keyframes for hover states | Not interruptible; jumps on un-hover | `transition` |
| Scale from 0 | Unnatural pop | Start at 0.95 with opacity |
| Infinite decorative loops | Distracting, battery drain, WCAG 2.2.2 | Limit iterations; pause offscreen; reduced-motion off |
| `@starting-style` placed before the base rule | Overridden by cascade | Place after, or nest |
| Transitions on theme toggle | Whole-page color animation flash | Temporarily disable transitions during theme switch |

## Accessibility
- WCAG 2.3.3 (AAA): motion triggered by interaction can be disabled. Implement it via `prefers-reduced-motion`.
- WCAG 2.2.2 (A): auto-playing animation longer than 5s needs pause/stop (spinners tied to loading are exempt as essential).
- WCAG 2.3.1 (A): no flashing more than 3 times per second.
- Don't rely on animation alone to convey state; pair it with text/ARIA changes (`aria-expanded`, live regions).
- Focus-visible styles must not be animated so slowly that focus is hard to track (≤150ms).

## Responsive Design
- Scale travel distances with viewport units or `clamp()`, and keep them small (≤ 24px) for UI.
- Disable hover-triggered motion on coarse pointers.
- For sheets, use `translate: 0 100%` on mobile and a scale/fade on desktop via media or container queries.

## Performance
- Compositor-friendly: `transform`, individual transforms, `opacity`. `filter` and `clip-path` are often accelerated but costlier on large areas.
- Avoid animating `box-shadow`. Animate the opacity of a pseudo-element that holds the shadow instead.
- `will-change` only for elements about to animate. Remove it when idle; never apply it globally.
- Many simultaneous keyframe loops (skeletons) can be expensive; use one shimmer on a container.
- `content-visibility: auto` offscreen reduces animation cost for long pages.

## Security
- Negligible. Avoid injecting user-provided strings into `style` attributes (CSS injection via `url()`); Content Security Policy `style-src` may affect inline styles used for dynamic animation values.

## Testing
- Playwright `page.emulateMedia({ reducedMotion: 'reduce' })` for both branches.
- Visual regression: disable animations (`animations: "disabled"` in Playwright screenshots).
- Use `element.getAnimations()` in tests to await `finished` promises instead of sleeps.
- DevTools Animations panel: replay at 10–25% speed to catch jumps at start/end.

## Tooling
- Chrome DevTools Animations panel; Firefox Animation inspector.
- linear() easing generators (e.g. Jake Archibald's/Easing Wizard tools) for spring/bounce curves.
- easings.co / easing.dev for curated curves.
- Open Props / Tailwind v4 `transition-*`, `ease-*`, `animate-*` utilities (Active).

## Framework Notes
- **React (Vite SPA)**: CSS transitions need the element present in both states. Entry via `@starting-style` works on mount with no JS. For unmount exits, either keep the element mounted and toggle `hidden`/`data-state` with `display` + `allow-discrete`, or use `<ViewTransition exit>` (React 19.3) or Motion `AnimatePresence`. Toggle `[popover]` via `popover`/`popoverTarget` attributes; React 19 supports them on JSX.
- **Next.js App Router**: CSS animations need no `"use client"`, so Server Components can ship animated markup with zero JS. Put keyframes and tokens in `app/globals.css` or CSS Modules. `@starting-style` entry animations replay on client-side navigation when the element is newly inserted, which is usually desired. Wrap persistent layout elements carefully so they don't re-animate.
- **Hydration flashes**: CSS entrance animations begin at first paint of server HTML, before hydration, so they don't flicker the way JS-initiated animations do. Prefer CSS for above-the-fold entrances. Don't gate the start state on a client-only class unless a no-JS fallback shows content.
- **Tailwind v4**: `starting:` variant maps to `@starting-style`; `transition-discrete` for `allow-discrete`; `motion-safe:`/`motion-reduce:` variants.
- **Radix / Base UI / shadcn/ui**: primitives expose `data-state="open|closed"` (Radix) or `data-starting-style`/`data-ending-style` (Base UI) and keep content mounted during the exit, so plain CSS enter/exit works in TSX components.

## AI Agent Guidance
- DO prefer CSS before adding animation libraries.
- DO use explicit transition property lists, motion tokens, and `@starting-style` for entries.
- DO include `overlay` and `display` with `allow-discrete` for popover/dialog exits.
- DO add reduced-motion handling in the same change.
- DON'T use `transition: all`, `ease-in` for entrances, or animate layout properties.
- DON'T rely on `interpolate-size` without a fallback.
- Verify: open/close both animate; rapid toggles don't glitch; reduced motion works; no layout shift (CLS) from animation.

## Examples

### Native popover component in TSX (Server Component compatible, zero JS)
```tsx
// components/info-popover.tsx — no "use client" needed
import styles from "./info-popover.module.css";

export function InfoPopover({ id, label, children }: { id: string; label: string; children: React.ReactNode }) {
  return (
    <>
      <button type="button" popoverTarget={id} className={styles.trigger}>{label}</button>
      <div id={id} popover="auto" className={styles.popover}>{children}</div>
    </>
  );
}
```
```css
/* info-popover.module.css */
.popover {
  opacity: 0; scale: 0.96; transform-origin: top center;
  transition: opacity 150ms var(--ease-out), scale 150ms var(--ease-out),
              overlay 150ms allow-discrete, display 150ms allow-discrete;
}
.popover:popover-open {
  opacity: 1; scale: 1;
  @starting-style { opacity: 0; scale: 0.96; }
}
@media (prefers-reduced-motion: reduce) { .popover { scale: 1; } }
```

### Controlled dialog with CSS exit (client component)
```tsx
"use client";
import { useEffect, useRef } from "react";

export function Modal({ open, onClose, children }: { open: boolean; onClose: () => void; children: React.ReactNode }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close(); // CSS allow-discrete keeps it painted during exit
  }, [open]);
  return <dialog ref={ref} onClose={onClose} className="modal">{children}</dialog>;
}
```
Pair it with the "Dialog with backdrop" CSS pattern above. The dialog element stays mounted, so the exit transition plays without an animation library.

### Tailwind v4 equivalent
```tsx
<div
  popover="auto"
  id="menu"
  className="opacity-0 scale-95 transition-[opacity,scale,display,overlay] transition-discrete duration-150 ease-out
             open:opacity-100 open:scale-100 starting:open:opacity-0 starting:open:scale-95 motion-reduce:scale-100"
/>
```
Verify that the `open:` variant matches `:popover-open` in your Tailwind version. If not, use an arbitrary variant `[&:popover-open]:`.

### Toast stack with transitions (retargetable)
```css
.toast {
  translate: 0 calc(var(--index) * -8px);
  scale: calc(1 - var(--index) * 0.05);
  opacity: 1;
  transition: translate 300ms var(--ease-out), scale 300ms var(--ease-out), opacity 200ms;
  @starting-style { translate: 0 100%; opacity: 0; }
}
```

### Skeleton shimmer that respects preferences
```css
@media (prefers-reduced-motion: no-preference) {
  .skeleton { background: linear-gradient(90deg, #eee 25%, #f5f5f5 50%, #eee 75%) 0 0 / 200% 100%;
              animation: shimmer 1.4s linear infinite; }
}
@keyframes shimmer { to { background-position: -200% 0; } }
```

## Related Skills
- [modern-css-features](../modern-css-features/Skill.md) — broader modern CSS context
- [micro-interactions](../micro-interactions/Skill.md) — applying transitions to feedback
- [animation-performance](../animation-performance/Skill.md) — compositor-only properties
- [motion-design-principles](../motion-design-principles/Skill.md) — easing/duration rationale
- [popovers](../popovers/Skill.md) — popover API animation
- [accessible-dialogs](../accessible-dialogs/Skill.md) — dialog enter/exit
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — motion preferences
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — `starting:` and motion variants

## Sources
- [MDN @starting-style](https://developer.mozilla.org/en-US/docs/Web/CSS/@starting-style) — Official — syntax, popover/dialog, compat
- [MDN transition-behavior](https://developer.mozilla.org/en-US/docs/Web/CSS/transition-behavior) — Official — discrete flip timing
- [MDN linear()](https://developer.mozilla.org/en-US/docs/Web/CSS/easing-function/linear) — Official — syntax and baseline
- [MDN interpolate-size](https://developer.mozilla.org/en-US/docs/Web/CSS/interpolate-size) — Official — height:auto animation, limited support
- [web.dev animations guide](https://web.dev/articles/animations-guide) — Official — compositor-only properties
- [Material 3 motion tokens (material-web)](https://github.com/material-components/material-web) — Official/Open Source — easing/duration values
- [Emil Kowalski: 7 practical animation tips](https://emilkowal.ski/ui/7-practical-animation-tips) — Community — press scale, origin, duration

## License / Usage Notes
CSS specs and MDN content (CC-BY-SA) are summarized, not copied. Code examples are original.

## Quality Tier
A — Verified against MDN compatibility data; the `linear()` spring values are illustrative approximations.

## Status
Active

## Last Verified
2026-09-15
