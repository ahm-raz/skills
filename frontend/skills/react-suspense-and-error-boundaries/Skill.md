# React Suspense and Error Boundaries

## Summary
`<Suspense>` declaratively shows a fallback while children wait on code (`lazy`), data (`use(promise)`, `useSuspenseQuery`, async Server Components) or browser-only rendering (`use(browser())`, React 19.3). Error boundaries catch render-time errors and show recovery UI. Together they define an app's loading and failure "reveal units". This skill covers boundary placement, transitions that avoid fallback flashes, resets, root error callbacks, and Next.js `loading.tsx`/`error.tsx`/`global-error.tsx`/`not-found.tsx`.

## Category
React

## Subcategories
Suspense boundaries, lazy loading, use(), streaming SSR, error boundaries, react-error-boundary, reset keys, root error handlers, Next.js loading/error files, ViewTransition + Suspense

## Problem It Solves
- Scattered `isLoading ? <Spinner/> : ...` checks.
- Layout pop-in and spinner soup.
- White screens when a single component throws.
- Error UIs that can't be retried.
- Slow SSR pages that block on the slowest query.

## When To Use
- Any async UI: route segments, dashboard widgets, lazy components, streamed server data.
- Isolating failures so one broken widget doesn't take down the page.
- Coordinating reveal order in Next.js streaming.

## When Not To Use
- Data fetched in `useEffect`: Suspense can't see it. Use a Suspense-enabled source instead.
- Expected validation or business errors (form errors, 404 lookups). Model them as return values or state, not thrown exceptions. Use `notFound()` for 404s in Next.js.
- Event handler and async callback errors: boundaries don't catch these. Handle locally, or forward with `showBoundary`.

## Core Principles
1. **Suspense only works with Suspense-enabled sources**: `lazy`, `use(promise)` with a cached promise, `useSuspenseQuery`, async Server Components, framework loaders.
2. **Place boundaries by design, not by component**: each boundary is a unit that appears together. Too few means a slow page; too many means popcorn UI.
3. **Transitions keep existing content visible.** Updates inside `startTransition` don't replace already-shown content with a fallback. Only new, never-shown boundaries show fallbacks.
4. **Error boundaries catch errors in rendering, lifecycle and effects of descendants**, not in event handlers, async code outside render, SSR-only errors (these are handled by the framework), or inside the boundary itself.
5. **Every error UI needs a recovery path**: retry/reset, navigation, or support info.
6. **Pair each important Suspense boundary with an error boundary** at the same granularity.

## Best Practices
- Fallbacks should match the final layout size (skeletons) to avoid CLS.
- Use `key` on a boundary (or a `resetKeys` prop) to reset it when the input entity changes. Otherwise the old error stays.
- Don't show a fallback for fast loads: rely on transitions, and consider the minimum display time React applies to avoid flicker.
- Use `react-error-boundary` (`ErrorBoundary`, `useErrorBoundary().showBoundary`) rather than writing class components by hand. Error boundaries still require a class under the hood, and there's no hook API in React 19.x.
- Report errors in `createRoot(el, { onCaughtError, onUncaughtError, onRecoverableError })` (React 19) or the boundary's `onError`, and send them to observability.
- With TanStack Query Suspense mode, wrap in `QueryErrorResetBoundary` so retries refetch.
- Combine with `<ViewTransition>` (React 19.3) to animate fallback → content reveals.

## Implementation Guidance
**Boundary placement guide**

| Area | Suspense | Error boundary |
|---|---|---|
| App root | Rarely (only for lazy shell) | Yes, last resort, full-page recovery |
| Route segment | Yes (`loading.tsx`) | Yes (`error.tsx`) |
| Independent widgets (dashboard cards, recommendations) | Yes, one per widget or group | Yes, per widget, so others keep working |
| Inline small pieces (avatar, count) | Group with parent | Usually no |
| Lazy modal/editor | Yes, near trigger | Yes |

**Error boundary with reset**
```tsx
"use client";
import { ErrorBoundary, type FallbackProps } from "react-error-boundary";

function WidgetError({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div role="alert">
      <p>Couldn't load revenue.</p>
      <button onClick={resetErrorBoundary}>Try again</button>
    </div>
  );
}

export function RevenueWidget({ accountId }: { accountId: string }) {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary FallbackComponent={WidgetError} onReset={reset} resetKeys={[accountId]}
          onError={(e, info) => reportError(e, info.componentStack)}>
          <Suspense fallback={<CardSkeleton />}>
            <RevenueChart accountId={accountId} />
          </Suspense>
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  );
}
```

