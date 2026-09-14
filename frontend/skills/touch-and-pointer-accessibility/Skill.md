# Touch and Pointer Accessibility

## Summary
Making React/Next.js interfaces operable for touch, mouse, stylus, voice control, switch and head-pointer users. Covers target sizes (2.5.8 AA 24px, 2.5.5 AAA 44px), pointer gestures and dragging alternatives (2.5.1, 2.5.7), pointer cancellation (2.5.2), label-in-name for voice control (2.5.3), motion actuation (2.5.4), hover dependence, and zoom.

## Category
Accessibility

## Subcategories
Target size, pointer gestures, dragging movements, pointer cancellation, label in name, voice control, motion actuation, hover, pinch zoom, pointer media queries, switch access

## Problem It Solves
Tiny icon buttons, swipe-only carousels, drag-only sortable lists, hover-only menus, shake-to-undo, actions firing on pointer-down, and disabled pinch-zoom exclude people with tremors, limited dexterity, low vision, and users of voice or switch control. They also frustrate everyone on phones.

## When To Use
- Any interactive UI viewed on touch devices, which means all of them.
- Drag-and-drop, sliders, carousels, maps, drawing canvases, swipe actions, sortable lists, kanban boards.
- Icon-only controls and dense toolbars and tables.

## When Not To Use
- Path-based gestures that are essential (signature capture, freehand drawing) are exempt from 2.5.1 and 2.5.7, but still offer alternatives where feasible (typed signature).

## Core Principles
1. **Targets are at least 24x24 CSS px, or spaced** so a 24px circle centred on each doesn't overlap another target (2.5.8 AA). Aim for 44x44 (2.5.5 AAA, Apple HIG 44pt, Material 48dp) for primary touch actions.
2. **Every multipoint or path-based gesture has a single-pointer alternative** (2.5.1 A): pinch gets +/- buttons, swipe gets arrows.
3. **Every drag has a single-pointer, non-drag alternative** (2.5.7 AA): click to select then click to place, or move buttons or menus.
4. **Activate on the up-event**, and allow abort by moving off the target (2.5.2 A). Native `click` does this.
5. **The visible label is contained in the accessible name**, ideally at the start (2.5.3 A), so "Click Send" works in voice control.
6. **Device-motion actions (shake, tilt) have UI alternatives and can be disabled** (2.5.4 A).
7. **Never disable zoom** (1.4.4). No `user-scalable=no` or `maximum-scale=1`.
8. **Don't depend on hover.** Touch has none; hover content must also be available on focus and tap (1.4.13).

## Best Practices
- Expand hit areas without changing visuals: padding, a `::before` pseudo-element with negative inset, or `min-block-size`/`min-inline-size`.
- Inline links in paragraphs are exempt (inline exception), but links in lists and nav are not. Give them padding.
- Space adjacent small targets (pagination, tag remove buttons, table row actions) at least 8px apart when under 24px.
- Swipe-to-delete or swipe-to-archive: provide a visible button or menu action too.
- Carousels: previous/next buttons plus pagination buttons; swipe is an enhancement.
- Maps: zoom buttons and a search alternative; don't require two-finger panning without an alternative.
- Sliders: native `<input type="range">`, or APG slider with arrow keys and tap-on-track; avoid tiny thumbs (at least 24px).
- Sortable lists: dnd-kit with keyboard sensor plus "Move up/down" buttons or a "Move to…" menu.
- Long-press menus: also offer a visible "More actions" button.
- Use `click` (`onClick`) rather than `onPointerDown`/`onTouchStart` for activation. If you need pointer-down (drag start), complete the action on up and allow cancel.
- Avoid `touch-action: none` on large areas (it blocks scrolling and zooming). Scope it to the canvas or drag handle.
- `@media (pointer: coarse)` increases spacing and target size; `@media (hover: hover)` gates hover-only visual enhancements (never gate functionality).
- Voice control users say visible labels. Make `aria-label` start with the visible text ("Send message", not "Submit form" on a "Send" button). Icon-only buttons need a name that matches the tooltip text.

## Implementation Guidance

### Target size utilities
```css
/* Minimum target size, keeping visual size */
.icon-button { position: relative; inline-size: 20px; block-size: 20px; }
.icon-button::before { content: ""; position: absolute; inset: -12px; } /* 44px hit area */

@media (pointer: coarse) {
  .toolbar { gap: 0.75rem; }
  .btn { min-block-size: 44px; min-inline-size: 44px; }
}
```
Tailwind: `min-h-6 min-w-6` (24px) as the base, and `pointer-coarse:min-h-11 pointer-coarse:min-w-11` (Tailwind v4 variant) for touch.

### Pointer cancellation-safe press (custom elements)
Prefer `<button onClick>`. If building custom pressable surfaces, React Aria `usePress` handles pointer, touch, keyboard and virtual clicks, fires on release, and cancels when the pointer leaves.
```tsx
import { usePress } from 'react-aria';
function Tile({ onOpen, children }: { onOpen: () => void; children: React.ReactNode }) {
  const { pressProps, isPressed } = usePress({ onPress: onOpen });
  return <div role="button" tabIndex={0} {...pressProps} data-pressed={isPressed || undefined}>{children}</div>;
}
```

