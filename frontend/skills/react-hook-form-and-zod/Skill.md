# React Hook Form and Zod

## Summary
The production pattern for type-safe, performant React and Next.js (App Router) forms with React Hook Form (RHF) v7 and Zod 4 through `@hookform/resolvers`. Covers:
- schema-first typing with separate input and output types
- `register` vs `Controller` and field arrays
- validation modes
- a shared schema module re-validated in Server Actions
- the Server Action + `useActionState`/`useFormStatus` alternative
- accessible error wiring with shadcn/ui `Field`, and re-render control

## Category
Components

## Subcategories
React Hook Form, Zod 4, @hookform/resolvers, Standard Schema, Controller, useFieldArray, Next.js Server Actions, useActionState, useFormStatus, shadcn/ui Field, form performance

## Problem It Solves
Hand-rolled React form state re-renders on every keystroke, duplicates types and rules, handles server errors inconsistently and ships inaccessible error markup. RHF + Zod gives uncontrolled-input performance, one schema as the source of types and messages shared with the server, and a consistent error model. Paired with Server Actions, the same schema protects the backend.

## When To Use
- Client Components with non-trivial validation, instant feedback, dynamic fields, or controlled widgets (Radix/Base UI selects, date pickers, rich text)
- Next.js apps that want rich client UX *and* server re-validation with the same schema
- Vite SPAs posting to an API that shares the schema
- shadcn/ui projects, whose form docs use RHF + Zod

## When Not To Use
- Simple Next.js forms where a Server Action + `useActionState` with no client library is enough and works before hydration. That approach is shown below as Variant B.
- Forms that must be fully usable without JS: use Variant B, the hybrid in [form-validation-patterns](../form-validation-patterns/Skill.md), or Conform.
- Highly reactive forms with many async field validators, where TanStack Form v1's field-level validators may fit better.
- Instant-save toggles, where each control is its own mutation.

## Core Principles
1. **Schema first, in a shared module.** `lib/schemas/<form>.ts` defines rules, messages and types. It has no `"use server"` and no server-only imports, and it is imported by both the Client Component and the Server Action.
2. **Input type ≠ output type.** Use `useForm<z.input<S>, unknown, z.output<S>>` so fields hold strings while `handleSubmit` receives parsed output.
3. **Uncontrolled by default.** Use `register` for native inputs and `Controller`/`useController` only for components without a native input ref.
4. **Always provide `defaultValues`** for every field.
5. **The server re-validates** with `schema.safeParse` and returns field errors that map back into RHF with `setError` (or the reactive `errors` prop).
6. **Subscribe narrowly** with `useWatch({ name })`, `useFormState({ name })` or `subscribe`. Don't call `watch()` at the root.
7. **Accessible wiring is your job:** labels, `aria-invalid`, `aria-describedby` and a focus strategy.

## Best Practices
- **Versions (Sept 2026):**
  - `react-hook-form` 7.88.x (v8 not released).
  - `zod` 4.6.x.
  - `@hookform/resolvers` current major, which supports Zod 4 via `import { z } from "zod"`, plus `standardSchemaResolver`.
- **Modes:** keep the defaults `mode: "onSubmit"`, `reValidateMode: "onChange"`. Use `mode: "onTouched"` for long forms. Avoid `"onChange"`/`"all"` on big schemas.
- **Zod 4 idioms:**
  - `z.email()`, `z.iso.date()`
  - `{ error: "…" }`
  - `.refine(..., { path: ["field"] })`
  - `z.stringbool()` for FormData booleans
  - `.default()` applies to output; use `.prefault()` for pre-parse defaults
  - `z.flattenError(err).fieldErrors` on the server
