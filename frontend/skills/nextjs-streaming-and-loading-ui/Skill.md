# Next.js Streaming and Loading UI

## Summary
The App Router streams HTML in chunks aligned to `<Suspense>` boundaries: the static shell (layouts, static content, fallbacks) is sent first, then each boundary's content streams in with an inline swap script and its RSC payload. `loading.tsx` wraps a page segment in Suspense; inline `<Suspense>` gives granular control. Error boundaries (`error.tsx`, and in 16.3 `catchError` from `next/error` with `retry()`) contain failures. Streaming fixes the HTTP status at 200 once started, and bots/crawlers receive fully rendered HTML instead.

## Category
Next.js

## Subcategories
Suspense, loading.tsx, streaming HTML, static shell, error.tsx, catchError, notFound status, bots, htmlLimitedBots, proxy buffering, skeletons, Web Vitals

## Problem It Solves
Pages that wait for the slowest query, full-page spinners hiding fast content, skeletons that cause layout shift, 404s returned as 200, LCP delayed by Suspense, and "streaming doesn't work" behind nginx/CDNs/compression.

## When To Use
- Any route with slow or request-time data.
- Designing loading states and error isolation per region.
- Diagnosing buffered responses in self-hosted infra.

## When Not To Use
- Choosing cache lifetimes (see [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md)).
- Loading-state visual/UX design principles (see [loading-states](../loading-states/Skill.md)).
- Instant client navigation validation (see [nextjs-instant-navigation](../nextjs-instant-navigation/Skill.md)).

## Core Principles
1. **Boundaries are streaming points and hydration units.** Sibling boundaries resolve independently.
2. **Place Suspense close to the async access,** not high in the tree.
3. **Status and headers are committed at first byte.** Call `notFound()`/`redirect()` and set cookies before any boundary suspends.
4. **Fallbacks must match final dimensions** to avoid CLS.
5. **Every hop must pass chunks through** (proxy, CDN, compression, serverless mode).
6. **A boundary may activate unexpectedly** (slow network/CPU); only add boundaries you accept as fallback points.

## Best Practices
- Use `loading.tsx` when nothing meaningful can render without the page's data; otherwise use inline Suspense.
- Remember: a layout reading uncached/runtime data is **not** covered by its sibling `loading.tsx` (loading wraps the page, inside the layout) — wrap that layout access in its own Suspense.
- Keep LCP elements outside boundaries; `preload` LCP images.
- Nest boundaries for progressive reveal (details → reviews).
- Pass `params`/`cookies()` promises into boundary children rather than awaiting at the top.
- Add `error.tsx` near risky segments; use `catchError` (16.3) for component-level boundaries that don't swallow `notFound`/`redirect` and can `retry()` Server Components.
- Put a fast existence check + `notFound()` before boundaries for real 404s.
- Self-hosting: `X-Accel-Buffering: no`; ensure load balancers/Lambda streaming mode; watch compression flush.
- Verify streaming with a chunk-timing script, not `curl` (buffers).

## Implementation Guidance

### loading.tsx vs Suspense
| | `loading.tsx` | `<Suspense>` |
|---|---|---|
| Scope | Whole page segment | Any subtree |
| Setup | Drop-in file | Explicit wrapper |
| Prefetched as instant fallback | Yes | Not by default (Partial Prefetching changes this) |
| Best for | Data-dependent pages with no useful shell content | Most pages; granular regions |

### Granular dashboard
```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react'
export default function Dashboard() {
  return (
    <main>
      <h1>Dashboard</h1>
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <Suspense fallback={<CardSkeleton title="Revenue" className="h-48" />}><Revenue /></Suspense>
        <Suspense fallback={<CardSkeleton title="Recent orders" className="h-48" />}><RecentOrders /></Suspense>
      </div>
      <Suspense fallback={<CardSkeleton title="Recommendations" className="h-96" />}><Recommendations /></Suspense>
    </main>
  )
}
```

