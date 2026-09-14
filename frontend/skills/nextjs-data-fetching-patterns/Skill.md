# Next.js Data Fetching Patterns

## Summary
In the Next.js 16 App Router, data is fetched primarily in async Server Components (via `fetch`, ORMs, or SDKs), deduplicated per request (`fetch` memoization, `React.cache`), streamed with `<Suspense>`/`loading.tsx`, and optionally cached with `'use cache'`. Client-side fetching (React `use()` with server-started promises, SWR, TanStack Query) is reserved for interactive, polled, or browser-dependent data. `fetch` is **not cached by default** (since v15). This skill gives patterns for sequential vs parallel fetching, preloading, the three recommended data-access architectures, and server-to-client data handoff.

## Category
Next.js

## Subcategories
Server Components fetching, fetch memoization, React.cache, parallel fetching, preload, streaming, use(), SWR, TanStack Query, Data Access Layer, external APIs

## Problem It Solves
Waterfalls from sequential awaits, duplicate DB queries across metadata/layout/page, fetching through the app's own Route Handlers, blocking pages on slow data, leaking raw records to clients, and outdated assumptions that `fetch` caches automatically or that `getServerSideProps` is needed.

## When To Use
- Loading data for pages, layouts, metadata, and components.
- Choosing where data access lives (HTTP APIs vs DAL vs component-level).
- Combining server-fetched data with client interactivity or polling.

## When Not To Use
- Mutations (see [nextjs-server-actions](../nextjs-server-actions/Skill.md)).
- Cache lifetimes/invalidation (see [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md)).
- ORM setup, pooling, migrations (see [nextjs-database-integration](../nextjs-database-integration/Skill.md)).
- End-to-end typed RPC layer (see [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md)).

## Core Principles
1. **Fetch where the data is needed, on the server.** Memoization makes repeated identical calls cheap.
2. **Start independent work together;** await sequentially only when a request depends on another.
3. **Stream slow data** behind the smallest meaningful Suspense boundary.
4. **Pick one data-access approach per codebase:** external HTTP APIs (existing orgs), a Data Access Layer (new projects), or component-level queries (prototypes only).
5. **Hand minimal, serializable data (or promises) to Client Components.**
6. **Don't call your own Route Handlers from Server Components.**

## Best Practices
- Wrap non-`fetch` data functions in `React.cache` for per-request dedup (scope: single request only).
- Use the preload pattern (`void getItem(id)`) to start requests before unrelated blocking work.
- Use `Promise.allSettled` when partial failure should not fail the page; otherwise `Promise.all`.
- Pass promises to Client Components and resolve with `use()` under `<Suspense>`; share via context for many consumers.
- For client-only concerns (polling, infinite scroll, optimistic lists, browser APIs) use TanStack Query or SWR; seed with server data (`initialData`/hydration) to avoid double loading.
- Forward auth cookies/headers explicitly when calling external APIs from Server Components (zero-trust).
- Validate external API responses (zod) at the boundary.
- Under Cache Components, move `searchParams`/`params`/`cookies()` reads into Suspense-wrapped children; pass extracted primitives to cached functions.
- Enable `logging.fetches` in dev to see fetch calls and cache status.

## Implementation Guidance

### Approach selection
| Situation | Approach |
|---|---|
| Existing REST/GraphQL backend owned by other teams | Server Components call external HTTP APIs (forward credentials) |
| New full-stack app | `server-only` Data Access Layer returning DTOs |
| Prototype/demo | Component-level queries (sanitize before passing to client) |
| Polling, infinite scroll, client filters | TanStack Query/SWR in Client Components |
| Needs browser APIs (geolocation, storage) | Client-side fetch |

### Sequential with streaming
```tsx
export default async function ArtistPage(props: PageProps<'/artist/[username]'>) {
  const { username } = await props.params
  const artist = await getArtist(username) // needed for next request
  return (
    <>
      <h1>{artist.name}</h1>
      <Suspense fallback={<p>Loading playlists…</p>}>
        <Playlists artistId={artist.id} />
      </Suspense>
    </>
  )
}
async function Playlists({ artistId }: { artistId: string }) {
  const playlists = await getPlaylists(artistId)
  return <ul>{playlists.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
}
```

