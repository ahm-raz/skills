# Checkbox, Radio, and Switch

## Summary
How to choose between and build checkboxes, radio groups, switches, and segmented controls in React/Next.js: semantics, grouping with fieldset/legend, the indeterminate (mixed) state, keyboard behavior, custom styling that keeps native behavior, and form submission through both React Hook Form + Zod and Server Actions. Based on the WAI-ARIA APG checkbox, radio, and switch patterns, GOV.UK guidance, NN/g toggle research, and the Radix, Base UI, and React Aria implementations.

## Category
Components

## Subcategories
checkbox, checkbox group, indeterminate / tri-state, radio group, radio cards, switch / toggle, segmented control, exclusive "none" option, conditional reveal

## Problem It Solves
Teams put switches in forms that need a Save button, build radios that behave like tabs, and make custom checkboxes out of divs that ignore Space or don't submit. Groups without fieldset/legend leave screen reader users hearing "Yes, radio button" with no question. Unchecked checkboxes are missing from `FormData`, so Server Actions misread them. This skill makes selection controls correct and consistent.

## When To Use
- A binary choice, or picking from a small visible set (about 2–7 options).
- Settings pages with toggles that apply immediately.
- Design-system Checkbox, Radio, and Switch components.
- Hierarchical "Select all" selection.

## When Not To Use
- Long or searchable lists: [select-and-combobox](../select-and-combobox/Skill.md).
- Multi-select with free text entry: [tags-and-chips-input](../tags-and-chips-input/Skill.md).
- Filter panels (instant vs apply decisions): [filters-and-faceted-search](../filters-and-faceted-search/Skill.md).
- Toolbar toggles like Bold: toggle buttons in [buttons-and-actions](../buttons-and-actions/Skill.md).
- Switching between content panels: [tabs](../tabs/Skill.md).

## Core Principles
1. Checkbox = independent on/off or multi-select. Radio = exactly one of several exclusive options. Switch = an on/off setting that applies immediately.
2. Use the native `<input type="checkbox">` / `<input type="radio">` when you can. Restyle it; don't replace it.
3. Wrap related options in a `<fieldset>` whose `<legend>` asks the question.
4. Labels are clickable and describe the option. A switch label names the setting and never changes with state.
5. Question-style radio groups usually start with nothing selected, which avoids bias and defaults nobody noticed. The exception is an expected safe default, like standard shipping.
6. Selected state must be visible without color: a checkmark, dot, thumb position, or text.
7. The server interprets form data explicitly: unchecked means absent, and groups are arrays.

## Best Practices
- Stack options vertically. Only lay out 2 short options (Yes/No) side by side.
- Order options logically (by frequency, alphabetically, or in natural order), never randomly.
- Consent checkbox: the label spells out what the user agrees to. Never pre-check marketing opt-ins (GDPR, dark pattern).
- For checkbox groups, add a hint under the legend: "Select all that apply".
- Exclusive "None of these": put it last, separated by "or". Selecting it clears the others and vice versa. The schema also rejects the conflict for when JS doesn't run.
- Conditional reveal: reveal only one simple follow-up question right after the selected option. Anything complex goes on the next page.
- Switches take effect immediately and give feedback (optimistic state, with rollback on error). If the change needs Save, use a checkbox (NN/g).
- Switch label is a noun phrase ("Email notifications"). Optional On/Off text never replaces the label.
- Hit area: make the whole label row clickable. At least 24px (SC 2.5.8); rows 44px tall on touch.
- Error messages (GOV.UK style): "Select if you have a passport", "Select how you want to be contacted". Link the error to the group and set `aria-invalid` on the inputs.
- Radio cards: the native radio sits inside the label, the description is linked with `aria-describedby`, and the card is styled with `has-checked:`.
- Segmented control for single-select: build it as a radio group (or Radix/Base UI `ToggleGroup` single), not tabs, unless it switches panels.
- For brand color on native controls, `accent-color` (Tailwind `accent-*`) is often enough.

## Implementation Guidance

### Choosing the control
| Situation | Control |
|---|---|
| Agree to terms, remember me | Single checkbox |
| Choose any number of several | Checkbox group |
| Choose exactly one of 2–7 visible | Radio group |
| Choose one of many | Select / combobox |
| Setting applies immediately | Switch |
| Setting saved with the form | Checkbox |
| Parent controls children | Checkbox with indeterminate |
| Compact single-select | Segmented control (radio semantics) |

