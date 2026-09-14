# HTTP Caching and CDN

## Summary
HTTP caching (RFC 9111) lets browsers and CDNs reuse responses instead of refetching them. Good caching gives near-zero repeat-visit asset cost and low TTFB for HTML. The core strategy has three parts. Content-hashed static assets are cached for a year with `immutable`. HTML and unversioned URLs are revalidated (`no-cache` with ETag) or cached briefly at the edge with `s-maxage` plus `stale-while-revalidate`. Personalized responses stay `private` or `no-store`. In Next.js most headers are set by the framework from each route's rendering and caching mode. In a Vite SPA you set them yourself on the CDN or host.

## Category
Performance

## Subcategories
Cache-Control directives, validators (ETag/Last-Modified), stale-while-revalidate, CDN-Cache-Control, Vary, cache keys, purging, immutable assets, edge caching of HTML, Next.js cache headers

## Problem It Solves
- Slow TTFB because every HTML request hits the origin.
- Repeat visitors re-downloading unchanged bundles.
- Stale deploys: old HTML pointing at deleted chunks, or users stuck on old versions.
- Personalized data accidentally cached publicly.
- Low CDN hit ratios caused by fragmented cache keys.

## When To Use
- Configuring a CDN, host headers, or Next.js/Vite deployment.
- TTFB above 800 ms or LCP dominated by TTFB.
- Investigating stale content, cache misses, or data leaking between users.

## When Not To Use
- Next.js data cache and `fetch` caching semantics, `revalidateTag`, or `use cache`. Those are framework data layers, covered in [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md). This skill covers the HTTP layer.
- Offline and app-shell caching, which belongs in [service-workers-and-offline](../service-workers-and-offline/Skill.md).

## Core Principles
1. **Version the URL, then cache it forever.** Hashed filenames with `max-age=31536000, immutable`.
2. **Never cache HTML long in browsers.** Browsers get `no-cache` or `max-age=0` and revalidate. CDNs can cache longer with `s-maxage` because you can purge them.
3. **`no-cache` is not `no-store`.** `no-cache` stores and revalidates. `no-store` never stores. Reserve `no-store` for sensitive responses.
4. **Personalized means `private`.** Responses that vary by cookie or auth must never be `public`.
5. **Cache keys must be deliberate.** `Vary` only on headers that really change the response. Normalize query strings.

## Best Practices
- Serve static assets (`/_next/static/*`, Vite `/assets/*`) with `Cache-Control: public, max-age=31536000, immutable`.
- For HTML on a CDN, use `Cache-Control: public, max-age=0, s-maxage=60..3600, stale-while-revalidate=86400`, or `CDN-Cache-Control` (RFC 9213) for CDN-specific TTLs. Purge on deploy or on content change.
- Always send validators (`ETag` or `Last-Modified`) on revalidated resources so the server can return 304.
- Use `stale-if-error` (RFC 5861) to keep serving cached content during origin outages, if your CDN supports it.
- Keep old hashed assets available for at least a few days after a deploy, so already-open tabs and cached HTML can still fetch chunks.
- Personalized HTML should be `private, no-cache`. Better still, serve a cacheable shell and fetch personalized parts client-side or stream them.
- APIs: cache public GET endpoints at the edge with short `s-maxage` plus SWR. Authenticated endpoints get `private` or `no-store`.
- Monitor CDN hit ratio and origin TTFB. A hit ratio below 80% on static assets means the cache key is broken.
- Mind bfcache. Chrome now allows `no-store` pages into bfcache under safeguards, but prefer `no-cache` for non-sensitive pages ([back-forward-cache](../back-forward-cache/Skill.md)).

## Implementation Guidance

### Header decision table
| Resource | Cache-Control | Notes |
|---|---|---|
| Hashed JS/CSS/fonts/images | `public, max-age=31536000, immutable` | URL changes on content change |
| HTML (static/ISR), CDN-cached | `public, max-age=0, s-maxage=300, stale-while-revalidate=86400` | Browser revalidates; CDN serves fast, refreshes in background |
| HTML (personalized/auth) | `private, no-cache` (+ ETag) | Never shared caches |
| Sensitive (banking, PII pages, auth responses) | `no-store` | No storage anywhere |
| Unversioned public files (`/favicon.ico`, `/robots.txt`) | `public, max-age=3600` or `no-cache` | Balance freshness |
| Public API GET | `public, s-maxage=60, stale-while-revalidate=300` | Add `Vary` only if needed |
| Authenticated API | `private, no-store` or `private, no-cache` | Choose by sensitivity |
| Service worker script | `no-cache` | Browsers cap SW cache at 24 h anyway |

