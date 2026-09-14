# Frontend Security Fundamentals

## Summary
The core browser and application security practices for React and Next.js apps, mapped to OWASP Top 10:2025. Covers XSS (React escaping and its escape hatches, Trusted Types — Baseline since Feb 2026 — and the Sanitizer API), CSRF and Server Action origin checks, clickjacking, secure cookies, security headers, secrets exposure, open redirects, postMessage, Server Component data exposure, and fail-closed error handling. Deep dives live in content-security-policy, frontend-auth-token-handling, and dependency-supply-chain-security.

## Category
Security

## Subcategories
XSS, DOM XSS, Trusted Types, Sanitizer API, CSRF, clickjacking, security headers, cookies, secrets, open redirects, postMessage, SSRF, RSC data exposure, OWASP Top 10:2025

## Problem It Solves
Frontend code is attacker-reachable: every input, URL, message, and dependency can inject script or exfiltrate data. Frameworks prevent many issues by default, but escape hatches (`dangerouslySetInnerHTML`, `href` with user URLs, Server Actions as public endpoints, props serialized into HTML) reintroduce them. A shared baseline prevents the common, high-impact classes of bugs.

## When To Use
- Every React/Next.js app; review on each feature touching user content, URLs, auth, payments, or third parties.
- Security reviews, pen-test remediation, compliance prep.

## When Not To Use
- Not a substitute for backend authorization and data validation — the server is the security boundary.

## Core Principles
1. **The server enforces; the client assists.** UI hiding is not access control (OWASP A01:2025 Broken Access Control).
2. **Treat all input as untrusted:** form data, URL/search params, headers, postMessage, storage, third-party API responses.
3. **Rely on framework escaping; audit every escape hatch.**
4. **Defense in depth:** strict CSP + Trusted Types + sanitization + secure cookies + headers.
5. **Least exposure:** send the minimum data to the client; secrets never leave the server.
6. **Fail closed** on errors in auth/validation paths (OWASP A10:2025).
7. **Secure defaults via configuration** (headers, cookie flags) rather than per-feature memory (OWASP A02:2025 Security Misconfiguration).

## Best Practices
- OWASP Top 10:2025 frontend relevance:
  | ID | Category | Frontend/Next.js concern |
  |---|---|---|
  | A01 | Broken Access Control | Authorize in Server Components/Actions/Route Handlers, not just UI; IDOR in API calls |
  | A02 | Security Misconfiguration | Missing headers/CSP, verbose errors, open CORS, debug endpoints |
  | A03 | Software Supply Chain Failures | Malicious npm packages, third-party scripts |
  | A04 | Cryptographic Failures | HTTP, weak token handling, client-side "encryption" |
  | A05 | Injection | XSS (DOM/stored/reflected), template/HTML injection |
  | A06 | Insecure Design | Trusting client-side checks, missing rate limits on actions |
  | A07 | Authentication Failures | Token storage, session fixation, weak logout |
  | A08 | Software or Data Integrity Failures | Unsigned updates, SRI missing, unsafe deserialization |
  | A09 | Security Logging and Alerting Failures | No CSP reports, no auth failure logging |
  | A10 | Mishandling of Exceptional Conditions | Failing open, leaking stack traces |
