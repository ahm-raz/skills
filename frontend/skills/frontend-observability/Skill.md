# Frontend Observability

## Summary
Instrumenting React and Next.js apps so production behavior is visible: errors, traces, logs, Real User Monitoring (Core Web Vitals), custom business events, and session context — correlated from browser to server. Covers Next.js `instrumentation.ts` (`register`, `onRequestError`), `instrumentation-client.ts` (Next.js 15.3+, `onRouterTransitionStart`), OpenTelemetry (server: stable; browser: experimental `@opentelemetry/browser-instrumentation`), Sentry v10, sampling, privacy, and source maps.

## Category
Tooling

## Subcategories
Error monitoring, RUM, Core Web Vitals, distributed tracing, OpenTelemetry, structured logging, session replay, source maps, sampling, PII scrubbing, alerting

## Problem It Solves
Frontend failures are invisible without instrumentation: users hit JS errors on specific browsers, slow INP on low-end devices, or broken checkout flows, and teams learn from support tickets. Correlated telemetry turns "it's broken" into a trace with release, route, device, and the backend span that failed.

## When To Use
- Every production app (minimum: error monitoring + Web Vitals).
- Before launches, migrations (SPA -> Next.js), or experiments.
- When debugging performance regressions or backend latency visible to users.

## When Not To Use
- Don't ship heavy session replay or full-fidelity tracing to 100% of users by default; sample.
- Don't use analytics product tools as your error/perf monitoring (different retention, sampling, and semantics).

## Core Principles
1. **Correlate everything:** release/version, route pattern, trace ID, anonymized user/session ID on every event.
2. **Measure real users** (RUM) — lab tests don't capture device/network diversity.
3. **Instrument at framework seams** (router transitions, fetch, error boundaries, server request hooks) instead of sprinkling calls.
4. **Sample deliberately:** keep 100% of errors (with rate limits), sample traces/replays.
5. **Privacy by default:** scrub PII, mask replays, respect consent.
6. **Vendor-neutral where practical:** OpenTelemetry on the server; browser OTel is still experimental, so a vendor SDK is acceptable client-side.
7. **Alert on user impact** (error rate per route, p75 INP/LCP regressions), not on raw event counts.

## Best Practices
- Signals to capture:
  | Signal | Browser | Server (Next.js) |
  |---|---|---|
  | Errors | Uncaught errors, boundary errors, unhandled rejections | `onRequestError` (render, route, action, proxy) |
  | Performance | LCP, INP, CLS, TTFB (p75 by route/device) | Request spans, fetch spans, render spans |
  | Traces | Navigation, fetch with `traceparent` | Next.js built-in OTel spans |
  | Logs | Breadcrumbs (navigation, clicks, console warnings) | Structured JSON logs with trace IDs |
  | Business | Funnel steps, experiment exposure | Server Action outcomes |
- Report Web Vitals with attribution builds (`web-vitals/attribution`) to find the element/interaction responsible; group by route pattern (`/product/[id]`), not raw URL.
- Next.js: `useReportWebVitals` from `next/web-vitals` in a small client component, or the monitoring SDK's integration.
- Put client SDK initialization in `instrumentation-client.ts` (runs after HTML load, before hydration; keep init < 16ms; async work is fire-and-forget).
- Use `onRouterTransitionStart` for navigation breadcrumbs/spans in App Router.
- Propagate W3C Trace Context (`traceparent`) from browser fetches to your APIs; configure allowed origins so it isn't sent to third parties (CORS preflight implications).
- Upload source maps to your monitoring vendor at build; don't publicly serve them (or restrict access).
- Tag every event with `release` = git SHA and `environment`.
- Set `NEXT_OTEL_VERBOSE=1` only when debugging (more spans); `NEXT_OTEL_FETCH_DISABLED=1` if using custom fetch instrumentation.
- Use `navigator.sendBeacon`/`fetch(..., { keepalive: true })` for flushing on `visibilitychange` (hidden), not `unload`.
- Rate-limit and dedupe noisy errors (browser extensions, ResizeObserver loop warnings, third-party scripts) with ignore rules and `allowUrls`.

## Implementation Guidance

