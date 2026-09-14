# Animation Performance

## Summary
Smooth animation means producing every frame within the display's budget (~16.7ms at 60Hz, ~8.3ms at 120Hz) without hurting Core Web Vitals. This skill covers the rendering pipeline (style → layout → paint → composite), which properties are compositor-only, when `will-change` helps or hurts, main-thread vs off-thread animation engines (CSS/WAAPI vs rAF JS), React-specific pitfalls (re-render per frame, hydration contention), and how to profile animation jank in Chrome DevTools for React and Next.js apps.

## Category
Animation

## Subcategories
Rendering pipeline, compositor properties, layer management, main-thread contention, React re-renders, INP/CLS interactions, profiling, battery and low-end devices

## Problem It Solves
Animations that look fine on a developer MacBook stutter on mid-range Android phones. Layout-triggering properties, per-frame React state updates, excessive layers, and animations competing with hydration all cause dropped frames, poor INP, and battery drain.

## When To Use
- Reviewing or implementing any animation in a React/Next.js codebase.
- Diagnosing jank reports, poor INP near animated interactions, or high GPU memory.
- Choosing between CSS, WAAPI, Motion, GSAP, and view transitions for a heavy effect.
- Setting design-system rules for animatable properties.

## When Not To Use
- Static UI with no motion.
- WebGL render loop optimization in depth (see 3d-web-three-and-r3f), though the principles overlap.

## Core Principles
1. Animate compositor-only properties: `transform` (and individual `translate`/`scale`/`rotate`) and `opacity`. `filter` and `clip-path` are often accelerated but cost more on large areas.
2. Never animate layout properties (`width`, `height`, `top`, `left`, `margin`, `padding`, `font-size`) per frame.
3. Prefer off-main-thread engines (CSS animations/transitions, WAAPI, scroll-driven animations) for simple effects. They survive busy JS.
4. Never drive per-frame values through React state. Use refs, motion values, CSS variables on a single element, or WAAPI.
5. Read layout before writing styles; never interleave in loops (avoid forced synchronous layout).
6. Layers cost memory: promote deliberately and briefly.
7. Measure on target hardware (4–6x CPU throttle, real mid-range device) before and after.

## Best Practices
- Replace `box-shadow` animation with opacity on a pseudo-element that holds the shadow.
- Replace `border-radius` or size animation with `clip-path: inset(... round ...)` or scale plus counter-scale.
- Use `will-change: transform` just before an animation (e.g. on hover/pointerdown) and remove it after. Avoid static `will-change` on many elements.
- Pause offscreen or hidden animations: `animation-play-state: paused` via IntersectionObserver, `content-visibility: auto`, and `document.visibilitychange`.
- Cap infinite animations. Spinners are fine; decorative loops should stop after a few iterations or when offscreen.
- Keep `filter: blur()` radii small (≤ 20px) and areas small. `backdrop-filter` on large fixed headers is expensive during scroll.
- Avoid animating many elements with individual JS tweens; use a single CSS variable or a stagger via `animation-delay`.
- Delay non-critical entrance animations until after hydration and idle on Next.js pages, or use CSS so they don't compete with hydration.
- Transform-based animations don't cause CLS, whereas layout property animations can.

## Implementation Guidance

### Property cost table
| Property | Pipeline stages | Verdict |
|---|---|---|
| `transform`, `translate`, `scale`, `rotate` | Composite | ✅ Preferred |
| `opacity` | Composite | ✅ Preferred |
| `filter` (blur, brightness) | Paint/composite (often GPU) | ⚠️ Small areas |
| `clip-path` | Paint (accelerated in modern Chromium for some shapes) | ⚠️ OK for reveals |
| `background-color`, `color` | Paint | ⚠️ Fine for small elements |
| `box-shadow` | Paint | ❌ Use pseudo-element opacity |
| `width`, `height`, `top`, `left`, `margin`, `padding` | Layout + paint | ❌ Avoid (FLIP instead) |
| `grid-template-rows` (0fr→1fr) | Layout | ⚠️ Small panels only |
| CSS custom property (unregistered) on a big subtree | Style recalc of all dependents | ❌ Scope narrowly |

### Engine threading
| Engine | Runs on | Survives busy main thread? |
|---|---|---|
| CSS transitions/animations (transform/opacity) | Compositor | Yes |
| WAAPI `element.animate` (transform/opacity) | Compositor | Yes |
| Scroll-driven animations (Chromium, Safari 26.4+) | Compositor | Yes |
| View transitions pseudo-element animations | Compositor | Yes (after snapshot) |
| Motion (`opacity`, full `transform`, `filter`, `clipPath` via WAAPI) | Compositor | Yes |
| Motion independent transforms (`x`, `scale`), springs on JS | Main thread rAF | No |
| GSAP | Main thread rAF | No |
| React state per frame | Main thread + reconciliation | No (worst) |

### Frame budget
| Refresh rate | Budget per frame | Practical JS budget |
|---|---|---|
| 60Hz | 16.7ms | ~10ms |
| 90Hz | 11.1ms | ~6ms |
| 120Hz | 8.3ms | ~4ms |

