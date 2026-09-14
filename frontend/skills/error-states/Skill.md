# Error States

## Summary
How to present failures so users understand what happened, whether their work is safe, and how to recover. Covers the error taxonomy (validation, request, page/route, not found, permission, offline, partial failure), message writing (GOV.UK, Atlassian, NN/g), placement, and React/Next.js implementation with `error.tsx`, `global-error.tsx`, `not-found.tsx`, error boundaries and Server Action errors.

## Category
UX

## Subcategories
validation errors, error summary, error boundaries, 404/500 pages, offline states, partial failures, retry, error copy

## Problem It Solves
Generic "Something went wrong" toasts that vanish, cleared forms, white screens from uncaught render errors, and blame-heavy or technical messages erode trust and create support tickets.

## When To Use
- Any operation that can fail: form submit, data fetch, upload, payment, auth, realtime connection.
- Designing route-level error boundaries and 404/500 pages.

## When Not To Use
- Empty-but-successful results (see empty-states).
- Warnings about future consequences before an action (see destructive-actions-and-confirmation).

## Core Principles
1. **Prevent first** (heuristic 5): constraints, defaults, inline hints.
2. **Say what happened, in plain language, and how to fix it** (heuristic 9).
3. **Show the error where the problem is**, and summarize when there are several.
4. **Preserve user input and context** — never clear forms or navigate away on failure.
5. **Offer a recovery action**: retry, edit, alternative method, contact support with reference.
6. **Contain the blast radius**: a failing widget shouldn't blank the whole page.
7. **Don't blame, don't joke, don't over-apologize**; avoid "invalid", "illegal", "oops".
8. **Be persistent when it matters**: errors don't auto-dismiss.
9. **Don't leak internals** (stack traces, SQL, user enumeration).

## Best Practices
- Field errors: next to the field, below label or input, with icon + text, linked via `aria-describedby`; set `aria-invalid`.
- On submit with errors: show an error summary at top ("There is a problem") with links to each field; move focus to it (GOV.UK).
- Validate on submit and on blur for format; don't show errors while the user is still typing the first time.
- Message patterns: missing input -> instruction ("Enter your email address"); wrong format -> description + example ("Enter an email address in the correct format, like name@example.com"); limits ("Name must be 35 characters or less").
- Request failures: inline alert in the affected region + "Try again"; include whether data was saved.
- Transient network errors: auto-retry with backoff for idempotent reads; manual retry for writes.
- Offline: banner "You're offline. Changes will sync when you reconnect." and queue if supported.
- Partial failure: "18 of 20 contacts imported. 2 rows had problems. Download error report."
- 404: plain explanation, search, links to likely destinations; keep site chrome.
- 500/unexpected: apologize once briefly, say it's not their fault, give retry and a reference ID (digest) for support.
- Log all errors with context to observability (Sentry etc.).

## Implementation Guidance

Error taxonomy and placement:

| Error | Placement | Dismissal | Recovery |
|---|---|---|---|
| Field validation | Inline under field + summary on submit | Clears when fixed | Edit field |
| Form-level (server rejected) | Alert at top of form | Persistent | Edit / retry |
| Region data fetch | Inline in region (replace content) | Persistent | Try again |
| Route render/data failure | `error.tsx` for segment | Persistent | `reset()` / navigate |
| Root layout failure | `global-error.tsx` | Persistent | Reload |
| Not found | `not-found.tsx` | — | Search / links |
| Background action | Toast with action (not auto-dismissed) | Manual | Retry / View details |
| Permission | Inline page message | — | Request access |
| Offline | Top banner | Auto on reconnect | Wait / retry |

Copy formula: **[What happened] + [Why, if known and useful] + [What to do]**.

| Bad | Good |
|---|---|
| "Error 500" | "We couldn't save your changes. Try again in a moment. Your draft is kept on this device." |
| "Invalid input" | "Enter a date in the past, like 27 3 2007" |
| "Oops! Something went wrong :(" | "We couldn't load invoices. Check your connection and try again." |
| "Payment failed" | "Your card was declined. Check the card details or use a different payment method." |
| "Forbidden" | "You need Editor access to change this project. Ask a project admin." |