### Next.js server: OpenTelemetry via @vercel/otel
```ts
// instrumentation.ts (project root or src/)
import { registerOTel } from '@vercel/otel';
import type { Instrumentation } from 'next';

export function register() {
  registerOTel({ serviceName: 'web-app' }); // exports via OTLP env vars (OTEL_EXPORTER_OTLP_ENDPOINT)
}

export const onRequestError: Instrumentation.onRequestError = async (err, request, context) => {
  const e = err instanceof Error ? err : new Error(String(err));
  logger.error({
    msg: e.message, stack: e.stack,
    digest: typeof err === 'object' && err && 'digest' in err ? String((err as { digest: unknown }).digest) : undefined,
    path: request.path, method: request.method,
    routePath: context.routePath, routeType: context.routeType, renderSource: context.renderSource,
  });
};
```
Manual alternative: `NodeSDK` in `instrumentation.node.ts`, imported only when `process.env.NEXT_RUNTIME === 'nodejs'` (NodeSDK is not Edge-compatible).

### Custom server span
```ts
import { trace } from '@opentelemetry/api';
export async function priceCart(cartId: string) {
  return trace.getTracer('checkout').startActiveSpan('priceCart', async (span) => {
    try {
      span.setAttribute('cart.id', cartId);
      return await pricing.compute(cartId);
    } catch (err) {
      span.recordException(err as Error);
      throw err;
    } finally {
      span.end();
    }
  });
}
```

### Next.js client instrumentation
```ts
// instrumentation-client.ts
import { initMonitoring, addBreadcrumb } from '@/shared/monitoring/client';
initMonitoring({
  release: process.env.NEXT_PUBLIC_RELEASE,
  tracesSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  replaysSessionSampleRate: 0.0,
});
export function onRouterTransitionStart(url: string, navigationType: 'push' | 'replace' | 'traverse') {
  addBreadcrumb({ category: 'navigation', message: `${navigationType} ${url}` });
}
```
With Sentry: `@sentry/nextjs` wizard generates `instrumentation-client.ts`, `instrumentation.ts`, and `withSentryConfig` in `next.config.ts` (SDK v10; FID no longer reported, INP instead).

### Web Vitals reporting (Next.js)
```tsx
// app/_components/web-vitals.tsx
'use client';
import { useReportWebVitals } from 'next/web-vitals';
import { useParams, usePathname } from 'next/navigation';
export function WebVitals() {
  useReportWebVitals((metric) => {
    const body = JSON.stringify({ name: metric.name, value: metric.value, rating: metric.rating, id: metric.id,
      navigationType: metric.navigationType, path: location.pathname });
    navigator.sendBeacon?.('/api/vitals', body) || fetch('/api/vitals', { body, method: 'POST', keepalive: true });
  });
  return null;
}
```
Mount once in the root layout. Group server-side by route pattern.

### Web Vitals reporting (Vite SPA)
```ts
import { onCLS, onINP, onLCP, onTTFB } from 'web-vitals/attribution';
const send = (m: { name: string; value: number; rating: string; attribution?: unknown }) =>
  navigator.sendBeacon('/rum', JSON.stringify({ ...m, route: currentRoutePattern(), release: import.meta.env.VITE_RELEASE }));
onLCP(send); onINP(send); onCLS(send); onTTFB(send);
```

### Browser OpenTelemetry (experimental)
```ts
import { logs } from '@opentelemetry/api-logs';
import { LoggerProvider, BatchLogRecordProcessor } from '@opentelemetry/sdk-logs';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-http';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { NavigationTimingInstrumentation, ResourceTimingInstrumentation } from '@opentelemetry/browser-instrumentation/experimental';
const provider = new LoggerProvider({ processors: [new BatchLogRecordProcessor(new OTLPLogExporter({ url: '/otel/v1/logs' }))] });
logs.setGlobalLoggerProvider(provider);
registerInstrumentations({ instrumentations: [new NavigationTimingInstrumentation(), new ResourceTimingInstrumentation()] });
```
Status: experimental, event-based (log records) instrumentations for navigation/resource timing, user actions, web vitals, console; expect breaking changes. Send to a same-origin collector proxy, never expose collector credentials.