**Forwarding async errors to a boundary**
```tsx
const { showBoundary } = useErrorBoundary();
async function onExport() {
  try { await exportCsv(); } catch (e) { showBoundary(e); }
}
```

**Avoid fallback flash on navigation/filter change**
```tsx
const [isPending, startTransition] = useTransition();
<select onChange={(e) => startTransition(() => setRange(e.target.value))} />
<div aria-busy={isPending} style={{ opacity: isPending ? 0.7 : 1 }}>
  <Suspense fallback={<ChartSkeleton />}><Chart range={range} /></Suspense>
</div>
```

## Recommended Workflow
1. Sketch the page's loading storyboard: what appears first (shell, LCP), what can stream later.
2. Put Suspense boundaries at those reveal units, and matching error boundaries.
3. Make data sources Suspense-compatible (RSC async, `useSuspenseQuery`, cached promises).
4. Wrap user-triggered updates that re-suspend in transitions.
5. Design fallbacks (skeletons with fixed dimensions) and error UIs (message + retry).
6. Wire error reporting (root options + boundary `onError`).
7. Test slow and failing responses (MSW delay/500) and verify recovery.

## Patterns
- **Nested reveal**: `<Suspense fallback={<PageSkeleton/>}> <Header/> <Suspense fallback={<FeedSkeleton/>}><Feed/></Suspense> </Suspense>`.
- **Lazy component with preload**: `const Editor = lazy(() => import("./Editor"));`, and call `import("./Editor")` on hover to warm it.
- **Promise-as-prop streaming** (RSC → client `use()`).
- **Reset by key**: `<ErrorBoundary key={pathname}>` resets on navigation.
- **Client-only island**: `use(browser())` inside `<Suspense>` for components that must not render on the server (React 19.3).

## Anti-Patterns
- **One Suspense at the root**: the whole page waits on the slowest request. Fix: segment-level boundaries.
- **Suspense around every tiny component**: popcorn layout shifts. Fix: group into reveal units.
- **Creating promises in render for `use()`**: infinite re-suspend. Fix: cache or create upstream (RSC/loader/query cache).
- **Throwing for expected errors** (validation): error screens for user mistakes. Fix: return an error state.
- **Error boundary without reset**: dead end. Fix: `resetErrorBoundary` + `resetKeys`.
- **Catching `redirect()`/`notFound()` in Next.js try/catch**: breaks navigation. Fix: rethrow (`unstable_rethrow`), or keep them outside try.
- **Spinner fallback with no dimensions**: CLS. Fix: skeleton sized like the content.

## Accessibility
- Fallbacks: indicate loading to assistive tech (`aria-busy="true"` on the container, or visually hidden "Loading revenue…" text). Don't announce every skeleton.
- Error fallbacks use `role="alert"` (or a heading plus focusable retry button). Move focus to the error message only when the error replaces the user's current focus target.
- After a reveal, don't steal focus. For route-level loads, follow accessible SPA routing focus rules.
- Respect reduced motion for skeleton shimmer and ViewTransition reveals.

## Responsive Design
- Skeletons must mirror responsive layouts (grid columns per breakpoint via CSS) so there's no shift at any width.
- On small screens, prefer fewer, larger reveal units (less vertical jumping).

## Performance
- Streaming SSR with Suspense improves TTFB and FCP. Keep LCP content outside slow boundaries.
- React 19.2 batches server-streamed Suspense reveals briefly for smoother paints.
- `lazy` + Suspense splits heavy code. Preload on intent to avoid a waterfall at click time.

## Security
- Production error messages from Server Components are redacted (only `digest`). Don't render raw `error.message` from server errors to users in Client Components. Log the digest instead.
- Don't include stack traces or internal ids in user-facing fallbacks.

## Testing
- MSW handlers with `delay()` to assert fallbacks, and `HttpResponse.error()`/500 to assert error UI and retry.
- Testing Library: `await screen.findByRole("alert")`, click retry, `await findByText(...)`.
- Suppress expected console errors in error-boundary tests (spy on `console.error`).
- Playwright: throttle the network and assert streaming order and no layout shift.

