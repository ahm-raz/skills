# Command Palette

## Summary
A command palette (⌘K / Ctrl+K) is a searchable, keyboard-first launcher for navigation and actions. This skill covers the underlying ARIA model (dialog containing a combobox + listbox), cmdk and shadcn/ui `Command`, React Aria Autocomplete-style alternatives, ranking and grouping, nested pages, shortcut handling across keyboard layouts, and wiring commands to Next.js routing and Server Actions.

## Category
Components

## Subcategories
⌘K menu, command menu, quick switcher, keyboard shortcuts, fuzzy search, combobox, spotlight search

## Problem It Solves
Power users in complex apps need fast access to deep pages and actions without hunting through menus. Palettes often fail as hidden features with no visible entry point. Other common failures: shortcuts that clash with the browser or screen readers, results that aren't announced, focus lost on close, slow filtering with large datasets, and actions that don't match permissions.

## When To Use
- SaaS or admin apps, developer tools, editors, docs sites with many destinations or actions.
- Repeat users who benefit from keyboard acceleration.
- Global search that mixes navigation (pages, records) and commands (create, toggle theme).

## When Not To Use
- Small marketing sites: use a nav and simple search.
- As the *only* way to reach features: always keep visible navigation.
- Complex search with filters/facets: use a search page.
- Mobile-first consumer apps where keyboard shortcuts are irrelevant (a search screen is better).

## Core Principles
1. It's a modal dialog containing a combobox input that controls a listbox of options; focus stays in the input and `aria-activedescendant` points at the highlighted option.
2. Provide a visible trigger (search button showing the shortcut hint) in addition to the shortcut.
3. Results update as you type with an announced count or empty state; Enter runs the highlighted command.
4. Escape closes (or backs out one nested page first); focus returns to where the user was.
5. Commands respect permissions and context; don't show commands that will fail.

## Best Practices
- Shortcut: ⌘K on macOS, Ctrl+K elsewhere. Also accept `/` only when focus isn't in an editable field. Detect by `event.key`, not `code`, for layout independence, and let users see or disable shortcuts.
- Don't override shortcuts screen readers use. Ctrl+K is generally safe; single-key shortcuts need a way to turn them off (WCAG 2.1.4).
- Empty query shows recent items and suggested commands; group results (Navigation, Actions, Records) with headings.
- Rank: exact prefix > word-start > fuzzy; boost recents. Support `keywords` aliases ("dark" → "Toggle theme").
- Show each command's shortcut on the right so users learn it.
- Nested pages (e.g., "Change status → …") show breadcrumbs in the input area. Backspace on an empty input goes back.
- Async results: debounce ~150ms, show a loading row, and keep static commands visible instantly.
- After running a command, close the palette and give feedback (navigation or toast).

## Implementation Guidance

### ARIA model
| Element | Role / attributes |
|---|---|
| Container | `role="dialog"` (modal) + `aria-label="Command menu"` |
| Input | `role="combobox" aria-expanded="true" aria-controls={listId} aria-activedescendant={activeId} aria-autocomplete="list"` |
| List | `role="listbox"` + label |
| Group | `role="group"` + `aria-labelledby` heading (cmdk renders groups this way) |
| Option | `role="option" aria-selected` for the highlighted item, `aria-disabled` if unavailable |
| Status | Polite live region: "12 results" / "No results" |

### Keyboard
| Key | Behavior |
|---|---|
| ⌘K / Ctrl+K | Open (toggle) |
| Typing | Filter |
| Down/Up Arrow | Move highlight (optionally loop) |
| Home/End | First/last (cmdk supports) |
| Enter | Run highlighted command |
| Escape | Close page / close palette |
| Backspace on empty input | Back to parent page |
| Ctrl+N/P (optional) | Vim/Emacs-style navigation (cmdk `vimBindings`) |

### Library decision table
| Need | Choose | Notes |
|---|---|---|
| React, fast to ship, shadcn project | shadcn/ui `Command` + `CommandDialog` (cmdk) | cmdk: unstyled, built-in ranking, groups, `Command.Dialog` uses Radix Dialog; good up to ~2–3k items |
| Large or async result sets | cmdk with `shouldFilter={false}` + server search; or React Aria `Autocomplete` + `Menu`/`ListBox` | Filter server-side, virtualize long lists |
| Full control over a11y and collections | React Aria Components (Autocomplete + Menu inside Dialog) | Strong screen reader testing |
| Palette actions also available as menus | Share one command registry | Avoid drift |

## Recommended Workflow
1. Build a command registry: id, label, keywords, group, shortcut, `perform`, `when` (permission/context predicate).
2. Add a visible trigger button with the shortcut hint.
3. Implement a global shortcut listener (ignore when an editable element or IME composition is active, unless ⌘K).
4. Render the palette with cmdk/shadcn; empty state shows recents.
5. Wire navigation (router) and actions (Server Actions/mutations) with feedback.
6. Add async sources with debounce and loading state.
7. Test keyboard, screen readers (announced options, counts), and focus return.

