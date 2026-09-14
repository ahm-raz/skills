# Focus Management

## Summary
Programmatically moving, containing, restoring and styling keyboard focus in React/Next.js when the UI changes without a full page load: dialogs, drawers, popovers, inline edits, deletions, errors, wizard steps and client-side route changes. Covers `ref.focus()`, `inert`, native `dialog`/`popover` focus behaviour, restoring focus, and focus-indicator styling (2.4.7, 2.4.11, 2.4.13).

## Category
Accessibility

## Subcategories
Focus restoration, focus trapping, inert, dialog/popover focus, focus after deletion, error focus, focus indicators, focus-visible, scroll-padding

## Problem It Solves
In SPAs the DOM changes under the user. When a focused element is removed (item deleted, modal closed, route changed), browsers reset focus to `<body>`. Keyboard and screen reader users are then thrown to the top of the page, or stranded in hidden content. Poor focus management is among the most common failures in audits of React apps.

## When To Use
- Opening or closing modal and non-modal overlays.
- Removing the focused element (delete row, dismiss card).
- Revealing new content the user asked for (expand edit form, next wizard step).
- Form submission with errors.
- Client-side route changes.

## When Not To Use
- Don't move focus on passive updates (polling results, toasts, live data). Announce instead (live regions).
- Don't auto-focus fields on page load for general pages. It skips context and causes unexpected scrolling. Search pages and dialogs are exceptions.
- Don't move focus on hover or on `onChange` of a select (3.2.1, 3.2.2).

## Core Principles
1. **Focus follows the user's intent.** Move it only in response to user action.
2. **Never lose focus.** If the focused element disappears, place focus somewhere logical.
3. **Restore focus** to the invoking control when a transient UI closes.
4. **Contain focus** inside modal UI only while it is open, and make the background inert.
5. **Focus must be visible and not obscured.**
6. **Prefer platform behaviour.** `dialog.showModal()` and `popover` handle initial focus, the inert background and restoration.

## Best Practices
- Focus targets:
  | Situation | Focus target |
  |---|---|
  | Modal opens | First focusable, or the dialog heading/container (`tabIndex={-1}`) for long content; destructive confirm dialogs focus the least destructive button |
  | Modal closes | The invoking button (or a logical successor if it no longer exists) |
  | Item deleted from list | The next item, the previous item if last, or the list heading/container if empty |
  | Inline edit opens | The first field |
  | Inline edit saved/cancelled | The "Edit" button that opened it |
  | Form submit with errors | The error summary (`tabIndex={-1}`), or the first invalid field |
  | Wizard next step | The new step's heading (`tabIndex={-1}`) |
  | Route change | The `<h1>` or `<main>` (see accessible-spa-routing) |
  | "Load more" | The first newly loaded item |
- Use `tabIndex={-1}` on non-interactive focus targets, and remove visible outlines only on those containers (`[tabindex="-1"]:focus { outline: none }`) if the heading is clearly announced. Interactive elements keep their outlines.
- `element.focus({ preventScroll: true })` if you control scroll separately; otherwise let it scroll.
- Use `inert` on background and app-shell regions for custom modals or off-canvas navigation.
- Use `scroll-padding-top` equal to the sticky header height so focused elements are not obscured (2.4.11).
- `autoFocus` inside dialogs is fine. `<dialog>` honours the `autofocus` attribute on descendants.

## Implementation Guidance

### Native dialog (preferred)
- `showModal()` puts the dialog in the top layer, makes the rest of the document inert, focuses the first focusable element (or the `autofocus` element), closes on Esc, and returns focus to the previously focused element on close in modern browsers.
- `closedby="any"` enables light dismiss (where supported); `closedby="closerequest"` is Esc only.
- `popover="auto"`: light dismiss, and returns focus to the invoker when closed via the invoker or Esc.

### Library dialogs
- Radix `Dialog` and React Aria `Modal`/`Dialog` implement trapping, `aria-modal`, Esc, scroll lock and restoration.
- Radix hooks: `onOpenAutoFocus`/`onCloseAutoFocus` (call `e.preventDefault()` and focus a custom target).
- React Aria: `FocusScope contain restoreFocus autoFocus`.

### Focus after deletion (React)
```tsx
function useFocusAfterDelete<T extends { id: string }>(items: T[]) {
  const itemRefs = useRef(new Map<string, HTMLElement>());
  const emptyRef = useRef<HTMLHeadingElement>(null);
  const pending = useRef<string | null>(null);

  const onDelete = (id: string) => {
    const i = items.findIndex(x => x.id === id);
    pending.current = items[i + 1]?.id ?? items[i - 1]?.id ?? '__empty__';
  };

  useEffect(() => {
    if (!pending.current) return;
    const target = pending.current === '__empty__' ? emptyRef.current : itemRefs.current.get(pending.current);
    target?.focus();
    pending.current = null;
  }, [items]);

  return { itemRefs, emptyRef, onDelete };
}
```

