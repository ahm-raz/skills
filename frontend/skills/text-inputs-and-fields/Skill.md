# Text Inputs and Fields

## Summary
How to build single-line and multi-line text fields in React/Next.js as a complete "field": label, hint, input, prefix/suffix, character count, and error message, wired correctly for assistive tech, autofill, and mobile keyboards. Covers `type`, `inputMode`, `enterKeyHint`, `autoComplete`, `autoCapitalize`, `spellCheck`, width sizing, auto-growing textareas, password fields, and binding one `Field` component to both React Hook Form + Zod and Server Actions with `useActionState`.

## Category
Components

## Subcategories
text input, textarea, field anatomy, labels, hints, error messages, autocomplete, inputmode, enterkeyhint, password field, character count, prefix/suffix

## Problem It Solves
Text fields look trivial but break all the time: placeholder used as the label, wrong mobile keyboard, autofill that doesn't work, errors that aren't announced, hints that aren't linked to the input, widths that suggest the wrong length, iOS zooming on focus, `type="number"` used for codes, and React 19 Server Action forms that wipe the user's input after a validation error. One consistent `Field` component fixes these in a single place.

## When To Use
- Building a design-system `TextField` / `Textarea` / `Field` component.
- Any form collecting names, emails, phone numbers, addresses, or free text.
- Auditing forms against WCAG 1.3.1, 1.3.5, 3.3.1, 3.3.2, 4.1.2.

## When Not To Use
- Quantities, prices, percentages: [number-and-currency-inputs](../number-and-currency-inputs/Skill.md).
- Picking from a known list: [select-and-combobox](../select-and-combobox/Skill.md).
- Sign-in, password, and OTP flows: [otp-and-auth-forms](../otp-and-auth-forms/Skill.md). This skill only covers the password field itself.
- Search with suggestions: [search-and-autocomplete](../search-and-autocomplete/Skill.md).
- Formatted content: [rich-text-editors](../rich-text-editors/Skill.md).

## Core Principles
1. Every input has a visible, persistent `<label>` linked through `htmlFor`/`id`.
2. Hints and errors are linked with `aria-describedby`, and an error also sets `aria-invalid`.
3. The right `type` + `inputMode` + `autoComplete` gives the right keyboard and autofill. Work with the browser, not against it.
4. Field width signals how long the answer should be.
5. Placeholder text is never the label and never the only place a hint lives.
6. Don't block paste or autofill.
7. The value is text. Normalize leniently (trim, collapse spaces) and validate with one shared Zod schema on client and server.

## Best Practices
- Put labels above inputs: fast to scan, works on mobile, and leaves room for longer translations.
- When most fields are required, mark optional ones "(optional)" instead of starring required ones (GOV.UK, Adam Silver). Whichever you choose, be consistent.
- Hint text: one short sentence between the label and the input, with no links.
- Size inputs to the expected content (postcode ~10ch, CVV ~4ch) using `ch` widths. Use full width for free text.
- Use at least 16px font on mobile (`text-base`) so iOS Safari doesn't zoom on focus.
- Add `autoComplete` tokens to every personal-data field (WCAG 1.3.5): `name`, `email`, `tel`, `street-address`, `address-line1`, `postal-code`, `country-name`, `bday`, `organization`.
- For emails, usernames, and codes, set `spellCheck={false}` and `autoCapitalize="none"`. Don't force capitalization on names.
- Use `enterKeyHint` (`next`, `go`, `search`, `send`, `done`) to label the mobile Enter key.
- Prefer one "Full name" field over first/last unless a downstream system really needs parts.
- Show-password toggle: `type="button"` that switches `type` between `password` and `text`. No confirm-password field.
- Character count: show what's left, announce politely after typing pauses, and let users go over the limit with an error instead of silently cutting text.
- Textarea: sensible `rows`, vertical resize, auto-grow with `field-sizing: content` (Chromium and Safari 26; progressive enhancement) and a `max-height`.
- `readOnly` values are focusable and submitted; `disabled` values are skipped and not submitted.

## Implementation Guidance

