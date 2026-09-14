# Next.js Performance

## Summary
A practical performance playbook for Next.js 16.3 apps: maximize the prerendered static shell (Cache Components + Suspense), keep client JavaScript small (Server Components, `'use client'` at leaves, `optimizePackageImports`, lazy loading), eliminate data waterfalls, optimize LCP/CLS/INP with `next/image`, `next/font`, `next/script`, measure with the Turbopack Bundle Analyzer (`next experimental-analyze`), Lighthouse, and `useReportWebVitals`, and use the React Compiler. It also covers build/dev performance (Turbopack defaults, file-system cache, memory eviction, TypeScript 7).

## Category
Next.js

## Subcategories
Core Web Vitals, bundle size, waterfalls, lazy loading, next/script, third-party scripts, React Compiler, bundle analyzer, Turbopack, build performance, prefetching

## Problem It Solves
Slow TTFB from blocking data, large client bundles from mis-placed client boundaries and barrel imports, LCP images inside Suspense, sequential awaits, third-party scripts blocking the main thread, and slow builds/dev servers in large repos.

## When To Use
- Performance audits and regressions on Next.js routes.
- Before launch (production checklist) and when adding heavy dependencies.
- Large monorepos with slow `next dev`/`next build`.

## When Not To Use
- Generic browser rendering/profiling techniques (see [performance-profiling-devtools](../performance-profiling-devtools/Skill.md)).
- Deep cache semantics (see [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md)).
- Navigation-instantness specifics (see [nextjs-instant-navigation](../nextjs-instant-navigation/Skill.md)).

## Core Principles
1. **Measure first, in production mode.** `next build && next start` + field data; dev is not representative (no prefetching, HMR overhead).
2. **Eliminate waterfalls before micro-optimizing** (highest impact per vercel-labs react-best-practices ordering).
3. **Ship less JavaScript.** Server Components by default; client islands small; heavy transforms on the server.
4. **Grow the static shell.** Cache what can be stale; stream the rest; push dynamic access down.
5. **Protect LCP and CLS structurally**: LCP element in the shell, sized media, matching skeletons.

## Best Practices
- Start parallel fetches together (`Promise.all`, preload pattern) and give independent sections their own Suspense boundaries.
- Keep LCP elements outside Suspense; `preload` the LCP image; correct `sizes`.
- Use `experimental.optimizePackageImports` for icon/utility libraries not auto-optimized.
- Lazy-load heavy client widgets with `next/dynamic` (`ssr: false` only inside Client Components) or `import()` on interaction.
- Run syntax highlighting/markdown/chart data prep in Server Components.
- Load third-party scripts with `next/script` strategies (`afterInteractive`, `lazyOnload`) or `@next/third-parties` wrappers.
- Enable `reactCompiler: true` (stable in 16; experimental Rust compiler via `experimental.turbopackRustReactCompiler` in 16.3) to cut unnecessary re-renders — measure build time impact.
- Disable prefetching for huge link lists (`prefetch={false}` or hover-prefetch) to reduce server load.
- Upgrade to 16.3 for SSR throughput (+~22% via Node streams), dev memory eviction, and persistent build cache.
- Report Web Vitals with `useReportWebVitals` to your RUM backend when not on Vercel Speed Insights.

## Implementation Guidance

### Priority checklist (highest impact first)
| Area | Check | Tool |
|---|---|---|
| Waterfalls | Sequential awaits, parent-blocking fetches | Code review, React DevTools Suspense panel |
| Static shell | Top-level `await cookies()/params` in layouts | Dev insights, Navigation Inspector |
| Bundle | Client modules > expected; large libs in client | `next experimental-analyze` |
| LCP | Hero in Suspense, missing preload/sizes | Lighthouse, DevTools |
| CLS | Unsized images, font swap, skeleton mismatch | Lighthouse, Web Vitals |
| INP | Long hydration, heavy handlers, third-party scripts | Performance panel, RUM |
| Prefetch cost | Many links to dynamic routes | Network panel, server metrics |

