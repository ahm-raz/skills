# Ark UI and Park UI (React)

## Summary
Ark UI (`@ark-ui/react` 5.39.2, MIT, Chakra team) is a headless component library whose behavior is modeled as **Zag.js finite state machines**. It has broad coverage: DatePicker, ColorPicker, TreeView with lazy loading, FileUpload, TagsInput, PinInput, Carousel, Splitter, Tour, Signature Pad. Park UI (MIT) is a styled layer on Ark UI, primarily with Panda CSS recipes (Tailwind support varies by version). Ark UI also powers Chakra UI v3. This skill covers React bindings only.

## Category
UI Libraries

## Subcategories
Headless components, Zag.js state machines, data-scope/data-part styling, asChild, Panda CSS recipes, Park UI, layer z-index stacking

## Problem It Solves
It covers complex widgets missing from Radix (date/color pickers, file upload, tree view, tags input, splitter, tour) with consistent anatomy and machine-driven logic that avoids effect-orchestration bugs. Everything is styleable through stable data attributes.

## When To Use
- Custom design systems needing breadth of complex headless widgets in React.
- Teams using Panda CSS (zero-runtime), where Park UI provides ready recipes.
- Teams that want the same behavior layer as Chakra UI v3 but with their own styling.

## When Not To Use
- Simple apps needing a few overlays (Base UI/Radix are lighter and more widely documented).
- Tailwind + code-ownership workflows centered on shadcn registries (unless you build your own).
- Teams requiring React Aria-level i18n (calendar systems, number parsing across locales).

## Core Principles
1. **Anatomy with data attributes**: every part renders `data-scope="<component>"` and `data-part="<part>"`, plus state (`data-state="open"`, `data-highlighted`, `data-disabled`).
2. **`asChild` composition** merges behavior into your element (like Radix).
3. **Machines own logic**: component context/props map to Zag machine context. Callbacks like `onValueChange`, `onOpenChange` receive details objects.
4. **Controlled and uncontrolled**: `value`/`defaultValue`, `open`/`defaultOpen`. Headless hooks (`useDialog`, `useDatePicker` style APIs) with `RootProvider` for external control (verify names per component).
5. **Stacking via `--layer-index`**: nested dismissible layers expose a zero-based offset so you keep a constant base z-index.

## Best Practices
- Style with anatomy selectors (`[data-scope="dialog"][data-part="content"]`) in CSS, or Tailwind `data-[state=open]:` variants on `className`.
- For Panda CSS, use `defineSlotRecipe` with Ark anatomy (Park UI recipes as a starting point).
- Use `z-index: calc(var(--base-z) + var(--layer-index))` for overlays instead of incrementing z-index per component.
- Use `lazyMount` + `unmountOnExit` on overlays/tabs with heavy content.
- Keep Ark UI updated. v5 minors added TreeView lazy loading (`loadChildren`), FileUpload `transformFiles`, a lighter internal store, and `hideMode`-style options.
- Use Portal (`<Portal>`) for popovers inside scroll containers.

## Implementation Guidance
```bash
pnpm add @ark-ui/react
```
| Widget | Ark component |
|---|---|
| Date / range picker | `DatePicker` |
| Color picker | `ColorPicker` |
| Tree with lazy children | `TreeView` (`loadChildren`) |
| File upload with previews | `FileUpload` (`transformFiles`) |
| Tags input | `TagsInput` |
| OTP / PIN | `PinInput` |
| Resizable panels | `Splitter` |
| Guided tour | `Tour` |
| Overlays | `Dialog`, `Popover`, `Menu`, `Tooltip`, `HoverCard` |

Ark UI v5 reported 1.5x to 4x better performance than v4 in stress tests with 10,000 components.

**Park UI**: a styled component collection built on Ark UI + Panda CSS, installed via its CLI into your project (code ownership similar to shadcn). Check park-ui.com for current Tailwind support and CLI commands before adopting.

## Recommended Workflow
1. Choose Ark (headless) vs Park UI (styled starter) vs Chakra v3 (styled, runtime).
2. Build a styled wrapper per component using anatomy selectors or Panda slot recipes.
3. Define a z-index base and use `--layer-index` for nested overlays.
4. Wire forms (Ark `Field` components) and controlled values into your form library.
5. Test keyboard and screen reader flows. Upgrade minors regularly.

## Patterns
- **Global anatomy CSS**: a single stylesheet with `[data-scope][data-part]` rules is reusable across all instances.
- **Tailwind wrapper**: `<Menu.Item className="px-2 py-1.5 data-[highlighted]:bg-muted">`.
- **Lazy tree**: `TreeView` with `loadChildren={async ({ node }) => fetchChildren(node.id)}` and `onLoadChildrenComplete` to update the collection.
- **Controlled date picker**: store ISO strings in form state and convert to Ark date values in the wrapper.

## Anti-Patterns
- **Styling by DOM structure** (`div > div:nth-child(2)`): use `data-part`.
- **Hard-coded z-index per overlay type**: breaks nested dialogs. Use `--layer-index`.
- **Mixing Chakra v3 and standalone Ark versions**: duplicate machines and contexts. Align versions or use Chakra's re-exports.
- **Rendering heavy content in closed overlays**: use `lazyMount`/`unmountOnExit`.

## Accessibility
- Zag machines implement WAI-ARIA APG keyboard and focus behavior with consistent semantics across components.
- Complex widgets (DatePicker, ColorPicker, TreeView) need your visual focus styles and labels. Audit with screen readers.
- `Field` components wire labels, helper text and errors.
- Respect reduced motion in your animations keyed on `data-state`.

