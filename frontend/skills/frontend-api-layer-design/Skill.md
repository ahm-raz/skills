# Frontend API Layer Design

## Summary
Designing the data-access layer between React/Next.js UI and backend services: a single typed HTTP client, contract-first types (OpenAPI codegen or tRPC), runtime validation at trust boundaries (Zod 4 / Standard Schema), error normalization, auth transport, retries/timeouts/cancellation, and where the layer sits in Next.js (server-only modules, Route Handlers, Server Actions, BFF).

## Category
Architecture

## Subcategories
HTTP client, OpenAPI codegen, runtime validation, error mapping, BFF, Server Actions, retries, cancellation, pagination, query key design

## Problem It Solves
Components calling `fetch` directly scatter base URLs, headers, error handling, and ad hoc types; backend changes break the UI silently at runtime; auth tokens leak to the browser. A deliberate API layer gives one place for transport concerns, types generated from the contract, and consistent errors.

## When To Use
- Any app talking to more than a couple of endpoints.
- Integrating an OpenAPI/GraphQL backend or multiple services.
- Migrating a SPA to Next.js with server-side data access.

## When Not To Use
- Full-stack TypeScript apps where tRPC or Server Actions already provide end-to-end types — don't wrap them in another REST-like client.
- Static sites with build-time data only.

## Core Principles
1. **One client, many typed endpoints.** Base URL, headers, auth, timeouts, and error mapping live in one module.
2. **Contract-first types.** Generate from OpenAPI/GraphQL schema; never hand-write response types for external APIs.
3. **Validate at trust boundaries.** Parse untrusted responses and all user input with a schema; trust generated types only for trusted internal backends.
4. **Normalize errors** into a typed `ApiError` shape the UI understands.
5. **UI never knows transport details.** Components call domain functions (`getOrder(id)`) or query hooks, not URLs.
6. **Credentials stay server-side when possible** (BFF / Next.js server).
7. **Every request is cancellable and time-bounded.**

## Best Practices
- Layers: `shared/api/http.ts` (transport) -> `entities/*/api/*.ts` (endpoint functions + query options) -> hooks/Server Components.
- OpenAPI: `openapi-typescript` + `openapi-fetch` (tiny, typed `{ data, error }`), or `@hey-api/openapi-ts` / Orval to generate clients and TanStack Query hooks and Zod schemas.
- Validation: Zod 4 (or Valibot/ArkType via Standard Schema) for responses from third parties, for Server Action inputs, and for URL params.
- Use `AbortSignal` everywhere: TanStack Query passes `signal` to `queryFn`; add `AbortSignal.timeout(ms)` and combine with `AbortSignal.any([...])`.
- Retries only for idempotent requests (GET/PUT with idempotency key) with exponential backoff; never retry 4xx except 408/429 (respect `Retry-After`).
- Map errors: network, timeout, 401 (re-auth), 403 (forbidden UI), 404 (not found UI), 409/422 (field errors), 429, 5xx (retry/fallback).
- Pagination: prefer cursor-based APIs; expose `{ items, nextCursor }` to `useInfiniteQuery`.
- In Next.js, mark server data modules with `import 'server-only'`; use Route Handlers only for external consumers/webhooks — internal UI reads go straight from Server Components to the data source/API.
- Server Actions are public HTTP endpoints: validate input, authenticate, and authorize inside every action.
- Keep query keys hierarchical and generated from one factory per entity.

## Implementation Guidance

### Decision table: API style for React/Next.js
| Situation | Choice |
|---|---|
| External/polyglot backend with OpenAPI | openapi-typescript + openapi-fetch (or hey-api/Orval) |
| TS backend in same monorepo, Vite SPA or Next | tRPC (or oRPC) |
| Next.js app owning its data | Server Components + Server Actions + server-only data modules |
| GraphQL backend | GraphQL Codegen client preset + TanStack Query or urql/Apollo |
| Third-party API with tokens | Call from Next.js server / BFF only |

### Transport with openapi-fetch
```ts
// shared/api/client.ts
import createClient, { type Middleware } from 'openapi-fetch';
import type { paths } from './generated/schema'; // npx openapi-typescript ./openapi.yaml -o src/shared/api/generated/schema.d.ts

const timeout: Middleware = {
  onRequest({ request }) {
    return new Request(request, { signal: AbortSignal.any([request.signal, AbortSignal.timeout(15_000)]) });
  },
};
export const api = createClient<paths>({ baseUrl: '/api/proxy', credentials: 'include' });
api.use(timeout);
```