### Skeleton with accessible status
```tsx
export function CardSkeleton({ title, className }: { title: string; className?: string }) {
  return (
    <section aria-busy="true" aria-labelledby={`${title}-h`} className={`rounded-lg border p-4 ${className ?? ''}`}>
      <h2 id={`${title}-h`}>{title}</h2>
      <span className="sr-only">Loading {title.toLowerCase()}…</span>
      <div className="mt-3 h-4 w-2/3 animate-pulse rounded bg-neutral-200 motion-reduce:animate-none" />
    </section>
  )
}
```

### Real 404 before streaming
```tsx
import { Suspense } from 'react'
import { notFound } from 'next/navigation'
export default async function PostPage(props: PageProps<'/post/[slug]'>) {
  const { slug } = await props.params
  if (!(await postExists(slug))) notFound()
  return <Suspense fallback={<PostSkeleton />}><PostContent slug={slug} /></Suspense>
}
```

### Component-level error boundary with retry (16.3)
```tsx
// app/_ui/section-boundary.tsx
'use client'
import { catchError, type ErrorInfo } from 'next/error'

function Fallback(props: { title: string }, { error, retry }: ErrorInfo) {
  return (
    <div role="alert">
      <p>{props.title} failed to load.</p>
      <button onClick={() => retry()}>Try again</button>
    </div>
  )
}
export default catchError(Fallback)

// usage (Server Component)
// <SectionBoundary title="Revenue"><Suspense fallback={…}><Revenue /></Suspense></SectionBoundary>
```

### Layout with runtime data not covered by loading.tsx
```tsx
// app/dashboard/layout.tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'
export default function Layout({ children }: LayoutProps<'/dashboard'>) {
  const cookieStore = cookies() // not awaited
  return (
    <div>
      <nav><Suspense fallback={<UserMenuSkeleton />}><UserMenu cookieStore={cookieStore} /></Suspense></nav>
      {children}
    </div>
  )
}
```

### Streaming infrastructure checklist
| Hop | Action |
|---|---|
| nginx | `proxy_buffering off` or `X-Accel-Buffering: no` |
| Load balancer | Chunked/HTTP2 streaming support (check ALB+Lambda) |
| AWS Lambda | Enable response streaming mode |
| CDN | Confirm pass-through of chunked responses |
| Compression | Ensure flushes; test with `Accept-Encoding: identity` |
| Safari | Buffers first 1024 bytes (only affects tiny responses) |

### Chunk observer (verification)
```js
// stream-observer.mjs
const res = await fetch(process.argv[2], { headers: { 'Accept-Encoding': 'identity' } })
const reader = res.body.getReader(); const start = Date.now(); let i = 0
for (;;) { const { done, value } = await reader.read(); if (done) break; console.log(`chunk ${i++} +${Date.now() - start}ms (${value.length} bytes)`) }
```

## Recommended Workflow
1. Identify slow/request-time regions; keep headings and LCP in the shell.
2. Add a Suspense boundary per independent region with dimension-matched fallbacks.
3. Add error isolation (`catchError` or `error.tsx`) for risky regions.
4. Move `notFound`/`redirect`/cookie writes before boundaries.
5. Inspect with Navigation Inspector and React DevTools Suspense panel.
6. Verify chunks through production infra and bot rendering with a bot UA.

## Patterns
- **Parallel siblings** for dashboards.
- **Nested progressive reveal** for detail pages.
- **Promise-to-client** chart streaming with `use()`.
- **Route-group-scoped `loading.tsx`** to apply skeleton to one page only.
- **Dynamic marker** (`<Suspense><Connection/></Suspense>`) to allow runtime `generateMetadata` under Cache Components.

## Anti-Patterns
- **One Suspense around the whole page** — everything waits for the slowest part. Fix: granular boundaries.
- **Skeletons of different size than content** — CLS. Fix: reserve space/min-height.
- **`notFound()` inside a streamed child** — 200 + `noindex` meta. Fix: check before boundaries.
- **Setting cookies/headers after streaming** — impossible. Fix: Server Action/Proxy/pre-boundary.
- **Expecting `loading.tsx` to cover the layout's awaits** — navigation blocks. Fix: Suspense in layout.
- **Hero image inside Suspense** — delayed LCP. Fix: shell.
- **Testing streaming with `curl`** — misleading buffering. Fix: chunk observer script.
- **Unnecessary boundaries** — React may show fallbacks on slow devices. Fix: add only intentional ones.

