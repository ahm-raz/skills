# Next.js Authentication and Authorization

## Summary
Authentication in the Next.js 16 App Router is layered: **optimistic checks** (session cookie present) in `proxy.ts` for fast redirects, and **secure checks** (validated session + permission) in a `server-only` Data Access Layer called from Server Components, Server Actions, and Route Handlers. Sessions are stored as encrypted HttpOnly cookies (stateless) or database sessions. Libraries (Better Auth, Clerk, Auth0, WorkOS, Supabase, etc.) implement these pieces; Auth.js/NextAuth is now in security-patch-only mode under the Better Auth team. With Cache Components, session reads stream behind `<Suspense>` and session-derived data is cached by user ID or with `'use cache: private'`.

## Category
Next.js

## Subcategories
Sessions, cookies, Data Access Layer, DTOs, proxy auth, Server Action authorization, Route Handler auth, RBAC, Better Auth, Clerk, Auth.js status, Cache Components auth

## Problem It Solves
Apps that gate pages in layouts but leave Server Actions and Route Handlers open, rely on middleware alone (bypassable), put DB calls in proxy, leak session data to the client, cache per-user data under shared keys, or pick an unmaintained auth library.

## When To Use
- Adding login, signup, sessions, logout, and protected areas.
- Implementing role/permission checks for pages, actions, and APIs.
- Choosing an auth library for a new Next.js 16 project.
- Adopting Cache Components in an authenticated app.

## When Not To Use
- Login/signup UI and UX flows (see [authentication-ux](../authentication-ux/Skill.md), [otp-and-auth-forms](../otp-and-auth-forms/Skill.md)).
- Generic token storage theory for SPAs (see [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md)).
- Database schema/ORM specifics (see [nextjs-database-integration](../nextjs-database-integration/Skill.md)).

## Core Principles
1. **Authorize close to the data.** Every data read and mutation path verifies the session and permission in the DAL.
2. **Proxy is optimistic only.** Cookie presence → redirect; never DB, never sole defense.
3. **Every Server Action and Route Handler is a public endpoint.** Re-verify inside each.
4. **Layouts are not guards.** They don't re-run on sibling navigation and don't stop child segments or parallel slots from rendering.
5. **Return DTOs, not users.** Session payloads and props contain minimal non-sensitive fields.
6. **Cookies: HttpOnly, Secure, SameSite=Lax (or Strict), bounded expiry, set on the server.**

## Best Practices
- Prefer a maintained library; for new projects Better Auth (self-hosted, DB-backed) or a hosted provider (Clerk, Auth0, WorkOS, Stytch, Descope, Kinde, Supabase Auth). Existing Auth.js users can stay (security patches continue) but plan migration.
- Build `verifySession()` / `getCurrentUser()` in `lib/dal` with `import 'server-only'`, memoized with `React.cache` (or `'use cache: private'` under Cache Components).
- Use `redirect('/login')` inside the DAL for page contexts; return 401/403 in Route Handlers; throw or return error state in actions.
- Check **ownership** (IDOR) in queries: `where: { id, ownerId: session.userId }`.
- Keep session payload minimal: `userId`, `role`, `expiresAt` — no email/PII.
- Rotate/refresh sessions on activity; invalidate on logout and password change (DB sessions allow "log out everywhere").
- Rate-limit login/signup/reset endpoints; hash passwords with bcrypt/argon2 if self-implementing.
- Protect routes that render **shared static** content (paywalls) in proxy, since DAL checks don't run for prerendered output.
- With experimental `authInterrupts`, use `unauthorized()`/`forbidden()` + `unauthorized.tsx`/`forbidden.tsx`.

## Implementation Guidance

### Where checks go
| Location | Check type | Action on failure |
|---|---|---|
| `proxy.ts` | Optimistic (cookie present/decodable) | Redirect to `/login` |
| DAL `verifySession()` | Secure (signature/expiry, DB session) | `redirect()` / throw |
| Server Component | Via DAL; role-based rendering | Render alternative / `notFound()` |
| Server Action | Via DAL + ownership | Throw / return error |
| Route Handler | Via DAL | `401` / `403` |
| Layout | Don't gate; fetch user for display only | — |

### Stateless session (jose)
```ts
// lib/session.ts
import 'server-only'
import { SignJWT, jwtVerify } from 'jose'
import { cookies } from 'next/headers'

const key = new TextEncoder().encode(process.env.SESSION_SECRET) // 32+ random bytes, never NEXT_PUBLIC_
type SessionPayload = { userId: string; role: 'user' | 'admin'; expiresAt: string }

export async function encrypt(payload: SessionPayload) {
  return new SignJWT(payload).setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('7d').sign(key)
}
export async function decrypt(token?: string) {
  if (!token) return null
  try { return (await jwtVerify<SessionPayload>(token, key, { algorithms: ['HS256'] })).payload } catch { return null }
}
export async function createSession(userId: string, role: SessionPayload['role']) {
  const expires = new Date(Date.now() + 7 * 864e5)
  const token = await encrypt({ userId, role, expiresAt: expires.toISOString() })
  ;(await cookies()).set('session', token, { httpOnly: true, secure: true, sameSite: 'lax', path: '/', expires })
}
export async function deleteSession() {
  ;(await cookies()).delete('session')
}
```

