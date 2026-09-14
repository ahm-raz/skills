# Motion for React

## Summary
Motion for React (formerly Framer Motion) is the most widely used declarative animation library for React. It provides `<motion.*>` components, exit animations via `AnimatePresence`, layout and shared-element animations, gestures, scroll-linked motion values, and a hybrid engine that uses the Web Animations API (WAAPI) where it can and falls back to JavaScript. This skill covers correct imports (`motion/react`), bundle-size control, reduced motion, and patterns that stay smooth. Version 13.x was current as of September 2026.

## Category
Animation

## Subcategories
React animation, exit animations, gestures, spring physics, scroll-linked animation, layout animation, bundle optimization

## Problem It Solves
React unmounts elements immediately, so exit animations need coordination. Measuring layout for FLIP is error-prone, and gesture state (hover, press, drag) is tedious to wire by hand. Motion handles all of this declaratively. It also keeps high-frequency values (scroll, pointer) outside React's render cycle.

## When To Use
- React/Next.js apps that need enter/exit animations for conditionally rendered UI (modals, toasts, list items).
- Gesture-driven UI: drag-to-dismiss sheets, swipeable cards, press feedback that uses springs.
- Layout animations: reordering, expanding cards, tab underlines via `layoutId`.
- Scroll-linked effects that need JS logic (`useScroll` + `useTransform`) beyond what CSS scroll timelines support.
- Interruptible, velocity-aware motion (springs retarget smoothly mid-animation).

## When Not To Use
- Simple hover/focus state changes: use CSS transitions, which cost zero JS.
- Route/page transitions in React 19.3+/Next.js App Router, where `<ViewTransition>` covers the need (see view-transitions-api).
- Complex timeline choreography, SVG morphing, or scroll-pinned storytelling: GSAP is stronger here.
- Above-the-fold entrances in Next.js Server Components where CSS `@starting-style` avoids a client boundary and hydration flash.
- Lists with thousands of animated rows: prefer virtualization plus CSS, or no animation.

## Core Principles
1. Import from `motion/react`. The `framer-motion` package is legacy; migrate imports.
2. Animate `transform` and `opacity` first. Other properties cause layout or paint work.
3. Every exit animation needs `AnimatePresence` as a stable parent and a stable `key` on the child.
4. Keep fast-changing values in motion values (`useMotionValue`, `useScroll`), not React state.
5. Respect reduced motion globally with `<MotionConfig reducedMotion="user">`.
6. Prefer springs for interactive, physical motion. Use duration/easing tweens for opacity and color.
7. Ship only the features you use: `LazyMotion` + `m` for bundle-sensitive routes.

## Best Practices
- Wrap the app once: `<MotionConfig reducedMotion="user" transition={{ duration: 0.2, ease: [0.23, 1, 0.32, 1] }}>`.
- Set `initial={false}` on `AnimatePresence` for content that is present on first paint, so it doesn't animate in on load.
- Use `mode="popLayout"` when exiting items should leave layout flow immediately (lists). Use `mode="wait"` for one-at-a-time swaps (step content).
- Use spring `{ type: "spring", duration: 0.35, bounce: 0.1 }` for UI. Keep bounce between 0 and 0.25; high bounce reads as toy-like.
- For press feedback: `whileTap={{ scale: 0.97 }}`. Never animate from `scale: 0`; start at 0.9–0.95 combined with opacity.
- Use `whileInView` with `viewport={{ once: true, amount: 0.3 }}` for reveal-on-scroll, and keep the offset small (8–24px).
- Where WAAPI hardware acceleration matters (a busy main thread), animate a full `transform` string instead of independent `x`/`y`/`scale`. Independent transforms use CSS variables and are not compositor-accelerated.
- Put `borderRadius` and `boxShadow` in `style` on layout-animated elements so Motion can correct scale distortion.
- In Server Components files, don't render `motion.*`. Isolate animated parts in `"use client"` components, or use the `motion/react-client` entry.

## Implementation Guidance

### Install and import
```bash
npm install motion
```
```tsx
"use client";
import { motion, AnimatePresence, MotionConfig, useReducedMotion } from "motion/react";
```

