# Tooltips

## Summary
Tooltips are short, non-interactive text labels or descriptions that appear on hover *and* keyboard focus of a control. Examples: an icon button's name, or a keyboard shortcut hint. This skill covers when tooltips are appropriate (rarely for essential info), WCAG 1.4.13 requirements, `role="tooltip"` with `aria-describedby` vs using the tooltip as the accessible name, delay-group behavior, touch limitations, and native `popover="hint"` + `interestfor` vs library implementations.

## Category
Components

## Subcategories
Overlays, hint, icon button labels, hover/focus content, delay groups, touch

## Problem It Solves
Tooltips are one of the most misused UI elements. Teams hide essential instructions in them, make them hover-only, put links or buttons inside, forget touch devices, and create WCAG 1.4.13 failures (they vanish when the pointer moves toward them, or can't be dismissed without moving focus).

## When To Use
- Naming icon-only buttons visually (while the button also has an accessible name).
- Showing keyboard shortcuts ("Bold ⌘B").
- Brief supplemental description of a control (non-essential).
- Revealing truncated text (full value of an ellipsized cell) — also provide another way to access it.

## When Not To Use
- Essential instructions, errors, or required info: show inline.
- Interactive content (links, buttons, inputs): use a popover or non-modal dialog.
- Disabled buttons that need explanation: disabled buttons often aren't focusable. Explain inline or use `aria-disabled` + focusable.
- Touch-first UIs as the only disclosure: use a toggletip (click-triggered popover) or inline text.
- Replacing visible labels on form fields.
- Native `title` attribute for anything important (not keyboard/touch accessible and inconsistent in screen readers).

## Core Principles
1. Tooltip content is supplementary and non-interactive; if it's interactive it's a popover/dialog.
2. Show on hover **and** focus; hide on blur, pointer leave (after grace), and Escape.
3. Meet WCAG 1.4.13: dismissible without moving pointer/focus (Escape), hoverable (pointer can move onto it), persistent (doesn't time out).
4. The trigger keeps focus; the tooltip never receives focus.
5. Relationship: `aria-describedby` for descriptions; for icon-only buttons the tooltip text should also be the accessible name (`aria-label` or `aria-labelledby`), and don't double-announce it.

## Best Practices
- Opening delay ~300–700ms for the first tooltip; subsequent tooltips in the same group open instantly within a short window (Radix default: 700ms delay, 300ms skip-delay).
- Keyboard focus opens without long delay (or immediately); users tabbing need the info.
- Keep text ≤ ~1 short sentence; no headings or rich structure.
- Don't cover the trigger or the content the user is working on; position with fallbacks.
- Keep tooltip text in sync with the button's accessible name to satisfy WCAG 2.5.3 Label in Name.
- Toggletip alternative: `(i)` button that opens a small popover on click, for mobile and for content users must be able to re-read.
- Don't show tooltips on elements that already have visible, identical text.

## Implementation Guidance

### Semantics decision table
| Trigger | Tooltip role | Wiring |
|---|---|---|
| Icon-only button ("Delete") | Accessible name | `<button aria-labelledby="tip">` or `aria-label="Delete"`; tooltip `aria-hidden` or labelledby target |
| Labelled button + extra hint ("Bold" + "⌘B") | Description | `aria-describedby="tip"` on button; `role="tooltip"` on tip |
| Truncated text | Description | Also expose full text elsewhere (detail view, `title` insufficient alone) |
| Needs links/actions | Not a tooltip | Popover / non-modal dialog |

### Keyboard
| Key | Behavior |
|---|---|
| Tab (focus trigger) | Show tooltip |
| Escape | Hide tooltip; focus stays on trigger |
| Tab away / blur | Hide |
| Enter/Space | Activates the trigger (tooltip may hide) |

### Native vs library
| Option | Support (Sept 2026) | Notes |
|---|---|---|
| `popover="hint"` + `interestfor` + anchor positioning | hint: Chrome/Edge 133+, Firefox 149+, no Safari; interestfor: Chromium 142+ only | Declarative hover/focus/long-press; browser manages delays & a11y mapping; polyfill interestfor and fall back for Safari |
| `popover="hint"` + small JS for hover/focus | Same hint support | Portable middle ground |
| Radix Tooltip, Base UI Tooltip, React Aria `TooltipTrigger`, Ariakit `Tooltip`, Floating UI `useHover`+`useFocus`+`useRole('tooltip')` | All browsers | Delay groups, safe hover, collision positioning |
| `title` attribute | Universal | Only for non-essential, redundant hints; UA-controlled (exempt from 1.4.13) but not keyboard/touch accessible |

## Recommended Workflow
1. Ask: is this info essential? If yes, make it visible inline.
2. Is it interactive? If yes, use a popover.
3. Decide name vs description wiring.
4. Implement with the project's tooltip primitive (or native hint + JS).
5. Configure delays and a provider/group for toolbars.
6. Position with fallbacks; ensure the tooltip doesn't cover the trigger.
7. Test hover, focus, Escape, pointer-onto-tooltip, touch, screen reader.

## Patterns

### Native hint tooltip with JS fallback (React)
```tsx
'use client';
import { useId, useRef } from 'react';

export function HintTooltip({ label, children }: { label: string; children: React.ReactElement }) {
  const id = useId();
  const tip = useRef<HTMLDivElement>(null);
  const closeTimer = useRef<number | undefined>(undefined);
  const show = () => { clearTimeout(closeTimer.current); tip.current?.showPopover?.(); };
  const hide = () => { closeTimer.current = window.setTimeout(() => tip.current?.hidePopover?.(), 120); };
  return (
    <span
      onPointerEnter={show} onPointerLeave={hide} onFocus={show} onBlur={hide}
      onKeyDown={(e) => { if (e.key === 'Escape') tip.current?.hidePopover?.(); }}
      aria-describedby={id}
    >
      {children}
      <div id={id} ref={tip} popover="hint" role="tooltip" className="tip"
           onPointerEnter={show} onPointerLeave={hide}>{label}</div>
    </span>
  );
}
```
```css
.tip { margin: 0; inset: auto; position-area: block-start; margin-block-end: 6px;
  position-try-fallbacks: flip-block; max-inline-size: 32ch; }
```
The pointer handlers on the tooltip keep it hoverable (1.4.13). `popover="hint"` falls back to manual in Safari, which is fine here because JS controls show/hide. Put `aria-describedby` on the focusable child itself in real code (clone the element or accept a render prop), not on the wrapper span. With `interestfor` (Chromium 142+), you can drop the JS handlers after feature detection. Anchor positioning uses an implicit anchor only for invoker-opened popovers, so for JS-opened ones pass `{ source }` or set `anchor-name`.

### Toggletip
```tsx
<button type="button" popoverTarget="tt-vat" aria-label="About VAT">i</button>
<div id="tt-vat" popover="auto" role="status">VAT is included for EU addresses.</div>
```
Click-driven, works on touch, and re-readable. Uses auto popover light dismiss.

### Toolbar delay group (React, Radix)
```tsx
<Tooltip.Provider delayDuration={500} skipDelayDuration={300}>
  <Toolbar>{tools.map(t => <IconButtonWithTooltip key={t.id} {...t} />)}</Toolbar>
</Tooltip.Provider>
```

## Anti-Patterns
- **Essential instructions in tooltips** (password rules): users can't see them while typing. Fix: inline hint text.
- **Hover-only tooltips**: keyboard and touch users miss them. Fix: focus trigger + toggletip on touch.
- **Links inside a tooltip**: unreachable, since the tooltip never takes focus. Fix: popover.
- **Tooltip disappears when moving pointer onto it**: 1.4.13 failure. Fix: hoverable region / grace period / safePolygon.
- **Tooltip on a disabled `<button disabled>`**: no events, no focus. Fix: `aria-disabled="true"` with explanation inline.
- **Double announcement** (`aria-label="Delete"` + `aria-describedby` tooltip "Delete"): noisy. Fix: use one.
- **Auto-hiding after N seconds**: 1.4.13 persistent failure. Fix: hide only on blur/leave/Escape.
- **Using `title` plus custom tooltip**: two tooltips appear. Fix: remove `title`.

## Accessibility
- WCAG 1.4.13 Content on Hover or Focus; 2.1.1 Keyboard; 4.1.2 Name/Role/Value; 2.5.3 Label in Name; 1.4.3 contrast for tooltip text; 1.4.12 text spacing (don't fix heights).
- APG tooltip pattern is marked work-in-progress without full task force consensus. Follow WCAG as the firm requirement.
- Screen readers: `aria-describedby` content is typically read after name/role; test VoiceOver and NVDA.

## Responsive Design
- Touch: no hover; long-press triggers vary (interestfor supports long-press in Chromium). Provide a toggletip or visible labels on touch layouts (`@media (hover: none)`).
- Constrain width (`max-inline-size: 32ch`) and allow wrapping.
- Use logical placement (`block-start`) for RTL correctness.

## Performance
- One tooltip instance per group can be reused instead of mounting hundreds (dense tables).
- Avoid measuring layout on every pointermove; CSS anchor positioning removes JS positioning cost.

## Security
- Don't render untrusted HTML in tooltips; text only.
- Avoid exposing sensitive data (e.g., full account numbers) in hover content that screen sharing reveals.

## Testing
- Playwright: `hover()` → `getByRole('tooltip')` visible; `focus()` → visible; `keyboard.press('Escape')` → hidden and trigger still focused; move mouse from trigger to tooltip → stays open.
- Assert `aria-describedby` points to an existing id, or that the accessible name is correct: `getByRole('button', { name: 'Delete' })`.
- Emulate touch (`hasTouch`) to confirm the toggletip path.
- axe: button-name for icon buttons.

## Tooling
- Native: `popover="hint"`, `interestfor` (Chromium) + npm polyfill, CSS anchor positioning.
- Radix Tooltip (delay 700ms / skip 300ms defaults), Base UI Tooltip (v1.x), React Aria `TooltipTrigger`/`Tooltip`, Ariakit Tooltip, Floating UI React (`useHover`, `useFocus`, `useDismiss`, `useRole`, `safePolygon`, `FloatingDelayGroup`).

## Framework Notes
- **React (Vite SPA)**: shadcn/ui Tooltip (Radix) needs a `TooltipProvider` near the root for delay grouping. Custom trigger components must accept `ref` (React 19 prop) and spread props so `asChild` can attach handlers and ARIA. Don't wrap `disabled` buttons directly: pointer events don't fire, so wrap in a span with an explanation instead.
- **Next.js (App Router)**: Tooltip components are Client Components (`'use client'`). Put `TooltipProvider` in a client `providers.tsx` rendered by the root layout, keeping the layout itself a Server Component. Tooltip content is portaled after hydration, so never render tooltip-only information that the server HTML lacks. Keep the icon button's `aria-label` in server-rendered markup so it's accessible before hydration.

## AI Agent Guidance
- DO check whether text should be visible instead of a tooltip before adding one.
- DO ensure icon-only buttons have accessible names independent of the tooltip rendering.
- DON'T place interactive content in tooltips or rely on `title` for essential info.
- DON'T use `interestfor`/`hint` without fallback.
- Verify: hover + focus open; Escape closes without moving focus; pointer can move onto tooltip; no auto-timeout; touch alternative exists; screen reader reads name/description once.

## Examples
shadcn/ui Tooltip (Radix) on an icon button, the recommended default:
```tsx
'use client';
import { Tooltip, TooltipTrigger, TooltipContent } from '@/components/ui/tooltip';

export function ArchiveButton({ onArchive }: { onArchive: () => void }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button type="button" aria-label="Archive" onClick={onArchive}><ArchiveIcon aria-hidden /></button>
      </TooltipTrigger>
      <TooltipContent side="top">Archive <kbd>E</kbd></TooltipContent>
    </Tooltip>
  );
}
```

Floating UI React tooltip for custom builds (key parts):
```tsx
const [open, setOpen] = useState(false);
const { refs, floatingStyles, context } = useFloating({
  open, onOpenChange: setOpen, placement: 'top',
  middleware: [offset(6), flip(), shift({ padding: 8 })],
  whileElementsMounted: autoUpdate,
});
const hover = useHover(context, { move: false, delay: { open: 500, close: 100 }, handleClose: safePolygon() });
const focus = useFocus(context);
const dismiss = useDismiss(context);
const role = useRole(context, { role: 'tooltip' });
const { getReferenceProps, getFloatingProps } = useInteractions([hover, focus, dismiss, role]);
return (<>
  <button ref={refs.setReference} {...getReferenceProps()} aria-label="Archive"><ArchiveIcon aria-hidden /></button>
  {open && <div ref={refs.setFloating} style={floatingStyles} {...getFloatingProps()}>Archive</div>}
</>);
```
Note: when the tooltip duplicates `aria-label`, `useRole('tooltip')` adds `aria-describedby`. Consider omitting the role's describedby to avoid a double read.

## Related Skills
- [popovers](../popovers/Skill.md): interactive alternative and toggletips
- [floating-element-positioning](../floating-element-positioning/Skill.md): placement and collision
- [buttons-and-actions](../buttons-and-actions/Skill.md): icon button naming
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md): hover-less devices
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md): concise tooltip text
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md): 1.4.13

