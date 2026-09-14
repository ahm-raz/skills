# Accessible Forms

## Summary
Building forms in React/Next.js that everyone can understand, fill in, and recover from errors in. Covers labels, hints, grouping, required fields, `autoComplete`, validation timing, error messages and summaries, and wiring errors from React Hook Form, Zod and Server Actions (`useActionState`) to accessible markup. Unlabelled inputs appeared on 51% of home pages in the WebAIM Million 2026.

## Category
Accessibility

## Subcategories
Labels, hints, fieldset/legend, required fields, autocomplete, error identification, error summary, aria-invalid, aria-describedby, Server Actions, React Hook Form

## Problem It Solves
Forms are where users convert: sign-up, checkout, applications. Missing labels, placeholder-only fields, color-only errors, errors not announced, focus lost after submit, and paste blocked on password fields all stop disabled users from completing tasks. They fail 1.3.1, 1.3.5, 3.3.1–3.3.3, 3.3.7, 3.3.8 and 4.1.3.

## When To Use
- Any input, form, filter panel, search box, settings page, or multi-step flow.
- Wiring a validation library or Server Action errors into UI.

## When Not To Use
- Composite widgets such as combobox, date picker or slider have their own patterns (see Related Skills), though the labelling and error rules here still apply.

## Core Principles
1. **Every control has a visible, persistent label** programmatically associated with it.
2. **Instructions and format hints come before the input** and are associated via `aria-describedby`.
3. **Errors are text, specific, and tied to the field.** Color and icons are supplementary only.
4. **Tell users about errors.** Move focus to an error summary on submit, or announce it.
5. **Don't make users repeat or recall.** Autocomplete, prefill, allow paste (3.3.7, 3.3.8).
6. **Don't validate aggressively.** Validate on blur or submit, not on every keystroke while typing.
7. **Native controls first.**

## Best Practices
- Associate labels with `<label htmlFor={id}>` using `useId()`. Wrapping `<label><input/> Text</label>` also works.
- Mark required fields: a visible "(required)" text or asterisk with a legend explaining it, plus `required` or `aria-required="true"`. If most fields are required, mark the optional ones instead.
- Use `noValidate` on `<form>` if you render custom errors, to avoid inconsistent native bubbles. Keep `required`/`type` attributes for semantics.
- Use `aria-invalid="true"` only after validation fails. Never set it on initial render.
- `aria-describedby="hint-id error-id"`, with the error id present only when an error exists. `aria-errormessage` has weaker AT support, so prefer `aria-describedby`.
- Group related controls: radios and checkboxes in `<fieldset><legend>`; date parts; address blocks.
- `autoComplete` tokens (1.3.5): `name`, `given-name`, `family-name`, `email`, `tel`, `street-address`, `postal-code`, `country`, `cc-number`, `cc-exp`, `username`, `current-password`, `new-password`, `one-time-code`.
- Use the right `type` and `inputMode` (`email`, `tel`, `url`, `inputMode="numeric"` for codes). Avoid `type="number"` for non-quantities (card numbers, postcodes).
- Error text should say what's wrong and how to fix it: "Enter a date in the past, like 27 3 2007", not "Invalid".
- Keep submit buttons enabled. Disabled submit buttons hide why users can't proceed; validate on submit instead.
- Character counters: announce politely and debounced ("20 characters remaining"), not on every keystroke.
- Don't use placeholder as a label or for critical hints. It disappears and often fails contrast.
- Timeouts: warn before session expiry and allow extension (2.2.1).

## Implementation Guidance

### Field anatomy
```tsx
type FieldProps = {
  label: string; name: string; hint?: string; error?: string; required?: boolean;
} & React.InputHTMLAttributes<HTMLInputElement>;

export function TextField({ label, name, hint, error, required, ...inputProps }: FieldProps) {
  const id = useId();
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  return (
    <div className="field">
      <label htmlFor={id}>{label}{required && <span aria-hidden="true"> *</span>}</label>
      {hint && <p id={hintId} className="hint">{hint}</p>}
      {error && <p id={errorId} className="error"><span className="sr-only">Error: </span>{error}</p>}
      <input id={id} name={name} required={required}
        aria-invalid={error ? true : undefined}
        aria-describedby={[hintId, errorId].filter(Boolean).join(' ') || undefined}
        {...inputProps} />
    </div>
  );
}
```
Put the error visually above or below the input consistently. Give it an icon plus text, and don't rely on red alone (1.4.1).

### Validation timing
| Moment | Do |
|---|---|
| While typing | Nothing, or only positive guidance (password rules checklist, updated politely) |
| On blur | Validate that field if the user entered something; don't flag empty required fields until submit |
| On submit | Validate all; render the error summary; focus the summary; set `aria-invalid` on fields |
| After an error, while correcting | Re-validate on change so errors clear promptly |

### Error summary (GOV.UK pattern)
- Put it at the top of the form with a heading "There is a problem" and a list of links to each invalid field (`href="#field-id"`).
- Focus it on submit (`tabIndex={-1}` + `.focus()`). `role="alert"` is optional if focus moves, and can double-announce with some screen readers.
- Prefix the page `<title>` with "Error: " so the problem is announced on full-page reloads and route renders.

