# Next.js Route Handlers

## Summary
Route Handlers (`app/**/route.ts`) are public HTTP endpoints built on Web `Request`/`Response` (extended by `NextRequest`/`NextResponse`), supporting `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`. They implement the Backend-for-Frontend pattern: webhooks, OAuth callbacks, file/stream responses, RSS/`llms.txt`/`.well-known`, APIs for mobile or third parties, and proxies to internal services. With Cache Components, `GET` handlers follow the page prerendering model (static unless they touch request/uncached data; cache helpers with `'use cache'`). Without it, handlers are uncached by default and opt in with `dynamic = 'force-static'`.

## Category
Next.js

## Subcategories
route.ts, NextRequest, NextResponse, RouteContext, webhooks, CORS, streaming responses, SSE, file downloads, rate limiting, content negotiation, special metadata routes

## Problem It Solves
Choosing wrongly between Server Actions and endpoints, unauthenticated or unvalidated APIs, webhook spoofing, open redirects in callbacks, broken caching expectations after v15/v16, and serverless limitations (timeouts, no WebSockets).

## When To Use
- Endpoints consumed by non-React clients (mobile apps, partners, cron, CMS webhooks).
- OAuth/payment callbacks and auth library handlers (`[...all]` catch-all).
- Streaming raw responses (SSE, large CSV, AI token streams).
- Non-HTML content (RSS, sitemaps beyond conventions, JSON feeds, markdown for agents).
- Client-side polling/infinite scroll data for Client Components.

## When Not To Use
- Mutations from your own React UI — prefer Server Actions (single round trip, progressive enhancement).
- Data for Server Components — call the data function directly, never your own handler.
- Long-lived WebSockets on serverless hosts (connections close); use a dedicated realtime service.
- AI chat streaming specifics (see [vercel-ai-sdk-integration](../vercel-ai-sdk-integration/Skill.md)).

## Core Principles
1. **Public by definition.** Authenticate, authorize, validate, rate-limit.
2. **A segment has either `page` or `route`,** never both.
3. **Handlers don't participate in layouts or client navigation.**
4. **Read the body once** (clone if needed); `GET`/`HEAD` have no body.
5. **Be deliberate with headers:** never reflect request headers into responses; set `Vary` when content negotiates.

## Best Practices
- Type context with `RouteContext<'/users/[id]'>`; `await ctx.params`.
- Validate `request.json()`/`formData()` with zod; enforce content-type and size.
- Verify webhook signatures (HMAC over the raw body with timing-safe compare) before parsing/acting.
- Use `revalidateTag(tag, 'max')` from webhooks (`updateTag` is Server Action only).
- Prevent open redirects: ensure redirect URLs are same-origin or allowlisted.
- Return generic error messages; log details server-side.
- Set CORS per route (or in proxy for `/api/*`), with explicit origin allowlists and `Vary: Origin`.
- Use `after()` for post-response work (logging, analytics).
- Set `maxDuration` (segment config) for long-running handlers where the platform supports it.
- Under Cache Components, put `'use cache'` in helper functions (not directly in the handler body).

## Implementation Guidance

### Caching behavior
| Mode | GET behavior | Opt into caching |
|---|---|---|
| Cache Components on | Prerendered if no request/uncached data; else request-time | `'use cache'` helper + `cacheLife` |
| Previous model | Uncached (since v15) | `export const dynamic = 'force-static'` |
| Other methods | Never cached | — |
| Static export | Only GET with `force-static` | — |

Prerendering stops on: network/DB/async fs access, `request.url`/headers/cookies/body, `cookies()`, `headers()`, `connection()`, non-deterministic calls.

### Server Action vs Route Handler
| Need | Choose |
|---|---|
| Form/mutation from own UI | Server Action |
| Third-party caller / webhook / cron | Route Handler |
| Non-POST verbs, custom status codes, streaming bytes | Route Handler |
| Progressive enhancement without JS | Server Action |
| Parallel client requests | Route Handler (actions are queued) |

