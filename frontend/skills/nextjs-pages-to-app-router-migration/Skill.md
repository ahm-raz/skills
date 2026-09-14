# Migrating from Pages Router to App Router

## Summary
The `app/` and `pages/` directories can coexist, enabling page-by-page migration. The path: upgrade to Next.js 16 first, create a root layout replacing `_app`/`_document`, move `next/head` to the Metadata API, move each page into `app/` by wrapping its existing component as a Client Component and replacing `getServerSideProps`/`getStaticProps`/`getStaticPaths` with async Server Component data fetching, caching, and `generateStaticParams`, switch routing hooks to `next/navigation`, and replace API Routes with Route Handlers. Target Cache Components for new code; the Pages Router remains supported but receives no new rendering features.

## Category
Next.js

## Subcategories
Incremental migration, _app/_document, next/head, getServerSideProps, getStaticProps, getStaticPaths, ISR, next/router, API routes, i18n config, codemods

## Problem It Solves
Big-bang rewrites that stall, broken styles/providers when mixing routers, confusion mapping data fetching methods, hard navigations between routers, and built-in `i18n` config that doesn't exist in the App Router.

## When To Use
- Existing Pages Router apps adopting Server Components, streaming, Server Actions, or Cache Components.
- Security posture review (mixed-router apps on Windows without Cache Components were affected by an Aug 2026 critical RCE until patched).

## When Not To Use
- Minor version upgrades within the Pages Router (see [nextjs-version-16-upgrade](../nextjs-version-16-upgrade/Skill.md)).
- Migrating from a Vite React SPA (see [vite-react-spa](../vite-react-spa/Skill.md) and the Next.js SPA guide).

## Core Principles
1. **Upgrade the framework before the architecture.** Get to Next.js 16 (Node 20.9+, React 19.2) on the Pages Router first.
2. **Migrate incrementally, route by route;** keep `_app`/`_document` until the last page moves.
3. **First move = behavior-preserving:** wrap the old page component as `'use client'`, fetch data in a Server Component parent.
4. **Then refactor toward server-first:** push `'use client'` down, add Suspense and caching.
5. **Routes must not exist in both routers** at the same path.

