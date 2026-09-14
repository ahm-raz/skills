# Popovers

## Summary
Popovers are non-modal overlays anchored to a trigger. They hold interactive content such as mini-forms, pickers, settings, info cards and "hover cards". This skill covers the native Popover API (`popover="auto|manual|hint"`), invoker attributes, implicit anchor positioning, choosing the right ARIA role (popovers are *not* one role), and when to use Radix/React Aria/Base UI/Ariakit instead.

## Category
Components

## Subcategories
Overlays, Popover API, top layer, light dismiss, anchor positioning, non-modal dialog, hover card

## Problem It Solves
Anchored overlays used to need portals, z-index wars, click-outside listeners, Escape handlers, and positioning libraries. The Popover API makes top-layer rendering, light dismiss, Escape, one-open-at-a-time stacking and focus return native. Semantics still have to be chosen correctly, because the `popover` attribute adds behavior, not a role.

## When To Use
- Interactive content tied to a trigger: share panel, color picker, quick filter, notification panel, "more info" with links.
- Non-modal content that should close when the user clicks elsewhere.
- Custom overlays that aren't menus, listboxes or tooltips.

## When Not To Use
- Plain text description on hover/focus: use a tooltip.
- A list of actions: use a menu (dropdown-menus).
- Selecting a value: use select/combobox/listbox.
- Blocking task: use a modal dialog.
- Content users need persistently: render inline.

## Core Principles
1. `popover` adds behavior (top layer, light dismiss, stacking); **you** add semantics (`role="dialog"`, `menu`, `listbox`, or none).
2. The trigger must be a `<button>`. Native invokers (`popovertarget` or `commandfor`) give implicit `aria-expanded` and focus handling.
3. Popover content should follow the trigger in reading/focus order; native invokers make Tab from the trigger enter the popover next.
4. Escape closes and focus returns to the trigger.
5. Positioning is a separate concern (anchor positioning or Floating UI).

