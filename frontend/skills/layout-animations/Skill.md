# Layout Animations

## Summary
Layout animations smoothly animate changes in an element's size or position caused by layout (reordering, filtering, expanding, moving between containers) instead of letting the element snap. The core technique is FLIP (First, Last, Invert, Play): measure before, measure after, apply an inverse transform, then animate the transform to zero. This keeps the animation compositor-friendly. In React/Next.js, choose among Motion's `layout`/`layoutId`, React 19.3 `<ViewTransition>` (update/share), AutoAnimate's `useAutoAnimate`, GSAP Flip, or CSS-only options (grid-rows trick, `interpolate-size`).

## Category
Animation

## Subcategories
FLIP, shared element transitions, list reorder, expand/collapse, height auto animation, tab indicators, grid/list view switch

## Problem It Solves
React re-renders move elements instantly, which disorients users: items jump when a list is filtered, cards snap open, tab underlines teleport. Animating `width`/`height`/`top` directly causes layout per frame and jank. FLIP-based layout animation gives continuity at compositor cost.

## When To Use
- Sortable, filterable, or paginated lists where items move or disappear.
- Expanding cards and accordions, and height changes from content.
- Tab/segmented-control indicators and "magic motion" highlights.
- Moving an element between containers (kanban card, grid→detail overlay).
- Switching grid↔list layouts.

## When Not To Use
- Virtualized lists with thousands of rows: measuring is expensive and items unmount. Animate only insert/remove opacity, or skip.
- Tables whose column widths change. Scaling text distorts; crossfade instead.
- Layout changes during continuous resizing (window resize, split panes). Snap instead.
- Text reflow inside paragraphs; scale distortion is very noticeable.

## Core Principles
1. Never animate layout properties per frame. Use FLIP (transform/scale) or the browser's snapshot (view transitions).
2. Stable identity: every animated item needs a stable `key` (and a unique `layoutId`/`name` for shared elements).
3. Correct scale distortion: children, `border-radius`, and `box-shadow` must be counter-scaled or kept out of the scaled element.
4. Choose the least powerful tool that works: CSS → AutoAnimate → View Transitions → Motion → GSAP Flip.
5. Keep durations proportional to distance: 200–400ms, with springs without bounce for layout.
6. Reduced motion: snap or crossfade instead of moving.

## Best Practices
- Motion: add `layout` to both the moving element and children that would distort. Set `borderRadius` via `style`.
- Use `layout="position"` for elements whose aspect ratio changes (images, text blocks) to avoid stretch.
- Wrap sibling components that affect each other's layout in `<LayoutGroup>` so they measure together.
- Use `layoutScroll` on scrollable ancestors and `layoutRoot` on fixed containers.
- Set `scrollbar-gutter: stable` so scrollbar appearance doesn't trigger layout animations.
- For removals, use `AnimatePresence mode="popLayout"` so siblings move up while the exiting item fades.
- For `<ViewTransition>` list animations, give each item `name={`item-${id}`}` and trigger reorders inside `startTransition`.
- Limit layout-animated items on screen (≈50) and disable for large lists.

## Implementation Guidance

### Tool decision table
| Scenario | Best tool | Why |
|---|---|---|
| Accordion/expand height | CSS grid-rows `0fr→1fr` (all browsers) or `interpolate-size` (Chromium) | No JS |
| Simple list add/remove/reorder | `useAutoAnimate` (`@formkit/auto-animate/react`) | One line, respects reduced motion |
| Tab indicator, shared highlight | Motion `layoutId` | Handles interruption, springs |
| Filter/sort grid in React 19.3 | `<ViewTransition>` with unique names + `startTransition` | Native, compositor, no measure code |
| Element moves across routes | `<ViewTransition name share>` | Survives navigation |
| Drag-reorder with physics | Motion `Reorder.Group`/`Reorder.Item` or dnd-kit + Motion layout | Gesture + layout |
| Reparenting into different containers, complex timeline | GSAP Flip | Handles nested, absolute positioning |

### Duration guide
| Change | Duration | Transition |
|---|---|---|
| Indicator slide (tabs) | 200–300ms | spring `bounce: 0` |
| List reorder | 250–350ms | spring `duration: 0.35, bounce: 0` |
| Expand card | 300–400ms | ease-out/spring |
| Grid↔list switch | 350–450ms | ease-in-out |

## Recommended Workflow
1. Identify what moves and why; decide whether movement conveys meaning (continuity) or noise.
2. Pick a tool from the decision table.
3. Ensure stable keys and unique names/IDs.
4. Implement, then check for distortion (text stretch, radius warp) and fix with child `layout`, `layout="position"`, or crossfade.
5. Test rapid interactions (click sort repeatedly) and scroll-position interactions.
6. Test reduced motion and large data volumes.

## Patterns

