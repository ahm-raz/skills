# Data Grids with AG Grid (and Alternatives)

## Summary
Using a full-featured data grid (AG Grid first, with MUI X Data Grid and Glide Data Grid as alternatives) in React and Next.js for spreadsheet-like enterprise screens: inline editing, range selection, grouping, pivoting, server-side row models, and Excel export. Covers the Community vs Enterprise licensing split, module registration, the Theming API and density, server-side data contracts, and secure editing through Server Actions or route handlers.

## Category
Enterprise UI

## Subcategories
AG Grid, MUI X Data Grid, Glide Data Grid, server-side row model, inline editing, grid theming, licensing, grid accessibility

## Problem It Solves
Some enterprise screens are really spreadsheets: planners editing hundreds of cells, analysts grouping and pivoting, operators watching live-updating rows. Building that on a headless table takes months. A commercial-grade grid provides it, but it brings licensing obligations, bundle weight, client-only rendering, and a separate editing path that must be secured.

## When To Use
- Cell-level editing with keyboard navigation, copy/paste, fill, range selection.
- Row grouping, aggregation, pivoting, tree data, master/detail rows.
- 100k+ rows with server-side lazy loading and grouping (AG Grid SSRM).
- Excel export with formatting, integrated charts, tool panels.
- Real-time updates at high frequency.

## When Not To Use
- Standard record lists with sort, filter, pagination: a design-system table is lighter and more accessible ([enterprise-data-tables](../enterprise-data-tables/Skill.md)).
- SEO or server-rendered content: grids render on the client.
- When the team cannot budget Enterprise licenses but the design depends on Enterprise-only features. Decide this before designing.

## Core Principles
1. Decide Community vs Enterprise before design; do not prototype on Enterprise features you won't license.
2. The grid is a client component; data authority stays on the server. Every edit is validated and authorized server-side.
3. Register only the modules you use; bundle size scales with features.
4. Give every row a stable ID (`getRowId`) so updates, selection, and edits survive refetches.
5. Configure the grid through a single typed wrapper so theme, locale, defaults, and a11y settings are consistent app-wide.
6. Treat the server-side row model request as untrusted input: allowlist columns, operators, and group fields.

## Best Practices
- Wrap AG Grid in one `AppGrid` client component that sets `theme`, `defaultColDef`, `getRowId`, locale text, and loading/empty overlays.
- Use `AgGridProvider` (recommended since v35.1 per docs) to register modules once near the admin layout.
- Use the Theming API (`themeQuartz.withParams`) for density rather than overriding CSS classes. Map app density to `spacing`, `rowHeight`, `headerHeight`, `fontSize`.
- Type column definitions with `ColDef<Row>` and field keys; avoid string field paths that drift from DTOs.
- Commit edits per cell or per row via a Server Action; show a pending state and roll back on failure.
- Prefer `applyTransaction` or updated immutable `rowData` with `getRowId` over replacing the dataset.
- Use value formatters for display and keep raw values in the data for sorting and export.
- Keep a visible "Reset columns" action once users can resize, reorder, and pin; persist column state per user.

## Implementation Guidance

### Licensing and feature split (AG Grid 36.1.0 at verification)
| Tier | License | Examples |
|---|---|---|
| Community (`ag-grid-community`, `ag-grid-react`) | MIT, free in production | Client-side row model, sorting, filtering, editing, CSV export, pagination, theming |
| Enterprise (`ag-grid-enterprise`) | Commercial EULA; runs unlicensed locally with watermark/console warnings; 30-day trial key | Server-side row model, row grouping, aggregation, pivoting, range selection, clipboard, Excel export, master/detail, integrated charts, tool panels, context menu |

Check the current AG Grid pricing and feature matrix before committing; the split above is summarized from the licensing page.

### Alternatives
| Grid | License | Notes |
|---|---|---|
| MUI X Data Grid | Community MIT; Pro adds multi-sort/multi-filter, resizing, pinning; Premium adds row grouping, Excel export | `dataSource` prop with `getRows` (available in Community) sets pagination/sort/filter modes to server; built-in cache (5 min TTL default). License key set via `LicenseInfo.setLicenseKey` from `@mui/x-license` before first render; keys are public by design |
| Glide Data Grid | MIT | Canvas rendering, millions of rows, very high update rates; verify accessibility yourself (canvas) |
| TanStack Table + virtualizer | MIT | Headless; you build every grid behavior |

