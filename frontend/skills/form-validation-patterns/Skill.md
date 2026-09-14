# Form Validation Patterns

## Summary
How and when to validate form input and present errors in React and Next.js (App Router) apps. Covers:
- the timing policy ("reward early, punish late")
- one shared Zod schema validated on both client and server
- React Hook Form client validation and Server Actions with `useActionState`/`useFormStatus`
- async checks and cross-field rules
- accessible error presentation: summary, inline messages, focus, live regions

## Category
Components

## Subcategories
Validation timing, shared Zod schemas, Standard Schema, server-side validation, Server Actions, async validation, error summary, aria-invalid, focus management, constraint validation

## Problem It Solves
Validation is the most error-prone part of forms. Common failures:
- errors fire while the user is still typing
- errors don't clear when fixed
- messages are vague
- client and server rules drift apart
- React 19's automatic form reset wipes input after a failed Server Action
- screen reader users never hear about errors
- async checks race each other

## When To Use
- Implementing validation in any React/Next.js form, from one field to a multi-step flow
- Choosing between client-side RHF validation, Server Action validation, or both
- Sharing one schema between a Client Component and a Server Action or API route
- Adding async checks (username availability, VAT lookup)
- Fixing accessibility bugs around errors

## When Not To Use
- Deciding which fields exist and how they are labelled: see [form-design-ux](../form-design-ux/Skill.md)
- Deep React Hook Form API usage: see [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md)
- Instant-apply toggles, where each change is its own mutation with rollback: see [optimistic-ui](../optimistic-ui/Skill.md)
- Search/filter inputs that never "fail"

## Core Principles
1. **The server is the source of truth.** Client validation is UX. Every Server Action or API route re-parses input with the same Zod schema and returns per-field errors.
2. **One schema module, two runtimes.** `lib/schemas/*.ts` is imported by the Client Component (RHF resolver) and by `actions.ts` / route handlers. Error messages live in the schema.
3. **Don't punish mid-entry.** Never show an error for a field the user is still typing into for the first time.
4. **Reward early, punish late.** Show the first error on submit (or on blur for well-formed fields). Once a field is in error, re-validate on change so it clears as soon as it's fixed (Baymard).
5. **Submit-time validation is the baseline** (GOV.UK, Adam Silver). On-blur and async checks are targeted enhancements.
6. **Two presentations per error:** a summary (after submit) and inline at the field, with identical text.
7. **Messages explain the fix:** "Enter a date in the past", not "Invalid date".
8. **Never block input or disable submit for invalidity.** Disabling only while pending is fine.
9. **Preserve input.** Server Action responses echo submitted values (minus secrets) so fields re-render filled in.
10. **Errors are announced.** Focus the summary on submit failure, set `aria-invalid` + `aria-describedby`, and use live regions only for non-submit updates.

## Best Practices

### Timing matrix
| Situation | First validation | Re-validation | Setting |
|---|---|---|---|
| Default | On submit | On change for errored fields | RHF defaults: `mode: "onSubmit"`, `reValidateMode: "onChange"` |
| Server Action only | On submit (round trip) | Next submit (optionally add RHF for instant re-validation) | `useActionState` |
| Long forms with well-formed fields | On blur if non-empty | On change | RHF `mode: "onTouched"` |
| Password creation | Live requirement checklist (neutral → met) | Live | `useWatch` + schema checks |
| Availability (async) | On blur or 300–500 ms debounce, with pending status | Debounced | RHF async `validate` + AbortController |
| Character count | Live polite count, error on submit | Live | Custom |
| Cross-field (date ranges) | On submit | On change of either field | Zod `.refine(..., { path })` |

### Messages
- **Pattern:** what's wrong, then how to fix it. "Enter your email address" (empty). "Enter an email address in the correct format, like name@example.com" (format).
- Refer to the field by its label. Avoid technical words and blame.
- Non-field failures (payment declined, rate-limited) go in a form-level `role="alert"` with a next step. In RHF use `setError("root.server")`; in action state use a `formError` field.

### Presentation
- **Inline message:** text, a visually hidden "Error:" prefix and an icon, directly above the input.
- **Summary:** "There is a problem" with a list of links to fields. Focus it after a failed submit.
- **Title:** prefix "Error: " to the document title while errors are shown (a `useEffect` that sets `document.title`).
- **Clearing:** remove the message and `aria-invalid` as soon as the value is valid.
- **Positive validation:** use it sparingly, for fields like a card number passing a Luhn check.

