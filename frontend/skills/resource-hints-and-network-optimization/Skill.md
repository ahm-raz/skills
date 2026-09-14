# Resource Hints and Network Optimization

## Summary
Resource hints (`preconnect`, `dns-prefetch`, `preload`, `modulepreload`, `prefetch`) and priority signals (`fetchpriority`) tell the browser what matters before it discovers it; network-level optimizations (HTTP/2–3, compression, 103 Early Hints, fewer origins, redirect elimination) reduce the cost of every request. In React 19 / Next.js these are exposed as `preload`/`preconnect`/`prefetchDNS`/`preinit` APIs from `react-dom`, framework components (`next/font`, `next/image`, `<Link>`), and HTTP headers. Used well they cut LCP resource load delay and TTFB; used indiscriminately they cause priority contention and waste.

## Category
Performance

## Subcategories
preconnect, dns-prefetch, preload, modulepreload, prefetch, fetchpriority, 103 Early Hints, HTTP/2, HTTP/3, Brotli, Zstandard, Compression Dictionary Transport, request waterfalls, React 19 resource APIs

## Problem It Solves
Late discovery of critical resources (fonts in CSS, hero images in CSS/JS, chunks behind other chunks), connection setup latency to third-party origins, waterfalls, uncompressed or poorly compressed text, and redirect chains that inflate TTFB.

## When To Use
- Waterfall shows the LCP resource or critical fonts starting late.
- Critical requests to extra origins (image CDN, API, auth) pay DNS+TCP+TLS late.
- Configuring CDN/server compression, protocols and Early Hints.

## When Not To Use
- As a substitute for putting resources in HTML (discoverable `<img>` beats preload).
- For resources not needed in the first seconds (preloading them hurts).
- Next-page navigation speedups for MPAs → [speculation-rules-and-prerendering](../speculation-rules-and-prerendering/Skill.md).

## Core Principles
1. **Discoverability first, hints second.**
2. **Few, high-confidence hints**: 1–2 preloads, 2–4 preconnects max.
3. **Priority is relative**: raising one resource lowers others; lower non-critical resources too (`fetchpriority="low"`).
4. **Every origin costs a connection**: consolidate origins; self-host critical assets.
5. **Compress and cache text aggressively**; eliminate redirects.

## Best Practices
- `preconnect` only to origins used in the first few seconds (image CDN, API used for LCP data); add `crossorigin` when requests are CORS (fonts, `fetch` with credentials mode considerations).
- `dns-prefetch` for less critical third-party origins (cheap).
- `preload` for late-discovered critical resources: CSS background LCP image, critical font (or let `next/font` do it), with correct `as`, `type`, `crossorigin`.
- `modulepreload` for critical ES module chunks (Vite injects for entry deps; Next handles its chunks).
- Remove unused preloads—Chrome warns "preloaded but not used within a few seconds".
- Serve HTML/JS/CSS with Brotli (static at high level, dynamic ~level 4–6) or Zstandard (supported in Chromium and Firefox); ensure CDN negotiates `Accept-Encoding`.
- Enable HTTP/2+ and HTTP/3 at the CDN; avoid domain sharding (hurts multiplexing).
- Use 103 Early Hints for `preconnect`/`preload` of critical resources when HTML generation is slow (CDN support: Cloudflare, Fastly, Akamai; browser support: Chromium; Firefox for preconnect/preload; Safari partial).
- Compression Dictionary Transport (`Use-As-Dictionary`, `dcb`/`dcz`) is Chromium-only; consider for large, frequently updated bundles with high repeat traffic—needs CDN/server support.
- Avoid redirects on critical paths (http→https, trailing slash, locale redirects on landing); HSTS preload removes the http hop.

## Implementation Guidance

### Hint decision table
| Situation | Hint | Example |
|---|---|---|
| LCP image referenced from CSS/JS | `preload as=image fetchpriority=high` (+ `imagesrcset`) | hero background |
| Critical web font | `preload as=font type=font/woff2 crossorigin` (Next: automatic) | body font |
| Image CDN / API origin used at load | `preconnect` | `https://img.example.com` |
| Analytics/chat origin used later | `dns-prefetch` | `https://widget.example.com` |
| Critical module deep in import graph | `modulepreload` | route chunk |
| Resource for likely next page | `prefetch` (low priority) / speculation rules | next step bundle |
| Non-critical image/script above other requests | `fetchpriority="low"` | carousel slide 2+, async analytics |