### Error normalization
```ts
// shared/api/errors.ts
export type ApiError =
  | { kind: 'network' }
  | { kind: 'timeout' }
  | { kind: 'unauthorized' }
  | { kind: 'forbidden' }
  | { kind: 'not-found' }
  | { kind: 'validation'; fields: Record<string, string[]> }
  | { kind: 'rate-limited'; retryAfterSec?: number }
  | { kind: 'server'; status: number; requestId?: string };

export function toApiError(res: Response | undefined, cause?: unknown): ApiError {
  if (!res) return cause instanceof DOMException && cause.name === 'TimeoutError' ? { kind: 'timeout' } : { kind: 'network' };
  switch (res.status) {
    case 401: return { kind: 'unauthorized' };
    case 403: return { kind: 'forbidden' };
    case 404: return { kind: 'not-found' };
    case 422: return { kind: 'validation', fields: {} };
    case 429: return { kind: 'rate-limited', retryAfterSec: Number(res.headers.get('retry-after')) || undefined };
    default: return { kind: 'server', status: res.status, requestId: res.headers.get('x-request-id') ?? undefined };
  }
}
```

### Entity endpoint + query options
```ts
// entities/order/api/orderApi.ts
import { queryOptions } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { toApiError } from '@/shared/api/errors';

export const orderKeys = {
  all: ['orders'] as const,
  list: (f: { status: string }) => [...orderKeys.all, 'list', f] as const,
  detail: (id: string) => [...orderKeys.all, 'detail', id] as const,
};
export const orderDetailQuery = (id: string) => queryOptions({
  queryKey: orderKeys.detail(id),
  queryFn: async ({ signal }) => {
    const { data, error, response } = await api.GET('/orders/{id}', { params: { path: { id } }, signal });
    if (error) throw toApiError(response);
    return data;
  },
});
```