### Native vs custom
- Keep semantic attributes (`type`, `required`, `maxLength`) for mobile keyboards and assistive tech, but add `noValidate` to `<form>` and render your own messages. Native bubbles can't be styled, vanish, and aren't in your summary.
- Use the `:user-invalid` pseudo-class (Tailwind v4 variant `user-invalid:`) rather than `:invalid`, so fields aren't red on first render.

## Implementation Guidance

### 1. Shared schema: `lib/schemas/signup.ts`
```tsx
import { z } from "zod"; // zod@4.x

export const signupSchema = z.object({
  email: z.email({ error: (iss) => !iss.input
    ? "Enter your email address"
    : "Enter an email address in the correct format, like name@example.com" }),
  password: z.string().min(12, { error: "Password must be 12 characters or more" }),
  startDate: z.iso.date({ error: "Enter a real start date" }),
  endDate: z.iso.date({ error: "Enter a real end date" }),
}).refine((d) => d.endDate >= d.startDate, {
  path: ["endDate"],
  error: "End date must be the same as or after the start date",
});

export type SignupInput = z.input<typeof signupSchema>;
export type SignupOutput = z.output<typeof signupSchema>;
export type FieldErrors = Partial<Record<keyof SignupInput, string[]>>;
export type SignupState =
  | { status: "idle" }
  | { status: "error"; values: Partial<SignupInput>; fieldErrors: FieldErrors; formError?: string };
```
Zod 4 notes:
- `error` replaces `message`, `required_error` and `invalid_type_error`.
- Format validators are top-level (`z.email()`, `z.iso.date()`).
- `z.flattenError()` / `z.treeifyError()` replace the deprecated `.flatten()` / `.format()`.
- Keep this file free of `"use server"` and server-only imports so Client Components can import it.

### 2. Server-side validation (shared by both variants): `app/signup/actions.ts`
```tsx
"use server";
import { z } from "zod";
import { redirect } from "next/navigation";
import { signupSchema, type SignupInput, type SignupState, type FieldErrors } from "@/lib/schemas/signup";

type Result = { ok: true } | { ok: false; fieldErrors: FieldErrors; formError?: string };

async function validateAndCreate(input: unknown): Promise<Result> {
  const parsed = signupSchema.safeParse(input);                 // server re-validation, always
  if (!parsed.success) return { ok: false, fieldErrors: z.flattenError(parsed.error).fieldErrors as FieldErrors };
  if (await emailTaken(parsed.data.email))                      // server-only business rule
    return { ok: false, fieldErrors: { email: ["An account with this email already exists. Sign in instead"] } };
  // await createUser(parsed.data)
  return { ok: true };
}

// Variant A (RHF) calls this with a typed object
export async function signup(data: SignupInput): Promise<Result> {
  return validateAndCreate(data);
}

// Variant B (useActionState) receives FormData
export async function signupAction(_prev: SignupState, formData: FormData): Promise<SignupState> {
  const values = Object.fromEntries(formData) as Partial<SignupInput>;
  const res = await validateAndCreate(values);
  if (!res.ok) {
    const { password: _omit, ...safeValues } = values;          // never echo passwords
    return { status: "error", values: safeValues, fieldErrors: res.fieldErrors, formError: res.formError };
  }
  redirect("/welcome");
}
declare function emailTaken(email: string): Promise<boolean>;
```

### 3. Focus and announcement rules
| Event | Focus | Announcement |
|---|---|---|
| Submit with errors | Error summary (`tabIndex={-1}`), or first invalid field if no summary | Summary `role="alert"` + title prefix |
| Blur validation shows error | Don't move focus | Message linked by `aria-describedby` |
| Error cleared while typing | No change | None |
| Async check result | No change | `role="status"` text |
| Server Action success | Next page (`redirect`) or success heading | `role="status"` for in-place saves |

### 4. Async validation without races (RHF)
```tsx
const controllerRef = useRef<AbortController | null>(null);
const checkUsername = async (value: string): Promise<true | string> => {
  controllerRef.current?.abort();
  const c = (controllerRef.current = new AbortController());
  try {
    const res = await fetch(`/api/username?u=${encodeURIComponent(value)}`, { signal: c.signal });
    const { available } = (await res.json()) as { available: boolean };
    return available || "That username is taken. Try another";
  } catch {
    return true; // network failure = "can't verify", server re-checks on submit
  }
};
// <input {...register("username", { validate: checkUsername })} />
```
Rate-limit `/api/username` (`app/api/username/route.ts`), because availability endpoints enable account enumeration.

