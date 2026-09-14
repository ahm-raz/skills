# Core Web Vitals

## Summary
Core Web Vitals (CWV) are Google's three user-centric metrics for loading (LCP), responsiveness (INP) and visual stability (CLS), assessed at the 75th percentile of real-user page loads. This skill covers what each metric measures, the thresholds, how field and lab data differ, how to collect the metrics yourself, and how to decide which metric to work on first. The per-metric skills cover the detailed fixes.

## Category
Performance

## Subcategories
Web Vitals, field data, CrUX, lab vs field, INP, LCP, CLS, soft navigations, supporting metrics (TTFB, FCP, TBT)

## Problem It Solves
Teams tune whatever Lighthouse score they can see and miss what real users experience. CWV gives a shared, field-based definition of "fast enough." Search ranking signals, PageSpeed Insights and most RUM tools use it. Knowing exactly how each metric is measured stops wasted work, such as fixing TBT when field INP is already good, or preloading an image that isn't the LCP element.

## When To Use
- Setting performance goals or SLOs for a site or route.
- Reading a PageSpeed Insights, CrUX or Search Console report and choosing what to fix.
- Adding web-vitals collection to an app (RUM).
- Explaining gaps between a Lighthouse score and field data.
- Checking performance before a launch or migration (framework, CDN or rendering-mode change).

## When Not To Use
- Internal tools behind auth with few users, where no CrUX data exists. Use task-specific timings (User Timing marks) together with INP.
- Non-browser runtimes (React Native, Electron shell metrics). CWV are web-page metrics.
- Micro-benchmarking a function. Use profiling instead ([performance-profiling-devtools](../performance-profiling-devtools/Skill.md)).

## Core Principles
1. **Field data decides; lab data diagnoses.** CrUX and RUM at p75 tell you whether a problem exists. Lighthouse and DevTools traces tell you why.
2. **Thresholds (p75, mobile and desktop scored separately):**

   | Metric | Good | Needs improvement | Poor |
   |---|---|---|---|
   | LCP | ≤ 2.5 s | 2.5–4.0 s | > 4.0 s |
   | INP | ≤ 200 ms | 200–500 ms | > 500 ms |
   | CLS | ≤ 0.1 | 0.1–0.25 | > 0.25 |

   A page "passes" only when all three are good at p75.
3. **INP replaced FID** (March 2024). `onFID()` was removed in web-vitals v5. Don't report or optimize FID.
4. **Each metric has subparts.** LCP = TTFB + resource load delay + resource load duration + element render delay. INP = input delay + processing duration + presentation delay. CLS = the largest session window of shifts (gap under 1 s, window up to 5 s). Always fix the dominant subpart.
5. **Supporting metrics are not CWV.** TTFB (good ≤ 0.8 s), FCP (good ≤ 1.8 s) and TBT (lab-only proxy for INP) help with diagnosis but don't define pass or fail.
6. **Cross-browser measurement is now possible.** LCP and INP (Event Timing) became Baseline Newly available with Safari 26.2 (Dec 2025). CLS (Layout Instability API) is still Chromium-only. CrUX contains Chrome data only.

## Best Practices
- Segment by device class, route template, country and connection. A site-wide p75 hides broken templates.
- Track p75 as the headline number and keep p95 for regressions. Never use the average.
- Use the web-vitals **attribution build** in RUM so every poor sample carries its cause (LCP element and subparts, INP target and LoAF scripts, CLS shift source).
- Send metrics on `visibilitychange` → hidden using `navigator.sendBeacon` or `fetch(..., {keepalive: true})`. Never rely on `unload`.
- For SPAs, enable soft-navigation reporting (web-vitals v6 `reportSoftNavs`, Chrome 151+) so per-route values aren't all attributed to the landing URL.
- Expect Safari INP values to differ, and early Safari builds have known INP bugs. Compare browsers separately; don't mix them into one p75 without a browser dimension.
- Recheck after every deploy. CrUX is a 28-day rolling window, so field changes show up slowly. RUM shows them within hours.

## Implementation Guidance

### Where to get data
| Source | Type | Granularity | Latency | Use for |
|---|---|---|---|---|
| CrUX via PageSpeed Insights / CrUX API | Field (Chrome) | URL or origin, phone/desktop | 28-day rolling, daily | Pass/fail, SEO view |
| CrUX History API / CrUX Vis | Field | Weekly periods | Weekly | Trends, before/after |
| CrUX BigQuery | Field | Origin, monthly | Monthly | Competitive/industry analysis |
| Search Console CWV report | Field | URL groups | Days | Template-level triage |
| Your RUM (web-vitals + beacon) | Field (all browsers) | Any dimension | Minutes | Attribution, SPAs, releases |
| Lighthouse / PSI lab | Lab | Single load, throttled | Instant | LCP/CLS debugging, TBT |
| DevTools Performance panel | Lab + CrUX overlay | Trace | Instant | Root cause, INP interactions |

