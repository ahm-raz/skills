# Keyboard Power-User UI

## Summary
Patterns for making enterprise React/Next.js apps fast for expert, keyboard-heavy users: a scoped shortcut registry, sequence shortcuts ("g then i"), j/k list navigation with roving focus, a discoverable cheat sheet (`?`), and a command palette entry point. It also covers how to avoid breaking browser, OS and assistive-technology keys, and how to meet WCAG 2.1.4 (Character Key Shortcuts).

## Category
Enterprise UI

## Subcategories
keyboard shortcuts, hotkeys, command palette, roving tabindex, list navigation, accessibility, productivity

## Problem It Solves
Operators in admin, CRM, support and ERP tools repeat the same actions hundreds of times a day. Mouse-only flows slow them down. Shortcuts added ad hoc cause their own problems: they fire while the user types in inputs, clash with screen-reader keys, differ between pages, and nobody can find them. A central registry with scopes and a cheat sheet fixes all of this.

## When To Use
- High-frequency triage screens: inboxes, ticket queues, approval worklists, order lists.
- Data-entry-heavy screens where hands stay on the keyboard.
- Apps with a command palette that should also advertise direct shortcuts.
- Products where NN/g's "help users adopt efficient methods" guideline applies (expert, trained users).

## When Not To Use
- Consumer or marketing pages visited occasionally. Nobody learns the shortcuts.
- Single-key shortcuts on content-editing surfaces (rich text, canvas) where letters must type.
- As the only path to an action. Every shortcut needs a visible, pointer- and keyboard-reachable equivalent.

## Core Principles
1. Shortcuts accelerate. They never replace visible controls.
2. One registry: every shortcut is declared once, with an id, keys, scope, description and handler. The cheat sheet and palette are generated from it.
3. Scopes decide precedence: modal > panel/focused region > page > global. Only the top active scope receives keys.
4. Never fire while the user is typing: inputs, textareas, selects, `contenteditable`, or during IME composition (`event.isComposing`).
5. Single-character shortcuts must be turn-off-able, remappable, or active only when their component has focus (WCAG 2.1.4, Level A).
6. Don't clobber reserved keys: browser (Ctrl/Cmd+L, T, W, R, F), OS, and screen-reader keys (Insert/CapsLock modifiers, browse-mode letters).
7. Use a platform-aware `Mod` key: Cmd on macOS, Ctrl elsewhere. Display the correct glyphs.
8. Make shortcuts discoverable: `?` opens the cheat sheet, tooltips and menu items show keys, the palette lists them.

## Best Practices
- Follow conventions users already know from Gmail, GitHub, Linear and Jira: `j`/`k` next/previous, `o`/`Enter` open, `x` select, `e` archive/done, `/` focus search, `g` + letter to navigate, `?` for help, `Mod+K` for the command palette, `Esc` to close or clear selection.
- Sequence shortcuts: after a leader key (`g`), wait about 1s for the second key. Show a small "g…" hint while waiting.
- Expose keys in the UI with `<kbd>` and on the control with `aria-keyshortcuts="Control+K"` (use the ARIA key names).
- Store user preferences (disable single-key shortcuts, remaps) in user settings on the server so they follow the user across devices.
- Run shortcut actions through the same Server Actions and permission checks as button clicks. Hide shortcuts for actions the user can't perform, but still enforce on the server.
- For destructive shortcuts (`#` delete), confirm or offer undo. Never delete instantly without recovery.
- Announce results of non-visual actions ("3 tickets archived") through a polite live region.

## Implementation Guidance
**Decision table: how to build it**

| Need | Approach |
|---|---|
| A few global combos | Small custom hook on `keydown` (below) |
| Many shortcuts, scopes, sequences | Registry + context provider (below), or a maintained hotkeys library such as `react-hotkeys-hook` or `tinykeys` (check current docs and maintenance) |
| Command palette | `cmdk` (see small-ui-primitives-vaul-sonner-cmdk), populated from the registry |
| Grid cell navigation | ARIA grid pattern with roving tabindex, or the grid library's built-in navigation (AG Grid, MUI X) |

