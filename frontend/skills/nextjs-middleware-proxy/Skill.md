# Next.js Proxy (formerly Middleware)

## Summary
`proxy.ts` (renamed from `middleware.ts` in Next.js 16) runs before routes render and can redirect, rewrite, set request/response headers and cookies, or return a response directly. It runs on the **Node.js runtime** (not configurable) and should be a thin network-boundary layer: locale redirects, optimistic auth redirects, CSP nonces, A/B rewrites, CORS. `middleware.ts` still works only for Edge-runtime use cases and is deprecated.

## Category
Next.js

## Subcategories
proxy.ts, middleware.ts migration, matcher, NextRequest, NextResponse, rewrites, redirects, headers, cookies, CORS, waitUntil

## Problem It Solves
Middleware was overused as an Express-style layer (DB calls, full auth, business logic), ran on every asset request because of missing matchers, blocked CSS/JS, leaked internal headers to clients, and was trusted as the sole auth barrier — a pattern that has produced real security incidents. The rename signals "last resort, network boundary only".

## When To Use
- Locale detection and redirect to `/[lang]` paths.
- Optimistic session-cookie checks to redirect unauthenticated users away from protected sections.
- Generating per-request CSP nonces.
- Rewrites for A/B tests, multi-tenant host routing, legacy URL maps with logic.
- CORS preflight for API paths; lightweight request logging with `event.waitUntil`.

## When Not To Use
- Database lookups or secure authorization — do it in the Data Access Layer, Server Actions, and Route Handlers.
- Static redirects/rewrites/headers — use `next.config` `redirects()`/`rewrites()`/`headers()`.
- Heavy computation or large dependencies (runs on every matched request, including prefetches).
- Static exports (unsupported).

## Core Principles
1. **Thin and fast.** Read cookies/headers/URL; decide; return. No DB.
2. **Never the only security layer.** Matcher changes or moved Server Actions silently drop coverage.
3. **Always scope with `matcher`.** Without it, proxy runs for `_next/static`, `_next/image`, and `public/` assets.
4. **Upstream vs downstream headers.** `NextResponse.next({ request: { headers } })` sends to your app; `response.headers.set` sends to the client.
5. **One file, one function.** Export `proxy` (named) or default; compose internally.

## Best Practices
- Rename via codemod: `npx @next/codemod@canary middleware-to-proxy .` (also renames `skipMiddlewareUrlNormalize` → `skipProxyUrlNormalize`).
- Use a negative-lookahead matcher excluding `api` (if not needed), `_next/static`, `_next/image`, and metadata files.
- Skip prefetch requests where work isn't needed using `missing: [{ type: 'header', key: 'next-router-prefetch' }, { type: 'header', key: 'purpose', value: 'prefetch' }]`.
- Keep matcher values static literals (dynamic values are ignored).
- Use `NextResponse.rewrite()` rather than custom `fetch` proxies so RSC headers propagate.
- Avoid large headers (431 errors).
- Unit-test with `unstable_doesProxyMatch` and `isRewrite`/`getRewrittenUrl` from `next/experimental/testing/server`.
- Check library compatibility: next-intl (`createMiddleware` in `proxy.ts`), Clerk (`clerkMiddleware()` in `proxy.ts`), Better Auth (`getSessionCookie` for optimistic checks) all document the proxy naming.

## Implementation Guidance

### Execution order
1. `headers` (next.config) → 2. `redirects` (next.config) → 3. **Proxy** → 4. `beforeFiles` rewrites → 5. filesystem routes (`public`, `_next/static`, `app`, `pages`) → 6. `afterFiles` rewrites → 7. dynamic routes → 8. `fallback` rewrites.

### Decision table
| Need | Tool |
|---|---|
| Fixed old→new URL | `next.config` `redirects()` |
| Security headers for all routes | `next.config` `headers()` |
| Redirect based on cookie/header/geo | `proxy.ts` |
| Per-request CSP nonce | `proxy.ts` |
| Authorization of data/mutation | DAL / Server Action / Route Handler |
| Edge runtime required | Deprecated `middleware.ts` (plan migration) |