### DAL
```ts
// lib/dal/auth.ts
import 'server-only'
import { cache } from 'react'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { decrypt } from '@/lib/session'

export const verifySession = cache(async () => {
  const session = await decrypt((await cookies()).get('session')?.value)
  if (!session?.userId) redirect('/login')
  return { userId: session.userId, role: session.role }
})

export async function requireRole(role: 'admin') {
  const s = await verifySession()
  if (s.role !== role) redirect('/403')
  return s
}
```

### Route Handler
```ts
// app/api/admin/users/route.ts
import { decrypt } from '@/lib/session'
import { cookies } from 'next/headers'

export async function GET() {
  const session = await decrypt((await cookies()).get('session')?.value)
  if (!session) return new Response(null, { status: 401 })
  if (session.role !== 'admin') return new Response(null, { status: 403 })
  return Response.json(await listUsersDTO())
}
```

### Cache Components pattern
```tsx
// lib/auth.ts
import 'server-only'
import { redirect } from 'next/navigation'
export async function getCurrentUser() {
  'use cache: private'           // may read cookies; browser-only cache
  const session = await getSessionFromCookie()
  if (!session?.userId) redirect('/login')
  const user = await findUserById(session.userId)
  if (!user) redirect('/login')
  return { id: user.id, name: user.name }
}

// lib/data/notes.ts
import 'server-only'
import { cacheLife, cacheTag } from 'next/cache'
export async function getNotes() {
  const user = await getCurrentUser()
  return getNotesByUserId(user.id)
}
async function getNotesByUserId(userId: string) { // NOT exported
  'use cache'
  cacheTag(`notes:${userId}`)
  cacheLife('minutes')
  return db.note.findMany({ where: { userId } })
}

// app/page.tsx
import { Suspense } from 'react'
export default function Page() {
  return <Suspense fallback={<p>Loading your dashboard…</p>}><Dashboard /></Suspense>
}
```

### Library quick reference (verify against current vendor docs)
| Library | Next.js 16 integration |
|---|---|
| Better Auth | `app/api/auth/[...all]/route.ts` → `toNextJsHandler(auth)`; server `auth.api.getSession({ headers: await headers() })`; `nextCookies()` plugin for actions; `getSessionCookie` for optimistic proxy checks |
| Clerk | `proxy.ts` → `export default clerkMiddleware()`; `<ClerkProvider>` in body; `await auth()` from `@clerk/nextjs/server`; `auth.protect()` |
| Auth.js (NextAuth v5 beta) | Maintained by Better Auth team, security patches only; recommended for existing apps, not new ones |