**Registry shape**
```ts
// lib/shortcuts/types.ts
export type Scope = 'global' | 'page' | 'panel' | 'modal';
export interface Shortcut {
  id: string;                 // 'ticket.archive'
  keys: string[];             // ['e'] or ['g', 'i'] (sequence) or ['Mod+Enter']
  scope: Scope;
  description: string;        // shown in cheat sheet + palette
  group: string;              // 'Navigation' | 'Actions' ...
  singleKey?: boolean;        // derived; subject to the user's disable setting
  when?: () => boolean;       // e.g. selection non-empty, permission granted
  run: () => void;
}
```

**Typing guard (critical)**
```ts
export function isTypingTarget(e: KeyboardEvent): boolean {
  if (e.isComposing || e.key === 'Process') return true; // IME
  const el = e.target as HTMLElement | null;
  if (!el) return false;
  if (el.isContentEditable) return true;
  const tag = el.tagName;
  if (tag === 'TEXTAREA' || tag === 'SELECT') return true;
  if (tag === 'INPUT') {
    const type = (el as HTMLInputElement).type;
    return !['checkbox', 'radio', 'button', 'submit', 'reset'].includes(type);
  }
  return el.closest('[role="textbox"],[role="combobox"],[data-shortcuts="off"]') !== null;
}
export const isMac = () =>
  typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
```
Allow `Esc` and explicit `Mod+Enter` (submit) even inside inputs, if you choose. Block everything else.

## Recommended Workflow
1. Inventory the top 10–20 repeated tasks per screen (analytics, interviews).
2. Map them to conventional keys and check for conflicts with the browser, OS and screen readers.
3. Build the registry and provider. Put a scope provider on modal/panel roots.
4. Generate the `?` cheat sheet and the palette entries from the registry.
5. Add a settings toggle, "Use single-key shortcuts", plus remapping if feasible.
6. Add `<kbd>` hints to tooltips and menus, and `aria-keyshortcuts` to controls.
7. Test with keyboard only, a screen reader (NVDA/VoiceOver), and a non-US layout/IME.

## Patterns
**Scoped provider with sequences**
```tsx
'use client';
import { createContext, useContext, useEffect, useRef } from 'react';
import type { Shortcut } from '@/lib/shortcuts/types';
import { isTypingTarget, isMac } from '@/lib/shortcuts/guard';

const Ctx = createContext<{ register: (s: Shortcut[]) => () => void } | null>(null);

function normalize(e: KeyboardEvent) {
  const mod = isMac() ? e.metaKey : e.ctrlKey;
  return `${mod ? 'Mod+' : ''}${e.shiftKey && e.key.length > 1 ? 'Shift+' : ''}${e.key}`;
}

export function ShortcutProvider({ enabledSingleKey, children }: { enabledSingleKey: boolean; children: React.ReactNode }) {
  const stack = useRef<Shortcut[][]>([]);
  const pending = useRef<{ key: string; t: number } | null>(null);
  const order = { modal: 3, panel: 2, page: 1, global: 0 } as const;

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.defaultPrevented || isTypingTarget(e)) return;
      const combo = normalize(e);
      const all = stack.current.flat();
      const top = Math.max(-1, ...all.map((s) => order[s.scope]));
      const candidates = all.filter((s) => order[s.scope] === top || s.scope === 'global');
      const seq = pending.current && Date.now() - pending.current.t < 1000 ? pending.current.key : null;
      const match = candidates.find((s) => {
        if (s.keys.length === 1 && s.keys[0].length === 1 && !enabledSingleKey) return false;
        return seq ? s.keys.join(' ') === `${seq} ${combo}` : s.keys.length === 1 && s.keys[0] === combo;
      });
      if (match && (match.when?.() ?? true)) { e.preventDefault(); pending.current = null; match.run(); return; }
      pending.current = candidates.some((s) => s.keys.length === 2 && s.keys[0] === combo) ? { key: combo, t: Date.now() } : null;
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [enabledSingleKey]);

  const register = (list: Shortcut[]) => { stack.current.push(list); return () => { stack.current = stack.current.filter((l) => l !== list); }; };
  return <Ctx.Provider value={{ register }}>{children}</Ctx.Provider>;
}

export function useShortcuts(list: Shortcut[], deps: unknown[] = []) {
  const ctx = useContext(Ctx);
  useEffect(() => ctx?.register(list), deps); // eslint-disable-line react-hooks/exhaustive-deps
}
```