### Keyboard and autofill decision table
| Data | `type` | `inputMode` | `autoComplete` | Extras |
|---|---|---|---|---|
| Email | `email` | (implied) | `email` (or `username` on auth) | `spellCheck={false}` `autoCapitalize="none"` |
| Phone | `tel` | (implied) | `tel` / `tel-national` | Accept spaces, dashes, `+` |
| URL | `url` | (implied) | `url` | |
| Digit identifier (account no.) | `text` | `numeric` | as appropriate | never `type="number"` |
| Postcode / ZIP | `text` | `text` (UK) / `numeric` (US ZIP) | `postal-code` | `ch` width |
| Search | `search` | (implied) | `off` | `enterKeyHint="search"` |
| Name | `text` | | `name` | `spellCheck={false}` |
| Password (sign in) | `password` | | `current-password` | show toggle |
| Password (new) | `password` | | `new-password` | |
| One-time code | `text` | `numeric` | `one-time-code` | see OTP skill |

Why not `type="number"` for identifiers: it strips leading zeros, accepts `e`, the scroll wheel changes the value, and spinners appear (GOV.UK advice).

### Field anatomy (IDs are the contract)
```
Field
├─ <label htmlFor={id}>Label (optional)</label>
├─ <div id={`${id}-hint`}>Hint</div>
├─ <p id={`${id}-error`}>Error: message</p>          ← only when invalid
├─ control: [prefix aria-hidden] <input id={id} aria-describedby="hint error" aria-invalid> [suffix aria-hidden]
└─ <div id={`${id}-count`} aria-live="polite">Character count</div>
```
Add a visually hidden "Error:" prefix so screen readers can tell errors from hints. If a prefix/suffix carries meaning ("per month"), put that meaning in the label or hint too.

### Validation timing with the two form stacks
| Stack | Timing | How |
|---|---|---|
| React Hook Form + Zod | Validate on first blur, then on every change once an error shows (reward early, punish late) | `mode: 'onTouched'` (default `reValidateMode: 'onChange'`), `zodResolver(schema)` |
| Server Action + `useActionState` | Validate on submit (server), render returned field errors | `schema.safeParse` in the action → `z.flattenError(error).fieldErrors` |

Both import the **same** schema module, and the server always runs `safeParse` again. Style errors with `aria-[invalid=true]:` (or `:user-invalid`), not `:invalid`, which fires before the user has typed anything. More detail in [form-validation-patterns](../form-validation-patterns/Skill.md).

### React 19 form reset gotcha
After a `<form action>` finishes, React resets uncontrolled fields. If you return validation errors, also return the submitted `values` (never passwords) and set `defaultValue={state.values?.email}`. Otherwise the user's input disappears.

## Recommended Workflow
1. List the fields. For each, note the data type, required/optional, expected length, and autofill token.
2. Pick `type` / `inputMode` / `autoComplete` / `enterKeyHint` from the table.
3. Write labels, hints, and specific error messages ("Enter an email address in the correct format, like name@example.com").
4. Put the rules in one Zod schema file with no `'use server'` / `'use client'` directive, importable from both sides.
5. Build one `TextField` that generates IDs with `useId` and wires `aria-describedby` / `aria-invalid`. It accepts `ref` (React 19) so RHF `register` works.
6. Wire the form both ways as needed: RHF + `zodResolver`, or Server Action + `useActionState` returning `fieldErrors` and `values`.
7. Apply widths, the 16px mobile font, a focus ring, and error styling that isn't only color (text + icon + border).
8. Test autofill in Chrome/Safari/Firefox, keyboards on iOS/Android, screen reader announcements, and submitting with JS disabled on the Server Action form.

## Patterns
- **Field compound component**: `<Field><Label/><Description/><Input/><FieldError/></Field>` (React Aria `TextField`, Base UI `Field`, shadcn/ui `Field`). Context wires the IDs.
- **Server-error adapter**: `setError(name, { message })` in RHF for each server `fieldErrors` entry, so both stacks show errors the same way.
- **Password with reveal**: input + `type="button"` toggle with `aria-pressed`; hide the password again after submit.
- **Character count**: a counter with `aria-live="polite"`, updated with a debounce; or show the counter only near the limit.
- **Prefix/suffix**: adornments are `aria-hidden`, and the label says the unit ("Cost, in pounds").
- **Auto-grow textarea**: `className="[field-sizing:content] min-h-[3lh] max-h-[12lh]"`.
- **Clearable input**: clear button `type="button" aria-label="Clear search"` that returns focus to the input.
- **Floating label**: only if the label stays visible (shrinks) and there's no placeholder. Static labels above are safer.

