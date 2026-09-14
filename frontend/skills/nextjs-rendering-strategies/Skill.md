# Next.js Rendering Strategies

## Summary
Next.js 16 treats static and dynamic rendering as a spectrum at the **component** level rather than a per-route switch. With Cache Components enabled, every route is prerendered into a **static shell** (static markup, cached `'use cache'` output, and `<Suspense>` fallbacks) and uncached or request-specific parts stream in at request time — this is Partial Prerendering (PPR), now the default rendering behavior under `cacheComponents: true`. This skill maps classic terms (SSG, SSR, ISR, CSR, static export) onto the current model and gives decision rules for each part of a page.

## Category
Next.js

## Subcategories
Partial Prerendering, static shell, App Shell, SSG, SSR, ISR, CSR, static export, generateStaticParams, connection(), bots

## Problem It Solves
Developers still think "this route is SSR or SSG", reach for `force-dynamic`/`force-static` exports that error under Cache Components, accidentally make whole routes dynamic by reading `cookies()` in a layout, or pick static export without knowing what breaks. The result is slow TTFB, wasted server compute, or broken features.

## When To Use
- Designing a new route and deciding what is prerendered, cached, or streamed.
- Migrating Pages Router `getStaticProps`/`getServerSideProps`/ISR mental models.
- Choosing between a Node server, adapter platform, or `output: 'export'`.
- Diagnosing "route became dynamic" or blocking-route insights.

## When Not To Use
- Cache lifetimes and invalidation specifics (see [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md)).
- Loading UI design (see [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md)).
- Client-only SPA without server (see [vite-react-spa](../vite-react-spa/Skill.md)).

## Core Principles
1. **The boundary is the component.** A page can have a static header, a cached product list, and a streamed cart.
2. **Everything above the first uncached/runtime access is the static shell.** Push dynamic access down to maximize it.
3. **Runtime data needs a Suspense boundary.** `cookies()`, `headers()`, `searchParams`, unknown `params`, uncached I/O, and `connection()` must sit under `<Suspense>` (or use `'use cache'` where appropriate) or Next.js raises a blocking-route insight/error.
4. **Non-deterministic values must be explicit.** `Date.now()`, `Math.random()`, `crypto.randomUUID()` need `await connection()` (per request) or `'use cache'` (shared).
5. **Streaming commits the status code.** Decide 404/redirect before the first Suspense boundary.

## Best Practices
- Keep root and section layouts free of top-level `await` on request data; pass promises down into Suspense-wrapped children.
- Provide `generateStaticParams` returning at least one param for dynamic routes under Cache Components (an empty array errors); unknown params get the App Shell and are upgraded in the background (16.3 ISR).
- Use `loading.tsx` only when nothing meaningful renders without data; otherwise use granular `<Suspense>`.
- For per-request env values in a single Docker image, read `process.env` after `await connection()`.
- Remember bots: HTML-limited crawlers skip the shell and get a fully rendered document — ensure shell data is available at request time too.
- Choose `output: 'export'` only for truly static sites (no Server Actions, proxy, ISR, cookies, rewrites/redirects/headers, default image loader, intercepting routes).

## Implementation Guidance

### Classic term → current model (Cache Components)
| Classic | Current equivalent |
|---|---|
| SSG (`getStaticProps`) | Components with no runtime data, or `'use cache'` + `cacheLife('max')` → static shell |
| ISR (`revalidate: n`) | `'use cache'` + `cacheLife(profile)` + `cacheTag`; `generateStaticParams` subset + background upgrade |
| `fallback: true` | Default: unknown params get App Shell, upgraded after first visit |
| SSR (`getServerSideProps`) | Uncached/runtime reads inside `<Suspense>` streamed per request |
| CSR | Client Component fetching with SWR/TanStack Query (use sparingly) |
| `force-dynamic` | Not needed; dynamic by default |
| `force-static` | Remove; add `'use cache'`; remove runtime reads |
| Static export | `output: 'export'` (limited features) |

