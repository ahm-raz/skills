# Next.js Server Actions

## Summary
Server Actions are React Server Functions (`'use server'`) invoked through form `action`, `formAction`, or transitions. In Next.js 16 a single POST round trip runs the mutation and, when it calls `updateTag`, `revalidatePath`, `refresh`, sets cookies, or redirects, returns the re-rendered route payload alongside the return value. They are public endpoints: every action must authenticate, authorize, validate input, and shape its return value.

## Category
Next.js

## Subcategories
Mutations, forms, useActionState, useFormStatus, useOptimistic, revalidation, progressive enhancement, CSRF, action security

## Problem It Solves
Boilerplate API routes and client fetch code for every mutation, stale UI after writes, forms that don't work before hydration, and — most critically — insecure actions that trust page-level auth, client-supplied IDs, or return raw DB rows.

## When To Use
- Form submissions and user-initiated mutations (create/update/delete, settings, likes).
- Mutations that must immediately reflect in server-rendered UI (read-your-own-writes).
- Progressive-enhancement forms that must work without JS.
- Setting/deleting cookies (login, logout, preferences).

## When Not To Use
- Data fetching/reads — actions are dispatched sequentially per client; use Server Components or Route Handlers.
- Public APIs consumed by third parties, webhooks, streaming responses, or non-POST semantics — use [nextjs-route-handlers](../nextjs-route-handlers/Skill.md).
- Parallel fan-out from the client (`Promise.all` over actions queues them anyway).
- Static exports (unsupported).

## Core Principles
1. **Treat every action as an untrusted public POST endpoint.** Render-time gating is not a security boundary.
2. **Authenticate, authorize (ownership), validate — inside the action or its DAL call.**
3. **Accept references + changes, not records.** Take an `itemId`, re-read the row scoped to the session user.
4. **Return only what the UI needs.** Model expected errors as return values; throw only for unexpected failures.
5. **Choose the right cache update:** `updateTag` (immediate), `revalidateTag(tag, 'max')` (SWR, no immediate re-render), `revalidatePath`, `refresh()` (uncached data only).
6. **`redirect()` throws** — call revalidation before it.

## Best Practices
- Define actions in `'use server'` files (`app/actions/*.ts`) when used from Client Components; inline `'use server'` functions are fine in Server Components.
- Validate `FormData` with zod/valibot `safeParse`; return `{ errors }` for field messages.
- Use `useActionState(action, initialState)` for state + `pending`; `useFormStatus` inside a child submit button; `useOptimistic` for instant feedback.
- Pass extra args with `action.bind(null, id)` (encrypted, progressive-enhancement friendly) rather than hidden inputs when the value shouldn't be user-editable in HTML (still re-authorize server-side).
- Delegate auth + DB to a `server-only` Data Access Layer so actions stay thin.
- Add rate limiting for expensive actions (email, AI, payments).
- For multi-instance/self-hosted deployments set `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` and `deploymentId`; handle "Failed to find Server Action" with a refresh/retry UI after deploys.
- Configure `experimental.serverActions.allowedOrigins` behind reverse proxies/CDNs with different hosts; raise `bodySizeLimit` (default 1MB) only when needed.
- With experimental `authInterrupts`, throw `unauthorized()`/`forbidden()` to render `unauthorized.tsx`/`forbidden.tsx`.

## Implementation Guidance

### Cache update decision table
| API | Where | Behavior | Re-render in same response |
|---|---|---|---|
| `updateTag(tag)` | Server Actions only | Expire now; next read waits for fresh | Yes |
| `revalidateTag(tag, 'max')` | Actions + Route Handlers | Stale-while-revalidate | No |
| `revalidatePath('/posts')` | Actions + Route Handlers | Invalidate by path | Yes |
| `refresh()` | Server Actions only | Refetch route payload, cache untouched | Yes |
| `cookies().set/delete` | Actions | Re-renders current route | Yes |
| `redirect(url)` | Actions | Throws; navigates with destination payload | Yes |

`revalidateTag(tag)` with one argument is deprecated in v16.

### Secure action with DAL
```ts
// lib/dal/posts.ts
import 'server-only'
import { getSession } from '@/lib/session'
import { db } from '@/lib/db'

export async function deletePostForCurrentUser(postId: string) {
  const session = await getSession()
  if (!session?.userId) throw new Error('Unauthorized')
  const post = await db.post.findFirst({ where: { id: postId, authorId: session.userId } })
  if (!post) throw new Error('Forbidden')
  await db.post.delete({ where: { id: post.id } })
}
```