- **Numbers:** keep strings in the form and coerce in the schema: `z.string().trim().min(1, {...}).pipe(z.coerce.number()...)`. This avoids `""` becoming `0`, and it works identically for FormData in Server Actions. Alternatively use `register(name, { valueAsNumber: true })` with `z.number()`, but that schema then can't parse FormData directly.
- **Checkboxes across both variants:** FormData sends `"on"` or omits the key. Model consent as `z.literal("on", { error: "..." })` or use `z.stringbool()`, and in RHF register the checkbox with `value="on"`.
- **Server errors:** `setError("email", { type: "server", message })` for a field and `setError("root.server", { message })` for the form. The reactive `errors` prop can mirror `useActionState` state.
- **Async data:** use the `values` prop with `resetOptions: { keepDirtyValues: true }`, or `reset(data)`.
- **Field arrays:** `useFieldArray`, `key={field.id}`, names like `items.${i}.name`, and schema `z.array(item).min(1, {...})`.
- **Focus:** `shouldFocusError` (default true) needs refs on inputs, so pass `field.ref` in `Controller`. For an error-summary UX, set it to false and focus the summary.
- **Submit state:** `formState.isSubmitting`, or `useTransition` when calling a Server Action. Never `disabled={!isValid}`.
- **Unsaved changes:** `formState.isDirty` + `beforeunload`.

## Implementation Guidance

### Install
Add `react-hook-form`, `zod` and `@hookform/resolvers` as dependencies with your package manager. For shadcn/ui, add the `field`, `input` and related components through its CLI.

### File layout (Next.js App Router)
```tsx
// lib/schemas/order.ts          -> shared Zod schema + types (client + server)
// app/orders/new/page.tsx       -> Server Component page
// app/orders/new/actions.ts     -> "use server": safeParse + authz + persist
// app/orders/new/order-form.tsx -> "use client": RHF (Variant A) or useActionState (Variant B)
```

### Shared schema: `lib/schemas/order.ts`
```tsx
import { z } from "zod";

export const orderSchema = z.object({
  name: z.string().trim().min(1, { error: "Enter your full name" }),
  email: z.email({ error: "Enter an email address in the correct format, like name@example.com" }),
  seats: z.string().trim().min(1, { error: "Enter number of seats" })
    .pipe(z.coerce.number().int({ error: "Seats must be a whole number" })
      .min(1, { error: "Seats must be 1 or more" }).max(50, { error: "Seats must be 50 or fewer" })),
  plan: z.enum(["starter", "team"], { error: "Select a plan" }),
  terms: z.literal("on", { error: "You must accept the terms to continue" }),
});

export type OrderInput = z.input<typeof orderSchema>;   // seats: string, terms: "on"
export type OrderOutput = z.output<typeof orderSchema>; // seats: number
export type OrderFieldErrors = Partial<Record<keyof OrderInput, string[]>>;
export type OrderActionState =
  | { status: "idle" }
  | { status: "error"; values: Partial<OrderInput>; fieldErrors: OrderFieldErrors; formError?: string };
```

### Server Action with re-validation: `app/orders/new/actions.ts`
```tsx
"use server";
import { z } from "zod";
import { redirect } from "next/navigation";
import { orderSchema, type OrderActionState, type OrderFieldErrors, type OrderInput } from "@/lib/schemas/order";

type Result = { ok: true; id: string } | { ok: false; fieldErrors: OrderFieldErrors; formError?: string };

async function createOrder(input: unknown): Promise<Result> {
  const session = await getSession();
  if (!session) return { ok: false, fieldErrors: {}, formError: "Your session has expired. Sign in again" };
  const parsed = orderSchema.safeParse(input);                     // never trust the client
  if (!parsed.success) return { ok: false, fieldErrors: z.flattenError(parsed.error).fieldErrors as OrderFieldErrors };
  const id = await db.orders.create({ ...parsed.data, userId: session.userId }); // parsed data only
  return { ok: true, id };
}

export async function createOrderFromClient(data: OrderInput) {    // Variant A
  return createOrder(data);
}

export async function createOrderAction(_prev: OrderActionState, fd: FormData): Promise<OrderActionState> { // Variant B
  const values = Object.fromEntries(fd) as Partial<OrderInput>;
  const res = await createOrder(values);
  if (!res.ok) return { status: "error", values, fieldErrors: res.fieldErrors, formError: res.formError };
  redirect(`/orders/${res.id}`);
}
declare function getSession(): Promise<{ userId: string } | null>;
declare const db: { orders: { create(d: object): Promise<string> } };
```

