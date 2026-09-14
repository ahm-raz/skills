# React State Management

## Summary
How to choose where state lives in a React app, and which tool to use: local state, URL state, server-cache state (TanStack Query / framework loaders), form state, and shared client state (Context, Zustand v5, Jotai v2, Redux Toolkit 2.x). The key idea is that most "global state" is really server state or URL state, and the client store left over should be small.

## Category
React

## Subcategories
local state, lifting state, URL/search-param state, server state vs client state, Zustand, Jotai, Redux Toolkit, RTK Query, form state, persistence

## Problem It Solves
Teams default to one global store for everything. The result is duplicated server data going stale, re-render storms, lots of boilerplate, and state that can't be bookmarked or shared through the URL.

## When To Use
- Starting a new app or feature and deciding where state lives.
- A component tree suffers prop drilling or excessive re-renders.
- Evaluating Redux vs Zustand vs Jotai, or migrating off legacy Redux.

## When Not To Use
- Server data caching details: see react-data-fetching-tanstack-query.
- Form field state: use form libraries (see react-hook-form-and-zod) or React 19 form Actions.
- Cross-framework architecture: see frontend-state-architecture.

## Core Principles
1. **Classify the state first**: server, URL, form, local UI, or shared client. Each has a best home.
2. **Colocate**: keep state in the lowest common owner. Lift it only when siblings need it.
3. **Derive, don't duplicate**: store the minimal source of truth and compute everything else in render.
4. **The server owns server data.** Cache it (TanStack Query, loaders, RSC). Don't copy it into a client store.
5. **The URL is state**: filters, tabs, pagination, search and selected ids belong in search params if users would share or bookmark them.
6. **Subscribe narrowly**: components should read slices through selectors, so unrelated updates don't re-render them.
7. **Immutable updates** everywhere. React compares by reference.

## Best Practices
- Model mutually exclusive status with unions (`status: "idle" | "loading" | "error"`), not multiple booleans.
- Don't mirror props into state. If you need a "draft", name it `initialX` and reset with `key`.
- Zustand v5: select atomic values (`useStore(s => s.count)`). When selecting multiple fields as an object or array, wrap with `useShallow`, because v5 throws "Maximum update depth exceeded" for selectors that return new references.
- Zustand/Redux in SSR frameworks: create the store per request (store factory + provider). Never a module-level singleton holding user data on the server.
- Redux Toolkit 2.x: use `createSlice`, `configureStore` and typed hooks (`useAppSelector = useSelector.withTypes<RootState>()`). Use RTK Query if you're already on Redux and need a cache. Hand-written reducers, `connect()`, and `redux-thunk` for fetching are legacy style.
- Jotai: good for many independent, fine-grained pieces (editors, canvases, spreadsheets). Use derived atoms instead of effects.
- Persist deliberately (`zustand/middleware` `persist`, `atomWithStorage`) with a version and a migration, and never persist secrets.

## Implementation Guidance
**Where should this state live?**

| State kind | Examples | Home |
|---|---|---|
| Server/remote | users, orders, permissions | RSC / route loaders / TanStack Query / RTK Query |
| URL | filters, sort, page, tab, search query | Search params (`nuqs` on the client, the `searchParams` page prop in Next.js Server Components) |
| Form | inputs, validation, dirty flags | Uncontrolled inputs + form Actions, or React Hook Form |
| Local UI | open/closed, hover, input text | `useState`/`useReducer` in the component |
| Shared UI across distant parts | theme, sidebar collapsed, toasts, cart (client-only) | Context (low-frequency) or Zustand/Jotai (high-frequency) |
| Complex domain workflows with audit/devtools/time-travel needs | large enterprise apps | Redux Toolkit |

**Library chooser**

| Criterion | Context | Zustand v5 | Jotai v2 | Redux Toolkit 2 |
|---|---|---|---|---|
| Size | 0 | ~1-3 KB | ~3-4 KB | ~12-15 KB with react-redux |
| Model | Provider value | Single store + selectors | Atoms graph | Slices + actions + middleware |
| Re-render control | Whole consumer | Selector + equality | Per atom | Selector |
| Boilerplate | Low | Very low | Low | Medium |
| Devtools | React DevTools | Redux DevTools via middleware | jotai-devtools | Best-in-class |
| Best for | Dependency injection, rarely-changing values | Most apps' shared client state | Fine-grained, derived-heavy state | Large teams, strict conventions, event logs |

## Recommended Workflow
1. Inventory the state for the feature and tag each piece by kind (table above).
2. Move remote data to the query or loader layer and URL-worthy state to search params.
3. Keep the rest local. Lift only as far as needed.
4. If prop drilling remains after trying composition, add Context (static values) or a store (frequently changing values).
5. Add selectors, and verify re-renders with React DevTools Profiler.
6. Test store logic as pure functions (reducers or actions) and components through the UI.

