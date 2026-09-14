# Frontend Error Handling Architecture

## Summary
An end-to-end strategy for errors in React and Next.js apps: classifying errors (expected vs unexpected), where each is caught (inline, error boundaries, route segments, global handlers, server hooks), how they are shown to users, reported to monitoring, and recovered from. Aligns with OWASP Top 10:2025 A10 "Mishandling of Exceptional Conditions" (new in 2025): fail safely, never fail open, don't leak internals.

## Category
Architecture

## Subcategories
Error boundaries, Next.js error.tsx/global-error.tsx, expected errors as values, Server Action errors, global handlers, React root error callbacks, error reporting, retry/recovery, fail-closed

## Problem It Solves
Without an architecture, errors either crash whole screens (white screen), get swallowed (silent data loss), leak stack traces or SQL to users, or fail open (showing data the user shouldn't see after an auth check throws). A layered model makes every failure visible to monitoring, recoverable for users, and safe.

## When To Use
- Setting up a new React/Next.js app shell.
- After incidents involving white screens, silent failures, or leaked error details.
- Adding monitoring (Sentry, OpenTelemetry) or hardening security.

## When Not To Use
- Designing the visual error-state UX (see error-states) — this skill defines plumbing and policy.

## Core Principles
1. **Expected errors are values; unexpected errors are exceptions.** Validation failures, 404s, permission denials are modeled and returned; bugs and outages throw to boundaries.
2. **Catch at the lowest level that can recover meaningfully**, and nowhere else.
3. **Every unexpected error reaches monitoring exactly once** with context (route, release, user ID hash, request/trace ID).
4. **Fail closed.** If an authorization or validation step errors, deny — never continue with defaults.
5. **Users see safe, actionable messages;** developers see details in telemetry. Never render `error.message` from the server to users.
6. **Contain blast radius.** Boundaries around independent widgets so one failure doesn't take down the page.
7. **Recovery is designed:** retry, reset boundary, navigate away, or preserve user input.

## Best Practices
- Error taxonomy (shared type): `ValidationError`, `NotFoundError`, `ForbiddenError`, `UnauthorizedError`, `ConflictError`, `RateLimitedError`, `NetworkError`, `UnexpectedError`.
- Server Actions return `{ ok: false, error }` for expected errors (render via `useActionState`); throw only for unexpected ones.
- Next.js route segments: `error.tsx` (must be a Client Component) per meaningful segment; `global-error.tsx` for root layout failures (must render its own `<html>`/`<body>`); `not-found.tsx` + `notFound()` for missing resources.
- In production Next.js, server-thrown error messages are replaced with a generic message plus `digest`; correlate `digest` with server logs from `onRequestError`.
- Don't catch Next.js control-flow errors: `redirect()`, `notFound()`, `forbidden()`/`unauthorized()` throw special errors; if you wrap code in `try/catch`, call `unstable_rethrow(err)` first in the catch block.
- React 19 root callbacks: `createRoot(el, { onUncaughtError, onCaughtError, onRecoverableError })` for SPA reporting.
- Use `react-error-boundary` for granular client boundaries with `resetKeys` and `onError` reporting.
- TanStack Query: `throwOnError` for boundary-worthy failures; inline handling for expected ones; `QueryErrorResetBoundary` to reset.
- Global browser handlers (`error`, `unhandledrejection`) as a last resort — installed once in `instrumentation-client.ts` (Next.js) or `main.tsx` (Vite), usually via the monitoring SDK.
- Use `Error` `cause` to wrap lower-level errors: `new UnexpectedError('Load orders failed', { cause: err })`.
- Preserve user input on failure (don't reset forms on submit error).
- Offline/network errors: detect `TypeError` from fetch / `navigator.onLine` hints; offer retry.

## Implementation Guidance

### Layered catch map
| Layer | Catches | Mechanism (React/Next.js) | User sees |
|---|---|---|---|
| Inline | Expected errors (validation, 404 data, conflicts) | Result types, `useActionState`, query `error` | Field/inline message |
| Widget boundary | Unexpected errors in an independent widget | `<ErrorBoundary>` (react-error-boundary) | Widget fallback + retry |
| Route segment | Unexpected errors in a page/segment | Next `error.tsx`; React Router `errorElement` | Segment fallback, layout stays |
| Root | Root layout / app-shell failures | Next `global-error.tsx`; React root callbacks | Full-page fallback |
| Server | Render, Route Handler, Server Action, proxy errors | `instrumentation.ts` `onRequestError` | Digest-correlated |
| Global browser | Uncaught async errors | SDK global handlers | Nothing / toast if user-impacting |

### Shared error types
```ts
// shared/lib/errors.ts
export class AppError extends Error {
  constructor(message: string, readonly code: string, options?: ErrorOptions & { safeMessage?: string }) {
    super(message, options);
    this.name = new.target.name;
    this.safeMessage = options?.safeMessage ?? 'Something went wrong. Please try again.';
  }
  readonly safeMessage: string;
}
export class ForbiddenError extends AppError { constructor(msg = 'Forbidden') { super(msg, 'FORBIDDEN', { safeMessage: "You don't have access to this." }); } }
export type Result<T, E = { code: string; message: string; fields?: Record<string, string[]> }> =
  | { ok: true; data: T } | { ok: false; error: E };
```

### Next.js segment error boundary
```tsx
// app/dashboard/error.tsx
'use client';
import { useEffect } from 'react';
export default function DashboardError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => { /* client-side report if SDK doesn't auto-capture */ }, [error]);
  return (
    <div role="alert">
      <h2>We couldn't load your dashboard.</h2>
      <p>Reference: {error.digest ?? 'n/a'}</p>
      <button type="button" onClick={() => reset()}>Try again</button>
    </div>
  );
}
```
(Check the current `error.tsx` prop names in your Next.js version — newer releases have been evolving the retry API.)

### Global error (root layout failures)
```tsx
// app/global-error.tsx
'use client';
export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <html lang="en"><body>
      <main role="alert"><h1>Something went wrong</h1><button onClick={() => reset()}>Reload</button></main>
    </body></html>
  );
}
```

### Server-side reporting hook
```ts
// instrumentation.ts
import type { Instrumentation } from 'next';
export const onRequestError: Instrumentation.onRequestError = async (err, request, context) => {
  const e = err instanceof Error ? err : new Error(String(err));
  const digest = typeof err === 'object' && err && 'digest' in err ? String((err as { digest: unknown }).digest) : undefined;
  await reportServerError({ message: e.message, stack: e.stack, digest, path: request.path, method: request.method,
    routePath: context.routePath, routeType: context.routeType }); // routeType: render | route | action | proxy
};
```

### Don't swallow Next.js control flow
```ts
import { unstable_rethrow, notFound } from 'next/navigation';
export async function loadOrder(id: string) {
  try {
    const order = await db.order.find(id);
    if (!order) notFound();
    return order;
  } catch (err) {
    unstable_rethrow(err);                 // lets notFound/redirect propagate
    throw new AppError('Order load failed', 'ORDER_LOAD', { cause: err });
  }
}
```

### Fail closed
```ts
export async function canViewInvoice(user: User, invoiceId: string): Promise<boolean> {
  try {
    return await policy.check(user, 'invoice:read', invoiceId);
  } catch (err) {
    report(err);
    return false; // deny on error — never default to true
  }
}
```

### Vite SPA root
```tsx
// main.tsx
createRoot(document.getElementById('root')!, {
  onUncaughtError: (error, info) => monitor.capture(error, { componentStack: info.componentStack, handled: false }),
  onCaughtError: (error, info) => monitor.capture(error, { componentStack: info.componentStack, handled: true }),
  onRecoverableError: (error) => monitor.capture(error, { level: 'warning' }),
}).render(<App />);
```

## Recommended Workflow
1. Define the error taxonomy and `Result` type; document which are expected.
2. Convert expected failures in Server Actions/APIs to returned results.
3. Add `error.tsx` at root dashboard/marketing segments and `global-error.tsx`; add `not-found.tsx`.
4. Wrap independent widgets with boundaries.
5. Wire monitoring: `onRequestError`, client SDK, React root callbacks (SPA).
6. Audit `try/catch` blocks: rethrow control flow, fail closed, no empty catches (lint `no-empty`, `@typescript-eslint/no-floating-promises`).
7. Chaos-test: force failures in each layer and verify UX + telemetry.

## Patterns
- **Result-returning Server Actions** with `useActionState`.
- **Boundary per independent widget** with `resetKeys` tied to input params.
- **Digest correlation** between user-visible reference and server logs.
- **Retry with backoff for transient errors**, surfaced via "Try again".
- **Error mapping at the API layer** (HTTP -> typed error) so UI never parses status codes.
- **Graceful degradation:** optional widgets render nothing (plus telemetry) instead of breaking the page.

## Anti-Patterns
- **Empty catch / `catch { return null }`** — silent failure. Fix: return typed error or rethrow; report.
- **Showing `error.message` from server to users** — information disclosure. Fix: safe messages + digest.
- **One root boundary only** — whole app blank on a widget error. Fix: segment + widget boundaries.
- **Catching `redirect()`/`notFound()`** in try/catch — breaks navigation. Fix: `unstable_rethrow`.
- **Failing open** on authorization errors — Fix: deny by default.
- **Throwing for validation errors in Server Actions** — generic error UI, lost field info. Fix: return field errors.
- **Double reporting** (SDK auto-capture + manual capture in every boundary) — noisy alerts. Fix: decide one capture point per layer.
- **Unhandled promise from event handlers** — Fix: `no-floating-promises` lint; handle or report.

## Accessibility
- Fallbacks use `role="alert"` (or move focus to the error heading) so screen reader users learn of failures (WCAG 4.1.3).
- Form errors identified in text and associated with fields (WCAG 3.3.1, 3.3.3 Error Suggestion).
- Retry buttons are real `<button>` elements reachable by keyboard; after reset, move focus to restored content.

## Responsive Design
- Fallback UIs must fit the container of the widget they replace (don't render a full-page error inside a card).

## Performance
- Boundaries are cheap; reporting should be async/batched and sampled for high-volume errors.
- Avoid retry storms: cap retries and use jitter; TanStack Query default retries (3) may be too aggressive for 4xx — disable for non-transient errors.

## Security
- OWASP A10:2025 Mishandling of Exceptional Conditions: fail closed, handle all error paths, avoid leaking stack traces/config.
- Scrub PII and secrets from error payloads before reporting (`beforeSend`).
- Don't expose source maps publicly; upload to monitoring instead.

## Testing
- Unit: error mapping and fail-closed policies.
- Component: boundaries render fallback and reset (throw from a child in tests).
- E2E (Playwright): route interception to return 500/timeout; assert fallback, retry, and preserved input.
- Verify `onRequestError` receives errors for render, action, and route handler in an integration test.

## Tooling
- react-error-boundary — Active.
- Sentry JavaScript SDK v10 (`@sentry/nextjs`, `@sentry/react`) — Active (v10.7x Sept 2026).
- Next.js `instrumentation.ts` `onRequestError` (stable since 15) — Active.
- OpenTelemetry — Active server; browser SDK Experimental.
- typescript-eslint `no-floating-promises`, `only-throw-error` — Active.

## Framework Notes
- **React (Vite SPA):** React Router / TanStack Router route `errorElement`/`errorComponent` for route-level; react-error-boundary for widgets; root callbacks for reporting; no server digest — attach a client-generated error ID.
- **Next.js App Router:** `error.tsx` does not catch errors in the same segment's `layout.tsx` (it's rendered inside the layout) — place boundaries in the parent segment or use `global-error.tsx`. Server Component errors arrive at the client boundary with a `digest` only. Server Actions: expected errors returned; unexpected thrown errors hit the nearest `error.tsx`. Use `forbidden()`/`unauthorized()` with `forbidden.tsx`/`unauthorized.tsx` where enabled (check whether `authInterrupts` is still experimental in your version).

## AI Agent Guidance
- Classify each failure as expected (return a value) or unexpected (throw) before writing handling.
- Do: add `error.tsx` for new route segments with data fetching; call `unstable_rethrow` in catch blocks around Next.js navigation helpers; return field errors from actions; deny on authorization errors.
- Don't: write empty catches, render raw server error messages, or add manual reporting where the SDK already captures.
- Verify: force an error in the new code path and confirm fallback UI, focus/announcement, and a single telemetry event with route context.

## Examples
```tsx
// Widget-level boundary with reset on param change
import { ErrorBoundary } from 'react-error-boundary';
<ErrorBoundary
  resetKeys={[accountId]}
  onError={(error, info) => monitor.capture(error, { componentStack: info.componentStack, widget: 'revenue-chart' })}
  fallbackRender={({ resetErrorBoundary }) => (
    <div role="alert">Chart unavailable. <button onClick={resetErrorBoundary}>Retry</button></div>
  )}>
  <RevenueChart accountId={accountId} />
</ErrorBoundary>
```
```tsx
// Server Action expected error handling
'use client';
import { useActionState } from 'react';
export function RenameForm({ action }: { action: (s: State, fd: FormData) => Promise<State> }) {
  const [state, formAction, pending] = useActionState(action, { ok: true } as State);
  return (
    <form action={formAction}>
      <label htmlFor="name">Name</label>
      <input id="name" name="name" aria-invalid={!state.ok || undefined} aria-describedby="name-err" />
      {!state.ok && <p id="name-err">{state.error.message}</p>}
      <button disabled={pending}>Save</button>
    </form>
  );
}
```

## Related Skills
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md) — boundary mechanics
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — special files
- [frontend-observability](../frontend-observability/Skill.md) — reporting pipeline
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — error normalization
- [error-states](../error-states/Skill.md) — UX of error messages
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action result patterns
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — fail-closed, disclosure

## Sources
- [Next.js: instrumentation.js (onRequestError)](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation) — Official — server error hook signature
- [Next.js: Error handling](https://nextjs.org/docs/app/getting-started/error-handling) — Official — error.tsx, global-error, expected errors
- [React: createRoot options](https://react.dev/reference/react-dom/client/createRoot) — Official — onCaughtError/onUncaughtError
- [OWASP Top 10:2025](https://top10.owasp.org/2025) — Official — A10 Mishandling of Exceptional Conditions
- [react-error-boundary](https://github.com/bvaughn/react-error-boundary) — Open Source
- [Sentry: Migrate from 9.x to 10.x](https://docs.sentry.io/platforms/javascript/migration/v9-to-v10/) — Official — current SDK major

## License / Usage Notes
Summarized; code original. react-error-boundary MIT; Sentry SDK MIT.

## Quality Tier
A — grounded in official Next.js/React/OWASP docs; some Next.js APIs (`unstable_rethrow`, `authInterrupts`, error.tsx retry props) are evolving and flagged.

## Status
Active

## Last Verified
2026-09-15
