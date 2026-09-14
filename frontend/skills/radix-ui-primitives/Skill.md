# Radix UI Primitives

## Summary
Radix Primitives is an unstyled, accessible React component library maintained by WorkOS. It ships as the unified `radix-ui` package (v1.6.7, September 2026) and the legacy per-component `@radix-ui/react-*` packages. It popularized the compound-component + `asChild` composition model and powered shadcn/ui until Base UI became shadcn's default in July 2026. It remains mature and maintained, with regular 2026 releases focused on React 19 stability and tree-shaking.

## Category
UI Libraries

## Subcategories
Headless components, asChild/Slot composition, data-state styling, portals, dismissable layers, focus scopes, React 19 compatibility

## Problem It Solves
Building accessible dialogs, menus, popovers, selects and tooltips correctly is hard: focus trapping, dismiss layers, typeahead, collision-aware positioning and screen-reader semantics. Radix encapsulates these behaviors while leaving 100% of the styling to you.

## When To Use
- Existing shadcn/ui (Radix base) projects, and design systems already built on Radix.
- Teams that want a stable, widely deployed primitive layer with a large body of community knowledge.
- Custom design systems styled with Tailwind, CSS Modules or CSS-in-JS.

## When Not To Use
- New shadcn projects without Radix-specific needs. Base UI is the actively expanding default and has more components (Combobox, NumberField, OTP, Toast, Drawer).
- Apps needing rich date/time, i18n number parsing or drag and drop. Use React Aria.
- Teams wanting pre-styled components. Use Mantine, MUI or Chakra.

## Core Principles
1. **Compound parts**: `Root`, `Trigger`, `Portal`, `Overlay`, `Content`, `Title`, `Description`, `Close`.
2. **`asChild` merges behavior into your element** via Slot. The child must forward refs and spread props.
3. **Style by state attributes**: `data-state="open|closed"`, `data-side`, `data-align`, `data-disabled`, `data-highlighted`.
4. **Controlled or uncontrolled**: `open`/`onOpenChange`, `value`/`onValueChange`, `defaultOpen`/`defaultValue`.
5. **Portals + DismissableLayer** handle stacking, outside click and Escape consistently across nested overlays.

## Best Practices
- Prefer the unified package: `import { Dialog, DropdownMenu } from "radix-ui"`. For shadcn projects, migrate with `shadcn migrate radix`, then remove the old `@radix-ui/react-*` deps.
- Always render `Dialog.Title` (visually hidden if needed) and `Dialog.Description` or `aria-describedby={undefined}`. Radix warns in dev when these are missing.
- Animate with CSS keyframes keyed on `data-state` and `data-side`. Radix's Presence waits for exit animations to finish.
- Use CSS variables exposed on Content (`--radix-popover-trigger-width`, `--radix-dropdown-menu-content-available-height`, transform-origin variables) for sizing.
- Use `forceMount` only with an animation library that controls presence (e.g. Motion `AnimatePresence`).
- Use `modal={false}` on DropdownMenu/Popover when triggering dialogs from menu items, to avoid pointer-events lock conflicts. Alternatively, control the dialog state outside the menu.

## Implementation Guidance
```bash
pnpm add radix-ui
```
Composition and state styling:
```tsx
"use client";
import { Popover } from "radix-ui";

export function FilterPopover({ children }: { children: React.ReactNode }) {
  return (
    <Popover.Root>
      <Popover.Trigger asChild>
        <button className="rounded-md border px-3 py-1.5 data-[state=open]:bg-muted">Filters</button>
      </Popover.Trigger>
      <Popover.Portal>
        <Popover.Content
          sideOffset={6}
          align="start"
          className="z-50 w-[var(--radix-popover-trigger-width)] min-w-64 rounded-lg border bg-popover p-3 shadow-md
                     data-[state=open]:animate-in data-[state=closed]:animate-out"
        >
          {children}
          <Popover.Arrow className="fill-popover" />
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}
```

| Need | Radix part/prop |
|---|---|
| Custom trigger element | `asChild` on Trigger |
| Keep content in DOM for animation | `forceMount` |
| Prevent close on outside click | `onPointerDownOutside={(e) => e.preventDefault()}` |
| Control initial focus | `onOpenAutoFocus={(e) => { e.preventDefault(); ref.current?.focus(); }}` |
| Restore focus elsewhere | `onCloseAutoFocus` |

