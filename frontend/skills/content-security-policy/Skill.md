# Content Security Policy

## Summary
Designing, deploying, and maintaining a strict Content Security Policy for React and Next.js apps: nonce-based CSP via `proxy.ts` in Next.js 16 (with its dynamic-rendering cost), hash/SRI-based CSP for static output (Next.js experimental SRI, Vite SPAs), `strict-dynamic`, Trusted Types enforcement (Baseline 2026), reporting (`report-to`/`Reporting-Endpoints`), third-party scripts, and rollout via report-only mode. Allowlist-based CSPs are flagged as outdated and bypassable.

## Category
Security

## Subcategories
Strict CSP, nonces, hashes, strict-dynamic, Trusted Types, frame-ancestors, reporting, report-only, SRI, third-party scripts, Next.js proxy

## Problem It Solves
XSS remains among the most common web vulnerabilities; a single injection can steal sessions or perform actions as the user. A strict CSP blocks injected scripts even when escaping fails, limits exfiltration channels, and prevents clickjacking — but naive host allowlists are easily bypassed and break apps. A correct, framework-aware policy gives real protection without breaking hydration.

## When To Use
- Any production React/Next.js app, especially those rendering user or CMS content, handling auth, payments, or PII.
- Compliance requirements (PCI DSS 4.0 script integrity requirements for payment pages).

## When Not To Use
- Don't ship an enforced policy without a report-only period on real traffic.
- Don't use CSP as the only XSS defense — escaping, sanitization, and Trusted Types still required.

## Core Principles
1. **Strict over allowlist:** `script-src 'nonce-…'` or hashes with `'strict-dynamic'`; host allowlists alone are bypassable (JSONP, open redirects, CDN-hosted gadgets).
2. **Always include** `object-src 'none'` and `base-uri 'none'` (or `'self'`).
3. **Nonces are per response,** cryptographically random (≥128 bits), never reused or cached.
4. **Report-only first, then enforce;** keep reporting on permanently.
5. **Lock DOM sinks with Trusted Types** after script-src is strict.
6. **Framework-aware:** Next.js must see the nonce in the request CSP header to apply it to its scripts.
7. **Policies are code:** versioned, tested, reviewed.

## Best Practices
- Reference strict policy (web.dev):
  - Nonce-based (server-rendered): `script-src 'nonce-{RANDOM}' 'strict-dynamic'; object-src 'none'; base-uri 'none';`
  - Hash-based (static): `script-src 'sha256-{HASH}' 'strict-dynamic'; object-src 'none'; base-uri 'none';`
  - Optional backward-compat fallbacks ignored by modern browsers: `'unsafe-inline' https:` alongside nonce + `'strict-dynamic'`.
- Add: `frame-ancestors 'none'` (clickjacking), `form-action 'self'`, `upgrade-insecure-requests`, `connect-src` for APIs/telemetry, `img-src`/`font-src`/`style-src` as needed.
- Next.js nonce specifics (16.x):
  - Generate nonce in `proxy.ts`, set `Content-Security-Policy` on both the request headers (so Next.js extracts the nonce and applies it to framework scripts, page bundles, inline scripts/styles, and `<Script nonce>`) and the response.
  - Pages using nonces must be dynamically rendered (`await connection()` or dynamic APIs); static generation, ISR, CDN caching, and Partial Prerendering are incompatible with per-request nonces.
  - Dev needs `'unsafe-eval'` (React debugging); production does not.
  - Exclude static assets and prefetch requests from the proxy matcher.