## Sources
- [WAI-ARIA APG: Tooltip Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/) — Official — role, Escape, no focus (WIP pattern)
- [WCAG 2.2 Understanding 1.4.13](https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html) — Official — dismissible/hoverable/persistent
- [NN/g: Tooltip Guidelines](https://www.nngroup.com/articles/tooltip-guidelines/) — Research — when to use, mobile
- [Chrome for Developers: popover=hint](https://developer.chrome.com/blog/popover-hint) — Official — hint behavior
- [web-features: interest invokers](https://web-platform-dx.github.io/web-features-explorer/features/interest-invokers/) — Official — support
- [Radix Tooltip](https://www.radix-ui.com/primitives/docs/components/tooltip) — Open Source — delay defaults, keyboard
- [Floating UI useHover](https://floating-ui.com/docs/useHover) — Open Source — safePolygon, delay
- [GoogleChrome modern-web-guidance: interest-triggered tooltips](https://github.com/GoogleChrome/modern-web-guidance/blob/main/skills/modern-web-guidance/guides/ui-behaviors/interest-triggered-tooltips.md) — Community agent skill — native tooltip recipe

## License / Usage Notes
Summarized in original wording; code original. Radix/Floating UI MIT; React Aria Apache-2.0.

## Quality Tier
A — official + research + library defaults verified; APG pattern itself is still WIP.

## Status
Active

## Last Verified
2026-09-15
