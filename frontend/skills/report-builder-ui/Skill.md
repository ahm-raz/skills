# Report Builder UI

## Summary
Building self-service report builders inside enterprise React + Next.js apps: users choose a data source, columns, filters, grouping, aggregations, and sort, preview results, then save, share, schedule, and export. The core is a declarative, versioned report definition compiled on the server against an allowlisted field catalog (a semantic layer), executed with the viewer's permissions, with limits and timeouts.

## Category
Enterprise UI

## Subcategories
Ad-hoc reporting, saved reports, column picker, group-by, aggregations, filter builder, pivot, scheduled reports, export, report sharing, semantic layer

## Problem It Solves
Operations and finance teams constantly ask engineers for "one more report." Hardcoded reports multiply; raw SQL consoles are unsafe; BI tools sit outside the product and ignore in-app permissions. An in-product report builder lets users answer their own questions within the app's security model, while protecting database performance and data boundaries.

## When To Use
- Multi-tenant SaaS or internal tools where users need custom tabular summaries (counts, sums, averages by dimension over time).
- Recurring exports/emails of the same data slice.
- When reports must respect in-app roles, tenants, and field-level permissions.

## When Not To Use
- Fixed KPI views: build a dashboard ([dashboard-design](../dashboard-design/Skill.md)).
- Only list filtering is needed: [advanced-filtering-ui](../advanced-filtering-ui/Skill.md).
- Data exploration across many warehouses by analysts: embed or integrate a dedicated BI tool instead.

## Core Principles
1. A report is data, not code: a versioned JSON definition (source, fields, filters, groups, measures, sort, limit, visualization).
2. Users pick from a curated field catalog with business names, types, and allowed aggregations; they never write SQL.
3. The server compiles definitions to parameterized queries through allowlists; tenant and row-level constraints wrap the user's query.
4. Reports run with the viewer's permissions (not the author's) unless an explicitly governed "run as" is configured and audited.
5. Every execution is bounded: row limits for preview, timeouts, cost estimates, and async execution for large exports.
6. Preview is fast and honest: sample-limited results with a clear "Preview of first 500 rows" label.
7. Progressive disclosure: simple table report first; grouping, measures, and pivot behind clear steps.

## Best Practices
- Layout: left rail field catalog (searchable, grouped by entity, type icons); top config strip with "Columns", "Filters", "Group by", "Measures", "Sort"; main area preview; right or top actions: Run, Save, Share, Schedule, Export.
- Field catalog shows friendly label, description, type, and sensitivity marker; hide fields the user cannot read.
- Drag to add/reorder columns, with click and keyboard alternatives ("Add column" menu, move up/down buttons).
- Measures: only allowed aggregations per type (count/count distinct for any; sum/avg/min/max for numbers; min/max for dates).
- Time grouping requires explicit grain (day/week/month/quarter) and time zone.
- Show totals/subtotals rows clearly styled; label aggregated columns "Sum of Amount".
- Auto-run preview on change only if the estimated cost is low; otherwise show "Run" with a dirty indicator.
- Saved report metadata: name, description, owner, folder, visibility, last run, schedule, version history.
- Sharing uses roles/groups and a "who can see this data" explanation; shared recipients see only rows/fields they are allowed.
- Scheduled deliveries send a link to the report (authenticated) by default; attachments only if policy allows and data classification permits.
- Export formats: CSV (streamed, formula-escaped), XLSX (generated server-side), and PDF only if needed.

## Implementation Guidance

### Report definition
```ts
// lib/reports/definition.ts
import type { FilterGroup } from '@/lib/filters/model';

export type Aggregation = 'count' | 'countDistinct' | 'sum' | 'avg' | 'min' | 'max';
export type TimeGrain = 'day' | 'week' | 'month' | 'quarter' | 'year';

export type ReportDefinitionV1 = {
  version: 1;
  source: 'orders' | 'invoices' | 'tickets';
  columns: string[];                                          // dimension field keys (when not grouped)
  groupBy: Array<{ field: string; grain?: TimeGrain }>;
  measures: Array<{ field: string; agg: Aggregation; alias?: string }>;
  filters: FilterGroup | null;
  sort: Array<{ key: string; dir: 'asc' | 'desc' }>;          // key = field or measure alias
  limit: number;                                              // capped server-side
  timezone: string;                                           // IANA
  visualization?: { type: 'table' | 'bar' | 'line'; x?: string; y?: string[] };
};
```

