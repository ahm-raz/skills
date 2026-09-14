# Vite React SPA

## Summary
Building React applications without Next.js: a Vite (v8, Rolldown-powered) single-page app with TypeScript, a client router (React Router in SPA mode or TanStack Router), client data fetching, `VITE_` env handling, and static deployment with an `index.html` rewrite. Includes a decision table for when a Vite SPA beats Next.js and when it does not.

## Category
React

## Subcategories
Vite, SPA architecture, client-side routing, environment variables, static hosting, build configuration, migration from CRA

## Problem It Solves
Teams default to Next.js even for authenticated dashboards, embedded widgets, and internal tools where SSR adds servers, cost, and complexity without benefit; others still run Create React App or old Vite configs. This skill provides a modern, minimal SPA baseline and clear criteria for choosing it.

## When To Use
- Authenticated apps behind login where SEO is irrelevant (admin panels, B2B dashboards).
- Apps deployed to static hosting/CDN or embedded in another platform (Electron, Tauri, browser extension, iframe).
- A separate backend already exists (REST/GraphQL in another language).
- Migrating off Create React App.

## When Not To Use
- Public, SEO- or share-preview-critical pages (marketing, e-commerce catalog, blog): prefer Next.js ([react-nextjs-project-setup](../react-nextjs-project-setup/Skill.md)).
- You need server mutations, streaming SSR, or RSC; prefer Next.js or React Router framework mode ([react-router-framework-mode](../react-router-framework-mode/Skill.md)).
- LCP on slow mobile networks is a primary KPI for anonymous users.

## Core Principles
1. SPA means the server sends a shell; everything else is client JS. Budget bundle size from day one.
2. Routes are code-split boundaries: lazy-load each route.
3. Anything in the client bundle is public, including every `VITE_*` variable.
4. Data fetching belongs in route loaders or a query cache, not scattered `useEffect`s.
5. URLs are the source of truth for navigational state (filters, tabs, pagination).
6. The host must rewrite unknown paths to `index.html`, while real 404s for assets still return 404.

## Best Practices
- Scaffold: `npm create vite@latest my-app -- --template react-ts` (Vite 8 requires Node 20.19+ or 22.12+).
- Use `@vitejs/plugin-react` (Babel/Oxc-based) and add React Compiler via its Babel plugin if desired.
- Choose one router: React Router (v7/v8) in declarative/data mode or framework mode with `ssr: false`; or TanStack Router for type-safe search params and file-based routes.
- Pair with TanStack Query for server state; use route loaders to prefetch (`queryClient.ensureQueryData`).
- Type env vars in `src/vite-env.d.ts` via `ImportMetaEnv`; validate at startup.
- Use `import.meta.env.DEV/PROD/MODE` for environment branching; use `--mode staging` for staging builds (mode is separate from `NODE_ENV`).
- Configure `resolve.alias` or `vite-tsconfig-paths` for `@/`.
- Use Vitest (shares Vite config) and Playwright against `vite preview`.
- Set long-lived immutable caching for hashed `assets/*`, `no-cache` for `index.html`.
- Add an error boundary at the router root and a real 404 route.

## Implementation Guidance

### Decision table: Vite SPA vs Next.js vs React Router framework
| Need | Vite SPA | Next.js (App Router) | React Router framework (SSR) |
|---|---|---|---|
| SEO/social previews for public pages | Poor | Best | Good |
| Static hosting only, no server | Best | `output: 'export'` (no server features) | `ssr: false` SPA mode |
| Behind-auth dashboard | Great | Good | Good |
| Server mutations / RSC | No | Yes | Actions (no RSC by default) |
| Infra and mental-model complexity | Lowest | Highest | Medium |
| Embed in Electron/extension/iframe | Best | Awkward | Possible |
| Type-safe search params | TanStack Router | nuqs | nuqs |

### Router choice
| Router | Pick when |
|---|---|
| React Router (data/declarative mode) | Familiar API, broad ecosystem, easy upgrade path to framework mode |
| React Router framework mode `ssr: false` | Want file routes, `clientLoader`/`clientAction`, pre-rendered `index.html` with `HydrateFallback` |
| TanStack Router | Want end-to-end type-safe routes/search params, built-in loaders + cache integration |

### vite.config.ts
```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  server: {
    // Dev-only proxy avoids CORS and keeps API origin out of client code
    proxy: { '/api': { target: 'http://localhost:8080', changeOrigin: true } },
  },
  build: { sourcemap: true },
})
```

### Typed env
```ts
// src/vite-env.d.ts
/// <reference types="vite/client" />
interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string
  readonly VITE_SENTRY_DSN?: string
}
interface ImportMeta { readonly env: ImportMetaEnv }
```
Load order: `.env`, `.env.local`, `.env.[mode]`, `.env.[mode].local` (mode-specific wins). Only `VITE_`-prefixed keys reach client code.

