# Accessible Dialogs

## Summary
How to build modal and non-modal dialogs (including alert/confirmation dialogs) that are keyboard-operable, correctly announced by screen readers, and robust across browsers. Covers the native `<dialog>` element with `showModal()`, invoker commands, `closedby`, scroll locking, animation, and when a headless library (Radix, React Aria, Base UI, Ariakit, Headless UI) is still the better choice.

## Category
Components

## Subcategories
Overlays, modal dialogs, alert dialogs, confirmation dialogs, focus management, top layer, inert

## Problem It Solves
Hand-rolled modals are a common source of serious accessibility bugs. Focus escapes behind the overlay, Escape doesn't close it, the background stays reachable to screen readers, focus is lost on close, and the page scrolls behind it. Stacking and z-index also break. The platform now handles most of this natively, but teams still ship `div`-based modals or misuse `<dialog>`.

## When To Use
- A task needs the user's full attention before continuing (confirm destructive action, required decision, short focused form).
- Content must block interaction with the rest of the page (modal) or float over it while the page stays usable (non-modal dialog).
- An `alertdialog` is needed: an urgent message that requires a response.

## When Not To Use
- Long or multi-step flows: use a page or route instead (deep-linkable, back button works).
- Passive confirmations ("Saved"): use a toast or inline status.
- Contextual, lightweight content anchored to a trigger: use a popover or menu.
- Validation errors: show them inline next to fields, not in a modal.
- Marketing interruptions on page load: these are hostile UX and often fail WCAG 2.2.1/2.4.3 expectations.

## Core Principles
1. Use `<dialog>` + `showModal()` for modals; it provides top-layer rendering, `::backdrop`, background inertness, implicit `aria-modal="true"`, and Escape handling.
2. Every dialog has an accessible name (`aria-labelledby` pointing at its visible heading, or `aria-label`).
3. Focus moves into the dialog on open and returns to the invoker (or a logical successor) on close.
4. Tab/Shift+Tab stay inside a modal; Escape closes it unless closing would lose data (then confirm).
5. Always provide a visible close/cancel control; never rely on Escape or backdrop click alone.
6. Inertness and scroll-locking are separate problems; the browser only solves inertness.

## Best Practices
- Title the dialog with a real heading (`<h2>`) and reference it via `aria-labelledby`.
- Initial focus (APG guidance): first interactive element for simple dialogs. For content-heavy dialogs, focus a `tabindex="-1"` heading or the first paragraph so the top isn't scrolled away. For destructive confirmations, focus the least destructive action (Cancel).
- Use `autofocus` inside `<dialog>` to set initial focus declaratively. Do not put `tabindex` on the `<dialog>` element itself.
- Use `<form method="dialog">` for buttons that simply close with a `returnValue`.
- Use `aria-describedby` only for short plain text. Omit it when the body has lists, tables or headings that must be read structurally.
- Button labels state the outcome ("Delete project", "Keep editing"), not "OK/Cancel" where ambiguous.
- Don't nest modals. If you must, the child is opened from inside the parent and closes first.
- Guard unsaved changes: intercept `cancel` and ask for confirmation rather than silently discarding.
- Keep dialogs small on mobile. At narrow widths make them full-screen or switch to a bottom sheet.

## Implementation Guidance

### Native vs library decision table
| Need | Recommended | Notes |
|---|---|---|
| Standard modal/confirm in any framework | Native `<dialog>` + `showModal()` | Baseline widely available since 2022 |
| Declarative open/close without JS | `<button commandfor="id" command="show-modal">` | Invoker commands Baseline (Chrome 135, Firefox 144, Safari 26.2) |
| Light dismiss (click outside) | `closedby="any"` | Chrome/Edge 134, Firefox 141; **not in Safari as of Sept 2026**, so add a JS backdrop-click fallback |
| Non-modal floating dialog with light dismiss | `<dialog popover>` or popover on a div with `role="dialog"` | See popovers skill |
| React design system needing consistent animation, portals, nested stacking, controlled state | Radix Dialog / AlertDialog, React Aria `Modal`+`Dialog`, Base UI `Dialog`/`AlertDialog`, Ariakit `Dialog` | These handle focus scope, scroll lock, `aria-hidden` of siblings, SSR |
| Very old browser support | Library with focus-trap polyfill | Rare in 2026 |

### Keyboard interaction
| Key | Behavior |
|---|---|
| Tab | Next tabbable element inside dialog; wraps last → first (modal) |
| Shift+Tab | Previous tabbable element; wraps first → last (modal) |
| Escape | Closes the dialog (fires `cancel`); for alertdialog with no safe default, may be disabled via `closedby="none"` |
| Enter/Space | Activate focused button |

Native `showModal()` makes outside content inert. Focus can still move to browser chrome (the address bar), which is expected and acceptable.

