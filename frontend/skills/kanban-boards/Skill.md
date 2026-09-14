# Kanban Boards

## Summary
How to build production kanban boards in React/Next.js. It covers columns (statuses) and cards, drag-and-drop with dnd-kit or Pragmatic drag and drop, keyboard and non-drag "Move to…" alternatives, stable ordering with fractional indexing, optimistic moves with rollback via `useOptimistic` and Server Actions, WIP limits, swimlanes, virtualization and realtime updates.

## Category
Enterprise UI

## Subcategories
drag and drop, sortable lists, dnd-kit, fractional indexing, optimistic UI, WIP limits, swimlanes, workflow states

## Problem It Solves
Boards look simple but fail in practice. Drag is inaccessible to keyboard and motor-impaired users. Reordering rewrites every row's position. Concurrent moves by teammates scramble order. Drops that violate workflow rules or permissions are accepted visually and then silently reverted. Large boards stutter.

## When To Use
- Work items flowing through a small number of ordered states: tickets, deals (CRM pipeline), recruiting candidates, content production, fulfilment stages.
- Teams that need at-a-glance WIP visibility and prioritization within a column.

## When Not To Use
- Many states (>8–10) or complex branching workflows. Use a list with a status filter, or workflow-and-approval-ui.
- Thousands of items per column that users need to search and compare. Use enterprise-data-tables, with the board as a secondary view.
- Time-based planning. Use resource-scheduling-and-timeline-views.

## Core Principles
1. Drag is a shortcut. Every move is possible without dragging (WCAG 2.5.7 Dragging Movements, AA), through a "Move to…" menu, keyboard sensor, or status select on the card detail.
2. The server is the authority for transitions: permissions, allowed transitions (state machine), WIP limits and ordering are validated in the Server Action/DAL.
3. Order with fractional keys (lexorank-style strings) so a move updates one row.
4. Moves are optimistic with explicit rollback and a clear error message.
5. Concurrent edits are expected: broadcast moves and reconcile by server order keys.
6. Columns and swimlanes are views over data: status, and optionally assignee/priority, grouped server-side.

## Best Practices
- Card anatomy: title (2 lines max), key id, 2–4 meta chips (assignee avatar, due date, priority, labels), and an overflow menu with Move to, Assign and Open. Keep the whole card clickable to open detail (drawer or route), with the drag handle separate or the whole card draggable with an activation constraint.
- Use a pointer activation constraint (distance of about 5–8px or delay) so clicks and scrolls don't start drags.
- Column header shows name, count and WIP limit ("4 / 5"). The limit exceeded state uses a text badge plus colour.
- Disallowed drop targets are dimmed while dragging, with a reason on hover/announcement ("Requires approval before Done").
- Auto-scroll columns and the board while dragging near edges (built into dnd-kit and Pragmatic dnd auto-scroll packages).
- Quick add at the top/bottom of a column. Collapse columns. Filters in the URL (assignee, label, search).
- Undo toast after moves ("Moved to Done · Undo").
- Swimlanes: group rows by assignee/epic/priority with collapsible lane headers. Drop sets both status and lane field.

## Implementation Guidance
**Library decision table**

| Library | Status (2026-09) | Notes |
|---|---|---|
| `@dnd-kit/core` + `@dnd-kit/sortable` | Stable, MIT, widely used. Repo actively pushed | Sensors (pointer, keyboard), `DragOverlay`, collision detection, screen-reader announcements and instructions |
| `@dnd-kit/react` (new architecture) | 0.5.0 on npm, pre-1.0 | Framework-agnostic core (`@dnd-kit/dom`). Evaluate for new work, but expect API changes |
| Pragmatic drag and drop (Atlassian) | Open source, framework-agnostic, used across Atlassian products | Built on native HTML DnD. Small core plus optional packages. Publishes design and accessibility guidance recommending non-drag alternatives |
| `react-beautiful-dnd` | Archived/deprecated by Atlassian (verify) | Don't start new work. Migrate to Pragmatic dnd or dnd-kit |

**Data model**
```ts
export interface Card { id: string; boardId: string; status: StatusKey; laneKey?: string; rank: string; version: number; title: string; }
export type StatusKey = 'backlog' | 'todo' | 'in_progress' | 'review' | 'done';
export interface Column { key: StatusKey; name: string; wipLimit?: number; }
export interface MoveInput { cardId: string; toStatus: StatusKey; toLane?: string; beforeId?: string; afterId?: string; version: number; }
```
The client sends neighbours (`beforeId`/`afterId`), not a computed rank. The server reads the neighbour ranks and computes `rank = between(prev.rank, next.rank)` with a fractional-indexing implementation (e.g. the `fractional-indexing` package; check maintenance). It rebalances a column in a background job when keys grow long.

