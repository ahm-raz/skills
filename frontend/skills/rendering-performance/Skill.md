# Rendering Performance

## Summary
Rendering performance is the browser's pixel pipeline—JavaScript → style → layout → paint → composite—running within frame budgets (~16 ms at 60 Hz, less on high-refresh screens). This skill covers keeping that pipeline cheap in React apps: avoiding forced synchronous layout (layout thrashing), limiting DOM size and style recalculation scope, using CSS containment and `content-visibility`, compositor-friendly animation, virtualization for long lists, and diagnosing jank with DevTools. React re-render optimization itself is owned by [react-performance-optimization](../react-performance-optimization/Skill.md); this skill is the browser side.

## Category
Performance

## Subcategories
Pixel pipeline, layout thrashing, forced reflow, style recalculation, DOM size, CSS containment, content-visibility, compositing, scroll performance, virtualization, frame budget

## Problem It Solves
Janky scrolling, slow presentation after interactions (INP presentation delay), sluggish resize, expensive large tables/feeds, and animations that drop frames—even when JS handlers are fast.

## When To Use
- DevTools shows long "Recalculate style", "Layout", "Paint" or "Commit" blocks, or a "Forced reflow" insight.
- INP presentation delay is the dominant phase.
- Long lists/tables/feeds, dashboards with many elements, complex CSS effects.

## When Not To Use
- Slow network/loading problems → [lcp-optimization](../lcp-optimization/Skill.md).
- Excess React re-renders with cheap DOM output → [react-performance-optimization](../react-performance-optimization/Skill.md).
- Animation choreography/design → [animation-performance](../animation-performance/Skill.md).

## Core Principles
1. **Read, then write**: batch all layout reads before style/DOM writes in a frame.
2. **Touch fewer elements**: smaller DOM, narrower style invalidation, contained subtrees.
3. **Skip what isn't visible**: `content-visibility: auto`, virtualization.
4. **Stay on the compositor for motion**: `transform`, `opacity` (and `filter` where GPU-accelerated); avoid animating layout/paint properties.
5. **Measure frames, not guesses**: Performance panel + Rendering tools before changing CSS.

## Best Practices
- Keep total DOM nodes modest (Lighthouse flags large DOMs roughly > ~1,400 nodes in body; depth > 32; parent with > 60 children).
- Virtualize lists > ~100–200 complex rows ([list-virtualization](../list-virtualization/Skill.md)); tables: TanStack Virtual with [tanstack-table](../tanstack-table/Skill.md).
- `content-visibility: auto` + `contain-intrinsic-size: auto <estimate>` for long off-screen sections (Baseline 2024).
- `contain: layout paint` (or `contain: strict` with sizes) on self-contained widgets (cards, chat panes) so internal changes don't invalidate the page.
- Avoid reading `offsetWidth/Height`, `getBoundingClientRect`, `scrollTop`, `getComputedStyle` right after writes; use `ResizeObserver`/`IntersectionObserver` instead of polling.
- Use `requestAnimationFrame` for visual updates tied to frames; don't set styles in scroll handlers—use CSS scroll-driven animations or passive listeners + rAF.
- `will-change: transform` only on elements about to animate; remove afterwards (layers cost memory).
- Avoid expensive paint: large `box-shadow`/`filter: blur()` on big or frequently repainted areas, `backdrop-filter` over scrolling content—test on low-end devices.
- Prefer class toggles on a container over per-element inline style updates for many elements.
- Large text/HTML inserts: chunk them, and avoid `innerHTML` of huge strings on interaction.

## Implementation Guidance

### Symptom → cause → fix
| Trace symptom | Likely cause | Fix |
|---|---|---|
| Purple "Layout" repeatedly inside one task, "Forced reflow" insight | Interleaved reads/writes (thrash) | Batch reads first; move reads into `ResizeObserver`; `useLayoutEffect` single measure |
| Long "Recalculate style" affecting thousands of elements | Class change on `body`/root, broad selectors, huge DOM | Scope class changes; containment; reduce DOM; check selector stats |
| Long "Paint"/"Rasterize" | Large shadows/blur, repaint of big areas, non-composited animation | Simplify effects; animate transform/opacity; isolate with `contain: paint` |
| Scroll jank | Non-passive `touchstart`/`wheel` listeners, heavy scroll handlers | `{ passive: true }`; IntersectionObserver; CSS scroll-driven animations |
| Long commit after state update in huge list | Rendering thousands of rows | Virtualization, pagination, `content-visibility` |
| Presentation delay high after interaction | Big DOM mutation + layout | Smaller update; defer secondary UI with transitions/yield |

