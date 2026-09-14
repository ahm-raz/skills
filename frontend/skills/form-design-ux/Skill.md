# Form Design UX

## Summary
Evidence-based rules for designing forms people can finish quickly and correctly: what to ask, how to lay it out, how to label and explain fields, and how to recover from mistakes. This skill combines GOV.UK Design System patterns, Adam Silver's *Form Design Patterns*, Baymard Institute checkout research and Nielsen Norman Group form guidelines. Every rule is applied through React and Next.js (App Router) components in TypeScript.

## Category
Components

## Subcategories
Form layout, labels and hints, field sizing, required/optional marking, error recovery, form copy, autofill, mobile forms

## Problem It Solves
Forms are where conversion, data quality and accessibility most often fail. Common causes include:
- placeholder-only labels
- multi-column layouts that people misread
- unnecessary fields
- errors that appear too early or hide in tooltips
- disabled submit buttons with no explanation
- mobile keyboards that don't match the field

Following these rules reduces abandonment, support contacts and bad data.

## When To Use
- Designing or reviewing any form in a React or Next.js app: sign-up, checkout, settings, lead capture, admin create/edit screens
- Converting a design mock into components, where labels, hints, grouping and button placement must be decided
- Auditing a form with high drop-off or many support tickets
- Writing the copy for labels, hints and error messages

## When Not To Use
- Choosing *when* validation runs and how it is wired: see [form-validation-patterns](../form-validation-patterns/Skill.md)
- Library-level API details: see [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) and [nextjs-server-actions](../nextjs-server-actions/Skill.md)
- Very dense, expert data-entry screens (ERP grids, bulk edit): see [dense-form-screens](../dense-form-screens/Skill.md)
- Deciding whether to split into steps: see [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md)
- Internals of individual controls (combobox, date picker): use the specific component skills

## Core Principles
1. **Question every question.** Each field costs completion. Remove it, defer it, infer it (for example, city from postcode) or make it optional. Baymard's checkout research repeatedly finds too many fields is a leading cause of abandonment.
2. **Visible labels, always.** Every control has a persistent `<label>` (or `<legend>` for groups). A placeholder is never the label.
3. **One column.** Put fields in a single vertical column. Short related pairs (expiry month/year) are the only exception.
4. **Mark the exception.** If most fields are required, mark the optional ones "(optional)". Don't rely on a red asterisk alone.
5. **Size fields to the expected answer.** Field width is a hint. Use the correct `type`, `autoComplete` and `inputMode`.
6. **Explain before, not after.** Put format hints under the label, before the input.
7. **Errors must be findable, specific and fixable.** Show an error summary at the top and an inline message at the field, with identical text.
8. **Don't disable the submit button** to signal invalid state. Let people submit, then tell them what to fix. Disabling only while a submission is pending is fine.
9. **Preserve input.** Never clear what someone typed because of a validation or server error.
10. **Don't ask twice** (WCAG 2.2 SC 3.3.7 Redundant Entry). Pre-fill or offer "same as billing address".
11. **The server decides.** Whether the form is client-rendered with React Hook Form or submitted with a Server Action, one shared Zod schema is validated again on the server.

## Best Practices
- **Labels:** put them above the input. Write short noun phrases or questions. Use sentence case with no trailing colon. In React, generate ids with `useId()`.
- **Hints:** use `aria-describedby`. Keep them to one sentence.
- **Required/optional:** add the `(optional)` text inside the label. If you use an asterisk, explain it at the top and set `required` or `aria-required`.
- **Grouping:** wrap related radios, checkboxes and multi-part inputs in `<fieldset>` + `<legend>`. Use headings for long form sections.
- **Buttons:**
  - Put the primary action left-aligned under the last field.
  - Use a verb label that says what happens ("Create account", "Pay £42.00").
  - Show pending with `useFormStatus` (Server Actions) or `formState.isSubmitting` (RHF).
  - Give secondary actions lower visual weight.
- **Autofill:**
  - Use correct `autoComplete` tokens (`given-name`, `family-name`, `email`, `tel`, `street-address`, `postal-code`, `cc-number`, `one-time-code`, `new-password`, `current-password`). This is required by WCAG 1.3.5.
  - Don't split names unless a downstream system needs parts.