### Keyboard
| Control | Key | Behavior |
|---|---|---|
| Checkbox | Tab | Each checkbox is its own tab stop |
| Checkbox | Space | Toggles |
| Radio group | Tab / Shift+Tab | Enters the group on the checked radio (or the first if none), then leaves the group |
| Radio group | Down / Right Arrow | Moves to and checks the next radio (wraps) |
| Radio group | Up / Left Arrow | Moves to and checks the previous radio (wraps) |
| Radio group | Space | Checks the focused radio |
| Switch | Space (Enter optional) | Toggles |

Native radios with the same `name` provide roving focus for free. Custom radio groups must implement roving `tabIndex` (Radix, Base UI, and React Aria do).

### ARIA when not native
- Checkbox: `role="checkbox"`, `aria-checked="true|false|mixed"`, a name. Group with `role="group"` + `aria-labelledby`.
- Radio: `role="radiogroup"` with a name; each child has `role="radio"` + `aria-checked`, with roving tabindex.
- Switch: `role="switch"` + `aria-checked` (no mixed state). Radix renders a `button role="switch"`; Base UI renders a span with a hidden input. Safari also supports `<input type="checkbox" switch>` natively; other engines ignore the attribute and show a checkbox.
- Native indeterminate: `input.indeterminate = true` has no HTML attribute. In React, set it through a ref. Clicking clears it, so recompute from the children.

### FormData and schemas
| Control | FormData | Server conversion |
|---|---|---|
| Single checkbox `name="terms"` | `'on'` (or its `value`) when checked, **missing** when unchecked | `formData.get('terms') === 'on'` |
| Checkbox group `name="topics"` | Repeated keys | `formData.getAll('topics')` |
| Radio group `name="contact"` | The value, or missing | `formData.get('contact') ?? undefined` |
| Radix / Base UI checkbox or switch | Hidden input inside `<form>` | Same as native (Base UI `uncheckedValue` can submit an explicit off value) |

React Hook Form `register` on native checkboxes gives a `boolean` for a single checkbox and a `string[]` for a group (set `defaultValues` to `[]`), so one Zod schema covers both paths.

### Indeterminate "Select all"
- The parent is checked when all children are, unchecked when none are, and mixed otherwise.
- Clicking a mixed parent usually checks all. APG's tri-state example restores the previous partial selection instead; pick one behavior and document it.
- Library support: Base UI `Checkbox.Root parent` inside `CheckboxGroup allValues`; React Aria `Checkbox isIndeterminate`; Radix `checked="indeterminate"`.

## Recommended Workflow
1. For each choice, pick the control from the table: multi or single, immediate or saved.
2. Write the question as the legend, short option labels, and a hint if needed.
3. Build with native inputs inside labels, grouped in a fieldset, or use a primitive library that renders hidden inputs.
4. Define states: default, hover, focus-visible, checked, indeterminate, disabled, invalid, forced-colors.
5. Put the rules in a shared Zod schema: enums for radios, arrays with `min(1)` and exclusivity checks for groups, and a boolean refine for consent.
6. Wire both paths as needed: Server Action with explicit FormData conversion, or RHF `register` calling the action. The server always runs `safeParse`.
7. For switches, call a Server Action immediately with a pending state and rollback.
8. Test keyboard (Tab / Space / arrows), screen readers (group name read on entry), forced colors, and submitted values.

## Patterns
- **Yes/No inline radios**: two radios in a row; the legend is the question, and on one-question pages it's also the page heading.
- **Checkbox group with "None"**: an exclusive last option after an "or" divider.
- **Select all**: a parent checkbox above an indented list; optionally `aria-controls` pointing at the child IDs.
- **Radio cards**: a large label containing the radio, title, description, and price, styled with `has-checked:ring-2`.
- **Settings rows with switches**: label + description + switch; each toggle saves on its own and shows an inline error and rollback on failure.
- **Conditional reveal**: a follow-up rendered right after the controlling option when it's checked (`watch` in RHF, local state in action forms).
- **Segmented control**: looks like buttons, but it's a radio group with arrow keys.

