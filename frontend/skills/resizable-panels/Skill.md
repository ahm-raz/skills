# Resizable Panels

## Summary
Resizable panels (split panes) let users drag or keyboard-adjust the boundary between regions: an IDE sidebar vs editor, mail list vs reading pane, a code/preview split. This skill covers the APG Window Splitter pattern (`role="separator"` with value attributes and arrow keys), collapse/expand behavior, persistence without layout shift, and React implementation with react-resizable-panels v4 (`Group`/`Panel`/`Separator`) or shadcn/ui Resizable.

## Category
Components

## Subcategories
Split pane, window splitter, separator, collapsible panel, layout persistence, IDE layouts

## Problem It Solves
Custom split panes are usually mouse-only drag handles: no keyboard support, no accessible name or value, and tiny hit areas. They lose their size on reload, flash on SSR, allow panels to shrink to unusable widths, and break on touch or when content (iframes) swallows pointer events during drag.

## When To Use
- Desktop-class apps where users tailor space between persistent regions: editors, dev tools, email/CRM master-detail, dashboards with inspector panels.
- Side-by-side comparison (diff, code + preview).

## When Not To Use
- Content websites and simple pages: fixed responsive layouts are better.
- Mobile: stack panels or use tabs/sheets. Dragging splitters on phones is awkward.
- When a simple collapse toggle suffices (sidebar open/closed).

## Core Principles
1. The splitter is a focusable `role="separator"` with `aria-valuenow`/`aria-valuemin`/`aria-valuemax`, a name matching the primary pane, and `aria-controls` → primary pane.
2. Arrow keys resize; Enter toggles collapse; Home/End go to min/max (optional); F6 cycles panes (optional).
3. Enforce min/max sizes so content stays usable; collapsible panels snap to a collapsed size.
4. Persist layout and restore it without layout shift (server-known on SSR).
5. The hit area is larger than the visual line; there's a visible focus indicator.

## Best Practices
- Name the separator after the primary pane ("Resize file explorer"). The value is the primary pane's size as a percentage.
- Arrow step ~1–5%; Shift+Arrow for larger steps (optional).
- Double-click the separator to reset or toggle collapse (a pointer shortcut; keep Enter as the keyboard equivalent).
- During drag, disable pointer events on iframes and heavy content so drags don't stall; show a resize cursor.
- Provide explicit collapse/expand buttons for panels as well (discoverability, WCAG 2.5.7).
- Use pixel minimums for panels with fixed-width content (toolbars), percentage for fluid content. react-resizable-panels v4 supports both units.
- Restore layout from a cookie (server-readable) in Next.js to avoid a post-hydration jump.

## Implementation Guidance

### Keyboard (APG Window Splitter)
| Key | Behavior |
|---|---|
| Left/Right Arrow (vertical splitter) | Move splitter, shrinking/growing primary pane |
| Up/Down Arrow (horizontal splitter) | Move splitter |
| Enter | Collapse primary pane / restore previous size |
| Home / End (optional) | Minimum / maximum primary size |
| F6 (optional) | Cycle focus between panes |

### ARIA
| Element | Attributes |
|---|---|
| Splitter | `role="separator"`, `tabIndex={0}`, `aria-orientation="vertical"` (for side-by-side panes), `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-label`/`aria-labelledby`, `aria-controls={primaryPaneId}` |
| Panes | Landmark or labelled regions as appropriate (`<aside aria-label="Explorer">`, `<main>`) |

### Decision table
| Need | Choose |
|---|---|
| React/Next.js split layouts | react-resizable-panels v4 (`Group`, `Panel`, `Separator`; `defaultLayout`, `onLayoutChanged`, collapsible, min/max in % or px) |
| shadcn/ui project | shadcn Resizable (wraps react-resizable-panels; check which major it targets) |
| Single sidebar width drag | Simple custom separator (below) or shadcn Sidebar rail |
| Mobile | Tabs or sheets instead of splitters |

## Recommended Workflow
1. Define panes, primary pane per splitter, min/max, collapsible behavior.
2. Pick react-resizable-panels (or shadcn Resizable) unless it's a single simple splitter.
3. Implement persistence (cookie for SSR, or localStorage in SPA).
4. Add collapse buttons and the Enter toggle.
5. Handle iframes/heavy content during drag.
6. Define a responsive fallback (stacked/tabs below a container width).
7. Test keyboard, screen reader value announcements, touch, persistence without flash.

## Patterns

