# Optimistic UI

## Summary
Optimistic UI updates the interface immediately as if a mutation succeeded, then reconciles with the server result and rolls back (with explanation) on failure. This skill covers when it's safe, how to design pending/failed visuals, and implementation with React 19 `useOptimistic` + Server Actions in Next.js and TanStack Query optimistic mutations in SPAs.

## Category
UX

## Subcategories
useOptimistic, optimistic mutations, rollback, reconciliation, perceived performance, offline-first, idempotency

## Problem It Solves
Round-trip latency (100ms-2s+) makes likes, toggles, reorders, and message sends feel sluggish, and spinners on tiny actions break flow (Doherty Threshold <400ms). Optimistic updates make the UI feel instant while keeping truth on the server.

## When To Use
- High-success-rate, low-stakes, reversible actions: like, star, toggle, rename, reorder, add comment, send chat message, mark as read, move card.
- Actions where the client can predict the result accurately.

## When Not To Use
- Payments, purchases, irreversible deletes, sending email/money, permission changes: show pending then confirmed result.
- Results that depend on server computation the client can't predict (pricing, search results, generated IDs shown prominently).
- Low success rate operations (validation-heavy, conflict-prone) — rollbacks become frequent and confusing.

## Core Principles
1. **Only be optimistic when failure is rare (>~99% success) and recoverable.**
2. **Make pending distinguishable but unobtrusive** (subtle opacity, "Sending..." timestamp), especially for created items.
3. **Always reconcile with the server** result (IDs, normalized values, timestamps).
4. **On failure: roll back visibly, explain, and offer retry** — never silent reversion.
5. **Keep user input on failure** (e.g., failed message stays in the thread with "Retry").
6. **Handle concurrency**: rapid repeated actions and out-of-order responses must converge to the right final state.
7. **Server remains authoritative**: validate and authorize server-side regardless.

## Best Practices
- Toggles/likes: flip immediately; debounce or serialize repeated toggles; final state wins.
- Created items: insert with temporary client ID (`crypto.randomUUID()`), mark `pending`; replace with server item on success.
- Deletes: prefer "hide + undo toast" (delayed commit) over optimistic permanent delete.
- Reorders/drag-and-drop: apply immediately; on failure snap back with message.
- Use idempotency keys (client-generated ID) so retries don't duplicate.
- Cancel in-flight refetches before applying optimistic state (TanStack Query `cancelQueries`) to avoid overwrite flicker.
- Revalidate affected data after the mutation settles (Next.js `revalidatePath`/`revalidateTag`/`updateTag`; Query `invalidateQueries`).
- Surface failures near the item ("Couldn't send. Retry") plus a toast for off-screen items.

## Implementation Guidance

Decision table:

| Action | Optimistic? | Pattern |
|---|---|---|
| Like / star / follow | Yes | Flip state, rollback + toast on fail |
| Mark read / archive | Yes | Remove from view + undo toast |
| Add comment / chat message | Yes | Append pending item, retry on fail |
| Rename / inline edit | Yes | Show new value, revert + inline error on fail |
| Reorder / kanban move | Yes | Move immediately, snap back on fail |
| Delete permanently | No (use undo delay or confirm) | Soft-delete + undo window |
| Checkout / payment / transfer | No | Pending state -> confirmed page |
| Invite user (validation by server) | Partial | Show pending row, mark failed rows clearly |
| Generate AI response | No (stream instead) | Streaming UI |

`useOptimistic` essentials (React 19):
- `const [optimistic, addOptimistic] = useOptimistic(state, reducer?)`.
- The setter must be called inside an Action or `startTransition`; calling it elsewhere warns and flashes.
- Optimistic value shows only while the Action is pending; when it finishes, React renders the real `state`. If the action throws, the optimistic value is discarded automatically (so show your own error message).

```tsx
// app/(app)/threads/[id]/actions.ts
"use server";
import { revalidatePath } from "next/cache";
export async function sendMessage(threadId: string, clientId: string, text: string) {
  const user = await requireUser();
  if (!text.trim()) return { ok: false as const, error: "Message can't be empty" };
  await db.message.upsert({ where: { clientId }, create: { clientId, threadId, authorId: user.id, text }, update: {} }); // idempotent
  revalidatePath(`/threads/${threadId}`);
  return { ok: true as const };
}
```

