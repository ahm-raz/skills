# React Router (v8) — Framework, Data and Declarative Modes

## Summary
React Router v8 (8.3.x as of late Aug 2026) is the successor to Remix and React Router v7. It runs in three modes: **declarative** (`<BrowserRouter>`, routing only), **data** (`createBrowserRouter` with loaders and actions), and **framework** (Vite plugin, file or config routes, typegen, SSR/SPA/prerender, middleware). In this React + Next.js stack, it's the recommended router for **Vite React SPAs**, and it's the main alternative to Next.js when a team wants a Remix-style, web-standards framework. This skill covers choosing a mode, loaders/actions, typegen, middleware (always on in v8), and the v7→v8 upgrade.

## Category
React

## Subcategories
framework mode, data mode, declarative mode, loaders, actions, clientLoader, fetchers, middleware, route typegen, SPA mode, prerendering, v7 to v8 upgrade

## Problem It Solves
SPAs need nested routing, data loading without waterfalls, pending UI, mutation revalidation and code splitting. React Router provides these without adopting RSC. It also gives a migration path for Remix v2 and React Router v6/v7 apps.

## When To Use
- Vite React SPAs (data mode, or framework mode with `ssr: false`).
- Teams preferring loaders/actions, web `Request`/`Response`, and deploy-anywhere adapters over Next.js conventions.
- Maintaining or upgrading Remix/React Router v6–v7 apps.

## When Not To Use
- Inside Next.js apps. Next.js has its own App Router, so never combine the two.
- When you need a mature RSC implementation (React Router RSC APIs are still `unstable_`). Use Next.js.
- Tiny single-page widgets without routing.

## Core Principles
1. **Pick the lowest mode that meets your needs**: declarative < data < framework.
2. **Load data in route loaders, in parallel**, not in component effects.
3. **Mutate with actions**, and let React Router revalidate loaders automatically.
4. **Use generated route types** (`./+types/<route>`) for params, loader data and actions.
5. **Middleware for cross-cutting concerns** (auth, logging, context). In v8 it's always enabled, and `context` is a `RouterContextProvider`.
6. **Import from `react-router`** (DOM-specific bits from `react-router/dom`). `react-router-dom` was removed in v8.

## Best Practices
- Framework mode: define routes in `app/routes.ts` (config) or with `@react-router/fs-routes`. Keep route modules thin and call a data layer.
- Throw `redirect()` or `data(..., { status: 404 })` from loaders. Handle them in `ErrorBoundary` route exports with `isRouteErrorResponse`.
- Use `useFetcher` for non-navigation mutations (like buttons, inline edits), and `fetcher.Form` for progressive enhancement.
- Optimistic UI: read `fetcher.formData` or `useNavigation().formData` while pending.
- `<Link prefetch="intent">` for hover or focus preloading.
- `clientLoader`/`clientAction` for client-only data (SPA mode, or client caches). Use `HydrateFallback` for the initial SPA load.
- Validate `params` and `formData` with Zod in loaders and actions.
- Split route modules (on by default in v8) keeps `clientLoader`/`clientAction` code out of the component chunk.

## Implementation Guidance
**Mode chooser**

| Need | Mode |
|---|---|
| URL → component mapping only | Declarative (`<BrowserRouter><Routes>`) |
| SPA with loaders/actions, pending UI, no build plugin | Data (`createBrowserRouter` + `RouterProvider` from `react-router/dom`) |
| Typegen, file routes, SSR/SPA/prerender, middleware, adapters | Framework (`@react-router/dev` Vite plugin) |

**v8 requirements**: Node ≥ 22.22, React/React DOM ≥ 19.2.7, Vite ≥ 7 (framework mode).

**Framework route module (typed)**
```tsx
// app/routes.ts
import { type RouteConfig, route, index, layout } from "@react-router/dev/routes";
export default [
  index("routes/home.tsx"),
  layout("routes/dashboard/layout.tsx", [route("projects/:projectId", "routes/dashboard/project.tsx")]),
] satisfies RouteConfig;

// app/routes/dashboard/project.tsx
import type { Route } from "./+types/project";
import { data, redirect, Form, useNavigation } from "react-router";
import { userContext } from "~/context";

export async function loader({ params, context }: Route.LoaderArgs) {
  const user = context.get(userContext);                 // set by middleware
  const project = await getProject(user.id, params.projectId);
  if (!project) throw data("Not found", { status: 404 });
  return { project };
}

export async function action({ request, params }: Route.ActionArgs) {
  const form = await request.formData();
  const name = String(form.get("name") ?? "").trim();
  if (!name) return data({ error: "Name is required" }, { status: 400 });
  await renameProject(params.projectId, name);
  return redirect(`/projects/${params.projectId}`);
}

export function meta({ loaderData }: Route.MetaArgs) {           // v8: loaderData, not data
  return [{ title: loaderData?.project.name ?? "Project" }];
}

export default function Project({ loaderData, actionData }: Route.ComponentProps) {
  const nav = useNavigation();
  return (
    <Form method="post">
      <label htmlFor="name">Name</label>
      <input id="name" name="name" defaultValue={loaderData.project.name} aria-describedby="name-err" />
      <p id="name-err" role="alert">{actionData?.error}</p>
      <button disabled={nav.state === "submitting"}>Save</button>
    </Form>
  );
}
```

