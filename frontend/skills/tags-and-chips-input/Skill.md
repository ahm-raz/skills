# Tags and Chips Input

## Summary
How to build inputs that collect several discrete values as removable chips (tags, recipients, labels, skills, email addresses), and how to display chip or tag groups. Covers creating tokens from free text (Enter or comma or paste), combining with suggestions, removing by keyboard, focus management after removal, validation of individual tokens, ARIA semantics (list vs grid/TagGroup), and form submission.

## Category
Components

## Subcategories
Token input, chip group, tag group, multi-value field, email recipients input, creatable multi-select, filter chips, removable chips

## Problem It Solves
Multi-value fields are often implemented as a text input plus floating `span`s. That leaves chips unreachable by keyboard, removal buttons unlabeled, focus lost after deleting a chip, paste of comma-separated lists broken, silent duplicates, and values that never reach the form. This skill defines a robust, accessible token-input and chip-group contract.

## When To Use
- Users enter an open-ended set of short values: tags, keywords, email recipients, skills.
- A multi-select from a large or async list where selected items should be visible and individually removable.
- Showing a set of applied values that can be removed (applied filters, selected labels).
- Pasting lists of values (emails, SKUs, IDs).

## When Not To Use
- Small closed set of options: use a checkbox group (`checkbox-radio-switch`).
- Single value: use a text input or `select-and-combobox`.
- Values are long sentences or need rich editing: use a list of text inputs ("Add another") or `rich-text-editors`.
- Toggle-style filter chips on a results page (on/off, no text entry): mostly covered in `filters-and-faceted-search`. Toggle chips are buttons with `aria-pressed`, not tokens.
- The order of values matters and users must reorder them: consider a sortable list (`drag-and-drop`).

## Core Principles
1. **Every chip is reachable and removable by keyboard.** Every remove affordance has an accessible name that includes the value ("Remove tag: design").
2. **Focus never gets lost.** After removing a chip, focus moves to the next chip, then the previous one, then the input.
3. **Text is never silently discarded.** Pending text commits on the delimiter, or is kept visible with guidance. On blur, either commit (if valid) or keep it as an invalid draft. Never drop it silently.
4. **Validate each token.** Invalid tokens (bad email, too long, duplicate) are shown inline with a text explanation, not just red color.
5. **Submit a real value.** Use a multi-value `name` (repeated hidden inputs or a JSON field) that works with native form submission and schema validation.
6. **Chips are not buttons unless they do something.** Pick semantics by behavior: static list, removable grid or tag group, toggle buttons, or links.

## Best Practices
- Delimiters: Enter and comma create a token. Also split pasted text on commas, semicolons, newlines, and (for emails) whitespace. Tell users which ones work in the hint ("Separate with commas or press Enter").
- Enter must not submit the surrounding form while the input has text. It does submit when the input is empty only if that fits the form's design.
- Trim whitespace, normalize case where appropriate (tags lowercase, emails lowercase domain), and de-duplicate. Flash or announce "already added" instead of silently ignoring.
- Backspace in an empty input: first press focuses or highlights the last chip, second press removes it. Removing on the first press causes accidental deletions.
- Show a count and limit when constrained ("3 of 5 tags"), and disable further entry with an explanation when the limit is reached.
- Let users edit a token: double-click or Enter on a chip turns it back into text in the input. At minimum, remove + retype must be easy.
- With suggestions, the combobox popup lists matches, excludes already-selected values, and offers `Create "xyz"` when creation is allowed.
- Let long chip labels truncate with ellipsis and expose the full value (title is not enough, so the accessible name must contain the full text).
- Chip layout wraps onto multiple lines inside the field, and the field grows vertically. Avoid horizontal scrolling inside inputs.
- Provide "Clear all" only when there are many chips, and make it a separate, clearly labeled button.

## Implementation Guidance

