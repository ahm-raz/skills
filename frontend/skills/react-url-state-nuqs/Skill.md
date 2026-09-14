# URL State with nuqs

## Summary
Treat URL search params as typed, shareable application state in React and Next.js using nuqs (v2.10): `useQueryState`/`useQueryStates` hooks with parsers, defaults, history and shallow-routing options, URL update rate limiting, and server-side parsing with `createLoader`/`createSearchParamsCache` in the App Router. Covers what belongs in the URL, serialization design, and SSR/RSC integration.

## Category
Next.js

## Subcategories
Search params, URL state, shallow routing, type-safe parsers, server components, filters, pagination, deep linking

## Problem It Solves
Filters, tabs, sort, pagination, and modals kept in `useState` vanish on reload, cannot be shared or bookmarked, break back/forward, and are invisible to Server Components. Hand-rolled `useSearchParams` + `URLSearchParams` + `router.push` code is verbose, stringly typed, and causes excessive navigation and re-renders. nuqs gives a `useState`-like typed API backed by the URL.

## When To Use
- List/table filters, search query, sort, page, page size, selected tab, date ranges, map viewport.
- Any state users may want to share, bookmark, or restore with back/forward.
- State that Server Components need to render (server-side filtering and pagination).

## When Not To Use
- Sensitive data (emails, tokens, PII): URLs are logged, cached, and shared.
- High-frequency ephemeral state (drag position, input keystrokes without debounce, animation state).
- Large objects (URLs have practical length limits, roughly a few thousand characters across browsers/CDNs).
- Server/cache data: use Server Components or TanStack Query ([react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md)).
- Form drafts before submission (local state or form library).

## Core Principles
1. The URL is the single source of truth for navigational/view state; do not mirror it into `useState`.
2. Parse at the boundary with typed parsers and defaults; invalid input falls back to defaults (or throws in strict mode) — never crash on user-edited URLs.
3. Declare parsers once, share between client hooks and server loaders.
4. Default updates are client-only (`shallow: true`) and replace history; opt into `shallow: false` when the server must re-render, and `history: 'push'` when the change is a navigation users expect Back to undo.
5. Keep URLs short and readable: `clearOnDefault` (default true), short `urlKeys`, stable encodings.
6. Rate-limit URL writes for text input (debounce) — browsers throttle `history` API calls.

## Best Practices
- Install `nuqs` and wrap the app with the right adapter: `nuqs/adapters/next/app` in `app/layout.tsx`; `nuqs/adapters/react` for Vite SPAs; `nuqs/adapters/react-router/v7` (or `/v8`), `nuqs/adapters/tanstack-router`.
- Put shared parser definitions in a file imported by both server and client, importing parsers from `nuqs/server` (safe in RSC, no `'use client'` boundary).
- Use `parseAsStringLiteral([...] as const)` for enums (sort, tab), `parseAsInteger.withDefault(1)` for page, `parseAsArrayOf(parseAsString)` or `parseAsNativeArrayOf` for multi-select, `parseAsIsoDate` for dates, `parseAsJson(schema)` sparingly with a Standard Schema validator.
- Use `useQueryStates` for related keys so a single update writes one URL change (e.g., change filter and reset page together).
- Reset pagination when filters change: `setParams({ status, page: null })` (null removes the key).
- For search boxes: update local input immediately, URL with `limitUrlUpdates: debounce(300)`; use `throttle` for sliders.
- When the server renders results, use `shallow: false` with `startTransition` from `useTransition` to show pending UI.
- In Next.js App Router pages, read params server-side with `createLoader(parsers)` and `await loadSearchParams(searchParams)` (searchParams is a Promise in Next 15+/16).
- Use `createSearchParamsCache` when deeply nested Server Components need the parsed values without prop drilling.
- Use `createSerializer(parsers)` to build typed `href`s for `<Link>` (pagination links, "clear filters").
- Test with `NuqsTestingAdapter` (`nuqs/adapters/testing`).

## Implementation Guidance

### What goes where
| State | URL (nuqs) | Local state | Server/cache |
|---|---|---|---|
| Search query, filters, sort, page | Yes | Input draft only | Results |
| Selected tab / view mode | Yes (if shareable) | If purely cosmetic | — |
| Open modal for an entity | Yes (`?item=123`) or route (intercepting routes) | Transient confirm dialogs | — |
| Row selection | Rarely (short-lived) | Yes | — |
| Auth/session, PII | Never | — | Cookies/server |
| Draft form values | No | Yes | On submit |