## Patterns
**Zustand v5 store with slices, typed, SSR-safe via context**
```ts
import { createStore, useStore } from "zustand";
import { useShallow } from "zustand/shallow";
import { createContext, use, useState } from "react";

type CartState = {
  items: Record<string, number>;
  add: (id: string) => void;
  clear: () => void;
};
const createCartStore = (init: Partial<CartState> = {}) =>
  createStore<CartState>()((set) => ({
    items: {},
    add: (id) => set((s) => ({ items: { ...s.items, [id]: (s.items[id] ?? 0) + 1 } })),
    clear: () => set({ items: {} }),
    ...init,
  }));

const CartCtx = createContext<ReturnType<typeof createCartStore> | null>(null);
export function CartProvider({ children }: { children: React.ReactNode }) {
  const [store] = useState(() => createCartStore());
  return <CartCtx value={store}>{children}</CartCtx>;
}
export function useCart<T>(selector: (s: CartState) => T) {
  const store = use(CartCtx);
  if (!store) throw new Error("useCart outside CartProvider");
  return useStore(store, selector);
}
// usage
const count = useCart((s) => Object.values(s.items).reduce((a, b) => a + b, 0));
const { add, clear } = useCart(useShallow((s) => ({ add: s.add, clear: s.clear })));
```
For client-only SPAs, a module-level `create()` hook is fine.

**Jotai derived atoms**
```ts
import { atom, useAtomValue, useSetAtom } from "jotai";
const todosAtom = atom<Todo[]>([]);
const filterAtom = atom<"all" | "done">("all");
const visibleTodosAtom = atom((get) =>
  get(filterAtom) === "done" ? get(todosAtom).filter((t) => t.done) : get(todosAtom));
```

**Redux Toolkit typed setup**
```ts
const store = configureStore({ reducer: { cart: cartSlice.reducer } });
export type RootState = ReturnType<typeof store.getState>;
export const useAppSelector = useSelector.withTypes<RootState>();
export const useAppDispatch = useDispatch.withTypes<typeof store.dispatch>();
```

**URL as state**: store `?status=open&page=2`, parse it with a schema (Zod/Valibot), and treat it as the single source of truth.

## Anti-Patterns
- **Copying query data into Zustand/Redux**: stale data and double sources of truth. Fix: read from the query cache, and keep only client-only UI state in the store.
- **One giant Context holding everything**: every consumer re-renders on any change. Fix: split contexts, or use a selector-based store.
- **Selecting the whole store** (`useStore()` / `useStore(s => s)`): re-renders on every change. Fix: atomic selectors or `useShallow`.
- **Object selector without `useShallow` in Zustand v5**: infinite loop. Fix: `useShallow`, or select separately.
- **Boolean flags for status** (`isLoading && isError` both true): impossible states. Fix: a discriminated union.
- **Module singleton store with user data in SSR**: cross-request data leak. Fix: a per-request store via provider.
- **Legacy Redux** (switch reducers, action-type constants, `connect`): verbose. Fix: RTK `createSlice` and hooks.
- **Tabs, filters and pagination in `useState`**: lost on refresh and not shareable. Fix: search params.

## Accessibility
- State that controls visibility must also drive ARIA (`aria-expanded`, `aria-selected`, `aria-busy`).
- URL-driven view changes should manage focus and announce updates (see accessible-spa-routing).
- Restoring persisted UI state must not unexpectedly move focus or open dialogs on load.

## Responsive Design
- Don't store breakpoints in global state. Use CSS, or a `useSyncExternalStore` matchMedia hook where JS is required.
- Persisted layout preferences (collapsed sidebar) should have a sensible default per viewport.

## Performance
- Narrow selectors and split stores cut re-renders more than `memo` does.
- Jotai and Zustand update subscribers without re-rendering providers. Context re-renders every consumer.
- Use `startTransition` for store updates that trigger expensive re-renders (filters over big lists).
- Avoid serializing huge stores to `localStorage` on every change. Throttle, or persist a partial slice.

## Security
- Never keep tokens or PII in persisted client stores (`localStorage` is readable by XSS). Prefer httpOnly cookies.
- Validate URL state with a schema before use, since it's user-controlled input.
- Per-request stores in SSR prevent leaking one user's data into another's HTML.

## Testing
- Unit test reducers, slices and store actions as pure functions (Vitest).
- For Zustand, reset stores between tests (create via factory, or use the documented `__mocks__` reset pattern).
- Test components with a real provider and store. Avoid mocking selectors.
- Test URL state by rendering with a memory router at a given URL.

