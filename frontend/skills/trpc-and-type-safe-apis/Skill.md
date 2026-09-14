# tRPC and Type-Safe APIs in Next.js

## Summary
How to get end-to-end type safety between server and client in a Next.js App Router app, and how to choose between tRPC v11 (with the TanStack React Query integration), Server Actions, Route Handlers, and OpenAPI-generated clients (Hey API, Orval). Includes the canonical tRPC v11 App Router setup with RSC prefetch/hydration, procedure/middleware design, and anti-patterns.

## Category
Next.js

## Subcategories
tRPC v11, TanStack Query integration, Server Actions, Route Handlers, OpenAPI code generation, API contracts, input validation, error handling

## Problem It Solves
Hand-typed `fetch` calls drift from server reality, causing runtime errors that TypeScript cannot catch. Teams also over-engineer (tRPC for three mutations) or under-engineer (Server Actions as a general read API). This skill picks the right contract layer and implements it correctly with caching, auth, and validation.

## When To Use
- A Next.js app with many client-side reads needing caching, polling, infinite queries, or optimistic updates.
- A TypeScript monorepo where the backend and frontend share types.
- Integrating an external REST API that publishes an OpenAPI spec.
- Deciding the API layer for a new project.

## When Not To Use
- Simple CRUD forms fully served by Server Components + Server Actions (tRPC adds little).
- Public APIs consumed by third parties or non-TS clients (use REST/OpenAPI or GraphQL).
- Backends in other languages without OpenAPI (consider GraphQL codegen or contract-first specs).

## Core Principles
1. Pick one primary data-access style per app surface and document it; mixing ad hoc increases security review cost.
2. Reads in Server Components call the data layer directly (DAL or a server-side tRPC caller) — do not HTTP-call your own API from the server.
3. Every procedure/action/handler validates input at runtime (Zod/Valibot/Standard Schema) and authorizes inside the procedure.
4. Types flow from the server definition or the API spec; never hand-write response types for your own endpoints.
5. Client caches (TanStack Query) are for interactive client data; Next.js caching is for server-rendered data. Know which one owns a given piece of data.
6. Errors are typed and mapped (tRPC error codes, action result objects, HTTP status).

## Best Practices
- tRPC v11 packages: `@trpc/server`, `@trpc/client`, `@trpc/tanstack-react-query`, `@tanstack/react-query` v5, plus `zod` and optionally `superjson`.
- Use the `createTRPCContext`/`useTRPC` + `queryOptions()`/`mutationOptions()` pattern (native TanStack Query APIs), not the classic `trpc.x.useQuery()` hooks for new code.
- Create the server context with `React.cache` so one request shares auth/session lookup.
- Build `publicProcedure` and `protectedProcedure` (middleware that asserts session and narrows `ctx`).
- Mount the HTTP handler at `app/api/trpc/[trpc]/route.ts` using the fetch adapter.
- Prefetch in Server Components with `createTRPCOptionsProxy` + `prefetch(...)` and wrap client subtrees in `HydrateClient`; consume with `useSuspenseQuery`.
- Dehydrate pending queries (`shouldDehydrateQuery` includes `status === 'pending'`) for streaming.
- Set a non-zero default `staleTime` (e.g., 30s) to avoid immediate client refetch after hydration.
- Use the same transformer (e.g., superjson) on both server `initTRPC.create({ transformer })` and client links.
- Invalidate via `queryClient.invalidateQueries({ queryKey: trpc.post.list.queryKey() })` or `trpc.post.pathFilter()`.
- For OpenAPI backends, generate clients in CI from a pinned spec; commit or regenerate deterministically; fail CI on drift.
- Keep procedures thin: validate -> authorize -> call domain/DAL -> map DTO.

## Implementation Guidance