## Recommended Workflow
1. Choose library vs custom (default: library).
2. Implement session creation/deletion in Server Actions (login/logout).
3. Build DAL `verifySession`, `getCurrentUser`, permission helpers, DTO mappers.
4. Add optimistic redirects in `proxy.ts` with a strict matcher.
5. Add checks to every action/handler; scope queries by owner.
6. Enable Cache Components patterns: session reads under Suspense; user-keyed caches.
7. Test bypass attempts (direct POST, other user's IDs, expired cookie).

## Patterns
- **Two-tier check:** proxy redirect + DAL enforcement.
- **Role-gated leaf component:** `<AdminActions />` calls `verifySession()` and returns `null` for non-admins (UI only; actions re-check).
- **User context via promise:** Server Component creates `getCurrentUser()` promise inside Suspense, passes to client `UserProvider`, consumers use `use()`.
- **Step-up auth for destructive ops:** require recent re-authentication timestamp in session for deletes/payments.

## Anti-Patterns
- **Auth check only in `layout.tsx`** — child segments, slots, and actions still execute. Fix: DAL in data paths.
- **DB session lookup in proxy** — latency on every request incl. prefetch. Fix: cookie-only optimistic check.
- **`return null` in a layout for unauthenticated users** (SPA habit) — other entry points remain open. Fix: DAL + actions.
- **Storing JWT in `localStorage`** or setting cookies client-side — XSS theft/tampering. Fix: HttpOnly server-set cookies.
- **Session payload with email/phone** — PII in cookies. Fix: IDs only.
- **Caching `getUserData(userId)` exported from a module** — callers can request others' data. Fix: unexported keyed helper behind session-deriving getter.
- **Reading `cookies()` inside `'use cache'`** — throws. Fix: `'use cache: private'` or pass `userId`.
- **Starting a new project on Auth.js v5 beta** — maintenance mode. Fix: Better Auth or hosted provider.

## Accessibility
- Redirect flows must preserve destination (`?next=`) and focus the login heading on arrival.
- Error messages for failed login must be announced (`aria-live`) and not rely on color (WCAG 3.3.1, 1.4.1).
- Don't block paste in password fields; support password managers (`autocomplete="current-password"`, `"new-password"`, `"one-time-code"`) — WCAG 3.3.8 Accessible Authentication.
- Session timeout warnings must give users a way to extend (WCAG 2.2.1).

## Responsive Design
- Auth pages must work on narrow viewports without horizontal scroll; hosted widget embeds (Clerk components) should be tested at 320px.

## Performance
- Top-level `await verifySession()` in a layout delays the whole segment; push session-dependent UI into Suspense leaves.
- Memoize with `React.cache` to avoid repeated cookie decode/DB hits per render.
- Hosted providers add network calls — cache user profile lookups keyed by userId with short lifetimes.

## Security
- CSRF: Server Actions are POST-only with Origin/Host checks; SameSite cookies add defense. Route Handlers that mutate via cookies need their own CSRF checks (Origin header validation or tokens).
- Validate redirect targets (same origin) to avoid open redirects in callback handlers.
- Keep `SESSION_SECRET`/provider secrets server-only; rotate on exposure (e.g., after the Dec 2025 React2Shell incident window).
- Use taint APIs (`experimental_taintUniqueValue`) for session tokens as a secondary guard.
- Cache keys/tags are plain text — use user IDs, never tokens or emails.

## Testing
- Unit: `decrypt` rejects tampered/expired tokens; DAL redirects when no session.
- Integration: call Server Actions with no cookie and with another user's resource IDs; expect rejection.
- E2E (Playwright): storage-state login fixture; protected route redirect; logout clears cookie; role-based UI.
- Security regression: request protected Route Handlers without auth → 401.

## Tooling
- `jose`, `iron-session` (session libraries recommended by Next.js docs).
- Better Auth, Clerk, Auth0, WorkOS, Stytch, Descope, Kinde, Logto, Ory, Stack Auth, Supabase Auth.
- zod for credential validation; `@upstash/ratelimit` or platform rate limiting.
- Next.js example: `with-iron-session-cache-components`.

## Framework Notes
- v16: `proxy.ts` naming; Node runtime lets proxy use Node crypto libs — still keep it light.
- Root params aren't available in Server Actions/Route Handlers.
- React (Vite SPA): no server layer — auth relies on a backend issuing HttpOnly cookies (BFF) or OIDC PKCE with tokens in memory; route guards are UX only, the API must authorize.

## AI Agent Guidance
- Always generate a DAL with `server-only`, and call it from every action/handler you write.
- Never place authorization solely in proxy or layouts; never DB in proxy.
- Recommend Better Auth or a hosted provider for new apps; flag Auth.js as maintenance-mode.
- Before done: enumerate every Server Action and Route Handler touched and confirm each verifies session + ownership; confirm cookies are HttpOnly/Secure/SameSite; run a logged-out direct request test.

## Examples
```ts
// app/actions/auth.ts
'use server'
import { z } from 'zod'
import { redirect } from 'next/navigation'
import { createSession, deleteSession } from '@/lib/session'
import { verifyPassword, findUserByEmail } from '@/lib/dal/users'

const Login = z.object({ email: z.email(), password: z.string().min(8) })

export async function login(_: unknown, fd: FormData) {
  const parsed = Login.safeParse(Object.fromEntries(fd))
  if (!parsed.success) return { message: 'Invalid email or password.' }
  const user = await findUserByEmail(parsed.data.email)
  if (!user || !(await verifyPassword(user, parsed.data.password))) return { message: 'Invalid email or password.' }
  await createSession(user.id, user.role)
  redirect('/dashboard')
}

export async function logout() {
  await deleteSession()
  redirect('/login')
}
```

## Related Skills
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — optimistic checks
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action authorization
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — API authorization
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — per-user caching rules
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — session tables, ORM
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — token storage theory
- [authentication-ux](../authentication-ux/Skill.md) — auth UX
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — RBAC UI

## Sources
- [Authentication guide](https://nextjs.org/docs/app/guides/authentication) — Official — sessions, DAL, DTO, proxy optimistic checks, layouts caveat, library list
- [Authentication with Cache Components](https://nextjs.org/docs/app/guides/authentication-with-cache-components) — Official — private cache, user-keyed caches, pitfalls
- [Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — IDOR, action auth, auditing
- [Better Auth Next.js integration](https://www.better-auth.com/docs/integrations/next) — Open Source — handler, getSession, nextCookies, proxy checks
- [Auth.js is now part of Better Auth](https://better-auth.com/blog/authjs-joins-better-auth) — Community/Open Source — maintenance status
- [Clerk Next.js quickstart](https://clerk.com/docs/quickstarts/nextjs) — Community (vendor) — proxy.ts clerkMiddleware, auth()
- [LogRocket: auth libraries for Next.js 2026](https://blog.logrocket.com/best-auth-library-nextjs-2026/) — Community — landscape (search result summary only)

## License / Usage Notes
Next.js MIT; jose MIT; Better Auth MIT; Clerk SDK MIT (commercial service). Vendor APIs change frequently — verify against current docs. Content summarized; code original.

## Quality Tier
A — Strong official grounding and current ecosystem status; vendor snippets summarized from docs pages and may drift.

## Status
Active

## Last Verified
2026-09-15
