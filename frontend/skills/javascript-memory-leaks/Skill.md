# JavaScript Memory Leaks

## Summary
A memory leak is memory the app no longer needs but keeps reachable—so the garbage collector can't free it. In long-lived React SPAs and Next.js client sessions (dashboards, editors, chat), leaks accumulate across navigations and cause growing heap, GC pauses (jank, poor INP), tab crashes on mobile, and "Aw, Snap" reloads. On the Next.js server, module-level caches and unbounded maps leak across requests. This skill covers common leak sources, prevention patterns in React, and the heap-snapshot diagnosis workflow.

## Category
Performance

## Subcategories
Heap snapshots, detached DOM, effect cleanup, event listeners, timers, subscriptions, closures, caches, AbortController, WeakMap/WeakRef, server-side leaks, MemLab

## Problem It Solves
Apps that get slower the longer they're open, mobile tabs that reload unexpectedly, memory growth after repeated route changes or modal opens, and Node server memory climbing until OOM restarts.

## When To Use
- Memory in Task Manager / Performance monitor grows steadily with repeated actions.
- INP/jank worsens over session length; GC ("Major GC") events frequent in traces.
- Building long-lived views: dashboards with polling, websockets, maps, editors, virtualized lists.
- Next.js server memory growth in production metrics.

## When Not To Use
- One-time high memory that plateaus (large but stable data) → data design / virtualization, not leaks.
- Initial load size issues → [bundle-optimization](../bundle-optimization/Skill.md).

## Core Principles
1. **Everything you start, you stop**: listeners, timers, observers, subscriptions, sockets, animation frames, fetches → cleanup on unmount.
2. **Bound every cache**: size/TTL limits; never unbounded module-level `Map`s (client or server).
3. **Don't retain DOM from JS after removal** (detached nodes via refs, closures, globals).
4. **Diagnose with repeated-action snapshots**, not single snapshots.
5. **Server modules are shared across requests**: request data must never go into module scope.

## Best Practices
- Every `useEffect` that subscribes returns a cleanup; lint with `react-hooks/exhaustive-deps` and the React Compiler lint rules.
- Use one `AbortController` per effect to remove multiple listeners and cancel fetches at once.
- Libraries with instances (maps, charts, editors, Monaco, Leaflet, Chart.js) must be `destroy()`ed on unmount.
- Prefer `IntersectionObserver`/`ResizeObserver` with `disconnect()` in cleanup.
- Global stores: unsubscribe; avoid storing DOM nodes or component instances in stores.
- TanStack Query / SWR caches: set sensible `gcTime`; don't key queries by unbounded unique values (timestamps).
- Use `WeakMap` for metadata keyed by objects/DOM nodes; avoid `WeakRef`/`FinalizationRegistry` for program logic (non-deterministic).
- Strict Mode double-invokes effects in development—use it to catch missing cleanups.
- On Next.js server: use `React.cache` (per-request memoization) or framework caching instead of module-level maps; LRU with max size if a process cache is needed.

## Implementation Guidance

### Common leak sources (client)
| Source | Symptom in heap snapshot | Fix |
|---|---|---|
| `addEventListener` on `window`/`document` without removal | Closures retaining component state; listener count grows | Cleanup / `AbortController` signal |
| `setInterval`/`setTimeout` recursion | Retained closures, growing timers | `clearInterval` in cleanup |
| WebSocket/EventSource subscriptions | Retained handlers, messages arrays | Close/unsubscribe on unmount |
| Third-party widget instances | Detached `<div>`/`<canvas>` trees | Call `destroy()`/`dispose()` |
| Refs/globals holding removed DOM | "Detached" DOM nodes | Null refs, don't store nodes globally |
| Unbounded arrays (logs, message history) | Large Arrays/Strings growing | Cap length, virtualize, paginate |
| Memoized caches keyed by objects created each render | Map entries grow | WeakMap or bounded LRU |
| Console logging objects in production | Objects retained by DevTools console | Strip logs in prod builds |

