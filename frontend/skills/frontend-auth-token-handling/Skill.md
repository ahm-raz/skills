# Frontend Auth Token Handling

## Summary
How React and Next.js apps should obtain, store, send, refresh, and revoke authentication credentials, aligned with RFC 10017 "OAuth 2.0 for Browser-Based Applications" (BCP 212, published 2026). Default: keep tokens out of JavaScript — use a Backend-for-Frontend (Next.js server) with HttpOnly session cookies. Covers architecture choice, cookie settings, PKCE, refresh token rotation, DPoP, CSRF, logout, multi-tab behavior, and SPA constraints.

## Category
Security

## Subcategories
BFF, session cookies, OAuth 2.0/OIDC, PKCE, refresh token rotation, DPoP, token storage, CSRF, logout, silent renew, Auth.js, Better Auth

## Problem It Solves
Access tokens in `localStorage` are stolen by any XSS or malicious dependency; silent-renew iframes break under third-party cookie blocking; refresh races log users out; logout leaves valid tokens; CSRF hits cookie-based APIs. Choosing the right architecture and handling rules eliminates most token theft and session bugs.

## When To Use
- Implementing login for a Next.js app or a Vite React SPA.
- Integrating an OIDC provider (Auth0, Entra ID, Okta, Keycloak, Cognito, Clerk, WorkOS, etc.).
- Reviewing existing token storage/refresh logic.

## When Not To Use
- UX of login/signup screens (see authentication-ux) or Next.js route protection specifics (see nextjs-authentication).

## Core Principles
1. **Tokens the browser JS never sees can't be stolen by XSS.** Prefer BFF (RFC 10017's strongest pattern; strongly recommended for business/sensitive/personal-data apps).
2. **Sessions via `HttpOnly; Secure; SameSite` cookies,** ideally `__Host-` prefixed.
3. **Authorization Code + PKCE** for any browser-involved OAuth flow; implicit flow and ROPC are obsolete.
4. **Refresh tokens are rotated or sender-constrained** (DPoP), with bounded lifetimes; never stored in web storage.
5. **Short-lived access tokens;** server-side session revocation on logout.
6. **CSRF defense for cookie-authenticated mutations.**
7. **Authorization on the server for every request;** client token claims are hints for UI only.

## Best Practices
- Architecture choice (RFC 10017, decreasing security):
  | Pattern | Tokens in browser JS | Fit |
  |---|---|---|
  | BFF (confidential client on server; browser gets session cookie; server proxies API calls) | None | Default for Next.js; strongly recommended for sensitive apps |
  | Token-mediating backend (server does code exchange, keeps refresh token, gives access token to JS) | Access token only | When SPA must call APIs directly across origins |
  | Browser-based OAuth client (public client, PKCE, tokens in JS) | Access + refresh | Only low-risk apps without a backend; highest exposure |
- Next.js is naturally a BFF: do the OIDC code flow in Route Handlers/auth library, store session (encrypted cookie or server-side session store), call upstream APIs from Server Components/Actions/Route Handlers with server-held tokens.
- Session cookie: `__Host-session=<opaque or encrypted>; Path=/; Secure; HttpOnly; SameSite=Lax` (Strict if no cross-site entry flows need the session). `__Host-` requires `Secure`, `Path=/`, no `Domain`.
- Prefer opaque session IDs mapped to server-side storage when you need instant revocation; encrypted stateless cookies (JWE) are simpler but revocation requires short expiry or a denylist.
- PKCE (`S256`) always; `state` for CSRF on the redirect; `nonce` for OIDC ID tokens; exact redirect URI matching.
- Refresh: rotate refresh tokens on every use (reuse detection revokes the family) or bind with DPoP; set absolute lifetime; expire when idle.
- For browser-held tokens (if unavoidable): keep in memory (module closure or Web Worker), not localStorage/sessionStorage; consider DPoP with non-extractable WebCrypto keys stored in IndexedDB; accept that XSS can still obtain fresh tokens by running a new flow — CSP is mandatory.
- Silent renew via hidden iframes (`prompt=none`) fails with third-party cookie restrictions (Safari ITP, Firefox TCP, Chrome user controls) — use refresh token rotation (SPA) or BFF.
- CSRF: SameSite=Lax blocks most cross-site POSTs; add origin verification (Next.js Server Actions do this automatically) or synchronizer tokens for Route Handlers accepting cookie auth; never use GET for state changes.
- Logout: destroy server session, clear cookie (same attributes, `Max-Age=0`), revoke refresh token at the IdP (RFC 7009), and optionally RP-initiated logout (OIDC end_session). Broadcast to other tabs via `BroadcastChannel`.
- Concurrency: single-flight refresh (one in-flight refresh promise shared by all requests) to avoid rotation races.
- Step-up auth (re-authentication) for sensitive actions; bind to `auth_time`/`acr` claims server-side.
- Never log tokens; strip `Authorization` headers from telemetry.
- Passkeys (WebAuthn) are the preferred credential for first-party login where feasible; this skill covers what happens after authentication.

