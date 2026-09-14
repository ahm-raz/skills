# Toasts and Notifications

## Summary
Toasts are brief, non-modal messages about the result of an action. Notifications more broadly include inline alerts, banners, and notification centers. This skill covers choosing the right feedback surface, live-region semantics (`status` vs `alert`), timing rules (WCAG 2.2.1, minimum durations, no auto-dismiss for actionable toasts), focus and landmark access (F6 regions), and React/Next.js implementation with Sonner (shadcn/ui) or React Aria Toast, including toasts after Server Actions and redirects.

## Category
Components

## Subcategories
Toast, snackbar, inline alert, banner, notification center, live regions, undo, promise toasts

## Problem It Solves
Teams overuse toasts for errors and critical info. Toasts vanish before users read them, are never announced to screen readers (or interrupt with assertive spam), stack endlessly, cover UI, and carry actions (Undo) that keyboard users can't reach in time. Toasts after server-side redirects often get lost entirely.

## When To Use
- Passive confirmation of a user-initiated action whose result isn't otherwise visible ("Message sent", "Copied").
- Undo for reversible actions ("Conversation archived · Undo"), kept on screen long enough and keyboard reachable.
- Background task completion ("Export ready · Download").

## When Not To Use
- Form validation errors: inline next to fields (NN/g: toasts are a poor choice for errors and validation).
- Errors that block progress: inline alert or a dialog if severe.
- System-wide persistent state (offline, trial expiring): banner.
- Anything the user must act on or read later: notification center/inbox or inline.
- Success where the UI already shows the change clearly (item appears in list): skip the toast or keep it minimal.

## Core Principles
1. Match surface to severity and persistence: inline (contextual), toast (transient, low severity), banner (persistent, page/system), dialog (blocking, severe).
2. Toasts are announced via live regions without moving focus: `role="status"` (polite) by default, `role="alert"` only for urgent failures.
3. Timing: long enough to read (≥5s is a common accessibility minimum, and React Aria recommends it). Pause on hover/focus and when the window is hidden. Toasts with actions don't auto-dismiss.
4. Toasts are reachable: a keyboard shortcut or landmark (F6) moves focus into the toast region, and focus is restored afterwards.
5. Keep them short (≤ ~3 lines), specific, and not dependent on color.

## Best Practices
- Write outcome-focused copy: "Invoice #1042 deleted" + "Undo". Avoid "Success!".
- Use one toaster per app, rendered once near the root. Position consistently (bottom-end or top-center) and away from primary actions and mobile nav.
- Limit visible toasts (~3). Collapse the rest into a stack; dedupe identical messages by id.
- Promise toasts: loading → success/error in the same toast (update by id), not three separate toasts.
- Provide a close button with an accessible name.
- Undo: perform the action optimistically, keep the toast until dismissed (or a long timeout with pause), and support a keyboard path.
- Error toasts are fine for *background* failures ("Couldn't sync, retrying"), with a Retry action and persistence.
- Don't toast on page load unless it reports the result of the previous action (e.g., after a redirect).

## Implementation Guidance

### Surface decision table
| Message | Surface | Role | Dismiss |
|---|---|---|---|
| "Copied to clipboard" | Toast | status | Auto ~4–6s, pause on hover/focus |
| "Archived · Undo" | Toast with action | status | No auto-dismiss (or long + pause); close button |
| "Payment failed: card declined" (checkout form) | Inline alert near form | alert | Persistent until fixed |
| "You're offline" | Banner | status | Persistent until resolved |
| "Delete workspace?" | Alert dialog | alertdialog | User choice |
| "3 new comments" | Notification center badge + list | status (badge count text) | User-managed |

### Library comparison (React)
| Library | Notes |
|---|---|
| Sonner (shadcn/ui `Sonner`) | `toast()` from anywhere; types success/error/warning/info/loading, `toast.promise`, action/cancel, id updates, default duration 4000ms, pauses on hover and when the tab is hidden, hotkey to focus the region. Raise `duration` for accessibility and set `Infinity` for actionable toasts |
| React Aria `ToastRegion`/`ToastQueue` | Landmark region navigable with F6/Shift+F6. Focus moves to the next toast or back when one closes. Docs recommend a minimum 5s timeout and no timeout for critical info. Uses view transitions |
| Radix Toast | Swipe to dismiss, hotkey (F8 default) to focus viewport, `type="foreground|background"` for assertive/polite |
| Base UI Toast | Stable in v1; unstyled, with stacking and promise support |

### ARIA
| Element | Attributes |
|---|---|
| Region | `<section aria-label="Notifications">` (landmark) containing a live region; must exist in the DOM *before* toasts are inserted |
| Toast | `role="status"` (`aria-live="polite"`, `aria-atomic="true"`) or `role="alert"` for urgent |
| Action | `<button>` with clear name ("Undo archive") |
| Close | `<button aria-label="Dismiss notification">` |

