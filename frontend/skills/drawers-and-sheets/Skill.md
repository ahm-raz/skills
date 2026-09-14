# Drawers and Sheets

## Summary
Drawers (side panels) and sheets (bottom panels) are edge-anchored overlays. They are used for navigation, filters, detail views, and quick actions, especially on mobile. This skill covers when to make them modal or non-modal, how to build them on native `<dialog>`, drag-to-dismiss and snap points, and which libraries are maintained in 2026 (note: Vaul is unmaintained).

## Category
Components

## Subcategories
Overlays, side drawer, bottom sheet, off-canvas navigation, detail panel, snap points, gestures

## Problem It Solves
Edge panels mix dialog semantics with gesture physics. Common failures: swipe-only dismissal, no close button, focus left behind the panel, background scroll bleeding through, stacked sheets, the Back button not closing the panel on mobile, and non-modal panels that trap focus (or modal ones that don't).

## When To Use
- Mobile navigation (off-canvas menu) or app sidebar collapse on small screens.
- Filters or settings that users adjust and then return to results.
- Record detail / quick-edit panels in master-detail UIs (often non-modal on desktop).
- Short, transient action lists on mobile (bottom sheet as an action sheet).

## When Not To Use
- Long content or complex multi-step flows: use a page (NN/g: sheets are transient UI).
- Replacing normal page-to-page navigation.
- Stacking a sheet on a sheet: redesign.
- Critical confirmations: use an alertdialog.
- Desktop contexts where a persistent sidebar or inline expansion fits better.

## Core Principles
1. A drawer is a dialog positioned at an edge. Modal drawers follow the dialog pattern (name, focus in, focus return, Escape, inert background).
2. Always provide a visible close button; the grab handle and swipe are enhancements, never the only way out.
3. Choose modality explicitly: modal (blocks page) vs non-modal (page remains usable, no focus trap).
4. Gestures must have non-gesture equivalents (WCAG 2.5.1 Pointer Gestures, 2.5.7 Dragging Movements).
5. Don't stack sheets; one edge panel at a time.

## Best Practices
- Place navigation drawers on the inline-start edge (logical `inset-inline-start`) so RTL flips automatically. Detail panels usually go inline-end.
- Bottom sheets: show a grab handle *and* a close button. Support the device/browser Back button when the sheet represents a navigational state (push a history entry or use route state).
- Snap points: at most 2–3 (e.g., peek, half, full). Make the sheet content scroll only at the largest snap.
- Keep the header (title + close) sticky and the body scrollable. Use `overscroll-behavior: contain` inside.
- A non-modal expandable sheet may become modal when fully expanded (NN/g). Switch semantics (`showModal()`) at that point.
- Honor safe areas: `padding-bottom: env(safe-area-inset-bottom)`.
- Width: side drawers ~ `min(90vw, 24–28rem)`. Full-width on phones.
- Animate with transform. Disable or shorten animation under `prefers-reduced-motion`.

## Implementation Guidance

### Decision table
| Scenario | Modality | Build with |
|---|---|---|
| Mobile nav menu | Modal | `<dialog>` + `showModal()` styled to edge, or Radix/Base UI Dialog |
| Filters panel on mobile | Modal | Same; "Apply"/"Show N results" sticky footer |
| Desktop detail panel next to list | Non-modal | `<aside>` region or `dialog.show()` (no trap); keep list interactive |
| Action sheet (share, copy, delete) | Modal | Dialog or menu-in-sheet |
| Map / media app draggable sheet | Non-modal → modal at full | Base UI Drawer (stable since v1.3, 2026) or custom gestures |
| Persistent app sidebar | Not an overlay | See navigation-menus-and-sidebars |

### Library status (Sept 2026)
| Library | Status | Notes |
|---|---|---|
| Native `<dialog>` + CSS | Baseline | Edge positioning via CSS; no built-in gestures |
| Base UI `Drawer` | Stable (v1.3+, gesture improvements v1.6) | Snap points and swipe handled; unstyled |
| Radix Dialog styled as sheet (shadcn `Sheet`) | Stable | No drag gestures |
| Vaul | **Unmaintained** (README states so) | Existing shadcn `Drawer` depends on it; plan migration |
| React Aria `Modal` + custom | Stable | Accessible modal; add your own gesture |
| Material (MUI) `Drawer`/`SwipeableDrawer` | Stable | Heavier; MUI ecosystem |

### Keyboard and ARIA
| Key / attribute | Behavior |
|---|---|
| Escape | Closes a modal drawer; for a non-modal panel, closes if focus is inside it |
| Tab | Modal: cycles inside. Non-modal: moves naturally in and out |
| `role` | `dialog` (native) with `aria-labelledby` → panel title |
| Trigger | `aria-expanded` + `aria-controls` for toggle-style nav drawers; returns focus on close |
| Drag handle | If focusable, a `<button aria-label="Resize sheet">` that cycles snap points on Enter/Space or arrows; otherwise `aria-hidden` |

### Edge-positioned native dialog
```css
dialog.drawer {
  margin: 0; inset-block: 0; inset-inline-start: 0; inset-inline-end: auto;
  block-size: 100dvh; max-block-size: none; inline-size: min(90vw, 26rem);
  translate: -100% 0;
  transition: translate .25s ease, overlay .25s allow-discrete, display .25s allow-discrete;
}
dialog.drawer:open { translate: 0 0; }
@starting-style { dialog.drawer:open { translate: -100% 0; } }
:dir(rtl) dialog.drawer { translate: 100% 0; }
dialog.sheet {
  margin: 0; inset-inline: 0; inset-block-end: 0; inset-block-start: auto;
  inline-size: 100%; max-inline-size: none; max-block-size: 90dvh;
  border-radius: 16px 16px 0 0; padding-bottom: env(safe-area-inset-bottom);
}
@media (prefers-reduced-motion: reduce) { dialog.drawer, dialog.sheet { transition: none; } }
html:has(dialog.drawer:modal, dialog.sheet:modal) { overflow: hidden; }
```
(Use `[open]` instead of `:open` if it's missing from your support matrix.)

## Recommended Workflow
1. Decide the panel's job and whether it should be modal. Consider whether a page or inline expansion is simpler.
2. Pick edge by purpose (nav: start; details: end; quick actions on mobile: bottom).
3. Build on the dialog primitive; add title, close button, sticky header/footer.
4. Add scroll lock (modal), overscroll containment, safe-area padding.
5. Add gestures (optional) with a pointer-events implementation or Base UI Drawer. Ensure button alternatives exist.
6. Wire Back button behavior for mobile full-height sheets that feel like navigation.
7. Test keyboard, screen reader, touch, RTL, reduced motion, virtual keyboard.

## Patterns

### Filter sheet with result-count footer (native dialog in React)
```tsx
'use client';
import { useEffect, useRef } from 'react';

export function FilterSheet({ open, onClose, count, onReset, children }: {
  open: boolean; onClose: () => void; count: number; onReset: () => void; children: React.ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current!;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog ref={ref} className="sheet" aria-labelledby="filters-title" onClose={onClose}>
      <header>
        <h2 id="filters-title">Filters</h2>
        <button type="button" aria-label="Close filters" onClick={onClose}>×</button>
      </header>
      <div className="body">{children}</div>
      <footer>
        <button type="button" onClick={onReset}>Clear all</button>
        <button type="button" onClick={onClose}>Show {count} results</button>
      </footer>
    </dialog>
  );
}
```

### Non-modal detail panel
Render as `<aside aria-labelledby="detail-title">` in the layout (not top layer). Move focus to its heading (`tabIndex={-1}` + `ref.focus()`) when opened from a row, and back to the row on close. No focus trap, so users can keep working in the list.

### URL-driven sheet (Next.js)
```tsx
'use client';
import { useRouter, useSearchParams, usePathname } from 'next/navigation';

export function useUrlPanel(name: string) {
  const params = useSearchParams(); const router = useRouter(); const pathname = usePathname();
  const open = params.get('panel') === name;
  const setOpen = (next: boolean) => {
    const p = new URLSearchParams(params);
    if (next) { p.set('panel', name); router.push(`${pathname}?${p}`, { scroll: false }); }
    else router.back(); // Back button and close button behave the same
  };
  return [open, setOpen] as const;
}
```
Push a history entry on open so the mobile Back button closes the sheet. If the page was loaded directly with `?panel=`, `router.back()` would leave the site, so fall back to `router.replace` without the param when there's no in-app history. Components that call `useSearchParams` need a `<Suspense>` boundary in the App Router.

### Snap-point button alternative
A handle `<button>` that cycles `peek → half → full`, and announces the new state via the `aria-label` ("Expand sheet", "Collapse sheet").

## Anti-Patterns
- **Swipe-down as the only dismiss**: gesture ambiguity and motor-impairment barrier. Fix: close button + Escape + Back.
- **Stacked sheets**: users can't tell what closes what. Fix: replace content within one sheet or navigate.
- **Non-modal panel that traps focus**: blocks the page for no reason. Fix: no trap; manage focus on open/close only.
- **Modal drawer without inertness** (`div` + transform): screen readers read the background. Fix: `showModal()` or library dialog.
- **Physical `left:`/`right:` everywhere**: breaks RTL. Fix: logical properties.
- **Animating `left`/`width`**: jank. Fix: `translate`/`transform`.
- **New features built on Vaul**: dependency is unmaintained. Fix: Base UI Drawer or dialog-based sheet.
- **Long forms in a half-height sheet with virtual keyboard**: fields get hidden. Fix: full-height sheet or page.

## Accessibility
- WCAG 2.1.1 Keyboard, 2.1.2 No Keyboard Trap, 2.4.3 Focus Order, 2.4.11 Focus Not Obscured (sticky footers must not hide focused fields), 2.5.1 Pointer Gestures, 2.5.7 Dragging Movements, 2.5.8 Target Size (handles/close ≥ 24×24 CSS px), 4.1.2 Name/Role/Value.
- Announce name and role on open; return focus on close.
- Reduced motion: no large sliding motion.

## Responsive Design
- Common pattern: persistent sidebar ≥ 1024px; modal drawer below. Filters inline on desktop; bottom/full sheet on mobile.
- Use container queries for panel content that renders both inline and in a sheet.
- Use `dvh`/`svh` for heights. Test landscape phones where half-height sheets become unusable (switch to full).

## Performance
- Animate transform/opacity only; avoid layout during drag (use `translate` from pointer delta, commit on release).
- Use passive pointer listeners; avoid React state updates per pointermove (use refs + rAF).
- Lazy-load heavy panel content on first open.

## Security
- Drawers showing record details must still enforce authorization server-side. Don't just hide data client-side.
- Don't put secrets in hidden-but-mounted panel markup.

## Testing
- Playwright: open via trigger, `getByRole('dialog', {name:'Filters'})`, Escape closes, focus restored, Back closes history-aware sheets.
- Mobile emulation + real iOS/Android devices for gestures, safe areas, virtual keyboard.
- Touch gesture tests: simulate pointer sequences; assert the snap state.
- axe for names; screen reader smoke test (VoiceOver iOS swipe navigation reaches close button).

## Tooling
- Base UI Drawer (MIT, stable), Radix Dialog / shadcn Sheet (MIT), React Aria Components Modal (Apache-2.0), MUI Drawer.
- Vaul (MIT) — unmaintained; avoid for new work.
- Native `<dialog>` + invoker commands.

## Framework Notes
- **React (Vite SPA)**: Use shadcn/ui `Sheet` (Radix Dialog) for non-gesture drawers and Base UI `Drawer` for swipe/snap sheets. Keep panel state in the URL (React Router `useSearchParams`, TanStack Router search params, or nuqs) so refresh/share/Back work. Drive drag with refs + `requestAnimationFrame`, not `useState` per pointermove.
- **Next.js (App Router)**: Drawers are Client Components (`'use client'`). Pass server-rendered content as `children`. Use search params or intercepting/parallel routes for detail panels that should deep-link. Wrap `useSearchParams` consumers in `<Suspense>`. Don't render the drawer open on the server based on client-only state (hydration mismatch). Close mobile nav drawers on route change (`usePathname` effect) and let focus move to the new page. Library portals mount after hydration.

## AI Agent Guidance
- DO reuse the project's dialog primitive for modal drawers; check for existing `Sheet`/`Drawer` components first.
- DO include a visible close button, title, and focus return.
- DON'T introduce Vaul in new code; flag existing usage as a maintenance risk.
- DON'T trap focus in non-modal side panels.
- Verify: Escape/close/Back paths; background inert (modal); no background scroll; RTL flip; reduced motion; 320px width; keyboard-only operation of snap points if present.

## Examples
shadcn/ui Sheet (Radix Dialog) for a mobile nav drawer that closes on navigation:
```tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Sheet, SheetTrigger, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';

export function MobileNav({ items }: { items: { href: string; label: string }[] }) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  useEffect(() => setOpen(false), [pathname]);
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild><button type="button" aria-label="Open menu">☰</button></SheetTrigger>
      <SheetContent side="left">
        <SheetHeader><SheetTitle>Menu</SheetTitle></SheetHeader>
        <nav aria-label="Main">
          <ul>{items.map(i => (
            <li key={i.href}><Link href={i.href} aria-current={pathname === i.href ? 'page' : undefined}>{i.label}</Link></li>
          ))}</ul>
        </nav>
      </SheetContent>
    </Sheet>
  );
}
```

Base UI-style drawer composition for a swipeable bottom sheet (conceptual, check current API names in docs):
```tsx
<Drawer.Root>
  <Drawer.Trigger>Filters</Drawer.Trigger>
  <Drawer.Portal>
    <Drawer.Backdrop />
    <Drawer.Popup aria-labelledby="filters-title">
      <h2 id="filters-title">Filters</h2>
      <Drawer.Close>Close</Drawer.Close>
      {/* content */}
    </Drawer.Popup>
  </Drawer.Portal>
</Drawer.Root>
```

## Related Skills
- [accessible-dialogs](../accessible-dialogs/Skill.md): underlying modal semantics
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md): off-canvas nav and persistent sidebars
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md): gesture alternatives
- [master-detail-layouts](../master-detail-layouts/Skill.md): non-modal detail panels
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md): filter sheet content
- [small-ui-primitives-vaul-sonner-cmdk](../small-ui-primitives-vaul-sonner-cmdk/Skill.md): Vaul status
- [base-ui](../base-ui/Skill.md): Drawer component
- [mobile-web-app-patterns](../mobile-web-app-patterns/Skill.md): mobile conventions

## Sources
- [NN/g: Bottom Sheets](https://www.nngroup.com/articles/bottom-sheet/) — Official research — modality, close button, Back, no stacking
- [WAI-ARIA APG: Dialog (Modal)](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) — Official — semantics
- [MDN: `<dialog>`](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog) — Official — animation, closing
- [Base UI Releases](https://base-ui.com/react/overview/releases) — Open Source — Drawer stable (v1.3), gestures (v1.6)
- [Vaul repository](https://github.com/emilkowalski/vaul) — Open Source — unmaintained notice
- [shadcn/ui Sidebar](https://ui.shadcn.com/docs/components/sidebar) — Open Source — Sheet on mobile

## License / Usage Notes
Summarized in original wording; code original. Libraries referenced are MIT/Apache-2.0.

## Quality Tier
A — official patterns + NN/g research + verified library status; gesture guidance not exhaustively device-tested.

## Status
Active

## Last Verified
2026-09-15
