# Bundle Optimization

## Summary
Bundle optimization reduces the JavaScript and CSS a React or Next.js app ships, parses and executes. You measure bundles with analyzers, remove or replace heavy dependencies, make tree-shaking work (ESM, `sideEffects`, no barrel traps), keep server-only code off the client (React Server Components), and enforce size budgets in CI. This skill covers analysis and reduction. Where the split points go belongs to [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md).

## Category
Performance

## Subcategories
Bundle analysis, tree-shaking, barrel files, dependency auditing, RSC client boundary, RSC payload, Vite 8/Rolldown, Turbopack, size-limit, modern build targets

## Problem It Solves
JS is the most expensive byte on the web: it costs download, parse, compile and execute time, and it's paid again on every low-end device. Oversized bundles hurt LCP (CSR apps), INP (hydration and long tasks at load) and data costs. Bundles grow gradually, one convenient import at a time: a date library, an icon pack, a whole UI kit, lodash, a Markdown parser that could run on the server.

## When To Use
- First-load JS for a route exceeds budget (see thresholds below) or grows between releases.
- Lighthouse/DevTools shows "Reduce unused JavaScript", "Legacy JavaScript", or long script evaluation tasks.
- Adding a new dependency above ~10 KB compressed.
- Migrating Pages Router → App Router, or webpack → Turbopack / Vite 8.

## When Not To Use
- Server-only bundle size, unless cold starts matter (then see `serverExternalPackages`).
- Micro-optimizing a few KB while field LCP/INP problems are caused by images, TTFB or third parties.

## Core Principles
1. **Measure compressed and uncompressed.** Transfer size (brotli) drives download; uncompressed size drives parse and execute cost.
2. **Server by default.** Anything that doesn't need state, effects or browser APIs belongs in a Server Component, and its dependencies never reach the client.
3. **Import the smallest thing.** Prefer per-function imports, native APIs (`Intl`, `structuredClone`, `fetch`, `URL`), and lightweight alternatives.
4. **Tree-shaking needs ESM plus side-effect-free modules.** CJS and side-effectful barrels defeat it.
5. **Budget in CI.** Any size win without a guard regresses within months.

## Best Practices
- Starting budgets for mobile-first sites: **≤ 150–200 KB brotli of first-load JS per route**, ≤ 50 KB critical CSS, and no single third-party dependency > 30 KB without sign-off. Content sites can aim lower; heavy apps should document an exception.
- Push `'use client'` to leaf components. A `'use client'` in a layout makes every import below it client code.
- Don't pass large data to Client Components as props. It's serialized into the RSC payload (inline `self.__next_f.push` scripts in HTML plus `.rsc` fetches on navigation). Pass IDs or pre-shaped minimal props.
- Add `import 'server-only'` to modules with secrets or heavy server libs so an accidental client import fails the build.
- Replace heavy libs: moment → `date-fns` / `Intl.DateTimeFormat` / Temporal (where available); lodash → native or `lodash-es` per-function; full icon packs → per-icon imports or SVG sprites; `uuid` → `crypto.randomUUID()`.
- Syntax highlighting, Markdown/MDX, and date/number formatting of static content: do it on the server.
- Target modern browsers. Vite 8's default `build.target` is `'baseline-widely-available'`; don't add legacy polyfills without analytics proof. In Next.js, keep `browserslist` modern.
- Remove unused deps and exports with `knip`; flag duplicates (two versions of the same lib) with the analyzer or `pnpm why`.
- Library authors: ship ESM, set `"sideEffects": false` (or list CSS files), and provide `exports` subpaths.

## Implementation Guidance

### Analyze
| Stack | Command/tool | Notes |
|---|---|---|
| Next.js 16.1+ (Turbopack) | `npx next experimental-analyze` (`--output` writes `.next/diagnostics/analyze`) | Filter by route, client/server, and trace import chains |
| Next.js (webpack builds) | `@next/bundle-analyzer` + `ANALYZE=true next build` | Webpack-only |
| Vite 8 (Rolldown) | `rollup-plugin-visualizer` or `vite-bundle-analyzer`; `build.license` for dependency inventory | Check plugin Rolldown compatibility |
| Any | Chrome DevTools Coverage panel | Unused bytes at runtime for a given page/interaction |
| Any | size-limit (`@size-limit/preset-app`) | CI budgets, optional execution-time measurement |
| Pre-install | bundlephobia / pkg-size.dev | Cost of a dependency before adding it |