### Parallel data
```tsx
export default async function Artist(props: PageProps<'/artist/[id]'>) {
  const { id } = await props.params
  const artistP = getArtist(id)
  const albumsP = getAlbums(id)
  const [artist, albums] = await Promise.all([artistP, albumsP])
  return <><h1>{artist.name}</h1><Albums list={albums} /></>
}
```

### Lazy client widget
```tsx
'use client'
import dynamic from 'next/dynamic'
import { useState } from 'react'

const Chart = dynamic(() => import('./revenue-chart'), { ssr: false, loading: () => <div className="h-64" aria-busy="true" /> })

export function RevenuePanel() {
  const [show, setShow] = useState(false)
  return (
    <section>
      <button onClick={() => setShow(true)} aria-expanded={show}>Show chart</button>
      {show && <Chart />}
    </section>
  )
}
```

### Config levers
```ts
// next.config.ts
import type { NextConfig } from 'next'
const nextConfig: NextConfig = {
  cacheComponents: true,
  reactCompiler: true,
  experimental: {
    optimizePackageImports: ['@acme/icons'],
    // turbopackRustReactCompiler: true, // experimental (16.3)
  },
  serverExternalPackages: ['some-native-module'],
}
export default nextConfig
```

### Third-party scripts
```tsx
// app/layout.tsx
import { GoogleTagManager } from '@next/third-parties/google'
import Script from 'next/script'

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en">
      <body>
        {children}
        <GoogleTagManager gtmId="GTM-XXXX" />
        <Script src="https://widget.example.com/chat.js" strategy="lazyOnload" />
      </body>
    </html>
  )
}
```

### Web Vitals reporting
```tsx
'use client'
import { useReportWebVitals } from 'next/web-vitals'
export function WebVitals() {
  useReportWebVitals((metric) => {
    navigator.sendBeacon('/api/vitals', JSON.stringify({ name: metric.name, value: metric.value, id: metric.id, route: location.pathname }))
  })
  return null
}
```

### Bundle analysis
```bash
npx next experimental-analyze            # interactive, Turbopack (16.1+)
npx next experimental-analyze --output   # writes .next/diagnostics/analyze
ANALYZE=true npm run build               # @next/bundle-analyzer (webpack builds)
```
Note: `next build` no longer prints "First Load JS"/size columns (removed in v16 as inaccurate for RSC); use the analyzer and Lighthouse.

## Recommended Workflow
1. Capture baseline: field CWV (RUM/CrUX), Lighthouse on `next start`, analyzer output.
2. Fix waterfalls and shell blockers (dev insights).
3. Reduce client JS (boundaries, lazy loading, package imports).
4. Fix LCP/CLS media and fonts.
5. Tame third-party scripts.
6. Enable React Compiler; re-measure.
7. Add budgets (Lighthouse CI) and `instant()` E2E tests to prevent regressions.

## Patterns
- **Server-side heavy lifting** (shiki, markdown, CSV parsing) with HTML output.
- **Hover-prefetch link** for dense tables.
- **Deferred below-the-fold client widgets** via `next/dynamic`.
- **Cached expensive aggregations** with `'use cache'` + `cacheLife('minutes')`.
- **`after()`** for analytics/logging post-response.

## Anti-Patterns
- **Sequential awaits of independent data** — waterfall. Fix: start promises together.
- **`'use client'` on a page to use one hook** — hydrates everything. Fix: extract a leaf.
- **Barrel imports from large libraries in Client Components** — bloat. Fix: `optimizePackageImports` or direct paths.
- **`ssr: false` in a Server Component** — error. Fix: move into a Client Component.
- **Dynamic import of a Client Component from a Server Component expecting code splitting** — not supported. Fix: do the dynamic import inside a Client Component.
- **Fetching your own Route Handler from Server Components** — extra round trip. Fix: call data function directly.
- **Chasing dev-mode timings** — misleading. Fix: measure on production build.
- **Relying on removed "First Load JS" metric** — gone in v16. Fix: analyzer/Lighthouse.

## Accessibility
- Lazy-loaded widgets need placeholders with reserved space and `aria-busy`; don't lazy-load content required to understand the page.
- Performance tricks must not remove focus styles or reduce motion preferences; honor `prefers-reduced-motion` in animations.
- Faster INP benefits keyboard and switch users with slower devices.

