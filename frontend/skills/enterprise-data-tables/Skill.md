# Enterprise Data Tables

## Summary
How to build list/record tables for admin and line-of-business apps in React + Next.js: server-driven pagination, sorting and filtering with a typed URL contract, column control, density modes, row actions, selection, and accessible semantics. Covers the headless path (TanStack Table v9 + your design system) and when to escalate to a full data grid (AG Grid, MUI X, Glide). The table is a view over a server query; the URL is its state.

## Category
Enterprise UI

## Subcategories
Data tables, server-side pagination, sorting, column visibility, density, row actions, URL state, TanStack Table, table API contracts

## Problem It Solves
Enterprise lists have thousands to millions of records, many columns, and users who need to find, compare, and act on records fast. Client-only tables load everything, break deep links, lose state on refresh, and leak fields the user should not see. This skill gives a repeatable anatomy and contract so every list screen behaves the same, stays fast, and is secure.

## When To Use
- Record list screens: orders, users, invoices, tickets, audit entries, inventory.
- Any list larger than a few hundred rows, or where filters and sort must be shareable by URL.
- When you control the backend (DAL or route handlers) and can implement a query contract.

## When Not To Use
- Spreadsheet-like editing, range selection, pivoting, grouping of 100k+ rows: use a data grid ([data-grids-ag-grid](../data-grids-ag-grid/Skill.md)).
- Tiny static tables (fewer than about 50 rows, no interaction): plain semantic `<table>`.
- Card/feed layouts where users do not compare attributes across records.

## Core Principles
1. Support the four table tasks NN/g identifies: find records, compare, view/edit one record, take actions. Design each explicitly.
2. The server owns data shaping: pagination, sort, and filters run in the query, not in the browser.
3. URL is the single source of truth for list state (page, pageSize, sort, filters, view). Refresh, back button, and shared links must reproduce the view.
4. Allowlist everything the client can influence: sortable fields, filterable fields, operators, page size maximum.
5. Return DTOs with only the columns the viewer may see; hiding a column in the UI is not access control.
6. The first column is a human-readable identifier (name, number), not an internal UUID.
7. Stable layout: fixed header, predictable column widths, no layout shift while loading.

## Best Practices
- Toolbar anatomy, left to right: search, filter trigger with active-count badge, saved views; right side: density, column picker, export, primary "Create" action.
- Freeze the header row and the identifier column on horizontal scroll (NN/g).
- Right-align numbers and use tabular numerals; left-align text; align header text with cell content.
- Offer three densities (compact ~32px, default ~40px, comfortable ~48px rows) and persist the choice per user. EUI and Carbon both expose density controls.
- Column picker: show/hide and reorder; persist per user (server) or per view; always keep the identifier column visible.
- Sort indicator on the header button with `aria-sort` on the `<th>`; single-column sort by default, multi-sort only with shift-click and a visible order.
- Row actions: one primary inline action (or row click to open) plus a kebab menu for the rest. Do not make both the row and inner buttons clickable without clear affordance.
- Show "1–50 of 12,430"; if count is expensive, show "50+ results" and use cursor pagination.
- Reset page to 1 whenever filters, search, or sort change.
- Empty states distinguish "no data yet" (show create CTA) from "no results for these filters" (show clear-filters CTA).
- Keep previous rows visible with a subtle progress indicator during refetch instead of blanking the table.
- Truncate long text with an accessible full value (tooltip plus the detail view), never silently.

## Implementation Guidance

### Decision table
| Need | Choose |
|---|---|
| Design-system-native table, server data, moderate interactivity | TanStack Table v9 (headless) + your `<table>` components |
| Row grouping, pivot, Excel export, range select, SSRM | AG Grid Enterprise or MUI X Premium (commercial) |
| Pinning, multi-sort, resizing with MUI stack | MUI X Pro |
| Millions of rows, canvas rendering, very high update rates | Glide Data Grid (MIT, canvas; check its a11y story yourself) |
| Read-only, under 50 rows | Semantic HTML table only |