### Default transition behavior
| Value type | Default | Recommendation |
|---|---|---|
| `x`, `y`, `scale`, `rotate` | spring | Keep the spring for gestures; set `bounce` ≤ 0.2 |
| `opacity`, colors | tween | 150–250ms, ease-out |
| Layout (`layout`, `layoutId`) | spring | `{ type: "spring", duration: 0.4, bounce: 0 }` for a calm UI |

### Duration/easing starting points
| Interaction | Duration | Easing |
|---|---|---|
| Press/tap feedback | 100–160ms | ease-out or spring (bounce 0) |
| Tooltip / small popover | 125–200ms | `[0.23, 1, 0.32, 1]` |
| Dropdown / menu | 150–250ms | ease-out |
| Modal / sheet | 200–400ms | spring or `[0.32, 0.72, 0, 1]` (drawer) |
| Exit (any) | ~75% of the enter duration | ease-in or ease-out; exits should be faster |

### Bundle-size decision table
| Need | Import | Approx. size |
|---|---|---|
| Full features, not size-sensitive | `motion` from `motion/react` | ~34kb |
| Animations + gestures + exit | `m` from `motion/react-m` + `LazyMotion features={domAnimation}` | 4.6kb + 15kb |
| Also drag + layout | `LazyMotion features={domMax}` | 4.6kb + 25kb |
| Imperative only, WAAPI | `useAnimate` from `motion/react-mini` | ~2.3kb |

```tsx
import { LazyMotion, domAnimation } from "motion/react";
import * as m from "motion/react-m";

export function Providers({ children }: { children: React.ReactNode }) {
  return <LazyMotion features={domAnimation} strict>{children}</LazyMotion>;
}
// usage: <m.div animate={{ opacity: 1 }} />
```
`strict` throws if someone renders `motion.div` inside, which prevents accidentally pulling in the full bundle.

## Recommended Workflow
1. Decide whether CSS can do it (hover, focus, `@starting-style` entry). If yes, stop.
2. Add `MotionConfig reducedMotion="user"` and shared transition tokens at the root.
3. Build the static component first. Then add `initial`/`animate`/`exit` with variants.
4. Wrap conditional renders in `AnimatePresence` with stable keys.
5. Test interruption: toggle rapidly and confirm the animation retargets without jumps.
6. Profile in Chrome DevTools Performance with 4x CPU throttling. Check for long tasks and layout during animation.
7. Verify with OS reduced motion enabled and keyboard-only use.

## Patterns

### Presence (modal/toast)
```tsx
<AnimatePresence initial={false}>
  {open && (
    <motion.div
      key="dialog"
      role="dialog"
      aria-modal="true"
      initial={{ opacity: 0, scale: 0.96 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.98, transition: { duration: 0.12 } }}
      transition={{ duration: 0.2, ease: [0.23, 1, 0.32, 1] }}
    />
  )}
</AnimatePresence>
```

### Variants with stagger
```tsx
const list = { show: { transition: { staggerChildren: 0.04 } } };
const item = { hidden: { opacity: 0, y: 8 }, show: { opacity: 1, y: 0 } };
<motion.ul variants={list} initial="hidden" animate="show">
  {items.map(i => <motion.li key={i.id} variants={item} />)}
</motion.ul>
```
Cap the stagger so that total delay stays under ~300ms (e.g. only the first 8 items get a delay).

### Scroll-linked progress bar (no re-renders)
```tsx
const { scrollYProgress } = useScroll();
const scaleX = useSpring(scrollYProgress, { stiffness: 200, damping: 30 });
<motion.div style={{ scaleX, transformOrigin: "0 0" }} className="fixed inset-x-0 top-0 h-1" />
```

### Drag-to-dismiss sheet
```tsx
<motion.div
  drag="y"
  dragConstraints={{ top: 0, bottom: 0 }}
  dragElastic={{ top: 0, bottom: 0.6 }}
  onDragEnd={(_, info) => {
    if (info.offset.y > 120 || info.velocity.y > 500) onClose();
  }}
/>
```
Always provide a visible close button as well; drag is not keyboard accessible.