## Implementation Guidance

### Decision table
| App | Recommended |
|---|---|
| Next.js App Router, same-origin APIs or server-reachable APIs | BFF: auth library + HttpOnly session cookie; server-to-API tokens |
| Vite React SPA with its own backend (same site) | Backend issues HttpOnly session cookie; SPA calls same-site API with `credentials: 'include'` + CSRF protection |
| Vite React SPA, third-party APIs, no backend | Add a thin BFF (edge function/serverless) — or, last resort, public client with PKCE + rotating refresh tokens in memory + strict CSP |
| Mobile + web sharing APIs | BFF for web; native uses platform-secure storage |

### Next.js BFF: session helpers
```ts
// src/entities/session/server.ts
import 'server-only';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

const COOKIE = '__Host-session';
export async function setSession(sessionId: string, maxAgeSec: number) {
  (await cookies()).set(COOKIE, sessionId, { httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge: maxAgeSec });
}
export async function getSession() {
  const id = (await cookies()).get(COOKIE)?.value;
  return id ? sessionStore.get(id) : null;          // server-side store: { userId, accessToken, refreshToken, expiresAt }
}
export async function requireSession() {
  const s = await getSession();
  if (!s) redirect('/login');
  return s;
}
export async function destroySession() {
  const jar = await cookies();
  const id = jar.get(COOKIE)?.value;
  if (id) await sessionStore.delete(id);
  jar.delete(COOKIE);
}
```
(Cookie mutation is allowed in Server Actions and Route Handlers, not during Server Component render.)

### Server-side upstream call with refresh (single-flight)
```ts
import 'server-only';
const inflight = new Map<string, Promise<Session>>();
async function freshSession(s: Session): Promise<Session> {
  if (s.expiresAt - Date.now() > 60_000) return s;
  let p = inflight.get(s.id);
  if (!p) {
    p = (async () => {
      const tokens = await oidc.refresh(s.refreshToken);       // rotated refresh token returned
      const next = { ...s, accessToken: tokens.access_token, refreshToken: tokens.refresh_token ?? s.refreshToken,
        expiresAt: Date.now() + tokens.expires_in * 1000 };
      await sessionStore.set(s.id, next);
      return next;
    })().finally(() => inflight.delete(s.id));
    inflight.set(s.id, p);
  }
  return p;
}
export async function callApi(path: string, init?: RequestInit) {
  const s = await freshSession(await requireSession());
  return fetch(`${process.env.API_URL}${path}`, { ...init, headers: { ...init?.headers, authorization: `Bearer ${s.accessToken}` } });
}
```
In multi-instance deployments, coordinate refresh with a distributed lock or rely on IdP refresh token grace periods.

### Auth libraries for Next.js
| Library | Status (Sept 2026) | Notes |
|---|---|---|
| Auth.js (NextAuth v5) | Active (verify stable status; long in beta) | OIDC providers, JWT or database sessions |
| Better Auth | Active | TS-first, self-hosted, plugins (passkeys, orgs) |
| IdP SDKs (Auth0 `@auth0/nextjs-auth0` v4, Clerk, WorkOS AuthKit, Microsoft MSAL Node) | Active | BFF-style session cookies |
| Lucia | Deprecated as a library (now learning resource) | Don't adopt |

### Logout Server Action
```ts
'use server';
import { redirect } from 'next/navigation';
export async function logout() {
  const s = await getSession();
  if (s) await oidc.revoke(s.refreshToken, 'refresh_token');
  await destroySession();
  redirect(oidc.endSessionUrl({ postLogoutRedirectUri: `${process.env.APP_URL}/` }));
}
```

### Vite SPA with same-site backend session
```ts
// SPA API calls
await fetch('/api/orders', { credentials: 'include', headers: { 'x-csrf-token': csrfTokenFromMeta() } });
```
Backend sets `__Host-session` HttpOnly cookie after OIDC code flow on the server; exposes `/api/me` for user info; validates `Origin` and CSRF token on mutations.

