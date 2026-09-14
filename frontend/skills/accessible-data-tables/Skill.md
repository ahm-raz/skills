# Accessible Data Tables

## Summary
Marking up and building data tables in React/Next.js so screen reader users can navigate cell by cell with headers announced, keyboard users can sort, select and paginate, and tables stay usable at 400% zoom. Covers native `<table>` semantics, captions, header scope, complex headers, sortable columns (`aria-sort`), row selection, responsive scroll containers, TanStack Table rendering, and when `role="grid"` is appropriate.

## Category
Accessibility

## Subcategories
table semantics, caption, th scope, headers/id, aria-sort, row selection, responsive tables, scrollable regions, role=grid, TanStack Table, virtualization, aria-rowcount

## Problem It Solves
Div-based "tables" and CSS-grid lists lose all relationships, so users hear a stream of values with no headers. Sort buttons without state, unlabelled row checkboxes, horizontal scroll areas unreachable by keyboard, and `display: block` responsive hacks that strip semantics make data unusable (1.3.1, 2.1.1, 4.1.2).

## When To Use
- Displaying tabular data: comparisons, invoices, admin lists, reports, pricing matrices.
- Adding sorting, filtering, selection, pagination, sticky headers, or virtualization to tables.

## When Not To Use
- Layout. Use CSS grid/flex.
- Simple key-value pairs (use `<dl>`) or card lists (use `<ul>`).
- Spreadsheet-like editing with 2-D arrow navigation needs the APG Grid pattern (see enterprise data grid skills). This skill covers static and lightly interactive tables.

## Core Principles
1. **Use `<table>` for tabular data.** Native semantics give screen readers table navigation (Ctrl+Alt+Arrows in NVDA and JAWS, VO+arrows).
2. **Every table has a name**: `<caption>` (preferred) or `aria-labelledby` pointing to a heading.
3. **Header cells are `<th>` with `scope="col"`/`"row"`.** Use `headers`/`id` only for multi-level complex tables.
4. **Interactive elements inside cells are real controls** with unique accessible names.
5. **State is exposed**: `aria-sort` on the sorted `<th>`, `aria-selected` or checkbox state for selection.
6. **Don't make static tables into grids.** `role="grid"` changes keyboard expectations and requires full arrow-key implementation.

## Best Practices
- Keep tables simple. Split complex multi-header tables into several simpler ones where possible.
- Use `<thead>`, `<tbody>`, `<tfoot>` (totals row).
- Sortable header: put a `<button>` inside the `<th>`, and set `aria-sort="ascending|descending"` on the `<th>` of the sorted column only (omit it or use `none` elsewhere). Visually indicate direction with an icon, not color.
- Announce sort changes via a polite live region ("Sorted by Date, descending") if the table re-renders heavily.
- Row selection checkboxes: an accessible name per row (`aria-label={`Select invoice ${row.number}`}`), and a header "Select all" checkbox with `checked`/`indeterminate` state.
- Row actions: a button per row with a unique name ("Edit invoice 1042"), or a menu button "Actions for invoice 1042".
- Make the whole row clickable only as an enhancement. Still provide a real link or button in a cell.
- Horizontal overflow: wrap in `<div role="region" aria-labelledby={captionId} tabIndex={0}>` so keyboard users can scroll and screen readers get a named region.
- Sticky headers (`position: sticky` on `th`) are fine. Ensure focused cells aren't obscured (2.4.11).
- Pagination: `<nav aria-label="Table pagination">`, announce "Page 3 of 12, rows 41–60" politely, and keep focus sensible after page change.
- Empty and loading states in `<tbody>`: a row with `<td colSpan={n}>` text; `aria-busy="true"` on the table while loading.
- Numbers: right-align, use tabular numerals, include units in headers ("Amount (USD)").

## Implementation Guidance

### Simple table
```tsx
<table>
  <caption>Invoices, September 2026</caption>
  <thead>
    <tr><th scope="col">Invoice</th><th scope="col">Customer</th><th scope="col">Due</th><th scope="col" className="text-right">Amount (USD)</th></tr>
  </thead>
  <tbody>
    {rows.map(r => (
      <tr key={r.id}>
        <th scope="row"><Link href={`/invoices/${r.id}`}>{r.number}</Link></th>
        <td>{r.customer}</td>
        <td><time dateTime={r.due}>{formatDate(r.due)}</time></td>
        <td className="text-right tabular-nums">{formatUsd(r.amount)}</td>
      </tr>
    ))}
  </tbody>
</table>
```

### Complex headers (two-level)
```tsx
<table>
  <caption>Quarterly revenue by region</caption>
  <thead>
    <tr><td /><th id="q1" colSpan={2} scope="colgroup">Q1</th><th id="q2" colSpan={2} scope="colgroup">Q2</th></tr>
    <tr><td /><th id="q1-new" scope="col">New</th><th id="q1-ren" scope="col">Renewal</th><th id="q2-new" scope="col">New</th><th id="q2-ren" scope="col">Renewal</th></tr>
  </thead>
  <tbody>
    <tr><th id="emea" scope="row">EMEA</th><td headers="emea q1 q1-new">1.2M</td><td headers="emea q1 q1-ren">0.8M</td>…</tr>
  </tbody>
</table>
```

