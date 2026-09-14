# Progressive Enhancement in React and Next.js

## Summary
Progressive enhancement (PE) means the core task (read, navigate, search, submit, buy) works from server-rendered HTML with links and forms, and JavaScript improves it once loaded. In Next.js 16 / React 19 this is achieved with Server Components, `<form action={serverAction}>`, `useActionState` (with permalinks), `useFormStatus`, `next/form` for GET search forms, and URL-driven state. This skill gives the rules, a per-feature decision table, and tests that prove forms work before hydration and when JS fails.

## Category
Next.js

## Subcategories
Server Actions forms, useActionState, next/form, pre-hydration interactivity, no-JS fallbacks, server validation, resilience testing

## Problem It Solves
JavaScript fails or arrives late: slow mobile networks, bundle errors, blocked CDNs, extensions, and the pre-hydration window where the page looks ready but `onClick` handlers do nothing. `onSubmit`/`onClick`-only React UIs lose submissions and users in that window. Next.js can make critical flows work without JS, but only if components are written for it.

## When To Use
- Sign-up, login, checkout, contact, search, filters, newsletter, comments, settings forms.
- Public pages where mobile users on slow networks matter (commerce, content, government, marketing).
- Any SSR/SSG page with interactive controls that users hit early.

## When Not To Use
- Inherently client-side tools (canvas editors, real-time collaboration, maps-first apps): provide clear messaging instead of a fake baseline.
- Vite SPAs with no server rendering: there is no HTML baseline to enhance (consider React Router framework mode or Next.js if PE matters; see [vite-react-spa](../vite-react-spa/Skill.md)).
- Purely decorative interactions (hover previews, animations) — these are enhancements by nature.

## Core Principles
1. Mutations are `<form>`s whose `action` is a Server Action; navigation is `<Link>`/`<a href>`; search/filter is a GET form. Never `onClick`-only for core tasks.
2. The server is authoritative: validate, authorize, and return errors from the action; client validation is additive.
3. State that must survive reload or no-JS lives in the URL (search params) or on the server, not in `useState`.
4. Enhance native behavior (`useActionState`, `useOptimistic`, `useFormStatus`) rather than replacing it with `fetch` in `onSubmit` + `preventDefault`.
5. Every field needs a `name` attribute, because `FormData` is the contract.
6. Keep the default render useful: no content hidden until JS runs; no disabled-until-hydrated core buttons.
7. Test the baseline automatically (JS disabled, JS blocked, slow network clicks before hydration).

## Best Practices
- Define forms in Server Components where possible: a `<form action={serverAction}>` rendered by a Server Component submits as a normal POST before/without JS.
- In Client Components, use `useActionState(action, initialState, permalink?)`. With a Server Function, React can show the server's response even before hydration; pass `permalink` when the form lives on a dynamic page so the no-JS submission navigates to the right URL.
- Return serializable, minimal state from actions: `{ ok, fieldErrors, values }`. Echo `values` back as `defaultValue` so the no-JS re-render keeps user input.
- Use `redirect()` after successful mutations (Post/Redirect/Get), and `revalidatePath`/`revalidateTag` (or `updateTag` for read-your-own-writes) before redirecting.
- Pass extra arguments with `action.bind(null, id)` (works with PE) rather than closures in `onClick`.
- Use hidden inputs for non-sensitive context; never for authorization decisions.
- Use `next/form` (`import Form from 'next/form'`) with a string `action="/search"` for GET search forms: client-side navigation with JS, standard GET without.
- Use HTML validation attributes (`required`, `type`, `min`, `maxLength`, `pattern`, `autocomplete`) for instant feedback without JS.
- Use `<button type="submit" name="intent" value="archive">` or `formAction={otherAction}` for multiple actions in one form.
- Use native disclosure (`<details>`), `<dialog>` with `command`/`commandfor` (where supported), and `popover` for UI that should function before hydration.
- Prefer URL state for filters/tabs/pagination via GET forms and links (see [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) for the enhanced layer).

