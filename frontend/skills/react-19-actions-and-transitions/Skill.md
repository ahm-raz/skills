# React 19 Actions and Transitions

## Summary
React 19 introduced **Actions**: async functions run inside transitions that manage pending state, errors, optimistic updates and form resets for you. The APIs are `useTransition` (async `startTransition`), `useActionState`, `useOptimistic`, `useFormStatus` (react-dom), `<form action={fn}>`, `requestFormReset`, and, with Next.js, Server Actions (Server Functions). This skill shows how to build mutations and forms the React 19 way, and when to still use a form library.

## Category
React

## Subcategories
useTransition, startTransition, useActionState, useOptimistic, useFormStatus, form actions, Server Actions, requestFormReset, useDeferredValue, pending UI

## Problem It Solves
Hand-managed `isSubmitting`/`error` state, double submits, forms that don't work before hydration, flicker between the optimistic and confirmed state, and UIs that freeze during expensive updates.

## When To Use
- Form submissions and mutations in React 19+ (especially Next.js with Server Actions).
- Buttons that trigger async work (like, follow, delete) and need pending or optimistic feedback.
- Keeping the UI responsive during expensive re-renders (tab switches, filtering).

## When Not To Use
- Complex client-side forms with field-level validation, arrays or wizards: use React Hook Form + Zod (and call the action from `handleSubmit`).
- Client-cache-driven apps (Vite SPA + TanStack Query) where `useMutation` already provides pending, error and optimistic handling. You can still combine the two.
- Urgent updates that must reflect immediately (typing into a controlled input). Never wrap those in transitions.

## Core Principles
1. **An Action is any function called inside a transition**, including async ones. React tracks pending state for its whole duration.
2. **Transitions are non-blocking**: already visible content stays up (no Suspense fallback flash), and urgent updates can interrupt.
3. **`useActionState` owns the result state of an action**: previous state in, next state out, plus `isPending`.
4. **`useOptimistic` shows temporary state while an Action is pending**, and automatically reverts to the real state when it settles.
5. **Forms with `action={fn}` progressively enhance** when `fn` is a Server Action (they work before hydration in Next.js) and reset uncontrolled fields automatically on success.
6. **Server Actions are public endpoints**: validate and authorize on the server every time.

