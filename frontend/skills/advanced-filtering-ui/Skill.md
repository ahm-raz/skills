# Advanced Filtering UI

## Summary
Designing and implementing complex filtering for enterprise lists in React + Next.js: filter bars, token-based filtered search, AND/OR filter builders, operators per data type, relative dates, saved views, and URL serialization. Pairs a typed filter model with a server-side allowlisted compiler so the UI can be expressive without ever sending raw queries.

## Category
Enterprise UI

## Subcategories
Filter bar, filter builder, filtered search tokens, saved views, operators, relative dates, URL-serialized filters, server-side filter compilation

## Problem It Solves
Power users need to answer questions like "open invoices over $10k, due in the next 14 days, for EMEA customers not owned by me." Simple facet checkboxes cannot express that; free-form query languages scare casual users and are dangerous if passed to the database. This skill gives a scaled approach from simple filters to a full builder, with a shared, validated filter model.

## When To Use
- Record lists with many attributes and heterogeneous data types.
- Users repeat the same filter combinations (saved views needed).
- Filters must be shareable by link, exportable, and reusable by bulk actions and reports.

## When Not To Use
- Consumer faceted search (ecommerce, content sites): use [filters-and-faceted-search](../filters-and-faceted-search/Skill.md).
- Lists with under ~5 filterable attributes: a simple filter bar is enough.
- Ad-hoc analytics with grouping and aggregation: see [report-builder-ui](../report-builder-ui/Skill.md).

## Core Principles
1. Scale the control to data complexity. GitLab Pajamas suggests search and sort for low complexity, tabs/dropdowns for medium, and a filter component or filter builder for high complexity.
2. One filter model drives everything: URL, UI chips, server query, bulk "select all matching", exports, and saved views.
3. Filters are always visible when active: a chip/summary row with per-filter remove and "Clear all" (NN/g: make active filters discoverable).
4. Operators are typed per field: text, number, date, enum, boolean, relation, user. Never show "contains" for dates.
5. The server compiles the model through an allowlist of fields and operators; unknown input is rejected.
6. Results update predictably: either live (with debounce and pending state) or explicit "Apply" for expensive queries; do not mix within one surface.

## Best Practices
- Layout: search input first, then 3–5 promoted quick filters (status, owner, date), then "More filters" or "Add filter" opening the full builder.
- Show result count next to the filter summary ("1,284 results").
- Default operator per type: enum `is any of`, text `contains`, number `between`, date `in the last N days`.
- Support negation (`is not`, `does not contain`) and emptiness (`is empty`, `is not empty`).
- Relative dates (`last 7 days`, `this quarter`) are stored as relative expressions, not resolved timestamps, so saved views stay current. Resolve on the server with the user's time zone.
- "Me" tokens (`owner = @me`) stored symbolically and resolved server-side.
- Saved views: name, owner, visibility (private/team/org), filter model, sort, columns, density. Show "modified" indicator and offer "Save" vs "Save as new".
- Provide sensible default views (e.g., "My open items") as tabs; Shopify Polaris index tables popularized saved views as tabs above the table.
- Keep filter panels nonmodal on desktop (side panel) so users see results change.
- Faceted counts on enum options when cheap; hide or disable options with zero results rather than removing them silently.

## Implementation Guidance

### Filter model
```ts
// lib/filters/model.ts
export type FieldType = 'text' | 'number' | 'date' | 'enum' | 'boolean' | 'user';
export type Operator =
  | 'eq' | 'neq' | 'in' | 'nin' | 'contains' | 'ncontains'
  | 'gt' | 'gte' | 'lt' | 'lte' | 'between' | 'empty' | 'nempty' | 'relative';

export type Condition = { field: string; op: Operator; value?: unknown };
export type FilterGroup = { combinator: 'and' | 'or'; rules: Array<Condition | FilterGroup> };

export const OPERATORS_BY_TYPE: Record<FieldType, Operator[]> = {
  text: ['contains', 'ncontains', 'eq', 'neq', 'empty', 'nempty'],
  number: ['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'between', 'empty'],
  date: ['relative', 'between', 'gt', 'lt', 'empty'],
  enum: ['in', 'nin', 'empty'],
  boolean: ['eq'],
  user: ['in', 'nin', 'empty'],
};
```