### List query contract (URL and API)
```
GET /orders?page=2&pageSize=50&sort=createdAt.desc&q=acme&status=open,pending&from=2026-01-01
```
Response:
```ts
type ListResponse<T> = {
  rows: T[];
  page: number;
  pageSize: number;
  total: number | null;     // null when counting is too expensive
  nextCursor?: string;      // present in cursor mode
};
```
Offset vs cursor:
| | Offset (`page`) | Cursor (`after`) |
|---|---|---|
| Jump to page N | Yes | No |
| Stable under inserts | No (rows shift) | Yes |
| Deep pages on large tables | Slow | Fast |
| Best for | Admin lists under ~100k rows | Feeds, audit logs, huge tables |

### Shared parsers (nuqs 2.x, used by server and client)
```ts
// app/(admin)/orders/search-params.ts
import {
  createLoader, parseAsInteger, parseAsString, parseAsArrayOf, parseAsStringLiteral,
} from 'nuqs/server';

export const SORTABLE = ['createdAt', 'number', 'customer', 'total', 'status'] as const;
export const STATUSES = ['open', 'pending', 'shipped', 'cancelled'] as const;

export const orderListParsers = {
  page: parseAsInteger.withDefault(1),
  pageSize: parseAsInteger.withDefault(50),
  sort: parseAsString.withDefault('createdAt.desc'),
  q: parseAsString.withDefault(''),
  status: parseAsArrayOf(parseAsStringLiteral(STATUSES)).withDefault([]),
};
export const loadOrderList = createLoader(orderListParsers);
```
Parsers do not validate business rules, so run Zod in the DAL:
```ts
// data/orders.ts
import 'server-only';
import { z } from 'zod';
import { SORTABLE, STATUSES } from '@/app/(admin)/orders/search-params';
import { requireUser, can } from '@/data/auth';

const Query = z.object({
  page: z.number().int().min(1).max(10_000),
  pageSize: z.number().int().refine((n) => [25, 50, 100].includes(n)),
  sort: z.string().regex(/^[a-zA-Z]+\.(asc|desc)$/).refine((s) => SORTABLE.includes(s.split('.')[0] as never)),
  q: z.string().max(200),
  status: z.array(z.enum(STATUSES)).max(STATUSES.length),
});

export async function listOrders(input: unknown) {
  const user = await requireUser();
  if (!can(user, 'read', 'Order')) throw new Error('Forbidden');
  const q = Query.parse(input);
  const [field, dir] = q.sort.split('.') as [(typeof SORTABLE)[number], 'asc' | 'desc'];
  const where = { tenantId: user.tenantId, ...(q.status.length && { status: { in: q.status } }) };
  const [rows, total] = await Promise.all([
    db.order.findMany({
      where, orderBy: { [field]: dir }, skip: (q.page - 1) * q.pageSize, take: q.pageSize,
      select: { id: true, number: true, customerName: true, total: true, status: true, createdAt: true },
    }),
    db.order.count({ where }),
  ]);
  return { rows, total, page: q.page, pageSize: q.pageSize };
}
```

### Server Component page (Next.js 16)
```tsx
// app/(admin)/orders/page.tsx
import type { SearchParams } from 'nuqs/server';
import { loadOrderList } from './search-params';
import { listOrders } from '@/data/orders';
import { OrdersTable } from './orders-table';

export default async function OrdersPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const params = await loadOrderList(searchParams);
  const result = await listOrders(params);
  return <OrdersTable result={result} />;
}
```

