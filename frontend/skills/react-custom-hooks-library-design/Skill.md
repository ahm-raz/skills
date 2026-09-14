# React Custom Hooks Library Design

## Summary
How to design, implement, type, test and package reusable custom hooks, for an app-internal `hooks/` folder or a published library. It covers API shape (tuple vs object, options objects), stability of returned functions, SSR and Next.js safety (`useSyncExternalStore`, `"use client"` directives in bundles), React Compiler compatibility, cleanup, and packaging (ESM, peer dependencies, preserved directives).

## Category
React

## Subcategories
custom hook API design, naming, return shapes, stable callbacks, SSR-safe hooks, useSyncExternalStore, "use client" in libraries, packaging, testing with renderHook, compiler compatibility

## Problem It Solves
Ad-hoc hooks leak listeners, return unstable callbacks that trigger effect loops, break during SSR (`window is not defined`), cause hydration mismatches, fail inside Next.js Server Components, and ship without types or tests.

## When To Use
- Extracting repeated stateful logic (subscriptions, media queries, local storage, debouncing, clipboard, intersection).
- Building a shared internal hooks package in a monorepo, or an open-source hooks library.
- Wrapping a third-party SDK in React-friendly APIs.

## When Not To Use
- Logic that doesn't use hooks: write a plain function (no `use` prefix).
- Wrapping a single `useState` with no added behaviour.
- Data fetching hooks that reimplement caching: wrap TanStack Query `queryOptions` instead.

## Core Principles
1. **A custom hook shares logic, not state.** Each call has independent state. Shared state needs context or an external store.
2. **Name with `use` + noun/verb** (`useMediaQuery`, `useCopyToClipboard`). Only prefix functions that call hooks.
3. **Follow the Rules of React** so the hook works with the React Compiler and Strict Mode.
4. **SSR-safe by default**: never touch `window`/`document` during render. Provide server snapshots.
5. **Stable outputs**: returned functions should keep identity across renders unless their behaviour changes.
6. **Small, composable, typed APIs** with sensible defaults and an options object for extensibility.

## Best Practices
- **Return shape**: tuple (`[value, setValue]`) for 1–2 values that consumers rename. Object (`{ data, error, isPending }`) for 3+ values or ones likely to grow.
- **Parameters**: required args positionally, optional config as an options object (`useDebounce(value, { delay: 300 })`).
- **External subscriptions**: implement with `useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)`, and keep `subscribe` stable (module scope or memoized by args).
- **Callbacks from consumers** (e.g. `onChange`): read the latest version with `useEffectEvent` (React ≥19.2) so effects don't re-subscribe. Support older React with a ref fallback only if needed.
- **Returned functions**: define via `useCallback` or rely on the compiler (if the library is compiled at build time). For published libraries, don't assume consumers use the compiler.
- **Snapshots must be cached**: `getSnapshot` must return the same value for unchanged data (no new objects each call), or React loops.
- **Cleanup**: every listener, timer and observer is removed in effect cleanup.
- **Document** SSR behaviour, return stability and React version requirements.

## Implementation Guidance
**Hook API checklist**

| Question | Guidance |
|---|---|
| Does it read browser state? | `useSyncExternalStore` + server snapshot (default value) |
| Does it accept callbacks? | `useEffectEvent` internally; don't require consumers to memoize |
| Does it return functions? | Stable identity (memoized) |
| Does it need shared state across components? | Context or external store, not the hook alone |
| Does it run on the server? | No effects there; ensure the render path is pure |
| Is it async? | Handle abort and stale results; consider TanStack Query instead |

**SSR-safe media query**
```ts
"use client";
import { useCallback, useSyncExternalStore } from "react";

export function useMediaQuery(query: string, { defaultValue = false }: { defaultValue?: boolean } = {}) {
  const subscribe = useCallback((onChange: () => void) => {
    const mql = window.matchMedia(query);
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
  }, [query]);
  return useSyncExternalStore(
    subscribe,
    () => window.matchMedia(query).matches,
    () => defaultValue, // server + hydration snapshot
  );
}
```

**localStorage with cross-tab sync and cached snapshot**
```ts
"use client";
import { useCallback, useSyncExternalStore } from "react";

const listeners = new Set<() => void>();
function emit() { listeners.forEach((l) => l()); }

export function useLocalStorage<T>(key: string, fallback: T) {
  const subscribe = useCallback((cb: () => void) => {
    listeners.add(cb);
    const onStorage = (e: StorageEvent) => { if (e.key === key) cb(); };
    window.addEventListener("storage", onStorage);
    return () => { listeners.delete(cb); window.removeEventListener("storage", onStorage); };
  }, [key]);

  // raw string snapshot is stable by value; parse outside
  const raw = useSyncExternalStore(subscribe, () => localStorage.getItem(key), () => null);
  const value: T = raw === null ? fallback : safeParse<T>(raw, fallback);

  const setValue = useCallback((next: T | ((prev: T) => T)) => {
    const current = (() => { const r = localStorage.getItem(key); return r === null ? fallback : safeParse<T>(r, fallback); })();
    const resolved = typeof next === "function" ? (next as (p: T) => T)(current) : next;
    localStorage.setItem(key, JSON.stringify(resolved));
    emit();
  }, [key, fallback]);

  return [value, setValue] as const;
}
function safeParse<T>(raw: string, fallback: T): T { try { return JSON.parse(raw) as T; } catch { return fallback; } }
```
(Parsing in render gives a new object per render. Consumers that need referential stability should select primitives, or the hook can memoize by `raw`.)

