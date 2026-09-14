# Testing Server Components and Server Actions

## Summary
How to test the server side of a Next.js App Router application: async React Server Components, Server Actions (`'use server'`), Route Handlers, `proxy.ts` (formerly middleware), caching/revalidation and server-side data fetching. Defines what is realistically unit-testable in Vitest/Jest today, which Next.js APIs must be mocked, and what must be verified end-to-end against a production build, including techniques for mocking server-originated fetches in E2E.

## Category
Testing & QA

## Subcategories
React Server Components, Server Actions, Route Handlers, proxy/middleware testing, next/headers and next/cache mocking, server-side fetch mocking, Next.js experimental test mode

## Problem It Solves
Official Next.js docs state Vitest, Jest and Cypress component testing do not support `async` Server Components and recommend E2E. Teams then either skip server logic tests or write fragile hacks. Server-side fetches are also invisible to browser-level mocking (`page.route`, MSW service worker), so E2E suites end up calling real third-party APIs.

## When To Use
- Writing or refactoring Server Actions, Route Handlers, RSC data loaders, `proxy.ts`.
- Designing E2E tests that need deterministic server-side data.
- Reviewing authorization in Server Functions.

## When Not To Use
- Client Components - see [component-testing](../component-testing/Skill.md).
- Vite SPA without a server runtime - not applicable.

## Core Principles
1. Keep Server Components and Actions thin: parse input, authorize, call a domain function, return/redirect/revalidate. Unit test the domain function and the action's orchestration; E2E the page.
2. Async Server Component rendering is verified with E2E (official recommendation).
3. Mock Next.js runtime APIs (`next/headers`, `next/cache`, `next/navigation`) at the module boundary in unit tests.
4. Every Server Action is a public POST endpoint: test authentication, authorization and input validation for each.
5. Server-side network must be mocked on the server side (mock server, injected client, or Next test proxy), not in the browser.

## Best Practices
- Validate Server Action input with zod and return typed result objects (`{ ok: false, errors }`) rather than throwing for validation; this makes actions easy to unit test.
- Inject data access (`lib/db`, API clients) via modules you can `vi.mock`, or pass dependencies to an inner `createProjectCore(deps, input)` function.
- Remember `redirect()` and `notFound()` work by throwing; in unit tests mock them to record calls (or assert the thrown digest - fragile, avoid).
- Use `import 'server-only'` in server modules; in Vitest, alias or mock `server-only` to an empty module.
- Test Route Handlers by calling the exported `GET/POST` with a `new Request(...)` / `NextRequest`.
- Test `proxy.ts` matching and rewrites with `next/experimental/testing/server` (available since Next 15.1; `unstable_` APIs).
- In E2E, point server-side API base URLs to a local mock server via env vars set in `webServer.env`.

## Implementation Guidance

### What goes where
| Subject | Unit (Vitest node) | Component (jsdom) | E2E (Playwright + next start) |
|---|---|---|---|
| Domain logic called by RSC/actions | Yes | - | - |
| Server Action: validation, auth checks, calls, `revalidatePath`/`revalidateTag`, `redirect` | Yes (mock next APIs) | - | One happy + one auth-failure path |
| Sync Server Component (props only) | - | Yes | Optional |
| Async Server Component (awaits data) | Workaround only | No | Yes |
| Streaming/Suspense boundaries, `loading.tsx`, `error.tsx` | - | - | Yes |
| Caching, `use cache`, revalidation effects | - | - | Yes (build + start) |
| Route Handler | Yes (call handler) | - | Smoke |
| `proxy.ts` matcher, redirects, rewrites | Yes (`next/experimental/testing/server`) | - | Smoke (auth redirect) |
| Cookies/headers set by actions | Mocked | - | Yes |

### vitest server project extras
```ts
// in vitest.config.mts projects[]
{
  extends: true,
  test: {
    name: 'server',
    environment: 'node',
    include: ['app/**/*.server.test.ts', 'lib/**/*.test.ts'],
    setupFiles: ['./test/server-setup.ts'],
    alias: { 'server-only': new URL('./test/empty.ts', import.meta.url).pathname },
  },
}
```