### Semantics decision table
| Chip behavior | Markup |
|---|---|
| Static display (read-only tags) | `<ul aria-label="Tags"><li>design</li>…</ul>` |
| Removable, each with an × button | `<ul>` of `<li>` with text + `<button aria-label="Remove design">` (simple, each button is a Tab stop), **or** a TagGroup (`role="grid"` rows) with arrow-key roving focus and Delete/Backspace |
| Selectable chips (single/multi) | TagGroup with `selectionMode` (grid with `aria-selected`) or a checkbox group styled as chips |
| Toggle filter chips | `<button aria-pressed="true">` in a labeled group |
| Chips that navigate | Links in a list |
| Multi-select combobox tokens | Combobox input (APG) + chips rendered before it (Base UI `Combobox.Chips`, Downshift `useTagGroup` + `useCombobox`) |

Rule of thumb: under about 5 removable chips, the simple list with buttons is fine. For many chips, a roving-tabindex tag group (one Tab stop, arrows inside) keeps tab order usable.

### Keyboard (token input with roving chip focus)
| Key | Where | Behavior |
|---|---|---|
| Enter / `,` | Input with text | Commit token (validate); keep focus in input |
| Enter | Input with highlighted suggestion | Add that suggestion |
| Backspace | Empty input | Focus last chip; second Backspace removes it |
| Left Arrow | Input, caret at start | Focus last chip |
| Left / Right Arrow | Chip | Move between chips; Right past last returns to input |
| Home / End | Chip group | First / last chip |
| Delete / Backspace | Chip | Remove chip; focus next (or previous, or input) |
| Enter (optional) | Chip | Edit chip text |
| Escape | Input with popup | Close suggestions |
| Tab | Anywhere | Leave the widget (chip group is one tab stop) |
| Ctrl/Cmd+V | Input | Split and add multiple tokens; report invalid ones |

### ARIA and announcements
- Label the whole field (`<label>` for the input). Give the chip list an accessible name ("Selected tags").
- Remove buttons: `aria-label="Remove {value}"`. The icon is `aria-hidden`.
- Announce additions and removals politely: "design added, 3 tags", "design removed". Library TagGroups handle focus. You may still add a status region.
- Invalid token: mark the chip with visible text or an icon plus a description (`aria-describedby` pointing to "Not a valid email"). Mark the field `aria-invalid` if any token is invalid on submit.
- `aria-describedby` on the input points to the hint and error message.

### Form value
- Native: render `<input type="hidden" name="tags" value="design">` per token. The server receives repeated keys (`formData.getAll('tags')`).
- Schema: `z.array(z.string().trim().min(1).max(30)).max(10)` plus a refinement for uniqueness. Email recipients: `z.array(z.email())`, where `z.email()` is the top-level Zod v4 form.

## Recommended Workflow
1. Define the value rules: free text vs from a list vs both, max count, max length, format, uniqueness, case normalization.
2. Choose semantics from the table and pick a primitive (React Aria `TagGroup` + `ComboBox`, Base UI `Combobox multiple` with `Chips`, Downshift `useTagGroup` + `useCombobox`, or a well-tested custom implementation).
3. Implement tokenization (delimiters, paste splitting, trimming, de-dup) as a pure function with unit tests.
4. Implement focus management for removal and the Backspace flow.
5. Implement per-token validation and field-level errors that integrate with the form library.
6. Style states: chip default, focus-visible, selected, invalid, disabled; field focus-within; limit reached.
7. Test keyboard, screen reader announcements, paste of 50 values, and mobile (virtual keyboard comma and Enter behavior).

## Patterns
- **Email recipients field.** Free text, tokenizes on comma, semicolon, space, or paste. Invalid addresses become red chips with an error icon and text. Suggestions come from contacts.
- **Creatable tags with suggestions.** A combobox shows existing tags, and a last row `Create "xyz"` adds a new one.
- **Chip group display.** Read-only tag list on cards: a plain list, no buttons, overflow as "+3 more" (a disclosure button that reveals the rest).
- **Applied-filter chips.** Each chip reads "Color: Blue ×" and removes that refinement. Includes a "Clear all" button. See `filters-and-faceted-search`.
- **Editable token.** Enter or double-click on a chip moves its text into the input for editing. Commit re-validates.