### Per-component decision table
| Component reads… | Do |
|---|---|
| Nothing async / module-scope data / sync fs | Nothing — prerendered |
| Shared external data OK to be stale | `'use cache'` + `cacheLife` |
| Per-request fresh data (inventory, feed) | `<Suspense>` around it |
| `cookies()`/`headers()`/`searchParams` | `<Suspense>`; optionally extract value → cached child |
| Random/time per request | `await connection()` inside `<Suspense>` |
| Must block (legacy route, not ready) | `export const instant = false` (temporary) |

### Maximize the shell: pass params promise down
```tsx
// app/shop/[slug]/layout.tsx
import { Suspense } from 'react'

export default function Layout({ children, params }: LayoutProps<'/shop/[slug]'>) {
  return (
    <div>
      <Sidebar />
      <Suspense fallback={<h1>Loading…</h1>}>
        {params.then(({ slug }) => <h1>{slug}</h1>)}
      </Suspense>
      {children}
    </div>
  )
}
```

### Per-request uniqueness
```tsx
import { connection } from 'next/server'
import { Suspense } from 'react'

async function RequestId() {
  await connection()
  return <p>Request {crypto.randomUUID()}</p>
}
export default function Page() {
  return <Suspense fallback={null}><RequestId /></Suspense>
}
```

### Static export config
```ts
// next.config.ts
const nextConfig = {
  output: 'export',
  images: { loader: 'custom', loaderFile: './image-loader.ts' },
  // trailingSlash: true,
}
export default nextConfig
```

### Previous model (no `cacheComponents`) — legacy but supported
Routes are static unless they use request-time APIs or uncached fetches; `fetch` is not cached by default (since v15); `export const dynamic`, `revalidate`, `fetchCache`, `dynamicParams` still work. Any `cookies()` read makes the whole route dynamic.

## Recommended Workflow
1. List each UI region and its data freshness requirement.
2. Mark regions: static / cached (lifetime) / streamed / client.
3. Build the page with static regions at top level and Suspense boundaries at the streamed leaves.
4. Add `generateStaticParams` for known high-traffic params.
5. Run `next dev`; resolve blocking-route insights (stream / cache / block).
6. Inspect the shell with the Navigation Inspector (DevTools) and verify with `next build` output.

## Patterns
- **Static shell + streamed personalization** (product page with cached details and streamed cart/inventory).
- **App Shell for long-tail params** (prerender top N products; the rest upgrade on first visit).
- **Marketing site fully static** (no runtime reads; cache CMS with `max` + webhook).
- **Dashboard** (static chrome; each widget under its own Suspense; per-user caches keyed by userId).
- **Static export docs site** with client search.