### Multi-tab logout sync
```ts
'use client';
const ch = new BroadcastChannel('auth');
export function broadcastLogout() { ch.postMessage({ type: 'logout' }); }
ch.onmessage = (e) => { if (e.data?.type === 'logout') window.location.assign('/login'); };
```

### If a pure browser OAuth client is unavoidable
- Use a certified library (e.g., `oauth4webapi`, `oidc-client-ts`) with Authorization Code + PKCE.
- Tokens in memory only (or inside a dedicated Web Worker that performs API calls); refresh token rotation enabled at IdP; short lifetimes; DPoP if supported by IdP/API.
- Strict CSP + Trusted Types; minimal third-party scripts.
- Accept and document residual risk per RFC 10017.

## Recommended Workflow
1. Classify data sensitivity; choose architecture (BFF by default).
2. Configure IdP: confidential client for BFF, exact redirect URIs, PKCE required, refresh token rotation, token lifetimes.
3. Implement login (code flow + PKCE + state/nonce), callback, session cookie.
4. Implement server-side API calls with single-flight refresh.
5. Implement logout with revocation, cookie clearing, multi-tab sync.
6. Add CSRF protections for non-Server-Action mutations.
7. Test token expiry, refresh races, revoked sessions, and XSS containment (no tokens reachable from `document.cookie`/storage).

## Patterns
- **BFF proxy route** (`/api/proxy/[...path]`) for client-side polling needs, attaching server-held tokens.
- **Opaque session ID + server store** for revocation.
- **Single-flight refresh.**
- **BroadcastChannel session sync.**
- **Step-up re-auth** for sensitive operations.
- **DTO user object** passed to Client Components (no tokens, no internal claims).

## Anti-Patterns
- **Access/refresh tokens in localStorage/sessionStorage** — XSS/supply-chain theft. Fix: BFF + HttpOnly cookies.
- **Implicit flow / tokens in URL fragments** — obsolete, leaks via history/referrer. Fix: code + PKCE.
- **Silent renew iframes** — broken by third-party cookie blocking. Fix: BFF or refresh rotation.
- **Long-lived non-rotating refresh tokens in the browser** — Fix: rotation/DPoP or keep server-side.
- **Passing access tokens to Client Components as props** — ends up in RSC payload/HTML. Fix: call APIs server-side.
- **Trusting decoded JWT claims in the client for authorization** — Fix: server checks.
- **Cookie without `Secure`/`HttpOnly`/`SameSite`** — Fix: set all; `__Host-` prefix.
- **Logout that only clears client state** — tokens remain valid. Fix: server session destroy + revocation.
- **Parallel refreshes with rotation** — invalidates session. Fix: single-flight.
- **Auth checks only in `proxy.ts`** — bypassable class of bugs. Fix: check in data access layer too.

## Accessibility
- Session timeout: warn before expiry with an accessible dialog and option to extend (WCAG 2.2.1 Timing Adjustable); preserve entered data on re-auth (WCAG 2.2.5 Re-authenticating AAA guidance).
- WCAG 2.2 3.3.8 Accessible Authentication (Minimum): allow password managers/paste, support passkeys, avoid cognitive tests.
- Redirect-based login flows must return focus to a sensible place and announce errors.

## Responsive Design
- OAuth popups are unreliable on mobile — use full-page redirects; ensure IdP pages are mobile-friendly.

## Performance
- BFF adds a server hop for API calls; mitigate with server-side parallel fetching and caching of non-user-specific data.
- Session lookups on every request: use fast stores (Redis/KV) or encrypted cookies; avoid calling the IdP per request (validate JWT locally with cached JWKS).
- Cookie size: keep session cookies small (opaque ID) to avoid bloating every request.

## Security
- RFC 10017 (BCP 212): BFF strongest; PKCE MUST for public clients; refresh token rotation or sender-constraining; CSP essential for browser-held tokens.
- OWASP A07:2025 Authentication Failures and A01 Broken Access Control.
- Cookie prefix `__Host-` prevents subdomain cookie injection; don't set `Domain`.
- Rotate session ID on login (session fixation) and privilege change.
- Rate-limit login and token endpoints; monitor refresh token reuse events (A09).

## Testing
- Unit: cookie attribute builders, refresh single-flight, reuse detection handling.
- Integration: callback validates `state`/PKCE/nonce; logout revokes tokens (subsequent API call fails).
- E2E (Playwright): `document.cookie` does not contain session; `localStorage`/`sessionStorage` empty of tokens; expired access token transparently refreshed; multi-tab logout.
- Security: attempt CSRF POST from another origin to Route Handlers — rejected.