### React 19 resource APIs (work in Server & Client Components)
```tsx
import { preconnect, prefetchDNS, preload, preinit } from 'react-dom';

export default function ProductPage() {
  preconnect('https://img.example.com');
  prefetchDNS('https://reviews.example.net');
  preload('/images/hero.avif', { as: 'image', fetchPriority: 'high' });
  // preinit executes/applies immediately; use rarely:
  // preinit('https://cdn.example.com/critical-widget.js', { as: 'script' });
  return <main>{/* ... */}</main>;
}
```
React dedupes these and hoists `<link>` tags into `<head>` during SSR/streaming.

### Next.js specifics
- `next/font` auto-preloads font files per route scope; don't add manual font preloads.
- `next/image` with `preload` prop emits image preload; for LCP prefer `loading="eager"` + `fetchPriority="high"`.
- `<Link>` prefetches route payloads for in-viewport links in production; `prefetch={false}` for huge link lists.
- Early Hints: supported on Vercel and some CDNs for Next-generated `Link` headers—verify in your hosting docs.

```ts
// next.config.ts — static preconnect header example (for all pages)
import type { NextConfig } from 'next';
const nextConfig: NextConfig = {
  async headers() {
    return [{ source: '/:path*', headers: [{ key: 'Link', value: '<https://img.example.com>; rel=preconnect' }] }];
  },
};
export default nextConfig;
```

### Vite SPA `index.html`
```html
<head>
  <link rel="preconnect" href="https://api.example.com" crossorigin>
  <link rel="dns-prefetch" href="https://widget.example.com">
  <link rel="preload" href="/fonts/inter-latin-var.woff2" as="font" type="font/woff2" crossorigin>
  <!-- Vite injects <link rel="modulepreload"> for entry chunk dependencies -->
</head>
```

### Early Hints (server/CDN)
```
HTTP/1.1 103 Early Hints
Link: <https://img.example.com>; rel=preconnect
Link: </assets/app.3f9a.css>; rel=preload; as=style

HTTP/1.1 200 OK
Content-Type: text/html
...
```

### Verify compression
```bash
curl -sI -H 'Accept-Encoding: br, zstd, gzip' https://example.com/ | grep -iE 'content-encoding|vary|cache-control'
```

## Recommended Workflow
1. Record a throttled load in DevTools Network (Priority, Protocol, Initiator columns) and Performance (Network track, "LCP request discovery" and "Network dependency tree" insights).
2. Identify late-starting critical requests, connection setup on critical origins, redirects, uncompressed text.
3. Fix discoverability (HTML) first; then add minimal hints; set `fetchpriority` on critical/non-critical.
4. Configure CDN: Brotli/Zstd, HTTP/3, Early Hints, redirect cleanup.
5. Re-record; confirm LCP resource load delay shrank and no preload warnings; check that other critical resources weren't delayed.

## Patterns
- **Critical path diet**: HTML → critical CSS → LCP image/font; everything else deferred or low priority.
- **Origin consolidation**: proxy third-party critical assets through your CDN (fonts, images).
- **Hints from data**: for dynamic LCP images, emit `preload` from server where the URL is known (React `preload()` in the Server Component).
- **Low-priority the rest**: `fetchpriority="low"` for offscreen carousel images and non-critical fetches (`fetch(url, { priority: 'low' })`).

## Anti-Patterns
- **Preconnecting to 10 origins** → CPU/socket waste, little gain. Fix: ≤ 4 critical.
- **Preloading scripts/CSS already in HTML head** → duplicate/no-op noise. Fix: remove.
- **Font preload without `crossorigin`** → double fetch. Fix: add attribute.
- **Preloading responsive images without `imagesrcset`/`imagesizes`** → wrong candidate downloaded twice. Fix: mirror `srcset`/`sizes`.
- **Domain sharding (static1/static2)** under HTTP/2. Fix: single origin.
- **Locale redirect `/ → /en` on every landing**. Fix: serve locale content directly or use rewrites.

## Accessibility
- No direct a11y impact; faster critical CSS/fonts reduce flashes that can disorient users.
- Don't preload media that autoplays—autoplay itself needs controls and reduced-motion handling.

