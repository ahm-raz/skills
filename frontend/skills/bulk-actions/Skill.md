# Bulk Actions

## Summary
Selecting many records and acting on them at once in enterprise React + Next.js apps: selection models (explicit IDs vs "all matching" query with exclusions), the contextual batch action bar, confirmation and undo, background jobs with progress, partial failure reporting, and per-record server-side authorization. The server acts on a query, not on a trusted list the client invented.

## Category
Enterprise UI

## Subcategories
Row selection, select all across pages, batch action bar, bulk edit, bulk delete, background jobs, progress, partial failures, undo

## Problem It Solves
Operators routinely need to "assign these 3,200 tickets to Team B" or "archive every draft older than 90 days." Doing this one row at a time is painful; naive implementations send thousands of IDs, time out, fail silently on some records, bypass permissions, or delete the wrong set because the list changed between selection and execution.

## When To Use
- Lists where users repeatedly apply the same change to multiple records (status, owner, tags, archive, export).
- Triage, moderation, inventory, CRM, and approval queues.

## When Not To Use
- Irreversible, high-risk actions better handled as a reviewed workflow ([workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md)).
- Lists where each record needs individual judgment and inputs (use a sequential "review next" flow instead).
- Very small lists where row actions suffice.

## Core Principles
1. Selection is explicit, visible, and counted ("24 selected" / "All 3,218 matching selected").
2. Two selection modes: `ids` (on-page picks) and `query` (all matching the current filters, minus exclusions). Never materialize thousands of IDs in the client.
3. The server re-evaluates the query at execution time and authorizes each affected record; the client selection is a request, not a grant.
4. Communicate scope before destructive actions: count, filter summary, and consequence.
5. Long-running work becomes a job with progress, cancel, and a results report; the UI never blocks on it.
6. Partial success is normal: report succeeded, skipped (no permission / invalid state), and failed with reasons.
7. Prefer undo (soft delete, reversible change set) over confirmation dialogs for reversible actions.

## Best Practices
- When selection is non-empty, a batch action bar replaces or overlays the table toolbar (Carbon `TableBatchActions` pattern) showing count, primary actions, overflow menu, and "Cancel"/"Clear selection".
- Promote 2–3 most common actions as buttons; put the rest in a "More actions" menu (Polaris index table promoted bulk actions pattern).
- Header checkbox selects the visible page; then offer an inline banner: "All 50 on this page are selected. Select all 3,218 matching?" and the reverse "Clear selection".
- Disable (with explanation) or hide actions not applicable to the whole selection; show "12 of 24 can be archived" when mixed.
- Selection clears on filter or sort change in `query` mode (scope changed); in `ids` mode, either clear or keep with a visible "selected items hidden by filter" note. Pick one rule and apply it consistently.
- Keep selection across pagination in `ids` mode, capped (e.g., 500); beyond the cap, suggest "select all matching".
- Confirmation for destructive actions states the exact number and requires typing the count or a keyword only for irreversible, very large operations.
- Show an undo toast for reversible actions ("Archived 24 invoices. Undo") with enough time (at least ~10 seconds) and keyboard reachability.
- Jobs: toast "Updating 3,218 tickets…" with a link to a job status panel; notify on completion with a summary.

## Implementation Guidance

### Selection model
```ts
// lib/bulk/selection.ts
import type { FilterGroup } from '@/lib/filters/model';

export type Selection =
  | { mode: 'ids'; ids: string[] }                                        // explicit picks, capped
  | { mode: 'query'; filters: FilterGroup | null; q?: string; excludedIds: string[]; expectedCount: number };

export type BulkRequest<A extends string, P> = {
  resource: 'invoice' | 'ticket';
  action: A;
  selection: Selection;
  params: P;
  idempotencyKey: string; // crypto.randomUUID() per user intent
};

export type BulkResult = {
  jobId?: string;                // present when queued
  succeeded: number;
  skipped: { id: string; reason: 'forbidden' | 'invalid_state' | 'not_found' }[];
  failed: { id: string; message: string }[];
  undoToken?: string;
};
```