**Server Action with authorization and rules**
```ts
'use server';
import { z } from 'zod';
import { moveCard } from '@/data/cards'; // server-only
import { revalidateTag } from 'next/cache';

const Move = z.object({ cardId: z.string(), toStatus: z.enum(['backlog','todo','in_progress','review','done']),
  toLane: z.string().optional(), beforeId: z.string().optional(), afterId: z.string().optional(), version: z.number().int() });

export async function moveCardAction(input: unknown) {
  const data = Move.parse(input);
  const res = await moveCard(data); // DAL: session, board permission, transition allowed, WIP limit, version check, fractional rank, audit, broadcast
  if (res.ok) revalidateTag(`board:${res.boardId}`); // check revalidateTag signature in current Next.js docs
  return res; // { ok: true, card } | { ok: false, reason: 'forbidden' | 'transition' | 'wip' | 'conflict', message }
}
```

## Recommended Workflow
1. Define statuses, allowed transitions, WIP limits and the ordering strategy with product.
2. Model `rank` (fractional string) and `version`. Add an index on `(boardId, status, rank)`.
3. Implement the `moveCard` DAL with all rules, then build the Server Action.
4. Render the board from a Server Component (DAL query grouped by status). Make the board interactivity a Client Component.
5. Add dnd-kit sortable with a keyboard sensor, announcements and a `DragOverlay`.
6. Add the "Move to…" menu and status select as non-drag alternatives, using the same action.
7. Add `useOptimistic` plus rollback, and the undo toast.
8. Add realtime broadcast (reconcile), virtualization for long columns, and URL filters.
9. Test keyboard moves, screen-reader announcements, rule violations and concurrent moves.

## Patterns
**Optimistic board with rollback**
```tsx
'use client';
import { useOptimistic, useTransition } from 'react';
import { DndContext, DragOverlay, KeyboardSensor, PointerSensor, closestCorners, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core';
import { sortableKeyboardCoordinates } from '@dnd-kit/sortable';
import { moveCardAction } from './actions';
import { toast } from '@/components/toast';

type Move = { cardId: string; toStatus: StatusKey; beforeId?: string; afterId?: string };

export function Board({ columns, cards }: { columns: Column[]; cards: Card[] }) {
  const [optimisticCards, applyMove] = useOptimistic(cards, (state, m: Move) => reorderLocally(state, m));
  const [, startTransition] = useTransition();
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  function commit(m: Move) {
    const card = optimisticCards.find((c) => c.id === m.cardId)!;
    startTransition(async () => {
      applyMove(m); // reverts automatically when the transition ends if server data didn't change
      const res = await moveCardAction({ ...m, version: card.version });
      if (!res.ok) toast.error(res.message ?? 'Move failed'); // optimistic state is discarded -> rollback
    });
  }

  function onDragEnd(e: DragEndEvent) {
    if (!e.over) return;
    commit(resolveDrop(optimisticCards, String(e.active.id), e.over)); // compute toStatus + neighbours
  }

  return (
    <DndContext sensors={sensors} collisionDetection={closestCorners} onDragEnd={onDragEnd}
      accessibility={{ announcements: boardAnnouncements(columns, optimisticCards), screenReaderInstructions: { draggable: 'Press space to pick up a card. Use arrow keys to move between positions and columns. Press space to drop, escape to cancel.' } }}>
      <div className="board" role="region" aria-label="Board">
        {columns.map((col) => (
          <BoardColumn key={col.key} column={col} cards={optimisticCards.filter((c) => c.status === col.key)} onMoveTo={commit} columns={columns} />
        ))}
      </div>
      <DragOverlay>{/* render dragged card preview */}</DragOverlay>
    </DndContext>
  );
}
```
Check the current dnd-kit docs for the exact `accessibility` prop shape. Wrap each column's list in `SortableContext` with `verticalListSortingStrategy`.

**Non-drag "Move to…" menu**
```tsx
<DropdownMenu label={`Move ${card.title}`}>
  {columns.filter((c) => c.key !== card.status).map((c) => (
    <MenuItem key={c.key} onSelect={() => onMoveTo({ cardId: card.id, toStatus: c.key /* append to top */ })}>{c.name}</MenuItem>
  ))}
  <MenuItem onSelect={() => onMoveTo(moveWithinColumn(card, 'top'))}>Move to top</MenuItem>
  <MenuItem onSelect={() => onMoveTo(moveWithinColumn(card, 'bottom'))}>Move to bottom</MenuItem>
</DropdownMenu>
```