### Dragging alternative (2.5.7) with dnd-kit
```tsx
'use client';
import { DndContext, KeyboardSensor, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core';
import { SortableContext, arrayMove, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable';

export function SortableList({ items, setItems }: { items: { id: string; label: string }[]; setItems: (x: typeof items) => void }) {
  const sensors = useSensors(useSensor(PointerSensor), useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }));
  const move = (from: number, to: number) => { if (to >= 0 && to < items.length) setItems(arrayMove(items, from, to)); };
  const onDragEnd = ({ active, over }: DragEndEvent) => {
    if (over && active.id !== over.id) move(items.findIndex(i => i.id === active.id), items.findIndex(i => i.id === over.id));
  };
  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}
      accessibility={{ announcements: {
        onDragStart: ({ active }) => `Picked up ${label(active.id)}.`,
        onDragOver: ({ active, over }) => over ? `${label(active.id)} is over ${label(over.id)}.` : '',
        onDragEnd: ({ active, over }) => over ? `Dropped ${label(active.id)} at ${label(over.id)}.` : 'Dropped.',
        onDragCancel: ({ active }) => `Cancelled moving ${label(active.id)}.`,
      } }}>
      <SortableContext items={items} strategy={verticalListSortingStrategy}>
        <ul>
          {items.map((it, i) => (
            <SortableRow key={it.id} item={it}>
              {/* single-pointer alternative, no drag needed */}
              <button type="button" onClick={() => move(i, i - 1)} disabled={i === 0} aria-label={`Move ${it.label} up`}>↑</button>
              <button type="button" onClick={() => move(i, i + 1)} disabled={i === items.length - 1} aria-label={`Move ${it.label} down`}>↓</button>
            </SortableRow>
          ))}
        </ul>
      </SortableContext>
    </DndContext>
  );
  function label(id: string | number) { return items.find(i => i.id === id)?.label ?? ''; }
}
```

### Viewport meta (Next.js)
```tsx
// app/layout.tsx
import type { Viewport } from 'next';
export const viewport: Viewport = { width: 'device-width', initialScale: 1 }; // never maximumScale: 1 or userScalable: false
```

### Gesture alternatives table
| Gesture | Required alternative |
|---|---|
| Pinch zoom (map, image) | +/- buttons, double-tap zoom, or keyboard |
| Two-finger rotate | Rotate buttons or input |
| Swipe carousel | Prev/next buttons |
| Swipe to delete/archive | Visible action button or menu |
| Drag to reorder | Move up/down buttons, "Move to" menu, keyboard sensor |
| Drag slider thumb | Tap on track, arrow keys, number input |
| Drag to resize panel | Keyboard-resizable separator (APG Window Splitter) or preset sizes |
| Draw selection box | Checkbox selection |
| Shake to undo | Undo button |
| Long press | Visible "More" button |

## Recommended Workflow
1. Inventory gestures, drags, hover-dependent UI, and small targets in the design.
2. Specify alternatives and target sizes in design (annotate).
3. Implement with native elements, hit-area expansion, and alternatives.
4. Test:
   - real phone, including zoom enabled
   - iOS Voice Control / Android Voice Access: say "Tap Send"
   - Switch Control basics
   - Chrome DevTools device emulation plus axe `target-size`
   - drag a sortable item using only buttons
5. Automate: axe `target-size` rule (wcag22aa tag) in Playwright mobile projects; unit tests for move buttons.

## Patterns
- **Stretched hit area** via pseudo-element.
- **Select-then-place** drag alternative (tap card, tap destination column) for kanban boards.
- **Hover-intent menus** that also open on click and focus.
- **Bottom-sheet actions** for long-press or swipe menus on mobile.

## Anti-Patterns
- **16px icon buttons packed together** (table row actions, tag close buttons). 2.5.8 failure. Expand hit areas and spacing.
- **Swipe-only carousels or drag-only sortables.** 2.5.1 and 2.5.7 failures. Add buttons.
- **`onTouchStart`/`onPointerDown` activation.** Accidental triggers with no cancel (2.5.2). Use click/press-up.
- **`maximum-scale=1, user-scalable=no`.** Blocks low-vision zoom (1.4.4). Remove it; fix iOS input-zoom with 16px fonts instead.
- **Hover-only tooltips holding essential info.** Unavailable on touch. Use visible text, or toggletips on click.
- **`aria-label` that doesn't match visible text.** Voice control fails (2.5.3). Begin the name with the visible label.
- **Global `touch-action: none`.** Kills scrolling and zoom. Scope it to drag handles.