```ts
// app/actions/posts.ts
'use server'
import { z } from 'zod'
import { updateTag } from 'next/cache'
import { redirect } from 'next/navigation'
import { deletePostForCurrentUser, createPostForCurrentUser } from '@/lib/dal/posts'

const CreatePost = z.object({
  title: z.string().trim().min(3).max(120),
  body: z.string().trim().min(1).max(20_000),
})

export type CreatePostState = { errors?: Record<string, string[]>; message?: string } | undefined

export async function createPost(_prev: CreatePostState, formData: FormData): Promise<CreatePostState> {
  const parsed = CreatePost.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors }
  const post = await createPostForCurrentUser(parsed.data) // auth inside
  updateTag('posts')
  redirect(`/posts/${post.id}`)
}

export async function deletePost(postId: string) {
  await deletePostForCurrentUser(z.string().uuid().parse(postId))
  updateTag('posts')
}
```

### Client form
```tsx
'use client'
import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { createPost, type CreatePostState } from '@/app/actions/posts'

function Submit() {
  const { pending } = useFormStatus()
  return <button type="submit" disabled={pending} aria-disabled={pending}>{pending ? 'Saving…' : 'Publish'}</button>
}

export function NewPostForm() {
  const [state, action] = useActionState<CreatePostState, FormData>(createPost, undefined)
  return (
    <form action={action} noValidate>
      <label htmlFor="title">Title</label>
      <input id="title" name="title" required aria-invalid={!!state?.errors?.title} aria-describedby="title-err" />
      <p id="title-err" aria-live="polite">{state?.errors?.title?.[0]}</p>
      <label htmlFor="body">Body</label>
      <textarea id="body" name="body" required />
      <Submit />
    </form>
  )
}
```

## Recommended Workflow
1. Write the DAL function (auth + ownership + DB) with `server-only`.
2. Write the action: parse input → call DAL → cache update → return/redirect.
3. Wire the form with `useActionState`; add `useFormStatus` button and error regions.
4. Add `useOptimistic` if latency is noticeable.
5. Test unauthenticated POST, wrong-owner ID, invalid input, and no-JS submission.
6. Configure encryption key / allowedOrigins for your deployment topology.

## Patterns
- **Thin action, fat DAL.**
- **Bound ID:** `<form action={deletePost.bind(null, post.id)}>`.
- **Multiple submit intents:** separate `<button formAction={saveDraft}>` and `<button formAction={publish}>`.
- **Optimistic list append** with `useOptimistic` + action call inside the form action.
- **Keyboard submit:** `form.requestSubmit()` on Cmd/Ctrl+Enter.
- **Event-handler invocation:** `startTransition(async () => setLikes(await incrementLike()))`.

## Anti-Patterns
- **Relying on page auth** (`if (!admin) redirect()` in page, no check in inline action) — action is reachable by direct POST. Fix: re-check in the action/DAL.
- **`completeItem(item: Item)`** trusting client-supplied object/ownership (IDOR). Fix: accept `itemId`, query with `ownerId: session.userId`.
- **Returning `db.user.update(...)` result** — leaks internal fields. Fix: return `{ ok: true }` or a DTO.
- **Using actions for reads/polling** — sequential queue causes waterfalls. Fix: Server Components / Route Handler + SWR/TanStack Query.
- **`try { redirect() } catch {}`** — swallows the control-flow throw. Fix: call `redirect` outside try/catch or rethrow `isRedirectError`.
- **`revalidateTag('posts')` single-arg** — deprecated. Fix: `revalidateTag('posts', 'max')` or `updateTag('posts')`.
- **Mutating in render** (logout via `?logout=1` in a page) — Next.js blocks cookie writes in render. Fix: form + action.
- **Secrets in closures** of inline actions — they are encrypted but round-trip through the client. Fix: re-read secrets server-side inside the action.

## Accessibility
- Associate labels and inputs; expose field errors via `aria-describedby` and `aria-invalid`; announce form-level results with `aria-live="polite"` (WCAG 3.3.1, 4.1.3).
- Pending buttons: keep them focusable or restore focus after completion; convey state text, not just a spinner.
- After `redirect`, the destination page should set a meaningful title/heading so screen reader users know where they are.
- Progressive enhancement: forms work before hydration (WCAG robustness on slow devices).

## Responsive Design
- Keep inline error messaging visible on small screens near fields (not only toasts).
- Submit buttons should remain reachable (sticky footer on mobile forms) and have adequate touch targets (WCAG 2.5.8).