## Recommended Workflow
1. Inventory feedback moments; assign each a surface using the decision table.
2. Install one toaster at the root with accessible defaults (duration ≥ 5s, close button, max visible).
3. Wrap mutations: loading/success/error via promise toasts, or post-action toasts.
4. Implement Undo with optimistic updates and server reconciliation.
5. Handle toasts across redirects (flash cookie) in Next.js.
6. Test announcements (NVDA/VoiceOver), keyboard access to actions, reduced motion, mobile placement.

## Patterns

### Root toaster (Next.js App Router with shadcn/ui Sonner)
```tsx
// app/providers.tsx
'use client';
import { Toaster } from '@/components/ui/sonner';
export function Providers({ children }: { children: React.ReactNode }) {
  return (<>{children}<Toaster position="bottom-right" closeButton visibleToasts={3} duration={6000} /></>);
}
```
```tsx
// app/layout.tsx (Server Component)
import { Providers } from './providers';
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body><Providers>{children}</Providers></body></html>;
}
```

### Server Action + promise toast
```tsx
'use client';
import { toast } from 'sonner';
import { archiveConversation, unarchiveConversation } from './actions';

export function ArchiveButton({ id, title }: { id: string; title: string }) {
  return (
    <button type="button" onClick={() => {
      toast.promise(archiveConversation(id), {
        loading: `Archiving “${title}”…`,
        success: () => ({
          message: `“${title}” archived`,
          duration: Infinity,
          action: { label: 'Undo', onClick: () => void unarchiveConversation(id) },
        }),
        error: 'Couldn’t archive. Try again.',
      });
    }}>Archive</button>
  );
}
```
Check the current Sonner API for returning per-state options from `success`. If it isn't supported, call `toast.success(...)` with an explicit `id` after awaiting.

### Toast after redirect (flash cookie)
```ts
// app/projects/actions.ts
'use server';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
export async function createProject(formData: FormData) {
  const project = await db.project.create({ data: { name: String(formData.get('name')) } });
  (await cookies()).set('flash', JSON.stringify({ type: 'success', message: `Project “${project.name}” created` }), { maxAge: 10, path: '/' });
  redirect(`/projects/${project.id}`);
}
```
```tsx
// app/flash-toaster.tsx: rendered by the layout
'use client';
import { useEffect } from 'react';
import { toast } from 'sonner';
export function FlashToast({ flash }: { flash?: { type: 'success' | 'error'; message: string } }) {
  useEffect(() => { if (flash) toast[flash.type](flash.message, { id: flash.message }); }, [flash]);
  return null;
}
```
The layout reads the cookie via `cookies()` and passes it in. Clear the cookie in a Server Action or route handler after reading, because cookies can't be modified during Server Component rendering. The `id` dedupes toasts in React Strict Mode double effects.

### Minimal accessible live region (no library)
```tsx
'use client';
export function StatusRegion({ message }: { message: string }) {
  // Always mounted; content changes are announced politely
  return <div role="status" aria-live="polite" aria-atomic="true" className="sr-only">{message}</div>;
}
```

## Anti-Patterns
- **Validation errors in toasts**: disconnected from fields, and they disappear. Fix: inline errors + error summary.
- **3-second auto-dismiss with an Undo action**: unreachable for keyboard, screen reader, and cognitive-disability users. Fix: no auto-dismiss for actions, pause on focus/hover, and a hotkey to reach it.
- **Mounting the live region together with the message**: often not announced. Fix: region persists; insert messages into it.
- **`role="alert"` for every success**: interrupts screen reader users. Fix: `status` by default.
- **Toast storms** (one per item in a bulk action): Fix: aggregate ("12 items archived").
- **Covering the primary CTA or mobile bottom nav**: Fix: position and offset with safe areas.
- **Color-only type indication**: Fix: icon + text ("Error:").
- **Losing toasts on redirect**: Fix: flash cookie/search param, consumed once.

## Accessibility
- WCAG 4.1.3 Status Messages, 2.2.1 Timing Adjustable, 2.2.4 Interruptions (AAA), 1.4.1 Use of Color, 2.1.1 Keyboard (actions reachable), 2.4.3 Focus Order (restore focus), 1.4.13 (hover-revealed toast details), 2.3.3 and reduced motion for slide animations.
- APG Alert pattern: alerts don't move focus, and auto-disappearing alerts risk failing 2.2.3. Keep critical alerts persistent.
- Test NVDA + Chrome, VoiceOver + Safari, and TalkBack for announcement reliability.

## Responsive Design
- Mobile: top-center or bottom above the tab bar; full-width with safe-area padding; swipe to dismiss as an extra (keep the close button).
- Keep the toast width within `min(24rem, 100vw - 2rem)`; wrap text; don't truncate the message.