```tsx
// lib/tokenize.ts — pure tokenizer, safe to import from client and server; unit test this
export function tokenize(raw: string, existing: string[], opts: {max?: number; normalize?: (s: string) => string} = {}) {
  const norm = opts.normalize ?? ((s) => s.trim().toLowerCase());
  const seen = new Set(existing.map(norm));
  const added: string[] = [];
  const duplicates: string[] = [];
  for (const part of raw.split(/[,;\n]+/)) {
    const v = norm(part);
    if (!v) continue;
    if (seen.has(v)) { duplicates.push(v); continue; }
    if (opts.max && existing.length + added.length >= opts.max) break;
    seen.add(v); added.push(v);
  }
  return {added, duplicates};
}
```

## Anti-Patterns
| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| × icon `<span onClick>` | Not focusable, unnamed | `<button type="button" aria-label="Remove {value}">` or TagGroup remove slot |
| Remove button named just "Remove" or "×" | Screen reader users can't tell which chip | Include the value in the name |
| Backspace instantly deletes last chip | Accidental data loss while correcting typing | Two-step: focus, then delete |
| Focus drops to `<body>` after removal | Keyboard users lose their place | Move focus to next, previous, or input |
| Enter submits the form mid-entry | Premature submission | `preventDefault` on Enter when input has text or popup open |
| Pending text lost on blur | Silent data loss | Commit valid text on blur or keep as a visible draft with a hint |
| Silent duplicate ignore | Users think input failed | Announce/flash "already added" |
| Only color marks invalid chip | Fails WCAG 1.4.1 | Icon + text + `aria-describedby` |
| Every chip a Tab stop in a 40-chip field | Tab fatigue | Roving tabindex tag group |
| Chips as `role="option"` outside a listbox | Invalid ARIA | List/grid/TagGroup semantics |
| Values only in component state | Nothing submitted | Hidden inputs per token / registered array field |

## Accessibility
- WCAG 2.1.1: add, navigate, edit, and remove all work with the keyboard. 2.4.3: focus order is logical after removal.
- WCAG 4.1.2: remove controls have names that include the value. Selected chips expose `aria-selected` or `aria-pressed` as appropriate.
- WCAG 4.1.3: announce add/remove/duplicate/limit status politely.
- WCAG 3.3.1/3.3.3: identify invalid tokens in text and suggest a fix ("Missing @ in 'jane.example.com'").
- WCAG 1.4.1 and 1.4.11: invalid and selected states are not color-only. Chip borders or focus rings ≥3:1.
- WCAG 2.5.8: remove buttons ≥24×24 CSS px. Pad the hit area even if the icon is small.
- Put the hint text about delimiters in `aria-describedby`. Screen reader users otherwise don't know that a comma creates a token.
- React Aria `TagGroup` and Downshift `useTagGroup` implement roving focus and removal. Prefer them to custom code.

## Responsive Design
- Many mobile keyboards lack an easily reachable comma. Also commit on Enter (`enterkeyhint="done"` or `"enter"`) and on blur for valid text. Show an explicit "Add" button on touch devices.
- Chips wrap and the field grows. Cap the height with internal vertical scroll only for very large sets, and keep the input visible.
- Remove buttons need ≥44 px touch area on touch. Use a padded hit area around a small icon.
- For long tag lists in narrow layouts, collapse to "+N more" with a disclosure.
- `inputmode="email"` and `autocapitalize="off"` for recipients, `autocapitalize="none"` for tags.

## Performance
- Tokenization and validation are cheap. The cost is rendering hundreds of chips, so collapse or virtualize beyond about 100.
- Use stable keys (normalized value or id), not array index, to avoid focus bugs and re-mounts.
- Debounce and abort suggestion fetches (see `search-and-autocomplete`).
- Paste of thousands of tokens: process in one state update and cap with a message.

## Security
- Render token text as text, never HTML (user-pasted content).
- Enforce limits (count, length, charset) on the server as well. Client caps are UX only.
- Recipient fields: don't reveal whether an address exists in the system through suggestion behavior (user enumeration). Scope contact suggestions to the user.
- Normalize Unicode (NFC) and consider confusable characters for tags used in URLs or slugs.

