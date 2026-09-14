# Data Import & Export UI

## Summary
How to build CSV/Excel import and export in React/Next.js admin apps. Import runs as a guided flow: upload, pick the header row, map columns, validate and fix, dry-run preview, then commit. Export runs as a permission-aware, filter-respecting job, protected against CSV/formula injection. Parsing happens on the client for fast feedback. The server re-validates and owns the commit.

## Category
Enterprise UI

## Subcategories
CSV import, Excel import, column mapping, validation, bulk upsert, background jobs, export, CSV injection

## Problem It Solves
Enterprise users move data in and out through spreadsheets. Naive imports produce silent data corruption: wrong columns, locale-formatted numbers, duplicates, partial writes. Naive exports leak fields the user shouldn't see, ignore active filters, time out on large datasets, or ship formulas that execute in Excel.

## When To Use
- Onboarding customers' existing data (contacts, products, inventory, price lists).
- Periodic bulk updates by operations staff.
- "Export what I see" from data tables and reports.
- Scheduled or large exports that exceed a request timeout.

## When Not To Use
- Continuous system-to-system sync. Use APIs, webhooks or ETL instead.
- Tiny edits (a handful of rows). Inline editing or bulk actions are simpler.
- Regulated data where exports must go through a separate approval workflow. Pair this skill with workflow-and-approval-ui.

## Core Principles
1. The client parses for preview and fast validation. The server re-validates every row and owns the write.
2. Nothing is committed without a preview: show counts of create/update/skip/error before commit.
3. Imports are idempotent: upsert on a stable key (external id, SKU, email), with a declared conflict strategy.
4. Large files run as background jobs with progress, cancel, and a downloadable error report.
5. Exports respect the current view (filters, sort, visible columns) and the user's permissions (row- and field-level).
6. Exported cells starting with `= + - @ \t \r` are neutralized to prevent formula injection.
7. Enforce size, row and type limits both before upload and on the server.

## Best Practices
- Offer a downloadable template (CSV/XLSX) generated from the same field schema used for validation.
- Auto-match columns with `alternateMatches` (e.g. "E-mail", "email address") and let users override. Remember mappings per user or tenant.
- Header row selection: many real files have title rows above the headers.
- Normalize before validating: trim, Unicode NFC, locale-aware numbers and dates (state the expected format), booleans ("yes/no/1/0").
- Validate with one shared Zod schema on client and server. Show errors inline per cell, with filters for "rows with errors".
- Let users fix errors in the preview grid or download an error CSV, fix it offline and re-upload.
- Chunk commits (for example 500–1000 rows per batch), each in a transaction, and record per-row outcomes.
- Record an audit entry for every import and export: who, when, file hash, row counts, filters used.
- Exports: small (under a few thousand rows) can stream directly. Anything large becomes an async job that emails or notifies with a short-lived signed URL.
- Name files predictably: `orders_2026-09-15_filtered.csv`. Include the UTF-8 BOM for Excel CSV compatibility if your users open CSVs in Excel.

## Implementation Guidance
**Library decision table**

| Need | Library | Notes |
|---|---|---|
| CSV parse (client, large) | Papa Parse (MIT) | `worker: true`, `step`/`chunk` streaming, `header`, `transformHeader`, `skipEmptyLines: 'greedy'`. `unparse` for CSV output with `escapeFormulae` |
| XLSX read/write | SheetJS Community Edition (Apache-2.0) | Install from `cdn.sheetjs.com` tarballs. The copy on the public npm registry is outdated. Source moved to git.sheetjs.com. Pro features are commercial |
| XLSX write with styling (server) | ExcelJS (MIT) | npm latest 4.4.0. Check maintenance activity before adopting |
| Ready-made import wizard | react-spreadsheet-import (MIT) | Upload, header select, column matching, validation/edit. Built on Chakra UI, so weigh the extra design-system dependency |
| Hosted importer | Flatfile, Dromo, OneSchema (commercial) | Consider when you don't want to own the UX. Review data residency |

**Server contract**
```ts
// lib/import/types.ts
export type ImportMode = 'create' | 'upsert' | 'update-only';
export interface ImportJob {
  id: string; status: 'validating' | 'ready' | 'committing' | 'done' | 'failed' | 'cancelled';
  totals: { rows: number; create: number; update: number; skip: number; error: number };
  processed: number; errorReportUrl?: string;
}
```
Flow: `POST /api/imports` (file or presigned upload key) creates the job, the server parses and validates into staging and returns `ready` with totals. The user confirms, a Server Action `commitImport(jobId)` runs batches, and the UI polls or subscribes for `processed`.

## Recommended Workflow
1. Define the field schema (key, label, type, required, unique, alternates, example) once in a shared module.
2. Generate the template download from that schema.
3. Build the wizard: Upload → Select header row → Map columns → Validate & fix → Preview totals → Commit.
4. Implement server staging plus re-validation plus a dry run, returning totals and per-row errors.
5. Commit in idempotent batches with progress and cancel. Produce an error report CSV.
6. Build export: a "current view" vs "all columns I can see" choice, format (CSV/XLSX), a sync/async threshold, and formula escaping.
7. Audit-log both. Test with ugly real-world files.