### Motion: expanding card with distortion correction
```tsx
"use client";
import { motion } from "motion/react";
import { useState } from "react";

export function ExpandCard({ title, body }: { title: string; body: string }) {
  const [open, setOpen] = useState(false);
  return (
    <motion.article layout style={{ borderRadius: 16 }} className="overflow-hidden bg-white p-4"
      transition={{ type: "spring", duration: 0.35, bounce: 0 }}>
      <motion.h3 layout="position">
        <button aria-expanded={open} onClick={() => setOpen(o => !o)}>{title}</button>
      </motion.h3>
      {open && (
        <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.1 }}>
          {body}
        </motion.p>
      )}
    </motion.article>
  );
}
```

### Motion: filterable grid with popLayout
```tsx
<motion.ul layout className="grid grid-cols-3 gap-4">
  <AnimatePresence mode="popLayout" initial={false}>
    {items.map(item => (
      <motion.li key={item.id} layout
        initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.96, transition: { duration: 0.15 } }}>
        <Card item={item} />
      </motion.li>
    ))}
  </AnimatePresence>
</motion.ul>
```
Children of `AnimatePresence mode="popLayout"` must forward refs if they're custom components (React 19 passes `ref` as a prop).

### AutoAnimate (lightest)
```tsx
"use client";
import { useAutoAnimate } from "@formkit/auto-animate/react";

export function TodoList({ todos }: { todos: { id: string; text: string }[] }) {
  const [parent] = useAutoAnimate({ duration: 200 });
  return <ul ref={parent}>{todos.map(t => <li key={t.id}>{t.text}</li>)}</ul>;
}
```
It animates only direct children and sets `position: relative` on static parents. It respects reduced motion by default.

### React ViewTransition list reorder
```tsx
"use client";
import { startTransition, useState, ViewTransition } from "react";

export function SortableList({ initial }: { initial: { id: string; label: string }[] }) {
  const [items, setItems] = useState(initial);
  const sort = () => startTransition(() => setItems(xs => [...xs].sort((a, b) => a.label.localeCompare(b.label))));
  return (
    <>
      <button onClick={sort}>Sort A–Z</button>
      <ul>
        {items.map(i => (
          <ViewTransition key={i.id} name={`row-${i.id}`}>
            <li>{i.label}</li>
          </ViewTransition>
        ))}
      </ul>
    </>
  );
}
```

### CSS-only accordion height (cross-browser)
```css
.panel { display: grid; grid-template-rows: 0fr; transition: grid-template-rows 250ms cubic-bezier(0.23,1,0.32,1); }
.panel[data-open="true"] { grid-template-rows: 1fr; }
.panel > .inner { min-height: 0; overflow: hidden; }
@media (prefers-reduced-motion: reduce) { .panel { transition: none; } }
```
This animates a layout property, but it's usually acceptable for small panels. Avoid it on large or complex subtrees.

### Manual FLIP with WAAPI (no library)
```tsx
"use client";
import { useLayoutEffect, useRef } from "react";

export function useFlip<T extends HTMLElement>(dep: unknown) {
  const ref = useRef<T>(null);
  const prev = useRef<DOMRect | null>(null);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const last = el.getBoundingClientRect();
    const first = prev.current;
    prev.current = last;
    if (!first || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const dx = first.left - last.left, dy = first.top - last.top;
    if (!dx && !dy) return;
    const a = el.animate([{ transform: `translate(${dx}px, ${dy}px)` }, { transform: "none" }],
      { duration: 300, easing: "cubic-bezier(0.23,1,0.32,1)" });
    return () => a.cancel();
  }, [dep]);
  return ref;
}
```

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| Animating `height: auto` via JS measuring per frame | Layout thrash | FLIP, grid-rows, `interpolate-size` |
| `key={index}` in animated lists | Wrong items animate | Stable IDs |
| `layout` on a huge container with many children | Measures everything each render | Scope layout to moving items; `layoutDependency` |
| Border radius set in className on layout element | Warps during scale | `style={{ borderRadius }}` |
| Text stretched during size animation | Unreadable mid-flight | Child `layout="position"` or crossfade |
| Duplicate `layoutId`/`name` rendered simultaneously | Glitches/errors | Unique per mounted instance |
| Layout animations on virtualized rows | Items unmount mid-animation | Disable or only fade |
| Animations triggered by scrollbar appearing | Unintended motion | `scrollbar-gutter: stable` |

## Accessibility
- WCAG 2.3.3: under reduced motion, replace movement with instant layout (MotionConfig `reducedMotion="user"` disables layout animations automatically).
- Keep DOM order equal to visual order after reorder, since screen readers and tab order follow DOM.
- Announce significant reorders or filter results via a polite live region ("12 results").
- Don't move the focused element far without keeping focus; verify that focus persists on the same item after sort.
- Avoid moving targets the user is about to click. Keep reorder durations short.

## Responsive Design
- Layout animations are disabled by Motion during horizontal window resize; don't fight this.
- Grid↔list switches often coincide with breakpoints. Don't animate breakpoint-driven layout changes (they happen during resize).
- On mobile, prefer vertical list animations with small travel; large cross-screen moves are disorienting.