## Testing
- Unit: the tokenizer (delimiters, trimming, de-dup, max, Unicode) and validators.
- Component (Testing Library + user-event): typing "a,b{Enter}" creates 2 chips. Backspace on an empty input focuses and then removes. Focus moves correctly after removal. Remove button names include the value. FormData contains all values. Invalid email chip shows text error.
- Paste test: `user.paste('a@x.com; b@y.com\nbad')` → 2 valid, 1 invalid.
- A11y: axe, plus a manual screen reader pass for announcements.
- E2E: mobile viewport keyboard flow and form submit payload.

## Tooling
| Tool | Notes (Sept 2026) |
|---|---|
| React Aria Components `TagGroup` | Label + TagList + Tag with `slot="remove"` button; `onRemove(keys: Set<Key>)`, `selectionMode`, pairs with `useListData` |
| React Aria `ComboBox selectionMode="multiple"` | Multi-select from list; combine with TagGroup for display |
| Base UI `Combobox` (`multiple`, `Chips`, `Chip`) | Integrated chips in combobox input |
| Downshift `useTagGroup` + `useCombobox` | Headless hooks for tag groups and combobox |
| Mantine `TagsInput`/`MultiSelect`, MUI `Autocomplete multiple freeSolo`, Chakra/Ark `TagsInput` | Batteries-included options |
| Zod v4 / Valibot | Array schemas, per-item validation, uniqueness refinement |

## Framework Notes
- **React (Vite SPA)**:
  - With React Hook Form, register the field through `Controller` (value `string[]`). Use `useFieldArray` only when each token carries extra fields (e.g., role per recipient).
  - Array errors can live at `errors.to.message`, `errors.to.root.message`, or per index `errors.to[i].message`, so surface the first one found.
  - Submit JSON to your API and validate again on the server with the same schema module.
- **Next.js App Router**:
  - The tags field is a Client Component. In a Server Action form, it renders one hidden input per token, and the action reads `formData.getAll('to')` and validates with the shared Zod schema.
  - `useActionState` returns field errors plus the submitted values, so the field can be re-seeded after an error.
  - React 19 resets uncontrolled native inputs after a successful action, but component state (the chip list) is not reset. Remount with a `key` returned by the action (e.g., `resetKey`).
- Both strategies share `lib/schemas/*.ts` and `lib/tokenize.ts`. The server never trusts client tokenization or limits.

## AI Agent Guidance
- Do: clarify value rules (free/closed, max, format, uniqueness) before building.
- Do: use an accessible primitive (TagGroup, Downshift `useTagGroup`, Material chip grid) instead of hand-rolled spans.
- Do: implement paste splitting, de-dup feedback, two-step Backspace, focus after removal, hidden inputs or registered arrays.
- Don't: use color-only invalid states, unnamed × buttons, or let Enter submit the form while typing a token.
- Do: make the field work controlled (RHF `Controller`) and uncontrolled with hidden inputs (Server Action). Both paths import one Zod schema, and the action re-validates.
- Verify before done: keyboard-only add/navigate/remove, screen reader announces removal and value names, pasted list works, submitted payload contains the array, and server-side validation mirrors client limits.

## Examples

