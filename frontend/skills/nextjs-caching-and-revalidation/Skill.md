# Next.js Caching and Revalidation (Cache Components)

## Summary
Next.js 16 introduced **Cache Components** (`cacheComponents: true`): everything is dynamic by default and caching is explicit via the `'use cache'` directive (plus `'use cache: remote'` and `'use cache: private'`), `cacheLife` profiles, and `cacheTag`. Invalidation uses `updateTag` (read-your-writes), `revalidateTag(tag, profile)` (stale-while-revalidate), `revalidatePath`, and `refresh`. Apps not yet on Cache Components still use the **previous model** (`fetch` cache options, `unstable_cache`, route segment `revalidate`/`dynamic`), which this skill also maps and marks as legacy.

## Category
Next.js

## Subcategories
use cache, cacheLife, cacheTag, updateTag, revalidateTag, revalidatePath, refresh, cache handlers, Partial Prerendering, legacy fetch cache

## Problem It Solves
The pre-v15 App Router cached implicitly and confusingly (fetch cached by default, full route cache, router cache). Teams over-cached personalized data, under-cached expensive queries, used stale tutorials (`export const revalidate`, `fetch(..., { next: { revalidate } })`) that error under Cache Components, and couldn't reason about what persists across serverless instances and deploys.

## When To Use
- Deciding what data/UI is cacheable, for how long, and how to invalidate it.
- Enabling or migrating to Cache Components.
- Designing CMS webhooks, mutation invalidation, or multi-instance cache handlers.
- Debugging stale or never-updating content.

## When Not To Use
- Per-request personalized data that must always be fresh — stream it behind `<Suspense>` instead of caching.
- HTTP/CDN header strategy in general (see [http-caching-and-cdn](../http-caching-and-cdn/Skill.md)).
- Client-side server-state caching (see [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md)).

## Core Principles
1. **Dynamic by default, cache on purpose.** Add `'use cache'` only where stale data for a known lifetime is acceptable.
2. **Always pair `'use cache'` with `cacheLife`** so lifetime is explicit at the call site.
3. **Cached scopes cannot read request data.** Read `cookies()`/`headers()`/`searchParams` outside and pass values as arguments (they become part of the key), or use `'use cache: private'`.
4. **Arguments and closures are the cache key**; they must be serializable, and they are stored in plain text — never put secrets or PII in keys or tags.
5. **Tag for invalidation, pick semantics per mutation:** `updateTag` for the user's own write, `revalidateTag(tag, 'max')` for background refresh.
6. **Know where entries live:** default in-memory (ephemeral on serverless), remote handler (shared, costs latency), browser-only (private). None survive a new deploy.

## Best Practices
- Cache at the **data level** (functions like `getProducts()`) for reuse; cache at the **UI level** (component/page) when the whole subtree is stable.
- Use `cacheLife('max')` + `cacheTag` + webhook `revalidateTag(tag, 'max')` for CMS content instead of short time-based lifetimes.
- Avoid short-lived caches inside prerender: `seconds` profile, `revalidate: 0`, or `expire` < 5 min become dynamic holes; nesting a short-lived cache inside one without explicit `cacheLife` fails the build.
- Use `'use cache: remote'` only for high hit-rate, expensive, rate-limited, or flaky upstreams; key on low-cardinality dimensions (category, locale) and filter in memory.
- Use `'use cache: private'` only when you cannot extract runtime values or compliance forbids server storage; keep `stale` ≥ 30s (prefetch) or ≥ 5 min (App Shell).
- Prefer tags over `revalidatePath` (more precise).
- Keep cached helper functions that take a `userId` **unexported**; expose a getter that derives the user from the session.
- Debug with `NEXT_PRIVATE_DEBUG_CACHE=1`.

## Implementation Guidance

### Enable
```ts
// next.config.ts
import type { NextConfig } from 'next'
const nextConfig: NextConfig = {
  cacheComponents: true,
  cacheLife: {
    catalog: { stale: 300, revalidate: 3600, expire: 86400 }, // custom profile
  },
}
export default nextConfig
```

### cacheLife built-in profiles
| Profile | stale (client) | revalidate (server) | expire |
|---|---|---|---|
| `default` | 5m | 15m | never |
| `seconds` | 30s | 1s | 60s |
| `minutes` | 5m | 1m | 1h |
| `hours` | 5m | 1h | 1d |
| `days` | 5m | 1d | 1w |
| `weeks` | 5m | 1w | 30d |
| `max` | 5m | 30d | 1y |

Client router enforces a minimum 30s stale time.

### Directive comparison
| | `use cache` | `use cache: remote` | `use cache: private` |
|---|---|---|---|
| Server storage | In-memory LRU / cacheHandlers | Remote handler (shared) | None |
| Scope | All users | All users | Per browser |
| Reads cookies/headers | No (pass args) | No (pass args) | Yes |
| In static shell | Yes (if lifetime not short) | At request time | No |
| Extra cost | None | Storage + latency | None |