### TanStack Table with sorting and selection
```tsx
'use client';
import { flexRender, getCoreRowModel, getSortedRowModel, useReactTable, type ColumnDef, type SortingState } from '@tanstack/react-table';

export function InvoiceTable({ data, columns }: { data: Invoice[]; columns: ColumnDef<Invoice>[] }) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [status, setStatus] = useState('');
  const captionId = useId();
  const table = useReactTable({ data, columns, state: { sorting }, onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(), getSortedRowModel: getSortedRowModel(), enableRowSelection: true });

  return (
    <>
      <div role="region" aria-labelledby={captionId} tabIndex={0} className="overflow-x-auto focus-visible:outline-2">
        <table>
          <caption id={captionId}>Invoices</caption>
          <thead>
            {table.getHeaderGroups().map(hg => (
              <tr key={hg.id}>
                {hg.headers.map(h => {
                  const sorted = h.column.getIsSorted();
                  return (
                    <th key={h.id} scope="col"
                      aria-sort={sorted === 'asc' ? 'ascending' : sorted === 'desc' ? 'descending' : undefined}>
                      {h.column.getCanSort() ? (
                        <button type="button" onClick={() => {
                          h.column.toggleSorting();
                          const next = h.column.getNextSortingOrder();
                          setStatus(next ? `Sorted by ${String(h.column.columnDef.header)}, ${next === 'asc' ? 'ascending' : 'descending'}` : 'Sorting removed');
                        }}>
                          {flexRender(h.column.columnDef.header, h.getContext())}
                          <SortIcon direction={sorted} aria-hidden="true" />
                        </button>
                      ) : flexRender(h.column.columnDef.header, h.getContext())}
                    </th>
                  );
                })}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map(row => (
              <tr key={row.id} aria-selected={row.getIsSelected() || undefined}>
                {row.getVisibleCells().map(cell => <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>)}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p role="status" className="sr-only">{status}</p>
    </>
  );
}
```
Column definition for the selection checkbox: `cell: ({ row }) => <input type="checkbox" checked={row.getIsSelected()} onChange={row.getToggleSelectedHandler()} aria-label={`Select invoice ${row.original.number}`} />`. The header cell uses the `indeterminate` ref for partial selection. Note that `aria-selected` on `<tr>` is only valid in grid/treegrid contexts, so for a plain table rely on the checkbox state and omit `aria-selected`.

### Virtualized tables
- Keep `<table>` semantics. Set `aria-rowcount={total}` on `<table>` and `aria-rowindex` on each rendered `<tr>` (1-based, including header rows).
- Virtualization hides rows from screen reader table navigation. Prefer pagination for primary data views, or offer a "show all/export" option.

### Responsive strategies
| Strategy | Accessibility notes |
|---|---|
| Horizontal scroll region (preferred) | Focusable named region; sticky first column helps; 1.4.10 exempts data tables from reflow |
| Priority columns (hide less important at narrow widths) | Provide a way to reveal hidden columns; don't hide essential data |
| Stacked "card" layout via CSS `display:block` | Strips table semantics in some browsers/AT; if used, render a separate list/`<dl>` markup for mobile instead of CSS-hacking the table, or restore with explicit `role="table"/"row"/"cell"` |

## Recommended Workflow
1. Confirm it's tabular data, then define the caption, column headers and row headers.
2. Build the markup with `<table>`; add units and formats in headers.
3. Add interactivity: sort buttons with `aria-sort`, labelled selection checkboxes, row actions with unique names.
4. Handle overflow with a focusable region; handle loading, empty and pagination announcements.
5. Test:
   - NVDA/JAWS T to jump to the table, Ctrl+Alt+Arrows to hear headers
   - VoiceOver VO+Shift+Down to interact, then VO+arrows
   - keyboard sort and select
   - 400% zoom
6. Automate with axe (`td-has-header`, `th-has-data-cells`, `table-fake-caption`, `scrollable-region-focusable`, `td-headers-attr`) and Testing Library `getByRole('columnheader', { name: /due/i })`.

## Patterns
- **Row header as primary link.** `<th scope="row"><Link>` gives context for every cell in the row.
- **Summary row.** `<tfoot><tr><th scope="row">Total</th>…</tr></tfoot>`.
- **Expandable rows.** A disclosure button in the first cell with `aria-expanded`; the detail row immediately follows, with a `colSpan` cell.
- **Filter results announcement.** A polite status: "24 invoices match".