```tsx
// app/(app)/projects/error.tsx — segment boundary keeps layout/nav alive
"use client";
import { useEffect } from "react";
export default function ProjectsError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => { reportError(error); }, [error]);
  return (
    <div role="alert" className="rounded-lg border border-red-200 bg-red-50 p-6">
      <h2 className="font-semibold text-red-900">We couldn't load your projects</h2>
      <p className="mt-1 text-sm text-red-800">This is a problem on our side. Try again, or contact support if it keeps happening.</p>
      {error.digest && <p className="mt-2 text-xs text-red-700">Reference: {error.digest}</p>}
      <button className="btn-secondary mt-4" onClick={() => reset()}>Try again</button>
    </div>
  );
}
```

```tsx
// app/not-found.tsx
import Link from "next/link";
export default function NotFound() {
  return (
    <main className="mx-auto max-w-lg py-24 text-center">
      <h1 className="text-2xl font-semibold">We can't find that page</h1>
      <p className="mt-2 text-neutral-600">The link may be broken or the page may have moved.</p>
      <div className="mt-6 flex justify-center gap-3">
        <Link className="btn-primary" href="/">Go to home</Link>
        <Link className="btn-secondary" href="/search">Search</Link>
      </div>
    </main>
  );
}
```

```tsx
// Server Action returning expected errors as data (don't throw for validation)
"use server";
export type FormState = { values: Record<string, string>; fieldErrors?: Record<string, string>; formError?: string };
export async function updateProfile(_: FormState, fd: FormData): Promise<FormState> {
  const values = { email: String(fd.get("email") ?? "") };
  if (!values.email) return { values, fieldErrors: { email: "Enter your email address" } };
  if (!/^\S+@\S+\.\S+$/.test(values.email)) return { values, fieldErrors: { email: "Enter an email address in the correct format, like name@example.com" } };
  try { await db.user.update({ email: values.email }); }
  catch { return { values, formError: "We couldn't save your profile. Try again." }; }
  return { values };
}
```

