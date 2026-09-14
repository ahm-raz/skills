# Ariakit

## Summary
Ariakit is a low-level, unstyled React toolkit for building accessible widgets. It is built around composable components plus explicit **stores** (`useSelectStore`, `useComboboxStore`, `useMenuStore`). `@ariakit/react` is at 0.4.40 (September 2026, MIT) with frequent patch releases but still pre-1.0 versioning. Its strength is fine-grained composite-widget control (combobox + select + tabs combinations, virtual focus) with a `render` prop composition model.

## Category
UI Libraries

## Subcategories
Headless components, stores, composite widgets, virtual focus, combobox/select/menu, render prop, data attributes, CSS variables

## Problem It Solves
Some widgets need combinations other libraries don't support: a select with a searchable combobox inside, a menu with nested combobox filtering, a tab list controlling a combobox list, toolbars with composite navigation. Ariakit exposes the underlying state stores so you can wire these combinations while keeping correct ARIA semantics.

## When To Use
- Custom, complex composite widgets (searchable select, command menus with tabs, tag inputs) where Radix/Base UI APIs are too opinionated.
- Design systems that want low-level building blocks with explicit state management.
- Teams comfortable with pre-1.0 semver (0.4.x) and reading source/examples.

## When Not To Use
- Teams wanting a large pre-built component set or styled starter (use shadcn/ui, Mantine, HeroUI).
- Projects needing date pickers, tables or i18n formatting (use React Aria).
- Organizations that require 1.0+ semver guarantees for procurement.

## Core Principles
1. **Stores own state**: create a store with a hook and pass it to components (`store={select}`), or rely on implicit context from providers.
2. **Components render semantic elements**: change them with `render` (`render={<a href="..." />}` or `render={(props) => <Custom {...props} />}`).
3. **Style via stable selectors**: `[aria-expanded]`, `[aria-checked]`, `[aria-disabled]`, `[data-active-item]`, `[data-focus-visible]`, `[data-enter]`, `[data-leave]`. Role attributes are not a public API.
4. **CSS variables for layout**: `--popover-anchor-width`, `--popover-available-height`, `--dialog-viewport-height`, `--scrollbar-width`.
5. **Virtual focus where appropriate**: comboboxes keep DOM focus on the input and move the active item via `aria-activedescendant`.