### Router + query setup (React Router data mode)
```tsx
// src/main.tsx
import { StrictMode, lazy } from 'react'
import { createRoot } from 'react-dom/client'
import { createBrowserRouter, RouterProvider } from 'react-router'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RootLayout } from './routes/root-layout'
import { RouteError } from './routes/route-error'

const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000 } } })

const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    errorElement: <RouteError />,
    children: [
      { index: true, lazy: () => import('./routes/home').then(m => ({ Component: m.default })) },
      {
        path: 'projects/:id',
        lazy: async () => {
          const m = await import('./routes/project')
          return { Component: m.default, loader: m.loader(queryClient) }
        },
      },
      { path: '*', lazy: () => import('./routes/not-found').then(m => ({ Component: m.default })) },
    ],
  },
])

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>,
)
```

### Deployment rewrites
| Host | Config |
|---|---|
| Netlify / Cloudflare Pages | `_redirects`: `/*  /index.html  200` |
| Vercel | `vercel.json`: `{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }` |
| Nginx | `try_files $uri $uri/ /index.html;` |
| S3 + CloudFront | Custom error response 403/404 -> `/index.html` 200 (beware masking real asset 404s) |

If serving under a sub-path, set `base: '/app/'` in Vite config and `basename` in the router.

## Recommended Workflow
1. Confirm SPA fits (decision table); document why in the README.
2. Scaffold with `react-ts` template; add alias, Tailwind, ESLint/Biome, strict tsconfig.
3. Pick router + TanStack Query; create root layout, error element, 404 route.
4. Lazy-load every route; add loaders that prefetch queries.
5. Type and validate env; set up dev proxy for the API.
6. Add auth handling (httpOnly cookie session via backend preferred) and route guards in loaders.
7. Add Vitest, MSW, Playwright; run e2e against `vite build && vite preview`.
8. Configure host rewrites and caching headers; verify deep-link reload and asset 404s in staging.

## Patterns
- **Loader prefetch + query cache**: `loader = (qc) => ({ params }) => qc.ensureQueryData(projectQuery(params.id))`; component uses `useSuspenseQuery(projectQuery(id))`.
- **Auth guard in loader**: throw `redirect('/login?next=...')` if session query fails.
- **Runtime config file**: fetch `/config.json` at boot for values that must change without rebuild (one artifact, many environments).
- **Chunk-load recovery**: catch `vite:preloadError` and reload once after a deploy invalidates old chunks.
- **Pre-rendered shell**: React Router framework `ssr: false` generates a real `index.html` with `HydrateFallback`, improving first paint.

## Anti-Patterns
- **Create React App / react-scripts.** Deprecated, slow, unmaintained. Fix: migrate to Vite (`VITE_` rename of `REACT_APP_` vars, `index.html` moves to root).
- **`process.env.REACT_APP_*` in Vite.** Undefined. Fix: `import.meta.env.VITE_*`.
- **Secrets in `VITE_*`.** Shipped to every browser. Fix: keep secrets on the backend; proxy requests.
- **Fetching in `useEffect` per component.** Waterfalls, race conditions, no caching. Fix: loaders + TanStack Query.
- **One giant bundle.** Slow first load. Fix: route-level `lazy`, analyze with `rollup-plugin-visualizer`/Vite bundle analysis.
- **Rewriting everything, including `/assets/*`, to `index.html`.** Returns HTML for missing JS and breaks error detection. Fix: rewrite only non-file routes.
- **Filters in `useState` only.** Lost on reload/share. Fix: search params ([react-url-state-nuqs](../react-url-state-nuqs/Skill.md)).
- **Tokens in `localStorage`.** XSS-exfiltratable. Fix: httpOnly cookies set by the backend ([frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md)).

## Accessibility
- Client routing does not announce page changes; move focus to the main heading or announce the new title on navigation ([accessible-spa-routing](../accessible-spa-routing/Skill.md)).
- Update `document.title` per route (React 19 supports `<title>` in components).
- Restore scroll position on back/forward (`<ScrollRestoration />` in React Router).
- Loading fallbacks must be perceivable (`aria-busy`, visually hidden status text).

## Responsive Design
- Same CSS strategy as any React app; Tailwind v4 via `@tailwindcss/vite`.
- Ensure `<meta name="viewport" content="width=device-width, initial-scale=1">` is in `index.html`.
- Prefer route-level code splitting over device-sniffing bundles.

## Performance
- Vite 8 builds with Rolldown: fast builds, good chunking defaults; still set a bundle budget.
- Preload critical route chunks on link hover/intent (TanStack Router `preload: 'intent'`, React Router `<Link prefetch>` in framework mode).
- Serve hashed assets with `Cache-Control: public, max-age=31536000, immutable`.
- Optimize LCP: inline critical CSS is limited in SPAs, so keep the shell light and render a skeleton immediately; consider pre-rendering the shell.
- Use `React.lazy` for heavy widgets (charts, editors) within routes.