### Client table (TanStack Table v9, manual modes)
```tsx
'use client';
import { useTransition } from 'react';
import { useQueryStates } from 'nuqs';
import { useTable, tableFeatures, rowSortingFeature, rowPaginationFeature, type ColumnDef } from '@tanstack/react-table';
import { orderListParsers } from './search-params';

const features = tableFeatures({ rowSortingFeature, rowPaginationFeature });
type Row = { id: string; number: string; customerName: string; total: number; status: string };

const columns: Array<ColumnDef<typeof features, Row>> = [
  { accessorKey: 'number', header: 'Order' },
  { accessorKey: 'customerName', header: 'Customer' },
  { accessorKey: 'total', header: 'Total', meta: { align: 'end' } },
  { accessorKey: 'status', header: 'Status', enableSorting: true },
];

export function OrdersTable({ result }: { result: { rows: Row[]; total: number; page: number; pageSize: number } }) {
  const [isPending, startTransition] = useTransition();
  const [qs, setQs] = useQueryStates(orderListParsers, { shallow: false, startTransition });
  const [sortId, sortDir] = qs.sort.split('.');

  const table = useTable({
    features, columns, data: result.rows,
    manualPagination: true, manualSorting: true, rowCount: result.total,
    state: {
      pagination: { pageIndex: qs.page - 1, pageSize: qs.pageSize },
      sorting: [{ id: sortId, desc: sortDir === 'desc' }],
    },
    onPaginationChange: (u) => {
      const next = typeof u === 'function' ? u({ pageIndex: qs.page - 1, pageSize: qs.pageSize }) : u;
      setQs({ page: next.pageIndex + 1, pageSize: next.pageSize });
    },
    onSortingChange: (u) => {
      const next = typeof u === 'function' ? u([{ id: sortId, desc: sortDir === 'desc' }]) : u;
      const s = next[0];
      setQs({ sort: s ? `${s.id}.${s.desc ? 'desc' : 'asc'}` : null, page: 1 });
    },
  });

  return (
    <table aria-busy={isPending} className="data-table">
      <thead>
        {table.getHeaderGroups().map((hg) => (
          <tr key={hg.id}>
            {hg.headers.map((h) => {
              const sorted = h.column.getIsSorted();
              return (
                <th key={h.id} scope="col" aria-sort={sorted ? (sorted === 'asc' ? 'ascending' : 'descending') : undefined}>
                  {h.column.getCanSort() ? (
                    <button type="button" onClick={h.column.getToggleSortingHandler()}>
                      <table.FlexRender header={h} />
                    </button>
                  ) : <table.FlexRender header={h} />}
                </th>
              );
            })}
          </tr>
        ))}
      </thead>
      <tbody>
        {table.getRowModel().rows.map((row) => (
          <tr key={row.id}>
            {row.getVisibleCells().map((cell) => <td key={cell.id}><table.FlexRender cell={cell} /></td>)}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```
TanStack Table v9 renamed `useReactTable` to `useTable`, requires `features`, and moves row-model factories into `tableFeatures()`. Server-side mode needs no client row models.

## Recommended Workflow
1. List user tasks per screen (find, compare, inspect, act) and the top 5–8 columns.
2. Define the query contract: sortable and filterable allowlists, operators, page size set, count strategy.
3. Implement the DAL function with authz, tenant scoping, Zod validation, and DTO `select`.
4. Write shared nuqs parsers; load them in the Server Component page.
5. Build the headless table with manual modes; wire URL updates with `shallow: false` and a transition.
6. Add toolbar (search, filters, column picker, density), row actions, empty/loading/error states.
7. Add selection and bulk actions if needed ([bulk-actions](../bulk-actions/Skill.md)).
8. Test URL round-trips, authz, keyboard, and screen reader output.

## Patterns
- **URL-as-state list**: nuqs parsers shared by `page.tsx` (server) and the table (client).
- **Keep-previous-data**: render current rows with `aria-busy` while the transition fetches the next page.
- **Density tokens**: `data-density="compact|default|comfortable"` on the table root drives row height and padding CSS variables.
- **Column preferences**: `{ visible: string[]; order: string[]; widths: Record<string, number> }` persisted per user and per saved view.
- **Row click to detail**: the identifier cell holds a real `<Link>`; the row gets hover style only. Opens a side panel or detail route ([master-detail-layouts](../master-detail-layouts/Skill.md)).
- **Estimated counts**: `total: null` plus "Next" enabled while `rows.length === pageSize`.

