# Tree Views

## Summary
Tree views show hierarchical data with expandable nodes: file explorers, org charts, folder pickers, nested categories, JSON inspectors. This skill covers the APG Tree View pattern (roles, full keyboard model, single and multi-selection), when a treegrid or nested navigation list is more appropriate, lazy loading and virtualization of large trees, drag-to-move, and React implementations (React Aria `Tree`, headless patterns with TanStack Virtual).

## Category
Components

## Subcategories
Tree, treeitem, treegrid, file explorer, hierarchical selection, lazy loading, virtualized tree

## Problem It Solves
Hierarchies are hard to browse without structure. Custom trees are usually nested divs with click handlers: no keyboard model, every node tabbable, and no announced level, position, or expanded state. They collapse under thousands of nodes, and selection and focus get confused. Developers also use `role="tree"` for simple nested navigation, adding complexity for screen reader users.

## When To Use
- Browsing and selecting within deep hierarchies in app-like UIs: file/asset managers, permissions scopes, taxonomy editors, component outlines.
- Choosing a node (folder picker) or multiple nodes (permission scopes with checkboxes).

## When Not To Use
- Site or docs navigation with links: use nested lists of links with disclosure buttons (navigation-menus-and-sidebars).
- Hierarchical data with columns (size, modified date): use a treegrid or data grid with row grouping.
- Shallow hierarchies (≤2 levels, few items): accordion or grouped lists.
- Mobile-first contexts: drill-down lists usually beat deep trees.

## Core Principles
1. One tab stop for the whole tree; arrow keys move focus (roving tabindex or `aria-activedescendant`).
2. Right/Left arrows expand/collapse and move between parent and child; Up/Down move through visible nodes.
3. Expanded state (`aria-expanded`) goes only on parent nodes; leaves have none.
4. Selection is distinct from focus; use `aria-selected` *or* `aria-checked` consistently, not both.
5. When not all nodes are in the DOM (lazy or virtualized), provide `aria-level`, `aria-setsize`, `aria-posinset`.

## Best Practices
- Initial focus when tabbing in: the selected node, or the first node if none is selected (APG).
- Typeahead: typing jumps to the next visible node starting with that character.
- Multi-select: prefer the APG "recommended" model. Space toggles selection with no modifier keys needed. Shift+Arrow extends and Ctrl+A selects all.
- Show loading children inline ("Loading…" treeitem or `aria-busy` on the group) and announce errors.
- Indent visually by level (logical `padding-inline-start: calc(level * 1rem)`), and show expand chevrons as decoration (`aria-hidden`).
- Enter activates the node (open file / navigate). Don't overload single click with both selecting and opening; double-click to open is familiar in desktop metaphors but needs a keyboard equivalent (Enter).
- Preserve expansion state across navigation or refresh when useful (URL or storage).

## Implementation Guidance

### Keyboard (APG Tree View)
| Key | Behavior |
|---|---|
| Down / Up Arrow | Next / previous visible node (no expand/collapse) |
| Right Arrow | Closed parent: expand. Open parent: move to first child. Leaf: nothing |
| Left Arrow | Open parent: collapse. Child or closed node: move to parent. Root closed: nothing |
| Home / End | First / last visible node |
| Enter | Activate node (open/select in single-select; toggles parent in some implementations) |
| Printable character | Typeahead to next matching node |
| `*` (optional) | Expand all siblings at the level |
| Space (multi-select) | Toggle selection of focused node |
| Shift+Down/Up (multi-select, optional) | Move and toggle/extend selection |
| Shift+Space (optional) | Select contiguous range from last selected |
| Ctrl+A (optional) | Select all |

### Roles and attributes
| Element | Attributes |
|---|---|
| Container | `role="tree"`, `aria-label`/`aria-labelledby`, `aria-multiselectable="true"` when multi |
| Node | `role="treeitem"`, `aria-expanded` (parents only), `aria-selected` or `aria-checked`, `tabIndex` 0/-1 |
| Children container | `role="group"` nested inside the parent treeitem's `li` |
| Virtualized/lazy | `aria-level`, `aria-setsize`, `aria-posinset` on each treeitem |
| Loading | `aria-busy="true"` on the group while fetching |