## Best Practices
- Use provider components (`SelectProvider`, `ComboboxProvider`) for simple cases. Create stores explicitly when wiring multiple widgets together.
- Read store state with `useStoreState(store, "value")` (or the store's hooks) rather than subscribing to everything, to avoid re-renders.
- Animate with `[data-enter]`/`[data-leave]` and let Ariakit wait for transitions before unmounting.
- Filter large combobox lists with `useDeferredValue` (React 18+) or `startTransition` to keep typing responsive.
- Use `--popover-anchor-width` to match popover width to the trigger.
- Pin exact versions. 0.4.x patches can include behavior changes. Read the Updates page before bumping.

## Implementation Guidance
```bash
pnpm add @ariakit/react
```
| Need | Ariakit building blocks |
|---|---|
| Searchable select | `SelectProvider` + `ComboboxProvider` + `Combobox` inside `SelectPopover` |
| Autocomplete | `ComboboxProvider`, `Combobox`, `ComboboxPopover`, `ComboboxItem` |
| Menu with submenu | `MenuProvider`, `MenuButton`, `Menu`, `MenuItem`, nested `MenuProvider` |
| Accessible toolbar | `Toolbar`, `ToolbarItem` (composite roving focus) |
| Dialog | `Dialog`, `DialogHeading`, `DialogDismiss` (`open`/`onClose`) |
| Tooltip / Hovercard | `TooltipProvider`, `HovercardProvider` |

Ariakit Plus (paid) provides additional examples. The core library is MIT. Treat Plus-only example code as licensed content.

## Recommended Workflow
1. Find the closest official example on ariakit.com. Examples are the de facto docs for complex combos.
2. Choose between implicit providers and explicit stores based on how many widgets share state.
3. Implement styling with data attributes and CSS variables.
4. Verify screen reader announcements (active descendant) and keyboard paths.
5. Pin the version and add Playwright tests before upgrading.

## Patterns
- **Select with search**: wrap `SelectProvider` around `ComboboxProvider` with `resetValueOnHide`. Filter items by the combobox value.
- **Controlled value synced to URL**: `SelectProvider value={v} setValue={setV}` backed by `nuqs` or router state.
- **Render as link**: `<MenuItem render={<Link href="/billing" />}>Billing</MenuItem>`.
- **Composite grid**: `Composite` + `CompositeRow` + `CompositeItem` for 2D arrow-key navigation (calendars, emoji pickers).

## Anti-Patterns
- **Styling via `[role=option]` selectors**: not public API. Use `[data-active-item]` or classNames.
- **Moving DOM focus into combobox items**: breaks virtual focus and typing. Keep the default.
- **Creating stores inside loops or conditionals**: violates the hooks rules. Create them at component top level.
- **Assuming 1.0 stability**: unpinned `^0.4.x` upgrades can shift behavior. Pin and test.

## Accessibility
- High-quality WAI-ARIA implementations with careful screen-reader testing, including VoiceOver quirks around `aria-activedescendant`.
- `data-focus-visible` provides keyboard-only focus styling (WCAG 2.4.7).
- Dialog handles focus trap, return focus and `aria-modal`. `--dialog-viewport-height` helps with mobile virtual keyboards.
- Your responsibility: labels (`SelectLabel`, `aria-label`), contrast, reduced-motion.

## Responsive Design
- Popovers are positioned with Floating UI and use available height/width CSS variables to fit small screens.
- For mobile, render `SelectPopover`/`Dialog` full-screen with media queries. Behavior is unchanged.

## Performance
- Small per-component footprint and tree-shakeable ESM.
- Store subscriptions are granular. Select only the state you need.
- For long lists, virtualize item rendering (e.g. TanStack Virtual). Ariakit supports rendering only visible items with some manual wiring.

## Security
- No HTML injection APIs. Sanitize user-supplied labels if they're rendered as HTML.
- MIT. Maintained primarily by its creator (Diego Haz) with community contributions, so there is some single-maintainer concentration risk.

## Testing
- `@ariakit/test` provides user-event-like helpers that model Ariakit's focus behavior (check the current package status).
- Testing Library role queries: combobox `getByRole("combobox")`, options `getByRole("option")`.
- Playwright for virtual-focus flows and screen-reader-sensitive scenarios.

## Tooling
- `@ariakit/react` 0.4.40 (MIT). 2026 releases include January 12 and March 4 and continue through September.
- Ariakit Plus (paid examples/support).
- Pairs well with Tailwind v4 via `data-[active-item]:` and `aria-expanded:` variants.

## Framework Notes
- **Next.js App Router**: all components use hooks, so put wrappers in `"use client"` files. SSR output is stable (ids via `useId`). Keep large option data fetched in Server Components and passed as props.
- **React (Vite SPA)**: no setup required.
- React 17-19 supported per peer range.

## AI Agent Guidance
- DO base implementations on official Ariakit examples. APIs like `resetValueOnHide`, `setValueOnClick` and `store` props are easy to hallucinate, so verify them.
- DO style with data/aria attribute selectors, not roles.
- DON'T mix Ariakit and another headless library inside one composite widget.
- Verify before done: arrow keys move the active item while focus stays in the input, Escape closes, the selected value is announced, and the version is pinned.

## Examples
```tsx
"use client";
import * as Ariakit from "@ariakit/react";
import { useDeferredValue, useMemo, useState } from "react";

export function CountryCombobox({ countries }: { countries: string[] }) {
  const [search, setSearch] = useState("");
  const deferred = useDeferredValue(search);
  const matches = useMemo(
    () => countries.filter((c) => c.toLowerCase().includes(deferred.toLowerCase())).slice(0, 100),
    [countries, deferred],
  );

  return (
    <Ariakit.ComboboxProvider setValue={setSearch}>
      <Ariakit.ComboboxLabel className="text-sm font-medium">Country</Ariakit.ComboboxLabel>
      <Ariakit.Combobox
        placeholder="Search countries"
        className="h-9 w-64 rounded-md border px-3 data-[focus-visible]:ring-2"
      />
      <Ariakit.ComboboxPopover
        gutter={6}
        sameWidth
        className="max-h-[min(var(--popover-available-height),300px)] overflow-auto rounded-md border bg-popover p-1"
      >
        {matches.length ? (
          matches.map((c) => (
            <Ariakit.ComboboxItem key={c} value={c} className="rounded px-2 py-1.5 data-[active-item]:bg-muted" />
          ))
        ) : (
          <div className="px-2 py-1.5 text-sm text-muted-foreground">No results</div>
        )}
      </Ariakit.ComboboxPopover>
    </Ariakit.ComboboxProvider>
  );
}
```

## Related Skills
- [select-and-combobox](../select-and-combobox/Skill.md): combobox UX
- [search-and-autocomplete](../search-and-autocomplete/Skill.md): autocomplete patterns
- [dropdown-menus](../dropdown-menus/Skill.md): menus
- [keyboard-navigation](../keyboard-navigation/Skill.md): composite widget keys
- [aria-authoring-practices](../aria-authoring-practices/Skill.md): patterns
- [base-ui](../base-ui/Skill.md): alternative headless library
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [Ariakit styling guide](https://ariakit.com/guide/styling): Official. Selectors, CSS variables, render prop
- [Ariakit updates](https://ariakit.org/updates): Official. Release cadence
- [@ariakit/react registry metadata](https://registry.npmjs.org/@ariakit/react/latest): Official. Version 0.4.40, peers
- [@ariakit/react on npm](https://www.npmjs.com/package/@ariakit/react): Official. Publish recency
- [ariakit/ariakit releases](https://github.com/ariakit/ariakit/releases): Open Source. 2026 releases

## License / Usage Notes
Ariakit core is MIT. Ariakit Plus examples are commercial; don't paste Plus-only code into open-source repos. Content here is summarized.

## Quality Tier
B: official sources and active releases, but pre-1.0 versioning, some API names (test package, virtualization wiring) are not re-verified, and the ecosystem is smaller.

## Status
Active

## Last Verified
2026-09-15