## Recommended Workflow
1. Check properties: are only transform/opacity animated? Refactor others.
2. Check engine: can it run on CSS/WAAPI instead of rAF JS?
3. Check React: does anything call `setState` per frame, on scroll, or on pointermove?
4. Profile: Chrome DevTools Performance panel, CPU 4x/6x throttle, record the interaction.
   - Look for purple (Layout/Recalculate Style) and green (Paint) blocks during animation frames.
   - Enable Rendering → Paint flashing, Layer borders, and the Frame Rendering Stats FPS meter.
   - Use the Layers panel to find layer explosions and memory.
5. Check Long Animation Frames (LoAF) in RUM for real-user jank attribution.
6. Fix, re-profile, and verify on a real mid-range Android phone and a Safari iPhone.

## Patterns

### Shadow via pseudo-element
```css
.card { position: relative; transition: translate 200ms var(--ease-out); }
.card::after {
  content: ""; position: absolute; inset: 0; border-radius: inherit;
  box-shadow: 0 12px 32px rgb(0 0 0 / .15); opacity: 0; transition: opacity 200ms var(--ease-out);
}
@media (hover: hover) { .card:hover { translate: 0 -2px; } .card:hover::after { opacity: 1; } }
```

### Per-frame value without re-render (React)
```tsx
"use client";
import { useEffect, useRef } from "react";

export function Spotlight() {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current!;
    let raf = 0, x = 0, y = 0;
    const onMove = (e: PointerEvent) => {
      x = e.clientX; y = e.clientY;
      if (!raf) raf = requestAnimationFrame(() => {
        el.style.transform = `translate3d(${x}px, ${y}px, 0)`;
        raf = 0;
      });
    };
    window.addEventListener("pointermove", onMove, { passive: true });
    return () => { window.removeEventListener("pointermove", onMove); cancelAnimationFrame(raf); };
  }, []);
  return <div ref={ref} aria-hidden className="pointer-events-none fixed left-0 top-0 size-64 -translate-1/2 rounded-full bg-white/10 blur-2xl" />;
}
```
Motion's `useMotionValue` + `useSpring` achieves the same with less code.

### Pause offscreen animations
```tsx
"use client";
import { useEffect, useRef } from "react";

export function usePauseOffscreen<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => {
      el.style.animationPlayState = e.isIntersecting ? "running" : "paused";
    });
    io.observe(el);
    return () => io.disconnect();
  }, []);
  return ref;
}
```

### Batch reads then writes
```ts
const rects = items.map(el => el.getBoundingClientRect()); // read all
items.forEach((el, i) => { el.style.transform = `translateY(${-rects[i].height}px)`; }); // write all
```

### Temporary will-change
```tsx
<button
  onPointerEnter={e => (e.currentTarget.style.willChange = "transform")}
  onTransitionEnd={e => (e.currentTarget.style.willChange = "auto")}
/>
```

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| `setState` in scroll/pointermove handlers for visuals | Reconciliation per event | Refs + rAF, motion values, CSS scroll timelines |
| `* { will-change: transform }` or on every card | GPU memory explosion, slower | Apply briefly to active elements |
| Animating `height` for accordions on complex content | Layout per frame | Grid-rows on light content, FLIP, or snap |
| `transition: all` | Unexpected layout/paint animations | Explicit properties |
| Large `backdrop-filter` on sticky headers + scroll | Expensive repaint each frame | Solid/semi-opaque background, smaller blur |
| JS entrance animations during Next.js hydration | Competes with hydration; jank and delayed INP | CSS entrances, or defer until idle |
| Infinite decorative loops offscreen | Battery, CPU | Pause offscreen, limit iterations |
| `getBoundingClientRect` inside animation loop after writes | Forced synchronous layout | Read once before writes |
| Animating an unregistered CSS variable on `:root` | Restyles entire document | Set on the animated element; `@property` |
| Lottie JSON (SVG renderer) for large looping hero | Heavy main-thread/paint | dotLottie canvas/WASM, video, or CSS |

## Accessibility
- Reduced motion also reduces CPU/GPU load; honor `prefers-reduced-motion` (WCAG 2.3.3).
- Janky motion is worse than none for vestibular users; if an effect can't be made smooth on low-end devices, remove it there.
- Don't block input during animations. Long animations that hold `pointer-events: none` hurt usability and INP perception.

## Responsive Design
- Low-end mobile is the performance baseline. Gate heavy effects with `matchMedia("(prefers-reduced-motion: no-preference)")` and capability heuristics (`navigator.hardwareConcurrency <= 4`, `navigator.connection?.saveData`), used conservatively.
- High-refresh displays (120Hz) halve the budget. rAF-driven animations must be cheaper.
- Reduce blur radii, particle counts, and parallax layers on small screens.