### Data-level cache with tag
```ts
// lib/data/products.ts
import 'server-only'
import { cacheLife, cacheTag } from 'next/cache'

export async function getProducts(category: string) {
  'use cache'
  cacheLife('hours')
  cacheTag('products', `products:${category}`)
  return db.product.findMany({ where: { category } })
}
```

### Passing runtime values into a cache
```tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'

export default function Page() {
  return <Suspense fallback={<p>Loading…</p>}><Prices /></Suspense>
}
async function Prices() {
  const currency = (await cookies()).get('currency')?.value ?? 'USD'
  return <PriceList currency={currency} />
}
async function PriceList({ currency }: { currency: string }) {
  'use cache'
  cacheLife('minutes')
  const prices = await getPrices(currency) // key includes currency
  return <ul>{prices.map((p) => <li key={p.id}>{p.label}</li>)}</ul>
}
```

### Invalidation
```ts
// app/actions/product.ts
'use server'
import { updateTag } from 'next/cache'
export async function saveProduct(id: string, fd: FormData) {
  await updateProductForCurrentUser(id, fd) // auth inside
  updateTag(`product:${id}`)                // user sees change immediately
}

// app/api/cms-webhook/route.ts
import { revalidateTag } from 'next/cache'
export async function POST(req: Request) {
  if (!(await verifyCmsSignature(req))) return new Response(null, { status: 401 })
  const { tag } = await req.json()
  revalidateTag(tag, 'max') // SWR background refresh
  return Response.json({ ok: true })
}
```

### Legacy model → Cache Components mapping (previous model, still valid without the flag)
| Previous model | Cache Components |
|---|---|
| `export const dynamic = 'force-dynamic'` | Remove (dynamic by default) |
| `export const dynamic = 'force-static'` | `'use cache'` + `cacheLife('max')` |
| `export const revalidate = 3600` | `cacheLife('hours')` |
| `export const fetchCache` | Remove; `'use cache'` scope caches fetches |
| `fetch(url, { cache: 'force-cache', next: { revalidate, tags } })` | Wrap in `'use cache'` fn with `cacheLife`/`cacheTag` |
| `unstable_cache(fn, keys, { tags, revalidate })` | `'use cache'` function |
| `unstable_noStore()` | Remove; use `connection()` if request-time is required |
| `revalidateTag('x')` | `revalidateTag('x', 'max')` or `updateTag('x')` |
| `dynamicParams` | Unsupported; call `notFound()` |
| `runtime = 'edge'` | Unsupported with Cache Components |

Note: `fetch` Data Cache and `unstable_cache` persist across deploys; `use cache` entries (even remote) do not, because the key includes build/deployment ID.

## Recommended Workflow
1. Enable `cacheComponents` (Next.js 16+); run `next dev`.
2. Remove `dynamic`/`revalidate`/`fetchCache` exports (they error).
3. Follow dev-overlay insights: for each blocking access choose **stream** (`<Suspense>`), **cache** (`'use cache'`), or **block** (`export const instant = false`).
4. Add `cacheLife` + `cacheTag` to every cache.
5. Wire mutations (`updateTag`) and webhooks (`revalidateTag(tag, 'max')`).
6. For multi-instance hosting, configure `cacheHandlers` (and `refreshTags` coordination) or use a platform that provides one.
7. Verify with `NEXT_PRIVATE_DEBUG_CACHE=1 next start`.

## Patterns
- **CMS content:** `max` lifetime + tag + webhook.
- **Catalog with low-cardinality remote cache:** `'use cache: remote'` keyed on category; filter price in memory.
- **Cached shell, streamed personalization:** cached `<ProductList>` + `<Suspense><Greeting/></Suspense>`.
- **Cache wrapper with pass-through children:** cached layout chrome containing dynamic `children` without affecting its key.
- **Deterministic build values:** `'use cache'` around `crypto.randomUUID()` to share one value, or `await connection()` for per-request values.

## Anti-Patterns
- **`cookies()` inside `'use cache'`** — throws `next-request-in-use-cache` (may only surface at `next start`). Fix: read outside and pass the value.
- **Passing a request Promise (e.g., `cookies()` promise) into a cached component** — build hangs ~50s "Filling a cache during prerender timed out". Fix: await outside, pass primitives.
- **Caching per-user data without the user in the key** — cross-user data leak. Fix: key on `userId` (unexported helper) or use `use cache: private`.
- **Tokens/emails as cache keys or tags** — stored in plain text. Fix: stable opaque IDs.
- **Remote-caching high-cardinality keys** (search filters) — near-zero hit rate, added latency and cost. Fix: cache coarse data, filter in memory.
- **Expecting `use cache` to persist across serverless instances or deploys** — it doesn't. Fix: remote handler, or `unstable_cache`/fetch cache where cross-deploy persistence is required.
- **Using `React.cache` to pass data into a cached scope** — isolated; value is null inside. Fix: function arguments.
- **`generateMetadata` with `'use cache'` returning `new URL()`** — not serializable. Fix: return strings.

## Accessibility
- Stale-while-revalidate can show outdated information; for status-critical data (stock, prices, balances) show freshness hints ("updated 5 min ago") and avoid caching when accuracy is required.
- After `updateTag`-driven re-renders, announce success in a live region so non-visual users know the change applied.