### Effect cleanup pattern
```tsx
'use client';
import { useEffect } from 'react';

export function useLiveTicker(symbol: string, onPrice: (p: number) => void) {
  useEffect(() => {
    const ac = new AbortController();
    const ws = new WebSocket(`wss://prices.example.com/${encodeURIComponent(symbol)}`);
    ws.addEventListener('message', (e) => onPrice(JSON.parse(e.data).price), { signal: ac.signal });
    window.addEventListener('online', () => ws.readyState > 1 && location.reload(), { signal: ac.signal });
    const id = window.setInterval(() => ws.readyState === 1 && ws.send('ping'), 25_000);

    fetch(`/api/history?symbol=${encodeURIComponent(symbol)}`, { signal: ac.signal }).catch(() => {});

    return () => {                // runs on unmount and before re-running for a new symbol
      ac.abort();                 // removes listeners + cancels fetch
      clearInterval(id);
      ws.close();
    };
  }, [symbol, onPrice]);          // stable onPrice (useCallback or React Compiler) to avoid reconnect churn
}
```

### Third-party instance cleanup
```tsx
useEffect(() => {
  if (!ref.current) return;
  const chart = new Chart(ref.current, config);
  return () => chart.destroy();
}, [config]);
```

### Bounded cache
```ts
export class LruCache<K, V> {
  #map = new Map<K, V>();
  constructor(private max = 500) {}
  get(k: K) { const v = this.#map.get(k); if (v !== undefined) { this.#map.delete(k); this.#map.set(k, v); } return v; }
  set(k: K, v: V) { this.#map.delete(k); this.#map.set(k, v); if (this.#map.size > this.max) this.#map.delete(this.#map.keys().next().value as K); }
}
```

### Server-side (Next.js) leak example
```ts
// BAD: module scope shared by all requests; grows forever and can leak user data across users
const userCache = new Map<string, User>();

// GOOD: per-request memoization
import { cache } from 'react';
export const getUser = cache(async (id: string) => db.user.findUnique({ where: { id } }));
```

## Recommended Workflow
1. **Confirm**: DevTools → Performance monitor (JS heap size, DOM nodes, JS event listeners) while repeating an action (open/close modal, navigate A→B→A) 10–20×. Steady growth after forced GC = leak.
2. **Three-snapshot technique** (Memory panel): snapshot 1 (baseline) → repeat action N times → snapshot 2 → repeat N times → snapshot 3. Compare 3 vs 2 ("Comparison" view), sort by `# New`/Size Delta; objects growing in multiples of N are suspects.
3. Filter "Detached" nodes (Summary view filter / "Detached elements" panel) to find removed DOM still retained.
4. Inspect **Retainers** of a suspect to find the path (listener → closure → component state).
5. Use **Allocation instrumentation on timeline** for allocations that aren't freed.
6. Fix, repeat the same procedure; automate with MemLab or a Playwright heap check for critical flows.
7. Server: `node --inspect` (`NODE_OPTIONS='--inspect' next start`), take heap snapshots under load, compare; monitor RSS/heap in production.

## Patterns
- **AbortController per effect** for listeners + fetch.
- **Owner-disposes-instance**: whoever creates an instance destroys it in the same effect.
- **Bounded collections**: ring buffers for logs/messages, LRU for caches.
- **Per-request state** on the server via `React.cache`, request-scoped objects, never module scope.
- **Repeated-action leak test** in CI for critical flows.

## Anti-Patterns
- **Effects without cleanup for subscriptions/timers**. Fix: return cleanup.
- **Storing component callbacks in global event buses without unsubscribe**. Fix: unsubscribe in cleanup.
- **Caching fetched data in module-level objects on the Next.js server** → cross-user data leakage + memory growth. Fix: framework caching / `React.cache` / bounded external cache.
- **Keeping full history of real-time data in state**. Fix: cap and aggregate.
- **Relying on page reloads to "clean up" in SPAs**. Fix: proper cleanup; long sessions are normal.
- **Using `WeakRef` to paper over retention bugs**. Fix: find the retainer.

## Accessibility
- Leak-induced jank and tab crashes disproportionately affect users on low-memory devices and assistive tech (screen readers add memory overhead); stability is an accessibility concern.
- Cleanup must also remove global keyboard shortcuts and focus traps when components unmount ([keyboard-navigation](../keyboard-navigation/Skill.md)).

## Responsive Design
- Mobile browsers aggressively discard background tabs and crash at lower heap limits—test leak scenarios on real low-RAM Android devices.

## Performance
- Growing heaps increase GC frequency and pause times, surfacing as long tasks and INP regressions late in sessions.
- `performance.measureUserAgentSpecificMemory()` (Chromium, requires cross-origin isolation) can report memory in RUM; sample sparingly.

## Security
- Server module-level caches can serve one user's data to another—both a leak and a data breach.
- Heap snapshots contain tokens/PII; treat them as sensitive, don't attach to public issues.

## Testing
- MemLab (Meta) scenario files: define `url`, `action`, `back`; it detects leaked objects between states.
- Playwright + CDP: `HeapProfiler.collectGarbage` then `Runtime.getHeapUsage` before/after N iterations; assert growth below threshold.
- React Strict Mode in dev to expose missing cleanups; unit tests that unmount and assert `removeEventListener`/`destroy` calls.

## Tooling
- Chrome DevTools Memory panel (heap snapshots, allocation timeline, detached elements), Performance monitor — Active.
- MemLab (facebook/memlab) — Open Source; verify maintenance activity before adopting.
- Node.js inspector / `--heapsnapshot-near-heap-limit` — Active.
- `eslint-plugin-react-hooks` (incl. React Compiler rules) — Active.

## Framework Notes
- **React (Vite SPA)**: sessions are long; leaks accumulate across client routes. Route components must clean up; global stores must not retain unmounted component references. React Router loaders' data is released on navigation—don't copy it into module globals.
- **Next.js**: client leaks as above (App Router keeps layouts mounted across navigations—effects in layouts live long; ensure they're bounded). Server leaks: never store per-request data in module scope; `React.cache` is per-request; the fetch/data caches are managed by Next ([nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md)).

## AI Agent Guidance
- Do: add cleanup for every subscription/timer/listener/instance you create in effects; prefer AbortController.
- Do: bound any cache or history array you introduce.
- Don't: introduce module-level mutable state in Next.js server code.
- Don't: claim a leak fix without a repeated-action measurement.
- Before declaring done: repeat the action 20× with forced GC; heap and DOM node counts return near baseline; no detached nodes from the component; Strict Mode dev shows no duplicate subscriptions.

## Examples
```js
// memlab scenario (scenario.js)
module.exports = {
  url: () => 'http://localhost:3000/dashboard',
  action: async (page) => { await page.click('[data-testid="open-report"]'); },
  back: async (page) => { await page.click('[data-testid="close-report"]'); },
};
// npx memlab run --scenario scenario.js
```

## Related Skills
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md) — trace & memory tools
- [react-hooks-patterns](../react-hooks-patterns/Skill.md) — effect cleanup discipline
- [realtime-data-ui](../realtime-data-ui/Skill.md) — sockets and streaming data
- [list-virtualization](../list-virtualization/Skill.md) — bounding DOM for large data
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — server caching instead of module maps
- [inp-optimization](../inp-optimization/Skill.md) — GC-induced long tasks

## Sources
- [Chrome DevTools: Fix memory problems](https://developer.chrome.com/docs/devtools/memory-problems) — Official — heap snapshots, detached DOM, allocation timeline
- [Chrome DevTools: Heap snapshots](https://developer.chrome.com/docs/devtools/memory-problems/heap-snapshots) — Official — comparison & retainers
- [React: useEffect cleanup](https://react.dev/reference/react/useEffect) — Official — cleanup semantics, Strict Mode double-invocation
- [React: cache](https://react.dev/reference/react/cache) — Official — per-request memoization
- [MemLab](https://github.com/facebook/memlab) — Open Source — automated leak detection
- [web.dev: Monitor total memory usage](https://web.dev/articles/monitor-total-page-memory-usage) — Official — measureUserAgentSpecificMemory

## License / Usage Notes
Summarized. MemLab MIT. Examples original.

## Quality Tier
A — Established official diagnosis workflow plus React/Next-specific leak sources; MemLab maintenance not re-verified for Sept 2026.

## Status
Active

## Last Verified
2026-09-15