## Anti-Patterns
| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| `AnimatePresence` inside the conditional | It unmounts together with the child, so no exit plays | Keep `AnimatePresence` mounted; put the conditional inside it |
| `key={index}` on presence children | Reorders animate the wrong items | Use stable IDs |
| Animating `width`/`height`/`top` | Layout on every frame | Use `layout` prop (transform-based) or `scale` |
| `useState` updated from `onScroll`/`mousemove` | Re-render per frame | `useMotionValue`, `useScroll`, `useTransform` |
| `scale: 0` entry | Feels like it pops from nowhere | Start from `scale: 0.95` + `opacity: 0` |
| Importing `framer-motion` and `motion` together | Duplicate bundles | Standardize on `motion/react` |
| Global `transition={{ duration: 1 }}` | Sluggish UI | 150–300ms for UI; longer only for large surfaces |
| Nested `AnimatePresence` without `propagate` | Child exits skipped when the parent exits | `<AnimatePresence propagate>` |

## Accessibility
- WCAG 2.3.3 Animation from Interactions (AAA) and 2.2.2 Pause, Stop, Hide (A): honor `prefers-reduced-motion` and give users a way to stop auto-playing motion that runs over 5s.
- `MotionConfig reducedMotion="user"` disables transform and layout animations but keeps opacity and color. Verify that this is enough. For parallax or large slides, use `useReducedMotion()` to swap the effect for a crossfade or no animation.
- Exit animations must not delay focus management. Move focus when the dialog opens, and return focus on close immediately rather than after the exit completes.
- Don't leave an exiting element interactive: set `pointer-events: none` in the exit variant, or make it `inert`.
- Drag gestures need keyboard and button alternatives.

## Responsive Design
- Use `useReducedMotion` together with a `matchMedia("(hover: hover) and (pointer: fine)")` check before enabling hover-only effects.
- Reduce travel distance on small screens (e.g. `y: 8` mobile vs `y: 16` desktop). Sheets slide from the bottom on mobile and dialogs scale in on desktop.
- Drag constraints should derive from container refs, not hard-coded pixels.

## Performance
- Motion runs `opacity`, `transform`, `filter`, and `clipPath` on WAAPI when possible, so they stay smooth even when the main thread is busy. Independent transforms (`x`, `scale`) run on the JS frame loop.
- Use motion values for continuous input, and `useTransform` to derive values without renders.
- Avoid `layout` on large subtrees or long lists. Each one measures on every render; scope with `layoutDependency`.
- Use `will-change: transform` only on elements that are actively animating. GPU memory is finite.
- Lazy-load features with `LazyMotion` async (`features={() => import("./features").then(r => r.default)}`).

## Security
- No direct risks. Don't pass user-controlled strings into `style`/`animate` values without validation, because CSS `url()` injection is possible via custom properties.
- Pin versions and review the changelog; animation libraries run on every page.

## Testing
- Unit tests (Vitest/Jest + Testing Library): assert that presence behavior ends in the correct DOM state. In jsdom, use `MotionGlobalConfig.skipAnimations = true` (from `motion`) so exits complete immediately.
- Playwright: use `page.emulateMedia({ reducedMotion: "reduce" })` to test both paths, and wait for `animationend` or the element's final state rather than using fixed timeouts.
- Visual regression: disable animations for deterministic screenshots.
- Manual: toggle rapidly, drag with a touch device, 4x CPU throttle.

## Tooling
- `motion` (13.x, active; MIT) is the core package. `motion/react`, `motion/react-m`, and `motion/react-mini` are its entry points.
- Motion+ (paid, optional) adds premium examples and components plus a VS Code/devtools transition editor.
- `framer-motion` is legacy; it re-exports Motion but should not be used for new code.
- Vaul (drawers) and Sonner (toasts) use their own CSS-based motion. Don't wrap them in Motion.

## Framework Notes
- **React (Vite SPA)**: no directive needed. For React Router route transitions, use `AnimatePresence mode="wait"` around `useOutlet()` keyed by `location.pathname`, or React 19.3 `<ViewTransition>` with navigations wrapped in `startTransition`. React 19 Strict Mode double-invokes effects; 13.1.1+ fixed `AnimatePresence` edge cases, so stay current.
- **Next.js App Router, `"use client"`**: any file rendering `motion.*`, `AnimatePresence`, or hooks (`useScroll`, `useReducedMotion`) must be a client component. Pattern: a thin `components/motion/fade-in.tsx` client wrapper that receives server-rendered `children`. For RSC-only files, `import * as motion from "motion/react-client"` allows `<motion.div>` without marking the file, but hooks and callbacks still need a client component.
- **Route-change animations**: `AnimatePresence` around `{children}` in `layout.tsx` is unreliable. The App Router swaps segments without keeping the old tree mounted, so exits don't play. A `template.tsx` re-mounts per navigation and supports enter animations only. For enter + exit + shared elements, use React `<ViewTransition>`; App Router navigations are transitions, so `<Link transitionTypes={["nav-forward"]}>` works with no config.
- **Hydration flashes**: `initial={{ opacity: 0 }}` is rendered into server HTML as inline style, so content is invisible until JS hydrates. That hurts LCP for hero text and leaves content blank when JS fails. Fixes: don't apply `initial` hiding to LCP elements; use CSS `@starting-style` for above-the-fold entrances; or use `initial={false}` where the first paint should be final.
- **Server Components boundaries**: keep animated leaves small so most of the tree stays server-rendered. Never pass functions (e.g. `onAnimationComplete`) from a Server Component into a Motion client wrapper.