## Tooling
- `zustand` v5 (active; `useShallow` from `zustand/shallow`).
- `jotai` v2 (active).
- `@reduxjs/toolkit` 2.x + `react-redux` 9.x (active; RTK Query built in).
- `nuqs` (type-safe search params with adapters for Next.js App Router and React SPAs).
- `@tanstack/react-query` v5 for server state.
- Legacy/avoid for new code: MobX-State-Tree for new React apps (still maintained, but niche), Recoil (archived by Meta in 2025), and plain Redux without RTK.

## Framework Notes
### React (Vite SPA)
- A module-level Zustand `create()` hook or a Jotai default store is safe, because there is only one user per JS runtime.
- Server state goes in TanStack Query. URL state goes in `nuqs` (React SPA adapter) or your router's search params.
- Persisted stores rehydrate synchronously from `localStorage`, so there is no hydration mismatch to handle.

### Next.js App Router
- Server Components can't read client stores or context. Pass server data down as props, or prefetch into a TanStack Query cache and wrap in `HydrationBoundary`.
- Create Zustand/Redux/Jotai stores **per request** inside a `"use client"` provider (`useState(() => createStore())`) and mount it in `app/layout.tsx`. A module-level store on the server leaks data between users.
- Filters, tabs and pagination: read `searchParams` (a Promise in Next.js 15+) in the page Server Component, and update from the client with `nuqs` (`NuqsAdapter` from `nuqs/adapters/next/app`). Use `shallow: false` when the server needs to re-render.
- Persisted client stores (`persist`, `atomWithStorage`) cause hydration mismatches when the first client render differs from the server HTML. Render a neutral default first, or use `skipHydration` and rehydrate in an effect.
- After a Server Action mutation, call `revalidatePath`/`revalidateTag` (or `router.refresh()`) instead of manually syncing a client store.

## AI Agent Guidance
- Before adding a store dependency, check whether the state is really server or URL state.
- Match the project's existing library. Don't add a second global store.
- In Zustand v5 code, verify every multi-value selector uses `useShallow`.
- In SSR projects, verify no module-level store holds per-user data.
- Done when: no duplicated server data in client stores, the Profiler shows only intended components re-rendering, and URL state survives refresh.

## Examples
```tsx
// URL-driven filters in Next.js App Router with nuqs
// app/layout.tsx: wrap children in <NuqsAdapter> from "nuqs/adapters/next/app"
"use client";
import { parseAsInteger, parseAsStringLiteral, useQueryStates } from "nuqs";

const STATUSES = ["all", "open", "closed"] as const;

export function StatusFilter() {
  const [{ status }, setFilters] = useQueryStates(
    { status: parseAsStringLiteral(STATUSES).withDefault("all"), page: parseAsInteger.withDefault(1) },
    { shallow: false } // re-run the Server Component page with new searchParams
  );
  return (
    <select aria-label="Status" value={status}
      onChange={(e) => setFilters({ status: e.target.value as (typeof STATUSES)[number], page: null })}>
      <option value="all">All</option><option value="open">Open</option><option value="closed">Closed</option>
    </select>
  );
}
```

## Related Skills
- [frontend-state-architecture](../frontend-state-architecture/Skill.md): framework-agnostic state architecture
- [react-context-patterns](../react-context-patterns/Skill.md): when Context is enough
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md): server state
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): URL state in Next.js and React SPAs
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md): form state
- [react-performance-optimization](../react-performance-optimization/Skill.md): selector-driven re-render control

## Sources
- [react.dev: Managing State / Choosing the State Structure](https://react.dev/learn/choosing-the-state-structure) (Official): minimal state, avoiding duplication
- [Zustand docs: Migrating to v5 / useShallow](https://zustand.docs.pmnd.rs/reference/migrations/migrating-to-v5) (Official): selector stability, useShallow
- [Zustand docs: Next.js setup](https://zustand.docs.pmnd.rs/guides/nextjs) (Official): per-request stores
- [Redux Toolkit docs](https://redux-toolkit.js.org/) (Official): createSlice, withTypes hooks, RTK Query
- [Jotai docs](https://jotai.org/docs) (Official): atoms, derived atoms
- [TkDodo: Practical React Query](https://tkdodo.eu/blog/practical-react-query) (Community): server vs client state separation
- [State of React 2025 survey coverage](https://dev.to/jsgurujobs/state-management-in-2026-zustand-vs-jotai-vs-redux-toolkit-vs-signals-2gge) (Community): adoption trends

## License / Usage Notes
Zustand, Jotai and Redux Toolkit are MIT. The content is summarized, with original code.

## Quality Tier
A: official docs for all libraries plus strong community consensus; bundle sizes are approximate and vary by version.

## Status
Active

## Last Verified
2026-09-15