## Recommended Workflow
1. Inventory rules per field: required, format, range, cross-field, async, server-only.
2. Write every message, then encode the rules in `lib/schemas/<form>.ts`.
3. Implement the Server Action (or API route for a Vite SPA) with `safeParse`, returning `{ values, fieldErrors, formError }`. Confirm it works with JS disabled.
4. Add client validation: RHF with `zodResolver(schema)`, or keep Server Action-only for simple forms.
5. Wire accessibility: `aria-invalid`, `aria-describedby`, summary focus, title prefix.
6. Add on-blur or async checks only where they clearly help.
7. Test rules at the schema, component and E2E levels, including race conditions and JS-disabled submission.

## Patterns
- **Reward early, punish late:** RHF default modes, or Server Action submit plus RHF re-validation on change.
- **Shared Standard Schema:** one Zod (or Valibot) schema consumed by `zodResolver`/`standardSchemaResolver` and by the server.
- **Server error hydration:** RHF `setError(field, { type: "server" })` / `setError("root.server")`, or read `state.fieldErrors` in `useActionState`.
- **Value echo:** the action returns `values`, and inputs use `defaultValue={state.values.x}`. This survives React 19's post-action form reset.
- **Pending button:** `useFormStatus()` in a child `SubmitButton` (Server Action) or `formState.isSubmitting` (RHF).
- **Warnings vs errors:** soft suggestions ("Did you mean gmail.com?") don't block submit.
- **Cross-field path targeting:** attach the error to the field users should change.

## Anti-Patterns
| Anti-pattern | Problem | Fix |
|---|---|---|
| `mode: "onChange"` from first keystroke | "Invalid email" after typing "j" | Default modes or `onTouched` |
| Blur-validating empty untouched fields | Wall of red while tabbing | Catch required on submit |
| Error persists after fix | Users think the fix failed | Re-validate on change once errored |
| `disabled={!isValid}` | Hides errors, blocks keyboard users | Enabled submit |
| Client-only validation | Bypassable | `safeParse` in every action/route |
| Duplicated rules in component and action | Drift | Shared schema module |
| Schema file with `"use server"` or DB imports | Can't import in Client Components; leaks server code | Pure schema module; server-only checks in action |
| Action returns errors but not values | React 19 resets the form; input lost | Echo `values` (minus secrets) |
| `alert()` or modal for errors | Hides context | Inline + summary |
| `aria-invalid` on pristine fields | "Invalid" announced on load | Only after validation |
| `role="alert"` on every inline message | Floods screen reader | Summary alert or focus |
| Async checks without abort/debounce | Stale results overwrite newer ones | AbortController + debounce |
| Generic "Something went wrong" for 400 | Unrecoverable | Map to fieldErrors |

## Accessibility
- WCAG 2.2:
  - **3.3.1 Error Identification (A)**
  - **3.3.3 Error Suggestion (AA)**
  - **3.3.4 Error Prevention (Legal, Financial, Data)**
  - **4.1.3 Status Messages (AA)**
  - **1.4.1 Use of Color** and **1.4.11 Non-text Contrast**
- Set `aria-invalid="true"` on invalid controls. For radio/checkbox groups, link the message to the `fieldset` with `aria-describedby`.
- Prefer `aria-describedby` over `aria-errormessage`, whose screen reader support is still uneven.
- Summary links must focus the control. Give the input an `id` equal to the field name, or call RHF `setFocus(name)` in the link's `onClick`.
- In Next.js, client-side navigation doesn't move focus. When a Server Action returns errors without navigating, focus the summary in a `useEffect` keyed on the state.
- See [accessible-forms](../accessible-forms/Skill.md), [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) and [focus-management](../focus-management/Skill.md).

## Responsive Design
- Put inline errors above inputs so the virtual keyboard doesn't cover them. Use `scroll-margin-top` (`scroll-mt-24`) for sticky headers when summary links jump to fields.
- Never depend on hover for error details. Let messages wrap rather than truncate.

## Performance
- RHF `register` inputs are uncontrolled, so validation on submit doesn't re-render per keystroke. Avoid `mode: "all"` with big schemas.
- Subscribe narrowly (`useFormState({ name })`, `useWatch({ name })`) for live indicators.
- Where the client bundle matters, consider `zod/mini` or Valibot with `standardSchemaResolver`. Keep server-only rules (DB lookups) in the action, not the shared schema.
- Server Action validation adds a round trip. For simple forms that's acceptable and ships zero client validation code.
- Debounce async checks and cache results per value.

