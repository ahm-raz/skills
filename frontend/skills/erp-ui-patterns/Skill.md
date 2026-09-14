# ERP UI Patterns

## Summary
Screen and interaction patterns for ERP-style business applications (finance, procurement, inventory, manufacturing, HR) built with React + Next.js. The skill covers the page types that recur in ERP suites: list report, worklist, object page, and flexible column layout. It also covers the document lifecycle (draft -> posted -> reversed), editable line-item grids, and the domain correctness details that break ERP UIs: money, units, decimal precision, fiscal periods, and concurrent editing.

## Category
Enterprise UI

## Subcategories
Floorplans (list report, worklist, object page, flexible column layout), business documents, line items, currency and units, fiscal periods, draft handling and locking, variant management (saved views)

## Problem It Solves
ERP screens get built one-off per module. Every page puts filters, actions, and save behavior somewhere different. Money is summed in floating point. Posted documents turn out to be editable, and two clerks overwrite each other. Standardizing on a few floorplans and a strict document model fixes consistency, training cost, and data integrity together.

## When To Use
- Back-office apps with many entity types sharing the same "find -> open -> edit -> post" loop.
- Documents with header + line items (purchase orders, invoices, sales orders, journal entries, goods receipts).
- Replacing or extending SAP/Oracle/Dynamics/NetSuite screens with custom React front ends.
- Internal tools where users spend hours a day and efficiency beats first-use discoverability.

## When Not To Use
- Consumer-facing apps or marketing sites.
- Small admin panels with a few CRUD resources. See `admin-panel-architecture` and `refine-and-react-admin-frameworks`.
- Highly visual analytic exploration. See `dashboard-design`.

## Core Principles
1. **A few floorplans, used consistently.** Every screen is one of: list report, worklist, object page, overview/dashboard, wizard. Same regions, same action placement everywhere.
2. **Documents have a lifecycle. Posted means immutable.** Corrections are reversals or credit notes, never edits.
3. **Money and quantities are exact.** Integer minor units or decimal strings end to end. Currency and unit always travel with the value.
4. **The server is authoritative** for totals, taxes, period status, numbering, and permissions. The client may preview but not decide.
5. **Protect concurrent work.** Drafts are owned. Edits carry a version. Locks are visible.
6. **Efficiency for experts.** Keyboard entry, dense layout, saved variants, and bulk operations are requirements, not extras.

## Best Practices
- **List report**: header with title + variant (saved view) selector. A filter bar with the most-used fields visible and "Adapt filters" for the rest. A results table with toolbar (count, create, bulk actions, column settings, export). Row click opens the object page. Put all filter/sort/page/variant state in the URL.
- **Worklist**: like a list report without a heavy filter bar. Use it for a personal queue ("my open items") with tabs for status buckets and counts.
- **Object page**: a header with the document identity (number, type, status badge), key facets (supplier, total, due date, posting period), and header actions. Anchor navigation or tabs for sections (General, Items, Delivery, Accounting, Attachments, History). A sticky footer toolbar holds the finalizing actions in edit mode (Save, Post, Discard draft). Posting validation messages go in a message popover listing errors per field, and each error navigates to its field.
- **Flexible column layout**: list | object | sub-object (line item) side by side on wide screens, with the ability to expand one column to full screen. Collapse to a single column on narrow viewports. Encode the layout in the URL.
- Show the draft indicator ("Draft - saved 10:42") and the lock owner ("Being edited by J. Park since 09:12") in the header.
- Use explicit currency codes (ISO 4217) and unit codes next to amounts in grids. Right-align numbers and use tabular numerals.
- Show period status on posting: disable Post with a reason when the period is closed ("Period 2026-08 is closed for posting"), and still reject it on the server.
- Line items: an editable grid with add-row at the bottom. Keyboard flow is Tab across cells and Enter to go down. Show per-line validation plus a document-level summary. Totals are computed on the server and displayed read-only.
- Number ranges come from the server at save/post time. Show "Draft" or a temporary ID until then.
- These floorplan names follow SAP Fiori conventions. The official Fiori site (sap.com) could not be fetched during research, so verify anatomy details against the current Fiori design guidelines before claiming conformance.

## Implementation Guidance