## Implementation Guidance

### Decision table: does this control work before JS?
| UI | PE-safe implementation | Not PE-safe |
|---|---|---|
| Create/update/delete | `<form action={serverAction}>` | `<button onClick={() => fetch(...)}>` |
| Search | `<Form action="/search">` (next/form) with `name="q"` | `onChange` -> `router.push` only |
| Filters | GET form with checkboxes + submit; auto-submit as enhancement | Controlled checkboxes updating state only |
| Pagination | `<Link href="?page=2">` | "Load more" button only |
| Tabs | Links to `?tab=x` or sections; ARIA tabs as enhancement | `useState` tabs rendering nothing server-side |
| Disclosure | `<details><summary>` | `useState` toggle with content absent in HTML |
| Delete confirm | Separate confirm page or `<dialog>` + form; `confirm()` as enhancement | `window.confirm` gate only |
| Like/star toggle | Form with hidden `intent`, `useOptimistic` enhancement | Client-only mutation |
| Theme toggle | Form posting to action that sets cookie | localStorage-only toggle |

### Where does it work before hydration?
| Form location | Before hydration | After hydration |
|---|---|---|
| Server Component `<form action={serverAction}>` | Full-page POST, server renders result | Client-side action call, no reload |
| Client Component `<form action={serverAction}>` | Submission works as native form post / queued until hydration (framework behavior) | Client call |
| Client Component with `useActionState` + Server Function (+ `permalink`) | Server response rendered, even before hydration | State updates in place |
| Client Component `onSubmit` + `preventDefault` + `fetch` | Broken or native GET to same URL with data in query string (can leak data) | Works |
| `<form action={clientAsyncFunction}>` (no server) | Does nothing useful | Works |

### Server Action with validation that round-trips values
```ts
// app/signup/actions.ts
'use server'
import { z } from 'zod'
import { redirect } from 'next/navigation'
import { createUser } from '@/server/users' // server-only DAL: auth, rate limit, DB

const Schema = z.object({
  email: z.string().email('Enter a valid email address'),
  name: z.string().min(1, 'Enter your name').max(100),
})

export type SignupState = {
  fieldErrors?: Partial<Record<'email' | 'name', string[]>>
  formError?: string
  values?: { email?: string; name?: string }
}

export async function signup(_prev: SignupState, formData: FormData): Promise<SignupState> {
  const values = { email: String(formData.get('email') ?? ''), name: String(formData.get('name') ?? '') }
  const parsed = Schema.safeParse(values)
  if (!parsed.success) return { fieldErrors: parsed.error.flatten().fieldErrors, values }

  const result = await createUser(parsed.data)
  if (!result.ok) return { formError: result.message, values: { name: values.name } }

  redirect('/welcome') // PRG; works with and without JS
}
```

### Client form that degrades gracefully
```tsx
// app/signup/signup-form.tsx
'use client'
import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { signup, type SignupState } from './actions'

function SubmitButton() {
  const { pending } = useFormStatus()
  // Not disabled by default: works before hydration; disables only while pending
  return <button type="submit" aria-disabled={pending}>{pending ? 'Creating account…' : 'Create account'}</button>
}

export function SignupForm() {
  const [state, formAction] = useActionState<SignupState, FormData>(signup, {}, '/signup')
  const err = state.fieldErrors

  return (
    <form action={formAction} noValidate={false}>
      {state.formError && <p role="alert">{state.formError}</p>}

      <label htmlFor="name">Name</label>
      <input id="name" name="name" required autoComplete="name"
        defaultValue={state.values?.name}
        aria-invalid={!!err?.name} aria-describedby={err?.name ? 'name-error' : undefined} />
      {err?.name && <p id="name-error">{err.name[0]}</p>}

      <label htmlFor="email">Email</label>
      <input id="email" name="email" type="email" required autoComplete="email"
        defaultValue={state.values?.email}
        aria-invalid={!!err?.email} aria-describedby={err?.email ? 'email-error' : undefined} />
      {err?.email && <p id="email-error">{err.email[0]}</p>}

      <SubmitButton />
    </form>
  )
}
```
Note: uncontrolled inputs with `defaultValue` keep PE simple; React 19 resets uncontrolled forms after a successful action, so re-supplying `values` from state preserves input on error.