### Module registration and theme
```tsx
// app/(admin)/_components/grid-provider.tsx
'use client';
import { AgGridProvider } from 'ag-grid-react';
import { ClientSideRowModelModule, TextFilterModule, NumberFilterModule, ValidationModule } from 'ag-grid-community';
import type { ReactNode } from 'react';

const modules = [
  ClientSideRowModelModule, TextFilterModule, NumberFilterModule,
  ...(process.env.NODE_ENV !== 'production' ? [ValidationModule] : []),
];

export function GridProvider({ children }: { children: ReactNode }) {
  return <AgGridProvider modules={modules}>{children}</AgGridProvider>;
}
```
Module names are per AG Grid's module docs; confirm exact exports for your version. For prototypes, `AllCommunityModule` / `AllEnterpriseModule` register everything at the cost of bundle size. Enterprise license key setup: follow the "Installing AG Grid Enterprise" docs for your version (historically `LicenseManager.setLicenseKey` from `ag-grid-enterprise`). The key ships in the client bundle; treat it as licensed configuration, not a secret, and keep it out of public repositories per your EULA.

```tsx
// app/(admin)/_components/app-grid.tsx
'use client';
import { AgGridReact, type AgGridReactProps } from 'ag-grid-react';
import { themeQuartz } from 'ag-grid-community';

const densities = {
  compact: themeQuartz.withParams({ spacing: 4, rowHeight: 28, headerHeight: 32, fontSize: 13 }),
  default: themeQuartz.withParams({ spacing: 8, rowHeight: 36, headerHeight: 40, fontSize: 14 }),
  comfortable: themeQuartz.withParams({ spacing: 12, rowHeight: 44, headerHeight: 48, fontSize: 14 }),
};

export function AppGrid<T extends { id: string }>(
  props: AgGridReactProps<T> & { density?: keyof typeof densities },
) {
  const { density = 'default', ...rest } = props;
  return (
    <div style={{ blockSize: 600 }}>
      <AgGridReact<T>
        theme={densities[density]}
        getRowId={(p) => p.data.id}
        defaultColDef={{ sortable: true, resizable: true, filter: true }}
        {...rest}
      />
    </div>
  );
}
```

### Server-side row model contract (Enterprise)
The datasource `getRows(params)` receives `params.request` with `startRow`, `endRow`, `sortModel`, `filterModel`, `rowGroupCols`, `groupKeys` (plus pivot/value columns), and replies with `params.success({ rowData, rowCount })` or `params.fail()`.
```tsx
'use client';
import type { IServerSideDatasource } from 'ag-grid-community';

export const ordersDatasource: IServerSideDatasource = {
  async getRows(params) {
    const res = await fetch('/api/grid/orders', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(params.request),
    });
    if (!res.ok) return params.fail();
    const { rows, total } = (await res.json()) as { rows: unknown[]; total: number };
    params.success({ rowData: rows, rowCount: total });
  },
};
// <AppGrid rowModelType="serverSide" serverSideDatasource={ordersDatasource} ... />
```
```ts
// app/api/grid/orders/route.ts
import { z } from 'zod';
import { queryOrdersForGrid } from '@/data/orders-grid'; // server-only DAL: authz + tenant scope

const COLS = ['number', 'customer', 'status', 'total', 'createdAt'] as const;
const Req = z.object({
  startRow: z.number().int().min(0),
  endRow: z.number().int().positive(),
  sortModel: z.array(z.object({ colId: z.enum(COLS), sort: z.enum(['asc', 'desc']) })).max(3),
  filterModel: z.record(z.enum(COLS), z.unknown()).nullable().optional(),
  rowGroupCols: z.array(z.object({ id: z.enum(COLS) })).max(2),
  groupKeys: z.array(z.string().max(200)),
}).refine((r) => r.endRow - r.startRow <= 500, 'block too large');

export async function POST(req: Request) {
  const parsed = Req.safeParse(await req.json());
  if (!parsed.success) return Response.json({ error: 'Bad request' }, { status: 400 });
  const result = await queryOrdersForGrid(parsed.data); // throws on unauthorized
  return Response.json(result);
}
```
Filter models differ per filter type; translate each allowed filter type explicitly and reject the rest.

### Secure cell editing
```tsx
'use client';
import { updateOrderField } from './actions';
// in AppGrid props:
onCellValueChanged={async (e) => {
  const res = await updateOrderField({ id: e.data.id, field: e.colDef.field!, value: e.newValue });
  if (!res.ok) e.node.setDataValue(e.colDef.field!, e.oldValue); // roll back and surface error
}}
```
```ts
'use server';
import { z } from 'zod';
import { updateOrder } from '@/data/orders'; // re-authenticates, checks ownership, validates
const Edit = z.discriminatedUnion('field', [
  z.object({ id: z.string(), field: z.literal('status'), value: z.enum(['open', 'shipped']) }),
  z.object({ id: z.string(), field: z.literal('dueDate'), value: z.string().date() }),
]);
export async function updateOrderField(input: unknown) {
  const p = Edit.safeParse(input);
  if (!p.success) return { ok: false as const, error: 'Invalid value' };
  await updateOrder(p.data.id, { [p.data.field]: p.data.value });
  return { ok: true as const };
}
```

