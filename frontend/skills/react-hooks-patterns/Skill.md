# React Hooks Patterns

## Summary
How to use React's built-in hooks correctly as of React 19.3: `useState`, `useReducer`, `useEffect`, `useLayoutEffect`, `useEffectEvent`, `useSyncExternalStore`, `useId`, `use`, `useMemo`/`useCallback` and the Actions hooks. It covers the Rules of Hooks, the "You Might Not Need an Effect" decision process, dependency handling, cleanup, and when a hook is the wrong tool.

## Category
React

## Subcategories
Rules of Hooks, useEffect, useEffectEvent, derived state, useReducer, useSyncExternalStore, useId, use(), cleanup, race conditions

## Problem It Solves
Most React bugs in real codebases come from misusing Effects: state synced through effects, stale closures, missing cleanup, race conditions in fetches, effects that fire twice in Strict Mode, and dependency arrays tweaked to silence the linter.

## When To Use
- Writing or reviewing any function component or custom hook.
- Debugging infinite loops, stale values, flicker or double requests.
- Migrating class lifecycles (`componentDidMount` etc.) to hooks.

## When Not To Use
- Data fetching in apps with a framework or cache. Use loaders, RSC or TanStack Query instead of hand-written `useEffect` fetches.
- Global state: see the state management skill.
- Memoization in React Compiler projects: write plain code (see react-compiler).

## Core Principles
1. **Rules of Hooks**: call hooks only at the top level of components or custom hooks, never inside conditions, loops or after an early return. (`use()` is the exception: it may be called conditionally.)
2. **Effects are for synchronizing with external systems** (DOM APIs, network subscriptions, timers, third-party widgets). Everything else is render logic or event-handler logic.
3. **If you can compute it during render, don't store it in state.**
4. **Dependencies are not chosen, they are discovered.** Never lie to the linter. Change the code so the dependency isn't needed.
5. **Every subscription needs cleanup.** Strict Mode mounts, unmounts and remounts in development to expose missing cleanup.
6. **Components and hooks must be pure during render.** No mutation of props, state, refs or module variables while rendering.

## Best Practices
- Enable `eslint-plugin-react-hooks` (v6+ `recommended` flat config), which includes `rules-of-hooks`, `exhaustive-deps` and the compiler-powered purity/refs/set-state-in-render rules.
- Use functional updates (`setCount(c => c + 1)`) when the next state depends on the previous one. They also remove state from dependency arrays.
- Use lazy initial state for expensive setup: `useState(() => parse(localStorage.getItem(k)))`.
- Use `useReducer` once 3+ related state fields change together, or when the next state depends on complex rules.
- Use `useEffectEvent` (stable since React 19.2) for "latest value" reads inside effects (logging, analytics, callbacks from props) without re-running the effect.
- Use `useSyncExternalStore` for browser or external stores (online status, `matchMedia`, custom stores). Never `useEffect` + `setState`.
- Use `useId` for accessibility ids. Never `Math.random()` (causes hydration mismatch).
- Reset state with a `key`, not with an effect.
- `useLayoutEffect` only for measuring or mutating layout before paint (tooltips, scroll restore). It blocks paint.

## Implementation Guidance
**Effect decision table**

| Situation | Do this instead of `useEffect` |
|---|---|
| Value derived from props/state | Compute in render (`const full = first + " " + last`) |
| Expensive derivation | `useMemo`, or nothing with the React Compiler |
| Reset all state when an id changes | `<Profile key={userId} />` |
| Adjust part of the state when a prop changes | Store previous prop and set during render, or better, derive it |
| Response to a click/submit | Event handler |
| Notify the parent of a change | Call `onChange` in the same event handler |
| Subscribe to an external store | `useSyncExternalStore` |
| Fetch data | Framework loader / RSC / TanStack Query / `use(promise)` |
| Chain of state updates | Compute all next state in one handler or reducer |
| Sync with a DOM/3rd-party widget, socket, timer | **`useEffect` is correct here** |

**Effect anatomy**
```ts
useEffect(() => {
  const conn = createConnection(roomId);   // setup
  conn.connect();
  return () => conn.disconnect();          // cleanup mirrors setup
}, [roomId]);                              // every reactive value read inside
```

**Handling fetch races, when you must fetch in an effect**
```ts
useEffect(() => {
  const controller = new AbortController();
  fetch(`/api/search?q=${encodeURIComponent(query)}`, { signal: controller.signal })
    .then(r => r.json())
    .then(setResults)
    .catch(e => { if (e.name !== "AbortError") setError(e); });
  return () => controller.abort();
}, [query]);
```