### Option defaults (nuqs 2.x)
| Option | Default | Change when |
|---|---|---|
| `history` | `'replace'` | `'push'` for tab/page changes users expect Back to undo |
| `shallow` | `true` (client-only) | `false` when Server Components must re-render with new params |
| `scroll` | `false` | `true` for pagination to top |
| `limitUrlUpdates` | `throttle(50ms)` (120ms Safari) | `debounce(300)` for text input |
| `clearOnDefault` | `true` | `false` if you need the explicit value in the URL |
| `startTransition` | — | Pass from `useTransition` with `shallow: false` for pending UI |

Set app-wide defaults via `<NuqsAdapter defaultOptions={{ ... }}>`.

### Shared parsers
```ts
// src/features/orders/search-params.ts
import {
  createLoader, createSerializer, parseAsInteger, parseAsString,
  parseAsStringLiteral, parseAsArrayOf, parseAsIsoDate,
} from 'nuqs/server'

export const sortOptions = ['newest', 'oldest', 'total_desc'] as const
export const statusOptions = ['open', 'paid', 'shipped', 'cancelled'] as const

export const orderSearchParams = {
  q: parseAsString.withDefault(''),
  status: parseAsArrayOf(parseAsStringLiteral(statusOptions)).withDefault([]),
  sort: parseAsStringLiteral(sortOptions).withDefault('newest'),
  page: parseAsInteger.withDefault(1),
  from: parseAsIsoDate,
}

export const orderUrlKeys = { q: 'q', status: 's', sort: 'sort', page: 'p', from: 'from' } as const

export const loadOrderSearchParams = createLoader(orderSearchParams, { urlKeys: orderUrlKeys })
export const serializeOrderSearch = createSerializer(orderSearchParams, { urlKeys: orderUrlKeys })
```

### Adapter
```tsx
// src/app/layout.tsx
import { NuqsAdapter } from 'nuqs/adapters/next/app'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body><NuqsAdapter>{children}</NuqsAdapter></body>
    </html>
  )
}
```

### Server page reads typed params
```tsx
// src/app/orders/page.tsx
import { Suspense } from 'react'
import type { SearchParams } from 'nuqs/server'
import { loadOrderSearchParams } from '@/features/orders/search-params'
import { listOrders } from '@/server/orders' // DAL: auth + query
import { OrderFilters } from './order-filters'
import { OrdersTable } from './orders-table'

export default async function OrdersPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const params = await loadOrderSearchParams(searchParams)
  const orders = await listOrders(params) // validate/limit on server too

  return (
    <>
      <OrderFilters />
      <Suspense fallback={<p>Loading orders…</p>}>
        <OrdersTable orders={orders} page={params.page} />
      </Suspense>
    </>
  )
}
```

### Client filters with server re-render and pending state
```tsx
// src/app/orders/order-filters.tsx
'use client'
import { useTransition } from 'react'
import { debounce, useQueryStates } from 'nuqs'
import { orderSearchParams, orderUrlKeys, statusOptions } from '@/features/orders/search-params'

export function OrderFilters() {
  const [isPending, startTransition] = useTransition()
  const [{ q, status, sort }, setParams] = useQueryStates(orderSearchParams, {
    urlKeys: orderUrlKeys,
    shallow: false, // re-run the Server Component
    startTransition,
  })

  return (
    <div aria-busy={isPending}>
      <label htmlFor="q">Search</label>
      <input id="q" type="search" value={q}
        onChange={e => setParams({ q: e.target.value || null, page: null }, { limitUrlUpdates: debounce(300) })} />

      <fieldset>
        <legend>Status</legend>
        {statusOptions.map(s => (
          <label key={s}>
            <input type="checkbox" checked={status.includes(s)}
              onChange={e => setParams({
                status: e.target.checked ? [...status, s] : status.filter(x => x !== s),
                page: null,
              })} />
            {s}
          </label>
        ))}
      </fieldset>

      <label htmlFor="sort">Sort</label>
      <select id="sort" value={sort}
        onChange={e => setParams({ sort: e.target.value as typeof sort, page: null })}>
        <option value="newest">Newest</option>
        <option value="oldest">Oldest</option>
        <option value="total_desc">Highest total</option>
      </select>
    </div>
  )
}
```
Note: `q` here is URL-bound and debounced; the displayed input value updates immediately because nuqs state updates synchronously and the URL write is rate-limited.

### Typed pagination links
```tsx
import Link from 'next/link'
import { serializeOrderSearch } from '@/features/orders/search-params'

export function Pager({ page, current }: { page: number; current: Record<string, unknown> }) {
  return (
    <nav aria-label="Pagination">
      <Link href={`/orders${serializeOrderSearch({ ...current, page: page - 1 })}`} aria-disabled={page <= 1}>Previous</Link>
      <Link href={`/orders${serializeOrderSearch({ ...current, page: page + 1 })}`}>Next</Link>
    </nav>
  )
}
```