## Accessibility
- 2.5.1 Pointer Gestures (A), 2.5.2 Pointer Cancellation (A), 2.5.3 Label in Name (A), 2.5.4 Motion Actuation (A), 2.5.5 Target Size Enhanced (AAA), 2.5.6 Concurrent Input Mechanisms (AAA: don't block mouse on touch devices or vice versa), 2.5.7 Dragging Movements (AA), 2.5.8 Target Size Minimum (AA), 1.4.4 Resize Text (AA), 1.4.13 Content on Hover or Focus (AA), 1.3.4 Orientation (AA).
- 2.5.8 exceptions: spacing, equivalent control elsewhere, inline in text, user-agent default controls, essential presentation.

## Responsive Design
- Use input-capability queries (`pointer`, `any-pointer`, `hover`) rather than viewport width to adapt target sizes. Tablets with keyboards and touch laptops break width assumptions.
- Keep primary actions in thumb-reachable zones on mobile, and ensure sticky bottom bars don't obscure focus (2.4.11).
- Support both orientations.

## Performance
- Pointer event handlers should be passive where they don't `preventDefault` (`{ passive: true }`) for smooth scrolling. React attaches touch listeners as passive by default at the root.
- Drag libraries: lazy-load heavy DnD code on interaction for large boards.

## Security
- Motion sensor access (DeviceMotion) requires permission on iOS. Don't gate security flows (e.g., shake to report) on sensors.

## Testing
```ts
test('@a11y mobile target sizes', async ({ page, makeAxeBuilder }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/inbox');
  const r = await makeAxeBuilder().withRules(['target-size']).analyze();
  expect(r.violations).toEqual([]);
});

test('reorder without dragging', async ({ page }) => {
  await page.goto('/playlist');
  await page.getByRole('button', { name: 'Move Song B up' }).click();
  await expect(page.getByRole('listitem').first()).toContainText('Song B');
});
```
- Manual: iOS Voice Control ("Show names", "Tap Move Song B up"), Android Voice Access, Windows Voice Access or Dragon on desktop; pinch-zoom check; tremor simulation (tap near edges).

## Tooling
- axe-core `target-size`, `meta-viewport` rules.
- React Aria `usePress`, `useMove`, `useLongPress` (with accessible descriptions); dnd-kit (`KeyboardSensor`, announcements); Pragmatic drag and drop (Atlassian; pair with its accessibility guidance and buttons).
- Chrome DevTools device mode, Polypane, real-device labs (BrowserStack).
- Tailwind v4 `pointer-coarse:`/`pointer-fine:` variants.

## Framework Notes
- **Next.js.** Use the `viewport` export (not a manual meta tag) and never set `maximumScale`/`userScalable: false`. Client components are needed for gesture libraries; keep alternatives (buttons) server-renderable where possible.
- **React (Vite SPA).** Check `index.html` viewport meta for zoom-blocking values inherited from templates.
- **Component libraries.** Radix/shadcn icon buttons often default to 32–36px (passes 24px); check custom compact variants. MUI `size="small"` icon buttons may need spacing.

## AI Agent Guidance
- Do: ensure every interactive element is at least 24px (44px for primary mobile actions), provide button alternatives for drag and swipe, use click-based activation, and keep accessible names starting with the visible label.
- Do: keep zoom enabled; use the Next.js `viewport` export correctly.
- Don't: implement swipe-only, drag-only, hover-only or motion-only interactions; don't use `onPointerDown` for activation.
- Verify before done:
  - axe `target-size` passes on a mobile viewport
  - drag features are operable via buttons alone
  - voice-control naming checked (visible label contained in name)

## Examples
See Implementation Guidance (hit area CSS, usePress, dnd-kit with buttons, viewport export).

## Related Skills
- [drag-and-drop](../drag-and-drop/Skill.md) — DnD component implementation
- [kanban-boards](../kanban-boards/Skill.md) — drag alternatives on boards
- [carousels](../carousels/Skill.md) — swipe alternatives
- [sliders-and-range-inputs](../sliders-and-range-inputs/Skill.md) — slider targets and keys
- [mobile-web-app-patterns](../mobile-web-app-patterns/Skill.md) — mobile ergonomics
- [tooltips](../tooltips/Skill.md) — hover/focus content
- [keyboard-navigation](../keyboard-navigation/Skill.md) — non-pointer input parity
- [maps-and-geospatial-ui](../maps-and-geospatial-ui/Skill.md) — map gesture alternatives

## Sources
- [Understanding 2.5.8 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) — Official — 24px rule, spacing circle, exceptions
- [Understanding 2.5.7 Dragging Movements](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html) — Official — single-pointer alternatives
- [Understanding 2.5.1 / 2.5.2 / 2.5.3 / 2.5.4](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — gestures, cancellation, label in name, motion
- [dnd-kit accessibility docs](https://docs.dndkit.com/guides/accessibility) — Open Source — keyboard sensor and announcements
- [React Aria usePress](https://react-spectrum.adobe.com/react-aria/usePress.html) — Open Source — cross-device press handling
- [Next.js viewport API](https://nextjs.org/docs/app/api-reference/functions/generate-viewport) — Official — viewport export
- [Apple HIG / Material Design touch targets](https://developer.apple.com/design/human-interface-guidelines/accessibility) — Official (platform) — 44pt/48dp guidance

## License / Usage Notes
Summarised from W3C and library docs (dnd-kit MIT, React Aria Apache-2.0). Code is original.

## Quality Tier
A — normative WCAG 2.2 criteria with practical React implementations. Voice-control behaviours vary by platform.

## Status
Active

## Last Verified
2026-09-15
