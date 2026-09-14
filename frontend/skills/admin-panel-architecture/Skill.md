# Admin Panel Architecture

## Summary
How to structure an internal admin or back-office app in Next.js App Router (or a React Vite SPA): the app shell, how resources are organized, list/detail/edit routes, URL-synced list state, server-side data contracts, and CRUD through Server Actions backed by an authorizing Data Access Layer (DAL). The aim is a predictable "resource" architecture, so adding the 30th entity is as cheap as adding the 3rd.

## Category
Enterprise UI

## Subcategories
App shell, resource routing, CRUD, Server Components, Server Actions, Data Access Layer, URL state, list/detail/edit floorplans

## Problem It Solves
Admin panels grow one screen at a time. Each screen ends up with its own fetching, filtering, permission checks and table code. The result is inconsistent UX, IDOR holes (a page checks auth but its actions don't), filters lost on refresh, and oversized client bundles. A shared resource architecture fixes all of these at once.

## When To Use
- Internal tools, back-office, support consoles, ops dashboards, or a SaaS "settings/admin" area with many entities.
- You need consistent list → detail → edit flows for tens of resources.
- You are choosing between hand-rolled App Router pages and a framework (refine / react-admin).

## When Not To Use
- Only 1–3 screens: build plain pages and don't abstract early.
- Public, SEO-driven marketing or content sites.
- Heavy spreadsheet-style editing is the core of the product: start from [data-grids-ag-grid](../data-grids-ag-grid/Skill.md) instead.

## Core Principles
1. **Resource-first structure.** Every entity gets the same route set: list, detail, create, edit, and optionally audit.
2. **The server is the security boundary.** Pages, Server Actions and Route Handlers each re-check authentication and authorization. Hiding a button is only UX.
3. **The URL is the list state.** Filters, sort, page, page size and the selected view live in search params, so they survive refresh, sharing and back/forward.
4. **Paginate, sort and filter on the server**, with one typed contract that every resource reuses.
5. **The DAL returns DTOs.** Only the minimal fields are passed to Client Components. Never pass raw DB rows.
6. **The client island is as small as possible.** Keep the shell, headers and read-only detail as Server Components; tables, filters and forms are client islands.
7. **Consistency beats cleverness.** Same toolbar placement, same bulk action bar, same confirm patterns, same keyboard shortcuts everywhere.

## Best Practices
- **Layout anatomy:** a persistent sidebar (resource nav grouped by domain), a top bar (tenant/org switcher, global search or command palette, user menu), and a page header (title, breadcrumbs, primary action). The content area follows one of three floorplans: list report, object page or form.
- Put the primary action ("New invoice") in the page header top-right. Put record-level finalizing actions (Save, Submit, Approve) in a sticky footer or header bar that is always visible.
- Use NN/g's four table tasks to design lists: find records, compare, view or edit one record, and take actions. Make the first column a human-readable identifier, not a UUID.
- Prefer a nonmodal side panel or a dedicated detail route over modals for viewing and editing, so users can keep referencing the list.
- Give every list the same states: loading skeleton, empty ("no records yet" + create CTA), filtered-empty ("no matches" + clear filters) and error with retry.
- Keep an "audit" tab on every detail page (see [audit-log-interfaces](../audit-log-interfaces/Skill.md)).
- Follow NN/g's complex-app guidance: allow flexible pathways (no forced linear flows), reduce clutter with staged disclosure, and give easy access to secondary info (hover cards, side panels) without leaving the screen.
- Offer density (comfortable/compact) as a user preference and persist it (cookie or user settings), not in the URL.
- Keyboard: `/` focuses search, `Cmd/Ctrl+K` opens the command palette, `j/k` or arrows move through rows, `Enter` opens a record. Use `?` to show a shortcut sheet. See [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md).

## Implementation Guidance

### Route structure (App Router)
```
app/
  (auth)/login/page.tsx
  (admin)/
    layout.tsx                 // shell: sidebar + topbar; verifies session (UX redirect only)
    [resource]/...             // avoid: over-generic; prefer explicit folders below
    invoices/
      page.tsx                 // list (Server Component, reads searchParams)
      loading.tsx
      new/page.tsx             // create form
      [id]/page.tsx            // detail (object page)
      [id]/edit/page.tsx
      [id]/@panel/...          // optional: parallel/intercepting route for side-panel preview
      actions.ts               // 'use server' thin wrappers
  api/export/invoices/route.ts // streaming CSV export (Route Handler)
data/                          // DAL: 'server-only', authz + DTOs
  invoices.ts
lib/list-params.ts             // shared nuqs parsers + Zod validation
```

### Shared list contract
```ts
// lib/list-contract.ts
export type SortDir = 'asc' | 'desc';
export type FilterOp = 'eq' | 'neq' | 'in' | 'contains' | 'gte' | 'lte' | 'between' | 'isEmpty';
export interface ListQuery<F extends string = string> {
  page: number;          // 1-based in URL; convert to pageIndex for TanStack Table
  pageSize: 10 | 25 | 50 | 100;
  sort: { field: F; dir: SortDir }[];
  filters: { field: F; op: FilterOp; value: unknown }[];
  q?: string;            // global search
}
export interface ListResult<T> {
  rows: T[];
  total: number;         // or null + nextCursor for very large tables
  nextCursor?: string | null;
}
```
Rules: the server allowlists sortable/filterable fields (never interpolate a field name into SQL), clamps `pageSize`, and applies tenant scoping before anything else.

### Decision table
| Need | Choice |
|---|---|
| < 20 resources, custom UX, RSC benefits | Hand-rolled App Router + TanStack Table v9 + nuqs + Server Actions |
| Many CRUD resources fast, headless, Next.js router support | refine (see [refine-and-react-admin-frameworks](../refine-and-react-admin-frameworks/Skill.md)) |
| Material look acceptable, SPA fine, huge component set | react-admin (client-only in Next.js) |
| Excel-like editing, grouping, pivot, millions of rows | AG Grid (Enterprise for SSRM/grouping) |

## Recommended Workflow
1. List the resources, their actions (list/read/create/update/delete/export/approve) and the roles. Produce a permission matrix first.
2. Build the DAL: `server-only` modules with `getX`, `listX(query)`, `createX`, `updateX`, `deleteX`. Each one resolves the session, checks permission and tenant scope, and returns DTOs.
3. Define the shared list-contract parsers (nuqs + Zod) and one generic `<ResourceTable>` client component.
4. Build the shell layout, nav generated from a resource registry filtered by permission (UX only), and breadcrumbs.
5. For each resource: list page (RSC) → detail page → create/edit forms with `useActionState` → thin Server Actions calling the DAL → `revalidatePath`/`refresh`.
6. Add bulk actions, export and the audit tab.
7. Test the authz matrix at the DAL/action level (integration tests) and the flows with Playwright.

## Patterns

### Resource registry (drives nav, breadcrumbs, command palette)
```ts
// lib/resources.ts
export const resources = [
  { key: 'invoices', label: 'Invoices', href: '/invoices', group: 'Billing', permission: 'invoice:read' },
  { key: 'customers', label: 'Customers', href: '/customers', group: 'CRM', permission: 'customer:read' },
] as const;
```

### List page as Server Component with URL state
```tsx
// app/(admin)/invoices/page.tsx
import { loadListParams } from '@/lib/list-params';
import { listInvoices } from '@/data/invoices';
import { InvoiceTable } from './invoice-table';

export default async function InvoicesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await loadListParams(searchParams); // nuqs createLoader + Zod validation
  const result = await listInvoices(query);          // DAL: authz + tenant scope + DTO
  return <InvoiceTable rows={result.rows} total={result.total} />;
}
```

### Shared parsers
```ts
// lib/list-params.ts
import { createLoader, parseAsInteger, parseAsString, parseAsStringLiteral } from 'nuqs/server';
export const listParsers = {
  page: parseAsInteger.withDefault(1),
  pageSize: parseAsInteger.withDefault(25),
  sort: parseAsString.withDefault('createdAt.desc'),
  q: parseAsString.withDefault(''),
  status: parseAsStringLiteral(['draft', 'open', 'paid', 'void'] as const),
};
const load = createLoader(listParsers);
export async function loadListParams(sp: Promise<Record<string, string | string[] | undefined>>) {
  const raw = await load(sp);
  // loaders don't validate business rules: clamp and allowlist here (or with Zod)
  return { ...raw, page: Math.max(1, raw.page), pageSize: [10, 25, 50, 100].includes(raw.pageSize) ? raw.pageSize : 25 };
}
```

### Thin Server Action → DAL
```ts
// app/(admin)/invoices/actions.ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { voidInvoice } from '@/data/invoices';

const Input = z.object({ id: z.string().uuid(), reason: z.string().min(3).max(500) });
export async function voidInvoiceAction(_prev: unknown, formData: FormData) {
  const parsed = Input.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { ok: false as const, errors: parsed.error.flatten().fieldErrors };
  await voidInvoice(parsed.data.id, parsed.data.reason); // re-auth, permission, tenant, ownership, audit
  revalidatePath('/invoices');
  return { ok: true as const };
}
```

## Anti-Patterns
- **Auth check only in `layout.tsx` or `proxy.ts`.** Layouts don't re-run on every navigation, and actions are separate POST entry points. Fix: check in the DAL for every read and mutation.
- **Passing full ORM rows to client tables.** This leaks internal fields. Fix: DTOs with explicit field selection.
- **Filters in `useState`.** They are lost on refresh and can't be shared. Fix: nuqs search params.
- **Client-side pagination over a `SELECT *`.** Breaks at scale. Fix: server-side `LIMIT/OFFSET` or a cursor, plus a count.
- **Modal-in-modal edit flows.** Fix: detail routes or nonmodal side panels.
- **One-off table components per resource.** Fix: a generic `ResourceTable` with column configs.
- **Generic `[resource]` dynamic route with stringly-typed everything.** Unsafe and untyped. Fix: explicit folders plus a registry.

## Accessibility
- Landmarks: `nav` for the sidebar (`aria-label="Admin"`), `main`, and `header`. Include a skip link to main.
- Tables: native `<table>` semantics with `aria-sort` on sorted headers. Use the APG grid pattern only for cell-navigable editing grids (see [accessible-data-tables](../accessible-data-tables/Skill.md)).
- Announce async results ("42 results", "Invoice voided") via a polite live region (WCAG 4.1.3 Status Messages).
- Move focus to the page `h1` after route changes, and return focus to the trigger when a side panel closes.
- Target size ≥ 24×24 CSS px even in compact density (WCAG 2.5.8).

## Responsive Design
- Admin is desktop-first, but it must not break at 1024px or on tablets. The sidebar collapses to an icon rail, then to a drawer.
- Tables: horizontal scroll with a pinned first column, or on narrow screens switch to a stacked card list with the key fields.
- Sticky page header and action footer. Avoid fixed-height layouts that hide content at 200% zoom (WCAG 1.4.10 Reflow).

## Performance
- Stream the shell immediately; wrap slow lists in `<Suspense>` with skeletons and use `loading.tsx`.
- Fetch counts in parallel with rows. For very large tables use estimated counts or cursor pagination.
- Lazy-load heavy grids, charts and editors (`next/dynamic`). Cherry-pick AG Grid modules.
- Debounce search inputs (~300ms) and use `startTransition` for URL updates so typing stays responsive.
- Virtualize long lists (see [list-virtualization](../list-virtualization/Skill.md)).

## Security
- DAL files `import 'server-only'`; only the DAL reads `process.env` secrets.
- Every Server Action and Route Handler must validate input (Zod), re-authenticate, authorize the action, and verify the resource belongs to the caller's tenant (IDOR).
- Allowlist sort and filter fields and use parameterized queries.
- Return minimal action results (`{ ok: true }`), not records.
- Treat `[id]` params and all searchParams as untrusted.
- CSV export: neutralize formula injection (prefix `= + - @ \t \r` values).
- Log privileged mutations to an append-only audit log.

## Testing
- DAL/action integration tests per role × action × tenant, including a cross-tenant IDOR test for each resource.
- Playwright: list → filter → URL reflects the state → reload keeps it → open detail → edit → toast → list updated.
- Automated axe checks on shell, list and form templates.
- Contract tests for the list query parser (invalid page, unknown sort field, oversize pageSize).

## Tooling
- nuqs 2.x (URL state), TanStack Table v9 (headless table), Zod (validation), React Hook Form or `useActionState`.
- refine / react-admin (frameworks).
- AG Grid 36 / MUI X Data Grid (full grids).
- CASL / OpenFGA / Permit.io (authorization).
- Playwright (E2E) and axe (accessibility).

## Framework Notes
- **Next.js (App Router):** Server Components for pages, Server Actions for mutations, Route Handlers for exports and webhooks. `params`/`searchParams` are Promises. `proxy.ts` (formerly middleware) is fine for coarse redirects but never the only check. Wrap the app in `NuqsAdapter` from `nuqs/adapters/next/app`.
- **React (Vite SPA):** routing via React Router or TanStack Router, and data via TanStack Query against a REST/GraphQL API that enforces authorization. URL state via nuqs's React Router adapter or router search params. There are no Server Actions, so all security lives in the API.

## AI Agent Guidance
- Do: build the DAL first, with authz and tenant scoping in every function. Keep actions thin. Use shared list parsers. Add loading, empty and error states to every list.
- Do: generate the nav from the resource registry, and the permission matrix from the requirements.
- Don't: put authorization only in layouts, `proxy.ts` or client components. Don't pass ORM entities to client components. Don't store list state in `useState`.
- Before declaring done, verify:
  - A direct POST to each action as an unauthorized role fails.
  - A cross-tenant ID fails.
  - Reload preserves filters.
  - Keyboard-only users can complete the CRUD flow.
  - axe reports no critical issues.

## Examples

### Generic table client island (TanStack Table v9, server-driven)
```tsx
'use client';
import { useQueryStates, parseAsInteger } from 'nuqs';
import { useTable, tableFeatures, rowPaginationFeature, rowSortingFeature, type ColumnDef } from '@tanstack/react-table';

const features = tableFeatures({ rowPaginationFeature, rowSortingFeature });
type InvoiceRow = { id: string; number: string; customer: string; total: number; status: string };

export function InvoiceTable({ rows, total, columns }: { rows: InvoiceRow[]; total: number; columns: ColumnDef<typeof features, InvoiceRow>[] }) {
  const [{ page, pageSize }, setParams] = useQueryStates(
    { page: parseAsInteger.withDefault(1), pageSize: parseAsInteger.withDefault(25) },
    { shallow: false }, // re-run the Server Component with new params
  );
  const table = useTable({
    features, columns, data: rows,
    manualPagination: true, manualSorting: true, rowCount: total,
    state: { pagination: { pageIndex: page - 1, pageSize } },
    onPaginationChange: (u) => {
      const next = typeof u === 'function' ? u({ pageIndex: page - 1, pageSize }) : u;
      void setParams({ page: next.pageIndex + 1, pageSize: next.pageSize });
    },
  });
  return (
    <table>
      <thead>{table.getHeaderGroups().map((hg) => (
        <tr key={hg.id}>{hg.headers.map((h) => <th key={h.id} scope="col"><table.FlexRender header={h} /></th>)}</tr>
      ))}</thead>
      <tbody>{table.getRowModel().rows.map((r) => (
        <tr key={r.id}>{r.getAllCells().map((c) => <td key={c.id}><table.FlexRender cell={c} /></td>)}</tr>
      ))}</tbody>
    </table>
  );
}
```
(Check the current TanStack Table v9 docs for exact row/cell accessor names; the v9 API changed from v8.)

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — list screen anatomy and behavior
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — filter bar and saved views
- [bulk-actions](../bulk-actions/Skill.md) — multi-record operations
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — permission modeling
- [multi-tenant-ui](../multi-tenant-ui/Skill.md) — org switching and scoping
- [refine-and-react-admin-frameworks](../refine-and-react-admin-frameworks/Skill.md) — framework alternative
- [master-detail-layouts](../master-detail-layouts/Skill.md) — detail panels
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — mutation mechanics
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — URL state
- [tanstack-table](../tanstack-table/Skill.md) — headless table engine
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md) — shell navigation
- [command-palette](../command-palette/Skill.md) — power-user navigation