### Decision table
| Need | Choose |
|---|---|
| React app tree with selection, expansion, DnD, keyboard, screen reader support | React Aria Components `Tree` (+ `useDragAndDrop`) |
| Huge trees (10k+ nodes) | Flatten visible nodes + TanStack Virtual + APG ARIA attributes (level/setsize/posinset) |
| Columns per node | Treegrid (React Aria Table/TreeGrid-capable components, AG Grid tree data) |
| Docs/site navigation | Nested `ul` of links + disclosure buttons, not `role="tree"` |

## Recommended Workflow
1. Confirm a tree is the right model (vs nav list, drill-down, treegrid).
2. Define the data model: `id`, `parentId`, `hasChildren`, `name`, lazy loaders.
3. Decide selection mode (none, single, multiple, checkbox with partial states).
4. Choose React Aria Tree or a flattened, virtualized custom tree.
5. Implement the keyboard model, typeahead, expansion state, loading states.
6. Add actions (rename, move) via context/menu buttons with keyboard access. Add DnD with alternatives.
7. Test with keyboard, NVDA/JAWS/VoiceOver (level, position, expanded), and large datasets.

## Patterns

### Flattening visible nodes (shared by custom and virtualized trees)
```ts
export type Node = { id: string; name: string; children?: Node[] };
export type FlatNode = { node: Node; level: number; posinset: number; setsize: number; parentId: string | null };

export function flattenVisible(nodes: Node[], expanded: Set<string>, level = 1, parentId: string | null = null): FlatNode[] {
  return nodes.flatMap((node, i) => {
    const row: FlatNode = { node, level, posinset: i + 1, setsize: nodes.length, parentId };
    return node.children && expanded.has(node.id)
      ? [row, ...flattenVisible(node.children, expanded, level + 1, node.id)]
      : [row];
  });
}
```

### Custom tree rows with APG keyboard (flat DOM + aria-level)
```tsx
'use client';
import { useMemo, useRef, useState } from 'react';
import { flattenVisible, type Node } from './flatten';

export function FileTree({ data, label, onOpen }: { data: Node[]; label: string; onOpen: (n: Node) => void }) {
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [focusId, setFocusId] = useState(data[0]?.id);
  const rows = useMemo(() => flattenVisible(data, expanded), [data, expanded]);
  const refs = useRef(new Map<string, HTMLDivElement>());
  const focus = (id?: string) => { if (!id) return; setFocusId(id); refs.current.get(id)?.focus(); };
  const toggle = (id: string, open: boolean) =>
    setExpanded((s) => { const n = new Set(s); open ? n.add(id) : n.delete(id); return n; });

  const onKeyDown = (e: React.KeyboardEvent, i: number) => {
    const r = rows[i]; const isParent = !!r.node.children?.length; const isOpen = expanded.has(r.node.id);
    const handled = () => e.preventDefault();
    switch (e.key) {
      case 'ArrowDown': handled(); focus(rows[i + 1]?.node.id); break;
      case 'ArrowUp': handled(); focus(rows[i - 1]?.node.id); break;
      case 'ArrowRight': handled();
        if (isParent && !isOpen) toggle(r.node.id, true); else if (isParent) focus(rows[i + 1]?.node.id); break;
      case 'ArrowLeft': handled();
        if (isParent && isOpen) toggle(r.node.id, false); else focus(r.parentId ?? undefined); break;
      case 'Home': handled(); focus(rows[0]?.node.id); break;
      case 'End': handled(); focus(rows.at(-1)?.node.id); break;
      case 'Enter': handled(); isParent ? toggle(r.node.id, !isOpen) : onOpen(r.node); break;
      default:
        if (e.key.length === 1 && /\S/.test(e.key)) {
          const k = e.key.toLowerCase();
          const next = [...rows.slice(i + 1), ...rows.slice(0, i)].find((x) => x.node.name.toLowerCase().startsWith(k));
          focus(next?.node.id);
        }
    }
  };

  return (
    <div role="tree" aria-label={label}>
      {rows.map((r, i) => (
        <div key={r.node.id} ref={(el) => { if (el) refs.current.set(r.node.id, el); else refs.current.delete(r.node.id); }}
          role="treeitem" aria-level={r.level} aria-posinset={r.posinset} aria-setsize={r.setsize}
          aria-expanded={r.node.children?.length ? expanded.has(r.node.id) : undefined}
          tabIndex={r.node.id === focusId ? 0 : -1}
          style={{ paddingInlineStart: `${(r.level - 1) * 1.25}rem` }}
          onKeyDown={(e) => onKeyDown(e, i)} onClick={() => focus(r.node.id)}
          onDoubleClick={() => !r.node.children && onOpen(r.node)}>
          {r.node.children?.length ? <span aria-hidden>{expanded.has(r.node.id) ? '▾' : '▸'}</span> : null} {r.node.name}
        </div>
      ))}
    </div>
  );
}
```
A flat DOM with `aria-level`/`aria-posinset`/`aria-setsize` is valid per APG and plugs directly into virtualization. If the focused node's ancestor collapses, move focus to that ancestor.