### Client selection hook (TanStack Table v9 compatible)
```tsx
'use client';
import { useCallback, useState } from 'react';
import type { Selection } from '@/lib/bulk/selection';
import type { FilterGroup } from '@/lib/filters/model';

const MAX_IDS = 500;

export function useBulkSelection(pageIds: string[], total: number, filterKey: string) {
  const [sel, setSel] = useState<Selection>({ mode: 'ids', ids: [] });
  const [key, setKey] = useState(filterKey);
  if (key !== filterKey) { setKey(filterKey); setSel({ mode: 'ids', ids: [] }); } // reset on scope change

  const isSelected = (id: string) =>
    sel.mode === 'ids' ? sel.ids.includes(id) : !sel.excludedIds.includes(id);

  const toggle = useCallback((id: string) => setSel((s) => {
    if (s.mode === 'query') {
      const ex = s.excludedIds.includes(id) ? s.excludedIds.filter((x) => x !== id) : [...s.excludedIds, id];
      return { ...s, excludedIds: ex };
    }
    const ids = s.ids.includes(id) ? s.ids.filter((x) => x !== id) : [...s.ids, id];
    return { mode: 'ids', ids: ids.slice(0, MAX_IDS) };
  }), []);

  const count = sel.mode === 'ids' ? sel.ids.length : total - sel.excludedIds.length;
  const pageState: 'none' | 'some' | 'all' =
    pageIds.every(isSelected) && pageIds.length ? 'all' : pageIds.some(isSelected) ? 'some' : 'none';

  return {
    sel, count, isSelected, toggle, pageState,
    selectPage: () => setSel((s) => ({ mode: 'ids', ids: Array.from(new Set([...(s.mode === 'ids' ? s.ids : []), ...pageIds])).slice(0, MAX_IDS) })),
    selectAllMatching: (filters: FilterGroup | null, q?: string) =>
      setSel({ mode: 'query', filters, q, excludedIds: [], expectedCount: total }),
    clear: () => setSel({ mode: 'ids', ids: [] }),
  };
}
```
If you use TanStack Table's row selection feature for on-page checkboxes, keep the cross-page/query semantics in your own state as above; the table only knows the current page.

### Server Action: authorize, re-query, execute or enqueue
```ts
// app/(admin)/tickets/actions.ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { bulkAssignTickets } from '@/data/tickets-bulk';

const Input = z.object({
  action: z.literal('assign'),
  params: z.object({ teamId: z.string().uuid() }),
  idempotencyKey: z.string().uuid(),
  selection: z.discriminatedUnion('mode', [
    z.object({ mode: z.literal('ids'), ids: z.array(z.string().uuid()).min(1).max(500) }),
    z.object({
      mode: z.literal('query'), filters: z.unknown(), q: z.string().max(200).optional(),
      excludedIds: z.array(z.string().uuid()).max(500), expectedCount: z.number().int().nonnegative(),
    }),
  ]),
});

export async function assignTicketsAction(raw: unknown) {
  const input = Input.safeParse(raw);
  if (!input.success) return { ok: false as const, error: 'Invalid request' };
  const result = await bulkAssignTickets(input.data); // DAL: auth, tenant, compile filters, per-row authz
  revalidatePath('/tickets');
  return { ok: true as const, result };
}
```
```ts
// data/tickets-bulk.ts
import 'server-only';
import { requireUser, canOn } from '@/data/auth';
import { compile } from '@/data/filters/compile';

const SYNC_LIMIT = 200;

export async function bulkAssignTickets(input: { selection: any; params: { teamId: string }; idempotencyKey: string }) {
  const user = await requireUser();
  if (await jobs.exists(input.idempotencyKey)) return jobs.resultFor(input.idempotencyKey);

  const where = input.selection.mode === 'ids'
    ? { tenantId: user.tenantId, id: { in: input.selection.ids } }
    : { AND: [{ tenantId: user.tenantId }, compile(input.selection.filters, user), { id: { notIn: input.selection.excludedIds } }] };

  const count = await db.ticket.count({ where });
  if (input.selection.mode === 'query' && Math.abs(count - input.selection.expectedCount) > 0) {
    // Scope drifted since the user confirmed; surface it rather than silently acting on a different set.
    return { succeeded: 0, skipped: [], failed: [], drift: { expected: input.selection.expectedCount, actual: count } };
  }
  if (count > SYNC_LIMIT) {
    const jobId = await jobs.enqueue('tickets.assign', { where, params: input.params, userId: user.id }, input.idempotencyKey);
    return { jobId, succeeded: 0, skipped: [], failed: [] };
  }
  const rows = await db.ticket.findMany({ where, select: { id: true, status: true, assigneeTeamId: true } });
  const skipped: { id: string; reason: 'forbidden' | 'invalid_state' }[] = [];
  const allowed = rows.filter((r) => {
    if (!canOn(user, 'assign', r)) { skipped.push({ id: r.id, reason: 'forbidden' }); return false; }
    if (r.status === 'closed') { skipped.push({ id: r.id, reason: 'invalid_state' }); return false; }
    return true;
  });
  await db.$transaction([
    db.ticket.updateMany({ where: { id: { in: allowed.map((r) => r.id) } }, data: { assigneeTeamId: input.params.teamId } }),
    db.auditLog.create({ data: { actorId: user.id, action: 'ticket.bulk_assign', count: allowed.length, meta: { before: rows } } }),
  ]);
  return { succeeded: allowed.length, skipped, failed: [], undoToken: await undo.store(user.id, rows) };
}
```
Whether drift should block or just warn depends on the action; destructive actions should block and re-confirm.