### Money and quantity types
```ts
// lib/money.ts
export type CurrencyCode = string & { readonly __brand: 'CurrencyCode' }; // ISO 4217, e.g. "EUR"
export type Money = { amountMinor: bigint; currency: CurrencyCode }; // never number for sums
export type Quantity = { value: string; unit: string }; // decimal string, e.g. "12.500" KG

const DIGITS: Record<string, number> = { JPY: 0, EUR: 2, USD: 2, KWD: 3 }; // prefer Intl-derived or server-provided scale

export function formatMoney(m: Money, locale: string) {
  const scale = DIGITS[m.currency] ?? 2;
  const major = Number(m.amountMinor) / 10 ** scale; // display-only conversion; safe within Number range for display
  return new Intl.NumberFormat(locale, { style: 'currency', currency: m.currency, minimumFractionDigits: scale }).format(major);
}
```
- Serialize `bigint` as strings in DTOs (RSC/JSON cannot carry `bigint` everywhere reliably). Parse at the edges.
- Do tax, rounding, and FX conversion on the server with a decimal library or the database's `numeric` type. Store the rate and rate date used.

### Document lifecycle
```ts
export type DocStatus = 'draft' | 'in_approval' | 'posted' | 'reversed' | 'cancelled';
export const EDITABLE: ReadonlySet<DocStatus> = new Set(['draft']);
```
| Status | Editable | Allowed actions |
|---|---|---|
| draft | Yes (owner/lock holder) | Save, Validate, Post / Submit, Discard |
| in_approval | No | Withdraw (requester), Approve/Reject (approver) |
| posted | No | Reverse (creates a reversal document), Copy, Print |
| reversed / cancelled | No | Copy |

### Object page route structure (App Router)
```
app/(erp)/purchase-orders/page.tsx                  // list report (Server Component, reads searchParams)
app/(erp)/purchase-orders/[id]/page.tsx             // object page (display mode)
app/(erp)/purchase-orders/[id]/edit/page.tsx        // edit mode on the draft
app/(erp)/purchase-orders/[id]/items/[line]/page.tsx// sub-object page (or FCL third column)
app/(erp)/purchase-orders/actions.ts                // saveDraft, post, reverse (Server Actions -> DAL)
```

### Draft autosave with version check
```tsx
'use client';
import { useEffect, useRef, useState, useTransition } from 'react';
import { saveDraft } from '../actions';

export function useDraftAutosave<T>(id: string, value: T, version: number, delay = 1500) {
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const [conflict, setConflict] = useState(false);
  const [, start] = useTransition();
  const ver = useRef(version);
  useEffect(() => {
    if (conflict) return;
    const t = setTimeout(() => start(async () => {
      const r = await saveDraft({ id, patch: value, version: ver.current });
      if (r.kind === 'conflict') setConflict(true);
      else if (r.kind === 'ok') { ver.current = r.version; setSavedAt(new Date()); }
    }), delay);
    return () => clearTimeout(t);
  }, [id, value, delay, conflict]);
  return { savedAt, conflict };
}
```
On the server, `saveDraft` checks the session, tenant, draft ownership/lock, `status === 'draft'`, and the version, then returns only `{ kind, version }`.

### Posting Server Action
```ts
'use server';
import { postDocument } from '@/data/purchase-orders';
import { revalidatePath } from 'next/cache';

export async function postAction(id: string, version: number) {
  const r = await postDocument(id, version); // authz, period open, validations, number assignment, totals, in one DB transaction
  if (r.kind === 'invalid') return { ok: false, messages: r.messages }; // [{ field: 'items[2].quantity', text: 'Must be > 0' }]
  if (r.kind !== 'ok') return { ok: false, messages: [{ field: null, text: r.message }] };
  revalidatePath(`/purchase-orders/${id}`);
  return { ok: true, number: r.documentNumber };
}
```

### Locking strategy decision
| Scenario | Strategy |
|---|---|
| Low contention, short edits | Optimistic concurrency (version column) + conflict dialog |
| Long edits on shared documents | Draft owned by user + soft lock with expiry and heartbeat. Show the lock holder. Admins can release it |
| Real-time co-editing needed | See `realtime-collaboration-ui` (rare in ERP postings) |

## Recommended Workflow
1. Inventory entity types. Assign each to a floorplan (list report / worklist / object page / wizard).
2. Define the document lifecycle, editable states, and the posting and reversal rules with the domain experts.
3. Define DTO types for Money/Quantity/Period, with string serialization.
4. Build shared layout primitives: `ListReport`, `ObjectPageHeader`, `ObjectPageSection`, `FooterToolbar`, `MessagePopover`.
5. Implement the list report with URL-synced filters and saved variants (stored per user on the server).
6. Implement the object page display, then edit mode with draft autosave and a version check.
7. Implement the line-item grid with keyboard entry and server-computed totals.
8. Implement post/reverse in a DAL transaction. Add period checks and numbering.
9. Test concurrency, rounding, locales, and keyboard-only data entry.