### Roles and attributes
| Element | Attribute |
|---|---|
| Container | `<dialog>` (implicit `role="dialog"`), or `role="alertdialog"` for urgent confirmations |
| Container | `aria-labelledby="titleId"` (or `aria-label`) |
| Container | `aria-describedby="descId"` (optional, short text only) |
| Modal | `aria-modal="true"` is implicit with `showModal()`; set it manually only on custom modals |
| Trigger | `aria-haspopup="dialog"` is optional; `aria-expanded` is usually not used for modals |

### Closing mechanisms
- `dialog.close(returnValue)`: programmatic close; fires `close`.
- `dialog.requestClose()`: behaves like Escape (fires cancellable `cancel`); check support before relying on it.
- `closedby`: `any` (Esc + outside click), `closerequest` (Esc; modal default), `none` (only developer-provided buttons).
- `cancel` event: call `preventDefault()` to block closing when there are unsaved changes, then confirm.

### Scroll locking
```css
/* Lock page scroll while a modal dialog is open */
html:has(dialog:modal) { overflow: hidden; scrollbar-gutter: stable; }
/* Prevent scroll chaining from inside the dialog */
dialog { overscroll-behavior: contain; max-block-size: min(90dvh, 100%); overflow: auto; }
```
`scrollbar-gutter: stable` prevents layout shift but leaves a blank gutter. Pick deliberately. On iOS, overflow hidden on the root is now respected in current Safari, but test touch scroll.

### Animation (entry and exit)
```css
dialog {
  opacity: 0; translate: 0 8px;
  transition: opacity .2s, translate .2s, overlay .2s allow-discrete, display .2s allow-discrete;
}
dialog:open { opacity: 1; translate: 0 0; }   /* use [open] if :open unsupported in your matrix */
@starting-style { dialog:open { opacity: 0; translate: 0 8px; } }
dialog::backdrop { background: rgb(0 0 0 / .5); }
@media (prefers-reduced-motion: reduce) { dialog { transition: none; } }
```