## Best Practices
- Return serializable, typed result objects (`{ ok: false, fieldErrors }`) from actions for expected errors. Throw only for unexpected ones (caught by error boundaries).
- Use `useFormStatus` in a **child** component of the `<form>` (it reads the parent form's status). Typical use: a submit button.
- After an `await` inside `startTransition`, wrap subsequent `setState` calls in another `startTransition`. This is a known React 19 limitation: state updates after `await` aren't automatically part of the transition.
- Keep inputs uncontrolled (`name`, `defaultValue`) with form actions to benefit from automatic reset and progressive enhancement. Use `defaultValue={state.values?.email}` to repopulate after validation errors.
- Use `permalink` (the third argument of `useActionState`) when a form may submit before hydration and should navigate to the right page.
- Show pending state on the control that started the action and disable double submission (`disabled={pending}`), while keeping the button focusable or announcing progress.

## Implementation Guidance
**API chooser**

| Need | API |
|---|---|
| Pending flag for any async update / avoid fallback flash | `useTransition` → `[isPending, startTransition]` |
| Form result state (errors, messages) + pending | `useActionState(action, initialState, permalink?)` |
| Submit button pending inside a form | `useFormStatus()` from `react-dom` |
| Instant UI while action runs | `useOptimistic(state, reducer?)` |
| Lag an expensive render behind fast input | `useDeferredValue(value, initialValue?)` |
| Reset a form imperatively inside a transition | `requestFormReset(formEl)` from `react-dom` |
| Mark update non-urgent outside components | `startTransition` from `react` |

**useActionState + Server Action (Next.js)**
```ts
// app/signup/actions.ts
"use server";
import { z } from "zod";
export type SignupState = { ok: boolean; fieldErrors?: Record<string, string[]>; values?: { email?: string } };
const Schema = z.object({ email: z.string().email(), password: z.string().min(12) });

export async function signup(_prev: SignupState, formData: FormData): Promise<SignupState> {
  const parsed = Schema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { ok: false, fieldErrors: parsed.error.flatten().fieldErrors, values: { email: String(formData.get("email") ?? "") } };
  }
  await createUser(parsed.data); // server-side authz/rate limit inside
  return { ok: true };
}
```
```tsx
// app/signup/signup-form.tsx
"use client";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { signup, type SignupState } from "./actions";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} aria-disabled={pending}>{pending ? "Creating…" : "Create account"}</button>;
}

export function SignupForm() {
  const [state, formAction] = useActionState<SignupState, FormData>(signup, { ok: false });
  return (
    <form action={formAction} noValidate>
      <label htmlFor="email">Email</label>
      <input id="email" name="email" type="email" defaultValue={state.values?.email}
        aria-invalid={!!state.fieldErrors?.email} aria-describedby="email-error" />
      <p id="email-error" role="alert">{state.fieldErrors?.email?.[0]}</p>
      <label htmlFor="password">Password</label>
      <input id="password" name="password" type="password" />
      <SubmitButton />
      {state.ok && <p role="status">Account created.</p>}
    </form>
  );
}
```

**useOptimistic**
```tsx
"use client";
import { useOptimistic, startTransition } from "react";
export function LikeButton({ liked, count, toggleLike }: { liked: boolean; count: number; toggleLike: () => Promise<void> }) {
  const [optimistic, setOptimistic] = useOptimistic({ liked, count });
  return (
    <button aria-pressed={optimistic.liked}
      onClick={() => startTransition(async () => {
        setOptimistic((s) => ({ liked: !s.liked, count: s.count + (s.liked ? -1 : 1) }));
        await toggleLike(); // Server Action; revalidation brings real props
      })}>
      ♥ {optimistic.count}
    </button>
  );
}
```

**Async transition with post-await update**
```ts
startTransition(async () => {
  const result = await saveDraft(draft);
  startTransition(() => { setSavedAt(result.savedAt); }); // re-wrap after await
});
```

## Recommended Workflow
1. Define the server mutation (Server Action or API) with validation and authorization.
2. Decide the result shape (success, field errors, message).
3. Build the form with uncontrolled inputs + `useActionState`. Add a `useFormStatus` submit button.
4. Add `useOptimistic` for interactions where latency is visible.
5. Revalidate server data (`revalidatePath`/`revalidateTag`) or invalidate the client cache.
6. Test with JS disabled (Server Actions) and with slow or failed responses.

## Patterns
- **Optimistic list append**: `useOptimistic(messages, (list, msg: Msg) => [...list, { ...msg, sending: true }])`.
- **Non-form action button**: `<button formAction={deleteItem}>` inside a form, or `startTransition(() => deleteItem(id))`.
- **Tab switch without fallback**: `startTransition(() => setTab(next))` + `isPending` dimming.
- **Search with deferred rendering**: `useDeferredValue(query)` for the result list.
- **Form library bridge**: React Hook Form `handleSubmit((values) => startTransition(() => serverAction(values)))`.

## Anti-Patterns
- **Manual `isSubmitting` state with `useState` + try/finally** in React 19 apps. Fix: `useActionState` or `useTransition`.
- **`useFormStatus` in the same component that renders `<form>`**: always not pending. Fix: move it into a child.
- **Wrapping controlled input `setValue` in `startTransition`**: typing lags. Fix: keep the input urgent and defer the consumers.
- **Throwing for validation errors from actions**: error boundary screens. Fix: return field errors.
- **Trusting `formData` shape**: security hole. Fix: schema-validate on the server.
- **Calling `setOptimistic` outside a transition or action**: React warns and it reverts immediately. Fix: call inside `startTransition` or a form action.
- **Catching `redirect()` inside a Server Action try/catch**: navigation silently fails. Fix: call `redirect` after try/catch.

## Accessibility
- Associate errors with inputs (`aria-describedby`, `aria-invalid`). Announce form-level results with `role="status"`/`role="alert"` (WCAG 3.3.1, 4.1.3).
- On a failed submit, move focus to the first invalid field or an error summary.
- Pending buttons: prefer `aria-disabled` + ignoring clicks over `disabled` if you need them to stay focusable, and communicate progress text.
- Optimistic toggles must update `aria-pressed`/`aria-checked` immediately and revert accessibly on failure (announce the error).

## Responsive Design
- Keep pending indicators visible near the touch target on mobile (not only in a distant toast).
- Long forms on mobile: after a failed submit, scroll the first error into view along with focus.

## Performance
- Transitions improve INP by letting React yield during expensive renders. React 19.3 renders independent transitions separately.
- Server Actions avoid shipping mutation logic and validation libraries to the client. Validate on the client only for UX.
- Optimistic updates remove perceived latency without extra requests.

## Security
- Server Actions: authenticate, authorize, validate, rate limit. They're callable with crafted POST requests.
- Next.js checks Origin against Host for Server Actions. Configure `serverActions.allowedOrigins` carefully behind proxies.
- Never return secrets or entire DB rows in action state, since it's serialized to the client.
- Keep React and Next.js patched (the Dec 2025 RSC/Server Function CVEs affected Server Function endpoints).

## Testing
- Unit test Server Actions as plain functions with `FormData` inputs, covering invalid, unauthorized and success cases.
- Component tests: mock the action, submit via `userEvent`, and assert pending text, then result or error UI.
- Playwright: test progressive enhancement (`javaScriptEnabled: false`) for critical forms, plus slow-network optimistic behaviour.

## Tooling
- React 19.x (`useActionState`, `useOptimistic` in `react`; `useFormStatus`, `requestFormReset` in `react-dom`).
- Zod / Valibot for server validation.
- `next-safe-action` (community) for typed and validated Server Action wrappers.
- Deprecated: `useFormState` from `react-dom` (Canary name), renamed to `useActionState` in React 19 stable.

## Framework Notes
### React (Vite SPA)
- There are no Server Actions. `<form action={async (formData) => { await api.post(...) }}>` still works client-side, with pending via `useFormStatus` and reset on success.
- With TanStack Query, prefer `useMutation` for cache invalidation. Use `useTransition` to avoid fallback flashes when mutation results trigger Suspense.

### Next.js App Router
- Server Actions are defined with `"use server"` (module-level file, or inline in a Server Component) and passed to Client Components as props or imported directly.
- `<form action={serverAction}>` works before hydration (progressive enhancement). `useActionState`'s `permalink` helps when the form is on a different page than the result.
- After mutations: `revalidatePath("/items")`, `revalidateTag("items")` (or the Next.js 16 cache tag APIs), or `redirect("/items/123")`. The response includes the updated RSC payload in the same round trip.
- Server Actions run sequentially per client and use POST. Don't use them for data fetching. Fetch in Server Components or route handlers.
- React 19.3 fires `onReset` when React auto-resets a form after a Server Action, which is useful for resetting client-side widget state.

## AI Agent Guidance
- Check the `react` version (≥19) before using these hooks, and never import `useFormState` in new code.
- Generate server-side validation and authorization in every Server Action. Return typed state for expected errors.
- Put `useFormStatus` in a child component. Re-wrap `setState` after `await` in `startTransition`.
- Verify: double-submit prevented, errors announced and focused, optimistic state reverts on failure, the form works with JS disabled (Next.js), and data revalidates.

## Examples
```tsx
// Optimistic todo add with Server Action + revalidation
"use client";
import { useOptimistic, useRef } from "react";
export function Todos({ todos, addTodo }: { todos: Todo[]; addTodo: (fd: FormData) => Promise<void> }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [optimisticTodos, addOptimistic] = useOptimistic(todos, (list, title: string) => [...list, { id: `tmp-${title}`, title, pending: true }]);
  return (
    <>
      <ul>{optimisticTodos.map((t) => <li key={t.id} aria-busy={"pending" in t}>{t.title}</li>)}</ul>
      <form ref={formRef} action={async (fd) => { addOptimistic(String(fd.get("title"))); await addTodo(fd); }}>
        <label htmlFor="title">New todo</label>
        <input id="title" name="title" required />
        <button type="submit">Add</button>
      </form>
    </>
  );
}
```

## Related Skills
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): Next.js Server Action specifics
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md): complex client forms
- [optimistic-ui](../optimistic-ui/Skill.md): optimistic UX design
- [form-validation-patterns](../form-validation-patterns/Skill.md): validation strategy
- [accessible-forms](../accessible-forms/Skill.md): error announcement and focus
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md): transitions vs fallbacks
- [progressive-enhancement](../progressive-enhancement/Skill.md): forms without JS

## Sources
- [React 19 release post](https://react.dev/blog/2024/12/05/react-19) (Official): Actions, useActionState, useOptimistic, useFormStatus, form actions
- [react.dev: useTransition / useActionState / useOptimistic references](https://react.dev/reference/react/useActionState) (Official): signatures, caveats (post-await updates)
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): independent transitions, onReset after auto reset, submitter in submit events
- [Next.js docs: Updating Data (Server Actions)](https://nextjs.org/docs/app/getting-started/updating-data) (Official): revalidation, progressive enhancement
- [vercel-labs agent-skills react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) (Community/Open Source): server-auth-actions, rerender-transitions, rendering-usetransition-loading

## License / Usage Notes
React/Next.js docs are MIT/CC-BY-4.0. Vercel agent-skills is MIT. This is a summary with original examples.

## Quality Tier
S: official React 19.x and Next.js sources, with current caveats and security posture.

## Status
Active

## Last Verified
2026-09-15