### Request dedup with React.cache
```ts
// lib/dal/user.ts
import 'server-only'
import { cache } from 'react'
export const getUser = cache(async (id: string) => {
  const u = await db.user.findUnique({ where: { id }, select: { id: true, name: true, avatarUrl: true } })
  return u
})
```

### Preload colocated with consumer
```tsx
// app/item/[id]/item.tsx
const getItem = cache(async (id: string) => (await fetch(`${API}/items/${id}`)).json())
export const preload = (id: string) => { void getItem(id) }
export default async function Item({ id }: { id: string }) {
  const item = await getItem(id)
  return <div>{item.name}</div>
}
```

### Promise through context to many client consumers
```tsx
// app/(app)/layout.tsx
import { Suspense } from 'react'
import { UserProvider } from './user-provider'
export default function AppLayout({ children }: LayoutProps<'/'>) {
  return (
    <Suspense fallback={<ShellSkeleton />}>
      <UserBoundary>{children}</UserBoundary>
    </Suspense>
  )
}
function UserBoundary({ children }: { children: React.ReactNode }) {
  const userPromise = getCurrentUser() // not awaited
  return <UserProvider userPromise={userPromise}>{children}</UserProvider>
}
```

### Server data seeding TanStack Query
```tsx
// app/orders/page.tsx
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'
export default async function OrdersPage() {
  const qc = new QueryClient()
  await qc.prefetchQuery({ queryKey: ['orders'], queryFn: getOrdersDTO })
  return (
    <HydrationBoundary state={dehydrate(qc)}>
      <OrdersTable /> {/* 'use client', useQuery(['orders'], fetchOrders) with polling */}
    </HydrationBoundary>
  )
}
```

### Legacy note (Pages Router / previous model)
`getServerSideProps` → async Server Component (uncached by default). `getStaticProps` → cached function (`'use cache'` or, without Cache Components, `fetch(..., { cache: 'force-cache' })`). `getStaticPaths` → `generateStaticParams`.

## Recommended Workflow
1. Draw the data dependency graph per route (what depends on what).
2. Implement data functions in the DAL (or API client) with DTOs + validation.
3. Call them from the components that render the data; start independent ones in parallel.
4. Place Suspense boundaries around slow independent regions.
5. Add caching only where freshness allows.
6. Add client fetching only for interactive/polling needs, seeded from the server.
7. Verify with fetch logging and the React DevTools Suspense panel.

## Patterns
- **Fetch-in-leaf + memoization** (no prop drilling of data).
- **Parallel sibling Suspense** for dashboards.
- **Preload before auth/feature-flag check.**
- **Promise prop → `use()`** for streaming into client charts.
- **Server-seeded client cache** for tables with polling.
- **URL as state:** filters in search params read inside Suspense (see [react-url-state-nuqs](../react-url-state-nuqs/Skill.md)).

## Anti-Patterns
- **`const a = await x(); const b = await y();`** for independent data — waterfall. Fix: start both first.
- **Fetching `/api/...` of the same app from a Server Component** — extra hop, fails during build prerender. Fix: import the data function.
- **`useEffect` + `fetch` for initial page data** — slower, no SSR, loading flashes. Fix: Server Component fetch.
- **Assuming `fetch` is cached** (pre-v15 behavior) — unexpectedly dynamic/slow. Fix: `'use cache'` (or `cache: 'force-cache'` in previous model).
- **Using Server Actions to fetch** — sequential queue. Fix: Server Components or Route Handlers.
- **Passing full ORM rows to Client Components** — data exposure. Fix: DTOs.
- **Using `React.cache` across requests** expecting persistence — it's per request. Fix: `'use cache'`.
- **Awaiting `searchParams` at page top under Cache Components** — blocks shell. Fix: pass promise to Suspense child.