## Anti-Patterns
- **Placeholder as label**: vanishes while typing, low contrast. Fix: a real `<label>`.
- **Label not associated** (`<label>Email</label><input/>`). Fix: `htmlFor` + `id` from `useId`.
- **Error shown only as a red border**: fails SC 1.4.1 / 3.3.1. Fix: text + `aria-invalid` + `aria-describedby`.
- **`autoComplete="off"` on personal data**: breaks autofill and SC 1.3.5. Fix: the right tokens.
- **Blocking paste** (`onPaste={e => e.preventDefault()}`): fails SC 3.3.8 on auth forms and frustrates everyone. Fix: allow paste.
- **Input masks that grab the caret**: break editing, paste, and screen readers. Fix: accept free-form input and format on blur.
- **`maxLength` silently truncating pasted text**. Fix: allow going over, show a counter and an error.
- **Controlled inputs re-rendering the whole form on every keystroke**. Fix: RHF `register` (uncontrolled) or keep state local.
- **Server Action form losing values on error**. Fix: return `values` and use `defaultValue`.
- **Validation only on the client**. Fix: `safeParse` the same schema in the action/API.
- **14px inputs on iOS**: page zooms. Fix: 16px.

## Accessibility
- SC 1.3.1: label, hint, and error associations. SC 1.3.5: valid `autoComplete` tokens.
- SC 2.5.3 Label in Name; SC 3.3.1 Error Identification; SC 3.3.2 Labels or Instructions; SC 3.3.3 Error Suggestion.
- SC 3.3.7 Redundant Entry (WCAG 2.2): don't ask for information already given in the same process; pre-fill it or offer it for selection.
- SC 4.1.2: `aria-invalid`, `required` / `aria-required`.
- Input borders and focus rings need 3:1 contrast (SC 1.4.11).
- `aria-describedby` order: hint, then error. Keep both short, since they're read on every focus.
- `aria-errormessage` support is still inconsistent; always use `aria-describedby` as well.
- After a failed submit, move focus to the first invalid field (RHF `shouldFocusError` does this by default) or to an error summary.

## Responsive Design
- Keep labels above inputs at every breakpoint.
- Fixed-width inputs: `max-w-full` so they never overflow.
- Use `scroll-margin-block` so focused fields aren't hidden behind sticky headers. Set `interactiveWidget: 'resizes-content'` in Next.js `export const viewport` so layouts adapt when the keyboard opens (Chromium).
- Use logical properties for prefix/suffix placement in RTL layouts. See [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md).

## Performance
- RHF registers uncontrolled inputs through refs, so typing doesn't re-render the form. Use `useWatch` only where needed.
- Debounce async checks (e.g., username availability) by 300–500ms and cancel stale ones with `AbortController`.
- Server Action forms don't need client JS to submit, so keep the form component small and push logic into the action.

## Security
- Treat every value as untrusted. React escapes output; never use `dangerouslySetInnerHTML` with field values.
- `required`, `pattern`, and `maxLength` in the browser are only UX. Validate on the server with the shared schema.
- Server Actions are public endpoints: authenticate, authorize, and validate in each one.
- Don't send raw values (PII, passwords) to analytics, error trackers, or session replay; mask inputs.
- Never echo passwords back in `useActionState` state.

## Testing
- Testing Library: `getByLabelText('Email address')`, `toHaveAccessibleDescription(/format/)`, `toBeInvalid()`.
- Assert `type`, `inputMode`, `autoComplete` in component tests; it's a cheap regression guard.
- Schema unit tests: table-driven valid/invalid inputs on the shared schema, which covers both stacks.
- Server Action tests: call the action with a built `FormData`; assert `fieldErrors` and that `values` excludes secrets.
- Playwright: submit invalid → error visible and focused; fix → error clears; run once with JavaScript disabled for the Server Action form.
- Autofill and mobile keyboards: manual check on real devices.
- axe: `label`, `autocomplete-valid`, `aria-valid-attr-value`, `color-contrast`.