## Security
- Server Actions are public HTTP endpoints. Re-parse, then authenticate and authorize inside every action.
- Pass parsed `data`, never raw `FormData` or spread input, to the database. Zod strips unknown keys by default; don't use `.passthrough()`/`.loose()` on write schemas.
- Don't leak account existence or internal exception text in messages.
- Rate-limit async validation route handlers.
- Never echo passwords or card numbers in action state.
- Avoid ReDoS-prone regexes in schemas, because they run on the server.

## Testing
- **Schema unit tests (Vitest):** valid and invalid fixtures per rule, including unicode names, `+` emails and leap days. Assert messages.
- **Server Action tests:** call `signupAction(initialState, formData)` directly and assert `fieldErrors` and echoed values without the password. Mock `redirect`.
- **Component tests (Testing Library + user-event):** partial typing shows no error. Submit shows the error with `aria-invalid`. Fixing the field clears it on change. The summary receives focus.
- **E2E (Playwright):** both variants. Submit empty and expect the summary focused and the title prefixed "Error:". Run the Server Action form with `javaScriptEnabled: false`. Mock async endpoints to check races.
- **Accessibility:** axe in the error state, plus a screen reader spot check.

## Tooling
- **Zod 4** (4.6.x, Sept 2026; MIT, active): `z.email()`, `error` param, `z.flattenError`, `zod/mini`.
- **Valibot v1** (MIT, active; latest patch unverified): alternative via `standardSchemaResolver`.
- **React Hook Form 7.88.x** (MIT, active; v8 not released) + **@hookform/resolvers** (`zodResolver`, `standardSchemaResolver`).
- **React 19 `useActionState` / `react-dom` `useFormStatus`** and **Next.js Server Actions** (active).
- **Conform v1** (MIT, active; "future" APIs in development): FormData-first alternative for Next.js with `parseWithZod` and `submission.reply()`.
- **TanStack Form v1** (MIT, active): alternative with per-field async validators and `asyncDebounceMs`.
- **next-safe-action** (community, active): typed action wrapper with schema validation. Check maintenance before adopting.
- **Formik:** in maintenance mode. Avoid for new work.

## Framework Notes
- **React (Vite SPA):**
  - Use RHF + Zod on the client.
  - Submit to your API (`fetch`/TanStack Query mutation). The backend must import the same schema (shared workspace package) and return `422 { fieldErrors }`, which you map with `setError`.
  - No Server Actions, and no progressive enhancement without a server.
- **Next.js (App Router):**
  - **Simple forms:** Server Action + `useActionState`, with `useFormStatus` in a child button. Works before hydration.
  - **Rich forms:** RHF in a Client Component, calling the Server Action from `handleSubmit` inside `startTransition` and mapping returned errors.
  - **Hybrid (instant client errors + progressive enhancement):** RHF `register` on native inputs with `<form action={formAction} onSubmit={...}>`. Validate with `trigger()` and `preventDefault` only when invalid, so the native action still runs without JS. See the Examples.
  - Server-side validation is mandatory in every case.

## AI Agent Guidance
- **Do:**
  - Create `lib/schemas/<form>.ts` with messages and import it in both client and action.
  - `safeParse` in every Server Action or route handler.
  - Echo safe values, using submit-first then change re-validation.
  - Render a summary with links, focus it, and set `aria-invalid`/`aria-describedby`.
  - Use `useFormStatus` for pending state, and debounce and abort async checks.
- **Don't:**
  - disable submit for invalidity
  - validate on the first keystroke
  - put `"use server"` or DB imports in the schema file
  - trust client validation
  - put `role="alert"` on each inline message
  - echo passwords
- **Verify before done:**
  1. Empty submit in both variants: summary focused, title prefixed, links focus fields.
  2. Partial typing: no premature error.
  3. Fixing a field clears its error immediately (RHF) or on the next submit (action-only).
  4. A JS-disabled Server Action submission returns the same messages with values preserved.
  5. A direct call to the action with bad data is rejected.
  6. axe passes in the error state.

## Examples

