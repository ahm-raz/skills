# Dense Form Screens

## Summary
How to build large, information-dense forms for enterprise apps in React + Next.js: 30–300 fields, sections, multi-column grids, read/edit modes, conditional fields, autosave or explicit save, unsaved-changes protection, field-level server errors, keyboard efficiency, and density modes. Expert users can fill these fast without losing data, and they stay accessible and performant.

## Category
Enterprise UI

## Subcategories
Form layout, sections and fieldsets, multi-column grids, read/edit mode, dirty state and navigation guards, autosave, server validation, React Hook Form + Zod, density, keyboard shortcuts, performance

## Problem It Solves
Enterprise records (customer master, product master, insurance claim, employee file) have many fields. Naive implementations make every field a re-rendering controlled input and scatter labels. Tab order jumps across columns, save errors show up only in a toast, and unsaved changes vanish on navigation. The result is slow typing, lost work, and inaccessible forms.

## When To Use
- Master-data maintenance screens and complex record edits.
- Back-office data entry where users know the domain and value speed.
- Settings pages with many grouped options for administrators.
- Forms that mix read-only context with editable fields.

## When Not To Use
- Consumer sign-up/checkout. Use single-column, progressive forms (`form-design-ux`).
- Linear processes where order matters and the user is a novice. Use `multi-step-forms-and-wizards`.
- Tabular repeated entry of the same shape (100 line items). Use an editable grid (`data-grids-ag-grid`, `enterprise-data-tables`).

## Core Principles
1. **Group by meaning, order by task.** Sections follow how users think about the record, most-used first.
2. **Predictable reading and tab order.** DOM order = visual order = tab order. Multi-column grids run row by row, or column by column within a section, but consistently.
3. **Never lose work.** Dirty tracking, a navigation guard, draft persistence or autosave, and conflict detection.
4. **Errors are local and summarized.** Field-level messages plus a summary that links to fields. The server is the final validator.
5. **Density is a user choice, not a design shortcut.** Compact modes keep target sizes, contrast, and labels.
6. **Performance by default.** Uncontrolled inputs, subscription-based validation, and rendering only what's visible.

## Best Practices
- **Labels**: top-aligned labels scan fastest and handle long translations. Left-aligned labels in a 2-column label/value grid suit read-heavy compact screens. Never use placeholder-only labels.
- **Columns**: at most 2–3 columns of fields on wide screens. Put related short fields together (City | Postal code). Long fields (address, notes) span full width. Use CSS grid with `grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr))` or container queries.
- **Sections**: `<fieldset>` + `<legend>` for groups of related controls, `<section>` + heading for larger areas. A sticky in-page nav (anchor list) for 6+ sections, with a scroll-spy highlight.
- **Required vs optional**: mark whichever is the minority. Explain the convention once at the top.
- **Read/edit mode**: show values as text in read mode (faster to scan, copyable), and switch the whole section or page to edit. Or use per-field inline edit for occasional single changes (see `crm-ui-patterns`). Don't mix both randomly.
- **Sticky action bar**: Save (primary), Cancel/Discard, "Saved 2 min ago" / "Unsaved changes" status, error count button. Keep it on the bottom or top consistently across the app.
- **Autosave vs explicit save**: autosave drafts for long, individual work. Use explicit Save for shared master data where changes have side effects or need validation as a unit. Never autosave directly into "live" records that trigger downstream processes.
- **Conditional fields**: reveal inline directly after the controlling field. Keep hidden values out of the submission (unregister or strip on the server). Announce newly revealed required fields through the label, not by moving focus.
- **Keyboard**: Ctrl/Cmd+S saves (preventDefault the browser save dialog). Enter in a single-line input should not submit a huge form accidentally; submit only through the Save button or shortcut. Escape cancels an inline edit, not the whole form. Document shortcuts and let users turn them off (WCAG 2.1.4 applies to single-character shortcuts).
- **Defaults and lookups**: prefill from context, use comboboxes with typeahead for reference data, and show the code + name ("DE01 – Berlin Plant").
- **Density modes**: comfortable/compact toggle persisted per user (cookie so Server Components render the right class and avoid flash). Compact reduces vertical padding and font size modestly but keeps ≥24×24px targets.

## Implementation Guidance