## Tooling
- React Hook Form v7 + `@hookform/resolvers` (`zodResolver` supports Zod 4). Active.
- Zod 4 (`z.email()`, `z.flattenError`, string-shorthand error messages). Active.
- React Aria `TextField` / `Input` / `TextArea` / `FieldError`. Active.
- Base UI `Field`, `Input`, `Fieldset`, `Form` (`@base-ui/react` v1.x). Active.
- shadcn/ui `Input`, `Textarea`, `Field`, `InputGroup`. Active.
- `libphonenumber-js` for parsing phone numbers (client and server). Active.
- Input masks: prefer none. If you must, use `react-imask` and test paste and screen readers.

## Framework Notes
- **React (Vite SPA)**: React Hook Form + `zodResolver` in the browser; submit to your API (fetch or TanStack Query mutation). The API imports the same schema (monorepo shared package) and returns `{ fieldErrors }` in the same shape, mapped with `setError`. Generate IDs with `useId`. No SSR, so autofill works as soon as the bundle renders; keep the form in the initial chunk for login and checkout.
- **Next.js (App Router)**: the schema lives in a plain module (e.g., `app/contact/schema.ts`). `actions.ts` has `'use server'` and only exports async functions (type exports are fine). Passing `useActionState`'s `formAction` to `<form action>` works before hydration. Return `values` for re-render because of React 19 form reset. For RHF in Next.js, call the Server Action as a typed async function inside `handleSubmit`, and the action runs `safeParse` again. `useFormStatus` gives pending state in a child submit button.

## AI Agent Guidance
- Do: build one `TextField` with `useId`; add `autoComplete` to every personal-data field; pick `type` / `inputMode` / `enterKeyHint` from the table; link hint and error with `aria-describedby`; use one shared Zod schema and `safeParse` it on the server; return `values` from Server Actions; use 16px mobile font.
- Don't: use placeholder as label, `type="number"` for codes or phones, `autoComplete="off"` on personal fields, block paste, add confirm fields, validate only on the client, or echo passwords.
- Verify before done: every input has an accessible name (axe); invalid submit shows text errors, sets `aria-invalid`, and focuses the first error; values survive a failed Server Action submit; the server rejects invalid payloads sent directly; attributes are in the rendered HTML.

## Examples
```tsx
// components/ui/text-field.tsx — works with RHF register (ref as prop in React 19) and plain forms
import { useId } from 'react';

type TextFieldProps = React.ComponentProps<'input'> & {
  label: string;
  hint?: string;
  error?: string;
  optional?: boolean;
};

export function TextField({ label, hint, error, optional, className = '', id: idProp, ...input }: TextFieldProps) {
  const autoId = useId();
  const id = idProp ?? autoId;
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  return (
    <div className="grid gap-1">
      <label htmlFor={id} className="font-medium">
        {label}{optional && <span className="font-normal"> (optional)</span>}
      </label>
      {hint && <div id={hintId} className="text-gray-700">{hint}</div>}
      {error && (
        <p id={errorId} className="font-medium text-red-700">
          <span className="sr-only">Error: </span>{error}
        </p>
      )}
      <input
        id={id}
        aria-describedby={[hintId, errorId].filter(Boolean).join(' ') || undefined}
        aria-invalid={error ? true : undefined}
        aria-required={optional ? undefined : true}
        className={`min-h-11 max-w-full rounded border-2 border-gray-700 px-3 text-base
          focus-visible:outline-3 focus-visible:outline-offset-1 aria-[invalid=true]:border-red-700 ${className}`}
        {...input}
      />
    </div>
  );
}
```

```tsx
// app/contact/schema.ts — shared by the RHF client and the Server Action
import { z } from 'zod';

export const contactSchema = z.object({
  fullName: z.string().trim().min(1, 'Enter your full name').max(200, 'Name must be 200 characters or fewer'),
  email: z.email('Enter an email address in the correct format, like name@example.com'),
  phone: z
    .string()
    .trim()
    .regex(/^\+?[0-9 ()-]{7,20}$/, 'Enter a telephone number, like 01632 960 001 or +44 808 157 0192')
    .optional()
    .or(z.literal('')),
  message: z.string().trim().min(1, 'Enter your message').max(1000, 'Message must be 1000 characters or fewer'),
});

export type ContactInput = z.infer<typeof contactSchema>;
export type ContactState = {
  ok: boolean;
  message?: string;
  errors?: Partial<Record<keyof ContactInput, string[]>>;
  values?: Partial<Record<keyof ContactInput, string>>;
};
```