### Unit testing a Server Action
```ts
// app/projects/actions.ts
'use server'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { getSession } from '@/lib/auth'
import { db } from '@/lib/db'

const Input = z.object({ name: z.string().trim().min(1, 'Name is required').max(80) })
export type CreateProjectState = { ok: boolean; errors?: Record<string, string[]> }

export async function createProject(_prev: CreateProjectState, formData: FormData): Promise<CreateProjectState> {
  const session = await getSession()
  if (!session) return { ok: false, errors: { _form: ['Unauthorized'] } }
  const parsed = Input.safeParse({ name: formData.get('name') })
  if (!parsed.success) return { ok: false, errors: parsed.error.flatten().fieldErrors }
  const project = await db.project.create({ data: { name: parsed.data.name, ownerId: session.userId } })
  revalidatePath('/projects')
  redirect(`/projects/${project.id}`)
}
```
```ts
// app/projects/actions.server.test.ts
import { beforeEach, describe, expect, test, vi } from 'vitest'

vi.mock('next/cache', () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }))
vi.mock('next/navigation', () => ({ redirect: vi.fn() }))
vi.mock('@/lib/auth', () => ({ getSession: vi.fn() }))
vi.mock('@/lib/db', () => ({ db: { project: { create: vi.fn() } } }))

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { getSession } from '@/lib/auth'
import { db } from '@/lib/db'
import { createProject } from './actions'

const form = (entries: Record<string, string>) => {
  const fd = new FormData()
  Object.entries(entries).forEach(([k, v]) => fd.set(k, v))
  return fd
}

describe('createProject', () => {
  beforeEach(() => vi.mocked(getSession).mockResolvedValue({ userId: 'u1' } as never))

  test('rejects unauthenticated users without touching the db', async () => {
    vi.mocked(getSession).mockResolvedValue(null)
    const result = await createProject({ ok: false }, form({ name: 'Apollo' }))
    expect(result).toEqual({ ok: false, errors: { _form: ['Unauthorized'] } })
    expect(db.project.create).not.toHaveBeenCalled()
  })

  test('returns field errors for empty name', async () => {
    const result = await createProject({ ok: false }, form({ name: '  ' }))
    expect(result.errors?.name).toContain('Name is required')
  })

  test('creates, revalidates and redirects', async () => {
    vi.mocked(db.project.create).mockResolvedValue({ id: 'p1' } as never)
    await createProject({ ok: false }, form({ name: 'Apollo' }))
    expect(db.project.create).toHaveBeenCalledWith({ data: { name: 'Apollo', ownerId: 'u1' } })
    expect(revalidatePath).toHaveBeenCalledWith('/projects')
    expect(redirect).toHaveBeenCalledWith('/projects/p1')
  })
})
```

### Mocking next/headers
```ts
vi.mock('next/headers', () => ({
  cookies: vi.fn(async () => ({ get: (n: string) => (n === 'session' ? { name: n, value: 'token' } : undefined), set: vi.fn(), delete: vi.fn() })),
  headers: vi.fn(async () => new Headers({ 'x-forwarded-for': '203.0.113.1' })),
}))
```
`cookies()` and `headers()` are async in Next 15+.

### Route Handler test
```ts
import { expect, test } from 'vitest'
import { GET } from '@/app/api/health/route'

test('health returns ok', async () => {
  const res = await GET(new Request('http://localhost/api/health'))
  expect(res.status).toBe(200)
  expect(await res.json()).toEqual({ status: 'ok' })
})
```