## Recommended Workflow
1. Confirm a dialog is the right pattern (vs page, popover, toast, inline).
2. Write the content first: title, one-sentence body, outcome-labelled buttons.
3. Build with `<dialog>` + `showModal()` (or your design system's primitive).
4. Decide initial focus per APG rules; set `autofocus`.
5. Wire close paths: close button, Escape, optional light dismiss (with Safari fallback), unsaved-changes guard.
6. Add scroll lock and reduced-motion-safe animation.
7. Verify focus return, screen reader announcement (name, role, modal), and zoom at 400%.
8. Add automated tests (open/close, focus, Escape, axe).

## Patterns

### Declarative confirm dialog (invoker commands, rendered by React)
```tsx
'use client';
import { useId } from 'react';

export function DeleteProjectButton({ name, onDelete }: { name: string; onDelete: () => void }) {
  const id = useId();
  return (
    <>
      {/* commandfor/command are native attributes; augment JSX types if your @types/react lacks them */}
      <button type="button" commandfor={`${id}-dlg`} command="show-modal">Delete project</button>
      <dialog
        id={`${id}-dlg`}
        aria-labelledby={`${id}-title`}
        aria-describedby={`${id}-desc`}
        onClose={(e) => { if (e.currentTarget.returnValue === 'delete') onDelete(); }}
      >
        <h2 id={`${id}-title`}>Delete “{name}”?</h2>
        <p id={`${id}-desc`}>This removes all files. You can’t undo this.</p>
        <form method="dialog">
          <button value="cancel" autoFocus>Keep project</button>
          <button value="delete">Delete project</button>
        </form>
      </dialog>
    </>
  );
}
```
Note: React's `autoFocus` calls `focus()` on mount rather than setting the attribute. For a dialog that's in the DOM before it opens, set initial focus in the open handler instead, or render the attribute explicitly. Verify in your React version.

### Light dismiss with Safari fallback (hook)
```tsx
'use client';
import { useEffect, type RefObject } from 'react';

export function useBackdropDismiss(ref: RefObject<HTMLDialogElement | null>) {
  useEffect(() => {
    const dlg = ref.current;
    if (!dlg || 'closedBy' in HTMLDialogElement.prototype) return; // native closedby="any" handles it
    const onClick = (e: MouseEvent) => {
      if (e.target !== dlg) return; // backdrop clicks target the dialog element itself
      const r = dlg.getBoundingClientRect();
      const inside = e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom;
      if (!inside) dlg.close('dismiss');
    };
    dlg.addEventListener('click', onClick);
    return () => dlg.removeEventListener('click', onClick);
  }, [ref]);
}
```
Put padding on an inner wrapper (not the `<dialog>`) so clicks on padding aren't mistaken for backdrop clicks.

### Unsaved-changes guard
```tsx
<dialog
  ref={ref}
  onCancel={(e) => { if (isDirty && !window.confirm('Discard changes?')) e.preventDefault(); }}
>
```
In product UI, replace `window.confirm` with a nested alertdialog.

### Focus return to a successor
If the invoker is removed (e.g., "Delete row" deletes the row), move focus to the next row, or to the table heading if none remain. Never leave focus on `<body>`.

## Anti-Patterns
- **`<div class="modal">` with `z-index: 9999`**: no inertness, stacking bugs. Fix: `<dialog>` + `showModal()` (top layer).
- **`dialog.show()` for a blocking modal**: background stays interactive and there is no backdrop. Fix: `showModal()`.
- **`open` attribute toggled directly**: opens non-modally with no focus handling. Fix: call methods, don't set `open`.
- **No visible close button**: touch and screen-reader users are stuck. Fix: always include one.
- **Focus lands on body after close**: users lose their place. Fix: restore to invoker/successor.
- **Auto-opening modals on load or on exit intent**: disorienting. Fix: inline banners or user-initiated dialogs.
- **Whole article in `aria-describedby`**: screen readers read a wall of text with no structure. Fix: omit describedby for structured content.
- **Backdrop click discards a half-filled form**: data loss. Fix: `closedby="closerequest"` or a dirty-check guard.
- **Stacked modals three deep**: users get lost. Fix: redesign as a page or a wizard.

## Accessibility
- WCAG 2.4.3 Focus Order, 2.1.2 No Keyboard Trap (the modal trap is escapable via Escape/close), 2.4.11 Focus Not Obscured, 4.1.2 Name/Role/Value, 1.3.1 Info and Relationships, 2.4.7 Focus Visible, 1.4.10 Reflow (usable at 320 CSS px).
- Announcement on open should include name, role "dialog" and the first focused element.
- Use `role="alertdialog"` only when the message is urgent and requires a response.
- Respect `prefers-reduced-motion` for transitions.

## Responsive Design
- Size with `inline-size: min(100% - 2rem, 40rem)` and `max-block-size: 90dvh` and scroll the body, not the whole dialog. Keep header and actions sticky.
- On small screens consider full-screen dialogs or bottom sheets. Keep action buttons reachable by thumb.
- Use `dvh` units to avoid iOS toolbar clipping. Test with the virtual keyboard open.

## Performance
- Lazy-load heavy dialog content (editors, charts) on first open. Keep the shell cheap.
- Don't mount hundreds of hidden dialogs (e.g., one per table row). Use a single dialog with dynamic content.
- Animate only `opacity`/`transform`/`translate`.

## Security
- Confirmation dialogs are not authorization. Enforce destructive actions server-side.
- Render user-provided text in dialogs as text, never as HTML (XSS).
- Clickjacking/overlay spoofing: don't imitate browser permission prompts.

## Testing
- Unit/component (Testing Library): opens via trigger, `getByRole('dialog', { name })`, Escape closes, focus returns to trigger.
- E2E (Playwright): Tab cycling stays inside, background buttons not reachable, scroll lock, light dismiss in Chromium/Firefox/WebKit (WebKit uses fallback path).
- axe-core: `aria-dialog-name`, no hidden focusable content.
- Manual: VoiceOver (Safari), NVDA (Firefox/Chrome), JAWS. Check the announcement and that the virtual cursor stays inside.
- Note: jsdom's `<dialog>` support is incomplete; stub `showModal`/`close` or test in a real browser (Vitest browser mode, Playwright component tests).

## Tooling
- Native: `<dialog>`, invoker commands (Baseline), `closedby` (limited, no Safari), `inert` (Baseline widely available).
- React: shadcn/ui Dialog/AlertDialog (Radix- or Base UI-based; default choice if the project uses shadcn), Radix Dialog/AlertDialog (stable), Base UI `Dialog`/`AlertDialog` (v1.8, Sept 2026), React Aria Components `Modal`/`Dialog`, Ariakit `Dialog`, Headless UI `Dialog`.
- TypeScript: if `closedby`, `commandfor` or `command` are missing from your `@types/react`, add a module augmentation for `React.DialogHTMLAttributes` / `ButtonHTMLAttributes`.
- Polyfill: `dialog-closedby-polyfill` (community) if you need `closedby` semantics in Safari.
- Testing: @testing-library, Playwright, axe-core.

## Framework Notes
- **React (Vite SPA)**: Call `showModal()` in an effect when a controlled `open` prop becomes true, and sync the `close` event back to state via `onClose`. Never render `<dialog open>` for modals (that opens it non-modally). With React 19, `ref` is a regular prop. Portals are unnecessary with top layer, but Radix/Base UI/React Aria still portal. That's fine. Use `useId()` for label ids. Prefer the project's DS primitive (shadcn/ui `Dialog`/`AlertDialog` over Radix or Base UI) when one exists.
- **Next.js (App Router)**: Dialog components are Client Components (`'use client'`). Keep the trigger + dialog in a small client leaf and pass server-rendered content as `children`. `showModal()` must run after hydration (effects only). Don't render an open modal on the server. For deep-linkable modals use intercepting + parallel routes (`@modal/(.)photo/[id]`), close with `router.back()`, and make sure a hard refresh renders a full page. On route change while a modal is open, close it and let focus go to the new page's heading. Portaled library dialogs render into `document.body` only on the client, so avoid conditional markup that differs between server and client (hydration mismatch).

## AI Agent Guidance
- DO default to `<dialog>` + `showModal()` or the project's existing dialog primitive. Search the codebase before creating a new one.
- DO give every dialog an accessible name and a visible close control.
- DO implement focus return and choose initial focus deliberately.
- DON'T use `closedby` without a Safari fallback, and don't set `open` directly for modals.
- DON'T wrap confirm flows around `window.confirm()` in product UI.
- Verify before done: (1) Escape closes; (2) Tab never reaches background; (3) focus returns; (4) `getByRole('dialog', {name})` passes; (5) page doesn't scroll behind; (6) works at 320px width; (7) reduced motion honored.

## Examples
Recommended library path (shadcn/ui AlertDialog on Radix):
```tsx
'use client';
import {
  AlertDialog, AlertDialogTrigger, AlertDialogContent, AlertDialogHeader, AlertDialogTitle,
  AlertDialogDescription, AlertDialogFooter, AlertDialogCancel, AlertDialogAction,
} from '@/components/ui/alert-dialog';

export function DeleteInvoice({ onConfirm }: { onConfirm: () => Promise<void> }) {
  return (
    <AlertDialog>
      <AlertDialogTrigger asChild><button type="button">Delete invoice</button></AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete invoice #1042?</AlertDialogTitle>
          <AlertDialogDescription>This can’t be undone.</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Keep invoice</AlertDialogCancel>
          <AlertDialogAction onClick={onConfirm}>Delete invoice</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
```
Radix AlertDialog focuses Cancel by default and doesn't close on outside click, which matches APG guidance for destructive confirmations.

React wrapper around native dialog:
```tsx
'use client';
import { useEffect, useRef } from 'react';

export function Modal({ open, onClose, title, children }: {
  open: boolean; onClose: () => void; title: string; children: React.ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current!;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog ref={ref} aria-labelledby="modal-title" onClose={onClose} closedby="closerequest">
      <h2 id="modal-title">{title}</h2>
      {children}
      <button type="button" onClick={onClose}>Close</button>
    </dialog>
  );
}
```
Focus restoration is automatic for native modals in current browsers when closed. Verify in your support matrix and restore manually if needed (store `document.activeElement` before opening). Use `useId()` instead of a fixed id when multiple instances can exist.

## Related Skills
- [drawers-and-sheets](../drawers-and-sheets/Skill.md): side/bottom variants of modal dialogs
- [popovers](../popovers/Skill.md): non-modal anchored overlays and the Popover API
- [focus-management](../focus-management/Skill.md): focus placement and restoration
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md): when a confirm dialog is warranted
- [aria-authoring-practices](../aria-authoring-practices/Skill.md): APG dialog pattern context
- [radix-ui-primitives](../radix-ui-primitives/Skill.md): library implementation
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md): overlay animation safety
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md): route-based modals

## Sources
- [WAI-ARIA APG: Dialog (Modal) Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) — Official — keyboard, roles, initial focus rules
- [MDN: `<dialog>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog) — Official — showModal, closedby, requestClose, animation, a11y notes
- [web-features: dialog closedby](https://web-platform-dx.github.io/web-features-explorer/features/dialog-closedby/) — Official — support (no Safari)
- [InfoQ: Invoker Commands reach Baseline](https://www.infoq.com/news/2026/01/html-invoker-commands/) — Community — support versions
- [MDN: inert](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert) — Official — inert behavior
- [Scroll-Locked Dialogs (Master.dev blog)](https://blog.master.dev/scroll-locked-dialogs/) — Community — `:has()` scroll lock and gutter caveat
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Community (agent skill/AGENTS.md) — focus and overscroll rules

## License / Usage Notes
Content is summarized from W3C (W3C Document License), MDN (CC-BY-SA 2.5) and community sources in original wording. Code samples are original. Radix, React Aria, Base UI, Ariakit and Headless UI are MIT/Apache-2.0 licensed.

## Quality Tier
A — grounded in APG and MDN with verified 2026 support data; lacks first-hand screen reader test matrix.

## Status
Active

## Last Verified
2026-09-15
