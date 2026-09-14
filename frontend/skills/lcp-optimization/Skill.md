# LCP Optimization

## Summary
Largest Contentful Paint (LCP) is the render time of the largest image, video poster or text block in the viewport. To optimize it, split LCP into four subparts (TTFB, resource load delay, resource load duration, element render delay) and fix whichever one dominates. The goal is ≤ 2.5 s at p75.

## Category
Performance

## Subcategories
LCP subparts, fetchpriority, preload, TTFB, render-blocking resources, hero images, SSR, image CDN

## Problem It Solves
Slow first impressions on landing, product and article pages. Common causes are hero images that the browser discovers late, lazy-loaded LCP images, client-side rendering that hides content until JS runs, render-blocking CSS and fonts, and slow origin responses.

## When To Use
- Field LCP is above 2.5 s at p75, or a template regressed.
- Building a new landing or hero section.
- Migrating rendering mode (CSR → SSR/SSG), image pipeline or CDN.

## When Not To Use
- Field LCP is already good and INP or CLS is the failing metric.
- The LCP element is text and TTFB is good. There's little to gain beyond render-blocking fixes, so check fonts and CSS and move on.

## Core Principles
1. **Measure the subparts before fixing anything.** Target shares (web.dev): TTFB ≈ 40%, resource load delay < 10%, resource load duration ≈ 40%, element render delay < 10%.
2. **The LCP resource must be discoverable in the initial HTML**, as `<img src/srcset>` or a `<link rel="preload">`. It should not be injected by JS or hidden in a CSS `background-image`.
3. **Prioritize one resource.** Put `fetchpriority="high"` on the likely LCP image. Never `loading="lazy"` it.
4. **Server-render the LCP content.** Client-side rendering adds JS download, parse and execute time to render delay.
5. **Fast HTML is the foundation.** TTFB is part of every LCP. Cache HTML at the edge wherever you can.

## Best Practices
- Hero `<img>`: explicit `width`/`height`, `srcset`/`sizes`, `fetchpriority="high"`, `decoding` left at default (or `async`), no `loading="lazy"`.
- Use responsive AVIF/WebP from an image CDN, sized to the rendered size × DPR (cap at 2× on phones).
- Preload CSS background heroes with `imagesrcset`/`imagesizes` and `fetchpriority="high"`. Better still, convert them to `<img>`.
- Inline critical CSS (≤ ~14 KB compressed) or keep the render-blocking CSS small. Defer non-critical stylesheets.
- Remove render-blocking `<script>` in `<head>`: use `defer` or `type="module"`.
- Avoid A/B-testing or personalization scripts that hide the page (anti-flicker snippets). Do experiments server-side or at the edge.
- For text LCP, use `font-display: swap` or `optional` so text isn't hidden for up to 3 s.
- Redirects count toward TTFB. Link to canonical URLs and avoid chains, especially from marketing links.
- Use Speculation Rules or bfcache for later navigations. Prerendered pages can reach an LCP near 0 ([speculation-rules-and-prerendering](../speculation-rules-and-prerendering/Skill.md)).
- Consider 103 Early Hints to `preconnect`/`preload` critical origins while the server generates HTML.

## Implementation Guidance

### Subpart diagnosis → fix
| Dominant subpart | Typical causes | Fixes |
|---|---|---|
| TTFB | No edge caching, slow SSR/data, redirects, cold starts | Cache HTML at CDN with `stale-while-revalidate`, stream HTML, parallelize data fetching, remove redirects, Early Hints |
| Resource load delay | LCP image found late (JS-inserted, CSS background, lazy), low priority, other requests first | Put it in HTML, `fetchpriority="high"`, preload, remove `loading="lazy"`, preconnect to the image CDN |
| Resource load duration | Oversized image, wrong format, no CDN, contention with many requests | AVIF/WebP, `srcset`/`sizes`, compression, CDN, fewer competing high-priority requests, HTTP/2+ |
| Element render delay | Render-blocking CSS/JS, fonts, client rendering, hydration before paint, hide-page snippets, image decode | Inline critical CSS, defer JS, SSR, remove anti-flicker, `font-display`, avoid blocking on hydration |

### How to get the subparts
- **DevTools Performance panel** → "LCP breakdown" (LCP by phase) insight. The live metrics view also shows the LCP element.
- **web-vitals attribution**: `timeToFirstByte`, `resourceLoadDelay`, `resourceLoadDuration`, `elementRenderDelay`, `target`, `url`.
- **Raw API**:
```js
new PerformanceObserver((list) => {
  const lcp = list.getEntries().at(-1);
  const nav = performance.getEntriesByType('navigation')[0];
  const res = lcp.url && performance.getEntriesByName(lcp.url)[0];
  const ttfb = nav.responseStart;
  const loadStart = res ? Math.max(ttfb, res.requestStart || res.startTime) : ttfb;
  const loadEnd = res ? Math.max(loadStart, res.responseEnd) : ttfb;
  console.table({
    element: lcp.element, ttfb,
    loadDelay: loadStart - ttfb,
    loadDuration: loadEnd - loadStart,
    renderDelay: lcp.startTime - loadEnd,
  });
}).observe({ type: 'largest-contentful-paint', buffered: true });
```
Note: cross-origin images need `Timing-Allow-Origin` to expose detailed timing.

