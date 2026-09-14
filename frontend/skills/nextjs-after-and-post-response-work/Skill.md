# Next.js after() and Post-Response Work

## Summary
`after()` from `next/server` schedules a callback to run after a response or prerender finishes. Use it for logging, analytics, cache warming, and other side effects that shouldn't slow the user down. It works in Server Components (including `generateMetadata`), Server Functions/Actions, Route Handlers, and `proxy.ts`. It is bounded by the route's max duration and is best-effort, not durable. This skill covers correct usage, request-API rules, platform behavior (Vercel `waitUntil`, self-hosting shutdown), and when to use a durable queue (Inngest, Trigger.dev, QStash) instead.

## Category
Next.js

## Subcategories
Server Actions, Route Handlers, Observability, Background Jobs, Serverless, Deployment

## Problem It Solves
Awaiting analytics calls, audit logs, or third-party pings inside a request adds latency and couples page speed to vendor uptime. Fire-and-forget promises (`void fetch(...)`) often get frozen or killed on serverless platforms once the response is sent. `after()` gives Next.js a supported way to keep the invocation alive until the work settles.

## When To Use
- Analytics or product events after a mutation (`user.signed_up`, `item.added`).
- Audit and activity logging that must not block the response.
- Warming or priming caches, or sending non-critical notifications (Slack pings, internal webhooks).
- Flushing telemetry buffers (OpenTelemetry exporters, log shippers) at the end of a request.
- Short follow-up work (under a few seconds) where occasional loss is acceptable.

## When Not To Use
- Work that must happen exactly once or be retried on failure: payment fulfillment, provisioning, billing sync, sending password-reset emails. Use a durable queue or do it inline.
- Long jobs (video processing, large imports, AI batch runs) that exceed `maxDuration`.
- Anything whose result must change the response. `after()` runs too late for that.
- Static export (`output: 'export'`), where it isn't supported.
- When you need per-request behavior on a static page. There `after()` runs at build or revalidation time, not per visit.

## Core Principles
1. `after()` is best-effort, lifetime-extended work inside the same invocation. It is not a job queue.
2. It runs even if the response errored, or if `notFound()` or `redirect()` was called. Write callbacks that tolerate partial state.
3. It does not make a route dynamic. On static routes the callback runs at build or revalidate time.
4. Request APIs (`cookies()`, `headers()`) can be called inside the callback in Route Handlers and Server Functions. In Server Components, read them during render and close over the values. Calling them inside `after` there throws.
5. The platform's max duration covers the response plus the `after` work. Set `maxDuration` deliberately.
6. Callback errors never reach the user. Catch and log them yourself.

## Best Practices
- Wrap callbacks in try/catch and send failures to your logger or error tracker, tagged with a label and request ID.
- Keep payloads small and serializable. Capture exactly what you need before scheduling.
- Use React `cache` to dedupe expensive lookups shared between render and `after`.
- Put timeouts on outbound calls (`AbortSignal.timeout(3000)`) so one slow vendor can't use up the invocation budget.
- Batch analytics events per request instead of making N `after` calls with N network requests.
- Self-hosting: send `SIGTERM`/`SIGINT` on shutdown and allow a 10-30s drain so pending `after` callbacks finish.
- On Vercel with Next.js 15.1+, use `after()` rather than `@vercel/functions` `waitUntil()`. Use `waitUntil` only outside Next.js or on older versions.
- To hand off durable work, use `after()` only to enqueue (fast, retriable publish), or better, enqueue inline before responding when loss is unacceptable.

## Implementation Guidance
**Decision table**

| Need | Use |
|---|---|
| Result needed in response | Inline `await` |
| Non-critical side effect, < few seconds, loss tolerable | `after()` |
| Must succeed eventually, needs retries/idempotency | Durable queue (Inngest, Trigger.dev, QStash), enqueued inline |
| Multi-step workflow, sleeps, fan-out | Workflow engine (Inngest steps, Trigger.dev tasks) |
| Scheduled/recurring | Cron (platform cron, Inngest/QStash schedules) |
| Stripe/webhook follow-up | Persist event, return 2xx, process idempotently (see stripe-payments-in-nextjs) |