### Field catalog (server-owned allowlist)
```ts
// data/filters/invoice-fields.ts
import 'server-only';
import type { FieldType } from '@/lib/filters/model';

export const invoiceFields = {
  status: { type: 'enum', column: 'status', options: ['draft', 'open', 'paid', 'void'] },
  total: { type: 'number', column: 'total_cents' },
  dueDate: { type: 'date', column: 'due_date' },
  customer: { type: 'text', column: 'customer_name' },
  owner: { type: 'user', column: 'owner_id' },
} satisfies Record<string, { type: FieldType; column: string; options?: readonly string[]; permission?: string }>;
```
Send the client only field keys, labels, types, and options (a DTO), never column names.

### URL encoding
- Simple filters: one param per field, e.g. `?status=open,paid&owner=@me&due=last_14d` via nuqs parsers. Readable and diff-friendly.
- Builder with nested AND/OR: a single `f` param holding compact JSON parsed with `parseAsJson` and a Zod schema, or a base64url-encoded model if length matters. Keep URLs under ~2,000 characters; beyond that, persist as a saved view and put `?view=<id>` in the URL.
- Always include sort and view id in the URL; page resets to 1 on any filter change.

```ts
// app/(admin)/invoices/search-params.ts
import { createLoader, parseAsArrayOf, parseAsString, parseAsJson, parseAsStringLiteral } from 'nuqs/server';
import { z } from 'zod';

const Condition: z.ZodType = z.lazy(() =>
  z.union([
    z.object({ field: z.string().max(64), op: z.string().max(16), value: z.unknown().optional() }),
    z.object({ combinator: z.enum(['and', 'or']), rules: z.array(Condition).max(25) }),
  ]),
);
export const FilterGroupSchema = z.object({ combinator: z.enum(['and', 'or']), rules: z.array(Condition).max(25) });

export const invoiceFilterParsers = {
  q: parseAsString.withDefault(''),
  status: parseAsArrayOf(parseAsStringLiteral(['draft', 'open', 'paid', 'void'] as const)).withDefault([]),
  due: parseAsString, // e.g. "last_14d" | "next_30d" | "2026-01-01..2026-03-31"
  f: parseAsJson(FilterGroupSchema.parse), // advanced builder model
  view: parseAsString,
};
export const loadInvoiceFilters = createLoader(invoiceFilterParsers);
```
Check nuqs docs for the current `parseAsJson` signature (it accepts a validation function or Standard Schema in 2.x).

### Server compiler (depth, count, and operator allowlist)
```ts
// data/filters/compile.ts
import 'server-only';
import { OPERATORS_BY_TYPE, type FilterGroup, type Condition } from '@/lib/filters/model';
import { invoiceFields } from './invoice-fields';

type Where = Record<string, unknown>;

export function compile(group: FilterGroup, ctx: { userId: string; tz: string }, depth = 0): Where {
  if (depth > 3) throw new Error('Filter too deep');
  const parts = group.rules.map((r) => ('combinator' in r ? compile(r, ctx, depth + 1) : compileCondition(r, ctx)));
  return { [group.combinator === 'and' ? 'AND' : 'OR']: parts };
}

function compileCondition(c: Condition, ctx: { userId: string; tz: string }): Where {
  const def = invoiceFields[c.field as keyof typeof invoiceFields];
  if (!def) throw new Error(`Unknown field ${c.field}`);
  if (!OPERATORS_BY_TYPE[def.type].includes(c.op)) throw new Error(`Bad operator ${c.op}`);
  const col = def.column;
  switch (c.op) {
    case 'in': {
      const values = (c.value as string[]).map((v) => (v === '@me' ? ctx.userId : v));
      if ('options' in def && def.options && !values.every((v) => def.options!.includes(v))) throw new Error('Bad value');
      return { [col]: { in: values } };
    }
    case 'contains': return { [col]: { contains: String(c.value).slice(0, 200), mode: 'insensitive' } };
    case 'relative': return { [col]: resolveRelative(String(c.value), ctx.tz) };
    case 'empty': return { [col]: null };
    // ...remaining operators, each with typed value validation
    default: throw new Error('Unsupported');
  }
}
declare function resolveRelative(expr: string, tz: string): { gte: Date; lt: Date };
```