**Realtime reconcile**: subscribe to `card.moved` events (SSE/WebSocket/Liveblocks). Replace the card by id if the `version` is newer and re-sort by `rank`. If the user is mid-drag, queue updates until drop.

## Anti-Patterns
- **Integer positions renumbered on every move.** O(n) writes and race conditions. Fix: fractional ranks computed server-side from neighbours.
- **Drag-only moves.** Fails WCAG 2.5.7 and keyboard users. Fix: keyboard sensor plus "Move to…" menu plus a status field in detail.
- **Client decides legality.** Forbidden transitions persist via a direct action call. Fix: validate transition, permission and WIP in the DAL. The UI hints only.
- **Silent revert on failure.** Users think the move happened. Fix: rollback plus an error toast with the reason.
- **Whole card draggable without an activation constraint.** Clicks and scrolls start drags on touch. Fix: a distance/delay constraint or a dedicated handle.
- **Rendering 2,000 cards.** Janky drag. Fix: virtualize column lists, paginate "Load more" per column, or filter.
- **Using react-beautiful-dnd for new work.** Unmaintained. Fix: dnd-kit or Pragmatic dnd.

## Accessibility
- WCAG 2.5.7 Dragging Movements (AA): a single-pointer alternative for every move ("Move to…" menu).
- WCAG 2.1.1 Keyboard: the keyboard sensor lets a user pick up (Space/Enter), move with arrows across columns, drop (Space) and cancel (Esc).
- Live announcements for pick up, over ("Over In review, position 2 of 5"), drop and cancel. dnd-kit provides `announcements` and `screenReaderInstructions` hooks.
- Columns: `role="group"` or a list with an accessible name including the count ("In progress, 4 cards, limit 5"). Cards are list items with a link/button to open.
- Focus returns to the moved card after keyboard or menu moves (focus-management).
- WIP exceeded and drop-disallowed are communicated with text, not colour only (WCAG 1.4.1). Honour `prefers-reduced-motion` for drop animations.

## Responsive Design
- Desktop: horizontal columns with horizontal scroll, sticky column headers and a fixed column width (272–320px).
- Tablet: snap scrolling per column (`scroll-snap-type: x mandatory`).
- Phone: one column at a time with a status tab/segmented control or select. Moves via menu. Drag optional with a long-press activation constraint.
- Swimlanes collapse into grouped sections on mobile.

## Performance
- Render the drag preview in `DragOverlay`, and memoize cards (`React.memo`) so only affected columns rerender.
- Virtualize long columns (TanStack Virtual). Note that sortable plus virtualization needs care: keep the dragged item mounted (see dnd-kit docs/examples).
- Use CSS transforms for movement. Avoid layout-triggering properties during drag.
- Batch realtime updates with `startTransition`.
- Load per-column pages server-side (e.g. first 50 by rank) with "Load more".

## Security
- Every move goes through a Server Action that checks authentication, board/project membership, transition rules, WIP policy (if enforced) and ownership (IDOR).
- Validate `cardId`, neighbour ids and board consistency (neighbours must belong to the same board and tenant).
- Audit log status changes (who, from, to, when). Return minimal card DTOs.

## Testing
- Unit: `resolveDrop`, `reorderLocally`, and fractional rank generation (including many inserts at the same spot).
- Component: keyboard move with Testing Library (`user.keyboard('[Space]')`, arrows, Space) and assert the action call and announcement text.
- Playwright: mouse drag between columns (`locator.dragTo` or manual `mouse.move` steps for dnd-kit pointer sensor), menu move, forbidden transition shows a rollback toast, and two contexts see each other's moves.
- A11y: axe on the board, and screen-reader walkthrough with NVDA/VoiceOver.

## Tooling
- dnd-kit (`@dnd-kit/core`, `@dnd-kit/sortable`, `@dnd-kit/modifiers`, MIT). `@dnd-kit/react` 0.5.0 is pre-1.0.
- Pragmatic drag and drop (Atlassian), with auto-scroll and accessibility guidance packages. Check current docs.
- Fractional indexing (`fractional-indexing` package or a lexorank implementation). Verify maintenance.
- TanStack Virtual for long columns. Liveblocks/Yjs/SSE for realtime.

