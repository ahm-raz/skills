# Master-Detail Layouts

## Summary
Patterns for showing a list of records alongside or above the selected record's details in React + Next.js: split panes, side panels (drawers), flexible multi-column layouts, and full-page object views. Covers URL design (selected record in the route), Next.js parallel and intercepting routes, keyboard navigation between records, unsaved-changes handling, and responsive collapse.

## Category
Enterprise UI

## Subcategories
Split view, list-detail, side panel, object page, flexible column layout, parallel routes, intercepting routes, record navigation, inspector panels

## Problem It Solves
Operators triage queues and review records one after another. Navigating list → detail → back loses scroll, filters, and flow; modals hide the list and block comparison. A well-built master-detail layout lets users move through records fast, keep context, deep-link to any record, and edit safely.

## When To Use
- Queues and inboxes (tickets, approvals, orders to fulfill, leads).
- Records that users inspect frequently but edit briefly.
- When comparing a record with neighbors or copying values from similar records (NN/g recommends nonmodal side panels for this).

## When Not To Use
- Deep, multi-section records with long edits: use a full object page route (still linked from the list).
- Mobile-first flows: use stacked navigation (list screen → detail screen).
- Lists where users never open individual records.

## Core Principles
1. The selected record lives in the URL (`/tickets/123` or `?selected=123`), so reload, back, and sharing work.
2. The list keeps its state (filters, sort, scroll, page) while details change.
3. Nonmodal by default: users can still scroll and select in the list while details are open.
4. Keyboard parity: move to next/previous record, open, close, and return focus without the mouse.
5. Detail data is fetched and authorized independently of the list (a row being visible is not permission to see all its fields).
6. Collapse gracefully: two or three columns on desktop, one column with navigation on small screens.

## Best Practices
- Choose the layout by task:
  | Layout | Use when |
  |---|---|
  | Split view (list 30–40%, detail 60–70%) | Triage queues, email-like flows |
  | Side panel/drawer over the list | Occasional inspection; list needs full width most of the time |
  | Flexible column layout (list → detail → sub-detail) | Drilling into line items (SAP Fiori flexible column layout; verify against current Fiori guidelines) |
  | Full object page | Long records with sections, tabs, related lists, and finalizing actions |
- Object page anatomy (Fiori-style, general practice): header with title, status, key facts, and primary actions; anchor/tab navigation for sections; sticky footer or header action bar for edit/save/cancel.
- Highlight the selected row with both background and a non-color cue (left border or `aria-current`).
- Provide "Previous / Next" in the detail header that respects current list filters and sort ("3 of 128").
- Resizable divider with keyboard support and persisted width; sensible min widths.
- Loading the detail must not blank the list; show a skeleton in the detail pane only.
- Prompt on unsaved changes when switching records; or autosave drafts per record.
- "Open in full page" action from the panel for deep work.

## Implementation Guidance

### Route design options (Next.js App Router)
| Option | URL | Notes |
|---|---|---|
| Nested dynamic segment | `/tickets/[id]` inside `tickets/layout.tsx` that renders the list | Simplest; list persists in layout across detail navigations |
| Parallel route slot | `tickets/@detail/[id]/page.tsx` | Independent loading/error states for list and detail |
| Intercepting route | `tickets/@panel/(.)[id]/page.tsx` | Soft navigation shows panel over list; hard load or refresh renders full page `/tickets/[id]` |
| Search param | `/tickets?selected=123` | Works in any page; easy with nuqs; list and detail in one page |

### Split view with nested layout
```tsx
// app/(admin)/tickets/layout.tsx  (Server Component)
import type { ReactNode } from 'react';
import { TicketList } from './ticket-list';

export default function TicketsLayout({ children }: { children: ReactNode }) {
  return (
    <div className="split">
      <section aria-labelledby="ticket-list-h" className="split__list">
        <h1 id="ticket-list-h">Tickets</h1>
        <TicketList />{/* reads filters from URL, streams its own data */}
      </section>
      <section aria-label="Ticket details" className="split__detail">{children}</section>
    </div>
  );
}
```
Note: layouts do not receive `searchParams`; if the list depends on search params, render it from a client component reading the URL (nuqs) that fetches via a route handler, or use the search-param option with everything in `page.tsx`.

