# Next.js Advanced Routing (Parallel & Intercepting Routes)

## Summary
Parallel routes (`@slot` folders) render multiple independently navigable pages inside one layout; intercepting routes (`(.)`, `(..)`, `(..)(..)`, `(...)`) render another route inside the current layout while masking the URL. Together they enable deep-linkable modals, dashboards with independent panes, tab groups, and role-conditional sections. Next.js 16 made `default.tsx` mandatory for every slot.

## Category
Next.js

## Subcategories
Parallel routes, intercepting routes, modals, slots, route groups, useSelectedLayoutSegment, soft vs hard navigation

## Problem It Solves
Modals that lose context on refresh, can't be shared via URL, or break the back button; dashboards whose panes must load and fail independently; and conditional UI where teams mistakenly believe the unrendered slot doesn't execute.

## When To Use
- Photo/product/login modals that must also exist as full pages (deep linking).
- Dashboards with independently streaming/erroring panels.
- Tabbed sub-navigation within a pane (`@analytics/layout.tsx`).
- Showing different UI per role in the same URL (with authorization inside each slot).

## When Not To Use
- Simple modals with no URL state — a client dialog component is simpler (see [accessible-dialogs](../accessible-dialogs/Skill.md)).
- As an authorization mechanism — all slots render on the server regardless of which one the layout returns.
- Static exports (`output: 'export'`): intercepting routes are unsupported.

## Core Principles
1. **Slots are not segments.** `@team/settings/page.tsx` serves `/settings`; slots never appear in the URL.
2. **Interception is by route segment, not file system.** `(..)` ignores `@slot` folders when counting levels.
3. **Soft vs hard navigation differ.** Soft navigation keeps unmatched slots' previous state; hard navigation (refresh/direct visit) renders `default.tsx` for unmatched slots.
4. **Every slot needs `default.tsx` (v16).** Builds fail without it; return `null` or call `notFound()`.
5. **Everything renders.** Slots and parallel segments all execute on the server and appear in the RSC payload.

## Best Practices
- Separate modal chrome (`<Modal>` client component) from content (Server Component) so the content can be server-rendered and reused on the full page.
- Close modals with `router.back()`; when navigating away via `<Link>`, add `@modal/[...catchAll]/page.tsx` (returns `null`) so the slot resets.
- Give each slot its own `loading.tsx` and `error.tsx` for independent streaming and failure isolation.
- A slot level must be uniformly static or dynamic — if one slot is dynamic, all slots at that level are.
- Use `useSelectedLayoutSegment('slotName')` to highlight active tabs inside a slot.
- Put authorization in each slot's page or in the Data Access Layer, never only in the conditional layout.

## Implementation Guidance

### Intercept conventions
| Convention | Matches |
|---|---|
| `(.)photo` | Segment at the same level |
| `(..)photo` | One segment level up |
| `(..)(..)photo` | Two segment levels up |
| `(...)photo` | From the `app` root |

### Deep-linkable modal file tree
```txt
app/
├── layout.tsx                 # renders {children} and {modal}
├── page.tsx                   # gallery feed
├── photo/[id]/page.tsx        # full page on hard navigation
└── @modal/
    ├── default.tsx            # return null
    ├── [...catchAll]/page.tsx # return null (closes modal on Link nav)
    └── (.)photo/[id]/page.tsx # modal on soft navigation
```

```tsx
// app/layout.tsx
export default function RootLayout({ children, modal }: LayoutProps<'/'>) {
  return (
    <html lang="en">
      <body>
        {children}
        {modal}
      </body>
    </html>
  )
}
```

```tsx
// app/@modal/(.)photo/[id]/page.tsx
import { Modal } from '@/app/_ui/modal'
import { PhotoDetail } from '@/app/_ui/photo-detail'

export default async function PhotoModal(props: PageProps<'/photo/[id]'>) {
  const { id } = await props.params
  return (
    <Modal>
      <PhotoDetail id={id} />
    </Modal>
  )
}
```

```tsx
// app/_ui/modal.tsx
'use client'
import { useRouter } from 'next/navigation'
import { useEffect, useRef } from 'react'

export function Modal({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const ref = useRef<HTMLDialogElement>(null)
  useEffect(() => { ref.current?.showModal() }, [])
  return (
    <dialog ref={ref} onClose={() => router.back()} aria-labelledby="modal-title">
      <button onClick={() => router.back()} aria-label="Close">×</button>
      {children}
    </dialog>
  )
}
```

### Dashboard with independent panes
```txt
app/dashboard/
├── layout.tsx          # ({ children, revenue, activity })
├── page.tsx
├── default.tsx
├── @revenue/{page,loading,error,default}.tsx
└── @activity/{page,loading,error,default}.tsx
```

### Decision table
| Need | Use |
|---|---|
| Modal + shareable URL + back button closes | Parallel `@modal` + intercepting `(.)` route |
| Panels that stream/fail independently | Parallel slots with own loading/error |
| Same URL, different UI by role | Parallel slots + authorize inside each slot |
| Pure client toggle, no URL | Client state dialog |
| Section-specific layout without URL change | Route group `(name)` (not a slot) |

## Recommended Workflow
1. Build the full-page route first (`photo/[id]/page.tsx`).
2. Add the `@modal` slot with `default.tsx` returning `null`.
3. Add the intercepting route reusing the same content component.
4. Render `{modal}` in the parent layout.
5. Add close behavior (`router.back()`) and catch-all reset page.
6. Test soft navigation, refresh, direct URL, back/forward.
7. Run `next build` to confirm all slots have defaults.