### GET search with next/form
```tsx
// app/components/search.tsx (Server Component is fine)
import Form from 'next/form'

export function Search({ defaultQuery = '' }: { defaultQuery?: string }) {
  return (
    <Form action="/search" role="search">
      <label htmlFor="q" className="sr-only">Search products</label>
      <input id="q" name="q" type="search" defaultValue={defaultQuery} />
      <button type="submit">Search</button>
    </Form>
  )
}
// app/search/page.tsx reads `await searchParams` and renders results server-side.
```

### Multiple intents in one form
```tsx
<form action={updatePost.bind(null, post.id)}>
  <input name="title" defaultValue={post.title} />
  <button type="submit" name="intent" value="save">Save draft</button>
  <button type="submit" formAction={publishPost.bind(null, post.id)}>Publish</button>
</form>
```

## Recommended Workflow
1. List the page's core tasks; for each, choose the PE-safe primitive from the decision table.
2. Build the Server Component page and the Server Action first; verify with JavaScript disabled in DevTools.
3. Add server validation returning `{ fieldErrors, values }` and PRG redirect on success.
4. Enhance: `useActionState` for inline errors, `useFormStatus` for pending, `useOptimistic` for instant feedback, auto-submit or debounced search as extras.
5. Add URL state for filters/pagination; links for navigation.
6. Write Playwright tests: `javaScriptEnabled: false` project, JS-blocked route test, and a slow-network click-before-hydration test.
7. Review for `onClick`-only mutations, `preventDefault` fetch forms, and missing `name` attributes before merging.

## Patterns
- **Server Component form + Server Action**: default for mutations.
- **Action state echo**: return `values` and `fieldErrors`; render with `defaultValue`.
- **PRG with revalidation**: mutate -> `revalidatePath`/tag -> `redirect`.
- **Bound arguments**: `action.bind(null, id)` instead of closures.
- **GET form for URL state**: filters/search as `<Form action>` or plain `<form method="get">`; enhance with auto-submit `onChange={e => e.currentTarget.form?.requestSubmit()}`.
- **Optimistic enhancement**: `useOptimistic` layered on a form that still works without it.
- **Cookie-backed preferences**: theme/locale via a Server Action setting a cookie so SSR renders correctly.
- **Confirmation page fallback**: destructive actions link to `/items/[id]/delete` confirm page; enhanced to a dialog.

## Anti-Patterns
- **`onSubmit={e => { e.preventDefault(); fetch(...) }}` for core forms.** Before hydration the browser does a native GET to the current URL, possibly putting fields (even passwords) in the query string. Fix: Server Action `action`; if you must use a Route Handler, set `method="post"` and `action="/api/..."` so the native fallback is correct.
- **Disabling submit buttons until hydrated** (`disabled={!mounted}`). Blocks the no-JS path. Fix: enabled by default; `aria-disabled` while pending.
- **Inputs without `name`.** Data missing from `FormData`. Fix: every field named.
- **Controlled-only inputs with state that never reaches the server.** Fix: uncontrolled + `defaultValue`, or ensure `name` + `value` are present.
- **Client-only validation (react-hook-form alone) with no server validation.** Fix: shared Zod schema validated in the action ([react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) as enhancement).
- **Filters in `useState`.** Lost on reload, not shareable, not no-JS. Fix: search params.
- **Whole page marked `'use client'`.** Loses server-rendered content and Server Component forms. Fix: push `'use client'` to leaves.
- **Mutations in GET (links that delete).** Prefetching can trigger them; CSRF risk. Fix: POST forms.
- **Relying on `window.confirm` as the only guard.** Fix: server-side confirmation step for irreversible actions.