**Middleware (always on in v8)**
```ts
// app/context.ts
import { createContext } from "react-router";
export const userContext = createContext<User>();

// app/routes/dashboard/layout.tsx
import type { Route } from "./+types/layout";
export const middleware: Route.MiddlewareFunction[] = [
  async ({ request, context }) => {
    const user = await getUserFromSession(request);
    if (!user) throw redirect("/login");
    context.set(userContext, user);
  },
];
```
Server middleware `next()` returns a `Response` (you can set headers after it). `clientMiddleware` runs on client navigations.

**Config (SPA vs SSR)**
```ts
// react-router.config.ts
import type { Config } from "@react-router/dev/config";
export default { ssr: false /* SPA */, prerender: ["/", "/pricing"] } satisfies Config;
```

## Recommended Workflow
1. Choose the mode (table). For new Vite SPAs, data mode or framework `ssr: false`.
2. Define the route tree with nested layouts.
3. Write loaders (parallel data) and actions (validated mutations) per route.
4. Add middleware for auth and context. Add `ErrorBoundary` exports per route.
5. Add pending UI (`useNavigation`, fetchers) and prefetching.
6. Run typegen (automatic in dev/build) and `tsc`.
7. For upgrades: move to the latest v7, enable the `v8_*` future flags one at a time, remove `react-router-dom`, replace `data` with `loaderData` in `meta`/`useMatches`, then install v8.

## Patterns
- **Parallel loader data**: `const [a, b] = await Promise.all([...])`, or return promises and render them with `<Await>` inside `<Suspense>` for streaming (framework SSR).
- **Resource routes**: a route module with only `loader`/`action` returning `Response` (CSV export, webhooks).
- **Fetcher inline mutation**: `<fetcher.Form method="post" action="/api/like">`.
- **Typed links**: the `href("/projects/:projectId", { projectId })` utility.
- **Pairing with TanStack Query**: loaders call `queryClient.ensureQueryData(options)`, and components use `useSuspenseQuery(options)` for a client cache plus loader preloading.

## Anti-Patterns
- **Fetching in `useEffect` inside route components**: waterfalls, and no revalidation. Fix: loaders.
- **Importing from `react-router-dom` in v8**: the package was removed. Fix: `react-router` / `react-router/dom`.
- **Using `data` in `meta` or `useMatches`**: removed in v8. Fix: `loaderData`.
- **Manually refetching after mutations**: duplicates revalidation. Fix: actions + automatic revalidation, or `shouldRevalidate` to tune.
- **Hand-writing param types**: they drift from routes. Fix: `Route.*` generated types.
- **Secrets in `clientLoader`**: shipped to the browser. Fix: server `loader`, or an API.
- **Mixing React Router into a Next.js app**: two routers fight. Fix: use Next.js routing.

## Accessibility
- `<Form>` works without JS (progressive enhancement) in SSR framework mode.
- Manage focus on navigation: focus the main heading or `<main>` after route changes, and announce page titles (use `meta` titles plus a live region or focus move).
- Pending states: `aria-busy` on the outlet region, and disabled submit buttons with visible text.
- Use `<ScrollRestoration />` in framework mode for expected scroll behaviour.

## Responsive Design
- Nested layouts express responsive shells (sidebar layouts). Keep layout switching in CSS.
- `prefetch="intent"` has no hover on touch devices. Consider `prefetch="viewport"` for key mobile links (watch data costs).

## Performance
- Route-based code splitting is automatic in framework mode. Split route modules separate client loader code.
- Parallel loaders remove waterfalls. Use `<Await>` streaming for slow, non-critical data.
- Prerender static routes (`prerender`) for fast LCP. SPA mode has an empty initial HTML except `HydrateFallback`.