**useEffectEvent (React 19.2+)**
```ts
import { useEffect, useEffectEvent } from "react";

function ChatRoom({ roomId, theme }: { roomId: string; theme: "light" | "dark" }) {
  const onConnected = useEffectEvent(() => {
    showToast(`Connected to ${roomId}`, theme); // reads latest theme
  });
  useEffect(() => {
    const c = createConnection(roomId);
    c.on("connected", () => onConnected());
    c.connect();
    return () => c.disconnect();
  }, [roomId]); // theme is NOT a dependency; don't list onConnected
}
```
Effect Events can only be called from inside effects. Don't pass them to children or call them during render.

## Recommended Workflow
1. Write the component with no effects. Derive everything possible during render.
2. Put user-caused logic in event handlers.
3. Add an effect only for external synchronization. Write the cleanup at the same time.
4. Fill dependencies from the linter. If one causes unwanted re-runs, restructure: move the object inside the effect, use a functional update, use `useEffectEvent`, or lift the value out of the component.
5. Run in Strict Mode and confirm the mount → unmount → mount cycle is harmless.
6. Test the behaviour, not the effect.

## Patterns
- **Previous-value adjustment in render** (rarely needed):
```ts
const [prevItems, setPrevItems] = useState(items);
if (items !== prevItems) { setPrevItems(items); setSelection(null); }
```
- **External store hook**
```ts
function subscribe(cb: () => void) {
  window.addEventListener("online", cb); window.addEventListener("offline", cb);
  return () => { window.removeEventListener("online", cb); window.removeEventListener("offline", cb); };
}
export const useOnline = () => useSyncExternalStore(subscribe, () => navigator.onLine, () => true);
```
- **Reducer with discriminated actions**
```ts
type State = { status: "idle" | "saving" | "error"; error?: string };
type Action = { type: "save" } | { type: "fail"; error: string } | { type: "done" };
function reducer(s: State, a: Action): State {
  switch (a.type) {
    case "save": return { status: "saving" };
    case "fail": return { status: "error", error: a.error };
    case "done": return { status: "idle" };
  }
}
```
- **`use()` for context and promises**: `const theme = use(ThemeContext)` works after early returns. `use(promise)` needs a cached or stable promise (created in a Server Component, loader or cache), never one created during render.

## Anti-Patterns
- **Derived state via effect** (`useEffect(() => setFull(a+b), [a,b])`): extra render and stale frame. Fix: compute inline.
- **Objects or functions created in render used as dependencies**: the effect re-runs every render. Fix: create them inside the effect, or depend on primitives.
- **`// eslint-disable-next-line react-hooks/exhaustive-deps`**: stale closures. Fix: `useEffectEvent` or restructure.
- **Empty dependency array as "componentDidMount"** while reading props: stale values. Fix: list the dependencies.
- **Async function passed directly to `useEffect`**: returns a promise, not a cleanup. Fix: define an inner async function and ignore/abort in cleanup.
- **Guarding against the Strict Mode double run with a ref flag**: hides missing cleanup. Fix: write idempotent setup and cleanup. For true app-init work, use a module-level guard outside components.
- **`useEffect` to call `onChange` of the parent**: double render and ordering bugs. Fix: call it in the handler.
- **`useCallback`/`useMemo` everywhere "for performance"**: noise. Fix: profile first, or use the React Compiler.

## Accessibility
- Focus management belongs in effects or ref callbacks tied to the triggering event (e.g. focus the first invalid field after submit) and must not steal focus on every render.
- Use `useId` for `aria-describedby`/`htmlFor` pairs (WCAG 1.3.1, 4.1.2).
- Announcements via live regions should come from state changes in handlers, not effects that fire on mount.

## Responsive Design
- Read viewport and media queries with `useSyncExternalStore(matchMedia...)` and a server snapshot to avoid hydration mismatch. Prefer CSS media and container queries whenever JS isn't strictly needed.
- Use `ResizeObserver` inside `useLayoutEffect` with cleanup for element-size-driven logic.

## Performance
- Each `setState` in an effect causes another render pass. Removing needless effects is often the biggest render win.
- `useTransition`/`useDeferredValue` keep typing responsive during expensive re-renders.
- Keep effect dependencies primitive to avoid re-subscription churn.

## Security
- Clean up `postMessage` listeners and validate `event.origin`.
- Don't persist secrets or tokens in `useState` initializers read from `localStorage`. See frontend-auth-token-handling.

## Testing
- Use React Testing Library and `userEvent`. Assert what users see after interactions, and `await findBy...` for async results.
- Test custom hooks with `renderHook` from `@testing-library/react`.
- Run tests in Strict Mode (RTL supports `reactStrictMode` config) to catch missing cleanup.
- Mock the network with MSW, not by stubbing `useEffect`.

