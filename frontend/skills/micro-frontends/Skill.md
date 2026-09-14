# Micro-Frontends

## Summary
Splitting a frontend into independently developed and deployed parts owned by different teams, for a React + Next.js stack as of Sept 2026. Covers when micro-frontends are justified, integration options (Next.js Multi-Zones, Module Federation 2.0 in React SPAs via Rsbuild/Rspack or Vite, build-time packages, iframes), shared dependencies, cross-app communication, routing, styling isolation, and the critical status fact: **Module Federation for Next.js (`@module-federation/nextjs-mf`) is end-of-life — App Router is unsupported** — so Next.js apps should use Multi-Zones.

## Category
Architecture

## Subcategories
Multi-Zones, Module Federation 2.0, runtime vs build-time integration, shared dependencies, app shell, cross-app communication, independent deployment, import maps

## Problem It Solves
Large organizations with many teams on one frontend hit coordination limits: shared release trains, merge conflicts, long builds, and one team's regression blocking everyone. Micro-frontends allow teams to deploy independently — at the cost of runtime complexity, payload duplication, and consistency risks.

## When To Use
- Multiple autonomous teams (typically 4+) own distinct product areas and need independent release cadence.
- Incremental migration of a legacy frontend (strangler fig) to React/Next.js.
- Distinct product sections with little shared state (marketing, docs, dashboard, checkout).

## When Not To Use
- One or two teams: a modular monolith or monorepo with boundaries is far cheaper.
- To "fix" poor code organization — you'll get a distributed monolith.
- When pages need heavy shared client state or seamless soft navigation across every section.
- Next.js App Router apps expecting runtime component federation — not supported by Module Federation; use Multi-Zones or packages.

## Core Principles
1. **Split by business domain/route, not by component.** Vertical slices owned end-to-end by one team.
2. **Independent deployability is the point;** if releases still need coordination, reconsider.
3. **Communicate as little as possible:** URL, custom events, and explicit contracts; no shared global stores.
4. **Share a design system and tokens, not business logic.**
5. **Contracts are versioned** (routes, events, exposed modules) and tested.
6. **Platform team owns the shell, integration, observability, and performance budgets.**
7. **Prefer the least dynamic integration that meets the need** (zones/links < build-time packages < runtime federation).

## Best Practices
- Integration decision:
  | Approach | Independent deploy | Soft nav across parts | Tech fit (React/Next) | Complexity |
  |---|---|---|---|---|
  | Next.js Multi-Zones (path-based apps under one domain) | Yes | No (hard nav between zones) | Official Next.js | Low–Medium |
  | Build-time npm/workspace packages | No (consumer redeploys) | Yes | Any | Low |
  | Module Federation 2.0 (React SPA host + remotes) | Yes | Yes | Rsbuild/Rspack, Vite 8, webpack; **not Next.js App Router** | High |
  | iframes | Yes | Awkward | Any | Medium (isolation strong, UX/a11y costs) |
  | Server-side composition (edge/proxy includes) | Yes | No | Custom | Medium–High |
- Next.js: put pages frequently visited together in the same zone to avoid hard navigations; link across zones with `<a>`, not `<Link>`.
- Multi-Zones: each non-default zone sets `assetPrefix`; the main app (or any proxy/CDN) routes paths with `rewrites`; use `proxy.ts` only for dynamic routing decisions (e.g., flag-based migration); set `experimental.serverActions.allowedOrigins` to the user-facing domain.
- Module Federation 2.0 (stable Feb 2026): runtime decoupled from bundler (webpack, Rspack, Rsbuild, Rollup/Rolldown, Vite, Metro), manifest-based remotes, type hints generation (`dts`), shared dependency tree shaking, Node runtime support for SSR/BFF consumption.
- Share `react`/`react-dom` as singletons with compatible `requiredVersion`; share the design system as a singleton only if it holds context; otherwise let remotes bundle their own copy.
- Each part owns its backend-for-frontend or API client; authentication handled centrally (shared cookie session on the same domain works naturally with zones).
- Styling isolation: CSS Modules/Tailwind with prefixes or `@layer` per app; shared design tokens via CSS variables; avoid global resets in remotes.
- Observability: consistent release tagging per part; route-to-owner mapping for alerts.
- Performance budget per part; monitor duplicated dependencies across zones/remotes.
- Fallbacks: remote load failures render an error boundary fallback, not a blank shell.

