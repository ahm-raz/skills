# Frontend State Architecture

## Summary
A decision framework for where each kind of state lives in React and Next.js apps: server state (remote data cache), URL state, form state, local UI state, shared client state, and workflow/machine state — plus the Next.js-specific rule that Server Components and the server cache now own most data. Library-level details live in React-specific skills; this skill decides ownership and boundaries.

## Category
Architecture

## Subcategories
Server state vs client state, URL state, derived state, global stores, state machines, SSR/RSC state, hydration, persistence

## Problem It Solves
Apps that put everything in a global store suffer stale data, over-rendering, hydration mismatches, and cross-request data leaks on the server. Classifying state and assigning a single owner per category removes most state bugs and most boilerplate.

## When To Use
- Designing a new app's data flow.
- Refactoring Redux/Context-heavy code with duplicated fetch logic.
- Moving a React SPA to Next.js App Router.
- Debugging stale data, flicker, or hydration mismatches.

## When Not To Use
- Choosing between specific store APIs (see react-state-management) — this skill is about ownership, not syntax.

## Core Principles
1. **Classify before storing.** Server, URL, form, local UI, shared client, machine.
2. **Single source of truth per piece of state.** Never copy server data into a client store.
3. **Derive, don't sync.** Compute from existing state during render instead of `useEffect` syncing.
4. **Keep state as local as possible; lift only when needed.**
5. **URL is state** for anything shareable/bookmarkable (filters, sort, page, selected tab).
6. **On the server, no module-level mutable state.** Per-request data only.
7. **In Next.js App Router, fetch in Server Components by default;** client caches are for client-driven interactions.

## Best Practices
- Server state: TanStack Query v5 (SPA or client-interactive parts), or RSC fetch + Next.js caching (`'use cache'`, revalidation) with Server Actions for mutations.
- URL state: `useSearchParams` + router, or `nuqs` for typed search params; read `searchParams` prop in Next.js pages.
- Form state: React 19 `useActionState` + Server Actions for simple forms; React Hook Form + Zod for complex client validation.
- Local UI state: `useState`/`useReducer` colocated.
- Shared client state (theme, sidebar, cart draft, multi-step wizard progress): Zustand (small, selector-based), Jotai (atomic), or React Context for low-frequency values.
- Complex flows with forbidden transitions (checkout, uploads, onboarding): XState v5 or a typed reducer with discriminated unions.
- Model async states as discriminated unions, not multiple booleans.
- Persist only what must survive reload (drafts, preferences) with versioned keys; never persist tokens or PII in localStorage.
- Optimistic updates via TanStack Query `onMutate` or React 19 `useOptimistic`.

## Implementation Guidance

### State classification table
| Question | If yes -> owner |
|---|---|
| Does the server own the truth? | Server state (RSC fetch / TanStack Query) |
| Should a shared link reproduce it? | URL search params (nuqs) |
| Is it an in-progress user input for a submit? | Form state (useActionState / RHF) |
| Used by one component subtree only? | `useState`/`useReducer` |
| Many distant components, changes often? | Zustand/Jotai store with selectors |
| Many distant components, rarely changes? | Context |
| Has explicit states and illegal transitions? | XState v5 / reducer with unions |
| Computable from other state? | Derive during render (no storage) |

### Next.js App Router data ownership
```tsx
// app/orders/page.tsx — Server Component owns data; URL owns filters
import { getOrders } from '@/entities/order/api/queries'; // 'server-only'
import { OrdersTable } from '@/features/orders-table';
export default async function OrdersPage({ searchParams }: { searchParams: Promise<{ status?: string; page?: string }> }) {
  const { status = 'all', page = '1' } = await searchParams;
  const orders = await getOrders({ status, page: Number(page) });
  return <OrdersTable initialOrders={orders} status={status} />;
}
```

### Per-request store in Next.js (avoid cross-request leaks)
```tsx
'use client';
import { createContext, useContext, useState } from 'react';
import { createStore, useStore } from 'zustand';

type CartState = { items: string[]; add: (id: string) => void };
const makeCartStore = (initial: string[]) =>
  createStore<CartState>()((set) => ({ items: initial, add: (id) => set((s) => ({ items: [...s.items, id] })) }));

const CartCtx = createContext<ReturnType<typeof makeCartStore> | null>(null);
export function CartProvider({ initial, children }: { initial: string[]; children: React.ReactNode }) {
  const [store] = useState(() => makeCartStore(initial)); // one store per client tree, never module-level on the server
  return <CartCtx.Provider value={store}>{children}</CartCtx.Provider>;
}
export function useCart<T>(selector: (s: CartState) => T) {
  const store = useContext(CartCtx);
  if (!store) throw new Error('useCart must be used within CartProvider');
  return useStore(store, selector);
}
```

### Async state as a discriminated union
```ts
type Upload =
  | { status: 'idle' }
  | { status: 'uploading'; progress: number }
  | { status: 'success'; url: string }
  | { status: 'error'; error: string };
```

### TanStack Query in a Vite SPA
```tsx
const orderQuery = (id: string) => queryOptions({
  queryKey: ['orders', id],
  queryFn: () => api.getOrder(id),
  staleTime: 30_000,
});
function OrderDetail({ id }: { id: string }) {
  const { data, isPending, error } = useQuery(orderQuery(id));
  // ...
}
```

## Recommended Workflow
1. List every piece of state on a screen; classify with the table.
2. Move remote data to RSC fetch or a server-cache library; delete duplicated store slices.
3. Move shareable view state to the URL.
4. Replace effect-based syncing with derived values.
5. Introduce a small client store only for remaining cross-cutting client state.
6. Model complex flows as machines/unions.
7. Test hydration (no mismatches), back/forward behavior, and refresh persistence.