### Decision table
| Criterion | Server Actions | tRPC v11 + TanStack Query | Route Handlers (REST) | OpenAPI codegen (Hey API/Orval) |
|---|---|---|---|---|
| Mutations from forms | Best (PE, revalidation) | OK | OK | OK |
| Client reads with caching/polling/infinite | Poor (actions are POST, sequential) | Best | OK with Query | Best for external APIs |
| Server Component reads | Call DAL directly | Server caller / prefetch | Call DAL directly | Generated client on server |
| Type safety | Function signature | Inferred end-to-end | Manual or zod-to-openapi | Generated from spec |
| Non-TS or 3rd-party consumers | No | No (TS clients only) | Yes | Yes |
| Webhooks, file streams, public endpoints | No | Awkward | Best | N/A |
| Setup cost | Lowest | Medium | Low | Medium (spec + pipeline) |

Rules of thumb:
- New Next.js app, mostly forms and server-rendered pages: Server Components + Server Actions.
- Highly interactive dashboard with lots of client reads in a TS stack: tRPC v11 (or Route Handlers + TanStack Query if you prefer REST semantics).
- Existing REST backend with OpenAPI: Hey API or Orval to generate typed clients and TanStack Query options.
- Webhooks, OAuth callbacks, file downloads, public APIs: Route Handlers.

### tRPC v11 file layout
```
src/trpc/
  init.ts           # initTRPC, context, procedures, middleware
  query-client.ts   # makeQueryClient with dehydrate settings
  client.tsx        # 'use client' TRPCReactProvider, useTRPC
  server.tsx        # 'server-only' options proxy, caller, HydrateClient, prefetch
  routers/_app.ts   # appRouter + AppRouter type
  routers/post.ts
src/app/api/trpc/[trpc]/route.ts
```

### init.ts with auth middleware
```ts
// src/trpc/init.ts
import { initTRPC, TRPCError } from '@trpc/server'
import { cache } from 'react'
import superjson from 'superjson'
import { getSession } from '@/server/auth' // reads cookies, verifies session

export const createTRPCContext = cache(async () => {
  const session = await getSession()
  return { session }
})

const t = initTRPC.context<Awaited<ReturnType<typeof createTRPCContext>>>().create({
  transformer: superjson,
})

export const createTRPCRouter = t.router
export const createCallerFactory = t.createCallerFactory
export const publicProcedure = t.procedure
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.session?.user) throw new TRPCError({ code: 'UNAUTHORIZED' })
  return next({ ctx: { ...ctx, user: ctx.session.user } })
})
```

### Router with validation and authorization
```ts
// src/trpc/routers/post.ts
import { z } from 'zod'
import { TRPCError } from '@trpc/server'
import { createTRPCRouter, protectedProcedure, publicProcedure } from '../init'
import { posts } from '@/server/posts' // server-only DAL returning DTOs

export const postRouter = createTRPCRouter({
  list: publicProcedure
    .input(z.object({ cursor: z.string().nullish(), limit: z.number().int().min(1).max(50).default(20) }))
    .query(({ input }) => posts.list(input)),

  update: protectedProcedure
    .input(z.object({ id: z.string().uuid(), title: z.string().min(1).max(200) }))
    .mutation(async ({ ctx, input }) => {
      const post = await posts.get(input.id)
      if (!post) throw new TRPCError({ code: 'NOT_FOUND' })
      if (post.authorId !== ctx.user.id) throw new TRPCError({ code: 'FORBIDDEN' })
      return posts.update(input.id, { title: input.title })
    }),
})
```

### Route handler
```ts
// src/app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from '@trpc/server/adapters/fetch'
import { createTRPCContext } from '@/trpc/init'
import { appRouter } from '@/trpc/routers/_app'

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: '/api/trpc',
    req,
    router: appRouter,
    createContext: createTRPCContext,
    onError: ({ path, error }) => {
      if (error.code === 'INTERNAL_SERVER_ERROR') console.error(`tRPC ${path}:`, error) // send to observability
    },
  })

export { handler as GET, handler as POST }
```

