# TanStack Router and TanStack Start

## Summary
TanStack Router (v1, `@tanstack/react-router` 1.16x) is a fully type-safe React router. It offers file-based or code-based routes, typed and validated search params, loaders with built-in SWR caching, preloading, and first-class TanStack Query integration. TanStack Start (`@tanstack/react-start` 1.16x, documented as a feature-complete Release Candidate with a stable API) builds a full-stack framework on it with Vite (or Rsbuild): SSR, streaming, `createServerFn` server functions, middleware, and server routes. In this React + Next.js stack, TanStack Router is a strong choice for **type-safe Vite SPAs**, and Start is an **alternative to Next.js** when a team doesn't want RSC.

## Category
React

## Subcategories
file-based routing, type-safe navigation, search param validation, loaders, preloading, router context, TanStack Query integration, createServerFn, middleware, server routes, SSR/streaming

## Problem It Solves
- String-typed routing: broken links, untyped params, search params parsed by hand.
- Data loading waterfalls in SPAs.
- The boilerplate of connecting a router to a query cache.

Start adds SSR and typed RPC without adopting RSC or Next.js conventions.

## When To Use
- Vite React SPAs (dashboards, internal tools, SaaS apps behind auth) where URL state and type safety matter.
- Apps with complex filter/search URL state (typed `validateSearch`).
- Full-stack React without RSC, with deploy-anywhere Vite builds (Start).