### Virtualizing the flat rows
Feed `rows.length` to TanStack Virtual's `useVirtualizer`. Call `virtualizer.scrollToIndex(i)` before focusing a row that isn't rendered, then focus it after render (effect keyed on `focusId`).

### Lazy children
Mark unloaded parents `hasChildren: true`. On expand, set `aria-busy` on the tree, render a "Loading…" row, fetch, then clear. On failure, render an error row with a Retry button, and announce it via a status region.

## Anti-Patterns
- **`role="tree"` for site navigation links**: forces app-mode interaction. Fix: nested lists + disclosure.
- **Every node tabbable**: Fix: roving tabindex.
- **`aria-expanded="false"` on leaves**: screen readers announce collapsible leaves. Fix: omit on leaves.
- **Both `aria-selected` and `aria-checked`**: conflicting semantics. Fix: pick one.
- **Clicking the row both selects and navigates**: accidental opens. Fix: select on click, open on Enter/double-click or an explicit action.
- **Focus lost when a node's ancestor collapses or the node is deleted**: Fix: move focus to the nearest ancestor or sibling.
- **Rendering 50k nodes**: Fix: flatten + virtualize + lazy load.
- **Drag-only move**: Fix: "Move to…" dialog/menu alternative.

## Accessibility
- WCAG 1.3.1 Info and Relationships (levels, position), 2.1.1 Keyboard, 4.1.2 Name/Role/Value, 2.4.7 Focus Visible, 2.5.7 Dragging Movements (move alternatives), 4.1.3 Status Messages (loading, errors, moves).
- Screen readers should announce "tree item, expanded, level 2, 3 of 7". Test NVDA, JAWS, VoiceOver.
- Visible focus distinct from selection styling.

## Responsive Design
- On narrow screens, switch to drill-down lists (one level per screen with a back button) or a full-width tree with larger rows (≥44px).
- Long names: truncate with an ellipsis and expose the full name via `title`/tooltip *and* the accessible name.
- Horizontal overflow for deep indentation: cap the indent and show level through other cues.

## Performance
- Memoize flattening; keep expansion as a `Set` of ids.
- Virtualize at ~1k+ visible rows. Lazy-load children for large backends.
- Avoid re-rendering all rows on focus change: key rows by id, and memoize row components.

## Security
- Lazy child endpoints must authorize per node; don't reveal names of restricted folders.
- Validate move operations server-side (no cycles, permissions).

