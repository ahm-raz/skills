# Resource Scheduling & Timeline Views

## Summary
Patterns for scheduler, resource timeline and Gantt-style views in React/Next.js enterprise apps. A horizontal time axis runs against rows of resources (people, machines, rooms, vehicles, docks) or tasks. Users create, drag-reschedule and resize bookings with keyboard alternatives, zoom between hour/day/week/month, get conflict and capacity detection enforced on the server, handle time zones correctly, and scroll smoothly through large grids virtualized on both axes.

## Category
Enterprise UI

## Subcategories
resource timeline, scheduler, Gantt, booking, dispatch board, shift planning, capacity, time zones, virtualization, drag to reschedule

## Problem It Solves
Planning screens (field-service dispatch, shift rostering, production scheduling, warehouse dock booking, equipment rental) must show who or what is busy when, prevent double-booking, and let planners rearrange quickly. They're hard to get right. Time-zone and DST bugs, client-only conflict checks, unusable drag on touch or keyboard, and DOM explosions at 500 resources × 30 days are the common failures.

## When To Use
- Assigning time-bound work to finite resources with capacity constraints.
- Visualizing utilization and gaps across teams or assets.
- Project timelines with dependencies (Gantt) where dates matter more than status.

## When Not To Use
- Picking a single date/time. See date-pickers-and-calendars.
- Personal calendar (month/week grid of one user's events). A standard calendar view is simpler.
- Status-based flow with no time dimension. See kanban-boards.
- Heavy optimization (auto-scheduling solvers). The UI can host it, but the solver belongs on the server.

## Core Principles
1. Time is stored as UTC instants plus an explicit IANA time zone for the resource/location. Render in a clearly labelled display zone.
2. The server is authoritative for conflicts, capacity, working hours and permissions. Client checks are previews only.
3. Every drag or resize has a non-drag equivalent: edit dialog with start/end/resource fields, and a keyboard move/resize mode (WCAG 2.5.7, 2.1.1).
4. Zoom levels change the time unit per column and the snapping granularity. They don't just scale pixels.
5. Virtualize rows and time columns, and fetch only the visible window plus a buffer.
6. Make conflicts visible before commit (ghost preview with a warning) and explain rejections after commit.

## Best Practices
- Layout anatomy: toolbar (date navigator ‹ Today ›, zoom select, display time zone, filters, "New booking"), a sticky resource column (name, avatar, capacity/utilization bar), a sticky time header (two tiers, e.g. day over hours), a scrollable grid body, a "now" line, and non-working time shaded.
- Snap to a granularity per zoom (15 min at hour zoom, 1 day at month zoom). Show start–end tooltips live while dragging.
- Unassigned queue: a side panel of unscheduled jobs to drag or "Assign…" onto resources.
- Overlapping events in one row: stack into sub-lanes and show "+N" at low zoom.
- Conflict styles: hatched pattern plus icon plus text ("Overlaps with Job 1042"), not colour alone.
- Keep the URL in sync: `?view=resourceTimeline&start=2026-09-14&zoom=day&tz=Europe/Berlin&team=north`.
- For DST days, render the real number of hours (23/25). Never assume 24.
- Show the recurring series vs occurrence choice when editing recurring bookings.
- Provide an undo toast for moves. Use bulk shift ("move selected +1 day") for planners.

## Implementation Guidance
**Build vs buy decision table**

| Option | Notes |
|---|---|
| FullCalendar (React connector) | Standard features MIT. Timeline and resource views are Premium (commercial license). Latest shows v7.1.0 on its pricing page, so check docs for React connector licensing details |
| MUI X Scheduler | Listed among MUI X components on the licensing page. Tier and feature split not verified this session, so check current docs |
| Bryntum Scheduler/Gantt, DHTMLX, Syncfusion, Mobiscroll | Commercial, feature-rich (dependencies, resource histograms). Evaluate licensing, React 19/Next.js SSR support and a11y. Check current docs |
| Custom (CSS grid + TanStack Virtual + dnd-kit) | Full control and design-system fit. Viable for simple resource rows and bookings. Costly for Gantt dependencies and critical path |

**Data contracts**
```ts
export interface Resource { id: string; name: string; timeZone: string; capacityPerDay?: number; workingHours?: { dow: number; start: string; end: string }[]; }
export interface Booking { id: string; resourceId: string; startUtc: string; endUtc: string; title: string; status: 'tentative' | 'confirmed'; version: number; }
export interface WindowQuery { start: string; end: string; resourceIds?: string[]; cursor?: string; limit: number; } // ISO instants
export type ScheduleResult =
  | { ok: true; booking: Booking }
  | { ok: false; reason: 'conflict'; conflicts: Pick<Booking, 'id' | 'title' | 'startUtc' | 'endUtc'>[] }
  | { ok: false; reason: 'outside_hours' | 'capacity' | 'forbidden' | 'stale'; message: string };
```
Enforce non-overlap in the database where possible (e.g. PostgreSQL exclusion constraint on `tstzrange` per resource), not only in application code.

**Coordinate math**
```ts
export const pxPerMs = (zoom: 'hour' | 'day' | 'week') => ({ hour: 120 / 3_600_000, day: 48 / 3_600_000, week: 160 / 86_400_000 }[zoom]);
export const xFor = (instantMs: number, windowStartMs: number, zoom: Parameters<typeof pxPerMs>[0]) => (instantMs - windowStartMs) * pxPerMs(zoom);
export const snap = (ms: number, stepMs: number) => Math.round(ms / stepMs) * stepMs;
```
Use a time-zone-aware library for wall-clock boundaries (day starts, working hours): `Temporal` where available or polyfilled, or `date-fns-tz`/Luxon/Day.js with tz. Check current support and docs.

## Recommended Workflow
1. Define resources, booking rules (overlap allowed?, buffers, working hours, capacity), and time-zone policy.
2. Implement the DAL: window query (paginated by resources), `scheduleBooking` with authz, rule checks, version check and DB constraint, plus audit.
3. Build the static grid: sticky headers and resource column, zoom levels, now line, non-working shading.
4. Virtualize rows (TanStack Virtual) and columns (horizontal virtualizer or render only visible time range).
5. Add create (click-drag empty space or the "New" dialog), move/resize (pointer), and edit dialog (non-drag).
6. Add keyboard mode: focus a booking, `Enter` to pick up, arrows for time (by snap) and resource (up/down), `Shift+arrows` to resize, `Enter` to commit, `Esc` to cancel, with live announcements.
7. Add optimistic preview, server validation, conflict UI and undo.
8. Test DST transitions, multiple zones, large windows and concurrent planners.

## Patterns
**Server-driven window loading (App Router)**
```tsx
// app/(app)/schedule/page.tsx
import { createLoader, parseAsIsoDate, parseAsStringLiteral, parseAsString } from 'nuqs/server'; // verify parser names in current nuqs docs
import { getScheduleWindow } from '@/data/schedule';
import { ScheduleView } from './schedule-view'; // 'use client'

const load = createLoader({
  start: parseAsIsoDate,
  zoom: parseAsStringLiteral(['hour', 'day', 'week'] as const).withDefault('day'),
  tz: parseAsString,
});

export default async function SchedulePage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const { start, zoom, tz } = await load(searchParams);
  const window = await getScheduleWindow({ start: start ?? new Date(), zoom, tz }); // authz + resource scoping, validates tz
  return <ScheduleView initial={window} zoom={zoom} displayTimeZone={window.displayTimeZone} />;
}
```

**Reschedule Server Action**
```ts
'use server';
import { z } from 'zod';
import { rescheduleBooking } from '@/data/schedule';

const Input = z.object({ id: z.string(), resourceId: z.string(), startUtc: z.string().datetime(), endUtc: z.string().datetime(), version: z.number().int() })
  .refine((v) => Date.parse(v.endUtc) > Date.parse(v.startUtc), { message: 'End must be after start' });

export async function rescheduleAction(raw: unknown): Promise<ScheduleResult> {
  return rescheduleBooking(Input.parse(raw)); // DAL: session, permission on both resources, working hours in resource tz, overlap via DB constraint, version, audit
}
```

**Keyboard move mode (sketch)**
```tsx
function onBookingKeyDown(e: React.KeyboardEvent, b: DraftBooking) {
  if (!moving) { if (e.key === 'Enter') { setMoving(b); announce(`Moving ${b.title}. Arrows change time and resource, Shift plus arrows resize, Enter to save, Escape to cancel.`); } return; }
  const step = snapMs(zoom);
  const next = { ...moving };
  if (e.key === 'ArrowRight') e.shiftKey ? (next.end += step) : ((next.start += step), (next.end += step));
  if (e.key === 'ArrowLeft') e.shiftKey ? (next.end = Math.max(next.start + step, next.end - step)) : ((next.start -= step), (next.end -= step));
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') next.resourceId = neighbourResource(next.resourceId, e.key === 'ArrowDown' ? 1 : -1);
  if (e.key === 'Enter') return void commit(next);
  if (e.key === 'Escape') { setMoving(null); return announce('Move cancelled'); }
  e.preventDefault(); setMoving(next); announce(describe(next, displayTimeZone));
}
```

**Conflict feedback**: during drag, check against loaded bookings for an instant hatched ghost ("Conflicts with Job 1042"). On commit, show the server's `conflicts` list in a toast or popover with "View" links, and the booking snaps back (optimistic rollback).

## Anti-Patterns
- **Storing local wall-clock strings without a zone.** DST and cross-zone bugs. Fix: UTC instants plus an IANA zone per resource and a labelled display zone.
- **Assuming a day equals 86,400,000 ms for day boundaries.** Wrong on DST days. Fix: compute boundaries with a zone-aware library.
- **Client-only overlap checks.** Double bookings from concurrent planners or direct action calls. Fix: DB constraint plus DAL check plus version.
- **Rendering every cell as a DOM node** (resources × slots). Freezes. Fix: render a background grid via CSS (`background-image` repeating gradients) and absolutely positioned bookings, virtualized on both axes.
- **Drag-only interaction.** Fails keyboard and 2.5.7. Fix: edit dialog plus keyboard move mode.
- **Fetching the whole year.** Fix: fetch the visible window plus a buffer, and prefetch adjacent periods on navigation.
- **Premium scheduler used without a license** in production. Fix: confirm the vendor license tier before shipping.

## Accessibility
- Structure: expose the timeline as a `grid` (resources as rows, time periods as column headers) or provide an equivalent accessible list/agenda view per resource. A full ARIA grid for a continuous timeline is hard, so the agenda alternative is often the most usable.
- Bookings are focusable with names like "Job 1042, Anna Kovacs, Tue 15 Sep 09:00–11:30 CEST, confirmed, conflict".
- WCAG 2.5.7 Dragging Movements and 2.1.1 Keyboard: edit dialog and keyboard move/resize mode.
- Live region announcements during keyboard moves (throttled), and on commit/reject.
- Colour-independent status and conflicts (pattern, icon, text; WCAG 1.4.1). Contrast of booking text on coloured backgrounds at least 4.5:1.
- Time zone always shown in the header and in announcements.
- Respect `prefers-reduced-motion` for snap-back animations.

## Responsive Design
- Desktop/planner monitors: full timeline with sticky resource column and two-tier header.
- Tablet: default to day zoom, larger hit areas, long-press to start drag (activation delay).
- Phone: switch to an agenda list per resource or "my schedule". Editing via dialog, not drag.
- Use container queries to hide secondary booking text at narrow widths (title only).

## Performance
- Virtualize rows (TanStack Virtual) and bound the rendered time range. Absolutely position bookings with `transform` for moves.
- Render drag previews in an overlay layer and avoid rerendering the grid on pointermove (refs plus rAF).
- Precompute layout (sub-lane stacking) in a memoized selector or Web Worker for dense rows.
- Stream the initial window from a Server Component. Fetch adjacent windows client-side (TanStack Query or Server Actions) with keep-previous-data.
- Canvas rendering (e.g. Glide-style) is an option for very large grids, at an accessibility cost that needs an alternate view.

## Security
- Authorize per resource: planners may only schedule resources in their team, region or tenant. Check both source and target resources on move.
- Validate instants and zones server-side (IANA allow-list via `Intl.supportedValuesOf('timeZone')` or a library).
- Enforce overlap and capacity in the database or transaction. Record audit entries (before/after, actor).
- Don't expose other resources' booking details beyond what the viewer may see: redact to "Busy" for restricted calendars.

## Testing
- Unit: coordinate math, snapping, sub-lane stacking, and DST boundaries (e.g. Europe/Berlin last Sunday of March and October, America/New_York).
- DAL integration: concurrent reschedules into the same slot, where exactly one succeeds and the other gets `conflict`.
- Component: keyboard move mode sequence and announcements.
- Playwright: drag booking to another resource and time, resize, conflict rollback, zoom change updates URL, and `timezoneId` context option to test different browser zones.
- Performance: 500 resources × 14 days scroll at 60fps on a mid-range laptop profile.

## Tooling
- Zone-aware dates: Temporal (check runtime support/polyfill), date-fns plus date-fns-tz, Luxon.
- TanStack Virtual (rows/columns), dnd-kit (drag), nuqs (URL window state).
- Commercial schedulers: FullCalendar Premium (timeline/resource views), MUI X Scheduler (verify tier), Bryntum, DHTMLX, Syncfusion. Check licensing and current docs.

## Framework Notes
- **React (Vite SPA):** all window fetching via TanStack Query keyed by `[start, zoom, tz, filters]`. Mutations via API with the same server rules. URL state via nuqs with the React Router adapter.
- **Next.js App Router:** Server Component loads the initial window via DAL (awaited `searchParams`). The interactive grid is a Client Component. Reschedules are Server Actions returning typed `ScheduleResult`, then `revalidateTag` for the window. Avoid rendering "now" or local-zone strings in Server Components without the explicit display zone (hydration mismatches). Pass instants and format on the client with the chosen zone, or format on the server with the same zone. Many commercial schedulers are client-only, so load them with `next/dynamic` in a Client Component.

## AI Agent Guidance
- Do: UTC instants plus IANA zones, a zone-aware library, server/DB conflict enforcement, a typed `ScheduleResult`, an edit dialog plus keyboard mode, virtualization on both axes, and URL-synced window/zoom.
- Don't: compute day boundaries with fixed ms, trust client overlap checks, render a cell per slot, or ship a premium scheduler without confirming license.
- Verify: DST-day rendering (23/25 hours), concurrent double-booking is rejected, keyboard-only reschedule works with announcements, and a large dataset scroll stays smooth.

## Examples
```sql
-- PostgreSQL: prevent overlapping confirmed bookings per resource
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE booking ADD CONSTRAINT no_overlap
  EXCLUDE USING gist (resource_id WITH =, tstzrange(start_utc, end_utc, '[)') WITH &&)
  WHERE (status = 'confirmed');
```
```tsx
'use client';
export function BookingBlock({ b, windowStartMs, zoom, tz }: { b: Booking; windowStartMs: number; zoom: 'hour' | 'day' | 'week'; tz: string }) {
  const start = Date.parse(b.startUtc), end = Date.parse(b.endUtc);
  const fmt = new Intl.DateTimeFormat(undefined, { timeZone: tz, weekday: 'short', hour: '2-digit', minute: '2-digit', timeZoneName: 'short' });
  const label = `${b.title}, ${fmt.format(start)} to ${fmt.format(end)}, ${b.status}`;
  return (
    <button className="booking" data-status={b.status} aria-label={label}
      style={{ transform: `translateX(${xFor(start, windowStartMs, zoom)}px)`, width: Math.max(8, xFor(end, start, zoom)) }}>
      <span aria-hidden>{b.title}</span>
    </button>
  );
}
```

## Related Skills
- [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md) — date/time inputs used in booking dialogs
- [kanban-boards](../kanban-boards/Skill.md) — status-based alternative to time-based planning
- [drag-and-drop](../drag-and-drop/Skill.md) — accessible drag foundations
- [list-virtualization](../list-virtualization/Skill.md) — row/column virtualization
- [wms-and-logistics-ui-patterns](../wms-and-logistics-ui-patterns/Skill.md) — dock booking and dispatch
- [erp-ui-patterns](../erp-ui-patterns/Skill.md) — production and shift scheduling contexts
- [realtime-collaboration-ui](../realtime-collaboration-ui/Skill.md) — concurrent planners
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — URL-synced window and zoom
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — reschedule mutations
- [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md) — planner shortcuts

## Sources
- [FullCalendar pricing](https://fullcalendar.io/pricing) — Official — Standard MIT vs Premium (timeline, vertical resource view), latest v7.1.0
- [MUI X licensing](https://mui.com/x/introduction/licensing/) — Official — Scheduler listed among MUI X components (tier not verified)
- [nuqs server-side docs](https://nuqs.dev/docs/server-side) — Official — createLoader/createSearchParamsCache, parsers, v2.10.1
- [W3C WAI-ARIA APG Grid Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — grid keyboard model and aria-rowcount/rowindex for virtualized grids
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — Server Action authz, DAL, controlled returns
- [dnd-kit repository](https://github.com/clauderic/dnd-kit) — Open Source — sensors and accessibility hooks for drag

## License / Usage Notes
FullCalendar Standard MIT, Premium commercial. MUI X Scheduler licensing per MUI X terms (verify tier). Other commercial schedulers need vendor licenses. Content is summarized. Code and SQL are original.

## Quality Tier
B — architecture, time-zone and security guidance is solid. Vendor scheduler specifics (MUI X Scheduler tier, FullCalendar React connector licensing, nuqs `parseAsIsoDate` name) were not fully verified.

## Status
Active

## Last Verified
2026-09-15
