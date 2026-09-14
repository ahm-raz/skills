# INP Optimization

## Summary
Interaction to Next Paint (INP) measures how long the page takes to show visual feedback after clicks, taps and key presses, over the whole page visit. It reports roughly the worst interaction (ignoring one outlier per 50 interactions). Each interaction's latency is input delay + processing duration + presentation delay. The goal is ≤ 200 ms at p75. This skill covers diagnosis (field attribution, LoAF, DevTools) and fixes (yielding, less work per interaction, smaller render cost).

## Category
Performance

## Subcategories
Long tasks, Long Animation Frames (LoAF), scheduler.yield, event handlers, main-thread scheduling, framework re-renders, layout thrashing, TBT

## Problem It Solves
Pages that look loaded but feel laggy: menus open late, typing stutters, "Add to cart" seems ignored. Heavy hydration, big handlers, third-party scripts and expensive re-renders block the main thread between input and the next frame.

## When To Use
- Field INP is above 200 ms, or specific interactions feel sluggish.
- Adding heavy client interactions: filters, editors, large lists, analytics on click.
- After adopting a new framework or state library, or adding third-party tags.

## When Not To Use
- Animation jank not tied to discrete input (scrolling, continuous animation). Use [rendering-performance](../rendering-performance/Skill.md) and [animation-performance](../animation-performance/Skill.md).
- Scroll and hover aren't INP interactions (only click, tap and keyboard count).

## Core Principles
1. **Give feedback in the first frame; defer everything else.** Update the UI that shows a response, then yield before analytics, persistence and secondary updates.
2. **No task over 50 ms during likely interaction windows.** Break long tasks up with `scheduler.yield()` and fallbacks.
3. **Diagnose by phase:**
   - *Input delay* is caused by other work already running (hydration, timers, third parties).
   - *Processing duration* is caused by your event handlers and the framework work they trigger.
   - *Presentation delay* is caused by style, layout, paint and commit cost (DOM size, forced layouts).
4. **Field attribution beats lab guessing.** Find the interaction target, type and responsible scripts (LoAF) from RUM first.
5. **Do less, not just later.** Yielding helps responsiveness, but removing work (smaller DOM, fewer re-renders, memoization) matters more.

## Best Practices
- Use the web-vitals attribution build. Log `interactionTarget`, `interactionType`, the three phases, and `longAnimationFrameEntries` / longest script info.
- Yield inside long loops and after the visual update in handlers.
- Debounce input-driven expensive work (search-as-you-type) and move heavy computation to a worker ([web-workers-offloading](../web-workers-offloading/Skill.md)).
- Avoid layout thrashing: read layout (`offsetHeight`, `getBoundingClientRect`) before writing styles, or batch reads and writes per frame.
- Keep the DOM small (Lighthouse flags large DOMs, roughly > 1,400 nodes). Virtualize long lists ([list-virtualization](../list-virtualization/Skill.md)).
- Use `content-visibility: auto` with `contain-intrinsic-size` for long off-screen sections.
- Load third-party scripts after interaction readiness and audit their LoAF attribution ([third-party-script-management](../third-party-script-management/Skill.md)).
- In React, use `startTransition`/`useDeferredValue` for non-urgent updates. Check that the React Compiler or memoization prevents large subtree re-renders.
- Avoid `alert`/`confirm`/synchronous XHR and synchronous `localStorage` loops in handlers.

## Implementation Guidance

### Yield helper (with fallbacks)
```ts
// src/lib/yield.ts
declare global { interface Scheduler { yield?: () => Promise<void> } var scheduler: Scheduler | undefined }

export function yieldToMain(): Promise<void> {
  if (globalThis.scheduler?.yield) return globalThis.scheduler.yield();   // Chrome/Edge 129+, Firefox 142+
  return new Promise((resolve) => setTimeout(resolve, 0));                // Safari fallback
}

// Yield only when needed (deadline-based) to limit overhead
export async function runChunked<T>(items: Iterable<T>, work: (item: T) => void, budgetMs = 40) {
  let deadline = performance.now() + budgetMs;
  for (const item of items) {
    work(item);
    if (performance.now() >= deadline) {
      await yieldToMain();
      deadline = performance.now() + budgetMs;
    }
  }
}
```
`scheduler.yield()` continuations run before other queued tasks of the same priority, so they don't wait behind third-party tasks the way `setTimeout` continuations can. It isn't supported in Safari as of Sept 2026, so always include the fallback.

### Handler shape: feedback first (React)
```tsx
'use client';
import { useState, useTransition } from 'react';
import { yieldToMain } from '@/lib/yield';

export function AddToCart({ sku }: { sku: string }) {
  const [added, setAdded] = useState(false);
  const [isPending, startTransition] = useTransition();

  async function onClick() {
    setAdded(true);                       // 1. urgent, cheap visual feedback, committed first
    await yieldToMain();                  // 2. let React commit and the browser paint
    startTransition(() => {               // 3. non-urgent re-render (cart drawer, recommendations)
      updateCartStore(sku);
    });
    queueMicrotask(() => analytics.track('add_to_cart', { sku })); // 4. after work is scheduled; keep it cheap
  }

  return (
    <button onClick={onClick} aria-busy={isPending}>
      {added ? 'Added ✓' : 'Add to cart'}
    </button>
  );
}
```
`updateCartStore` and `analytics` are app-specific placeholders. React 18+ batches the `setAdded` update and paints it before the awaited continuation runs.

