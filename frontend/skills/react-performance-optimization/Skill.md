# React Performance Optimization

## Summary
A measurement-first playbook for fast React apps in 2026. In rough order of impact: eliminate data waterfalls, cut bundle size, render less on the server/client boundary, avoid unnecessary re-renders (structurally or with React Compiler), keep interactions responsive with transitions, and virtualize large lists. It builds on the Vercel react-best-practices rule priorities and React 19.2/19.3 features (Activity, Performance Tracks, independent transitions).

## Category
React

## Subcategories
waterfalls, bundle size, re-renders, memoization, transitions, virtualization, code splitting, profiling, INP

## Problem It Solves
Slow initial loads (LCP), janky typing and clicks (INP), and wasted CPU from re-render cascades. On top of that, people often "optimize" with blanket `useMemo`/`useCallback`, which adds complexity without measured gains.

## When To Use
- A Core Web Vitals regression, a slow interaction or a heavy bundle is reported.
- Reviewing React code for performance.
- Building data-heavy UIs (tables, dashboards, editors, feeds).

## When Not To Use
- Before measuring, unless a rule is a free structural win (no waterfalls, no inline component definitions).
- General web performance (images, fonts, HTTP caching): see the W12 skills.

## Core Principles
1. **Measure → hypothesize → fix → re-measure.** Use Profiler, Performance panel and RUM.
2. **Prioritize by impact**: waterfalls and bundle size (critical) > server rendering costs > client data fetching > re-renders > rendering micro-costs > JS micro-optimizations.
3. **Structure beats memoization**: move state down, lift content up, split contexts, narrow selectors.
4. **Let the React Compiler memoize.** Hand-written `memo`/`useMemo`/`useCallback` is for targeted cases.
5. **Keep urgent updates cheap.** Defer expensive re-rendering with `useTransition`/`useDeferredValue`.
6. **Don't render what isn't visible**: virtualize, code-split, `Activity`, `content-visibility`.

## Best Practices
**Waterfalls (critical)**
- `Promise.all` for independent async work. Start promises early, await late.
- Fetch in route loaders/RSC in parallel, not in nested child effects.
- Prefetch on hover/intent (router `preload`, `queryClient.prefetchQuery`).

**Bundle (critical)**
- Import directly from module paths instead of barrel files (or use bundler `optimizePackageImports`).
- Lazy-load heavy, below-the-fold or conditional components (`React.lazy` + Suspense, `next/dynamic`).
- Defer third-party analytics until after hydration or idle.
- Keep static-only rendering in Server Components.

**Re-renders (medium)**
- Never define components inside components.
- Subscribe to derived booleans (`useStore(s => s.items.length > 0)`), not raw collections.
- Use functional `setState` for stable callbacks. Use lazy state init for expensive initial values.
- Put transient high-frequency values (pointer position, scroll) in refs or CSS variables when they don't need to re-render UI.
- Hoist static JSX and default non-primitive props (`const EMPTY: Item[] = []`) out of components.
- Use `startTransition` for non-urgent updates. Show `isPending` instead of blocking.

**Rendering (medium)**
- Virtualize lists over ~200 complex rows (TanStack Virtual, react-virtuoso).
- `content-visibility: auto` with `contain-intrinsic-size` for long static sections.
- Use `<Activity>` for tab and panel hide/show that should preserve state.
- Use ternaries instead of `&&` when the left side can be `0`/`NaN` (a render bug, and it causes extra nodes).

## Implementation Guidance
**Symptom → first fix**

| Symptom | Likely cause | First fix |
|---|---|---|
| Slow LCP, many sequential requests | Waterfall | Parallelize, loaders/RSC, preload |
| Large JS, slow TTI/hydration | Bundle | Code split, remove barrels, server components |
| Typing lag in search box | Expensive list re-render per keystroke | `useDeferredValue` + compiled or memoized list, virtualize |
| Whole page re-renders on small change | State too high / broad context | Move state down, split context, selectors |
| Click feels frozen | Long synchronous render | `startTransition`, split work, yield |
| Scroll jank in long list | Too many DOM nodes | Virtualization |
| Tab switch re-fetches / loses state | Unmounting | `<Activity>` or query cache |