## Implementation Guidance

### Next.js Multi-Zones (recommended for Next.js)
```ts
// apps/blog/next.config.ts — a non-default zone
import type { NextConfig } from 'next';
const config: NextConfig = {
  assetPrefix: '/blog-static',
  experimental: { serverActions: { allowedOrigins: ['www.example.com'] } },
};
export default config;
```
```ts
// apps/main/next.config.ts — default zone routes other zones' paths
import type { NextConfig } from 'next';
const BLOG = process.env.BLOG_ORIGIN!; // e.g. https://blog-zone.internal.example.com
const config: NextConfig = {
  async rewrites() {
    return [
      { source: '/blog', destination: `${BLOG}/blog` },
      { source: '/blog/:path+', destination: `${BLOG}/blog/:path+` },
      { source: '/blog-static/:path+', destination: `${BLOG}/blog-static/:path+` },
    ];
  },
  experimental: { serverActions: { allowedOrigins: ['www.example.com'] } },
};
export default config;
```
```tsx
// Cross-zone link: plain anchor (hard navigation)
<a href="/blog/launch-notes">Launch notes</a>
// Same-zone link: next/link
<Link href="/pricing">Pricing</Link>
```
Share header/footer via a workspace package (`@acme/shell-ui`) so zones look identical; version skew is acceptable briefly but track it.

### Module Federation 2.0 with Rsbuild (React SPA host + remote)
```ts
// remote: apps/orders/rsbuild.config.ts
import { defineConfig } from '@rsbuild/core';
import { pluginReact } from '@rsbuild/plugin-react';
import { pluginModuleFederation } from '@module-federation/rsbuild-plugin';
export default defineConfig({
  plugins: [
    pluginReact(),
    pluginModuleFederation({
      name: 'orders',
      exposes: { './OrdersApp': './src/OrdersApp.tsx' },
      shared: {
        react: { singleton: true, requiredVersion: '^19.0.0' },
        'react-dom': { singleton: true, requiredVersion: '^19.0.0' },
      },
      dts: true,
    }),
  ],
  server: { port: 3001 },
});
```
```ts
// host: apps/shell/rsbuild.config.ts
pluginModuleFederation({
  name: 'shell',
  remotes: { orders: 'orders@https://orders.example.com/mf-manifest.json' },
  shared: { react: { singleton: true }, 'react-dom': { singleton: true } },
});
```
```tsx
// host: lazy remote with boundary
import { lazy, Suspense } from 'react';
import { ErrorBoundary } from 'react-error-boundary';
const OrdersApp = lazy(() => import('orders/OrdersApp'));
export function OrdersRoute() {
  return (
    <ErrorBoundary fallback={<p role="alert">Orders is temporarily unavailable.</p>}>
      <Suspense fallback={<PageSkeleton />}><OrdersApp basePath="/orders" /></Suspense>
    </ErrorBoundary>
  );
}
```
Vite 8 hosts/remotes: use the Module Federation Vite plugin (`@module-federation/vite`) — verify maturity for your use case; Vite 8's Rolldown integration lists Module Federation support as a newly unlocked capability.

### Cross-app communication contract
```ts
// packages/mfe-contracts/src/events.ts
export type MfeEvents = {
  'cart:item-added': { sku: string; quantity: number };
  'auth:session-expired': Record<string, never>;
};
export function emit<K extends keyof MfeEvents>(type: K, detail: MfeEvents[K]) {
  window.dispatchEvent(new CustomEvent(type, { detail }));
}
export function on<K extends keyof MfeEvents>(type: K, handler: (d: MfeEvents[K]) => void) {
  const listener = (e: Event) => handler((e as CustomEvent<MfeEvents[K]>).detail);
  window.addEventListener(type, listener);
  return () => window.removeEventListener(type, listener);
}
```
Prefer URL state and server data over events; events only for cross-part notifications.

