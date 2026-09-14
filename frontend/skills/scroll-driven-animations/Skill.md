# Scroll-Driven Animations

## Summary
CSS scroll-driven animations link a `@keyframes` animation's progress to a scroll position (`animation-timeline: scroll()`) or to an element's visibility within a scrollport (`animation-timeline: view()`) instead of time. They run off the main thread in supporting engines, need zero JS, and replace many IntersectionObserver and scroll-listener effects. As of September 2026 they ship in Chromium (115+) and Safari (26.0+), while Firefox still has them behind a flag in release builds. They're a progressive enhancement; in React/Next.js they can live entirely in CSS from Server Components.

## Category
Animation

## Subcategories
Scroll progress timelines, view progress timelines, animation-range, reveal-on-scroll, parallax, scroll-triggered animations, ScrollTimeline JS API

## Problem It Solves
Scroll effects built with `scroll` listeners or IntersectionObserver + state updates cause main-thread jank, re-renders in React, and hydration dependencies. Native scroll timelines stay smooth while JS is busy and ship no JS bundle.

## When To Use
- Reading progress bars, header shrink/shadow on scroll, scroll-linked hero fades.
- Reveal-on-enter effects for cards/images (`view()` with `animation-range: entry`).
- Subtle parallax on decorative layers.
- Carousel/scroller item scaling or snapping indicators within a horizontal scroll container.
- Marketing pages in Next.js where you want scroll polish without client components.

## When Not To Use
- Pinning, horizontal-scroll storytelling, or complex timelines with callbacks: use GSAP ScrollTrigger.
- Effects that must work identically in Firefox today without fallback: use IntersectionObserver or Motion `useScroll`.
- Content-critical visibility. Never make content depend on a scroll animation to become visible in unsupported browsers.
- Scroll-jacking or heavy parallax on the main content (accessibility risk).

## Core Principles
1. Progressive enhancement: wrap in `@supports (animation-timeline: view())`. Without support, content renders in its final state.
2. Declare `animation-timeline` after the `animation` shorthand (the shorthand resets it to `auto`).
3. Use `linear` easing (or none) for scroll-scrubbed effects. Use keyframe percentages for shaping.
4. Animate only `transform`, `opacity`, `clip-path`, and `filter` (sparingly) to stay compositor-driven.
5. Gate motion under `@media (prefers-reduced-motion: no-preference)`.
6. Use `animation-fill-mode: both` so start and end states hold outside the range.

## Best Practices
- Use `animation-range: entry 0% entry 100%` (or `entry 10% cover 30%`) for reveals so items finish animating once they're in view.
- Keep reveal distances small (8–24px) and pair them with opacity.
- For named timelines consumed outside the subject's subtree, hoist them with `timeline-scope` on a common ancestor.
- Prefer `view()` on the element itself over tracking the document scroll for per-item effects.
- For "animate once" behavior (no reverse on scroll up), scroll-driven isn't the right tool. Use scroll-triggered animations (`animation-trigger`, Chrome 145+) or IntersectionObserver with a class.
- Avoid applying scroll timelines to hundreds of elements; batch visual effects at the section level.
- Test on real devices, since mobile dynamic toolbars change scrollport size.

## Implementation Guidance

### Support snapshot (Sept 2026)
| Engine | Scroll-driven (`scroll()`/`view()`/`animation-range`) | Scroll-triggered (`animation-trigger`) |
|---|---|---|
| Chrome/Edge | 115+ | 145+ |
| Safari (macOS/iOS) | 26.0+ (threaded in 26.4) | Not yet |
| Firefox | Behind `layout.css.scroll-driven-animations.enabled` (on in Nightly) | Not yet |