**Event listener hook with latest handler (React 19.2+)**
```ts
"use client";
import { useEffect, useEffectEvent } from "react";
export function useEventListener<K extends keyof WindowEventMap>(type: K, handler: (e: WindowEventMap[K]) => void, options?: AddEventListenerOptions) {
  const onEvent = useEffectEvent(handler);
  const passive = options?.passive; const capture = options?.capture;
  useEffect(() => {
    const listener = (e: WindowEventMap[K]) => onEvent(e);
    window.addEventListener(type, listener, { passive, capture });
    return () => window.removeEventListener(type, listener, { capture });
  }, [type, passive, capture]);
}
```

## Recommended Workflow
1. Identify duplicated logic in 2–3 real call sites before extracting it (avoid speculative hooks).
2. Write the consumer usage and types first.
3. Implement with SSR-safe primitives, cleanup and stable outputs.
4. Test with `renderHook`: initial value, updates, cleanup on unmount, SSR (`renderToString` with no window access).
5. Lint with `eslint-plugin-react-hooks` (compiler rules).
6. For libraries: build ESM + types, preserve `"use client"`, declare `react` as a peer dependency, document it, and add a changelog.

## Patterns
- **Headless component hook**: `useDisclosure()` → `{ isOpen, open, close, toggle, getTriggerProps, getContentProps }` (prop getters merge consumer props).
- **Store-backed hook**: `createStore` at module scope + `useStore(selector)` via `useSyncExternalStore`.
- **Query wrapper hook**: `useProject(id) => useQuery(projectQueries.detail(id))`, which keeps keys centralized.
- **Composable hooks**: `useDebouncedValue` built on `useEffect` + timers. `useSearch` composes debounce + query.
- **Options with defaults**: `const { delay = 300, leading = false } = options`.

## Anti-Patterns
- **Reading `window` in render or `useState` initializer** in SSR apps: crash or mismatch. Fix: `useSyncExternalStore` with a server snapshot, or effects.
- **`getSnapshot` returning a new object each call**: infinite loop. Fix: return primitives or cached values.
- **Requiring consumers to `useCallback` their handlers**: fragile. Fix: `useEffectEvent` internally.
- **Returning new function identities every render** from library hooks: consumer effects loop. Fix: memoize.
- **Hooks that call hooks conditionally** based on options: Rules of Hooks violation. Fix: always call, and branch inside.
- **Missing `"use client"` in a published hooks bundle**: Next.js Server Component imports fail with confusing errors. Fix: preserve the directive in the build output.
- **Bundling React into the library**: duplicate React ("Invalid hook call"). Fix: `peerDependencies` + externals.
- **`useIsMounted` / `useUpdateEffect` hacks**: they fight Strict Mode and concurrent rendering. Fix: proper cleanup and derived logic.

## Accessibility
- Headless hooks that manage widgets must return the ARIA wiring via prop getters (`aria-expanded`, `aria-controls`, `role`, ids from `useId`), so consumers can't forget it.
- Keyboard handling (Escape, arrows) should be part of the hook contract and documented.
- Motion-related hooks should expose `prefers-reduced-motion` (`usePrefersReducedMotion`).

## Responsive Design
- Provide `useMediaQuery`/`useContainerSize` (ResizeObserver) with SSR defaults. Document that CSS is preferred for pure layout changes.

## Performance
- `useSyncExternalStore` subscribers re-render only when their snapshot changes. Allow selectors for large stores.
- Share a single global listener across hook instances (e.g. one `resize` listener feeding a store) for hooks used in many rows.
- Use passive listeners for scroll and touch.

## Security
- Storage hooks: never store tokens. Namespace keys and validate parsed data (Zod) because storage is user-modifiable.
- Clipboard and permissions hooks must handle denied permissions gracefully and only run on user gestures.

## Testing
- `renderHook` from `@testing-library/react`. Use `act` for updates and `rerender` with new props.
- Test cleanup: spy on `removeEventListener` after `unmount()`.
- SSR test: `renderToString(<Probe />)` in a Node environment (no jsdom) to assert there's no `window` access and the default value renders.
- Strict Mode wrapper in tests to catch double-subscribe bugs.
- Type tests with `expectTypeOf` for generics (`useLocalStorage<number>`).