```tsx
// app/contact/actions.ts
'use server';
import { z } from 'zod';
import { contactSchema, type ContactInput, type ContactState } from './schema';
import { saveEnquiry } from '@/lib/server/enquiries';

async function handle(input: unknown): Promise<ContactState> {
  const parsed = contactSchema.safeParse(input);                 // server ALWAYS re-validates
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  await saveEnquiry(parsed.data);
  return { ok: true, message: 'Thanks, we will reply within 2 working days' };
}

export async function submitContact(_prev: ContactState, formData: FormData): Promise<ContactState> {
  const values = {
    fullName: String(formData.get('fullName') ?? ''),
    email: String(formData.get('email') ?? ''),
    phone: String(formData.get('phone') ?? ''),
    message: String(formData.get('message') ?? ''),
  };
  const result = await handle(values);
  return result.ok ? result : { ...result, values };             // keep input after React 19 form reset
}

export async function saveContact(input: ContactInput): Promise<ContactState> {
  return handle(input);
}
```

```tsx
// app/contact/contact-form-action.tsx — Server Action + useActionState + useFormStatus
'use client';
import { useActionState } from 'react';
import { submitContact } from './actions';
import type { ContactState } from './schema';
import { TextField } from '@/components/ui/text-field';
import { SubmitButton } from '@/components/ui/submit-button';

export function ContactFormAction() {
  const [state, formAction] = useActionState<ContactState, FormData>(submitContact, { ok: false });
  const e = state.errors;
  return (
    <form action={formAction} noValidate className="grid max-w-prose gap-6">
      <TextField label="Full name" name="fullName" autoComplete="name" spellCheck={false}
        defaultValue={state.values?.fullName} error={e?.fullName?.[0]} enterKeyHint="next" />
      <TextField label="Email address" name="email" type="email" autoComplete="email"
        spellCheck={false} autoCapitalize="none" defaultValue={state.values?.email} error={e?.email?.[0]} />
      <TextField label="Phone number" name="phone" type="tel" autoComplete="tel" optional
        hint="For international numbers include the country code" defaultValue={state.values?.phone}
        error={e?.phone?.[0]} className="w-[20ch]" />
      <div className="grid gap-1">
        <label htmlFor="message" className="font-medium">Your message</label>
        {e?.message?.[0] && <p id="message-error" className="text-red-700"><span className="sr-only">Error: </span>{e.message[0]}</p>}
        <textarea id="message" name="message" rows={5} defaultValue={state.values?.message}
          aria-invalid={e?.message ? true : undefined} aria-describedby={e?.message ? 'message-error' : undefined}
          className="[field-sizing:content] min-h-[5lh] max-h-[15lh] rounded border-2 border-gray-700 p-3 text-base" />
      </div>
      <SubmitButton pendingLabel="Sending…">Send message</SubmitButton>
      <p role="status">{state.ok ? state.message : ''}</p>
    </form>
  );
}
```

```tsx
// app/contact/contact-form-rhf.tsx — React Hook Form + Zod, same schema, server re-validates
'use client';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { contactSchema, type ContactInput } from './schema';
import { saveContact } from './actions';
import { TextField } from '@/components/ui/text-field';
import { Button } from '@/components/ui/button';

export function ContactFormRHF() {
  const [status, setStatus] = useState('');
  const { register, handleSubmit, setError, reset, formState: { errors, isSubmitting } } = useForm<ContactInput>({
    resolver: zodResolver(contactSchema),
    mode: 'onTouched',                       // first check on blur, then live while fixing
    defaultValues: { fullName: '', email: '', phone: '', message: '' },
  });

  const onSubmit = handleSubmit(async (values) => {
    const res = await saveContact(values);
    if (!res.ok) {
      for (const [field, msgs] of Object.entries(res.errors ?? {})) {
        if (msgs?.[0]) setError(field as keyof ContactInput, { message: msgs[0] });
      }
      return;
    }
    reset();
    setStatus(res.message ?? 'Sent');
  });

  return (
    <form onSubmit={onSubmit} noValidate className="grid max-w-prose gap-6">
      <TextField label="Full name" autoComplete="name" spellCheck={false} {...register('fullName')}
        error={errors.fullName?.message} />
      <TextField label="Email address" type="email" autoComplete="email" spellCheck={false}
        autoCapitalize="none" {...register('email')} error={errors.email?.message} />
      <TextField label="Phone number" type="tel" autoComplete="tel" optional
        hint="For international numbers include the country code" {...register('phone')}
        error={errors.phone?.message} className="w-[20ch]" />
      <div className="grid gap-1">
        <label htmlFor="rhf-message" className="font-medium">Your message</label>
        {errors.message && <p id="rhf-message-error" className="text-red-700">{errors.message.message}</p>}
        <textarea id="rhf-message" rows={5} {...register('message')}
          aria-invalid={errors.message ? true : undefined}
          aria-describedby={errors.message ? 'rhf-message-error' : undefined}
          className="[field-sizing:content] min-h-[5lh] max-h-[15lh] rounded border-2 border-gray-700 p-3 text-base" />
      </div>
      <Button type="submit" pending={isSubmitting}>{isSubmitting ? 'Sending…' : 'Send message'}</Button>
      <p role="status">{status}</p>
    </form>
  );
}
```

