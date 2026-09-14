# Web Animations API (WAAPI)

## Summary
The Web Animations API is the browser-native JavaScript interface to the same animation engine that powers CSS animations. `element.animate(keyframes, options)` returns an `Animation` object with `play`/`pause`/`reverse`/`cancel`, a `finished` promise, `playbackRate`, `commitStyles()`, and scroll timeline support (`ScrollTimeline`/`ViewTimeline` in Chromium and Safari 26). It's Baseline, runs transform/opacity animations on the compositor, and needs zero dependencies. In React it's the right tool for imperative, one-off animations through refs. React 19.3's `<ViewTransition>` callbacks and Motion's mini `useAnimate` are built on it.

## Category
Animation

## Subcategories
Imperative animation, Animation objects, promises, commitStyles, getAnimations, composite modes, scroll timelines, pseudo-element animation

## Problem It Solves
CSS animations are declarative but hard to control from JS: they can't be awaited, reversed mid-flight, or given runtime-computed keyframes without class juggling. Libraries add bundle weight. WAAPI provides JS control with native, off-main-thread performance and promise-based sequencing.

## When To Use
- Runtime-computed animations (FLIP offsets, pointer-derived keyframes) in React event handlers or effects.
- Awaiting animation completion before a state change (e.g. remove an item after its exit animation).
- Controlling `<ViewTransition>` pseudo-elements via `onEnter`/`onExit`/`onShare` callbacks.
- Lightweight projects that can't justify Motion/GSAP bundle cost.
- Querying and pausing all running animations (`document.getAnimations()`) for tests or reduced-motion toggles.

## When Not To Use
- Declarative presence/layout/gesture-heavy React UI: Motion for React is more ergonomic.
- Complex timelines with overlapping labels and scroll pinning: GSAP.
- Pure state changes expressible via CSS transitions.
- Spring physics with velocity: WAAPI has no native springs (approximate with `linear()` easing).

## Core Principles
1. Animate `transform`/`opacity` for compositor acceleration.
2. Always handle cleanup: `animation.cancel()` in effect cleanups/unmounts.
3. Don't rely on `fill: "forwards"` for persistent state; `commitStyles()` then `cancel()`, or set the final style in React/CSS.
4. Await `animation.finished` for sequencing, and catch the `AbortError` rejection on cancel.
5. Respect `prefers-reduced-motion` before calling `animate`.
6. Keep React as the source of truth for final state. WAAPI handles the in-between.

## Best Practices
- Use `easing` with custom cubic-bezier or `linear()` strings. Default is `linear`, which is rarely right for UI.
- Name animations with `id` for debugging in DevTools.
- Use `composite: "add"` to layer animations (e.g. hover wobble on top of an entrance) instead of fighting over `transform`.
- Use `pseudoElement: "::before"` or `"::view-transition-new(name)"` options to animate pseudo-elements.
- Use `el.getAnimations()` to cancel existing animations before starting new ones (prevent stacking on rapid clicks).
- Use `animation.updatePlaybackRate()` for smooth speed changes (it syncs with the compositor).
- For scroll-linked JS animations, pass `timeline: new ViewTimeline({ subject: el })` with feature detection.
- Prefer implicit from-keyframes (only `to` keyframe) when animating from current computed style, which allows smooth retargeting.

## Implementation Guidance

### API cheat sheet
| API | Purpose |
|---|---|
| `el.animate(keyframes, options)` | Create + play animation; returns `Animation` |
| `options`: `duration`, `delay`, `easing`, `iterations`, `direction`, `fill`, `composite`, `id`, `pseudoElement`, `timeline`, `rangeStart`/`rangeEnd` | Timing and behavior |
| `animation.finished` / `.ready` | Promises |
| `play()`, `pause()`, `reverse()`, `finish()`, `cancel()` | Control |
| `playbackRate`, `updatePlaybackRate(n)` | Speed/direction |
| `currentTime`, `effect.getComputedTiming().progress` | Scrubbing/inspection |
| `commitStyles()` | Write current animated values to inline style |
| `persist()` | Prevent auto-removal of filling animations |
| `document.getAnimations()`, `el.getAnimations({ subtree: true })` | Query running CSS + WAAPI animations |
| `new ScrollTimeline({ source, axis })`, `new ViewTimeline({ subject, axis, inset })` | Scroll-driven (Chromium; Safari 26+) |

### WAAPI vs alternatives
| Need | WAAPI | Motion | GSAP | CSS |
|---|---|---|---|---|
| Zero dependency | ✅ | ❌ | ❌ | ✅ |
| Runtime keyframes | ✅ | ✅ | ✅ | ⚠️ via variables |
| Await completion | ✅ `finished` | ✅ | ✅ | ⚠️ events |
| Springs | ⚠️ `linear()` approx | ✅ | ⚠️ plugins/eases | ⚠️ `linear()` |
| Exit on unmount in React | ⚠️ manual | ✅ AnimatePresence | ⚠️ manual | ⚠️ |
| Compositor acceleration | ✅ | ✅ (partial) | ❌ | ✅ |

