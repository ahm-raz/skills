# Workflow and Approval UI

## Summary
Patterns for building approval flows in React + Next.js: purchase requests, expense claims, content review, access requests, change requests. The server owns a typed state machine. The UI shows the current state, the actions this user may take, who owns the next step, and the full history. Every transition is a Server Action that re-authorizes the user, checks the allowed transition, and uses optimistic concurrency.

## Category
Enterprise UI

## Subcategories
State machines, approval inbox / worklist, multi-level approvals, delegation, SLA and escalation, comments and audit trail, optimistic concurrency, idempotent mutations

## Problem It Solves
Approval UIs often let users do things they shouldn't. A button shows up for the wrong role. Two approvers act on the same stale record. A double-click approves twice. A reject goes through with no reason. The UI also forgets to say who has the item now. The result is lost trust, broken compliance, and "where is my request?" support tickets. This skill makes status, allowed actions, ownership, and history explicit and enforced on the server.

## When To Use
- Any record that moves through named states with different people acting at each step (draft -> submitted -> approved/rejected -> fulfilled).
- Multi-step sign-off (manager, then finance, then director above a threshold).
- Regulated processes that need a who/when/why trail (SOX, GxP, ISO change control).
- Queues where people process many items: approval inbox, review queue, worklist.

## When Not To Use
- Simple CRUD with no lifecycle. A `status` badge is enough.
- Free-form collaboration where there is no gatekeeping step. Use comments and activity feeds instead.
- Long-running technical orchestration (retries, compensation across services). Use a workflow engine on the backend. This skill covers only its UI surface.

## Core Principles
1. **The server owns the state machine.** The client never computes the next status. It asks the server to run a named transition.
2. **Show only actions that are allowed, and still enforce them on the server.** Hiding a button is a UX choice, not security. Server Actions can be reached by direct POST, so re-check authentication, authorization, and the transition inside every action.
3. **Every transition is guarded and idempotent.** Send the expected `version` (or ETag) and an idempotency key. Reject stale or duplicate submissions with a clear message.
4. **Always make ownership visible.** Every screen answers: current state, who holds it now, since when, what happens next.
5. **Negative decisions need reasons.** Reject, return for changes, and cancel require a comment. It goes into the audit trail.
6. **History is append-only.** Transitions, comments, delegations, and escalations are events. Never overwrite them.

## Best Practices
- Model status as a string-literal union plus a transitions table. Derive both the UI actions and the server checks from that one table.
- Label buttons with the verb of the transition ("Approve", "Return for changes", "Reject"). Avoid generic "Submit" or "Update".
- Put the primary positive action last in the action bar, separated from destructive actions. Reject opens a dialog that requires a reason (min length, e.g. 10 characters).
- Show a status stepper or path at the top of the record: completed steps, current step with assignee avatar and "waiting 2d", upcoming steps greyed out.
- Put SLA indicators in the inbox. Show relative time ("due in 4h", "overdue 1d") with text, plus an icon or color. Never rely on color alone.
- In the approval inbox, default the filter to "Assigned to me, pending". Sync filters to the URL with nuqs so queues can be shared and bookmarked.
- Support delegation (out-of-office) with an effective date range. Show "Acting on behalf of Dana" in the header and write it to the audit trail.
- For multi-level approvals, show the whole chain up front, including conditional levels ("Director approval required because amount > $10,000").
- After an action, move to the next item in the queue (worklist "approve and next"). Announce the result through a live region.
- Put comments and the event history in one chronological timeline. Let users filter it to "decisions only".

## Implementation Guidance

### 1. Typed state machine (shared, pure, no I/O)
```ts
// lib/workflow/purchase-request.ts
export type PRStatus = 'draft' | 'submitted' | 'manager_approved' | 'approved' | 'rejected' | 'returned' | 'cancelled';
export type PRTransition = 'submit' | 'approve' | 'reject' | 'return' | 'resubmit' | 'cancel';
export type Role = 'requester' | 'manager' | 'finance';

type Rule = { from: PRStatus[]; to: PRStatus | ((ctx: { amountMinor: number }) => PRStatus); roles: Role[]; requiresReason?: boolean };

export const TRANSITIONS: Record<PRTransition, Rule> = {
  submit:   { from: ['draft'], to: 'submitted', roles: ['requester'] },
  approve:  { from: ['submitted', 'manager_approved'], roles: ['manager', 'finance'],
              to: ({ amountMinor }) => (amountMinor > 1_000_000 ? 'manager_approved' : 'approved') },
  reject:   { from: ['submitted', 'manager_approved'], to: 'rejected', roles: ['manager', 'finance'], requiresReason: true },
  return:   { from: ['submitted', 'manager_approved'], to: 'returned', roles: ['manager', 'finance'], requiresReason: true },
  resubmit: { from: ['returned'], to: 'submitted', roles: ['requester'] },
  cancel:   { from: ['draft', 'returned', 'submitted'], to: 'cancelled', roles: ['requester'], requiresReason: true },
};

export function availableTransitions(status: PRStatus, roles: Role[]): PRTransition[] {
  return (Object.keys(TRANSITIONS) as PRTransition[]).filter(
    (t) => TRANSITIONS[t].from.includes(status) && TRANSITIONS[t].roles.some((r) => roles.includes(r)),
  );
}
```
The two-level approval above is a simplification. In a real implementation, the second `approve` must require a *different* approver with the `finance` role. Enforce that (and separation of duties: requester never equals approver) in the DAL, not just in this table.