**j/k list navigation with roving focus**: keep `activeIndex` in state. The active row gets `tabIndex={0}` and all others `-1`. On change, call `rowRefs[i].focus()` and `scrollIntoView({ block: 'nearest' })`. With virtualization, scroll with the virtualizer first, then focus. `Enter` opens the detail (master-detail), and `x` toggles selection for bulk actions.

**Cheat sheet**: a dialog opened by `?` (Shift+/), grouped by `group`, filtered to the active scopes, with a search box and a link to settings.

## Anti-Patterns
- **Global `keydown` without a typing guard.** Typing "e" in a comment archives the ticket. Fix: `isTypingTarget` plus IME checks.
- **Hijacking Ctrl/Cmd+F, L, W, T or R.** This breaks browser expectations. Fix: pick unused combos, or scope find-in-grid to a focused grid only.
- **Always-on single-letter shortcuts with no way to turn them off.** Speech-input users trigger them accidentally, which fails WCAG 2.1.4. Fix: a settings toggle or focus-scoped activation.
- **Shortcuts documented nowhere.** Fix: `?` cheat sheet, `<kbd>` in tooltips, palette listing.
- **A shortcut that skips the permission check** because "the button was hidden". Fix: the same Server Action with server-side authorization.
- **Different keys for the same action on different pages.** Fix: a central registry with ids reused across screens.
- **Matching on `e.keyCode` or physical position only.** This breaks non-QWERTY layouts. Fix: match `e.key` for letters and `e.code` only for layout-independent physical combos, deliberately.

## Accessibility
- WCAG 2.1.4 Character Key Shortcuts (A): single printable-key shortcuts must be turn-off-able, remappable, or active only on focus.
- WCAG 2.1.1 Keyboard and 2.1.2 No Keyboard Trap: every action is reachable without shortcuts, and modals release focus on `Esc`.
- WCAG 2.4.7 Focus Visible and 2.4.11 Focus Not Obscured (Minimum): the roving focus target must be visible and not hidden under sticky headers.
- `aria-keyshortcuts` on the control that performs the action. Keys are also visible in the tooltip or menu text.
- Screen-reader browse mode intercepts letters. Grids and lists using application-like keys need proper roles (`grid`, `listbox`) so AT switches to focus mode.
- Announce bulk or invisible results through `aria-live="polite"`.

## Responsive Design
- On touch devices, don't advertise keyboard hints. Show them when a hardware keyboard is detected (first `keydown`), or only on `(hover: hover) and (pointer: fine)`.
- Tablets with keyboards should still get shortcuts. Don't gate on viewport width alone.

## Performance
- A single `window` listener with a registry lookup. Don't add one listener per row.
- Keep handlers cheap. Trigger transitions (`startTransition`) for navigation so INP stays low.
- Registering and unregistering on mount must not rerender the tree. Store the registry in refs.

## Security
- Shortcuts call the same Server Actions and route handlers as buttons. Authorization happens there (DAL), never in the key handler.
- Don't let users remap keys to arbitrary script or URLs. Store remaps as validated `{ id, keys }` pairs.

## Testing
- Unit test the typing guard, key normalization and sequence timing (Vitest with fake timers).
- Component test with Testing Library `user.keyboard('g')`, then `('i')`, and assert navigation. Assert nothing fires inside `<input>`.
- Playwright: `page.keyboard.press('Meta+K')` on WebKit and `Control+K` on Chromium/Linux, plus `?` opening the cheat sheet, and focus landing on the next row after `j`.
- Manual: NVDA plus Firefox and VoiceOver plus Safari, IME input (Japanese/Chinese), and an AZERTY layout.

## Tooling
- `cmdk` for the command palette (see the command-palette skill).
- Hotkey libraries: `react-hotkeys-hook`, `tinykeys`. Both are popular; check current maintenance and scope support before adopting.
- Grid libraries with built-in keyboard models: AG Grid, MUI X Data Grid, Glide Data Grid (canvas; verify a11y).