### Baseline proxy
```ts
// proxy.ts (project root or src/)
import { NextResponse, type NextRequest } from 'next/server'

const PROTECTED = ['/dashboard', '/settings']

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl
  const hasSession = request.cookies.has('session') // optimistic only

  if (PROTECTED.some((p) => pathname === p || pathname.startsWith(`${p}/`)) && !hasSession) {
    const url = new URL('/login', request.url)
    url.searchParams.set('next', pathname)
    return NextResponse.redirect(url)
  }

  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-pathname', pathname) // upstream only
  return NextResponse.next({ request: { headers: requestHeaders } })
}

export const config = {
  matcher: [
    {
      source: '/((?!api|_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
}
```

### CORS for API paths
```ts
import { NextResponse, type NextRequest } from 'next/server'
const ALLOWED = new Set(['https://app.acme.com'])

export function proxy(req: NextRequest) {
  const origin = req.headers.get('origin') ?? ''
  const allowed = ALLOWED.has(origin)
  if (req.method === 'OPTIONS') {
    return new NextResponse(null, {
      status: 204,
      headers: {
        ...(allowed && { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' }),
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    })
  }
  const res = NextResponse.next()
  if (allowed) { res.headers.set('Access-Control-Allow-Origin', origin); res.headers.set('Vary', 'Origin') }
  return res
}
export const config = { matcher: '/api/:path*' }
```

### Background work
```ts
import type { NextFetchEvent, NextRequest } from 'next/server'
export function proxy(req: NextRequest, event: NextFetchEvent) {
  event.waitUntil(logRequest(req.nextUrl.pathname))
}
```

### Matcher syntax cheat sheet
- `'/about/:path*'` zero or more; `:path+` one or more; `:path?` optional.
- `'/((?!api|_next).*)'` regex negative lookahead.
- Objects: `{ source, locale?: false, has?: [...], missing?: [...] }` with `type: 'header' | 'query' | 'cookie'`.
- `_next/data` routes still invoke proxy even when excluded (intentional safety).

## Recommended Workflow
1. Ask whether `next.config` redirects/headers/rewrites suffice; stop if yes.
2. Run the codemod if migrating from `middleware.ts`.
3. Write the matcher first; test it with `unstable_doesProxyMatch`.
4. Implement minimal logic reading cookies/headers/URL.
5. Duplicate the real authorization in DAL/actions/route handlers.
6. Measure: proxy runs on every matched request and prefetch — watch latency.

## Patterns
- **Locale negotiation** with `@formatjs/intl-localematcher` + `negotiator`, redirect to `/${locale}${pathname}`.
- **Multi-tenant rewrite:** `acme.app.com/x` → rewrite to `/tenants/acme/x` based on `host`.
- **A/B bucket cookie:** assign cookie if absent, rewrite to variant route.
- **Nonce CSP:** generate nonce, set `Content-Security-Policy` on request and response, `x-nonce` request header.
- **Library composition:** call library handler (e.g., next-intl) then add headers to its response.

## Anti-Patterns
- **No matcher** — auth redirects block CSS/JS/images. Fix: negative matcher.
- **DB/session lookups in proxy** — latency on every request and prefetch. Fix: cookie-only optimistic check; secure check in DAL.
- **Proxy-only auth** — bypass via matcher gaps or moved actions (Server Actions POST to the page route). Fix: verify in every action/handler/DAL.
- **`NextResponse.next({ headers: requestHeaders })`** — exposes internal headers to clients. Fix: `NextResponse.next({ request: { headers } })`.
- **Setting `export const runtime` in proxy** — throws. Fix: remove; Node.js is the runtime.
- **Relying on shared globals/modules between proxy and app** — proxy may be deployed separately. Fix: pass data via headers/cookies/URL.
- **Custom fetch-based rewrites** dropping RSC headers. Fix: `NextResponse.rewrite()`.

## Accessibility
- Redirects should preserve intent (`?next=`) so users (including screen reader users) return to where they were.
- Locale redirects must not trap users: provide a visible language switcher and honor explicit choice (cookie) over `Accept-Language`.

