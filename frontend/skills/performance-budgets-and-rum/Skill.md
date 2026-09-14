# Performance Budgets and RUM

## Summary
Performance budgets are enforced limits on metrics and resources (e.g., LCP p75 ≤ 2.5 s, route first-load JS ≤ 170 KB brotli). Real User Monitoring (RUM) collects performance data from actual users so budgets reflect reality. This skill covers how to set up both for React and Next.js:
- Budget types.
- Collecting web-vitals with attribution.
- Choosing RUM tooling (Vercel Speed Insights, vendors, self-hosted).
- Segmenting data, alerting, and CI enforcement (size-limit, Lighthouse CI).
- A governance process that keeps performance from regressing.

## Category
Performance

## Subcategories
Performance budgets, milestone/quantity/rule budgets, RUM, web-vitals, CrUX API, Vercel Speed Insights, segmentation, alerting, SLOs, size-limit, Lighthouse CI assertions, release tracking

## Problem It Solves
Performance wins erode through small regressions. Teams can't see real-user impact or tie it to releases, and lab-only checks miss field problems. Budgets plus RUM make performance a tracked, owned, enforced requirement.

## When To Use
- Establishing performance goals for a product or team.
- After an optimization project, to lock in gains.
- Setting up monitoring for a new Next.js or Vite app.
- When field CWV regressions are discovered late (e.g., via Search Console).

## When Not To Use
- Prototypes with no users. Use lightweight lab checks only.
- As a replacement for diagnosis. Budgets flag problems; profiling explains them ([performance-profiling-devtools](../performance-profiling-devtools/Skill.md)).

## Core Principles
1. **Budget what users feel (field metrics) and what engineers control (bytes, requests, long tasks).** You need both.
2. **p75 per template and device class** as the primary target. p95 for alerting on tail regressions.
3. **Enforce in CI (lab/resource budgets) and monitor in production (field budgets).**
4. **Every budget has an owner and a response process.** A budget with no action on breach is decoration.
5. **Budgets tighten over time.** Ratchet down after improvements.

## Best Practices
- Starting budgets (adjust to your baseline and competitors):

  | Budget | Type | Starting value |
  |---|---|---|
  | LCP p75 (mobile) | Field milestone | ≤ 2.5 s |
  | INP p75 | Field milestone | ≤ 200 ms |
  | CLS p75 | Field milestone | ≤ 0.1 |
  | TTFB p75 | Field milestone | ≤ 0.8 s |
  | First-load JS per route | Quantity | ≤ 150–200 KB brotli |
  | Critical CSS | Quantity | ≤ 50 KB brotli |
  | Total page weight (landing) | Quantity | ≤ 1–1.5 MB |
  | Third-party JS | Quantity | ≤ 100 KB, ≤ 5 origins |
  | Lighthouse perf score (mobile, lab) | Rule | ≥ 90 on key templates (median of 3–5 runs) |
  | TBT (lab) | Milestone | ≤ 200 ms |

- Collect RUM with the web-vitals attribution build. Send route pattern, device, connection (`navigator.connection.effectiveType` where available), release SHA, and navigation type.
- Sample high-traffic sites (e.g., 10–25%), but don't sample so low that per-route p75s become noisy (aim for ≥ ~500 samples per segment per week).
- Cross-check RUM with CrUX (Chrome-only, 28-day rolling). Big gaps usually mean sampling or instrumentation bugs.
- Alert on sustained breaches (e.g., p75 over budget for 3 consecutive days, or a ≥ 20% jump after a release), not single spikes.
- Put budgets in the repo (size-limit config, LHCI config) so changes are reviewed.
- Report monthly: CWV pass rate by template, budget breaches, fixes shipped.

## Implementation Guidance

### RUM options
| Option | Pros | Cons |
|---|---|---|
| Vercel Speed Insights (`@vercel/speed-insights/next`) | Zero-config for Next.js on Vercel; per-route/element views; preview deployments | Vercel-only; full CWV breakdowns need Speed Insights Plus |
| Vendor RUM (DebugBear, SpeedCurve, RUMvision, Calibre, Sentry, Datadog) | Attribution dashboards, alerting, CrUX blending | Cost; third-party script weight |
| Self-hosted (web-vitals → `/api/rum` → warehouse) | Full control, joins with business data | Build dashboards, storage, and privacy handling yourself |
| CrUX API / History API / CrUX Vis | Free, Google's view of field data | Chrome-only, 28-day lag, needs traffic thresholds |

