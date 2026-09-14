# TanStack Table

## Summary
TanStack Table is a headless table and datagrid engine. It gives you row models (sorting, filtering, pagination, grouping, expanding, selection, column sizing and pinning), and you render the markup. **V9 went stable on August 4, 2026.** V9 adds tree-shakable opt-in features registered via `tableFeatures()`, state built on TanStack Store atoms with fine-grained subscriptions, lower memory use, and React Compiler compliance. V8 (`useReactTable`) is still widespread. This skill covers both, with a migration path, plus server-side mode, virtualization and accessibility.

## Category
React

## Subcategories
headless tables, column definitions, sorting, filtering, pagination, row selection, server-side (manual) mode, virtualization, v8 to v9 migration, React Compiler compatibility

## Problem It Solves
Hand-built tables get sorting, filtering, pagination and selection wrong and are hard to type. Heavy grid libraries dictate styling. TanStack Table provides the logic with full TypeScript types, while your design system renders accessible markup.

## When To Use
- Data tables in admin panels, dashboards and SaaS apps with custom design systems (shadcn/ui data table builds on it).
- Client-side datasets up to tens of thousands of rows (with virtualization), or server-driven tables with URL state.

## When Not To Use
- Simple static tables: a semantic `<table>` is enough.
- Spreadsheet-grade grids (cell editing at scale, pivoting, Excel export, 1M rows): consider AG Grid (see data-grids-ag-grid).
- When you need batteries-included styled UI with no design effort: Mantine React Table, MUI X DataGrid.

## Core Principles
1. **Headless**: the table instance computes state and row models, and you render semantic HTML (`<table>`, `<th scope="col">`, `aria-sort`).
2. **Stable `data` and `columns` references**: define columns at module scope or memoize. Unstable arrays cause re-computation and render loops.
3. **Opt into only the features you use** (V9 `tableFeatures`, V8 `get*RowModel` options), which keeps the bundle small and behaviour explicit.
4. **Choose client or server processing per feature** (`manualSorting`, `manualFiltering`, `manualPagination`) based on data size.
5. **Controlled state for anything that belongs in the URL** (sorting, filters, page), and internal state for ephemeral UI (column sizing during drag).
6. **Render large tables with virtualization**, not all rows.

## Best Practices
- Type columns with the row type (V8 `ColumnDef<Person>` / `createColumnHelper<Person>()`; V9 `ColumnDef<typeof features, Person>`).
- Provide `getRowId: (row) => row.id` so selection and expansion survive re-sorting and refetches.
- Sync sorting, filtering and pagination to URL search params (nuqs in Next.js) for shareable views.
- In server mode, include table state in the TanStack Query key and use `placeholderData: keepPreviousData`.
- Debounce global filter input (or use `useDeferredValue`).
- Virtualize with `@tanstack/react-virtual` beyond a few hundred rows. Keep header semantics.
- **React Compiler + V8**: `useReactTable` returns a mutable instance that the compiler can memoize incorrectly (stale UI). Add `"use no memo"` to components that use it, or migrate to V9, which was designed for compiler compliance.

## Implementation Guidance
**Client vs server processing**

| Data size / source | Sorting | Filtering | Pagination |
|---|---|---|---|
| < ~5k rows loaded once | Client | Client | Client |
| 5k–50k rows loaded once | Client + virtualization | Client (debounced) | Client or virtual scroll |
| Large or remote datasets | `manualSorting` (server) | `manualFiltering` (server) | `manualPagination` + `rowCount` |

**V9 (stable, Aug 2026): basic shape**
```tsx
"use client";
import {
  tableFeatures, useTable,
  rowSortingFeature, createSortedRowModel,
  rowPaginationFeature, createPaginatedRowModel,
  type ColumnDef,
} from "@tanstack/react-table";

const features = tableFeatures({
  rowSortingFeature,
  sortedRowModel: createSortedRowModel(),
  rowPaginationFeature,
  paginatedRowModel: createPaginatedRowModel(),
});

type Invoice = { id: string; customer: string; totalCents: number; status: "paid" | "open" };

const columns: ColumnDef<typeof features, Invoice>[] = [
  { accessorKey: "customer", header: "Customer" },
  { accessorKey: "totalCents", header: "Total", cell: (info) => formatMoney(info.getValue<number>()) },
  { accessorKey: "status", header: "Status" },
];

export function InvoiceTable({ data }: { data: Invoice[] }) {
  const table = useTable({ features, columns, data });
  // Render with table.getHeaderGroups() / table.getRowModel().rows and table.FlexRender
  // (verify exact FlexRender props and subscription helpers such as table.Subscribe against V9 docs)
  return <InvoiceTableMarkup table={table} />;
}
```
Key V9 differences: features and row models are registered explicitly (tree-shakable), state is stored in TanStack Store atoms (subscribe only to the slices a component needs), and feature APIs remain (`table.setSorting`, `table.nextPage`). `useReactTable` in V9 is a framework-specific wrapper name kept for familiarity. Follow the official migration guide for exact renames.