```tsx
// app/components/tags-field.tsx — React Aria Components; works controlled (RHF) or uncontrolled (Server Action)
'use client';
import {TagGroup, TagList, Tag, Label, Button, TextField, Input, Text, FieldError} from 'react-aria-components';
import {useState} from 'react';
import {tokenize} from '@/lib/tokenize';

type TagsFieldProps = {
  label: string;
  name?: string;                   // set for Server Actions → one hidden input per token
  max?: number;
  value?: string[];                // set for controlled use (RHF)
  defaultValue?: string[];
  onChange?: (next: string[]) => void;
  onBlur?: () => void;
  errorMessage?: string;
};

export function TagsField({label, name, max = 10, value, defaultValue = [], onChange, onBlur, errorMessage}: TagsFieldProps) {
  const [inner, setInner] = useState<string[]>(defaultValue);
  const tags = value ?? inner;
  const setTags = (next: string[]) => { if (value === undefined) setInner(next); onChange?.(next); };
  const [draft, setDraft] = useState('');
  const [status, setStatus] = useState('');

  const commit = (raw: string) => {
    const {added, duplicates} = tokenize(raw, tags, {max});
    if (added.length) setTags([...tags, ...added]);
    setDraft('');
    setStatus([added.length ? `${added.join(', ')} added` : '', duplicates.length ? `${duplicates.join(', ')} already added` : ''].filter(Boolean).join('. '));
  };

  return (
    <div>
      <TextField value={draft} onChange={setDraft} isInvalid={Boolean(errorMessage)}>
        <Label>{label}</Label>
        <Input
          enterKeyHint="done"
          onKeyDown={(e) => {
            if ((e.key === 'Enter' || e.key === ',') && draft.trim()) { e.preventDefault(); commit(draft); }
            if (e.key === 'Enter' && !draft.trim()) e.preventDefault(); // don't submit mid-entry; use the submit button
          }}
          onPaste={(e) => { e.preventDefault(); commit(e.clipboardData.getData('text')); }}
          onBlur={() => { if (draft.trim()) commit(draft); onBlur?.(); }}
        />
        <Text slot="description">Separate with commas or press Enter. Up to {max}.</Text>
        <FieldError>{errorMessage}</FieldError>
      </TextField>
      <TagGroup
        aria-label={`Selected ${label.toLowerCase()}`}
        onRemove={(keys) => { setTags(tags.filter((t) => !keys.has(t))); setStatus(`${[...keys].join(', ')} removed`); }}
      >
        <TagList items={tags.map((id) => ({id}))} renderEmptyState={() => 'None added yet'}>
          {(item) => (
            <Tag id={item.id} textValue={item.id}>
              {item.id}
              <Button slot="remove" aria-label={`Remove ${item.id}`}>×</Button>
            </Tag>
          )}
        </TagList>
      </TagGroup>
      {name && tags.map((t) => <input key={t} type="hidden" name={name} value={t} />)}
      <div role="status" className="sr-only">{status}</div>
    </div>
  );
}
```

```tsx
// lib/schemas/invite.ts — ONE schema imported by the RHF form and the Server Action (Zod v4)
import {z} from 'zod';

export const InviteSchema = z.object({
  to: z.array(z.email({error: 'Enter valid email addresses only'}))
    .min(1, {error: 'Add at least one recipient'})
    .max(50, {error: 'Add up to 50 recipients'})
    .refine((a) => new Set(a.map((s) => s.toLowerCase())).size === a.length, {error: 'Remove duplicate recipients'}),
});
export type Invite = z.infer<typeof InviteSchema>;
```

```tsx
// app/invite/actions.ts — server re-validates regardless of which form called it
'use server';
import {z} from 'zod';
import {InviteSchema} from '@/lib/schemas/invite';

export type InviteState = {status: 'idle' | 'error' | 'success'; errors?: {to?: string[]}; values?: {to: string[]}; resetKey?: number};

export async function sendInvites(prev: InviteState, formData: FormData): Promise<InviteState> {
  const raw = {to: formData.getAll('to').map(String)};
  const parsed = InviteSchema.safeParse(raw);
  if (!parsed.success) {
    return {status: 'error', errors: z.flattenError(parsed.error).fieldErrors, values: raw, resetKey: prev.resetKey};
  }
  // Authorize the caller, rate-limit, then send invites for parsed.data.to
  return {status: 'success', values: {to: []}, resetKey: (prev.resetKey ?? 0) + 1};
}
```

```tsx
// A) Server Action + useActionState/useFormStatus — app/invite/invite-form-action.tsx
'use client';
import {useActionState} from 'react';
import {useFormStatus} from 'react-dom';
import {sendInvites, type InviteState} from './actions';
import {TagsField} from '@/app/components/tags-field';

function SubmitButton() {
  const {pending} = useFormStatus();
  return <button type="submit" disabled={pending}>{pending ? 'Sending…' : 'Send invites'}</button>;
}

export function InviteFormAction() {
  const [state, formAction] = useActionState<InviteState, FormData>(sendInvites, {status: 'idle'});
  return (
    <form action={formAction} noValidate>
      {/* key remounts to clear chips after success; values re-seed chips after a validation error */}
      <TagsField
        key={state.resetKey ?? 0}
        label="Recipients"
        name="to"
        max={50}
        defaultValue={state.values?.to ?? []}
        errorMessage={state.errors?.to?.[0]}
      />
      <SubmitButton />
      <p role="status">{state.status === 'success' ? 'Invites sent' : ''}</p>
    </form>
  );
}
```

