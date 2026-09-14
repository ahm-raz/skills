# React Data Fetching with TanStack Query

## Summary
TanStack Query v5 (`@tanstack/react-query` 5.10x as of Sept 2026) is the standard async server-state cache for React. It handles fetching, caching, deduplication, background refetching, pagination, mutations, optimistic updates and SSR hydration. This skill covers the `queryOptions` API, query key design, status handling, mutations and invalidation, Suspense mode, and the Next.js App Router prefetch-and-hydrate pattern.

## Category
React

## Subcategories
queryOptions, query keys, staleTime/gcTime, mutations, invalidation, optimistic updates, infinite queries, useSuspenseQuery, SSR hydration, Next.js App Router, prefetching

## Problem It Solves
Hand-rolled `useEffect` fetching has race conditions, no caching, duplicate requests, stale data, no retries, and ad-hoc loading and error states. Copying server data into Redux or Zustand adds a second source of truth. TanStack Query makes the server the owner and the client a synchronized cache.

## When To Use
- Vite React SPAs: the default way to load and mutate API data.
- Next.js App Router: client-side interactive data (infinite lists, polling, optimistic mutations, dashboards filtered on the client) layered on top of server prefetching.
- Any app calling REST, GraphQL or tRPC from the client.

## When Not To Use
- Next.js pages whose data is only rendered on the server and never refetched on the client. Plain async Server Components are simpler.
- Pure client-only state (UI toggles). Use `useState`/Zustand.
- Real-time collaborative state that needs CRDTs. Use a sync engine, optionally fed into the cache.

## Core Principles
1. **Query keys are dependencies.** Include every variable the `queryFn` uses (`["todos", { status, page }]`).
2. **Define queries once with `queryOptions`** and reuse them for `useQuery`, `useSuspenseQuery`, `prefetchQuery`, `getQueryData` and `invalidateQueries`, for type-safe keys.
3. **Set `staleTime` deliberately.** The default of 0 means "stale immediately, refetch on mount, focus or reconnect". SSR apps need `staleTime > 0` to avoid refetching right after hydration.
4. **Don't copy query data into local state.** Derive from it (`select`) and let background updates flow.
5. **Mutations invalidate or update the cache.** Never manually refetch everything.
6. **Handle all states**: pending, error, success, empty, and background-fetching.

## Best Practices
- One `QueryClient` per app in SPAs (module scope). In Next.js, one per request on the server and a singleton in the browser.
- Use a query key factory per feature (`todoKeys.list(filters)`), or `queryOptions` factories, which also carry the key.
- `throwOnError` / Suspense mode route errors to error boundaries. Otherwise render `isError` states explicitly.
- `placeholderData: keepPreviousData` for pagination to avoid flashing skeletons.
- `select` to transform or subscribe to a slice. Components then re-render only when the selected value changes.
- `enabled` for dependent queries. With Suspense, use `skipToken` patterns or split components instead.
- Pass `signal` from `queryFn` context to `fetch` for automatic cancellation.
- Retries: keep the default (3) for GETs. Mutations don't retry by default. Don't retry 4xx.
- Mount `ReactQueryDevtools` in development only.

## Implementation Guidance
**Defaults to consider**

| Option | Default | Typical override |
|---|---|---|
| `staleTime` | 0 | 30s–5min for most data; `60_000` in SSR; `Infinity` for static reference data |
| `gcTime` | 5 min | Longer for back-navigation-heavy apps |
| `refetchOnWindowFocus` | true | Keep for dashboards; disable for forms/editors |
| `retry` | 3 (queries) | `(count, err) => err.status >= 500 && count < 3` |

**queryOptions factory**
```ts
import { queryOptions, infiniteQueryOptions } from "@tanstack/react-query";

export const todoQueries = {
  all: () => ["todos"] as const,
  list: (filters: { status: "open" | "done"; page: number }) =>
    queryOptions({
      queryKey: [...todoQueries.all(), "list", filters],
      queryFn: ({ signal }) => api.get<Todo[]>("/todos", { params: filters, signal }),
      staleTime: 30_000,
    }),
  detail: (id: string) =>
    queryOptions({
      queryKey: [...todoQueries.all(), "detail", id],
      queryFn: ({ signal }) => api.get<Todo>(`/todos/${id}`, { signal }),
    }),
};
// usage
const { data, isPending, isError } = useQuery(todoQueries.list({ status: "open", page: 1 }));
queryClient.setQueryData(todoQueries.detail(id).queryKey, updated); // typed
```

**Mutation with invalidation**
```ts
const qc = useQueryClient();
const createTodo = useMutation({
  mutationFn: (input: NewTodo) => api.post<Todo>("/todos", input),
  onSuccess: () => qc.invalidateQueries({ queryKey: todoQueries.all() }),
});
```