### Server Actions + useActionState (Next.js / React 19)
```tsx
'use client';
import { useActionState, useEffect, useRef } from 'react';
import { signup, type SignupState } from './actions';

export function SignupForm() {
  const [state, action, pending] = useActionState<SignupState, FormData>(signup, { errors: {} });
  const summaryRef = useRef<HTMLDivElement>(null);
  const errors = Object.entries(state.errors);

  useEffect(() => { if (errors.length) summaryRef.current?.focus(); }, [state]);

  return (
    <form action={action} noValidate>
      {errors.length > 0 && (
        <div ref={summaryRef} tabIndex={-1} className="error-summary" aria-labelledby="es-title">
          <h2 id="es-title">There is a problem</h2>
          <ul>{errors.map(([f, m]) => <li key={f}><a href={`#${f}`}>{m}</a></li>)}</ul>
        </div>
      )}
      <TextField id="email" label="Email" name="email" type="email" autoComplete="email" required
        error={state.errors.email} defaultValue={state.values?.email} />
      <TextField id="password" label="Password" name="password" type="password" autoComplete="new-password"
        required hint="At least 12 characters" error={state.errors.password} />
      <button type="submit" aria-disabled={pending}>{pending ? 'Creating account…' : 'Create account'}</button>
    </form>
  );
}
```
Notes:
- Return submitted values so fields are refilled after server errors (3.3.7).
- If you pass `id` explicitly (as here, for summary links), let `TextField` accept it instead of `useId()`.
- Using `aria-disabled` rather than `disabled` keeps focus on the button during pending. Guard against double-submit in the action.

### React Hook Form + Zod
- `register('email')` spreads `name`/`ref`/`onChange`. Add `aria-invalid={!!errors.email}` and `aria-describedby`.
- `mode: 'onBlur'` or `'onSubmit'`, with `reValidateMode: 'onChange'`.
- `shouldFocusError: true` (default) focuses the first invalid field. Alternatively, render a summary and focus it in `onInvalid`.

## Recommended Workflow
1. Content first: labels, hints and error messages written (and reviewed) before coding.
2. Build fields from a single accessible `Field` component in the design system.
3. Add `autoComplete`, `type`, `inputMode` and grouping.
4. Implement validation timing and the error summary.
5. Test with keyboard only, NVDA (F to jump fields, hear label, hint, required, invalid), VoiceOver, 200% zoom, and the autofill and password-manager flow.
6. Automate: axe (`label`, `autocomplete-valid`, `aria-valid-attr-value`), Testing Library `getByLabelText`, `toHaveAccessibleDescription`, and `toHaveAccessibleErrorMessage`.

## Patterns
- **Fieldset for radios**: `<fieldset><legend>How should we contact you?</legend>…radios…</fieldset>`.
- **Required legend**: "Fields marked * are required", placed before the form.
- **Password reveal**: `<button type="button" aria-pressed={shown}>Show password</button>`; keep `autoComplete="current-password"`.
- **Inline success**: don't announce "valid" per field; announce once on successful submit or navigate.
- **"Same as shipping" checkbox** for 3.3.7 Redundant Entry.

## Anti-Patterns
- **Placeholder-only labels.** They vanish, have low contrast, and are inconsistently named. Use a visible `<label>`.
- **Red border only for errors.** 1.4.1 failure. Add text and an icon.
- **Errors injected without association or announcement.** Screen reader users never know. Use `aria-describedby` plus summary focus.
- **`aria-invalid="false"` noise or `aria-invalid` on page load.** Use it only after validation.
- **Blocking paste (`onPaste={e => e.preventDefault()}`)** on password, email or OTP fields. 3.3.8 failure.
- **Disabled submit until valid.** Users can't discover problems. Keep it enabled and validate on submit.
- **Auto-advancing OTP inputs split across six fields without a single-field fallback.** Use one `<input autoComplete="one-time-code" inputMode="numeric">`.
- **Submitting on `<select onChange>`.** 3.2.2 violation. Add a submit button.
- **CAPTCHA puzzles without alternatives.** 3.3.8. Use passkeys, email links, or invisible risk scoring.

## Accessibility
- 1.3.1 Info and Relationships, 1.3.5 Identify Input Purpose, 1.4.1 Use of Color, 2.4.6 Headings and Labels, 2.5.3 Label in Name, 3.2.2 On Input, 3.3.1 Error Identification, 3.3.2 Labels or Instructions, 3.3.3 Error Suggestion, 3.3.4 Error Prevention (legal/financial: review step or undo), 3.3.7 Redundant Entry, 3.3.8 Accessible Authentication, 4.1.2, 4.1.3 Status Messages.

## Responsive Design
- Stack labels above inputs on narrow screens; side-by-side labels break at 400% zoom.
- Inputs at least 16px font on iOS to prevent auto-zoom (also improves readability).
- Touch targets at least 24px (2.5.8); radios and checkboxes get a larger clickable label area.
- Error summary links must scroll the field into view below sticky headers (`scroll-padding-top`).

## Performance
- Validate with Zod on both client and server, but avoid re-rendering the whole form per keystroke (React Hook Form uncontrolled inputs).
- Debounce async validation (username availability) and announce the result politely.

## Security
- Allow password managers: correct `autoComplete`, stable `name`/`id`, no paste blocking.
- Don't reveal whether an account exists in error text beyond what your threat model allows. Still give actionable wording.
- Always validate server-side. Client errors are UX only.

## Testing
```tsx
// SignupForm.test.tsx (Vitest + Testing Library + vitest-axe)
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe } from 'vitest-axe';