## Recommended Workflow
1. Confirm CSS can't do it declaratively. If it can, use CSS.
2. Get a ref to the element, and check reduced motion.
3. Cancel existing animations on the element if restarting.
4. Call `animate` with tokens (duration/easing), and await `finished` if sequencing.
5. Commit the final state via React state or CSS, not via lingering fills.
6. Cancel in cleanup.

## Patterns

### useAnimateOnce hook (React 19)
```tsx
"use client";
import { useCallback, useRef } from "react";

const reduced = () => typeof window !== "undefined" && matchMedia("(prefers-reduced-motion: reduce)").matches;

export function useWaapi<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const run = useCallback(async (keyframes: Keyframe[], options: KeyframeAnimationOptions) => {
    const el = ref.current;
    if (!el || reduced()) return;
    el.getAnimations().forEach(a => a.cancel());
    const anim = el.animate(keyframes, options);
    try { await anim.finished; } catch { /* cancelled */ }
  }, []);
  return { ref, run };
}
```

### Exit-then-remove (list item)
```tsx
"use client";
import { useRef } from "react";

export function RemovableItem({ label, onRemove }: { label: string; onRemove: () => void }) {
  const ref = useRef<HTMLLIElement>(null);
  async function remove() {
    const el = ref.current;
    if (el && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const a = el.animate(
        [{ opacity: 1, transform: "none" }, { opacity: 0, transform: "translateX(-8px)" }],
        { duration: 150, easing: "cubic-bezier(0.23,1,0.32,1)", fill: "forwards" },
      );
      try { await a.finished; } catch { return; }
    }
    onRemove(); // React removes the node; fill no longer matters
  }
  return <li ref={ref}>{label} <button onClick={remove} aria-label={`Remove ${label}`}>×</button></li>;
}
```
The remaining siblings snap up. Pair with layout animations (Motion `layout`, `<ViewTransition>`) if they should move smoothly.

### Ref callback with cleanup (React 19)
```tsx
<div
  ref={(el) => {
    if (!el || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const a = el.animate([{ opacity: 0, transform: "translateY(8px)" }, { opacity: 1, transform: "none" }],
      { duration: 250, easing: "cubic-bezier(0.23,1,0.32,1)", fill: "backwards" });
    return () => a.cancel();
  }}
/>
```

### commitStyles for persistent end state
```ts
const a = el.animate({ transform: "translateX(200px)" }, { duration: 300, easing: "ease-out", fill: "forwards" });
await a.finished;
a.commitStyles(); // writes transform inline
a.cancel();       // frees the filling animation
```
In React, prefer setting the final style via state/className instead of inline commits that React doesn't know about.

### Spring-like easing with linear()
```ts
const springEasing = "linear(0, 0.35 8%, 0.82 18%, 1.03 28%, 1.06 35%, 1.02 48%, 1 100%)";
el.animate({ transform: ["scale(0.95)", "scale(1)"] }, { duration: 400, easing: springEasing });
```

### Scroll-linked via ViewTimeline (enhancement)
```tsx
useEffect(() => {
  const el = ref.current;
  if (!el || !("ViewTimeline" in window) || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const a = el.animate({ opacity: [0, 1], transform: ["translateY(16px)", "none"] }, {
    fill: "both",
    // @ts-expect-error — ViewTimeline/range options may be missing from lib.dom in your TS version
    timeline: new ViewTimeline({ subject: el }), rangeStart: "entry 0%", rangeEnd: "entry 80%",
  });
  return () => a.cancel();
}, []);
```

### Reduced-motion kill switch for tests/demos
```ts
document.getAnimations().forEach(a => a.finish());
```

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| `fill: "forwards"` as permanent state | Animations accumulate; style conflicts; memory | Set final state in React/CSS, or `commitStyles` + `cancel` |
| No cleanup on unmount | Animations on detached nodes, warnings | `cancel()` in cleanup |
| Not catching `finished` rejection | Unhandled promise rejection on cancel | `try/catch` |
| Restarting without cancelling previous | Stacked, jumping animations | `getAnimations().forEach(a => a.cancel())` |
| Default `linear` easing | Mechanical | Token easings |
| Animating `width/height/left` | Main-thread layout | Transform |
| Calling `document.startViewTransition` in React trees | Conflicts with React | `<ViewTransition>` callbacks |
| Reading layout inside per-frame WAAPI updates | Forced layout | Precompute keyframes |

## Accessibility
- Check `prefers-reduced-motion` before starting animations. Unlike CSS, a media query won't stop JS-started animations automatically.
- Don't delay focus moves or announcements until animation completion; do them immediately.
- When removing items after exit animations, keep focus on a logical next element (the next item or the list heading).
- WCAG 2.2.2: infinite `iterations: Infinity` animations need pause controls or must be essential.

## Responsive Design
- Compute distances from element or container sizes at animation time, not hard-coded pixels.
- Re-run or cancel scroll-linked animations on container resize if keyframes depend on dimensions.
- Gate hover-triggered animations to fine pointers.