- Next.js static alternative: `experimental.sri` (sha256/384/512) adds `integrity` to scripts at build so you can use a CSP without nonces and keep static rendering (experimental, App Router only, can't cover dynamic inline scripts).
- Vite SPA: host `index.html` statically; move inline scripts to files; use hash-based CSP for any remaining inline script (compute hashes at build); set headers at CDN/host. Avoid libraries requiring `'unsafe-eval'`.
- Styles: `style-src 'self' 'nonce-…'` in Next.js; many CSS-in-JS runtimes need nonce support or `'unsafe-inline'` for styles (lower risk than scripts, but prefer zero-runtime CSS). Inline `style=""` attributes need `'unsafe-inline'` or `'unsafe-hashes'` — React `style` props set via CSSOM are not blocked by `style-src` (only HTML attributes parsed from markup are).
- Trusted Types: `require-trusted-types-for 'script'; trusted-types <policy names> 'allow-duplicates'?` — deploy report-only first; framework/library policy names must be allowed.
- Reporting: `Reporting-Endpoints: csp="https://example.com/csp-reports"` + `report-to csp`; keep `report-uri` as fallback for older browsers. Filter noise from extensions.
- Third-party scripts: load via `next/script` or `@next/third-parties` with the nonce; `'strict-dynamic'` lets nonce-trusted loaders add their scripts; add their `connect-src`/`img-src`/`frame-src` endpoints.
- Evaluate policies with CSP Evaluator and Lighthouse.

## Implementation Guidance

### Next.js 16 `proxy.ts` (nonce-based)
```ts
// src/proxy.ts
import { NextResponse, type NextRequest } from 'next/server';

export function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64');
  const isDev = process.env.NODE_ENV === 'development';
  const csp = [
    `default-src 'self'`,
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${isDev ? ` 'unsafe-eval'` : ''}`,
    `style-src 'self' ${isDev ? `'unsafe-inline'` : `'nonce-${nonce}'`}`,
    `img-src 'self' blob: data:`,
    `font-src 'self'`,
    `connect-src 'self' https://api.example.com`,
    `object-src 'none'`,
    `base-uri 'self'`,
    `form-action 'self'`,
    `frame-ancestors 'none'`,
    `upgrade-insecure-requests`,
    `report-to csp`,
  ].join('; ');

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-nonce', nonce);
  requestHeaders.set('Content-Security-Policy', csp);

  const response = NextResponse.next({ request: { headers: requestHeaders } });
  response.headers.set('Content-Security-Policy', csp);
  response.headers.set('Reporting-Endpoints', 'csp="/api/csp-report"');
  return response;
}

export const config = {
  matcher: [{
    source: '/((?!api|_next/static|_next/image|favicon.ico).*)',
    missing: [
      { type: 'header', key: 'next-router-prefetch' },
      { type: 'header', key: 'purpose', value: 'prefetch' },
    ],
  }],
};
```
Rollout: first set `Content-Security-Policy-Report-Only` on the response (keep the request header so nonces are still applied), monitor, then switch.

### Reading the nonce for third-party scripts
```tsx
// app/layout.tsx
import { headers } from 'next/headers';
import Script from 'next/script';
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const nonce = (await headers()).get('x-nonce') ?? undefined;
  return (
    <html lang="en">
      <body>
        {children}
        <Script src="https://www.googletagmanager.com/gtag/js?id=G-XXXX" strategy="afterInteractive" nonce={nonce} />
      </body>
    </html>
  );
}
```

### Static/cached pages: SRI-based policy (experimental)
```ts
// next.config.ts
import type { NextConfig } from 'next';
const csp = `default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:; font-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests`;
const config: NextConfig = {
  experimental: { sri: { algorithm: 'sha256' } },
  async headers() { return [{ source: '/(.*)', headers: [{ key: 'Content-Security-Policy', value: csp }] }]; },
};
export default config;
```
Verify no inline scripts remain that would need `'unsafe-inline'` (Next.js may emit inline bootstrap data; test in your version).

### Vite SPA on a CDN (hash-based)
```
Content-Security-Policy: default-src 'self'; script-src 'self' 'sha256-<hash-of-inline-theme-script>'; style-src 'self'; img-src 'self' data: https://images.example.com; connect-src 'self' https://api.example.com; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'; report-to csp
```
Compute hash: `echo -n "<exact inline script content>" | openssl sha256 -binary | openssl base64` (whitespace matters).

### Trusted Types rollout header
```
Content-Security-Policy-Report-Only: require-trusted-types-for 'script'; trusted-types default dompurify; report-to csp
```

### Report ingestion (Route Handler)
```ts
// app/api/csp-report/route.ts
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);          // application/reports+json (array) or legacy csp-report
  const reports = Array.isArray(body) ? body : [body?.['csp-report']].filter(Boolean);
  for (const r of reports.slice(0, 20)) {
    const b = r.body ?? r;
    if (String(b.sourceFile ?? b['source-file'] ?? '').startsWith('chrome-extension')) continue;
    logger.warn({ type: 'csp-violation', directive: b.effectiveDirective ?? b['violated-directive'], blocked: b.blockedURL ?? b['blocked-uri'], doc: b.documentURL ?? b['document-uri'] });
  }
  return new Response(null, { status: 204 });
}
```
Exclude this route from the CSP proxy matcher (already excluded via `api`) and rate-limit it.

### Directive decision table
| Need | Directive |
|---|---|
| Block injected scripts | `script-src 'nonce-x' 'strict-dynamic'` |
| Block plugins | `object-src 'none'` |
| Block `<base>` hijack | `base-uri 'none'`/`'self'` |
| Prevent framing | `frame-ancestors 'none'` |
| Restrict form posts | `form-action 'self'` |
| Limit exfiltration via fetch/XHR/WebSocket | `connect-src` explicit list |
| Embed YouTube/Stripe | `frame-src https://www.youtube-nocookie.com https://js.stripe.com` |
| WebAssembly | `'wasm-unsafe-eval'` in `script-src` |
| Lock DOM sinks | `require-trusted-types-for 'script'` |

