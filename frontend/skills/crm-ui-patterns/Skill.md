# CRM UI Patterns

## Summary
Interface patterns for customer relationship management apps built with React + Next.js: record pages for accounts, contacts, leads, and opportunities; list views with saved filters; pipeline boards; activity timelines; inline editing; duplicate detection and merge; global search; bulk ownership reassignment. The goal is fast context for sales and support users, with correct server-side enforcement of record visibility and ownership.

## Category
Enterprise UI

## Subcategories
Record pages, highlights panel, related lists, activity timeline, stage path, pipeline kanban, list views, inline edit, duplicate management, global search, ownership and territories

## Problem It Solves
CRM users switch between dozens of records a day while on calls or in meetings. Bad CRM UIs bury key facts, force full-page edit modes for one field, lose context on navigation, create duplicates, and leak records across teams. These patterns keep the essentials visible, make updates one-step, and keep sharing rules on the server.

## When To Use
- Building or customizing sales, support, partner, or customer success tools.
- Any "entity with relationships and activity history" app (recruiting ATS, donor management, property management).
- Pipeline-driven processes with stages and forecasts.

## When Not To Use
- Transactional document processing with posting semantics. See `erp-ui-patterns`.
- Pure ticket queues with SLA-driven routing. Combine `workflow-and-approval-ui` with `enterprise-data-tables`.
- Marketing sites or customer-facing portals.

## Core Principles
1. **Record page = identity + next action + context.** Highlights at the top, stage path, activity in the center, related data at the side.
2. **Edit where you read.** Inline edit single fields. Reserve full edit forms for creation and bulk changes.
3. **Activity is the heartbeat.** Calls, emails, meetings, notes, and field changes appear in one filterable timeline.
4. **Prevent duplicates at entry, resolve them safely later.** Match while typing, and merge with explicit field-by-field choices.
5. **Visibility rules live on the server.** Ownership, teams, territories, and sharing apply to lists, search, related lists, exports, and counts.
6. **Everything is findable.** Global search across objects with keyboard access, plus list views with saved filters in the URL.

## Best Practices
- **Highlights panel**: record name, type icon, 4–7 key fields (owner, stage, amount, close date, last activity), and primary actions (Log call, New task, Email). Follow/unfollow.
- **Path / stage indicator**: horizontal stages with the current one marked. Selecting a stage shows guidance and required fields ("Key fields for Negotiation"). Changing stage runs through the server's validation. Salesforce Lightning's "path" and "highlights panel" concepts are the inspiration here; the SLDS docs could not be fetched during research, so verify specifics against current SLDS guidance.
- **Related lists**: show the first 5–10 rows with a count ("Contacts (23)") and a "View all" link to a filtered list view. Load them lazily.
- **Activity timeline**: reverse-chronological, grouped by "Upcoming & overdue" then by month. Filter by type. Composer tabs at the top (Note, Call, Email, Task).
- **List views**: named, shareable (private/team/all), stored on the server as a filter + columns + sort definition. The active state is mirrored in the URL. Show a count and "last refreshed".
- **Inline edit**: a pencil appears on hover and focus; double-click or Enter enters edit mode. Save on Enter/blur, cancel on Escape. Show the saving state and roll back on error. Check field-level permissions on the server.
- **Duplicate detection**: on create, debounce a match query on email/domain/phone/name. Show a non-blocking "Possible duplicates (2)" panel with links. Hard-block only on exact unique keys.
- **Merge**: pick a master record, then choose per field (radio per row), preview related record re-parenting, and confirm. The server merges in a transaction and writes an audit event. Make it undoable only if the backend supports it; otherwise say it's permanent.
- **Bulk reassignment**: select rows -> "Change owner" -> choose user -> options (also move open tasks, notify new owner). The server validates each record and returns per-record results.
- **Global search**: Cmd/Ctrl+K palette with object-type groups and recent records. Results respect sharing rules.

## Implementation Guidance

### Record page layout (App Router)
```
app/(crm)/accounts/page.tsx                       // list view (Server Component, URL filters)
app/(crm)/accounts/[id]/layout.tsx                // highlights + path (shared across tabs)
app/(crm)/accounts/[id]/page.tsx                  // activity timeline + details
app/(crm)/accounts/[id]/related/[rel]/page.tsx    // "View all" related list
app/(crm)/@modal/(.)accounts/[id]/page.tsx        // intercepting route: quick view from lists
app/(crm)/accounts/actions.ts                     // updateField, logActivity, changeOwner, merge
```