### Field catalog (semantic layer)
```ts
// data/reports/catalog.ts
import 'server-only';

type FieldDef = {
  label: string; type: 'string' | 'number' | 'date' | 'enum' | 'boolean';
  sql: string;                       // trusted expression owned by engineers
  aggs: readonly Aggregation[];
  permission?: 'finance:read' | 'pii:read';
  groupable: boolean;
};
import type { Aggregation } from '@/lib/reports/definition';

export const catalog = {
  orders: {
    table: 'orders o',
    tenantColumn: 'o.tenant_id',
    fields: {
      region: { label: 'Region', type: 'enum', sql: 'o.region', aggs: ['count', 'countDistinct'], groupable: true },
      createdAt: { label: 'Created', type: 'date', sql: 'o.created_at', aggs: ['min', 'max'], groupable: true },
      amount: { label: 'Amount', type: 'number', sql: 'o.total_cents / 100.0', aggs: ['sum', 'avg', 'min', 'max'], groupable: false, permission: 'finance:read' },
      customerEmail: { label: 'Customer email', type: 'string', sql: 'o.customer_email', aggs: ['countDistinct'], groupable: false, permission: 'pii:read' },
    },
  },
} satisfies Record<string, { table: string; tenantColumn: string; fields: Record<string, FieldDef> }>;

export function catalogForUser(source: keyof typeof catalog, perms: Set<string>) {
  const { fields } = catalog[source];
  return Object.entries(fields)
    .filter(([, f]) => !f.permission || perms.has(f.permission))
    .map(([key, f]) => ({ key, label: f.label, type: f.type, aggs: f.aggs, groupable: f.groupable })); // DTO: no sql
}
```
If a dedicated semantic layer (e.g., Cube, dbt metrics) exists, generate this catalog from it instead; check those tools' current docs.

### Validation and compile (server)
```ts
// data/reports/run.ts
import 'server-only';
import { z } from 'zod';
import { catalog } from './catalog';
import { requireUser } from '@/data/auth';

const Def = z.object({
  version: z.literal(1),
  source: z.enum(['orders']),
  columns: z.array(z.string()).max(30),
  groupBy: z.array(z.object({ field: z.string(), grain: z.enum(['day', 'week', 'month', 'quarter', 'year']).optional() })).max(3),
  measures: z.array(z.object({ field: z.string(), agg: z.enum(['count', 'countDistinct', 'sum', 'avg', 'min', 'max']), alias: z.string().regex(/^[a-z_]{1,32}$/).optional() })).max(10),
  filters: z.unknown().nullable(),
  sort: z.array(z.object({ key: z.string(), dir: z.enum(['asc', 'desc']) })).max(3),
  limit: z.number().int().min(1).max(10_000),
  timezone: z.string().max(64),
});

export async function runReport(raw: unknown, mode: 'preview' | 'full') {
  const user = await requireUser();
  const def = Def.parse(raw);
  const src = catalog[def.source];
  const allowed = (key: string) => {
    const f = src.fields[key as keyof typeof src.fields];
    if (!f) throw new Error(`Unknown field ${key}`);
    if ('permission' in f && f.permission && !user.permissions.has(f.permission)) throw new Error('Forbidden field');
    return f;
  };
  def.columns.forEach(allowed);
  def.groupBy.forEach((g) => { if (!allowed(g.field).groupable) throw new Error('Not groupable'); });
  def.measures.forEach((m) => { if (!allowed(m.field).aggs.includes(m.agg)) throw new Error('Bad aggregation'); });

  const limit = mode === 'preview' ? Math.min(def.limit, 500) : def.limit;
  // Build parameterized SQL with a query builder from catalog expressions only;
  // wrap: WHERE tenant = $tenant AND (<compiled user filters>) plus row-level policy.
  return executeWithTimeout(buildQuery(def, src, user, limit), mode === 'preview' ? 5_000 : 60_000);
}
declare function buildQuery(...a: unknown[]): unknown;
declare function executeWithTimeout(q: unknown, ms: number): Promise<{ columns: { key: string; label: string; type: string }[]; rows: unknown[][]; truncated: boolean }>;
```

