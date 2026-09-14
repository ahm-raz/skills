# Headless UI

## Summary
Headless UI (`@headlessui/react`) is Tailwind Labs' unstyled, accessible component set: Menu, Listbox, Combobox, Dialog, Popover, Disclosure, Tabs, Switch, RadioGroup, Checkbox, Field/Input/Select/Textarea and more. v2 (2024) added built-in anchor positioning (Floating UI), form components and a data-attribute transition API. It is the foundation of Tailwind Plus templates and the Catalyst UI kit. As of September 2026 the latest version is still 2.2.10. It is stable and React 19-compatible, but release activity is low.

## Category
UI Libraries

## Subcategories
Headless components, Tailwind Labs, Catalyst, anchor positioning, data-attribute transitions, form fields, virtualization in Combobox

## Problem It Solves
It gives Tailwind users a small, well-documented set of accessible interactive primitives that match Tailwind Plus/Catalyst examples exactly, with state exposed as data attributes (`data-open`, `data-focus`, `data-selected`) for Tailwind variants.

## When To Use
- Projects built on Tailwind Plus (formerly Tailwind UI) templates or Catalyst, which are already written against Headless UI.
- Small-to-medium apps that need a focused set of accessible widgets and prefer Tailwind Labs' API style.
- Combobox with built-in virtualization (`virtual` prop using TanStack Virtual) for long option lists.

## When Not To Use
- New design systems needing broad coverage (Toast, Tooltip, Slider, NumberField, DatePicker, Drawer). Use Base UI, React Aria or shadcn/ui.
- Teams requiring frequent upstream fixes. Releases have been sparse since 2.2.x.
- Projects that are not Tailwind-based, where Headless UI's ergonomics offer little advantage.

## Core Principles
1. **Unstyled components with data attributes**: `data-open`, `data-active`, `data-focus`, `data-hover`, `data-selected`, `data-disabled`, `data-checked`, `data-closed`.
2. **`as` prop for element polymorphism** (`as="a"`, `as={Fragment}`), plus render props exposing state (`{({ open }) => ...}`).
3. **Built-in anchoring**: `anchor="bottom start"` on MenuItems/ListboxOptions/PopoverPanel/ComboboxOptions, with `--anchor-gap`, `--anchor-padding`, `--button-width` CSS variables.
4. **Transitions via data attributes**: the `transition` prop on panels plus `data-closed:`, `data-enter:`, `data-leave:` utilities (v2.1+).
5. **Form integration**: `Field`, `Label`, `Description`, `Fieldset`, `Legend` wire ids and ARIA automatically. `name` props render hidden inputs.

## Best Practices
- Use Tailwind v4 data variants directly: `data-focus:bg-muted`, `data-closed:opacity-0`, `data-selected:font-semibold`.
- Prefer the `anchor` prop over manual positioning. Use `[--anchor-gap:--spacing(1)]` utility syntax to set gaps.
- Use `Field` wrappers so labels and descriptions associate automatically.
- For long Combobox lists, use `virtual={{ options }}` rather than rendering thousands of nodes.
- Use `Dialog` + `DialogPanel` + `DialogTitle`. Close via `onClose`, and the `transition` prop handles enter/leave.
- Use `CloseButton` or the `close` render prop inside Popover panels for links that should dismiss.

## Implementation Guidance
```bash
pnpm add @headlessui/react
```
Dependencies (2.2.10): `@floating-ui/react`, `@react-aria/focus`, `@react-aria/interactions`, `@tanstack/react-virtual`. Peers: React 18/19.

| Need | Component |
|---|---|
| Action menu | `Menu`, `MenuButton`, `MenuItems`, `MenuItem` |
| Single/multi select | `Listbox` (`multiple`) |
| Autocomplete | `Combobox` (+ `virtual`) |
| Modal | `Dialog`, `DialogPanel`, `DialogTitle`, `DialogBackdrop` |
| Disclosure/accordion | `Disclosure` |
| Forms | `Field`, `Label`, `Input`, `Select`, `Textarea`, `Checkbox`, `Switch`, `RadioGroup` |
| Missing (use other libs) | Toast, Tooltip, Slider, DatePicker, NumberField, Drawer |

## Recommended Workflow
1. Check whether the component exists in Headless UI. If not, choose a companion library (sonner for toasts, Base UI or React Aria for others).
2. Start from Tailwind Plus/Catalyst examples if licensed, otherwise the headlessui.com examples.
3. Style with data variants. Add the `transition` prop for animations.
4. Verify keyboard behavior and focus return.
5. Monitor the repo. Plan a migration path if gaps block you.

## Patterns
- **Anchored menu**: `<MenuItems anchor="bottom end" className="[--anchor-gap:4px] w-52 ...">`.
- **Link menu items**: `<MenuItem><a href="/settings" className="block data-focus:bg-muted">Settings</a></MenuItem>` or `as={Link}`.
- **Controlled dialog**: `<Dialog open={open} onClose={setOpen}>` with `DialogBackdrop transition`.
- **Catalyst wrapper layer**: keep Catalyst's `components/*.tsx` as the design-system layer and treat Headless UI as its engine.

## Anti-Patterns
- **Using v1 APIs** (`Transition.Child` everywhere, `Menu.Items` dot notation, `@headlessui/react` v1 `Popover.Panel` positioning by hand) in v2 code. Use v2 named exports and `anchor`/`transition`.
- **Wrapping `MenuItem` content in a `<button>` inside another button**: invalid nesting. Pass `as` or a single interactive child.
- **Relying on it for components it doesn't have**, which leads to hand-rolled tooltips/toasts. Use maintained libraries instead.
- **Assuming active maintenance**: pin the version and have a contingency plan.