### Phase → fix table
| Phase dominant | Diagnose with | Fix |
|---|---|---|
| Input delay | LoAF scripts overlapping the interaction; long tasks during load | Break up hydration/boot work, defer third parties, lazy-init widgets, `requestIdleCallback` for non-critical setup |
| Processing duration | DevTools: handler + framework work under the interaction | Yield after feedback, debounce, memoize, move computation to a worker, avoid re-rendering whole trees |
| Presentation delay | Long style/layout/paint after handlers; forced reflow insight | Smaller DOM, `content-visibility`, avoid layout thrash, avoid huge `innerHTML` writes, cheaper CSS selectors |

### LoAF observation (field diagnosis)
```js
new PerformanceObserver((list) => {
  for (const f of list.getEntries()) {
    if (f.blockingDuration < 100) continue;
    const scripts = f.scripts.map((s) => ({
      src: s.sourceURL, fn: s.sourceFunctionName, invoker: s.invoker,
      dur: Math.round(s.duration), forcedLayout: Math.round(s.forcedStyleAndLayoutDuration),
    }));
    report({ blocking: f.blockingDuration, scripts });
  }
}).observe({ type: 'long-animation-frame', buffered: true });
```
LoAF is Chromium-only (Chrome 123+), not Baseline.

## Recommended Workflow
1. Get the field INP distribution by template. List the top interaction targets and types from attribution.
2. Reproduce in DevTools: enable 4× (or calibrated) CPU throttling, record, do the interaction, and read the "INP breakdown" insight and the Interactions track.
3. Decide the dominant phase and apply the matching fix from the table.
4. Recheck with the same interaction. Interaction latency in the trace should be < 200 ms on throttled CPU.
5. Check load-time INP: interact during hydration (input delay is usually worst early).
6. Ship, then watch RUM INP for that target. Add a LoAF-based alert for new offending scripts.

## Patterns
- **Optimistic feedback + yield**: update the UI, yield, then persist ([optimistic-ui](../optimistic-ui/Skill.md)).
- **Deadline-based chunking**: yield every ~40–50 ms rather than every item.
- **Idle-until-urgent** (Philip Walton): compute lazily in `requestIdleCallback`, but compute synchronously if needed sooner.
- **Worker for pure computation**: parsing, sorting, diffing and search indexing via Comlink.
- **Progressive rendering of large updates**: render the first N results, then append the rest after yielding.

## Anti-Patterns
- **Yielding before visual feedback**: the user still waits. Fix: update the visible state first.
- **`await` on a resolved promise as a "yield"**: microtasks don't yield to rendering. Fix: `scheduler.yield()` or `setTimeout`.
- **Synchronous analytics in click handlers** (third-party `track` calls that serialize big payloads). Fix: queue, then yield, or send via beacon after paint.
- **Re-rendering the whole app on each keystroke** (global store subscription). Fix: selector-based subscriptions, transitions, colocated state.
- **Reading `offsetWidth` in a loop after writing styles**: forced synchronous layout per iteration. Fix: batch reads, then writes.
- **Relying on TBT alone**: TBT has no interactions. Fix: test real interactions and use field INP.

## Accessibility
- Show busy state with `aria-busy` or disabled plus visible feedback when work continues after yielding. Don't leave the user unsure whether the click registered.
- Keyboard interactions count toward INP. Test Enter/Space on custom controls and typing in inputs.
- Deferred updates must not move focus unexpectedly. Keep focus stable when chunked rendering appends content.

## Responsive Design
- Low-end mobile CPUs are 4–10× slower than dev laptops. Always test throttled or on real mid-tier Android.
- Touch interactions include the pointerdown→click sequence. Avoid heavy `touchstart` handlers and use passive listeners.

## Performance
- Yielding adds a little total time. Use deadline-based yielding to avoid thousands of tiny tasks.
- `content-visibility` is Baseline 2024. Reserve space with `contain-intrinsic-size: auto <size>` to avoid scrollbar jumps.
- Hydration improvements ([hydration-strategies](../hydration-strategies/Skill.md)) often reduce input delay more than handler tuning.

## Security
- LoAF `sourceURL` can contain query tokens. Strip query strings before sending to RUM.
- Don't move sensitive computations into third-party workers or iframes just to improve INP.

## Testing
- Playwright: click a control and measure the time to a DOM change with `performance.now()` inside `page.evaluate`. Use it as a smoke check, not an exact INP.
- Use a DevTools trace or Chrome DevTools MCP (`performance_start_trace`, interact, `performance_stop_trace`, `performance_analyze_insight` for INP breakdown).
- Lighthouse timespan mode (user flows) reports INP for scripted interactions in the lab.
- Regression: RUM alert when p75 INP for a template exceeds 200 ms for 3 consecutive days.

