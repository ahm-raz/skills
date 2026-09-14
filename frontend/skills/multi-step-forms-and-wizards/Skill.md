# Multi-Step Forms and Wizards

## Summary
Guidance for splitting long or branching data collection into steps in React and Next.js (App Router). Covers:
- when a wizard helps or hurts (NN/g)
- GOV.UK's "one thing per page" and "check answers" patterns
- step state in the URL, and per-step validation with a shared Zod schema
- branching, save-and-resume and honest progress
- focus management and final submission integrity

Two implementations are shown: a client-side React Hook Form wizard, and route-per-step Next.js Server Actions with `useActionState`/`useFormStatus`.

## Category
Components

## Subcategories
Wizards, steppers, question pages, one thing per page, check answers, branching logic, save and resume, progress indicators, onboarding flows, checkout steps

## Problem It Solves
Long forms overwhelm people. Badly built wizards create new problems:
- the browser Back button loses data
- step 1 errors appear on step 4
- progress bars lie
- screen reader users aren't told the step changed
- refresh wipes progress
- hidden-branch data leaks into the final payload
- double-clicks create duplicate applications

## When To Use
- Long, infrequent or unfamiliar tasks: applications, onboarding, quotes, account setup (NN/g)
- Flows with branching, where later questions depend on earlier answers
- Legal, financial or data submissions needing a review step (WCAG 3.3.4)
- Mobile-heavy audiences

## When Not To Use
- Frequent expert tasks. Use one page with sections: see [dense-form-screens](../dense-form-screens/Skill.md).
- Short forms (roughly under 6–8 fields).
- Tasks requiring comparison or cross-referencing across steps.
- Settings pages.
- Checkout specifics (guest checkout, payment): see [checkout-flow-design](../checkout-flow-design/Skill.md).

## Core Principles
1. **Each step is a self-sufficient form** with its own heading, fields, validation and Continue button.
2. **One thing per page as the starting point** (GOV.UK). Group more only when research supports it.
3. **Validate the current step only**, when leaving it.
4. **Never lose data.** In-app Back, browser Back, refresh and interruptions all preserve answers.
5. **The URL reflects the step** (`/apply/income` or `?step=income`), so Back/Forward, deep links and analytics work.
6. **Branching is data-driven.** Compute the path from answers and prune answers for branches no longer taken.
7. **Check answers before commit**, with Change links that return straight to the review.
8. **One shared schema module** defines per-step schemas and the complete schema. The server validates each step *and* the complete payload at final submit.
9. **Honest progress.** Use "Step 2 of 5" or step names. Avoid clickable jump-ahead trackers (GOV.UK research found them often unnoticed and confusing).

## Best Practices
- Label the primary button "Continue" or "Continue to payment". The final button names the outcome ("Submit application").
- Back is a link or button that never validates.
- The step `<h1>` is the question and doubles as the `<label>`/`<legend>` for single-question steps.
- Put the step caption above the heading. For steppers, use `<ol>` with `aria-current="step"`.
- **Save and resume:**
  - Long or high-value flows: server drafts (DB keyed to user or session).
  - Short, non-sensitive flows: `sessionStorage`.
  - Never put PII in `localStorage` or query strings.
- Pre-fill from earlier answers or the account (WCAG 3.3.7).
- Start page: time estimate and what to have ready.
- Consistent layout on every step.
- Idempotent final submit: pending-disabled button plus an idempotency key.
- Confirmation page with a reference number. Clear drafts.

## Implementation Guidance

### Architecture decision table
| Approach | Data lives | Pros | Cons | Use for |
|---|---|---|---|---|
| **Next.js route per step + Server Actions + server draft** | DB/session | Works without JS, survives refresh/devices, clean funnel analytics, save-and-resume | More routes | Long/high-stakes applications |
| **Client RHF wizard + `?step=` via nuqs** | Memory (+ sessionStorage) | Instant validation, one `useForm`, Back works | Lost across devices; needs JS | In-app onboarding, quotes, Vite SPAs |
| **Single component, step in `useState`** | Memory | Simplest | Browser Back leaves flow; refresh loses data | 2–4 step dialogs only |