### Validating an untrusted response (Zod 4)
```ts
import { z } from 'zod';
const Rate = z.object({ currency: z.string().length(3), rate: z.number().positive() });
export async function getRate(code: string, signal?: AbortSignal) {
  const res = await fetch(`https://rates.example.com/v1/${encodeURIComponent(code)}`, { signal });
  if (!res.ok) throw toApiError(res);
  return Rate.parse(await res.json());
}
```

### Next.js server-only data module + Server Action
```ts
// entities/order/api/queries.ts
import 'server-only';
import { cookies } from 'next/headers';
export async function getOrders(filter: { status: string; page: number }) {
  const token = (await cookies()).get('session')?.value;
  const res = await fetch(`${process.env.ORDERS_API_URL}/orders?status=${filter.status}&page=${filter.page}`, {
    headers: { authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`orders ${res.status}`);
  return (await res.json()) as OrdersPage;
}
```
```ts
// features/cancel-order/api/actions.ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { requireUser } from '@/entities/session/server';
const Input = z.object({ orderId: z.string().uuid() });
export async function cancelOrder(_: unknown, formData: FormData) {
  const user = await requireUser();                         // authenticate
  const parsed = Input.safeParse({ orderId: formData.get('orderId') });
  if (!parsed.success) return { ok: false, error: 'Invalid order' } as const;
  await assertCanCancel(user, parsed.data.orderId);         // authorize
  await ordersService.cancel(parsed.data.orderId);
  revalidatePath('/orders');
  return { ok: true } as const;
}
```

## Recommended Workflow
1. Obtain/author the API contract (OpenAPI/GraphQL); add codegen script and commit generated types (or generate in CI deterministically).
2. Build the transport module: base URL, auth, timeout, error mapping, request ID propagation.
3. Write entity endpoint functions + query key factories.
4. Expose hooks/queryOptions (SPA) or server-only functions (Next.js).
5. Add schema validation at trust boundaries.
6. Add MSW handlers generated from the contract for tests/storybook.
7. Add contract drift check in CI (regenerate and diff).

## Patterns
- **Gateway module per backend service.**
- **BFF proxy** (`/api/proxy/*` Route Handler) attaching server-held tokens.
- **Query key factory** per entity.
- **Result type for actions** (`{ ok: true, data } | { ok: false, error }`) instead of throwing across the network boundary.
- **Idempotency keys** on POST retries.
- **Request ID propagation** (`x-request-id`/`traceparent`) for observability.

## Anti-Patterns
- **`fetch` in components** with inline URLs — Fix: endpoint functions.
- **Hand-written response types** drifting from backend — Fix: codegen + drift check.
- **`as` casting JSON from third parties** — runtime crashes. Fix: schema parse.
- **Retrying non-idempotent POSTs** — duplicate orders. Fix: idempotency keys or no retry.
- **Exposing API keys via `NEXT_PUBLIC_*` or Vite `VITE_*` env** — they ship in the bundle. Fix: call from server.
- **Next.js Route Handler called from your own Server Component** — extra hop. Fix: call the data function directly.
- **Server Action without auth/validation** — public endpoint abuse. Fix: validate + authorize in each action.
- **Swallowing errors into `null`** — UI can't distinguish empty vs failed. Fix: typed errors.

## Accessibility
- Map API errors to accessible UI: field errors associated with inputs (`aria-describedby`, WCAG 3.3.1 Error Identification), global errors announced via live regions (4.1.3).
- Loading states should be perceivable (`aria-busy` on regions) without trapping focus.

## Responsive Design
- Consider payload size for mobile: request only needed fields (sparse fieldsets/GraphQL selection), paginate, and avoid over-fetching large lists.

## Performance
- Dedupe and cache (TanStack Query / Next.js `fetch` + `'use cache'`); parallelize independent requests (`Promise.all`) in Server Components to avoid waterfalls.
- Prefetch on intent (hover/viewport) for likely navigations.
- Set `staleTime` per entity volatility.

## Security
- Keep tokens server-side (BFF) where possible; use `credentials: 'include'` with SameSite cookies and CSRF protection for cookie-authenticated mutations.
- Validate/encode path and query params (`encodeURIComponent`); avoid SSRF when server code fetches user-supplied URLs (allowlist hosts).
- Don't log full responses containing PII.

## Testing
- MSW handlers (optionally generated from OpenAPI) for unit/component tests and Storybook.
- Contract tests: codegen diff in CI; optionally Pact for consumer-driven contracts.
- Unit test `toApiError` mapping and retry policies.

## Tooling
- openapi-typescript + openapi-fetch — Active.
- @hey-api/openapi-ts — Active (clients, TanStack Query plugin, Zod plugin).
- Orval — Active (clients + hooks + MSW mocks).
- Zod 4 — Active; Valibot, ArkType — Active (Standard Schema compatible).
- tRPC v11 — Active; oRPC — Active (OpenAPI-compatible alternative).
- GraphQL Codegen (client preset) — Active.
- MSW 2 — Active.
- Axios — Active but unnecessary for most modern apps (native fetch + AbortSignal suffices).

## Framework Notes
- **React (Vite SPA):** all calls are public; route through your backend/BFF for secrets. Use TanStack Query `queryOptions` + router loaders for prefetching; configure Vite `server.proxy` for local dev CORS-free calls.
- **Next.js App Router:** server-only modules for reads; Server Actions for mutations from forms; Route Handlers for webhooks, external clients, or a BFF proxy for client-side polling. `fetch` in Server Components is not cached by default in recent versions — opt in with `'use cache'`/revalidate settings as appropriate. Propagate cancellation where supported.

## AI Agent Guidance
- Find the existing client/transport module and endpoint conventions before adding requests.
- Do: regenerate types from the contract after API changes; add schema validation for untrusted data; add error mapping; pass `signal`.
- Don't: inline `fetch` in components, cast JSON with `as`, expose secrets in public env vars, or create Route Handlers merely to call from your own Server Components.
- Verify: typecheck passes against regenerated types, MSW tests cover success + error kinds, Server Actions validate and authorize.

## Examples
```tsx
// SPA component consuming query options with typed error UI
function OrderPage({ id }: { id: string }) {
  const q = useQuery(orderDetailQuery(id));
  if (q.isPending) return <Spinner label="Loading order" />;
  if (q.isError) {
    const e = q.error as ApiError;
    if (e.kind === 'not-found') return <NotFound />;
    return <ErrorState onRetry={() => q.refetch()} />;
  }
  return <OrderView order={q.data} />;
}
```

## Related Skills
- [frontend-state-architecture](../frontend-state-architecture/Skill.md) — who owns fetched data
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — query hooks
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md) — end-to-end typed alternative
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — mutation endpoints
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — BFF/webhooks
- [frontend-error-handling-architecture](../frontend-error-handling-architecture/Skill.md) — error propagation
- [api-mocking-msw](../api-mocking-msw/Skill.md) — test doubles
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — credentials

## Sources
- [openapi-fetch docs](https://openapi-ts.dev/openapi-fetch/) — Open Source — typed client usage
- [openapi-typescript](https://openapi-ts.dev/) — Open Source — codegen
- [TanStack Query: Query Cancellation](https://tanstack.com/query/latest/docs/framework/react/guides/query-cancellation) — Official — signal usage
- [MDN: AbortSignal.timeout / any](https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal) — Official
- [Next.js: Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — server-only, Server Action security
- [Zod 4 docs](https://zod.dev) — Open Source — runtime validation
- [RFC 10017: OAuth 2.0 for Browser-Based Applications](https://www.rfc-editor.org/info/rfc10017/) — Official — BFF recommendation

## License / Usage Notes
Summarized; code original. Libraries MIT.

## Quality Tier
A — official docs for core tools; Next.js caching defaults change between versions and should be rechecked.

## Status
Active

## Last Verified
2026-09-15