## When Not To Use
- Inside Next.js apps. Use the Next.js App Router.
- When RSC, `next/image` or Vercel-integrated caching are requirements (Start's RSC support is experimental).
- When the team's risk tolerance requires an explicitly declared 1.0-stable framework (Start docs still say RC; verify before adopting for critical production apps).

## Core Principles
1. **Register the router type** once (`declare module "@tanstack/react-router" { interface Register { router: typeof router } }`) so every `Link`, `navigate` and hook is typed.
2. **Search params are validated state**: define `validateSearch` with a schema, and read with `Route.useSearch()`.
3. **Loaders fetch in parallel before render.** Use `loaderDeps` to declare which search params affect the loader.
4. **Let TanStack Query own caching when used**: loaders call `ensureQueryData`, components call `useSuspenseQuery`.
5. **Server functions are RPC endpoints**: validate input (`.validator()`), authenticate in middleware.
6. **Keep server-only code in `.server.ts` files**, wrap it in `.functions.ts` server functions, and keep shared schemas/types in plain `.ts`.

## Best Practices
- Use file-based routing via the Vite plugin (`@tanstack/router-plugin/vite`), which generates `routeTree.gen.ts`. Commit it or regenerate it in CI consistently.
- Set `defaultPreload: "intent"` and a sensible `defaultPreloadStaleTime` (0 when TanStack Query handles caching).
- Pass dependencies (queryClient, auth) through **router context** (`createRootRouteWithContext<{ queryClient: QueryClient }>()`).
- Protect routes in `beforeLoad` (throw `redirect({ to: "/login", search: { redirect: location.href } })`).
- Provide `pendingComponent`, `errorComponent` and `notFoundComponent` per route or as defaults.
- Start: use `createServerFn({ method: "POST" }).validator(schema).handler(...)`. `inputValidator` is deprecated in favour of `validator`.
- Start: CSRF middleware is installed by default for server functions. Keep it.

## Implementation Guidance
**Router vs Start vs Next.js**

| Need | Choice |
|---|---|
| Client-only SPA, max type safety for URL state | TanStack Router |
| SPA already on React Router | Stay (see react-router-framework-mode) |
| SSR + typed RPC, no RSC, Vite-based | TanStack Start |
| RSC, image/font optimization, mature ecosystem | Next.js |

**Root route with context + Query**
```tsx
// src/routes/__root.tsx
import { createRootRouteWithContext, Outlet } from "@tanstack/react-router";
import type { QueryClient } from "@tanstack/react-query";
export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  component: () => <Outlet />,
  notFoundComponent: () => <p>Page not found</p>,
});

// src/router.tsx
import { createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";
export const queryClient = new QueryClient();
export const router = createRouter({ routeTree, context: { queryClient }, defaultPreload: "intent", defaultPreloadStaleTime: 0 });
declare module "@tanstack/react-router" { interface Register { router: typeof router } }
```

**Typed search params + loader deps**
```tsx
// src/routes/projects/index.tsx
import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

const searchSchema = z.object({
  status: z.enum(["all", "active", "archived"]).catch("all"),
  page: z.number().int().min(1).catch(1),
});

export const Route = createFileRoute("/projects/")({
  validateSearch: searchSchema,
  loaderDeps: ({ search }) => ({ status: search.status, page: search.page }),
  loader: ({ context, deps }) => context.queryClient.ensureQueryData(projectQueries.list(deps)),
  pendingComponent: ProjectsSkeleton,
  component: ProjectsPage,
});

function ProjectsPage() {
  const search = Route.useSearch();
  const navigate = Route.useNavigate();
  const { data } = useSuspenseQuery(projectQueries.list(search));
  return (
    <>
      <select aria-label="Status" value={search.status}
        onChange={(e) => navigate({ search: (prev) => ({ ...prev, status: e.target.value as typeof search.status, page: 1 }) })}>
        <option value="all">All</option><option value="active">Active</option><option value="archived">Archived</option>
      </select>
      <ProjectTable rows={data} />
    </>
  );
}
```
(Schema adapters: with Zod v4 or Valibot, Standard Schema validators can be passed directly. Check the docs for the adapter needed by your schema library version.)

**Auth guard**
```tsx
export const Route = createFileRoute("/_authed")({
  beforeLoad: ({ context, location }) => {
    if (!context.auth.user) throw redirect({ to: "/login", search: { redirect: location.href } });
  },
});
```

**Start server function**
```ts
// src/features/projects/projects.functions.ts
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { renameProjectInDb } from "./projects.server";

export const renameProject = createServerFn({ method: "POST" })
  .validator(z.object({ id: z.string().uuid(), name: z.string().min(1).max(100) }))
  .middleware([authMiddleware])            // provides context.user
  .handler(async ({ data, context }) => {
    await renameProjectInDb(context.user.id, data.id, data.name); // authorize inside
    return { ok: true as const };
  });
// Call from components/loaders: await renameProject({ data: { id, name } })
```
Server context helpers (`getRequest`, `setResponseHeaders`, `setResponseStatus`) are imported from `@tanstack/react-start/server`.

## Recommended Workflow
1. Scaffold with the official CLI/template (Router SPA or Start). Configure the Vite router plugin.
2. Define the root route with context (queryClient, auth).
3. Create routes, with `validateSearch` for any URL state.
4. Add loaders using `ensureQueryData`, and components using `useSuspenseQuery`.
5. Add `beforeLoad` guards and pending/error/not-found components.
6. Start: add server functions with validators and middleware, and server routes for webhooks and APIs.
7. `tsc --noEmit` and e2e tests for navigation, preload and auth redirects.

## Patterns
- **Pathless layout routes** (`_authed.tsx`) for shared guards and layouts.
- **Route masking** for modals with shareable URLs.
- **Search middlewares** (`retainSearchParams`, `stripSearchParams`) to keep or clean params across navigation.
- **Deferred data**: return un-awaited promises from loaders and render them with `<Await>` inside Suspense (Start SSR streaming).
- **Isomorphic loaders**: loaders run on the server for the first SSR request and on the client for later navigations (Start). Use server functions for server-only work.

## Anti-Patterns
- **Parsing `window.location.search` manually**: loses types and validation. Fix: `validateSearch` + `useSearch`.
- **Loader reading search params without `loaderDeps`**: stale cache keys. Fix: declare deps.
- **Duplicate caching** (router loader cache plus Query with conflicting stale times). Fix: `defaultPreloadStaleTime: 0` and let Query own it.
- **Importing `.server.ts` modules into client components**: bundle leaks or build errors. Fix: call server functions.
- **Skipping input validation on server functions** ("types are enough"): public endpoints. Fix: `.validator(schema)`.
- **Forgetting router type registration**: `Link` becomes untyped. Fix: the `Register` interface declaration.
- **Using deprecated `inputValidator`** in new code. Fix: `validator`.

## Accessibility
- `<Link>` renders real anchors, so keep them for navigation. Don't use `onClick` + `navigate` on divs.
- Manage focus and titles on route change (focus `<main>` heading, `head` via route `head()` in Start).
- Typed search-driven filters must use labelled controls and announce result counts (live region).
- Pending components should use skeletons with `aria-busy` rather than blocking spinners.

## Responsive Design
- Intent preloading on hover doesn't exist on touch. Consider `preload="viewport"` for primary mobile links, balanced against data usage.
- Keep layout responsiveness in CSS. Route layouts provide structure only.

## Performance
- Automatic code splitting (`autoCodeSplitting` in the router plugin) splits route components.
- Intent preloading plus `ensureQueryData` gives near-instant navigations.
- Structural sharing of search params avoids unnecessary re-renders. Select narrowly: `Route.useSearch({ select: (s) => s.page })`.
- Start: streaming SSR with deferred loader data. Prerender static routes where supported.

## Security
- Server functions and server routes are public HTTP endpoints: validate, authenticate (middleware), authorize, rate limit.
- Keep CSRF middleware enabled. Set security headers in request middleware.
- Env: only prefixed public vars reach the client (Vite `VITE_` convention). Keep secrets in server-only modules.
- Validate search params, which are user-controlled input (the `.catch()` defaults above are defensive).

## Testing
- Unit test search schemas and server function handlers (call the handler logic in `.server.ts` directly).
- Component tests: create a test router with `createMemoryHistory` and render `<RouterProvider>` with a test QueryClient.
- Playwright: typed navigation flows, auth redirects, preload behaviour, SSR hydration (Start).

## Tooling
- `@tanstack/react-router` v1 (active), `@tanstack/router-plugin` (Vite), `@tanstack/react-router-devtools`.
- `@tanstack/react-start` (docs: Release Candidate, API stable; npm 1.16x; RSC experimental).
- `@tanstack/react-router-ssr-query` / Query integration utilities for SSR dehydration (check the current package name in docs).
- Zod / Valibot / ArkType for `validateSearch` and server function validators.

## Framework Notes
### React (Vite SPA)
- The main use case in this stack: `@tanstack/router-plugin/vite` + `createRouter` + `<RouterProvider router={router} />`, paired with TanStack Query via router context.
- SPAs have no server functions. Call your API (REST/tRPC) from loaders through query options.

### Next.js App Router
- Don't mix TanStack Router into Next.js. Concepts map as follows: `validateSearch` → nuqs parsers or `searchParams` + Zod in Server Components; loaders → async Server Components; `createServerFn` → Server Actions or route handlers; `beforeLoad` guards → layout-level session checks plus `proxy.ts`; `pendingComponent` → `loading.tsx`.
- Choose Start over Next.js mainly for a Vite toolchain, no RSC, explicit RPC and isomorphic loaders. Choose Next.js for RSC, built-in image and font optimization, and the larger ecosystem.

## AI Agent Guidance
- Detect whether the project uses Router only (Vite SPA) or Start (`@tanstack/react-start` in dependencies, `src/start.ts`).
- Always add `validateSearch` for URL state, `loaderDeps` for loaders that use search params, and register the router type.
- For server functions, use `.validator()` (not deprecated `inputValidator`) plus auth middleware.
- Verify: `tsc` passes with typed links, route tree regenerated, auth redirects work, and no server-only imports in client bundles.

## Examples
```tsx
// Typed navigation, type error if params/search are wrong
<Link to="/projects/$projectId" params={{ projectId: p.id }} search={{ tab: "settings" }}>
  {p.name}
</Link>
```

## Related Skills
- [react-router-framework-mode](../react-router-framework-mode/Skill.md): alternative router
- [vite-react-spa](../vite-react-spa/Skill.md): SPA project setup
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md): loader + query integration
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): URL state equivalent in Next.js
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md): typed API alternatives to server functions
- [accessible-spa-routing](../accessible-spa-routing/Skill.md): route change accessibility