## Performance
- CLS: animations using `transform` are excluded from layout shift scoring. Animating `top`/`height` that moves other content counts.
- INP: an animation starting in an event handler should not do heavy synchronous work first. Update visual state, then defer computation (`startTransition`, `scheduler.yield()` where supported).
- LCP: don't hide the LCP element with `opacity: 0` pending a JS animation; LCP waits for it to become visible.
- Memory: every composited layer holds a texture (width × height × 4 bytes × DPR²). A full-screen layer on a 3x DPR phone costs tens of MB.
- The React Compiler reduces unnecessary re-renders but doesn't make per-frame state updates acceptable.

## Security
- No specific concerns.

## Testing
- Chrome DevTools Performance panel with CPU throttle. Save traces for before/after comparison.
- Lighthouse / PageSpeed: check TBT and CLS on pages with entrance animations.
- RUM: Long Animation Frames API (`PerformanceObserver` type `long-animation-frame`) plus `web-vitals` attribution for INP.
- Playwright: `page.evaluate` with `performance.now()` sampling is noisy. Prefer trace-based checks in CI (`tracing.start` in Chromium) for regression spotting.
- React Profiler: confirm zero component renders during a running animation.

## Tooling
- Chrome DevTools: Performance, Rendering (Paint flashing, Layer borders, FPS), Layers, Animations panels.
- Safari Web Inspector Timelines (Layout & Rendering) for iOS.
- `web-vitals` library with attribution (Active).
- React DevTools Profiler, with "Highlight updates when components render".
- Motion's docs list of accelerated values; GSAP's `gsap.ticker.fps()` for debugging only.

## Framework Notes
- **React (Vite SPA)**: keep animated leaf components memo-stable. Avoid context values that change per frame (every consumer re-renders). Use refs and CSS variables on the element itself.
- **Next.js App Router**: prefer CSS animations in Server Components for above-the-fold motion. There's no hydration dependency or JS cost. Lazy-load heavy animation components (`next/dynamic`) below the fold. Don't run GSAP/Motion entrance timelines on the LCP element. Route transitions via `<ViewTransition>` are compositor-driven after the snapshot, but the navigation commit must be fast (prefetch).
- **Hydration flashes**: client-side animation libraries apply start states after hydration, which causes flicker. Server HTML with `opacity: 0` inline styles (Motion `initial`) delays visible content until JS runs. Both hurt perceived performance. Use CSS entrances or disable `initial` for server-visible content.

## AI Agent Guidance
- DO audit every animation for property cost using the table.
- DO move per-frame updates out of React state.
- DO add offscreen pausing for loops and heavy canvases.
- DON'T add global `will-change`; DON'T animate layout properties; DON'T hide LCP elements for animation.
- Verify: DevTools trace shows no layout/paint per frame during the animation; React Profiler shows no renders during animation; CLS unchanged; test at 4x CPU throttle.

## Examples

### Motion value-driven parallax without renders
```tsx
"use client";
import { motion, useScroll, useTransform, useReducedMotion } from "motion/react";
import { useRef } from "react";

export function ParallaxImage({ src, alt }: { src: string; alt: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start end", "end start"] });
  const y = useTransform(scrollYProgress, [0, 1], reduce ? ["0%", "0%"] : ["-8%", "8%"]);
  return (
    <div ref={ref} className="relative aspect-video overflow-hidden">
      <motion.img src={src} alt={alt} style={{ y, scale: 1.2 }} className="absolute inset-0 size-full object-cover" />
    </div>
  );
}
```

## Related Skills
- [rendering-performance](../rendering-performance/Skill.md) — broader rendering pipeline
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md) — trace analysis
- [inp-optimization](../inp-optimization/Skill.md) — interactions and animations
- [cls-prevention](../cls-prevention/Skill.md) — transform vs layout shifts
- [lcp-optimization](../lcp-optimization/Skill.md) — not hiding LCP elements
- [hydration-strategies](../hydration-strategies/Skill.md) — avoiding hydration contention
- [react-performance-optimization](../react-performance-optimization/Skill.md) — re-render control
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md) — compositor-friendly CSS

## Sources
- [web.dev: How to create high-performance CSS animations](https://web.dev/articles/animations-guide) — Official — compositor properties, will-change, DevTools
- [Motion: Web animation performance tier list](https://motion.dev/docs/performance) — Official — WAAPI acceleration, independent transforms, property substitutions
- [MDN transition-behavior / animation references](https://developer.mozilla.org/en-US/docs/Web/CSS/transition-behavior) — Official — property behavior
- [WebKit Safari 26 features](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/) — Official — scroll-driven support context
- [emilkowalski/skills](https://github.com/emilkowalski/skills) — Community — transform/opacity rules, blur limits
- [Chrome Long Animation Frames API](https://developer.chrome.com/docs/web-platform/long-animation-frames) — Official — LoAF for RUM

## License / Usage Notes
Guidance summarized from the cited sources; code original.

## Quality Tier
A — Well-established principles verified against official performance guides. Accelerated-property lists vary by engine and change over time.

## Status
Active

## Last Verified
2026-09-15