## Patterns
- **Variant management (saved views)**: `{ id, name, ownerId, shared, isDefault, query: string }`, where `query` is the serialized URL search string. Applying a variant replaces the URL. A "modified" asterisk shows when the current URL differs from the variant.
- **Message popover**: a footer button showing an error/warning count. It opens a list, and clicking an item focuses the field (switching section/tab first).
- **Header facets**: 3–6 key-value blocks (Supplier, Net amount, Delivery date, Status). Each is a `<dl>`.
- **Reverse, don't edit**: "Reverse" opens a dialog (reversal date, reason) and creates a linked document. Both documents link to each other.
- **Copy from**: create a new draft from an existing document or template. Always a draft, always renumbered.

## Anti-Patterns
- **Floating-point sums** (`0.1 + 0.2`). Totals drift by cents. Fix: integer minor units / decimal on the server. The client only displays.
- **Editing posted documents.** Destroys auditability. Fix: immutable posted status plus a reversal flow.
- **Client-side totals as truth.** Tax/rounding mismatch with the backend. Fix: server computes on save. The client shows "recalculating…".
- **Amounts without currency** in multi-currency grids. Fix: currency code column or suffix on every amount.
- **Every module invents its own layout.** Fix: shared floorplan components and a review checklist.
- **Filters in component state only.** Users can't share or bookmark. Fix: URL state (nuqs) plus saved variants.
- **Silent overwrite of concurrent edits.** Fix: version check, lock indicator, conflict resolution UI.
- **Disabling Post without saying why.** Fix: inline reason text or a tooltip alternative plus a message popover.

## Accessibility
- Object page sections are landmarks or headings (`<section aria-labelledby>`). Anchor nav uses `aria-current`.
- Line-item editable grids follow the APG grid pattern: arrow navigation, Enter/F2 to edit, Escape to cancel, and `aria-rowcount`/`aria-rowindex` when virtualized. Otherwise use a plain `<table>` with inputs and natural Tab order.
- Field errors use `aria-invalid` and `aria-describedby`. The message popover count is announced via a live region after posting.
- Status badges have text. Locked/read-only fields use `readOnly` (focusable, readable) rather than `disabled` where users need to copy values.
- Numbers in tables use `<td>` with consistent alignment. Units and currency are visible, not only in headers (WCAG 1.3.1).

## Responsive Design
- ERP is desktop-first, but approvals, lookups, and goods receipts happen on tablets and phones.
- Flexible column layout: 3 columns at ≥1440px, 2 at ≥1024px, 1 below. Use container queries for panels.
- On narrow screens the line-item grid becomes a list of cards with a detail sheet per line.
- Keep the footer toolbar sticky. Collapse secondary actions into an overflow menu.

## Performance
- List reports use server-side pagination/sort/filter, with indexed queries and count estimates for huge tables (show "10,000+").
- Virtualize long line-item grids (hundreds of lines). Avoid re-rendering the whole document on each keystroke; use uncontrolled inputs or per-row memoization.
- Stream object page sections with `<Suspense>` (History and Attachments load lazily).
- Debounce autosave (1–2s) and cancel in-flight saves on unmount.