- **Names:** prefer a single "Full name" field. Don't validate names against Latin-only patterns.
- **Phone/address:** accept any reasonable formatting and normalise in the Zod schema (`.transform`) on the server. Offer address lookup with a manual-entry fallback.
- **Dates:** memorable dates (date of birth) use three text inputs with `inputMode="numeric"`. Calendars are for dates chosen relative to now: see [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md).
- **Choices:**
  - Up to ~7 options: radios.
  - Longer lists: a select or combobox.
  - Yes/no questions: two radios when "no" must be explicit.
- **Passwords:** add a show/hide toggle, show the requirements up front, allow paste and password managers, and don't use a confirm field when show/hide exists.
- **Error copy (GOV.UK style):**
  - Be specific: "Enter an email address in the correct format, like name@example.com".
  - Don't blame the user and avoid "please", "oops" and "valid".
  - Put messages in the Zod schema so client and server show the same text.
- **Success:** in Next.js, `redirect()` to a confirmation page after the action, or show a focused `role="status"` message for in-place saves.
- **Length perception:** set expectations up front ("This takes about 5 minutes").

## Implementation Guidance

### Decision table: control choice
| Data | Control | Notes |
|---|---|---|
| Free text, one line | `<input type="text">` | `autoComplete`; `spellCheck={false}` for codes/names |
| Email | `type="email"` | `autoComplete="email"`; validate with `z.email()` on server |
| Phone | `type="tel"` | Never `type="number"` |
| Numeric identifiers (card, account, postcode) | `type="text" inputMode="numeric"` | `type="number"` strips leading zeros and adds a spinner |
| Quantity with small range | `type="number"` or stepper | See [number-and-currency-inputs](../number-and-currency-inputs/Skill.md) |
| 2–7 mutually exclusive options | Radios in fieldset | Stack vertically |
| Many options | `<select>` / combobox | See [select-and-combobox](../select-and-combobox/Skill.md) |
| Binary setting applied instantly | Switch | Not inside a submit-based form: see [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) |
| Consent | Single checkbox | Never pre-ticked for marketing consent |
| Long text | `<textarea>` + character count | Count announces politely and doesn't block typing |

### Two submission architectures (same schema, same markup)
| | Client: React Hook Form + Zod | Next.js: Server Action + `useActionState` |
|---|---|---|
| Works without JS | No | Yes (progressive enhancement) |
| When errors show | Instantly on submit, re-validates on change | After round trip |
| Validation | `zodResolver(schema)` in browser, **plus** server re-parse | `schema.safeParse` in action |
| Pending UI | `formState.isSubmitting` | `useFormStatus().pending` / `isPending` |
| Best for | Rich interactive forms, custom widgets, Vite SPA (server = API route re-validating) | Simple-to-medium forms in App Router |

Both import `lib/schemas/<form>.ts`, which holds the rules and the human-readable messages, and both render the same `Field` and `ErrorSummary` components.

### Field order and anatomy
Order within a field: label, hint, error message, input. The error sits above the input, as GOV.UK and Adam Silver recommend, so the mobile keyboard or an autocomplete popup can't hide it. See the `Field` component in Examples.

## Recommended Workflow
1. List every field and justify it. Cut, defer or make optional.
2. Order the fields to match the user's mental model.
3. Pick controls using the decision table. Set `type`, `autoComplete`, `inputMode` and width.
4. Write the shared Zod schema with every error message (empty, format, range) in `lib/schemas/`.
5. Build a single-column layout with `Field`, `fieldset` and a verb-labelled submit button.
6. Choose the submission architecture (RHF client or Server Action). The server always re-validates with the shared schema.
7. Add an error summary plus inline errors per [form-validation-patterns](../form-validation-patterns/Skill.md).
8. Test with autofill, a password manager, keyboard only, a screen reader, 200% zoom and a real phone.
9. Instrument field-level drop-off and error frequency. Iterate.

## Patterns
- **Label, hint, error, input stack:** the `Field` component.
- **Error summary + inline errors:** the `ErrorSummary` component, focused after a failed submit.
- **Optional marker in label:** `<Field label="Company name" optional>`.
- **Memorable date:** a fieldset of day/month/year text inputs.
- **Address lookup with manual fallback:** postcode + "Find address", a results select, and an "Enter address manually" disclosure.
- **Show password toggle:** `<button type="button" aria-pressed>` that switches `type`.
- **Character count:** a counter referenced by `aria-describedby`, updated in a debounced `aria-live="polite"` region. Allow typing over the limit and show an error.
- **Check answers before submit:** see [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md).
- **"Same as" shortcut:** a checkbox that copies shipping to billing (SC 3.3.7).