## Anti-Patterns
- **Switch in a form with a Submit button**: users think it already saved. Fix: checkbox.
- **Checkboxes for exclusive options**: allows invalid combinations. Fix: radios.
- **A single radio button**: can't be unchecked. Fix: checkbox.
- **Radio group without fieldset/legend**. Fix: fieldset + legend, or `role="radiogroup"` + `aria-labelledby`.
- **Div checkbox** with no Space support and no form value. Fix: native input, or Radix / Base UI / React Aria.
- **`display: none` / `hidden` on the native input** for custom styling: removes it from keyboard and accessibility tree. Fix: `appearance-none` on the visible input, or a visually-hidden technique.
- **Switch label that flips** ("Enabled" / "Disabled"). Fix: a constant label; state comes from `aria-checked`.
- **Pre-checked marketing consent**. Fix: unchecked by default.
- **Treating an unchecked checkbox as "no change"** in the Server Action: missing from FormData means false. Fix: explicit conversion.
- **`z.coerce.boolean()` on FormData**: `Boolean('false')` is `true`. Fix: `=== 'on'`.
- **A 16px box as the only hit area**. Fix: clickable label and padding.
- **Custom radio group where arrows only move focus**: differs from native. Fix: arrows move and check.

## Accessibility
- SC 1.3.1: fieldset/legend or `role="group"` / `role="radiogroup"` with a name.
- SC 4.1.2: role, name, and checked state (including mixed).
- SC 2.1.1 keyboard per the table; SC 2.4.7 focus visible; SC 2.5.8 target size.
- SC 1.4.11: control borders and checked indicators need 3:1 contrast; checked state can't be only a change of fill color.
- SC 3.3.1 / 3.3.3: a group-level error message linked to the group.
- Forced colors (Windows High Contrast): custom controls must stay visible. Use system colors or `forced-colors:appearance-auto`.
- NVDA and JAWS read the legend on entering the group; VoiceOver is less consistent, so keep legends short.
- Switch role support is good in current NVDA, JAWS, VoiceOver, and TalkBack; check your target assistive tech.

## Responsive Design
- Vertical stacks at every breakpoint; 44px rows on touch.
- Radio cards: one column in narrow containers, a grid in wider ones (container queries).
- Long labels wrap under the label text, not under the control (`grid grid-cols-[auto_1fr]`).
- RTL: the switch thumb moves the other way. Use logical properties or `rtl:` variants.

## Performance
- Large checkbox lists (hundreds of permissions): group them with disclosures or virtualize; keep selection in a `Set`, and avoid re-rendering every row on each toggle (React Compiler or memoized rows).
- Switch saves: optimistic update first, then the Server Action in a transition, so INP stays low.

## Security
- The server validates allowed values; hidden or disabled options can still be posted by a crafted request.
- Permission and role toggles need server-side authorization and audit logging in the action.
- Consent records: store the timestamp and the policy version on the server, not only a boolean.

## Testing
- Testing Library: `getByRole('checkbox' | 'radio' | 'switch', { name })`, `toBeChecked()`, `toBePartiallyChecked()`.
- `getByRole('group', { name: 'How would you like to be contacted?' })` confirms the legend is wired.
- `user.keyboard('[Space]')`, `'{ArrowDown}'`: the radio becomes checked on arrow.
- Schema tests: no radio chosen, empty group, "none" plus another option, consent false.
- Server Action tests: `FormData` without `terms` → consent error; repeated `topics` → array parsed.
- Playwright: forced-colors screenshots (`page.emulateMedia({ forcedColors: 'active' })`), axe rules `label` and `aria-toggle-field-name`.

## Tooling
- Native inputs + Tailwind `accent-*` / `appearance-none` + `checked:` / `indeterminate:` / `has-checked:` variants: zero JS.
- Radix `Checkbox` (`checked="indeterminate"`), `RadioGroup`, `Switch` (button with role, hidden input in forms). Active.
- Base UI `Checkbox`, `CheckboxGroup` (parent checkbox), `Radio` / `RadioGroup`, `Switch` (`@base-ui/react` v1.x). Active.
- React Aria `Checkbox`, `CheckboxGroup`, `RadioGroup`, `Switch` (visually hidden native inputs). Active.
- shadcn/ui `Checkbox`, `RadioGroup`, `Switch`, `ToggleGroup` (Radix or Base UI builds). Active.
- React Hook Form + `@hookform/resolvers` + Zod 4. Active.