### Variant A: client-side React Hook Form + Zod
```tsx
"use client";
import { useTransition } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { orderSchema, type OrderInput, type OrderOutput } from "@/lib/schemas/order";
import { createOrderFromClient } from "./actions";
import { Field, FieldLabel, FieldError, FieldDescription } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function OrderFormClient() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const form = useForm<OrderInput, unknown, OrderOutput>({
    resolver: zodResolver(orderSchema),
    defaultValues: { name: "", email: "", seats: "1", plan: undefined, terms: undefined },
  });
  const { register, handleSubmit, setError, formState: { errors } } = form;

  const onSubmit = handleSubmit((data) =>
    startTransition(async () => {
      // Server action re-validates; send the raw input shape so the same schema parses it
      const res = await createOrderFromClient(form.getValues());
      if (res.ok) return router.push(`/orders/${res.id}`);
      Object.entries(res.fieldErrors).forEach(([k, v]) => v?.[0] && setError(k as keyof OrderInput, { type: "server", message: v[0] }));
      if (res.formError) setError("root.server", { message: res.formError });
    }),
  );

  return (
    <form onSubmit={onSubmit} noValidate className="max-w-xl space-y-6">
      {errors.root?.server && <div role="alert">{errors.root.server.message}</div>}

      <Field data-invalid={!!errors.name}>
        <FieldLabel htmlFor="name">Full name</FieldLabel>
        <Input id="name" autoComplete="name" aria-invalid={!!errors.name} {...register("name")} />
        {errors.name && <FieldError errors={[errors.name]} />}
      </Field>

      <Field data-invalid={!!errors.seats}>
        <FieldLabel htmlFor="seats">Number of seats</FieldLabel>
        <FieldDescription>Between 1 and 50</FieldDescription>
        <Input id="seats" inputMode="numeric" aria-invalid={!!errors.seats} {...register("seats")} />
        {errors.seats && <FieldError errors={[errors.seats]} />}
      </Field>

      <Controller
        name="plan"
        control={form.control}
        render={({ field, fieldState }) => (
          <Field data-invalid={fieldState.invalid}>
            <FieldLabel htmlFor="plan">Plan</FieldLabel>
            <Select name={field.name} value={field.value} onValueChange={field.onChange}>
              <SelectTrigger id="plan" ref={field.ref} onBlur={field.onBlur} aria-invalid={fieldState.invalid}>
                <SelectValue placeholder="Choose a plan" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="starter">Starter</SelectItem>
                <SelectItem value="team">Team</SelectItem>
              </SelectContent>
            </Select>
            {fieldState.invalid && <FieldError errors={[fieldState.error]} />}
          </Field>
        )}
      />

      <Field data-invalid={!!errors.terms} orientation="horizontal">
        <input id="terms" type="checkbox" value="on" aria-invalid={!!errors.terms} {...register("terms")} />
        <FieldLabel htmlFor="terms">I accept the terms</FieldLabel>
        {errors.terms && <FieldError errors={[errors.terms]} />}
      </Field>

      <button type="submit" disabled={isPending}>{isPending ? "Placing order…" : "Place order"}</button>
    </form>
  );
}
```
Notes:
- An unchecked RHF checkbox yields `false`, which the schema rejects with the terms message, and the server does the same for a missing key.
- shadcn/ui's current docs compose `Controller` + `Field`/`FieldLabel`/`FieldError` with `data-invalid`/`aria-invalid`. The older `Form`/`FormField`/`FormMessage` wrappers still work in existing projects.