test('shows associated errors and focuses summary', async () => {
  const user = userEvent.setup();
  const { container } = render(<SignupForm />);
  await user.click(screen.getByRole('button', { name: /create account/i }));
  const summary = await screen.findByRole('heading', { name: /there is a problem/i });
  expect(summary.parentElement).toHaveFocus();
  const email = screen.getByLabelText(/email/i);
  expect(email).toHaveAttribute('aria-invalid', 'true');
  expect(email).toHaveAccessibleDescription(/enter an email/i);
  expect(await axe(container)).toHaveNoViolations();
});
```
- Manual: NVDA F/Shift+F through fields; VoiceOver rotor "Form controls"; autofill with Chrome and Safari; 1Password or Bitwarden fill.

## Tooling
- React Hook Form, Zod (or Valibot); Conform (progressive-enhancement forms for Server Actions).
- React Aria `TextField`/`useField` (wires label, description and error ids automatically); Radix Form (lightweight).
- jest-dom matchers: `toHaveAccessibleName`, `toHaveAccessibleDescription`, `toHaveAccessibleErrorMessage`.
- axe rules: `label`, `label-title-only`, `autocomplete-valid`, `select-name`, `form-field-multiple-labels`.

## Framework Notes
- **Next.js.**
  - Server Actions with `<form action>` work before hydration (progressive enhancement). Ensure the server-rendered error state includes the summary and `aria-invalid`.
  - Use `generateMetadata` or a client title update to prefix "Error:".
  - `useFormStatus` gives the pending state for submit buttons.
- **React (Vite SPA).** React Hook Form with a `handleSubmit` `onInvalid` callback to focus the summary. React 19 `useActionState` also works client-only.
- **shadcn/ui `Form`.** Its `FormControl` wires `aria-describedby` and `aria-invalid`. Verify the error message id is included and the label is visible.

## AI Agent Guidance
- Do: generate fields with a visible `<label>`, `useId`, hints via `aria-describedby`, `autoComplete`, correct `type`, and fieldset/legend for groups.
- Do: implement an error summary with focus on submit, and inline errors tied to fields; refill values after server errors.
- Don't: use placeholder as a label, disable submit until valid, block paste, set `aria-invalid` initially, or show color-only errors.
- Verify before done:
  - `getByLabelText` works for every field
  - errors are announced (tested focus plus description)
  - axe clean
  - keyboard submit works
  - password manager autofill works

## Examples
```tsx
// Radio group
export function ContactPreference({ error }: { error?: string }) {
  const id = useId();
  return (
    <fieldset aria-describedby={error ? `${id}-err` : undefined} aria-invalid={error ? true : undefined}>
      <legend>How should we contact you?</legend>
      {error && <p id={`${id}-err`} className="error">Error: {error}</p>}
      {['Email', 'Phone', 'Text message'].map(opt => (
        <label key={opt} className="flex min-h-6 items-center gap-2">
          <input type="radio" name="contact" value={opt.toLowerCase()} /> {opt}
        </label>
      ))}
    </fieldset>
  );
}
```

## Related Skills
- [form-design-ux](../form-design-ux/Skill.md) — layout and content design
- [form-validation-patterns](../form-validation-patterns/Skill.md) — validation architecture
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — library integration
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — server-side form handling
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) — field components
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) — grouped controls
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md) — 3.3.8 authentication
- [focus-management](../focus-management/Skill.md) — error summary focus
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — status messages

## Sources
- [W3C WAI Forms Tutorial](https://www.w3.org/WAI/tutorials/forms/) — Official — labels, grouping, instructions, notifications
- [Understanding 3.3.1, 3.3.3, 3.3.7, 3.3.8, 1.3.5](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — requirements
- [HTML autofill tokens](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill) — Official — autocomplete values
- [GOV.UK Design System: Error summary & Error message](https://design-system.service.gov.uk/components/error-summary/) — Official (government) — tested error patterns
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — 51% missing labels
- [React useActionState](https://react.dev/reference/react/useActionState) — Official — Server Action form state
- [Adrian Roselli: Avoid Default Field Validation / disabled buttons](https://adrianroselli.com/) — Community — validation timing critique

## License / Usage Notes
W3C and WHATWG content is summarised. GOV.UK patterns are under OGL v3. Code examples are original.

## Quality Tier
S — official tutorials plus government-tested patterns, with React 19 and Next.js wiring.

## Status
Active

## Last Verified
2026-09-15