```tsx
// app/(admin)/tickets/[id]/page.tsx
import { notFound } from 'next/navigation';
import { getTicketDetail } from '@/data/tickets'; // server-only: authn, authz, tenant, DTO

export default async function TicketDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ticket = await getTicketDetail(id);
  if (!ticket) notFound(); // also for forbidden, to avoid leaking existence
  return <TicketDetail ticket={ticket} />;
}
```
```tsx
// app/(admin)/tickets/page.tsx — empty state when nothing selected
export default function NoSelection() {
  return <p className="empty">Select a ticket to see details.</p>;
}
```

### Panel over list with intercepting routes
```
app/(admin)/orders/
  layout.tsx            // renders {children} and {panel}
  page.tsx              // list
  [id]/page.tsx         // full object page (direct load, refresh, share)
  @panel/default.tsx    // returns null
  @panel/(.)[id]/page.tsx // same detail rendered inside a side panel on soft navigation
```
```tsx
// app/(admin)/orders/layout.tsx
export default function Layout({ children, panel }: { children: React.ReactNode; panel: React.ReactNode }) {
  return <>{children}{panel}</>;
}
```
```tsx
// app/(admin)/orders/@panel/(.)[id]/page.tsx
import { getOrderDetail } from '@/data/orders';
import { SidePanel } from '@/components/side-panel';

export default async function OrderPanel({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const order = await getOrderDetail(id);
  return <SidePanel title={`Order ${order.number}`}><OrderSummary order={order} /></SidePanel>;
}
```
```tsx
// components/side-panel.tsx
'use client';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, type ReactNode } from 'react';

export function SidePanel({ title, children }: { title: string; children: ReactNode }) {
  const router = useRouter();
  const headingRef = useRef<HTMLHeadingElement>(null);
  useEffect(() => { headingRef.current?.focus(); }, [title]);
  return (
    <aside className="side-panel" aria-labelledby="panel-title"
      onKeyDown={(e) => { if (e.key === 'Escape') router.back(); }}>
      <header>
        <h2 id="panel-title" ref={headingRef} tabIndex={-1}>{title}</h2>
        <button type="button" aria-label="Close details" onClick={() => router.back()}>×</button>
      </header>
      {children}
    </aside>
  );
}
```
Check the current Next.js intercepting routes docs for the `(.)` convention relative to route segments (it matches segments, not the file system) and `default.tsx` requirements.

### Record navigation respecting filters
```ts
// data/tickets.ts (excerpt)
import 'server-only';
export async function getNeighbors(id: string, listQuery: ListQuery) {
  // Use the same compiled where + orderBy as the list; fetch previous/next by keyset on the sort field + id.
  // Return { prevId, nextId, position, total } — IDs only.
}
```
```tsx
'use client';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

export function useRecordHotkeys(prevHref?: string, nextHref?: string) {
  const router = useRouter();
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement;
      if (t.closest('input, textarea, select, [contenteditable="true"]')) return;
      if (e.key === 'j' && nextHref) router.push(nextHref, { scroll: false });
      if (e.key === 'k' && prevHref) router.push(prevHref, { scroll: false });
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [router, prevHref, nextHref]);
}
```
Preserve list search params when building `prevHref`/`nextHref` so filters stay intact.

## Recommended Workflow
1. Identify the dominant task (triage, inspect, deep edit) and choose split, panel, flexible columns, or object page.
2. Design URLs: selected record in path or search param; list state in search params.
3. Build the list with persistent state; build detail data access with its own authorization.
4. Implement layout (nested layout, parallel/intercepting routes, or search param).
5. Add selection highlight, prev/next with position, keyboard shortcuts, focus management.
6. Add editing with unsaved-changes guard or autosave; revalidate list row after save.
7. Implement responsive collapse and resizable divider.
8. Test deep links, back/forward, refresh, keyboard flow, and forbidden records.