## Security
- Loaders and actions are server endpoints in SSR mode. Authenticate in middleware and authorize per resource.
- v7.12+ added CSRF protection enhancements for actions. Keep `react-router` patched (RSC-related CVEs in Dec 2025 affected RSC users).
- Validate `request.formData()` and `params`. Never trust hidden inputs.
- Set security headers in server middleware (`response.headers.set(...)` after `next()`).

## Testing
- Unit test loaders and actions as functions with `new Request(...)` and mocked context.
- Component tests with `createRoutesStub` (from `react-router`) to render routes with stubbed loaders and actions.
- Playwright for navigation, pending UI, progressive enhancement and error boundaries.

## Tooling
- `react-router` 8.x, `@react-router/dev`, adapters (`@react-router/node`, `@react-router/serve`, Cloudflare via `@cloudflare/vite-plugin`).
- `@react-router/fs-routes` for file-based route config.
- Typegen (automatic in `react-router dev/build`, or `react-router typegen`).
- Deprecated: `react-router-dom` (removed in v8), Remix v2 packages (migrate to React Router), `json()`/`defer()` helpers (return plain objects or `data()`).

## Framework Notes
### React (Vite SPA)
- The primary use case in this stack. Data mode: `createBrowserRouter([...])` + `<RouterProvider router={router} />` from `react-router/dom`. Framework mode with `ssr: false` adds typegen and file routes while still producing a static SPA.
- Pair with TanStack Query for caching, using loaders to prefetch (`ensureQueryData`).

### Next.js App Router
- Don't use React Router inside Next.js. Concepts map as follows: loader → async Server Component or data fetch; action → Server Action; `ErrorBoundary` export → `error.tsx`; `HydrateFallback`/pending → `loading.tsx`; middleware → `proxy.ts` (Next.js 16) plus layout-level auth checks; `useSearchParams` → `next/navigation` `useSearchParams` or nuqs.
- Choose Next.js when you want RSC, integrated image and font optimization, and Vercel-first caching. Choose React Router framework mode when you want a Vite-based, adapter-agnostic, loader/action model without RSC.

## AI Agent Guidance
- Check the `react-router` version. For v8, import from `react-router`, use `loaderData` in `meta`, and don't add `future.v8_*` flags (they're removed). For v7 projects, don't use v8-only assumptions.
- Detect the mode (presence of `react-router.config.ts` and `app/routes.ts` = framework).
- Always use generated `Route.*` types in framework mode, and validate inputs in actions.
- Verify: `react-router typegen && tsc` passes, navigation pending states work, errors render the route `ErrorBoundary`, and there are no `react-router-dom` imports.

## Examples
```tsx
// Data mode SPA (Vite)
import { createBrowserRouter } from "react-router";
import { RouterProvider } from "react-router/dom";
const router = createBrowserRouter([
  {
    path: "/", Component: RootLayout, ErrorBoundary: RootError,
    children: [
      { index: true, Component: Home },
      { path: "projects/:id", loader: ({ params }) => queryClient.ensureQueryData(projectQuery(params.id!)), Component: ProjectPage },
    ],
  },
]);
createRoot(document.getElementById("root")!).render(<RouterProvider router={router} />);
```

## Related Skills
- [vite-react-spa](../vite-react-spa/Skill.md): SPA project setup
- [tanstack-router-and-start](../tanstack-router-and-start/Skill.md): alternative type-safe router
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md): Next.js equivalent concepts
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md): cache pairing with loaders
- [accessible-spa-routing](../accessible-spa-routing/Skill.md): focus and announcements on navigation
- [progressive-enhancement](../progressive-enhancement/Skill.md): Form without JS

## Sources
- [React Router docs: Modes / Framework](https://reactrouter.com/start/modes) (Official): mode selection, route modules
- [React Router docs: Middleware](https://reactrouter.com/how-to/middleware) (Official): middleware, createContext, next() contract
- [React Router docs: Upgrading from v7](https://reactrouter.com/upgrading/v7) (Official): v8 requirements, flags, removals
- [React Router CHANGELOG](https://github.com/remix-run/react-router/blob/main/CHANGELOG.md) (Open Source): 8.3.1 (Aug 27 2026), stable middleware (7.9), split route modules default, RSC unstable
- [Critical Security Vulnerability in RSC](https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components) (Official): React Router listed among affected RSC frameworks

## License / Usage Notes
React Router is MIT. Docs are summarized. Code is original. Some API details (e.g. `createRoutesStub`, `href`) should be confirmed against the installed 8.x docs.

## Quality Tier
B: official and version-verified, but it's secondary to Next.js for this stack's scope, and a few helper APIs weren't re-verified for v8.

## Status
Active

## Last Verified
2026-09-15
