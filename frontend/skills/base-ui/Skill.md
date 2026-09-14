# Base UI

## Summary
Base UI (`@base-ui/react`) is an unstyled, accessible React component library from the creators of Radix, Floating UI and Material UI, maintained by MUI. v1.0 shipped December 11, 2025, and it reached v1.8.0 on September 4, 2026. It uses a `render` prop for composition, state-driven `className`/`style` functions, and data attributes. Since July 2026 it is the default primitive layer for shadcn/ui, and Material UI is building new components on it.

## Category
UI Libraries

## Subcategories
Headless components, render prop composition, useRender/mergeProps, Combobox, Drawer, Toast, NumberField, OTPField, Floating UI positioning

## Problem It Solves
It provides a single, actively expanding, well-funded headless layer with components Radix lacks (Combobox, Autocomplete, NumberField, OTPField, Toast, Drawer, Meter, Menubar). Its composition model avoids `asChild` Slot pitfalls and supports state-aware rendering without extra context plumbing.

## When To Use
- New custom design systems or new shadcn/ui projects (default base).
- Apps needing an accessible Combobox/Autocomplete, NumberField, OTP input, toast stack or swipeable drawer from one consistent library.
- Teams that value long-term backing (MUI's stated 2026 focus).

## When Not To Use
- Existing Radix design systems with no pain points. Migration costs outweigh benefits.
- Heavy i18n/date/calendar needs across many locales and calendar systems. React Aria is stronger.
- Teams that want pre-styled components. Use Material UI, Mantine or HeroUI.

## Core Principles
1. **Unstyled, but state-exposed**: every part exposes `data-*` attributes (`data-open`, `data-highlighted`, `data-disabled`, `data-starting-style`, `data-ending-style`).
2. **`render` prop replaces the element**: pass an element (`render={<a href="/x" />}`) or a function `(props, state) => JSX`.
3. **`className` and `style` can be functions of state**: `className={(state) => state.open ? "..." : "..."}`.
4. **Most appropriate element by default**: only change the element case by case.
5. **Composable positioning**: `Positioner` parts wrap popups with Floating UI and expose CSS variables (e.g. anchor width, available height).

## Best Practices
- Import from subpaths or namespaces per component (e.g. `import { Dialog } from "@base-ui/react/dialog"`) to keep bundles lean.
- When passing custom components to `render`, they must accept `ref` and spread all received props onto their DOM node.
- Use the function form of `render` in performance-sensitive lists to control prop spreading and branch on state.
- Animate with `data-starting-style` / `data-ending-style` (CSS transitions). Base UI waits for exit animations before unmounting.
- Use the `useRender` + `mergeProps` utilities to build your own components that support a `render` prop consistently.
- For Combobox with large or async data, use the `createItems` collection API (v1.8).
- For mobile drawers, add `Drawer.VirtualKeyboardProvider` (v1.6) so inputs aren't hidden by the on-screen keyboard.

## Implementation Guidance
```bash
pnpm add @base-ui/react
```
Portals need an isolated stacking context. Add `isolation: isolate` on your app root (`<body><div className="root isolate">`) so popups layer above page content predictably.

| Radix concept | Base UI equivalent |
|---|---|
| `asChild` | `render={<Comp />}` or `render={(props, state) => ...}` |
| `data-state="open"` | `data-open` / `data-closed` |
| `forceMount` | `keepMounted` |
| `Content` with side/align | `Positioner` (side/align/sideOffset) + `Popup` |
| `onOpenChange(open)` | `onOpenChange(open, eventDetails)` |
| Slot | `useRender` + `mergeProps` |

Component coverage highlights (v1.x): Accordion, AlertDialog, Autocomplete, Avatar, Checkbox, Collapsible, Combobox, ContextMenu, Dialog, Drawer, Field, Fieldset, Form, Input, Menu, Menubar, Meter, NavigationMenu, NumberField, OTPField (stable in v1.6), Popover, PreviewCard, Progress, Radio, ScrollArea, Select, Separator, Slider, Switch, Tabs, Toast, Toggle, ToggleGroup, Toolbar, Tooltip. Check the docs for the exact current list.

## Recommended Workflow
1. Read the component's anatomy page. Base UI splits Trigger / Portal / Positioner / Popup / Arrow / Backdrop.
2. Build styled wrappers in `components/ui` (or use shadcn's Base UI styles).
3. Style using data attributes and state-function `className`. Add transitions with starting/ending styles.
4. Wire forms with `Field` + `Form` for validation messages and `aria-invalid`.
5. Test keyboard and screen reader behavior. Upgrade minors regularly (monthly cadence in 2026).

## Patterns
- **Link as menu item**: `<Menu.Item render={<Link href="/settings" />}>Settings</Menu.Item>`.
- **Nested render composition**: Tooltip.Trigger rendering a Dialog.Trigger rendering your Button, e.g. `render={<Dialog.Trigger render={<Button />} />}`.
- **State-driven class**: `className={(s) => cn("rounded px-2", s.highlighted && "bg-muted")}`.
- **Toast manager**: create a toast manager (`Toast.createToastManager()`) and call it outside React trees (e.g. from mutation callbacks). Updates can be function-based (v1.8).
- **Own render-prop component**: `useRender({ defaultTagName: "button", render, props: mergeProps(defaultProps, props) })`.

## Anti-Patterns
- **Copying Radix code with `asChild`**: Base UI ignores it and renders a nested element. Convert to `render`.
- **Custom `render` components that don't spread props/ref**: focus, ARIA and event handlers are lost.
- **Global z-index wars**: without an `isolate` root, portaled popups can appear under sticky headers. Fix the stacking context instead of piling up `z-[9999]`.
- **Mass codemod migration from Radix**: behavior differs (event details, positioning parts). Migrate component by component and test.
- **Pinning an old 1.x**: many a11y fixes landed in 1.6-1.8 (APG-aligned accordion keys, overlay fixes). Stay current.

## Accessibility
- Follows WAI-ARIA APG. v1.6 aligned Accordion keyboard navigation with APG, and v1.8 brought further interaction refinements.
- Field/Form integrate labels, descriptions and error messages with correct `aria-describedby`/`aria-invalid`.
- Toast announces via live regions. Drawer supports swipe dismissal plus keyboard close.
- Your responsibility: visible focus rings, color contrast, reduced-motion handling for transitions, accessible names on icon-only triggers.

## Responsive Design
- Drawer with `swipeDirection` offers mobile sheets. Pair it with Dialog on desktop.
- Positioner collision avoidance keeps popups within the viewport. Use available-height CSS variables to cap scrolling lists.
- `ScrollArea` gives consistent custom scrollbars. v1.7 added overscroll feedback on WebKit.

## Performance
- v1.7 reduced bundle size across components. v1.8 made Menu/Popover triggers mount faster.
- Combobox performance was optimized in v1.6. For thousands of items, combine with virtualization.
- The `render` function form avoids extra element creation in hot paths.
- Only the components you import are bundled. `date-fns` is an optional peer, needed only for date-related parts.

## Security
- No HTML injection APIs. Sanitize user content rendered in Popups/Toasts.
- MIT-licensed, maintained by MUI. Pin via lockfile and review changelogs for behavior changes.

## Testing
- Query by role and name. Portaled popups render to `document.body`.
- Use `userEvent` over `fireEvent` for pointer and keyboard fidelity. For swipe/drag (Drawer, Slider), prefer Playwright.
- Stub `ResizeObserver` in jsdom for ScrollArea/Positioner.

## Tooling
- `@base-ui/react` 1.8.0 (MIT). Releases: v1.0 December 2025, v1.1 January 2026, v1.5 May 2026, v1.6 June, v1.7 August, v1.8 September 2026.
- shadcn/ui Base UI styles (default base) for a pre-styled starting point.
- coss ui: a large community component set built on Base UI.

## Framework Notes
- **Next.js App Router**: components are client-side (hooks/context). Put them in `"use client"` wrappers and render those from Server Components. IDs use `useId`, so SSR markup is hydration-safe. Place the Toast provider/viewport in a client provider under `app/layout.tsx`.
- **React (Vite SPA)**: no special setup beyond the stacking-context root.
- React 17-19 peer range. Ref-as-prop works with React 19 components passed to `render`.

## AI Agent Guidance
- Detect the base first (shadcn `components.json` / `shadcn info`, or imports from `@base-ui/react`).
- Use `render`, never `asChild`, in Base UI code. Don't invent Radix part names (`Content` becomes `Positioner` + `Popup`).
- Look up current anatomy in the docs. The API grew monthly in 2026, so don't rely on 2025 memory (e.g. the pre-1.0 package name `@base-ui-components/react`).
- Before declaring done, check focus returns to the trigger, Escape closes, exit transitions complete, there are no nested-button warnings, and the app root has `isolate`.

## Examples
```tsx
"use client";
import { Popover } from "@base-ui/react/popover";
import { cn } from "cn";

export function HelpPopover({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <Popover.Root>
      <Popover.Trigger
        aria-label={label}
        className={(s) => cn("size-8 rounded-full border", s.open && "bg-muted")}
      >
        ?
      </Popover.Trigger>
      <Popover.Portal>
        <Popover.Positioner sideOffset={8} side="bottom" align="start">
          <Popover.Popup
            className="w-72 rounded-lg border bg-popover p-4 shadow-md transition-[opacity,transform]
                       data-[starting-style]:scale-95 data-[starting-style]:opacity-0
                       data-[ending-style]:scale-95 data-[ending-style]:opacity-0"
          >
            <Popover.Title className="font-medium">{label}</Popover.Title>
            <Popover.Description className="text-sm text-muted-foreground">{children}</Popover.Description>
          </Popover.Popup>
        </Popover.Positioner>
      </Popover.Portal>
    </Popover.Root>
  );
}
```

```tsx
// A design-system Button that supports render, built with useRender
import { useRender } from "@base-ui/react/use-render";
import { mergeProps } from "@base-ui/react/merge-props";

type ButtonProps = useRender.ComponentProps<"button"> & { tone?: "primary" | "ghost" };

export function Button({ render, tone = "primary", ...props }: ButtonProps) {
  return useRender({
    defaultTagName: "button",
    render,
    props: mergeProps<"button">({ className: tone === "primary" ? "btn-primary" : "btn-ghost" }, props),
  });
}
// <Button render={<a href="/docs" />}>Docs</Button>
```
(Verify exact `useRender` type names against the current docs; the helper API is documented under Handbook > Composition.)

## Related Skills
- [shadcn-ui](../shadcn-ui/Skill.md): default styled layer on Base UI
- [radix-ui-primitives](../radix-ui-primitives/Skill.md): predecessor model; migration mapping
- [material-ui](../material-ui/Skill.md): MUI builds new components on Base UI
- [select-and-combobox](../select-and-combobox/Skill.md): Combobox/Autocomplete patterns
- [drawers-and-sheets](../drawers-and-sheets/Skill.md): Drawer usage
- [toasts-and-notifications](../toasts-and-notifications/Skill.md): Toast manager
- [component-api-design](../component-api-design/Skill.md): render-prop API design
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): headless library comparison

## Sources
- [Base UI releases](https://base-ui.com/react/overview/releases): Official. v1.6-v1.8 highlights and dates
- [Base UI composition handbook](https://base-ui.com/react/handbook/composition): Official. render prop and function form
- [mui/base-ui GitHub](https://github.com/mui/base-ui): Open Source. Project description, MIT
- [@base-ui/react registry metadata](https://registry.npmjs.org/@base-ui/react/latest): Official. Version 1.8.0, peers
- [MUI: 2026 and beyond](https://mui.com/blog/2026-and-beyond/): Official. Base UI as MUI's primary focus
- [Show HN: Base UI v1.0](https://news.ycombinator.com/item?id=46245401): Community. v1.0 launch context
- [shadcn: Base UI as default](https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default): Official
- [shadcn Drawer (Base UI)](https://ui.shadcn.com/docs/components/base/drawer): Official. Vaul to Base UI Drawer (`direction` becomes `swipeDirection`)

## License / Usage Notes
MIT (MUI). This skill summarizes the documentation. Code samples are original. Verify helper type names against the current docs.

## Quality Tier
A: official sources, verified version and release cadence; a few helper API specifics (useRender typings, toast manager naming) are summarized and should be checked against the docs.

## Status
Active

## Last Verified
2026-09-15
