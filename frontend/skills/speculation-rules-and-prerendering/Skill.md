# Speculation Rules and Prerendering

## Summary
The Speculation Rules API lets a page tell Chromium browsers which URLs to prefetch or fully prerender, and when, before the user navigates. A prerendered page activates almost instantly, with LCP and CLS near zero for that navigation. In a React + Next.js stack, speculation rules matter mainly for full-page (hard) navigations:
- Marketing and content pages built as MPAs.
- Links between separate apps or Next.js multi-zones.
- Entry pages linking into an app.
- Vite SPAs where the link target is a different HTML document.

In-app client navigations are handled by the router's own prefetching (Next `<Link>`, React Router). This skill covers rule syntax, eagerness, limits, side-effect safety (analytics, auth, state), CSP, and measuring the effect.

## Category
Performance

## Subcategories
Speculation Rules API, prefetch, prerender, eagerness, document rules, list rules, Speculation-Rules header, prerender_until_script, document.prerendering, activationStart, Sec-Purpose, multi-zone navigation

## Problem It Solves
Full-page navigations pay TTFB, resource loading and rendering every time. Examples: marketing site to pricing page, blog index to post, search results to product page on MPA stacks, landing page to app login. Prerendering finishes that work before the click.

## When To Use
- MPA-style pages, or links that trigger full document loads (different zone/app, `<a>` without client routing).
- High-probability next navigations: pagination "next", search results, product listing to detail, CTA to signup.
- Content sites with cacheable HTML, where extra server load is acceptable.

## When Not To Use
- Links already handled by client-side routing (Next `<Link>`, React Router `<Link>`). Prerendering a document that will never be used as a document wastes resources.
- URLs with side effects on GET: logout, add-to-cart links, one-time tokens, "mark as read".
- Highly personalized or expensive dynamic pages where server load matters, unless you use conservative eagerness.
- As the only speed strategy. Safari support is behind a flag and Firefox doesn't support speculation rules.

## Core Principles
1. **Prefetch broadly, prerender selectively.** Prerender costs memory, CPU and server load.
2. **Match eagerness to confidence:** `conservative` (pointer down) < `moderate` (200 ms hover or pointerdown; the default for document rules) < `eager` (10 ms hover on desktop; 50 ms after a link enters the viewport on mobile) < `immediate` (as soon as the rules load; the default for list rules).
3. **Prerendered pages must be side-effect safe** until activation. Defer analytics, ad impressions and state-changing calls until `prerenderingchange`.
4. **Exclude dangerous URLs** explicitly (logout, cart actions, admin).
5. **Measure activation.** Segment RUM by navigation type `prerender`, and subtract `activationStart` from timings.

## Best Practices
- Use document rules with `where` conditions and exclusions rather than hardcoded lists, so rules adapt to page content.
- Mark opt-in links (`a[data-prerender]`) or opt-out links (`a[rel~=nofollow]`, `.no-prerender`).
- Chrome limits per page:

  | Eagerness | Prefetch | Prerender |
  |---|---|---|
  | `immediate` | up to 50 | up to 10 |
  | `eager` / `moderate` / `conservative` | 2 (FIFO) | 2 (FIFO) |

- Chrome skips speculation when Save-Data is on, under memory pressure, or when the user disables preloading.
- Serve speculation rules via inline `<script type="speculationrules">` or the `Speculation-Rules: "/rules.json"` header (MIME `application/speculationrules+json`). The header is handy for CDN injection.
- On the server, `Sec-Purpose: prefetch` (and `prefetch;prerender`) identifies speculative requests. You can deny them (e.g., return 503) under load, or skip expensive logging.
- The analytics libraries you use must be prerender-aware (GA4 and web-vitals handle it). For custom code, check `document.prerendering` and wait for `prerenderingchange`.
- `prerender_until_script` (origin trial from Chrome 144) prerenders HTML and subresources but pauses at the first blocking script. It's a safer middle ground; treat it as experimental.
- Cross-origin prerender is restricted. Same-site cross-origin needs opt-in (`Supports-Loading-Mode: credentialed-prerender`), and cross-site prerender is not supported.

## Implementation Guidance

### Rules examples
```html
<script type="speculationrules">
{
  "prerender": [{
    "where": { "and": [
      { "href_matches": "/*" },
      { "not": { "href_matches": ["/logout", "/cart/*", "/api/*", "/*\\?*add-to-cart=*"] } },
      { "not": { "selector_matches": "[data-no-prerender], [rel~=nofollow]" } }
    ]},
    "eagerness": "moderate"
  }],
  "prefetch": [{
    "where": { "href_matches": "/*" },
    "eagerness": "conservative"
  }]
}
</script>
```

