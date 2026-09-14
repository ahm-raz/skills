# Audit Log Interfaces

## Summary
How to design and build audit log UIs for enterprise apps: the org-wide audit log page, per-record "History" tabs, field-level diffs, actor and impersonation display, filtering by actor, action, target and time, export for compliance, and the backend event model that makes the UI trustworthy (append-only, server-written, tenant-scoped).

## Category
Enterprise UI

## Subcategories
Audit trails, activity history, change diffs, compliance export, event schema, impersonation logging, retention

## Problem It Solves
Security teams, admins and auditors need to answer "who did what, to which record, when, from where, and what changed". Ad-hoc logs (console lines, `updatedBy` columns) can't answer that. Poor UIs (unfilterable walls of JSON, local timezones without offsets, missing actor context) make investigations slow and exports useless for compliance reviews.

## When To Use
- B2B SaaS with admin roles, SOC 2/ISO 27001-type customer requirements, regulated domains (finance, healthcare), approval workflows.
- Any privileged action: role changes, permission grants, exports, deletes, settings changes, API key creation, impersonation.

## When Not To Use
- Debug or observability logging (use tracing and log tooling instead; different audience and retention).
- End-user social "activity feeds". Related, but those optimize for engagement, not evidentiary completeness (though a record history tab can serve both).

## Core Principles
1. **Written server-side, in the same transaction as the change**, or reliably via an outbox. Never from the client.
2. **Append-only.** No edit or delete in the UI; retention purges are system jobs, and are themselves logged.
3. **Structured events** with a stable schema (actor, action, target, tenant, time, context, changes), not free text.
4. **Tenant-scoped and permission-gated.** Viewing the audit log is itself a privileged permission.
5. **Unambiguous time.** Store UTC; display in the viewer's timezone with the offset, plus exact ISO on hover or in the details.
6. **Human-readable first, raw second.** A summary sentence, then a field diff, then an expandable raw JSON view.

## Best Practices
- **Event schema:**
  - `id`, `occurredAt` (UTC), `tenantId`
  - `actor { type: user|api_key|system|support, id, displayName, email? }`
  - `onBehalfOf` (impersonation)
  - `action` (`invoice.voided`; past tense, dotted namespace)
  - `target { type, id, displayName }`
  - `changes [{ field, before, after }]` (redact sensitive values)
  - `context { ip, userAgent, requestId, source: web|api|job }`
  - `result` (success/denied/failed)
- Snapshot display names at write time (a deleted user still reads "Jane Doe (deleted)").
- **Org-wide log page layout:** filter bar (date range with presets, actor combobox, action multi-select grouped by resource, target type/ID, result), a reverse-chronological table (Time, Actor, Action summary, Target, Source/IP), and a side panel with full details and diff.
- **Record History tab:** vertical timeline grouped by day, each entry "Jane changed Status from Open → Void" with a reason if captured. Include creates and deletes.
- Diffs: show changed fields only, before → after. Use a strikethrough and insertion treatment plus text labels (not color alone). Long text gets a word-level diff.
- Redact secrets and PII per policy (`"••••1234"`, "value hidden"). Say that the value is redacted rather than silently omitting it.
- Cursor-based pagination (logs are huge and append-heavy). Offer "Jump to date".
- Filters live in the URL (shareable investigations). Consider "Copy link to event".
- Export: CSV/JSON for the current filter, done asynchronously for large ranges (job + notification + expiring download link). Prevent CSV formula injection. Stream from a Route Handler.
- Show retention clearly ("Events are retained for 365 days on your plan").
- Log views of sensitive data and exports of the audit log itself.

## Implementation Guidance

### Decision table
| Need | Approach |
|---|---|
| < ~10M events/tenant, relational app | `audit_events` table, indexed `(tenant_id, occurred_at desc, id)`, plus indexes on actor and target |
| High volume or long retention | Append to a log store (ClickHouse, OpenSearch, BigQuery) via an outbox; the UI queries through an API |
| Tamper evidence required | Hash-chain events or WORM storage; show a "verified" indicator only if actually verified |
| Customer SIEM integration | Webhook or streaming export in addition to the UI |

