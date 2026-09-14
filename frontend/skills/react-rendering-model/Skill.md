# React Rendering Model

## Summary
This is the mental model of how React turns state into UI: render (calling components), reconciliation (diffing element trees by type and key), commit (applying DOM mutations), and effects. It also covers what triggers re-renders, batching, concurrent rendering (transitions, Suspense, `Activity`), Strict Mode, and hydration. Almost every performance and correctness decision in React depends on this model.

## Category
React

## Subcategories
render and commit phases, reconciliation and keys, state identity and preservation, batching, concurrent rendering, Strict Mode, hydration, Activity

## Problem It Solves
Developers misread why components re-render, why state resets or persists unexpectedly, why effects run twice, and why hydration errors appear. That leads to wrong fixes like sprinkling `memo`, random keys or `suppressHydrationWarning` everywhere.

## When To Use
- Debugging unexpected re-renders, lost state or stale UI.
- Designing list keys, conditional trees and component boundaries.
- Understanding transitions, Suspense and SSR hydration behaviour.

## When Not To Use
- As a reason to micro-optimize before measuring. Most re-renders are cheap.
- Framework caching (Next.js cache layers) is a separate topic.

## Core Principles
1. **UI = f(state)**. Rendering is calling your component functions, and it must be pure. React may render without committing, render twice (Strict Mode), or throw away renders (transitions).
2. **A component re-renders when**: its state updates, its parent re-renders (regardless of props, unless memoized), or a context it reads changes. Props changing is not itself a trigger.
3. **Commit only touches changed DOM.** Re-rendering is not re-painting.
4. **State is tied to a position in the tree** (component type + position + key), not to the component variable.
5. **Same type at the same position keeps state. A different type or key resets the whole subtree.**
6. **Updates are batched** automatically in handlers, promises and timeouts (React 18+).
7. **State is a snapshot per render.** `setState` schedules a new render and doesn't mutate the current variable.
8. **Urgent vs non-urgent**: updates in `startTransition` are interruptible and can be discarded.

## Best Practices
- Use stable, unique keys from data (`item.id`). Never array index for reorderable, filterable or insertable lists. Never `Math.random()`.
- Use `key` on purpose to reset state (`<Editor key={docId} />`).
- Keep component types stable. Don't define components inside components, and don't switch wrapper element types conditionally around stateful children.
- Keep Strict Mode on in development. It double-invokes renders, initializers and effects (including during hydration since 19.3) to surface impurity.
- Make server and client first renders identical. Read browser-only values after hydration (`useSyncExternalStore` with a server snapshot, or `use(browser())` in React 19.3 inside a Suspense boundary).
- Use `<Activity mode="hidden">` (19.2+) to hide UI while preserving state and deprioritizing updates, instead of unmounting or CSS-hiding heavy trees.

## Implementation Guidance
**What re-renders?**

| Event | Re-renders |
|---|---|
| `setState` in component C | C and all descendants (unless a descendant is memoized with equal props, or compiled by the React Compiler) |
| Parent re-renders | Child, even with identical props |
| Context value changes (by `Object.is`) | Every component that reads that context via `use`/`useContext` |
| External store change (`useSyncExternalStore`) | Subscribers whose snapshot changed |
| `setState` with the same value (`Object.is`) | Bails out (may render C once before bailing) |

**Pipeline**
1. Trigger (initial root render or a state update).
2. Render: call components and build the new element tree. Must be pure and may be interrupted (concurrent).
3. Reconcile: compare with the previous tree by type/key and compute minimal changes.
4. Commit: mutate the DOM, attach refs, run `useLayoutEffect`s, and the browser paints.
5. Passive effects (`useEffect`) run after paint.

**State preservation examples**
```tsx
// Same position + same type => state preserved when isFancy toggles
{isFancy ? <Counter isFancy /> : <Counter />}

// Different positions => state reset
{isFancy && <Counter isFancy />}
{!isFancy && <Counter />}

// Force reset per entity
<ChatInput key={contactId} />
```

**Transitions and deferred values**
```tsx
const [isPending, startTransition] = useTransition();
function selectTab(next: Tab) {
  startTransition(() => setTab(next)); // keeps old UI interactive until new tab ready
}
const deferredQuery = useDeferredValue(query); // render expensive list with lagging value
```