## Security
- Authorize every read and mutation in the DAL (tenant, company code/plant/org-unit scoping, role). Never trust hidden fields for IDs or amounts.
- Posting, reversal, and period close are privileged. Log them to the audit trail with before/after.
- Segregation of duties (creator can't approve or post their own document) is enforced on the server.
- Export endpoints re-check authorization and escape CSV formulas (see `data-import-export-ui`).
- DTOs omit internal costs/margins for roles that must not see them. Filter on the server, not by hiding columns.

## Testing
- Unit: money formatting per locale/currency scale, and rounding helpers against backend fixtures.
- Integration: post in an open vs closed period, version conflict, lock expiry, reversal linking, number assignment under concurrency.
- E2E (Playwright): create draft -> add 3 lines by keyboard only -> post -> reverse. Two users editing the same draft.
- Visual regression on dense grids in compact/cozy modes. Axe on list report and object page.

## Tooling
- UI5 Web Components for React (`@ui5/webcomponents-react`): a Fiori-compliant React implementation (DynamicPage/ObjectPage-style layouts, FilterBar, AnalyticalTable, VariantManagement via the fiori package). It notes Next.js caveats (no top-level await for asset imports). Check its current docs for the version and license.
- AG Grid (v36.x; Enterprise needed for row grouping, server-side row model, Excel export, master/detail) or TanStack Table v9 (headless) for list reports and line items.
- MUI X Data Grid (Pro/Premium tiers for pinning, grouping, Excel export).
- nuqs 2.x for URL state. React Hook Form + Zod for header forms.
- A decimal library or DB `numeric` on the server. `Intl.NumberFormat` for display.

## Framework Notes
- **Next.js (App Router, 16)**: list reports and object pages are Server Components (`searchParams`/`params` are Promises). Edit mode and grids are Client Components. Post/reverse/save are Server Actions delegating to a `server-only` DAL. Use `revalidatePath` for the affected document and list. Use parallel or intercepting routes for flexible column layout or quick-view panels.
- **React (Vite SPA)**: same floorplans with React Router or TanStack Router. Search params hold the list state. TanStack Query handles caching with `If-Match` ETags for saves. The backend enforces lifecycle and authorization.

## AI Agent Guidance
- Do: pick a floorplan before writing JSX. Reuse shared layout components.
- Do: represent money as minor units/decimal strings with a currency. Never add money as JS numbers.
- Do: make posted documents read-only on both server and client, and implement reversal.
- Don't: compute authoritative totals, taxes, or document numbers on the client.
- Don't: claim "Fiori compliant" without checking the current Fiori guidelines.
- Verify before done: closed-period posting is rejected by the server; concurrent edit shows a conflict; keyboard-only line entry works; totals match backend fixtures; list state survives reload via URL.

## Examples
```tsx
// Object page header (Server Component)
import { getPurchaseOrderDTO } from '@/data/purchase-orders';

export default async function POPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const po = await getPurchaseOrderDTO(id); // authz + tenant scope; money as strings
  return (
    <article aria-labelledby="po-title">
      <header className="grid gap-4 border-b p-4 md:grid-cols-[1fr_auto]">
        <div>
          <p className="text-sm text-muted-foreground">Purchase order</p>
          <h1 id="po-title" className="text-xl font-semibold">{po.number ?? 'Draft'} · {po.supplierName}</h1>
          <span className="badge">{po.statusLabel}</span>
        </div>
        <dl className="grid grid-cols-2 gap-x-6 gap-y-1 text-sm md:grid-cols-4">
          <div><dt>Net amount</dt><dd className="tabular-nums">{po.netAmountFormatted}</dd></div>
          <div><dt>Delivery date</dt><dd>{po.deliveryDate}</dd></div>
          <div><dt>Posting period</dt><dd>{po.period}</dd></div>
          <div><dt>Buyer</dt><dd>{po.buyerName}</dd></div>
        </dl>
      </header>
      {/* sections: General, Items, Accounting, Attachments, History */}
    </article>
  );
}
```

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — list report tables
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md) — line-item and large list grids
- [master-detail-layouts](../master-detail-layouts/Skill.md) — flexible column layout
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — filter bar and variants
- [dense-form-screens](../dense-form-screens/Skill.md) — header/edit forms
- [workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md) — document approval lifecycles
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md) — money/quantity inputs
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — posting history
- [fluent-ui-and-enterprise-systems](../fluent-ui-and-enterprise-systems/Skill.md) — enterprise design systems
- [report-builder-ui](../report-builder-ui/Skill.md) — ad hoc ERP reporting

## Sources
- [UI5 Web Components for React README](https://github.com/SAP/ui5-webcomponents-react) — Open Source (SAP) — Fiori-compliant React implementation, Next.js caveats
- [SAP Fiori floorplan overview](https://www.sap.com/design-system/fiori-design-web/page-types/floorplan-overview) — Official — floorplan names; page returned 403 during research, so anatomy is from general knowledge and must be verified
- [SAP fundamental-styles](https://github.com/SAP/fundamental-styles) — Open Source — Fiori 3 (Quartz) / Horizon theme context
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, Server Action authorization, minimal DTOs
- [AG Grid licensing](https://www.ag-grid.com/react-data-grid/licensing/) — Official — Community vs Enterprise feature split, v36.1
- [MUI X licensing](https://mui.com/x/introduction/licensing/) — Official — Pro/Premium feature tiers
- [NN/g complex applications](https://www.nngroup.com/articles/complex-application-design/) — Official (research) — expert efficiency, reducing clutter without reducing capability

## License / Usage Notes
Guidance is summarized and original. Fiori is SAP's design language; follow SAP's terms if claiming Fiori alignment. UI5 Web Components for React is open source (check its LICENSE). AG Grid Enterprise and MUI X Pro/Premium require commercial licenses.

## Quality Tier
B — strong official backing for security and grid licensing; Fiori floorplan anatomy could not be re-verified against sap.com in this pass.

## Status
Active

## Last Verified
2026-09-15