```tsx
// app/(app)/threads/[id]/thread.tsx
"use client";
import { useOptimistic, useRef, useState, startTransition } from "react";
import { sendMessage } from "./actions";

type Msg = { id: string; text: string; author: string; status?: "pending" | "failed" };

export function Thread({ threadId, messages }: { threadId: string; messages: Msg[] }) {
  const [failed, setFailed] = useState<Msg[]>([]);
  const [optimistic, addOptimistic] = useOptimistic(messages, (cur: Msg[], m: Msg) => [...cur, m]);
  const formRef = useRef<HTMLFormElement>(null);

  function submit(text: string, clientId = crypto.randomUUID()) {
    setFailed((f) => f.filter((m) => m.id !== clientId));
    startTransition(async () => {
      addOptimistic({ id: clientId, text, author: "You", status: "pending" });
      const res = await sendMessage(threadId, clientId, text).catch(() => ({ ok: false as const, error: "Network error" }));
      if (!res.ok) setFailed((f) => [...f, { id: clientId, text, author: "You", status: "failed" }]);
    });
  }

  return (
    <>
      <ol aria-live="polite" className="space-y-2">
        {[...optimistic, ...failed].map((m) => (
          <li key={m.id} className={m.status === "pending" ? "opacity-60" : ""}>
            <span className="font-semibold">{m.author}:</span> {m.text}
            {m.status === "pending" && <span className="ml-2 text-xs text-neutral-500">Sending...</span>}
            {m.status === "failed" && (
              <span className="ml-2 text-xs text-red-700">Not sent. <button className="underline" onClick={() => submit(m.text, m.id)}>Retry</button></span>
            )}
          </li>
        ))}
      </ol>
      <form ref={formRef} action={(fd) => { const t = String(fd.get("text") ?? ""); if (t.trim()) { submit(t); formRef.current?.reset(); } }}>
        <label htmlFor="text" className="sr-only">Message</label>
        <input id="text" name="text" autoComplete="off" />
        <button type="submit">Send</button>
      </form>
    </>
  );
}
```

TanStack Query (React SPA) toggle with rollback:

```tsx
const qc = useQueryClient();
const toggleStar = useMutation({
  mutationFn: (p: { id: string; starred: boolean }) => api.setStar(p.id, p.starred),
  onMutate: async ({ id, starred }) => {
    await qc.cancelQueries({ queryKey: ["repos"] });
    const prev = qc.getQueryData<Repo[]>(["repos"]);
    qc.setQueryData<Repo[]>(["repos"], (rs) => rs?.map((r) => (r.id === id ? { ...r, starred } : r)));
    return { prev };
  },
  onError: (_e, _v, ctx) => { qc.setQueryData(["repos"], ctx?.prev); toast.error("Couldn't update star. Try again."); },
  onSettled: () => qc.invalidateQueries({ queryKey: ["repos"] }),
});
```

## Recommended Workflow
1. Classify each mutation with the decision table (stakes, reversibility, success rate, predictability).
2. Define pending and failed visuals and copy for each optimistic action.
3. Make the server endpoint idempotent (client ID / idempotency key).
4. Implement optimistic update + reconciliation + rollback + retry.
5. Test with slow and failing network, rapid repeated clicks, and out-of-order responses.
6. Monitor mutation failure rates; if > ~1%, reconsider optimism.

## Patterns
- **Pending item with temp ID** replaced by server item.
- **Undo instead of confirm**: hide immediately, commit after 5-10s unless undone.
- **Last-write-wins toggle**: serialize requests per item; ignore stale responses.
- **Failed item stays in place** with retry/discard.
- **Batch optimistic** for bulk actions with partial-failure reporting.

## Anti-Patterns
- **Silent rollback** — users think the action worked, then it quietly reverts. Fix: explicit message + retry.
- **Optimistic payments or permission changes** — dangerous false success. Fix: pending -> confirmed.
- **Calling `useOptimistic` setter outside a transition** — warning and flash. Fix: `startTransition` or form action.
- **Showing temp IDs/URLs** that 404 before sync — Fix: disable navigation to pending items.
- **No refetch cancellation** — stale query overwrites optimistic state (flicker). Fix: `cancelQueries` in `onMutate`.
- **Duplicate records on retry** — Fix: idempotency key.