### Client: live quick filters with pending state
```tsx
'use client';
import { useTransition } from 'react';
import { useQueryStates } from 'nuqs';
import { invoiceFilterParsers } from './search-params';

export function QuickFilters() {
  const [isPending, startTransition] = useTransition();
  const [f, setF] = useQueryStates(
    { ...invoiceFilterParsers },
    { shallow: false, startTransition, throttleMs: 300 },
  );
  const toggleStatus = (s: 'open' | 'paid') =>
    setF({ status: f.status.includes(s) ? f.status.filter((x) => x !== s) : [...f.status, s] });

  return (
    <div role="group" aria-label="Quick filters" aria-busy={isPending}>
      <input type="search" aria-label="Search invoices" defaultValue={f.q}
        onChange={(e) => setF({ q: e.target.value || null })} />
      {(['open', 'paid'] as const).map((s) => (
        <button key={s} type="button" aria-pressed={f.status.includes(s)} onClick={() => toggleStatus(s)}>{s}</button>
      ))}
      <button type="button" onClick={() => setF({ q: null, status: null, due: null, f: null })}>Clear all</button>
    </div>
  );
}
```
Remember to reset `page` in the same `setF` call when the list is paginated.

## Recommended Workflow
1. Inventory filterable fields, types, cardinality, and which are indexed; rate complexity (low/medium/high).
2. Choose surface: quick filters only, quick filters plus panel, or full builder.
3. Define the filter model and server field catalog with per-field permissions.
4. Implement the compiler with allowlists, limits (rules, depth, value lengths), and tests.
5. Define URL encoding; wire nuqs parsers on server and client.
6. Build chips/summary row, clear all, empty result recovery.
7. Add saved views (CRUD via Server Actions with ownership/visibility checks).
8. Reuse the same model in exports and bulk "select all matching".

## Patterns
- **Filter summary row**: chips like "Status: Open, Paid ×", "Due: next 14 days ×", then "Clear all" and "Save view".
- **Filtered search tokens**: a single input where typing `status:` suggests values and commits a token (key, operator, value). Good for expert users; always provide a click path too.
- **Builder rows**: `[Field ▾] [Operator ▾] [Value input]  [× remove]`, `+ Add condition`, `+ Add group`, combinator toggle per group.
- **View tabs**: default and saved views as tabs; a modified view shows a dot and "Save" / "Discard".
- **Zero-results recovery**: show which filters are active and one-click removal of the most restrictive one.
- **Value inputs per type**: combobox for enum/user (async search), number range, date range with relative presets.

## Anti-Patterns
- **Passing a query string or JSON directly to the ORM**: injection, data exposure via unauthorized fields. Fix: field catalog plus compiler.
- **Resolving "last 7 days" into fixed dates in saved views**: views go stale. Fix: store relative expressions.
- **Filters hidden in a closed drawer with no indicator**: users think data is missing. Fix: always-visible chips and count badge.
- **Instant refetch on every keystroke in number/date inputs**: server load and flicker. Fix: throttle, or apply on blur/Enter.
- **Different filter logic in table, export, and bulk action**: inconsistent results. Fix: one compiler.
- **Unbounded builder** (100 rules, deep nesting): slow queries. Fix: limit rules and depth; show message.
- **Exposing filters on fields the user cannot read**: leaks existence of data via counts. Fix: filter catalog per role.

## Accessibility
- Every control has a visible or programmatic label; builder rows label inputs with the row context ("Condition 2 field").
- Toggle filters use `aria-pressed` or checkboxes; do not rely on color.
- Announce result count changes with a polite live region after results settle, not on every keystroke (WCAG 4.1.3).
- Removing a chip moves focus to the next chip or the "Add filter" button, never to the document body.
- Filter panels opened as dialogs trap focus and restore it; nonmodal side panels need a heading and landmark.
- Comboboxes follow the APG combobox pattern ([select-and-combobox](../select-and-combobox/Skill.md)).
- Token inputs must support keyboard deletion (Backspace on empty input removes the last token) and announce token creation.

## Responsive Design
- Small screens: collapse quick filters into a "Filters (3)" button opening a full-screen sheet with "Show N results".
- Keep chips horizontally scrollable in one line with a count overflow.
- The builder becomes a vertical stack per condition; the combinator is a clear text label between rows.

## Performance
- Index combinations used by default views; monitor slow queries from saved views.
- Cache facet counts briefly; compute them in parallel with the main query.
- Throttle URL updates (nuqs `throttleMs`) and use transitions so input stays responsive (INP).
- Limit async option search results and debounce remote lookups.

