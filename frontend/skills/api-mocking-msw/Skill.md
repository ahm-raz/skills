# API Mocking with MSW

## Summary
Mock Service Worker (MSW) intercepts network requests at the network layer - a Service Worker in the browser and request-module patching in Node - so the same typed request handlers can power unit/component tests (Vitest/Jest), Storybook, local development and demos. This skill covers MSW 2.x APIs (`http`, `graphql`, `HttpResponse`), handler organization, per-test overrides, `onUnhandledRequest`, and the Next.js App Router caveats for server-side requests.

## Category
Testing & QA

## Subcategories
Network mocking, request handlers, setupServer, setupWorker, GraphQL mocking, Storybook MSW addon, Next.js server-side mocking, contract drift

## Problem It Solves
Mocking `fetch`, axios or data hooks module-by-module couples tests to implementation and drifts from the real API. Tests pass while integration breaks. MSW lets the application code run unchanged while responses are controlled centrally and deterministically.

## When To Use
- Component tests for data-fetching components (TanStack Query, SWR, fetch in effects).
- Storybook stories for loading/empty/error states.
- Local frontend development before or independent of a backend.
- Vite SPA E2E where all requests originate in the browser.

## When Not To Use
- Server-side fetches inside Next.js App Router (RSC, Server Actions) in a running `next` server - MSW support is limited (see Framework Notes); prefer injected clients, env-pointed mock servers or Next's experimental test proxy.
- Playwright tests that only need a single stub (`page.route` is simpler).
- Contract verification against the real API (use contract tests/Pact/schema validation).

## Core Principles
1. Mock the network, not your code.
2. Default handlers describe the happy path; tests override per scenario with `server.use()`.
3. Fail on unhandled requests in tests (`onUnhandledRequest: 'error'`).
4. Reset handlers after each test to prevent leakage.
5. Type handlers from the API schema so mocks drift loudly.

## Best Practices
- Organize: `mocks/handlers/{projects,users}.ts`, `mocks/handlers.ts` (aggregate), `mocks/node.ts` (`setupServer`), `mocks/browser.ts` (`setupWorker`), `mocks/data/` (factories).
- Use absolute-URL-agnostic patterns (`*/api/projects`) or a shared `API_URL` constant.
- Use generics for type safety: `http.get<Params, RequestBody, ResponseBody>(...)`.
- Use `HttpResponse.json(data, { status })`, `HttpResponse.error()` for network errors, `delay()` for loading states.
- Use factories (e.g., `@faker-js/faker` with fixed seed or hand-written builders) - see [test-data-and-fixtures](../test-data-and-fixtures/Skill.md).
- Assert requests by outcome in UI; if you must assert payloads, capture in handler (`let body; http.post(..., async ({ request }) => { body = await request.json() ... })`).
- Await `worker.start()` before rendering the app in the browser to avoid race conditions.
- Enable browser mocking only in development/test (never in production bundles): dynamic import behind an env flag.

## Implementation Guidance

### Handlers
```ts
// mocks/handlers/projects.ts
import { http, HttpResponse, delay } from 'msw'
import type { Project } from '@/lib/types'
import { buildProject } from '../data/project'

export const projectHandlers = [
  http.get<never, never, Project[]>('*/api/projects', () =>
    HttpResponse.json([buildProject({ name: 'Apollo' }), buildProject({ name: 'Gemini' })]),
  ),
  http.post<never, { name: string }, Project | { message: string }>('*/api/projects', async ({ request }) => {
    const { name } = await request.json()
    if (!name.trim()) return HttpResponse.json({ message: 'Name is required' }, { status: 422 })
    await delay(50)
    return HttpResponse.json(buildProject({ name }), { status: 201 })
  }),
]
```

### Node (Vitest/Jest)
```ts
// mocks/node.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'
export const server = setupServer(...handlers)
```
```ts
// vitest.setup.ts
import { afterAll, afterEach, beforeAll } from 'vitest'
import { server } from '@/mocks/node'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```
Debugging: `server.events.on('request:start', ({ request }) => console.log(request.method, request.url))`.