## Tooling
- `@testing-library/react` (`renderHook`), Vitest (node + jsdom/browser environments).
- `tsdown`/`tsup`/Rollup with directive preservation for `"use client"` banners. Vite library mode.
- `eslint-plugin-react-hooks` (compiler-powered rules).
- Reference libraries: `usehooks-ts` (TS-first), `@uidotdev/usehooks`, `ahooks`. `react-use` is widely used but less actively maintained, so check SSR behaviour before adopting it.
- Changesets for versioning in monorepos.

## Framework Notes
### React (Vite SPA)
- There's no SSR constraint, but still write SSR-safe hooks if they may be reused in Next.js later. Place shared hooks in `src/hooks` or a workspace package.

### Next.js App Router
- Hooks can only be called from Client Components. Put `"use client"` at the top of hook modules that are imported by client-boundary components, or ensure the consuming component module has it. For **published packages**, the built entry file must start with `"use client"` (bundlers strip directives unless configured).
- Server Components that need the same logic should call a plain async function (e.g. `getUserPreferences()`), not a hook.
- Hydration: the server snapshot passed to `useSyncExternalStore` must equal the first client render. Choose defaults (e.g. `false` for `useMediaQuery`) and accept a post-hydration update, or use `use(browser())` (React 19.3) in a Suspense boundary for client-only values.
- Navigation hooks: wrap `next/navigation` (`usePathname`, `useSearchParams`) in app hooks like `useActiveNav()`. Remember the Suspense requirement for `useSearchParams` in static routes.

## AI Agent Guidance
- Before creating a hook, search the codebase for existing equivalents (`hooks/`, packages) and for an established library already in dependencies.
- Generate SSR-safe implementations (`useSyncExternalStore` + server snapshot) in any Next.js project.
- Use `useEffectEvent` for consumer callbacks when React ≥19.2. Otherwise document that callbacks should be stable.
- Verify: lint clean, `renderHook` tests including unmount cleanup, no `window` access during server render, stable returned functions.

## Examples
```tsx
// Headless disclosure hook with prop getters
"use client";
import { useId, useState, useCallback } from "react";
export function useDisclosure(initial = false) {
  const [isOpen, setOpen] = useState(initial);
  const contentId = useId();
  const open = useCallback(() => setOpen(true), []);
  const close = useCallback(() => setOpen(false), []);
  const toggle = useCallback(() => setOpen((o) => !o), []);
  const getTriggerProps = (props: React.ComponentProps<"button"> = {}) => ({
    ...props, type: "button" as const, "aria-expanded": isOpen, "aria-controls": contentId,
    onClick: (e: React.MouseEvent<HTMLButtonElement>) => { props.onClick?.(e); if (!e.defaultPrevented) toggle(); },
  });
  const getContentProps = (props: React.ComponentProps<"div"> = {}) => ({ ...props, id: contentId, hidden: !isOpen });
  return { isOpen, open, close, toggle, getTriggerProps, getContentProps };
}
```

## Related Skills
- [react-hooks-patterns](../react-hooks-patterns/Skill.md): built-in hook rules
- [browser-apis-in-react](../browser-apis-in-react/Skill.md): wrapping browser APIs
- [react-typescript-patterns](../react-typescript-patterns/Skill.md): typing generics and returns
- [react-compiler](../react-compiler/Skill.md): compiler compatibility
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md): shared packages
- [component-api-design](../component-api-design/Skill.md): API design principles
- [vitest-unit-testing](../vitest-unit-testing/Skill.md): testing hooks

## Sources
- [react.dev: Reusing Logic with Custom Hooks](https://react.dev/learn/reusing-logic-with-custom-hooks) (Official): naming, sharing logic not state, when to extract
- [react.dev: useSyncExternalStore](https://react.dev/reference/react/useSyncExternalStore) (Official): subscribe/snapshot caching, server snapshot
- [react.dev: useEffectEvent](https://react.dev/reference/react/useEffectEvent) (Official): latest-callback pattern
- [Next.js docs: Server and Client Components (third-party packages & "use client")](https://nextjs.org/docs/app/getting-started/server-and-client-components) (Official): directive requirements for libraries
- [usehooks-ts](https://usehooks-ts.com/) (Open Source): reference implementations and SSR options
- [vercel-labs agent-skills react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) (Community/Open Source): client-event-listeners dedup, passive listeners, localStorage schema rules

## License / Usage Notes
React/Next.js docs are MIT/CC-BY-4.0. usehooks-ts and Vercel agent-skills are MIT. Code is original.

## Quality Tier
A: official primitives plus established library practice; packaging tool specifics change often.

## Status
Active

## Last Verified
2026-09-15