### Status table (Sept 2026)
| Technology | Status | Guidance |
|---|---|---|
| Next.js Multi-Zones | Active, official | Default for Next.js |
| Module Federation 2.0 (`@module-federation/enhanced`, rsbuild/vite plugins) | Stable (Feb 2026) | React SPAs, Rsbuild/Rspack/Vite hosts |
| `@module-federation/nextjs-mf` | End-of-life (announced Nov 2024; functional until ~mid/end 2026; App Router never supported) | Do not adopt; migrate |
| single-spa | Maintenance slowdown (v7 work paused after Sept 2025) | Brownfield only |
| Native Federation (import maps, ESM) | Community, active | Bundler-agnostic option; evaluate |
| iframes | Stable platform feature | Isolation for untrusted/legacy content |

## Recommended Workflow
1. Validate the need: team topology, release pain, domain boundaries. Try monorepo boundaries first.
2. Map routes to owning teams; choose integration per boundary (zones for Next.js).
3. Stand up the platform: shell/default zone, shared design system package, contracts package, observability conventions.
4. Migrate one low-risk section (strangler fig) behind routing rules.
5. Add contract tests and cross-zone E2E journeys.
6. Set per-part performance budgets and dependency duplication monitoring.
7. Review quarterly: merge parts that always change together.

## Patterns
- **Route-based zones** with shared shell UI package.
- **App shell + lazy remotes** with error boundaries (MF in SPA).
- **Strangler fig migration** via proxy rewrites toggled by flags.
- **Contracts package** for events/types; semantic versioning.
- **BFF per micro-frontend** behind the same domain.
- **Shared session cookie** on the parent domain (`__Host-` cookies are per host — use a single public host for zones).

## Anti-Patterns
- **Micro-frontends for a single team** — overhead without benefit. Fix: monorepo + boundaries.
- **Adopting nextjs-mf for App Router** — unsupported/EOL. Fix: Multi-Zones or packages.
- **Shared global Redux/Zustand store across parts** — tight coupling. Fix: URL/server data/events.
- **Component-level federation everywhere** (button from remote) — waterfalls and version chaos. Fix: federate at page/section level; share UI via packages.
- **Non-singleton React** — hooks errors, duplicate contexts. Fix: `singleton: true` for react/react-dom.
- **`<Link>` across zones** — broken prefetch/soft nav. Fix: `<a>`.
- **No fallback when a remote fails** — blank shell. Fix: boundary + telemetry.
- **Divergent design system versions for months** — inconsistent UX. Fix: version-lag policy and dashboards.

## Accessibility
- Consistent landmarks, skip links, and heading structure across parts (shared shell).
- On hard navigation between zones, standard page-load semantics apply; within SPA hosts, remotes must announce route changes and manage focus (WCAG 2.4.3, 4.1.3).
- iframes require `title` and must not trap keyboard focus.
- Accessibility ownership: a platform-level a11y test suite runs across all parts.

## Responsive Design
- Shared layout primitives and breakpoints/tokens from the design system; remotes must be container-aware since the shell controls available space.

## Performance
- Watch duplicate dependencies (each zone ships its own React runtime; MF shares singletons).
- Hard navigations between zones cost full page loads — group related routes; use `<link rel="prefetch">`/Speculation Rules for likely cross-zone navigations.
- Remote manifests and chunks: cache-control with hashed filenames; preload critical remotes.
- MF 2.0 shared dependency tree shaking reduces shared payloads.

## Security
- Only load remotes from trusted, allowlisted origins; CSP `script-src` must include them (with `strict-dynamic` + nonce, loader scripts inherit trust).
- Server Actions across zones require `allowedOrigins`.
- Cookies: define domain/path scope deliberately; avoid broad `Domain=` cookies unless required.
- Untrusted third-party UIs: iframes with `sandbox`, strict `postMessage` origin checks.

## Testing
- Unit/component tests per part; contract tests for exposed modules and events (consumer-driven).
- E2E journeys spanning zones/remotes in a production-like environment.
- Synthetic monitoring for remote availability; chaos test remote failures.