## Patterns
- **Nextgram pattern** (vercel-labs/nextgram): feed + intercepted photo modal.
- **Login modal from navbar:** `@auth/(.)login/page.tsx` with `/login` as the standalone page.
- **Tab group in slot:** `@analytics/layout.tsx` containing `<Link>` tabs to `page-views`/`visitors`.
- **Cart drawer:** `@cart/(.)cart/page.tsx` rendered as a side sheet.

## Anti-Patterns
- **Missing `default.tsx`** — v16 build failure. Fix: add `default.tsx` returning `null` or `notFound()` in every slot (including implicit `children` where recovery is needed).
- **Counting `@slot` folders in `(..)`** — interception never matches. Fix: count route segments only.
- **Conditional layout as access control** (`role === 'admin' ? admin : user`) — admin slot still executes and ships in the payload. Fix: authorize in `@admin/page.tsx` or the DAL.
- **Modal content as a Client Component that fetches in `useEffect`** — loses server rendering and duplicates the page. Fix: share a Server Component between modal and page.
- **Closing modal with `<Link href="/">` without a matching null slot page** — modal stays visible. Fix: add `@modal/page.tsx` or `[...catchAll]` returning `null`.

## Accessibility
- Modals must trap focus, restore focus to the trigger on close, close with Escape, and have an accessible name (WCAG 2.1.2, 2.4.3; APG Dialog pattern). Native `<dialog>` + `showModal()` handles inert background and Escape.
- On hard navigation the full page renders instead of the modal — ensure it has its own `<h1>` and landmark structure.
- Announce pane loading/errors with appropriate roles (`role="alert"` for errors, `aria-busy` for loading regions).

## Responsive Design
- Intercepted "modals" can render as bottom sheets on small screens and centered dialogs on large screens with CSS only.
- Parallel dashboard panes should reflow with CSS grid/container queries; avoid rendering different slots per breakpoint (all slots execute anyway).

## Performance
- Each slot is a separate streaming unit — slow panes don't block fast ones.
- Every slot executes on the server for each render of that level: avoid expensive slots users rarely see, or cache their data with `use cache`.
- With Cache Components, a slot included in a cached segment needs `use cache` in each segment file to prerender the full route.

## Security
- All slots render and serialize their output regardless of the layout's conditional; never place privileged data in a slot without authorizing inside it.
- Intercepted routes expose the same data as the full page — apply identical authorization to both.

## Testing
- Playwright: click-through opens modal with URL change; `page.reload()` shows full page; `page.goBack()` closes modal; direct `goto` shows full page.
- Assert focus returns to the trigger element after closing.
- CI `next build` guards against missing `default.tsx`.

## Tooling
- `useSelectedLayoutSegment(s)` from `next/navigation` (accept `parallelRouteKey`).
- `useRouter().back()` for closing.
- Reference implementation: vercel-labs/nextgram.

## Framework Notes
- Available since Next.js 13.3; `default.tsx` became mandatory in 16.0.
- Not supported in static exports.
- React (Vite SPA): the same UX is built with client router state (background location / route masking) and a client dialog; there is no server rendering of the modal content and no hard-navigation fallback page unless you build one.
- Keep modal open/close state in the URL (this pattern) rather than component state so it survives refresh and is shareable; for non-route UI state in the query string use nuqs (see [react-url-state-nuqs](../react-url-state-nuqs/Skill.md)).

## AI Agent Guidance
- Do: generate `default.tsx` for every slot; reuse a shared server content component for page and modal; add catch-all null pages.
- Don't: use parallel routes for simple toggles; authorize only in the layout; count slot folders in `(..)`.
- Verify before done: `next build` passes; manual or Playwright check of soft nav, refresh, back/forward, and direct URL; focus management in the modal works with keyboard only.

## Examples
```tsx
// app/dashboard/@admin/page.tsx — authorize inside the slot
import { requireRole } from '@/lib/dal'
import { getAdminStats } from '@/lib/dal/stats'

export default async function AdminSlot() {
  await requireRole('admin') // throws/redirects if not allowed
  const stats = await getAdminStats()
  return <section aria-labelledby="admin-h"><h2 id="admin-h">Admin</h2>{/* ... */}</section>
}
```

```tsx
// app/@modal/[...catchAll]/page.tsx
export default function CatchAll() {
  return null
}
```

## Related Skills
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — base file conventions
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — per-slot loading states
- [nextjs-authentication](../nextjs-authentication/Skill.md) — authorization inside slots
- [accessible-dialogs](../accessible-dialogs/Skill.md) — modal accessibility
- [drawers-and-sheets](../drawers-and-sheets/Skill.md) — intercepted cart/side sheets
- [master-detail-layouts](../master-detail-layouts/Skill.md) — independent panes

## Sources
- [Parallel Routes](https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes) — Official — slots, default.js, modals, conditional routes caveat
- [Intercepting Routes](https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes) — Official — conventions and modal example
- [Upgrading to v16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — mandatory default.js
- [vercel-labs/nextgram](https://github.com/vercel-labs/nextgram) — Open Source — reference modal gallery

## License / Usage Notes
Next.js and nextgram are MIT licensed. Guidance summarized from official docs; code is original minimal illustration.

## Quality Tier
A — Official-doc grounded with verified v16 breaking change; accessibility guidance added from general dialog practice.

## Status
Active

## Last Verified
2026-09-15