### Minimal RUM with attribution (TypeScript, shared by Vite SPA and Next.js)
```ts
// src/lib/rum.ts
import { onLCP, onINP, onCLS, onTTFB, type MetricWithAttribution } from 'web-vitals/attribution';

type Beacon = { name: string; value: number; rating: string; id: string; navType: string; path: string; attr: Record<string, unknown> };
const queue = new Map<string, Beacon>();              // keyed by metric id: later values replace earlier ones

const round = (n?: number) => Math.round(n ?? 0);

function toBeacon(m: MetricWithAttribution): Beacon {
  let attr: Record<string, unknown> = {};
  if (m.name === 'LCP') {
    const a = m.attribution;
    attr = { target: a.target, ttfb: round(a.timeToFirstByte), loadDelay: round(a.resourceLoadDelay),
             loadDuration: round(a.resourceLoadDuration), renderDelay: round(a.elementRenderDelay) };
  } else if (m.name === 'INP') {
    const a = m.attribution;
    attr = { target: a.interactionTarget, type: a.interactionType, input: round(a.inputDelay),
             processing: round(a.processingDuration), presentation: round(a.presentationDelay) };
  } else if (m.name === 'CLS') {
    attr = { target: m.attribution.largestShiftTarget };
  }
  return { name: m.name, value: m.value, rating: m.rating, id: m.id, navType: m.navigationType,
           path: location.pathname, attr };  // pathname only: never send query strings (PII)
}

function flush() {
  if (!queue.size) return;
  const body = JSON.stringify([...queue.values()]);
  queue.clear();
  if (!navigator.sendBeacon?.('/api/rum', body)) {
    void fetch('/api/rum', { body, method: 'POST', keepalive: true });
  }
}

export function initRum() {
  const add = (m: MetricWithAttribution) => queue.set(m.id, toBeacon(m));
  const opts = { reportSoftNavs: true } as const;         // web-vitals v6+, Chrome 151+ (ignored elsewhere)
  onLCP(add, opts); onINP(add, opts); onCLS(add, opts); onTTFB(add, opts);
  addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') flush(); });
}
```
- **Vite SPA**: call `initRum()` in `main.tsx` after `createRoot(...).render(...)`.
- **Next.js**: call it from a `'use client'` component's `useEffect` with an empty dependency array, mounted once in `app/layout.tsx`, or use `useReportWebVitals`. See Examples.

### Triage decision table
| Field symptom | First check | Go to |
|---|---|---|
| LCP poor, TTFB > 0.8 s | Server/CDN, redirects, cache HIT ratio | [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) |
| LCP poor, load delay large | LCP image not discoverable or lazy | [lcp-optimization](../lcp-optimization/Skill.md) |
| LCP poor, render delay large | Render-blocking CSS/JS, client rendering | [lcp-optimization](../lcp-optimization/Skill.md) |
| INP poor, input delay large | Long tasks during load, third parties | [inp-optimization](../inp-optimization/Skill.md), [third-party-script-management](../third-party-script-management/Skill.md) |
| INP poor, processing large | Heavy handlers, framework re-render | [inp-optimization](../inp-optimization/Skill.md) |
| INP poor, presentation large | Big DOM, layout thrash | [rendering-performance](../rendering-performance/Skill.md) |
| CLS poor | Images without dimensions, late ads/banners, fonts | [cls-prevention](../cls-prevention/Skill.md) |
| Good lab, poor field | Device/network mix, third parties, logged-in state | [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md) |

## Recommended Workflow
1. Pull CrUX for the origin and the top 10 URL templates in PSI or the CrUX API. Note phone vs desktop.
2. If there's no RUM, add the snippet above (attribution build) and collect at least a few days of data.
3. Rank templates by traffic × how far they miss the threshold. Choose a single metric and template to work on.
4. Use attribution to find the dominant subpart. Reproduce it in DevTools with 4× CPU throttling (or a calibrated preset) and a slow-4G profile.
5. Fix, then verify in the lab (trace plus Lighthouse). Ship behind a flag or to a canary if the change is risky.
6. Confirm in RUM within days and in CrUX after about 28 days. Add a regression budget ([performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md)).