## AI Agent Guidance
- DO import from `motion/react`; DO add `"use client"` in Next.js files using Motion.
- DO add `MotionConfig reducedMotion="user"` if absent.
- DO give every `AnimatePresence` child a stable `key`.
- DON'T add Motion to a project just for hover effects; CSS is enough.
- DON'T animate layout properties; DON'T store per-frame values in React state.
- DON'T mix `framer-motion` and `motion` imports.
- Verify before declaring done: exit animations actually play; rapid toggling doesn't break; reduced motion removes movement; no hydration warnings; the bundle grew by an expected amount.

## Examples

### Tabs with shared underline
```tsx
<LayoutGroup id="tabs">
  {tabs.map(t => (
    <button key={t.id} role="tab" aria-selected={t.id === active} onClick={() => setActive(t.id)} className="relative px-3 py-2">
      {t.label}
      {t.id === active && (
        <motion.span layoutId="tab-underline" className="absolute inset-x-0 -bottom-px h-0.5 bg-current"
          transition={{ type: "spring", duration: 0.35, bounce: 0 }} />
      )}
    </button>
  ))}
</LayoutGroup>
```

### Reduced-motion aware reveal
```tsx
function Reveal({ children }: { children: React.ReactNode }) {
  const reduce = useReducedMotion();
  return (
    <motion.div
      initial={{ opacity: 0, y: reduce ? 0 : 16 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.3 }}
      transition={{ duration: 0.3, ease: [0.23, 1, 0.32, 1] }}
    >{children}</motion.div>
  );
}
```

## Related Skills
- [layout-animations](../layout-animations/Skill.md) — deep dive on `layout`/`layoutId` and FLIP
- [view-transitions-api](../view-transitions-api/Skill.md) — native alternative for route and state transitions
- [animation-performance](../animation-performance/Skill.md) — compositor rules and profiling
- [micro-interactions](../micro-interactions/Skill.md) — press, hover, and toggle feedback patterns
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — accessibility requirements
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — transitions that drive `<ViewTransition>`
- [animated-component-collections](../animated-component-collections/Skill.md) — prebuilt Motion-based components
- [drawers-and-sheets](../drawers-and-sheets/Skill.md) — drag-to-dismiss sheets

## Sources
- [Motion for React docs](https://motion.dev/docs/react) — Official — install, imports, defaults
- [Motion changelog](https://motion.dev/changelog) — Official — 13.x version status
- [AnimatePresence](https://motion.dev/docs/react-animate-presence) — Official — modes, propagate, pitfalls
- [Reduce bundle size](https://motion.dev/docs/react-reduce-bundle-size) — Official — LazyMotion sizes
- [Motion accessibility](https://motion.dev/docs/react-accessibility) — Official — reducedMotion behavior
- [Web animation performance tier list](https://motion.dev/docs/performance) — Official — independent transforms not accelerated
- [emilkowalski/skills](https://github.com/emilkowalski/skills) — Community — durations, easing curves, press scale
- [vercel-labs web-animation-design SKILL.md](https://github.com/vercel-labs/open-agents/blob/main/.agents/skills/web-animation-design/SKILL.md) — Community — agent rules

## License / Usage Notes
Motion is MIT-licensed; Motion+ is a separate commercial offering. Content here is summarized from the docs and community guidance, not copied.

## Quality Tier
A — Verified against official docs and the 13.x changelog; the bundle sizes come from docs and may drift between minors.

## Status
Active

## Last Verified
2026-09-15