## Patterns
- **Inbox split view**: list with compact rows; detail with header actions; j/k to move, Enter to open, Esc to return to list.
- **Inspector side panel**: nonmodal panel, width ~400–560px, list remains interactive; panel content is a summary with "Open full page".
- **Flexible column layout**: up to three columns (list / object / line item); the newest column gets the most width; users can expand one column to full screen (Fiori concept; verify details).
- **Object page**: sticky header (title, status badge, key facts, actions), section anchor tabs, related lists as embedded tables, footer with Save/Cancel in edit mode.
- **Post-save list sync**: Server Action updates the record, then `revalidatePath('/tickets')` or tag revalidation so the list row reflects changes.
- **Deleted-while-open**: detail shows "This record no longer exists" with a link back to the list; list removes the row.

## Anti-Patterns
- **Detail in a modal dialog**: hides list, prevents comparison, awkward deep links. Fix: side panel or split view.
- **Selected record only in React state**: refresh loses context; no sharing. Fix: route or search param.
- **Navigating to detail with a full page load and losing list scroll/filters**. Fix: nested layout or parallel routes; `scroll: false`.
- **Prev/next ignoring filters**: jumps to unrelated records. Fix: compute neighbors with the list query.
- **Passing the whole list row as detail data**: stale and may expose or lack fields. Fix: fetch detail DTO by ID with authz.
- **Global single-letter shortcuts firing while typing**: corrupts input. Fix: ignore when focus is in editable elements; allow disabling (WCAG 2.1.4).
- **Silent discard of unsaved edits when switching records**. Fix: guard dialog or autosave draft.

## Accessibility
- Both panes are labeled regions (`<section aria-label>` or headings) so screen reader users can jump between list and detail.
- The selected row has `aria-current="true"` (or `aria-selected` in a listbox/grid pattern) plus visual non-color cue.
- On opening details, move focus to the detail heading (`tabIndex={-1}`); on closing, return focus to the originating row.
- Esc closes panels; Tab order goes list → detail predictably.
- Character-key shortcuts (j/k) must be remappable, disableable, or active only on focus (WCAG 2.1.4 Character Key Shortcuts).
- Resizable splitter uses `role="separator"` with `aria-orientation`, `aria-valuenow/min/max`, and arrow key support (APG window splitter pattern).
- Announce "Ticket 3 of 128" on record change via the detail heading or a polite live region.

## Responsive Design
- Wide (≥1280px): split or three-column; medium: panel overlays list; narrow: single column with the list at `/tickets` and detail at `/tickets/[id]` and a back link.
- Use container queries on the admin content area rather than viewport queries, since sidebars change available width ([container-queries](../container-queries/Skill.md)).
- On narrow screens, the intercepting-route panel becomes a full-screen sheet; the full page route remains the canonical fallback.
- Preserve scroll position of the list when returning on mobile (Next.js restores scroll on back; avoid remounting the list with keys that change).

## Performance
- Stream detail independently with `loading.tsx` in the detail segment or Suspense, so list interaction stays responsive.
- Prefetch neighbor records on hover/focus of rows or on idle for prev/next (Next.js `<Link prefetch>` behavior; check current defaults).
- Keep list rows light; fetch heavy detail (activity, attachments) lazily in tabs.
- Use `scroll: false` on record navigation to avoid scroll jumps.

## Security
- Detail pages authorize by record ID in the DAL (IDOR); treat `params.id` as untrusted.
- Return `notFound()` for both missing and forbidden records if existence should not leak.
- Edits via Server Actions re-authorize; do not rely on the page having authorized the view.
- Field-level permissions apply in the detail DTO; do not ship hidden fields for client-side hiding.