## Patterns

### Global shortcut hook
```tsx
'use client';
import { useEffect } from 'react';

export function useHotkey(key: string, handler: () => void) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.isComposing) return;
      if (e.key.toLowerCase() === key && (e.metaKey || e.ctrlKey) && !e.altKey) {
        e.preventDefault();
        handler();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [key, handler]);
}
```
Pass a stable `handler` (e.g., a `useCallback` or state setter) so the listener isn't re-attached on every render.

### Command registry
```ts
export type Command = {
  id: string; label: string; group: 'Navigation' | 'Actions';
  keywords?: string[]; shortcut?: string;
  when?: (ctx: { role: 'admin' | 'member' }) => boolean;
  perform: (api: { navigate: (href: string) => void }) => void | Promise<void>;
};
```

### shadcn/ui CommandDialog with navigation and actions (Next.js)
```tsx
'use client';
import { useCallback, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  CommandDialog, CommandInput, CommandList, CommandEmpty, CommandGroup, CommandItem, CommandShortcut,
} from '@/components/ui/command';
import { useHotkey } from './use-hotkey';
import type { Command } from './commands';

export function CommandPalette({ commands, role }: { commands: Command[]; role: 'admin' | 'member' }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  useHotkey('k', useCallback(() => setOpen((o) => !o), []));
  const visible = commands.filter((c) => c.when?.({ role }) ?? true);
  const groups = Object.groupBy(visible, (c) => c.group);

  return (
    <>
      <button type="button" onClick={() => setOpen(true)} aria-keyshortcuts="Control+K Meta+K">
        Search… <kbd>⌘K</kbd>
      </button>
      <CommandDialog open={open} onOpenChange={setOpen}>
        <CommandInput placeholder="Type a command or search…" />
        <CommandList>
          <CommandEmpty>No results found.</CommandEmpty>
          {Object.entries(groups).map(([group, items]) => (
            <CommandGroup key={group} heading={group}>
              {items!.map((c) => (
                <CommandItem key={c.id} value={c.label} keywords={c.keywords}
                  onSelect={async () => { setOpen(false); await c.perform({ navigate: router.push }); }}>
                  {c.label}
                  {c.shortcut && <CommandShortcut>{c.shortcut}</CommandShortcut>}
                </CommandItem>
              ))}
            </CommandGroup>
          ))}
        </CommandList>
      </CommandDialog>
    </>
  );
}
```
`Object.groupBy` is ES2024; use a reducer if your target lacks it. Make sure the dialog has an accessible title (shadcn's `CommandDialog` includes a visually hidden `DialogTitle`).

### Nested pages
Keep `pages: string[]` in state. Selecting "Change status…" pushes `'status'`. Render that page's items. Handle `onKeyDown` so Escape or Backspace on an empty input pops the page before closing.

### Async search
Use cmdk with `shouldFilter={false}`. Debounce the query, fetch from a route handler (or Server Action), render `Command.Loading` while pending, and cancel stale requests with `AbortController`.

## Anti-Patterns
- **Shortcut-only discovery**: most users never find it. Fix: visible search/command button.
- **Hijacking Ctrl+F or single keys globally**: breaks browser and assistive tech. Fix: ⌘K/Ctrl+K; single-key shortcuts only when not typing and toggleable (WCAG 2.1.4).
- **Moving DOM focus into list items**: typing breaks. Fix: `aria-activedescendant` pattern (cmdk does this).
- **Showing commands the user lacks permission for**: failures and confusion. Fix: `when` predicates, plus server-side enforcement.
- **Separate, drifting definitions for menus vs palette**: Fix: single registry.
- **Filtering 50k records client-side**: jank. Fix: server search + virtualization.
- **Closing silently after an action with no visible change**: Fix: toast or navigation feedback.

## Accessibility
- WCAG 2.1.1 Keyboard, 2.1.4 Character Key Shortcuts, 4.1.2 Name/Role/Value, 4.1.3 Status Messages (result counts), 2.4.3 Focus Order (focus returns on close), 1.4.13 not applicable (modal).
- Test VoiceOver (Safari) and NVDA: the highlighted option must be announced as it changes.

## Responsive Design
- On touch devices, open from a search button as a full-screen dialog. Hide shortcut hints when `(hover: none)`.
- Keep the list height within `dvh` and keep the input visible with the virtual keyboard open.

## Performance
- cmdk handles roughly 2–3k items well. Beyond that, filter server-side or pre-index (e.g., a worker-based fuzzy index).
- Lazy-load the palette bundle on first open or first shortcut press (`next/dynamic` / `React.lazy`), with the trigger rendered eagerly.
- Debounce async queries; cache recent results.

## Security
- Enforce authorization server-side for every action a palette can trigger.
- Don't leak record titles from other tenants in search results; scope queries per tenant.
- Treat search input as untrusted in server queries (parameterized queries, rate limiting).

## Testing
- Testing Library: open via `user.keyboard('{Control>}k{/Control}')`, `getByRole('combobox')`, type → `getAllByRole('option')`, `{ArrowDown}{Enter}` → assert router push or action called.
- Playwright: ⌘K on WebKit (Meta) and Ctrl+K on Chromium/Firefox; focus returns to the prior element; nested page Backspace.
- Screen reader smoke test for option announcements.
- Unit-test ranking and `when` predicates.

## Tooling
- cmdk (MIT; Radix Dialog inside `Command.Dialog`; React 18+), shadcn/ui Command.
- React Aria Components (Autocomplete, Menu, ListBox, Dialog).
- kbar (community alternative; verify maintenance before adopting).

## Framework Notes
- **React (Vite SPA)**: Mount the palette once near the app root. Get navigation from React Router's `useNavigate` or TanStack Router. Lazy-load with `React.lazy` + Suspense on first open. Register contextual commands from pages via context (register on mount, unregister on unmount).
- **Next.js (App Router)**: The palette is a Client Component (`'use client'`) mounted in the root or app layout. Pass a serializable command list from a Server Component (no functions across the boundary; map ids to client handlers) or fetch results from a route handler. Run mutations through Server Actions and follow with `router.refresh()` or `revalidatePath`. Use `router.push` for navigation; after navigation Next.js announces the new page, so don't force focus back to the old trigger. Load the palette with `next/dynamic` using `{ ssr: false }` inside a client component if it's heavy.

## AI Agent Guidance
- DO build or reuse a single command registry; check for existing cmdk/shadcn Command usage.
- DO include a visible trigger and an accessible dialog title.
- DON'T implement single-key global shortcuts without an off switch.
- DON'T expose unauthorized commands.
- Verify: ⌘K/Ctrl+K toggles; arrow navigation announced; Enter runs; Escape closes or backs out; focus return; empty state; performance with realistic data volume.

## Examples
React Aria Components alternative (conceptual composition):
```tsx
import { Autocomplete, SearchField, Input, Menu, MenuItem, Dialog, Modal, useFilter } from 'react-aria-components';

function Palette({ isOpen, onOpenChange, items }: { isOpen: boolean; onOpenChange: (o: boolean) => void; items: { id: string; label: string }[] }) {
  const { contains } = useFilter({ sensitivity: 'base' });
  return (
    <Modal isDismissable isOpen={isOpen} onOpenChange={onOpenChange}>
      <Dialog aria-label="Command menu">
        <Autocomplete filter={contains}>
          <SearchField aria-label="Search commands" autoFocus><Input /></SearchField>
          <Menu items={items} onAction={(id) => run(String(id))}>
            {(item) => <MenuItem id={item.id}>{item.label}</MenuItem>}
          </Menu>
        </Autocomplete>
      </Dialog>
    </Modal>
  );
}
```
Check current React Aria docs for exact component names.

## Related Skills
- [search-and-autocomplete](../search-and-autocomplete/Skill.md): combobox and search fundamentals
- [select-and-combobox](../select-and-combobox/Skill.md): combobox ARIA
- [accessible-dialogs](../accessible-dialogs/Skill.md): modal container
- [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md): shortcut systems
- [small-ui-primitives-vaul-sonner-cmdk](../small-ui-primitives-vaul-sonner-cmdk/Skill.md): cmdk library details
- [shadcn-ui](../shadcn-ui/Skill.md): Command component
- [dropdown-menus](../dropdown-menus/Skill.md): shared command definitions
- [list-virtualization](../list-virtualization/Skill.md): very large result lists

## Sources
- [cmdk README](https://github.com/dip/cmdk) — Open Source — API parts, filtering, pages pattern, a11y claims
- [WAI-ARIA APG: Combobox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/) — Official — combobox/listbox/activedescendant model
- [WCAG 2.2 Understanding 2.1.4 Character Key Shortcuts](https://www.w3.org/WAI/WCAG22/Understanding/character-key-shortcuts.html) — Official — single-key shortcut rules
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Community (agent skill) — internationalized shortcuts, keyboard operability

## License / Usage Notes
Summarized in original wording; code original. cmdk and shadcn/ui MIT; React Aria Apache-2.0.

## Quality Tier
B — solid library and APG grounding. No official "command palette" pattern exists, and kbar/React Aria specifics weren't re-verified.

## Status
Active

## Last Verified
2026-09-15