## Tooling
- Chrome DevTools Performance panel: live metrics interaction log, INP breakdown insight. Active.
- web-vitals v6 attribution build (LoAF data). Active.
- Long Animation Frames API: Chromium-only, stable since Chrome 123.
- `scheduler.yield()`: Chrome/Edge 129+, Firefox 142+, no Safari. `scheduler.postTask()`: Chromium and Firefox.
- Lighthouse user flows (timespan). Active.
- React DevTools Profiler and React performance tracks in the Chrome Performance panel (React 19.2+). Active.
- Vercel Speed Insights (INP per route for Next.js on Vercel). Active.

## Framework Notes
- **React (Vite SPA and Next.js)**: this skill decides *which phase* to fix. React-specific re-render techniques belong to [react-performance-optimization](../react-performance-optimization/Skill.md) and [react-compiler](../react-compiler/Skill.md). The INP-relevant React tools are:
  - `useTransition`/`startTransition` marks non-urgent state updates as interruptible, so the urgent update (input value, pressed state) commits and paints first. `isPending` provides feedback.
  - `useDeferredValue` renders expensive derived UI (filtered lists, charts) against a lagging value.
  - React DevTools Profiler ("Highlight updates", commit durations) shows what re-rendered for an interaction. Pair it with the Chrome trace's React "Scheduler" and "Components" custom tracks (React 19.2+ performance tracks).
  - Avoid context providers whose value changes on every keystroke high in the tree ([react-context-patterns](../react-context-patterns/Skill.md)).
- **Vite SPA**: the whole app hydrates or mounts at boot, so input delay during load is common. Lazy-load routes and heavy widgets ([code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md)).
- **Next.js**: every `'use client'` subtree hydrates at load and competes with early interactions. Keep static content in Server Components, push `'use client'` to leaves, and `next/dynamic` non-critical client widgets. Load tags with `next/script` `lazyOnload`. Server Actions triggered by forms: show pending UI with `useFormStatus`/`useActionState` immediately so the next paint isn't blocked on the network. See [nextjs-performance](../nextjs-performance/Skill.md).

## AI Agent Guidance
- Do: identify the interaction and phase before editing. Cite the trace or attribution data.
- Do: use the `yieldToMain` helper with fallback. Never ship `scheduler.yield()` without feature detection.
- Do: preserve feedback-first ordering in handlers you modify.
- Don't: wrap everything in `setTimeout` blindly or add `useMemo` everywhere without profiler evidence.
- Don't: move DOM-touching code into workers (they have no DOM access).
- Before declaring done: re-trace the same interaction under CPU throttling, confirm it's < 200 ms with the phase reduced, check that focus and ARIA states still work, and check that no new long tasks appeared at load.

## Examples
```tsx
// React: keep typing responsive while filtering a large list
const [query, setQuery] = useState('');
const deferredQuery = useDeferredValue(query);
const results = useMemo(() => filter(items, deferredQuery), [items, deferredQuery]);
return (<>
  <input value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Filter" />
  <Results items={results} stale={query !== deferredQuery} />
</>);
```

```css
/* Cheaper rendering for long pages */
.feed-section { content-visibility: auto; contain-intrinsic-size: auto 800px; }
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md) — thresholds and field data
- [rendering-performance](../rendering-performance/Skill.md) — presentation delay, layout thrash
- [web-workers-offloading](../web-workers-offloading/Skill.md) — moving computation off the main thread
- [third-party-script-management](../third-party-script-management/Skill.md) — input delay from tags
- [hydration-strategies](../hydration-strategies/Skill.md) — load-time input delay
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md) — tracing interactions
- [react-performance-optimization](../react-performance-optimization/Skill.md) — React-specific re-render fixes
- [list-virtualization](../list-virtualization/Skill.md) — DOM size reduction

## Sources
- [Optimize Interaction to Next Paint](https://web.dev/articles/optimize-inp) — Official — phases and fix strategies
- [Interaction to Next Paint](https://web.dev/articles/inp) — Official — definition, outlier handling, thresholds
- [Optimize long tasks](https://web.dev/articles/optimize-long-tasks) — Official — yielding patterns
- [MDN Scheduler.yield()](https://developer.mozilla.org/en-US/docs/Web/API/Scheduler/yield) — Official — API and support
- [MDN PerformanceLongAnimationFrameTiming](https://developer.mozilla.org/en-US/docs/Web/API/PerformanceLongAnimationFrameTiming) — Official — LoAF fields, experimental status
- [DebugBear: scheduler.yield guide](https://www.debugbear.com/blog/scheduler-yield) — Community — Firefox 142 support, fallback
- [web-vitals v5/v6 changelog](https://github.com/GoogleChrome/web-vitals/blob/main/CHANGELOG.md) — Open Source — INP attribution with LoAF

## License / Usage Notes
web.dev CC BY 4.0, MDN CC BY-SA 2.5, web-vitals Apache-2.0. Summarized, with original code.

## Quality Tier
S — Official methodology, verified API support matrix (Sept 2026), concrete diagnosis-to-fix mapping.

## Status
Active

## Last Verified
2026-09-15