## Sources
- [TanStack Router docs](https://tanstack.com/router/latest/docs/framework/react/overview) (Official): file routes, search params, loaders, context, preloading
- [TanStack Start overview](https://tanstack.com/start/latest/docs/framework/react/overview) (Official): RC status, capabilities, RSC experimental
- [TanStack Start: Server Functions](https://tanstack.com/start/latest/docs/framework/react/guide/server-functions) (Official): createServerFn, validator, file organization, CSRF middleware
- [TanStack/router source: createServerFn.ts](https://github.com/TanStack/router/blob/main/packages/start-client-core/src/createServerFn.ts) (Open Source): `inputValidator` deprecated in favor of `validator`
- [TanStack Start v1 Release Candidate blog](https://tanstack.com/blog/announcing-tanstack-start-v1) (Official): RC announcement (Sept 2025)
- [npm @tanstack/react-start](https://www.npmjs.com/package/@tanstack/react-start) (Official): version 1.168.x, peers (React ≥18, Vite ≥7)

## License / Usage Notes
TanStack libraries are MIT. Docs are summarized. Examples are original. Start's stability label conflicts across sources (docs say RC; some community posts claim a 1.0 release), so verify before citing it as stable.

## Quality Tier
B: official sources, but Start's status is ambiguous, some adapter APIs weren't re-verified, and it's secondary to Next.js in this stack.

## Status
Active

## Last Verified
2026-09-15
