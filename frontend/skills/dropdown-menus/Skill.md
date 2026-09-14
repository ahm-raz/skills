# Dropdown Menus

## Summary
Action menus opened from a button (menu button), including submenus, checkable items, radio groups, and context (right-click) menus. This skill covers the APG Menu Button and Menu patterns: roles, roving focus, typeahead, and focus return. It also covers what *not* to model as a menu (site navigation, selects), hover-intent submenus, and native vs library options in 2026.

## Category
Components

## Subcategories
Menu button, menu, menuitemcheckbox, menuitemradio, submenu, context menu, menubar, overflow "more" menu

## Problem It Solves
`role="menu"` carries a strong keyboard contract. Screen readers switch into application-style interaction and expect arrow keys, typeahead and Escape. Teams often apply menu roles to navigation link lists (breaking link semantics), build dropdowns where arrow keys don't work, lose focus on close, or make submenus that collapse when the pointer moves diagonally.

## When To Use
- A button reveals a list of **actions** or commands: "More actions", row actions, user account menu actions, editor toolbar menus.
- Toggling options within a menu (menuitemcheckbox "Show grid") or picking one of a set (menuitemradio "Sort by").
- Context menus on right-click / long-press / Shift+F10 in app-like UIs.
- Desktop-app-style menubars (File/Edit/View) in web apps such as editors.

## When Not To Use
- Site/app navigation links: use disclosure navigation (navigation-menus-and-sidebars).
- Choosing a form value: use `<select>`, listbox or combobox.
- Content with inputs, headings or rich layouts: use a popover/dialog.
- A single primary action: use a button. Only 1–2 actions: show them inline.

## Core Principles
1. Menu items are actions; activation performs the action and (usually) closes the menu.
2. Only one tab stop: the trigger. Inside the menu, arrow keys move focus (roving tabindex or `aria-activedescendant`).
3. Escape closes and returns focus to the trigger; Tab closes the menu and moves on.
4. Every item has a clear text label; icons are decorative additions.
5. Destructive items are visually and semantically distinct and often confirmed.

## Best Practices
- Label triggers by purpose ("Actions for invoice 1042"), not a bare "⋯". Icon-only triggers need `aria-label`.
- Group related items with `role="group"` + label or separators; put destructive items last.
- Show keyboard shortcuts as visual hints (`aria-keyshortcuts` optional).
- Disabled items: keep them focusable with `aria-disabled="true"` so users discover them (APG allows focusing disabled items). Explain why elsewhere if needed.
- Submenus: open on Right Arrow/Enter/hover with intent; use a "safe triangle" so diagonal pointer movement doesn't close them.
- Avoid deep nesting (max 1 submenu level in most product UI).
- Context menus must have a visible alternative (row "⋯" button). Right-click-only features are undiscoverable and inaccessible on touch.

## Implementation Guidance

### Keyboard (APG Menu Button + Menu)
| Context | Key | Behavior |
|---|---|---|
| Trigger | Enter / Space | Open, focus first item |
| Trigger | Down Arrow (optional) | Open, focus first item |
| Trigger | Up Arrow (optional) | Open, focus last item |
| Menu | Down / Up Arrow | Next / previous item (optionally wraps) |
| Menu | Home / End | First / last item |
| Menu | Printable character | Typeahead to next item starting with that character |
| Menu | Enter | Activate item and close (or open submenu) |
| Menu | Space | Toggle menuitemcheckbox / check menuitemradio (may keep menu open) |
| Menu | Right Arrow | Open submenu, focus its first item |
| Submenu | Left Arrow / Escape | Close submenu, focus parent item |
| Menu | Escape | Close, return focus to trigger |
| Menu | Tab / Shift+Tab | Close all menus, move focus out |
| Element | Shift+F10 / Menu key | Open context menu (context menus) |