## Performance
- Single toaster instance; avoid re-rendering the app on toast state (Sonner uses an external store).
- Lightweight animations (transform/opacity); disable under `prefers-reduced-motion`.

## Security
- Never include secrets, tokens, or sensitive PII in toast text (shoulder surfing, screenshots, session replay tools).
- Escape messages derived from user or server data (React escapes by default; avoid rendering HTML strings).
- Undo must be authorized server-side like any mutation.

## Testing
- Testing Library: trigger the action → `findByRole('status')` has text; action button `getByRole('button', {name:/undo/i})` works; fake timers verify pause and auto-dismiss durations.
- Playwright: toast survives redirect (flash); hover pauses timer; keyboard hotkey reaches the toast and restores focus.
- Screen reader manual check for announcements and politeness.
- axe: region landmark labels, button names.

## Tooling
- Sonner (MIT) via shadcn/ui; React Aria Components Toast; Radix Toast; Base UI Toast.
- Testing: @testing-library/react, Playwright, axe-core.

## Framework Notes
- **React (Vite SPA)**: Mount `<Toaster />` once in the app root. Call `toast()` from mutation handlers (TanStack Query `onSuccess`/`onError`, or `toast.promise(mutation.mutateAsync(...))`). Survive route transitions by keeping the toaster outside route outlets.
- **Next.js (App Router)**: The toaster lives in a client `providers.tsx` rendered by the root layout, and stays mounted across navigations. Server Actions can't call `toast()`. Return a result (`{ ok, message }`) consumed with `useActionState` and toast on the client, or use a flash cookie when you `redirect()`. Don't render toast content on the server, since the portal mounts after hydration. For errors from `error.tsx` boundaries, render inline UI, not toasts.

## AI Agent Guidance
- DO pick the surface by severity; DO default to `role="status"` and ≥5–6s durations with pause.
- DO make actionable toasts persistent and keyboard reachable.
- DON'T use toasts for form validation or critical errors.
- DON'T mount multiple toasters or create per-item toast storms.
- Verify: announced once, politely; action reachable by keyboard; timer pauses; survives redirects; no overlap with primary UI on mobile; reduced motion respected.

## Examples
React Aria Components toast queue (conceptual; check the current API):
```tsx
import { UNSTABLE_ToastQueue as ToastQueue, UNSTABLE_ToastRegion as ToastRegion, UNSTABLE_Toast as Toast, UNSTABLE_ToastContent as ToastContent, Text, Button } from 'react-aria-components';

export const queue = new ToastQueue<{ title: string; description?: string }>({ maxVisibleToasts: 3 });

export function GlobalToasts() {
  return (
    <ToastRegion queue={queue}>
      {({ toast }) => (
        <Toast toast={toast}>
          <ToastContent><Text slot="title">{toast.content.title}</Text>
            {toast.content.description && <Text slot="description">{toast.content.description}</Text>}</ToastContent>
          <Button slot="close" aria-label="Dismiss">×</Button>
        </Toast>
      )}
    </ToastRegion>
  );
}
// queue.add({ title: 'Settings saved' }, { timeout: 6000 });
```
Toast APIs in React Aria have carried `UNSTABLE_` prefixes. Verify whether they're stable in your installed version.

## Related Skills
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md): politeness and reliability
- [error-states](../error-states/Skill.md): where errors belong
- [optimistic-ui](../optimistic-ui/Skill.md): undo and optimistic updates
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): action results and redirects
- [small-ui-primitives-vaul-sonner-cmdk](../small-ui-primitives-vaul-sonner-cmdk/Skill.md): Sonner
- [form-validation-patterns](../form-validation-patterns/Skill.md): inline errors instead of toasts
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md): message copy
- [realtime-data-ui](../realtime-data-ui/Skill.md): background notifications

## Sources
- [NN/g: Indicators, Validations, and Notifications](https://www.nngroup.com/articles/indicators-validations-notifications/) — Research — toasts not for errors, ≤3 lines
- [WAI-ARIA APG: Alert Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/alert/) — Official — no focus change, avoid auto-dismissing alerts
- [React Aria: Toast](https://react-aria.adobe.com/Toast) — Open Source — F6 landmark, ≥5s timeout, focus restoration
- [Sonner docs: Toast](https://sonner.emilkowal.ski/toast) — Open Source — types, promise, action, default 4000ms, ids
- [Radix Toast](https://www.radix-ui.com/primitives/docs/components/toast) — Open Source — foreground/background types, hotkey
- [Base UI Releases](https://base-ui.com/react/overview/releases) — Open Source — Toast availability

## License / Usage Notes
Summarized in original wording; code original. Sonner/Radix/Base UI MIT; React Aria Apache-2.0.

## Quality Tier
A — official patterns + research + library docs. Carbon/Polaris notification guidance couldn't be retrieved this pass, and the Sonner hotkey default wasn't re-verified.

## Status
Active

## Last Verified
2026-09-15