### Next.js defaults (verify with `curl -I` on your deployment)
| Route type | Typical header set by Next.js |
|---|---|
| `/_next/static/*` | `public, max-age=31536000, immutable` |
| Static (prerendered) page | `s-maxage=31536000` (with revalidation semantics per config) |
| ISR / `revalidate = N` | `s-maxage=N, stale-while-revalidate` |
| Dynamic (cookies/headers/no-store data) | `private, no-cache, no-store, max-age=0, must-revalidate` |
| Optimized images (`/_next/image`) | `max-age` from `minimumCacheTTL` or upstream |

- Next.js controls `Cache-Control` for pages and assets. Custom values set in `next.config` `headers()` for those paths can be overwritten in production, so change caching behavior through the route segment config and data caching instead.
- For Route Handlers you control the headers:
```ts
// app/api/products/route.ts
export async function GET() {
  const data = await getPublicProducts();
  return Response.json(data, {
    headers: { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300' },
  });
}
```
- On Vercel, `CDN-Cache-Control` / `Vercel-CDN-Cache-Control` let you set CDN TTLs separately from browser TTLs. Self-hosted deployments behind Cloudflare, Fastly or CloudFront must honor `s-maxage` and must not cache `private` responses ([nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md)).

### Vite SPA (static host) examples
```
# Netlify _headers / Cloudflare Pages _headers
/assets/*
  Cache-Control: public, max-age=31536000, immutable
/index.html
  Cache-Control: no-cache
/*
  X-Content-Type-Options: nosniff
```
```nginx
location /assets/ { add_header Cache-Control "public, max-age=31536000, immutable"; try_files $uri =404; }
location / { add_header Cache-Control "no-cache"; try_files $uri /index.html; }
```
Make sure missing `/assets/*` return 404, not `index.html`. An SPA fallback on asset paths gets cached as JS with the wrong MIME type.

### Diagnosing
```bash
curl -sI https://example.com/ | grep -iE 'cache-control|age|etag|vary|x-cache|cf-cache-status|x-vercel-cache'
curl -sI https://example.com/_next/static/chunks/main-abc.js | grep -i cache-control
```
- An `Age` header greater than 0 plus HIT status means the CDN served it.
- A `304` on a repeat request means revalidation is working.
- In DevTools Network, Size shows "(disk cache)" or "(memory cache)" for browser hits.

## Recommended Workflow
1. Inventory responses by type: HTML, static, images, API, fonts, and service worker. Record current headers and CDN status per type.
2. Apply the decision table and confirm assets are content-hashed.
3. Configure the CDN: cache key (strip marketing query params such as `utm_*`), `Vary` hygiene, compression, and purge-on-deploy hooks.
4. For HTML: decide what can be edge-cached. Move personalization client-side or into streamed holes.
5. Verify with `curl`, then run a WebPageTest repeat view. Monitor hit ratio and TTFB p75 in RUM.
6. Document the purge and revalidation procedure. Test the deploy scenario where an old tab loads a new chunk.

## Patterns
- **Immutable assets plus revalidated HTML**: the baseline for every app.
- **Edge SWR for HTML**: serve stale instantly and refresh in the background. Cuts TTFB for anonymous traffic.
- **Cacheable shell plus personalized islands**: logged-in header fetched client-side or streamed.
- **Tag-based purge**: CDN surrogate keys or Next.js `revalidateTag` mapped to content IDs.
- **Split TTLs**: `Cache-Control` for browsers and `CDN-Cache-Control` for the edge.

## Anti-Patterns
- **`max-age=31536000` on HTML or unhashed URLs.** Users get stuck on old versions. Fix: `no-cache` in browsers, `s-maxage` at the CDN.
- **`public` caching of pages that read cookies.** Leaks one user's data to others. Fix: `private`, or split the personalization out.
- **`Vary: User-Agent` or `Vary: Cookie` on CDN.** Fragments the cache and ruins the hit ratio. Fix: normalize, or vary on a derived header.
- **`no-store` everywhere "to be safe."** Kills performance and was historically a bfcache blocker. Fix: `no-cache` for non-sensitive pages.
- **Deleting old assets at deploy.** Open tabs get chunk-load errors. Fix: retain previous builds' assets.
- **Query-string cache busting (`app.js?v=2`) with CDNs ignoring query strings.** Fix: filename hashing.

## Accessibility
- No direct accessibility impact. Stale HTML with broken chunks produces blank screens, which is especially confusing for screen reader users, so handle chunk errors with an accessible error state ([error-states](../error-states/Skill.md)).

## Responsive Design
- Don't vary HTML by device at the CDN unless you serve different markup. Prefer responsive HTML with one cache entry.
- Client hints (`Sec-CH-*`, `Save-Data`) as cache keys fragment caches. Use them sparingly with `Vary` if needed.