### Decision table: large module found
| Finding | Fix |
|---|---|
| Heavy lib used only for static output | Move usage to a Server Component |
| Big client-only widget (editor, chart, map) not needed at first paint | `next/dynamic` / `React.lazy` on interaction or visibility |
| Icon/utility package pulled in whole | Next: `experimental.optimizePackageImports` (many popular libs auto-optimized); Vite: direct subpath imports |
| Internal barrel `index.ts` re-exports everything | Import from specific files; enable `optimizePackageImports` for internal packages in monorepos |
| Two versions of the same dep | Dedupe (`pnpm dedupe`, overrides/resolutions) |
| Polyfills for old browsers | Drop them or serve by target; check `browserslist` |
| JSON/locale data bundled | Load per locale dynamically; fetch large data instead of importing |
| Server package bundled unnecessarily (Next server) | `serverExternalPackages: ['pkg']` |

### Next.js config essentials
```ts
// next.config.ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  experimental: {
    optimizePackageImports: ['@acme/ui', 'react-icons'], // add internal barrels & non-default libs
  },
  serverExternalPackages: ['sharp-like-native-lib'],
};
export default nextConfig;
```

### Vite 8 config essentials
```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [react(), visualizer({ filename: 'stats.html', gzipSize: true, brotliSize: true })],
  build: {
    target: 'baseline-widely-available', // Vite 8 default; explicit for clarity
    chunkSizeWarningLimit: 250,          // kB uncompressed; tighter than the 500 default
    // build.rolldownOptions replaces the deprecated build.rollupOptions in Vite 8
  },
});
```

### size-limit budget
```json
// .size-limit.json
[
  { "name": "SPA entry", "path": "dist/assets/index-*.js", "limit": "120 kB", "brotli": true },
  { "name": "Button import cost", "path": "src/ui/index.ts", "import": "{ Button }", "limit": "6 kB" }
]
```
Run `npx size-limit` in CI; `andresz1/size-limit-action` comments PR diffs.

## Recommended Workflow
1. Record baselines: first-load JS per key route (Next build output / analyzer), entry chunk (Vite), and field INP/LCP.
2. Open the analyzer; list the top 10 modules by size on the client for the heaviest route.
3. For each: ask server-able? lazy-able? replaceable? duplicated? Apply the decision table.
4. Check Coverage in DevTools for the landing interaction to confirm unused code dropped.
5. Rebuild, compare analyzer output (`--output` snapshots), and re-trace load for script evaluation time.
6. Add or tighten size-limit budgets; fail CI on regression.

## Patterns
- **Server-render, client-enhance**: Server Component renders data, a tiny `'use client'` island handles interaction.
- **Dependency gate**: PR template requires bundle cost for new deps > 10 KB.
- **Lazy heavy leaf**: `const Chart = dynamic(() => import('./chart'), { loading: () => <ChartSkeleton /> })`.
- **Adapter module**: wrap a heavy lib behind `lib/date.ts` so replacing it is a one-file change.

## Anti-Patterns
- **`'use client'` at the top of `app/layout.tsx` or a providers file wrapping everything with heavy imports**: whole tree ships. Fix: providers file only imports providers; keep children as Server Components passed through `children`.
- **`import * as Icons from 'lucide-react'` / `import _ from 'lodash'`**: full package. Fix: named/subpath imports + `optimizePackageImports`.
- **Passing full DB rows to client components**: RSC payload bloat, duplicated in HTML. Fix: select fields; pass minimal props.
- **`next/dynamic` with `ssr: false` in a Server Component**: not allowed; and hiding SSR content hurts LCP. Fix: use inside a Client Component, only for browser-only widgets.
- **Relying on `chunkSizeWarningLimit` raises to silence warnings**. Fix: investigate; budget instead.
- **Shipping source maps publicly with secrets inlined**. Fix: never inline secrets; upload maps privately to error tracker.

## Accessibility
- Replacing a UI library to save bytes must not lose keyboard/ARIA behavior; prefer headless accessible primitives over hand-rolled widgets ([radix-ui-primitives](../radix-ui-primitives/Skill.md), [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md)).
- Lazy-loaded interactive widgets need accessible loading states (`aria-busy`, visible skeleton text).

## Responsive Design
- Don't ship desktop-only features (complex tables, charts) eagerly to mobile; lazy-load by media query or interaction.
- Low-end Android parse/execute is ~3–5× slower than desktop; budget for p75 mobile devices.

## Performance
- Every 100 KB of compressed JS ≈ several hundred ms of parse/compile/execute on mid-tier mobile (varies; measure with a trace).
- Code caching helps repeat visits only if chunk hashes are stable—avoid churning vendor chunks with every deploy.
- RSC reduces client JS but RSC payload size is still bytes in HTML and on navigation; keep props lean.

## Security
- `server-only` / `client-only` packages prevent leaking server code and secrets into client bundles.
- Only `NEXT_PUBLIC_*` (Next) / `VITE_*` (Vite) env vars are inlined into client code—never prefix secrets ([nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md)).
- Fewer dependencies = smaller supply-chain surface ([dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md)).