### Client provider essentials
Follow the official `client.tsx`: a module-level browser `QueryClient` singleton (new client per server request), `createTRPCClient` with `httpBatchLink({ url: '/api/trpc', transformer: superjson })` created in `useState`, and `TRPCProvider` inside `QueryClientProvider`. Server-side `server.tsx` exports `getQueryClient = cache(makeQueryClient)`, `trpc = createTRPCOptionsProxy({ ctx: createTRPCContext, router: appRouter, queryClient: getQueryClient })`, `caller = appRouter.createCaller(createTRPCContext)`, `HydrateClient`, and `prefetch`.

### RSC prefetch + client consumption
```tsx
// src/app/posts/page.tsx
import { Suspense } from 'react'
import { ErrorBoundary } from 'react-error-boundary'
import { HydrateClient, prefetch, trpc } from '@/trpc/server'
import { PostList } from './post-list'

export default function PostsPage() {
  prefetch(trpc.post.list.queryOptions({ limit: 20 }))
  return (
    <HydrateClient>
      <ErrorBoundary fallback={<p role="alert">Could not load posts.</p>}>
        <Suspense fallback={<p>Loading posts…</p>}>
          <PostList />
        </Suspense>
      </ErrorBoundary>
    </HydrateClient>
  )
}
```

```tsx
// src/app/posts/post-list.tsx
'use client'
import { useMutation, useQueryClient, useSuspenseQuery } from '@tanstack/react-query'
import { useTRPC } from '@/trpc/client'

export function PostList() {
  const trpc = useTRPC()
  const queryClient = useQueryClient()
  const { data } = useSuspenseQuery(trpc.post.list.queryOptions({ limit: 20 }))
  const rename = useMutation(
    trpc.post.update.mutationOptions({
      onSuccess: () => queryClient.invalidateQueries({ queryKey: trpc.post.list.queryKey() }),
    }),
  )
  return (
    <ul>
      {data.items.map(p => (
        <li key={p.id}>
          {p.title}
          <button disabled={rename.isPending} onClick={() => rename.mutate({ id: p.id, title: `${p.title}!` })}>
            Rename
          </button>
        </li>
      ))}
    </ul>
  )
}
```
If a Server Component needs the data itself (not just to hydrate the client), use `await caller.post.list({ limit: 20 })` or `getQueryClient().fetchQuery(...)` — but avoid rendering server and client copies that can diverge.

### OpenAPI codegen (Hey API example)
```ts
// openapi-ts.config.ts
import { defineConfig } from '@hey-api/openapi-ts'

export default defineConfig({
  input: './openapi/billing.yaml', // pinned spec file or versioned URL
  output: 'src/generated/billing',
  plugins: ['@hey-api/client-fetch', '@hey-api/sdk', 'zod', '@tanstack/react-query'],
})
```
Pin `@hey-api/openapi-ts` exactly (pre-1.0, breaking changes possible). Orval (v8) is an alternative that also generates MSW mocks and Zod schemas; choose one generator per spec.

## Recommended Workflow
1. Classify endpoints: form mutations, interactive client reads, server-rendered reads, external/public endpoints.
2. Apply the decision table; record the choice in AGENTS.md/architecture docs.
3. Build the DAL first (server-only, auth-aware, DTOs); procedures/actions/handlers call it.
4. For tRPC: scaffold `init.ts`, routers, route handler, client/server files per official v11 docs.
5. Add input schemas and `protectedProcedure` for anything non-public.
6. Prefetch in Server Components where the first paint needs data; use Suspense + error boundaries.
7. Implement mutations with invalidation or optimistic updates.
8. Add tests (caller-based unit tests, e2e flows) and CI type checks.

## Patterns
- **Protected procedure middleware** narrowing `ctx.user`.
- **Server caller for tests and RSC**: `createCallerFactory(appRouter)(ctx)`.
- **Prefetch + HydrateClient + useSuspenseQuery** for streaming without waterfalls.
- **Infinite lists**: `trpc.post.list.infiniteQueryOptions(input, { getNextPageParam: last => last.nextCursor })`.
- **Hybrid**: Server Actions for form mutations; tRPC for client-heavy reads — mutations call the same DAL and invalidate both Next cache tags and relevant query keys.
- **Generated client + queryOptions** for external OpenAPI APIs, wrapped in a thin `src/api/` layer.