**Activity (React 19.2+)**
```tsx
import { Activity } from "react";
<Activity mode={tab === "inbox" ? "visible" : "hidden"}><Inbox /></Activity>
<Activity mode={tab === "drafts" ? "visible" : "hidden"}><Drafts /></Activity>
```
Hidden children keep their state and DOM (with `display: none`), effects are cleaned up while hidden and re-run when shown, and updates are processed at low priority. You can also use it to pre-render likely-next screens.

## Recommended Workflow
1. Reproduce with React DevTools "Highlight updates when components render".
2. Use the Profiler's "Why did this render?" to identify triggers (state, parent, context, hooks).
3. Decide whether the re-render is actually expensive (flamegraph ms), not just frequent.
4. Fix structurally first: move state down, lift content up, split context. Then use the compiler or `memo`.
5. For state-identity bugs, inspect tree position, types and keys.
6. For hydration errors, diff server HTML against the client render (dates, random, `window`, invalid nesting, locale).

## Patterns
- **Key reset**: `key={id}` to reinitialize a subtree for a new entity.
- **Move state down**: isolate frequently changing state (input text, hover) in a small child.
- **Lift content up**: pass expensive subtrees as `children` into the stateful component.
- **Suspense boundaries as reveal units**: group content that should appear together. Since 19.2, SSR batches Suspense reveals for smoother streaming.
- **Hidden pre-render with Activity**: mount the likely-next tab hidden so switching is instant.

## Anti-Patterns
- **Index keys on dynamic lists**: state and inputs attach to the wrong rows. Fix: stable ids.
- **Random or regenerated keys**: remount every render, losing focus and state, and slow. Fix: stable ids.
- **Mutating state objects then calling `setState(sameRef)`**: bail-out, nothing updates. Fix: immutable copies (`toSorted`, spread, `structuredClone` sparingly).
- **Reading state right after `setState` expecting the new value**: snapshot semantics. Fix: compute `next` first and use it.
- **Side effects in render** (logging analytics, mutating refs, subscriptions): duplicated under Strict Mode and concurrent renders. Fix: effects or handlers.
- **`suppressHydrationWarning` to hide real mismatches**: masks bugs. Fix: render identical markup and defer client-only values. It's only acceptable for unavoidable single-element text like timestamps.
- **Conditional wrapper type switch** (`<div>` vs `<section>` around a stateful form): resets state. Fix: keep the element type stable.

## Accessibility
- Remounts from unstable keys or component types destroy focus. Keyboard and screen-reader users lose their place (WCAG 2.4.3 Focus Order).
- Hidden `Activity` content is `display: none`, so it's removed from the accessibility tree, which is correct. Don't use CSS `visibility` hacks that leave it focusable.
- During transitions, show `isPending` feedback (e.g. `aria-busy` on the region).

## Responsive Design
- Hydration mismatches often come from rendering different trees per viewport. Use CSS for layout differences.
- If a component must branch on viewport, render a neutral server snapshot, then update after hydration.

## Performance
- Re-render cost = the number of components rendered × work per render. Reduce both structurally.
- Transitions keep input responsive (better INP). React 19.3 renders independent transitions separately, so a slow one doesn't block others.
- `useDeferredValue` with memoized or compiled children avoids re-rendering expensive lists on each keystroke.
- Long lists: virtualize instead of relying on reconciliation speed.

## Security
- Hydration renders server-supplied data. Never embed unescaped user HTML. React escapes text by default; `dangerouslySetInnerHTML` bypasses that.
- Avoid rendering secrets into server HTML that is hidden only in the client UI.

## Testing
- Testing Library `render` runs the full render+commit. Use `act`-aware async utilities (`findBy*`, `waitFor`).
- Assert state preservation or reset through user-visible behaviour (input value after toggle).
- Check hydration with framework e2e tests (Playwright) watching the console for hydration errors.

## Tooling
- React DevTools Components + Profiler (highlight updates, "why did this render").
- React Performance Tracks in Chrome DevTools Performance panel (React 19.2+) show scheduler priorities and component work.
- `react-scan` (community) for visual re-render detection in development.

