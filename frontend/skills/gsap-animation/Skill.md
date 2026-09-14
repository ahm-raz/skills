# GSAP Animation

## Summary
GSAP (GreenSock Animation Platform) is a JavaScript animation engine known for precise timelines, robust cross-browser behavior, and a large plugin ecosystem (ScrollTrigger, Flip, SplitText, MorphSVG, DrawSVG, Draggable, Observer). Webflow acquired GreenSock in October 2024. Since the 3.13 release (April 2025), all of GSAP, including the formerly paid "Club" plugins, has been free for commercial use under the GSAP Standard License. As of September 2026 the docs cover v3.15. In React and Next.js, integrate it through `@gsap/react`'s `useGSAP` hook inside client components.

## Category
Animation

## Subcategories
Timelines, scroll-triggered animation, ScrollTrigger pinning/scrub, SVG animation, text splitting, FLIP, React/Next.js integration

## Problem It Solves
Choreographed, multi-step, scroll-coupled animation is fragile with CSS alone or with declarative React libraries. Examples include sequences with overlaps, labels, and callbacks; pinned sections that scrub with scroll; SVG morphing; and per-character text reveals. GSAP gives imperative, deterministic control. `useGSAP` adds automatic cleanup that fits React's lifecycle and Strict Mode.

## When To Use
- Marketing and landing pages in Next.js with scroll storytelling (pinning, scrubbing, horizontal scroll sections).
- Complex sequencing: timelines with labels, position parameters (`"<"`, `"-=0.2"`), nested timelines.
- SVG path drawing/morphing, motion along a path, text-splitting effects.
- FLIP transitions across DOM restructures that Motion `layout` handles poorly (e.g. reparenting into a different container).
- Tweening non-DOM values (three.js/R3F uniforms, canvas state).

## When Not To Use
- App UI state transitions (menus, dialogs, toasts): CSS or Motion for React is lighter and declarative.
- Next.js route transitions: use React `<ViewTransition>`.
- Simple scroll progress or reveal effects where CSS scroll-driven animations suffice (with a fallback).
- Where the license doesn't fit: the Standard License is "no charge", not OSI open source, and has restrictions (notably for tools competing with Webflow's visual builder). Review it before bundling GSAP into a site-builder product.

## Core Principles
1. Always scope and clean up: `useGSAP({ scope })` reverts every tween, timeline, and ScrollTrigger it created on unmount.
2. Wrap anything created after the hook runs (event handlers, timeouts) in `contextSafe`.
3. Animate transforms via GSAP aliases (`x`, `y`, `scale`, `rotation`, `autoAlpha`), never `left/top/width`.
4. Build sequences with timelines, not chains of `delay`s.
5. Register plugins once at module scope in a client file: `gsap.registerPlugin(useGSAP, ScrollTrigger)`.
6. Gate motion by media query (reduced motion, breakpoints) with `gsap.matchMedia()` inside `useGSAP`.
7. Every GSAP file in Next.js is a `"use client"` component; keep it a small leaf.

## Best Practices
- Use `autoAlpha` instead of `opacity`; it toggles `visibility: hidden` at 0, removing the element from hit-testing and the accessibility tree.
- Set timeline defaults: `gsap.timeline({ defaults: { duration: 0.4, ease: "power3.out" } })`.
- For scroll scrubbing, use `scrub: true` for a direct link or `scrub: 0.5–1` for smoothing. Use `ease: "none"` inside scrubbed timelines.
- Use `markers: process.env.NODE_ENV === "development"` rather than hard-coded `markers: true`.
- Call `ScrollTrigger.refresh()` after layout-affecting async work (images via `next/image` `onLoad`, fonts via `document.fonts.ready`, streamed Suspense content). Use `invalidateOnRefresh: true` with function-based values.
- Use `ScrollTrigger.batch()` for many reveal items instead of one trigger per element.
- Avoid `normalizeScroll` and ScrollSmoother unless explicitly required; they move scrolling to JS.
- Prevent hydration flicker: hide pre-animated elements with CSS before hydration (see Framework Notes).
- Pass refs, not global selectors. When using selectors, always set `scope`.