## Framework Notes
- **React (Vite SPA)**: native inputs work with RHF `register`. Radix, Base UI, and React Aria controls aren't native inputs from RHF's point of view, so use `Controller` (`checked={field.value}` / `onCheckedChange={field.onChange}`). Submit JSON to your API, which imports the same schema. Native indeterminate needs a ref effect.
- **Next.js (App Router)**: native inputs and the primitive libraries both submit through `<form action>` because the primitives render hidden inputs. Convert FormData explicitly (`=== 'on'`, `getAll`). Return `values` and use `defaultChecked` to survive React 19 form reset. Immediate-effect switches call a Server Action directly inside `startTransition`, then `revalidatePath` for server-rendered settings.

## AI Agent Guidance
- Do: pick the control from the table; use native inputs in labels; group with fieldset/legend; keep switch labels constant; implement indeterminate through a ref; convert FormData explicitly; share one Zod schema; `safeParse` in actions; ensure 24px+ targets and visible focus.
- Don't: put switches in submit-to-save forms; hide native inputs with `display:none`; pre-check consent; use a single radio; use `z.coerce.boolean()` on FormData; build div checkboxes.
- Verify before done: Tab enters the radio group once and arrows change the selection; Space toggles checkboxes and switches; the screen reader announces the group name, role, and state; the server receives correct values when nothing is checked; forced-colors mode still shows state; axe passes.

## Examples
```tsx
// components/ui/checkbox.tsx — native input, custom look, forced-colors safe
import { useEffect, useRef } from 'react';

type CheckboxProps = Omit<React.ComponentProps<'input'>, 'type'> & { label: React.ReactNode; indeterminate?: boolean };

export function Checkbox({ label, indeterminate = false, className = '', ref: _ignored, ...props }: CheckboxProps) {
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => { if (ref.current) ref.current.indeterminate = indeterminate; }, [indeterminate]);
  return (
    <label className="grid min-h-11 cursor-pointer grid-cols-[auto_1fr] items-center gap-3">
      <span className="relative grid size-6 place-items-center">
        <input
          ref={ref}
          type="checkbox"
          className={`peer size-6 appearance-none rounded border-2 border-gray-900 bg-white
            checked:bg-gray-900 indeterminate:bg-gray-900 aria-[invalid=true]:border-red-700
            focus-visible:outline-3 focus-visible:outline-offset-2 forced-colors:appearance-auto ${className}`}
          {...props}
        />
        <svg aria-hidden="true" viewBox="0 0 16 16"
          className="pointer-events-none absolute hidden size-4 fill-none stroke-white stroke-2 peer-checked:block forced-colors:hidden">
          <path d="M3 8.5 6.5 12 13 4" />
        </svg>
        <span aria-hidden="true"
          className="pointer-events-none absolute hidden h-0.5 w-3 bg-white peer-indeterminate:block forced-colors:hidden" />
      </span>
      <span>{label}</span>
    </label>
  );
}
```
Note: `register()` passes its own `ref`, and this component needs a local ref for `indeterminate`. For RHF, merge the refs (e.g., a callback ref that sets both) or use the component only for native forms. The simplified version above ignores the incoming ref.

```tsx
// app/preferences/schema.ts — ONE schema for RHF and the Server Action
import { z } from 'zod';

export const CONTACT_METHODS = ['email', 'phone', 'post'] as const;
export const TOPIC_OPTIONS = ['product', 'events', 'research', 'none'] as const;

export const preferencesSchema = z.object({
  contact: z.enum(CONTACT_METHODS, 'Select how you want to be contacted'),
  topics: z
    .array(z.enum(TOPIC_OPTIONS))
    .min(1, 'Select which updates you want, or select "None of these"')
    .refine((t) => !(t.includes('none') && t.length > 1), 'Select updates, or select "None of these", not both'),
  terms: z.boolean().refine((v) => v, 'Select to confirm you agree to the privacy policy'),
});

export type PreferencesInput = z.infer<typeof preferencesSchema>;
export type PreferencesState = {
  ok: boolean;
  message?: string;
  errors?: Partial<Record<keyof PreferencesInput, string[]>>;
  values?: { contact?: string; topics?: string[]; terms?: boolean };
};

export const notificationSchema = z.object({ enabled: z.boolean() });
```