### Layout thrashing fix (React)
```tsx
'use client';
import { useLayoutEffect, useRef } from 'react';

// BAD: for each item, read height then write style → N forced layouts
// GOOD: read all, then write all
export function EqualHeights({ ids }: { ids: string[] }) {
  const container = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const els = Array.from(container.current?.querySelectorAll<HTMLElement>('[data-card]') ?? []);
    const max = Math.max(...els.map((el) => el.getBoundingClientRect().height)); // reads
    els.forEach((el) => { el.style.minHeight = `${max}px`; });                    // writes
  }, [ids]);
  return <div ref={container}>{/* cards */}</div>;
}
```
(Better: CSS grid `align-items: stretch` removes the JS entirely.)

### Observe size without polling
```tsx
'use client';
import { useEffect, useRef, useState } from 'react';

export function useElementWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(([entry]) => setWidth(entry.contentBoxSize[0].inlineSize));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, width] as const;
}
```
Prefer container queries over JS width measurement for layout ([container-queries](../container-queries/Skill.md)).

### Containment and content-visibility
```css
.card { contain: layout paint; }                 /* internal changes don't reflow the page */
.feed-section {
  content-visibility: auto;
  contain-intrinsic-size: auto 1200px;           /* remembers last rendered size */
}
.fab { will-change: transform; }                 /* only while it animates, ideally toggled */
```

### Passive, rAF-throttled scroll work
```tsx
useEffect(() => {
  let ticking = false;
  const onScroll = () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { header.current?.classList.toggle('compact', window.scrollY > 80); ticking = false; });
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  return () => window.removeEventListener('scroll', onScroll);
}, []);
```

## Recommended Workflow
1. Reproduce jank with 4–6× CPU throttling; record in Performance panel.
2. Check the Frames track and Main thread: identify dominant pipeline stage (style/layout/paint/commit) and the Insights sidebar ("Forced reflow", "Optimize DOM size", "Layout shift culprits").
3. Use Rendering tab: Paint flashing, Layer borders, Scrolling performance issues, Frame rendering stats.
4. For style recalcs, enable "CSS selector stats" in Performance settings to find expensive selectors.
5. Apply fix from table; re-record identical scenario; compare frame times and task durations.
6. Validate on a real mid-tier Android device (remote debugging).

## Patterns
- **FastDOM-style batching**: read phase, then write phase per frame.
- **Windowing**: render only visible rows + overscan.
- **Containment islands**: `contain` on independent widgets.
- **CSS-first responsive behavior**: container/media queries instead of resize listeners.
- **Compositor-only motion**: transform/opacity, FLIP for layout transitions ([layout-animations](../layout-animations/Skill.md)).

## Anti-Patterns
- **Measuring in render or in loops after writes**. Fix: `useLayoutEffect` once, batch.
- **Animating `top/left/width/height`** → layout every frame. Fix: `transform`.
- **`will-change` on everything** → memory blow-up, worse performance. Fix: apply sparingly, temporarily.
- **Rendering 5,000 table rows** → slow commit & style. Fix: virtualization/pagination.
- **Toggling a theme class on `<html>` triggering full-page style recalc during interaction**. Fix: acceptable once, but avoid frequent root class churn; use CSS variables scoped to components.
- **Non-passive wheel/touch listeners** → scroll blocked. Fix: `{ passive: true }`.

## Accessibility
- `content-visibility: auto` keeps content in the accessibility tree, but test find-in-page and screen reader navigation; don't use it to hide content semantically.
- Virtualized lists: maintain `aria-rowcount`/`aria-rowindex` or `aria-setsize`/`aria-posinset`; ensure keyboard focus moves rows into view ([accessible-data-tables](../accessible-data-tables/Skill.md)).
- Respect `prefers-reduced-motion`; reducing motion also reduces rendering work ([reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md)).

## Responsive Design
- Resize triggers layout for everything; heavy JS on resize multiplies cost—use container queries.
- High-refresh screens (120 Hz) halve frame budgets for animations; mobile GPUs struggle with large blurred/transparent layers.