## Performance
- One round trip returns data + UI; avoid extra `router.refresh()` calls.
- Prefer `updateTag` for targeted invalidation over `revalidatePath('/', 'layout')`, which re-renders broadly.
- Heavy work (emails, analytics) can run after the response with `after()` from `next/server`.

## Security
- Built-in: POST-only, Origin vs Host/X-Forwarded-Host CSRF check, encrypted non-deterministic action IDs (rotated at most every 14 days), dead-code elimination of unused actions, closure encryption, 1MB body limit.
- Your job: authN, authZ (ownership), validation, output filtering, rate limiting, audit logging for destructive operations.
- Proxy matchers that exclude a path also skip actions posted to that path — never rely on `proxy.ts` for action auth.
- Keep `next`/`react` patched (RSC protocol advisories in Dec 2025).

## Testing
- Unit-test DAL functions and zod schemas with Vitest (mock session/db).
- Integration: call the exported action function directly in a Node test with mocked `next/headers`/session.
- E2E (Playwright): submit forms, assert UI updates without reload, test JS-disabled context (`javaScriptEnabled: false`).
- Security tests: replay the action POST without a session cookie and with another user's resource ID; expect failure.

## Tooling
- zod / valibot for validation; `react-hook-form` + zod when you need rich client validation (still validate on the server).
- `next-safe-action` (community) for typed action middleware — optional; verify it keeps per-action auth.
- Rate limiting: platform WAF or `@upstash/ratelimit`-style libraries.

## Framework Notes
- Server Functions are a React 19 feature; Next.js adds caching integration, security checks, and encryption.
- `useFormState` was renamed `useActionState` in React 19 (import from `react`).
- Experimental `useOffline` (16.3) keeps interrupted actions pending until connectivity returns.
- Root params (`next/root-params`) are not available inside Server Actions.

## AI Agent Guidance
- Always generate: input schema, session check, ownership-scoped query, minimal return, correct cache API.
- Never generate an action without auth unless it is explicitly public, and then add rate limiting.
- Don't use actions for GET-like reads.
- Before done: test a direct unauthenticated call path (or reason through it explicitly), confirm the UI updates in one round trip, run `next build`, and verify no single-arg `revalidateTag` remains.

## Examples
```tsx
// Optimistic like button
'use client'
import { useOptimistic, startTransition } from 'react'
import { toggleLike } from '@/app/actions/likes'

export function Like({ postId, liked, count }: { postId: string; liked: boolean; count: number }) {
  const [state, setOptimistic] = useOptimistic({ liked, count }, (s) => ({ liked: !s.liked, count: s.count + (s.liked ? -1 : 1) }))
  return (
    <button
      aria-pressed={state.liked}
      onClick={() => startTransition(async () => { setOptimistic(null); await toggleLike(postId) })}
    >
      {state.liked ? 'Unlike' : 'Like'} ({state.count})
    </button>
  )
}
```

## Related Skills
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — updateTag vs revalidateTag
- [nextjs-authentication](../nextjs-authentication/Skill.md) — session + DAL
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — when an endpoint is better
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — React hooks
- [form-validation-patterns](../form-validation-patterns/Skill.md) — validation UX
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — rich client forms
- [optimistic-ui](../optimistic-ui/Skill.md) — optimistic UX principles
- [progressive-enhancement](../progressive-enhancement/Skill.md) — forms that work before hydration
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — ORM/transactions behind the DAL
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md) — alternative typed RPC layer

## Sources
- [Mutating Data](https://nextjs.org/docs/app/getting-started/mutating-data) — Official — creating/invoking actions, refresh, cookies
- [Server Actions and Mutations guide](https://nextjs.org/docs/app/guides/server-actions) — Official — single round trip, sequential dispatch, security, config, deployment
- [Forms guide](https://nextjs.org/docs/app/guides/forms) — Official — bind, validation, useFormStatus, useOptimistic
- [Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — IDOR, return values, closures, allowedOrigins
- [Revalidating](https://nextjs.org/docs/app/getting-started/revalidating) — Official — updateTag vs revalidateTag
- [proxy.js reference](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) — Official — matcher exclusion skips actions

## License / Usage Notes
Next.js/React MIT. zod MIT. Content summarized; examples original.

## Quality Tier
S — Comprehensive, security-first, fully aligned with 16.3 official guides including newest cache APIs and deployment caveats.

## Status
Active

## Last Verified
2026-09-15