## Recommended Workflow
1. Inventory scripts: inline scripts, event handler attributes, `javascript:` URLs, `eval` usage, third parties.
2. Refactor inline handlers to `addEventListener`/React handlers; remove `eval`/`new Function`.
3. Choose nonce (dynamic Next.js) or hash/SRI (static, SPA) strategy per route group.
4. Deploy `Content-Security-Policy-Report-Only` with reporting; monitor 1–2 weeks across browsers.
5. Fix violations; add required third-party endpoints narrowly.
6. Enforce; keep report-only for the next tightening step (Trusted Types).
7. Add tests asserting header presence and key directives; review on every third-party addition.

## Patterns
- **Nonce in proxy, read via `headers()`** for `next/script`.
- **Split policy by route group:** dynamic authenticated app with nonces; static marketing pages with SRI/hash policy.
- **Report-only shadow policy** for the next tightening step while enforcing the current one.
- **Third-party registry** documenting each vendor's required directives and owner.
- **Same-origin telemetry tunnel** to keep `connect-src` short.

## Anti-Patterns
- **Host allowlists only** (`script-src 'self' https://cdn.example.com https://www.google.com`) — bypassable. Fix: nonce/hash + `'strict-dynamic'`.
- **`'unsafe-inline'` without nonce/hash in `script-src`** — negates XSS protection. Fix: nonces.
- **`'unsafe-eval'` in production** — Fix: remove eval-dependent libs; dev only.
- **Static nonce or nonce cached by CDN** — attacker can reuse. Fix: per-request nonce, dynamic rendering, no shared caching.
- **Setting CSP only on the response in Next.js** (not on request headers) — Next.js can't apply nonce to its scripts; app breaks. Fix: set both.
- **Using nonce CSP with PPR/ISR expectations** — incompatible. Fix: SRI/hash for static routes.
- **Enforcing without report-only** — production outage. Fix: staged rollout.
- **`X-Frame-Options` alone** — Fix: `frame-ancestors`.
- **Ignoring reports forever** — Fix: triage dashboard, alert on new directive violations.
- **`<meta http-equiv="Content-Security-Policy">` for frame-ancestors/reporting** — unsupported in meta. Fix: HTTP headers.

## Accessibility
- CSP shouldn't affect accessibility, but blocked scripts can break interactive widgets and focus management silently — include keyboard/screen-reader smoke tests in CSP rollout.
- Blocked third-party accessibility overlays or captioning services must be allowed explicitly if relied upon (prefer native accessible implementations).

## Responsive Design
- Not directly applicable; verify responsive image CDNs are allowed in `img-src`.

## Performance
- Nonce-based CSP in Next.js forces dynamic rendering: slower TTFB, no CDN caching, higher server cost. Use it where risk justifies; SRI/hash policies preserve static performance.
- CSP header size: keep policies compact; very large headers can exceed proxy limits.
- `'strict-dynamic'` avoids maintaining large allowlists and reduces breakage when vendors add subdomains.

## Security
- CSP mitigates XSS impact (OWASP A05:2025 Injection) and clickjacking; Trusted Types closes DOM XSS sinks.
- Nonce generation: `crypto.randomUUID()` base64 as in Next.js docs, or `crypto.getRandomValues(new Uint8Array(16))` base64.
- Violation reports may contain URLs with tokens/PII — scrub before storage.
- PCI DSS 4.0 (req. 6.4.3/11.6.1) payment-page script inventory and integrity monitoring: CSP + reporting supports compliance.