```tsx
// components/ui/password-field.tsx — reveal toggle that never submits the form
'use client';
import { useId, useState } from 'react';

export function PasswordField({ label = 'Password', autoComplete = 'current-password', error, ...input }:
  React.ComponentProps<'input'> & { label?: string; error?: string }) {
  const id = useId();
  const [visible, setVisible] = useState(false);
  return (
    <div className="grid gap-1">
      <label htmlFor={id}>{label}</label>
      {error && <p id={`${id}-error`} className="text-red-700">{error}</p>}
      <div className="flex gap-2">
        <input id={id} type={visible ? 'text' : 'password'} autoComplete={autoComplete}
          aria-invalid={error ? true : undefined} aria-describedby={error ? `${id}-error` : undefined}
          className="min-h-11 flex-1 rounded border-2 px-3 text-base" {...input} />
        <button type="button" aria-controls={id} aria-pressed={visible} onClick={() => setVisible((v) => !v)}>
          Show password
        </button>
      </div>
    </div>
  );
}
```

## Related Skills
- [form-design-ux](../form-design-ux/Skill.md) — layout, labels, question design
- [form-validation-patterns](../form-validation-patterns/Skill.md) — timing and error summaries
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — deep RHF/Zod integration
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action security and patterns
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState and form reset
- [progressive-enhancement](../progressive-enhancement/Skill.md) — forms without JS
- [accessible-forms](../accessible-forms/Skill.md) — WCAG form requirements in depth
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md) — numeric fields
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md) — sign-in, password, OTP flows
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — wording for labels, hints, errors

## Sources
- [GOV.UK Design System: Text input](https://design-system.service.gov.uk/components/text-input/) — Official — widths, numeric input, prefixes/suffixes, placeholder advice
- [MDN: autocomplete attribute](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/autocomplete) — Official — tokens and grouping
- [MDN: inputmode](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inputmode) and [enterkeyhint](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/enterkeyhint) — Official — mobile keyboards
- [web.dev: Sign-in form best practices](https://web.dev/articles/sign-in-form-best-practices) — Official — labels, password reveal, font size
- [WCAG 2.2 Understanding](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — SC 1.3.5, 3.3.1–3.3.3, 3.3.7
- [React Hook Form docs](https://react-hook-form.com/docs/useform) — Open Source — modes, setError, shouldFocusError
- [Zod 4 docs: error formatting](https://zod.dev/error-formatting) — Open Source — flattenError, error params
- [Next.js docs: Forms](https://nextjs.org/docs/app/guides/forms) — Official — Server Action validation, useActionState
- [React Aria TextField](https://react-aria.adobe.com/TextField) / [Base UI Field](https://base-ui.com/react/components/field) — Open Source — field composition
- Adam Silver, *Form Design Patterns* — Community — label/hint placement, marking optional fields

## License / Usage Notes
Summarized from W3C, MDN (CC-BY-SA), GOV.UK (MIT/OGL), React/Next.js docs, and library docs; all examples are original. React Hook Form (MIT), Zod (MIT), React Aria (Apache-2.0), Base UI (MIT), libphonenumber-js (MIT).

## Quality Tier
A — standards- and GOV.UK-grounded with complete RHF and Server Action wiring; `field-sizing` and `interactive-widget` support is uneven and marked as progressive enhancement.

## Status
Active

## Last Verified
2026-09-15