## Security
- Server compiler is the enforcement point: field allowlist, per-field read permission, operator allowlist, value validation, depth/rule limits.
- Saved views: Server Actions check ownership and visibility; shared views run with the viewer's permissions, not the author's.
- Tenant scope is applied outside the user's filter group (`AND tenantId = ...`) so an `OR` cannot escape it.
- Rate-limit expensive filter queries and exports.

## Testing
- Unit: compiler rejects unknown fields/operators, enforces depth, resolves `@me` and relative dates with time zones.
- Property tests: random valid models always include the tenant constraint at the root.
- Component: chips reflect URL; clear all resets; focus moves correctly after chip removal.
- E2E: build a filter, reload, share link in a new context, save view, open as a different role.

## Tooling
- `nuqs` 2.x for URL state (`parseAsArrayOf`, `parseAsJson`, `createLoader`).
- `zod` for model validation.
- `react-querybuilder` (MIT) for builder UI scaffolding; check current version and styling adapters.
- Headless combobox from your design system ([select-and-combobox](../select-and-combobox/Skill.md)).
- `date-fns-tz` or `Temporal` polyfill for relative date resolution (verify availability).

## Framework Notes
- **Next.js (App Router)**: parse filters in the Server Component page with a nuqs loader, compile in the DAL, and stream results with Suspense keyed on the serialized filter. Client filter controls update the URL with `shallow: false`. Saved view CRUD uses Server Actions plus `revalidatePath` or tag revalidation.
- **React (Vite SPA)**: same parsers with the React Router nuqs adapter; TanStack Query key is the parsed filter object; API endpoint compiles with the same allowlist logic.

## AI Agent Guidance
- Do: create the field catalog and compiler before UI; keep tenant scope outside user groups; reuse the model for export/bulk.
- Do: store relative dates and `@me` symbolically.
- Don't: accept raw SQL/JSON where-clauses; don't show filters for fields the role cannot read.
- Before done: test deep link round-trip, an OR filter attempting cross-tenant data, zero-results recovery, and keyboard-only builder use.

## Examples
Active filter chips derived from URL state:
```tsx
'use client';
import { useQueryStates } from 'nuqs';
import { invoiceFilterParsers } from './search-params';

export function FilterChips({ total }: { total: number }) {
  const [f, setF] = useQueryStates(invoiceFilterParsers, { shallow: false });
  const chips = [
    ...(f.status.length ? [{ key: 'status', label: `Status: ${f.status.join(', ')}` }] : []),
    ...(f.due ? [{ key: 'due', label: `Due: ${f.due.replace('_', ' ')}` }] : []),
  ] as const;
  return (
    <div aria-label="Active filters">
      <p aria-live="polite">{total.toLocaleString()} results</p>
      <ul>
        {chips.map((c) => (
          <li key={c.key}>
            {c.label}
            <button type="button" aria-label={`Remove filter ${c.label}`} onClick={() => setF({ [c.key]: null })}>×</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

## Related Skills
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — simpler facet filtering
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — list query contract
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — URL state
- [bulk-actions](../bulk-actions/Skill.md) — reuses the filter model for select-all-matching
- [report-builder-ui](../report-builder-ui/Skill.md) — grouping and aggregation on top of filters
- [select-and-combobox](../select-and-combobox/Skill.md) — value pickers
- [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md) — date ranges
- [tags-and-chips-input](../tags-and-chips-input/Skill.md) — token inputs

## Sources
- [GitLab Pajamas: Filtering](https://design.gitlab.com/patterns/filtering) — Official design system — complexity levels and component choice
- [NN/g: Data Tables](https://www.nngroup.com/articles/data-tables/) — Research — discoverable filters with visible active state
- [NN/g: Complex application design](https://www.nngroup.com/articles/complex-application-design/) — Research — reduce clutter without reducing capability
- [nuqs server-side docs](https://nuqs.dev/docs/server-side) — Official — loaders, parsers, validation caveat
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — untrusted search params, DAL
- [Shopify Polaris (now web components)](https://shopify.dev/docs/api/polaris) — Official — saved views as tabs pattern (Polaris React deprecated)

## License / Usage Notes
nuqs, Zod, react-querybuilder: MIT. Design-system guidance summarized, not copied. Code original.

## Quality Tier
A — principles grounded in NN/g and Pajamas plus verified nuqs/Next.js docs; token-search specifics are general industry practice rather than a single verified spec.

## Status
Active

## Last Verified
2026-09-15