### react-resizable-panels v4 with persisted layout (Next.js)
```tsx
// app/(ide)/layout.tsx (Server Component)
import { cookies } from 'next/headers';
import { IdeShell } from './ide-shell';

export default async function IdeLayout({ children }: { children: React.ReactNode }) {
  const raw = (await cookies()).get('ide-layout')?.value;
  const defaultLayout = raw ? (JSON.parse(raw) as Record<string, number>) : undefined;
  return <IdeShell defaultLayout={defaultLayout}>{children}</IdeShell>;
}
```
```tsx
// ide-shell.tsx
'use client';
import { Group, Panel, Separator } from 'react-resizable-panels';

export function IdeShell({ defaultLayout, children }: { defaultLayout?: Record<string, number>; children: React.ReactNode }) {
  return (
    <Group orientation="horizontal" defaultLayout={defaultLayout}
      onLayoutChanged={(layout) => { document.cookie = `ide-layout=${encodeURIComponent(JSON.stringify(layout))}; path=/; max-age=31536000; samesite=lax`; }}>
      <Panel id="explorer" defaultSize="20%" minSize="12rem" maxSize="40%" collapsible collapsedSize={0}>
        <aside aria-label="Explorer">…</aside>
      </Panel>
      <Separator aria-label="Resize explorer" className="splitter" />
      <Panel id="editor" minSize="30%">
        <main id="main">{children}</main>
      </Panel>
    </Group>
  );
}
```
Prop names follow the v4 renames (`PanelGroup`→`Group`, `PanelResizeHandle`→`Separator`). The exact names and shapes of `defaultLayout`, `orientation` and unit strings should be checked against the installed version's docs. Validate the cookie JSON before trusting it.

### Minimal accessible splitter (single sidebar)
```tsx
'use client';
import { useRef, useState } from 'react';

export function SidebarSplitter({ min = 15, max = 45 }: { min?: number; max?: number }) {
  const [size, setSize] = useState(25);
  const prev = useRef(25);
  const clamp = (n: number) => Math.min(max, Math.max(min, n));
  const onKeyDown = (e: React.KeyboardEvent) => {
    const step = e.shiftKey ? 10 : 2;
    if (e.key === 'ArrowLeft') setSize((s) => clamp(s - step));
    else if (e.key === 'ArrowRight') setSize((s) => clamp(s + step));
    else if (e.key === 'Home') setSize(min);
    else if (e.key === 'End') setSize(max);
    else if (e.key === 'Enter') setSize((s) => { if (s > 0) { prev.current = s; return 0; } return prev.current; });
    else return;
    e.preventDefault();
  };
  const onPointerDown = (e: React.PointerEvent) => {
    const container = (e.currentTarget.parentElement as HTMLElement).getBoundingClientRect();
    e.currentTarget.setPointerCapture(e.pointerId);
    const move = (ev: PointerEvent) => setSize(clamp(((ev.clientX - container.left) / container.width) * 100));
    const up = () => { window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); };
    window.addEventListener('pointermove', move); window.addEventListener('pointerup', up);
  };
  return (
    <div className="split" style={{ gridTemplateColumns: `${size}% 12px 1fr` }}>
      <aside id="sidebar" aria-label="Sidebar" hidden={size === 0}>…</aside>
      <div role="separator" tabIndex={0} aria-orientation="vertical" aria-label="Resize sidebar"
        aria-controls="sidebar" aria-valuenow={Math.round(size)} aria-valuemin={0} aria-valuemax={max}
        onKeyDown={onKeyDown} onPointerDown={onPointerDown} className="splitter" />
      <main>…</main>
    </div>
  );
}
```
```css
.split { display: grid; block-size: 100dvh; }
.splitter { cursor: col-resize; touch-action: none; position: relative; }
.splitter::before { content: ""; position: absolute; inset-block: 0; inset-inline-start: 50%; inline-size: 1px; background: var(--border); }
.splitter:focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
```
For RTL, invert the arrow direction and the pointer math.

## Anti-Patterns
- **Mouse-only drag handle `<div>`**: keyboard users can't resize. Fix: focusable separator with arrow keys.
- **Missing `aria-valuenow`**: screen readers can't convey size. Fix: value attributes.
- **1px hit area**: hard to grab, fails target size. Fix: ≥ 8–12px hit zone with a thin visual line.
- **localStorage layout in SSR apps**: layout jumps after hydration. Fix: cookie read on the server.
- **No minimum sizes**: panes collapse into unusable slivers. Fix: min/max + an explicit collapse state.
- **Iframes eating pointermove during drag**: the drag stalls. Fix: pointer capture + disable iframe pointer events while dragging.
- **Splitters on mobile layouts**: Fix: stacked panes or tabs.