### Next.js: Speed Insights + custom attribution beacons
```tsx
// app/layout.tsx
import { SpeedInsights } from '@vercel/speed-insights/next';
import { RumReporter } from './_components/rum-reporter';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        {children}
        <SpeedInsights sampleRate={0.5} />
        <RumReporter release={process.env.NEXT_PUBLIC_RELEASE_SHA ?? 'dev'} />
      </body>
    </html>
  );
}
```
```tsx
// app/_components/rum-reporter.tsx
'use client';
import { useEffect } from 'react';

export function RumReporter({ release }: { release: string }) {
  useEffect(() => {
    if (Math.random() > 0.25) return;                        // 25% sampling
    let cancelled = false;
    import('web-vitals/attribution').then(({ onLCP, onINP, onCLS, onTTFB }) => {
      if (cancelled) return;
      const send = (m: { name: string; value: number; rating: string; id: string }) =>
        navigator.sendBeacon('/api/rum', JSON.stringify({
          n: m.name, v: Math.round(m.name === 'CLS' ? m.value * 1000 : m.value), r: m.rating, id: m.id,
          route: document.body.dataset.route ?? location.pathname,     // set data-route with the route pattern
          release, conn: (navigator as Navigator & { connection?: { effectiveType?: string } }).connection?.effectiveType,
        }));
      onLCP(send); onINP(send); onCLS(send); onTTFB(send);
    });
    return () => { cancelled = true; };
  }, [release]);
  return null;
}
```
(`sendBeacon` per metric is fine at low volume. Batch on `visibilitychange` for high volume, as in [core-web-vitals](../core-web-vitals/Skill.md).)

### CI resource budgets
```json
// .size-limit.json — Next.js example (paths depend on build output; prefer analyzer route data where available)
[
  { "name": "Vite SPA entry", "path": "dist/assets/index-*.js", "limit": "150 kB", "brotli": true },
  { "name": "Design system Button", "path": "packages/ui/dist/index.js", "import": "{ Button }", "limit": "5 kB" }
]
```

### Lighthouse CI assertions
```js
// lighthouserc.cjs
module.exports = {
  ci: {
    collect: { startServerCommand: 'pnpm start', url: ['http://localhost:3000/', 'http://localhost:3000/products/demo'], numberOfRuns: 5 },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9, aggregationMethod: 'median-run' }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['warn', { maxNumericValue: 200 }],
        'resource-summary:script:size': ['warn', { maxNumericValue: 350000 }],
      },
    },
    upload: { target: 'temporary-public-storage' },
  },
};
```
Details are in [lighthouse-ci](../lighthouse-ci/Skill.md).