## Anti-Patterns
| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Placeholder as label | Disappears on typing, low contrast | Visible `<label htmlFor>` |
| Floating labels by default | Tiny label, autofill overlap | Static label above input |
| Multi-column layout | Fields skipped | Single column |
| `disabled={!isValid}` on submit | No explanation of what's wrong; not focusable | Enabled button; validate on submit |
| Errors in tooltips / on hover | Missed on touch and by screen readers | Persistent inline text |
| Red border only | Fails 1.4.1 | Text + icon + border |
| "Invalid input" | Not actionable | Specific messages in schema |
| Clearing fields after Server Action error | React 19 resets uncontrolled forms after an action | Return `values` from the action; set `defaultValue` from state |
| `type="number"` for card/postcode | Spinner, leading-zero loss | `inputMode="numeric"` |
| Reset button next to Submit | Accidental data loss | Remove |
| Strict phone/card formatting rules | Rejects valid input | Normalise in schema transform |
| Pre-ticked marketing consent | Dark pattern | Unticked opt-in |
| Blocking paste | Breaks password managers | Allow paste |
| Different messages client vs server | Confusing, drift | Messages live in the shared schema |

## Accessibility
- WCAG 2.2 criteria to meet:
  - **1.3.1 Info and Relationships** (label, fieldset/legend, describedby).
  - **1.3.5 Identify Input Purpose** (`autoComplete`).
  - **1.4.1 Use of Color** and **1.4.11 Non-text Contrast** (input borders ≥3:1).
  - **2.4.6 Headings and Labels.**
  - **2.5.8 Target Size (Minimum).**
  - **3.3.1 Error Identification**, **3.3.2 Labels or Instructions**, **3.3.3 Error Suggestion**.
  - **3.3.4 Error Prevention (Legal, Financial, Data).**
  - **3.3.7 Redundant Entry.**
  - **3.3.8 Accessible Authentication (Minimum).**
  - **4.1.2 Name, Role, Value** and **4.1.3 Status Messages.**
- Use `aria-invalid` only after validation, never on first render.
- Move focus to the error summary after a failed submit, and make summary links focus the field.
- Keep a logical DOM order. Don't use positive `tabIndex`.
- Warn before session timeouts.
- More in [accessible-forms](../accessible-forms/Skill.md).

## Responsive Design
- A single column constrained to about 30–40em (`max-w-xl`) works at every width.
- Input font-size ≥16px prevents iOS Safari zoom on focus (`text-base`).
- Touch targets ≥44×44px for radios and checkboxes. Make labels clickable.
- Avoid sticky footers covering focused inputs when the keyboard is open. Use `scroll-margin` for sticky headers.
- Mobile keyboard selection via `type`/`inputMode`/`enterKeyHint`: see [text-inputs-and-fields](../text-inputs-and-fields/Skill.md).

## Performance
- In Next.js, render the form in a Server Component page, with only the interactive form as a Client Component. A Server Action form works before hydration.
- Lazy-load heavy widgets (rich text, address lookup, maps) with `next/dynamic` or `React.lazy` when the field is reached.
- Prefer uncontrolled inputs (`register`, or native inputs with `defaultValue`) to avoid re-rendering on every keystroke.

## Security
- Client rules are UX only. Re-validate on the server (Server Action or API route) with the same schema.
- `autoComplete="new-password"` / `current-password` let password managers work.
- Don't reveal account existence in login or reset error copy.
- Don't put PII in URLs (GET forms, search params) or analytics events.
- Server Actions are public endpoints. Authenticate and authorize inside them.
- Never echo passwords or card numbers back in action state.

## Testing
- **Manual:** keyboard-only completion, NVDA and VoiceOver passes, autofill and password manager, 200% zoom.
- **Component (Vitest + Testing Library):** `getByRole('textbox', { name: 'Email address' })` proves accessible names. Submit empty and assert the summary and inline messages.
- **E2E (Playwright):** error summary focused, links move focus, and a JS-disabled run of the Server Action variant still validates.
- **Automated:** axe via `@axe-core/playwright` in both the pristine and error states.
- **Analytics:** field-level abandonment and error rates.