## Anti-Patterns
- **`await cookies()` in root layout** — whole app request-bound. Fix: read in a leaf under Suspense; for `<html data-theme>` use an inline script before paint.
- **`export const dynamic = 'force-dynamic'` in a Cache Components app** — build error. Fix: remove.
- **`generateStaticParams` returning `[]`** under Cache Components — `empty-generate-static-params` error. Fix: return at least one real param.
- **`new Date()` in a prerendered component** — sync IO build error (not cleared by `instant = false`). Fix: `connection()` + Suspense, or move to a Client Component.
- **LCP hero inside a Suspense boundary** — delays LCP. Fix: keep the LCP element in the shell.
- **`notFound()` after Suspense started** — status stays 200 with noindex meta. Fix: existence check before boundaries.
- **Nonce-based CSP with PPR** — incompatible (shell scripts can't get per-request nonce). Fix: SRI hash-based CSP or fully dynamic routes.

## Accessibility
- Streamed fallbacks should reserve space and use `aria-busy`/visually hidden status text; avoid multiple competing live regions.
- Server-rendered HTML must be usable before hydration (forms via Server Actions, links as `<a>`).
- Crawler/bot full renders also benefit assistive tech browsing with JS disabled.

## Responsive Design
- A single static shell serves all devices — implement responsive differences in CSS, not by reading `user-agent` headers (which forces request-time rendering).

## Performance
- Static shell from CDN → fast TTFB/FCP; streaming holes don't block paint.
- Each Suspense boundary is a hydration unit (selective hydration improves INP).
- Fallback and content must match dimensions to avoid CLS.
- Streaming requires no buffering in proxies/CDNs (`X-Accel-Buffering: no` for nginx); otherwise PPR's TTFB advantage disappears.

## Security
- Cached shells are shared: never put user-specific data in them.
- Nonce CSP forces dynamic rendering; plan CSP strategy with rendering strategy.
- Static export removes server-side auth entirely — protected content must not be exported.

## Testing
- `next build` output plus dev insights identify blocking routes.
- Playwright + `@next/playwright` `instant()` to assert shell contents on page load and client navigation.
- Test as a bot user agent (e.g., `Twitterbot`) to ensure full renders succeed.

## Tooling
- Next.js DevTools: Navigation Inspector, Instant Insights (16.3).
- `next build --debug-prerender` for readable prerender errors.
- Next.js Skill `next-cache-components-adoption`.

## Framework Notes
- PPR flags `experimental.ppr` and `experimental_ppr` were removed in 16.0; PPR is part of Cache Components.
- `runtime = 'edge'` is deprecated and unsupported with Cache Components; Node.js runtime is the default.
- React (Vite SPA) is CSR-only: everything renders after JS loads; pair with a prerender step or move to Next.js when SEO/TTFB matter.
- Platform "performance fidelity" varies: shell-at-CDN resume requires adapter support (Vercel native; others via Adapter API).

## AI Agent Guidance
- Determine whether `cacheComponents` is on before emitting segment config.
- Default layout pattern: no top-level awaits of request data; push into Suspense leaves.
- Before done: `next build` succeeds with no blocking-prerender errors; LCP element is outside Suspense; dynamic routes have `generateStaticParams` (≥1) when appropriate; verified a crawler-UA request renders.

## Examples
```tsx
// app/products/[id]/page.tsx
import { Suspense } from 'react'
import { notFound } from 'next/navigation'
import { cacheLife, cacheTag } from 'next/cache'

export async function generateStaticParams() {
  return (await getTopProductIds(50)).map((id) => ({ id }))
}

export default async function ProductPage(props: PageProps<'/products/[id]'>) {
  const { id } = await props.params
  if (!(await productExists(id))) notFound() // before any boundary → real 404
  return (
    <main>
      <ProductInfo id={id} />
      <Suspense fallback={<p>Checking stock…</p>}><Stock id={id} /></Suspense>
    </main>
  )
}

async function ProductInfo({ id }: { id: string }) {
  'use cache'
  cacheLife('days')
  cacheTag(`product:${id}`)
  const p = await getProduct(id)
  return <><h1>{p.name}</h1><p>{p.price}</p></>
}

async function Stock({ id }: { id: string }) {
  const { count } = await getInventory(id) // fresh per request
  return <p>{count} in stock</p>
}
```

## Related Skills
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — cache lifetimes
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — Suspense placement
- [nextjs-instant-navigation](../nextjs-instant-navigation/Skill.md) — App Shell and prefetching
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) — platform fidelity
- [hydration-strategies](../hydration-strategies/Skill.md) — selective hydration
- [lcp-optimization](../lcp-optimization/Skill.md) — keeping LCP in the shell

## Sources
- [Rendering Philosophy](https://nextjs.org/docs/app/guides/rendering-philosophy) — Official — component-level spectrum, infrastructure implications
- [Caching (Cache Components)](https://nextjs.org/docs/app/getting-started/caching) — Official — prerendering, static shell, random values, bots
- [ISR with Cache Components](https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components) — Official — App Shell upgrade, Pages mapping
- [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) — Official — segment config replacements, sync IO
- [Static Exports](https://nextjs.org/docs/app/guides/static-exports) — Official — supported/unsupported features
- [Streaming guide](https://nextjs.org/docs/app/guides/streaming) — Official — HTTP contract, web vitals
- [Content Security Policy guide](https://nextjs.org/docs/app/guides/content-security-policy) — Official — nonce/PPR incompatibility

## License / Usage Notes
Next.js MIT. Summarized and restructured from official docs; examples original.

## Quality Tier
S — Current model accurately mapped to legacy terminology with verified constraints from 16.3 docs.

## Status
Active

## Last Verified
2026-09-15