### Stack decision
| Need | Approach |
|---|---|
| < ~20 fields, simple validation, progressive enhancement | Native `<form action={serverAction}>` + `useActionState` + Zod on server |
| 20–300 fields, conditional logic, field arrays, instant client validation | React Hook Form (uncontrolled registration) + Zod resolver + Server Action submit |
| Repeated rows (> ~50) | Editable grid or a virtualized field array |

### Shared schema, server action with field errors
```ts
// lib/schemas/customer.ts
import { z } from 'zod';
export const CustomerSchema = z.object({
  name: z.string().trim().min(1, 'Name is required').max(120),
  taxId: z.string().trim().max(32).optional(),
  country: z.string().length(2, 'Choose a country'),
  creditLimitMinor: z.string().regex(/^\d+$/, 'Enter a whole amount in minor units'),
  billingSameAsShipping: z.boolean(),
  billingAddress: z.string().max(500).optional(),
  version: z.number().int(),
}).superRefine((v, ctx) => {
  if (!v.billingSameAsShipping && !v.billingAddress) ctx.addIssue({ code: 'custom', path: ['billingAddress'], message: 'Billing address is required' });
});
export type CustomerInput = z.infer<typeof CustomerSchema>;
```
```ts
// app/customers/[id]/edit/actions.ts
'use server';
import { CustomerSchema, type CustomerInput } from '@/lib/schemas/customer';
import { updateCustomer } from '@/data/customers';

export type SaveResult =
  | { ok: true; version: number }
  | { ok: false; fieldErrors?: Partial<Record<keyof CustomerInput, string>>; formError?: string; conflict?: boolean };

export async function saveCustomer(id: string, input: CustomerInput): Promise<SaveResult> {
  const parsed = CustomerSchema.safeParse(input);
  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const i of parsed.error.issues) fieldErrors[String(i.path[0])] ??= i.message;
    return { ok: false, fieldErrors };
  }
  const data = parsed.data.billingSameAsShipping ? { ...parsed.data, billingAddress: undefined } : parsed.data; // strip hidden values
  return updateCustomer(id, data); // DAL: session, tenant, field-level permissions, version check, business rules -> fieldErrors
}
```

### Client form (React Hook Form + Zod, server errors mapped to fields)
```tsx
'use client';
import { useForm, useWatch } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useTransition } from 'react';
import { CustomerSchema, type CustomerInput } from '@/lib/schemas/customer';
import { saveCustomer } from './actions';
import { useUnsavedChangesGuard, useSaveShortcut } from './form-hooks';

export function CustomerForm({ id, defaults }: { id: string; defaults: CustomerInput }) {
  const form = useForm<CustomerInput>({ resolver: zodResolver(CustomerSchema), defaultValues: defaults, mode: 'onBlur' });
  const { register, handleSubmit, setError, reset, control, formState: { errors, isDirty } } = form;
  const [pending, start] = useTransition();
  const same = useWatch({ control, name: 'billingSameAsShipping' });

  const onSubmit = handleSubmit((values) => start(async () => {
    const r = await saveCustomer(id, values);
    if (r.ok) return reset({ ...values, version: r.version });
    if (r.conflict) return setError('root', { message: 'Someone else saved this record. Reload to review their changes.' });
    for (const [name, message] of Object.entries(r.fieldErrors ?? {})) setError(name as keyof CustomerInput, { message }, { shouldFocus: false });
    if (r.formError) setError('root', { message: r.formError });
    document.getElementById('error-summary')?.focus();
  }));

  useUnsavedChangesGuard(isDirty && !pending);
  useSaveShortcut(() => onSubmit());

  const errorList = Object.entries(errors).filter(([k]) => k !== 'root');
  return (
    <form onSubmit={onSubmit} noValidate aria-describedby={errors.root ? 'form-error' : undefined}>
      {(errorList.length > 0 || errors.root) && (
        <div id="error-summary" tabIndex={-1} role="alert" className="mb-4 rounded border border-destructive p-3">
          {errors.root && <p id="form-error">{errors.root.message}</p>}
          {errorList.length > 0 && <p>{errorList.length} field(s) need attention:</p>}
          <ul>{errorList.map(([k, e]) => <li key={k}><a href={`#f-${k}`}>{(e as { message?: string }).message}</a></li>)}</ul>
        </div>
      )}

      <fieldset className="grid gap-x-6 gap-y-3 [grid-template-columns:repeat(auto-fit,minmax(16rem,1fr))]">
        <legend className="text-base font-semibold">General</legend>
        <Field id="f-name" label="Name" error={errors.name?.message}><input id="f-name" {...register('name')} aria-invalid={!!errors.name} aria-describedby={errors.name ? 'f-name-err' : undefined} /></Field>
        <Field id="f-taxId" label="Tax ID (optional)" error={errors.taxId?.message}><input id="f-taxId" {...register('taxId')} /></Field>
        <Field id="f-country" label="Country" error={errors.country?.message}><input id="f-country" {...register('country')} aria-invalid={!!errors.country} /></Field>
      </fieldset>

      <fieldset className="mt-6 grid gap-3">
        <legend className="text-base font-semibold">Billing</legend>
        <label className="flex items-center gap-2"><input type="checkbox" {...register('billingSameAsShipping')} /> Billing address same as shipping</label>
        {!same && (
          <Field id="f-billingAddress" label="Billing address" error={errors.billingAddress?.message}>
            <textarea id="f-billingAddress" {...register('billingAddress', { shouldUnregister: true })} rows={3} aria-invalid={!!errors.billingAddress} />
          </Field>
        )}
      </fieldset>

      <div className="sticky bottom-0 mt-6 flex items-center gap-3 border-t bg-background py-3">
        <span role="status" className="me-auto text-sm">{pending ? 'Saving…' : isDirty ? 'Unsaved changes' : 'All changes saved'}</span>
        <button type="button" onClick={() => reset(defaults)} disabled={!isDirty || pending}>Discard</button>
        <button type="submit" disabled={pending} className="btn-primary">Save <kbd className="ms-1 text-xs">Ctrl S</kbd></button>
      </div>
    </form>
  );
}