- XSS in React: JSX text and attributes are escaped. Escape hatches to audit: `dangerouslySetInnerHTML`, `ref.current.innerHTML`, `href`/`src`/`action` with user-controlled URLs, `srcdoc`, `eval`/`new Function`, dynamic `<script>` injection, third-party markdown/HTML renderers, and inline JSON in `<script>` tags.
- User-controlled URLs: allow only `https:`/`http:`/`mailto:` (parse with `new URL()`); React 19 blocks `javascript:` URLs in `href`, but validate anyway (older React, other sinks, `window.location` assignments).
- HTML from users/CMS: sanitize with DOMPurify (server + client) or the Sanitizer API `element.setHTML()` where available (Firefox 148+, Chrome 146+; not Safari as of Sept 2026 — feature-detect and fall back to DOMPurify).
- Trusted Types (`require-trusted-types-for 'script'`) is Baseline (Chrome/Edge 83+, Safari 26, Firefox Feb 2026) — enforce to lock DOM XSS sinks; define a single policy using DOMPurify with `RETURN_TRUSTED_TYPE`.
- Inline JSON for hydration: serialize safely (escape `<`, `>`, `&`, U+2028/2029) — Next.js handles RSC payloads; custom `<script>` JSON-LD must escape `<` (`JSON.stringify(data).replace(/</g, '\\u003c')`).
- CSRF: cookie-authenticated mutations need `SameSite=Lax` or `Strict` cookies plus origin checks or CSRF tokens. Next.js Server Actions compare `Origin` with `Host`/`X-Forwarded-Host` and only accept POST; configure `serverActions.allowedOrigins` behind proxies. Custom Route Handlers must implement their own checks.
- Clickjacking: `Content-Security-Policy: frame-ancestors 'none'` (or `'self'`); `X-Frame-Options: DENY` for legacy.
- Security headers baseline: CSP, `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (disable unused features), `Cross-Origin-Opener-Policy: same-origin` (where compatible with OAuth popups), remove `X-Powered-By` (`poweredByHeader: false`).
- Cookies: `HttpOnly; Secure; SameSite=Lax; Path=/` and the `__Host-` prefix for session cookies.
- Secrets: nothing secret in `NEXT_PUBLIC_*`/`VITE_*`; `import 'server-only'` in modules touching secrets; Next.js taint APIs (`experimental_taintObjectReference`/`taintUniqueValue`) can block accidental passing of sensitive objects to Client Components (experimental).
- RSC data exposure: everything passed as props to Client Components is serialized into the page; map DB records to DTOs with only needed fields.
- Server Actions are public POST endpoints: validate input (Zod), authenticate, authorize, rate-limit; don't rely on the action being "unreachable" because no UI calls it. Closed-over variables are encrypted but still shouldn't hold secrets.
- Open redirects: validate `returnTo`/`next` params to same-origin relative paths.
- `target="_blank"`: modern browsers imply `noopener`; add `rel="noopener noreferrer"` for external links to also drop referrer if desired.
- postMessage: always specify exact `targetOrigin`; verify `event.origin` with strict equality against an allowlist; validate `event.data` shape; never pass to HTML sinks.
- Storage: no tokens, secrets, or sensitive PII in `localStorage`/`sessionStorage`/IndexedDB (readable by any XSS).
- SSRF (server code in Next.js): when fetching user-provided URLs (link previews, image proxies), allowlist hosts, block private IP ranges; configure `images.remotePatterns` narrowly.
- Password fields: allow password managers (`autocomplete="current-password"`/`"new-password"`); older advice to set `autocomplete="off"` on credentials is outdated and harms security.

## Implementation Guidance

### Safe URL helper
```ts
// shared/lib/safe-url.ts
const ALLOWED = new Set(['http:', 'https:', 'mailto:']);
export function safeHref(input: string | null | undefined, base = 'https://example.com'): string | undefined {
  if (!input) return undefined;
  try {
    const url = new URL(input, base);
    return ALLOWED.has(url.protocol) ? url.href : undefined;
  } catch { return undefined; }
}
export function safeReturnTo(input: string | null): string {
  if (!input || !input.startsWith('/') || input.startsWith('//') || input.startsWith('/\\')) return '/';
  return input;
}
```

### Sanitized HTML component (DOMPurify + Sanitizer API)
```tsx
'use client';
import DOMPurify from 'dompurify';
import { useEffect, useRef } from 'react';
export function SafeHtml({ html }: { html: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if ('setHTML' in Element.prototype) {
      (el as HTMLElement & { setHTML(h: string): void }).setHTML(html);   // browser-native safe sanitizer
    } else {
      el.innerHTML = DOMPurify.sanitize(html, { USE_PROFILES: { html: true } });
    }
  }, [html]);
  return <div ref={ref} />;
}
```
For server-rendered HTML (RSC), sanitize on the server with `isomorphic-dompurify` or `sanitize-html` before rendering with `dangerouslySetInnerHTML`, and keep CSP as backup.

### Trusted Types default policy
```ts
// instrumentation-client.ts (Next.js) or main.tsx (Vite)
import DOMPurify from 'dompurify';
if (window.trustedTypes?.createPolicy) {
  window.trustedTypes.createPolicy('default', {
    createHTML: (s) => DOMPurify.sanitize(s, { RETURN_TRUSTED_TYPE: false }),
    createScriptURL: (s) => { const u = new URL(s, location.origin); if (u.origin === location.origin) return u.href; throw new TypeError('Blocked script URL'); },
    createScript: () => { throw new TypeError('Blocked dynamic script'); },
  });
}
```
Header: `Content-Security-Policy: require-trusted-types-for 'script'; trusted-types default dompurify nextjs#bundler` (roll out in report-only first; verify which policy names your framework/libraries create).

### Security headers in Next.js
```ts
// next.config.ts
import type { NextConfig } from 'next';
const securityHeaders = [
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), browsing-topics=()' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
];
const config: NextConfig = {
  poweredByHeader: false,
  async headers() { return [{ source: '/(.*)', headers: securityHeaders }]; },
};
export default config;
```
CSP with nonces is set in `proxy.ts` (see content-security-policy).