### Sampling guide
| Signal | Default sample | Notes |
|---|---|---|
| Errors | 100% with per-issue rate limits | Filter known noise |
| Web Vitals | 100% (tiny payload) or 10–50% at high traffic | Keep enough per route for p75 |
| Traces | 5–20% | Raise temporarily during incidents |
| Session replay | 0–5% sessions, 100% on error (masked) | Consent-dependent |

## Recommended Workflow
1. Define SLOs: JS error-free session rate, p75 LCP/INP/CLS per key route, checkout success rate.
2. Install error monitoring (client + `onRequestError`) with release tagging and source-map upload.
3. Add Web Vitals reporting with route grouping.
4. Enable server OTel; propagate `traceparent` from client to first-party APIs.
5. Add breadcrumbs at router transitions and key business events.
6. Configure PII scrubbing, consent gating, and sampling.
7. Build dashboards/alerts per route; review weekly; add regression alerts to release process.

## Patterns
- **Single monitoring facade** (`shared/monitoring`) wrapping the vendor SDK: `captureError`, `addBreadcrumb`, `trackEvent`.
- **Release health:** compare error-free sessions and vitals between releases; auto-rollback triggers.
- **Digest correlation:** user-visible error reference = server `digest`/trace ID.
- **Same-origin telemetry tunnel** (`/monitoring` route) to reduce ad-blocker loss and avoid CSP `connect-src` sprawl.
- **Route pattern tagging** to aggregate dynamic URLs.

## Anti-Patterns
- **Logging PII** (emails, tokens, full request bodies) — privacy/legal breach. Fix: scrub in `beforeSend`, allowlist fields.
- **Raw URL as dimension** (`/product/123`) — cardinality explosion. Fix: route pattern.
- **100% replay/trace sampling** — cost and performance hit. Fix: sampling table.
- **Public source maps with sensitive code comments** — Fix: upload privately, delete from deploy output or restrict.
- **Measuring FID** — deprecated metric (replaced by INP in 2024). Fix: INP.
- **`unload` handlers for flushing** — unreliable, breaks bfcache. Fix: `visibilitychange` + `sendBeacon`.
- **Heavy SDK init blocking hydration** — Fix: keep `instrumentation-client.ts` light, lazy-load replay.
- **Sending `traceparent` to all origins** — CORS failures on third parties. Fix: allowlist first-party origins.

## Accessibility
- Instrument accessibility-relevant signals: keyboard-only journey failures (E2E), focus-loss errors, and client-side a11y violations sampled from dev/staging (axe) — not a replacement for audits.
- Session replay must mask sensitive inputs and should respect users' reduced-data preferences; don't record assistive-technology-identifying details.

## Responsive Design
- Segment vitals and errors by device class, viewport width bucket, and connection type — mobile regressions are often invisible in desktop aggregates.

## Performance
- Load monitoring SDKs efficiently (tree-shaken integrations; replay lazy-loaded).
- Batch and compress telemetry; flush on page hide.
- Observer overhead: `PerformanceObserver` with `buffered: true` is cheap; avoid long tasks in `beforeSend`.

## Security
- CSP: add telemetry endpoints to `connect-src`; prefer a same-origin tunnel.
- Never embed secret ingestion keys in client bundles (DSNs/client keys designed to be public are fine; server tokens are not).
- Scrub auth headers/cookies from captured requests; OWASP A09:2025 Security Logging and Alerting Failures — ensure security-relevant events (auth failures, CSP violations) are logged and alerted.
- Collect CSP violation reports (`report-to`) into the same pipeline.

