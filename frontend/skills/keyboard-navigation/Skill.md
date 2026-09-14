# Keyboard Navigation

## Summary
Making every feature of a React/Next.js UI operable with a keyboard alone, in a logical order, with visible focus and no traps. Covers tab order, `tabIndex`, standard key conventions, roving tabindex vs `aria-activedescendant`, skip links, shortcuts (2.1.4), and the platform features coming next (`focusgroup`, `reading-flow`).

## Category
Accessibility

## Subcategories
Tab order, tabindex, roving tabindex, aria-activedescendant, keyboard shortcuts, skip links, focus visible, keyboard traps, focusgroup

## Problem It Solves
Keyboard users include screen reader users, switch and voice-control users, people with tremors or RSI, and power users. Custom clickable divs, hover-only menus, focus rings removed by CSS resets and drag-only interactions lock them out, failing 2.1.1, 2.1.2, 2.4.3 and 2.4.7.

## When To Use
- Any interactive component or page.
- Building composite widgets (menus, tabs, grids, listboxes, toolbars).
- Adding keyboard shortcuts or a command palette.
- Reviewing Tailwind/CSS resets that touch `outline`.

## When Not To Use
- Don't add `tabIndex={0}` to non-interactive content (paragraphs, headings, cards) "for screen readers". Screen readers have their own reading cursor; extra tab stops slow keyboard users down.
- Don't hijack arrow keys on regular pages. Arrow keys belong to scrolling and screen reader browse mode outside composite widgets.

## Core Principles
1. **Everything actionable by pointer is actionable by keyboard** (2.1.1).
2. **Focus can always move away** (2.1.2). Modal traps are allowed only while the modal is open and closable by Esc.
3. **Tab order follows reading order** (2.4.3). Fix the DOM, not `tabIndex`.
4. **Focus is always visible** (2.4.7) and not hidden by sticky UI (2.4.11).
5. **One Tab stop per composite widget.** Arrow keys move inside it.
6. **Follow platform conventions** (APG key tables). Surprise costs users more than novelty helps.
7. **Single-character shortcuts must be remappable, disableable, or active only on focus** (2.1.4).

## Best Practices
- `tabIndex` values:
  - `0` makes a custom control focusable in DOM order
  - `-1` makes something programmatically focusable (headings, `main`, dialog containers, roving items)
  - never use a positive value
- Handle `onKeyDown`, not `onKeyPress` (deprecated). Check `e.key` values ('Enter', ' ', 'ArrowDown', 'Escape').
- For custom button-like controls, Enter activates on keydown and Space activates on keyup. Simply use `<button>`.
- Hover-revealed actions (row actions, card menus) must also appear on `:focus-within`.
- Use `:focus-visible` for rings, so mouse clicks don't show rings but keyboard focus does.
- Provide a skip link as the first focusable element.
- Disabled buttons are unfocusable, so users can't discover why. Consider `aria-disabled="true"` plus a guard in the click handler for important actions.
- Ensure focus never lands on hidden or off-screen content: closed drawers get `inert` or `hidden`.
- Don't block paste, and don't capture Tab inside textareas without an escape (e.g., code editors should document Esc then Tab).

## Implementation Guidance

### Standard keys
| Key | Expected behaviour |
|---|---|
| Tab / Shift+Tab | Next/previous focusable control or widget |
| Enter | Activate link/button, submit form |
| Space | Activate button, toggle checkbox, page scroll outside controls |
| Arrow keys | Move within radio groups, selects, menus, tabs, listboxes, sliders, grids |
| Home / End | First/last item in a widget |
| Esc | Close dialog, popover, menu, tooltip; cancel |
| Page Up/Down | Large steps in sliders and grids; scroll |
| Type-ahead | Jump to item starting with a character (menus, listboxes, trees) |

### Roving tabindex vs aria-activedescendant
| | Roving tabindex | aria-activedescendant |
|---|---|---|
| DOM focus | Moves to each item | Stays on the container or input |
| Best for | Toolbars, tabs, radio-like groups, menus, trees | Comboboxes (focus must stay in the input), large virtualized lists |
| Scrolling into view | Automatic with `.focus()` | Manual `scrollIntoView({ block: 'nearest' })` |
| Focus styling | `:focus-visible` | Style `[aria-selected]`/active class yourself |

### Roving tabindex hook
```tsx
import { useRef, useState, type KeyboardEvent } from 'react';

export function useRovingTabIndex(count: number, { orientation = 'horizontal', loop = true } = {}) {
  const [active, setActive] = useState(0);
  const refs = useRef<(HTMLElement | null)[]>([]);
  const next = orientation === 'horizontal' ? 'ArrowRight' : 'ArrowDown';
  const prev = orientation === 'horizontal' ? 'ArrowLeft' : 'ArrowUp';

  const focus = (i: number) => {
    const n = loop ? (i + count) % count : Math.max(0, Math.min(count - 1, i));
    setActive(n);
    refs.current[n]?.focus();
  };

  const onKeyDown = (e: KeyboardEvent) => {
    const map: Record<string, () => void> = {
      [next]: () => focus(active + 1),
      [prev]: () => focus(active - 1),
      Home: () => focus(0),
      End: () => focus(count - 1),
    };
    if (map[e.key]) { e.preventDefault(); map[e.key](); }
  };

  const getItemProps = (i: number) => ({
    ref: (el: HTMLElement | null) => { refs.current[i] = el; },
    tabIndex: i === active ? 0 : -1,
    onFocus: () => setActive(i),
  });

  return { onKeyDown, getItemProps };
}
```