## Tooling
- RFC 10017 (BCP 212) — Official BCP (2026).
- RFC 9700 OAuth 2.0 Security BCP — Official.
- RFC 9449 DPoP — Official.
- Auth.js v5, Better Auth, `@auth0/nextjs-auth0` v4, Clerk, WorkOS AuthKit — Active.
- `oauth4webapi` / `openid-client` (panva) — Active, certified implementations.
- `oidc-client-ts` — Active (browser public clients).
- `iron-session` — Active (encrypted cookie sessions).
- `jose` — Active (JWT/JWE validation).
- Lucia — Deprecated library.

## Framework Notes
- **React (Vite SPA):** no server — pair with a backend/BFF (same-site) for HttpOnly sessions; if tokens must live in the browser, keep them in memory and use code + PKCE with rotating refresh tokens; `VITE_` env holds only public client IDs; configure CSP at the host.
- **Next.js App Router:** acts as BFF — OIDC callback in a Route Handler, cookies set in Route Handlers/Server Actions, session read via `cookies()` in Server Components (makes routes dynamic), upstream calls server-side; Server Actions get built-in origin checks; `proxy.ts` can do optimistic redirects for unauthenticated users but authorization must be re-checked in the data access layer; pass only DTO user info to Client Components.

## AI Agent Guidance
- Identify the auth library and session model already in use; never introduce a second auth mechanism.
- Do: keep tokens server-side, use `__Host-` HttpOnly Secure SameSite cookies, verify session and permissions in every Server Action/Route Handler/data function, implement single-flight refresh, revoke on logout.
- Don't: store tokens in localStorage/sessionStorage/Zustand persist, pass tokens as props, decode JWTs client-side for authorization, or rely solely on proxy redirects.
- Verify: E2E shows no tokens in JS-accessible storage or RSC payload (search page source for `eyJ`), logout invalidates API access, refresh works under concurrent requests.

## Examples
```ts
// Route Handler OIDC callback (outline)
// app/auth/callback/route.ts
import { NextResponse, type NextRequest } from 'next/server';
export async function GET(req: NextRequest) {
  const { code, state } = Object.fromEntries(req.nextUrl.searchParams);
  const tx = await loadTransaction(req.cookies.get('__Host-oauth_tx')?.value); // holds state, code_verifier, nonce
  if (!tx || tx.state !== state) return NextResponse.redirect(new URL('/login?error=state', req.url));
  const tokens = await oidc.exchangeCode({ code, codeVerifier: tx.codeVerifier, redirectUri: `${process.env.APP_URL}/auth/callback` });
  await oidc.validateIdToken(tokens.id_token, { nonce: tx.nonce });
  const sessionId = await sessionStore.create(tokens);      // new ID (prevents fixation)
  const res = NextResponse.redirect(new URL(safeReturnTo(tx.returnTo), req.url));
  res.cookies.set('__Host-session', sessionId, { httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge: 60 * 60 * 8 });
  res.cookies.delete('__Host-oauth_tx');
  return res;
}
```

## Related Skills
- [nextjs-authentication](../nextjs-authentication/Skill.md) — route protection and library setup
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — XSS/CSRF baseline
- [content-security-policy](../content-security-policy/Skill.md) — required when tokens touch the browser
- [authentication-ux](../authentication-ux/Skill.md) — login/logout UX
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md) — credential inputs
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — attaching credentials to requests
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — callback and BFF proxy routes

## Sources
- [RFC 10017: OAuth 2.0 for Browser-Based Applications (BCP 212)](https://www.rfc-editor.org/info/rfc10017/) — Official — architectures, PKCE, refresh, DPoP, storage
- [IETF draft-ietf-oauth-browser-based-apps](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps) — Official — detailed threat analysis
- [OWASP HTML5 Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html) — Official — no tokens in web storage
- [MDN: Set-Cookie (cookie prefixes, SameSite)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie) — Official
- [Next.js: Authentication guide](https://nextjs.org/docs/app/guides/authentication) — Official — sessions, DAL, proxy caveats
- [RFC 9700: OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700) — Official
- [OWASP Top 10:2025](https://top10.owasp.org/2025) — Official — A07 Authentication Failures

## License / Usage Notes
IETF RFCs are freely usable with attribution (summarized here). OWASP CC BY-SA 4.0 summarized. Code examples original; OIDC helper functions (`oidc.*`, `sessionStore`) are illustrative placeholders for a certified library.

## Quality Tier
S — anchored in RFC 10017 (2026 BCP) and official framework docs; library status rows (Auth.js v5 stability) should be re-verified.

## Status
Active

## Last Verified
2026-09-15