## Tooling
- React Hook Form 7.x + `@hookform/resolvers` + Zod 4 (active): client form state.
- Next.js App Router Server Actions + React 19 `useActionState` / `useFormStatus` (active).
- shadcn/ui `Field`, `FieldLabel`, `FieldDescription`, `FieldError` (active): accessible field layout.
- React Aria `TextField`/`Form` and Base UI `Field`/`Form` (active): headless accessible fields.
- axe-core / `@axe-core/playwright` (active).
- GOV.UK Design System (active): reference patterns to port into React components.

## Framework Notes
- **React (Vite SPA):**
  - There are no Server Actions. Use RHF + Zod on the client and POST to your API, which must import the same schema (a shared package in a monorepo) and return `{ fieldErrors }`.
  - Map server errors with `setError`.
  - Use `useId()` for ids.
- **Next.js (App Router):**
  - Keep the page a Server Component and put the form in a `"use client"` component.
  - Put schemas in `lib/schemas/*.ts` (no `"use server"` and no server-only imports) so both the client component and `actions.ts` can import them.
  - Prefer Server Actions with `useActionState` for progressive enhancement. Use RHF when you need instant client feedback or complex widgets, and call the action from `handleSubmit`.
  - Use `redirect()` after success.

## AI Agent Guidance
- **Do:**
  - Give every input a visible `<label htmlFor>` via `useId()`, and group choices in `fieldset`/`legend`.
  - Set `type`, `name`, `autoComplete` and `inputMode`.
  - Put error messages in the shared Zod schema and re-validate on the server.
  - Keep submit enabled except while pending.
  - Preserve values after server errors.
- **Don't:** use placeholder-only labels, multi-column layouts, `disabled={!isValid}`, tooltip errors, `type="number"` for identifiers, or different client and server messages.
- **Verify before done:**
  - Tab through the form.
  - Submit empty and confirm the summary is focused and its links work.
  - axe reports 0 violations.
  - Mobile emulation shows the right keyboard and no zoom on focus.
  - Autofill works.
  - The Server Action variant works with JS disabled.

## Examples

**Shared schema: `lib/schemas/contact.ts`**
```tsx
import { z } from "zod";

export const contactSchema = z.object({
  name: z.string().trim().min(1, { error: "Enter your full name" }),
  email: z.email({ error: "Enter an email address in the correct format, like name@example.com" }),
  company: z.string().trim().optional(),
  message: z.string().trim().min(1, { error: "Enter your message" })
    .max(500, { error: "Message must be 500 characters or fewer" }),
});
export type ContactInput = z.input<typeof contactSchema>;
export type ContactOutput = z.output<typeof contactSchema>;
export type FieldErrors = Partial<Record<keyof ContactInput, string[]>>;
```

**Accessible building blocks: `components/form/field.tsx`**
```tsx
"use client";
import { useId, cloneElement, type ReactElement, type Ref } from "react";

export function Field({ label, hint, error, optional, children }: {
  label: string; hint?: string; error?: string; optional?: boolean;
  children: ReactElement<React.InputHTMLAttributes<HTMLElement>>;
}) {
  const id = useId();
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  return (
    <div className="mb-6 max-w-xl" data-invalid={error ? "" : undefined}>
      <label htmlFor={id} className="block font-semibold">{label}{optional && " (optional)"}</label>
      {hint && <p id={hintId} className="text-muted-foreground">{hint}</p>}
      {error && (
        <p id={errorId} className="font-semibold text-red-700">
          <span className="sr-only">Error: </span>{error}
        </p>
      )}
      {cloneElement(children, {
        id,
        "aria-invalid": error ? true : undefined,
        "aria-describedby": [hintId, errorId].filter(Boolean).join(" ") || undefined,
      })}
    </div>
  );
}

// React 19: ref is a regular prop; no forwardRef needed
export function ErrorSummary({ errors, ref }: {
  errors: { href: string; message: string }[];
  ref?: Ref<HTMLDivElement>;
}) {
  if (!errors.length) return null;
  return (
    <div ref={ref} tabIndex={-1} role="alert" className="mb-6 border-4 border-red-700 p-4">
      <h2 className="text-lg font-bold">There is a problem</h2>
      <ul>{errors.map((e) => <li key={e.href}><a href={e.href}>{e.message}</a></li>)}</ul>
    </div>
  );
}
```