**When manual memoization still makes sense (even with the compiler)**
- A value is an effect dependency and must be referentially stable.
- Passing props to third-party components that rely on reference equality.
- A codebase or file where the compiler bails out (inspect in DevTools: compiled components show a "Memo ✨" badge).

```tsx
// Deferred expensive list
function Search({ items }: { items: Item[] }) {
  const [q, setQ] = useState("");
  const dq = useDeferredValue(q);
  const stale = q !== dq;
  return (
    <>
      <input value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search" />
      <div style={{ opacity: stale ? 0.6 : 1 }}><Results items={items} query={dq} /></div>
    </>
  );
}
const Results = memo(function Results({ items, query }: { items: Item[]; query: string }) {
  const filtered = items.filter((i) => i.name.toLowerCase().includes(query.toLowerCase()));
  return <VirtualList rows={filtered} />;
}); // memo unnecessary if React Compiler is enabled
```

## Recommended Workflow
1. Capture field data (RUM: LCP, INP, CLS) and identify the worst pages or interactions.
2. Reproduce locally with a production build and CPU throttling.
3. Record in Chrome Performance panel. Read React Performance Tracks (Scheduler / Components) and long tasks.
4. Use React DevTools Profiler to find expensive commits and why components rendered.
5. Apply the highest-priority applicable fix (waterfall > bundle > re-render).
6. Re-measure. Add a regression guard (bundle budget, Lighthouse CI, interaction benchmark).

## Patterns
- **Split context by change frequency**: `ThemeContext` (static) separate from `SelectionContext` (volatile).
- **Container that owns volatile state + memo-free children via `children`.**
- **Preload on intent**: `onMouseEnter={() => queryClient.prefetchQuery(projectQuery(id))}`.
- **Idle deferral**: `requestIdleCallback` for non-critical work (analytics, warming caches).
- **Index maps**: build `Map` by id once per data change instead of `array.find` in every row.
- **CSS variables for continuous values**: `el.style.setProperty("--x", ...)` instead of `setState` on pointermove.

## Anti-Patterns
- **Blanket `useCallback`/`useMemo`**: overhead and noise, often ineffective when children aren't memoized. Fix: remove, and rely on structure or the compiler.
- **`React.memo` with inline object/function props**: always fails the comparison. Fix: stable props, or the compiler.
- **Inline component definitions**: remount every render. Fix: module-scope components.
- **Fetching in child `useEffect` after parent fetch**: waterfall. Fix: hoist to loader or parallel queries.
- **Barrel imports of icon or UI libraries**: large bundles and slow dev. Fix: direct imports or `optimizePackageImports`.
- **Putting everything in one context**: global re-renders. Fix: split contexts or a selector store.
- **Rendering 10k rows**: DOM cost dominates. Fix: virtualization or pagination.
- **Premature `useLayoutEffect`**: blocks paint. Fix: `useEffect` unless measuring layout.

## Accessibility
- Virtualized lists must keep semantics (`role="grid"`/`aria-rowcount`/`aria-rowindex`) and keyboard navigation. Consider pagination for screen-reader-heavy use.
- Deferred or stale UI should indicate loading (`aria-busy`) and not move focus.
- Lazy-loaded components need accessible fallbacks. Don't lazy-load focus targets of open dialogs.

## Responsive Design
- Test performance on low-end mobile CPU profiles (4–6x throttle). Budgets should target mobile.
- Avoid JS-driven responsive re-renders on resize. Use CSS; React 19.3 batches resize-event updates to the next frame.
- Serve smaller component sets for mobile only via CSS or container queries, not duplicated trees.

## Performance
This entire skill is about performance. Key numeric targets: INP < 200 ms, LCP < 2.5 s (p75), and keep route-level JS within the team budget (e.g. < 170 KB gz for initial route on mobile).

## Security
- Code-split chunks are public. Don't gate secrets behind lazy loading.
- Third-party performance scripts: load with CSP-compliant nonces, and audit supply chain.

## Testing
- Lighthouse CI / WebPageTest budgets in CI for lab metrics.
- Bundle size checks (size-limit, bundler analyzer) on PRs.
- Interaction benchmarks with Playwright + `PerformanceObserver` (event timing) for critical flows.
- Don't unit-test render counts except for library code. Test user-perceived behaviour.