**Where request data can be read**

| Caller | `cookies()`/`headers()` inside `after` callback |
|---|---|
| Route Handler | Allowed |
| Server Function / Server Action | Allowed |
| Server Component / layout / `generateMetadata` | Throws. Read before `after`, pass the values in |
| Component under `<Suspense>` with Cache Components | Read during render in the dynamic component, then close over |

**Platform support (per Next.js docs)**: Node.js server yes, Docker yes, static export no, adapters platform-specific. Custom serverless hosts must provide `waitUntil` via `globalThis[Symbol.for('@next/request-context')]`.

## Recommended Workflow
1. Classify each side effect with the decision table. Write "loss tolerable?" next to each one.
2. Create a small `afterSafe` helper with error capture and timeouts.
3. Move tolerable side effects into `afterSafe`. Move critical ones to inline code or queue publishes.
4. Set `maxDuration` on routes or pages that schedule meaningful work. For Server Actions, set it at the page level.
5. Check logs in a preview deployment to confirm callbacks complete after the response (look at timestamps).
6. For self-hosting, test graceful shutdown during load.

## Patterns
**Safe wrapper**
```ts
// lib/after-safe.ts
import 'server-only'
import { after } from 'next/server'

export function afterSafe(label: string, task: () => Promise<unknown>) {
  after(async () => {
    const started = Date.now()
    try {
      await task()
    } catch (err) {
      console.error(JSON.stringify({ level: 'error', msg: `after:${label} failed`, err: String(err) }))
    } finally {
      console.log(JSON.stringify({ level: 'info', msg: `after:${label}`, ms: Date.now() - started }))
    }
  })
}
```

**Server Action: mutate, then track**
```ts
// app/projects/actions.ts
'use server'
import { headers } from 'next/headers'
import { afterSafe } from '@/lib/after-safe'
import { db } from '@/lib/db'
import { track } from '@/lib/analytics'

export async function createProject(formData: FormData) {
  const name = String(formData.get('name') ?? '').trim()
  if (!name) return { error: 'Name is required' }
  const project = await db.project.create({ data: { name } })

  afterSafe('project.created', async () => {
    const ua = (await headers()).get('user-agent') ?? 'unknown' // allowed in Server Functions
    await track('project.created', { projectId: project.id, ua }, { signal: AbortSignal.timeout(3000) })
  })
  return { id: project.id }
}
```

**Server Component: read first, then schedule**
```tsx
// app/dashboard/page.tsx
import { after } from 'next/server'
import { cookies } from 'next/headers'
import { logView } from '@/lib/analytics'

export default async function Page() {
  const sessionId = (await cookies()).get('sid')?.value ?? 'anon' // read during render
  after(() => logView({ path: '/dashboard', sessionId }))           // no request APIs inside
  return <h1>Dashboard</h1>
}
```

**Proxy: log without blocking routing**
```ts
// proxy.ts
import { NextResponse, after, type NextRequest } from 'next/server'
export function proxy(req: NextRequest) {
  const path = req.nextUrl.pathname
  after(() => fetch(process.env.LOG_INGEST_URL!, { method: 'POST', body: JSON.stringify({ path }) }))
  return NextResponse.next()
}
```

## Anti-Patterns
- **`void fetch(analyticsUrl)` with no `after`.** The serverless runtime may freeze before it completes, so events get lost silently. Fix: `after(() => fetch(...))`.
- **Fulfilling orders or granting entitlements in `after`.** A timeout or crash drops them with no retry. Fix: do it inline with idempotency, or publish to a durable queue and return.
- **`await cookies()` inside an `after` callback in a page or layout.** It throws at runtime. Fix: read during render and pass the value in.
- **Expecting per-visit execution on a static page.** The callback runs at build or revalidate time. Fix: call it from a dynamic boundary, Route Handler, or client beacon.
- **Unbounded loops or retries inside `after`.** They hit `maxDuration` and get killed mid-write. Fix: set a deadline, or move the work to a queue.
- **Swallowed errors.** Failures vanish. Fix: `afterSafe` with structured logs and error tracking.
- **Hard kills on self-hosted deploys (`SIGKILL`, zero drain).** Pending callbacks are lost. Fix: graceful `SIGTERM` with a 10-30s drain period.
- **Leaking PII to analytics in callbacks.** Fix: send IDs, not emails or tokens, and honor consent state captured during the request.