## Accessibility
- Announce outcomes that aren't visually obvious or are off-screen ("Message sent", "Couldn't archive") via polite live region/toast (4.1.3).
- Toggle buttons use `aria-pressed` reflecting the optimistic state; on rollback, update and announce.
- Don't move focus unexpectedly on rollback; keep focus on the control.
- Undo toasts must remain long enough and be keyboard reachable (2.2.1).

## Responsive Design
- Mobile networks fail more; ensure failed-state UI fits small screens and retry targets meet 24px/44px.

## Performance
- Optimistic UI improves perceived latency and INP when the update render is cheap; avoid re-rendering huge lists (memoize rows, virtualize).
- Pair with `useTransition` so optimistic renders don't block input.

## Security
- Never trust optimistic client state: authorize and validate every mutation server-side.
- Don't optimistically reveal data the user may not be allowed to see.

## Testing
- Unit: reducer for optimistic state; rollback on rejected promise.
- Playwright: `page.route` with delay to assert pending style; with 500 to assert rollback message and retry; rapid double-click results in correct final state.
- Component tests with MSW for success/failure.

## Tooling
- React 19 `useOptimistic`, `useTransition`; Next.js Server Actions + `revalidatePath`/`revalidateTag`; TanStack Query mutations; Sonner for undo toasts; Replicache/Zero/Convex/Liveblocks for sync engines with built-in optimistic updates.

## Framework Notes
- **Next.js (App Router)**: pass server data as `state` to `useOptimistic`; after the Server Action revalidates, the fresh server props replace the optimistic value. Return result objects for expected failures (the optimistic value disappears either way, so render failed items separately).
- **React (Vite SPA)**: TanStack Query `onMutate`/`onError`/`onSettled` or the simpler "variables" approach (render `mutation.variables` while `isPending`); `useOptimistic` also works with client async actions in transitions.

## AI Agent Guidance
- Do: classify mutations before choosing optimism; implement failure UI and idempotency; revalidate after settle.
- Don't: make payments, deletes without undo, or permission changes optimistic; don't swallow errors.
- Verify: throttle and force-fail requests in the browser; confirm rollback message, retry, no duplicates.

## Examples
```tsx
// Like button: useOptimistic with Server Action
"use client";
import { useOptimistic, startTransition } from "react";
import { setLike } from "./actions";
export function LikeButton({ postId, liked, count }: { postId: string; liked: boolean; count: number }) {
  const [opt, setOpt] = useOptimistic({ liked, count });
  return (
    <button aria-pressed={opt.liked} onClick={() => startTransition(async () => {
      const next = !opt.liked;
      setOpt({ liked: next, count: opt.count + (next ? 1 : -1) });
      const res = await setLike(postId, next);
      if (!res.ok) toast.error("Couldn't update like. Try again.");
    })}>
      {opt.liked ? "Liked" : "Like"} · {opt.count}
    </button>
  );
}
```

## Related Skills
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — Actions, transitions, useOptimistic mechanics
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — server mutation side
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — SPA optimistic mutations
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — undo vs confirm
- [loading-states](../loading-states/Skill.md) — when to show pending instead
- [error-states](../error-states/Skill.md) — failure messaging
- [realtime-collaboration-ui](../realtime-collaboration-ui/Skill.md) — conflict resolution

## Sources
- [React docs: useOptimistic](https://react.dev/reference/react/useOptimistic) — Official — signature, transition requirement, automatic revert
- [Next.js docs: Server Actions and mutations](https://nextjs.org/docs/app/getting-started/updating-data) — Official — revalidation after mutations
- [TanStack Query: Optimistic Updates](https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates) — Open Source — onMutate/rollback, variables approach
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Open Source (MIT) — recommends optimistic updates with rollback
- [Laws of UX: Doherty Threshold](https://lawsofux.com/doherty-threshold/) — Community

## License / Usage Notes
React docs CC BY 4.0; TanStack MIT. Code original.

## Quality Tier
S — official API behavior verified against current React docs; clear safety criteria.

## Status
Active

## Last Verified
2026-09-15