### 2. Transition Server Action (thin) calling a server-only DAL
```ts
// app/requests/[id]/actions.ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { runTransition } from '@/data/purchase-requests';

const Input = z.object({
  id: z.string().uuid(),
  transition: z.enum(['submit', 'approve', 'reject', 'return', 'resubmit', 'cancel']),
  version: z.coerce.number().int(),
  reason: z.string().trim().max(2000).optional(),
  idempotencyKey: z.string().uuid(),
});

export type TransitionState = { ok: boolean; message?: string; conflict?: boolean };

export async function transitionAction(_: TransitionState, formData: FormData): Promise<TransitionState> {
  const parsed = Input.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { ok: false, message: 'Invalid input' };
  const result = await runTransition(parsed.data); // authn + authz + transition rule + version check inside
  if (result.kind === 'conflict') return { ok: false, conflict: true, message: 'This request changed since you opened it. Reload to see the latest.' };
  if (result.kind === 'forbidden') return { ok: false, message: 'You can no longer perform this action.' };
  revalidatePath(`/requests/${parsed.data.id}`);
  revalidatePath('/inbox');
  return { ok: true };
}
```
```ts
// data/purchase-requests.ts
import 'server-only';
import { TRANSITIONS } from '@/lib/workflow/purchase-request';
import { getCurrentUser } from '@/data/auth';
import { db } from '@/lib/db';

export async function runTransition(input: { id: string; transition: keyof typeof TRANSITIONS; version: number; reason?: string; idempotencyKey: string }) {
  const user = await getCurrentUser();
  if (!user) return { kind: 'forbidden' } as const;
  const seen = await db.idempotency.find(input.idempotencyKey);
  if (seen) return seen.result; // duplicate click / retry returns the same outcome

  const pr = await db.purchaseRequest.findForTenant(input.id, user.tenantId); // tenant-scoped: prevents IDOR
  const rule = TRANSITIONS[input.transition];
  const roles = await db.roles.forUserOnRecord(user.id, pr.id); // includes active delegations
  if (!pr || !rule.from.includes(pr.status) || !rule.roles.some((r) => roles.includes(r))) return { kind: 'forbidden' } as const;
  if (rule.requiresReason && !input.reason) return { kind: 'forbidden' } as const;
  if (input.transition === 'approve' && pr.requesterId === user.id) return { kind: 'forbidden' } as const; // separation of duties

  const to = typeof rule.to === 'function' ? rule.to({ amountMinor: pr.amountMinor }) : rule.to;
  // UPDATE ... SET status = $to, version = version + 1 WHERE id = $id AND version = $expected
  const updated = await db.purchaseRequest.updateIfVersion(pr.id, input.version, { status: to });
  if (!updated) return { kind: 'conflict' } as const;
  await db.events.append({ recordId: pr.id, type: input.transition, from: pr.status, to, actorId: user.id, onBehalfOf: roles.delegatedFrom, reason: input.reason });
  const result = { kind: 'ok' } as const;
  await db.idempotency.save(input.idempotencyKey, result);
  return result;
}
```
In production, run the version-checked update, the event append, and the idempotency save in one DB transaction.

### 3. Decision table: which approval layout
| Situation | Layout |
|---|---|
| Many similar items, fast decisions | Worklist table + side panel (master-detail) with "Approve and next" |
| Complex items needing full context | Inbox list -> full record page with sticky decision bar |
| Mobile approvers | Card list, detail page, bottom sticky bar with 2 primary actions + overflow |
| Bulk approvals of low-risk items | Row selection + bulk approve. Server validates each item and returns per-item results |

## Recommended Workflow
1. Write the state diagram with the business. List states, transitions, roles, required reasons, and SLAs.
2. Encode it as the typed `TRANSITIONS` table. Unit-test every allowed and forbidden combination.
3. Build the DAL `runTransition` with tenant scoping, role and delegation resolution, separation of duties, version check, event append, and idempotency.
4. Build thin Server Actions and wire them through `useActionState`.
5. Build the record page: status path, ownership banner, decision bar, timeline.
6. Build the inbox/worklist: URL-synced filters, SLA column, "approve and next".
7. Add delegation, escalation jobs (server-side scheduler), and notifications.
8. Test conflicts (two tabs), double-submit, forbidden direct POSTs, and the keyboard-only flow.