## Responsive Design
- Positioning via Zag's floating logic with collision handling (`positioning` prop).
- Dialog/Drawer styling adapts per breakpoint through your CSS.
- `Splitter` supports responsive panel sizing with min/max constraints.

## Performance
- The v5 internals are markedly faster. The v5.36+ bundle work replaced `@zag-js/store` with a lighter store.
- Tree-shakeable per component. Complex widgets (DatePicker, ColorPicker) carry more code, so lazy-load them.
- Panda CSS (Park UI) is zero runtime. Styling cost stays at build time.

## Security
- FileUpload: validate type, size and content server-side. `transformFiles` is client-side only.
- MIT. Maintained by the Chakra team. Release cadence is active in 2026.

## Testing
- Use `data-scope`/`data-part` selectors when roles are ambiguous in complex widgets. Prefer roles otherwise.
- Playwright for DatePicker/ColorPicker keyboard interactions.
- Mock `ResizeObserver` in jsdom for positioned components.

## Tooling
- `@ark-ui/react` 5.39.2 (React >= 18), Zag.js (framework-agnostic machines), Park UI (Ark + Panda), Panda CSS.
- Chakra UI v3 uses Ark UI under the hood.

## Framework Notes
- **Next.js App Router**: Ark components use hooks and context, so wrap them in `"use client"` components. Portals render to `document.body` on the client. Ids are SSR-stable. Keep data loading (e.g. tree roots) in Server Components and pass it as props.
- **React (Vite SPA)**: no setup beyond styling.
- React 19: supported by peer range (>= 18).

## AI Agent Guidance
- DO verify component anatomy in ark-ui.com docs (part names like `Positioner`, `Content`, `ItemControl` vary).
- DO style via `data-scope`/`data-part` or `className` with data variants.
- DON'T invent hook names. Check whether a component exposes `use<Component>` + `RootProvider`.
- Verify before done: overlays stack correctly with nested layers, keyboard flows, labels, lazy mounting for heavy content.

## Examples
```tsx
"use client";
import { Dialog } from "@ark-ui/react/dialog";
import { Portal } from "@ark-ui/react/portal";

export function ShareDialog({ url }: { url: string }) {
  return (
    <Dialog.Root lazyMount unmountOnExit>
      <Dialog.Trigger className="rounded-md border px-3 py-1.5">Share</Dialog.Trigger>
      <Portal>
        <Dialog.Backdrop className="fixed inset-0 bg-black/40 data-[state=open]:animate-in" style={{ zIndex: "calc(50 + var(--layer-index, 0))" }} />
        <Dialog.Positioner className="fixed inset-0 grid place-items-center" style={{ zIndex: "calc(50 + var(--layer-index, 0))" }}>
          <Dialog.Content className="w-96 rounded-lg bg-white p-6 shadow-lg">
            <Dialog.Title className="font-semibold">Share link</Dialog.Title>
            <Dialog.Description className="text-sm text-gray-600">Anyone with the link can view.</Dialog.Description>
            <input readOnly value={url} className="mt-3 w-full rounded border px-2 py-1" aria-label="Share URL" />
            <Dialog.CloseTrigger className="mt-4 rounded-md border px-3 py-1.5">Close</Dialog.CloseTrigger>
          </Dialog.Content>
        </Dialog.Positioner>
      </Portal>
    </Dialog.Root>
  );
}
```
```css
/* Anatomy-based styling alternative */
[data-scope="menu"][data-part="item"][data-highlighted] { background: var(--color-muted); }
[data-scope="tooltip"][data-part="content"] { font-size: 0.75rem; }
```

## Related Skills
- [chakra-ui](../chakra-ui/Skill.md): styled library on Ark
- [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md): DatePicker
- [file-upload](../file-upload/Skill.md): FileUpload
- [tree-views](../tree-views/Skill.md): TreeView lazy loading
- [tags-and-chips-input](../tags-and-chips-input/Skill.md): TagsInput
- [css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md): Panda CSS context
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [Ark UI introduction](https://ark-ui.com/docs/overview/introduction): Official. Scope and Zag foundation
- [Ark UI styling guide](https://ark-ui.com/docs/guides/styling): Official. data-scope/data-part, Tailwind, Panda, `--layer-index`
- [Ark UI about](https://ark-ui.com/docs/overview/about): Official
- [Zag.js introduction](https://zagjs.com/overview/introduction): Official. State machine model
- [chakra-ui/ark GitHub](https://github.com/chakra-ui/ark): Open Source. MIT, frameworks
- [Ark releases (newreleases.io)](https://newreleases.io/project/github/chakra-ui/ark/release/@ark-ui/react@5.38.2): Community mirror. 5.36-5.38 features
- [@ark-ui/react registry metadata](https://registry.npmjs.org/@ark-ui/react/latest): Official. Version 5.39.2
- [chakra-ui/park-ui](https://github.com/chakra-ui/park-ui): Open Source. Park UI stack, MIT

## License / Usage Notes
Ark UI, Zag.js and Park UI are MIT. Summarized content; examples are original. Park UI's current Tailwind support and CLI were not verified.

## Quality Tier
B: official styling docs and versions verified, but several hook/part names and Park UI's current install flow need doc confirmation.

## Status
Active

## Last Verified
2026-09-15