## Recommended Workflow
1. List bulk actions per resource; classify reversible vs irreversible, sync vs job, and required permissions.
2. Define the selection model and request/result types; reuse the list filter model for `query` mode.
3. Implement the DAL bulk function: authn, tenant scope, compile filters, per-record authz and state checks, audit log, idempotency.
4. Add job infrastructure for large sets (queue, progress, cancel, result report).
5. Build UI: checkboxes, header tri-state, select-all-matching banner, batch action bar, confirmation, undo toast, job panel.
6. Wire announcements and focus management.
7. Test drift, partial failures, forbidden rows, retries, and undo.

## Patterns
- **Batch action bar**: `[✓ 24 selected] [Assign] [Change status] [More ▾] ........ [Clear selection]`; appears in place of the toolbar, same height to avoid layout shift.
- **Select-all banner**: "All 50 on this page selected. Select all 3,218 matching this filter" → "All 3,218 selected. Clear selection".
- **Bulk edit form**: side panel with only the fields being changed; each field has "Leave unchanged" default; preview "This will change Owner on 24 records".
- **Result summary**: "22 updated, 2 skipped (no permission)"; link "View skipped" filters the list to those IDs.
- **Job panel**: progress bar with processed/total, cancel, and download of failures CSV.
- **Undo**: server stores a change set (previous values) keyed by token with TTL; "Undo" calls an action that re-authorizes and restores.

## Anti-Patterns
- **Sending 10,000 IDs from the client**: payload limits, stale lists, easy tampering. Fix: `query` mode with exclusions.
- **Trusting client-provided IDs without per-row authz**: IDOR across records or tenants. Fix: re-query with tenant scope and check each record.
- **"Select all" that silently means only the current page**: users think they acted on everything. Fix: explicit banner distinguishing page vs all matching.
- **Blocking modal spinner for minutes**: timeouts and lost work. Fix: background job with progress and notification.
- **All-or-nothing failure message** ("Something went wrong"): users cannot recover. Fix: per-record outcome report.
- **No idempotency**: double-clicks run twice. Fix: idempotency key per intent; disable button while pending.
- **Confirmation dialogs for every reversible action**: dialog fatigue. Fix: undo toast; confirm only irreversible or very large actions.
- **Keeping stale selection after filters change in query mode**: acts on the wrong set. Fix: reset or detect drift.

## Accessibility
- Row checkboxes have accessible names referencing the record ("Select ticket T-1042"); header checkbox "Select all on this page" with `indeterminate` state reflected (native `indeterminate` property, exposed as mixed).
- Announce selection count changes and action results via a polite live region ("24 selected", "22 updated, 2 skipped") (WCAG 4.1.3).
- When the batch bar appears, do not move focus automatically; ensure it is next in tab order after the table header or reachable via a skip shortcut.
- After an action removes rows, move focus to a stable element (the table heading or the next row), not the body.
- Undo toasts must be reachable by keyboard and not disappear while focused or hovered (WCAG 2.2.1 timing).
- Confirmation dialogs follow [accessible-dialogs](../accessible-dialogs/Skill.md).
- Shift+click range selection needs a keyboard equivalent (Shift+Space on focused rows, or "Select range" in the menu).

## Responsive Design
- Mobile: long-press or an "Select" mode toggle enables checkboxes; the batch bar docks at the bottom with 1–2 actions and an overflow sheet.
- Keep the selection count visible while scrolling (sticky bar).
- Avoid hover-only checkboxes on touch devices.

## Performance
- Use `updateMany`/set-based SQL for homogeneous changes; per-row logic in batches (e.g., 500) inside jobs.
- Stream job progress via polling a status endpoint or SSE; throttle UI updates.
- Keep selection state as a `Set` or small arrays; avoid re-rendering all rows on each toggle (memoize rows, subscribe to selection per row).

## Security
- Treat every bulk request as untrusted: Zod schema, caps on ID arrays and exclusions, compiled filters with tenant scope at the root.
- Authorize the action type and every affected record server-side; UI disabling is advisory.
- Write audit log entries with actor, action, count, filter snapshot, and affected IDs or change set ([audit-log-interfaces](../audit-log-interfaces/Skill.md)).
- Rate-limit bulk endpoints; require re-authentication or step-up for extremely destructive operations if policy demands.
- Bulk exports enforce field-level permissions and escape formulas.