## Anti-Patterns
- **Div/CSS-grid tables with no roles.** No relationships. Use `<table>`, or full ARIA table roles if unavoidable.
- **`role="grid"` on a read-only table.** Users expect arrow navigation and application mode. Use `<table>`.
- **Sort indicated by icon color only, with no `aria-sort`.** State is invisible to AT.
- **Clickable `<tr onClick>` as the only way to open a row.** Not keyboard accessible. Add a link or button.
- **Repeating "Edit" buttons with identical names.** Ambiguous in links/buttons lists. Include the row identifier.
- **Layout tables inside data tables, or empty header cells** without reason. Confusing header association.
- **Overflow container without `tabIndex`.** Keyboard users can't scroll (axe `scrollable-region-focusable`).

## Accessibility
- 1.3.1 Info and Relationships (A), 1.3.2 Meaningful Sequence (A), 2.1.1 Keyboard (A), 2.4.6 Headings and Labels (AA), 4.1.2 Name, Role, Value (A), 4.1.3 Status Messages (AA), 1.4.10 Reflow (AA; data tables exempt from 2-D scrolling but the rest of the page must reflow), 2.4.11 Focus Not Obscured.

## Responsive Design
- Keep tables in a scroll region rather than breaking semantics. Sticky first column plus a visible scroll shadow hints at overflow.
- For mobile-first data views, render a semantically separate list component instead of CSS-transforming the table.
- Target size: sort buttons and checkboxes at least 24px.

## Performance
- For large datasets, paginate server-side (Next.js search params) rather than rendering thousands of rows, which also helps screen reader performance.
- Memoize column definitions; avoid re-creating rows on every keystroke of a filter input (debounce).

## Security
- Escape user-generated cell content (JSX does). Beware CSV export injection (`=cmd`) in data-import/export flows.
- Don't reveal hidden columns' sensitive data in `aria-label`s.

## Testing
```tsx
test('sortable column exposes aria-sort', async () => {
  const user = userEvent.setup();
  render(<InvoiceTable data={fixtures} columns={columns} />);
  const header = screen.getByRole('columnheader', { name: /due/i });
  await user.click(within(header).getByRole('button'));
  expect(header).toHaveAttribute('aria-sort', 'ascending');
  expect(screen.getByRole('status')).toHaveTextContent(/sorted by due, ascending/i);
});
```
- Manual SR checks as in the workflow; Accessibility Insights "Headings/Tables" checks.

## Tooling
- TanStack Table (headless, you own the semantics), React Aria `Table` (accessible sorting, selection and keyboard nav with grid semantics), AG Grid (implements grid ARIA; review its accessibility docs), MUI DataGrid.
- axe-core table rules, W3C Nu checker.

## Framework Notes
- **Next.js.**
  - Render static tables in Server Components. Put only sort, select and filter controls in client components.
  - URL-driven sorting and pagination (`?sort=due&page=2`) keeps state shareable and works without JS via links. Links inside `<th>` then carry `aria-sort` on the `th`.
- **React (Vite SPA).** Same markup. When using client-side sorting, announce changes via `role="status"`.

## AI Agent Guidance
- Do: use `<table>`, `<caption>`, `<th scope>`, sort buttons inside `<th>` with `aria-sort`, uniquely labelled row controls, and a focusable named overflow region.
- Don't: build tables from divs, use `role="grid"` for static data, rely on row `onClick`, or restyle tables with `display:block` on mobile.
- Verify before done:
  - `getByRole('columnheader')` and `getByRole('rowheader')` queries work
  - axe table rules pass
  - keyboard sort and select works
  - screen reader announces headers with cells

## Examples
See Implementation Guidance (simple, complex, and TanStack Table examples).

## Related Skills
- [tanstack-table](../tanstack-table/Skill.md) — headless table engine
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — large, dense admin tables
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md) — interactive grid pattern
- [list-virtualization](../list-virtualization/Skill.md) — virtualization trade-offs
- [pagination](../pagination/Skill.md) — pagination nav
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — sort/filter announcements
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — grid vs table decision

## Sources
- [W3C WAI Tables Tutorial](https://www.w3.org/WAI/tutorials/tables/) — Official — simple, irregular and multi-level headers, captions
- [APG Table and Grid patterns; Sortable Table example](https://www.w3.org/WAI/ARIA/apg/patterns/table/examples/sortable-table/) — Official — aria-sort usage
- [Adrian Roselli: A Responsive Accessible Table / Sortable Table Columns](https://adrianroselli.com/2021/04/sortable-table-columns.html) — Community — scroll region and sort patterns
- [TanStack Table docs](https://tanstack.com/table/latest) — Open Source — headless API
- [axe-core rule descriptions](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md) — Open Source — table rules

## License / Usage Notes
Summarised from W3C tutorials, practitioner articles and TanStack docs (MIT). Code is original.

## Quality Tier
A — authoritative markup guidance with a complete React/TanStack implementation. Virtualized table AT support remains inconsistent.

## Status
Active

## Last Verified
2026-09-15