```tsx
// app/preferences/actions.ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { preferencesSchema, notificationSchema, type PreferencesState } from './schema';
import { requireUser, savePreferences, setEmailNotifications } from '@/lib/server/preferences';

async function handle(input: unknown): Promise<PreferencesState> {
  const user = await requireUser();
  const parsed = preferencesSchema.safeParse(input);          // server ALWAYS re-validates
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  await savePreferences(user, parsed.data);
  revalidatePath('/preferences');
  return { ok: true, message: 'Preferences saved' };
}

export async function savePreferencesAction(_prev: PreferencesState, formData: FormData): Promise<PreferencesState> {
  const values = {
    contact: (formData.get('contact') as string | null) ?? undefined,  // missing when nothing chosen
    topics: formData.getAll('topics').map(String),                     // repeated keys → array
    terms: formData.get('terms') === 'on',                             // missing → false (NOT z.coerce.boolean)
  };
  const result = await handle(values);
  return result.ok ? result : { ...result, values };
}

export async function savePreferencesRHF(input: unknown): Promise<PreferencesState> {
  return handle(input);
}

export async function updateEmailNotifications(input: unknown): Promise<{ ok: boolean }> {
  const user = await requireUser();
  const parsed = notificationSchema.safeParse(input);
  if (!parsed.success) return { ok: false };
  await setEmailNotifications(user, parsed.data.enabled);
  return { ok: true };
}
```

```tsx
// app/preferences/preferences-form-action.tsx — Server Action + useActionState + useFormStatus
'use client';
import { useActionState } from 'react';
import { savePreferencesAction } from './actions';
import { CONTACT_METHODS, type PreferencesState } from './schema';
import { Checkbox } from '@/components/ui/checkbox';
import { SubmitButton } from '@/components/ui/submit-button';

const CONTACT_LABELS = { email: 'Email', phone: 'Phone', post: 'Post' } as const;

export function PreferencesFormAction() {
  const [state, formAction] = useActionState<PreferencesState, FormData>(savePreferencesAction, { ok: false });
  const e = state.errors;
  const v = state.values;

  return (
    <form action={formAction} noValidate className="grid max-w-prose gap-8">
      <fieldset aria-describedby={e?.contact ? 'contact-error' : undefined}>
        <legend className="text-lg font-semibold">How would you like to be contacted?</legend>
        {e?.contact && <p id="contact-error" className="text-red-700"><span className="sr-only">Error: </span>{e.contact[0]}</p>}
        {CONTACT_METHODS.map((m) => (
          <label key={m} className="flex min-h-11 items-center gap-3">
            <input type="radio" name="contact" value={m} defaultChecked={v?.contact === m}
              aria-invalid={e?.contact ? true : undefined} className="size-6 accent-gray-900" />
            {CONTACT_LABELS[m]}
          </label>
        ))}
      </fieldset>

      <fieldset aria-describedby={`topics-hint${e?.topics ? ' topics-error' : ''}`}>
        <legend className="text-lg font-semibold">Which updates do you want?</legend>
        <div id="topics-hint">Select all that apply</div>
        {e?.topics && <p id="topics-error" className="text-red-700"><span className="sr-only">Error: </span>{e.topics[0]}</p>}
        <Checkbox name="topics" value="product" label="Product news" defaultChecked={v?.topics?.includes('product')} />
        <Checkbox name="topics" value="events" label="Events" defaultChecked={v?.topics?.includes('events')} />
        <Checkbox name="topics" value="research" label="Research invitations" defaultChecked={v?.topics?.includes('research')} />
        <p className="my-2">or</p>
        <Checkbox name="topics" value="none" label="None of these updates" defaultChecked={v?.topics?.includes('none')} />
      </fieldset>

      <div>
        {e?.terms && <p id="terms-error" className="text-red-700"><span className="sr-only">Error: </span>{e.terms[0]}</p>}
        <Checkbox name="terms" label="I agree to the privacy policy" defaultChecked={v?.terms}
          aria-invalid={e?.terms ? true : undefined} aria-describedby={e?.terms ? 'terms-error' : undefined} />
      </div>

      <SubmitButton pendingLabel="Saving…">Save preferences</SubmitButton>
      <p role="status">{state.ok ? state.message : ''}</p>
    </form>
  );
}
```