### Next.js: target only hard-navigation links
In the App Router, `<Link>` does client navigation, so broad `href_matches: "/*"` rules would prerender documents that never activate. Target:
- Links to other zones or apps (multi-zone, docs site, marketing ↔ app).
- Explicit plain `<a data-prerender>` anchors.

```tsx
// app/(marketing)/layout.tsx — Server Component
const rules = {
  prerender: [{
    where: { selector_matches: 'a[data-prerender]' },
    eagerness: 'moderate',
  }],
  prefetch: [{
    where: { and: [{ href_matches: 'https://app.example.com/*' }, { not: { href_matches: 'https://app.example.com/logout' } }] },
    eagerness: 'moderate',
  }],
};

export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      {children}
      <script type="speculationrules" dangerouslySetInnerHTML={{ __html: JSON.stringify(rules) }} />
    </>
  );
}
```
```tsx
// usage: plain anchor for a cross-zone link
<a href="/docs/getting-started" data-prerender>Read the docs</a>
```
- Cross-origin (app subdomain) prerender needs same-site opt-in and credentials handling. Prefetch is simpler and safer.
- Next.js routes can observe `Sec-Purpose` in Route Handlers or proxy/middleware to shed load.

### CSP
Inline speculation rules need either the `'inline-speculation-rules'` source keyword in `script-src`, or a nonce/hash:
```
Content-Security-Policy: script-src 'self' 'nonce-{random}' 'inline-speculation-rules'
```

### Prerender-safe analytics and side effects (React)
```tsx
'use client';
import { useEffect } from 'react';

function whenActivated(cb: () => void) {
  if ((document as Document & { prerendering?: boolean }).prerendering) {
    document.addEventListener('prerenderingchange', cb, { once: true });
  } else {
    cb();
  }
}

export function PageView({ path }: { path: string }) {
  useEffect(() => { whenActivated(() => analytics.page(path)); }, [path]);
  return null;
}
```
`analytics` is a placeholder for your client. Defer the same way: ad impressions, "viewed" API calls, autoplaying media, and time-based UI such as countdowns and session timeouts.

### Measuring
```ts
const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming & { activationStart?: number };
const wasPrerendered = document.prerendering || (nav.activationStart ?? 0) > 0;
// web-vitals reports navigationType 'prerender' and adjusts metrics to activationStart automatically
```
DevTools > Application > Background services > **Speculative loads** lists rules, speculation status and failure reasons. The Network panel shows `Sec-Purpose` headers.

## Recommended Workflow
1. Identify top hard-navigation paths from analytics (entry page to next page, cross-zone links).
2. Audit targets for GET side effects and personalization. Build an exclusion list.
3. Start with `prefetch` at `moderate` eagerness. Add `prerender` for the highest-confidence links.
4. Make analytics and side effects prerender-aware. Add CSP support.
5. Ship to a percentage of traffic (feature flag). Monitor server load (`Sec-Purpose` requests), hit rate (activations vs speculations), and RUM LCP for `navigationType=prerender`.
6. Tune eagerness and selectors. Expand only if hit rate is good (e.g., over 30–50% of prerenders activate).

## Patterns
- **Opt-in attribute** (`data-prerender`) on CTA and next-page links.
- **Hover-intent prerender** (`moderate`) for navigation menus and listing pages.
- **Immediate prerender of "next" pagination/article** for readers.
- **Header-delivered rules** from the CDN for site-wide policies without code changes.
- **Load shedding:** the server rejects `Sec-Purpose: prefetch` when overloaded.

## Anti-Patterns
- **`href_matches: "/*"` with `immediate`/`eager` prerender on content-heavy pages.** Resource waste, server load. Fix: `moderate`, selectors, limits.
- **Prerendering GET URLs with side effects.** Accidental logouts or cart additions. Fix: exclusions, and make those actions POST.
- **Analytics counting prerenders as page views.** Inflated metrics. Fix: prerender-aware analytics.
- **Broad speculation rules in Next.js App Router apps for `<Link>` routes.** Wasted prerenders. Fix: target hard-navigation links only.
- **No CSP update.** Rules silently blocked. Fix: `'inline-speculation-rules'` or nonce.

## Accessibility
- A prerendered page activates with focus at the document start, like a normal navigation. Make sure skip links and headings are correct.
- Autoplaying media or announcements in prerendered pages must wait for activation. Otherwise screen readers may miss them or they may play unexpectedly.