## Accessibility
- WCAG 2.1.1 Keyboard, 4.1.2 Name/Role/Value (separator value), 2.5.7 Dragging Movements (keyboard and collapse buttons provide alternatives, but a single-pointer alternative such as buttons is still needed for pointer users who can't drag), 2.5.8 Target Size, 2.4.7 Focus Visible, 1.4.10 Reflow (stack at narrow widths).

## Responsive Design
- Below a container width (e.g., 48rem), render panes stacked or as tabs; drop splitters.
- Persist separate layouts per breakpoint class if users resize on different screens.
- Use logical properties and mirror the keyboard direction in RTL.

## Performance
- Update sizes with CSS variables/grid templates or flex-basis; avoid re-rendering heavy pane content on each pointermove (libraries batch this).
- Debounce persistence writes (`onLayoutChanged` fires after resize completes in v4).
- Heavy panes (editors, charts) should respond to ResizeObserver with throttling.

## Security
- Validate persisted layout values read from cookies (parse safely, clamp ranges) to avoid crashes from tampered input.

## Testing
- Testing Library: `getByRole('separator', {name:'Resize explorer'})`, `{ArrowRight}` increases `aria-valuenow`, Enter collapses.
- Playwright: pointer drag changes width; reload restores layout without visible jump (screenshot before/after hydration); mobile layout stacks.
- Screen reader: separator announced with value.

## Tooling
- react-resizable-panels (MIT) v4: `Group`, `Panel`, `Separator`; units in %, px, rem, vh; collapsible; `defaultLayout`; `onLayoutChange` (during) vs `onLayoutChanged` (after); `groupResizeBehavior`.
- shadcn/ui Resizable (wrapper).
- Allotment (VS Code-style split views; verify maintenance) as an alternative.

## Framework Notes
- **React (Vite SPA)**: Persist the layout in localStorage and read it before first render (synchronously in state init) to avoid a jump. Keep the pane content out of the resizing component's re-render path (pass as children).
- **Next.js (App Router)**: Panel groups are Client Components (`'use client'`). Read the persisted layout from `cookies()` in a Server Component layout and pass `defaultLayout` to avoid hydration shifts; the library notes slight shifts can happen with percentage defaults during SSR otherwise. Put the split shell in a layout so it persists across route changes. Page content renders in the editor panel as `children`.

## AI Agent Guidance
- DO use react-resizable-panels (v4 API names) or shadcn Resizable; check the installed major version before writing props.
- DO ensure separators have names, values, keyboard support and visible focus; DO set min/max sizes.
- DON'T use localStorage-only persistence in SSR apps; DON'T ship splitters on mobile layouts.
- Verify: arrows resize and announce value; Enter collapses/restores; reload restores layout without a jump; drag works over iframes; stacked layout at narrow widths.

## Examples
Vertical (top/bottom) split for a terminal panel:
```tsx
<Group orientation="vertical">
  <Panel id="editor" minSize="30%"><Editor /></Panel>
  <Separator aria-label="Resize terminal" />
  <Panel id="terminal" defaultSize="30%" minSize="6rem" collapsible><Terminal /></Panel>
</Group>
```

## Related Skills
- [master-detail-layouts](../master-detail-layouts/Skill.md): list + detail splits
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md): collapsible app sidebars
- [developer-tool-ui-patterns](../developer-tool-ui-patterns/Skill.md): IDE-style layouts
- [keyboard-navigation](../keyboard-navigation/Skill.md): keyboard operability
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md): drag alternatives
- [responsive-dashboard-layouts](../responsive-dashboard-layouts/Skill.md): adaptive layouts

## Sources
- [WAI-ARIA APG: Window Splitter Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/) — Official — keyboard, separator role and value attributes
- [react-resizable-panels repository](https://github.com/bvaughn/react-resizable-panels) — Open Source — v4 API renames, units, persistence, SSR note

## License / Usage Notes
Summarized in original wording; code original. react-resizable-panels MIT.

## Quality Tier
B — APG pattern and primary library verified, but exact v4 prop shapes weren't fully confirmed and design-system guidance is thin.

## Status
Active

## Last Verified
2026-09-15