### Roles and attributes
| Element | Role / attributes |
|---|---|
| Trigger | `<button aria-haspopup="menu" aria-expanded="true|false" aria-controls="menuId">` |
| Menu | `role="menu"`, `aria-labelledby` → trigger |
| Item | `role="menuitem"`; `tabindex="-1"` (roving) |
| Checkable | `role="menuitemcheckbox" aria-checked="true|false"` |
| Radio | `role="menuitemradio" aria-checked`, wrapped in `role="group"` with label |
| Submenu parent | `role="menuitem" aria-haspopup="menu" aria-expanded` |
| Separator | `role="separator"` |
| Disabled | `aria-disabled="true"` |

Children of menu items are presentational. Don't nest links/buttons inside `menuitem`; the item *is* the control.

### Native vs library decision table
| Need | Choose | Notes |
|---|---|---|
| Simple action menu, any framework | `<button popovertarget>` + `<div popover role="menu">` + ~60 lines JS for arrows/typeahead | Popover gives top layer, light dismiss, Escape, focus return; you still write roving focus |
| React product UI with submenus, checkable items, typeahead, collision-aware positioning | Radix DropdownMenu / ContextMenu / Menubar; Base UI Menu / ContextMenu / Menubar; React Aria `MenuTrigger`/`Menu`/`SubmenuTrigger`; Ariakit Menu; Headless UI Menu | Pick the one your design system already uses |
| Menubar (app chrome) | Radix/Base UI Menubar, React Aria (compose) | Rarely needed on websites |
| Customizable `<select>` for value choice | See select-and-combobox | Not a menu |

## Recommended Workflow
1. Confirm the content is a set of actions (not navigation or values).
2. Inventory items; group, order by frequency, destructive last; write labels.
3. Choose primitive (project DS first).
4. Implement trigger wiring (`aria-haspopup`, `aria-expanded`).
5. Implement roving focus, typeahead, Escape/Tab behavior, submenus with hover intent.
6. Add confirmation for destructive actions and visible alternatives for context menus.
7. Test with keyboard, screen readers (NVDA browse/focus mode switch, VoiceOver), touch.

## Patterns

### Minimal native-popover menu with roving focus (React, no library)
```tsx
'use client';
import { useId, useRef } from 'react';

type Item = { id: string; label: string; danger?: boolean; onSelect: () => void };

export function ActionsMenu({ label, items }: { label: string; items: Item[] }) {
  const id = useId();
  const menuRef = useRef<HTMLDivElement>(null);
  const list = () => [...(menuRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? [])];

  const onKeyDown = (e: React.KeyboardEvent) => {
    const els = list(); const i = els.indexOf(document.activeElement as HTMLElement);
    const move = (n: number) => { e.preventDefault(); els[(n + els.length) % els.length]?.focus(); };
    if (e.key === 'ArrowDown') move(i + 1);
    else if (e.key === 'ArrowUp') move(i - 1);
    else if (e.key === 'Home') move(0);
    else if (e.key === 'End') move(els.length - 1);
    else if (e.key === 'Tab') menuRef.current?.hidePopover();
    else if (e.key.length === 1 && /\S/.test(e.key)) {
      const k = e.key.toLowerCase();
      [...els.slice(i + 1), ...els.slice(0, i + 1)].find(el => el.textContent?.trim().toLowerCase().startsWith(k))?.focus();
    }
  };

  return (
    <>
      <button id={`${id}-btn`} type="button" popoverTarget={`${id}-menu`} aria-haspopup="menu">{label}</button>
      <div
        id={`${id}-menu`} ref={menuRef} popover="auto" role="menu" aria-labelledby={`${id}-btn`}
        onKeyDown={onKeyDown}
        onToggle={(e) => { if ((e.nativeEvent as ToggleEvent).newState === 'open') list()[0]?.focus(); }}
      >
        {items.map((it) => (
          <button key={it.id} type="button" role="menuitem" tabIndex={-1} data-danger={it.danger || undefined}
            onClick={() => { menuRef.current?.hidePopover(); it.onSelect(); }}>
            {it.label}
          </button>
        ))}
      </div>
    </>
  );
}
```
Native invokers set `aria-expanded` and return focus on Escape. Using `<button role="menuitem">` keeps Enter/Space activation for free. If your React version doesn't expose `onToggle` for popovers, attach a native `toggle` listener in an effect. For submenus, checkable items and collision handling, use a library.