Jest + jsdom note: jsdom environments may lack `fetch`, `TextEncoder`, streams or `BroadcastChannel` globals required by MSW 2; MSW docs suggest environment fixes (e.g., `jest-fixed-jsdom`) - Check current docs. Vitest's jsdom environment uses Node globals and generally works.

### Per-test override
```tsx
import { http, HttpResponse } from 'msw'
import { server } from '@/mocks/node'

test('shows empty state', async () => {
  server.use(http.get('*/api/projects', () => HttpResponse.json([])))
  renderWithProviders(<ProjectsList />)
  expect(await screen.findByText(/no projects yet/i)).toBeInTheDocument()
})

test('shows retry on network failure', async () => {
  server.use(http.get('*/api/projects', () => HttpResponse.error()))
  renderWithProviders(<ProjectsList />)
  expect(await screen.findByRole('button', { name: /retry/i })).toBeInTheDocument()
})
```
One-time handler: `http.get(url, resolver, { once: true })`.

### Browser (Vite SPA dev or Storybook)
```bash
npx msw init public/ --save
```
```tsx
// src/main.tsx (Vite SPA)
async function enableMocking() {
  if (import.meta.env.MODE !== 'development' || import.meta.env.VITE_API_MOCKING !== 'enabled') return
  const { worker } = await import('./mocks/browser')
  await worker.start({ onUnhandledRequest: 'bypass' })
}
enableMocking().then(() => {
  ReactDOM.createRoot(document.getElementById('root')!).render(<App />)
})
```

### GraphQL
```ts
import { graphql, HttpResponse } from 'msw'
graphql.query('GetProject', ({ variables }) => HttpResponse.json({ data: { project: { id: variables.id, name: 'Apollo' } } }))
```