function Field({ id, label, error, children }: { id: string; label: string; error?: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={id} className="text-sm font-medium">{label}</label>
      {children}
      {error && <p id={`${id}-err`} className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
```

### Unsaved-changes guard and save shortcut
```tsx
'use client';
import { useEffect } from 'react';

export function useUnsavedChangesGuard(when: boolean, message = 'You have unsaved changes. Leave anyway?') {
  useEffect(() => {
    if (!when) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => { e.preventDefault(); e.returnValue = ''; };
    const onClick = (e: MouseEvent) => {
      const a = (e.target as Element | null)?.closest('a[href]');
      if (!a || a.getAttribute('target') === '_blank' || e.metaKey || e.ctrlKey || e.shiftKey) return;
      if (!window.confirm(message)) { e.preventDefault(); e.stopImmediatePropagation(); }
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    document.addEventListener('click', onClick, true); // capture phase, before next/link handles it
    return () => { window.removeEventListener('beforeunload', onBeforeUnload); document.removeEventListener('click', onClick, true); };
  }, [when, message]);
}

export function useSaveShortcut(save: () => void) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 's') { e.preventDefault(); save(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [save]);
}
```
Limits: Next.js App Router has no built-in API to block client-side navigation (check current docs, as this may change). The link-capture approach doesn't catch `router.push` calls or browser back/forward within the SPA. Mitigate by persisting drafts (sessionStorage or server draft) so leaving is recoverable, and by routing programmatic navigations through a guarded helper. `beforeunload` shows only the browser's generic message.

## Recommended Workflow
1. Inventory fields with domain experts: frequency of use, required-ness, dependencies, permissions, read-only rules.
2. Group into sections and order by task frequency. Decide read/edit mode and the save model (autosave draft vs explicit).
3. Write the Zod schema shared by client and server, including cross-field rules.
4. Build layout primitives (`Field`, `FieldGroup`, `FormSection`, `StickyActionBar`, `ErrorSummary`) with density variants.
5. Wire RHF with uncontrolled inputs, and the Server Action with DAL authorization, version check, and field error mapping.
6. Add the dirty guard, save shortcut, draft persistence, and conflict handling.
7. Performance-test with realistic field counts on low-end hardware. Accessibility-test keyboard and screen reader flows.

## Patterns
- **Error summary + inline errors** (GOV.UK-style): a focusable summary at the top on submit failure, with links to each field.
- **Section completeness**: the section nav shows per-section error counts ("Billing · 2 errors") computed from `formState.errors`.
- **Field-level permissions**: the server sends `{ name: 'edit', creditLimitMinor: 'read', taxId: 'hidden' }`. Render `readOnly` text or omit. The server ignores or rejects unauthorized fields.
- **Copy from reference**: "Copy address from account" fills fields and marks them dirty.
- **Draft recovery banner**: "Restore unsaved changes from 10:42?" when a local draft newer than the server version exists.
- **Virtualized field arrays**: for long repeated groups, `useFieldArray` + TanStack Virtual, rendering only visible rows while keeping values in RHF.

## Anti-Patterns
- **Controlled `useState` per field with the whole form re-rendering on every keystroke.** Laggy typing at 100+ fields. Fix: RHF uncontrolled `register`, `useWatch` only where needed.
- **Visual columns with DOM order that zigzags.** Tab jumps unpredictably (WCAG 2.4.3). Fix: DOM order matches visual reading, with no positive `tabindex`.
- **Placeholder as label.** Disappears on input, low contrast. Fix: visible `<label>`.
- **Errors only in a toast.** Users can't find the field. Fix: inline errors + summary with links + `aria-invalid`/`aria-describedby`.
- **Disabled Save until valid.** Users don't know why. Fix: keep Save enabled and show errors on submit.
- **Submitting hidden conditional values.** Stale data persists. Fix: `shouldUnregister` and strip on the server.
- **Trusting client validation.** Fix: re-parse with Zod and re-authorize in the Server Action/DAL.
- **Enter submits the whole form from any input.** Accidental saves. Fix: handle submit via button/shortcut; prevent implicit submission where needed.
- **Compact mode shrinking targets below 24px or dropping labels.** Fix: reduce padding, not affordances.

## Accessibility
- Every control has a programmatic label (WCAG 1.3.1, 4.1.2). Groups use `fieldset`/`legend`. Instructions come before inputs.
- Errors: text description (3.3.1), suggestion (3.3.3), `aria-invalid`, `aria-describedby` to the message, and a focusable summary on submit.
- Required fields: `aria-required` or `required`, plus a visible indicator not based on color alone.
- Logical focus order (2.4.3). Visible focus (2.4.7). Focus not obscured by sticky bars (2.4.11): add `scroll-padding-bottom` equal to the action bar height.
- Autocomplete attributes for personal data (1.3.5). Don't use timeouts that discard entries (2.2.1). Redundant entry: don't ask for the same info twice in a process (3.3.7).
- Read-only values are text or `readOnly` inputs (focusable, copyable), not `disabled` if users need them.
- Keyboard shortcuts documented, and single-key shortcuts must be adjustable or disableable (2.1.4).

## Responsive Design
- Grid collapses from 3 -> 2 -> 1 columns via `auto-fit` or container queries (forms often live in panels, so prefer container queries).
- Section nav becomes a select or collapsible list on narrow screens. The sticky action bar stays at the bottom with safe-area padding.
- Larger touch targets on coarse pointers (`@media (pointer: coarse)`) even in compact density.
- Avoid side-by-side label/value layouts below ~40rem.

## Performance
- RHF with uncontrolled inputs. `useWatch` scoped to the fields that drive conditions. Avoid `watch()` of the whole form in render.
- Validate `onBlur` or `onSubmit` for large forms rather than `onChange` everywhere.
- Split rarely used sections behind disclosure or tabs and render them lazily, but keep their values in form state (`shouldUnregister: false`) if they must submit.
- Virtualize long field arrays. Memoize expensive option lists (countries, plants) and load large lookups via async comboboxes.
- Server Component page shell loads the DTO. Only the form is a Client Component.

## Security
- Re-validate every field on the server with the same schema. Never trust `readOnly`/hidden state.
- Field-level authorization in the DAL: reject writes to fields the user can't edit, and don't send values for fields they can't read.
- Version check to prevent lost updates. Tenant-scope record lookup by ID (IDOR).
- Return minimal results from Server Actions (version + errors, not the whole record).
- Don't store sensitive draft data (SSNs, bank details) in localStorage. Use server-side drafts or sessionStorage with care.
- Audit changes with before/after for sensitive master data.

## Testing
- Unit: Zod schema including cross-field rules. Server field-error mapping.
- Component (Testing Library + Vitest): conditional field reveal/unregister, error summary links focus fields, dirty state toggles, Ctrl/Cmd+S triggers save.
- E2E (Playwright): keyboard-only completion in tab order, server-side validation error rendering, two-tab version conflict, navigation guard on link click, reload shows the beforeunload prompt (dialog handling).
- Performance: React Profiler typing test on a 150-field form. Check for commit time regressions.
- Accessibility: axe + manual screen reader pass on the error summary and fieldsets.

## Tooling
- React Hook Form + `@hookform/resolvers` + Zod (check current versions). Conform is an alternative for progressive-enhancement forms with Server Actions.
- TanStack Virtual for large field arrays.
- nuqs only for view state (active section/tab), never for form values.
- Storybook for density variants. Playwright + axe for verification.

## Framework Notes
- **Next.js (App Router, 16)**: `page.tsx` is a Server Component that awaits `params`, loads the DTO + field permissions, and renders a Client form. Submit through a Server Action (called from `handleSubmit`, or `<form action>` with `useActionState` for simpler forms). `revalidatePath` after saving. No built-in navigation blocking; see the guard limits above.
- **React (Vite SPA)**: same RHF + Zod setup. Submit via TanStack Query mutation with `If-Match` versioning. React Router data routers offer `useBlocker` for navigation guards; TanStack Router has its own blocking API. Check current docs for exact APIs.

## AI Agent Guidance
- Do: share one Zod schema between client and server, and map server `fieldErrors` onto fields with `setError`.
- Do: keep DOM order equal to visual order, use fieldset/legend, and add an error summary.
- Do: implement the dirty guard + Ctrl/Cmd+S, and state the guard's limitations in code comments.
- Don't: use controlled state per field for large forms, or disable Save as a validation strategy.
- Don't: submit hidden conditional values or trust client-only permission flags.
- Verify before done: keyboard-only fill works in logical order; server validation errors appear inline and in the summary; leaving with unsaved changes prompts on link click and reload; typing stays responsive with the full field count; compact mode keeps ≥24px targets.

## Examples
```tsx
// app/customers/[id]/edit/page.tsx
import { notFound } from 'next/navigation';
import { getCustomerForEdit } from '@/data/customers';
import { CustomerForm } from './customer-form';

export default async function EditCustomerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dto = await getCustomerForEdit(id); // authz + tenant scope + field permissions
  if (!dto) notFound();
  return (
    <div className="mx-auto max-w-6xl p-4 [scroll-padding-bottom:5rem]">
      <h1 className="mb-4 text-xl font-semibold">Edit customer · {dto.values.name}</h1>
      <CustomerForm id={id} defaults={dto.values} />
    </div>
  );
}
```

## Related Skills
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — form library foundations
- [form-validation-patterns](../form-validation-patterns/Skill.md) — validation timing and messaging
- [accessible-forms](../accessible-forms/Skill.md) — labels, errors, fieldsets
- [form-design-ux](../form-design-ux/Skill.md) — general form UX principles
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — secure submission
- [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md) — shortcuts and discoverability
- [erp-ui-patterns](../erp-ui-patterns/Skill.md) — object page edit mode
- [crm-ui-patterns](../crm-ui-patterns/Skill.md) — inline single-field editing
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md) — when to split forms
- [list-virtualization](../list-virtualization/Skill.md) — virtualized field arrays

## Sources
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — validating client input, re-authorizing in actions, minimal return values
- [NN/g complex applications](https://www.nngroup.com/articles/complex-application-design/) — Official (research) — reduce clutter without reducing capability, staged disclosure, expert efficiency
- [Carbon Design System (data table & density)](https://carbondesignsystem.com/components/data-table/usage/) — Official — density concept (page content not fully retrievable; general reference)
- [WAI-ARIA APG Grid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — editable grid alternative for repeated rows
- [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — error identification, focus order, focus not obscured, character key shortcuts (criteria cited from general knowledge; confirm wording)

## License / Usage Notes
Original, summarized guidance. React Hook Form, Zod, and Next.js are MIT licensed. Code examples are illustrative and may be adapted freely.

## Quality Tier
B — security and accessibility guidance grounded in official sources; React Hook Form specifics and navigation-blocking APIs were not re-fetched this pass and should be checked against current docs.

## Status
Active

## Last Verified
2026-09-15