**V8 (widely deployed): full example with controlled sorting**
```tsx
"use client"; // Next.js
import { useState } from "react";
import {
  useReactTable, getCoreRowModel, getSortedRowModel, getPaginationRowModel,
  flexRender, createColumnHelper, type SortingState,
} from "@tanstack/react-table";

const col = createColumnHelper<Invoice>();
const columns = [
  col.accessor("customer", { header: "Customer" }),
  col.accessor("totalCents", { header: "Total", cell: (i) => formatMoney(i.getValue()) }),
  col.accessor("status", { header: "Status" }),
];

export function InvoiceTableV8({ data }: { data: Invoice[] }) {
  "use no memo"; // if React Compiler is enabled
  const [sorting, setSorting] = useState<SortingState>([]);
  const table = useReactTable({
    data, columns, state: { sorting }, onSortingChange: setSorting,
    getRowId: (r) => r.id,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  });
  return (
    <table>
      <caption className="sr-only">Invoices</caption>
      <thead>
        {table.getHeaderGroups().map((hg) => (
          <tr key={hg.id}>
            {hg.headers.map((h) => {
              const sorted = h.column.getIsSorted();
              return (
                <th key={h.id} scope="col" aria-sort={sorted === "asc" ? "ascending" : sorted === "desc" ? "descending" : "none"}>
                  {h.column.getCanSort() ? (
                    <button type="button" onClick={h.column.getToggleSortingHandler()}>
                      {flexRender(h.column.columnDef.header, h.getContext())}
                    </button>
                  ) : flexRender(h.column.columnDef.header, h.getContext())}
                </th>
              );
            })}
          </tr>
        ))}
      </thead>
      <tbody>
        {table.getRowModel().rows.map((row) => (
          <tr key={row.id}>
            {row.getVisibleCells().map((cell) => (
              <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

**Server-side mode (V8 options; same concepts in V9)**
```ts
useReactTable({
  data: query.data?.rows ?? [], columns,
  rowCount: query.data?.total,
  state: { sorting, pagination },
  onSortingChange: setSorting, onPaginationChange: setPagination,
  manualSorting: true, manualPagination: true,
  getCoreRowModel: getCoreRowModel(),
});
// query key: ["invoices", { sorting, pagination }] with placeholderData: keepPreviousData
```

## Recommended Workflow
1. Define the row type and column definitions at module scope.
2. Decide client or server processing per feature (table above).
3. Choose the version: V9 for new projects (especially with React Compiler), V8 for existing code until migration.
4. Wire controlled state for URL-worthy state (nuqs / search params).
5. Render semantic, accessible markup (caption, scope, aria-sort, sort buttons).
6. Add virtualization if row count warrants it.
7. Test sorting, filtering, pagination and selection through the UI.

## Patterns
- **Reusable `<DataTable table={table} />` renderer** plus per-screen column definitions (the shadcn/ui pattern).
- **Row selection column** with an accessible checkbox header (`aria-label="Select all rows"`, indeterminate state).
- **Column visibility menu** persisted per user.
- **Faceted filters** using faceted row models for option counts.
- **Virtualized body** with `useVirtualizer`, keeping `<table>` semantics via padding rows or CSS grid with ARIA grid roles.

## Anti-Patterns
- **Inline `columns` or `data` arrays in render** (without compiler or memo): recomputation and potential infinite loops. Fix: module scope or `useMemo`.
- **Index-based row ids with selection**: selection jumps after sort. Fix: `getRowId`.
- **Client-side filtering of paged server data**: wrong results. Fix: `manual*` modes.
- **Clickable `<th>` without a button**: not keyboard accessible. Fix: a button inside the header.
- **Div-soup tables without roles**: screen readers lose structure. Fix: `<table>`, or a full ARIA grid pattern.
- **V8 + React Compiler without opt-out**: stale table UI. Fix: `"use no memo"` or V9.
- **Rendering 10k rows**. Fix: virtualization or pagination.

## Accessibility
- Use native `<table>` with `<caption>` (visible or `sr-only`), `<th scope="col">`, and `aria-sort` on sortable headers (WCAG 1.3.1).
- Sorting controls are buttons with clear names ("Sort by Total"). Announce sort or filter result changes with a polite live region ("32 results, sorted by Total descending").
- Selection checkboxes need labels ("Select row INV-1042").
- Only use `role="grid"` with full arrow-key navigation (see keyboard-navigation). Otherwise stay with table semantics.
- Virtualized tables: set `aria-rowcount` and `aria-rowindex` so assistive tech knows the full size.

## Responsive Design
- Horizontal scroll container with a sticky first column for wide tables (`overflow-x: auto`, `position: sticky`). Keep the header visible.
- For narrow screens, consider column visibility presets or a card/list layout that renders from the same row model.
- Use container queries for the table wrapper when it's embedded in resizable panels.

## Performance
- V9's tree-shakable features cut the bundle (a small table starts around 5 KB) and its store subscriptions reduce re-renders.
- Memoize or stabilize `data`/`columns`. Use `getRowId`.
- Virtualize large bodies. Debounce filters. Push heavy processing to the server.
- Avoid expensive cell renderers. Hoist formatters (`Intl.NumberFormat` instances) to module scope.

## Security
- Cell renderers must not inject raw HTML from data. Rely on React escaping.
- Server-side sorting and filtering params are user input: allow-list sortable columns and validate before building SQL.

## Testing
- Testing Library: click the sort header button, assert row order via `within(rows[1]).getByText(...)` and `aria-sort` values.
- Server mode: MSW handlers that assert query params (sort, page) and return fixtures.
- Playwright for virtualization scroll and sticky headers. Axe checks for table semantics.

## Tooling
- `@tanstack/react-table` V9 (stable Aug 2026) / V8 (maintenance; widely used).
- `@tanstack/react-virtual` for virtualization.
- shadcn/ui Data Table recipe (built on TanStack Table).
- Alternatives: AG Grid (enterprise grid), MUI X DataGrid, Mantine React Table.

## Framework Notes
### React (Vite SPA)
- Tables are fully client-side. Pair with TanStack Query for server mode, and sync state to router search params.

### Next.js App Router
- Table components use hooks, so mark the table module `"use client"`. Fetch initial data in the Server Component page and pass serializable rows as props.
- **Column definitions containing `cell` functions can't be passed from Server Components** (functions aren't serializable). Define columns inside the client module.
- Server-side mode: read `searchParams` (Promise) in the page, query the DB with validated sort and page params, and render the client table with `manualSorting`/`manualPagination`. Update the URL with nuqs (`shallow: false`) so the Server Component re-renders.
- Hydration: format dates and numbers deterministically (explicit locale and timezone) to avoid server/client text mismatches in cells.

## AI Agent Guidance
- Check the installed `@tanstack/react-table` major version before generating code. Don't mix V8 (`getCoreRowModel`, `useReactTable` with `get*RowModel` options) and V9 (`tableFeatures`, `useTable`) APIs.
- If the React Compiler is enabled and V8 is used, add `"use no memo"` to table components or propose V9.
- Always generate `getRowId`, semantic headers with `aria-sort`, and stable `columns`.
- Verify: sorting, pagination and selection work by keyboard, no infinite render loops, URL state round-trips, and axe shows no table violations.

## Examples
```tsx
// Next.js page (Server Component) feeding a client table with URL-driven server sorting
export default async function InvoicesPage({ searchParams }: { searchParams: Promise<{ sort?: string; page?: string }> }) {
  const sp = await searchParams;
  const sort = ["customer", "totalCents", "status"].includes(sp.sort ?? "") ? sp.sort! : "customer";
  const page = Math.max(1, Number(sp.page) || 1);
  const { rows, total } = await listInvoices({ sort, page, pageSize: 50 });
  return <InvoiceTableServerMode rows={rows} total={total} sort={sort} page={page} />;
}
```

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md): table UX at enterprise scale
- [accessible-data-tables](../accessible-data-tables/Skill.md): table semantics and ARIA
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md): when a full grid is needed
- [list-virtualization](../list-virtualization/Skill.md): virtualization techniques
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): URL-synced table state
- [react-compiler](../react-compiler/Skill.md): V8 compatibility caveat
- [shadcn-ui](../shadcn-ui/Skill.md): data table recipe

## Sources
- [Announcing TanStack Table V9 (Aug 4 2026)](https://tanstack.com/blog/announcing-tanstack-table-v9) (Official): features registration, store-based state, adapters
- [TanStack Table docs (React quick start)](https://tanstack.com/table/latest/docs/framework/react/react-table) (Official): useTable, tableFeatures, ColumnDef generics
- [InfoQ: TanStack Table V9 Beta (Jul 2026)](https://www.infoq.com/news/2026/07/tanstack-table-v9-beta/) (Community): tree-shaking, memory, store subscriptions
- [TanStack Table V8 docs: sorting, pagination, manual mode](https://tanstack.com/table/v8/docs/guide/sorting) (Official): V8 API used in example
- [React Compiler docs: incremental adoption / "use no memo"](https://react.dev/learn/react-compiler/incremental-adoption) (Official): opt-out mechanism

## License / Usage Notes
TanStack Table is MIT. V9 code is illustrative. Exact V9 render and subscription helper signatures (`table.FlexRender`, `table.Subscribe`) were not fully verified and should be checked against the V9 docs.

## Quality Tier
B: V8 guidance is solid; V9 became stable six weeks ago and only its API shape could be verified, not its full signatures.

## Status
Active

## Last Verified
2026-09-15