## Accessibility
- Native forms give keyboard and screen reader support by default (WCAG 2.1.1, 4.1.2).
- Associate errors with fields (`aria-describedby`, `aria-invalid`) and render them in server HTML so they exist without JS (WCAG 3.3.1, 3.3.3).
- For enhanced in-place updates, announce results via `role="status"`/`role="alert"` and move focus to the first error or an error summary (WCAG 4.1.3, 2.4.3).
- Use `aria-disabled` rather than `disabled` during pending so focus is not lost.
- After redirects, ensure the new page has a unique `<title>` and focus lands sensibly (see [accessible-spa-routing](../accessible-spa-routing/Skill.md)).

## Responsive Design
- Server-rendered forms must be usable at 320 CSS px without JS-driven layout.
- Use `inputmode`, `autocomplete`, and correct `type` to get appropriate mobile keyboards without JS.
- Do not hide filter forms behind a JS-only drawer on mobile; use `<details>` or a CSS-only pattern as baseline.

## Performance
- PE improves perceived performance: content and forms are usable as soon as HTML arrives; INP is protected because early interactions do not wait on hydration.
- Keep Client Component islands small; forms can stay server-rendered with small client leaves (`SubmitButton`).
- Streaming with Suspense lets the form render before slow data sections.
- Avoid large client validation libraries on first load; lazy-load enhancements.

## Security
- Server Actions are public POST endpoints: authenticate and authorize inside each action (or the DAL it calls), validate every field, and return minimal data (see [nextjs-server-actions](../nextjs-server-actions/Skill.md)).
- Next.js compares Origin and Host for Server Actions (CSRF mitigation); configure `serverActions.allowedOrigins` behind proxies.
- For Route Handler form endpoints without JS, implement CSRF protection (SameSite cookies plus token or Origin check).
- PRG prevents duplicate submissions on refresh; add idempotency keys for payments.
- Never put secrets or authorization flags in hidden inputs or bound arguments; bound arguments are sent to the client (closures are encrypted, but do not rely on that).
- Rate-limit expensive actions (sign-up, email sending).

## Testing
- Playwright project with `javaScriptEnabled: false` for core journeys.
- Block JS mid-load: `await page.route('**/_next/static/**/*.js', r => r.abort())`, then submit and assert redirect/result.
- Pre-hydration click test: throttle CPU/network via CDP, click submit immediately after `domcontentloaded`, assert no lost submission and no sensitive data in URL.
- Unit test actions as plain async functions with `FormData` inputs (valid, invalid, unauthorized).
- axe scans in both enhanced and no-JS states.

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| Server Actions (Next.js 16) | Stable | Core PE mutation primitive |
| `useActionState` (React 19) | Stable | Replaces `useFormState` (renamed; old name removed) |
| `useFormStatus` (react-dom) | Stable | Pending UI in child components |
| `useOptimistic` | Stable | Optimistic enhancement |
| `next/form` | Stable | GET forms with client navigation |
| Zod / Valibot | Active | Server validation |
| `conform` (`@conform-to/react`) | Community, active | PE-friendly form validation library for Server Actions |
| Playwright | Active | No-JS and blocked-JS projects |

## Framework Notes
- **Next.js**: Server Components + Server Actions are the PE path. `useActionState` permalink supports no-JS submission on dynamic routes. `next/form` string actions do GET navigation with prefetch of loading UI. Avoid route-handler `fetch` forms for core flows unless the native `method`/`action` fallback is correct.
- **React (Vite SPA)**: no server HTML, so no true baseline; `<form action={asyncFn}>` and `useActionState` still give better pending/error handling than `onSubmit`. If PE is a requirement, adopt SSR (Next.js or React Router framework mode with `<Form>` and actions).

