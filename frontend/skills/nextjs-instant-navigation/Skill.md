# Next.js Instant Navigation and Partial Prefetching

## Summary
Instant Navigations (Next.js 16.3, opt-in) make server-rendered apps feel like SPAs: with `cacheComponents: true` and `partialPrefetching: true`, every `<Link>` prefetches the destination's reusable **App Shell** (static + cached + fallback UI), `<Link prefetch={true}>` additionally resolves per-link URL data, and dev-time **instant validation** flags any navigation that would block. Tooling includes Instant Insights, the Navigation Inspector in Next.js DevTools, the `instant` segment config, and the `@next/playwright` `instant()` test helper. These behaviors are slated to become defaults in a future major.

## Category
Next.js

## Subcategories
Partial Prefetching, App Shell, Link prefetch, instant segment config, Instant Insights, Navigation Inspector, @next/playwright instant(), useLinkStatus, prefetch inlining, UI state preservation, offline resilience

## Problem It Solves
Clicking a link in a Server Components app waits on the server with no feedback; `loading.tsx` is easy to forget; `prefetch={true}` was all-or-nothing and expensive; refactors silently make fast navigations slow (e.g., a `cookies()` read added to a shared header).

## When To Use
- Apps on Next.js 16.3+ with Cache Components (or adopting it) that want SPA-like navigation.
- Dashboards/e-commerce/content apps with dynamic routes and frequent in-app navigation.
- Adding regression tests for navigation responsiveness.

## When Not To Use
- Apps on Next.js <16.3, or not using Cache Components (use `loading.tsx` + `useLinkStatus`).
- Pages Router.
- Routes where blocking is acceptable (set `instant = false` rather than contorting code).

## Core Principles
1. **Instant = the browser can render something meaningful at click time**, with remaining content streaming into fallbacks (assuming warm caches).
2. **Page loads and client navigations differ:** client navigations only re-render below the shared layout, so Suspense boundaries above it don't help.
3. **Make the App Shell good first;** per-link prefetching cannot fix a route that blocks without its shell.
4. **Levers:** push dynamic access down into Suspense, cache with `'use cache'` + `cacheLife`, per-link prefetch for URL-dependent cached data.
5. **Lock it in with tests** — validation proves a shell exists; `instant()` tests prove the right content is in it.

## Best Practices
- Enable both flags; follow dev overlay insights (Stream / Cache / Block) one at a time.
- Keep `stale` ≥ 30s for caches you want in per-link prefetches, ≥ 5 min for App Shell inclusion (`'use cache: private'`).
- Use `prefetch={true}` only where the wait is worth one server invocation per link (e.g., primary CTAs, not every sidebar item).
- Session data from `cookies()`/`headers()` already lands in a per-session App Shell — no per-link prefetch needed for that.
- `useSearchParams`/`usePathname`/`useParams` in shared layouts suspend on page load for dynamic routes — wrap the smallest leaf in Suspense.
- Use `export const instant = false` on segments that legitimately block; keep it low in the tree.
- Use `useLinkStatus` for pending hints on slow networks (debounce with a CSS animation delay).
- Cache Components preserves UI state across navigations via React `<Activity>` — reset dropdowns/forms explicitly where needed.
- Try experimental `experimental.useOffline` + `useOffline()` hook for connectivity drops.

## Implementation Guidance

### Enable
```ts
// next.config.ts
import type { NextConfig } from 'next'
const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  experimental: {
    instantInsights: { validationLevel: 'warning' }, // default; 'manual-warning' = only segments exporting instant
    // exposeTestingApiInProductionBuild: true,        // for instant() tests against next start in CI
  },
}
export default nextConfig
```

### Prefetch modes (with Partial Prefetching)
| Link | Prefetches | Cost |
|---|---|---|
| `<Link href>` (default) | Destination App Shell (shared per route) | Low; shells deduplicated/inlined |
| `<Link prefetch>` / `prefetch={true}` | App Shell + cached content resolved with link's `params`/`searchParams` + `use cache: private` results | One server invocation per link |
| `<Link prefetch={false}>` | Nothing | Navigation waits |

### `instant` segment config
| Value | Meaning |
|---|---|
| `true` | Validate at global level |
| `false` | Allowed to block; opts out of validation (highest `false` also disables static shell validation for the subtree) |
| `{ level: 'warning' }` | Explicit dev-only validation |