## Testing
- Unit: `flattenVisible` levels, posinset, setsize; keyboard reducer transitions.
- Testing Library: `getByRole('tree')`, `getAllByRole('treeitem')`, `{ArrowRight}` sets `aria-expanded="true"`, typeahead focuses the expected node.
- Playwright: large dataset scroll plus keyboard to end; lazy load and error states; focus retention on collapse.
- Screen reader manual pass.

## Tooling
- React Aria Components `Tree`, `TreeItem`, `TreeItemContent`, `useDragAndDrop` (Apache-2.0).
- TanStack Virtual for virtualized flat trees.
- AG Grid (tree data) / MUI X Tree View for enterprise grids. Verify licenses: some features are commercial.

## Framework Notes
- **React (Vite SPA)**: Keep tree data normalized (`byId`, `childrenIds`). Expansion and selection live in component state or the URL (for shareable explorers). Fetch children with TanStack Query keyed by `parentId`, and prefetch on hover or focus.
- **Next.js (App Router)**: Trees are Client Components (`'use client'`). Load the initial levels in a Server Component and pass serializable data. Load deeper levels through route handlers or Server Actions. Selecting a node that maps to a route (`/files/[...path]`) should use `router.push` and keep tree focus. Avoid re-mounting the tree on navigation by placing it in a layout. Expanded state from cookies or search params must be identical on server and client to avoid hydration mismatch.

## AI Agent Guidance
- DO confirm the tree is appropriate (not nav, not a treegrid).
- DO implement the full APG keyboard model or use React Aria Tree.
- DO add level/posinset/setsize for flat or virtualized rendering.
- DON'T make every node tabbable or put `aria-expanded` on leaves.
- Verify: arrow semantics (Right/Left) exactly per APG; typeahead; focus after collapse or delete; screen reader announcements; performance with realistic node counts; move alternative to DnD.

## Examples
React Aria Components Tree with selection:
```tsx
import { Tree, TreeItem, TreeItemContent, Button, Checkbox } from 'react-aria-components';

type Item = { id: string; name: string; children?: Item[] };

export function PermissionTree({ items }: { items: Item[] }) {
  return (
    <Tree aria-label="Permission scopes" items={items} selectionMode="multiple" defaultExpandedKeys={['projects']}>
      {function render(item: Item) {
        return (
          <TreeItem id={item.id} textValue={item.name}>
            <TreeItemContent>
              {({ hasChildItems }) => (<>
                <Checkbox slot="selection" />
                {hasChildItems && <Button slot="chevron" aria-label="Toggle">▸</Button>}
                {item.name}
              </>)}
            </TreeItemContent>
            {item.children?.map(render)}
          </TreeItem>
        );
      }}
    </Tree>
  );
}
```
The render-prop and slot names follow current React Aria docs; verify them against your installed version.

## Related Skills
- [list-virtualization](../list-virtualization/Skill.md): virtualizing flattened trees
- [drag-and-drop](../drag-and-drop/Skill.md): moving nodes accessibly
- [keyboard-navigation](../keyboard-navigation/Skill.md): roving focus and typeahead
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md): why nav isn't a tree
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md): Tree component
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md): tree data in grids
- [master-detail-layouts](../master-detail-layouts/Skill.md): explorer + detail panes

## Sources
- [WAI-ARIA APG: Tree View Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treeview/) — Official — keyboard, selection models, roles and properties
- [React Aria: Tree](https://react-aria.adobe.com/Tree) — Open Source — anatomy, selection, expansion, DnD
- [React Aria: Drag and Drop](https://react-aria.adobe.com/dnd) — Open Source — tree moves, keyboard DnD
- [TanStack Virtual: Virtualizer API](https://tanstack.com/virtual/latest/docs/api/virtualizer) — Open Source — virtualization of flat rows

## License / Usage Notes
Summarized in original wording; code original. React Aria Apache-2.0; TanStack MIT. AG Grid/MUI X tree features may require commercial licenses.

## Quality Tier
A — APG-complete keyboard model with runnable React code; React Aria Tree's exact rendered roles weren't verified.

## Status
Active

## Last Verified
2026-09-15