## Recommended Workflow
1. Pick the primitive matching the APG pattern (a Menu is not a Popover with buttons).
2. Build a styled wrapper in `components/ui/*` that exposes your API and keeps Title/Description required.
3. Style via `data-*` attributes and CSS variables. Add enter/exit animations.
4. Test keyboard (Tab, Escape, arrows, typeahead) and screen-reader names.
5. Track releases. Upgrade the unified package as a single unit.

## Patterns
- **Slot-based polymorphism**: `Slot` from `radix-ui` for your own `asChild` components (`const Comp = asChild ? Slot.Root : "button"`).
- **Dialog from menu item**: control dialog state in the parent. `DropdownMenu.Item onSelect={() => setOpen(true)}` then render the `Dialog` outside the menu.
- **Tooltip provider**: one `Tooltip.Provider delayDuration={300}` at app root rather than per tooltip.
- **Form-adjacent primitives**: Checkbox, Switch, RadioGroup and Select render hidden native inputs for form submission (`name` prop).

## Anti-Patterns
- **`asChild` on a component that doesn't forward refs/props**: behavior silently breaks. Ensure the child spreads `...props` and accepts `ref` (ref-as-prop in React 19).
- **Nesting interactive elements** (`<Trigger><button/></Trigger>` without `asChild`) produces a button inside a button and invalid HTML.
- **Mixing old `@radix-ui/react-*` and `radix-ui` versions**: duplicate contexts break nested layers. Standardize on one.
- **Overriding focus management** with `e.preventDefault()` everywhere breaks WCAG 2.4.3. Only redirect focus to a sensible target.
- **Using Tooltip for essential info or on disabled buttons**: not reachable by touch or keyboard. Use a visible hint or Popover.

## Accessibility
- Implements WAI-ARIA APG patterns: dialog/alertdialog focus trap and return, menu roving tabindex and typeahead, listbox semantics for Select, and Tooltip on focus and hover.
- `DismissableLayer` provides Escape to close. `FocusScope` traps and loops focus in modals.
- `aria-hidden` is applied to outside content while a modal is open (`hideOthers`).
- Your responsibility: visible focus styles, contrast, accessible names on icon triggers, reduced-motion for animations.

## Responsive Design
- `Popover`/`DropdownMenu` content uses Floating UI collision handling (`avoidCollisions`, `collisionPadding`).
- On small screens swap Dialog for a bottom sheet (Base UI Drawer or a Dialog styled as a sheet). Radix has no native drawer.
- Use `--radix-*-available-height` to cap menu height on short viewports.

## Performance
- The unified package is tree-shakeable. The July 2026 releases added `@__PURE__` annotations and per-primitive subpath entry points.
- Each primitive is small, but heavy overlays mount on open. Keep large content lazy inside `Content`.
- Avoid rendering hundreds of `Tooltip.Root` in tables. Use a single delegated tooltip or `title` alternatives.

## Security
- No HTML injection surface of its own. Sanitize any user HTML rendered inside content.
- Pin versions through the lockfile. Radix is a high-download package (~9.5M/week), so watch advisories (Snyk rates it healthy).

## Testing
- Testing Library: `userEvent.click(trigger)`, then `await screen.findByRole("menu")`. Portals render into `document.body`.
- jsdom lacks `PointerEvent`/`ResizeObserver` features some primitives use. Polyfill `ResizeObserver` and `hasPointerCapture` in setup for Select/Slider.
- Prefer Playwright for full keyboard/focus flows.

## Tooling
- `radix-ui` 1.6.7 (MIT, WorkOS), with 2026 releases on June 6, June 30, July 6 and July 20.
- Preview primitives: `unstable_OneTimePasswordField`, `unstable_PasswordToggleField` (2025, still unstable-prefixed).
- Radix Themes (styled layer from the same team) exists but is not covered here.
- `tw-animate-css` for `animate-in`/`animate-out` utilities with Tailwind v4.

## Framework Notes
- **Next.js App Router**: all Radix parts use hooks/context, so wrappers need `"use client"`. The unified package does not add directives for you. Server Components can render your client wrappers with serializable props. `useId` makes ARIA ids hydration-safe.
- **React (Vite SPA)**: no special setup. Mount a single `Tooltip.Provider` at root.
- React 19 / 19.2: supported. The June-July 2026 releases fixed ref-callback re-render loops and 19.2 event-handler issues, so stay on the latest.