## Implementation Guidance

### Install
```bash
npm install gsap @gsap/react
```
All plugins ship in the public `gsap` package (`gsap/ScrollTrigger`, `gsap/Flip`, `gsap/SplitText`). Remove any old private-registry auth for `npm.greensock.com` and the `gsap-trial` package.

### Shared client setup (Next.js)
```tsx
// lib/gsap.ts
"use client";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Flip } from "gsap/Flip";
import { useGSAP } from "@gsap/react";

gsap.registerPlugin(useGSAP, ScrollTrigger, Flip);
export { gsap, ScrollTrigger, Flip, useGSAP };
```
Import from `@/lib/gsap` only in client components so plugins are registered exactly once.

### Ease cheat sheet
| GSAP ease | Rough CSS equivalent | Use |
|---|---|---|
| `power1.out` | `ease-out` | Subtle UI |
| `power3.out` / `expo.out` | `cubic-bezier(0.23,1,0.32,1)` | Entrances, reveals |
| `power2.inOut` | `ease-in-out` | On-screen movement |
| `back.out(1.4)` | overshoot | Playful pops (sparingly) |
| `none` | `linear` | Scrubbed scroll, progress, marquees |

### Tool selection (React/Next.js)
| Need | Choose |
|---|---|
| Scroll-pinned story, horizontal scroll | GSAP ScrollTrigger |
| Simple reveal/progress, zero JS | CSS `animation-timeline: view()` + fallback |
| Presence/exit, layout, gestures in app UI | Motion for React |
| Route transition, shared element across routes | React `<ViewTransition>` |
| Reparenting FLIP, complex SVG | GSAP Flip / MorphSVG |

### useGSAP options
| Option | Purpose |
|---|---|
| `scope` | Ref; selector strings resolve only inside it |
| `dependencies` | Re-run when values change (like `useEffect` deps) |
| `revertOnUpdate` | `true` reverts previous animations on every dependency change (default only on unmount) |

## Recommended Workflow
1. Storyboard the sequence: elements, order, overlaps, scroll ranges.
2. Build the Server Component layout so it's fully readable with no JS.
3. Wrap only the animated section in a `"use client"` component taking `children`.
4. Inside `useGSAP`, create `gsap.matchMedia()` with reduced-motion and breakpoint conditions.
5. Build a timeline per section and attach ScrollTrigger with dev-only markers. Tune `start`/`end`.
6. Test client navigation away and back (no orphaned triggers), resize, late images, and the browser back/forward cache.
7. Profile scroll on a mid-range Android device and check INP and LCP in Lighthouse.

## Patterns

### Scoped entrance with contextSafe handler
```tsx
"use client";
import { useRef } from "react";
import { gsap, useGSAP } from "@/lib/gsap";

export function Hero({ children }: { children: React.ReactNode }) {
  const root = useRef<HTMLDivElement>(null);
  const { contextSafe } = useGSAP(() => {
    gsap.from("[data-word]", { y: 20, autoAlpha: 0, stagger: 0.05, ease: "power3.out" });
  }, { scope: root });

  const pulse = contextSafe(() => {
    gsap.fromTo("[data-cta]", { scale: 0.97 }, { scale: 1, duration: 0.2 });
  });

  return (
    <div ref={root}>
      {children}
      <button data-cta onClick={pulse}>Start</button>
    </div>
  );
}
```