### Typed JSON endpoint with auth and validation
```ts
// app/api/projects/[id]/route.ts
import { z } from 'zod'
import { type NextRequest } from 'next/server'
import { getSessionFromRequest } from '@/lib/dal/auth'
import { getProjectForUser, updateProjectForUser } from '@/lib/dal/projects'

const Patch = z.object({ name: z.string().trim().min(1).max(100) })

export async function GET(_req: NextRequest, ctx: RouteContext<'/api/projects/[id]'>) {
  const session = await getSessionFromRequest()
  if (!session) return Response.json({ error: 'unauthorized' }, { status: 401 })
  const { id } = await ctx.params
  const project = await getProjectForUser(id, session.userId)
  if (!project) return Response.json({ error: 'not_found' }, { status: 404 })
  return Response.json(project)
}

export async function PATCH(req: NextRequest, ctx: RouteContext<'/api/projects/[id]'>) {
  const session = await getSessionFromRequest()
  if (!session) return Response.json({ error: 'unauthorized' }, { status: 401 })
  if (!req.headers.get('content-type')?.includes('application/json')) return new Response(null, { status: 415 })
  const parsed = Patch.safeParse(await req.json().catch(() => null))
  if (!parsed.success) return Response.json({ error: 'invalid', issues: parsed.error.flatten() }, { status: 400 })
  const { id } = await ctx.params
  const updated = await updateProjectForUser(id, session.userId, parsed.data)
  return updated ? Response.json(updated) : Response.json({ error: 'not_found' }, { status: 404 })
}
```

### Signed webhook → revalidation
```ts
// app/api/webhooks/cms/route.ts
import { createHmac, timingSafeEqual } from 'node:crypto'
import { revalidateTag } from 'next/cache'

const ALLOWED_TAGS = /^(posts|post:[a-z0-9-]+|products)$/

export async function POST(req: Request) {
  const raw = await req.text()
  const sig = req.headers.get('x-signature') ?? ''
  const expected = createHmac('sha256', process.env.CMS_WEBHOOK_SECRET!).update(raw).digest('hex')
  const ok = sig.length === expected.length && timingSafeEqual(Buffer.from(sig), Buffer.from(expected))
  if (!ok) return new Response(null, { status: 401 })
  const { tag } = JSON.parse(raw) as { tag?: string }
  if (!tag || !ALLOWED_TAGS.test(tag)) return new Response(null, { status: 400 })
  revalidateTag(tag, 'max')
  return Response.json({ revalidated: tag })
}
```