## Performance
- Transform/opacity WAAPI animations run on the compositor and stay smooth under main-thread load.
- Filling animations are auto-removed when replaced (the "replace" event) unless `persist()` is called; avoid `persist()`.
- `commitStyles()` forces style computation. Call it once at the end, not per frame.
- Hundreds of simultaneous animations cost memory; use CSS variable-driven or grouped animations.

## Security
- No specific concerns. Keyframe values derived from user input should be validated (numbers, not arbitrary strings).

## Testing
- jsdom lacks WAAPI. Guard `el.animate` existence (`typeof el.animate === "function"`) or mock it in unit tests.
- Playwright: `await page.evaluate(() => Promise.all(document.getAnimations().map(a => a.finished)))` to wait deterministically before assertions.
- Emulate reduced motion and assert that no animations were created (`document.getAnimations().length === 0` for the component).
- DevTools Animations panel shows WAAPI animations, and the `id` option labels them.

## Tooling
- Native browser API (Baseline; scroll timeline constructors: Chromium, Safari 26+; not Firefox release).
- Motion `animate`/`useAnimate` from `motion/react-mini` (~2.3KB) — ergonomic WAAPI wrapper (Active).
- TypeScript `lib.dom` types (newer timeline options may need `@ts-expect-error` depending on TS version).
- Chrome DevTools Animations panel.

## Framework Notes
- **React (Vite SPA)**: use refs plus `useEffect`/`useLayoutEffect` (use layout effect for FLIP measuring before paint). React 19 ref callbacks can return cleanup functions, which suits mount animations. Keep the animation's final state reflected in React state so re-renders don't snap back.
- **Next.js App Router**: WAAPI touches the DOM, so components must be `"use client"`. Don't start animations during render (SSR has no DOM). Server-rendered HTML shows the final state, and effects run after hydration; use `fill: "backwards"` with an initial keyframe for entrances, but expect a brief flash of the final state before hydration. For above-the-fold entrances, prefer CSS `@starting-style`. Use `<ViewTransition onEnter/onExit>` callbacks (instance.old/new/group are animatable targets) for route-level imperative control.
- **Hydration flashes**: avoid hiding server HTML with inline styles that only WAAPI later reveals. If JS fails or is slow, content stays hidden.

## AI Agent Guidance
- DO feature-detect, check reduced motion, cancel previous animations, and clean up.
- DO await `finished` with try/catch for sequencing.
- DO keep React state as the final source of truth.
- DON'T use lingering `fill: "forwards"` as state; DON'T animate layout properties.
- Verify: no unhandled promise rejections on rapid interactions/unmounts; reduced motion creates no animations; TypeScript compiles; animations visible in DevTools with ids.

## Examples

### Shake on invalid submit
```tsx
"use client";
import { useRef } from "react";

export function ShakeOnError({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const shake = () => {
    const el = ref.current;
    if (!el || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    el.getAnimations().forEach(a => a.cancel());
    el.animate({ transform: ["translateX(0)", "translateX(-4px)", "translateX(4px)", "translateX(-2px)", "translateX(0)"] },
      { duration: 320, easing: "ease-in-out", id: "form-shake" });
  };
  return <div ref={ref} onInvalidCapture={shake}>{children}</div>;
}
```

## Related Skills
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md) — declarative counterpart
- [view-transitions-api](../view-transitions-api/Skill.md) — `onEnter`/`onExit` WAAPI callbacks
- [layout-animations](../layout-animations/Skill.md) — FLIP with WAAPI
- [motion-for-react](../motion-for-react/Skill.md) — higher-level wrapper
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md) — refs and cleanup
- [scroll-driven-animations](../scroll-driven-animations/Skill.md) — ScrollTimeline/ViewTimeline
- [animation-performance](../animation-performance/Skill.md) — compositor behavior
- [browser-apis-in-react](../browser-apis-in-react/Skill.md) — using platform APIs safely in React

## Sources
- [MDN Web Animations API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Animations_API) — Official — API surface, Animation interface
- [MDN Element.animate()](https://developer.mozilla.org/en-US/docs/Web/API/Element/animate) — Official — options incl. pseudoElement, timeline, ranges
- [React ViewTransition reference](https://react.dev/reference/react/ViewTransition) — Official — WAAPI callbacks with cleanup
- [Motion: reduce bundle size (useAnimate mini)](https://motion.dev/docs/react-reduce-bundle-size) — Official — WAAPI-only 2.3KB wrapper
- [Motion performance guide](https://motion.dev/docs/performance) — Official — WAAPI hardware acceleration
- [WebKit Safari 26 features](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/) — Official — scroll-driven support

## License / Usage Notes
Web platform API; MDN content (CC-BY-SA) summarized, not copied. Code original.

## Quality Tier
A — Stable Baseline API. The ViewTimeline range options and TypeScript lib typings vary by version, and the MDN pages were referenced from established knowledge rather than fetched this session.

## Status
Active

## Last Verified
2026-09-15