## Patterns
- **Decision bar**: sticky footer on the record page. Positive action (primary) on the inline-end side, "Return" (secondary), "Reject" (destructive, opens a reason dialog), overflow for Delegate/Reassign.
- **Ownership banner**: "Waiting on Finance (Priya S.) for 2 days. Due Sep 17." Includes a "Nudge" action, rate-limited on the server.
- **Status path / stepper**: an `<ol>` with `aria-current="step"` on the current stage, and visually hidden text for completed/upcoming.
- **Reason-required dialog**: a textarea with a character minimum. Submit stays enabled; errors are shown in text on submit.
- **Conflict recovery**: on `conflict`, show an inline alert with "Reload" and keep the user's typed reason in local state.
- **Idempotency key per render of the form**: `const [key] = useState(() => crypto.randomUUID())`, sent as a hidden input. Regenerate it after success.

```tsx
'use client';
import { useActionState, useState } from 'react';
import { transitionAction, type TransitionState } from './actions';

export function DecisionBar({ id, version, allowed }: { id: string; version: number; allowed: string[] }) {
  const [state, action, pending] = useActionState<TransitionState, FormData>(transitionAction, { ok: false });
  const [key] = useState(() => crypto.randomUUID());
  return (
    <form action={action} className="sticky bottom-0 flex justify-end gap-2 border-t bg-background p-3">
      <input type="hidden" name="id" value={id} />
      <input type="hidden" name="version" value={version} />
      <input type="hidden" name="idempotencyKey" value={key} />
      <p role="status" aria-live="polite" className="me-auto text-sm">{state.message}</p>
      {allowed.includes('return') && <button name="transition" value="return" disabled={pending}>Return for changes</button>}
      {allowed.includes('approve') && <button name="transition" value="approve" disabled={pending} className="btn-primary">Approve</button>}
    </form>
  );
}
```
(For brevity, the reason dialog for reject/return is omitted. It should add a `reason` field before submitting.)

## Anti-Patterns
- **Client computes the next status and sends `status: 'approved'`.** Any user can POST any status. Fix: send a transition name. The server validates it against the table.
- **Hiding the Approve button as the only control.** Fix: re-check the role and state in the Server Action/DAL, because actions are reachable by direct POST.
- **Last write wins.** Two approvers overwrite each other. Fix: version column with a conditional update, and a conflict message.
- **Double-click creates two approvals or two emails.** Fix: idempotency key plus disable while pending.
- **Reject without reason.** Requesters can't act on it. Fix: require a reason on the server, and show it in the timeline and notification.
- **Status as a free-text column** ("Pending approval", "pending", "PENDING"). Fix: enum/union plus a display-label map.
- **Hidden ownership.** Fix: ownership banner and an "assigned to" column in every list.
- **Editing history rows.** Fix: append-only events. Corrections are new events.

## Accessibility
- Status must not be conveyed by color alone (WCAG 1.4.1). Pair badges with text and icons.
- Stepper: an ordered list with `aria-current="step"`. Completed/upcoming state goes in text, not just checkmarks.
- Action results are announced via `role="status"` (WCAG 4.1.3). Errors and conflicts use `role="alert"`.
- The reason dialog follows the APG dialog pattern: focus the textarea on open, return focus to the trigger on close, label it with `aria-labelledby`.
- In "approve and next", move focus to the next item's heading and announce "Approved PR-1042. Now showing PR-1043."
- Keyboard shortcuts (e.g. `a` approve, `r` return) must be documented, disable-able or remappable (WCAG 2.1.4), and inactive while typing in inputs.

## Responsive Design
- Desktop: worklist + detail side by side. Tablet: a collapsible list. Mobile: list -> detail route, with a bottom decision bar that respects the safe-area inset.
- The timeline collapses to "decisions only" by default on small screens.
- Keep the two most common actions visible on mobile. Put the rest in an overflow menu.

## Performance
- The inbox uses server-side pagination/filtering (Server Component reading `searchParams`). Counts come from indexed queries on `(tenant_id, assignee_id, status)`.
- Stream the timeline separately (`<Suspense>`) so the decision bar renders first.
- After a transition, `revalidatePath` only the affected record and inbox, not the whole app.

## Security
- UI is never the security boundary. Authorize in Server Actions/route handlers through a `server-only` DAL.
- Tenant-scope every lookup by ID to prevent IDOR. Enforce separation of duties on the server.
- Validate all input with Zod. Treat `searchParams` and hidden fields as untrusted.
- Return minimal results from actions (no full records).
- The audit trail must record the actor, the on-behalf-of user, the timestamp (server clock), and the reason. Protect it from updates and deletes at the DB permission level.
- Rate-limit "nudge"/reminder actions.

