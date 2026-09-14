# Drag and Drop

## Summary
Drag and drop (DnD) lets users reorder lists, move cards between columns, rearrange layouts, and drop files. This skill covers WCAG 2.5.7 (every drag needs a single-pointer, non-drag alternative), keyboard and screen reader strategies (React Aria keyboard DnD vs Atlassian's action-menu approach), live-region announcements, and library selection in 2026: Pragmatic drag and drop, dnd-kit (legacy `@dnd-kit/core` vs the pre-1.0 `@dnd-kit/react`), React Aria `useDragAndDrop`. It also covers persistence with optimistic updates in React and Next.js.

## Category
Components

## Subcategories
Sortable lists, kanban, cross-list moves, file drop zones, drop indicators, auto-scroll, keyboard DnD, fractional indexing

## Problem It Solves
DnD is often pointer-only, which excludes keyboard, screen reader, switch, voice and motor-impaired users. It's also janky with large lists, broken on touch, and silent about outcomes. Reorders get lost on network failure. Libraries have shifted (react-beautiful-dnd is deprecated; dnd-kit is mid-rewrite), so teams pick stale tooling.

## When To Use
- Reordering items where spatial manipulation is natural: kanban boards, playlists, dashboard widgets, form builders, tree moves.
- File upload drop zones (always alongside a file input button).
- Moving items between containers (columns, folders).

## When Not To Use
- As the only way to perform an action: never.
- Ordering 2–3 items: up/down buttons are simpler.
- Setting numeric priority precisely: use a position/select input.
- Mobile-first flows where long-press drag conflicts with scrolling. Prefer "Move to…" actions.

## Core Principles
1. Every drag outcome is achievable without dragging (WCAG 2.5.7 AA): buttons, menus ("Move to top", "Move to column…") or keyboard DnD.
2. Announce start, movement and result in a live region with item name and old/new position ("Task ‘Clean dishes’ moved to Doing, position 2 of 5").
3. Show clear affordances: a drag handle with an accessible name, a drop indicator line, and the source placeholder.
4. After a move, keep focus on the moved item (or the trigger that initiated the move).
5. Persist optimistically, reconcile with the server, and roll back with a message on failure.

## Best Practices
- Name handles with context: "Reorder ‘Clean dishes’", not "Drag".
- Atlassian's research found action menus (drag handle button opens a "Move" menu: top, up, down, bottom, to another list) more usable for assistive tech users than arrow-key dragging. Consider offering both.
- Keyboard DnD (React Aria model): Enter to start; Tab/arrows to choose a drop target or position; Enter to drop; Escape to cancel.
- Drop indicators: a line between items for "before/after", a highlight for "on" (into a folder).
- Auto-scroll near container edges during drag.
- Touch: activation delay or distance threshold so scrolling still works; handles ≥ 44px.
- Respect `prefers-reduced-motion` for drop animations.
- Store order with fractional indexes/lexorank strings so a move updates one row instead of renumbering everything.

## Implementation Guidance

### Library decision table (Sept 2026)
| Library | Model | Status | Choose when |
|---|---|---|---|
| Pragmatic drag and drop (Atlassian) | Native HTML5 DnD, headless, framework-agnostic; core ~4.7 kB; optional hitbox, auto-scroll, live-region, react-drop-indicator packages | Active; powers Trello/Jira/Confluence | Large boards, virtualization, cross-window or external file drops, performance-sensitive UIs |
| `@dnd-kit/core` + `@dnd-kit/sortable` (legacy) | Pointer/keyboard sensors, built-in announcements | Widely used, stable; maintenance focus moved to the new packages | Existing codebases; mature sortable examples |
| `@dnd-kit/react` (+ `@dnd-kit/dom`, `@dnd-kit/helpers`) | New architecture: `DragDropProvider`, `useDraggable`, `useDroppable`, `useSortable` | Pre-1.0 (0.5.0 mid-2026); roadmap for legacy core unclear | New projects that accept pre-1.0 APIs |
| React Aria `useDragAndDrop` | Collection-integrated DnD (ListBox, GridList, Tree, Table) with full keyboard and screen reader DnD, drop positions on/before/after | Stable | You already use React Aria collections; accessibility parity is the priority |
| react-beautiful-dnd | — | Deprecated/archived | Don't use; migrate to Pragmatic (Atlassian provides a migration path) |
| Native HTML DnD by hand | — | — | Only simple file drop zones |

### Keyboard (React Aria-style keyboard DnD)
| Key | Behavior |
|---|---|
| Enter (on draggable/handle) | Start drag mode, announce instructions |
| Tab / Shift+Tab | Move between drop targets (containers) |
| Arrow keys | Choose position within a collection (before/on/after) |
| Enter | Drop at the current target |
| Escape | Cancel, return to original position |

### Action-menu alternative (Atlassian guidance)
| Element | Markup |
|---|---|
| Handle | `<button aria-label="Move ‘Clean dishes’">` opens a menu |
| Menu items | "Move to top", "Move up", "Move down", "Move to bottom", "Move to column → Doing" |
| After action | Announce via live region; return focus to the handle button |

### ARIA notes
- `aria-grabbed`/`aria-dropeffect` are deprecated. Don't use them.
- Use a polite live region (`role="status"`) for announcements; libraries provide one (dnd-kit announcements, Pragmatic `live-region` package, React Aria built in).
- Drag instructions: associate with handles via `aria-describedby` ("Press Enter to pick up. Use arrows to move. Enter to drop, Escape to cancel.").

## Recommended Workflow
1. Define the moves (reorder within, between, into) and design the non-drag alternative first.
2. Choose a library (decision table); prototype with realistic list sizes and touch.
3. Implement handles, drop indicators, auto-scroll, placeholders.
4. Add announcements and focus restoration.
5. Persist: optimistic reorder → Server Action/API → reconcile or roll back with a toast.
6. Test pointer, touch, keyboard, screen reader, and virtualization if used.

## Patterns

### Fractional ordering helper
```ts
// Order keys as numbers between neighbors (use a lexorank/fractional-indexing lib for strings in production)
export function between(prev?: number, next?: number): number {
  if (prev === undefined && next === undefined) return 1;
  if (prev === undefined) return next! - 1;
  if (next === undefined) return prev + 1;
  return (prev + next) / 2;
}
```
Floats eventually lose precision. Rebalance occasionally, or use string fractional indexes.

### Sortable list with legacy dnd-kit + move buttons + optimistic Server Action
```tsx
'use client';
import { useOptimistic, useTransition, useId } from 'react';
import { DndContext, closestCenter, KeyboardSensor, PointerSensor, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core';
import { SortableContext, arrayMove, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { reorderTasks } from './actions'; // 'use server'

type Task = { id: string; title: string };

function Row({ task, index, count, onMove }: { task: Task; index: number; count: number; onMove: (from: number, to: number) => void }) {
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition, isDragging } = useSortable({ id: task.id });
  return (
    <li ref={setNodeRef} style={{ transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? .6 : 1 }}>
      <button ref={setActivatorNodeRef} {...attributes} {...listeners} aria-label={`Reorder ${task.title}`}>⠿</button>
      <span>{task.title}</span>
      <button type="button" disabled={index === 0} onClick={() => onMove(index, index - 1)} aria-label={`Move ${task.title} up`}>↑</button>
      <button type="button" disabled={index === count - 1} onClick={() => onMove(index, index + 1)} aria-label={`Move ${task.title} down`}>↓</button>
    </li>
  );
}

export function TaskList({ initial }: { initial: Task[] }) {
  const [tasks, setOptimistic] = useOptimistic(initial, (_s, next: Task[]) => next);
  const [, startTransition] = useTransition();
  const id = useId(); // stable DndContext id avoids SSR hydration mismatch in aria-describedby ids
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );
  const move = (from: number, to: number) => {
    const next = arrayMove(tasks, from, to);
    startTransition(async () => { setOptimistic(next); await reorderTasks(next.map((t) => t.id)); });
  };
  const onDragEnd = ({ active, over }: DragEndEvent) => {
    if (!over || active.id === over.id) return;
    move(tasks.findIndex((t) => t.id === active.id), tasks.findIndex((t) => t.id === over.id));
  };
  return (
    <DndContext id={id} sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}
      accessibility={{ announcements: {
        onDragStart: ({ active }) => `Picked up ${label(active.id)}.`,
        onDragOver: ({ active, over }) => over ? `${label(active.id)} is over position ${pos(over.id)} of ${tasks.length}.` : `${label(active.id)} is no longer over a drop position.`,
        onDragEnd: ({ active, over }) => over ? `${label(active.id)} dropped at position ${pos(over.id)} of ${tasks.length}.` : `${label(active.id)} dropped.`,
        onDragCancel: ({ active }) => `Moving ${label(active.id)} cancelled.`,
      } }}>
      <SortableContext items={tasks} strategy={verticalListSortingStrategy}>
        <ul>{tasks.map((t, i) => <Row key={t.id} task={t} index={i} count={tasks.length} onMove={move} />)}</ul>
      </SortableContext>
    </DndContext>
  );
  function label(id: string | number) { return tasks.find((t) => t.id === id)?.title ?? 'item'; }
  function pos(id: string | number) { return tasks.findIndex((t) => t.id === id) + 1; }
}
```
The up/down buttons also need a live-region announcement ("Moved ‘X’ to position 3 of 8"), and focus should follow the moved row. When the Server Action rejects, the optimistic state reverts after the transition ends; show a toast.

### Pragmatic drag and drop element wiring (React effect)
```tsx
'use client';
import { useEffect, useRef, useState } from 'react';
import { combine } from '@atlaskit/pragmatic-drag-and-drop/combine';
import { draggable, dropTargetForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import { attachClosestEdge, extractClosestEdge, type Edge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';

export function Card({ id, title }: { id: string; title: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const handleRef = useRef<HTMLButtonElement>(null);
  const [edge, setEdge] = useState<Edge | null>(null);
  useEffect(() => combine(
    draggable({ element: ref.current!, dragHandle: handleRef.current!, getInitialData: () => ({ id }) }),
    dropTargetForElements({
      element: ref.current!,
      getData: ({ input, element }) => attachClosestEdge({ id }, { input, element, allowedEdges: ['top', 'bottom'] }),
      onDrag: ({ self }) => setEdge(extractClosestEdge(self.data)),
      onDragLeave: () => setEdge(null),
      onDrop: () => setEdge(null),
    }),
  ), [id]);
  return (
    <div ref={ref} data-edge={edge ?? undefined}>
      <button ref={handleRef} type="button" aria-label={`Move ${title}`} /* opens Move menu on click */>⠿</button>
      {title}
    </div>
  );
}
```
Handle the actual reorder in a `monitorForElements({ onDrop })` at the list level. Announce with `@atlaskit/pragmatic-drag-and-drop-live-region`.

### File drop zone
```tsx
<div onDragOver={(e) => e.preventDefault()} onDrop={(e) => { e.preventDefault(); upload([...e.dataTransfer.files]); }}
  className="dropzone">
  <p>Drag files here or</p>
  <label className="button">Choose files<input type="file" multiple className="sr-only" onChange={(e) => upload([...(e.target.files ?? [])])} /></label>
</div>
```

## Anti-Patterns
- **Drag-only reordering**: WCAG 2.5.7 failure. Fix: move buttons or menus, or keyboard DnD.
- **Silent moves**: screen reader users don't know the result. Fix: live-region announcements with names and positions.
- **Whole card as drag activator on touch**: scrolling triggers drags. Fix: handle + activation distance/delay.
- **Renumbering every row's `position` on each move**: write amplification and race conditions. Fix: fractional indexes.
- **No rollback on failed persist**: UI shows an order the server rejected. Fix: optimistic with reconciliation + toast.
- **New adoption of react-beautiful-dnd**: deprecated. Fix: Pragmatic DnD or dnd-kit.
- **Using `aria-grabbed`**: deprecated. Fix: live regions + instructions.
- **Losing focus after a keyboard move**: Fix: refocus the moved item's handle.

## Accessibility
- WCAG 2.5.7 Dragging Movements (AA), 2.1.1 Keyboard, 4.1.3 Status Messages, 2.5.8 Target Size (handles), 2.4.7 Focus Visible, 1.3.1 (list semantics), 2.3.3 and reduced motion.
- Test with NVDA/JAWS (browse vs focus mode for arrow-key DnD), VoiceOver (iOS double-tap-and-hold), and voice control ("click Move Clean dishes").

## Responsive Design
- Mobile: prefer action menus ("Move to…") over dragging; if dragging, long-press activation with haptic-like visual feedback.
- Kanban on small screens: one column at a time with a "Move to column" action instead of cross-column drags.
- Increase handle size on coarse pointers (`@media (pointer: coarse)`).

## Performance
- Pragmatic DnD uses the native drag layer, so no per-frame React re-renders. Lazy-load the adapters it needs.
- With dnd-kit, avoid re-rendering all items on drag over. Memoize rows and use `transform` styles.
- For virtualized lists, use libraries that support it (Pragmatic works with virtualization; dnd-kit needs care since offscreen items are unmounted).
- Throttle auto-scroll and hit-testing; don't measure layout on every pointermove manually.

## Security
- Validate moves server-side (permissions, target container exists, no cycles in trees).
- File drops: validate type/size server-side, and never trust `dataTransfer` MIME types alone. Scan uploads.
- Beware dropped HTML/text from external sources; don't inject it as HTML.

## Testing
- Unit: reorder reducers, fractional index generation, announcement strings.
- Testing Library: move up/down buttons change order and announce; keyboard DnD (dnd-kit KeyboardSensor with Space/arrows) in jsdom is flaky, so prefer browser tests.
- Playwright: `locator.dragTo()` for pointer DnD (for native HTML5 DnD, verify `dragTo` fires dragstart/drop in all engines, or dispatch events); touch emulation; persistence and rollback with a mocked failing Server Action.
- Manual screen reader passes for announcements.

## Tooling
- `@atlaskit/pragmatic-drag-and-drop` (+ hitbox, auto-scroll, live-region, react-drop-indicator) — Apache-2.0.
- `@dnd-kit/core`/`@dnd-kit/sortable` (legacy, MIT), `@dnd-kit/react` (pre-1.0, MIT).
- React Aria `useDragAndDrop` (Apache-2.0).
- `fractional-indexing` style libraries for order keys (verify maintenance).

## Framework Notes
- **React (Vite SPA)**: Keep list order in a query cache (TanStack Query) and update optimistically in `onMutate` with rollback in `onError`. Pragmatic DnD wiring belongs in `useEffect` with the cleanup returned by `combine`. dnd-kit hooks must run inside `DndContext`/`DragDropProvider`.
- **Next.js (App Router)**: DnD components are Client Components (`'use client'`). Render the initial order in a Server Component and pass it as props. Persist with Server Actions + `useOptimistic`, then `revalidatePath`/`revalidateTag`. Legacy dnd-kit generates ids for `aria-describedby`; pass a stable `id` (from `useId`) to `DndContext` to avoid hydration mismatches. Don't import DnD libraries into Server Components. For file drops to storage, upload directly to presigned URLs rather than through Server Actions for large files.

## AI Agent Guidance
- DO implement the non-drag alternative first (buttons/menu), then add dragging.
- DO add announcements and focus restoration; DO use handles with contextual names.
- DON'T adopt react-beautiful-dnd; flag `@dnd-kit/react` as pre-1.0 when proposing it.
- DON'T renumber all positions on each move.
- Verify: reorder possible with keyboard only; screen reader announces the result; touch doesn't hijack scroll; optimistic rollback works; server validates moves; performance with realistic list sizes.

## Examples
React Aria GridList reordering (keyboard and screen reader DnD built in):
```tsx
'use client';
import { GridList, GridListItem, useDragAndDrop, Button } from 'react-aria-components';
import { useListData } from 'react-stately';

export function Playlist({ songs }: { songs: { id: string; name: string }[] }) {
  const list = useListData({ initialItems: songs });
  const { dragAndDropHooks } = useDragAndDrop({
    getItems: (keys) => [...keys].map((k) => ({ 'text/plain': list.getItem(k)!.name })),
    onReorder(e) {
      if (e.target.dropPosition === 'before') list.moveBefore(e.target.key, e.keys);
      else if (e.target.dropPosition === 'after') list.moveAfter(e.target.key, e.keys);
    },
  });
  return (
    <GridList aria-label="Playlist" items={list.items} dragAndDropHooks={dragAndDropHooks}>
      {(item) => <GridListItem textValue={item.name}><Button slot="drag" aria-label={`Drag ${item.name}`}>≡</Button>{item.name}</GridListItem>}
    </GridList>
  );
}
```

## Related Skills
- [kanban-boards](../kanban-boards/Skill.md): cross-column moves
- [optimistic-ui](../optimistic-ui/Skill.md): optimistic reorder and rollback
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md): move announcements
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md): WCAG 2.5.7
- [file-upload](../file-upload/Skill.md): drop zones
- [tree-views](../tree-views/Skill.md): moving nodes
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): persistence
- [list-virtualization](../list-virtualization/Skill.md): DnD in virtual lists