## Patterns
- **Subpart-first triage**: always record the breakdown along with the metric value, then optimize the largest share.
- **Template grouping**: group URLs by route pattern (`/product/:id`) when reporting, so fixes map to code.
- **Release annotations**: tag RUM beacons with the build SHA so you can compare distributions per release.
- **Soft-nav aware SPA reporting**: `onINP(cb, { reportSoftNavs: true })` in web-vitals v6+, with the navigation URL included in each beacon.

## Anti-Patterns
- **Optimizing the Lighthouse score as the goal.** Lab scores use one simulated device and include no interactions. Fix: set goals on field p75.
- **Reporting FID or "TTI".** Both are deprecated. Fix: use INP and TBT.
- **Averaging metrics.** Averages hide the long tail. Fix: use p75, and p95 for alerting.
- **Mixing browsers in CLS.** Only Chromium reports it, so a "cross-browser" CLS is really Chrome-only. Fix: add a browser dimension.
- **Flushing beacons on `unload`.** It's unreliable and blocks bfcache. Fix: flush on `visibilitychange` or `pagehide`.
- **Fixing site-wide averages.** One slow template can dominate. Fix: segment by template.

## Accessibility
- Good CWV help assistive-tech users: fast INP matters for switch and keyboard users, whose activations also count as interactions.
- Stable layouts (CLS) prevent mis-taps and lost reading position for low-vision and cognitive-disability users (related to WCAG 2.2 SC 3.2.x predictability).
- Don't "improve" metrics in ways that hurt accessibility, such as removing focus styles or deferring skip links, or hiding content with `content-visibility` without reserving space.

## Responsive Design
- Phone and desktop are scored separately, and the LCP element is often different (hero image on desktop, a heading on mobile).
- Responsive art direction can change which image is the LCP, so verify LCP per breakpoint.
- Viewport-dependent CLS (for example, banners that wrap on narrow screens) only appears on mobile.

## Performance
This whole skill is about performance. Keep RUM overhead small: web-vitals is about 2 KB brotli (the attribution build is a bit larger). Load it after first paint using `type="module"` or dynamic import. Don't block rendering to measure it.

## Security
- RUM beacons can leak PII through URLs (query strings, IDs) and CSS selectors (user-generated class names). Strip query strings and hash IDs.
- Send beacons to a first-party endpoint and allow it in the CSP `connect-src`.
- Rate-limit and validate the ingestion endpoint. Anyone can POST fake metrics.

## Testing
- Unit-test beacon serialization, including that PII is stripped.
- In E2E runs (Playwright), read metrics with `page.evaluate` using the web-vitals IIFE build, or use a CDP trace. Assert only lab-stable metrics (CLS, LCP element identity) in CI; timings are noisy.
- Run Lighthouse CI with repeated runs (median of 3–5) for LCP, TBT and CLS assertions ([lighthouse-ci](../lighthouse-ci/Skill.md)).
- Test INP manually with DevTools interaction tracking at 4–6× CPU throttling.

## Tooling
- `web-vitals` (GoogleChrome) v6.x, Active. v6.0.0 (Jul 2026) added soft-navigation support. v5 removed `onFID`.
- PageSpeed Insights / CrUX API / CrUX History API / CrUX Vis, Active.
- Chrome DevTools Performance panel with live metrics and CrUX field data, Active.
- Lighthouse 13, Active. Insight-based audits shared with DevTools; scoring unchanged.
- Web Vitals Chrome extension. Most of its features now live in the DevTools live metrics view.
- Vercel Speed Insights (`@vercel/speed-insights/next`), Active. Free tier includes Real Experience Score; per-metric CWV, route and element breakdowns need Speed Insights Plus. Tracks preview and production deployments.
- RUM vendors: DebugBear, SpeedCurve, RUMvision, Calibre, Sentry, Datadog, New Relic, Akamai mPulse.

## Framework Notes
- **React (Vite SPA)**: call web-vitals once from `main.tsx`, outside the React tree, so re-renders never re-register observers. CSR SPAs usually have poor LCP (content waits for the JS bundle) and accumulate INP across client route changes. Enable `reportSoftNavs: true` (web-vitals v6, Chrome 151+) and include `location.pathname` in each beacon so metrics map to routes. Prerender marketing routes, or move them to Next.js, if field LCP fails.
- **Next.js (App Router)**: `useReportWebVitals` from `next/web-vitals` in a small `'use client'` component mounted in the root layout. Alternatively, use `@vercel/speed-insights/next` (`<SpeedInsights />`) on Vercel for zero-config RUM. `<Link>` navigations are soft navigations, so without soft-nav reporting the landing URL gets blamed for later-route INP. Pages served from the Full Route Cache or CDN usually have the best TTFB; dynamic routes need streaming. Route-level fixes are in [nextjs-performance](../nextjs-performance/Skill.md). Component-level re-render fixes are in [react-performance-optimization](../react-performance-optimization/Skill.md).
- Group RUM by route segment (`/products/[slug]`) using `useSelectedLayoutSegments()` or the route pattern, not the raw URL.