### Custom parser
```ts
import { createParser } from 'nuqs'

// "lat,lng,zoom" compact encoding
export const parseAsViewport = createParser({
  parse: v => {
    const [lat, lng, zoom] = v.split(',').map(Number)
    return [lat, lng, zoom].every(Number.isFinite) ? { lat, lng, zoom } : null
  },
  serialize: ({ lat, lng, zoom }) => `${lat.toFixed(4)},${lng.toFixed(4)},${zoom}`,
  eq: (a, b) => a.lat === b.lat && a.lng === b.lng && a.zoom === b.zoom,
})
```

## Recommended Workflow
1. Inventory view state; classify with the "what goes where" table.
2. Define parsers + defaults + `urlKeys` in a shared `search-params.ts` using `nuqs/server` imports.
3. Add the framework adapter at the root.
4. Server pages: `createLoader` to read params; pass values to the DAL (re-validate bounds server-side).
5. Client controls: `useQueryStates` with `shallow: false` + `startTransition` if the server renders results; otherwise shallow.
6. Add debounce for text inputs, `history: 'push'` where Back should undo, `page: null` resets on filter changes.
7. Generate links with `createSerializer`.
8. Test parsing edge cases, defaults, and interactions with `NuqsTestingAdapter`; e2e test reload, share, back/forward.

## Patterns
- **Filter + reset page** in one `setParams` call.
- **URL-driven modal**: `?order=123` opens a dialog; closing sets `null` (pair with `history: 'push'` so Back closes it).
- **Server-rendered list with shallow:false + transition** for pending UI while RSC payload loads.
- **Client-only filtering with shallow:true** when data is already on the client (small datasets).
- **Search params cache** for deep RSC trees: `searchParamsCache.parse(searchParams)` in the page, `searchParamsCache.get('page')` in children.
- **Typed links** via serializer for SEO-friendly, crawlable pagination.

## Anti-Patterns
- **Mirroring URL into `useState` with effects.** Double sources of truth, loops. Fix: read from `useQueryState` directly.
- **`router.push` on every keystroke.** History spam, server requests per character, browser rate-limit errors. Fix: debounce, `history: 'replace'`.
- **Using `next-usequerystate` or nuqs v1 APIs** (`queryTypes`, `subscribeToQueryUpdates`). Outdated. Fix: nuqs v2 parsers and adapters.
- **Importing parsers from `nuqs` in Server Components.** Pulls a client boundary. Fix: import from `nuqs/server` in shared files.
- **Forgetting the adapter.** Runtime error. Fix: `NuqsAdapter` at root.
- **Trusting parsed values for authorization or unbounded queries** (`pageSize=100000`). Fix: clamp and authorize in the DAL.
- **Encoding large JSON blobs** in the URL. Fix: store server-side (saved views) and put an ID in the URL.
- **Expecting Server Components to update with default `shallow: true`.** Fix: `shallow: false` for server-rendered data.
- **Putting PII or tokens in params.** Leaks via logs, analytics, Referer. Fix: server state/cookies.

## Accessibility
- Keep controls native (checkbox, select, input) with labels; URL state does not change a11y requirements.
- Announce result count changes with a polite live region after filtering (WCAG 4.1.3).
- Use `aria-busy` on the results region during transitions.
- Back/forward restoring filter state helps users recover (WCAG cognitive guidance); ensure focus is not lost when the list re-renders.
- Pagination links should be real links with `aria-current="page"` on the active page.

## Responsive Design
- Mobile filter drawers should read/write the same URL state; opening a drawer itself is usually local state, not URL.
- Consider applying filters on "Apply" for mobile (fewer server round trips) and live on desktop; both write the same keys.

## Performance
- Default throttling avoids history API rate limits; debounce text inputs to reduce server renders.
- `useQueryStates` batches multiple key updates into one URL write/render.
- `shallow: true` avoids RSC round trips when filtering client-side data.
- Keep parsers cheap and pure; avoid heavy JSON parsing on every render.
- With Cache Components, server-rendered search-param-dependent sections are dynamic; wrap them in `<Suspense>` so the static shell streams immediately.

## Security
- URLs are user-controlled input: server-side validate, clamp numbers, allowlist enums (parsers help; the DAL must still enforce).
- Never place secrets or PII in search params; they leak through logs, analytics, browser history, and `Referer`.
- Avoid reflecting raw param values into HTML without React's escaping (no `dangerouslySetInnerHTML`).
- Validate redirect targets read from params (`?next=`) against internal paths.
- Enable nuqs strict mode or schema validation (`parseAsJson(schema)`) for complex values.

