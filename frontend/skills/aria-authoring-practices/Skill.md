# ARIA Authoring Practices

## Summary
How to use WAI-ARIA correctly in React/Next.js when native HTML cannot express a widget, following the W3C ARIA Authoring Practices Guide (APG). Covers the rules of ARIA use, roles/states/properties, accessible name computation, the keyboard contracts of common APG patterns, and when to delegate to APG-conformant libraries (React Aria, Radix, Base UI). ARIA 1.2 is the current Recommendation; ARIA 1.3 is a Working Draft heading toward CR.

## Category
Accessibility

## Subcategories
WAI-ARIA 1.2, ARIA 1.3, APG patterns, accessible name computation, roles, states and properties, composite widgets, roving tabindex, aria-activedescendant

## Problem It Solves
ARIA is powerful and easy to misuse. WebAIM Million 2026: pages with ARIA averaged 59.1 detected errors versus 42 without, and ARIA attribute use grew 27% in a year. Wrong roles and missing keyboard support produce widgets that announce as one thing and behave as another.

## When To Use
- Building a custom composite widget with no native equivalent: tabs, tree, combobox, menu button, listbox, grid, toolbar.
- Exposing a state HTML lacks: `aria-expanded`, `aria-pressed`, `aria-current`, `aria-selected`.
- Reviewing headless library output or hand-rolled components.
- Fixing 4.1.2 Name, Role, Value failures.

## When Not To Use
- When a native element exists: `button`, `a`/`<Link>`, `input type=checkbox`, `select`, `details`, `dialog`, `[popover]`, `input type=range`.
- For site navigation. Don't use `role="menu"`/`menubar` for nav links.
- To fix visual issues. ARIA changes neither visuals nor behaviour.
- As production-ready code copied blindly. APG examples are demonstrations, not fully tested across every AT.

## Core Principles
1. **Native first.** If an HTML element provides the semantics and behaviour, use it.
2. **Don't override native semantics** (no `<h2 role="tab">`).
3. **Every interactive ARIA control must be keyboard operable** per its pattern.
4. **Never put `role="presentation"` or `aria-hidden="true"` on focusable elements.**
5. **Every interactive element needs an accessible name.**
6. **No ARIA is better than bad ARIA.** A role promises behaviour.
7. **States must stay in sync** with component state.