### Variant B: Next.js Server Action + `useActionState` / `useFormStatus`
```tsx
"use client";
import { useActionState, useEffect, useRef } from "react";
import { useFormStatus } from "react-dom";
import { createOrderAction } from "./actions";
import type { OrderActionState } from "@/lib/schemas/order";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending}>{pending ? "Placing order…" : "Place order"}</button>;
}

export function OrderFormAction() {
  const [state, formAction] = useActionState<OrderActionState, FormData>(createOrderAction, { status: "idle" });
  const alertRef = useRef<HTMLDivElement>(null);
  const fe = state.status === "error" ? state.fieldErrors : {};
  const v = state.status === "error" ? state.values : {};
  useEffect(() => { if (state.status === "error") alertRef.current?.focus(); }, [state]);

  const err = (name: keyof typeof fe) =>
    fe[name] ? <p id={`${name}-error`} className="text-red-700"><span className="sr-only">Error: </span>{fe[name]![0]}</p> : null;
  const a11y = (name: keyof typeof fe) => ({ "aria-invalid": fe[name] ? true : undefined, "aria-describedby": fe[name] ? `${name}-error` : undefined });

  return (
    <form action={formAction} noValidate className="max-w-xl space-y-6">
      {state.status === "error" && (
        <div ref={alertRef} tabIndex={-1} role="alert">
          <h2>There is a problem</h2>
          <ul>{Object.entries(fe).map(([k, m]) => <li key={k}><a href={`#${k}`}>{m![0]}</a></li>)}</ul>
          {state.formError && <p>{state.formError}</p>}
        </div>
      )}
      <div><label htmlFor="name">Full name</label>{err("name")}
        <input id="name" name="name" autoComplete="name" defaultValue={v.name} {...a11y("name")} /></div>
      <div><label htmlFor="seats">Number of seats</label>{err("seats")}
        <input id="seats" name="seats" inputMode="numeric" defaultValue={v.seats ?? "1"} {...a11y("seats")} /></div>
      <fieldset {...a11y("plan")}>
        <legend>Plan</legend>{err("plan")}
        <label><input type="radio" name="plan" value="starter" defaultChecked={v.plan === "starter"} /> Starter</label>
        <label><input type="radio" name="plan" value="team" defaultChecked={v.plan === "team"} /> Team</label>
      </fieldset>
      <div>{err("terms")}
        <input id="terms" name="terms" type="checkbox" defaultChecked={v.terms === "on"} {...a11y("terms")} />
        <label htmlFor="terms">I accept the terms</label></div>
      <SubmitButton />
    </form>
  );
}
```
Variant B uses native radios rather than a JS Select so it works before hydration. React 19 resets uncontrolled forms after an action, so every input reads `defaultValue`/`defaultChecked` from the echoed `values`.

### Choosing
| Need | Choose |
|---|---|
| Instant client errors, custom widgets, field arrays, Vite SPA | Variant A (RHF + Zod), with server re-validation |
| Works before hydration / without JS, simple fields | Variant B (Server Action + useActionState) |
| Both | Hybrid (RHF `register` + `<form action>`): see [form-validation-patterns](../form-validation-patterns/Skill.md) |
| Smaller client bundle | `zod/mini` or Valibot via `standardSchemaResolver` |

## Recommended Workflow
1. Write the shared schema with messages and export input/output/state types.
2. Write the Server Action: session check, `safeParse`, authorization, persist, return errors or `redirect`.
3. Choose Variant A or B (or the hybrid).
4. For A: `useForm<In, unknown, Out>` with `zodResolver` and `defaultValues`. Use `register` for native inputs and `Controller` for widgets. Call the action in `startTransition` and map errors.
5. For B: `useActionState`, a `useFormStatus` button, `defaultValue` from echoed values, and summary focus.
6. Add accessible markup (shadcn `Field` or your own), field arrays and conditional fields.
7. Profile re-renders (React DevTools). Narrow subscriptions.
8. Test the schema, the action, the component and E2E.

## Patterns
- **Shared schema module** consumed by resolver and action.
- **Root/server error:** `setError("root.server")`, rendered as `role="alert"`.
- **Reactive server errors:** `useForm({ errors: mappedFromActionState })`.
- **FormProvider for deep trees:** `useFormContext()` plus `useFormState({ name })` in leaves.
- **Conditional fields:** `useWatch({ name: "kind" })` + `z.discriminatedUnion("kind", [...])`. Use `shouldUnregister: true` if hidden values must be dropped.
- **Edit form:** a Server Component loads the record and passes it as `defaultValues`. Use `values` + `keepDirtyValues` for live refreshes.
- **Render-free autosave:** `useEffect(() => form.subscribe({ formState: { values: true }, callback: ({ values }) => saveDraft(values) }), [form])`.
- **Standard Schema swap:** `standardSchemaResolver(valibotSchema)`.

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| Hand-written `FormValues` type | Drifts | `z.input`/`z.output` |
| `useForm<z.infer<S>>` with coerce/transform/default | Wrong field/submit types | Three generics |
| Schema defined inside the component or action file | Can't share; duplicates | `lib/schemas/*.ts` |
| `"use server"` or DB imports in schema module | Breaks client import; leaks server code | Pure module |
| Action trusts client-parsed data | Bypassable | `safeParse` inside action |
| `Controller` for plain inputs | Extra re-renders | `register` |
| `watch()` at root | Whole-form re-render per keystroke | `useWatch`/`subscribe` |
| Missing `defaultValues` | Controlled/uncontrolled warnings | Provide all |
| `key={index}` in field arrays | Values swap on remove | `key={field.id}` |
| No `field.ref` in Controller | Error focus fails | Pass ref |
| `disabled={!isValid}` | Hidden errors; extra subscription | Enabled submit |
| `z.coerce.number()` on empty input | `""` becomes `0` | Non-empty string, then pipe |
| Action returns errors without values (Variant B) | Form reset loses input | Echo values |
| Zod 3 idioms (`message`, `.email()`, `.flatten()`) | Deprecated in Zod 4 | `error`, `z.email()`, `z.flattenError()` |

## Accessibility
- Every input needs a `<label htmlFor>`, and choice groups need `fieldset`/`legend` with group errors associated to the fieldset.
- Set `aria-invalid` only when an error exists, and link the message with `aria-describedby`. shadcn `FieldError` renders `role="alert"`, so avoid also rendering a summary alert that repeats every message at once, or drop one of them.
- On failed submit, either rely on `shouldFocusError` or focus an error summary. Pick one strategy per app.
- Field arrays: remove buttons need unique names ("Remove guest 2"). Move focus to the new input after append and to a sensible target after remove.
- `Controller`-wrapped widgets must be accessible themselves (Radix, Base UI, React Aria).
- WCAG 3.3.1, 3.3.3, 4.1.2, 4.1.3. See [accessible-forms](../accessible-forms/Skill.md).

## Responsive Design
Library choice doesn't change layout. Follow [form-design-ux](../form-design-ux/Skill.md): single column, `inputMode`/`autoComplete`, 16px inputs. Prefer native radios/selects in Variant B and on mobile for reliable keyboards and pickers.

## Performance
- `register` is uncontrolled, so no re-render per keystroke.
- formState is a proxy, so reading a property subscribes to it. Read only what you render.
- Isolate reactive UI in children with `useWatch`/`useFormState({ name })`.
- Avoid `mode: "onChange"` with large schemas. Use field-level `validate` for hot fields.
- In Next.js, keep the page a Server Component and put only the form in a Client Component. Variant B ships no validation code to the client.
- Large field arrays: virtualize and avoid watching the whole array.

## Security
- Server Actions are public endpoints. Authenticate and authorize inside each one, and `safeParse` with the shared schema.
- Persist `parsed.data` only. Zod strips unknown keys by default, so don't loosen it on write schemas.
- Keep secrets and DB-dependent checks out of the shared schema.
- Next.js checks the Origin header for Server Actions, but you still need auth and rate limiting.
- Don't log full payloads with PII. Don't echo passwords or card data in action state.

## Testing
- **Schema (Vitest):** `orderSchema.safeParse` fixtures per rule, including `""` seats, `"0"`, `"51"` and a missing terms key.
- **Server Action:** call `createOrderAction({ status: "idle" }, formData)` with mocked `getSession`/`db`/`redirect`. Assert `fieldErrors` and echoed values.
- **Component (Testing Library + user-event):**
  ```tsx
  await user.click(screen.getByRole("button", { name: "Place order" }));
  expect(await screen.findByText("Enter your full name")).toBeInTheDocument();
  expect(screen.getByRole("textbox", { name: "Full name" })).toHaveAttribute("aria-invalid", "true");
  await user.type(screen.getByRole("textbox", { name: "Full name" }), "Ada");
  expect(screen.queryByText("Enter your full name")).not.toBeInTheDocument();
  ```
- **E2E (Playwright):** both variants, server rejection path, and Variant B with JavaScript disabled. Run axe in the error state.
- **Re-renders:** React DevTools Profiler on large forms.

## Tooling
- **react-hook-form 7.88.x** (MIT, active; v8 unreleased). Exports include `useForm`, `useController`, `useFieldArray`, `useFormState`, `useWatch`, `useFormContext`, `Controller`, `FormProvider`, `Form`, `Watch`, `FormStateSubscribe` and `createFormControl`. `UseFormProps` includes `mode`, `reValidateMode`, `defaultValues`, `values`, `errors`, `resetOptions`, `resolver`, `context`, `criteriaMode`, `shouldFocusError`, `delayError`, `shouldUnregister`, `shouldUseNativeValidation`, `disabled`, `progressive`, `formControl` and `validate`.
- **@hookform/resolvers** (MIT, active): `zodResolver`, `valibotResolver`, `standardSchemaResolver`.
- **@hookform/devtools** (active): dev-only.
- **zod 4.6.x** (MIT, active) and **Valibot v1** (MIT, active).
- **shadcn/ui Field components** (MIT, active).
- **Alternatives:** Conform v1 (FormData-first, Next.js), TanStack Form v1, next-safe-action (community action wrapper). Formik is in maintenance; avoid.

## Framework Notes
- **React (Vite SPA):**
  - Variant A only.
  - Submit with `fetch` or a TanStack Query mutation to an API that imports the same schema from a shared package and returns `422 { fieldErrors }`.
  - Map the response with `setError`. Use `isSubmitting` or `mutation.isPending` for pending state.
- **Next.js (App Router):**
  - Forms are Client Components (`"use client"`) rendered by Server Component pages.
  - Variant A calls the Server Action from `handleSubmit` inside `startTransition`. Variant B passes the action to `<form action>` via `useActionState`, with `useFormStatus` in a child button.
  - Use `redirect()` inside the action on success and `revalidatePath`/`revalidateTag` as needed.
  - Server-side `safeParse` is mandatory in both variants.
- **React Compiler:** RHF 7.x works. If memoized children miss updates, subscribe via `useWatch`/`useFormState` instead of closures over `watch()`.

## AI Agent Guidance
- **Do:**
  - Create `lib/schemas/<form>.ts` with messages and types.
  - Use three `useForm` generics and provide `defaultValues`.
  - `register` native inputs and use `Controller` with `ref`/`onBlur` for widgets.
  - `safeParse` in the Server Action and map errors (including `root.server`).
  - For Variant B, echo values and use `useFormStatus`.
  - Use accessible Field markup and `field.id` keys.
- **Don't:**
  - duplicate schemas
  - put `"use server"` in schema files
  - disable submit for `!isValid`
  - call `watch()` at the root
  - use index keys
  - use Zod 3 APIs
  - trust client parsing
- **Verify before done:**
  1. `tsc` passes and submit data is output-typed (`seats: number`).
  2. Empty submit shows errors with `aria-invalid`/`aria-describedby` and focus moves correctly.
  3. Fixing a field clears the error.
  4. Posting bad data straight to the action is rejected with the same messages.
  5. Variant B works with JS disabled and keeps values.
  6. There are no controlled/uncontrolled warnings.
  7. The Profiler shows no whole-form re-render per keystroke.

## Examples
```tsx
// Valibot via Standard Schema resolver (shared module works the same way)
import * as v from "valibot";
import { standardSchemaResolver } from "@hookform/resolvers/standard-schema";

export const EmailSchema = v.object({
  email: v.pipe(v.string(), v.nonEmpty("Enter your email address"), v.email("Enter an email address in the correct format")),
});
const form = useForm<v.InferInput<typeof EmailSchema>, unknown, v.InferOutput<typeof EmailSchema>>({
  resolver: standardSchemaResolver(EmailSchema),
  defaultValues: { email: "" },
});
```

```tsx
// Field array with focus management
const { fields, append, remove } = useFieldArray({ control: form.control, name: "guests" });
const prevLen = useRef(fields.length);
useEffect(() => {
  if (fields.length > prevLen.current) form.setFocus(`guests.${fields.length - 1}.name`);
  prevLen.current = fields.length;
}, [fields.length, form]);

return (
  <>
    {fields.map((f, i) => (
      <fieldset key={f.id}>
        <legend>Guest {i + 1}</legend>
        <label htmlFor={`guest-${f.id}`}>Name</label>
        <input id={`guest-${f.id}`} {...form.register(`guests.${i}.name`)} />
        <button type="button" onClick={() => remove(i)}>Remove guest {i + 1}</button>
      </fieldset>
    ))}
    <button type="button" onClick={() => append({ name: "" })}>Add another guest</button>
  </>
);
```

```tsx
// Discriminated union conditional fields (shared schema)
export const contactPrefSchema = z.discriminatedUnion("contact", [
  z.object({ contact: z.literal("email"), email: z.email({ error: "Enter an email address" }) }),
  z.object({ contact: z.literal("phone"), phone: z.string().min(7, { error: "Enter a phone number" }) }),
]);
function ContactFields() {
  const { register, control } = useFormContext<z.input<typeof contactPrefSchema>>();
  const contact = useWatch({ control, name: "contact" });
  return contact === "phone"
    ? <input type="tel" autoComplete="tel" {...register("phone")} />
    : <input type="email" autoComplete="email" {...register("email")} />;
}
```

## Related Skills
- [form-validation-patterns](../form-validation-patterns/Skill.md): timing, error presentation, hybrid pattern
- [form-design-ux](../form-design-ux/Skill.md): labels, layout, copy
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): action security and revalidation
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md): useActionState, useFormStatus, useTransition
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md): per-step schemas and `trigger`
- [select-and-combobox](../select-and-combobox/Skill.md): controlled widgets in Controller
- [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md): controlled date values
- [shadcn-ui](../shadcn-ui/Skill.md): Field components
- [vite-react-spa](../vite-react-spa/Skill.md): SPA submission to APIs
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md): reusing schemas as procedure inputs
- [typescript-for-frontend](../typescript-for-frontend/Skill.md): inference patterns
- [testing-library-principles](../testing-library-principles/Skill.md): form tests by role

## Sources
- [react-hook-form on npm](https://www.npmjs.com/package/react-hook-form) — Official — current version 7.88.0 (Sept 2026)
- [react-hook-form types (jsDocs.io)](https://www.jsdocs.io/package/react-hook-form) — Open Source — UseFormProps options and exports
- [useForm docs](https://react-hook-form.com/docs/useform) — Official — modes, values/errors, subscribe (page blocked the fetcher; cross-checked via types)
- [@hookform/resolvers](https://github.com/react-hook-form/resolvers) — Open Source — zodResolver with Zod 4, three-generic typing, standardSchemaResolver
- [Zod 4 changelog](https://zod.dev/v4/changelog) — Official — error param, top-level formats, flattenError, default/prefault
- [zod on npm](https://www.npmjs.com/package/zod) — Official — 4.6.x
- [shadcn/ui: React Hook Form](https://ui.shadcn.com/docs/forms/react-hook-form) — Open Source — Controller + Field composition
- [React: useActionState](https://react.dev/reference/react/useActionState) — Official — action state, isPending, form reset
- [Conform docs](https://conform.guide/) — Official — FormData-first alternative
- [TanStack Form v1 announcement](https://tanstack.com/blog/announcing-tanstack-form-v1) — Official — alternative with native Standard Schema

## License / Usage Notes
React Hook Form, @hookform/resolvers, Zod, Valibot, shadcn/ui, React, Next.js, Conform and TanStack Form are MIT. Code is original and API facts are summarized from docs.

## Quality Tier
A — APIs checked against current package versions, resolver docs and React docs. The useForm docs page couldn't be fetched directly, so props were confirmed via published types. The shadcn `Field` `orientation` prop was not independently verified.

## Status
Active

## Last Verified
2026-09-15