## Testing
- Unit/component: wrap with `NuqsTestingAdapter` (`searchParams` initial value, `onUrlUpdate` spy) and assert URL updates and defaults.
- Test parser edge cases: missing, invalid, out-of-range, duplicated keys.
- Server: call `loadOrderSearchParams(new URLSearchParams('...'))` in Vitest.
- E2E (Playwright): apply filters, reload, copy URL into new page, back/forward, and verify results and control state.

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| nuqs 2.10.x | Active | Next >= 14.2, React 18.3/19, React Router 6/7/8, TanStack Router adapters |
| nuqs 1.x / `next-usequerystate` | Outdated | Old Next versions only |
| TanStack Router `validateSearch` | Active | Alternative in TanStack Router apps; nuqs adapter available |
| Next.js `useSearchParams` | Stable | Low-level; nuqs builds on it |
| Zod/Valibot (Standard Schema) | Active | `parseAsJson` validation |

## Framework Notes
- **Next.js**: `nuqs/adapters/next/app` (App Router), `nuqs/adapters/next/pages`, or `nuqs/adapters/next` for mixed. `searchParams` is a Promise in page props; use `createLoader`. Client components using `useSearchParams` under the hood should sit inside `<Suspense>` for static rendering. `shallow: false` triggers a server round trip; pair with `startTransition`.
- **React (Vite SPA)**: `nuqs/adapters/react`; all updates are client-side; `fullPageNavigationOnShallowFalseUpdates` option exists for server-rendered hosts. With React Router, prefer the React Router adapter so router state stays in sync.

## AI Agent Guidance
- Do: check for an existing `search-params.ts` and reuse parsers; add new keys there with defaults.
- Do: reset `page` when changing filters; debounce text input URL writes.
- Do: validate and clamp params again in the server data layer.
- Don't: add `useState` + `useEffect` URL sync code or call `router.push` for each keystroke.
- Don't: import from `nuqs` (client) in Server Components; use `nuqs/server`.
- Before done: reload the page with params and confirm identical UI; test back/forward; confirm no hydration warnings; confirm URL stays clean with defaults omitted.

## Examples
```tsx
// Simple tab state with push history
'use client'
import { parseAsStringLiteral, useQueryState } from 'nuqs'

const tabs = ['overview', 'activity', 'settings'] as const

export function ProjectTabs() {
  const [tab, setTab] = useQueryState('tab', parseAsStringLiteral(tabs).withDefault('overview').withOptions({ history: 'push' }))
  return (
    <div role="tablist" aria-label="Project sections">
      {tabs.map(t => (
        <button key={t} role="tab" aria-selected={tab === t} onClick={() => setTab(t)}>{t}</button>
      ))}
    </div>
  )
}
```

```tsx
// Component test with the testing adapter
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { NuqsTestingAdapter, type UrlUpdateEvent } from 'nuqs/adapters/testing'
import { vi, test, expect } from 'vitest'
import { ProjectTabs } from './project-tabs'

test('switches tab and writes URL', async () => {
  const onUrlUpdate = vi.fn<[UrlUpdateEvent]>()
  render(<ProjectTabs />, {
    wrapper: ({ children }) => (
      <NuqsTestingAdapter searchParams="?tab=overview" onUrlUpdate={onUrlUpdate}>{children}</NuqsTestingAdapter>
    ),
  })
  await userEvent.click(screen.getByRole('tab', { name: 'activity' }))
  expect(onUrlUpdate.mock.calls.at(-1)?.[0].queryString).toBe('?tab=activity')
})
```

## Related Skills
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — filter UX built on URL state
- [pagination](../pagination/Skill.md) — page/cursor params and links
- [react-state-management](../react-state-management/Skill.md) — choosing state location
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — searchParams in pages
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md) — intercepting routes vs URL modals
- [progressive-enhancement](../progressive-enhancement/Skill.md) — GET-form baseline under nuqs enhancement
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — debounced query UX

## Sources
- [nuqs Installation](https://nuqs.dev/docs/installation) — Official — v2.10.1, framework compatibility
- [nuqs Adapters](https://nuqs.dev/docs/adapters) — Official — adapter import paths per framework, testing adapter
- [nuqs Options](https://nuqs.dev/docs/options) — Official — history/shallow/scroll/limitUrlUpdates/clearOnDefault/startTransition defaults
- [nuqs Parsers](https://nuqs.dev/docs/parsers) — Official — built-in parsers, createParser, nuqs/server imports
- [nuqs Server-side usage](https://nuqs.dev/docs/server-side) — Official — createLoader, createSearchParamsCache, urlKeys, strict mode
- [Next.js SPA guide: shallow routing](https://nextjs.org/docs/app/guides/single-page-applications) — Official — pushState/replaceState integration with Next router

## License / Usage Notes
nuqs is MIT licensed. Content summarized from official docs; code examples are original and should be checked against the installed nuqs version.

## Quality Tier
A — Current official nuqs 2.10 docs; some helper signatures (e.g., testing adapter event shape) can shift between minors and should be verified.

## Status
Active

## Last Verified
2026-09-15