## Anti-Patterns
- **Fetching all rows and paginating client-side**: slow and leaks data. Fix: manual pagination with server query.
- **Sorting by any `?sort=` value passed to the ORM**: injection or unindexed full scans. Fix: allowlist plus indexes on sortable columns.
- **List state in `useState` only**: lost on refresh and not shareable. Fix: nuqs URL state.
- **Not resetting page on filter change**: users land on empty page 7. Fix: set `page: 1` with every filter or sort update.
- **Hiding sensitive columns with CSS or column visibility**: data is still in the RSC payload. Fix: omit fields in the DAL DTO.
- **Whole-row `onClick` with nested buttons**: accidental navigation, inaccessible. Fix: link in the identifier cell, `stopPropagation` avoided by design.
- **Spinner replacing the table on each page change**: layout jump. Fix: keep previous rows, show progress bar.
- **Zebra striping plus borders plus hover plus heavy colors**: noise. Fix: pick one row separator style; highlight selection clearly.

## Accessibility
- Use a native `<table>` with `<caption>` (can be visually hidden), `<th scope="col">`, and `aria-sort` on sorted headers (WCAG 1.3.1).
- Sort controls are `<button>` elements inside headers; announce sort changes via a polite live region.
- Use the ARIA grid pattern (roving tabindex, arrow keys, Enter/F2 to edit) only when cells are interactive like a spreadsheet; otherwise a table keeps all controls in the tab order (APG guidance).
- With virtualization, set `aria-rowcount` and `aria-rowindex` so position is conveyed.
- Selection checkboxes need labels like "Select order SO-1042"; header checkbox reflects mixed state.
- Density "compact" must still meet target size 24x24 CSS px for controls (WCAG 2.5.8).
- Status cells use text plus color, never color alone (1.4.1).

## Responsive Design
- Below tablet widths, switch to a stacked "record card" list that shows the identifier and 2–3 key fields, keeping the same URL state.
- Otherwise allow horizontal scroll inside a focusable, labeled region (`role="region"`, `tabIndex={0}`, `aria-label`) with sticky first column.
- Move column picker and density into an overflow menu on small screens.
- Use container queries when tables appear inside resizable panes.

## Performance
- Index every sortable and filterable column combination you allow; set a maximum page size.
- Avoid `COUNT(*)` on huge tables per request; cache counts or return estimates.
- Stream the table with `loading.tsx` or Suspense around the table body so toolbar renders immediately.
- Virtualize only when showing more than about 100 rows per page ([list-virtualization](../list-virtualization/Skill.md)).
- Memoize column definitions outside render; keep cell renderers cheap.
- Debounce search input (250–400 ms) via nuqs `throttleMs` or a debounced setter.

## Security
- Every list and mutation goes through a `server-only` DAL that authenticates, authorizes, scopes by tenant, and validates input (Next.js data-security guide).
- Server Actions for row actions re-check authorization and resource ownership (IDOR) on each call; the page-level check does not cover them.
- Return minimal DTOs from the DAL and from actions.
- Exports honor the same filters and permissions as the table.
- Search parameters are untrusted input; never interpolate them into SQL.

## Testing
- Unit: Zod query schema rejects unknown sort fields, oversized page sizes, bad operators.
- Integration: DAL returns only tenant-scoped rows and allowed fields per role.
- Component (Vitest + Testing Library): sort button toggles `aria-sort`, pagination updates URL, page resets on filter.
- E2E (Playwright): load a deep link with filters and sort, reload, press back; verify identical rows.
- Accessibility: axe checks plus manual screen reader pass on header sort announcements.