## Testing
- Playwright: assert `content-security-policy` header on key routes; assert nonce differs between two requests; listen to `page.on('console')` for CSP violation messages during E2E; inject a test payload and assert it doesn't execute.
- CSP Evaluator in CI (or custom check for `'unsafe-inline'`/`'unsafe-eval'` in production policies).
- Lighthouse "Ensure CSP is effective against XSS attacks" audit.

## Tooling
- Next.js 16 `proxy.ts` nonce CSP — Active (official guide); `experimental.sri` — Experimental.
- `@next/third-parties` — Active (nonce props).
- CSP Evaluator (Google) — Active.
- Lighthouse CSP audit — Active.
- Report collectors: URIports, Report URI, Sentry CSP reports, self-hosted Route Handler — Commercial/Self-hosted.
- Trusted Types — Baseline 2026 (Chrome/Edge 83+, Safari 26, Firefox 2026).
- Helmet (Express) — Active, for custom Node servers only.

## Framework Notes
- **React (Vite SPA):** no per-request server, so use hash-based or `'self'`-only script policies set by the host/CDN (Netlify `_headers`, Vercel `vercel.json`, CloudFront response headers policy, nginx). Keep `index.html` free of inline scripts; if you need a theme pre-paint script, hash it. Vite dev server injects inline scripts/HMR — apply strict CSP only to production.
- **Next.js App Router:** nonce CSP in `proxy.ts` (renamed from `middleware.ts` in Next.js 16) with both request and response headers; Next.js auto-applies the nonce to framework scripts and `<Script nonce>`; routes must be dynamic; exclude `_next/static`, `_next/image`, and prefetches from the matcher. For static/marketing routes, prefer `experimental.sri` + static CSP in `next.config.ts` headers. Server Actions and RSC payloads don't require extra directives beyond `'self'` in `connect-src`/`form-action`.

## AI Agent Guidance
- Check the existing CSP (proxy, next.config headers, host config) before adding scripts, iframes, fonts, or API origins.
- Do: pass the nonce to `next/script` for any new script; add the narrowest directive entry needed; update the third-party registry; test in report-only locally.
- Don't: add `'unsafe-inline'` or `'unsafe-eval'` to production `script-src`, add inline event handler attributes, or inject `<script>` tags manually.
- Verify: no CSP violations in the browser console during E2E, header present on target routes, nonce varies per request, Lighthouse CSP audit passes.

## Examples
```ts
// Playwright check
test('CSP is strict and nonce rotates', async ({ request }) => {
  const a = (await request.get('/dashboard')).headers()['content-security-policy'];
  const b = (await request.get('/dashboard')).headers()['content-security-policy'];
  expect(a).toContain("'strict-dynamic'");
  expect(a).toContain("object-src 'none'");
  expect(a).not.toMatch(/script-src[^;]*'unsafe-eval'/);
  expect(a.match(/nonce-([^']+)/)?.[1]).not.toEqual(b.match(/nonce-([^']+)/)?.[1]);
});
```

## Related Skills
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — XSS context and Trusted Types policy
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — proxy.ts mechanics
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md) — dynamic rendering cost of nonces
- [third-party-script-management](../third-party-script-management/Skill.md) — vendor scripts
- [frontend-observability](../frontend-observability/Skill.md) — violation reporting pipeline
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md) — script integrity

## Sources
- [Next.js: Content Security Policy guide (16.3.5)](https://nextjs.org/docs/app/guides/content-security-policy) — Official — proxy nonce code, dynamic rendering, SRI, dev unsafe-eval
- [web.dev: Mitigate XSS with a strict CSP](https://web.dev/articles/strict-csp) — Official (Google) — nonce/hash policies, rollout, fallbacks
- [MDN: Content-Security-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy) — Official — directives
- [MDN: require-trusted-types-for](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/require-trusted-types-for) — Official
- [URIports: CSP Trusted Types](https://www.uriports.com/blog/csp-trusted-types/) — Community — Baseline status/timeline
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/) — Official (Google) — policy checks

## License / Usage Notes
Next.js docs MIT-licensed content; proxy example adapted from the official guide with modifications. web.dev content CC BY 4.0, summarized.

## Quality Tier
S — derived from the current official Next.js guide (16.3.5) and web.dev strict CSP guidance; SRI flagged experimental.

## Status
Active

## Last Verified
2026-09-15
