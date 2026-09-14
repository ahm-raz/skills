# Next.js Server Component Patterns

## Summary
In the App Router, layouts and pages are React Server Components (RSC) that run only on the server, can access databases and secrets, and ship zero component JavaScript. Client Components (`'use client'`) add interactivity. This skill covers where to draw the boundary, how to pass data and Server Components across it (serializable props, `children` slots, promises + `use()`), context providers, third-party wrappers, environment poisoning protection, and how these patterns interact with Cache Components in Next.js 16.

## Category
Next.js

## Subcategories
React Server Components, client boundaries, composition, serialization, server-only, context providers, bundle size

## Problem It Solves
Oversized client bundles from `'use client'` placed too high, leaked secrets or full DB records serialized to the browser, "functions cannot be passed to Client Components" errors, context used in Server Components, and third-party libraries that crash when rendered on the server.

## When To Use
- Designing component trees for any App Router route.
- Integrating interactive widgets (search, forms, charts) into server-rendered pages.
- Adding global providers (theme, query client, auth context).
- Reviewing code for boundary placement and data exposure.

## When Not To Use
- Pages Router code (no RSC).
- Fully client-driven SPA sections where every component is interactive — a `'use client'` page is acceptable there (it can also make navigations instant).
- Mutation mechanics (see [nextjs-server-actions](../nextjs-server-actions/Skill.md)).

## Core Principles
1. **Server by default, client by exception.** Add `'use client'` only where state, effects, event handlers, browser APIs, or client-only hooks are needed.
2. **`'use client'` marks a module-graph boundary.** Everything a client module imports is bundled for the client; Server Components passed as `children`/props are not.
3. **Props crossing the boundary must be serializable** (primitives, plain objects, arrays, Date, Map, Set, promises, JSX, Server Actions). Not functions or class instances.
4. **Send the minimum.** Anything passed to a Client Component is visible in the RSC payload.
5. **Server-only code must be marked.** `import 'server-only'` turns accidental client imports into build errors.

## Best Practices
- Push `'use client'` to leaves: a static `Layout` renders `<Logo />` (server) and `<Search />` (client).
- Use the **children slot** to nest server-rendered content inside client wrappers (`<Modal><Cart /></Modal>`).
- Render providers as deep as possible — wrap `{children}` inside `<body>`, not `<html>`.
- Pass **promises** (not awaited data) from Server to Client Components and read them with React `use()` inside `<Suspense>` to stream.
- Wrap client-only third-party components in a tiny `'use client'` re-export file.
- Shape DTOs on the server: return `{ id, name }`, not the ORM row.
- Keep `process.env` secret reads inside `server-only` modules (the Data Access Layer).
- Use `client-only` for modules touching `window`/`localStorage`.
- Library authors: put `'use client'` at client entry points and make sure the bundler preserves it.

## Implementation Guidance

### Decision table
| Need | Component type |
|---|---|
| Fetch data, access DB/secrets | Server |
| Large dependencies for transforming data to markup (markdown, syntax highlight) | Server |
| `useState`, `useEffect`, event handlers | Client |
| Browser APIs (`window`, `localStorage`, geolocation) | Client |
| React context consumers/providers | Client |
| Static markup | Server |
| Reads `useSearchParams`/`usePathname` | Client (inside `<Suspense>` under Cache Components) |

### Boundary placement
```tsx
// app/layout.tsx (Server)
import Logo from './_ui/logo'          // server
import Search from './_ui/search'      // 'use client'
export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en">
      <body>
        <nav><Logo /><Search /></nav>
        <main>{children}</main>
      </body>
    </html>
  )
}
```

### Interleaving via children
```tsx
// app/_ui/collapsible.tsx
'use client'
import { useState } from 'react'
export function Collapsible({ title, children }: { title: string; children: React.ReactNode }) {
  const [open, setOpen] = useState(false)
  return (
    <section>
      <button aria-expanded={open} onClick={() => setOpen(!open)}>{title}</button>
      {open && children}
    </section>
  )
}

// app/orders/page.tsx (Server)
import { Collapsible } from '@/app/_ui/collapsible'
import { OrderHistory } from './_components/order-history' // async Server Component
export default function Page() {
  return <Collapsible title="History"><OrderHistory /></Collapsible>
}
```

### Streaming a promise to the client
```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react'
import { StatsChart } from './_components/stats-chart'
import { getStats } from '@/lib/dal/stats'

export default function Page() {
  const statsPromise = getStats() // not awaited
  return (
    <Suspense fallback={<p>Loading chart…</p>}>
      <StatsChart statsPromise={statsPromise} />
    </Suspense>
  )
}

// stats-chart.tsx
'use client'
import { use } from 'react'
export function StatsChart({ statsPromise }: { statsPromise: Promise<{ revenue: number }> }) {
  const stats = use(statsPromise)
  return <output>{stats.revenue}</output>
}
```

### Environment poisoning guard
```ts
// lib/dal/users.ts
import 'server-only'
export async function getUserDTO(id: string) {
  const row = await db.user.findUnique({ where: { id } })
  return row ? { id: row.id, name: row.name } : null
}
```

### Third-party client-only component
```tsx
// app/_ui/carousel.tsx
'use client'
export { Carousel as default } from 'acme-carousel'
```

## Recommended Workflow
1. Start every new component as a Server Component.
2. Identify interactive islands; extract them into `'use client'` files.
3. Fetch data in the nearest Server Component that needs it (fetch is memoized; wrap ORM calls in `React.cache`).
4. Pass minimal serializable props or a promise to client islands.
5. Add `server-only` to data/secret modules.
6. Run the bundle analyzer (`next experimental-analyze`) to confirm heavy libs stayed server-side.