## Recommended Workflow
1. List required grid features; mark each Community or Enterprise (or MUI tier); get license sign-off.
2. Define DTO row type and column definitions typed with `ColDef<Row>`.
3. Create `GridProvider` and `AppGrid` wrappers with theme, density, `getRowId`, overlays.
4. Choose row model: client-side (under ~10–50k rows loaded once) or server-side (Enterprise) / MUI `dataSource`.
5. Implement the route handler or DAL contract with allowlists and authz.
6. Add editing through Server Actions with validation and rollback.
7. Persist column state per user; add reset.
8. Test keyboard use, screen reader output, large data, and permission failures.

## Patterns
- **Grid wrapper**: one `AppGrid` owns theme, locale, defaults; screens only pass columns and data source.
- **Column state persistence**: save `api.getColumnState()` on column events (debounced) and restore with `api.applyColumnState` on `onGridReady`.
- **Per-field editability from permissions**: compute `editable` in column defs from a server-provided capability map, and still enforce on the server.
- **Live updates**: batch server events and apply with transactions keyed by `getRowId`.
- **Hybrid list**: URL-synced filters outside the grid (nuqs) feed the datasource; purge the server-side cache on filter change.

## Anti-Patterns
- **Shipping Enterprise features in production without a license**: legal risk and watermarks. Fix: license or restrict to Community modules.
- **Registering `AllEnterpriseModule` in a screen that uses sorting only**: large bundle. Fix: register specific modules.
- **Trusting `onCellValueChanged` as the save**: client can edit anything. Fix: Server Action with schema, ownership, and field-level permission checks.
- **No `getRowId`**: selection and edits lost on refresh, full re-render. Fix: stable IDs.
- **Passing `filterModel` straight into a query builder**: injection and unindexed scans. Fix: translate allowlisted filter types.
- **Rendering the grid in a Server Component**: runtime error. Fix: `'use client'` wrapper; pass serializable DTOs.
- **Styling via legacy theme CSS classes mixed with Theming API**: conflicts. Fix: one theming approach (Theming API is the current default; check docs when migrating older versions).

## Accessibility
- Data grids use the ARIA grid pattern: one tab stop, arrow-key navigation, Home/End, Ctrl+Home/End, PageUp/PageDown, Enter or F2 to edit, Escape to cancel (APG).
- AG Grid and MUI X implement grid roles and `aria-rowcount`/`aria-rowindex` for virtualized rows; verify with a screen reader in your configuration, especially custom cell renderers.
- Custom cell renderers must not add extra tab stops; interactive content inside cells should be reachable via Enter.
- Canvas grids (Glide) expose limited semantics; confirm screen reader support before choosing for public-sector or WCAG-bound products.
- Provide a non-grid path (export, detail view) for tasks that are hard with assistive tech.
- Keep contrast of selection and focus rings at 3:1 against adjacent colors (WCAG 1.4.11).

## Responsive Design
- Grids are desktop tools; on small screens offer a simplified list or read-only card view instead.
- Give the grid container an explicit height (or `domLayout` auto-height for short grids) so it lays out correctly in flex/grid parents.
- Hide tool panels and secondary columns under a width breakpoint; pin the identifier column.

## Performance
- Client-side row model: fine for tens of thousands of rows loaded once; beyond that, use server-side models or MUI `dataSource`.
- Row and column virtualization are built in; avoid heavy React cell renderers on every cell (prefer value formatters or lightweight renderers).
- Use transactions for streaming updates; avoid replacing `rowData` arrays at high frequency.
- Lazy-load the grid chunk (`next/dynamic` in a client component) on routes where it appears below the fold.
- Server-side: cap block sizes, index group/sort fields, cache group counts.

## Security
- UI `editable` flags are convenience only; enforce per-field permissions in the Server Action or DAL.
- Validate SSRM requests with Zod; allowlist columns, sort fields, filter types, and group columns; cap block size.
- Excel/CSV exports must respect row-level and field-level permissions; do server-side export for sensitive data.
- Escape formula-like values in exports (`=`, `+`, `-`, `@`) to prevent CSV/formula injection.
- License keys are not secrets but are licensed assets; never put real secrets in `NEXT_PUBLIC_` variables.