## AI Agent Guidance
- Check `package.json` for `radix-ui` vs `@radix-ui/react-*` and match the existing import style.
- Use `asChild` (not `render`) in Radix projects. Don't confuse with Base UI.
- Always include Title/Description in Dialog/AlertDialog.
- Don't recommend migrating to Base UI unless asked. shadcn states Radix needs no migration.
- Before declaring done, verify there are no dev-console a11y warnings, Escape and outside click behave, focus returns to the trigger, and animations don't block unmount.

## Examples
```tsx
"use client";
import { DropdownMenu, Dialog } from "radix-ui";
import { useState } from "react";

export function RowActions({ onDelete }: { onDelete: () => void }) {
  const [confirmOpen, setConfirmOpen] = useState(false);
  return (
    <>
      <DropdownMenu.Root>
        <DropdownMenu.Trigger asChild>
          <button aria-label="Row actions" className="size-8 rounded-md hover:bg-muted">⋯</button>
        </DropdownMenu.Trigger>
        <DropdownMenu.Portal>
          <DropdownMenu.Content align="end" className="min-w-40 rounded-md border bg-popover p-1">
            <DropdownMenu.Item className="rounded px-2 py-1.5 data-[highlighted]:bg-muted">Edit</DropdownMenu.Item>
            <DropdownMenu.Item
              className="rounded px-2 py-1.5 text-destructive data-[highlighted]:bg-muted"
              onSelect={() => setConfirmOpen(true)}
            >
              Delete
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Portal>
      </DropdownMenu.Root>

      <Dialog.Root open={confirmOpen} onOpenChange={setConfirmOpen}>
        <Dialog.Portal>
          <Dialog.Overlay className="fixed inset-0 bg-black/50" />
          <Dialog.Content className="fixed left-1/2 top-1/2 w-96 -translate-x-1/2 -translate-y-1/2 rounded-lg bg-background p-6">
            <Dialog.Title className="font-semibold">Delete row?</Dialog.Title>
            <Dialog.Description className="text-sm text-muted-foreground">This cannot be undone.</Dialog.Description>
            <div className="mt-4 flex justify-end gap-2">
              <Dialog.Close asChild><button>Cancel</button></Dialog.Close>
              <button onClick={() => { onDelete(); setConfirmOpen(false); }}>Delete</button>
            </div>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </>
  );
}
```

## Related Skills
- [shadcn-ui](../shadcn-ui/Skill.md): main consumer of Radix
- [base-ui](../base-ui/Skill.md): successor-style alternative from overlapping authors
- [accessible-dialogs](../accessible-dialogs/Skill.md): dialog requirements
- [dropdown-menus](../dropdown-menus/Skill.md): menu patterns
- [popovers](../popovers/Skill.md): popover behavior
- [floating-element-positioning](../floating-element-positioning/Skill.md): collision handling
- [aria-authoring-practices](../aria-authoring-practices/Skill.md): APG patterns implemented
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): Radix vs Base UI vs React Aria

## Sources
- [Radix Primitives releases](https://www.radix-ui.com/primitives/docs/overview/releases): Official. 2025-2026 release content
- [radix-ui on npm](https://www.npmjs.com/package/radix-ui): Official. Unified package, download volume
- [radix-ui registry metadata](https://registry.npmjs.org/radix-ui/latest): Official. Version 1.6.7, peer ranges
- [shadcn: Unified Radix UI package](https://ui.shadcn.com/docs/changelog/2026-02-radix-ui): Official. Migration command and imports
- [shadcn: Base UI as default](https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default): Official. "Radix is a mature, tested library", no migration needed
- [Radix on GitHub](https://github.com/radix-ui): Open Source. MIT, WorkOS ownership
- [Snyk radix-ui health](https://security.snyk.io/package/npm/radix-ui): Community. Maintenance rated healthy

## License / Usage Notes
MIT, Copyright WorkOS. This skill is an original summary; no documentation text is copied.

## Quality Tier
A: official sources and verified 2026 release activity, but a slower-growing component set than Base UI and some maintenance-perception concerns in the community.

## Status
Active (mature; no longer shadcn's default base)

## Last Verified
2026-09-15