### Shared schemas and flow: `lib/schemas/apply.ts`
```tsx
import { z } from "zod";

export const aboutStep = z.object({
  fullName: z.string().trim().min(1, { error: "Enter your full name" }),
});
export const partnerStep = z.object({
  hasPartner: z.enum(["yes", "no"], { error: "Select yes if you have a partner" }),
});
export const partnerDetailsStep = z.object({
  partnerName: z.string().trim().min(1, { error: "Enter your partner's name" }),
});
export const incomeStep = z.object({
  income: z.string().trim().min(1, { error: "Enter your yearly income" })
    .pipe(z.coerce.number().min(0, { error: "Income must be 0 or more" })),
});

// Complete schema for final server validation (branch-aware)
export const applicationSchema = z.discriminatedUnion("hasPartner", [
  aboutStep.extend(incomeStep.shape).extend({ hasPartner: z.literal("no") }),
  aboutStep.extend(incomeStep.shape).extend(partnerDetailsStep.shape).extend({ hasPartner: z.literal("yes") }),
]);

export type Answers = Partial<z.input<typeof aboutStep> & z.input<typeof partnerStep>
  & z.input<typeof partnerDetailsStep> & z.input<typeof incomeStep>>;

export const STEP_IDS = ["about", "partner", "partner-details", "income", "check"] as const;
export type StepId = (typeof STEP_IDS)[number];

export const steps: Record<StepId, {
  title: string; schema: z.ZodObject | null; next: (a: Answers) => StepId | null;
}> = {
  about:             { title: "What is your full name?",  schema: aboutStep,          next: () => "partner" },
  partner:           { title: "Do you have a partner?",   schema: partnerStep,        next: (a) => (a.hasPartner === "yes" ? "partner-details" : "income") },
  "partner-details": { title: "What is your partner's name?", schema: partnerDetailsStep, next: () => "income" },
  income:            { title: "What is your yearly income?",  schema: incomeStep,     next: () => "check" },
  check:             { title: "Check your answers before sending your application", schema: null, next: () => null },
};

export function pathFor(a: Answers): StepId[] {
  const path: StepId[] = [];
  for (let s: StepId | null = "about"; s; s = steps[s].next(a)) path.push(s);
  return path;
}

export function pruneToPath(a: Answers): Answers {
  const keep = new Set(pathFor(a).flatMap((id) => Object.keys(steps[id].schema?.shape ?? {})));
  return Object.fromEntries(Object.entries(a).filter(([k]) => keep.has(k))) as Answers;
}
```
This module is pure: no `"use server"` and no DB imports. Both the Client Component wizard and the Server Actions import it.

### Variant A: client-side React Hook Form wizard (step in URL with nuqs)
```tsx
"use client";
import { useEffect, useRef } from "react";
import { FormProvider, useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { useRouter } from "next/navigation";
import { applicationSchema, pathFor, pruneToPath, steps, STEP_IDS, type Answers, type StepId } from "@/lib/schemas/apply";
import { submitApplication } from "./actions";

export function ApplyWizard({ idempotencyKey }: { idempotencyKey: string }) {
  const router = useRouter();
  const [step, setStep] = useQueryState("step",
    parseAsStringLiteral(STEP_IDS).withDefault("about").withOptions({ history: "push" }));  // Back button works
  const form = useForm<Answers>({
    defaultValues: { fullName: "", hasPartner: undefined, partnerName: "", income: "" },
    shouldUnregister: false,            // keep values of unmounted steps
  });
  const answers = useWatch({ control: form.control }) as Answers;
  const path = pathFor(answers);
  const headingRef = useRef<HTMLHeadingElement>(null);

  // Guard deep links to unreachable steps
  useEffect(() => { if (!path.includes(step)) void setStep(path[path.length - 1] === "check" ? "about" : path[0]); }, [step]);
  // Focus heading + title on step change
  useEffect(() => {
    headingRef.current?.focus();
    document.title = `${steps[step].title} – Step ${path.indexOf(step) + 1} of ${path.length} – Apply`;
  }, [step]);

  async function onContinue(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const current = steps[step];
    if (current.schema) {
      const result = current.schema.safeParse(form.getValues());       // validate THIS step only
      form.clearErrors();
      if (!result.success) {
        result.error.issues.forEach((i, idx) =>
          form.setError(i.path[0] as keyof Answers, { message: i.message }, { shouldFocus: idx === 0 }));
        return;
      }
    }
    const next = current.next(form.getValues());
    if (next) return void setStep(next);

    // Final submit: server re-validates everything
    const payload = pruneToPath(form.getValues());
    const res = await submitApplication(payload, idempotencyKey);
    if (res.ok) router.push(`/apply/confirmation?ref=${res.reference}`);
    else {
      const first = res.stepWithError;
      void setStep(first);
      Object.entries(res.fieldErrors).forEach(([k, v]) => v?.[0] && form.setError(k as keyof Answers, { message: v[0] }));
    }
  }

  const back = () => { const i = path.indexOf(step); if (i > 0) void setStep(path[i - 1]); };

  return (
    <FormProvider {...form}>
      <form onSubmit={onContinue} noValidate className="max-w-xl">
        {step !== "about" && <button type="button" onClick={back} className="underline">Back</button>}
        <p className="text-muted-foreground">Step {path.indexOf(step) + 1} of {path.length}</p>
        <h1 ref={headingRef} tabIndex={-1}>{steps[step].title}</h1>
        <StepFields step={step} />
        <SubmitButton final={step === "check"} pending={form.formState.isSubmitting} />
      </form>
    </FormProvider>
  );
}

function SubmitButton({ final, pending }: { final: boolean; pending: boolean }) {
  return <button type="submit" disabled={pending}>{final ? (pending ? "Sending…" : "Accept and send") : "Continue"}</button>;
}
declare function StepFields(props: { step: StepId }): React.JSX.Element;
```
Why a single `<form onSubmit>` per rendered step: pressing Enter in a field triggers Continue rather than a full submit. Per-step `safeParse` avoids surfacing future-step errors. For the heading-as-label pattern on single-question steps, render the `<label>` inside the `<h1>`.