### Error summary focus
```tsx
const summaryRef = useRef<HTMLDivElement>(null);
useEffect(() => { if (errors.length) summaryRef.current?.focus(); }, [errors]);

{errors.length > 0 && (
  <div ref={summaryRef} tabIndex={-1} role="alert" aria-labelledby="err-title">
    <h2 id="err-title">There is a problem</h2>
    <ul>{errors.map(e => <li key={e.field}><a href={`#${e.field}`}>{e.message}</a></li>)}</ul>
  </div>
)}
```

### Focus indicator CSS (2.4.7 / 2.4.13)
```css
:where(a, button, input, select, textarea, [tabindex]):focus-visible {
  outline: 3px solid var(--focus-color, #1a5fb4); /* ≥3:1 against adjacent colors */
  outline-offset: 2px;
}
@media (forced-colors: active) {
  :focus-visible { outline-color: Highlight; }
}
html { scroll-padding-block: var(--sticky-header-h, 4rem) var(--sticky-footer-h, 0); }
```
Use `outline`, not `box-shadow`, for rings. Box shadows are removed in forced-colors mode.

## Recommended Workflow
1. List every transient UI and destructive action in the feature.
2. For each, decide the open/close/remove focus targets using the table.
3. Implement with native `dialog`/`popover` or the design-system primitive. Add refs and effects only for custom cases.
4. Style `:focus-visible` globally, and check contrast against all backgrounds.
5. Test: keyboard walk, NVDA/VoiceOver hear what gets focused, Playwright `toBeFocused()` assertions.

## Patterns
- **Return-focus ref.** Store `document.activeElement` on open and focus it on close if it's still connected (`el.isConnected`).
- **Inert background.** `<div inert={isDrawerOpen}>` around the app shell while a custom drawer is open.
- **Heading focus on step change.** `<h2 tabIndex={-1} ref={stepHeading}>Step 2 of 4: Payment</h2>`.
- **Focus sentinel for "load more".** Focus the first new item's link after appending.

## Anti-Patterns
- **Focus trap without Esc or a close button.** A keyboard trap (2.1.2).
- **`aria-hidden` on the background with focus still reachable.** Use `inert` or native modal.
- **Moving focus on every re-render** (focus in an effect without dependency guards). Users get yanked around. Guard with state transitions.
- **Focusing a `div` without `tabIndex={-1}`.** `.focus()` silently fails.
- **`outline: none` on `:focus` for everything.** Invisible focus.
- **Closing a menu on selection and leaving focus on `<body>`.** Restore it to the trigger.
- **`setTimeout(() => el.focus(), 300)` to wait for animations.** Fragile. Focus when the element is mounted and visible (`onAnimationEnd`, or the library callback).

## Accessibility
- 2.4.3 Focus Order (A), 2.4.7 Focus Visible (AA), 2.4.11 Focus Not Obscured Min (AA), 2.4.12 (AAA), 2.4.13 Focus Appearance (AAA), 2.1.2 No Keyboard Trap (A), 3.2.1 On Focus (A), 1.4.11 Non-text Contrast (focus indicator 3:1).
- Screen readers announce the newly focused element's name and role. Choose targets that give context (a heading beats a bare "Close" button for long dialogs).

## Responsive Design
- Mobile screen readers (VoiceOver iOS, TalkBack) follow programmatic focus inconsistently. Native `dialog` with a labelled heading works best.
- On small screens sticky headers and bottom bars are larger, so update `scroll-padding` via CSS variables per breakpoint.
- Virtual keyboards can cover focused inputs. Use `scrollIntoView({ block: 'center' })` after focus if needed, and the `interactive-widget=resizes-content` viewport meta where appropriate.

## Performance
- Avoid `document.querySelectorAll(focusable)` on every keystroke in traps; cache it on open or use native `dialog`.
- Don't force synchronous layout by reading positions right after `.focus()` inside loops.

## Security
- Clickjacking-style overlays must not steal focus from sensitive fields. Don't auto-focus third-party iframes.

## Testing
```ts
test('dialog returns focus to trigger', async ({ page }) => {
  await page.goto('/projects');
  const trigger = page.getByRole('button', { name: 'Delete project Alpha' });
  await trigger.click();
  const dialog = page.getByRole('dialog', { name: 'Delete project?' });
  await expect(dialog.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();
  await expect(trigger).toBeFocused();
});
```
- Component tests: `expect(screen.getByRole('button', { name: /edit/i })).toHaveFocus()` (jest-dom).
- Manual: NVDA speech viewer or VoiceOver caption panel shows what was announced on focus moves.
- Chrome DevTools: Live Expression `document.activeElement` to watch focus.

## Tooling
- Native `<dialog>`, `popover`, `inert` (all Baseline).
- React Aria `FocusScope`, `useFocusRing`, `useFocusManager`; Radix Dialog/Popover/DropdownMenu focus props.
- focus-trap-react (only for legacy custom overlays).
- Accessibility Insights (Tab stops), Chrome DevTools Live Expression.

## Framework Notes
- **React (both).**
  - Use refs with `.focus()` in `useEffect`/`useLayoutEffect` after the element mounts.
  - React 19 ref callbacks can return cleanup functions, a good place to restore focus.
  - `flushSync` can ensure DOM updates before focusing when state and focus change together.
  - React 19 supports `inert` as a boolean.
- **Next.js App Router.**
  - Client navigation does not move focus. Handle it in a client component keyed on `usePathname()`.
  - Intercepting/parallel route modals (`@modal` slot) must restore focus to the opening `<Link>` when `router.back()` closes them. Store the trigger before navigating.
  - Server Actions: after `useActionState` returns errors, focus the error summary in an effect.
- **Vite SPA.** Implement the same route focus logic in the router layout (React Router `useLocation`, TanStack Router `useRouterState`).

## AI Agent Guidance
- Do: for every overlay or destructive action you add, specify and implement the open/close/remove focus targets.
- Do: prefer native `dialog` or the design-system primitive over custom traps.
- Do: add `:focus-visible` styles and `scroll-padding` for sticky UI.
- Don't: autofocus on page load, move focus on passive updates, or use timers to focus.
- Verify before done:
  - Playwright or Testing Library assertions on focus for open, close and delete
  - manual keyboard pass
  - focus never lands on `<body>` after interactions

## Examples
```tsx
'use client';
import { useRef } from 'react';

export function ConfirmDelete({ name, onConfirm }: { name: string; onConfirm: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" onClick={() => ref.current?.showModal()}>Delete {name}</button>
      <dialog ref={ref} aria-labelledby="del-title"
        onClose={() => { if (ref.current?.returnValue === 'confirm') onConfirm(); }}>
        <h2 id="del-title">Delete {name}?</h2>
        <p>This cannot be undone.</p>
        <form method="dialog">
          <button value="cancel" autoFocus>Cancel</button>{/* least destructive gets focus */}
          <button value="confirm">Delete</button>
        </form>
      </dialog>
    </>
  );
}
```

```tsx
// Radix: custom return target when the trigger unmounts
<Dialog.Content onCloseAutoFocus={(e) => { e.preventDefault(); listHeadingRef.current?.focus(); }}>
  <Dialog.Title>Archive item</Dialog.Title>
  …
</Dialog.Content>
```

## Related Skills
- [keyboard-navigation](../keyboard-navigation/Skill.md) — tab order and key handling
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — focus on route change
- [accessible-dialogs](../accessible-dialogs/Skill.md) — dialog component specifics
- [drawers-and-sheets](../drawers-and-sheets/Skill.md) — off-canvas focus and inert
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — when to announce instead of focus
- [form-validation-patterns](../form-validation-patterns/Skill.md) — error focus
- [radix-ui-primitives](../radix-ui-primitives/Skill.md) — focus props in primitives

## Sources
- [HTML Standard: dialog focusing steps, inert, popover](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element) — Official — native focus behaviour
- [APG: Dialog (Modal) pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) — Official — initial focus guidance
- [Understanding 2.4.11 Focus Not Obscured / 2.4.13 Focus Appearance](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html) — Official — requirements
- [GOV.UK Design System: Error summary](https://design-system.service.gov.uk/components/error-summary/) — Official (government) — error-summary focus pattern
- [React Aria FocusScope](https://react-spectrum.adobe.com/react-aria/FocusScope.html) — Open Source — contain/restore API
- [Radix Dialog](https://www.radix-ui.com/primitives/docs/components/dialog) — Open Source — autofocus callbacks

## License / Usage Notes
Summarised from W3C, WHATWG (CC BY 4.0), GOV.UK (OGL v3) and library docs (MIT/Apache-2.0). Code is original.

## Quality Tier
A — thorough and platform-accurate; mobile screen reader focus behaviour varies and needs per-product testing.

## Status
Active

## Last Verified
2026-09-15