## Testing
- E2E (Playwright): open record from filtered list, press j/k, verify URL and filters persist; refresh on a detail URL renders full page; back returns to list with scroll and selection.
- Intercepting routes: soft navigation shows panel; hard load shows full page.
- Authorization: user without access to a record gets 404 on direct URL.
- Accessibility: focus moves to detail heading and back to row; splitter keyboard operation; shortcuts do not fire in inputs.

## Tooling
- Next.js App Router parallel and intercepting routes.
- `nuqs` for `?selected=` and list state.
- `react-resizable-panels` (MIT) for split panes with keyboard support; verify current API.
- UI5 Web Components for React offers Fiori-style layouts (e.g., flexible column layout, object page) if you are in the SAP ecosystem; confirm Next.js setup notes in its docs.

## Framework Notes
- **Next.js (App Router)**: prefer nested layouts for split views and intercepting routes for panels with full-page fallbacks. `params` and `searchParams` are Promises in Next.js 16. Layouts do not receive `searchParams`, so plan where list-state-dependent data is fetched. Use `revalidatePath`/tags after edits.
- **React (Vite SPA)**: React Router nested routes (`/tickets` with `<Outlet />` for `:id`) give the same split behavior; background-location pattern emulates intercepting routes for panels. Fetch detail with TanStack Query keyed by ID; prefetch neighbors.

## AI Agent Guidance
- Do: put the selected ID in the URL; fetch detail by ID with authz; implement focus move/return; guard unsaved changes; keep list state on navigation.
- Do: verify Next.js parallel/intercepting route conventions against current docs before generating folder structures.
- Don't: open details in a blocking modal by default; don't reuse list row objects as detail data; don't add unguarded single-key shortcuts.
- Before done: test refresh on detail URL, back/forward, keyboard-only triage of five records, narrow viewport behavior, and a forbidden ID.

## Examples
Split-view CSS with container queries:
```css
.split { container-type: inline-size; display: grid; grid-template-columns: 1fr; block-size: 100%; }
@container (min-width: 960px) {
  .split { grid-template-columns: minmax(320px, 38%) 1fr; }
  .split__list { border-inline-end: 1px solid var(--border); overflow: auto; }
  .split__detail { overflow: auto; }
}
.row[aria-current='true'] { background: var(--selected-bg); box-shadow: inset 3px 0 0 var(--accent); }
```

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — the master list
- [drawers-and-sheets](../drawers-and-sheets/Skill.md) — side panel mechanics
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md) — parallel and intercepting routes
- [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md) — shortcut conventions
- [focus-management](../focus-management/Skill.md) — focus move and return
- [dense-form-screens](../dense-form-screens/Skill.md) — editing in the detail pane
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — selected record in search params
- [container-queries](../container-queries/Skill.md) — pane-aware responsiveness

## Sources
- [NN/g: Data Tables](https://www.nngroup.com/articles/data-tables/) — Research — nonmodal side panels preferred for viewing/editing records
- [NN/g: Complex application design](https://www.nngroup.com/articles/complex-application-design/) — Research — coordinate workspaces, access secondary info without leaving the screen
- [SAP Fiori floorplan overview](https://www.sap.com/design-system/fiori-design-web/page-types/floorplan-overview) — Official — list report, object page, flexible column layout concepts (page returned 403 at verification; summarized from general knowledge, verify)
- [UI5 Web Components for React](https://github.com/SAP/ui5-webcomponents-react) — Open Source — Fiori-compliant React components, Next.js notes
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — params as untrusted input, action authz
- [W3C APG Grid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — keyboard model for interactive lists

## License / Usage Notes
Guidance summarized; code original. react-resizable-panels and nuqs are MIT; UI5 Web Components for React license per its repository (check).

## Quality Tier
B — strong, practical patterns, but Fiori guidance could not be fetched and Next.js intercepting-route details were not re-verified this session.

## Status
Active

## Last Verified
2026-09-15