## Best Practices
- Migrate low-risk, high-value routes first (marketing, docs), then authenticated sections.
- Prefer migrating whole sections to minimize cross-router hard navigations (links between routers don't prefetch).
- Move providers into `app/providers.tsx` (`'use client'`), rendered inside `<body>`.
- Replace `useRouter().query` with `useSearchParams()` + `useParams()`; `pathname` with `usePathname()`; `asPath`/`isFallback`/`locale` have no equivalent.
- Share components between routers with `next/compat/router` during transition.
- Replace built-in `i18n` config with `[lang]` segments + proxy or next-intl.
- Replace `getLayout` pattern with nested `layout.tsx`.
- Enable Cache Components for new `app/` routes early so you don't migrate twice (from `fetch` cache options to `'use cache'`).
- Run codemods: `npx @next/codemod@canary upgrade latest`, `next-async-request-api`, `middleware-to-proxy`.

## Implementation Guidance

### API mapping
| Pages Router | App Router |
|---|---|
| `pages/_app.tsx`, `pages/_document.tsx` | `app/layout.tsx` (+ `providers.tsx`) |
| `pages/_error.tsx`, `pages/500.tsx` | `error.tsx`, `global-error.tsx` |
| `pages/404.tsx` | `not-found.tsx` (and optional `global-not-found`) |
| `next/head` | `metadata` / `generateMetadata` |
| `getServerSideProps` | async Server Component fetch (uncached by default), `cookies()`/`headers()` |
| `getStaticProps` | `'use cache'` + `cacheLife` (or `fetch` `force-cache` in previous model) |
| `getStaticProps` `revalidate: n` | `cacheLife(profile)` (or `next.revalidate` previously) |
| `getStaticPaths` | `generateStaticParams` |
| `fallback: true/'blocking'` | Default behavior; App Shell + background upgrade (Cache Components) |
| `fallback: false` | `dynamicParams = false` (previous model) / `notFound()` (Cache Components) |
| `pages/api/*` | `app/**/route.ts` Route Handlers (or Server Actions for UI mutations) |
| `next/router` | `next/navigation` (`useRouter`, `usePathname`, `useSearchParams`, `useParams`) |
| Router events | `usePathname` + `useSearchParams` effects |
| `next.config` `i18n` | `app/[lang]` + proxy / next-intl |
| `getLayout` | nested `layout.tsx` |
| `req.cookies`, `req.headers` | `await cookies()`, `await headers()` |
| `middleware.ts` | `proxy.ts` |
| `_document` `beforeInteractive` scripts | `next/script` in root layout |
| AMP | Removed in v16 |

### Step 1: root layout
```tsx
// app/layout.tsx
import type { Metadata } from 'next'
import '@/styles/globals.css'
import { Providers } from './providers'

export const metadata: Metadata = { title: { template: '%s | Acme', default: 'Acme' } }

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en">
      <body><Providers>{children}</Providers></body>
    </html>
  )
}
```

### Step 2: move a gSSP page (behavior-preserving)
```tsx
// BEFORE: pages/dashboard.tsx
export async function getServerSideProps({ req }) {
  const projects = await getProjects(req.cookies.session)
  return { props: { projects } }
}
export default function Dashboard({ projects }) { /* uses useState, useRouter */ }
```
```tsx
// AFTER: app/dashboard/dashboard-client.tsx
'use client'
import { useRouter } from 'next/navigation'
export function DashboardClient({ projects }: { projects: ProjectDTO[] }) { /* same UI */ }

// AFTER: app/dashboard/page.tsx
import { Suspense } from 'react'
import { DashboardClient } from './dashboard-client'
import { getProjectsForCurrentUser } from '@/lib/dal/projects'

export const metadata = { title: 'Dashboard' }

export default function Page() {
  return <Suspense fallback={<p>Loading projects…</p>}><Data /></Suspense>
}
async function Data() {
  const projects = await getProjectsForCurrentUser() // reads cookies inside DAL
  return <DashboardClient projects={projects} />
}
```

### Step 3: gSP + gSPaths → generateStaticParams + cache
```tsx
// app/posts/[id]/page.tsx
import { notFound } from 'next/navigation'
import { cacheLife, cacheTag } from 'next/cache'

export async function generateStaticParams() {
  return (await getPopularPostIds()).map((id) => ({ id }))
}

async function getPost(id: string) {
  'use cache'
  cacheLife('hours')      // was revalidate: 3600
  cacheTag(`post:${id}`)
  return db.post.findUnique({ where: { id } })
}

export default async function Post(props: PageProps<'/posts/[id]'>) {
  const { id } = await props.params
  const post = await getPost(id)
  if (!post) notFound()
  return <article><h1>{post.title}</h1></article>
}
```

### Step 4: API route → Route Handler
```ts
// BEFORE pages/api/hello.ts: export default (req, res) => res.status(200).json({ ok: true })
// AFTER app/api/hello/route.ts
export function GET() {
  return Response.json({ ok: true })
}
```

### Routing hooks
```tsx
'use client'
import { usePathname, useSearchParams, useParams, useRouter } from 'next/navigation'
export function Tabs() {
  const pathname = usePathname()
  const search = useSearchParams()
  const { id } = useParams<{ id: string }>()
  const router = useRouter()
  // router.push(`${pathname}?${new URLSearchParams({ ...Object.fromEntries(search), tab: 'b' })}`)
}
```

## Recommended Workflow
1. Upgrade to latest Next.js 16 on Pages Router; fix breaking changes; ensure tests pass.
2. Add `app/layout.tsx`, providers, global styles; keep `_app`/`_document`.
3. Choose a section; migrate pages one at a time (client wrapper + server data).
4. Replace `next/head`, routing hooks, API routes for that section.
5. Delete the migrated `pages/` files; run E2E.
6. Refactor migrated routes toward Server Components, Suspense, caching.
7. Repeat; finally remove `_app`, `_document`, `pages/`.

## Patterns
- **Strangler by section:** `(marketing)` first, then `(app)`.
- **Client wrapper then shrink:** move non-interactive parts of the wrapper into server components progressively.
- **Compat hooks:** `next/compat/router` for shared components.
- **Parallel run in staging** with Playwright visual regression per migrated route.

## Anti-Patterns
- **Same route in `pages/` and `app/`** — conflict. Fix: delete the old file when moving.
- **Porting `getServerSideProps` verbatim as a helper called in a Client Component** — no server access. Fix: fetch in Server Component.
- **Wrapping the whole app in one `'use client'` layout** to "make it work" — loses RSC benefits permanently. Fix: providers component + leaf clients.
- **Relying on `router.query` during prerender** — undefined. Fix: `params`/`searchParams` props or hooks inside Suspense.
- **Carrying over `fetch(..., { next: { revalidate } })` in a Cache Components app** — segment/fetch options won't express caching. Fix: `'use cache'` + `cacheLife`.
- **Expecting `next.config` `i18n` to work in `app/`** — ignored. Fix: `[lang]` routing.
- **Leaving mixed-router apps unpatched on Windows** — Aug 2026 critical RCE (CVE-2026-75604). Fix: 16.3.3+/15.5.24+.

## Accessibility
- Migration is a chance to fix `<html lang>`, page titles per route (Metadata API), and focus handling on navigation.
- Cross-router navigations are full page loads; ensure skip links and landmarks are consistent between old and new layouts.
- Regression-test with axe on each migrated route.

## Responsive Design
- Keep CSS identical during the behavior-preserving step (global CSS can now be imported in `app/layout.tsx`; Tailwind v3 `content` globs must include `./app/**`; Tailwind v4 auto-detects sources).

## Performance
- Expect initial gains from Server Components only after shrinking client wrappers.
- Cross-router links cause hard navigations — migrate adjacent routes together.
- Replace client data fetching in migrated pages with server fetching/streaming.

## Security
- API Routes → Route Handlers: re-apply auth/validation; don't assume middleware protection carries over identically (proxy matchers skip Server Actions on excluded paths).
- Server Actions introduced during migration need per-action authorization.
- Remove secrets passed via `publicRuntimeConfig` (removed in v16).

## Testing
- Freeze a Playwright E2E suite on the Pages version; run it after each migrated route.
- Visual regression per route (screenshots) to catch CSS/provider differences.
- Unit tests for components continue; async Server Components need E2E.

## Tooling
- `@next/codemod` (`upgrade`, `next-async-request-api`, `middleware-to-proxy`, `new-link`, `next-image-to-legacy-image`).
- Next.js Skills: `next-cache-components-adoption` for post-migration caching.
- `next/compat/router`.

## Framework Notes
- App Router requires Next.js ≥13.4; Cache Components requires 16.
- Pages Router remains supported (security patches, basic features) but Cache Components, root params, Instant Navigations target `app/`.
- React (Vite SPA) → Next.js: follow the official SPA guide (start with `'use client'` pages, then introduce Server Components).

## AI Agent Guidance
- Migrate one route per change set; keep behavior identical first.
- Never leave duplicated routes; always port metadata and hooks.
- Before done: E2E for migrated route passes, no `next/router`/`next/head` imports in `app/`, `next build` passes, and migrated data fetching respects the project's caching model (Cache Components or previous).

## Examples
```tsx
// Shared component during transition
'use client'
import { useRouter as useCompatRouter } from 'next/compat/router'
import { usePathname } from 'next/navigation'
export function ActiveLink({ href, children }: { href: string; children: React.ReactNode }) {
  const pagesRouter = useCompatRouter() // null in app/
  const pathname = pagesRouter ? pagesRouter.asPath : usePathname()
  return <a href={href} aria-current={pathname === href ? 'page' : undefined}>{children}</a>
}
```
(Hooks must be called unconditionally in real code; restructure into two components if linting flags this.)

## Related Skills
- [nextjs-version-16-upgrade](../nextjs-version-16-upgrade/Skill.md) — framework upgrade first
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — target conventions
- [nextjs-data-fetching-patterns](../nextjs-data-fetching-patterns/Skill.md) — replacing gSSP/gSP
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — ISR replacement
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — API routes replacement
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — i18n config replacement
- [visual-regression-testing](../visual-regression-testing/Skill.md) — migration safety net

## Sources
- [App Router migration guide](https://nextjs.org/docs/app/guides/migrating/app-router-migration) — Official — step-by-step, hooks, data fetching mapping, API routes, interop
- [ISR with Cache Components](https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components) — Official — Pages Router mapping (fallback, isFallback)
- [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) — Official — fetch/unstable_cache mapping
- [Upgrading to v16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — removals (AMP, runtime config), codemods
- [August 2026 Security Release](https://nextjs.org/blog/august-2026-security-release) — Official — mixed-router Windows RCE

## License / Usage Notes
Next.js MIT. Summarized; examples original. Note the official migration guide's early sections still reference v13-era upgrade steps; guidance here targets v16.

## Quality Tier
A — Complete mapping validated against current docs; includes version-precise caveats beyond the partially dated official guide.

## Status
Active

## Last Verified
2026-09-15