```tsx
// app/preferences/preferences-form-rhf.tsx — React Hook Form + Zod, exclusive "none", same schema
'use client';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { preferencesSchema, CONTACT_METHODS, type PreferencesInput } from './schema';
import { savePreferencesRHF } from './actions';
import { Button } from '@/components/ui/button';

const TOPICS = [
  { value: 'product', label: 'Product news' },
  { value: 'events', label: 'Events' },
  { value: 'research', label: 'Research invitations' },
] as const;

export function PreferencesFormRHF() {
  const [status, setStatus] = useState('');
  const { register, handleSubmit, setValue, getValues, setError, formState: { errors, isSubmitting } } =
    useForm<PreferencesInput>({
      resolver: zodResolver(preferencesSchema),
      mode: 'onSubmit',
      reValidateMode: 'onChange',
      defaultValues: { topics: [], terms: false },
    });

  const topicsReg = register('topics', {
    onChange: (e: React.ChangeEvent<HTMLInputElement>) => {
      if (!e.target.checked) return;                          // enforce exclusivity for "none"
      const current = getValues('topics');
      setValue('topics', e.target.value === 'none' ? ['none'] : current.filter((t) => t !== 'none'),
        { shouldValidate: !!errors.topics });
    },
  });

  const onSubmit = handleSubmit(async (values) => {
    const res = await savePreferencesRHF(values);            // server re-validates
    if (!res.ok) {
      for (const [k, msgs] of Object.entries(res.errors ?? {})) {
        if (msgs?.[0]) setError(k as keyof PreferencesInput, { message: msgs[0] });
      }
      return;
    }
    setStatus(res.message ?? 'Saved');
  });

  const box = 'size-6 accent-gray-900';
  return (
    <form onSubmit={onSubmit} noValidate className="grid max-w-prose gap-8">
      <fieldset aria-describedby={errors.contact ? 'rhf-contact-error' : undefined}>
        <legend className="text-lg font-semibold">How would you like to be contacted?</legend>
        {errors.contact && <p id="rhf-contact-error" className="text-red-700">{errors.contact.message}</p>}
        {CONTACT_METHODS.map((m) => (
          <label key={m} className="flex min-h-11 items-center gap-3">
            <input type="radio" value={m} {...register('contact')} aria-invalid={errors.contact ? true : undefined} className={box} />
            {m[0].toUpperCase() + m.slice(1)}
          </label>
        ))}
      </fieldset>

      <fieldset aria-describedby={`rhf-topics-hint${errors.topics ? ' rhf-topics-error' : ''}`}>
        <legend className="text-lg font-semibold">Which updates do you want?</legend>
        <div id="rhf-topics-hint">Select all that apply</div>
        {errors.topics && <p id="rhf-topics-error" className="text-red-700">{errors.topics.message}</p>}
        {TOPICS.map((t) => (
          <label key={t.value} className="flex min-h-11 items-center gap-3">
            <input type="checkbox" value={t.value} {...topicsReg} className={box} /> {t.label}
          </label>
        ))}
        <p className="my-2">or</p>
        <label className="flex min-h-11 items-center gap-3">
          <input type="checkbox" value="none" {...topicsReg} className={box} /> None of these updates
        </label>
      </fieldset>

      <div>
        {errors.terms && <p id="rhf-terms-error" className="text-red-700">{errors.terms.message}</p>}
        <label className="flex min-h-11 items-center gap-3">
          <input type="checkbox" {...register('terms')} aria-invalid={errors.terms ? true : undefined}
            aria-describedby={errors.terms ? 'rhf-terms-error' : undefined} className={box} />
          I agree to the privacy policy
        </label>
      </div>

      <Button type="submit" pending={isSubmitting}>{isSubmitting ? 'Saving…' : 'Save preferences'}</Button>
      <p role="status">{status}</p>
    </form>
  );
}
```