## Patterns
- **Server shell + client islands** (most pages).
- **Promise-through-context:** create the promise in a Server Component, store in a client context provider, read with `use()` in any descendant.
- **Server-rendered heavy transforms:** run `shiki`/markdown on the server; ship HTML.
- **Client page for fully interactive screens:** `'use client'` at page level gives SPA-like instant navigation but loses server data locality — use deliberately.

## Anti-Patterns
- **`'use client'` in root layout** — entire app becomes client JS. Fix: move providers into `app/providers.tsx` and wrap `{children}` only.
- **Passing an ORM entity to a client prop** — leaks every column. Fix: map to a DTO; optionally enable `experimental.taint` and taint sensitive objects.
- **Passing event handler functions from Server to Client** — serialization error. Fix: define the handler in the client component or pass a Server Action.
- **`useContext` in a Server Component** — unsupported. Fix: read request-scoped data with `React.cache` helpers or root params.
- **Importing a server module into a client file** "because it works in dev" — non-`NEXT_PUBLIC_` env vars become empty strings, secrets may leak. Fix: `server-only`.
- **Doing expensive rendering (chart/markdown) in client** — bundle bloat. Fix: server render.

## Accessibility
- Server-rendered HTML is available before hydration — ensure interactive client islands are progressively enhanced (e.g., forms with Server Actions work pre-hydration).
- Client islands that toggle content must expose state (`aria-expanded`, `aria-controls`).
- Streaming promise-based components need meaningful fallbacks that don't cause focus jumps.

## Responsive Design
- Keep responsive behavior in CSS so server-rendered markup is identical for all devices (cacheable shell).
- Avoid reading user-agent headers on the server to pick layouts; it forces request-time rendering.

## Performance
- Server Components reduce JS shipped and improve FCP; Suspense boundaries split hydration into smaller tasks (better INP).
- A Server Component dynamically imported via `next/dynamic` only lazy-loads its client children.
- Excessive tiny client islands each hydrate separately; group tightly coupled interactivity.

## Security
- RSC payload is public: never pass secrets, tokens, or unfiltered records as props.
- `server-only` + Data Access Layer + DTOs are the primary defense; taint APIs (`experimental_taintObjectReference`, `experimental_taintUniqueValue` with `experimental.taint: true`) are a secondary net.
- Keep Next.js/React patched: the December 2025 RSC Flight protocol RCE (CVE-2025-55182 / CVE-2025-66478) affected App Router apps on 15.x/16.0 until patched (16.0.7+); rotate secrets if exposed.

## Testing
- Vitest/Jest can render synchronous Server Components and Client Components; async Server Components need E2E (Playwright).
- Add a lint/CI check that `lib/dal/**` files import `server-only`.
- Snapshot the props of client islands in tests to catch data over-exposure.

## Tooling
- `server-only` / `client-only` (handled internally by Next.js; install only if lint requires).
- `next experimental-analyze` (Turbopack bundle analyzer, 16.1+), `@next/bundle-analyzer` (webpack).
- React DevTools (component tree, Suspense panel); Next.js DevTools MCP.
- React Compiler (`reactCompiler: true`, stable in 16) reduces manual memoization in client islands.

## Framework Notes
- RSC semantics come from React 19; Next.js adds file conventions, caching, and bundling.
- Under Cache Components, Server Components that read runtime data must sit inside `<Suspense>`; cached components (`'use cache'`) can accept `children`/Server Actions as pass-through props without affecting their cache key.
- UI state is preserved across navigations with React `<Activity>` when Cache Components is enabled — client state no longer resets on unmount-by-navigation.

## AI Agent Guidance
- Default to Server Components; justify each `'use client'` with a concrete hook/event/browser API.
- Never pass DB rows to client props; create DTOs.
- Add `import 'server-only'` to any file reading secrets or the database.
- Before done: check the bundle analyzer or build output for unexpected client dependencies; confirm no "Functions cannot be passed" or "server-only" build errors; verify fallbacks exist around `use()` consumers.

## Examples
```tsx
// app/providers.tsx
'use client'
import { ThemeProvider } from 'next-themes'
export function Providers({ children }: { children: React.ReactNode }) {
  return <ThemeProvider attribute="class">{children}</ThemeProvider>
}

// app/layout.tsx
import { Providers } from './providers'
export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body><Providers>{children}</Providers></body>
    </html>
  )
}
```

## Related Skills
- [react-server-components](../react-server-components/Skill.md) — React-level RSC model
- [nextjs-data-fetching-patterns](../nextjs-data-fetching-patterns/Skill.md) — fetching inside Server Components
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — `use cache` interleaving
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — env var exposure rules
- [react-context-patterns](../react-context-patterns/Skill.md) — providers
- [bundle-optimization](../bundle-optimization/Skill.md) — measuring client JS
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — ORM clients and connection handling inside Server Components
- [browser-apis-in-react](../browser-apis-in-react/Skill.md) — safe browser API use in client islands

## Sources
- [Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components) — Official — boundaries, interleaving, providers, server-only
- [Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DTOs, taint, auditing
- [Fetching Data](https://nextjs.org/docs/app/getting-started/fetching-data) — Official — promises + use()
- [Optimizing package bundling](https://nextjs.org/docs/app/guides/package-bundling) — Official — server-side heavy work, analyzer
- [Security Advisory CVE-2025-66478](https://nextjs.org/blog/CVE-2025-66478) — Official — RSC protocol RCE and patched versions
- [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) — Community/Open Source — react-best-practices rule categories (waterfalls, bundle size, server performance)

## License / Usage Notes
Next.js and React are MIT licensed; vercel-labs/agent-skills is open source. Content is summarized and rewritten, not copied.

## Quality Tier
A — Current official guidance plus security advisory context; patterns are well-established.

## Status
Active

## Last Verified
2026-09-15