### Inline field update with field-level authorization
```ts
// app/(crm)/accounts/actions.ts
'use server';
import { z } from 'zod';
import { updateAccountField } from '@/data/accounts';

const FIELD_SCHEMAS = {
  phone: z.string().trim().max(40),
  industry: z.enum(['software', 'manufacturing', 'retail', 'other']),
  annualRevenueMinor: z.string().regex(/^\d+$/),
} as const;
type EditableField = keyof typeof FIELD_SCHEMAS;

export async function updateFieldAction(input: { id: string; field: EditableField; value: unknown; version: number }) {
  const schema = FIELD_SCHEMAS[input.field];
  if (!schema) return { ok: false as const, error: 'Unknown field' };
  const parsed = schema.safeParse(input.value);
  if (!parsed.success) return { ok: false as const, error: parsed.error.issues[0]?.message ?? 'Invalid' };
  // DAL: session, record visibility (owner/team/territory/sharing), field-level edit permission, version check, audit event
  return updateAccountField(input.id, input.field, parsed.data, input.version);
}
```

```tsx
'use client';
import { useOptimistic, useRef, useState, useTransition } from 'react';
import { updateFieldAction } from '../actions';

export function InlineField({ id, field, label, value, version, canEdit }: {
  id: string; field: 'phone'; label: string; value: string; version: number; canEdit: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [optimistic, setOptimistic] = useOptimistic(value);
  const [pending, start] = useTransition();
  const btn = useRef<HTMLButtonElement>(null);

  function commit(next: string) {
    setEditing(false);
    if (next === value) return btn.current?.focus();
    start(async () => {
      setOptimistic(next);
      const r = await updateFieldAction({ id, field, value: next, version });
      if (!r.ok) setError(r.error);
      btn.current?.focus();
    });
  }

  if (editing) {
    return (
      <input
        autoFocus
        aria-label={label}
        defaultValue={optimistic}
        onKeyDown={(e) => {
          if (e.key === 'Enter') commit(e.currentTarget.value);
          if (e.key === 'Escape') { setEditing(false); btn.current?.focus(); }
        }}
        onBlur={(e) => commit(e.currentTarget.value)}
      />
    );
  }
  return (
    <div>
      <dt>{label}</dt>
      <dd className="flex items-center gap-2">
        <span aria-busy={pending}>{optimistic || '—'}</span>
        {canEdit && <button ref={btn} type="button" onClick={() => setEditing(true)} aria-label={`Edit ${label}`}>✎</button>}
      </dd>
      {error && <p role="alert" className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
```
`canEdit` is a UX hint computed server-side. The action re-checks it.

### Pipeline board
- Columns = stages. Cards show name, amount, close date, owner avatar, and days in stage. Column headers show count and summed amount (server-computed).
- Drag with dnd-kit (`@dnd-kit/core` + `@dnd-kit/sortable`, stable and MIT; `@dnd-kit/react` is at 0.x, so treat it as pre-1.0). Dropping calls a `changeStage` Server Action. Required fields for the target stage open a dialog before committing.
- Always provide a non-drag alternative: a "Move to stage" menu on each card (WCAG 2.5.7 Dragging Movements).

### Duplicate matching contract
```ts
type DuplicateQuery = { object: 'contact' | 'account'; email?: string; domain?: string; name?: string; phone?: string };
type DuplicateMatch = { id: string; displayName: string; score: number; matchedOn: Array<'email' | 'domain' | 'name' | 'phone'>; canView: boolean };
// Server returns only records the user can see. For invisible matches, return a count only ("1 matching record you don't have access to").
```

## Recommended Workflow
1. Define objects, relationships, and the sharing model (owner, team, territory, public read) with the business.
2. Build the server-side visibility filter once in the DAL and apply it to every query (lists, search, related lists, counts, exports).
3. Build the list view with URL state and saved views. Add bulk owner change.
4. Build the record layout: highlights + path + timeline + related lists (Suspense per panel).
5. Add inline editing with field-level permissions and version checks.
6. Add activity composers and timeline filters.
7. Add duplicate detection on create, then the merge flow.
8. Add the pipeline board with a keyboard alternative, and global search.
9. Test visibility leaks, concurrent edits, and keyboard/screen reader flows.

