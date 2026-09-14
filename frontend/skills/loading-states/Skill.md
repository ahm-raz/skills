# Loading States

## Summary
How to communicate waiting in React and Next.js interfaces: choosing between no indicator, inline pending states, spinners, skeletons, progress bars and background processing based on expected duration and scope. Covers Next.js `loading.tsx` and Suspense streaming, `useFormStatus`/`useTransition` pending UI, delayed indicators to avoid flicker, and accessible announcements.

## Category
UX

## Subcategories
skeleton screens, spinners, progress indicators, Suspense, streaming, pending states, perceived performance, response time limits

## Problem It Solves
Without feedback users think the app froze, click again (double submits), or leave. With the wrong feedback, apps flicker spinners for 50ms loads, shift layout when content arrives, or block the whole page for a slow widget.

## When To Use
- Any async operation: route navigation, data fetch, form submit, upload, AI generation, export.
- Designing Suspense boundaries and `loading.tsx` placement in Next.js.

## When Not To Use
- Operations reliably < ~100ms: an indicator only adds flicker; use optimistic UI instead.
- Background sync the user didn't initiate: use subtle status, not blocking loaders.

## Core Principles
1. **Match indicator to duration** (NN/g response limits: 0.1s feels instant, 1s keeps flow, 10s loses attention).
2. **Match indicator to scope**: indicate where the change will appear (button, section, page), not globally.
3. **Preserve layout**: placeholders reserve the same space as final content (no CLS).
4. **Show structure early**: stream the shell and fast parts; suspend only slow parts.
5. **Don't flash**: delay spinners ~150-300ms and, once shown, keep them a minimum ~300-500ms.
6. **Keep the previous content visible** during refetch/transition when possible (stale-while-revalidate) rather than blanking.
7. **Long work must be escapable**: cancel, run in background, notify when done.
8. **Announce status to assistive tech** without spamming.

## Best Practices
- Buttons: disable + inline spinner + label change ("Saving...") while the action is pending; keep width stable.
- Skeletons for content-heavy regions (lists, cards, profiles) on initial load when duration ~1-10s; mirror real layout shape, not generic bars.
- Spinner for small, unknown-duration, localized waits (a panel refresh) ~1-3s.
- Determinate progress bar for > ~10s or measurable work (uploads, imports) with percent and/or remaining time.
- For very long jobs (> 1 min): background job + status page + notification/email; let users leave.
- Avoid full-page blocking overlays; they destroy context and hide progress.
- Skeleton animation: subtle shimmer or pulse; disable under `prefers-reduced-motion`.
- Never show a skeleton for an empty result; resolve to empty state as soon as known.
- Pagination/infinite scroll: show inline loader row at list end; keep existing rows.
- Stream AI/text output token-by-token rather than waiting for the full response.

## Implementation Guidance

Decision table:

| Expected wait | Scope | Indicator |
|---|---|---|
| < 100ms | any | None (or optimistic update) |
| 100ms - 1s | control | Pending state on control (disabled + subtle spinner after 150ms delay) |
| 1 - 10s | region/page initial load | Skeleton matching layout |
| 1 - 10s | region refresh | Keep stale content + small spinner / dimmed overlay on region |
| > 10s, measurable | task | Determinate progress bar + cancel |
| > 10s, unmeasurable | task | Indeterminate indicator + step messages ("Analyzing file...") + cancel |
| > 1 min | job | Background job, status row, notify on completion |

Next.js App Router placement:
- `app/<segment>/loading.tsx` wraps that segment's `page.tsx` in Suspense automatically; the layout stays interactive. Put it at the level where the layout (nav, header) should remain visible.
- Use explicit `<Suspense fallback>` around individual slow server components so the rest of the page streams.
- Client transitions (`router.push`, `<Link>`) show `loading.tsx` for new segments; `useLinkStatus` (Next.js 15.3+) can show per-link pending hints.
- Forms: `useFormStatus` inside a submit button component, or `pending` from `useActionState`.