## Security
- Assume all client code and `VITE_*` values are public.
- Configure CSP on the host (no inline scripts; Vite production output is CSP-friendly) — see [content-security-policy](../content-security-policy/Skill.md).
- Validate redirects (`?next=`) against an allowlist of internal paths to avoid open redirects.
- Avoid `dangerouslySetInnerHTML` with API content unless sanitized (DOMPurify).
- Lock dependencies; audit Vite plugins (they run with full Node privileges at build time).

## Testing
- Vitest with `environment: 'jsdom'` or `happy-dom`, sharing `vite.config.ts`.
- MSW for API mocking in tests and local dev ([api-mocking-msw](../api-mocking-msw/Skill.md)).
- Playwright e2e against `vite preview`, including a deep-link reload test and a 404 test.
- Test loaders/guards as plain functions.

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| Vite 8.x (Rolldown) | Active | Node 20.19+/22.12+ |
| `@vitejs/plugin-react` | Active | React Fast Refresh |
| React Router v7/v8 | Active (8.3 latest docs) | Data mode or framework `ssr: false` |
| TanStack Router v1 | Active | Type-safe routing |
| TanStack Query v5 | Active | Server state |
| Vitest | Active | Unit tests |
| Create React App | Deprecated | Migrate |
| `vite-plugin-pwa` | Community | Offline support if needed |

## Framework Notes
- **React (Vite SPA)**: This skill. No RSC, no Server Actions; `useActionState` still works with client async functions.
- **Next.js**: Can emulate SPA via `output: 'export'` (no server features) or `next/dynamic` with `ssr: false` for browser-only parts. Choose Next when public-page SEO or server mutations matter; Next also supports incremental migration from Vite (official guide).

## AI Agent Guidance
- Do: check `package.json` for `vite` vs `next` before choosing APIs (`import.meta.env` vs `process.env`).
- Do: lazy-load new routes and add them to the router config with an error element.
- Do: put new env keys in `vite-env.d.ts` and `.env.example`.
- Don't: introduce `react-scripts`, `REACT_APP_*`, or `process.env` in client code.
- Don't: add fetch-in-effect data loading when TanStack Query/loaders exist.
- Before done: `vite build` succeeds with no oversized-chunk warnings you introduced; deep-link reload works in `vite preview`; tests pass.

## Examples
```tsx
// src/routes/project.tsx — loader prefetch + suspense query
import { queryOptions, useSuspenseQuery, type QueryClient } from '@tanstack/react-query'
import { useParams, type LoaderFunctionArgs } from 'react-router'

const projectQuery = (id: string) =>
  queryOptions({
    queryKey: ['project', id],
    queryFn: async ({ signal }) => {
      const res = await fetch(`${import.meta.env.VITE_API_BASE_URL}/projects/${id}`, { signal, credentials: 'include' })
      if (!res.ok) throw new Response('Not found', { status: res.status })
      return (await res.json()) as { id: string; name: string }
    },
  })

export const loader = (qc: QueryClient) => ({ params }: LoaderFunctionArgs) =>
  qc.ensureQueryData(projectQuery(params.id!))

export default function ProjectPage() {
  const { id } = useParams()
  const { data } = useSuspenseQuery(projectQuery(id!))
  return <h1>{data.name}</h1>
}
```

```ts
// src/chunk-reload.ts — recover once from stale chunks after deploy
window.addEventListener('vite:preloadError', (event) => {
  if (!sessionStorage.getItem('chunk-reloaded')) {
    sessionStorage.setItem('chunk-reloaded', '1')
    event.preventDefault()
    window.location.reload()
  }
})
```

## Related Skills
- [react-nextjs-project-setup](../react-nextjs-project-setup/Skill.md) — the Next.js alternative
- [react-router-framework-mode](../react-router-framework-mode/Skill.md) — SSR or SPA mode with React Router
- [tanstack-router-and-start](../tanstack-router-and-start/Skill.md) — type-safe router option
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — server state in SPAs
- [frontend-build-tooling](../frontend-build-tooling/Skill.md) — bundler internals
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — route chunking
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — focus and announcements on navigation

## Sources
- [Vite Getting Started](https://vite.dev/guide/) — Official — Vite 8.3, Node requirements, react-ts template, Rolldown
- [Vite Env Variables and Modes](https://vite.dev/guide/env-and-mode) — Official — VITE_ prefix, load order, modes, ImportMetaEnv
- [React Router SPA mode](https://reactrouter.com/how-to/spa) — Official — ssr:false, HydrateFallback, clientLoader, rewrites
- [Next.js SPA guide](https://nextjs.org/docs/app/guides/single-page-applications) — Official — Next's SPA capabilities, static export tradeoffs

## License / Usage Notes
Vite, React Router, TanStack libraries are MIT licensed. Content is summarized from official docs with original examples.

## Quality Tier
A — Grounded in current official Vite 8 and React Router docs; hosting/rewrite and chunk-recovery patterns are well-established community practice.

## Status
Active

## Last Verified
2026-09-15