```tsx
// app/settings/email-notifications-switch.tsx — immediate-effect switch calling a Server Action
'use client';
import { useState, useTransition } from 'react';
import { Switch } from '@base-ui/react/switch';
import { updateEmailNotifications } from '../preferences/actions';

export function EmailNotificationsSwitch({ initial }: { initial: boolean }) {
  const [enabled, setEnabled] = useState(initial);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  return (
    <div className="flex min-h-11 items-center justify-between gap-4" aria-busy={isPending || undefined}>
      <label className="flex items-center gap-3">
        <span>Email notifications</span>
        <Switch.Root
          checked={enabled}
          aria-describedby={error ? 'notif-error' : undefined}
          onCheckedChange={(next) => {
            setEnabled(next);                                 // optimistic
            setError(null);
            startTransition(async () => {
              const res = await updateEmailNotifications({ enabled: next }); // server validates with z.boolean()
              if (!res.ok) { setEnabled(!next); setError('Could not update email notifications. Try again.'); }
            });
          }}
          className="relative h-7 w-12 rounded-full border-2 border-gray-900 data-[checked]:bg-gray-900
            focus-visible:outline-3 focus-visible:outline-offset-2"
        >
          <Switch.Thumb className="block size-5 translate-x-0.5 rounded-full bg-gray-900 transition-transform
            data-[checked]:translate-x-5 data-[checked]:bg-white rtl:data-[checked]:-translate-x-5" />
        </Switch.Root>
      </label>
      {error && <p id="notif-error" role="alert" className="text-red-700">{error}</p>}
    </div>
  );
}
```

## Related Skills
- [form-design-ux](../form-design-ux/Skill.md) — question design, one thing per page
- [form-validation-patterns](../form-validation-patterns/Skill.md) — group error messages
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — Controller vs register, schema typing
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — FormData conversion and security
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — transitions for immediate toggles
- [select-and-combobox](../select-and-combobox/Skill.md) — when options exceed a visible set
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — checkbox facets
- [buttons-and-actions](../buttons-and-actions/Skill.md) — toggle buttons vs switches
- [settings-and-preferences-ux](../settings-and-preferences-ux/Skill.md) — screens full of switches
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — pre-checked consent
- [keyboard-navigation](../keyboard-navigation/Skill.md) — roving tabindex
- [optimistic-ui](../optimistic-ui/Skill.md) — immediate toggles with rollback

## Sources
- [WAI-ARIA APG: Switch Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/switch/) — Official — role, keys, constant label, no mixed state
- [WAI-ARIA APG: Checkbox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/) — Official — dual-state and tri-state behavior
- [WAI-ARIA APG: Radio Group Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/radio/) — Official — roving focus, arrow keys
- [GOV.UK Design System: Checkboxes](https://design-system.service.gov.uk/components/checkboxes/) and [Radios](https://design-system.service.gov.uk/components/radios/) — Official — "none" option, conditional reveal, error wording
- [NN/g: Toggle-Switch Guidelines](https://www.nngroup.com/articles/toggle-switch-guidelines/) — Community (research) — immediate effect, labels
- [Base UI Checkbox](https://base-ui.com/react/components/checkbox) — Open Source — parent checkbox, uncheckedValue, hidden input
- [Radix Switch](https://www.radix-ui.com/primitives/docs/components/switch) — Open Source — parts, hidden input, keyboard
- [React Aria Checkbox / RadioGroup / Switch](https://react-aria.adobe.com/) — Open Source — implementations backed by native inputs
- [MDN: FormData.getAll](https://developer.mozilla.org/en-US/docs/Web/API/FormData/getAll) — Official — repeated keys for checkbox groups

## License / Usage Notes
Summarized from W3C APG (W3C license), GOV.UK (MIT/OGL), NN/g (summarized, not copied), MDN (CC-BY-SA), Radix and Base UI (MIT), React Aria (Apache-2.0), React Hook Form (MIT), Zod (MIT). All code examples are original.

## Quality Tier
S — based directly on APG patterns, GOV.UK research-backed guidance, NN/g, and three major library implementations, with full keyboard, ARIA, FormData, and dual-stack validation coverage.

## Status
Active

## Last Verified
2026-09-15