## Responsive Design
- Avoid device-sniffing rewrites to separate mobile routes; prefer responsive CSS. If unavoidable, send `Vary: User-Agent` and accept cache fragmentation.

## Performance
- Runs before cache lookup of routes; keep it O(1) with no network calls when possible.
- Exclude prefetches when logic doesn't affect them.
- Heavy imports increase cold starts for every matched request.

## Security
- Middleware/proxy bypass has been exploited historically (e.g., header-based internal subrequest bypass, CVE-2025-29927, fixed in 15.2.3/14.2.25) — keep Next.js patched and never depend solely on proxy for auth.
- Validate redirect targets to prevent open redirects (same-origin check).
- Don't reflect incoming headers into responses.
- Nonce generation must be per-request and unpredictable (`crypto.randomUUID()` base64).

## Testing
- Unit: `unstable_doesProxyMatch({ config, nextConfig, url })`; call `proxy(new NextRequest(url))` and assert `isRewrite`, `getRewrittenUrl`, redirect URLs.
- E2E: protected route redirects when logged out; static assets load while logged out; Server Action on excluded path still enforces auth.

## Tooling
- `@next/codemod` `middleware-to-proxy`.
- `next/experimental/testing/server` helpers (experimental).
- `negotiator`, `@formatjs/intl-localematcher`; next-intl; Clerk; Better Auth.

## Framework Notes
- v16.0: renamed to Proxy, Node.js runtime default; `middleware.ts` deprecated (Edge only). v15.5: Node middleware stable. v13.1: advanced flags.
- Proxy is supported on Node server, Docker, and adapters (platform-specific); not on static export.
- React (Vite SPA): no server layer — equivalent logic lives in a reverse proxy/CDN edge function or the API backend.

## AI Agent Guidance
- Emit `proxy.ts` with `export function proxy`, never `middleware.ts`, for Next.js ≥16.
- Always include a matcher; never add DB calls; always add server-side authorization elsewhere.
- Before done: verify static assets load unauthenticated, test matcher coverage for protected paths, confirm no internal headers appear in client responses.

## Examples
```ts
// proxy.ts — compose next-intl with a CSP nonce header
import createMiddleware from 'next-intl/middleware'
import type { NextRequest } from 'next/server'
import { routing } from './src/i18n/routing'

const intl = createMiddleware(routing)

export default function proxy(req: NextRequest) {
  const res = intl(req)
  res.headers.set('X-Content-Type-Options', 'nosniff')
  return res
}

export const config = { matcher: '/((?!api|trpc|_next|_vercel|.*\\..*).*)' }
```

## Related Skills
- [nextjs-authentication](../nextjs-authentication/Skill.md) — optimistic vs secure checks
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — locale routing
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — headers/CSP config
- [content-security-policy](../content-security-policy/Skill.md) — CSP design
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — API endpoints
- [nextjs-version-16-upgrade](../nextjs-version-16-upgrade/Skill.md) — rename codemod

## Sources
- [proxy.js reference](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) — Official — API, matcher, execution order, runtime, migration, testing
- [Next.js 16](https://nextjs.org/blog/next-16) — Official — rename rationale, Node runtime
- [Upgrading to v16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — edge caveat, renamed flags
- [Authentication guide](https://nextjs.org/docs/app/guides/authentication) — Official — optimistic checks in proxy
- [Content Security Policy](https://nextjs.org/docs/app/guides/content-security-policy) — Official — nonce proxy
- [next-intl routing setup](https://next-intl.dev/docs/routing/setup) — Community/Open Source — proxy.ts createMiddleware
- [Clerk Next.js quickstart](https://clerk.com/docs/quickstarts/nextjs) — Community (vendor) — clerkMiddleware in proxy.ts

## License / Usage Notes
Next.js MIT; next-intl MIT; Clerk SDK MIT (service is commercial). CVE-2025-29927 reference is from prior public advisories (training knowledge; not re-fetched in this session). Content summarized.

## Quality Tier
A — Official reference fully verified; one historical CVE detail cited from prior knowledge rather than fetched this session.

## Status
Active

## Last Verified
2026-09-15