## Tooling
- `@tanstack/react-table` v9 (9.2.4 on npm at verification; MIT). v9 API differs from v8; `useLegacyTable` exists as a deprecated bridge.
- `nuqs` 2.x (2.10.1 at verification) for URL state; requires `NuqsAdapter`.
- `zod` for query validation.
- `@tanstack/react-virtual` for large pages.
- Commercial grids: AG Grid Enterprise, MUI X Pro/Premium. MIT alternatives: AG Grid Community, MUI X Data Grid community, Glide Data Grid.

## Framework Notes
- **Next.js (App Router)**: page is a Server Component that awaits `searchParams` (a Promise in Next.js 16), loads via nuqs `createLoader`, calls the DAL, and passes DTO rows to a client table. URL updates use `shallow: false` so the server re-renders. Mount `NuqsAdapter` from `nuqs/adapters/next/app` in the root layout.
- **React (Vite SPA)**: use `NuqsAdapter` for React Router or plain React; fetch with TanStack Query keyed by the parsed URL state (`placeholderData: keepPreviousData`); the API server enforces the same contract and authz.

## AI Agent Guidance
- Do: define the allowlisted query contract before writing UI; share parsers between server and client; select DTO fields explicitly; add `aria-sort`; reset page on filter change.
- Do: verify the installed TanStack Table major version before writing code (v8 `useReactTable` vs v9 `useTable`).
- Don't: paginate or filter client-side for server data; pass raw search params to the ORM; hide sensitive columns only in the UI.
- Before declaring done: reload a filtered/sorted deep link, confirm unauthorized roles cannot fetch hidden fields, run axe, tab through the table.

## Examples
Density tokens (the choice is a radio group in a menu, persisted per user via a Server Action that re-checks the session):
```css
.data-table[data-density='compact'] { --row-h: 32px; --cell-px: 8px; }
.data-table[data-density='default'] { --row-h: 40px; --cell-px: 12px; }
.data-table[data-density='comfortable'] { --row-h: 48px; --cell-px: 16px; }
.data-table td { block-size: var(--row-h); padding-inline: var(--cell-px); }
```

## Related Skills
- [tanstack-table](../tanstack-table/Skill.md) — headless table API in depth
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md) — when a table becomes a grid
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — filter builder and saved views
- [bulk-actions](../bulk-actions/Skill.md) — selection and batch operations
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — URL state mechanics
- [accessible-data-tables](../accessible-data-tables/Skill.md) — table semantics
- [list-virtualization](../list-virtualization/Skill.md) — large pages
- [pagination](../pagination/Skill.md) — pagination controls
- [master-detail-layouts](../master-detail-layouts/Skill.md) — opening records from the list

## Sources
- [NN/g: Data Tables: Four Major User Tasks](https://www.nngroup.com/articles/data-tables/) — Community (research) — four tasks, frozen headers, nonmodal edit panels
- [TanStack Table docs (v9 guides on GitHub)](https://github.com/TanStack/table/tree/main/docs) — Official — `useTable`, `tableFeatures`, manual modes, `table.FlexRender`, migration notes
- [npm @tanstack/react-table](https://www.npmjs.com/package/@tanstack/react-table) — Official — version 9.2.4
- [nuqs server-side docs](https://nuqs.dev/docs/server-side) — Official — `createLoader`, `createSearchParamsCache`, validation caveat
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, DTOs, Server Action authz
- [W3C APG Grid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — table vs grid decision, aria-rowcount
- [Elastic EUI Data Grid](https://eui.elastic.co/docs/components/tabular-content/data-grid/) — Open Source — density, column selector, toolbar controls

## License / Usage Notes
TanStack Table, nuqs, Zod, Glide Data Grid: MIT. AG Grid Enterprise and MUI X Pro/Premium require commercial licenses. Content summarized from the sources above; code is original.

## Quality Tier
A — built on verified official docs (TanStack v9, nuqs, Next.js security) plus NN/g research; density pixel values are conventions, not a spec.

## Status
Active

## Last Verified
2026-09-15