**Variant A: client-side React Hook Form + Zod, `app/contact/contact-form-client.tsx`**
```tsx
"use client";
import { useRef } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { contactSchema, type ContactInput, type ContactOutput } from "@/lib/schemas/contact";
import { sendContact } from "./actions";
import { Field, ErrorSummary } from "@/components/form/field";

export function ContactFormClient() {
  const summaryRef = useRef<HTMLDivElement>(null);
  const { register, handleSubmit, setError, formState: { errors, isSubmitting } } =
    useForm<ContactInput, unknown, ContactOutput>({
      resolver: zodResolver(contactSchema),
      defaultValues: { name: "", email: "", company: "", message: "" },
      shouldFocusError: false, // we focus the summary instead
    });

  const onValid = async (data: ContactOutput) => {
    const res = await sendContact(data);          // server re-validates
    if (!res.ok) Object.entries(res.fieldErrors).forEach(([k, v]) =>
      v?.[0] && setError(k as keyof ContactInput, { type: "server", message: v[0] }));
  };
  const summary = Object.entries(errors).map(([k, e]) => ({ href: `#${k}`, message: String(e?.message) }));

  return (
    <form noValidate onSubmit={handleSubmit(onValid, () => requestAnimationFrame(() => summaryRef.current?.focus()))}>
      <ErrorSummary ref={summaryRef} errors={summary} />
      <Field label="Full name" error={errors.name?.message}><input {...register("name")} autoComplete="name" className="text-base" /></Field>
      <Field label="Email address" hint="We'll only use this to reply" error={errors.email?.message}>
        <input {...register("email")} type="email" autoComplete="email" spellCheck={false} className="text-base" />
      </Field>
      <Field label="Company name" optional><input {...register("company")} autoComplete="organization" className="text-base" /></Field>
      <Field label="Message" error={errors.message?.message}><textarea {...register("message")} rows={5} className="text-base" /></Field>
      <button type="submit" disabled={isSubmitting}>{isSubmitting ? "Sending…" : "Send message"}</button>
    </form>
  );
}
```
The `Field` component generates its own id, so summary links need to target it. In practice, pass `id={name}` through `Field`, or register refs and use `setFocus` from the summary link's `onClick`. The example keeps `href="#name"` for brevity.

**Variant B: Next.js Server Action + `useActionState` / `useFormStatus`**
```tsx
// app/contact/actions.ts
"use server";
import { z } from "zod";
import { redirect } from "next/navigation";
import { contactSchema, type ContactInput, type FieldErrors } from "@/lib/schemas/contact";

export type ContactState = { ok: false; values: Partial<ContactInput>; fieldErrors: FieldErrors } | null;

async function validateAndSave(input: unknown) {
  const parsed = contactSchema.safeParse(input);          // ALWAYS re-validate on server
  if (!parsed.success) return { ok: false as const, fieldErrors: z.flattenError(parsed.error).fieldErrors as FieldErrors };
  // await db.message.create({ data: parsed.data });
  return { ok: true as const };
}

export async function sendContact(data: unknown) { return validateAndSave(data); } // used by RHF variant

export async function sendContactAction(_prev: ContactState, formData: FormData): Promise<ContactState> {
  const values = Object.fromEntries(formData) as Partial<ContactInput>;
  const res = await validateAndSave(values);
  if (!res.ok) return { ok: false, values, fieldErrors: res.fieldErrors };
  redirect("/contact/sent");
}
```
```tsx
// app/contact/contact-form-action.tsx
"use client";
import { useActionState, useEffect, useRef } from "react";
import { useFormStatus } from "react-dom";
import { sendContactAction, type ContactState } from "./actions";
import { Field, ErrorSummary } from "@/components/form/field";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending}>{pending ? "Sending…" : "Send message"}</button>;
}