## Responsive Design
- Test on mid-tier mobile hardware/network throttling; `sizes` and image variants matter most on mobile.
- Avoid shipping desktop-only heavy components to mobile — lazy-load behind interaction.

## Performance
- Targets (good): LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 at p75.
- Each Suspense boundary is a hydration unit (selective hydration).
- 16.3 dev: memory eviction up to 90% less RAM; build: persistent Turbopack cache; type check: TypeScript 7 via `typescript@^7`.

## Security
- Third-party scripts are both a performance and supply-chain risk; load only vetted scripts, use CSP, and consider SRI (`experimental.sri`).
- `serverExternalPackages` changes bundling of server deps — keep them patched.

## Testing
- Lighthouse CI with budgets on key routes (production build).
- Playwright `instant()` tests for critical navigations.
- RUM dashboards by route; alert on p75 regressions.
- Analyzer output diff in PRs (`--output`, compare directories).

## Tooling
- `next experimental-analyze`, `@next/bundle-analyzer`.
- `@next/third-parties`, `next/script`.
- Vercel Speed Insights/Analytics, `useReportWebVitals`.
- React DevTools Profiler & Suspense panel; Next.js DevTools (Instant Insights, Navigation Inspector).
- vercel-labs/agent-skills `react-best-practices` (40+ rules prioritized: waterfalls, bundle size, server performance, client fetching, re-renders).

## Framework Notes
- Turbopack is default for dev and build since 16.0; `--webpack` opts out (custom webpack config fails Turbopack builds unless migrated).
- `import.meta.glob` (16.3) replaces ad-hoc fs globbing with HMR-friendly imports.
- React (Vite SPA): performance levers are route-level code splitting, `React.lazy`, prefetching data in loaders, and image CDNs; no static shell/streaming — consider Next.js for content-heavy pages.

## AI Agent Guidance
- Profile before changing; cite the metric you are improving.
- Prefer structural fixes (boundaries, parallelism, caching) over memo micro-optimizations; enable React Compiler instead of manual `useMemo`.
- Before done: production build Lighthouse run on affected routes, analyzer check for new client deps, no LCP element inside Suspense, no sequential independent awaits.

## Examples
```tsx
// Preload pattern to start work before a blocking check
import Item, { preload } from './item'
export default async function Page(props: PageProps<'/item/[id]'>) {
  const { id } = await props.params
  preload(id)                       // starts getItem(id) (memoized)
  const allowed = await checkAccess(id)
  return allowed ? <Item id={id} /> : null
}
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md) — metric definitions
- [bundle-optimization](../bundle-optimization/Skill.md) — bundle strategy
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — lazy loading
- [third-party-script-management](../third-party-script-management/Skill.md) — scripts
- [react-compiler](../react-compiler/Skill.md) — compiler adoption
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — LCP/CLS media
- [nextjs-instant-navigation](../nextjs-instant-navigation/Skill.md) — navigation speed
- [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md) — budgets

## Sources
- [Production checklist](https://nextjs.org/docs/app/guides/production-checklist) — Official — optimization checklist
- [Optimizing package bundling](https://nextjs.org/docs/app/guides/package-bundling) — Official — analyzer, optimizePackageImports, serverExternalPackages
- [Lazy loading](https://nextjs.org/docs/app/guides/lazy-loading) — Official — next/dynamic rules
- [Fetching Data](https://nextjs.org/docs/app/getting-started/fetching-data) — Official — parallel/preload patterns
- [Streaming guide](https://nextjs.org/docs/app/guides/streaming) — Official — web vitals impact
- [Next.js 16.3](https://nextjs.org/blog/next-16-3) — Official — SSR throughput, memory, TS7, Rust compiler
- [Upgrading to v16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — removed size metrics, React Compiler stable
- [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) — Open Source/Community — react-best-practices priority categories

## License / Usage Notes
Next.js MIT; agent-skills repository open source (check its license). Summarized; examples original.

## Quality Tier
A — Current and actionable; community rule set referenced at category level only (full rules not fetched).

## Status
Active

## Last Verified
2026-09-15