### Next.js page and preview
```tsx
// app/(app)/reports/[id]/edit/page.tsx
import { getReportForEdit } from '@/data/reports';     // authz: can edit this report
import { catalogForUser } from '@/data/reports/catalog';
import { requireUser } from '@/data/auth';
import { ReportBuilder } from './report-builder';

export default async function EditReport({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await requireUser();
  const report = await getReportForEdit(id);
  return <ReportBuilder initial={report.definition} fields={catalogForUser(report.definition.source, user.permissions)} reportId={id} />;
}
```
```tsx
// app/(app)/reports/[id]/edit/report-builder.tsx
'use client';
import { useDeferredValue, useState, useTransition } from 'react';
import { previewReportAction, saveReportAction } from './actions';
import type { ReportDefinitionV1 } from '@/lib/reports/definition';

export function ReportBuilder({ initial, fields, reportId }: {
  initial: ReportDefinitionV1; fields: { key: string; label: string; type: string; aggs: readonly string[] }[]; reportId: string;
}) {
  const [def, setDef] = useState(initial);
  const [result, setResult] = useState<Awaited<ReturnType<typeof previewReportAction>> | null>(null);
  const [running, startRun] = useTransition();
  const deferred = useDeferredValue(def);

  const run = () => startRun(async () => setResult(await previewReportAction(deferred)));
  const save = () => startRun(async () => { await saveReportAction(reportId, def); });

  return (
    <div className="report-builder">
      <FieldCatalog fields={fields} onAdd={(key) => setDef((d) => ({ ...d, columns: [...d.columns, key] }))} />
      <ConfigStrip def={def} fields={fields} onChange={setDef} />
      <div role="toolbar" aria-label="Report actions">
        <button type="button" onClick={run} disabled={running}>Run preview</button>
        <button type="button" onClick={save} disabled={running}>Save</button>
      </div>
      <section aria-label="Preview" aria-busy={running}>
        {result?.ok ? <PreviewTable data={result.data} /> : result ? <p role="alert">{result.error}</p> : <p>Run to see results.</p>}
        {result?.ok && result.data.truncated && <p>Preview limited to first 500 rows.</p>}
      </section>
    </div>
  );
}
// FieldCatalog, ConfigStrip, PreviewTable: your design-system components (omitted).
declare function FieldCatalog(p: any): React.JSX.Element; declare function ConfigStrip(p: any): React.JSX.Element; declare function PreviewTable(p: any): React.JSX.Element;
```
```ts
// app/(app)/reports/[id]/edit/actions.ts
'use server';
import { runReport } from '@/data/reports/run';
import { saveReport } from '@/data/reports'; // checks ownership/edit permission, bumps version

export async function previewReportAction(def: unknown) {
  try { return { ok: true as const, data: await runReport(def, 'preview') }; }
  catch (e) { return { ok: false as const, error: e instanceof Error && e.message.startsWith('Unknown') ? 'Invalid report' : 'Could not run report' }; }
}
export async function saveReportAction(id: string, def: unknown) {
  await saveReport(id, def);
  return { ok: true as const };
}
```

### Scheduling and export
| Concern | Rule |
|---|---|
| Execution identity | Scheduled runs execute as the recipient (per-recipient run) or deliver a link that runs on view |
| Large exports | Enqueue job; stream CSV to object storage; notify with an expiring, authenticated download link |
| Formats | CSV with formula escaping; XLSX generated server-side (e.g., ExcelJS, MIT); check SheetJS licensing/distribution notes if used |
| Failure | Retry with backoff; notify owner after repeated failures; auto-pause schedule |
| Governance | Audit log for create/share/schedule/export; admin view of all schedules |