### Radix DropdownMenu with radio group
```tsx
<DropdownMenu.Root>
  <DropdownMenu.Trigger aria-label="View options">⋯</DropdownMenu.Trigger>
  <DropdownMenu.Portal>
    <DropdownMenu.Content sideOffset={4} align="end">
      <DropdownMenu.CheckboxItem checked={grid} onCheckedChange={setGrid}>Show grid</DropdownMenu.CheckboxItem>
      <DropdownMenu.Separator />
      <DropdownMenu.Label>Sort by</DropdownMenu.Label>
      <DropdownMenu.RadioGroup value={sort} onValueChange={setSort}>
        <DropdownMenu.RadioItem value="name">Name</DropdownMenu.RadioItem>
        <DropdownMenu.RadioItem value="date">Date</DropdownMenu.RadioItem>
      </DropdownMenu.RadioGroup>
    </DropdownMenu.Content>
  </DropdownMenu.Portal>
</DropdownMenu.Root>
```

### Context menu with visible alternative
Right-click on a row opens a ContextMenu; the same items are available from a row "⋯" menu button. Share one item definition array between both.

### Hover-intent submenu
Use a safe polygon (Floating UI `safePolygon`, or built into Radix/Base UI/React Aria) and a small close delay (~100–150ms). Never open submenus on hover alone for touch.

## Anti-Patterns
- **`role="menu"` for header nav links**: screen readers enter app mode and link lists aren't announced as links. Fix: `<nav>` + disclosure buttons + lists of links.
- **Menu items containing `<a>` inside `role="menuitem"` div**: nested interactive. Fix: make the `<a role="menuitem">` itself the item (navigation-like actions are OK when truly in an action menu).
- **Every item in tab order**: many tab stops. Fix: roving tabindex.
- **Menu closes and focus goes to `<body>`**: Fix: return to trigger (or to the result of the action, e.g., rename input).
- **Destructive item next to benign one with no confirmation or undo**: Fix: separator + confirm dialog or undo toast.
- **Right-click-only actions**: Fix: visible menu button; Shift+F10 support.
- **Using a dropdown menu as a form select**: value isn't announced as a field. Fix: select/combobox.
- **Hover-opening top-level dropdowns** on click-based UIs: accidental opens. Fix: click to open; hover only for submenus with intent.

## Accessibility
- WCAG 2.1.1 Keyboard, 2.4.3 Focus Order, 2.4.7 Focus Visible, 4.1.2 Name/Role/Value, 1.4.13 for hover-opened submenus, 2.5.8 Target Size (items ≥ 24px, aim 32–44px on touch).
- Checkable items must expose `aria-checked`; visual check icons alone are insufficient.
- Announce outcomes of actions (e.g., "Duplicated") via live region where there's no visible change.

## Responsive Design
- On small screens, long menus can become bottom sheets (action sheet) with the same items. Keep semantics as menu or a list of buttons in a dialog.
- Constrain height with scroll; keep the selected radio visible.
- Place menus with collision fallbacks; align end for right-aligned "⋯" triggers (logical alignment for RTL).

## Performance
- Render menu content lazily on open (libraries do this).
- In large tables, use one shared menu instance positioned at the active row trigger instead of N mounted menus.

## Security
- Hide actions users can't perform *and* enforce on the server; hiding alone isn't authorization.
- Confirm destructive or irreversible actions; avoid dark patterns (e.g., placing "Delete" where "Edit" usually is).

## Testing
- Testing Library: `getByRole('button', {name:/actions/i})` → click → `getByRole('menu')` → `getAllByRole('menuitem')`; `userEvent.keyboard('{ArrowDown}{Enter}')`; assert focus returns to trigger after Escape.
- Playwright: typeahead, submenu Right/Left arrows, Tab closes menu, context menu via `click({ button: 'right' })` and `Shift+F10`.
- Screen readers: NVDA + Firefox/Chrome, JAWS, VoiceOver. Check item count/position announcements.
- axe: `aria-required-children`, `aria-required-parent`.