## Testing
- Unit (Vitest): table-driven tests over `TRANSITIONS` × roles × statuses. Separation-of-duties rules.
- Integration: `runTransition` with a test DB. Version conflict, duplicate idempotency key, cross-tenant ID, and delegation window cases.
- E2E (Playwright): approve flow as each role. Two browser contexts approving at the same time (expect one conflict). Reject without reason is blocked. A forbidden role's direct action call is rejected.
- Accessibility: axe on the inbox and the record page. Keyboard-only approval run.

## Tooling
- Zod for action input validation.
- XState or a hand-written transitions table. A typed table is usually enough for UI-facing approval flows. Consider XState when parallel or hierarchical states appear. Check current XState docs for the version.
- nuqs (v2.x) for inbox filter state in the URL.
- TanStack Table (v9, `useTable` + `tableFeatures`) or AG Grid for large worklists.
- Backend workflow engines (e.g. Temporal, Camunda) for orchestration. The UI consumes their task APIs. Check each vendor's docs.

## Framework Notes
- **Next.js (App Router, 16)**: record pages are Server Components that read `params: Promise<{ id: string }>` and load a DTO with `status`, `version`, and `allowedTransitions`, computed on the server for the current user. Transitions are Server Actions plus `useActionState`. `proxy.ts` can redirect unauthenticated users but is not the authorization layer.
- **React (Vite SPA)**: the same transitions table can be imported for display. Mutations go to an API that enforces the same rules. Use TanStack Query mutations, send `If-Match: <etag>`, handle `412 Precondition Failed` as a conflict, and send an `Idempotency-Key` header.

## AI Agent Guidance
- Do: define the status union and transitions table first. Derive the UI's `allowed` from a server-computed DTO.
- Do: implement version checks, idempotency, required reasons, and tenant scoping in the DAL.
- Don't: accept a raw `status` from the client, or rely on hidden buttons for authorization.
- Don't: mutate the audit history.
- Verify before done: a forbidden transition via a direct action call fails; the two-tab conflict shows a message; double-submit yields one event; keyboard-only approval works; status is readable without color.

## Examples
```tsx
// app/inbox/page.tsx — Server Component worklist
import { createLoader, parseAsStringLiteral, parseAsInteger } from 'nuqs/server';
import { listInbox } from '@/data/inbox';

const loadInbox = createLoader({
  view: parseAsStringLiteral(['mine', 'team', 'overdue'] as const).withDefault('mine'),
  page: parseAsInteger.withDefault(1),
});

export default async function InboxPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const { view, page } = await loadInbox(searchParams);
  const { rows, total } = await listInbox({ view, page, pageSize: 50 }); // authz + tenant scope inside
  return (
    <section aria-labelledby="inbox-h">
      <h1 id="inbox-h">Approvals ({total})</h1>
      <table>
        <thead><tr><th scope="col">Request</th><th scope="col">Requester</th><th scope="col">Amount</th><th scope="col">Due</th></tr></thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id}>
              <th scope="row"><a href={`/requests/${r.id}`}>{r.title}</a></th>
              <td>{r.requesterName}</td>
              <td>{r.amountFormatted}</td>
              <td>{r.overdue ? <strong>Overdue {r.dueRelative}</strong> : `Due ${r.dueRelative}`}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
```

## Related Skills
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — timeline and immutable event history
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — computing allowed actions, server enforcement
- [bulk-actions](../bulk-actions/Skill.md) — bulk approve with per-item results
- [master-detail-layouts](../master-detail-layouts/Skill.md) — worklist + detail panel
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action security and `useActionState`
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — shareable inbox filters
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — reject/cancel dialogs
- [optimistic-ui](../optimistic-ui/Skill.md) — when (not) to be optimistic on transitions
- [toasts-and-notifications](../toasts-and-notifications/Skill.md) — decision feedback

## Sources
- [Next.js: How to think about data security](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, re-authorizing in Server Actions, IDOR ownership checks, minimal return values
- [NN/g: Design guidelines for complex applications](https://www.nngroup.com/articles/complex-application-design/) — Official (research) — flexible pathways, tracking actions, easing access to secondary info
- [nuqs server-side docs](https://nuqs.dev/docs/server-side) — Official — `createLoader`, parsers for URL-synced inbox filters
- [WAI-ARIA APG Grid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — keyboard model for interactive worklists

## License / Usage Notes
Content is original guidance summarizing the sources above, not copied. Code examples are illustrative, free to adapt. Referenced libraries: Next.js (MIT), nuqs (MIT), Zod (MIT). Check each workflow engine's license separately.

## Quality Tier
B — core security and concurrency guidance is backed by official Next.js docs; approval UX patterns come from practitioner experience and NN/g rather than a single canonical spec.

## Status
Active

## Last Verified
2026-09-15