### Shortcuts (2.1.4 Character Key Shortcuts)
- Prefer modifier-based shortcuts (Ctrl/Cmd+K). If you use single keys (`?`, `/`, `j`/`k`), provide a setting to turn them off or remap them, or only activate them when the relevant component has focus.
- Ignore shortcuts when focus is in `input`, `textarea`, `select` or `[contenteditable]`.
- Expose shortcuts via `aria-keyshortcuts` on the control and in visible help.

### Upcoming platform features (don't depend on them yet)
- **`focusgroup` attribute** (Open UI/WHATWG proposal): declarative arrow-key navigation and memory for toolbars, tablists and menus. In development in Chromium, with no shipping cross-browser implementation as of Sept 2026.
- **CSS `reading-flow` / `reading-order`**: make focus and reading order follow flex/grid visual order. Experimental, limited availability.

## Recommended Workflow
1. Unplug the mouse (or ignore the trackpad).
2. Start from the address bar, then Tab. The first stop should be the skip link.
3. Walk the whole page: note unreachable controls, invisible focus, illogical order, and focus landing in hidden content.
4. Operate every widget with its APG keys; open and close overlays and confirm focus returns.
5. Test at 400% zoom: focus stays visible and isn't covered by sticky headers.
6. Automate regressions with Playwright `page.keyboard.press('Tab')` plus `expect(locator).toBeFocused()`.

## Patterns
- **Skip link.** First element in `<body>`; visually hidden until focused; targets `<main id="main" tabIndex={-1}>`.
- **Focus-within reveal.** `.row-actions { opacity: 0 } .row:hover .row-actions, .row:focus-within .row-actions { opacity: 1 }`.
- **Escape stack.** Only the topmost overlay handles Esc (`e.stopPropagation()` in nested popovers), or rely on native `dialog`/`popover`, which handle stacking.
- **Keyboard-accessible drag-and-drop.** dnd-kit's `KeyboardSensor` plus announcements, or explicit "Move up/down" buttons (also satisfies 2.5.7).

## Anti-Patterns
- **`*:focus { outline: none }` or Tailwind `outline-none` without `focus-visible:ring`.** Invisible focus (2.4.7). Always replace it.
- **Positive `tabIndex`.** Breaks natural order globally. Reorder the DOM.
- **`onClick` on non-focusable elements.** Use `<button>`.
- **Mouse-only events** (`onMouseEnter` opening menus, `onDoubleClick`-only actions). Add focus and keyboard equivalents.
- **Focus traps outside modals** (e.g., rich text editors capturing Tab with no exit). Document and implement an escape.
- **`tabIndex={0}` on every card or heading.** Tab-stop bloat. Only interactive elements belong in the tab order.
- **`preventDefault` on Space/arrow keys globally.** Breaks scrolling and AT. Scope handlers to widgets.

## Accessibility
- WCAG: 2.1.1 Keyboard (A), 2.1.2 No Keyboard Trap (A), 2.1.4 Character Key Shortcuts (A), 2.4.1 Bypass Blocks (A), 2.4.3 Focus Order (A), 2.4.7 Focus Visible (AA), 2.4.11 Focus Not Obscured (AA), 2.4.13 Focus Appearance (AAA), 1.4.13 Content on Hover or Focus (AA), 3.2.1 On Focus (A: no context change on focus).
- Screen readers in browse mode intercept keys. Composite widgets need proper roles, so NVDA/JAWS switch to focus mode.

## Responsive Design
- Keyboards are used on tablets and phones too (iPad with keyboard, Android with Bluetooth). Don't disable keyboard handling on "mobile" breakpoints.
- Off-canvas mobile nav must be `inert` when closed, and focus moves into it when opened.

## Performance
- Attach one delegated `onKeyDown` to the widget container instead of per-item listeners in large lists.
- For virtualized lists, the focused item must remain rendered (keep the active index in the overscan range) or use `aria-activedescendant`.

## Security
- Avoid global key listeners that log keystrokes to analytics, which could capture passwords. Scope and sanitise.