## Patterns
- **Quick view**: open a record in a side sheet from any list via an intercepting route. Full-page on refresh.
- **Composer tabs**: Note / Call / Email / Task share the same "related to" and "due" fields. Submitting prepends to the timeline optimistically.
- **Stage guidance drawer**: per-stage checklist and required fields, configured server-side.
- **Recently viewed**: a per-user MRU list stored on the server, shown in search and the home page.
- **"View as list" / "View as board" toggle** on the same URL filter state (`?view=board`).
- **Field history**: a hover or button on a field shows its last changes (from the audit trail).

## Anti-Patterns
- **Full edit mode to change one field.** Slow and loses scroll position. Fix: inline edit with Enter/Escape semantics.
- **Hiding records only in the UI.** Search/export/API still leaks them. Fix: a DAL visibility filter on every query path.
- **Drag-only stage changes.** Excludes keyboard and motor-impaired users. Fix: "Move to" menu plus keyboard sensor.
- **Blocking duplicates on fuzzy matches.** Users create junk variations to bypass. Fix: warn on fuzzy, block only on exact unique keys.
- **Merge without a field-level choice.** Silent data loss. Fix: side-by-side comparison with explicit choices and a preview.
- **Related lists all loading eagerly.** Slow record pages. Fix: lazy/Suspense panels with counts.
- **Timeline mixing server time zones.** Fix: store UTC, render in the user's time zone with an absolute time on hover/focus.

## Accessibility
- Highlights use `<dl>`. The path is an `<ol>` with `aria-current="step"`. Stage names are text.
- Inline edit triggers are real buttons with accessible names ("Edit Phone"). Return focus to the trigger after save/cancel. Announce save errors with `role="alert"`.
- Timeline: a list (`<ol>`) of `<article>`s with headings. Filter changes announce the result count via `role="status"`.
- Kanban: a keyboard sensor with screen reader announcements (dnd-kit provides live-region announcements), plus a menu alternative.
- Global search palette: combobox/listbox semantics, `Escape` closes, focus is restored.
- Avatars have `alt` text with the owner name, or are decorative if the name is shown next to them.

## Responsive Design
- Desktop: 3-zone record layout (details | timeline | related). Tablet: 2 zones with related lists as tabs. Mobile: highlights + action bar + tabs (Activity, Details, Related).
- Pipeline board on mobile: one column at a time with a stage selector, or switch to a list grouped by stage.
- Put call/email actions (tel:, mailto:) as primary on mobile.

## Performance
- Server Components for the record shell. Suspense boundaries for timeline and each related list.
- Paginate the timeline with a cursor ("Load more"). Virtualize very long ones.
- Debounce duplicate checks (300–500ms) and search. Cancel stale requests.
- Pipeline column sums and counts come from aggregate queries, not by loading all cards.

## Security
- Record-level (owner/team/territory/sharing) and field-level permissions are enforced in the DAL. DTOs omit fields the viewer can't read.
- Search, typeahead, duplicate check, related counts, and exports all apply the same visibility filter. Counts can leak existence; decide deliberately.
- Bulk owner change and merge are privileged. Validate per record, audit, and rate-limit.
- Email/notes content is untrusted HTML. Sanitize before rendering, or render as text.
- PII: mask sensitive fields by default where policy requires, and log reveal events.

## Testing
- Integration: visibility matrix (owner, same team, other team, admin) across list, search, record, related list, and export endpoints.
- Unit: field schemas, duplicate scoring thresholds, stage required-field rules.
- E2E (Playwright): inline edit via keyboard (Enter/Escape), stage move via menu and via drag, merge two contacts and verify re-parented activities, bulk owner change with partial failures.
- Accessibility: axe plus screen reader smoke test of inline edit and the pipeline board.

## Tooling
- dnd-kit (`@dnd-kit/core`, `@dnd-kit/sortable`; MIT) for pipeline boards. Atlassian Pragmatic drag and drop is an alternative.
- TanStack Table v9 (`useTable`, `tableFeatures`) or AG Grid / MUI X for list views.
- nuqs 2.x for list view URL state. cmdk-style palettes for global search.
- React Hook Form + Zod for create forms. Zod on the server for inline field updates.
- A search backend (Postgres full-text, OpenSearch, Typesense, Algolia) with security filters applied on the server. Check vendor docs.