### Pinned horizontal scroll with reduced-motion branch
```tsx
"use client";
import { useRef } from "react";
import { gsap, useGSAP } from "@/lib/gsap";

export function HorizontalScroll({ children }: { children: React.ReactNode }) {
  const section = useRef<HTMLElement>(null);
  const track = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    const mm = gsap.matchMedia();
    mm.add(
      { motionOK: "(prefers-reduced-motion: no-preference)", desktop: "(min-width: 768px)" },
      (ctx) => {
        const { motionOK, desktop } = ctx.conditions as { motionOK: boolean; desktop: boolean };
        const el = track.current;
        if (!motionOK || !desktop || !el) return; // native stacked layout remains
        gsap.to(el, {
          x: () => -(el.scrollWidth - window.innerWidth),
          ease: "none",
          scrollTrigger: {
            trigger: section.current,
            pin: true,
            scrub: 0.5,
            end: () => `+=${el.scrollWidth}`,
            invalidateOnRefresh: true,
            markers: process.env.NODE_ENV === "development",
          },
        });
      },
    );
  }, { scope: section });

  return (
    <section ref={section} className="overflow-hidden">
      <div ref={track} className="flex flex-col gap-6 md:w-max md:flex-row">{children}</div>
    </section>
  );
}
```
`matchMedia` created inside `useGSAP` reverts automatically with the context.

### Batch reveals
```tsx
useGSAP(() => {
  ScrollTrigger.batch("[data-card]", {
    start: "top 85%",
    onEnter: (els) => gsap.to(els, { autoAlpha: 1, y: 0, stagger: 0.06, overwrite: true }),
  });
}, { scope: gridRef });
```

### Flip after a React state change
```tsx
const stateRef = useRef<Flip.FlipState | null>(null);

const toggleView = contextSafe(() => {
  stateRef.current = Flip.getState("[data-item]");
  setView(v => (v === "grid" ? "list" : "grid")); // DOM changes on next commit
});

useGSAP(() => {
  if (!stateRef.current) return;
  Flip.from(stateRef.current, { duration: 0.4, ease: "power2.inOut", absolute: true });
  stateRef.current = null;
}, { dependencies: [view], scope: containerRef });
```
Capture state before `setState` and animate in the hook after commit. Keep stable `key`s so React reuses the DOM nodes.

### SplitText (accessible)
Create `SplitText` inside `useGSAP` with `autoSplit: true` and animate in `onSplit` (which re-splits on font load and resize). SplitText's aria handling keeps a readable `aria-label` on the parent, and the context reverts the split on unmount.

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| `gsap.to` in `useEffect` without cleanup | Duplicated tweens/triggers in Strict Mode and after navigation | `useGSAP` |
| Global selectors without `scope` | Animates other component instances | `scope` ref or refs |
| Handler animations not wrapped in `contextSafe` | Not reverted on unmount; leaks | `contextSafe` |
| GSAP imported in a Server Component | Build error / window undefined | `"use client"` leaf component |
| ScrollTriggers created in `layout.tsx` client children | Persist across routes with stale positions | Create in page-level components |
| `gsap.from()` on server-rendered hero without CSS pre-hide | Content flashes then jumps | Pre-hide via CSS gated by `.js` + motion preference |
| Chained `delay` values | Brittle | Timeline with position params |
| Eased tweens inside scrubbed timeline | Scroll feels laggy | `ease: "none"` |
| Scroll-jacking by default | Breaks native scroll, a11y, find-in-page | Native scroll |
| `ScrollTrigger.refresh()` on every render | Thrashing | Refresh on load/resize/content change |

## Accessibility
- Wrap non-essential motion in `gsap.matchMedia()` with `(prefers-reduced-motion: no-preference)` (WCAG 2.3.3). With reduced motion or no JS, content must be visible in its final state.
- Pinned sections must not trap keyboard users. Tab through them and confirm focus stays visible and nothing is clipped.
- Looping or auto-playing sequences longer than 5s need a pause control (WCAG 2.2.2).
- SplitText: keep the readable string available to assistive tech; letters must not be announced individually.
- Avoid large parallax and zoom, which are vestibular triggers.

## Responsive Design
- Use `gsap.matchMedia()` breakpoints that match the Tailwind/CSS breakpoints. Mobile gets simpler, non-pinned versions.
- Use function-based values plus `invalidateOnRefresh` for viewport-dependent distances.
- Keep `ignoreMobileResize` (default) so address-bar resizes don't trigger refreshes.
- Avoid `100vh` pin lengths; use computed values or `svh`/`dvh`.