```tsx
// B) Client-side React Hook Form + zodResolver — app/invite/invite-form-client.tsx
'use client';
import {Controller, useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {InviteSchema, type Invite} from '@/lib/schemas/invite';
import {TagsField} from '@/app/components/tags-field';
import {sendInvites} from './actions';

// Array errors may sit at .message, .root.message, or per index; return the first one
function firstMessage(err: unknown): string | undefined {
  if (!err || typeof err !== 'object') return undefined;
  const e = err as {message?: unknown; root?: {message?: unknown}};
  if (typeof e.message === 'string') return e.message;
  if (typeof e.root?.message === 'string') return e.root.message;
  for (const [k, v] of Object.entries(err)) {
    if (k === 'ref') continue;
    const m = firstMessage(v);
    if (m) return m;
  }
  return undefined;
}

export function InviteFormClient() {
  const {control, handleSubmit, reset, setError, formState: {errors, isSubmitting, isSubmitSuccessful}} = useForm<Invite>({
    resolver: zodResolver(InviteSchema),
    defaultValues: {to: []},
    mode: 'onTouched',
  });

  const onSubmit = async (data: Invite) => {
    const fd = new FormData();
    data.to.forEach((t) => fd.append('to', t));
    const res = await sendInvites({status: 'idle'}, fd); // server validates again
    if (res.status === 'error') setError('to', {message: res.errors?.to?.[0] ?? 'Could not send invites'});
    else reset({to: []});
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <Controller
        control={control}
        name="to"
        render={({field}) => (
          <TagsField label="Recipients" max={50} value={field.value} onChange={field.onChange} onBlur={field.onBlur} errorMessage={firstMessage(errors.to)} />
        )}
      />
      <button type="submit" disabled={isSubmitting}>{isSubmitting ? 'Sending…' : 'Send invites'}</button>
      <p role="status">{isSubmitSuccessful && !errors.to ? 'Invites sent' : ''}</p>
    </form>
  );
}
```

## Related Skills
- [select-and-combobox](../select-and-combobox/Skill.md) — multi-select combobox foundation
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — suggestion fetching and announcements
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — applied-filter chips and toggle chips
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) — better for short closed sets
- [form-validation-patterns](../form-validation-patterns/Skill.md) — per-item and field-level errors
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — array field wiring
- [focus-management](../focus-management/Skill.md) — focus after removal
- [keyboard-navigation](../keyboard-navigation/Skill.md) — roving tabindex
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md) — TagGroup implementation
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — remove-button target size
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — `formData.getAll` and server re-validation
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — `useActionState`/`useFormStatus`, post-action reset

## Sources
- [React Aria TagGroup](https://react-aria.adobe.com/TagGroup) — Open Source — anatomy, `onRemove`, `selectionMode`, `useListData`
- [React Aria ComboBox](https://react-aria.adobe.com/ComboBox) — Open Source — `selectionMode="multiple"`, `allowsCustomValue`
- [Base UI Combobox](https://base-ui.com/react/components/combobox) — Open Source — `multiple`, `Chips`/`Chip` parts
- [Downshift](https://github.com/downshift-js/downshift) — Open Source — `useTagGroup`, `useCombobox`
- [WAI-ARIA APG: Combobox](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/) and [Listbox](https://www.w3.org/WAI/ARIA/apg/patterns/listbox/) — Official — semantics for the suggestion popup and multi-select keys
- [Baymard: Applied filters overview](https://baymard.com/blog/how-to-design-applied-filters) — Community (research) — removable filter chips, clear all

## License / Usage Notes
Summarized from W3C (W3C Document License), Adobe React Aria (Apache-2.0), Base UI and Downshift (MIT), and Baymard (copyrighted research, paraphrased). Keyboard conventions combine the APG grid and listbox guidance with common library behavior. They are not a single normative spec. Code is original.

## Quality Tier
B — Solid, practical guidance, but there is no dedicated APG "tag input" pattern, so keyboard conventions are synthesized from library behavior. The TagGroup's exact ARIA role output was not confirmed from docs.

## Status
Active

## Last Verified
2026-09-15