### Hero image (Next.js)
```tsx
// app/(marketing)/page.tsx: Server Component
import Image from 'next/image';
import hero from '@/public/hero.jpg'; // static import: width/height/blur inferred, hashed + immutable caching

export default function Page() {
  return (
    <section className="grid lg:grid-cols-2">
      <h1>Trail running, simplified</h1>
      <Image
        src={hero}
        alt="Runner on a mountain trail at sunrise"
        sizes="(min-width: 1024px) 50vw, 100vw"
        loading="eager"
        fetchPriority="high"
        placeholder="blur"
      />
    </section>
  );
}
```

### Hero image (React Vite SPA, image CDN)
```tsx
export function Hero() {
  const base = 'https://img.example.com/hero.jpg';
  return (
    <img
      src={`${base}?w=1200&fm=avif`}
      srcSet={[640, 960, 1200].map((w) => `${base}?w=${w}&fm=avif ${w}w`).join(', ')}
      sizes="(min-width: 1024px) 50vw, 100vw"
      width={1200}
      height={800}
      fetchPriority="high"
      alt="Runner on a mountain trail at sunrise"
    />
  );
}
```
In a CSR SPA this `<img>` doesn't exist until JS runs. For a static hero, also add `<link rel="preload" as="image" fetchpriority="high" imagesrcset="..." imagesizes="...">` to `index.html`.

### CSS background hero (if it can't be `<img>`)
```html
<link rel="preload" as="image" fetchpriority="high"
  imagesrcset="/hero-640.avif 640w, /hero-1200.avif 1200w" imagesizes="100vw" type="image/avif">
```
A `type` on the preload means browsers that don't support that format skip it, so only preload the format you're sure the browser will use.

## Recommended Workflow
1. Identify the LCP element per template and device, using RUM attribution or the DevTools live metrics view.
2. Record a throttled load trace and read the LCP breakdown and "LCP request discovery" insights.
3. Fix the largest subpart using the table above. Change one thing per iteration.
4. Recheck that the LCP element didn't change (for example, a cookie banner becoming the LCP).
5. Verify in the lab (median of 5 runs), then in RUM p75 per template.

## Patterns
- **Priority hint pairing**: `fetchpriority="high"` on the hero, `fetchpriority="low"` on non-visible carousel slides.
- **Edge-cached HTML plus client personalization**: serve a cacheable shell, then fetch the personalized bits after LCP.
- **Streaming SSR**: flush `<head>` (CSS, preloads) immediately, and stream the hero before slow data sections.
- **Placeholder that doesn't count**: low-res blurred placeholders (LQIP) can become the LCP candidate. Chrome ignores low-entropy images (< 0.05 bits per pixel), so a tiny blurred placeholder usually doesn't count, but a medium-quality one might.

## Anti-Patterns
- **`loading="lazy"` on the hero** (often from a blanket lazy-load rule or CMS default): delays discovery until layout. Fix: eager-load above-the-fold images and lazy-load only below the fold.
- **Preloading everything**: priority dilution and wasted bytes. Fix: preload at most 1–2 LCP-critical resources.
- **Hero rendered by a client component after data fetch**: render delay equals JS plus API time. Fix: SSR/SSG the hero markup and URL.
- **Fade-in animation on the hero** starting at `opacity: 0`: LCP is recorded only when the element is painted visibly. Fix: don't animate the LCP element's initial opacity.
- **Anti-flicker snippets** (`body { opacity: 0 }` until the experiment loads): can add seconds. Fix: server-side experiments.
- **Huge image served to mobile**: long load duration. Fix: `srcset`/`sizes` plus a CDN transform.

## Accessibility
- Keep meaningful `alt` text on hero images. Priority hints don't change semantics.
- Don't swap visible text for images of text to "control" LCP (fails SC 1.4.5 Images of Text).
- Honor `prefers-reduced-motion` for hero animations. Removing the animation also helps LCP.

## Responsive Design
- Write `sizes` to match the CSS layout. A wrong `sizes="100vw"` on a 50%-wide image doubles the download.
- Art direction with `<picture>`: put `fetchpriority` on the `<img>` inside, and preload with `media` queries per source if needed.
- The mobile LCP is often a text block. Check per breakpoint before adding image preloads.

## Performance
- `fetchpriority` is Baseline (Chrome 101+, Safari 17.2+, Firefox 132+).
- Every preload and high-priority request competes with the others. Measure after adding each.
- Faster LCP by hydrating less can shift work into INP. Watch both.

## Security
- Preconnect only to origins you trust and control. Too many preconnects waste sockets.
- `Timing-Allow-Origin: *` exposes timing for cross-origin resources. Set it on your image CDN only, not on authenticated responses.
- Image CDN URL transforms (width, format) must be allowlisted to avoid cost-amplification abuse.