## Testing
```ts
// e2e/keyboard.spec.ts (Playwright)
import { test, expect } from '@playwright/test';

test('skip link and tab order', async ({ page }) => {
  await page.goto('/');
  await page.keyboard.press('Tab');
  const skip = page.getByRole('link', { name: 'Skip to main content' });
  await expect(skip).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('main')).toBeFocused();
});

test('tabs arrow navigation', async ({ page }) => {
  await page.goto('/settings');
  await page.getByRole('tab', { name: 'Profile' }).focus();
  await page.keyboard.press('ArrowRight');
  await expect(page.getByRole('tab', { name: 'Billing' })).toBeFocused();
  await expect(page.getByRole('tab', { name: 'Billing' })).toHaveAttribute('aria-selected', 'true');
});
```
- Component tests: `@testing-library/user-event` `user.tab()` and `user.keyboard('{ArrowDown}')`.
- Manual: Accessibility Insights "Tab stops" visualiser draws the tab order.
- axe: `scrollable-region-focusable`, `tabindex` (positive), `nested-interactive`, `focus-order-semantics` (experimental).

## Tooling
- Accessibility Insights for Web (Tab stops), axe DevTools, Chrome DevTools Rendering and Elements `:focus-visible` forcing.
- React Aria `useFocusRing`, `FocusScope`, `useKeyboard`; Radix primitives' built-in roving focus (`RovingFocusGroup`).
- dnd-kit `KeyboardSensor`; tinykeys or react-hotkeys-hook for shortcuts (verify input-field guards).
- eslint-plugin-jsx-a11y: `no-noninteractive-tabindex`, `tabindex-no-positive`, `click-events-have-key-events`, `interactive-supports-focus`, `no-autofocus`.

## Framework Notes
- **React (Vite SPA).** Same principles. React Router or TanStack Router links are real anchors. Avoid `autoFocus` except in dialogs and search pages where it's expected.
- **Next.js.**
  - `<Link>` is a real anchor, so keyboard works by default.
  - Client navigation keeps focus on the clicked link, so manage focus (see accessible-spa-routing).
  - Hydration gap: server-rendered custom widgets are inert until hydrated. Prefer native elements, or disable interactivity visibly until ready.
- **Tailwind.** Use `focus-visible:outline-2 focus-visible:outline-offset-2` utilities in the design-system base, and never ship `outline-none` alone.

## AI Agent Guidance
- Do: use native interactive elements; add `:focus-visible` styles to every component you create.
- Do: implement arrow-key navigation (roving tabindex) for composite widgets, and write a keyboard test for each.
- Do: guard global shortcuts against text inputs, and offer a way to disable single-key shortcuts.
- Don't: emit `tabIndex` greater than 0, `outline: none` without a replacement, mouse-only handlers, or `tabIndex={0}` on static content.
- Verify before done:
  - full Tab walk of changed screens
  - every widget operable
  - Esc closes overlays with focus returned
  - focus visible and unobscured

## Examples
```tsx
// Toolbar using the roving hook
export function FormatToolbar() {
  const buttons = ['Bold', 'Italic', 'Underline'] as const;
  const { onKeyDown, getItemProps } = useRovingTabIndex(buttons.length);
  const [pressed, setPressed] = useState<Record<string, boolean>>({});

  return (
    <div role="toolbar" aria-label="Text formatting" onKeyDown={onKeyDown}>
      {buttons.map((b, i) => (
        <button key={b} type="button" aria-pressed={!!pressed[b]} {...getItemProps(i)}
          className="min-h-6 min-w-6 focus-visible:outline-2 focus-visible:outline-offset-2"
          onClick={() => setPressed(p => ({ ...p, [b]: !p[b] }))}>
          {b}
        </button>
      ))}
    </div>
  );
}
```

```tsx
// Skip link (Tailwind)
<a href="#main"
   className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-white focus:px-4 focus:py-2">
  Skip to main content
</a>
```

## Related Skills
- [focus-management](../focus-management/Skill.md) — moving focus programmatically
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — per-pattern key contracts
- [landmarks-and-accessible-navigation](../landmarks-and-accessible-navigation/Skill.md) — skip links, bypass blocks
- [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md) — shortcut systems for power users
- [command-palette](../command-palette/Skill.md) — Cmd+K patterns
- [drag-and-drop](../drag-and-drop/Skill.md) — keyboard alternatives to drag
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — non-keyboard input parity

## Sources
- [Understanding 2.1.1 Keyboard / 2.1.4 / 2.4.3 / 2.4.7 / 2.4.11](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — requirements and exceptions
- [APG: Developing a Keyboard Interface](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/) — Official — roving tabindex, activedescendant, key conventions
- [Open UI focusgroup explainer](https://open-ui.org/components/scoped-focusgroup.explainer/) — Experimental — proposal status
- [MDN: reading-flow](https://developer.mozilla.org/en-US/docs/Web/CSS/reading-flow) — Official (MDN) — experimental status
- [WebAIM: Keyboard Accessibility](https://webaim.org/techniques/keyboard/) — Community — testing procedure
- [Playwright docs](https://playwright.dev/docs/input) — Open Source — keyboard API

## License / Usage Notes
Summarised from W3C (W3C Document License), MDN (CC BY-SA) and WebAIM. Code examples are original.

## Quality Tier
A — authoritative and complete for React/Next.js; upcoming platform features are still unsettled.

## Status
Active

## Last Verified
2026-09-15