### Streaming (SSE)
```ts
// app/api/events/route.ts
export async function GET(req: Request) {
  const encoder = new TextEncoder()
  const stream = new ReadableStream({
    async start(controller) {
      const send = (data: unknown) => controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`))
      const timer = setInterval(() => send({ t: Date.now() }), 1000)
      req.signal.addEventListener('abort', () => { clearInterval(timer); controller.close() })
    },
  })
  return new Response(stream, { headers: { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' } })
}
```

### Cached GET under Cache Components
```ts
// app/api/catalog/route.ts
import { cacheLife, cacheTag } from 'next/cache'
export async function GET() {
  return Response.json(await getCatalog())
}
async function getCatalog() {
  'use cache'
  cacheLife('hours')
  cacheTag('catalog')
  return db.product.findMany({ select: { id: true, name: true, price: true } })
}
```

### Safe OAuth-style callback
```ts
import { NextResponse, type NextRequest } from 'next/server'
export async function GET(req: NextRequest) {
  const next = req.nextUrl.searchParams.get('next') ?? '/'
  const dest = new URL(next, req.url)
  if (dest.origin !== req.nextUrl.origin) return new Response('Invalid redirect', { status: 400 })
  // exchange code, create session cookie (httpOnly, secure, sameSite)...
  return NextResponse.redirect(dest)
}
```

## Recommended Workflow
1. Confirm a Route Handler is the right tool (vs Server Action / Server Component).
2. Define request/response schemas.
3. Implement auth + validation + DAL call; map errors to status codes.
4. Add CORS/rate limiting/signature verification as needed.
5. Decide caching (Cache Components helper vs force-static vs none).
6. Test with unauthenticated, malformed, oversized, and cross-origin requests.

## Patterns
- **Library catch-all handler:** `export const { GET, POST } = toNextJsHandler(auth)` (Better Auth).
- **Content negotiation:** `next.config` rewrite on `Accept: text/markdown` → markdown handler with `Vary: Accept`.
- **File download stream:** `new Response((await open(path)).readableWebStream(), { headers: { 'Content-Disposition': 'attachment; filename="x.csv"' } })`.
- **BFF proxy:** validate, then `fetch(new Request(upstreamUrl, request))`.
- **Health check:** `app/api/health/route.ts` returning 200 with no dependencies.

## Anti-Patterns
- **`page.tsx` and `route.ts` in same folder** — conflict. Fix: separate paths.
- **Server Component `fetch('http://localhost:3000/api/x')`** — extra hop, build failure. Fix: call function directly.
- **Webhook secret in query string compared with `!==`** — leaks in logs, timing attack. Fix: HMAC header + `timingSafeEqual` (the docs' token example is minimal; harden it).
- **`updateTag` in a Route Handler** — throws. Fix: `revalidateTag(tag, 'max')`.
- **Reflecting `Origin` into `Access-Control-Allow-Origin` without allowlist** — CORS bypass. Fix: allowlist.
- **Returning stack traces/DB errors** — info leak. Fix: generic messages.
- **`'use cache'` directly in `GET`** — unsupported. Fix: cached helper.
- **Reading body twice** — throws. Fix: `request.clone()` or parse once.

## Accessibility
- Not UI-facing, but error payloads consumed by UIs should include human-readable, localizable messages or codes the client maps to accessible messages.
- Download endpoints should set filenames and content types so assistive tech/browsers present them correctly.

## Responsive Design
- Not applicable directly; keep API payloads lean for mobile clients (pagination, field selection).

## Performance
- Avoid heavy cold-start imports; lazy-import large SDKs inside handlers.
- Paginate and stream large responses.
- Cache GET data via helpers or CDN headers (`Cache-Control: public, s-maxage=…, stale-while-revalidate=…`) for public data.
- Use `after()` to keep response latency low.

## Security
- AuthN/AuthZ on every handler; don't rely on proxy.
- CSRF: cookie-authenticated state-changing handlers need Origin checks or CSRF tokens (Server Actions do this for you; handlers don't).
- Validate size/type; set timeouts on upstream fetches (`AbortSignal.timeout`).
- Rate-limit expensive endpoints (return 429).
- Keep secrets server-side; rotate webhook secrets.

## Testing
- Unit/integration: import the handler and call `GET(new NextRequest(url), { params: Promise.resolve({ id }) })`; assert status/body.
- Contract tests with zod schemas for responses.
- Security tests: 401 without session, 403 wrong owner, 400 invalid payload, 415 wrong content-type, invalid webhook signature.
- E2E with Playwright `request` fixture.

## Tooling
- `NextRequest`/`NextResponse`, `RouteContext` (generated types), `after()`.
- zod, `@upstash/ratelimit` (or platform WAF), MSW for upstream mocks.
- `create-next-app --api` scaffolds an example route.

## Framework Notes
- v15: GET no longer cached by default. v16: `params` Promise required; Cache Components prerender model for GET.
- Root params getters not yet supported in Route Handlers (planned).
- Special handlers (`sitemap.ts`, `opengraph-image.tsx`, `icon.tsx`) are static by default unless using request-time APIs.
- React (Vite SPA): no server endpoints — use a separate API service (Hono/Express) or serverless functions; for typed end-to-end calls consider tRPC.

## AI Agent Guidance
- Choose Server Actions for own-UI mutations; Route Handlers for external callers.
- Every generated handler: typed context, auth, zod validation, explicit status codes, no internal error leakage.
- Before done: run through unauthenticated/malformed request cases, confirm caching mode matches intent, confirm no page/route conflicts in `next build`.

## Examples
```ts
// app/rss.xml/route.ts
import { cacheLife, cacheTag } from 'next/cache'
export async function GET() {
  const xml = await buildRss()
  return new Response(xml, { headers: { 'Content-Type': 'application/rss+xml; charset=utf-8' } })
}
async function buildRss() {
  'use cache'
  cacheLife('hours')
  cacheTag('posts')
  const posts = await getPublishedPosts()
  const esc = (s: string) => s.replace(/[<>&'"]/g, (c) => `&#${c.charCodeAt(0)};`)
  return `<?xml version="1.0"?><rss version="2.0"><channel><title>Acme</title>${posts
    .map((p) => `<item><title>${esc(p.title)}</title><link>https://acme.com/blog/${p.slug}</link></item>`)
    .join('')}</channel></rss>`
}
```

## Related Skills
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — alternative for UI mutations
- [nextjs-authentication](../nextjs-authentication/Skill.md) — auth in handlers
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — CORS/proxy layer
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — webhook revalidation
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md) — typed API layer on handlers
- [vercel-ai-sdk-integration](../vercel-ai-sdk-integration/Skill.md) — AI streaming endpoints
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — API design

## Sources
- [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers) — Official — conventions, caching, Cache Components model, RouteContext
- [Backend for Frontend guide](https://nextjs.org/docs/app/guides/backend-for-frontend) — Official — content types, webhooks, callbacks, security, caveats
- [Streaming guide](https://nextjs.org/docs/app/guides/streaming) — Official — streaming responses, file streams
- [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) — Official — GET handler migration
- [Revalidating](https://nextjs.org/docs/app/getting-started/revalidating) — Official — revalidateTag in handlers, updateTag restriction
- [Better Auth Next.js integration](https://www.better-auth.com/docs/integrations/next) — Open Source — catch-all handler pattern

## License / Usage Notes
Next.js MIT; zod MIT. HMAC verification and SSE examples are original hardening of documented patterns.

## Quality Tier
A — Complete and security-conscious; SSE/HMAC examples are standard practice rather than official snippets.

## Status
Active

## Last Verified
2026-09-15