## Sources
- [Atlassian: Pragmatic drag and drop accessibility guidelines](https://atlassian.design/components/pragmatic-drag-and-drop/accessibility-guidelines) — Official (design system) — action menus, labels, live regions, focus restoration, why not arrow dragging
- [Pragmatic drag and drop repository](https://github.com/atlassian/pragmatic-drag-and-drop) — Open Source — packages, APIs, size
- [dnd kit docs](https://dndkit.com/) and [@dnd-kit/react quickstart](https://dndkit.com/react/quickstart) — Open Source — new architecture, migration guide
- [dnd-kit roadmap discussion #1842](https://github.com/clauderic/dnd-kit/discussions/1842) — Open Source — unresolved legacy vs new status
- [@dnd-kit/react on npm](https://www.npmjs.com/package/@dnd-kit/react) — Open Source — 0.5.0 version status
- [React Aria: Drag and Drop](https://react-aria.adobe.com/dnd) — Open Source — keyboard DnD flow, drop positions
- [WCAG 2.2 Understanding 2.5.7 Dragging Movements](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html) — Official — single-pointer alternative requirement

## License / Usage Notes
Summarized in original wording; code original. Pragmatic DnD Apache-2.0; dnd-kit MIT; React Aria Apache-2.0.

## Quality Tier
A — official WCAG and Atlassian research plus current library status; dnd-kit roadmap uncertainty noted.

## Status
Active

## Last Verified
2026-09-15