## Framework Notes
- **React (Vite SPA):** mount `ShortcutProvider` at the app root. Route navigation shortcuts call the router's `navigate`.
- **Next.js App Router:** the provider is a Client Component in `app/(app)/layout.tsx`. Read user preferences in the Server Component layout (DAL) and pass them as props. Navigation shortcuts use `useRouter().push`. Mutations call Server Actions. Keep the registry module free of server-only imports.

## AI Agent Guidance
- Do: create or extend a central registry, and add a typing/IME guard, a scope stack, the `?` cheat sheet, `aria-keyshortcuts` and a single-key disable setting.
- Do: reuse existing Server Actions for shortcut actions and keep the server-side authorization.
- Don't: bind Ctrl/Cmd+F/L/T/W/R/N, or add a per-component `window` listener.
- Verify before done: typing in every input on the page triggers nothing, `Esc` closes the top scope only, keys work on Mac and Windows naming, and the cheat sheet lists every registered shortcut.

## Examples
```tsx
'use client';
import { useRouter } from 'next/navigation';
import { useShortcuts } from '@/components/shortcuts/provider';
import { archiveTickets } from './actions'; // 'use server' — checks session + permission in DAL

export function TicketListShortcuts({ selectedIds, next, prev }: { selectedIds: string[]; next: () => void; prev: () => void }) {
  const router = useRouter();
  useShortcuts([
    { id: 'list.next', keys: ['j'], scope: 'page', group: 'Navigation', description: 'Next ticket', run: next },
    { id: 'list.prev', keys: ['k'], scope: 'page', group: 'Navigation', description: 'Previous ticket', run: prev },
    { id: 'go.inbox', keys: ['g', 'i'], scope: 'global', group: 'Navigation', description: 'Go to inbox', run: () => router.push('/inbox') },
    { id: 'ticket.archive', keys: ['e'], scope: 'page', group: 'Actions', description: 'Archive selected',
      when: () => selectedIds.length > 0, run: () => void archiveTickets(selectedIds) },
  ], [selectedIds, next, prev]);
  return null;
}
```
```tsx
<button onClick={openPalette} aria-keyshortcuts="Control+K Meta+K">
  Search <kbd>{isMac() ? '⌘' : 'Ctrl'}</kbd><kbd>K</kbd>
</button>
```

## Related Skills
- [command-palette](../command-palette/Skill.md) — primary discovery surface for shortcuts
- [keyboard-navigation](../keyboard-navigation/Skill.md) — foundational keyboard patterns
- [focus-management](../focus-management/Skill.md) — roving focus, restoring focus after actions
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — grid/listbox keyboard models
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — j/k and selection in tables
- [bulk-actions](../bulk-actions/Skill.md) — selection shortcuts feeding bulk operations
- [master-detail-layouts](../master-detail-layouts/Skill.md) — list navigation driving a detail pane
- [settings-and-preferences-ux](../settings-and-preferences-ux/Skill.md) — shortcut toggles and remapping
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — announcing shortcut results

## Sources
- [W3C WAI-ARIA APG Grid Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — arrow/Home/End/PageUp keys, roving tabindex, Enter/F2 edit mode, Escape
- [WCAG 2.2 Understanding 2.1.4 Character Key Shortcuts](https://www.w3.org/WAI/WCAG22/Understanding/character-key-shortcuts.html) — Official — turn off/remap/active-on-focus requirement (from standard knowledge; not re-fetched this session)
- [NN/g: 8 Design Guidelines for Complex Applications](https://www.nngroup.com/articles/complex-application-design/) — Community (research) — helping users adopt efficient methods, contextual shortcut cues
- [EUI Data Grid](https://eui.elastic.co/docs/components/tabular-content/data-grid/) — Official — keyboard shortcut toolbar control in a data grid

## License / Usage Notes
Guidance is summarized from W3C (W3C document license), NN/g and Elastic EUI docs. It is not copied. Code samples are original. Named libraries (`cmdk`, `react-hotkeys-hook`, `tinykeys`) are MIT-licensed as far as we know. Confirm before adoption.

## Quality Tier
A — grounded in WCAG/APG requirements and established product conventions, with working registry code. Hotkey library maintenance was not re-verified.

## Status
Active

## Last Verified
2026-09-15