### DTO mapping before passing to Client Components
```tsx
// app/profile/page.tsx
import 'server-only';
export default async function ProfilePage() {
  const user = await db.user.findCurrent();            // contains passwordHash, mfaSecret, etc.
  const dto = { name: user.name, avatarUrl: user.avatarUrl }; // only what UI needs
  return <ProfileCard user={dto} />;                   // client component
}
```

### Secure Server Action
```ts
'use server';
import { z } from 'zod';
const Input = z.object({ projectId: z.string().uuid(), name: z.string().trim().min(1).max(80) });
export async function renameProject(formData: FormData) {
  const session = await requireSession();                       // A07
  const input = Input.parse(Object.fromEntries(formData));      // A05/A06
  if (!(await can(session.userId, 'project:update', input.projectId))) throw new ForbiddenError(); // A01, fail closed
  await rateLimit(`rename:${session.userId}`, { limit: 20, windowSec: 60 });
  await projects.rename(input.projectId, input.name);
}
```

### postMessage receiver
```ts
const TRUSTED = new Set(['https://widgets.example.com']);
window.addEventListener('message', (e) => {
  if (!TRUSTED.has(e.origin)) return;
  const parsed = WidgetMsg.safeParse(e.data);
  if (!parsed.success) return;
  handle(parsed.data);
});
iframe.contentWindow?.postMessage({ type: 'init' }, 'https://widgets.example.com'); // never '*'
```

## Recommended Workflow
1. Threat-model the feature: inputs, sinks, data sensitivity, trust boundaries.
2. Apply baseline headers/cookies globally; add strict CSP (report-only -> enforce).
3. Grep for escape hatches (`dangerouslySetInnerHTML`, `innerHTML`, `eval`, `postMessage`, `window.location =`, `NEXT_PUBLIC_`) and remediate.
4. Validate inputs with schemas at every server entry (Server Actions, Route Handlers, `searchParams`).
5. Enforce authorization server-side for every data access; map to DTOs.
6. Enable Trusted Types in report-only, fix violations, enforce.
7. Add security tests (E2E XSS payloads, header checks) and CSP/Trusted Types violation reporting.

## Patterns
- **Single sanitization module** and single Trusted Types policy.
- **DTO/view-model layer** between data and Client Components.
- **Action wrapper** (`authedAction(schema, permission, handler)`) enforcing auth/validation/rate limit for every Server Action.
- **Safe URL/redirect helpers** used by all link components.
- **Headers as code** in `next.config.ts`/`proxy.ts` with tests.

## Anti-Patterns
- **`dangerouslySetInnerHTML` with unsanitized CMS/user content** — stored XSS. Fix: sanitize server-side + CSP/Trusted Types.
- **Client-side-only permission checks** (`if (user.isAdmin) show button`) — Fix: server authorization on data and actions.
- **Tokens in localStorage** — XSS theft. Fix: HttpOnly cookies / BFF.
- **Secrets in `NEXT_PUBLIC_`** — Fix: server-only access.
- **Passing full DB objects to Client Components** — data leak via RSC payload. Fix: DTOs, taint APIs.
- **`postMessage(data, '*')` and `origin.includes('example.com')`** — Fix: exact origins.
- **Open redirect via `?next=https://evil.com`** — Fix: relative-path validation.
- **CORS `Access-Control-Allow-Origin: *` with credentials or reflecting any Origin** — Fix: explicit allowlist.
- **Framebusting JS instead of `frame-ancestors`** — Fix: header.
- **`autocomplete="off"` on password fields** (outdated OWASP-era advice) — breaks password managers. Fix: proper autocomplete tokens.