## Patterns
- **Server-first with client islands:** RSC fetches; client components receive initial data and handle interaction.
- **Query key factories:** `orderKeys.detail(id)` for consistent invalidation.
- **URL-as-state with typed parsers** (nuqs `parseAsInteger.withDefault(1)`).
- **Store per request/tree** via context + `createStore` in Next.js.
- **Selector subscriptions** to avoid re-render storms.
- **State machine for wizards** with guarded transitions.

## Anti-Patterns
- **Copying fetched data into Redux/Zustand** — stale duplicates. Fix: server-cache is the source; select from it.
- **`useEffect` to sync derived state** (`setFullName(first + last)`) — extra renders, bugs. Fix: compute during render.
- **Module-level store in Next.js server code** — data leaks between users. Fix: per-request provider.
- **Filters in component state** — lost on refresh/share. Fix: search params.
- **Boolean soup** (`isLoading && !isError && data`) — impossible states. Fix: discriminated union.
- **Giant Context value updated frequently** — whole tree re-renders. Fix: split contexts or selector store.
- **Reading `localStorage` during render** in SSR — hydration mismatch. Fix: read in effect / `useSyncExternalStore` with server snapshot.
- **Storing auth tokens in a client store persisted to localStorage** — XSS exfiltration. Fix: httpOnly cookies / BFF.

## Accessibility
- State changes that aren't visually obvious must be announced (WCAG 4.1.3 Status Messages): e.g., "3 results" after filter updates via a polite live region.
- URL state enables back/forward navigation that matches user expectations; preserve focus sensibly after state-driven content changes.

## Responsive Design
- Don't store viewport-derived state in global stores; use CSS/container queries. If JS needs it, `useSyncExternalStore` over `matchMedia` with a server snapshot.

## Performance
- Selector-based subscriptions (Zustand/Jotai) prevent broad re-renders; React Compiler reduces manual memoization.
- Server-first data reduces client JS and waterfalls; prefetch queries in RSC and hydrate (`HydrationBoundary`) when client interactivity needs cache.
- Set sensible `staleTime` to avoid refetch storms.

## Security
- Never place secrets or other users' data in serialized props/RSC payloads — everything passed to Client Components is visible in page source.
- Validate URL state (it's user input) with a schema before use.

## Testing
- Unit test reducers/machines and selectors as pure functions.
- Component tests with a fresh QueryClient/store per test.
- E2E: refresh and back/forward preserve URL state; no hydration warnings in console.

## Tooling
- TanStack Query v5 — Active.
- Zustand v5 — Active; Jotai v2 — Active.
- XState v5 + `@xstate/react` — Active.
- nuqs — Active (typed URL state, Next.js and React Router adapters).
- Redux Toolkit / RTK Query — Active; reasonable for existing Redux codebases, not a default for new apps.
- Recoil — Archived (do not adopt).

## Framework Notes
- **React (Vite SPA):** TanStack Query for all server state; router loaders (React Router / TanStack Router) can prefetch; client store for the rest.
- **Next.js App Router:** Server Components fetch; Server Actions mutate and call `revalidatePath`/`revalidateTag`/`updateTag`; client components use `useOptimistic`/`useActionState`. Use TanStack Query only where client-side polling, infinite scroll, or rich client caching is needed. Never create stores at module scope in files imported by the server.
- **Hydration:** pass server data as props or dehydrate queries; avoid reading browser-only APIs during render.

## AI Agent Guidance
- Classify each new piece of state with the table before writing code; state the classification in the PR.
- Do: fetch in Server Components (Next.js) or with query hooks (SPA); put filters in URL; derive values.
- Don't: add a global store for data that comes from an API; don't add `useEffect` + `setState` to mirror props; don't create module-level stores in Next.js.
- Verify: no hydration warnings, refresh keeps expected state, no duplicated sources of truth, tests reset stores between cases.

## Examples
```tsx
// nuqs URL state for filters (Next.js client component)
'use client';
import { useQueryState, parseAsStringLiteral } from 'nuqs';
const statuses = ['all', 'open', 'closed'] as const;
export function StatusFilter() {
  const [status, setStatus] = useQueryState('status', parseAsStringLiteral(statuses).withDefault('all').withOptions({ shallow: false }));
  return (
    <select aria-label="Status" value={status} onChange={(e) => setStatus(e.target.value as typeof statuses[number])}>
      {statuses.map((s) => <option key={s}>{s}</option>)}
    </select>
  );
}
```

## Related Skills
- [react-state-management](../react-state-management/Skill.md) — library-level usage
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — server cache details
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — URL state
- [nextjs-data-fetching-patterns](../nextjs-data-fetching-patterns/Skill.md) — RSC data ownership
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — mutations
- [optimistic-ui](../optimistic-ui/Skill.md) — optimistic patterns
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — data access layer

## Sources
- [TanStack Query docs](https://tanstack.com/query/latest) — Official — server state model
- [React docs: You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) — Official — derive vs sync
- [Zustand: Setup with Next.js](https://zustand.docs.pmnd.rs/guides/nextjs) — Official — per-request store
- [XState v5 docs](https://stately.ai/docs) — Official — state machines
- [nuqs](https://nuqs.dev) — Open Source — URL state
- [Next.js data fetching](https://nextjs.org/docs/app/getting-started/fetching-data) — Official — server-first

## License / Usage Notes
Summarized; examples original. Libraries MIT.

## Quality Tier
A — consensus architecture backed by official docs; library versions verified; Next.js caching APIs evolve quickly — recheck names.

## Status
Active

## Last Verified
2026-09-15