## Responsive Design
- Cache keys should not include viewport/device hints; serve the same cached HTML to all devices and adapt with CSS so hit rates stay high.

## Performance
- Cached content joins the static shell (served from CDN) and prefetches — the biggest lever for instant navigation.
- Short lifetimes silently remove content from prerendering; watch build output and insights.
- `cacheMaxMemorySize` tunes self-hosted in-memory size; set `0` when a custom handler is authoritative.
- Draft Mode bypasses all `use cache` (re-executes every request).

## Security
- Cached output is shared across users (except private): never cache authorization decisions or user-specific records under shared keys.
- Webhook revalidation endpoints must verify signatures/secrets and validate tag names against an allowlist.
- Keys/tags are plaintext in handlers — exclude secrets and PII.

## Testing
- E2E: mutate via UI, assert immediate update (updateTag) or eventual update (revalidateTag).
- Run tests against `next build && next start` — dev re-executes caches on HMR and never prefetches.
- Use `@next/playwright` `instant()` to lock in cached content appearing in the shell.
- Log with `NEXT_PRIVATE_DEBUG_CACHE=1` in CI smoke tests to detect unexpected misses.

## Tooling
- `next/cache`: `cacheLife`, `cacheTag`, `updateTag`, `revalidateTag`, `revalidatePath`, `refresh`.
- `next/server`: `connection()`, `after()`.
- `cacheHandlers` (for `use cache*`) and `cacheHandler` (ISR/previous model) in `next.config`; Redis example in vercel/next.js `examples/cache-handler-redis`.
- Next.js Skills: `next-cache-components-adoption`, `next-cache-components-optimizer` (`npx skills add vercel/next.js --skill ...`).

## Framework Notes
- Cache Components shipped in 16.0 (replacing `experimental.dynamicIO`, `experimental.useCache`, and `experimental.ppr`). `cacheLife`/`cacheTag` lost the `unstable_` prefix in 16.0.
- Partial Prerendering is the default rendering behavior under Cache Components.
- Next.js 16.3 blog states these behaviors will become the default in a future major.
- Vercel provides durable remote handlers; self-hosters must supply one for cross-instance sharing; OpenNext Cloudflare supports `'use cache'`.

## AI Agent Guidance
- Check `next.config` for `cacheComponents` before choosing APIs; never emit `export const revalidate`/`dynamic` in a Cache Components app.
- Every `'use cache'` gets `cacheLife` and (if mutable) `cacheTag`.
- Never read `cookies()`/`headers()` inside cached scopes; never key on secrets.
- Before done: `next build` passes with no blocking-route errors, mutation paths use `updateTag` or two-arg `revalidateTag`, and a production-mode check confirms content updates as intended.

## Examples
```tsx
// Page mixing static, cached, and streamed content
import { Suspense } from 'react'
import { cacheLife, cacheTag } from 'next/cache'

export default function BlogPage() {
  return (
    <>
      <h1>Blog</h1>
      <Posts />
      <Suspense fallback={<p>Loading your picks…</p>}><Recommended /></Suspense>
    </>
  )
}

async function Posts() {
  'use cache'
  cacheLife('max')
  cacheTag('posts')
  const posts = await getPublishedPosts()
  return <ul>{posts.map((p) => <li key={p.id}>{p.title}</li>)}</ul>
}
```

## Related Skills
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md) — static shell / PPR / ISR
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — mutation invalidation
- [nextjs-instant-navigation](../nextjs-instant-navigation/Skill.md) — prefetch and stale times
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) — cache handlers
- [nextjs-data-fetching-patterns](../nextjs-data-fetching-patterns/Skill.md) — React.cache and preload
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) — CDN layer
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — caching ORM queries safely

## Sources
- [Caching (Cache Components)](https://nextjs.org/docs/app/getting-started/caching) — Official — model, runtime APIs, prerendering, storage locations
- [Revalidating](https://nextjs.org/docs/app/getting-started/revalidating) — Official — cacheLife table, tags, updateTag vs revalidateTag
- [use cache reference](https://nextjs.org/docs/app/api-reference/directives/use-cache) — Official — keys, serialization, constraints, troubleshooting
- [use cache: remote](https://nextjs.org/docs/app/api-reference/directives/use-cache-remote) — Official — comparison table, key cardinality, nesting
- [use cache: private](https://nextjs.org/docs/app/api-reference/directives/use-cache-private) — Official — allowed APIs, stale thresholds
- [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) — Official — legacy API mapping
- [Caching and Revalidating (Previous Model)](https://nextjs.org/docs/app/guides/caching-without-cache-components) — Official — legacy fetch/segment config
- [Next.js 16](https://nextjs.org/blog/next-16) — Official — API changes

## License / Usage Notes
Next.js MIT. Tables and code are condensed rewrites of official documentation.

## Quality Tier
S — Deep, current (16.3.5 docs), includes legacy mapping, storage semantics, and pitfalls verified against reference pages.

## Status
Active

## Last Verified
2026-09-15