## Best Practices
- Use `popover` (auto) for most interactive popovers; `manual` for persistent overlays you control (e.g., toasts, pinned panels); `hint` for tooltips/hover cards that must not close open auto popovers.
- Give interactive popovers with multiple controls `role="dialog"` + `aria-labelledby`. Simple content-only popovers need no role.
- Place the popover element right after its trigger in the DOM when possible. Top layer handles visual stacking, and DOM order preserves logical order.
- Don't auto-focus into the popover unless the content is the task (e.g., search input). Let Tab move in naturally.
- Reset UA styles when anchoring: `margin: 0; inset: auto;`.
- Provide an explicit close button for popovers with forms (mobile users can't press Escape).
- Hover cards: open on hover *and* focus with delay; content must remain hoverable (WCAG 1.4.13). Never put essential actions only in hover cards.

## Implementation Guidance

### Popover types
| Type | Light dismiss | Closes others | Typical use |
|---|---|---|---|
| `auto` | Yes (outside click, Escape) | Closes non-ancestor auto popovers | Menus, pickers, panels |
| `hint` | Yes | Closes other hints only, not autos | Tooltips, hover cards |
| `manual` | No | No | Toasts, persistent overlays |

Support: Popover API core is Baseline (newly available, Jan 2025). `popover="hint"` is in Chrome/Edge 133+ and Firefox 149+; **not in Safari as of Sept 2026**. Unsupported `hint` falls back to `manual` behavior, so add Escape/blur handling if you rely on it. `interestfor` (hover/focus invokers) is Chromium 142+ only; polyfill or use JS.

### Native vs library
| Need | Choose |
|---|---|
| Simple anchored panel, any framework | Native `popover` + `popovertarget`/`commandfor` + CSS anchor positioning |
| React DS needing controlled state, animations with presence, collision-aware positioning in all browsers, nested popovers inside dialogs | Radix Popover, Base UI Popover, React Aria `Popover`+`DialogTrigger`, Ariakit `Popover` |
| Hover card with safe-triangle pointer movement | Radix HoverCard / Base UI PreviewCard / Floating UI `useHover` + `safePolygon` |
| Support for engines lacking anchor positioning sub-features | Floating UI or `@oddbird/css-anchor-positioning` polyfill |

### Keyboard
| Key | Behavior |
|---|---|
| Enter/Space on trigger | Toggle popover |
| Tab | From trigger into popover content (native invoker order), then onward |
| Escape | Close; focus returns to trigger |
| Shift+Tab from first item | Back to trigger |

### ARIA
| Element | Attribute |
|---|---|
| Trigger `<button>` | `aria-expanded` (implicit with native invokers; set manually otherwise), `aria-controls` optional, `aria-haspopup="dialog"` only if role is dialog |
| Popover | `role="dialog"` + `aria-labelledby` when interactive and multi-control; no role for simple content |
| Hover card | Treat as supplemental; link target must be reachable without it |

### Positioning with implicit anchor
```css
[popover].panel {
  margin: 0; inset: auto;
  position-area: block-end span-inline-end;   /* below, aligned to start */
  margin-block-start: 6px;
  position-try-fallbacks: flip-block, flip-inline;
}
```
Anchor positioning core: Chrome/Edge 125+, Safari 26+, Firefox 147+. Some sub-features only fully match in the newest releases, so test fallbacks.

## Recommended Workflow
1. Classify content: tooltip, menu, listbox, dialog-like panel, or plain disclosure. Choose the role accordingly.
2. Mark up the trigger button and the popover element adjacent in the DOM.
3. Choose `auto`/`manual`/`hint`.
4. Position with anchor positioning (plus fallbacks), or Floating UI where needed.
5. Add animation with `@starting-style` + `allow-discrete` on `display`/`overlay`.
6. Test Escape, outside click, focus order, mobile tap, 400% zoom.

## Patterns

### Native interactive popover (React 19)
```tsx
'use client';
import { useId } from 'react';

export function SharePopover({ url }: { url: string }) {
  const id = useId();
  return (
    <>
      <button type="button" popoverTarget={`${id}-share`}>Share</button>
      <div id={`${id}-share`} popover="auto" role="dialog" aria-labelledby={`${id}-h`} className="panel">
        <h2 id={`${id}-h`}>Share link</h2>
        <label>URL <input value={url} readOnly /></label>
        <button type="button" onClick={() => navigator.clipboard.writeText(url)}>Copy</button>
        <button type="button" popoverTarget={`${id}-share`} popoverTargetAction="hide">Close</button>
      </div>
    </>
  );
}
```
React 19 types include `popover`, `popoverTarget` and `popoverTargetAction`. `useId` values contain colons, which is fine for id references but needs escaping in CSS selectors.

### Animated popover
```css
[popover] { opacity: 0; scale: .96;
  transition: opacity .15s, scale .15s, display .15s allow-discrete, overlay .15s allow-discrete; }
[popover]:popover-open { opacity: 1; scale: 1; }
@starting-style { [popover]:popover-open { opacity: 0; scale: .96; } }
```

### Imperative open with source + toggle sync (React)
```tsx
const panelRef = useRef<HTMLDivElement>(null);
const triggerRef = useRef<HTMLButtonElement>(null);
useEffect(() => {
  const el = panelRef.current!;
  const onToggle = (e: Event) => setOpen((e as ToggleEvent).newState === 'open');
  el.addEventListener('toggle', onToggle);
  return () => el.removeEventListener('toggle', onToggle);
}, []);
const show = () => panelRef.current?.showPopover({ source: triggerRef.current! }); // source: focus return + implicit anchor
```
Check `showPopover({ source })` support in your matrix. Without it, set up the anchor with `anchor-name`/`position-anchor`.

### Nested popovers
A popover opened by a button *inside* another auto popover is its child. Opening it doesn't close the parent, and light dismiss closes from the top.

## Anti-Patterns
- **`popover` on a div with no role for a mini-form**: screen readers get no context. Fix: `role="dialog"` + label.
- **`role="menu"` on a popover that contains inputs/links**: breaks the menu contract. Fix: dialog role or plain content.
- **Trigger is a `<div>` or `<a>`**: no invoker semantics. Fix: `<button type="button">` (`interestfor` on links is only for hint-style content).
- **Popover appended to `<body>` far from trigger**: Tab order jumps. Fix: keep adjacent or manage focus.
- **Relying on `popover="hint"` in Safari**: falls back to manual and never light-dismisses. Fix: feature-detect and add handlers.
- **Hover-only open**: inaccessible to keyboard/touch. Fix: click or focus as well.
- **Forgetting `inset: auto`**: UA centering conflicts with anchor positioning. Fix: reset.
- **Popover with critical info that disappears on scroll**: Fix: persistent inline content.

## Accessibility
- WCAG 1.4.13 Content on Hover or Focus (dismissible, hoverable, persistent), 2.1.1 Keyboard, 2.4.3 Focus Order, 4.1.2 Name/Role/Value, 1.3.2 Meaningful Sequence.
- Native invokers set `aria-expanded` and an `aria-details` relationship automatically. Don't duplicate conflicting values.
- Focus visible inside popovers; target size ≥ 24px.

## Responsive Design
- On small viewports, large popovers become bottom sheets or full-screen dialogs. Keep the same content component and switch the container.
- Constrain size: `max-inline-size: min(22rem, 100vw - 16px)`, `max-block-size` with scroll. Use `position-try-fallbacks` and `anchor-size()`.
- Touch: no hover; ensure tap opens.

## Performance
- Native top layer avoids portal re-renders.
- Lazy-render heavy content on the first `beforetoggle`.
- Avoid per-scroll JS positioning when CSS anchoring suffices.

## Security
- Hover cards that fetch user data on hover can leak info or cause request floods. Debounce, and authorize server-side.
- Sanitize any user-generated content rendered in popovers.

## Testing
- Playwright: click trigger → `toBeVisible()`, press Escape → hidden + trigger focused; outside click closes (auto); check `aria-expanded` toggles.
- Cross-engine runs (WebKit for hint fallback behavior, Firefox for anchor positioning).
- Unit tests: jsdom lacks top layer and Popover API fidelity, so use browser-mode tests.
- axe: dialog name when role is dialog.

## Tooling
- Native Popover API, invoker commands (Baseline), CSS anchor positioning (Baseline 2026 core).
- Polyfills: `@oddbird/css-anchor-positioning`, `interestfor` polyfill (npm), `@oddbird/popover-polyfill` for very old engines.
- Libraries: shadcn/ui Popover/HoverCard, Radix Popover/HoverCard, Base UI Popover/PreviewCard (v1.x stable), React Aria Components Popover, Ariakit Popover/Hovercard, Headless UI Popover, Floating UI React.

## Framework Notes
- **React (Vite SPA)**: React 19 supports `popover`, `popoverTarget` and `popoverTargetAction` props. For `commandfor`/`command`/`interestfor`, augment JSX types if your `@types/react` lacks them. For a controlled `open`, call `showPopover()`/`hidePopover()` in an effect and sync back from the `toggle` event. In a design system, prefer shadcn/ui Popover (Radix or Base UI) for consistent animation and collision handling.
- **Next.js (App Router)**: Popovers with state or handlers are Client Components (`'use client'`). Native `popover` markup can be server-rendered, but the popover stays closed until the user interacts, so there's no hydration risk. Library popovers portal to `body` after hydration. Close open popovers on route change (`usePathname` effect) because the trigger may unmount. Don't fetch hover-card data in render; fetch on open via a Server Action or route handler.

## AI Agent Guidance
- DO decide role first (dialog/menu/listbox/none), then implement behavior.
- DO use `<button>` triggers with native invokers where possible.
- DON'T use `popover="hint"` or `interestfor` without fallback for Safari/Firefox (interestfor).
- DON'T create hover-only interactions.
- Verify: Escape closes and returns focus; outside click (auto); `aria-expanded` updates; content reachable by Tab right after trigger; positions correctly near viewport edges; works in WebKit.

## Examples
shadcn/ui Popover (Radix) with an interactive form:
```tsx
'use client';
import { Popover, PopoverTrigger, PopoverContent } from '@/components/ui/popover';

export function RenameColumn({ name, onRename }: { name: string; onRename: (v: string) => void }) {
  return (
    <Popover>
      <PopoverTrigger asChild><button type="button">Rename</button></PopoverTrigger>
      <PopoverContent align="start" aria-label="Rename column">
        <form onSubmit={(e) => { e.preventDefault(); onRename(new FormData(e.currentTarget).get('name') as string); }}>
          <label htmlFor="col-name">Column name</label>
          <input id="col-name" name="name" defaultValue={name} autoFocus />
          <button type="submit">Save</button>
        </form>
      </PopoverContent>
    </Popover>
  );
}
```
Radix Popover renders `role="dialog"` on content and handles focus return, Escape and collision-aware positioning.

React with Base UI-style API (conceptual):
```tsx
<Popover.Root>
  <Popover.Trigger>Notifications</Popover.Trigger>
  <Popover.Portal>
    <Popover.Positioner sideOffset={8}>
      <Popover.Popup>
        <Popover.Title>Notifications</Popover.Title>
        <ul>…</ul>
        <Popover.Close>Close</Popover.Close>
      </Popover.Popup>
    </Popover.Positioner>
  </Popover.Portal>
</Popover.Root>
```

## Related Skills
- [floating-element-positioning](../floating-element-positioning/Skill.md): anchor positioning and Floating UI
- [tooltips](../tooltips/Skill.md): text-only hint overlays
- [dropdown-menus](../dropdown-menus/Skill.md): action menus
- [accessible-dialogs](../accessible-dialogs/Skill.md): modal alternative
- [select-and-combobox](../select-and-combobox/Skill.md): value selection popups
- [focus-management](../focus-management/Skill.md): focus return
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md): entry/exit animation

## Sources
- [MDN: Using the Popover API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using) — Official — types, stacking, events, implicit anchor, a11y
- [Chrome for Developers: popover=hint](https://developer.chrome.com/blog/popover-hint) — Official — hint semantics
- [web-features: Interest invokers](https://web-platform-dx.github.io/web-features-explorer/features/interest-invokers/) — Official — Chromium-only support
- [MDN: Using CSS anchor positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Anchor_positioning/Using) — Official — position-area, fallbacks
- [WCAG 2.2 Understanding 1.4.13](https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html) — Official — hover/focus content rules
- [GoogleChrome modern-web-guidance skill](https://github.com/GoogleChrome/modern-web-guidance) — Community/Official (agent skill) — hint + interestfor guidance with polyfills

## License / Usage Notes
Summarized in original wording from W3C/MDN/Chrome docs; code original. Libraries MIT/Apache-2.0.

## Quality Tier
A — verified against MDN, web-features and WCAG; browser support for hint/interestfor still moving.

## Status
Active

## Last Verified
2026-09-15