## Framework Notes
- **Next.js (App Router, 16)**: record `layout.tsx` loads the highlights DTO once. Child routes stream panels. Intercepting + parallel routes (`@modal`) provide quick views. Server Actions + `useOptimistic` handle inline edits. `revalidatePath` on the record path after mutations.
- **React (Vite SPA)**: TanStack Router/React Router with nested routes for the record shell. TanStack Query for per-panel queries and optimistic updates (`onMutate` rollback). The backend API enforces sharing rules.

## AI Agent Guidance
- Do: put visibility filtering in one DAL function and use it for every query path, including search and counts.
- Do: implement inline edit with an accessible trigger, Enter/Escape, focus return, and error rollback.
- Do: provide a non-drag alternative for any pipeline drag.
- Don't: pass full DB records to client components; send DTOs with permitted fields only.
- Don't: auto-merge duplicates.
- Verify before done: a user from another team cannot see the record via list, search, URL, or export; inline edit works keyboard-only; stage change via menu works; merge preview matches the result.

## Examples
```tsx
// app/(crm)/accounts/[id]/layout.tsx
import { Suspense } from 'react';
import { getAccountHighlights } from '@/data/accounts';

export default async function AccountLayout({ params, children }: { params: Promise<{ id: string }>; children: React.ReactNode }) {
  const { id } = await params;
  const a = await getAccountHighlights(id); // visibility-checked DTO; notFound() inside if not visible
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_22rem]">
      <header className="lg:col-span-2 rounded border p-4" aria-labelledby="acct-name">
        <h1 id="acct-name" className="text-xl font-semibold">{a.name}</h1>
        <dl className="mt-2 grid grid-cols-2 gap-2 text-sm md:grid-cols-5">
          <div><dt>Owner</dt><dd>{a.ownerName}</dd></div>
          <div><dt>Industry</dt><dd>{a.industryLabel}</dd></div>
          <div><dt>Open pipeline</dt><dd className="tabular-nums">{a.openPipelineFormatted}</dd></div>
          <div><dt>Last activity</dt><dd>{a.lastActivityRelative}</dd></div>
          <div><dt>Tier</dt><dd>{a.tier}</dd></div>
        </dl>
      </header>
      <main>{children}</main>
      <aside aria-label="Related">
        <Suspense fallback={<p>Loading contacts…</p>}>{/* <RelatedContacts accountId={id} /> */}</Suspense>
        <Suspense fallback={<p>Loading opportunities…</p>}>{/* <RelatedOpportunities accountId={id} /> */}</Suspense>
      </aside>
    </div>
  );
}
```

## Related Skills
- [kanban-boards](../kanban-boards/Skill.md) — pipeline boards
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — list views
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — saved list view filters
- [bulk-actions](../bulk-actions/Skill.md) — bulk owner reassignment
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — record/field-level permissions
- [master-detail-layouts](../master-detail-layouts/Skill.md) — quick view panels
- [command-palette](../command-palette/Skill.md) — global search
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — field history
- [optimistic-ui](../optimistic-ui/Skill.md) — inline edit feedback
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md) — intercepting/parallel routes

## Sources
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, DTO filtering, IDOR checks in Server Actions
- [NN/g data tables](https://www.nngroup.com/articles/data-tables/) — Official (research) — find/compare/view-edit/act tasks, nonmodal side panels for editing
- [NN/g complex applications](https://www.nngroup.com/articles/complex-application-design/) — Official (research) — access to secondary info without leaving the screen
- [dnd-kit repository](https://github.com/clauderic/dnd-kit) — Open Source — packages, keyboard sensor, screen reader announcements, MIT
- [@dnd-kit/react on npm](https://www.npmjs.com/package/@dnd-kit/react) — Open Source — 0.5.0 pre-1.0 status
- [Salesforce Lightning Design System](https://www.lightningdesignsystem.com/) — Official — path/highlights/related list concepts; page content not retrievable during research, so verify details
- [nuqs](https://nuqs.dev/docs/server-side) — Official — URL-synced list view state

## License / Usage Notes
Guidance is original and summarized. SLDS concepts are referenced by name only; check Salesforce's terms before reusing SLDS assets. dnd-kit, nuqs, Zod, and Next.js are MIT.

## Quality Tier
B — security and interaction guidance verified against official docs; CRM-specific layout conventions draw on SLDS concepts that could not be re-verified this pass.

## Status
Active

## Last Verified
2026-09-15