### Next.js server-side options
| Need | Recommended approach |
|---|---|
| Unit test a Server Action / Route Handler that calls `fetch` | `setupServer` in Vitest node project - works (plain Node process) |
| Client Components in a running Next app (dev) | `setupWorker` started in a client provider gated by env; await start before rendering children |
| RSC/Server Action fetches in running `next dev/start` | Option A: `instrumentation.ts` `register()` with `setupServer().listen()` when `NEXT_RUNTIME === 'nodejs'` and a test env flag - known limitations (MSW issue #1644 remains open; module patching across Next's processes/bundling). Option B: env-pointed standalone mock server (e.g., MSW `@mswjs/http-middleware` or a tiny Node server). Option C: `next/experimental/testmode/playwright` with `next.onFetch` or its MSW integration (experimental). |

## Recommended Workflow
1. Define handler modules per API domain with typed responses.
2. Wire `setupServer` in test setup with `onUnhandledRequest: 'error'`.
3. Write component tests using default handlers; override for edge states.
4. Reuse handlers in Storybook via `msw-storybook-addon`.
5. Optionally enable the worker in local dev behind an env flag.
6. Periodically validate mock payloads against the real API schema (OpenAPI types or zod parse in handlers).

## Patterns
- **Scenario presets**: `export const scenarios = { empty: [...], error: [...] }` used by tests and stories.
- **Stateful in-memory db**: `@mswjs/data` or a simple Map for CRUD flows in dev/Storybook (reset between tests).
- **Schema-validated mocks**: `ProjectSchema.array().parse(mockData)` inside factories to catch drift at test time.
- **Request assertion via spy**: `const onCreate = vi.fn(); server.use(http.post(url, async ({ request }) => { onCreate(await request.json()); return HttpResponse.json(...) }))`.

## Anti-Patterns
- **`vi.mock('@/lib/api')` everywhere**: tests bypass serialization, headers and error handling. Fix: MSW.
- **`onUnhandledRequest: 'bypass'` in tests**: silently hits real network. Fix: `'error'`.
- **Not resetting handlers**: overrides leak across tests. Fix: `afterEach(server.resetHandlers)`.
- **Shipping the worker in production**: `mockServiceWorker.js` enabled by default in prod builds. Fix: env-gated dynamic import; consider excluding the file from production `public/`.
- **Expecting browser MSW to intercept Server Component fetches**: server requests never pass through the Service Worker. Fix: server-side strategies above.
- **Untyped, hand-copied JSON fixtures that drift**. Fix: typed factories and schema validation.

## Accessibility
Use MSW `delay()` to create loading states and verify loading UI is announced (`aria-busy`, live region messages) and error states expose `role="alert"`. See [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) and [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).

## Responsive Design
Not directly relevant; use the same handlers across viewport-specific stories/tests.

## Performance
- Handlers add negligible overhead; avoid `delay()` without args in unit tests (it adds realistic random latency) - use `delay(0)` or none.
- Use `delay('infinite')` only in stories for persistent loading states.

## Security
- Never put real tokens or production data in handlers.
- Gate browser mocking behind build-time env flags so it cannot be enabled in production by query params.
- If `mockServiceWorker.js` is in `public/`, it is publicly served; it is inert unless registered, but consider excluding it from production artifacts.

## Testing
Test your mocks: a small test that each default handler's response parses against the API schema. Watch MSW warnings for unhandled requests in CI logs.

## Tooling
| Package | Status (2026-09-15) |
|---|---|
| `msw` | 2.15.x |
| `msw-storybook-addon` | Active; MSW 2 |
| `@mswjs/data` | Community-maintained data modeling (Check current docs) |
| `@mswjs/http-middleware` | Standalone mock server from handlers (Check current docs) |
| `@faker-js/faker` | Data generation (seed for determinism) |

## Framework Notes
- **Next.js**: Works well for Vitest/Jest unit and component tests and for Client Component requests in the browser. Server-side interception in a running App Router server is the weak spot (MSW issue #1644 open); use experimental Next test mode or a standalone mock server for E2E.
- **React (Vite SPA)**: Ideal fit - browser worker in dev, Storybook and Playwright E2E (enable worker in a `test` build mode), `setupServer` in Vitest.

## AI Agent Guidance
- Do: add/extend handlers in the shared handlers directory rather than inline fetch mocks.
- Do: use `server.use` for per-test scenarios and keep `onUnhandledRequest: 'error'`.
- Do: type handler responses with app types.
- Don't: claim MSW mocks RSC/Server Action fetches in a running Next server without verifying.
- Don't: enable mocking in production code paths.
- Before done: tests pass with no MSW unhandled request warnings; handlers typed; Storybook stories using handlers still render.

## Examples
```tsx
// components/create-project-form.test.tsx
import { http, HttpResponse } from 'msw'
import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'
import { server } from '@/mocks/node'
import { renderWithProviders } from '@/test/render'
import { CreateProjectForm } from './create-project-form'

test('shows server validation message', async () => {
  server.use(
    http.post('*/api/projects', () => HttpResponse.json({ message: 'Name already taken' }, { status: 409 })),
  )
  const { user } = renderWithProviders(<CreateProjectForm />)
  await user.type(screen.getByLabelText(/name/i), 'Apollo')
  await user.click(screen.getByRole('button', { name: /create/i }))
  expect(await screen.findByRole('alert')).toHaveTextContent('Name already taken')
})
```

## Related Skills
- [component-testing](../component-testing/Skill.md) - consuming handlers in tests
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) - MSW addon
- [testing-server-components-and-actions](../testing-server-components-and-actions/Skill.md) - server-side mocking alternatives
- [test-data-and-fixtures](../test-data-and-fixtures/Skill.md) - factories
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) - API client structure
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) - query testing

## Sources
- [MSW Node.js integration](https://mswjs.io/docs/integrations/node) - Official - setupServer lifecycle, events
- [MSW Browser integration](https://mswjs.io/docs/integrations/browser) - Official - msw init, await worker.start, conditional enabling
- [MSW issue #1644 (Next.js App Router)](https://github.com/mswjs/msw/issues/1644) - Open Source - server-side limitations, open status
- [Next.js experimental test mode README](https://github.com/vercel/next.js/tree/canary/packages/next/src/experimental/testmode/playwright) - Open Source - onFetch and MSW integration
- [npm: msw](https://registry.npmjs.org/msw/latest) - Official - version 2.15.0

## License / Usage Notes
MSW is MIT-licensed. API usage summarized; examples original.

## Quality Tier
A - Core MSW 2 usage is stable and verified; Next.js server-side guidance reflects an open upstream issue and experimental APIs.

## Status
Active

## Last Verified
2026-09-15