## Accessibility
- Implements APG patterns for menu, listbox, combobox, dialog, tabs, disclosure, switch and radio group. Focus management uses `@react-aria/focus` and interactions.
- `data-focus` is keyboard-aware (use it for focus-visible styling).
- Dialog traps focus and restores it. Adds `inert`/`aria-hidden` outside.
- Your responsibility: visible focus, contrast, labels on icon-only buttons, reduced motion (`motion-reduce:transition-none`).

## Responsive Design
- Anchored panels flip and shift to stay in view. `--anchor-max-height` constrains scrolling lists.
- For mobile, render `DialogPanel` as a bottom sheet via responsive classes. There is no swipe-to-dismiss built in.

## Performance
- Moderate bundle. Floating UI and React Aria focus/interaction packages are included even if you use one component (tree-shaking limits this, but shared deps remain).
- `Combobox virtual` prevents large DOM trees.
- Portaled panels mount on open only (unless `static`/`unmount={false}`).

## Security
- No HTML injection APIs. MIT, Tailwind Labs.
- Low release cadence means dependency updates (Floating UI, React Aria packages) lag. Audit transitive advisories.

## Testing
- Testing Library: `getByRole("button", { name })`, then `click`, then `findByRole("menu")`.
- jsdom: some anchor/positioning features need `ResizeObserver` and `getBoundingClientRect` stubs.
- Playwright for transition-dependent open/close flows (wait for `data-closed` to disappear).

## Tooling
- `@headlessui/react` 2.2.10 (MIT). `@headlessui/vue` 1.7.23 exists but is out of scope.
- Catalyst (Tailwind Plus, commercial license): an application UI kit built on Headless UI v2.
- `@headlessui/tailwindcss` plugin (legacy v3-era variants; v2 data attributes work natively with Tailwind v4).

## Framework Notes
- **Next.js App Router**: components are client-side, so add `"use client"` to wrappers. Render Catalyst/Headless UI shells inside client components and pass server data as props. v2.2.10 fixed Portal rendering during hydration, so stay on the latest.
- **React (Vite SPA)**: drop-in.
- React 19: supported via peers (`^18 || ^19`).

## AI Agent Guidance
- DO use v2 named exports (`MenuButton`, `ListboxOptions`) and `anchor`/`transition` props. Many training examples are v1.
- DO check for Catalyst/Tailwind Plus files before creating new components, and reuse them.
- DON'T add Headless UI to a project already using Radix/Base UI/React Aria.
- Flag the maintenance cadence when recommending it for new projects.
- Verify before done: keyboard open/close, focus return, anchor positioning on small viewports, no v1 imports.

## Examples
```tsx
"use client";
import { Listbox, ListboxButton, ListboxOption, ListboxOptions, Field, Label } from "@headlessui/react";

type Person = { id: number; name: string };

export function AssigneeSelect({ people, value, onChange }: { people: Person[]; value: Person; onChange: (p: Person) => void }) {
  return (
    <Field className="flex flex-col gap-1">
      <Label className="text-sm font-medium">Assignee</Label>
      <Listbox value={value} onChange={onChange} by="id" name="assignee">
        <ListboxButton className="h-9 rounded-md border px-3 text-left data-focus:ring-2">{value.name}</ListboxButton>
        <ListboxOptions
          anchor="bottom start"
          transition
          className="w-(--button-width) rounded-md border bg-white p-1 shadow [--anchor-gap:4px]
                     transition duration-100 data-closed:opacity-0"
        >
          {people.map((p) => (
            <ListboxOption key={p.id} value={p} className="rounded px-2 py-1.5 data-focus:bg-gray-100 data-selected:font-semibold">
              {p.name}
            </ListboxOption>
          ))}
        </ListboxOptions>
      </Listbox>
    </Field>
  );
}
```

## Related Skills
- [tailwind-component-kits](../tailwind-component-kits/Skill.md): Tailwind Plus/Catalyst context
- [tailwind-css-v4](../tailwind-css-v4/Skill.md): data variants
- [select-and-combobox](../select-and-combobox/Skill.md): Listbox/Combobox UX
- [accessible-dialogs](../accessible-dialogs/Skill.md): Dialog
- [base-ui](../base-ui/Skill.md): broader actively developed alternative
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): when to pick Headless UI

## Sources
- [Headless UI v2.0 announcement](https://tailwindcss.com/blog/headless-ui-v2): Official. Anchor positioning, form components, checkbox
- [tailwindlabs/headlessui](https://github.com/tailwindlabs/headlessui): Open Source. Packages, MIT
- [Headless UI releases](https://github.com/tailwindlabs/headlessui/releases): Open Source. 2.2.x release notes
- [@headlessui/react registry metadata](https://registry.npmjs.org/@headlessui/react/latest): Official. Version 2.2.10, deps and peers
- [Catalyst docs](https://catalyst.tailwindui.com/docs): Official. Catalyst built on Headless UI
- [Tailwind Plus changelog](https://tailwindcss.com/plus/changelog): Official. Template updates using the v2.1 transition API

## License / Usage Notes
Headless UI is MIT. Catalyst and Tailwind Plus templates are commercially licensed; don't redistribute their source. Summarized content only.

## Quality Tier
B: official and accurate, but release cadence is low (2.2.10 still latest as of September 2026) and component coverage is narrow, which limits long-term value.

## Status
Active (low release activity; stable)

## Last Verified
2026-09-15