## Accessibility
- Security UX must remain accessible: CAPTCHAs need accessible alternatives (WCAG 2.2 3.3.8 Accessible Authentication (Minimum) — don't require cognitive function tests; allow paste and password managers).
- Session timeout warnings must be announced and extendable (WCAG 2.2.1 Timing Adjustable).
- Error messages for blocked actions must be perceivable without revealing sensitive details.

## Responsive Design
- Not directly applicable; ensure security prompts (re-auth, confirmations) work on small screens and aren't dismissed accidentally.

## Performance
- Nonce-based CSP forces dynamic rendering in Next.js (no static/ISR/PPR for those routes) — consider hash-based CSP with experimental SRI for static pages.
- DOMPurify is ~20kB; Sanitizer API is free where supported — lazy-load DOMPurify only when rendering HTML.

## Security
- This skill is the security baseline; see Related Skills for CSP, auth tokens, and supply chain specifics.
- Monitor: CSP/Trusted Types violation reports, auth failures, rate-limit triggers (A09).

## Testing
- Unit: `safeHref`, `safeReturnTo`, sanitizer configs with XSS payload corpora (e.g., OWASP XSS filter evasion examples).
- E2E (Playwright): submit payloads like `<img src=x onerror=alert(1)>` into rich fields, assert no dialog and no script execution; verify response headers; verify Server Actions reject unauthenticated/unauthorized requests.
- Automated scanning: OWASP ZAP baseline scan in CI against preview deploys; `npx is-website-vulnerable`-style checks for vulnerable client libs.
- Periodic manual pen test for high-risk apps.

## Tooling
- DOMPurify 3.x — Active; isomorphic-dompurify — Active (server).
- HTML Sanitizer API (`setHTML`) — Limited availability (Firefox 148+, Chrome 146+, not Safari).
- Trusted Types — Baseline 2026.
- Zod 4 — Active (input validation).
- OWASP ZAP — Active; Burp Suite — Commercial.
- eslint-plugin-no-unsanitized, `react/no-danger` / Biome `noDangerouslySetInnerHtml` — Active.
- Next.js taint APIs — Experimental.
- securityheaders.com / Mozilla HTTP Observatory — Active (header checks).

## Framework Notes
- **React (Vite SPA):** no server to enforce anything — all authorization lives in the API; CSP via hosting/CDN headers (hash-based for static `index.html`); tokens should be handled by a BFF (see frontend-auth-token-handling); Vite env vars prefixed `VITE_` are public.
- **Next.js App Router:** Server Components, Server Actions, Route Handlers, and `proxy.ts` are server entry points — validate/authorize in each (proxy is for coarse checks, not sole authorization). Server Actions have built-in origin checking (POST + Origin vs Host); configure `allowedOrigins` behind reverse proxies. Use `server-only`, DTOs, and taint APIs to prevent data leaks. Set headers in `next.config.ts` and CSP nonces in `proxy.ts`. Keep Next.js patched — framework CVEs (e.g., the 2025 middleware authorization bypass CVE-2025-29927) show why proxy/middleware must not be the only auth layer.

## AI Agent Guidance
- For every change touching input, HTML rendering, URLs, auth, or data passed to Client Components, apply the checklist.
- Do: validate with schemas at server entry points, authorize every data access, map to DTOs, sanitize HTML, use safe URL helpers, keep secrets server-only.
- Don't: add `dangerouslySetInnerHTML` without sanitization, store tokens in web storage, use `postMessage` with `'*'`, add `NEXT_PUBLIC_` secrets, or rely on proxy/middleware alone for authorization.
- Verify: grep diff for escape hatches, run XSS payload E2E tests, confirm headers present, confirm unauthorized action calls fail.

## Examples
```tsx
// JSON-LD safely embedded (Server Component)
export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, '\\u003c') }} />;
}
```
```tsx
// Safe user link
<a href={safeHref(profile.website)} rel="noopener noreferrer nofollow" target="_blank">{profile.website}</a>
```

## Related Skills
- [content-security-policy](../content-security-policy/Skill.md) — CSP and Trusted Types rollout
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — tokens, sessions, cookies
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md) — A03
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — secrets and config
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action security
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — UI vs server authorization
- [frontend-error-handling-architecture](../frontend-error-handling-architecture/Skill.md) — A10 fail closed

## Sources
- [OWASP Top 10:2025](https://top10.owasp.org/2025) — Official — category list
- [OWASP HTML5 Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html) — Official — postMessage, storage, CORS, iframes, links (autocomplete advice flagged outdated)
- [MDN: Trusted Types API](https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API) — Official — API, Baseline
- [MDN: HTML Sanitizer API](https://developer.mozilla.org/en-US/docs/Web/API/HTML_Sanitizer_API) — Official — setHTML
- [Next.js: Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DTOs, server-only, taint, Server Action security
- [URIports: CSP Trusted Types](https://www.uriports.com/blog/csp-trusted-types/) — Community — Baseline timeline
- [web.dev: Strict CSP](https://web.dev/articles/strict-csp) — Official (Google) — CSP + Trusted Types complement
- [DOMPurify](https://github.com/cure53/DOMPurify) — Open Source — sanitization

## License / Usage Notes
OWASP content is CC BY-SA 4.0 — summarized with attribution, not copied. DOMPurify Apache-2.0/MPL-2.0. Code examples original.

## Quality Tier
S — mapped to OWASP 2025 and official MDN/Next.js docs verified Sept 2026; browser support facts dated.

## Status
Active

## Last Verified
2026-09-15