### Instant product page
```tsx
// app/store/[slug]/page.tsx
import { Suspense } from 'react'
import { cacheLife, cacheTag } from 'next/cache'

export default function ProductPage(props: PageProps<'/store/[slug]'>) {
  return (
    <div>
      <Suspense fallback={<ProductSkeleton />}><ProductInfo params={props.params} /></Suspense>
      <Suspense fallback={<p>Checking availability…</p>}><Inventory params={props.params} /></Suspense>
    </div>
  )
}

type P = PageProps<'/store/[slug]'>['params']

async function ProductInfo({ params }: { params: P }) {
  const { slug } = await params
  const product = await getProduct(slug)
  return <><h1>{product.name}</h1><p>${product.price}</p></>
}
async function getProduct(slug: string) {
  'use cache'
  cacheLife('hours')
  cacheTag(`product:${slug}`)
  return db.product.findBySlug(slug)
}
async function Inventory({ params }: { params: P }) {
  const { slug } = await params
  const item = await db.inventory.findBySlug(slug) // fresh per request
  return <p>{item.count} in stock</p>
}
```

### Tab layout that may block, tabs that must be instant
```tsx
// app/settings/layout.tsx
export const instant = false
// app/settings/[tab]/page.tsx
export const instant = true
```

### Regression test
```ts
// e2e/instant.spec.ts
import { test, expect } from '@playwright/test'
import { instant } from '@next/playwright'

test('client navigation to product is instant', async ({ page }) => {
  await page.goto('/store/shoes')
  await instant(page, async () => {
    await page.click('a[href="/store/hats"]')
    await page.waitForURL((u) => u.pathname === '/store/hats')
    await expect(page.locator('h1')).toContainText('Baseball Cap')
    await expect(page.getByText('in stock')).toHaveCount(0) // still streaming
  })
  await expect(page.getByText('in stock')).toBeVisible()
})

test('initial load shows shell', async ({ page, baseURL }) => {
  await instant(page, async () => {
    await page.goto('/store/hats')
    await expect(page.getByText('Checking availability…')).toBeVisible()
  }, { baseURL })
})
```

### Pending hint for slow networks
```tsx
'use client'
import { useLinkStatus } from 'next/link'
export function PendingDot() {
  const { pending } = useLinkStatus()
  return <span aria-hidden className={pending ? 'pending-dot is-pending' : 'pending-dot'} />
}
// <Link href="/reports">Reports <PendingDot /></Link>
// .pending-dot.is-pending { animation: fade-in 150ms 100ms both; } (debounced)
```

## Recommended Workflow
1. Adopt Cache Components (Skill: `next-cache-components-adoption`), then Partial Prefetching (Skill: `next-partial-prefetching-adoption`).
2. In `next dev`, navigate key flows; read Instant Insights; apply Stream / Cache / Block fixes.
3. Inspect shells with Navigation Inspector ("Pause on navigations") for page load and client nav.
4. Iterate loading states: maximize real content, minimize fallback area.
5. Add `prefetch={true}` on high-value links needing URL-dependent cached content.
6. Write `instant()` tests for critical flows; run against a production-like build in CI.
7. Optionally use `next-cache-components-optimizer` Skill for test-first optimization loops.

## Patterns
- **Push down:** extract I/O into a Suspense-wrapped child so the parent and siblings join the shell.
- **Cache:** `'use cache'` + `cacheLife` for data with acceptable staleness.
- **Per-link prefetch:** search results/product links with `prefetch` to resolve `searchParams`/`params` cached content ahead of click.
- **Client page for fully interactive screens:** `'use client'` page gives SPA transitions (still needs Suspense for `useSearchParams`).
- **Offline-tolerant navigation:** `useOffline` banner + prefetched shells.

## Anti-Patterns
- **Suspense only in the root layout** — covers page loads but not client navigations below shared layouts. Fix: boundaries below the shared layout.
- **`prefetch={true}` on every link in long lists** — server cost per link. Fix: default prefetch; opt in selectively or hover-prefetch.
- **Guessing short cache lifetimes to pass validation** — stale data or dropped from prefetch (<30s). Fix: keep fresh data behind Suspense.
- **Adding `cookies()` to a shared header component** — de-opts navigations. Fix: Suspense leaf for the user menu; `instant()` tests catch this.
- **Validating only in dev without tests** — regressions ship. Fix: Playwright `instant()` in CI.
- **Assuming dev navigation speed reflects prod** — dev disables prefetching. Fix: test with production build (`exposeTestingApiInProductionBuild`).
- **Relying on state reset on navigation** under Cache Components — state now persists. Fix: explicit resets.