## Best Practices
- Prefer visible text for names. Precedence is `aria-labelledby` > `aria-label` > native label/content > `title`.
- Use `aria-describedby` for hints and errors, not names.
- Choose roving tabindex or `aria-activedescendant` per widget, not both.
- Don't `aria-label` generic `div`/`span`. ARIA 1.2 prohibits naming `generic`, and AT often ignores it.
- `role="application"` is almost never right.
- For complex widgets (combobox, date picker, grid, tree), prefer React Aria Components, Radix, Base UI or Ariakit over hand-rolling. Still verify with AT.
- Check W3C ARIA-AT results and practitioner notes (Scott O'Hara, Adrian Roselli, Sarah Higley) before relying on newer attributes.

## Implementation Guidance

### Decision table
| Need | Use |
|---|---|
| Action | `<button type="button">` |
| Navigation | `next/link` `<Link>` / `<a href>` |
| Show/hide | `<details>` or `<button aria-expanded aria-controls>` |
| Modal | `<dialog>` + `showModal()`, or Radix/React Aria Dialog |
| Non-modal floating panel | `[popover]`, or Radix Popover |
| Toggle button | `<button aria-pressed>` |
| On/off setting | `<input type="checkbox" role="switch">` |
| Tabs | APG Tabs (React Aria `Tabs`, Radix `Tabs`) |
| Editable autocomplete | APG Combobox (React Aria `ComboBox`, Ariakit, Base UI) |
| Action menu | APG Menu Button (Radix `DropdownMenu`, React Aria `Menu`) |
| Hierarchy | APG Tree View (React Aria `Tree`) |
| 2-D interactive grid | APG Grid; static data uses `<table>` |

### Keyboard contracts (APG)
| Pattern | Keys |
|---|---|
| Tabs | Tab into the active tab; Left/Right (Up/Down if vertical); Home/End; Enter/Space if manual activation |
| Menu button / menu | Enter/Space/Down opens and focuses the first item; Up focuses the last; arrows move; Esc closes and returns focus; type-ahead; Tab closes |
| Combobox | Down opens/moves; Up moves; Enter accepts; Esc closes (then clears); Alt+Down opens |
| Listbox | Up/Down; Home/End; Space toggles (multi); Shift+arrows extend |
| Tree | Up/Down; Right expands or goes to the child; Left collapses or goes to the parent; Home/End; `*` expands siblings |
| Radio group | Tab to the checked radio; arrows move and select |
| Toolbar | Tab in; Left/Right; Home/End |
| Grid | Arrows by cell; Home/End row; Ctrl+Home/End; PageUp/PageDown |
| Slider | Arrows ±step; Home/End; PageUp/PageDown |
| Dialog | Tab cycles inside; Esc closes; focus returns to the invoker |

### Accessible name computation (simplified)
1. `aria-labelledby` (concatenates referenced text, even hidden).
2. `aria-label`.
3. Native: `<label>`, `alt`, `<caption>`, `<legend>`.
4. Subtree text for name-from-content roles (button, link, tab, menuitem, heading).
5. `title`/`placeholder` as a last resort only.

### Standards status
- **ARIA 1.2**: W3C Recommendation (2023).
- **ARIA 1.3**: Working Draft; adds `aria-description`, `suggestion`/`comment`/`mark` roles and braille label attributes; CR targeted late 2026. Treat as enhancement.
- **HTML-AAM**: defines native-to-accessibility-API mappings; consult it when native and ARIA conflict.
- **axe-core 4.12+**: adds an `aria-tab-name` rule and Element Internals support.

## Recommended Workflow
1. Confirm no native element fits.
2. Check whether the design system's headless library already implements the APG pattern. Use it.
3. If hand-rolling, read the APG pattern's "Keyboard Interaction" and "Roles, States, Properties".
4. Write JSX with roles and relationships (ids via `useId()`).
5. Implement keyboard handling and focus exactly per the contract.
6. Derive every `aria-*` state from React state (single source of truth).
7. Test:
   - DevTools Accessibility tree
   - keyboard
   - NVDA+Chrome and VoiceOver+Safari
   - Testing Library `getByRole` assertions
   - axe

## Patterns
**Disclosure**
```tsx
function Disclosure({ title, children }: { title: string; children: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const id = useId();
  return (
    <>
      <button type="button" aria-expanded={open} aria-controls={id} onClick={() => setOpen(o => !o)}>
        {title}
      </button>
      <div id={id} hidden={!open}>{children}</div>
    </>
  );
}
```

**Toggle button**
```tsx
<button type="button" aria-pressed={muted} onClick={() => setMuted(m => !m)}>Mute</button>
```

**Tabs with roving tabindex**
```tsx
function Tabs({ tabs }: { tabs: { label: string; content: React.ReactNode }[] }) {
  const [active, setActive] = useState(0);
  const base = useId();
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const move = (i: number) => { const n = (i + tabs.length) % tabs.length; setActive(n); refs.current[n]?.focus(); };

  return (
    <>
      <div role="tablist" aria-label="Account" onKeyDown={e => {
        if (e.key === 'ArrowRight') move(active + 1);
        if (e.key === 'ArrowLeft') move(active - 1);
        if (e.key === 'Home') move(0);
        if (e.key === 'End') move(tabs.length - 1);
      }}>
        {tabs.map((t, i) => (
          <button key={t.label} role="tab" ref={el => { refs.current[i] = el; }}
            id={`${base}-tab-${i}`} aria-controls={`${base}-panel-${i}`}
            aria-selected={i === active} tabIndex={i === active ? 0 : -1}
            onClick={() => setActive(i)}>{t.label}</button>
        ))}
      </div>
      {tabs.map((t, i) => (
        <div key={t.label} role="tabpanel" id={`${base}-panel-${i}`}
          aria-labelledby={`${base}-tab-${i}`} hidden={i !== active} tabIndex={0}>{t.content}</div>
      ))}
    </>
  );
}
```

**Delegate to a library (React Aria Components)**
```tsx
import { Tabs, TabList, Tab, TabPanel } from 'react-aria-components';

<Tabs>
  <TabList aria-label="Account"><Tab id="profile">Profile</Tab><Tab id="billing">Billing</Tab></TabList>
  <TabPanel id="profile">…</TabPanel><TabPanel id="billing">…</TabPanel>
</Tabs>
```

## Anti-Patterns
- **`<div role="button" onClick>` without `tabIndex` or Enter/Space.** Not operable. Use `<button>`.
- **`role="menu"` for site nav.** Wrong interaction model. Use `<nav>` + lists + disclosure buttons.
- **`aria-label` different from the visible text.** Fails 2.5.3 and breaks voice control. Start the name with the visible label.
- **`aria-hidden` on a subtree with focusables.** Creates ghost focus. Use `inert`.
- **Redundant roles** (`<button role="button">`). Remove them.
- **`aria-selected` without panel or focus updates.** State lies. Derive it from state.
- **Conditionally mounting an `aria-live` region together with its message.** Nothing is announced. Keep the region mounted and change its text.
- **Passing `aria-expanded={undefined}` when closed.** The attribute disappears and AT loses the "collapsed" state. Always pass a boolean.

## Accessibility
- 4.1.2 Name, Role, Value; 1.3.1; 2.1.1; 2.4.3; 2.5.3 Label in Name; 4.1.3 Status Messages.
- With `aria-activedescendant`, DOM focus stays on the input. Style the active option visibly (2.4.7).

## Responsive Design
- Patterns that transform at breakpoints (tabs to accordion) must re-render with the correct roles, not only change CSS.
- Touch screen-reader users can't press arrow keys. Every item must be reachable by swipe and activatable by double-tap.

## Performance
- Virtualized listboxes and grids: use `aria-activedescendant` and set `aria-setsize`/`aria-posinset` or `aria-rowcount`/`aria-rowindex`.
- Avoid re-keying the whole widget on each keystroke (AT loses position). Keep stable `key`s.

## Security
- Never build `aria-label` from unsanitised HTML. JSX attribute binding escapes values; avoid `dangerouslySetInnerHTML` for labels.

## Testing
- DevTools: the Chrome full accessibility tree and Firefox Accessibility Inspector show the computed role, name and states.
- Testing Library:
  - `getByRole('tab', { name: 'Billing', selected: true })`
  - `user.keyboard('{ArrowRight}')` to test the contract
- axe rules: `aria-allowed-attr`, `aria-required-children`, `aria-required-parent`, `aria-valid-attr-value`, `aria-command-name`, `aria-tab-name`, `nested-interactive`.
- Screen readers: NVDA Insert+Tab and VoiceOver VO+F3 read the focused control's name, role and state.

## Tooling
- React Aria / React Aria Components (Adobe; strongest APG and AT test coverage), Radix Primitives, Base UI, Ariakit, Headless UI.
- eslint-plugin-jsx-a11y: `role-has-required-aria-props`, `aria-proptypes`, `no-noninteractive-element-to-interactive-role`, `interactive-supports-focus`.
- W3C ARIA-AT (AT interoperability reports for APG patterns); a11ysupport.io (community tables, sometimes stale).

## Framework Notes
- **React (Vite SPA and Next.js).**
  - JSX `aria-*` attributes stay kebab-case; boolean values serialise to "true"/"false".
  - `useId()` gives SSR-safe ids for relationships.
  - React 19 accepts `inert` as a boolean.
  - `role` and `aria-*` pass through to DOM elements; for custom components, spread them to the underlying element.
- **Next.js.**
  - Interactive ARIA widgets need `'use client'`. Keep the static structure in Server Components and isolate the interactive island.
  - Ensure SSR markup already contains the correct roles and states, so AT users aren't confused before hydration.
  - `<Link>` renders `<a href>`; don't add `role="button"` to it.
- **Radix.** Dialog logs a console warning if `Dialog.Title` is missing. Use `VisuallyHidden` to hide it visually, not by removing it.
- **React Aria.** Hooks (`useButton`, `useComboBox`) or Components. Handles press events across pointer, touch and keyboard, and virtual cursor quirks.

## AI Agent Guidance
- Do: use native elements or the project's headless library first. Justify any hand-written `role`.
- Do: implement and test the full APG keyboard table for any composite widget you create.
- Do: derive `aria-*` from state, and pass explicit booleans.
- Don't: generate `role="menu"` for navigation, `role="button"` on divs, `aria-label` on divs, `tabIndex > 0`.
- Don't: copy APG examples verbatim without adapting and testing.
- Verify before done:
  - accessibility tree shows the correct role, name and state
  - keyboard contract passes
  - `getByRole` tests pass
  - axe clean
  - one screen reader smoke test

## Examples
```tsx
'use client';
// Menu button – abbreviated hand-rolled version (prefer Radix DropdownMenu / React Aria Menu in production)
import { useId, useRef, useState } from 'react';

export function ActionsMenu({ items }: { items: { label: string; onSelect: () => void }[] }) {
  const [open, setOpen] = useState(false);
  const btnId = useId(); const menuId = useId();
  const btn = useRef<HTMLButtonElement>(null);
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const focusAt = (i: number) => refs.current.at(i)?.focus();
  const close = () => { setOpen(false); btn.current?.focus(); };

  return (
    <div>
      <button ref={btn} id={btnId} aria-haspopup="menu" aria-expanded={open} aria-controls={menuId}
        onClick={() => { setOpen(true); requestAnimationFrame(() => focusAt(0)); }}
        onKeyDown={e => { if (e.key === 'ArrowUp') { e.preventDefault(); setOpen(true); requestAnimationFrame(() => focusAt(-1)); } }}>
        Actions
      </button>
      {open && (
        <ul role="menu" id={menuId} aria-labelledby={btnId} onKeyDown={e => {
          const i = refs.current.indexOf(document.activeElement as HTMLButtonElement);
          if (e.key === 'ArrowDown') { e.preventDefault(); focusAt((i + 1) % items.length); }
          if (e.key === 'ArrowUp') { e.preventDefault(); focusAt(i - 1); }
          if (e.key === 'Home') focusAt(0);
          if (e.key === 'End') focusAt(-1);
          if (e.key === 'Escape') close();
          if (e.key === 'Tab') setOpen(false);
        }}>
          {items.map((it, i) => (
            <li role="none" key={it.label}>
              <button role="menuitem" tabIndex={-1} ref={el => { refs.current[i] = el; }}
                onClick={() => { it.onSelect(); close(); }}>{it.label}</button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

## Related Skills
- [semantic-html](../semantic-html/Skill.md) — the native-first alternative
- [keyboard-navigation](../keyboard-navigation/Skill.md) — roving tabindex and key handling
- [focus-management](../focus-management/Skill.md) — focus on open/close
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — `aria-live`, `ariaNotify`
- [select-and-combobox](../select-and-combobox/Skill.md) — combobox implementation
- [tabs](../tabs/Skill.md) — tabs component
- [dropdown-menus](../dropdown-menus/Skill.md) — menu button component
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md) — APG-conformant hooks and components
- [radix-ui-primitives](../radix-ui-primitives/Skill.md) — accessible primitives

## Sources
- [ARIA Authoring Practices Guide – Patterns](https://www.w3.org/WAI/ARIA/apg/patterns/) — Official — pattern list, keyboard contracts
- [WAI-ARIA 1.2](https://www.w3.org/TR/wai-aria-1.2/) — Official — roles and states
- [WAI-ARIA 1.3 Editor's Draft](https://w3c.github.io/aria/) — Official (draft) — new roles and attributes
- [HTML-AAM](https://www.w3.org/TR/html-aam-1.0/) — Official — native mappings
- [Accessible Name and Description Computation 1.2](https://www.w3.org/TR/accname-1.2/) — Official — name precedence
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — ARIA/error correlation
- [axe-core releases](https://github.com/dequelabs/axe-core/releases) — Open Source — `aria-tab-name`, Element Internals
- [React Aria](https://react-spectrum.adobe.com/react-aria/) — Open Source — APG-conformant React implementations

## License / Usage Notes
W3C specs are under the W3C Document License; APG code is under the W3C Software License. React Aria is Apache-2.0 and Radix is MIT. Examples are original.

## Quality Tier
S — authoritative W3C sources, current spec status, React-specific implementation guidance.

## Status
Active

## Last Verified
2026-09-15