**Optimistic update via cache (rollback on error)**
```ts
useMutation({
  mutationFn: toggleTodo,
  onMutate: async (id: string) => {
    const key = todoQueries.detail(id).queryKey;
    await qc.cancelQueries({ queryKey: key });
    const prev = qc.getQueryData(key);
    qc.setQueryData(key, (t) => (t ? { ...t, done: !t.done } : t));
    return { prev, key };
  },
  onError: (_e, _id, ctx) => ctx && qc.setQueryData(ctx.key, ctx.prev),
  onSettled: () => qc.invalidateQueries({ queryKey: todoQueries.all() }),
});
```
A simpler v5 alternative: render `mutation.variables` while `isPending` (optimistic UI via the variables) without touching the cache.

**Status rendering order** (TkDodo): check `data` first when stale data is acceptable, and show a background error toast instead of replacing good data with an error screen.

## Recommended Workflow
1. Create an API client (typed fetch wrapper that throws on non-2xx).
2. Create `queryOptions` factories per feature.
3. Build hooks or components with `useQuery`/`useSuspenseQuery`. Choose Suspense boundaries.
4. Add mutations with invalidation. Add optimistic updates for high-frequency actions.
5. Configure defaults (`staleTime`, retry) in the `QueryClient`.
6. Add SSR prefetch and hydration in Next.js for above-the-fold data.
7. Test with MSW and a fresh `QueryClient` per test (`retry: false`).

## Patterns
- **Prefetch on intent**: `onMouseEnter={() => qc.prefetchQuery(todoQueries.detail(id))}`.
- **Seed detail from list**: `initialData: () => qc.getQueryData(listKey)?.find(t => t.id === id)` with `initialDataUpdatedAt`.
- **Infinite scroll**: `useInfiniteQuery` / `infiniteQueryOptions` with `initialPageParam`, `getNextPageParam`, and `maxPages` to cap memory.
- **Suspense-first**: `useSuspenseQuery` (data is always defined) + `<Suspense>` + error boundary with `QueryErrorResetBoundary`.
- **Parallel dynamic**: `useQueries({ queries: ids.map(id => todoQueries.detail(id)), combine })`.
- **Global error toasts**: `QueryCache({ onError })` for background refetch failures.

## Anti-Patterns
- **Missing variables in `queryKey`**: shows the wrong cached data. Fix: include all inputs (eslint `@tanstack/eslint-plugin-query` `exhaustive-deps`).
- **`useEffect(() => setLocal(data))`**: stale copies. Fix: use `data` directly or `select`.
- **`new QueryClient()` inside a component body**: cache wiped on every render. Fix: module scope (SPA) or `useState(() => new QueryClient())`, or the `getQueryClient` helper.
- **`refetch()` after mutations**: misses other screens. Fix: `invalidateQueries`.
- **`staleTime: 0` with SSR hydration**: immediate client refetch and flicker. Fix: `staleTime ≥ 60s`.
- **Using `isLoading` from v4 semantics**: in v5, `isPending` = no data yet, and `isLoading` = `isPending && isFetching`. Fix: use `isPending` for first load.
- **Sharing one server `QueryClient` across requests in Next.js**: data leak between users. Fix: per-request client.
- **v4 legacy options** (`cacheTime`, `onSuccess` on `useQuery`, `keepPreviousData: true`): removed in v5. Fix: `gcTime`, effects or `select`, `placeholderData: keepPreviousData`.

## Accessibility
- Loading states: skeletons with `aria-busy="true"` on the region. Avoid focus jumps when data arrives.
- Background refetch errors: announce through a polite live-region toast, not by replacing content.
- Pagination with `keepPreviousData`: keep focus on the pagination control and announce "Page 3 loaded".

## Responsive Design
- Infinite scroll on mobile, pagination on desktop, both driven by the same query options.
- Tune `refetchOnWindowFocus`/`refetchOnReconnect` for mobile networks. Consider `networkMode: "offlineFirst"` for flaky connections.

## Performance
- `select` + tracked properties (v5 only re-renders for properties you access) minimize re-renders.
- Prefetch in Server Components or on hover to eliminate waterfalls.
- `maxPages` on infinite queries bounds memory. Tune `gcTime` for memory-constrained devices.
- Don't over-invalidate broad keys on every mutation in huge caches. Scope keys.

## Security
- Query cache content is visible in DevTools and memory. Never cache secrets. Clear the cache on logout (`queryClient.clear()`).
- In Next.js, dehydrated state is serialized into HTML. Only prefetch data the user may see.
- Validate API responses (Zod) at the boundary for untrusted third-party APIs.

## Testing
- Wrap renders in a fresh `QueryClientProvider` per test with `defaultOptions: { queries: { retry: false } }`.
- Mock the network with MSW rather than mocking `useQuery`.
- Assert UI states: loading, error (return a 500 from MSW), empty, success, and optimistic rollback.
- `renderHook` for custom query hooks. `await waitFor(() => expect(result.current.isSuccess).toBe(true))`.