## Responsive Design
- On mobile, `eager` triggers when links enter the viewport (50 ms), which can speculate a lot on long lists. Prefer `moderate` or `conservative` on mobile-heavy sites.
- Save-Data and low memory disable speculation automatically. Don't try to override that.

## Performance
- Prerendered navigations often have LCP near 0 ms. Prefetch removes the HTML network time but still renders on click.
- Costs: server requests for unused speculations, and client memory and CPU (limited by Chrome caps).
- Complementary to bfcache (back/forward) and HTTP caching.

## Security
- Speculation requests carry cookies (same-site). Ensure GET endpoints are safe and idempotent.
- CSP must explicitly allow inline speculation rules.
- Don't prerender pages that expose sensitive data in shared-device contexts unless they'd be shown anyway on click.
- Cross-origin prerender restrictions protect privacy. Don't try to work around them.

## Testing
- DevTools Speculative loads panel: verify rules parse and URLs are speculated and activated.
- Playwright (Chromium): hover a link, wait, then check `chrome://` is unavailable. Instead, assert via server logs for `Sec-Purpose` and via `performance.getEntriesByType('navigation')[0].activationStart > 0` after click.
- Unit-test exclusion patterns against the URL inventory.

## Tooling
- Speculation Rules API: Chrome/Edge 109+ (document rules, eagerness in later versions). Safari behind a flag. Firefox unsupported.
- `prerender_until_script`: Origin trial (Chrome 144+).
- Chrome DevTools Speculative loads panel: Active.
- web-vitals (prerender-aware `navigationType`): Active.

## Framework Notes
- **Next.js:** `<Link>` prefetching (RSC payloads) already makes in-app navigations fast. Use speculation rules for hard navigations: multi-zone links, marketing to app, plain `<a>` to separately deployed properties. Inject rules from Server Component layouts or via a CDN `Speculation-Rules` header. See [nextjs-performance](../nextjs-performance/Skill.md) and [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md).
- **React (Vite SPA):** internal navigations are client-side, so speculation rules don't apply there. They help when a static landing page links into the SPA (prerender the app's `index.html` and entry chunks), or when the SPA links out to MPA pages. For in-app route data and chunks, use router preloading ([code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md)).

## AI Agent Guidance
- Do: identify whether target links are hard or client navigations before adding rules.
- Do: add exclusions for side-effect URLs, use `moderate` eagerness by default, update CSP, and make analytics prerender-aware.
- Don't: add blanket `/*` prerender rules to Next.js App Router or React Router apps.
- Don't: rely on speculation rules for Safari or Firefox users.
- Before declaring done: DevTools Speculative loads shows the intended URLs speculated and activated, there are no side-effect URLs in the speculated set, analytics don't double-count, and the CSP allows the rules.

## Examples
```
# CDN-delivered rules
Speculation-Rules: "/speculation-rules.json"
```
```json
// /speculation-rules.json  (Content-Type: application/speculationrules+json)
{ "prefetch": [{ "where": { "href_matches": "/blog/*" }, "eagerness": "moderate" }] }
```

## Related Skills
- [back-forward-cache](../back-forward-cache/Skill.md): instant back/forward navigations
- [lcp-optimization](../lcp-optimization/Skill.md): navigation LCP
- [resource-hints-and-network-optimization](../resource-hints-and-network-optimization/Skill.md): lower-level hints
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md): in-app prefetch
- [content-security-policy](../content-security-policy/Skill.md): allowing inline rules
- [marketing-website-architecture](../marketing-website-architecture/Skill.md): MPA marketing to app flows

## Sources
- [Chrome for Developers: Prerender pages in Chrome](https://developer.chrome.com/docs/web-platform/prerender-pages) (Official): syntax, eagerness values, limits, header delivery, Sec-Purpose, browser support
- [Chrome for Developers: prerender until script origin trial](https://developer.chrome.com/blog/prerender-until-script-origin-trial) (Official): Chrome 144 origin trial
- [MDN: Speculation Rules API](https://developer.mozilla.org/en-US/docs/Web/API/Speculation_Rules_API) (Official): rule reference, CSP keyword
- [Chrome: Guide to implementing speculation rules for more complex sites](https://developer.chrome.com/docs/web-platform/implementing-speculation-rules) (Official): analytics, side effects, activation
- [DebugBear: Speculation rules](https://www.debugbear.com/blog/speculation-rules) (Community): practical measurement

## License / Usage Notes
Summarized from Chrome/MDN docs (CC BY). Examples original.

## Quality Tier
A: Verified Sept 2026 official docs (eagerness, limits, origin trial). Next.js-specific integration is a pattern, not official Next.js guidance.

## Status
Active

## Last Verified
2026-09-15