## AI Agent Guidance
- Do: implement mutations as Server Actions invoked by `<form action>`; name every input; validate with a schema on the server; return `{ fieldErrors, values }`; redirect on success.
- Do: implement search/filters/pagination with GET forms, `next/form`, and links.
- Don't: write `onSubmit` + `preventDefault` + `fetch` for core forms, disable buttons until mount, or mark whole pages `'use client'`.
- Don't: rely on client-only validation or `window.confirm` as the only guard.
- Before done: disable JavaScript in the browser and complete the flow; run the Playwright no-JS project; confirm no form data appears in the URL on early submit; confirm auth checks inside the action.

## Examples
```ts
// playwright.config.ts (excerpt)
projects: [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  { name: 'no-js', use: { ...devices['Desktop Chrome'], javaScriptEnabled: false }, testMatch: /.*\.pe\.spec\.ts/ },
]
```

```ts
// e2e/signup.pe.spec.ts
import { test, expect } from '@playwright/test'

test('signup works without JavaScript and re-renders errors', async ({ page }) => {
  await page.goto('/signup')
  await page.getByLabel('Name').fill('Ada')
  await page.getByLabel('Email').fill('not-an-email')
  await page.getByRole('button', { name: 'Create account' }).click()
  await expect(page.getByText('Enter a valid email address')).toBeVisible()
  await expect(page.getByLabel('Name')).toHaveValue('Ada')

  await page.getByLabel('Email').fill('ada@example.com')
  await page.getByRole('button', { name: 'Create account' }).click()
  await expect(page).toHaveURL(/\/welcome$/)
})
```

```tsx
// Filter form: works as GET without JS, auto-applies with JS
'use client'
export function StatusFilter({ current }: { current?: string }) {
  return (
    <form method="get" action="/orders">
      <label htmlFor="status">Status</label>
      <select id="status" name="status" defaultValue={current ?? ''}
        onChange={e => e.currentTarget.form?.requestSubmit()}>
        <option value="">All</option>
        <option value="open">Open</option>
        <option value="shipped">Shipped</option>
      </select>
      <noscript><button type="submit">Apply</button></noscript>
    </form>
  )
}
```

## Related Skills
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action security, revalidation, and patterns
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState/useOptimistic semantics
- [form-validation-patterns](../form-validation-patterns/Skill.md) — server-first validation UX
- [accessible-forms](../accessible-forms/Skill.md) — labels, errors, and focus
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — URL state enhanced layer
- [hydration-strategies](../hydration-strategies/Skill.md) — the pre-hydration window
- [semantic-html](../semantic-html/Skill.md) — the baseline layer
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) — no-JS test projects

## Sources
- [Next.js: Forms with Server Actions](https://nextjs.org/docs/app/guides/forms) — Official — useActionState, useFormStatus, bind, validation, optimistic updates, requestSubmit
- [Next.js: Data Security](https://nextjs.org/docs/app/guides/data-security) — Official — action auth, allowedOrigins, closures, return values
- [react.dev: useActionState](https://react.dev/reference/react/useActionState) — Official — permalink, pre-hydration server responses
- [Next.js: Form component (next/form)](https://nextjs.org/docs/app/api-reference/components/form) — Official — GET form navigation behavior
- [GOV.UK Service Manual: Using progressive enhancement](https://www.gov.uk/service-manual/technology/using-progressive-enhancement) — Official — layered PE rationale and testing
- [React Router: Progressive enhancement](https://reactrouter.com/explanation/progressive-enhancement) — Official — comparison model for form-based mutations

## License / Usage Notes
Next.js (MIT), react.dev (CC-BY-4.0), GOV.UK Service Manual (OGL v3.0). Content summarized and rewritten; examples are original.

## Quality Tier
A — Built on current official Next.js 16.3 and React 19 docs plus GOV.UK principles; exact pre-hydration queuing behavior for Client Component forms should be re-tested per Next.js release.

## Status
Active

## Last Verified
2026-09-15