## Performance
- GSAP runs on the main thread (requestAnimationFrame) and is not compositor-offloaded. Keep hydration and other JS work off the scroll path, and animate only transform and opacity.
- `next/dynamic` with `ssr: false` can defer heavy GSAP sections below the fold. Core is ~25kb gzip and ScrollTrigger adds ~12kb.
- Limit concurrent ScrollTriggers; use `batch`.
- Use `gsap.quickTo()` for pointer-follow effects instead of creating tweens per event.
- Avoid animating `filter: blur()` on large areas or `box-shadow`.

## Security
- Install from npm with lockfiles. If a CDN is used, pin the version and add SRI.
- CSP: GSAP sets inline `style` via CSSOM, which is allowed under `style-src` without `unsafe-inline` because CSSOM manipulation isn't blocked. Inline `<script>` pre-hide snippets need a nonce in Next.js.

## Testing
- Playwright: emulate `reducedMotion: "reduce"` and assert content is visible. Scroll with `mouse.wheel` and snapshot pinned states. Assert no leaked triggers after client navigation via `page.evaluate(() => (window as any).ScrollTrigger?.getAll().length)` in a debug build.
- Vitest/Testing Library: mock `gsap` or set `gsap.globalTimeline.timeScale(1000)`, and test only resulting state.
- Visual regression: run under reduced motion for determinism.

## Tooling
- `gsap` 3.15 (Active; GSAP Standard License, free incl. commercial) — core plus all plugins.
- `@gsap/react` (Active) — `useGSAP` hook.
- GSDevTools (free) — timeline scrubbing in development.
- Deprecated: `gsap-trial`, private `npm.greensock.com` registry.

## Framework Notes
- **React (Vite SPA)**: `useGSAP` replaces `useEffect`/`useLayoutEffect` for animation. Register plugins once in a shared module. With React Router, create ScrollTriggers in route components, which unmount on navigation, and call `ScrollTrigger.refresh()` after route data and images render.
- **Next.js App Router, `"use client"`**: every file importing `gsap`/`@gsap/react` for DOM work must be a client component. Keep pages and layouts as Server Components that pass `children` into small client animation wrappers. `useGSAP` uses an isomorphic layout effect, so there are no SSR warnings.
- **Hydration flash (FOUC)**: server HTML paints the final state, and after hydration `gsap.from()` snaps elements back to their start, causing a flicker. Pre-hide with CSS:
  ```css
  @media (prefers-reduced-motion: no-preference) {
    html.js [data-reveal] { visibility: hidden; }
  }
  ```
  Add `js` to `<html>` with a tiny inline script in `app/layout.tsx` (nonce it if CSP is strict), then reveal with `autoAlpha`. Never pre-hide the LCP element; animate secondary elements only.
- **Route changes in App Router**: layouts persist across navigation, so triggers created under a layout keep stale measurements. Create them in page-level components, or refresh in an effect keyed on `usePathname()`. Streaming Suspense content changes page height, so refresh after it resolves.
- **Page transitions**: use React `<ViewTransition>` with `Link transitionTypes` for route transitions, and GSAP for in-page choreography. Don't block Next.js navigation to finish a GSAP exit timeline.

## AI Agent Guidance
- DO use `useGSAP` with `scope`; DO wrap handlers in `contextSafe`; DO put `"use client"` at the top of GSAP files.
- DO wrap motion in `gsap.matchMedia()` with a reduced-motion condition inside `useGSAP`.
- DO make markers dev-only.
- DON'T add old Club GSAP registry auth or `gsap-trial`.
- DON'T implement scroll-jacking or smooth-scroll unless explicitly requested.
- DON'T hide the LCP element before hydration.
- Verify before done: no hydration warnings; no flicker on hard reload; triggers correct after resize and client navigation; content visible with reduced motion and with JS disabled.

## Examples