## AI Agent Guidance
- Do: ask for or fetch field data (PSI/CrUX) before proposing fixes. State which metric and subpart each change targets.
- Do: use the thresholds exactly as above (p75; 2.5 s / 200 ms / 0.1).
- Do: when you have Chrome DevTools MCP, record a trace (`performance_start_trace` with `reload: true`) and read the insights (`performance_analyze_insight`) instead of guessing.
- Don't: add `onFID`, import from `web-vitals/base` (removed), or flush on `unload`.
- Don't: claim a CWV improvement from a single local Lighthouse run.
- Before declaring done: the lab trace shows the targeted subpart reduced, no other CWV regressed, the RUM snippet (if added) sends on hidden, and a way to verify in the field is documented.

## Examples
```bash
# CrUX API: p75 for a URL on phones (requires an API key; keep it in env, never commit)
curl -s "https://chromeuxreport.googleapis.com/v1/records:queryRecord?key=$CRUX_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com/","formFactor":"PHONE","metrics":["largest_contentful_paint","interaction_to_next_paint","cumulative_layout_shift"]}' \
  | jq '.record.metrics | map_values(.percentiles.p75)'
```

```tsx
// app/_components/web-vitals.tsx: Next.js App Router
'use client';
import { useReportWebVitals } from 'next/web-vitals';

export function WebVitals() {
  useReportWebVitals((metric) => {
    const body = JSON.stringify({ name: metric.name, value: metric.value, rating: metric.rating,
                                  id: metric.id, path: location.pathname });
    navigator.sendBeacon('/api/rum', body);
  });
  return null;
}

// app/layout.tsx
import { WebVitals } from './_components/web-vitals';
import { SpeedInsights } from '@vercel/speed-insights/next'; // optional, if deployed on Vercel

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        {children}
        <WebVitals />
        <SpeedInsights />
      </body>
    </html>
  );
}
```

```ts
// app/api/rum/route.ts: first-party ingestion endpoint (validate; never trust client input)
export async function POST(req: Request) {
  const text = await req.text();
  if (text.length > 10_000) return new Response(null, { status: 413 });
  // parse, validate names/values, forward to your analytics store
  return new Response(null, { status: 204 });
}
```

## Related Skills
- [lcp-optimization](../lcp-optimization/Skill.md) — fixing loading
- [inp-optimization](../inp-optimization/Skill.md) — fixing responsiveness
- [cls-prevention](../cls-prevention/Skill.md) — fixing stability
- [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md) — collecting and guarding field data
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md) — lab diagnosis
- [frontend-observability](../frontend-observability/Skill.md) — wider telemetry pipeline
- [lighthouse-ci](../lighthouse-ci/Skill.md) — lab regression gates
- [seo-for-frontend](../seo-for-frontend/Skill.md) — CWV as a page-experience signal

## Sources
- [Web Vitals](https://web.dev/articles/vitals) — Official — metric definitions and thresholds
- [LCP and INP are now Baseline Newly available](https://web.dev/blog/lcp-and-inp-are-now-baseline-newly-available) — Official — Safari 26.2 cross-browser support
- [GoogleChrome/web-vitals README and CHANGELOG](https://github.com/GoogleChrome/web-vitals) — Open Source — API, attribution, v5/v6 changes, soft navs
- [Soft navigations](https://developer.chrome.com/docs/web-platform/soft-navigations-experiment) — Official — Chrome 151 shipping, SPA metric semantics
- [Lighthouse 13](https://developer.chrome.com/blog/lighthouse-13-0) — Official — insight audits, unchanged scoring
- [DebugBear: Firefox and Safari Web Vitals](https://www.debugbear.com/blog/firefox-safari-web-vitals) — Community — Safari INP caveats
- [addyosmani/web-quality-skills](https://github.com/addyosmani/web-quality-skills) — Open Source (MIT) — compared agent-skill structure and thresholds

## License / Usage Notes
web-vitals is Apache-2.0. web.dev content is CC BY 4.0 (code samples Apache-2.0). Guidance here is summarized and rewritten, not copied.

## Quality Tier
S — Based on official definitions checked against the current web-vitals v6 changelog and 2025–2026 browser support changes.

## Status
Active

## Last Verified
2026-09-15