## Tooling
- React DevTools Profiler; React Performance Tracks in Chrome DevTools (React 19.2+).
- React Compiler 1.x + `eslint-plugin-react-hooks` compiler rules.
- `react-scan` (community) for re-render visualization.
- TanStack Virtual / react-virtuoso for virtualization.
- `@next/bundle-analyzer`, `vite-bundle-visualizer`/`rollup-plugin-visualizer`, `size-limit`.
- `web-vitals` library for RUM.
- Legacy: `why-did-you-render` is mostly superseded by the Profiler and react-scan, and is not compatible with compiled code in all cases.

## Framework Notes
### React (Vite SPA)
- The initial load is limited by JS size, because nothing renders until the bundle executes. Split by route with `React.lazy`, and keep the entry chunk minimal.
- Prefetch data on intent with `queryClient.prefetchQuery` and preload route chunks on hover or focus.
- Enable the React Compiler through the Vite 8 Babel preset (see react-compiler), and analyze bundles with `rollup-plugin-visualizer`.

### Next.js App Router
- **Server Components are the biggest lever**: non-interactive UI and heavy rendering libraries ship zero JS. Push `"use client"` to the leaves.
- Stream slow data behind `<Suspense>`/`loading.tsx` so the shell and LCP element render first. Never put the LCP element behind a slow boundary.
- `next/dynamic` for heavy client-only widgets (`ssr: false` only inside Client Components). `experimental.optimizePackageImports` for barrel-heavy libraries.
- `<Link>` prefetches automatically in production for static routes. Avoid rendering hundreds of prefetching links at once.
- `after()` for logging or analytics after the response. `React.cache` for per-request deduplication.
- Hydration cost scales with Client Component size. Large client trees near the root hurt INP on low-end devices.
- `reactCompiler: true` in `next.config.ts` enables the compiler with SWC-based file filtering. See nextjs-performance for framework caching and images.

## AI Agent Guidance
- Ask for, or gather, measurements before proposing memoization-heavy changes.
- Apply critical rules proactively in new code: no waterfalls, no barrel imports of heavy libraries, no inline component definitions, lazy-load heavy optional UI.
- If the React Compiler is enabled, don't add `useMemo`/`useCallback`/`memo` unless one of the targeted cases applies.
- Verify: production build size diff, Profiler before and after, no behaviour change, and a11y intact on virtualized UI.

## Examples
```ts
// Eliminate waterfall in a Next.js App Router page (Server Component)
export default async function CustomerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const userP = getUser(id);
  const ordersP = getOrders(id);                 // started concurrently
  const [user, orders] = await Promise.all([userP, ordersP]);
  return (
    <>
      <CustomerHeader user={user} />
      <OrdersTable orders={orders} />
      <Suspense fallback={<RecommendationsSkeleton />}>
        <Recommendations userId={id} />        {/* slow, non-critical: streamed */}
      </Suspense>
    </>
  );
}
```

## Related Skills
- [react-compiler](../react-compiler/Skill.md): automatic memoization
- [react-rendering-model](../react-rendering-model/Skill.md): why re-renders happen
- [inp-optimization](../inp-optimization/Skill.md): interaction responsiveness
- [bundle-optimization](../bundle-optimization/Skill.md): bundle reduction
- [list-virtualization](../list-virtualization/Skill.md): large lists
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md): lazy loading
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md): profiling technique

## Sources
- [vercel-labs/agent-skills react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) (Open Source/Community): 8-category prioritized rule set (waterfalls, bundle, server, client fetch, re-render, rendering, JS, advanced)
- [react.dev: memo / useMemo / useTransition / useDeferredValue](https://react.dev/reference/react/useDeferredValue) (Official): API semantics
- [React 19.2 post](https://react.dev/blog/2025/10/01/react-19-2) (Official): Activity, Performance Tracks
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): independent transitions, resize batching
- [React Compiler v1.0](https://react.dev/blog/2025/10/07/react-compiler-1) (Official): memoization guidance
- [Dan Abramov: Before You memo()](https://overreacted.io/before-you-memo/) (Community): structural fixes

## License / Usage Notes
Vercel agent-skills is MIT; React docs are CC-BY-4.0. Rules are paraphrased and reordered, not copied.

## Quality Tier
S: combines official APIs with the most-adopted community agent rule set, and prioritized by impact.

## Status
Active

## Last Verified
2026-09-15