**Variant A: client-side React Hook Form + Zod (instant feedback)**
```tsx
"use client";
import { useEffect, useRef } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { signupSchema, type SignupInput, type SignupOutput } from "@/lib/schemas/signup";
import { signup } from "./actions";

export function SignupFormClient() {
  const summaryRef = useRef<HTMLDivElement>(null);
  const { register, handleSubmit, setError, setFocus, formState: { errors, isSubmitting, submitCount } } =
    useForm<SignupInput, unknown, SignupOutput>({
      resolver: zodResolver(signupSchema),
      defaultValues: { email: "", password: "", startDate: "", endDate: "" },
      shouldFocusError: false,
    });
  const list = Object.entries(errors).filter(([k]) => k !== "root") as [keyof SignupInput, { message?: string }][];

  useEffect(() => { if (list.length) summaryRef.current?.focus(); }, [submitCount]); // after each failed submit
  useEffect(() => {
    const base = document.title.replace(/^Error: /, "");
    document.title = list.length ? `Error: ${base}` : base;
  }, [list.length]);

  const onValid = async (data: SignupOutput) => {
    const res = await signup(data);                               // server re-validates
    if (!res.ok) {
      Object.entries(res.fieldErrors).forEach(([k, v]) => v?.[0] && setError(k as keyof SignupInput, { type: "server", message: v[0] }));
      if (res.formError) setError("root.server", { message: res.formError });
    }
  };

  return (
    <form noValidate onSubmit={handleSubmit(onValid)}>
      {errors.root?.server && <div role="alert">{errors.root.server.message}</div>}
      {list.length > 0 && (
        <div ref={summaryRef} tabIndex={-1} role="alert" className="border-4 border-red-700 p-4">
          <h2>There is a problem</h2>
          <ul>{list.map(([name, e]) => (
            <li key={name}><a href={`#${name}`} onClick={(ev) => { ev.preventDefault(); setFocus(name); }}>{e.message}</a></li>
          ))}</ul>
        </div>
      )}
      <label htmlFor="email">Email address</label>
      {errors.email && <p id="email-error" className="text-red-700"><span className="sr-only">Error: </span>{errors.email.message}</p>}
      <input id="email" type="email" autoComplete="email" className="text-base user-invalid:border-red-700"
        aria-invalid={errors.email ? true : undefined} aria-describedby={errors.email ? "email-error" : undefined}
        {...register("email")} />
      {/* password, startDate, endDate follow the same pattern */}
      <button type="submit" disabled={isSubmitting}>{isSubmitting ? "Creating account…" : "Create account"}</button>
    </form>
  );
}
```

**Variant B: Next.js Server Action + `useActionState` / `useFormStatus` (works without JS)**
```tsx
"use client";
import { useActionState, useEffect, useRef } from "react";
import { useFormStatus } from "react-dom";
import { signupAction } from "./actions";
import type { SignupState } from "@/lib/schemas/signup";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending}>{pending ? "Creating account…" : "Create account"}</button>;
}