## Tooling
- `eslint-plugin-react-hooks` v6+ (flat config `recommended`), which includes the React Compiler diagnostics.
- React DevTools (Components → hooks inspection, "highlight updates").
- `@testing-library/react` `renderHook`.

## Framework Notes
### React (Vite SPA)
- Everything runs on the client, and there is no SSR hydration to worry about. Server data belongs in TanStack Query, not hand-written effects.
- The React Compiler (Babel preset in the Vite config) removes most manual `useMemo`/`useCallback`. It doesn't remove the need for correct effect dependencies.

### Next.js App Router
- State, effect and ref hooks (`useState`, `useReducer`, `useEffect`, `useLayoutEffect`, `useEffectEvent`, `useRef`, `useSyncExternalStore`, `useActionState`, `useOptimistic`) only work in Client Components (`"use client"` modules). Server Components use `async`/`await` (and `cache`) instead.
- "Client Components" still render once on the server to produce HTML. Effects don't run there, so the first render must not read `window`, `localStorage`, `Date.now()` or random values. Use `useSyncExternalStore` with a `getServerSnapshot`, or `use(browser())` (React 19.3) inside a Suspense boundary, to avoid hydration mismatches.
- Don't fetch initial page data in `useEffect`. Fetch it in the Server Component and pass props, or pass an un-awaited promise and unwrap it with `use()`.
- `useRouter`, `usePathname` and `useSearchParams` come from `next/navigation` (not `next/router`) and are client-only. A statically rendered route that calls `useSearchParams` needs a `<Suspense>` boundary around that component.
- Legacy: class lifecycles, `UNSAFE_*` methods and mixins are outdated. Migrate to hooks.

## AI Agent Guidance
- Before writing `useEffect`, ask "what external system am I synchronizing with?" If there is none, don't write it.
- Never suppress `exhaustive-deps`. Use `useEffectEvent` (React ≥ 19.2) or restructure.
- Check the React version in `package.json` before using `useEffectEvent`, `use`, `useActionState` (19+), `Activity` (19.2+) or `ViewTransition`/Fragment refs (19.3+).
- Verify: lint is clean, no "Maximum update depth" or hydration warnings, Strict Mode double-mount is harmless, and fetch effects abort or ignore stale responses.

## Examples
```tsx
// Before: 3 effects, 4 renders per keystroke
function Filtered({ items }: { items: Item[] }) {
  const [query, setQuery] = useState("");
  const [filtered, setFiltered] = useState<Item[]>([]);
  useEffect(() => setFiltered(items.filter(i => i.name.includes(query))), [items, query]);
  return <List items={filtered} />;
}
// After: zero effects
function Filtered({ items }: { items: Item[] }) {
  const [query, setQuery] = useState("");
  const deferred = useDeferredValue(query);
  const filtered = items.filter(i => i.name.includes(deferred));
  return <><input value={query} onChange={e => setQuery(e.target.value)} /><List items={filtered} /></>;
}
```

## Related Skills
- [react-custom-hooks-library-design](../react-custom-hooks-library-design/Skill.md): packaging hooks for reuse
- [react-rendering-model](../react-rendering-model/Skill.md): why effects cause extra renders
- [react-compiler](../react-compiler/Skill.md): memoization hooks in compiled code
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md): replaces fetch-in-effect
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md): refs vs state
- [testing-library-principles](../testing-library-principles/Skill.md): testing hooks through behaviour

## Sources
- [react.dev: You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) (Official): effect decision cases
- [react.dev: Synchronizing with Effects / Lifecycle of Reactive Effects](https://react.dev/learn/synchronizing-with-effects) (Official): cleanup, Strict Mode
- [react.dev: useEffectEvent reference](https://react.dev/reference/react/useEffectEvent) (Official): 19.2 API
- [React 19.2 release post](https://react.dev/blog/2025/10/01/react-19-2) (Official): useEffectEvent, Activity, eslint plugin v6
- [vercel-labs/agent-skills react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) (Open Source/Community): rerender-* rules (functional setState, lazy init, derived state)
- [Dan Abramov: A Complete Guide to useEffect](https://overreacted.io/a-complete-guide-to-useeffect/) (Community): dependency mental model

## License / Usage Notes
React docs are CC-BY-4.0 (content) and MIT (code). Vercel agent-skills is MIT. This is a summary with original examples.

## Quality Tier
S: directly aligned with official React 19.2/19.3 docs and lint rules, with decision tables and anti-pattern fixes.

## Status
Active

## Last Verified
2026-09-15