## Performance
- Edge-cached HTML often cuts TTFB from 500 ms or more to under 100 ms for anonymous users.
- `immutable` avoids revalidation on reload in browsers that honor it.
- A 304 still costs a round trip. For hashed assets, avoid revalidation entirely.

## Security
- Web cache poisoning and deception: don't cache responses keyed on unkeyed headers (`X-Forwarded-Host`). Don't cache `/account.css`-style paths that actually serve personalized HTML. Only cache by extension where the content type matches.
- Authenticated responses must be `private` or `no-store`. Set `Vary: Authorization`/`Cookie` if a shared cache might see them, or better, bypass the CDN cache.
- Don't cache `Set-Cookie` responses at the CDN.
- See [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) and [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md).

## Testing
- CI smoke test: `curl -I` assertions for `Cache-Control` on HTML, static, API, and auth routes.
- A Playwright test that a logged-in page response is not `public`.
- Deploy test: load the old HTML, deploy, navigate, and confirm chunks still load or recover.
- WebPageTest first vs repeat view comparisons.

## Tooling
- RFC 9111 (HTTP Caching), RFC 5861 (stale-while-revalidate / stale-if-error), RFC 9213 (Targeted Cache-Control / `CDN-Cache-Control`): Standards.
- CDN analytics (Cloudflare, Fastly, CloudFront, Vercel) for hit ratio and cache status: Active.
- Chrome DevTools Network (Size column, response headers): Active.
- REDbot (redbot.org) for header linting: Active.

## Framework Notes
- **Next.js**: HTTP caching follows from rendering mode. Static and ISR routes are CDN-cacheable; dynamic APIs (cookies, headers, uncached data) produce private no-store responses. To improve TTFB, make more of the route static (Cache Components/PPR, `use cache`, `revalidate`) rather than overriding headers. See [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md), [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md), and [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**: `index.html` gets `no-cache`, `/assets/*` gets immutable, and the SPA fallback applies only to navigation routes. API caching is set on your backend. Client data caching (TanStack Query `staleTime`) is separate from HTTP caching; don't confuse them ([react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md)).

## AI Agent Guidance
- Do: inspect real response headers before proposing changes. Use the decision table.
- Do: mark anything that depends on the user's session as `private`.
- Don't: set long `max-age` on HTML, add `Vary: Cookie` at the CDN, or override Next.js page `Cache-Control` via `headers()`.
- Don't: recommend `no-store` broadly.
- Before declaring done: `curl -I` shows the intended headers per resource type, CDN HIT on repeat for static and cacheable HTML, authenticated pages not publicly cached, and the old-tab deploy scenario handled.

## Examples
```ts
// Next.js Route Handler: private user data (no shared caching)
import { cookies } from 'next/headers';
export async function GET() {
  const session = (await cookies()).get('session')?.value;
  const data = await getUserDashboard(session);
  return Response.json(data, { headers: { 'Cache-Control': 'private, no-store' } });
}
```

## Related Skills
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md): framework data caching
- [lcp-optimization](../lcp-optimization/Skill.md): TTFB as an LCP subpart
- [service-workers-and-offline](../service-workers-and-offline/Skill.md): client-side caching layer
- [back-forward-cache](../back-forward-cache/Skill.md): history navigation caching
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md): CDN setup for self-hosted Next
- [resource-hints-and-network-optimization](../resource-hints-and-network-optimization/Skill.md): compression and protocols
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md): cache poisoning and deception

## Sources
- [RFC 9111: HTTP Caching](https://www.rfc-editor.org/rfc/rfc9111) (Official): directive semantics
- [MDN: HTTP caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Caching) (Official): practical directive guide
- [web.dev: Prevent unnecessary network requests with the HTTP Cache](https://web.dev/articles/http-cache) (Official): versioned vs unversioned strategy, no-cache vs no-store
- [RFC 9213: Targeted HTTP Cache Control](https://www.rfc-editor.org/rfc/rfc9213) (Official): `CDN-Cache-Control`
- [Next.js docs: caching and deploying](https://nextjs.org/docs/app/guides/caching) (Official): route caching behavior
- [Jake Archibald: Caching best practices & max-age gotchas](https://jakearchibald.com/2016/caching-best-practices/) (Community): versioning patterns (older; principles valid)
- [Chrome: bfcache for Cache-Control: no-store](https://developer.chrome.com/docs/web-platform/bfcache-ccns) (Official): no-store/bfcache change

## License / Usage Notes
RFCs are IETF Trust. Docs summarized. Examples original.

## Quality Tier
A: Standards-based. Next.js default headers are summarized from docs and behavior and should be verified per version and host.

## Status
Active

## Last Verified
2026-09-15