## Tooling
- Next.js 16 Multi-Zones — Active (official guide).
- Module Federation 2.0 (`@module-federation/enhanced`, `@module-federation/rsbuild-plugin`, `@module-federation/vite`) — Active/stable runtime; plugin maturity varies.
- Rsbuild/Rspack 2.x — Active (strong MF support).
- `@module-federation/nextjs-mf` — Deprecated/EOL.
- single-spa — Low activity; brownfield.
- Native Federation — Community.
- Turborepo/Nx — monorepo orchestration for multiple zones.

## Framework Notes
- **React (SPA host):** Module Federation 2.0 via Rsbuild/Rspack or Vite 8 plugin; React Router/TanStack Router in the host maps route prefixes to lazy remotes; each remote receives `basePath` and uses a nested router.
- **Next.js App Router:** use Multi-Zones for independent deployment; share UI via workspace packages (`transpilePackages`); use `rewrites` for routing and `proxy.ts` for dynamic migration routing; Server Actions `allowedOrigins`. Do not use Module Federation inside Next.js App Router apps.
- **Mixed:** a Next.js default zone can route a path prefix to a Vite React SPA (zones are framework-agnostic at the HTTP level) — serve the SPA under its own asset prefix.

## AI Agent Guidance
- Confirm the integration style in use (zones vs MF vs packages) before editing; never introduce `nextjs-mf` into a Next.js App Router project.
- Do: use `<a>` for cross-zone links, keep contracts typed in the contracts package, wrap remotes in error boundaries, share React as singleton in MF configs.
- Don't: import code across zones directly, share global stores, or federate small components.
- Verify: cross-zone navigation works in a production-like build, remote failure shows fallback, no duplicate React errors, E2E journey passes.

## Examples
```ts
// apps/main/src/proxy.ts — flag-driven migration of /account to new zone
import { NextResponse, type NextRequest } from 'next/server';
export async function proxy(req: NextRequest) {
  if (req.nextUrl.pathname.startsWith('/account') && (await isEnabled('account-new-zone', req))) {
    return NextResponse.rewrite(new URL(`${req.nextUrl.pathname}${req.nextUrl.search}`, process.env.ACCOUNT_ZONE_ORIGIN));
  }
}
export const config = { matcher: ['/account/:path*'] };
```

## Related Skills
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — often the better alternative, or the repo hosting zones
- [frontend-architecture-principles](../frontend-architecture-principles/Skill.md) — when not to distribute
- [frontend-build-tooling](../frontend-build-tooling/Skill.md) — Rsbuild/Vite federation builds
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) — deploying zones
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — dynamic routing
- [design-system-architecture](../design-system-architecture/Skill.md) — shared UI across parts
- [content-security-policy](../content-security-policy/Skill.md) — allowing remote origins

## Sources
- [Next.js: Multi-Zones guide](https://nextjs.org/docs/app/guides/multi-zones) — Official — assetPrefix, rewrites, linking, Server Actions allowedOrigins
- [Module Federation 2.0 stable release](https://module-federation.io/blog/v2-stable-version) — Official — runtime decoupling, bundler support
- [InfoQ: Module Federation 2.0 reaches stable](https://www.infoq.com/news/2026/04/module-federation-2-stable/) — Community — release summary
- [module-federation/core issue #3153 (nextjs-mf end-of-life)](https://github.com/module-federation/core/issues/3153) — Official repo — deprecation, App Router unsupported
- [Martin Fowler: Micro Frontends](https://martinfowler.com/articles/micro-frontends.html) — Community (respected) — integration approaches, communication, downsides
- [Vite 8 announcement](https://vite.dev/blog/announcing-vite8) — Official — Module Federation capability via Rolldown
- [single-spa recommended setup](https://single-spa.js.org/docs/recommended-setup/) — Open Source — import maps approach

## License / Usage Notes
Summarized; the nextjs-mf maintainer's strongly worded opinion is noted as context, not endorsed. Module Federation MIT; Next.js MIT.

## Quality Tier
A — official Next.js and Module Federation sources verified Sept 2026; Vite MF plugin maturity not independently verified.

## Status
Active

## Last Verified
2026-09-15