### API contract (cursor pagination)
```ts
export interface AuditQuery {
  from?: string; to?: string;              // ISO 8601 UTC
  actorIds?: string[]; actions?: string[]; // allowlisted action names
  targetType?: string; targetId?: string;
  result?: 'success' | 'denied' | 'failed';
  cursor?: string | null; limit?: 50 | 100;
}
export interface AuditPage { events: AuditEventDTO[]; nextCursor: string | null }
```
The cursor encodes `(occurredAt, id)` for stable ordering under concurrent inserts. Avoid `COUNT(*)` on large logs: show "50+ results" or an estimate.

## Recommended Workflow
1. Define the action catalogue (which events, their names, which fields to diff and redact) with security and compliance stakeholders.
2. Implement `recordAudit()` in the DAL and call it inside the mutation transaction; add it to every privileged action.
3. Build the query API with tenant scoping, `audit:read` permission and cursor pagination.
4. Build the org-wide page: URL-synced filters (nuqs), table, details side panel.
5. Build the record History tab reusing the same DTO and renderer.
6. Add async export with a download link and audit-of-export.
7. Test completeness (each privileged action emits an event), scoping and redaction.

## Patterns

### Recording in the same transaction
```ts
// data/audit.ts
import 'server-only';
type Change = { field: string; before: unknown; after: unknown };
const REDACT = new Set(['password', 'apiKey', 'ssn']);

export function diff<T extends Record<string, unknown>>(before: T, after: Partial<T>): Change[] {
  return Object.keys(after)
    .filter((k) => JSON.stringify(before[k]) !== JSON.stringify(after[k]))
    .map((k) => REDACT.has(k) ? { field: k, before: '[redacted]', after: '[redacted]' } : { field: k, before: before[k], after: after[k] });
}

export async function recordAudit(tx: Tx, e: {
  tenantId: string; actor: { type: 'user' | 'api_key' | 'system' | 'support'; id: string; displayName: string };
  onBehalfOfId?: string; action: string; target: { type: string; id: string; displayName: string };
  changes?: Change[]; context: { ip?: string; userAgent?: string; requestId?: string; source: 'web' | 'api' | 'job' };
  result?: 'success' | 'denied' | 'failed';
}) {
  await tx.auditEvent.create({ data: { ...e, result: e.result ?? 'success', occurredAt: new Date() } });
}
```
```ts
// data/members.ts
export async function changeMemberRole(orgSlug: string, memberId: string, role: Role) {
  const t = await getTenantContext(orgSlug);
  authorize(t, 'update', 'Member');
  const h = await headers();
  await db.$transaction(async (tx) => {
    const m = await tx.membership.findFirstOrThrow({ where: { id: memberId, orgId: t.orgId } });
    await tx.membership.update({ where: { id: m.id }, data: { role } });
    await recordAudit(tx, {
      tenantId: t.orgId, actor: { type: 'user', id: t.userId, displayName: t.displayName },
      action: 'member.role_changed', target: { type: 'member', id: m.id, displayName: m.email },
      changes: diff({ role: m.role }, { role }),
      context: { ip: h.get('x-forwarded-for') ?? undefined, userAgent: h.get('user-agent') ?? undefined, source: 'web' },
    });
  });
}
```
Only trust `x-forwarded-for` behind a known proxy; configure it per your hosting platform.

### Human-readable summary renderer
```tsx
const verbs: Record<string, (e: AuditEventDTO) => string> = {
  'member.role_changed': (e) => `changed role of ${e.target.displayName} from ${e.changes?.[0]?.before} to ${e.changes?.[0]?.after}`,
  'invoice.voided': (e) => `voided invoice ${e.target.displayName}`,
};
export function summarize(e: AuditEventDTO) {
  return (verbs[e.action] ?? ((x) => `${x.action} on ${x.target.type} ${x.target.displayName}`))(e);
}
```

### Timestamp cell
```tsx
export function AuditTime({ iso, timeZone }: { iso: string; timeZone: string }) {
  const d = new Date(iso);
  const label = new Intl.DateTimeFormat('en', { dateStyle: 'medium', timeStyle: 'medium', timeZone, timeZoneName: 'short' }).format(d);
  return <time dateTime={iso} title={iso}>{label}</time>;
}
```
Pass the viewer's timezone from user settings to avoid SSR/client hydration mismatches.