## Tooling
- `react-error-boundary` (maintained; standard hook-friendly wrapper).
- React DevTools: toggle Suspense fallbacks and trigger error states on a selected component.
- TanStack Query `QueryErrorResetBoundary`, `useSuspenseQuery`.
- Next.js file conventions (`loading.tsx`, `error.tsx`, `global-error.tsx`, `not-found.tsx`).

## Framework Notes
### React (Vite SPA)
- Code splitting with `lazy()` + Suspense per route. Data Suspense via `useSuspenseQuery`.
- Put one top-level `ErrorBoundary` around the router plus per-route boundaries. Report through `createRoot` error options.
- No streaming: fallbacks show during client fetching only.

### Next.js App Router
- `loading.tsx` wraps `page.tsx` (and children segments) in a Suspense boundary automatically. The layout stays interactive.
- `error.tsx` **must be a Client Component** (`"use client"`), receives `{ error, reset }`, and wraps the segment below its own `layout.tsx`. To catch layout errors, place `error.tsx` in the parent segment. `global-error.tsx` catches root layout errors and must render `<html>` and `<body>`.
- `notFound()` renders the nearest `not-found.tsx`. `redirect()` throws a special error. Neither should be swallowed by try/catch.
- `error.digest` correlates the redacted client error with server logs.
- Inside a page, add granular `<Suspense>` around slow async Server Components to stream them independently of `loading.tsx`.
- `useSearchParams()` in statically rendered routes requires a Suspense boundary above it.
- Hydration errors are "recoverable": React re-renders on the client and reports through `onRecoverableError`, so still fix them.

```tsx
// app/dashboard/error.tsx
"use client";
export default function DashboardError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div role="alert">
      <h2>Dashboard failed to load</h2>
      <p>Reference: {error.digest}</p>
      <button onClick={() => reset()}>Try again</button>
    </div>
  );
}
```

## AI Agent Guidance
- For each new async section, add a Suspense boundary and an error boundary at the same granularity, with a sized skeleton and a retry.
- Never throw for expected user errors, and never catch Next.js `redirect`/`notFound`.
- Make sure `error.tsx` has `"use client"`.
- Verify: slow network shows skeletons without CLS, forced 500 shows error UI with a working retry, other widgets are unaffected, errors are reported.

## Examples
```tsx
// app/dashboard/page.tsx (Server Component): independent streaming widgets
import { Suspense } from "react";
export default function Dashboard() {
  return (
    <main className="grid">
      <KpiRow />                                            {/* fast, in shell */}
      <WidgetBoundary title="Revenue"><Suspense fallback={<CardSkeleton />}><Revenue /></Suspense></WidgetBoundary>
      <WidgetBoundary title="Signups"><Suspense fallback={<CardSkeleton />}><Signups /></Suspense></WidgetBoundary>
    </main>
  );
}
// WidgetBoundary is a "use client" wrapper around react-error-boundary
```

## Related Skills
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md): Next.js streaming specifics
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md): useSuspenseQuery
- [frontend-error-handling-architecture](../frontend-error-handling-architecture/Skill.md): app-wide error strategy
- [loading-states](../loading-states/Skill.md): loading UX
- [error-states](../error-states/Skill.md): error UX and copy
- [cls-prevention](../cls-prevention/Skill.md): skeleton sizing
- [frontend-observability](../frontend-observability/Skill.md): error reporting

## Sources
- [react.dev: Suspense reference](https://react.dev/reference/react/Suspense) (Official): boundaries, transitions, reset with key
- [react.dev: Component (error boundaries) / createRoot options](https://react.dev/reference/react/Component#catching-rendering-errors-with-an-error-boundary) (Official): boundary semantics, onCaughtError/onUncaughtError
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): browser(), ViewTransition + Suspense
- [Next.js docs: Error Handling & loading.js](https://nextjs.org/docs/app/getting-started/error-handling) (Official): error.tsx, global-error, digest
- [react-error-boundary README](https://github.com/bvaughn/react-error-boundary) (Open Source): API, resetKeys, showBoundary
- [TanStack Query: Suspense guide](https://tanstack.com/query/latest/docs/framework/react/guides/suspense) (Official): QueryErrorResetBoundary

## License / Usage Notes
React docs are CC-BY-4.0/MIT. react-error-boundary is MIT. Next.js docs are MIT. This is a summary with original code.

## Quality Tier
A: official sources across React, Next.js and TanStack; Next.js error file props may evolve across 16.x minors.

## Status
Active

## Last Verified
2026-09-15