export function ContactFormAction() {
  const [state, formAction] = useActionState<ContactState, FormData>(sendContactAction, null);
  const summaryRef = useRef<HTMLDivElement>(null);
  const fe = state?.fieldErrors ?? {};
  const v = state?.values ?? {};
  useEffect(() => { if (state) summaryRef.current?.focus(); }, [state]);

  return (
    <form action={formAction} noValidate>
      <ErrorSummary ref={summaryRef} errors={Object.entries(fe).map(([k, m]) => ({ href: `#${k}`, message: m![0] }))} />
      <Field label="Full name" error={fe.name?.[0]}><input name="name" defaultValue={v.name} autoComplete="name" className="text-base" /></Field>
      <Field label="Email address" hint="We'll only use this to reply" error={fe.email?.[0]}>
        <input name="email" type="email" defaultValue={v.email} autoComplete="email" spellCheck={false} className="text-base" />
      </Field>
      <Field label="Company name" optional><input name="company" defaultValue={v.company} autoComplete="organization" className="text-base" /></Field>
      <Field label="Message" error={fe.message?.[0]}><textarea name="message" defaultValue={v.message} rows={5} className="text-base" /></Field>
      <SubmitButton />
    </form>
  );
}
```

**Memorable date (TSX)**
```tsx
export function DateOfBirth({ error }: { error?: string }) {
  return (
    <fieldset aria-describedby={`dob-hint${error ? " dob-error" : ""}`} className="mb-6">
      <legend className="font-semibold">What is your date of birth?</legend>
      <p id="dob-hint">For example, 27 3 2007</p>
      {error && <p id="dob-error" className="text-red-700"><span className="sr-only">Error: </span>{error}</p>}
      <div className="flex gap-4">
        <label>Day<input name="dobDay" inputMode="numeric" autoComplete="bday-day" size={2} className="block w-[5ch] text-base" /></label>
        <label>Month<input name="dobMonth" inputMode="numeric" autoComplete="bday-month" size={2} className="block w-[5ch] text-base" /></label>
        <label>Year<input name="dobYear" inputMode="numeric" autoComplete="bday-year" size={4} className="block w-[7ch] text-base" /></label>
      </div>
    </fieldset>
  );
}
```

## Related Skills
- [form-validation-patterns](../form-validation-patterns/Skill.md): validation timing, error summary mechanics
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md): client-side implementation
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): server-side submission
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md): useActionState/useFormStatus
- [progressive-enhancement](../progressive-enhancement/Skill.md): forms that work before hydration
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md): splitting long forms
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md): input types, inputMode
- [buttons-and-actions](../buttons-and-actions/Skill.md): submit button states
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md): choice controls
- [accessible-forms](../accessible-forms/Skill.md): deeper accessibility requirements
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md): label and error copy
- [checkout-flow-design](../checkout-flow-design/Skill.md): applied checkout forms
- [shadcn-ui](../shadcn-ui/Skill.md): Field components

## Sources
- [GOV.UK Design System: Validation pattern](https://design-system.service.gov.uk/patterns/validation/) — Official — validate on submit, error summary, "Error:" title prefix, server validation
- [GOV.UK Design System: Error summary](https://design-system.service.gov.uk/components/error-summary/) — Official — placement, focus, linking rules
- [GOV.UK Design System: Question pages](https://design-system.service.gov.uk/patterns/question-pages/) — Official — heading as label, Continue button
- [Adam Silver: Form design from zero to hero](https://adamsilver.io/blog/form-design-from-zero-to-hero-all-in-one-blog-post/) — Community (expert) — label/hint/error ordering, single column, no disabled buttons
- [Baymard: Usability Testing of Inline Form Validation](https://baymard.com/blog/inline-form-validation) — Community (research) — premature validation, benchmark stats
- [NN/g: 10 Design Guidelines for Reporting Errors in Forms](https://www.nngroup.com/articles/errors-forms-design-guidelines/) — Community (research) — proximity, no tooltips, colour + icon
- [W3C WAI Forms Tutorial: Notifications](https://www.w3.org/WAI/tutorials/forms/notifications/) — Official — error lists, aria-invalid/describedby
- [React: useActionState](https://react.dev/reference/react/useActionState) — Official — action state, automatic form reset
- [shadcn/ui: React Hook Form](https://ui.shadcn.com/docs/forms/react-hook-form) — Open Source — Field composition
- [MDN: Constraint validation](https://developer.mozilla.org/en-US/docs/Web/HTML/Guides/Constraint_validation) — Official — native attributes and limits

## License / Usage Notes
GOV.UK Design System content is under the Open Government Licence v3.0 (code MIT). MDN is CC-BY-SA 2.5. React, Next.js, React Hook Form, Zod and shadcn/ui are MIT. Baymard and NN/g research is only summarized. All code is original.

## Quality Tier
A — Grounded in converging government, standards and research sources, with React/Next.js implementations checked against current APIs. Paywalled Baymard data is not reproduced.

## Status
Active

## Last Verified
2026-09-15