## Recommended Workflow
1. Interview users for top 10 report questions; derive sources, dimensions, measures.
2. Build the field catalog with labels, types, aggregations, groupability, permissions.
3. Define and version the report definition schema; write compiler and tests with tenant wrapping and limits.
4. Build builder UI: catalog, config strip, preview table, run/save.
5. Add saved reports list (folders, search, owners), sharing with permission explanation.
6. Add scheduling and async export via jobs.
7. Add optional charts from the same result set.
8. Load-test common and worst-case definitions; add query timeouts and cost guards.

## Patterns
- **Catalog → Config → Preview**: three-zone layout; every config change marks preview stale until run (or auto-run when cheap).
- **Definition migration**: `version` field plus pure migration functions `v1 → v2` run on load.
- **Explain panel**: plain-language summary: "Sum of Amount by Region and Month, for Orders created in the last 90 days, sorted by Sum of Amount desc."
- **Pivot toggle**: second group-by rendered as columns; cap distinct values (e.g., 50) with "Other".
- **Report as starting point**: templates users can clone ("Revenue by month").
- **Drill-through**: clicking an aggregated cell opens the underlying list with equivalent filters (reuses list filter model).

## Anti-Patterns
- **SQL text box for end users**: injection, data exfiltration, runaway queries. Fix: catalog-based builder; separate governed SQL tool for analysts if needed.
- **Running shared reports with the author's permissions**: privilege escalation. Fix: viewer permissions; audited service identity only when governed.
- **Emailing full data attachments by default**: data leaves the security boundary. Fix: authenticated links; attachments only per policy.
- **Unbounded preview of millions of rows in the browser**: freezes UI. Fix: server limit and virtualization.
- **Storing resolved dates in saved filters**: stale reports. Fix: relative date expressions.
- **Client-side aggregation of paginated data**: wrong totals. Fix: aggregate in the database.
- **No versioning of definitions**: schema changes break saved reports. Fix: versioned schema and migrations.

## Accessibility
- All drag-and-drop interactions have keyboard and button alternatives (add, remove, move up/down) (WCAG 2.5.7 Dragging Movements).
- Field catalog is a searchable list with grouped headings; items announce type ("Amount, number").
- Preview uses a semantic table with header cells for group and measure columns; totals rows labeled.
- Announce run completion and errors ("Report returned 1,240 rows") via polite live region or `role="alert"` for errors.
- Charts built from results need a data table alternative ([accessible-data-visualization](../accessible-data-visualization/Skill.md)).
- Scheduling form uses accessible date/time and recurrence controls with clear time zone labels.

## Responsive Design
- Builder is a desktop experience; on tablets collapse the catalog into a drawer.
- On phones, provide viewing of saved reports (read-only table/cards, export link) rather than full editing.
- Preview table scrolls horizontally within a labeled region with sticky first column.

## Performance
- Precompute or cache results per definition hash + tenant + permission set with short TTL.
- Enforce statement timeouts and row limits; consider read replicas or a warehouse for heavy reports.
- Estimate cost (e.g., EXPLAIN or cardinality heuristics) before auto-running.
- Stream CSV exports; never build large files in memory in a Server Action.
- Virtualize preview tables beyond a few hundred rows.

## Security
- Definitions are untrusted input: Zod schema, catalog allowlist, per-field permission checks, aggregation allowlist, limits.
- Tenant constraint and row-level policies wrap compiled user filters so `OR` cannot escape them.
- Catalog DTO sent to the client excludes SQL expressions and hidden fields.
- Sharing, scheduling, and export actions re-authorize in Server Actions; audit every export and schedule change.
- Download links expire and require authentication; exports escape spreadsheet formulas.
- Small-group aggregates on sensitive data may re-identify individuals; apply minimum group sizes where policy requires.

## Testing
- Compiler unit tests: forbidden fields, bad aggregations, depth/limit caps, tenant wrapping with OR filters, time zone grains.
- Golden tests: definition → SQL snapshot (parameterized) for regressions.
- Permission matrix: same shared report viewed by roles with different field permissions yields different columns/rows.
- E2E: build, preview, save, reopen, share to another user, schedule, receive link.
- Performance: worst-case definitions against production-like data volumes with timeouts.