### proxy.ts unit test (experimental helpers)
```ts
import { NextRequest } from 'next/server'
import { unstable_doesProxyMatch, isRewrite, getRewrittenUrl } from 'next/experimental/testing/server'
import { config, proxy } from '@/proxy'
import nextConfig from '@/next.config'

test('matcher skips static assets', () => {
  expect(unstable_doesProxyMatch({ config, nextConfig, url: '/_next/static/chunk.js' })).toBe(false)
})
test('rewrites docs', async () => {
  const res = await proxy(new NextRequest('https://example.com/docs'))
  expect(isRewrite(res)).toBe(true)
  expect(getRewrittenUrl(res)).toBe('https://docs.example.com/docs')
})
```
Older versions expose `unstable_doesMiddlewareMatch`; check the installed Next version.

### Async Server Component: workaround (not officially supported)
Calling the component as a function and rendering the result can work for leaf components with no async children and no client hooks:
```tsx
const ui = await ProjectHeader({ params: Promise.resolve({ id: 'p1' }) })
render(ui)
```
It breaks with nested async components, Suspense streaming, `use cache`, and many Next APIs. Treat as optional; E2E remains the source of truth. React/Next may add first-class RSC test utilities - Check current docs.

### E2E: mocking server-side fetches
| Technique | How | Trade-offs |
|---|---|---|
| Env-pointed mock server | `webServer: [{ command: 'node e2e/mock-api.mjs', url: 'http://localhost:4010/health' }, { command: 'npm run start', env: { API_URL: 'http://localhost:4010' } }]` | Simple, robust, per-run data; cannot vary per test without an admin endpoint |
| Next experimental test proxy | `experimental: { testProxy: true }` in `next.config`, import `test` from `next/experimental/testmode/playwright`, use `next.onFetch(req => new Response(...))` | Per-test mocks of external fetches (server and client); experimental, only intercepts external URLs |
| MSW in `instrumentation.ts` (`setupServer` in `register()` when `APP_ENV=test`) | Patches Node fetch in the server process | Known App Router limitations (MSW issue #1644 open - multiple processes/module patching); verify with your Next version |
| Seeded real backend/test DB | Seed via API/fixtures | Most realistic; needs data isolation |

## Recommended Workflow
1. Refactor: move data/business logic out of `page.tsx` and action bodies into `lib/`.
2. Unit test `lib/` functions (node env).
3. Unit test each Server Action for unauthenticated, unauthorized, invalid input, success (revalidate/redirect).
4. Unit test Route Handlers and `proxy.ts` matchers.
5. Add E2E for each page with async data: render, empty state, error boundary, and form submission via Server Action.
6. Provide deterministic server data in E2E via mock server or test proxy.

## Patterns
- **Humble page**: `page.tsx` awaits `getProjects()` and renders `<ProjectsView projects={...} />` (sync, component-testable).
- **Action core + wrapper**: `createProjectCore(deps, input)` pure-ish and tested; exported action wires real deps.
- **Result object**: actions return discriminated unions consumed by `useActionState`.
- **Auth matrix test**: `test.each([[null, 'Unauthorized'], [{ role: 'viewer' }, 'Forbidden']])`.

## Anti-Patterns
- **Relying on `proxy.ts` for auth of Server Actions**: Next.js docs warn matchers can silently skip Server Function calls. Fix: check auth inside each action; test it.
- **Browser-level mocks for server data** (`page.route` for RSC fetch): never intercepted. Fix: server-side mocking technique above.
- **Asserting `redirect` by catching `NEXT_REDIRECT` errors**: couples to internals. Fix: mock `next/navigation`.
- **Testing actions only through E2E**: slow feedback on validation/auth permutations. Fix: unit tests per branch.
- **Rendering async pages in jsdom as the only coverage**. Fix: E2E.

## Accessibility
Server-rendered forms must work without JS (progressive enhancement) where designed; E2E can verify with `test.use({ javaScriptEnabled: false })` that the form posts and renders errors with proper `role="alert"` or associated descriptions. Detailed a11y automation: [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).

## Responsive Design
Not specific; server output is viewport-independent unless reading `user-agent` headers - test such branches by mocking `headers()` in unit tests and device projects in E2E.

## Performance
- Unit tests of actions run in milliseconds; keep permutations there.
- E2E per async page: one or two specs. Use a single build across shards.
- Assert caching behavior in E2E sparingly (e.g., mutation followed by revalidated list).

## Security
- Test authorization for every Server Action and Route Handler (IDOR: user cannot mutate another user's resource by ID).
- Test input validation and size limits.
- Ensure test-only switches (`testProxy`, mock API URLs, seed routes) are disabled in production config; add a unit test asserting `experimental.testProxy` is not enabled when `NODE_ENV=production` if you toggle it by env.
- Never place secrets in mocked `headers()`/`cookies()` fixtures beyond dummy values.

## Testing
Validate coverage by listing each exported Server Action/Route Handler and checking for unit tests covering auth + validation + success.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| Vitest 5 (node env) / Jest 30 | Unit tests for actions, handlers |
| `next/experimental/testing/server` | Experimental (`unstable_doesProxyMatch`, `isRewrite`, `getRewrittenUrl`, `getRedirectUrl`) |
| `next/experimental/testmode/playwright` | Experimental test proxy |
| Playwright 1.63 | E2E |
| MSW 2.x | Node mocking; App Router server caveats |

## Framework Notes
- **Next.js**: `middleware` renamed to `proxy` in Next 16 (codemod available); proxy defaults to Node.js runtime. `cookies()`, `headers()`, `params`, `searchParams` are async. Server Functions are POSTs to the page route.
- **React (Vite SPA)**: No RSC/Server Actions; server logic lives in a separate API tested with its own tooling. React 19 client actions (`useActionState` with client functions) are component-testable.

## AI Agent Guidance
- Do: when adding a Server Action, add unit tests for unauthenticated, invalid, and success cases in the same change.
- Do: mock `next/cache`, `next/navigation`, `next/headers` at module level; keep domain modules real where possible.
- Do: route async page verification to Playwright.
- Don't: attempt to make async Server Components render in jsdom as primary coverage.
- Don't: enable `experimental.testProxy` or mock endpoints in production config.
- Before done: action tests pass, E2E for the page passes against `next build && next start`, auth checks exist inside the action.

## Examples
E2E with Next test proxy (experimental):
```ts
// next.config.ts: experimental: { testProxy: process.env.NEXT_TEST_PROXY === '1' }
import { test, expect } from 'next/experimental/testmode/playwright'

test('product page renders data from upstream API', async ({ page, next }) => {
  next.onFetch((request) => {
    if (request.url === 'https://api.example.com/products/shoe') {
      return new Response(JSON.stringify({ title: 'Trail Shoe', price: 120 }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }
    return 'abort'
  })
  await page.goto('/products/shoe')
  await expect(page.getByRole('heading', { name: 'Trail Shoe' })).toBeVisible()
})
```

## Related Skills
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) - action design
- [react-server-components](../react-server-components/Skill.md) - RSC model
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) - humble component structure
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) - proxy design
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) - handler design
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - E2E layer
- [api-mocking-msw](../api-mocking-msw/Skill.md) - MSW caveats
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) - server project config

## Sources
- [Next.js Testing guide](https://nextjs.org/docs/app/guides/testing) - Official - async Server Components: recommend E2E
- [Next.js: Vitest guide](https://nextjs.org/docs/app/guides/testing/vitest) - Official - sync vs async component support
- [Next.js proxy.js reference](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) - Official - unit testing helpers, Server Function auth warning, v16 rename
- [Next.js experimental test mode README](https://github.com/vercel/next.js/tree/canary/packages/next/src/experimental/testmode/playwright) - Open Source - testProxy and next.onFetch
- [MSW issue #1644: Next.js App Router support](https://github.com/mswjs/msw/issues/1644) - Open Source - server-side limitations

## License / Usage Notes
Next.js and MSW are MIT-licensed. Examples are original. The async component workaround is community practice, not an official API.

## Quality Tier
A - Core boundaries and helpers verified in current Next.js docs; experimental APIs and MSW-in-instrumentation behavior can change.

## Status
Active

## Last Verified
2026-09-15