## Patterns
**Client-side streaming parse with Papa Parse**
```tsx
'use client';
import Papa from 'papaparse';

export function parseCsv(file: File, onProgress: (rows: number) => void) {
  return new Promise<Record<string, string>[]>((resolve, reject) => {
    const rows: Record<string, string>[] = [];
    Papa.parse<Record<string, string>>(file, {
      header: true,
      worker: true,
      skipEmptyLines: 'greedy',
      transformHeader: (h) => h.trim(),
      chunk: (res) => { rows.push(...res.data); onProgress(rows.length); if (rows.length > 100_000) reject(new Error('Row limit exceeded')); },
      complete: () => resolve(rows),
      error: reject,
    });
  });
}
```

**Column mapping state**
```ts
type Mapping = Record<string /* file header */, string | null /* field key or ignore */>;
// Require every `required` field mapped exactly once before "Next".
```

**Server re-validation and dry run**
```ts
// data/imports.ts
import 'server-only';
import { z } from 'zod';
import { requirePermission } from '@/data/auth';

const ContactRow = z.object({
  email: z.string().trim().toLowerCase().email(),
  name: z.string().trim().min(1),
  seats: z.coerce.number().int().nonnegative().optional(),
});

export async function dryRunImport(jobId: string) {
  const user = await requirePermission('contacts:import'); // throws if forbidden
  const job = await db.importJob.findFirstOrThrow({ where: { id: jobId, tenantId: user.tenantId } });
  const staged = await db.importRow.findMany({ where: { jobId: job.id } });
  const existing = new Set((await db.contact.findMany({
    where: { tenantId: user.tenantId, email: { in: staged.map((r) => String(r.data.email).toLowerCase()) } },
    select: { email: true },
  })).map((c) => c.email));
  let create = 0, update = 0, error = 0;
  for (const r of staged) {
    const parsed = ContactRow.safeParse(r.data);
    if (!parsed.success) { error++; await db.importRow.update({ where: { id: r.id }, data: { errors: parsed.error.flatten() } }); continue; }
    existing.has(parsed.data.email) ? update++ : create++;
  }
  return { create, update, error, rows: staged.length };
}
```

**Export Server Action → async job**
```ts
'use server';
import { exportFiltersSchema } from '@/lib/table/filters';
import { enqueueExport } from '@/data/exports';

export async function requestExport(input: unknown) {
  const filters = exportFiltersSchema.parse(input);   // same schema as the list page URL state
  return enqueueExport(filters);                      // DAL: authz, column allow-list, row scoping, audit
}
```

**Formula-safe CSV**
```ts
import Papa from 'papaparse';
const csv = '﻿' + Papa.unparse(rows, { escapeFormulae: true });
```
If you build CSV manually, prefix a single quote to any string cell starting with `=`, `+`, `-`, `@`, tab or CR.

## Anti-Patterns
- **Trusting client-parsed JSON on submit.** A tampered payload bypasses validation. Fix: re-parse or re-validate on the server from the stored file or staging rows.
- **One giant transaction or request.** It times out, and one bad row loses everything. Fix: batches plus per-row outcomes plus a resumable job.
- **Insert-only imports.** Re-running duplicates everything. Fix: upsert on a natural key, with a user-chosen mode.
- **Export that re-queries "all rows" ignoring filters or permissions.** It leaks data. Fix: build the export query from the validated URL filter state inside the DAL with tenant/row/field scoping.
- **Hidden columns still exported.** Fix: an explicit column allow-list intersected with the user's field permissions.
- **Unescaped CSV.** Formula injection (`=HYPERLINK(...)`). Fix: `escapeFormulae` or manual prefixing.
- **Pulling SheetJS from the public npm registry.** You get an outdated version with known issues. Fix: install the tarball from cdn.sheetjs.com and pin it.
- **Error messages like "Row invalid".** Fix: cell-level messages with the expected format and an example.

## Accessibility
- Wizard steps: a labelled step list with `aria-current="step"`, focus moved to each step heading on navigation.
- File drop zones must also be a real `<input type="file">` button (WCAG 2.1.1).
- Column mapping selects need visible labels tied to the source header name.
- Progress: `role="progressbar"` with `aria-valuenow`, plus polite live-region milestones ("50% imported").
- Error grid: row and column headers announced. Error cells use text and icons, not colour only (WCAG 1.4.1).

## Responsive Design
- Import is desktop-first. On small screens, allow upload and summary but recommend desktop for mapping and fixing.
- The preview grid scrolls horizontally with a sticky first column (row number plus status).

## Performance
- Parse in a Web Worker (`worker: true`) and stream with `chunk`. Never `readAsText` a 50 MB file on the main thread.
- Virtualize the preview grid, and only render error rows by default for huge files.
- Upload directly to object storage via presigned URL rather than through a Next.js route body. Server Actions have a default body size limit (check `serverActions.bodySizeLimit` in current docs).
- Server: stream XLSX/CSV generation for exports, and use a queue/worker for jobs.