### Field budget check (CrUX API, scheduled job)
```ts
const res = await fetch(`https://chromeuxreport.googleapis.com/v1/records:queryRecord?key=${process.env.CRUX_API_KEY}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ origin: 'https://example.com', formFactor: 'PHONE' }),
});
const { record } = await res.json();
const p75 = (m: string) => Number(record.metrics[m]?.percentiles?.p75);
const breaches = [
  p75('largest_contentful_paint') > 2500 && 'LCP',
  p75('interaction_to_next_paint') > 200 && 'INP',
  p75('cumulative_layout_shift') > 0.1 && 'CLS',
].filter(Boolean);
if (breaches.length) await notify(`CrUX budget breach: ${breaches.join(', ')}`);
```
Keep the API key in secrets or env. Never commit it.

## Recommended Workflow
1. **Baseline**: 2–4 weeks of RUM plus CrUX per template/device. Current bundle sizes and Lighthouse medians.
2. **Set budgets** at the current p75 or the CWV threshold, whichever is stricter-but-achievable. Document owners.
3. **Enforce resource budgets** in CI (size-limit, LHCI) on PRs. Require an explanation to raise a limit.
4. **Monitor field budgets**: dashboards per template, release annotations, alerts on sustained breaches.
5. **Respond**: a breach creates a ticket with attribution data, and the owner triages within an agreed SLA.
6. **Review monthly**: ratchet budgets after improvements; retire irrelevant ones.

## Patterns
- **Release-tagged RUM**: compare p75 before and after each deploy.
- **Budget ratchet**: lower limits after each win.
- **Performance champion rotation**: one engineer per sprint watches dashboards.
- **Dependency gate**: new dependency PRs show size-limit diff.
- **Template scorecard**: CWV pass/fail per route pattern and device, shared with product.

## Anti-Patterns
- **Single site-wide Lighthouse score as the budget.** Lab noise, ignores field and templates. Fix: field p75 per template plus resource budgets.
- **Budgets without CI enforcement or owners.** Fix: codify and assign.
- **Raw URLs as RUM dimensions.** High cardinality and PII. Fix: route patterns.
- **Alerting on daily p75 spikes from low sample counts.** Alert fatigue. Fix: minimum sample thresholds, multi-day windows.
- **RUM script loaded synchronously in `<head>`.** Hurts the metrics it measures. Fix: lazy import after load.
- **Ignoring Safari/Firefox now that LCP/INP are measurable there.** Fix: browser dimension (CLS remains Chromium-only).

## Accessibility
- Include assistive-tech-relevant flows (keyboard navigation, form submission) in lab budgets and INP monitoring.
- Performance dashboards and alerts must themselves be accessible (color plus text status, not red/green only) ([color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md)).

## Responsive Design
- Separate budgets for mobile and desktop. Mobile LCP/INP budgets are the ones that usually fail.
- Segment by viewport or device class; responsive layouts change LCP elements.

## Performance
- web-vitals is small (~2 KB brotli). Load it lazily. Speed Insights and vendor scripts add weight too, so count them in the third-party budget.

## Security
- RUM endpoints accept untrusted input: validate schema, cap payload size, rate-limit, and never reflect data unsanitized in dashboards (stored XSS).
- Strip query strings, emails, and IDs from URLs and selectors. Respect consent requirements for analytics (GDPR/ePrivacy).
- Keep CrUX/PSI API keys server-side.

## Testing
- Unit-test the beacon payload shape and PII stripping.
- CI: size-limit and LHCI on every PR to main. Nightly LHCI against staging.
- Synthetic monitoring (scheduled Lighthouse/WebPageTest) on production key pages as an early warning between CrUX updates.

## Tooling
- web-vitals v6 (soft navigations, attribution): Active.
- Vercel Speed Insights: Active (free Real Experience Score; Plus for per-metric breakdowns).
- CrUX API / CrUX History API / CrUX Vis / PageSpeed Insights API: Active.
- Lighthouse CI (`@lhci/cli`): Active.
- size-limit + size-limit-action: Active.
- RUM vendors: DebugBear, SpeedCurve, RUMvision, Calibre, Sentry, Datadog RUM, New Relic: Active.

## Framework Notes
- **Next.js**:
  - `<SpeedInsights />` or `useReportWebVitals` for RUM.
  - Tag beacons with the route pattern (e.g., from a `data-route` attribute set in each layout, or `useSelectedLayoutSegments`).
  - Budgets per route using `next experimental-analyze --output` snapshots.
  - Soft-navigation reporting (web-vitals v6) attributes client transitions correctly.
  - Route-level optimizations are in [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**:
  - Initialize web-vitals in `main.tsx`.
  - Route pattern from your router (React Router `useMatches()` / TanStack Router route IDs).
  - Entry chunk budget via size-limit on `dist/assets/index-*.js`.
  - Component-level budgets (React Profiler thresholds) only for critical interactions; see [react-performance-optimization](../react-performance-optimization/Skill.md).

## AI Agent Guidance
- Do: propose budgets from measured baselines, with owners, and codify them (size-limit / LHCI configs).
- Do: use route patterns and strip PII in RUM code you write. Load RUM scripts lazily.
- Don't: set budgets you can't enforce, or use a single Lighthouse score as the only budget.
- Don't: hardcode API keys; use env/secrets.
- Before declaring done: CI fails on a deliberate budget-violating change (test it), RUM beacons arrive with route/release/device dimensions, and dashboards or alerts are defined with sample thresholds.

## Examples
```yaml
# .github/workflows/perf-budgets.yml (excerpt)
name: perf-budgets
on: pull_request
jobs:
  size:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile && pnpm build
      - run: npx size-limit
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile && pnpm build
      - run: npx @lhci/cli autorun
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md): metric definitions and RUM snippet
- [lighthouse-ci](../lighthouse-ci/Skill.md): lab enforcement details
- [bundle-optimization](../bundle-optimization/Skill.md): meeting resource budgets
- [frontend-observability](../frontend-observability/Skill.md): telemetry pipelines
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md): wiring checks into CI
- [third-party-script-management](../third-party-script-management/Skill.md): third-party budgets
- [dashboard-design](../dashboard-design/Skill.md): presenting performance data

## Sources
- [web.dev: Performance budgets 101](https://web.dev/articles/performance-budgets-101) (Official): budget types
- [web-vitals](https://github.com/GoogleChrome/web-vitals) (Open Source): RUM collection, attribution, soft navs (v6)
- [Vercel Speed Insights](https://vercel.com/docs/speed-insights) (Official): features, RES, Plus tier, preview tracking
- [CrUX API](https://developer.chrome.com/docs/crux/api) (Official): field data queries
- [Lighthouse CI configuration](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/configuration.md) (Open Source): assertions
- [size-limit](https://github.com/ai/size-limit) (Open Source): budgets and CI action
- [addyosmani/web-quality-skills](https://github.com/addyosmani/web-quality-skills) (Open Source, MIT): community agent-skill budget recommendations (compared)
- [Tim Kadlec: performance budgets writing](https://timkadlec.com/) (Community): budget governance

## License / Usage Notes
Summarized. Configs original. Budget numbers are recommendations, not standards.

## Quality Tier
A: Official tooling verified. Budget values are pragmatic defaults to calibrate per product.

## Status
Active

## Last Verified
2026-09-15