## Anti-Patterns
- **Classic v10 setup (`createTRPCNext`, `@trpc/react-query` `trpc.x.useQuery`) in new App Router code.** Outdated. Fix: `@trpc/tanstack-react-query` with `queryOptions`.
- **Server Components fetching `http://localhost:3000/api/trpc/...`.** Extra hop, lost auth context, build-time failures. Fix: server caller/options proxy or DAL.
- **Server Actions for general reads/polling.** POST-only, run sequentially, no client cache. Fix: RSC reads or Query.
- **Procedures without `.input()` validation.** Type-only safety is not runtime safety. Fix: Zod schemas.
- **Auth checked only in layout/proxy.** Procedures are directly callable. Fix: middleware per procedure.
- **Shared `QueryClient` singleton on the server.** Leaks data between users. Fix: `cache(makeQueryClient)` per request on the server; singleton only in the browser.
- **Returning raw DB rows.** Leaks internal fields. Fix: DTO mapping in the DAL.
- **Hand-written types for an OpenAPI backend.** Drift. Fix: codegen in CI with drift check.
- **`staleTime: 0` with SSR prefetch.** Immediate duplicate client fetch. Fix: sensible `staleTime`.

## Accessibility
- Loading and error states from Suspense/ErrorBoundary must be perceivable: text fallbacks, `role="alert"` for errors, `aria-busy` on regions.
- Mutation feedback (success/failure) should be announced (live region or toast with `role="status"`).
- Disable or `aria-disabled` controls during pending mutations without removing focus.

## Responsive Design
- API choice is layout-agnostic; for mobile, reduce payload size via cursor pagination and field selection in procedures.
- Avoid over-fetching large lists for small screens; parameterize `limit`.

## Performance
- `httpBatchLink` batches concurrent calls; `httpBatchStreamLink` streams batched responses as they resolve.
- Prefetch on the server to avoid client waterfalls; dehydrate pending queries to stream.
- Set `staleTime` to avoid refetch storms; use `select` to limit re-renders.
- Keep the `AppRouter` type import type-only on the client (`import type`) so server code is never bundled.
- Split large routers; TypeScript performance degrades with very large inferred routers — consider project references or splitting apps.

## Security
- tRPC and Route Handlers are public HTTP endpoints; Server Actions are public POST endpoints. Authenticate and authorize in every procedure/action/handler.
- Validate and bound all inputs (lengths, ranges, enums).
- Return DTOs, never secrets or internal fields; mark DAL modules `server-only`.
- Rate-limit expensive procedures (middleware with a shared store).
- Do not expose stack traces: map `INTERNAL_SERVER_ERROR` to generic messages in production (`errorFormatter`).
- CSRF: tRPC over fetch with JSON bodies and SameSite cookies is generally safe; if you allow GET for queries, ensure queries have no side effects.
- For codegen, treat specs as supply-chain input: pin versions and review generated diffs.

## Testing
- Unit test procedures with `createCaller` and a fake context (authorized, unauthorized, forbidden, invalid input).
- Component tests: MSW handlers for `/api/trpc/*` or wrap with a test QueryClient and mock `useTRPC` data; for OpenAPI clients, Orval/Hey API MSW generators.
- E2E (Playwright): critical flows through real route handlers.
- CI: `tsc --noEmit` catches contract breaks; codegen drift check (`git diff --exit-code src/generated`).

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| tRPC v11 + `@trpc/tanstack-react-query` | Active | Recommended integration for new apps |
| `@trpc/react-query` classic hooks | Legacy-supported | Migrate new code to queryOptions style |
| tRPC v10 / `@trpc/next` pages patterns | Outdated | — |
| TanStack Query v5 | Active | Required by tRPC v11 |
| Next.js Server Actions | Stable | Forms/mutations |
| Hey API `@hey-api/openapi-ts` | Active, pre-1.0 (pin exact) | Fetch/Next clients, Zod, TanStack Query plugins |
| Orval v8 | Active | React Query/SWR hooks, Zod, MSW mocks |
| superjson | Active | Dates/Maps over the wire |
| next-safe-action | Community, active | Typed, validated Server Actions with middleware |

