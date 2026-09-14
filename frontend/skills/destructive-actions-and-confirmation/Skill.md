# Destructive Actions and Confirmation

## Summary
How to design delete, remove, revoke, cancel-subscription, overwrite, and other consequential actions so users don't cause accidental loss, without burying them in "Are you sure?" dialogs. Covers the undo-vs-confirm decision, friction levels (type-to-confirm), dialog copy and button labeling, placement and separation, and React/Next.js implementation with Server Actions and accessible alert dialogs.

## Category
UX

## Subcategories
confirmation dialogs, undo, soft delete, type-to-confirm, danger zone, bulk delete, irreversible actions, alertdialog

## Problem It Solves
Two failure modes: accidental irreversible loss (dangerous buttons next to safe ones, vague dialogs), and confirmation fatigue (dialogs on every action train users to click "OK" without reading, making the real dangerous confirmation useless).

## When To Use
- Deleting/removing data, revoking access/keys, leaving/closing workspaces, canceling plans, discarding unsaved changes, overwriting files, bulk operations, publishing to production.

## When Not To Use
- Easily reversible, low-impact actions (archive, mark read, remove filter): use undo, no confirmation.
- Consent to deceptive retention flows (see ethical-design-and-dark-patterns): friction must protect users, not obstruct them.

## Core Principles
1. **Prefer undo over confirmation** for reversible actions (NN/g): act immediately, offer undo.
2. **Confirm only when the action is irreversible or high-impact**; keep confirmations rare so they retain meaning.
3. **Scale friction to consequence**: none -> undo -> confirm dialog -> type-to-confirm -> re-authentication.
4. **Be specific**: name the object and the consequence ("Delete project “Atlas” and its 42 tasks?").
5. **Label buttons with the verb**, not "OK/Yes" ("Delete project" / "Cancel").
6. **Separate destructive from safe controls** spatially and visually (NN/g: consequential options away from benign ones).
7. **Don't make destructive the default focus**; Enter shouldn't delete by default.
8. **Honest friction only**: cancellation and account deletion must remain easy to complete.