## Testing
- Unit: SSRM request schema and filter-model translation.
- Integration: route handler returns 400 on disallowed columns, 403 for unauthorized roles, tenant-scoped rows.
- E2E (Playwright): edit a cell, confirm persisted after reload; simulate server rejection and confirm rollback message.
- Keyboard E2E: arrow navigation, Enter to edit, Escape to cancel.
- Performance: load test SSRM endpoint with realistic block sizes.

## Tooling
- AG Grid: `ag-grid-community`, `ag-grid-react` (MIT), `ag-grid-enterprise` (commercial). 36.1.0 released 2026-08-05.
- MUI X Data Grid: `@mui/x-data-grid` (MIT), `@mui/x-data-grid-pro`, `@mui/x-data-grid-premium` (commercial), `@mui/x-license`.
- Glide Data Grid: `@glideapps/glide-data-grid` (MIT).
- Zod for request validation.

## Framework Notes
- **Next.js (App Router)**: grids are Client Components. Fetch initial data in a Server Component via the DAL and pass DTOs as `rowData`, or use a route handler for SSRM/infinite loading. Mutations go through Server Actions that re-authorize. Put `GridProvider` in an admin segment layout, not the root, to keep grid code off marketing routes.
- **React (Vite SPA)**: register modules once at app entry or with `AgGridProvider`; datasource calls your API; the API enforces authz. Use route-level code splitting for grid screens.

## AI Agent Guidance
- Do: check `package.json` for installed grid packages and tier before using features; ask if an Enterprise feature is required and unlicensed.
- Do: add `getRowId`, typed `ColDef<Row>`, theme via Theming API, specific modules.
- Do: implement edits as Server Actions with Zod and authorization; roll back on failure.
- Don't: import from `ag-grid-enterprise` in a Community-only project; don't invent module or option names; confirm against current docs.
- Before done: run the grid with the production build to check bundle size and license console warnings; test keyboard edit flow and a forbidden edit.

## Examples
MUI X server data source (Community tier):
```tsx
'use client';
import { DataGrid, type GridDataSource, type GridColDef } from '@mui/x-data-grid';

const columns: GridColDef[] = [{ field: 'number', headerName: 'Order', flex: 1 }, { field: 'total', type: 'number' }];

const dataSource: GridDataSource = {
  getRows: async (params) => {
    const res = await fetch('/api/mui/orders', { method: 'POST', body: JSON.stringify(params) });
    const data = await res.json();
    return { rows: data.rows, rowCount: data.total };
  },
};

export function OrdersMuiGrid() {
  return <DataGrid columns={columns} dataSource={dataSource} pagination initialState={{ pagination: { paginationModel: { pageSize: 50, page: 0 } } }} pageSizeOptions={[25, 50, 100]} />;
}
```
Verify `GridDataSource` type names against current MUI X docs for your major version.

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — lighter table path and query contract
- [tanstack-table](../tanstack-table/Skill.md) — headless alternative
- [list-virtualization](../list-virtualization/Skill.md) — virtualization concepts
- [material-ui](../material-ui/Skill.md) — MUI X lives in this ecosystem
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — secure edit commits
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — SSRM endpoints
- [data-import-export-ui](../data-import-export-ui/Skill.md) — exports and CSV injection
- [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md) — grid keyboard expectations

## Sources
- [AG Grid React licensing](https://www.ag-grid.com/react-data-grid/licensing/) — Official — Community MIT vs Enterprise EULA, feature list, trial
- [AG Grid modules](https://www.ag-grid.com/react-data-grid/modules/) — Official — `AgGridProvider`, module registration, bundle advice
- [AG Grid theming parameters](https://www.ag-grid.com/react-data-grid/theming-parameters/) — Official — `themeQuartz.withParams` density params
- [AG Grid SSRM datasource](https://www.ag-grid.com/react-data-grid/server-side-model-datasource/) — Official — `getRows` request/response contract
- [AG Grid releases](https://github.com/ag-grid/ag-grid/releases) — Official — 36.1.0, 2026-08-05
- [MUI X licensing](https://mui.com/x/introduction/licensing/) — Official — tiers and license key setup
- [MUI X server-side data](https://mui.com/x/react-data-grid/server-side-data/) — Official — `dataSource`, cache, modes
- [Glide Data Grid](https://grid.glideapps.com/) — Open Source — canvas, MIT, scale
- [W3C APG Grid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — keyboard model
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — Server Action authz

## License / Usage Notes
AG Grid Community and MUI X Data Grid community: MIT. AG Grid Enterprise and MUI X Pro/Premium: commercial, per-developer licensing; read the EULA. Glide Data Grid: MIT. Content summarized; code original and should be checked against current docs.

## Quality Tier
A — licensing, modules, theming, and SSRM contract verified from official docs; some module export names and the Enterprise key API should be confirmed per version.

## Status
Active

## Last Verified
2026-09-15