## Testing
- size-limit in CI on every PR; analyzer snapshot diff for large changes.
- Build-time test that `server-only` imports don't appear in client graph (Next build fails automatically).
- Lighthouse CI "total-byte-weight" / script-size assertions on key routes ([lighthouse-ci](../lighthouse-ci/Skill.md)).

## Tooling
- Next.js Bundle Analyzer for Turbopack (`next experimental-analyze`, v16.1+) — Experimental.
- `@next/bundle-analyzer` — Active (webpack builds only).
- Vite 8 (Rolldown bundler, stable Mar 2026); Rolldown 1.0 (May 2026) — Active.
- `rollup-plugin-visualizer`, `vite-bundle-analyzer` — Active (verify Rolldown plugin compatibility on upgrade).
- size-limit (+ size-limit-action) — Active.
- knip (unused files/deps/exports) — Active.
- Chrome DevTools Coverage — Active.

## Framework Notes
- **Next.js (App Router)**: first-load JS = shared framework chunks + route client components. Levers: Server Components, leaf `'use client'`, `optimizePackageImports`, `next/dynamic`, lean RSC props, `serverExternalPackages` for server cold start. Turbopack is the default bundler in Next 16. Route-level strategy lives in [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**: everything is client code; entry chunk size directly gates LCP. Use route-level lazy loading, `build.rolldownOptions` for chunk grouping (keep vendor chunks stable), and avoid CSS-in-JS runtimes where zero-runtime options exist ([css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md)). Component-level memoization is not a bundle concern—see [react-performance-optimization](../react-performance-optimization/Skill.md).

## AI Agent Guidance
- Do: run the analyzer (or read build output) before and after; report KB deltas (brotli) per route.
- Do: check a dependency's cost before adding it; prefer native APIs.
- Do: keep `'use client'` at leaves; add `import 'server-only'` to server utilities you create.
- Don't: add `@next/bundle-analyzer` to a Turbopack-only project expecting output—use `next experimental-analyze`.
- Don't: raise `chunkSizeWarningLimit` or disable warnings to "fix" size.
- Before declaring done: analyzer shows the module removed/moved, size-limit passes, app still works (lazy chunks load, no hydration errors), and no secret env vars leaked into client chunks (`grep` built assets).

## Examples
```tsx
// Before: whole page is client because of one interactive button
// app/blog/[slug]/page.tsx
// 'use client'  ← removed
import { codeToHtml } from 'shiki';          // stays on server
import { LikeButton } from './like-button';  // tiny client island

export default async function Post({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await getPost(slug);
  const html = await codeToHtml(post.code, { lang: 'tsx', theme: 'github-dark' });
  return (
    <article>
      <h1>{post.title}</h1>
      <div dangerouslySetInnerHTML={{ __html: html }} />
      <LikeButton postId={post.id} /> {/* pass an id, not the whole post */}
    </article>
  );
}
```

```ts
// lib/db.ts
import 'server-only';
export async function getPost(slug: string) { /* ... */ }
```

## Related Skills
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — where to split
- [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md) — budgets and enforcement
- [hydration-strategies](../hydration-strategies/Skill.md) — reducing hydrated JS
- [react-server-components](../react-server-components/Skill.md) — server/client boundary
- [nextjs-performance](../nextjs-performance/Skill.md) — Next.js route-level performance
- [frontend-build-tooling](../frontend-build-tooling/Skill.md) — Vite/Turbopack configuration
- [third-party-script-management](../third-party-script-management/Skill.md) — non-bundled JS weight

## Sources
- [Next.js: Optimizing package bundling](https://nextjs.org/docs/app/guides/package-bundling) — Official — Turbopack analyzer, `@next/bundle-analyzer`, optimizePackageImports, serverExternalPackages (docs v16.3.5)
- [Vite 8 announcement](https://vite.dev/blog/announcing-vite8) — Official — Rolldown as unified bundler
- [Vite build options](https://vite.dev/config/build-options) — Official — `build.rolldownOptions`, target default, chunkSizeWarningLimit, license
- [size-limit](https://github.com/ai/size-limit) — Open Source — config format, presets, CI action
- [web.dev: Reduce JavaScript payloads with code splitting](https://web.dev/articles/reduce-javascript-payloads-with-code-splitting) — Official — cost of JS
- [Addy Osmani: The Cost of JavaScript](https://medium.com/@addyosmani/the-cost-of-javascript-in-2018-7d8950fbb5d4) — Community — parse/execute cost model (older, principle still valid)

## License / Usage Notes
Next.js docs MIT/CC; Vite MIT; size-limit MIT. Summarized; examples original.

## Quality Tier
A — Current official tooling verified (Next 16.3 docs, Vite 8); budget numbers are pragmatic starting points, not official standards.

## Status
Active

## Last Verified
2026-09-15