### Timeline with labels (TSX)
```tsx
"use client";
import { useRef } from "react";
import { gsap, useGSAP } from "@/lib/gsap";

export function IntroSequence() {
  const root = useRef<HTMLDivElement>(null);
  useGSAP(() => {
    const mm = gsap.matchMedia();
    mm.add("(prefers-reduced-motion: no-preference)", () => {
      gsap.timeline({ defaults: { ease: "power3.out", duration: 0.5 } })
        .from("[data-nav]", { y: -20, autoAlpha: 0 })
        .from("[data-headline]", { y: 24, autoAlpha: 0 }, "<0.1")
        .add("cta")
        .from("[data-cta]", { scale: 0.95, autoAlpha: 0, duration: 0.3 }, "cta")
        .from("[data-hero-img]", { autoAlpha: 0, duration: 0.8 }, "cta-=0.2");
    });
  }, { scope: root });
  return <div ref={root}>{/* nav, headline, cta, image with data-* attributes */}</div>;
}
```

### Pointer follower with quickTo
```tsx
"use client";
import { useRef } from "react";
import { gsap, useGSAP } from "@/lib/gsap";

export function CursorDot() {
  const dot = useRef<HTMLDivElement>(null);
  useGSAP(() => {
    if (!matchMedia("(pointer: fine) and (prefers-reduced-motion: no-preference)").matches) return;
    const xTo = gsap.quickTo(dot.current, "x", { duration: 0.3, ease: "power3" });
    const yTo = gsap.quickTo(dot.current, "y", { duration: 0.3, ease: "power3" });
    const onMove = (e: PointerEvent) => { xTo(e.clientX); yTo(e.clientY); };
    window.addEventListener("pointermove", onMove, { passive: true });
    return () => window.removeEventListener("pointermove", onMove);
  });
  return <div ref={dot} aria-hidden className="pointer-events-none fixed left-0 top-0 size-3 rounded-full bg-current" />;
}
```

## Related Skills
- [scroll-driven-animations](../scroll-driven-animations/Skill.md) — native CSS alternative for scroll-linked effects
- [motion-for-react](../motion-for-react/Skill.md) — declarative alternative for app UI
- [view-transitions-api](../view-transitions-api/Skill.md) — route transitions in Next.js
- [motion-design-principles](../motion-design-principles/Skill.md) — easing and choreography rationale
- [animation-performance](../animation-performance/Skill.md) — main thread vs compositor
- [landing-page-design](../landing-page-design/Skill.md) — where GSAP is most common
- [layout-animations](../layout-animations/Skill.md) — Flip plugin vs Motion layout
- [hydration-strategies](../hydration-strategies/Skill.md) — avoiding hydration flashes
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — motion safety

## Sources
- [GSAP React guide](https://gsap.com/resources/React/) — Official — useGSAP, contextSafe, scope, "use client"
- [ScrollTrigger docs](https://gsap.com/docs/v3/Plugins/ScrollTrigger/) — Official — config, refresh, batch; v3.15
- [gsap.matchMedia()](https://gsap.com/docs/v3/GSAP/gsap.matchMedia()/) — Official — conditions and reduced motion
- [Flip plugin](https://gsap.com/docs/v3/Plugins/Flip/) — Official — getState/from options, framework gotchas
- [GSAP 3.13 release](https://gsap.com/blog/3-13/) — Official — plugins free, SplitText rewrite
- [Webflow: GSAP becomes free](https://webflow.com/blog/gsap-becomes-free) — Official — licensing change
- [GSAP Standard License](https://gsap.com/community/standard-license/) — Official — license terms
- [CSS-Tricks: GSAP is now completely free](https://css-tricks.com/gsap-is-now-completely-free-even-for-commercial-use/) — Community — confirmation and context

## License / Usage Notes
GSAP is free under the GSAP Standard License (proprietary, no-charge; not MIT). Check its restrictions before redistributing it inside competing visual-builder tools. This skill summarizes the docs and does not copy them; code is original.

## Quality Tier
A — Official docs verified for v3.15 and the licensing change. Bundle sizes are approximate, and the license restriction wording should be checked against the live text.

## Status
Active

## Last Verified
2026-09-15