## Accessibility
- Instant fallbacks should be meaningful (headings present) so screen reader users get context immediately; avoid announcing transient skeletons.
- Preserved UI state (Activity) can leave dialogs/popovers open when returning — close them on navigation to avoid focus traps.
- Ensure route-change announcements and focus placement still work with instant shells (WCAG 2.4.3).
- Pending indicators must not rely on motion only; respect `prefers-reduced-motion`.

## Responsive Design
- App Shell content is shared across devices; keep responsive differences in CSS so a single shell serves all.

## Performance
- 16.3 prefetch inlining bundles small prefetches into fewer requests; shared shells are fetched once per route.
- Per-link prefetch costs one server invocation per visible link — budget it.
- Instant shells reduce perceived latency even when total load time is unchanged.

## Security
- Per-session App Shells include session-derived content cached **per session on the client**, not in shared server caches — keep it that way (don't move session reads into plain `'use cache'`).
- The DevTools testing cookie `next-instant-navigation-testing` is shared across localhost projects — clear it when switching projects; don't expose the testing API in real production builds (use a separate CI build).

## Testing
- `@next/playwright` `instant()` for page loads (pass `baseURL`) and client navigations (wait for URL before asserting).
- Run against `next dev` locally; in CI against `next build && next start` with `experimental.exposeTestingApiInProductionBuild` in a test-only config.
- Keep tests focused on user-critical flows.

## Tooling
- Next.js DevTools: Instant Insights, Navigation Inspector; React DevTools Suspense panel.
- `@next/playwright`, `@playwright/test`.
- Next.js Skills (vercel/next.js/skills): `next-cache-components-adoption`, `next-cache-components-optimizer`, `next-partial-prefetching-adoption`, `next-partial-prefetching-optimizer`, `next-dev-loop`; `agent-browser` for agent runtime inspection.

## Framework Notes
- Introduced in Next.js 16.3 (Aug 2026); `partialPrefetching` opt-in; `instant` requires Cache Components; the App Shell for unlisted params served from 16.3.
- `unstable_eager` link prefetch migration is covered by the "Adopting Partial Prefetching" guide.
- React (Vite SPA): navigations are inherently client-side; the analogous work is route-level code-split preloading and data prefetching (TanStack Query/router loaders) with pending UI.

## AI Agent Guidance
- Confirm Next.js ≥16.3 and Cache Components before using these APIs.
- Follow insights; don't guess cache lifetimes — when unsure, stream behind Suspense.
- Ask the user what must appear instantly for each critical navigation; encode it in an `instant()` test that fails before the fix.
- Before done: tests pass against a production-like build, Navigation Inspector shows intended shell for page load and client nav, no new `prefetch={true}` on large link lists.

## Examples
```tsx
// Search results link that prefetches cached results for its query
import Link from 'next/link'
export function RecentSearches({ queries }: { queries: string[] }) {
  return (
    <ul>
      {queries.slice(0, 5).map((q) => (
        <li key={q}><Link href={`/search?q=${encodeURIComponent(q)}`} prefetch>{q}</Link></li>
      ))}
    </ul>
  )
}
```

## Related Skills
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — cache lifetimes and private caches
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — Suspense placement
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md) — App Shell and ISR
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) — E2E setup
- [speculation-rules-and-prerendering](../speculation-rules-and-prerendering/Skill.md) — browser-level prerendering
- [frontend-agent-verification-loop](../frontend-agent-verification-loop/Skill.md) — agent verify loops

## Sources
- [Ensuring instant navigations guide](https://nextjs.org/docs/app/guides/instant-navigation) — Official — concepts, tools, validation, inspector, e2e tests, AI workflow, opting out
- [instant segment config reference](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant) — Official — values, validationLevel, known issues
- [Next.js 16.3](https://nextjs.org/blog/next-16-3) — Official — Instant Navigations suite, prefetch inlining, useOffline
- [Caching (Cache Components)](https://nextjs.org/docs/app/getting-started/caching) — Official — prefetching and App Shell
- [Authentication with Cache Components](https://nextjs.org/docs/app/guides/authentication-with-cache-components) — Official — stale thresholds, per-session shells
- [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) — Official — UI state preservation
- [Linking and Navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating) — Official — useLinkStatus, prefetch prop
- [vercel/next.js skills directory](https://github.com/vercel/next.js/tree/canary/skills) — Open Source — first-party skill names

## License / Usage Notes
Next.js MIT; @next/playwright MIT. Features are new (16.3) and partly experimental (`instantInsights`, testing API) — expect changes. Summarized; examples adapted.

## Quality Tier
A — Current official material thoroughly covered; feature is newly released with evolving APIs, so tier is capped below S.

## Status
Experimental

## Last Verified
2026-09-15