## Accessibility
Not directly user-facing. Indirect rules: never delay confirmation UI while waiting on side effects. Show success from the mutation result (and announce it with a live region, see live-regions-and-announcements), then let `after` handle telemetry.

## Responsive Design
Not applicable. Post-response work doesn't affect layout. Mobile users on slow networks benefit most from shorter response times.

## Performance
- Moving 100-500ms of vendor calls out of the request path directly improves TTFB for dynamic routes and Server Action round-trips.
- Billable duration can still grow on serverless (the invocation stays alive), so batch and time-box callbacks.
- Don't schedule heavy CPU work in `after`. On shared Node instances (Fluid compute, containers) it competes with concurrent requests.
- Use `getDeadline()` from `@vercel/functions` (Vercel only) if a callback needs to check how much time is left.

## Security
- Callbacks run with server privileges. Validate inputs captured from the request just as you would inline.
- Never log secrets, session tokens, raw cookies, or full request bodies. Redact before scheduling.
- Outbound calls to logging or analytics endpoints should use server-only credentials (`process.env.*`, never `NEXT_PUBLIC_*`).
- Queue receivers (QStash, Inngest) must verify signatures (`verifySignatureAppRouter`, Inngest signing key) because they are public endpoints.
- Respect consent: capture the user's analytics consent during render or the action, and skip tracking in the callback if they haven't consented.

## Testing
- Unit test: mock `next/server` `after` to capture callbacks, run them manually, and assert on the side effects and error handling.
```ts
import { vi, test, expect } from 'vitest'
const scheduled: Array<() => unknown> = []
vi.mock('next/server', () => ({ after: (cb: () => unknown) => void scheduled.push(cb) }))
vi.mock('next/headers', () => ({ headers: async () => new Headers({ 'user-agent': 'vitest' }) }))
vi.mock('@/lib/db', () => ({ db: { project: { create: async () => ({ id: 'p1' }) } } }))
const track = vi.fn(async () => {})
vi.mock('@/lib/analytics', () => ({ track }))

test('schedules tracking after create and does not call it inline', async () => {
  const { createProject } = await import('@/app/projects/actions')
  const fd = new FormData()
  fd.set('name', 'Demo')
  await createProject(fd)
  expect(track).not.toHaveBeenCalled()          // not in the request path
  expect(scheduled).toHaveLength(1)
  await Promise.all(scheduled.map((cb) => cb())) // simulate post-response
  expect(track).toHaveBeenCalledWith('project.created', expect.objectContaining({ projectId: 'p1', ua: 'vitest' }), expect.anything())
})
```
- Integration: in a preview deployment, compare response time with and without the side effect, and check the logs show the callback finishing after the response.
- Self-hosted: send `SIGTERM` during a request that schedules work, and check the callback's log line appears before exit.

## Tooling
- `after` from `next/server`: stable since v15.1.0 (introduced as `unstable_after` in 15.0 RC). Current in Next.js 16.3.x.
- `maxDuration` route segment config (seconds). Set it on the page for Server Actions.
- `@vercel/functions` `waitUntil`, `getDeadline`: for non-Next or Next < 15.1 on Vercel.
- Inngest (`inngest`, `serve()` at `app/api/inngest/route.ts`, `inngest.send`, `step.run` retries). Active.
- Trigger.dev (`@trigger.dev/sdk`, `tasks.trigger`, runs on Trigger.dev infra without function timeouts). Active.
- Upstash QStash (`@upstash/qstash` `publishJSON`, `verifySignatureAppRouter`, automatic retries). Active.