## Framework Notes
- **React (Vite SPA):** use TanStack Query `useMutation` with `onMutate` snapshot and `onError` rollback instead of `useOptimistic` plus Server Actions. The server API enforces the same rules.
- **Next.js App Router:** the Server Component page fetches columns and cards through the DAL (cached and tagged by board), and passes plain DTOs to the client `Board`. Moves are Server Actions, then `revalidateTag`/`revalidatePath`. `useOptimistic` gives instant feedback. Filters live in the URL (nuqs, `searchParams` Promise). Card detail opens via an intercepting route (`@modal/(.)cards/[id]`) so it is linkable.

## AI Agent Guidance
- Do: fractional ranks computed on the server, a Server Action with transition/permission/WIP checks, a keyboard sensor with announcements, a "Move to…" menu, `useOptimistic` rollback plus toast, and an activation constraint.
- Don't: renumber all positions, trust client legality checks, ship drag-only moves, or pick react-beautiful-dnd.
- Verify: move a card with keyboard only and with the menu, a forbidden move rolls back with a message, reloading preserves order, two browser contexts stay consistent, and a 500-card column scrolls and drags smoothly.

## Examples
```ts
// data/cards.ts (excerpt)
import 'server-only';
import { generateKeyBetween } from 'fractional-indexing'; // verify package API/maintenance
import { requireBoardRole } from '@/data/auth';
import { allowedTransitions } from '@/lib/workflow';

export async function moveCard(input: MoveInput) {
  const card = await db.card.findUniqueOrThrow({ where: { id: input.cardId } });
  const user = await requireBoardRole(card.boardId, 'member'); // throws on forbidden
  if (!allowedTransitions[card.status].includes(input.toStatus)) return { ok: false as const, reason: 'transition' as const, message: `Can't move from ${card.status} to ${input.toStatus}` };
  const [before, after] = await Promise.all([
    input.beforeId ? db.card.findFirst({ where: { id: input.beforeId, boardId: card.boardId } }) : null,
    input.afterId ? db.card.findFirst({ where: { id: input.afterId, boardId: card.boardId } }) : null,
  ]);
  const rank = generateKeyBetween(before?.rank ?? null, after?.rank ?? null);
  const updated = await db.card.updateMany({ where: { id: card.id, version: input.version }, data: { status: input.toStatus, rank, version: { increment: 1 } } });
  if (updated.count === 0) return { ok: false as const, reason: 'conflict' as const, message: 'This card was changed by someone else. Refreshing.' };
  await audit(user, 'card.moved', { cardId: card.id, from: card.status, to: input.toStatus });
  return { ok: true as const, boardId: card.boardId };
}
```

## Related Skills
- [drag-and-drop](../drag-and-drop/Skill.md) — general accessible DnD foundations
- [optimistic-ui](../optimistic-ui/Skill.md) — optimistic updates and rollback
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — move mutations
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useOptimistic/useTransition
- [workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md) — transition rules and approvals
- [realtime-collaboration-ui](../realtime-collaboration-ui/Skill.md) — live moves and presence
- [list-virtualization](../list-virtualization/Skill.md) — long columns
- [crm-ui-patterns](../crm-ui-patterns/Skill.md) — deal pipelines as boards
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — drag announcements
- [dropdown-menus](../dropdown-menus/Skill.md) — "Move to…" menu

## Sources
- [dnd-kit repository](https://github.com/clauderic/dnd-kit) — Open Source — packages, sensors (pointer/mouse/touch/keyboard), screen-reader instructions and live announcements, MIT, active (pushed Sep 2026)
- [@dnd-kit/react on npm](https://www.npmjs.com/package/@dnd-kit/react) — Open Source — version 0.5.0, depends on @dnd-kit/dom/state/abstract, React 18/19 peer
- [Pragmatic drag and drop (Atlassian Design System)](https://atlassian.design/components/pragmatic-drag-and-drop/about) — Official — framework-agnostic DnD, design and accessibility guidelines
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — authz and IDOR checks in Server Actions/DAL
- [WCAG 2.2 Understanding 2.5.7 Dragging Movements](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html) — Official — single-pointer alternative requirement (from standard knowledge; not re-fetched)

## License / Usage Notes
dnd-kit MIT. Pragmatic drag and drop is open source (Apache-2.0; verify). fractional-indexing is CC0/MIT (verify). Content is summarized. Code is original, and API details marked "check current docs" should be confirmed.

## Quality Tier
A — library status verified against npm and GitHub, with an accessibility-compliant and server-authoritative design. A few API specifics (dnd-kit `accessibility` prop shape, react-beautiful-dnd archive status) are flagged for verification.

## Status
Active

## Last Verified
2026-09-15