## Testing
- Unit: selection reducer (page select, exclusions, cap, reset on filter change).
- DAL integration: cross-tenant IDs are skipped, forbidden rows reported, closed rows skipped, idempotent replays return the same result.
- Drift test: insert matching rows between selection and execution; destructive actions refuse.
- E2E (Playwright): select page, select all matching, run action, verify toast counts, undo, and audit entry.
- Accessibility: screen reader announces selection and results; keyboard-only selection flow.

## Tooling
- TanStack Table v9 row selection feature for on-page checkbox state (check feature name in current docs), or grid built-ins (AG Grid, MUI X) for grid screens.
- Job queue of your platform (e.g., database-backed queue, cloud queue); status exposed through a route handler.
- `zod` for request validation.
- Toast library such as Sonner ([small-ui-primitives-vaul-sonner-cmdk](../small-ui-primitives-vaul-sonner-cmdk/Skill.md)).

## Framework Notes
- **Next.js (App Router)**: bulk mutations are Server Actions calling a `server-only` DAL; use `useActionState` or `useTransition` for pending state; `revalidatePath`/`revalidateTag` after sync completion. Job status via a route handler polled with `useSWR`/TanStack Query or SSE. Pass the current filter model (from nuqs) into the action for `query` mode.
- **React (Vite SPA)**: POST to a bulk endpoint with the same request shape; TanStack Query mutation with `onSuccess` invalidation; the API performs identical authz and job orchestration.

## AI Agent Guidance
- Do: implement both selection modes, the select-all-matching banner, per-record authz, partial result reporting, idempotency, and audit logging.
- Do: reuse the list's filter compiler for `query` mode.
- Don't: send all IDs for "select all"; don't rely on disabled buttons for permissions; don't show a generic error for partial failures.
- Before done: test with a user lacking permission on some rows, a cross-tenant ID injection, a double submit, and a filter change mid-selection.

## Examples
Batch action bar:
```tsx
'use client';
import { useTransition } from 'react';
import { assignTicketsAction } from './actions';
import type { Selection } from '@/lib/bulk/selection';

export function BatchBar({ selection, count, onClear, onDone }: {
  selection: Selection; count: number; onClear: () => void; onDone: (msg: string) => void;
}) {
  const [pending, start] = useTransition();
  if (count === 0) return null;
  const assign = (teamId: string) => start(async () => {
    const res = await assignTicketsAction({ action: 'assign', params: { teamId }, selection, idempotencyKey: crypto.randomUUID() });
    if (!res.ok) return onDone(res.error);
    const r = res.result;
    onDone(r.jobId ? `Assigning ${count} tickets in the background` : `${r.succeeded} updated, ${r.skipped.length} skipped`);
  });
  return (
    <div role="toolbar" aria-label="Bulk actions" className="batch-bar">
      <span aria-live="polite">{count.toLocaleString()} selected</span>
      <button type="button" disabled={pending} onClick={() => assign('team-b-uuid')}>Assign to Team B</button>
      <button type="button" onClick={onClear}>Clear selection</button>
    </div>
  );
}
```

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — list and selection columns
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — filter model reused in query mode
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — confirm vs undo
- [toasts-and-notifications](../toasts-and-notifications/Skill.md) — result and undo toasts
- [optimistic-ui](../optimistic-ui/Skill.md) — immediate feedback for small sets
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — recording bulk changes
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — per-record authorization
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — mutation mechanics
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — announcing counts

## Sources
- [Carbon DataTable (React source docs)](https://github.com/carbon-design-system/carbon/tree/main/packages/react/src/components/DataTable) — Official design system — toolbar plus `TableBatchActions`, select all, selection modes
- [NN/g: Data Tables](https://www.nngroup.com/articles/data-tables/) — Research — batch actions with checkboxes vs single-row actions
- [Shopify Polaris](https://shopify.dev/docs/api/polaris) — Official — promoted bulk actions / select-all-across-pages concepts (Polaris React deprecated; now web components)
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — per-action authz, IDOR, minimal return values
- [W3C APG Grid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — selection keys (Shift+Space, Ctrl+A)

## License / Usage Notes
Guidance summarized from design systems and docs; code original. Zod, TanStack Table: MIT.

## Quality Tier
A — selection and security model verified against Next.js security docs and design-system patterns; job/undo specifics are established practice rather than a single cited spec.

## Status
Active

## Last Verified
2026-09-15