## Framework Notes
- **Next.js (App Router, 16.3.x):** use `after()` in Server Components, Server Actions, Route Handlers, and `proxy.ts`. Cache Components: read request data inside the Suspense-wrapped dynamic component and close over it. Pages Router API routes can use `waitUntil` on Vercel. Check current docs for other hosts.
- **React (Vite SPA):** there is no server lifecycle. Use `navigator.sendBeacon()` or `fetch(..., { keepalive: true })` for client analytics on page hide. Put durable work behind your API backend's queue.

## AI Agent Guidance
- Do: classify each side effect as critical or tolerable before choosing `after`.
- Do: use `afterSafe`-style error handling and timeouts, and set `maxDuration` when adding meaningful work.
- Do: in Server Components, move `cookies()`/`headers()` reads outside the callback.
- Don't: put payments, provisioning, or must-send emails in `after` alone.
- Don't: assume `after` runs per request on a static route.
- Verify before done: `next build` output shows unchanged static/dynamic status, logs show callbacks finishing, and there are no "cookies was called inside after" runtime errors.

## Examples
**Durable handoff with Inngest (enqueue inline, process with retries)**
```ts
// app/api/inngest/route.ts
import { serve } from 'inngest/next'
import { inngest } from '@/inngest/client'
import { sendWelcomeSequence } from '@/inngest/functions'
export const { GET, POST, PUT } = serve({ client: inngest, functions: [sendWelcomeSequence] })
```
```ts
// app/signup/actions.ts
'use server'
import { inngest } from '@/inngest/client'
export async function signUp(formData: FormData) {
  const user = await createUser(formData)                               // inline, critical
  await inngest.send({ name: 'app/user.signed_up', data: { userId: user.id } }) // durable, retried
  return { ok: true }
}
```
Check current docs for the exact `createFunction` option shape in your Inngest SDK version.

**QStash receiver with signature verification**
```ts
// app/api/jobs/resize/route.ts
import { verifySignatureAppRouter } from '@upstash/qstash/nextjs'
export const POST = verifySignatureAppRouter(async (req: Request) => {
  const { imageId } = (await req.json()) as { imageId: string }
  await resizeImage(imageId) // must be idempotent: QStash retries on non-2xx
  return new Response('ok')
})
```

## Related Skills
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): the most common caller of `after`
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md): request APIs allowed inside `after`
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md): `after` in `proxy.ts`
- [frontend-observability](../frontend-observability/Skill.md): logging and telemetry pipelines
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md): graceful shutdown and platform limits
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md): static vs dynamic implications
- [stripe-payments-in-nextjs](../stripe-payments-in-nextjs/Skill.md): why fulfillment is not `after` work
- [transactional-email-with-react-email](../transactional-email-with-react-email/Skill.md): choosing inline vs queued email sends

## Sources
- [Next.js API: after](https://nextjs.org/docs/app/api-reference/functions/after) (Official): callers, duration, request API rules, Cache Components, platform support, version history (docs v16.3.5)
- [Next.js Guide: Self-hosting, after](https://nextjs.org/docs/app/guides/self-hosting) (Official): graceful shutdown and drain period
- [Next.js API: maxDuration](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration) (Official): syntax, Server Actions note
- [Vercel: @vercel/functions reference](https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package) (Official): `waitUntil`, `getDeadline`, recommendation to use `after` on Next 15.1+
- [Inngest: Next.js quick start](https://www.inngest.com/docs/getting-started/nextjs-quick-start) (Official): `serve`, `createFunction`, `inngest.send`, steps
- [Upstash QStash: Next.js quickstart](https://upstash.com/docs/qstash/quickstarts/vercel-nextjs) (Official): `publishJSON`, `verifySignatureAppRouter`, env vars
- [Trigger.dev: Next.js guide](https://trigger.dev/docs/guides/frameworks/nextjs) (Official): `tasks.trigger`, execution model

## License / Usage Notes
Vendor documentation is summarized, not copied. Code examples are original and illustrative. Next.js is MIT-licensed. Inngest, Trigger.dev, and Upstash SDKs have their own licenses (check each repo).

## Quality Tier
A: behavior and limits verified against current Next.js 16.3.5 and Vercel docs. Queue sections are brief, and their SDK option shapes are flagged to check.

## Status
Active

## Last Verified
2026-09-15