## Accessibility
- Fallbacks: `aria-busy="true"` on the region and visually hidden text; avoid announcing every skeleton via live regions.
- When content replaces a fallback, don't move focus unexpectedly (WCAG 3.2.2); if the user triggered the load, consider announcing completion politely.
- Respect `prefers-reduced-motion` for shimmer animations (WCAG 2.3.3).
- Error fallbacks use `role="alert"` and provide a keyboard-accessible retry.

## Responsive Design
- Fallback dimensions must match content at each breakpoint (use the same grid classes).
- Avoid rendering different boundary structures per breakpoint.

## Performance
- TTFB = shell render time; FCP decoupled from data.
- LCP depends on whether the LCP element is in the shell.
- Selective hydration per boundary improves INP.
- Early resource discovery: CSS/JS/font links arrive in the first chunk.

## Security
- Errors thrown mid-stream render the nearest boundary; production errors show a digest, not the message from Server Components — don't put sensitive info in thrown messages anyway.
- Bots receive full renders; ensure no data appears in bot HTML that wouldn't appear for users.

## Testing
- Playwright: throttle network, assert fallbacks then content; `@next/playwright` `instant()` for shell assertions.
- Assert HTTP 404 status for missing resources.
- Bot UA request returns complete HTML with metadata in `<head>`.
- Infra test with chunk observer through staging proxies.

## Tooling
- React DevTools Suspense panel; Next.js DevTools Navigation Inspector.
- vercel-labs streaming demo (streaming-demo.labs.vercel.dev).
- `htmlLimitedBots` config for bot detection customization.

## Framework Notes
- 16.3: `catchError` component-level boundaries with `retry()`; error.js receives `retry` in current docs (older versions used `reset`).
- Under Cache Components, missing boundaries around runtime/uncached access raise blocking-route insights/errors.
- React (Vite SPA): Suspense works for code/data loading on the client, but there is no HTML streaming; fallbacks show after JS loads.

## AI Agent Guidance
- Add boundaries at data leaves with sized skeletons; never wrap the LCP element.
- Always put `notFound()` checks before Suspense.
- Before done: throttled-network check shows progressive rendering, no CLS from fallbacks (Lighthouse), error boundary retry works, 404 status correct.

## Examples
```tsx
// app/blog/(list)/loading.tsx — route-group-scoped skeleton for /blog only
export default function Loading() {
  return (
    <ul aria-busy="true" className="space-y-3">
      {Array.from({ length: 6 }).map((_, i) => <li key={i} className="h-16 rounded bg-neutral-100" />)}
      <li className="sr-only">Loading posts…</li>
    </ul>
  )
}
```

## Related Skills
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md) — React mechanics
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md) — static shell
- [nextjs-instant-navigation](../nextjs-instant-navigation/Skill.md) — navigation fallbacks
- [loading-states](../loading-states/Skill.md) — UX design
- [error-states](../error-states/Skill.md) — error UX
- [cls-prevention](../cls-prevention/Skill.md) — layout stability
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — announcements

## Sources
- [Streaming guide](https://nextjs.org/docs/app/guides/streaming) — Official — mechanics, HTTP contract, bots, infra, verification, web vitals
- [Fetching Data](https://nextjs.org/docs/app/getting-started/fetching-data) — Official — loading.js vs Suspense, layout caveat
- [Error Handling](https://nextjs.org/docs/app/getting-started/error-handling) — Official — error.js retry, catchError, global-error
- [Next.js 16.3](https://nextjs.org/blog/next-16-3) — Official — custom error boundaries
- [Self-hosting guide](https://nextjs.org/docs/app/guides/self-hosting) — Official — streaming config

## License / Usage Notes
Next.js MIT. Summarized; examples original.

## Quality Tier
S — Detailed, version-precise (16.3 catchError), includes infrastructure verification and HTTP semantics.

## Status
Active

## Last Verified
2026-09-15