## Sources
- [Next.js: How to think about data security](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, DTOs, `server-only`, re-auth in Server Actions, IDOR, return-value filtering, audit checklist
- [nuqs server-side docs](https://nuqs.dev/docs/server-side) — Official — `createLoader`, `createSearchParamsCache`, parsers; loaders don't validate
- [TanStack Table docs (v9)](https://github.com/TanStack/table/tree/main/docs) — Official — `useTable`, `tableFeatures`, manual pagination, controlled state
- [NN/g: Data Tables: Four Major User Tasks](https://www.nngroup.com/articles/data-tables/) — Community (research) — table tasks, nonmodal editing
- [NN/g: 8 Design Guidelines for Complex Applications](https://www.nngroup.com/articles/complex-application-design/) — Community (research) — flexible pathways, staged disclosure
- [refine general concepts](https://refine.dev/docs/guides-concepts/general-concepts/) — Official — resource/provider model used as architecture reference

## License / Usage Notes
Content is summarized and paraphrased from the sources above; code is original. nuqs, TanStack Table and refine are MIT. The Next.js docs are under Vercel's site terms.

## Quality Tier
A — core guidance verified against the current Next.js security guide, nuqs and TanStack Table v9 docs; layout anatomy synthesized from NN/g and design-system patterns.

## Status
Active

## Last Verified
2026-09-15