## Responsive Design
- Preload with `media` attribute for breakpoint-specific heroes: `<link rel="preload" as="image" media="(max-width: 767px)" ...>`.
- Mobile networks have higher RTT—preconnect and redirect removal matter more on mobile.

## Performance
- `fetchpriority` Baseline (Chrome 101, Safari 17.2, Firefox 132).
- Zstd content-encoding: Chromium 123+, Firefox 126+.
- Compression Dictionary Transport: Chromium-only (shipped after an origin trial; verify current CDN support).
- Too many high-priority resources negate each other; measure after each change.

## Security
- Preconnect/dns-prefetch leak intent to third parties; only for origins you already use.
- Early Hints `Link` headers must not include user-specific URLs.
- Compression + secrets reflected in responses can enable BREACH-style attacks—don't compress responses mixing secrets with attacker-controlled input, or use masking tokens.
- Keep CSP aligned with preconnected/preloaded origins.

## Testing
- WebPageTest waterfalls (connection view) before/after; DevTools "Network dependency tree" insight.
- Lighthouse checks: preload warnings, text compression, redirects.
- Header tests in CI (`curl -I`) for compression and `Link` headers on key URLs.

## Tooling
- Chrome DevTools Network & Performance insights — Active.
- WebPageTest — Active.
- React 19 `react-dom` resource APIs — Active.
- CDN features: Cloudflare/Fastly/Akamai/Vercel (Early Hints, Brotli/Zstd, HTTP/3) — verify per provider.

## Framework Notes
- **Next.js**: rely on `next/font`, `next/image`, `<Link>` and React 19 `preload`/`preconnect` in Server Components; add static `Link` headers via `headers()` only for truly global origins. Don't manually preload Next chunks. See [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**: edit `index.html` for global hints; Vite adds `modulepreload` for entry imports (`build.modulePreload`); use React 19 resource APIs in route components for route-specific hints (they inject into `<head>` on the client).

## AI Agent Guidance
- Do: confirm late discovery in a waterfall before adding a hint; keep hints minimal and correct (`as`, `type`, `crossorigin`).
- Do: prefer HTML discoverability and framework components over manual hints.
- Don't: add preconnects for every third party or preload multiple fonts/images.
- Before declaring done: no "preloaded but not used" warnings; targeted request starts earlier; LCP/FCP not regressed; compression confirmed via headers.

## Examples
```tsx
// Server Component emitting a preload for a data-dependent hero
import { preload } from 'react-dom';

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const article = await getArticle(slug);
  preload(article.heroUrl, { as: 'image', fetchPriority: 'high' });
  return <Article article={article} />;
}
```

## Related Skills
- [lcp-optimization](../lcp-optimization/Skill.md) — resource load delay
- [font-loading-performance](../font-loading-performance/Skill.md) — font preloads
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) — CDN, compression, TTFB
- [speculation-rules-and-prerendering](../speculation-rules-and-prerendering/Skill.md) — next-navigation hints
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — modulepreload & prefetch
- [third-party-script-management](../third-party-script-management/Skill.md) — third-party origins

## Sources
- [web.dev: Optimize LCP](https://web.dev/articles/optimize-lcp) — Official — preload/fetchpriority for LCP
- [web.dev: Fetch Priority](https://web.dev/articles/fetch-priority) — Official — priority hints
- [web.dev: Preconnect and dns-prefetch](https://web.dev/articles/preconnect-and-dns-prefetch) — Official — connection hints
- [Chrome for Developers: Early Hints](https://developer.chrome.com/docs/web-platform/early-hints) — Official — 103 usage
- [Chrome for Developers: Shared dictionary compression](https://developer.chrome.com/blog/shared-dictionary-compression) — Official — Use-As-Dictionary, dcb/dcz
- [React: Resource preloading APIs](https://react.dev/reference/react-dom#resource-preloading-apis) — Official — preload/preconnect/prefetchDNS/preinit
- [CSS Wizardry: preload/preconnect guidance](https://csswizardry.com/) — Community — hint trade-offs

## License / Usage Notes
Summarized. Examples original.

## Quality Tier
A — Official sources; Early Hints and dictionary-compression support vary by CDN and should be checked per deployment.

## Status
Active

## Last Verified
2026-09-15