## Framework Notes
- **Next.js**: Official tRPC docs cover App Router RSC prefetch/hydration; route handler at `app/api/trpc/[trpc]/route.ts`; context via `React.cache`; `server-only` for the server file. Server Actions remain the default for forms; see [nextjs-server-actions](../nextjs-server-actions/Skill.md).
- **React (Vite SPA)**: tRPC client + TanStack Query work the same (no RSC prefetch); the server runs separately (Node, Hono, Fastify adapters). OpenAPI codegen is often the better fit when the backend is not TypeScript.

## AI Agent Guidance
- Do: detect the existing API style (look for `src/trpc`, `'use server'` files, `app/api/**/route.ts`, generated clients) and follow it.
- Do: add `.input()` schemas and use `protectedProcedure` for non-public operations; add invalidation on mutations.
- Do: import `AppRouter` as a type only on the client.
- Don't: introduce tRPC into a project that uses Server Actions + RSC unless requirements justify it; don't mix a second API style without documenting why.
- Don't: call your own HTTP API from Server Components.
- Before done: `tsc --noEmit` passes; unauthorized caller test fails as expected; the page renders without client waterfall (network tab shows no duplicate fetch after hydration).

## Examples
```ts
// Unit test with caller
import { describe, it, expect } from 'vitest'
import { createCallerFactory } from '@/trpc/init'
import { appRouter } from '@/trpc/routers/_app'

const createCaller = createCallerFactory(appRouter)

describe('post.update', () => {
  it('rejects anonymous users', async () => {
    const caller = createCaller({ session: null })
    await expect(caller.post.update({ id: crypto.randomUUID(), title: 'x' })).rejects.toMatchObject({ code: 'UNAUTHORIZED' })
  })
})
```

```ts
// Server Action alternative for the same mutation (form-driven)
'use server'
import { z } from 'zod'
import { revalidatePath } from 'next/cache'
import { requireUser } from '@/server/auth'
import { posts } from '@/server/posts'

const Input = z.object({ id: z.string().uuid(), title: z.string().min(1).max(200) })

export async function renamePost(formData: FormData) {
  const user = await requireUser()
  const { id, title } = Input.parse(Object.fromEntries(formData))
  await posts.updateOwned(user.id, id, { title }) // authz inside DAL
  revalidatePath('/posts')
}
```

## Related Skills
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — form mutations alternative
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — REST endpoints and webhooks
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — query cache fundamentals
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — API layer boundaries
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — the DAL procedures call
- [nextjs-data-fetching-patterns](../nextjs-data-fetching-patterns/Skill.md) — server reads
- [api-mocking-msw](../api-mocking-msw/Skill.md) — mocking API contracts in tests

## Sources
- [tRPC: TanStack React Query + Server Components setup](https://trpc.io/docs/client/tanstack-react-query/server-components) — Official — init/query-client/client/server files, prefetch, HydrateClient, caller
- [Next.js Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, action auth, return values
- [Next.js Forms guide](https://nextjs.org/docs/app/guides/forms) — Official — Server Actions for mutations
- [Hey API openapi-ts Get Started](https://heyapi.dev/openapi-ts/get-started) — Official — config, plugins, pin exact version
- [Orval](https://orval.dev/) — Official — generated hooks, Zod, MSW mocks, v8

## License / Usage Notes
tRPC, TanStack Query, Hey API, Orval are MIT licensed. Content summarized from official docs; code adapted and simplified, verify against installed versions.

## Quality Tier
A — tRPC setup from current official v11 docs; decision table is synthesized guidance; OpenAPI generator config details should be verified per version.

## Status
Active

## Last Verified
2026-09-15