## Testing
- Lighthouse CI assertion: `largest-contentful-paint` ≤ 2500 ms (mobile preset) on key templates.
- Playwright check that the hero `<img>` has `fetchpriority="high"` and no `loading="lazy"`.
- WebPageTest filmstrip comparisons, before and after, on a real mid-tier Android profile.

## Tooling
- Chrome DevTools Performance panel (LCP breakdown, request discovery insights), Active.
- PageSpeed Insights / Lighthouse 13, Active.
- WebPageTest (Catchpoint), Active. Filmstrip, experiments ("opportunities").
- DebugBear / Calibre / SpeedCurve: synthetic plus RUM LCP subparts.
- Image CDNs: Cloudinary, imgix, Cloudflare Images, Vercel/Netlify image optimization.

## Framework Notes
- **Next.js (App Router, v16)**:
  - `next/image` lazy-loads by default. On the LCP image, set `loading="eager"` and `fetchPriority="high"` (the docs recommend these in most cases). Use the `preload` prop, which injects a `<link rel="preload">`, only when the image can't be discovered early enough, for example when it's behind CSS or rendered late. The old `priority` prop is deprecated since Next 16.
  - Always set `sizes` with `fill` or responsive layouts. Without it, Next generates a srcset that assumes 100vw.
  - `images.formats: ['image/avif', 'image/webp']` in `next.config`. `images.qualities` is required in 16 (default `[75]`).
  - Keep the hero in a Server Component. A `'use client'` hero that waits on `useEffect` data fetching turns into render delay.
  - TTFB: static or cached routes are served from the edge. For dynamic routes, stream: put slow data in `<Suspense>` below the hero so the hero HTML flushes first ([nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md)). Keep proxy/middleware work minimal ([nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md)).
  - `next/font` preloads and self-hosts fonts, which removes third-party connections from text LCP.
  - Details: [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md), [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**: LCP waits for HTML → JS bundle → render → (often) API → image. Mitigations: put the hero image URL and dimensions in `index.html` or preload it from the HTML when it's static. Keep the entry chunk small ([code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md)). Start data fetches in the route loader, not after mount. Consider prerendering (React Router framework mode prerender, or a Next.js migration) for landing pages. In TSX, write `fetchPriority="high"` (camelCase, React 19 passes it through).

## AI Agent Guidance
- Do: identify the actual LCP element first (trace or attribution). Don't assume it's the first image.
- Do: remove `loading="lazy"` and add `fetchpriority="high"` only on the verified LCP element.
- Do: check the rendered `sizes` against the layout width.
- Do (Next.js): use `loading="eager"` + `fetchPriority="high"` on the LCP `next/image`. Don't add the deprecated `priority` prop in Next 16+ code. Keep the hero in a Server Component.
- Do (Vite SPA): check whether the hero exists in `index.html`. If not, recommend preload, prerendering, or a smaller entry chunk.
- Don't: add blanket `<link rel="preload">` for fonts, images and scripts together.
- Don't: introduce client-side data fetching for above-the-fold content.
- Before declaring done: trace shows the LCP subpart reduced, the LCP element is unchanged or intentionally changed, and no CLS regression from new image markup.

## Examples
```html
<!-- Head ordering for a fast LCP -->
<head>
  <meta charset="utf-8">
  <link rel="preconnect" href="https://img.example.com">
  <style>/* critical CSS */</style>
  <link rel="stylesheet" href="/app.9f2c.css">
  <script type="module" src="/app.1b7e.js"></script>
</head>
```

```
# Edge-cacheable HTML
Cache-Control: public, max-age=0, s-maxage=300, stale-while-revalidate=86400
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md) — metric definitions and field data
- [image-optimization](../image-optimization/Skill.md) — formats, sizing, CDNs
- [font-loading-performance](../font-loading-performance/Skill.md) — text LCP and render delay
- [resource-hints-and-network-optimization](../resource-hints-and-network-optimization/Skill.md) — preload, preconnect, Early Hints
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) — TTFB
- [hydration-strategies](../hydration-strategies/Skill.md) — render delay from JS
- [responsive-images-and-media](../responsive-images-and-media/Skill.md) — srcset/sizes/picture
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — Next.js specifics

## Sources
- [Optimize Largest Contentful Paint](https://web.dev/articles/optimize-lcp) — Official — subparts, target shares, fetchpriority/preload guidance
- [Largest Contentful Paint](https://web.dev/articles/lcp) — Official — candidate elements, thresholds
- [Fetch Priority API](https://web.dev/articles/fetch-priority) — Official — priority hint usage
- [Chrome DevTools Performance reference](https://developer.chrome.com/docs/devtools/performance/reference) — Official — LCP insights
- [web-vitals attribution](https://github.com/GoogleChrome/web-vitals) — Open Source — LCP attribution fields
- [CSS Wizardry (Harry Roberts)](https://csswizardry.com/) — Community — preload/priority trade-offs

## License / Usage Notes
web.dev content is CC BY 4.0. Code is original or adapted from Apache-2.0 samples. Summarized, not copied.

## Quality Tier
S — Aligned with official web.dev subpart methodology and current DevTools insights. Code is tested pattern-level.

## Status
Active

## Last Verified
2026-09-15