## Performance
- FLIP animates `transform`, which stays on the compositor, but the measurement (`getBoundingClientRect`) forces layout. Batch reads before writes, once per change.
- Motion's layout projection is efficient but scales with the number of `layout` components mounted.
- View transitions snapshot named elements as images, so memory scales with count × area. Name only visible items (items outside the viewport don't animate anyway).
- Grid-rows/`interpolate-size` animate layout; keep panel content light, or use `content-visibility`.

## Security
- No specific concerns.

## Testing
- Testing Library: assert final order and presence; set `MotionGlobalConfig.skipAnimations = true` for Motion in tests.
- Playwright: click sort repeatedly and screenshot mid-animation for distortion review (headed, slowed via `animation` playbackRate in DevTools or CPU throttle).
- Verify focus retention after reorder with keyboard-only tests.
- Check console for duplicate `name` errors (ViewTransition).

## Tooling
- Motion for React `layout`, `layoutId`, `LayoutGroup`, `Reorder` (Active).
- React 19.3 `<ViewTransition>` (Stable).
- `@formkit/auto-animate` with `useAutoAnimate` (Active, MIT).
- GSAP Flip (free, Standard License).
- dnd-kit for accessible drag-and-drop (pair with Motion layout or its own sortable transitions).

## Framework Notes
- **React (Vite SPA)**: all tools work. Prefer `<ViewTransition>` for reorder/filter when on React 19.3; use Motion for interruptible, gesture-driven layout.
- **Next.js App Router**: Motion, AutoAnimate, and GSAP Flip need `"use client"`. `<ViewTransition>` can wrap server-rendered lists, but the triggering state change must be in a client component (`startTransition`), or be a navigation such as search params changing through `router.push`/`Link`. Filter results from `searchParams` changes animate automatically because navigations are transitions.
- **Hydration**: Motion `layout` doesn't animate on first render, so there's no flash. Avoid `initial` hide states on server-rendered lists above the fold.

## AI Agent Guidance
- DO choose from the decision table and justify the tool.
- DO use stable keys and unique `layoutId`/`name`s.
- DO fix distortion (style radius, child `layout`, `layout="position"`).
- DON'T animate width/height/top in JS loops; DON'T add layout animations to virtualized lists.
- Verify: rapid repeated interactions stay stable; no text stretch; focus persists; reduced motion snaps; no duplicate-name errors.

## Examples

### Tabs indicator with layoutId (Next.js client component)
```tsx
"use client";
import { LayoutGroup, motion } from "motion/react";

export function Segmented({ options, value, onChange }: { options: string[]; value: string; onChange: (v: string) => void }) {
  return (
    <LayoutGroup id="segmented">
      <div role="radiogroup" className="inline-flex rounded-full bg-neutral-100 p-1">
        {options.map(o => (
          <button key={o} role="radio" aria-checked={o === value} onClick={() => onChange(o)} className="relative px-3 py-1.5 text-sm">
            {o === value && (
              <motion.span layoutId="seg-pill" className="absolute inset-0 rounded-full bg-white shadow"
                transition={{ type: "spring", duration: 0.3, bounce: 0 }} />
            )}
            <span className="relative">{o}</span>
          </button>
        ))}
      </div>
    </LayoutGroup>
  );
}
```

## Related Skills
- [motion-for-react](../motion-for-react/Skill.md) — Motion API details
- [view-transitions-api](../view-transitions-api/Skill.md) — native snapshot-based layout transitions
- [gsap-animation](../gsap-animation/Skill.md) — Flip plugin
- [accordions-and-disclosure](../accordions-and-disclosure/Skill.md) — expand/collapse components
- [drag-and-drop](../drag-and-drop/Skill.md) — reorder interactions
- [kanban-boards](../kanban-boards/Skill.md) — cross-container movement
- [list-virtualization](../list-virtualization/Skill.md) — when not to animate
- [animation-performance](../animation-performance/Skill.md) — measurement and compositor costs

## Sources
- [Motion layout animations](https://motion.dev/docs/react-layout-animations) — Official — layout, layoutId, LayoutGroup, distortion, troubleshooting
- [React ViewTransition reference](https://react.dev/reference/react/ViewTransition) — Official — update/share triggers, unique names
- [GSAP Flip](https://gsap.com/docs/v3/Plugins/Flip/) — Official — FLIP options and framework gotchas
- [AutoAnimate](https://auto-animate.formkit.com/) — Open Source — React hook, limitations
- [MDN interpolate-size](https://developer.mozilla.org/en-US/docs/Web/CSS/interpolate-size) — Official — height:auto animation support
- [Paul Lewis: FLIP your animations](https://aerotwist.com/blog/flip-your-animations/) — Community — original FLIP technique

## License / Usage Notes
Motion (MIT), AutoAnimate (MIT), GSAP (Standard License, free). Content summarized; code original.

## Quality Tier
A — Cross-checked across official docs for Motion, React, and GSAP; the manual FLIP hook is illustrative.

## Status
Active

## Last Verified
2026-09-15