## Accessibility
- Loading fallbacks should describe what's loading ("Loading playlists…"), not just spinners; use `aria-busy` on regions.
- Errors from failed fetches must render meaningful messages with recovery (`catchError` retry or `error.tsx`).
- Avoid layout jumps when data arrives (skeletons with matching dimensions).

## Responsive Design
- Don't fetch different data per viewport on the server; fetch once and let CSS adapt; lazy-load optional mobile-hidden panels on the client if expensive.

## Performance
- Parallelism and streaming reduce TTFB/LCP; each boundary also splits hydration.
- `fetch` memoization applies to identical GET requests in the React render tree (not in Route Handlers).
- Seeded client caches avoid double requests on hydration.
- Watch N+1 queries in lists — batch in DAL (`findMany` with `in`).

## Security
- Server Components can use secrets; Client Components cannot — keep API keys in DAL modules with `server-only`.
- Forward only required credentials to upstream APIs; never log tokens.
- Validate and authorize in the DAL (see [nextjs-authentication](../nextjs-authentication/Skill.md)).
- `[param]` and `searchParams` are untrusted input.

## Testing
- Unit test DAL functions (mock DB/API), including authorization branches.
- MSW to mock external APIs for component and E2E tests (server-side interception in Node).
- Playwright for async Server Components; assert fallbacks appear and resolve.

## Tooling
- `React.cache`, `use()`; `next.config` `logging: { fetches: { fullUrl: true } }`.
- TanStack Query v5, SWR; zod for response validation; MSW for mocking.
- React DevTools Suspense panel.

## Framework Notes
- v15 changed `fetch` default to uncached; v16 Cache Components makes all data uncached unless in `'use cache'`.
- `React.cache` is isolated inside `'use cache'` scopes; pass args instead.
- React (Vite SPA): all fetching is client-side — use TanStack Query with route loaders/prefetching; there is no server memoization or streaming HTML.

## AI Agent Guidance
- Default to server-side fetching in the component that renders the data; wrap ORM calls in `React.cache`.
- Detect and fix sequential independent awaits.
- Never generate `useEffect` initial-data fetching for server-renderable content, nor internal `/api` fetches from Server Components.
- Before done: confirm no waterfalls in the changed route, DTOs at client boundaries, Suspense around slow regions, and production build passes.

## Examples
```tsx
// Dashboard with independent streamed widgets
import { Suspense } from 'react'
export default function Dashboard() {
  return (
    <main className="grid gap-4 md:grid-cols-2">
      <h1 className="md:col-span-2">Dashboard</h1>
      <Suspense fallback={<CardSkeleton label="Revenue" />}><Revenue /></Suspense>
      <Suspense fallback={<CardSkeleton label="Orders" />}><RecentOrders /></Suspense>
    </main>
  )
}
```

## Related Skills
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) — boundaries and props
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — Suspense design
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — caching fetched data
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — client server-state
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — ORM/DB access
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — search-param state
- [api-mocking-msw](../api-mocking-msw/Skill.md) — mocking
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — API client design

## Sources
- [Fetching Data](https://nextjs.org/docs/app/getting-started/fetching-data) — Official — server/client fetching, streaming, sequential/parallel, React.cache, preload
- [Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — three data access approaches, DTOs
- [Streaming guide](https://nextjs.org/docs/app/guides/streaming) — Official — promise passing, context sharing
- [Backend for Frontend guide](https://nextjs.org/docs/app/guides/backend-for-frontend) — Official — don't call own route handlers
- [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) — Official — searchParams/params inside Suspense, React.cache isolation
- [App Router migration guide](https://nextjs.org/docs/app/guides/migrating/app-router-migration) — Official — gSSP/gSP mapping

## License / Usage Notes
Next.js MIT; TanStack Query MIT; SWR MIT. Summarized; code original. TanStack hydration snippet follows its documented public API — verify against installed version.

## Quality Tier
A — Official-grounded, practical; TanStack integration summarized from general knowledge of v5 API.

## Status
Active

## Last Verified
2026-09-15