## Tooling
- `zod` for definition validation; a SQL query builder (e.g., Kysely, Drizzle) for parameterized compilation; check current docs.
- `react-querybuilder` (MIT) for filter group UI; verify current version.
- TanStack Table v9 or a data grid for preview; AG Grid Enterprise offers pivoting/aggregation if licensed.
- Semantic layers such as Cube or dbt Semantic Layer when a warehouse exists (verify licensing and APIs).
- ExcelJS (MIT, 4.4.0 on npm at verification) for XLSX; SheetJS Community Edition is Apache-2.0 and distributed from its own CDN rather than an up-to-date npm registry package (check SheetJS docs).

## Framework Notes
- **Next.js (App Router)**: Server Component loads the definition and filtered catalog; client builder holds draft state; preview and save are Server Actions calling a `server-only` DAL; large exports and scheduled runs are jobs, with downloads served by route handlers that re-check auth. `params` is a Promise in Next.js 16.
- **React (Vite SPA)**: builder state in React (optionally `useReducer`); preview via TanStack Query mutation or query keyed by definition hash; API implements the same compiler and permission checks.

## AI Agent Guidance
- Do: start from the field catalog and definition schema; compile only allowlisted catalog expressions; wrap with tenant scope; set limits and timeouts; run as viewer.
- Do: provide keyboard alternatives for every drag interaction.
- Don't: generate raw SQL from user text; don't send catalog SQL to the client; don't email data attachments by default.
- Before done: test a forbidden field injected into the definition, an OR filter trying to escape tenant scope, a 1M-row export path, and viewer-vs-author permissions on a shared report.

## Examples
Plain-language summary of a definition:
```ts
export function describeReport(def: ReportDefinitionV1, label: (k: string) => string) {
  const measures = def.measures.map((m) => `${m.agg === 'count' ? 'Count' : `${m.agg} of ${label(m.field)}`}`).join(', ') || 'Rows';
  const groups = def.groupBy.map((g) => `${label(g.field)}${g.grain ? ` (${g.grain})` : ''}`).join(' and ');
  return `${measures}${groups ? ` by ${groups}` : ''} from ${def.source}${def.filters ? ', filtered' : ''}.`;
}
import type { ReportDefinitionV1 } from '@/lib/reports/definition';
```

## Related Skills
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — filter model and compiler reused
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — preview table and drill-through lists
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md) — pivot/aggregation grids
- [data-import-export-ui](../data-import-export-ui/Skill.md) — export formats and safety
- [dashboard-design](../dashboard-design/Skill.md) — fixed KPI views vs ad-hoc reports
- [chart-type-selection](../chart-type-selection/Skill.md) — visualizing report results
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — field- and row-level permissions
- [drag-and-drop](../drag-and-drop/Skill.md) — accessible column reordering

## Sources
- [NN/g: Complex application design](https://www.nngroup.com/articles/complex-application-design/) — Research — learning by doing (previews), exports to other tools, staged disclosure
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, DTOs, Server Action authz, minimal returns
- [Papa Parse docs](https://www.papaparse.com/docs) — Open Source — `escapeFormulae` for CSV injection defense
- [SheetJS repository notice](https://github.com/SheetJS/sheetjs) — Open Source — Apache-2.0 CE, moved to git.sheetjs.com, CDN distribution
- [npm exceljs](https://www.npmjs.com/package/exceljs) — Open Source — version 4.4.0, MIT
- [AG Grid React licensing](https://www.ag-grid.com/react-data-grid/licensing/) — Official — pivot/aggregation are Enterprise features

## License / Usage Notes
Summarized guidance; code original. ExcelJS and react-querybuilder: MIT. SheetJS CE: Apache-2.0. AG Grid pivoting requires Enterprise license. No verbatim copying.

## Quality Tier
B — sound architecture and security model grounded in verified Next.js and library facts, but no single authoritative report-builder spec exists and semantic-layer tools were not verified this session.

## Status
Active

## Last Verified
2026-09-15