```tsx
// app/(app)/projects/loading.tsx — skeleton mirrors the real list layout
export default function Loading() {
  return (
    <div aria-busy="true" aria-live="polite">
      <span className="sr-only">Loading projects</span>
      <div className="h-8 w-48 rounded bg-neutral-200 motion-safe:animate-pulse" />
      <ul className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <li key={i} className="h-28 rounded-lg border border-neutral-200 p-4">
            <div className="h-4 w-2/3 rounded bg-neutral-200 motion-safe:animate-pulse" />
            <div className="mt-3 h-3 w-1/3 rounded bg-neutral-100 motion-safe:animate-pulse" />
          </li>
        ))}
      </ul>
    </div>
  );
}
```

```tsx
// app/(app)/dashboard/page.tsx — stream slow widgets independently
import { Suspense } from "react";
export default function Dashboard() {
  return (
    <>
      <h1>Dashboard</h1>
      <Suspense fallback={<KpiRowSkeleton />}><KpiRow /></Suspense>
      <Suspense fallback={<ChartSkeleton />}><RevenueChart /></Suspense>
    </>
  );
}
```

```tsx
// Submit button with pending state
"use client";
import { useFormStatus } from "react-dom";
export function SubmitButton({ children, pendingLabel }: { children: React.ReactNode; pendingLabel: string }) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending} aria-disabled={pending} className="inline-flex min-w-28 items-center justify-center gap-2">
      {pending && <Spinner aria-hidden />}
      {pending ? pendingLabel : children}
    </button>
  );
}
```

```tsx
// Delay indicator to prevent flicker on fast responses
"use client";
import { useEffect, useState } from "react";
export function useDelayedFlag(active: boolean, delay = 200) {
  const [show, setShow] = useState(false);
  useEffect(() => {
    if (!active) { setShow(false); return; }
    const t = setTimeout(() => setShow(true), delay);
    return () => clearTimeout(t);
  }, [active, delay]);
  return show;
}
```