## Anti-Patterns
- **Client calls `logEvent()` after a successful mutation.** Can be skipped, forged or lost. Fix: write server-side in the transaction.
- **Free-text messages only.** Unfilterable, can't be localized. Fix: a structured event plus a renderer.
- **Deleting audit events when the record is deleted** (cascade). Fix: no FK cascade; snapshot target names.
- **Local time without an offset.** Ambiguous across teams and DST. Fix: timezone name/offset plus ISO on hover.
- **Offset pagination with a total count on a massive log.** Slow and unstable. Fix: a cursor on `(occurredAt, id)`.
- **Dumping raw JSON as the primary view.** Fix: summary → diff → collapsible raw.
- **Logging secrets or full PII in `changes`.** Fix: redaction allowlist and denylist at write time.
- **Audit log readable by all members.** Fix: an `audit:read` permission; record-level history follows record read permission, with sensitive fields redacted.

## Accessibility
- The log table uses native table semantics (`<th scope="col">`). Timestamps use `<time dateTime>`.
- Diffs must not rely on red and green alone (WCAG 1.4.1). Use "Before"/"After" labels, `<del>`/`<ins>`, or visually hidden text.
- The details side panel is a labelled dialog or complementary region; restore focus to the row on close.
- Timeline entries in History tabs: a list (`<ol>`) with day headings. Relative times ("3h ago") also expose absolute time.
- Announce filter result updates politely ("Showing events for Jane Doe").

## Responsive Design
- On narrow screens, collapse table rows into entries showing summary, time and actor, with details in a full-screen sheet.
- The filter bar collapses into a "Filters (3)" button that opens a sheet. Active filters show as removable chips.
- Diffs stack vertically (before above after) below ~640px.

## Performance
- Composite indexes on `(tenant_id, occurred_at desc, id)`, plus `(tenant_id, actor_id, occurred_at)` and `(tenant_id, target_type, target_id, occurred_at)`.
- Cursor pagination with "Load more" or an infinite list plus virtualization for long timelines.
- Require a bounded default time range (e.g., last 7 days) to keep queries cheap.
- Large exports run as background jobs; stream CSV from a Route Handler for moderate sizes.

## Security
- Writes happen only in server code. There is no public "create audit event" endpoint for clients.
- Enforce append-only at the DB level (grant INSERT/SELECT only to the app role for the audit table), and log retention purges.
- Tenant scoping and the `audit:read` permission are enforced in the DAL; exports re-check both.
- Neutralize CSV formula injection (`=`, `+`, `-`, `@`, tab, CR prefixes) in exports. Papa Parse `unparse` supports `escapeFormulae`.
- Record impersonation (`actor=support`, `onBehalfOf`), failed or denied privileged attempts, and audit-log exports.
- IP and user agent are personal data in some jurisdictions; apply retention and access policy.

## Testing
- Completeness: a test per privileged action asserts exactly one event with the correct action, target and diff.
- Scoping: a member of org B can't query org A's events (list, detail, export).
- Redaction: sensitive fields never appear in stored `changes` or the API response.
- Cursor stability: insert events during pagination; no duplicates or skips.
- E2E: filter by actor and date → URL updated → reload → same results → open details → diff visible.
- Timezone rendering unit tests (DST boundaries).

## Tooling
- Storage: Postgres table (default); ClickHouse, OpenSearch or BigQuery for scale.
- URL filters: nuqs. Table: TanStack Table v9 (manual pagination). Long timelines: TanStack Virtual.
- CSV: Papa Parse `unparse` with `escapeFormulae` (MIT).
- Hosted audit logging (e.g., WorkOS Audit Logs, Retraced) exists; check current offerings and features.

## Framework Notes
- **Next.js:** the audit page is a Server Component reading URL filters (`searchParams` is a Promise) through a `server-only` DAL. The details panel can be an intercepting route (`@panel/(.)events/[id]`) so events are linkable. Export is a Route Handler streaming a `ReadableStream`. `recordAudit` is called inside Server Actions or DAL mutations, never from client code.
- **React (Vite SPA):** same UI with TanStack Query `useInfiniteQuery` on a cursor API. The backend owns event writes, and the SPA only reads.