### Variant B: Next.js route per step with Server Actions + `useActionState` / `useFormStatus`
```tsx
// app/apply/[step]/page.tsx  (Server Component)
import { notFound, redirect } from "next/navigation";
import { pathFor, steps, STEP_IDS, type StepId } from "@/lib/schemas/apply";
import { getDraft } from "@/lib/drafts";
import { StepForm } from "./step-form";
import { CheckAnswers } from "./check-answers";

export default async function StepPage({ params, searchParams }: {
  params: Promise<{ step: string }>; searchParams: Promise<{ returnTo?: string }>;
}) {
  const { step } = await params;
  const { returnTo } = await searchParams;
  if (!STEP_IDS.includes(step as StepId)) notFound();
  const draft = await getDraft();                              // authorized to current user/session
  const path = pathFor(draft);
  if (!path.includes(step as StepId)) redirect(`/apply/${path[0]}`); // guard unreachable steps
  const index = path.indexOf(step as StepId);
  return step === "check"
    ? <CheckAnswers draft={draft} />
    : <StepForm step={step as Exclude<StepId, "check">} defaults={draft} caption={`Step ${index + 1} of ${path.length}`}
        title={steps[step as StepId].title} returnTo={returnTo === "check" ? "check" : undefined} />;
}
```
```tsx
// app/apply/[step]/actions.ts
"use server";
import { z } from "zod";
import { redirect } from "next/navigation";
import { applicationSchema, pathFor, pruneToPath, steps, type Answers, type StepId } from "@/lib/schemas/apply";
import { getDraft, saveDraft, clearDraft } from "@/lib/drafts";

export type StepState = { status: "idle" } | { status: "error"; values: Answers; fieldErrors: Record<string, string[] | undefined> };

export async function saveStep(step: StepId, returnTo: "check" | undefined, _prev: StepState, fd: FormData): Promise<StepState> {
  const schema = steps[step].schema!;
  const values = Object.fromEntries(fd) as Answers;
  const parsed = schema.safeParse(values);                      // server validates the step
  if (!parsed.success) return { status: "error", values, fieldErrors: z.flattenError(parsed.error).fieldErrors };
  const draft = await saveDraft(values);                        // store raw step input; merge into draft
  const next = steps[step].next(draft);
  const branchStillComplete = pathFor(draft).every((id) => !steps[id].schema || steps[id].schema!.safeParse(draft).success);
  redirect(returnTo === "check" && branchStillComplete ? "/apply/check" : `/apply/${next}${returnTo ? "?returnTo=check" : ""}`);
}

// Final submit: whole payload, pruned, idempotent. Also used by Variant A.
export async function submitApplication(input?: Answers, idempotencyKey?: string) {
  const answers = pruneToPath(input ?? (await getDraft()));
  const parsed = applicationSchema.safeParse(answers);
  if (!parsed.success) {
    const fieldErrors = z.flattenError(parsed.error).fieldErrors as Record<string, string[] | undefined>;
    const stepWithError = pathFor(answers).find((id) => steps[id].schema && !steps[id].schema!.safeParse(answers).success) ?? "about";
    return { ok: false as const, fieldErrors, stepWithError };
  }
  const reference = await createApplication(parsed.data, idempotencyKey);
  await clearDraft();
  return { ok: true as const, reference };
}

export async function submitApplicationAction(key: string) {
  const res = await submitApplication(undefined, key);
  redirect(res.ok ? `/apply/confirmation?ref=${res.reference}` : `/apply/${res.stepWithError}`);
}
declare function createApplication(data: z.output<typeof applicationSchema>, key?: string): Promise<string>;
```
```tsx
// app/apply/[step]/step-form.tsx
"use client";
import { useActionState, useEffect, useRef } from "react";
import { useFormStatus } from "react-dom";
import Link from "next/link";
import { saveStep, type StepState } from "./actions";
import type { Answers, StepId } from "@/lib/schemas/apply";

function ContinueButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending}>{pending ? "Saving…" : "Continue"}</button>;
}

export function StepForm({ step, defaults, caption, title, returnTo }: {
  step: Exclude<StepId, "check">; defaults: Answers; caption: string; title: string; returnTo?: "check";
}) {
  const [state, formAction] = useActionState<StepState, FormData>(saveStep.bind(null, step, returnTo), { status: "idle" });
  const summaryRef = useRef<HTMLDivElement>(null);
  const values = state.status === "error" ? { ...defaults, ...state.values } : defaults;
  const fe = state.status === "error" ? state.fieldErrors : {};
  useEffect(() => {
    if (state.status === "error") {
      summaryRef.current?.focus();
      document.title = `Error: ${title}`;
    }
  }, [state, title]);

  return (
    <form action={formAction} noValidate className="max-w-xl">
      <Link href="/apply" className="underline">Back</Link>  {/* or previous step on the path */}
      {state.status === "error" && (
        <div ref={summaryRef} tabIndex={-1} role="alert"><h2>There is a problem</h2>
          <ul>{Object.entries(fe).map(([k, m]) => m?.[0] && <li key={k}><a href={`#${k}`}>{m[0]}</a></li>)}</ul>
        </div>
      )}
      <p className="text-muted-foreground">{caption}</p>
      {step === "partner" ? (
        <fieldset aria-describedby={fe.hasPartner ? "hasPartner-error" : undefined}>
          <legend><h1>{title}</h1></legend>
          {fe.hasPartner && <p id="hasPartner-error" className="text-red-700"><span className="sr-only">Error: </span>{fe.hasPartner[0]}</p>}
          <label><input id="hasPartner" type="radio" name="hasPartner" value="yes" defaultChecked={values.hasPartner === "yes"} /> Yes</label>
          <label><input type="radio" name="hasPartner" value="no" defaultChecked={values.hasPartner === "no"} /> No</label>
        </fieldset>
      ) : (
        <StepTextField step={step} title={title} values={values} fieldErrors={fe} />
      )}
      <ContinueButton />
    </form>
  );
}
declare function StepTextField(p: { step: StepId; title: string; values: Answers; fieldErrors: Record<string, string[] | undefined> }): React.JSX.Element;
```
With route-per-step, each Continue is a real navigation (`redirect`). Next.js App Router doesn't move focus to the new heading on client navigation by default, so focus the `<h1>` on mount (a small client `FocusHeading` component) or rely on the route announcer. The flow works without JS because each step is a native form POST.

### Check answers (Server Component + final action)
```tsx
// app/apply/[step]/check-answers.tsx
import Link from "next/link";
import { randomUUID } from "node:crypto";
import { pathFor, type Answers } from "@/lib/schemas/apply";
import { submitApplicationAction } from "./actions";
import { FinalSubmitButton } from "./final-submit-button"; // "use client" + useFormStatus