## Testing
- Verify in staging: throw test errors in client, RSC, Server Action, Route Handler; confirm each arrives once with release, route, and trace ID.
- Unit test scrubbing functions (`beforeSend`) with PII fixtures.
- Local OTel collector (e.g., Vercel's OpenTelemetry dev setup, Jaeger) to inspect spans.
- Lighthouse CI for lab vitals; RUM for field.

## Tooling
- Next.js `instrumentation.ts` (`register`, `onRequestError` since 15.0) — Active; `instrumentation-client.ts` (15.3+; router transition event experimental in 16.3) — Active.
- `@vercel/otel` — Active (Node + Edge); OpenTelemetry JS SDK 2.x — Active (server).
- `@opentelemetry/browser-instrumentation` — Experimental.
- Sentry JavaScript SDK v10 (`@sentry/nextjs`, `@sentry/react`) — Active.
- `web-vitals` library (v5) — Active.
- Alternatives: Datadog RUM, New Relic Browser, Grafana Faro (OTel-based), Honeycomb, PostHog, Vercel Speed Insights/Observability — Commercial/Open core.

## Framework Notes
- **React (Vite SPA):** initialize SDK in `main.tsx` before `createRoot`; use React root `onUncaughtError`/`onCaughtError`; instrument router navigations (React Router/TanStack Router integrations); inject release via `define`/`import.meta.env`; upload source maps via vendor Vite plugin (`build.sourcemap: 'hidden'`).
- **Next.js App Router:** use `instrumentation.ts` for server (Node vs Edge via `process.env.NEXT_RUNTIME`), `instrumentation-client.ts` for browser, `useReportWebVitals` for vitals. Next.js emits built-in spans (`[http.method] [next.route]`, `render route (app)`, `fetch`, `generateMetadata`, `start response`) with `next.route` attributes — use them for route-level dashboards. Server Action errors appear with `routeType: 'action'`.

## AI Agent Guidance
- Use the existing monitoring facade; don't add a second SDK or raw `console.error` as reporting.
- Do: tag events with route pattern and release; scrub PII; add breadcrumbs for new critical flows; keep client init light.
- Don't: log tokens/emails/request bodies, sample errors to 0, add `unload` listeners, or expose server telemetry keys.
- Verify: trigger an error in the new code path in a preview deploy and confirm it appears once with correct route, release, and trace correlation; Web Vitals still reported.

## Examples
```ts
// shared/monitoring/scrub.ts
const SENSITIVE = /(authorization|cookie|password|token|secret|email)/i;
export function scrub<T extends Record<string, unknown>>(data: T): T {
  return Object.fromEntries(Object.entries(data).map(([k, v]) =>
    [k, SENSITIVE.test(k) ? '[redacted]' : typeof v === 'object' && v ? scrub(v as Record<string, unknown>) : v])) as T;
}
```
```ts
// app/api/vitals/route.ts — minimal RUM ingestion
export async function POST(req: Request) {
  const m = await req.json();
  if (!['LCP', 'INP', 'CLS', 'TTFB', 'FCP'].includes(m?.name)) return new Response(null, { status: 400 });
  await metrics.record(m.name, Number(m.value), { route: normalizeRoute(String(m.path)), rating: String(m.rating) });
  return new Response(null, { status: 204 });
}
```

## Related Skills
- [frontend-error-handling-architecture](../frontend-error-handling-architecture/Skill.md) — what gets reported and where
- [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md) — RUM budgets
- [core-web-vitals](../core-web-vitals/Skill.md) — metric definitions
- [feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md) — exposure/guardrails
- [content-security-policy](../content-security-policy/Skill.md) — connect-src, violation reports
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) — collectors when self-hosting

## Sources
- [Next.js: OpenTelemetry guide](https://nextjs.org/docs/app/guides/open-telemetry) — Official — @vercel/otel, NodeSDK, default spans, env flags
- [Next.js: instrumentation.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation) — Official — register, onRequestError
- [Next.js: instrumentation-client.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client) — Official — client init timing, onRouterTransitionStart
- [OpenTelemetry Browser repo](https://github.com/open-telemetry/opentelemetry-browser) — Official — experimental browser instrumentations
- [OpenTelemetry JavaScript docs](https://opentelemetry.io/docs/languages/js/) — Official — browser status experimental
- [Sentry: Migrate 9.x to 10.x](https://docs.sentry.io/platforms/javascript/migration/v9-to-v10/) — Official — v10 changes (FID removed, OTel 2.x)
- [web-vitals](https://github.com/GoogleChrome/web-vitals) — Official (Google) — metrics library
- [OWASP Top 10:2025](https://top10.owasp.org/2025) — Official — A09 logging and alerting

## License / Usage Notes
Summarized from official docs; examples original or reduced from documented API shapes. OpenTelemetry Apache-2.0; Sentry SDK MIT; web-vitals Apache-2.0.

## Quality Tier
A — Next.js and OTel docs verified Sept 2026 (Next.js 16.3.5); browser OTel is experimental and flagged.

## Status
Active

## Last Verified
2026-09-15