## Recommended Workflow
1. List async operations per screen with realistic p50/p95 durations (measure, don't guess).
2. Pick indicator per operation via the decision table.
3. Decide Suspense boundaries: shell first, each independent slow region separately; avoid waterfalls.
4. Build skeletons from the real component layout (same dimensions).
5. Add pending states to all submit buttons and mutations.
6. Test with network throttling (Slow 4G) and artificial server delays.
7. Verify screen reader announcements and reduced-motion behavior.

## Patterns
- **Skeleton-from-component**: a `variant="skeleton"` on cards/rows ensures identical dimensions.
- **Stale-while-revalidate**: keep old list, show "Updating..." in header (TanStack Query `isFetching` vs `isPending`; `useTransition` `isPending` for filters).
- **Progressive messages**: after 3s "Still working...", after 10s explain and offer cancel.
- **Background job row**: "Export in progress (42%)" in a jobs panel + toast when complete with link.
- **Streaming text**: render partial content with a caret; Stop button replaces Send.

## Anti-Patterns
- **Global page spinner for local change** — loses context. Fix: scope indicator to the region/control.
- **Spinner flashing on 80ms loads** — perceived jank. Fix: delay + minimum display.
- **Generic skeleton that doesn't match content** — layout jumps. Fix: component-shaped skeletons.
- **Skeletons forever on error** — Fix: timeouts and error boundaries converting to error state.
- **One Suspense boundary around the whole page** — slowest query blocks everything. Fix: granular boundaries.
- **Too many tiny boundaries** — popcorn effect of pieces appearing randomly. Fix: group related content into one boundary; reveal top-to-bottom.
- **Enabled submit while pending** — duplicates. Fix: disable + idempotency.
- **Animated indicator ignoring reduced motion** — Fix: `motion-safe:` utilities.

## Accessibility
- Status messages (4.1.3): announce loading start/finish in a polite live region; don't announce every tick of progress (throttle to ~10-25% steps).
- Use `aria-busy="true"` on the updating region; `role="progressbar"` with `aria-valuenow/min/max` for determinate progress (or native `<progress>`).
- Don't move focus into skeletons; after load completes on navigation, focus the page heading.
- Pause, stop, hide (2.2.2) for animations lasting > 5s: shimmer should respect reduced motion.
- `aria-disabled` keeps pending buttons focusable when you need to explain why.

## Responsive Design
- Skeleton counts adapt to viewport (fewer cards on mobile).
- On mobile networks, expect longer waits: favor streaming shells and cached content.

## Performance
- Streaming SSR (Next.js) improves TTFB/FCP; keep `loading.tsx` lightweight (no client JS).
- Reserve dimensions to protect CLS; skeleton == final size.
- Prefetch on hover/viewport (Next.js `<Link>` prefetch) to eliminate loaders on navigation.
- Don't let loading indicators be the LCP element for long; stream the LCP content early.

## Security
- Don't expose internal job IDs or stack traces in long-running status messages.
- Cancel buttons must actually abort server work or clearly say the job continues.

## Testing
- Playwright: route interception with delay (`page.route` + `await new Promise(r => setTimeout(r, 2000))`) to assert skeleton/pending UI, then final content.
- Unit test `useDelayedFlag` with fake timers.
- Lighthouse/Web Vitals for CLS during load; screen reader check of announcements.

## Tooling
- Next.js `loading.tsx`, React `Suspense`, `useFormStatus`, `useActionState`, `useTransition`; TanStack Query (`isPending`/`isFetching`); shadcn/ui `Skeleton`; `nprogress`-style top bars (use sparingly).

## Framework Notes
- **Next.js (App Router)**: `loading.tsx` per segment; `<Suspense>` for streaming server components; `useLinkStatus` for link pending; route-level prefetching reduces loaders.
- **React (Vite SPA)**: no streaming SSR; use `React.lazy` + Suspense for code, TanStack Query/`use()` with Suspense for data, `useTransition` to keep old UI during navigation; router `pending` states (React Router `useNavigation`).

## AI Agent Guidance
- Do: add pending state to every mutation button; create `loading.tsx` or Suspense fallbacks shaped like the content; handle error and empty outcomes of each load.
- Don't: wrap the entire app in one spinner; don't add skeletons for sub-100ms UI; don't forget `motion-safe`.
- Verify: throttle network and record screen; no layout shift when content appears; double-click on submit sends one request.

## Examples
```tsx
// Determinate upload progress with accessible announcements
"use client";
export function UploadProgress({ name, percent }: { name: string; percent: number }) {
  const announced = Math.floor(percent / 25) * 25;
  return (
    <div>
      <label htmlFor="up" className="text-sm">{name}</label>
      <progress id="up" max={100} value={percent} className="w-full" />
      <p className="sr-only" aria-live="polite">{announced}% uploaded</p>
    </div>
  );
}
```

## Related Skills
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — Next.js streaming mechanics
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md) — boundary design
- [optimistic-ui](../optimistic-ui/Skill.md) — avoiding loaders for fast mutations
- [empty-states](../empty-states/Skill.md) — what loading resolves to when there's no data
- [error-states](../error-states/Skill.md) — what loading resolves to on failure
- [cls-prevention](../cls-prevention/Skill.md) — layout stability
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — announcing status
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — animation safety

## Sources
- [NN/g: Skeleton Screens 101](https://www.nngroup.com/articles/skeleton-screens/) — Community (research) — when skeletons fit (full-page loads under 10s)
- [NN/g: Progress Indicators Make a Slow System Less Insufferable](https://www.nngroup.com/articles/progress-indicators/) — Community — duration thresholds
- [NN/g: Response Time Limits](https://www.nngroup.com/articles/response-times-3-important-limits/) — Community — 0.1s / 1s / 10s
- [Next.js docs: loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading) — Official — segment Suspense behavior
- [React docs: useFormStatus, Suspense](https://react.dev/reference/react-dom/hooks/useFormStatus) — Official — pending APIs
- [IBM Carbon: Loading pattern](https://carbondesignsystem.com/patterns/loading-pattern/) — Official (design system) — skeleton vs loader usage
- [Laws of UX: Doherty Threshold](https://lawsofux.com/doherty-threshold/) — Community — 400ms

## License / Usage Notes
Guidance summarized; code original. React/Next.js docs are CC BY 4.0 / MIT respectively.

## Quality Tier
S — research-backed thresholds plus official framework APIs with verified current behavior.

## Status
Active

## Last Verified
2026-09-15