```tsx
// Error summary that receives focus
"use client";
import { useEffect, useRef } from "react";
export function ErrorSummary({ errors }: { errors: Record<string, string> }) {
  const ref = useRef<HTMLDivElement>(null);
  const entries = Object.entries(errors);
  useEffect(() => { if (entries.length) ref.current?.focus(); }, [entries.length]);
  if (!entries.length) return null;
  return (
    <div ref={ref} tabIndex={-1} role="alert" aria-labelledby="error-summary-title" className="border-l-4 border-red-600 p-4">
      <h2 id="error-summary-title" className="font-semibold">There is a problem</h2>
      <ul className="mt-2 list-disc pl-5">
        {entries.map(([field, msg]) => <li key={field}><a href={`#${field}`} className="underline">{msg}</a></li>)}
      </ul>
    </div>
  );
}
```

## Recommended Workflow
1. Enumerate failure modes per operation (validation, 4xx types, 5xx, timeout, offline, partial).
2. Decide placement and persistence via the table; write copy with the formula.
3. Implement error boundaries at route segments and around independent widgets.
4. Return expected errors as data from Server Actions/APIs; throw only unexpected errors.
5. Preserve inputs; add retries (idempotent reads automatic, writes manual).
6. Wire error reporting with digest/reference IDs.
7. Test each failure path with mocks; review copy against glossary.

## Patterns
- **Error summary + inline messages** (GOV.UK), identical wording in both.
- **Retry with backoff**: TanStack Query `retry: 3` for queries; `retry: false` for mutations with manual button.
- **Widget boundary**: `react-error-boundary` around each dashboard card with local retry.
- **Reference ID**: show `digest` so support can find logs.
- **Offline banner + outbox**: queue writes, show pending count.

## Anti-Patterns
- **Auto-dismissing error toasts** — users miss them. Fix: persistent inline alert; toasts only with manual dismiss + action.
- **Clearing the form on error** — Fix: return values from the action; `defaultValue` from state.
- **Throwing validation errors to `error.tsx`** — whole segment replaced. Fix: return errors as data.
- **Leaking stack traces / "user not found"** on login — Fix: generic auth failure copy; log details server-side.
- **Red text only** — color-only error cue. Fix: icon + text + `aria-invalid`.
- **Validating on every keystroke from the first character** — hostile. Fix: validate on blur/submit; re-validate live after an error is shown.
- **Disabling submit until form valid** without explanation — users don't know what's wrong. Fix: allow submit and show errors.

## Accessibility
- Error identification (3.3.1) in text; labels or instructions (3.3.2); error suggestion (3.3.3); error prevention for legal/financial (3.3.4).
- `aria-invalid="true"` + `aria-describedby` linking the message; focus the error summary or first invalid field on submit.
- Status messages (4.1.3): non-focus-moving errors use `role="alert"` (assertive) sparingly or `aria-live="polite"`.
- Error colors meet contrast (1.4.3) and aren't the only cue (1.4.1).
- On route error pages, update `<title>` ("Error: Page not found – App").

## Responsive Design
- Error summary at top must be scrolled into view on mobile (focus does this).
- Inline messages wrap; don't truncate error text.
- Toast placement avoids covering the mobile keyboard or primary action.

## Performance
- Error boundaries are client components; keep `error.tsx` small.
- Avoid retry storms: exponential backoff with jitter; respect `Retry-After`.

## Security
- Never render raw server error messages; map to user copy. In production Next.js hides server error messages from client (only `digest`).
- Login/reset forms: avoid account enumeration ("If an account exists, we've sent an email").
- Sanitize any user-provided values echoed in error messages.

## Testing
- Unit: Server Action returns expected field errors for each invalid input.
- Playwright: mock 500/timeout via `page.route`, assert inline alert, retry recovers, form values kept.
- Throw inside a component in a test route to verify `error.tsx` catches and `reset()` works.
- axe: `aria-invalid` and described-by relationships.

## Tooling
- `react-error-boundary`, Next.js `error.tsx`/`global-error.tsx`/`not-found.tsx`, Zod for validation messages, Sentry/OpenTelemetry for reporting, MSW for failure mocks.

## Framework Notes
- **Next.js (App Router)**: `error.tsx` must be a Client Component and does not catch errors in the same segment's `layout.tsx` (use parent segment or `global-error.tsx`, which must render its own `<html>` and `<body>`). `notFound()` renders nearest `not-found.tsx`. Server Actions: return expected errors, throw unexpected ones. `redirect()` works by throwing — don't wrap it in try/catch that swallows it.
- **React (Vite SPA)**: `react-error-boundary` at route and widget level; router `errorElement`; TanStack Query `throwOnError` for boundary integration or render `isError` inline.

## AI Agent Guidance
- Do: create `error.tsx` and `not-found.tsx` for new route segments; return typed form state with field errors; preserve values; write specific copy.
- Don't: `console.error` and render nothing; don't catch-and-ignore; don't show raw `error.message` to users.
- Verify: simulate failure for every mutation and fetch; check focus moves to summary; check copy has what + how to fix.

## Examples
```tsx
// Widget-level boundary in a client dashboard
"use client";
import { ErrorBoundary } from "react-error-boundary";
export function WidgetBoundary({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <ErrorBoundary fallbackRender={({ resetErrorBoundary }) => (
      <div role="alert" className="p-4 text-sm">
        <p>We couldn't load {title.toLowerCase()}.</p>
        <button className="underline" onClick={resetErrorBoundary}>Try again</button>
      </div>
    )}>
      {children}
    </ErrorBoundary>
  );
}
```

## Related Skills
- [form-validation-patterns](../form-validation-patterns/Skill.md) — validation timing and rules
- [frontend-error-handling-architecture](../frontend-error-handling-architecture/Skill.md) — error plumbing and reporting
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md) — boundary mechanics
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — returning errors from actions
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — tone and wording
- [empty-states](../empty-states/Skill.md) — empty is not error
- [toasts-and-notifications](../toasts-and-notifications/Skill.md) — when toasts are appropriate
- [accessible-forms](../accessible-forms/Skill.md) — ARIA for errors

## Sources
- [GOV.UK Design System: Error message](https://design-system.service.gov.uk/components/error-message/) — Official — message patterns, words to avoid, preserve input
- [GOV.UK Design System: Error summary](https://design-system.service.gov.uk/components/error-summary/) — Official — focus, "There is a problem", links
- [GOV.UK: Recover from validation errors](https://design-system.service.gov.uk/patterns/validation/) — Official
- [Atlassian Design: Error messages](https://atlassian.design/foundations/content/designing-messages/error-messages) — Official (design system) — structure, no "sorry/please", most likely fix first
- [NN/g: Error-Message Guidelines](https://www.nngroup.com/articles/error-message-guidelines/) — Community (research)
- [Next.js docs: error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error) — Official — boundary behavior, digest

## License / Usage Notes
GOV.UK content OGL v3.0; Atlassian guidance summarized, not copied. Code original.

## Quality Tier
S — multiple official government/design-system sources converge; framework APIs verified.

## Status
Active

## Last Verified
2026-09-15