## Security
- Authorization on every endpoint: import, commit, status, error-report download and export download all check tenant and permission in the DAL.
- Validate MIME and extension and enforce size and row limits server-side. Reject macros (`.xlsm`) unless required.
- Treat file contents as untrusted: no `eval`, no HTML rendering of cell values without escaping.
- Signed export URLs: short TTL, scoped to the requesting user, not guessable, and audit-logged.
- Field-level redaction (PII, cost prices) happens in the query, not by hiding columns in the UI.

## Testing
- Fixture files: BOM/no BOM, semicolon delimiters, quoted newlines, title rows above headers, duplicate headers, locale decimals, 100k rows, empty trailing rows.
- Unit: schema normalization and the mapping auto-match.
- Integration: dry-run totals, idempotent re-import (second run produces zero creates), cancellation mid-job.
- Security: export as a restricted role, assert hidden fields are absent, and assert `=1+1` is escaped.
- E2E (Playwright): `setInputFiles`, map, fix a cell, commit, download the error report and assert its contents.

## Tooling
- Papa Parse (MIT), SheetJS CE (Apache-2.0, CDN install), ExcelJS (MIT; verify maintenance), react-spreadsheet-import (MIT; Chakra UI).
- Zod for the shared row schema. A queue (e.g. a managed job queue or DB-backed jobs) for large jobs. Check current options for your platform.

## Framework Notes
- **React (Vite SPA):** client parsing and preview are identical. Commit goes to your API with the same server-side re-validation. Downloads use `URL.createObjectURL` for small client-generated files.
- **Next.js App Router:** use a route handler for uploads/presigned URLs and streaming export downloads (`new Response(stream, { headers: { 'Content-Disposition': 'attachment; filename=...' } })`). Use Server Actions for commit and request-export. Keep parsing libraries out of Server Component bundles unless used server-side. Mark import/export DAL modules `server-only`.

## AI Agent Guidance
- Do: define one schema for template, client validation and server validation. Add a dry run, idempotent upsert, batches, error report, audit and formula escaping.
- Do: build exports from the validated list-view filter state with server-side permission scoping.
- Don't: commit on upload, trust client JSON, install SheetJS from the npm registry, or export via the client-side table state only.
- Verify: a re-import is a no-op, a restricted-role export omits restricted fields, a 100k-row file doesn't freeze the UI, and cancel works.

## Examples
```tsx
// app/(app)/contacts/import/page.tsx — Server Component shell
import { requirePermission } from '@/data/auth';
import { ImportWizard } from './import-wizard'; // 'use client'
import { contactFields } from '@/lib/import/contact-fields';

export default async function ImportPage() {
  await requirePermission('contacts:import');
  return <ImportWizard fields={contactFields} maxRows={100_000} maxBytes={20 * 1024 * 1024} />;
}
```
```ts
// app/api/exports/[id]/route.ts
import { getExportDownload } from '@/data/exports';
export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const file = await getExportDownload(id); // checks owner + tenant + expiry, audits
  if (!file) return new Response('Not found', { status: 404 });
  return new Response(file.stream, {
    headers: { 'Content-Type': file.mime, 'Content-Disposition': `attachment; filename="${file.name}"` },
  });
}
```

## Related Skills
- [file-upload](../file-upload/Skill.md) — drop zones, presigned uploads, progress
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md) — import wizard structure
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — export current view
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — filter state reused by export
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — recording imports/exports
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — field-level redaction
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — streaming downloads
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — commit/export actions
- [web-workers-offloading](../web-workers-offloading/Skill.md) — off-main-thread parsing
- [report-builder-ui](../report-builder-ui/Skill.md) — scheduled report exports

## Sources
- [Papa Parse docs](https://www.papaparse.com/docs) — Open Source — header, dynamicTyping, worker, step/chunk, transformHeader, skipEmptyLines, unparse, escapeFormulae
- [SheetJS repository notice](https://github.com/SheetJS/sheetjs) — Open Source — Apache-2.0 CE, move to git.sheetjs.com, cdn.sheetjs.com distribution
- [react-spreadsheet-import README](https://github.com/UgnisSoftware/react-spreadsheet-import) — Open Source — steps, field definitions, validations, MIT, Chakra UI
- [ExcelJS on npm](https://www.npmjs.com/package/exceljs) — Open Source — version 4.4.0, MIT
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, Server Action authz, controlled return values

## License / Usage Notes
Papa Parse MIT. SheetJS CE Apache-2.0 (Pro commercial). ExcelJS MIT. react-spreadsheet-import MIT. Hosted importers are commercial. Content is summarized. Code is original.

## Quality Tier
A — library facts verified against official docs and npm. Server-side patterns follow Next.js security guidance. Hosted importer comparisons not verified.

## Status
Active

## Last Verified
2026-09-15