const rows: { key: keyof Answers; label: string; step: string }[] = [
  { key: "fullName", label: "Full name", step: "about" },
  { key: "hasPartner", label: "Partner", step: "partner" },
  { key: "partnerName", label: "Partner's name", step: "partner-details" },
  { key: "income", label: "Yearly income", step: "income" },
];

export function CheckAnswers({ draft }: { draft: Answers }) {
  const path = pathFor(draft);
  return (
    <>
      <h1>Check your answers before sending your application</h1>
      <dl>
        {rows.filter((r) => path.includes(r.step as never)).map((r) => (
          <div key={r.key} className="grid grid-cols-[1fr_2fr_auto] gap-4 border-b py-2">
            <dt className="font-semibold">{r.label}</dt>
            <dd>{String(draft[r.key] ?? "")}</dd>
            <dd><Link href={`/apply/${r.step}?returnTo=check`}>Change<span className="sr-only"> {r.label.toLowerCase()}</span></Link></dd>
          </div>
        ))}
      </dl>
      <form action={submitApplicationAction.bind(null, randomUUID())}>
        <FinalSubmitButton>Accept and send</FinalSubmitButton>
      </form>
    </>
  );
}
```
Generating the idempotency key at render means a page refresh creates a new key. For stricter guarantees, store the key on the draft.

## Recommended Workflow
1. Confirm a wizard is appropriate. If not, use one page with sections.
2. Map the flow graph: steps, branch conditions, review and confirmation.
3. Choose Variant A (client RHF + nuqs) or Variant B (route per step + Server Actions). Default to B for long or high-stakes flows.
4. Write `lib/schemas/<flow>.ts`: per-step schemas, a branch-aware complete schema, `steps` config, `pathFor` and `pruneToPath`.
5. Build one step template: caption, heading-as-label, fields, Continue, Back.
6. Implement next/back, guards for unreachable steps, and persistence (server draft or sessionStorage).
7. Add heading focus and title updates per step, plus an error summary for step errors.
8. Build check answers with Change and return, then a final submit with full server validation, pruning, idempotency and a confirmation page.
9. Instrument per-step drop-off. Test Back/Forward, refresh, deep links, branch changes, keyboard, screen reader and JS-disabled (Variant B).

## Patterns
- **Question page:** one question, `<h1>` inside `<label>`/`<legend>`, Continue.
- **Task list (hub-and-spoke):** for very long applications, a task list page with section statuses ("Not started / In progress / Completed"). Each section is a mini wizard (GOV.UK "Complete multiple tasks").
- **Check answers + Change and return:** `?returnTo=check`. If a change opens a new branch, walk the new steps first.
- **Stepper indicator:** `<ol aria-label="Progress">` with `aria-current="step"` and visually hidden state text. Make it non-interactive, or link only completed steps.
- **Draft autosave (Variant A):** RHF `subscribe` writes to `sessionStorage` (non-PII) or a debounced Server Action, with a `role="status"` "Saved" message.
- **Branch pruning:** `pruneToPath(answers)` before final validation.
- **Dialog wizard (2–4 steps):** step in `useState`, focus trapped in the dialog, heading focused per step, confirm before closing if dirty. See [accessible-dialogs](../accessible-dialogs/Skill.md).

## Anti-Patterns
| Anti-pattern | Problem | Fix |
|---|---|---|
| `trigger()` on the full resolver schema at step 1 | Errors for fields not shown | Per-step `safeParse` or `trigger(stepFields)` |
| Step only in `useState` for long flows | Browser Back exits, refresh loses data | nuqs `?step=` or route per step |
| Clickable progress tracker that jumps ahead | Skips required steps | "Step X of Y" caption |
| Back validates | Traps users | Back never validates |
| Hidden-branch answers submitted | Inconsistent data | `pruneToPath` + discriminated union |
| Only per-step client validation | Bypassable | Server validates each step and the whole payload |
| Schema duplicated in actions and components | Drift | Shared `lib/schemas` module |
| Focus left on stale element after step change | Screen reader unaware | Focus `<h1>`, update title |
| PII drafts in localStorage or query string | Leaks on shared devices/logs | Server drafts |
| Wizard for frequent expert tasks | Tedious (NN/g) | Single page with sections |
| Change on review re-walks all later steps | Frustrating | Return to check answers |
| No idempotency on final submit | Duplicate records | Pending-disabled button + idempotency key |

## Accessibility
- On step change, focus the step `<h1>` (`tabIndex={-1}`) and update `document.title` ("Your income – Step 3 of 5 – Apply").
- The heading doubles as the label or legend for single-question steps.
- Steppers use `<ol>` with `aria-current="step"` and text states. Don't show completion by colour alone (1.4.1).
- Step errors follow [form-validation-patterns](../form-validation-patterns/Skill.md): error summary, "Error:" title prefix, focus.
- **WCAG 3.3.4:** review step before commit. **3.3.7:** don't re-ask. **2.2.1 Timing Adjustable:** warn before session or draft expiry and allow extension.
- Enter submits the current step. Back is a real link or button.
- Announce autosave via `role="status"`.
- See [focus-management](../focus-management/Skill.md) and [accessible-spa-routing](../accessible-spa-routing/Skill.md).

## Responsive Design
- Collapse steppers to "Step 3 of 6: Income" on small screens. Don't use horizontally scrolling steppers.
- Keep Continue in normal flow after the fields, not a fixed footer covering inputs when the keyboard is open.
- Scroll to top on step change (heading focus does this). Put checkout-style context panels in a disclosure on mobile.

## Performance
- Variant B: each step is a small server-rendered page, and Continue is a native POST with `redirect`, so little client JS ships. Use `next/dynamic` for heavy steps (file upload, payment SDK).
- Variant A: lazy-load step components with `React.lazy`/`next/dynamic`, keep one RHF instance, and use `useWatch` only where needed.
- Prefetch the next step route (`<Link prefetch>` or `router.prefetch`) once the current step is valid.
- Debounce autosave and send only the changed step's fields.

## Security
- Re-validate every step in its Server Action and the complete pruned payload at final submit. Never trust client-computed paths or prices.
- Guard unreachable steps server-side (redirect). Authorize drafts to their owner or session.
- Resume links must be unguessable, expiring and re-authenticated for sensitive data.
- Use idempotency keys for final submission and payments.
- Keep answers out of query strings. Only the step id belongs in the URL.

## Testing
- **Unit (Vitest):** `pathFor` for all branch combinations, `pruneToPath`, per-step schemas and `applicationSchema`.
- **Server Actions:** call `saveStep` with FormData and assert errors or the redirect target (mock `redirect`, drafts). Test `submitApplication` with stale hidden-branch data and assert pruning.
- **Component (Testing Library):** Continue on an empty step shows only that step's errors, Back preserves values, the heading receives focus, and the caption updates.
- **E2E (Playwright):** happy path; branch change via check answers; browser back/forward; refresh mid-flow; deep link to a later step redirects; double-click final submit gives one record; Variant B with `javaScriptEnabled: false`.
- **Accessibility:** axe on each step and error state, plus a screen reader check of step announcements.
- **Analytics:** per-step funnel.

## Tooling
- **React Hook Form 7.88.x + Zod 4.6.x** (MIT, active): per-step validation and FormProvider.
- **nuqs** (MIT, active): type-safe `?step=` state with push history in Next.js and React SPAs. See [react-url-state-nuqs](../react-url-state-nuqs/Skill.md).
- **Next.js Server Actions + React 19 `useActionState`/`useFormStatus`** (active).
- **XState / Stately** (MIT, active): explicit state machines when the branching graph grows complex.
- **Zustand** with `persist` to sessionStorage (MIT, active): client step stores in Vite SPAs.
- **Stepper UIs:** shadcn/ui community stepper blocks, Mantine `Stepper`, MUI `Stepper`. Verify `aria-current` support and non-interactive defaults.

## Framework Notes
- **React (Vite SPA):**
  - Use Variant A with nuqs (React SPA adapter) or React Router search params for the step.
  - Persist drafts to your API (shared schema validates each PATCH) or sessionStorage.
  - Final submit posts the pruned payload, and the API re-validates with `applicationSchema`.
- **Next.js (App Router):**
  - Variant B uses `app/apply/[step]/page.tsx` (Server Component guard + draft load), `actions.ts` (step and final Server Actions), and client `StepForm` with `useActionState`/`useFormStatus`.
  - A shared `layout.tsx` can hold the caption or back link.
  - Variant A is a Client Component with nuqs (`NuqsAdapter` in the root layout) calling the same `submitApplication` action.
  - `params`/`searchParams` are Promises in current Next.js page props, so await them.

## AI Agent Guidance
- **Do:**
  - Confirm a wizard is warranted.
  - Create `lib/schemas/<flow>.ts` with per-step schemas, the complete schema, `steps`, `pathFor` and `pruneToPath`.
  - Put the step in the URL and validate only the current step client-side.
  - Validate each step in Server Actions and the whole pruned payload at the end.
  - Focus the heading and update the title per step.
  - Build check answers with return, and use idempotent final submit.
- **Don't:**
  - build jump-ahead trackers
  - validate future steps
  - let Back validate
  - store PII drafts in localStorage or URLs
  - duplicate schemas
  - skip server validation
- **Verify before done:**
  1. Browser Back/Forward and refresh keep answers.
  2. A deep link to a later step redirects.
  3. Changing a branch on review routes through new steps and back.
  4. The final payload contains no off-path answers.
  5. Double submit gives one record.
  6. The screen reader announces the new step heading.
  7. Variant B completes with JS disabled.
  8. axe passes on each step.

## Examples
```tsx
// Accessible, non-interactive stepper
export function Steps({ names, current }: { names: string[]; current: number }) {
  return (
    <ol aria-label="Progress" className="flex flex-col gap-1 sm:flex-row sm:gap-4">
      {names.map((n, i) => (
        <li key={n} aria-current={i === current ? "step" : undefined}
            className={i === current ? "font-bold" : i < current ? "text-foreground" : "text-muted-foreground"}>
          <span className="sr-only">{i < current ? "Completed: " : i === current ? "Current: " : "Not started: "}</span>
          {n}
        </li>
      ))}
    </ol>
  );
}
```

```tsx
// Focus the step heading after route-per-step navigation (Next.js)
"use client";
import { useEffect, useRef } from "react";
export function FocusHeading({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLHeadingElement>(null);
  useEffect(() => { ref.current?.focus(); }, []);
  return <h1 ref={ref} tabIndex={-1} className="outline-none">{children}</h1>;
}
```

```tsx
// Final submit button with pending state (used in check answers)
"use client";
import { useFormStatus } from "react-dom";
export function FinalSubmitButton({ children }: { children: React.ReactNode }) {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending}>{pending ? "Sending application…" : children}</button>;
}
```

## Related Skills
- [form-design-ux](../form-design-ux/Skill.md): field design within each step
- [form-validation-patterns](../form-validation-patterns/Skill.md): per-step error handling
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md): RHF and shared schemas
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): step persistence and security
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md): useActionState/useFormStatus
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): step in URL
- [progressive-enhancement](../progressive-enhancement/Skill.md): wizards that work without JS
- [buttons-and-actions](../buttons-and-actions/Skill.md): Continue/Back and pending states
- [checkout-flow-design](../checkout-flow-design/Skill.md): multi-step checkout
- [onboarding-ux](../onboarding-ux/Skill.md): onboarding flows
- [user-flow-design](../user-flow-design/Skill.md): mapping branches
- [focus-management](../focus-management/Skill.md): focus on step change
- [accessible-spa-routing](../accessible-spa-routing/Skill.md): route-change announcements
- [nextjs-database-integration](../nextjs-database-integration/Skill.md): server-side drafts

## Sources
- [NN/g: Wizards: Definition and Design Recommendations](https://www.nngroup.com/articles/wizards/) — Community (research) — when to use/avoid, step labels, save progress, self-sufficient steps
- [GOV.UK Design System: Question pages](https://design-system.service.gov.uk/patterns/question-pages/) — Official — one thing per page, back link, Continue, heading-as-label, against complex progress indicators
- [GOV.UK Design System: Check answers](https://design-system.service.gov.uk/patterns/check-answers/) — Official — summary list, Change links with hidden text, return to check answers
- [GOV.UK Design System: Validation](https://design-system.service.gov.uk/patterns/validation/) — Official — per-page validation and error summary
- [React: useActionState](https://react.dev/reference/react/useActionState) — Official — action state and pending
- [Zod 4 changelog](https://zod.dev/v4/changelog) — Official — error API, extend (merge deprecated), flattenError
- [@hookform/resolvers](https://github.com/react-hook-form/resolvers) — Open Source — typing with Zod 4
- [W3C WAI: Form notifications](https://www.w3.org/WAI/tutorials/forms/notifications/) — Official — title updates and error lists

## License / Usage Notes
GOV.UK Design System guidance is under OGL v3 (code MIT). NN/g content is summarized only. React, Next.js, RHF, Zod, nuqs, XState and Zustand are MIT. Code is original.

## Quality Tier
A — Strong convergence between GOV.UK and NN/g, with complete client and Server Action implementations sharing one schema. The nuqs option names and the Zod 4 `z.ZodObject` generic usage were not re-fetched this cycle, so check them against installed versions.

## Status
Active

## Last Verified
2026-09-15