## AI Agent Guidance
- Do:
  - Add `recordAudit` inside the same transaction for every privileged mutation you touch.
  - Define action names in a typed catalogue.
  - Implement redaction at write time.
  - Use cursor pagination and URL-synced filters.
- Don't:
  - Emit audit events from client components.
  - Cascade-delete audit rows.
  - Show red/green-only diffs.
- Verify before done:
  - Each privileged action produces an event (test).
  - Cross-tenant queries fail.
  - Timestamps show the timezone.
  - Exports escape formulas.
  - The audit page requires the `audit:read` permission.

## Examples

### Audit log page (RSC) with details link
```tsx
// app/[org]/settings/audit-log/page.tsx
import { createLoader, parseAsArrayOf, parseAsString, parseAsIsoDateTime } from 'nuqs/server';
import { listAuditEvents } from '@/data/audit-read';
import { AuditTable } from './audit-table';

const load = createLoader({
  from: parseAsIsoDateTime, to: parseAsIsoDateTime,
  actor: parseAsArrayOf(parseAsString).withDefault([]),
  action: parseAsArrayOf(parseAsString).withDefault([]),
  cursor: parseAsString,
});

export default async function AuditLogPage({ params, searchParams }: {
  params: Promise<{ org: string }>; searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { org } = await params;
  const q = await load(searchParams);
  const page = await listAuditEvents(org, {   // checks audit:read + tenant; clamps range; allowlists actions
    from: q.from?.toISOString(), to: q.to?.toISOString(), actorIds: q.actor, actions: q.action, cursor: q.cursor, limit: 50,
  });
  return (
    <main>
      <h1>Audit log</h1>
      <p>Events are retained per your plan. Times shown in your timezone.</p>
      <AuditTable events={page.events} nextCursor={page.nextCursor} />
    </main>
  );
}
```

### Field diff component
```tsx
export function FieldDiff({ changes }: { changes: { field: string; before: unknown; after: unknown }[] }) {
  return (
    <dl className="diff">
      {changes.map((c) => (
        <div key={c.field}>
          <dt>{c.field}</dt>
          <dd>
            <span className="sr-only">Before: </span><del>{String(c.before ?? '—')}</del>
            <span aria-hidden="true"> → </span>
            <span className="sr-only">After: </span><ins>{String(c.after ?? '—')}</ins>
          </dd>
        </div>
      ))}
    </dl>
  );
}
```

## Related Skills
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — `audit:read` and logging grants and denials
- [multi-tenant-ui](../multi-tenant-ui/Skill.md) — tenant scoping and impersonation banners
- [admin-panel-architecture](../admin-panel-architecture/Skill.md) — DAL and transaction placement
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — filter bar for actor, action and date
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — log table behavior
- [data-import-export-ui](../data-import-export-ui/Skill.md) — async export flows
- [master-detail-layouts](../master-detail-layouts/Skill.md) — event details side panel
- [workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md) — approval history timelines
- [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md) — date range filtering
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — shareable investigation URLs

## Sources
- [Next.js: How to think about data security](https://nextjs.org/docs/app/guides/data-security) — Official — server-only DAL, Server Actions as endpoints, auditing checklist
- [nuqs server-side docs](https://nuqs.dev/docs/server-side) — Official — `createLoader`, parsers for URL-synced filters
- [Papa Parse docs](https://www.papaparse.com/docs) — Open Source — `unparse`, `escapeFormulae` for CSV injection defense
- [NN/g: Data Tables](https://www.nngroup.com/articles/data-tables/) — Community (research) — find/compare tasks, nonmodal details panels
- [TanStack Table docs (v9)](https://github.com/TanStack/table/tree/main/docs) — Official — manual pagination for server-driven tables

## License / Usage Notes
Summarized guidance; code is original. The event schema and UI patterns are synthesized from common enterprise practice. There is no single authoritative audit-log UI standard, so validate retention and compliance requirements with your own compliance team. Papa Parse, nuqs and TanStack Table are MIT.

## Quality Tier
B — security and data-layer rules verified against official Next.js docs; event schema and UI patterns are well-established practice but not drawn from one authoritative design-system spec.

## Status
Active

## Last Verified
2026-09-15