export function SignupFormAction() {
  const [state, formAction] = useActionState<SignupState, FormData>(signupAction, { status: "idle" });
  const summaryRef = useRef<HTMLDivElement>(null);
  const fe = state.status === "error" ? state.fieldErrors : {};
  const values = state.status === "error" ? state.values : {};
  const entries = Object.entries(fe).filter(([, m]) => m?.length) as [string, string[]][];

  useEffect(() => { if (state.status === "error") summaryRef.current?.focus(); }, [state]);

  return (
    <form action={formAction} noValidate>
      {state.status === "error" && state.formError && <div role="alert">{state.formError}</div>}
      {entries.length > 0 && (
        <div ref={summaryRef} tabIndex={-1} role="alert" className="border-4 border-red-700 p-4">
          <h2>There is a problem</h2>
          <ul>{entries.map(([name, msgs]) => <li key={name}><a href={`#${name}`}>{msgs[0]}</a></li>)}</ul>
        </div>
      )}
      <label htmlFor="email">Email address</label>
      {fe.email && <p id="email-error" className="text-red-700"><span className="sr-only">Error: </span>{fe.email[0]}</p>}
      <input id="email" name="email" type="email" autoComplete="email" defaultValue={values.email} className="text-base"
        aria-invalid={fe.email ? true : undefined} aria-describedby={fe.email ? "email-error" : undefined} />
      <label htmlFor="password">Create a password</label>
      {fe.password && <p id="password-error" className="text-red-700"><span className="sr-only">Error: </span>{fe.password[0]}</p>}
      <input id="password" name="password" type="password" autoComplete="new-password" className="text-base"
        aria-invalid={fe.password ? true : undefined} aria-describedby={fe.password ? "password-error" : undefined} />
      {/* dates follow the same pattern with defaultValue={values.startDate} */}
      <SubmitButton />
    </form>
  );
}
```

**Hybrid: RHF instant validation, native action still submits (progressive enhancement)**
```tsx
"use client";
export function SignupFormHybrid() {
  const [state, formAction] = useActionState<SignupState, FormData>(signupAction, { status: "idle" });
  const form = useForm<SignupInput, unknown, SignupOutput>({
    resolver: zodResolver(signupSchema),
    defaultValues: { email: "", password: "", startDate: "", endDate: "" },
    errors: state.status === "error"                                   // reactive server errors
      ? Object.fromEntries(Object.entries(state.fieldErrors).map(([k, v]) => [k, { type: "server", message: v?.[0] }]))
      : undefined,
  });
  return (
    <form
      action={formAction}
      noValidate
      onSubmit={async (e) => {
        if (!(await form.trigger())) e.preventDefault(); // block only when client-invalid
      }}
    >
      {/* inputs use {...form.register("email")} plus name attributes; errors from form.formState.errors */}
      <SubmitButton />
    </form>
  );
}
```
Because `trigger()` is async, `preventDefault` must run synchronously to be reliable. In production, validate synchronously with `signupSchema.safeParse(Object.fromEntries(new FormData(e.currentTarget)))` inside `onSubmit`, call `preventDefault()` when it fails, then call `form.trigger()` to render the errors.

## Related Skills
- [form-design-ux](../form-design-ux/Skill.md): labels, copy, layout
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md): RHF details
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): action security and patterns
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md): useActionState, useFormStatus, form reset
- [progressive-enhancement](../progressive-enhancement/Skill.md): forms before hydration
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md): per-step validation
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md): auth-specific error disclosure
- [accessible-forms](../accessible-forms/Skill.md): ARIA and WCAG detail
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md): status announcements
- [focus-management](../focus-management/Skill.md): focusing summaries
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md): sharing schemas with API procedures
- [error-states](../error-states/Skill.md): non-form error UX

## Sources
- [GOV.UK Design System: Recover from validation errors](https://design-system.service.gov.uk/patterns/validation/) — Official — submit-time validation, server validation mandatory
- [GOV.UK Design System: Error summary](https://design-system.service.gov.uk/components/error-summary/) — Official — summary focus, linking, "Error:" title prefix
- [Baymard: Usability Testing of Inline Form Validation](https://baymard.com/blog/inline-form-validation) — Community (research) — premature validation, clear errors on keystroke once fixed; 31% of sites lack inline validation
- [Adam Silver: The problem with live validation](https://adamsilver.io/blog/the-problem-with-live-validation-and-what-to-do-instead/) — Community (expert) — submit-time validation argument
- [NN/g: Reporting Errors in Forms](https://www.nngroup.com/articles/errors-forms-design-guidelines/) — Community (research) — timing, proximity, no tooltips/modals
- [W3C WAI: Form notifications](https://www.w3.org/WAI/tutorials/forms/notifications/) — Official — aria-invalid, describedby, error lists
- [MDN: Constraint validation](https://developer.mozilla.org/en-US/docs/Web/HTML/Guides/Constraint_validation) — Official — ValidityState, novalidate, :user-invalid, limits
- [React: useActionState](https://react.dev/reference/react/useActionState) — Official — signature, isPending, automatic form reset
- [Zod 4 changelog](https://zod.dev/v4/changelog) — Official — error param, top-level formats, flattenError
- [@hookform/resolvers](https://github.com/react-hook-form/resolvers) — Open Source — zodResolver, standardSchemaResolver, input/output generics
- [Conform docs](https://conform.guide/) — Official — FormData-first alternative
- [TanStack Form validation guide](https://tanstack.com/form/latest/docs/framework/react/guides/validation) — Official — alternative timing model, asyncDebounceMs

## License / Usage Notes
React, Next.js, Zod, Valibot, React Hook Form, Conform and TanStack Form are MIT. GOV.UK content is under OGL v3. MDN is CC-BY-SA. Research articles are summarized, not reproduced. Code is original.

## Quality Tier
A — Converging official and research guidance, and React 19, Zod 4 and RHF APIs checked against current docs. The hybrid progressive-enhancement pattern is a synthesis and should be tested per app.

## Status
Active

## Last Verified
2026-09-15