## Tooling
- shadcn/ui DropdownMenu/ContextMenu/Menubar (default in shadcn projects); Radix DropdownMenu/ContextMenu/Menubar (MIT, stable); Base UI Menu/ContextMenu/Menubar (v1.x stable; Menu transition support added 2026); React Aria Components Menu/SubmenuTrigger (Apache-2.0); Ariakit Menu; Headless UI Menu.
- Floating UI React for custom menus (`useListNavigation`, `useTypeahead`, `FloatingTree` for submenus).

## Framework Notes
- **React (Vite SPA)**: Use the DS primitive (shadcn/ui DropdownMenu/ContextMenu on Radix or Base UI). Custom item components must accept `ref` and spread props so roving focus and `asChild`/`render` work. Keep a single item-definition array shared by the "⋯" menu and the context menu. Menu items that navigate can render React Router `<Link>` via `asChild`.
- **Next.js (App Router)**: Menus are Client Components (`'use client'`). Keep them as small leaves inside Server Component rows. Navigation items render `next/link` via `asChild`. Library menus close on selection, but also close on route change if the trigger persists. For mutations, call a Server Action from `onSelect`, then show a toast or revalidate. Mark the item busy with `useTransition` instead of leaving the menu open. Radix menu content portals after hydration; don't conditionally render triggers differently on server and client.

## AI Agent Guidance
- DO classify: actions → menu; links → nav disclosure; values → select/combobox.
- DO implement or verify arrow keys, Home/End, typeahead, Escape focus return, Tab closes.
- DON'T put `role="menu"` on navigation or on containers holding inputs.
- DON'T ship context-menu-only actions.
- Verify: single tab stop; `aria-expanded` toggles; checkable items expose `aria-checked`; destructive action confirmation/undo; submenu survives diagonal pointer movement; test passes in WebKit.

## Examples
React Aria Components menu with submenu:
```tsx
<MenuTrigger>
  <Button aria-label="File actions">⋯</Button>
  <Popover>
    <Menu onAction={(key) => run(key)}>
      <MenuItem id="open">Open</MenuItem>
      <SubmenuTrigger>
        <MenuItem>Share</MenuItem>
        <Popover><Menu onAction={share}><MenuItem id="link">Copy link</MenuItem><MenuItem id="email">Email</MenuItem></Menu></Popover>
      </SubmenuTrigger>
      <Separator />
      <MenuItem id="delete" className="danger">Delete…</MenuItem>
    </Menu>
  </Popover>
</MenuTrigger>
```

## Related Skills
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md): why nav isn't a menu
- [select-and-combobox](../select-and-combobox/Skill.md): value selection
- [popovers](../popovers/Skill.md): top-layer behavior
- [floating-element-positioning](../floating-element-positioning/Skill.md): placement, submenus
- [command-palette](../command-palette/Skill.md): searchable command lists
- [keyboard-navigation](../keyboard-navigation/Skill.md): roving tabindex
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md): delete items
- [bulk-actions](../bulk-actions/Skill.md): row action menus in tables

## Sources
- [WAI-ARIA APG: Menu Button](https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/) — Official — trigger keyboard/ARIA
- [WAI-ARIA APG: Menu and Menubar](https://www.w3.org/WAI/ARIA/apg/patterns/menubar/) — Official — full keyboard, roles, focus approaches
- [WAI-ARIA APG: Disclosure Navigation example](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/) — Official — why not menu for nav
- [MDN: Popover API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using) — Official — native behavior
- [Floating UI useHover/safePolygon](https://floating-ui.com/docs/useHover) — Open Source — submenu hover intent
- [Base UI Releases](https://base-ui.com/react/overview/releases) — Open Source — Menu/ContextMenu/Menubar status

## License / Usage Notes
Summarized in original wording; code original. Libraries MIT/Apache-2.0.

## Quality Tier
A — APG-grounded with native and library paths; screen reader behavior summarized, not freshly tested.

## Status
Active

## Last Verified
2026-09-15