## Tooling
- `@tanstack/react-query` v5 (active; v5 is still the React major as of Sept 2026).
- `@tanstack/react-query-devtools`.
- `@tanstack/eslint-plugin-query` (exhaustive-deps, stable-query-client, no-rest-destructuring).
- `@tanstack/react-query-next-experimental` (streaming without explicit prefetch; experimental).
- Alternatives: SWR (simpler, fewer features), RTK Query (Redux apps), tRPC's React Query integration (`@trpc/tanstack-react-query`).

## Framework Notes
### React (Vite SPA)
- `const queryClient = new QueryClient({...})` at module scope. Wrap `<App/>` in `QueryClientProvider`.
- All data loads client-side, so use Suspense boundaries or pending states per section and prefetch on hover or route preload.

### Next.js App Router
**Recommended: prefetch in Server Components, hydrate in Client Components.**
```tsx
// app/get-query-client.ts
import { QueryClient, defaultShouldDehydrateQuery, isServer } from "@tanstack/react-query";
function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { staleTime: 60_000 },
      dehydrate: {
        // include pending queries so un-awaited prefetches stream to the client
        shouldDehydrateQuery: (q) => defaultShouldDehydrateQuery(q) || q.state.status === "pending",
      },
    },
  });
}
let browserQueryClient: QueryClient | undefined;
export function getQueryClient() {
  if (isServer) return makeQueryClient();           // new per request
  return (browserQueryClient ??= makeQueryClient()); // singleton in browser
}

// app/providers.tsx
"use client";
import { QueryClientProvider } from "@tanstack/react-query";
import { getQueryClient } from "./get-query-client";
export function Providers({ children }: { children: React.ReactNode }) {
  const queryClient = getQueryClient(); // not useState: avoids losing client if Suspense discards initial render
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

// app/todos/page.tsx (Server Component)
import { HydrationBoundary, dehydrate } from "@tanstack/react-query";
export default async function TodosPage() {
  const qc = getQueryClient();
  await qc.prefetchQuery(todoQueries.list({ status: "open", page: 1 })); // or omit await to stream
  return (
    <HydrationBoundary state={dehydrate(qc)}>
      <TodoList />   {/* "use client": useSuspenseQuery / useQuery(todoQueries.list(...)) */}
    </HydrationBoundary>
  );
}
```
- `queryFn`s used in both places must work on the server and the client (absolute URLs, or call the data layer directly on the server via a separate prefetch function that uses the same key).
- After Server Action mutations, either `revalidatePath` (server data) or `queryClient.invalidateQueries` on the client (client cache). Pick one owner per piece of data.
- Don't also render the same data from the Server Component. It gets out of sync when the client cache refetches.

## AI Agent Guidance
- Check the installed major version (`@tanstack/react-query` 5.x). Don't generate v4 APIs (`cacheTime`, `useQuery(key, fn)` positional args, `onSuccess` on queries).
- Always create `queryOptions` factories. Never inline string keys scattered across files.
- In Next.js: per-request server QueryClient, `staleTime > 0`, `HydrationBoundary` in the Server Component page.
- Verify: no hydration refetch flash, mutations update every affected view, error and empty states render, and the eslint query plugin is clean.

## Examples
```tsx
"use client";
import { useSuspenseQuery } from "@tanstack/react-query";
export function TodoList() {
  const { data: todos } = useSuspenseQuery(todoQueries.list({ status: "open", page: 1 }));
  if (todos.length === 0) return <EmptyState title="No open todos" />;
  return <ul>{todos.map((t) => <li key={t.id}>{t.title}</li>)}</ul>;
}
```

## Related Skills
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md): Suspense mode and error resets
- [react-state-management](../react-state-management/Skill.md): server vs client state
- [nextjs-data-fetching-patterns](../nextjs-data-fetching-patterns/Skill.md): when to fetch in RSC instead
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md): typed API layer over Query
- [optimistic-ui](../optimistic-ui/Skill.md): UX of optimistic updates
- [api-mocking-msw](../api-mocking-msw/Skill.md): testing with MSW
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md): API client design

## Sources
- [TanStack Query docs: React overview & guides](https://tanstack.com/query/latest/docs/framework/react/overview) (Official): options, mutations, infinite queries
- [TanStack Query: Advanced Server Rendering](https://tanstack.com/query/latest/docs/framework/react/guides/advanced-ssr) (Official): Next.js App Router prefetch/hydrate, streaming pending queries
- [TanStack Query: Migrating to v5](https://tanstack.com/query/latest/docs/framework/react/guides/migrating-to-v5) (Official): removed v4 APIs
- [npm @tanstack/react-query](https://www.npmjs.com/package/@tanstack/react-query) (Official): current version 5.102.x
- [TkDodo: Practical React Query series](https://tkdodo.eu/blog/practical-react-query) (Community): staleTime defaults, keys, status checks, query options API
- [TkDodo: The Query Options API](https://tkdodo.eu/blog/the-query-options-api) (Community): queryOptions factories

## License / Usage Notes
TanStack Query is MIT. TkDodo's content is summarized with original examples.

## Quality Tier
S: official docs plus the maintainer's blog, verified against the v5 current release, including Next.js App Router integration.

## Status
Active

## Last Verified
2026-09-15