### Timeline types
| Timeline | Syntax | Progress 0→100% |
|---|---|---|
| Scroll progress (anonymous) | `scroll(block nearest)` / `scroll(root)` | Scroll container start → end |
| View progress (anonymous) | `view()` / `view(block 20% 10%)` | Subject enters → fully exits scrollport (with insets) |
| Named scroll | `scroll-timeline: --list y` + `animation-timeline: --list` | Named container |
| Named view | `view-timeline: --card` + `animation-timeline: --card` | Named subject |

### animation-range keywords
| Range | Meaning | Typical use |
|---|---|---|
| `cover` | First pixel enters → last pixel leaves | Parallax |
| `contain` | Fully visible span | Hold states |
| `entry` | Entering the scrollport | Reveal-in |
| `exit` | Leaving the scrollport | Fade-out |
| `entry-crossing` / `exit-crossing` | Crossing edges | Fine control |

### Decision table
| Effect | Tool |
|---|---|
| Progress bar, header shadow | CSS `scroll()` |
| Card reveal (reversible OK) | CSS `view()` + `animation-range: entry` |
| Reveal once, cross-browser | IntersectionObserver hook or Motion `whileInView` |
| Pinned sections, scrub sequences | GSAP ScrollTrigger |
| Scroll value needed in React logic | Motion `useScroll` |