## Best Practices
- Soft delete with a retention period (Trash, 30 days) whenever possible; tell users how long.
- Undo toast: "Project archived. Undo" for 5-10s; pause timer on hover/focus; commit on timeout.
- Confirmation dialog anatomy: title as question with object name; body stating consequences (what's lost, who is affected, reversibility); cancel + destructive action button labeled with verb.
- Type-to-confirm (enter the resource name) only for catastrophic actions (delete repository, organization, production database).
- Re-authentication for account deletion, security settings, and payout changes.
- Danger zone: group destructive settings at the bottom of settings page in a clearly marked section.
- Bulk destructive actions: show count and sample ("Delete 128 files?"); partial failure reporting.
- Unsaved changes: warn on navigation only if there are real unsaved changes; offer "Save" / "Discard" / "Keep editing".
- Don't use red for non-destructive primary actions; reserve danger styling.
- After deletion, navigate to a sensible place (parent list) and confirm with a toast.

## Implementation Guidance

Friction ladder:

| Consequence | Reversible? | Pattern | Example |
|---|---|---|---|
| Low | Yes | Act + undo toast | Archive email, remove tag |
| Medium | Yes (trash) | Act + toast with "View trash"/undo | Delete document (30-day trash) |
| Medium | No | Confirm dialog | Remove member, revoke API key |
| High | No, broad impact | Confirm dialog + type name | Delete project/repo/org |
| Critical / security | No | Re-auth + confirm | Delete account, disable 2FA |

Copy examples:

| Element | Weak | Strong |
|---|---|---|
| Title | "Are you sure?" | "Delete “Q3 Report”?" |
| Body | "This action cannot be undone." (only) | "The report and its 12 comments will be permanently deleted. Collaborators will lose access." |
| Confirm button | "OK" / "Yes" | "Delete report" |
| Cancel button | "No" | "Cancel" (or "Keep report") |
| Revoke | "Continue" | "Revoke key" + body "Apps using this key will stop working immediately." |

Avoid double negatives ("Cancel cancellation?"): use "Cancel subscription" / "Keep subscription".

```tsx
// components/confirm-delete-dialog.tsx — Radix AlertDialog (via shadcn/ui) + Server Action
"use client";
import { useActionState, useState } from "react";
import * as AlertDialog from "@radix-ui/react-alert-dialog";
import { deleteProject } from "@/app/(app)/projects/actions";

export function DeleteProjectDialog({ project }: { project: { id: string; name: string; taskCount: number } }) {
  const [typed, setTyped] = useState("");
  const [state, action, pending] = useActionState(deleteProject, { error: undefined as string | undefined });
  const matches = typed === project.name;

  return (
    <AlertDialog.Root>
      <AlertDialog.Trigger className="btn-danger-outline">Delete project</AlertDialog.Trigger>
      <AlertDialog.Portal>
        <AlertDialog.Overlay className="fixed inset-0 bg-black/40" />
        <AlertDialog.Content className="fixed left-1/2 top-1/2 w-[min(32rem,92vw)] -translate-x-1/2 -translate-y-1/2 rounded-lg bg-white p-6">
          <AlertDialog.Title className="text-lg font-semibold">Delete “{project.name}”?</AlertDialog.Title>
          <AlertDialog.Description className="mt-2 text-sm text-neutral-700">
            This permanently deletes the project and its {project.taskCount} tasks. This can’t be undone.
          </AlertDialog.Description>
          <form action={action} className="mt-4">
            <input type="hidden" name="projectId" value={project.id} />
            <label htmlFor="confirm-name" className="text-sm">To confirm, type <strong>{project.name}</strong></label>
            <input id="confirm-name" autoComplete="off" className="mt-1 w-full" value={typed} onChange={(e) => setTyped(e.target.value)} />
            {state.error && <p role="alert" className="mt-2 text-sm text-red-700">{state.error}</p>}
            <div className="mt-6 flex justify-end gap-3">
              <AlertDialog.Cancel className="btn-secondary">Cancel</AlertDialog.Cancel>
              <button type="submit" className="btn-danger" disabled={!matches || pending} aria-disabled={!matches || pending}>
                {pending ? "Deleting..." : "Delete project"}
              </button>
            </div>
          </form>
        </AlertDialog.Content>
      </AlertDialog.Portal>
    </AlertDialog.Root>
  );
}
```

```ts
// app/(app)/projects/actions.ts
"use server";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
export async function deleteProject(_: { error?: string }, fd: FormData) {
  const user = await requireUser();
  const id = String(fd.get("projectId"));
  if (!(await can(user, "project:delete", id))) return { error: "You don't have permission to delete this project." };
  try { await softDeleteProject(id, { retentionDays: 30, by: user.id }); }
  catch { return { error: "We couldn't delete the project. Try again." }; }
  revalidatePath("/projects");
  redirect("/projects?deleted=1"); // outside try/catch
}
```

```tsx
// Undo pattern with Sonner: act immediately, allow undo
"use client";
import { toast } from "sonner";
import { startTransition } from "react";
import { archiveConversation, unarchiveConversation } from "./actions";
export function ArchiveButton({ id, title }: { id: string; title: string }) {
  return (
    <button onClick={() => startTransition(async () => {
      await archiveConversation(id);
      toast(`“${title}” archived`, { duration: 8000, action: { label: "Undo", onClick: () => startTransition(() => unarchiveConversation(id)) } });
    })}>Archive</button>
  );
}
```

## Recommended Workflow
1. Inventory destructive actions; rate consequence and reversibility.
2. Choose pattern via friction ladder; prefer building soft delete/undo into the data model.
3. Write specific dialog/toast copy with object names and consequences.
4. Place controls: separated from safe actions; danger zone for settings.
5. Implement server authorization, audit logging, and idempotency.
6. Test keyboard flow (focus starts on Cancel or the least destructive control), screen reader announcement, and failure paths.
7. Review metrics: undo usage, support tickets for accidental deletions.

## Patterns
- **Undo toast** (reversible actions).
- **Trash / recently deleted** with restore and retention notice.
- **Alert dialog with verb buttons**.
- **Type-to-confirm** for catastrophic scope.
- **Danger zone** section in settings.
- **Unsaved-changes guard**: "Discard unsaved changes?" with "Discard" / "Keep editing".
- **Two-step bulk delete**: selection count in toolbar -> confirm with count.

## Anti-Patterns
- **Confirming everything** — confirmation blindness. Fix: undo for reversible, confirm only irreversible.
- **"Are you sure?" + OK/Cancel** — ambiguous. Fix: name object and use verb labels.
- **Delete next to Save with same style** — mis-clicks. Fix: separate and style destructive distinctly.
- **Destructive button focused by default** — Enter deletes. Fix: initial focus on Cancel (Radix AlertDialog does this).
- **Type-to-confirm on minor actions** — hostility. Fix: reserve for catastrophic.
- **Confirmshaming** ("No, I don't care about my data") — manipulative. Fix: neutral labels.
- **Obstructive cancellation** (multi-page retention mazes) — dark pattern and regulatory risk. Fix: one clear offer at most, then cancel.
- **Hover-only delete icons** — inaccessible and accidental on touch. Fix: visible in row menu with label.

## Accessibility
- Use `role="alertdialog"` with `aria-labelledby`/`aria-describedby` (Radix AlertDialog/React Aria handle this); focus trapped, Esc cancels, focus returns to trigger (2.4.3).
- Error prevention for legal/financial/data (3.3.4): reversible, checked, or confirmed.
- Undo toasts: sufficient time or pausable (2.2.1), reachable by keyboard, announced politely (4.1.3).
- Don't rely on red alone; include text "Delete" and icon (1.4.1).

## Responsive Design
- On mobile, use bottom sheets or full-width dialogs with large targets; stack buttons with destructive action not in the thumb's default tap spot, or clearly separated.
- Swipe-to-delete must have a visible alternative and undo.

## Performance
- Undo-window deletion avoids expensive restores; commit asynchronously.
- Bulk deletes run as background jobs with progress for large sets.

## Security
- Authorize every destructive action server-side; log to audit trail (who, what, when).
- Re-auth (step-up) for account deletion, credential and billing changes.
- Protect against CSRF (Server Actions include origin checks; still validate).
- Rate-limit bulk destructive endpoints.

## Testing
- Playwright: dialog opens, Cancel leaves data intact, confirm deletes and redirects, keyboard Esc cancels, type-to-confirm gating.
- Test undo within window and commit after timeout (fake timers in component tests).
- Authorization tests for unpermitted users.

## Tooling
- Radix `AlertDialog` / shadcn/ui `AlertDialog`, React Aria `AlertDialog`, Sonner toasts with actions, soft-delete helpers in ORMs (Prisma extensions, Drizzle `deletedAt`).

## Framework Notes
- **Next.js (App Router)**: Server Action performs authz + soft delete; call `redirect()` outside try/catch; use `revalidatePath`/`revalidateTag`. Intercept navigation with unsaved changes carefully (no official router blocking API; use `beforeunload` for hard navigations and guard in-app links).
- **React (Vite SPA)**: React Router `useBlocker` for unsaved-change guards; TanStack Query mutation with optimistic removal + undo.

## AI Agent Guidance
- Do: choose undo vs confirm via the friction ladder; name the object and consequence; label buttons with verbs; separate destructive controls; authorize server-side.
- Don't: add "Are you sure?" to every action; don't default focus to destructive button; don't write guilt-inducing copy.
- Verify: keyboard-only delete flow, Cancel really cancels, failure shows error, audit/log entry exists.

## Examples
```tsx
// Danger zone section on settings page (Server Component)
export function DangerZone({ project }: { project: Project }) {
  return (
    <section aria-labelledby="danger-h" className="mt-12 rounded-lg border border-red-300 p-6">
      <h2 id="danger-h" className="font-semibold text-red-900">Danger zone</h2>
      <div className="mt-4 flex items-center justify-between gap-4">
        <div>
          <h3 className="font-medium">Delete this project</h3>
          <p className="text-sm text-neutral-600">Deleted projects stay in Trash for 30 days, then are removed permanently.</p>
        </div>
        <DeleteProjectDialog project={project} />
      </div>
    </section>
  );
}
```

## Related Skills
- [accessible-dialogs](../accessible-dialogs/Skill.md) — alert dialog accessibility
- [toasts-and-notifications](../toasts-and-notifications/Skill.md) — undo toasts
- [optimistic-ui](../optimistic-ui/Skill.md) — immediate action with rollback
- [bulk-actions](../bulk-actions/Skill.md) — bulk destructive operations
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — honest friction vs obstruction
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — button labels and dialog copy
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — recording destructive actions
- [buttons-and-actions](../buttons-and-actions/Skill.md) — button hierarchy and danger variants

## Sources
- [NN/g: Confirmation Dialogs Can Prevent User Errors](https://www.nngroup.com/articles/confirmation-dialog/) — Community (research) — rarity, specificity, undo preference
- [NN/g: Proximity of Consequential Options](https://www.nngroup.com/articles/proximity-consequential-options/) — Community — separation
- [NN/g: Cancel vs Close](https://www.nngroup.com/articles/cancel-vs-close/) — Community — labeling
- [WAI-ARIA APG: Alert and Message Dialogs](https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/) — Official — alertdialog semantics
- [Radix UI AlertDialog](https://www.radix-ui.com/primitives/docs/components/alert-dialog) — Open Source (MIT) — focus behavior
- [deceptive.design: Confirmshaming, Hard to cancel](https://deceptive.design/types/) — Community — anti-patterns

## License / Usage Notes
Guidance summarized; Radix MIT; code original.

## Quality Tier
A — strong research consensus and official ARIA patterns; friction thresholds are judgment calls.

## Status
Active

## Last Verified
2026-09-15