## Framework Notes
### React (Vite SPA)
- `createRoot(document.getElementById("root")!).render(<StrictMode><App /></StrictMode>)`. There is no server HTML and no hydration step, so the first paint is empty until JS loads. That's the main LCP cost of SPAs.
- All render, commit and effect rules above apply directly. Route changes are just state changes, and wrapping them in `startTransition` keeps the old screen visible.
- Legacy: `ReactDOM.render`/`hydrate`/`unmountComponentAtNode` were removed in React 19. Use `createRoot`/`hydrateRoot`.

### Next.js App Router
- **Server Components** render only on the server (per request, or at build time for static routes) and never re-render on the client on their own. `router.refresh()`, Server Actions with revalidation, or navigation fetch a new RSC payload, which React merges into the tree **while preserving client state** in unchanged positions.
- **Client Components (`"use client"`) are also rendered on the server** to produce HTML, and then **hydrated**. Their first client render must match the server output exactly, including text, attributes and element nesting.
- Common causes of hydration mismatch: `Date`/locale formatting, `Math.random()`/`crypto.randomUUID()` in render, `typeof window` branches, invalid HTML nesting (`<p><div>`), browser extensions changing the DOM. Use `useId`, server-provided timestamps, `useSyncExternalStore` server snapshots, or `use(browser())` (19.3).
- `layout.tsx` stays mounted across sibling navigations and keeps its state. `template.tsx` remounts. `loading.tsx` is an automatic Suspense boundary around `page.tsx`.
- Navigations run inside transitions. The old page stays visible (and interactive) until the new segment is ready, unless a `loading.tsx` or Suspense fallback is hit first.
- Dynamic route params changing (`/p/1` to `/p/2`) keeps the same component position, so client state persists. Add `key={id}` inside the page when a reset is needed.

## AI Agent Guidance
- When a user reports "re-renders too much", measure first. Propose structural fixes before `memo`.
- Never use index keys for mutable lists or random keys. Never remove `<StrictMode>` to "fix" double effects.
- When state resets unexpectedly, check for components defined inside render, changing keys, or a changing wrapper type.
- Verify: no hydration warnings in the console, Profiler confirms the intended render scope, and keyboard focus survives list updates.

## Examples
```tsx
// Hydration-safe client-only value (React 19.3)
import { Suspense, use } from "react";
import { browser } from "react-dom";
function LocalTime({ iso }: { iso: string }) {
  use(browser()); // suspends on server, renders on client
  return <time dateTime={iso}>{new Date(iso).toLocaleString()}</time>;
}
export function EventTime({ iso }: { iso: string }) {
  return <Suspense fallback={<time dateTime={iso}>{iso.slice(0, 10)}</time>}><LocalTime iso={iso} /></Suspense>;
}
```

## Related Skills
- [react-performance-optimization](../react-performance-optimization/Skill.md): applying the model to speed
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md): Suspense reveal semantics
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md): transitions in practice
- [hydration-strategies](../hydration-strategies/Skill.md): SSR hydration approaches
- [react-server-components](../react-server-components/Skill.md): server/client render split
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md): profiling renders

## Sources
- [react.dev: Render and Commit](https://react.dev/learn/render-and-commit) (Official): pipeline
- [react.dev: Preserving and Resetting State](https://react.dev/learn/preserving-and-resetting-state) (Official): position/type/key rules
- [react.dev: State as a Snapshot / Queueing updates](https://react.dev/learn/state-as-a-snapshot) (Official): batching, snapshots
- [React 19.2 post](https://react.dev/blog/2025/10/01/react-19-2) (Official): Activity, Performance Tracks, SSR Suspense batching
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): browser(), independent transitions, Strict Mode during hydration
- [Josh Comeau: Why React Re-Renders](https://www.joshwcomeau.com/react/why-react-re-renders/) (Community): re-render triggers explanation

## License / Usage Notes
React docs content is CC-BY-4.0. This is a summary with original examples.

## Quality Tier
S: official, current through React 19.3, with concrete diagnostic tables.

## Status
Active

## Last Verified
2026-09-15