## Recommended Workflow
1. Build the static page. Content must be complete and visible without animation.
2. Write keyframes describing the effect from 0% to 100%.
3. Attach the timeline inside `@supports` and `prefers-reduced-motion: no-preference`.
4. Tune `animation-range` in DevTools (Chrome's Animations panel shows scroll timelines).
5. Verify in Safari 26+, Chrome, and Firefox (no animation, content visible).
6. Profile scrolling in the Performance panel; there should be no main-thread work per frame.

## Patterns

### Reading progress bar
```css
@supports (animation-timeline: scroll()) {
  @media (prefers-reduced-motion: no-preference) {
    .progress {
      position: fixed; inset: 0 0 auto; height: 3px; transform-origin: 0 50%;
      background: currentColor;
      animation: grow linear both;
      animation-timeline: scroll(root block);
    }
  }
}
@keyframes grow { from { scale: 0 1; } to { scale: 1 1; } }
```

### Reveal on entry
```css
@supports (animation-timeline: view()) {
  @media (prefers-reduced-motion: no-preference) {
    .reveal {
      animation: reveal linear both;
      animation-timeline: view();
      animation-range: entry 0% entry 80%;
    }
  }
}
@keyframes reveal { from { opacity: 0; translate: 0 16px; } }
```

### Sticky header shadow after 80px
```css
@supports (animation-timeline: scroll()) {
  .site-header {
    animation: elevate linear both;
    animation-timeline: scroll(root);
    animation-range: 0 80px;
  }
}
@keyframes elevate { to { box-shadow: 0 1px 0 rgb(0 0 0 / .08), 0 8px 24px rgb(0 0 0 / .06); } }
```
`box-shadow` repaints. For large headers, animate the opacity of a `::after` shadow layer instead.

### Horizontal carousel item focus effect
```css
.carousel { overflow-x: auto; scroll-snap-type: x mandatory; }
.carousel > li {
  scroll-snap-align: center;
  animation: focus linear both;
  animation-timeline: view(inline);
}
@keyframes focus {
  0%, 100% { scale: 0.9; opacity: 0.6; }
  50% { scale: 1; opacity: 1; }
}
```

### Named timeline shared with a sibling (timeline-scope)
```css
.gallery { timeline-scope: --strip; }
.strip { scroll-timeline: --strip inline; overflow-x: auto; }
.strip-indicator { animation: grow linear both; animation-timeline: --strip; }
```

### Scroll-triggered (Chrome 145+, enhancement only)
```css
.badge {
  timeline-trigger: --t view() entry 100% exit 0%;
  animation: pop 300ms cubic-bezier(0.23,1,0.32,1) both;
  animation-trigger: --t play-forwards play-backwards;
}
```
Treat this as experimental and verify syntax against current MDN before shipping.

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| `animation-timeline` declared before `animation` shorthand | Reset to `auto`; plays on time | Declare after shorthand or use longhands |
| Hiding content in base styles (`opacity: 0`) with animation to reveal | Invisible in Firefox/unsupported | Put the hidden state only in keyframes `from` inside `@supports` |
| Ease-out easing on scrubbed animations | Nonlinear, feels detached from scroll | `linear`; shape with keyframe stops |
| Animating `height`/`top` on scroll | Main-thread layout; loses off-thread benefit | `transform`/`scale` |
| Parallax on main content/text | Vestibular trigger, reading difficulty | Decorative layers only, small offsets, reduced-motion off |
| Scroll listener + `setState` in React | Re-render per scroll event | CSS timelines or Motion `useScroll` |
| Expecting "play once" from view() | Reverses on scroll up | IntersectionObserver class or `animation-trigger` |

## Accessibility
- WCAG 2.3.3: scroll-linked motion is interaction-triggered. Disable it under `prefers-reduced-motion: reduce`, especially parallax and zoom.
- Never let animation delay readability. Text should reach full opacity early in the entry range, not at `cover 50%`.
- Don't hijack scroll speed or direction. Native scrolling, keyboard (Space/PageDown), and find-in-page must keep working.
- Content that animates in must be present in the DOM and the accessibility tree regardless of animation state.

## Responsive Design
- `view()` insets can use percentages; they adapt to scrollport height.
- Mobile dynamic toolbars change `scroll(root)` range while scrolling. Prefer `view()` for per-element effects on mobile.
- Disable parallax on small or coarse-pointer devices with media queries.
- Horizontal scroller timelines (`view(inline)`) work well for touch carousels. Pair them with `scroll-snap`.

## Performance
- In Chromium and Safari 26.4+, scroll-driven animations of compositor-friendly properties run off the main thread. They stay smooth during React hydration or heavy JS.
- Non-compositor properties (colors, `box-shadow`, `background-position`) still need main-thread style and paint per frame.
- Many timeline subjects (hundreds of `view()` elements) add style/update cost. Apply them to sections, or use `content-visibility: auto` for offscreen regions.
- No JS means no bundle cost and no hydration dependency, which is good for LCP and INP.

## Security
- No specific concerns.

## Testing
- Playwright: scroll with `page.mouse.wheel` or `element.scrollIntoViewIfNeeded()`, then assert computed styles via `getComputedStyle` in Chromium/WebKit. In Firefox, assert content is visible (fallback).
- Visual regression at defined scroll positions, with reduced motion both on and off.
- JS: `el.getAnimations()[0].timeline` is a `ScrollTimeline`/`ViewTimeline` in supporting engines, which is useful for feature assertions.
- Cross-browser matrix: Chrome, Safari 26, Firefox release.

## Tooling
- Chrome DevTools Animations panel (scroll timelines).
- scroll-driven-animations.style (Bramus) demos and range visualizer (Community).
- `ScrollTimeline`/`ViewTimeline` JS constructors for WAAPI (`element.animate(keyframes, { timeline: new ViewTimeline({ subject }) })`).
- Polyfill (flackr/scroll-timeline) exists but is heavy and main-thread; generally not recommended when a static fallback is acceptable.

## Framework Notes
- **React (Vite SPA)**: write effects in CSS/CSS Modules/Tailwind arbitrary properties. No hooks are needed. For JS-based timelines use `useEffect` with `element.animate(..., { timeline: new ViewTimeline({ subject: ref.current! }) })`, guarded by `"ViewTimeline" in window`, and cancel on cleanup.
- **Next.js App Router**: pure CSS works in Server Components with no `"use client"`, and there are no hydration flashes because effects apply from first paint of server HTML. Put keyframes in `globals.css` or a CSS Module. Inline styles in TSX need camelCase and a TS escape: `style={{ animationTimeline: "view()" } as React.CSSProperties}`. Custom properties like `animationRange` may need a cast depending on `csstype` version.
- **Tailwind v4**: use arbitrary properties such as `[animation-timeline:view()]` and `[animation-range:entry_0%_entry_80%]` plus `supports-[animation-timeline:view()]:` variants, or a small `@utility` definition.
- **Motion for React alternative**: `useScroll({ target, offset: ["start end", "end start"] })` + `useTransform` for cross-browser JS scroll effects without re-renders. Motion also accelerates `useScroll` via native ScrollTimeline where available.

## AI Agent Guidance
- DO wrap in `@supports (animation-timeline: view())` and `prefers-reduced-motion: no-preference`.
- DO keep content visible by default; hidden states live only in keyframes.
- DO prefer CSS over scroll listeners in React components.
- DON'T claim Firefox support. It is flag-only in release as of September 2026.
- DON'T use this for pinning/storytelling; recommend GSAP.
- Verify: Chrome and Safari animate; Firefox shows static content; reduced motion shows static content; no layout properties animated; TypeScript compiles for inline style usage.

## Examples

### Reusable TSX reveal wrapper (Server Component)
```tsx
// components/scroll-reveal.tsx
import styles from "./scroll-reveal.module.css";

export function ScrollReveal({ as: Tag = "div", children }: { as?: React.ElementType; children: React.ReactNode }) {
  return <Tag className={styles.reveal}>{children}</Tag>;
}
```
```css
/* scroll-reveal.module.css */
@supports (animation-timeline: view()) {
  @media (prefers-reduced-motion: no-preference) {
    .reveal { animation: reveal linear both; animation-timeline: view(); animation-range: entry 0% entry 70%; }
  }
}
@keyframes reveal { from { opacity: 0; translate: 0 16px; } }
```

### Cross-browser fallback hook for "reveal once"
```tsx
"use client";
import { useEffect, useRef, useState } from "react";

export function useRevealOnce<T extends Element>() {
  const ref = useRef<T>(null);
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el || shown) return;
    const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) { setShown(true); io.disconnect(); } }, { threshold: 0.2 });
    io.observe(el);
    return () => io.disconnect();
  }, [shown]);
  return { ref, shown };
}
```

## Related Skills
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md) — keyframes fundamentals
- [gsap-animation](../gsap-animation/Skill.md) — ScrollTrigger for pinning/scrub sequences
- [motion-for-react](../motion-for-react/Skill.md) — `useScroll` JS alternative
- [animation-performance](../animation-performance/Skill.md) — compositor-driven animation
- [landing-page-design](../landing-page-design/Skill.md) — typical use context
- [carousels](../carousels/Skill.md) — scroll-snap carousel effects
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — parallax risks
- [progressive-enhancement](../progressive-enhancement/Skill.md) — `@supports` strategy

## Sources
- [MDN animation-timeline](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/animation-timeline) — Official — values, shorthand reset caveat
- [WebKit: guide to scroll-driven animations](https://webkit.org/blog/17101/a-guide-to-scroll-driven-animations-with-just-css/) — Official — Safari support, patterns
- [WebKit features in Safari 26.0](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/) — Official — shipping confirmation
- [MDN Firefox experimental features](https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Experimental_features) — Official — Firefox flag status
- [Chrome: CSS scroll-triggered animations](https://developer.chrome.com/blog/scroll-triggered-animations) — Official — animation-trigger, Chrome 145
- [Cyd Stumpel: Start using scroll-driven animations today](https://cydstumpel.nl/start-using-scroll-driven-animations-today/) — Community — progressive enhancement approach

## License / Usage Notes
Spec and docs content summarized; examples original.

## Quality Tier
A — Official sources verified. The Firefox flag status comes from MDN's experimental features page, and the scroll-triggered syntax is new and may change.

## Status
Active (scroll-triggered sub-feature: Experimental)

## Last Verified
2026-09-15