## Performance
- Frame budget: ~16.7 ms at 60 Hz including browser work—aim for JS < ~8–10 ms per frame during animation/scroll.
- Containment and content-visibility often cut initial rendering time substantially on long pages; verify with traces.

## Security
- No direct concerns; avoid `innerHTML` for large dynamic inserts (also an XSS risk)—use React rendering or sanitized templates.

## Testing
- DevTools trace comparisons (save traces before/after; annotate).
- Playwright + CDP `Performance.getMetrics` (LayoutCount, RecalcStyleCount) around a scripted interaction as a regression signal.
- Scroll-jank checks on real devices; Lighthouse "Optimize DOM size" insight.

## Tooling
- Chrome DevTools Performance panel (Insights: forced reflow, DOM size; CSS selector stats), Rendering tab, Layers panel — Active.
- React DevTools Profiler (render counts) — Active.
- TanStack Virtual, react-window/react-virtuoso — Active (see list-virtualization).

## Framework Notes
- **React (Vite SPA & Next.js)**: DOM work happens in commit; measure in `useLayoutEffect` (runs before paint) and mutate in the same pass; never measure during render. Use transitions to keep urgent updates small. Avoid re-rendering large subtrees on scroll/resize state—subscribe narrowly. React 19.2 performance tracks show component render vs commit time in the Chrome trace.
- **Next.js**: server-rendered long pages benefit greatly from `content-visibility` on below-the-fold sections; streaming doesn't reduce client rendering cost of a huge DOM.

## AI Agent Guidance
- Do: prefer CSS solutions (grid stretch, container queries, containment) over JS measurement.
- Do: batch reads/writes; add passive listeners; animate transform/opacity only.
- Don't: add `will-change` broadly or `content-visibility` without `contain-intrinsic-size`.
- Before declaring done: re-recorded trace shows reduced style/layout/paint time for the scenario, no new forced reflows, no CLS or accessibility regressions (find-in-page, keyboard).

## Examples
```tsx
// Virtualized list with TanStack Virtual
'use client';
import { useVirtualizer } from '@tanstack/react-virtual';
import { useRef } from 'react';

export function LogList({ rows }: { rows: string[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const v = useVirtualizer({ count: rows.length, getScrollElement: () => parentRef.current, estimateSize: () => 32, overscan: 8 });
  return (
    <div ref={parentRef} style={{ height: 480, overflow: 'auto', contain: 'strict' }} role="list" aria-label="Logs">
      <div style={{ height: v.getTotalSize(), position: 'relative' }}>
        {v.getVirtualItems().map((item) => (
          <div key={item.key} role="listitem" aria-setsize={rows.length} aria-posinset={item.index + 1}
               style={{ position: 'absolute', top: 0, left: 0, right: 0, transform: `translateY(${item.start}px)`, height: item.size }}>
            {rows[item.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Related Skills
- [inp-optimization](../inp-optimization/Skill.md) — presentation delay
- [react-performance-optimization](../react-performance-optimization/Skill.md) — React re-render tuning
- [list-virtualization](../list-virtualization/Skill.md) — windowing details
- [animation-performance](../animation-performance/Skill.md) — motion-specific performance
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md) — tracing workflow
- [container-queries](../container-queries/Skill.md) — CSS instead of resize JS
- [cls-prevention](../cls-prevention/Skill.md) — layout stability

## Sources
- [web.dev: Rendering performance](https://web.dev/articles/rendering-performance) — Official — pixel pipeline
- [web.dev: Avoid large, complex layouts and layout thrashing](https://web.dev/articles/avoid-large-complex-layouts-and-layout-thrashing) — Official — forced reflow guidance
- [web.dev: content-visibility](https://web.dev/articles/content-visibility) — Official — rendering skip & intrinsic size
- [web.dev: Optimize INP (presentation delay, DOM size)](https://web.dev/articles/optimize-inp) — Official — DOM size & content-visibility for interactions
- [Chrome DevTools Performance reference](https://developer.chrome.com/docs/devtools/performance/reference) — Official — insights, selector stats, rendering tools
- [MDN: CSS containment](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_containment) — Official — contain values

## License / Usage Notes
Summarized (web.dev CC BY 4.0, MDN CC BY-SA). Examples original; TanStack Virtual MIT.

## Quality Tier
A — Official browser guidance with React-specific application; DOM size thresholds are Lighthouse heuristics.

## Status
Active

## Last Verified
2026-09-15
