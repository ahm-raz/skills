# React Aria and React Spectrum

## Summary
React Aria (Adobe) is the most thorough accessibility and internationalization foundation for React. It comes in layers: low-level hooks (`react-aria`), state hooks (`react-stately`) and the unstyled component library `react-aria-components` (RAC, v1.21.1, Apache-2.0). React Spectrum S2 (`@react-spectrum/s2`, v1.7.1) is Adobe's styled design system on top, using a build-time style macro. RAC also powers HeroUI v3 and is a selectable shadcn/ui base (July 2026).

## Category
UI Libraries

## Subcategories
Headless components, hooks, i18n (dates, numbers, calendars, RTL), collections API, drag and drop, render props, data attributes, Spectrum 2 style macro

## Problem It Solves
Accessibility beyond the basics: consistent press/hover/focus semantics across mouse, touch, pen, keyboard and screen readers; localized date and number parsing and formatting; accessible drag and drop; multi-selection grids with keyboard and screen-reader support. It solves the hard 20% that other headless libraries skip.

## When To Use
- Internationalized products (30+ locales, 13 calendar systems, RTL), date/time pickers, number fields with currency/units.
- Complex collection widgets: ListBox, GridList, Table with column resizing, Tree, Tag groups, drag and drop.
- Design systems that need to pass strict accessibility audits (public sector, enterprise).
- Adobe-ecosystem apps (Spectrum S2) or HeroUI v3 / shadcn Aria-base projects.

## When Not To Use
- Small marketing sites needing only a dialog and a menu. RAC's size and API depth are overkill.
- Teams unwilling to learn its event model (`onPress` rather than `onClick`) and collection APIs.
- Spectrum S2 for non-Adobe-branded products: it encodes Adobe's visual language.

## Core Principles
1. **Interactions are normalized**: `usePress`, `useHover`, `useFocusRing` unify pointer types. Components expose `onPress`, not `onClick`.
2. **Style by render props and data attributes**: `className={({ isSelected }) => ...}`, `[data-pressed]`, `[data-focus-visible]`.
3. **Collections are declarative and dynamic**: `items` + render function with stable `id`s. Selection uses `Set` keys.
4. **Layered escape hatches**: components, then contexts (slots), then hooks, depending on how much DOM control you need.
5. **i18n is built in**: `I18nProvider locale`, `@internationalized/date` values, locale-aware parsing.

## Best Practices
- Use `react-aria-components` for most work. Drop to hooks only for bespoke DOM structures.
- Install `tailwindcss-react-aria-components` to get variants like `selected:`, `pressed:`, `focus-visible:` matching RAC data attributes.
- Use `@internationalized/date` (`parseDate`, `today(getLocalTimeZone())`) for DatePicker/Calendar values, never `Date` directly.
- Give collection items stable string `id`s. Control selection with `selectedKeys` (`Set`) and `onSelectionChange`.
- Use `Form` + `validationBehavior="aria"` or native, and `FieldError` for messages.
- Provide `aria-label` for components without visible labels. RAC warns in dev.
- For Spectrum S2, use the `style` macro (`import { style } from "@react-spectrum/s2/style" with { type: "macro" }`) and wrap the app in S2 `Provider`. The Provider loads locale fonts.

## Implementation Guidance
```bash
pnpm add react-aria-components
pnpm add -D tailwindcss-react-aria-components   # Tailwind v4: @plugin "tailwindcss-react-aria-components";
```

| Layer | Package | Use for |
|---|---|---|
| Components | `react-aria-components` | Default: unstyled, composable parts |
| Hooks | `react-aria`, `react-stately` | Custom DOM or unusual widgets |
| Styled (Adobe) | `@react-spectrum/s2` | Adobe-style apps; style macro |
| Styled (third-party) | HeroUI v3, shadcn `--base aria` | Tailwind-styled RAC |

**Spectrum S2 notes (release notes)**: the style macro emits CSS in cascade layers. Global CSS now takes precedence over S2 styles after the `revert-layer` removal. Passing style macros to `UNSAFE_className` is a TypeScript error. Use the `styles` prop.

## Recommended Workflow
1. Identify the APG pattern and pick the RAC component (Select vs ComboBox vs Autocomplete vs Menu).
2. Build a styled wrapper per component (starter kits exist in the docs for Tailwind and vanilla CSS).
3. Wire collections with `items` and stable ids. Hook selection to URL or state as needed.
4. Add `I18nProvider` if the locale differs from the browser's. Verify RTL.
5. Test with keyboard, VoiceOver/NVDA, and touch.

## Patterns
- **Render-prop className**: `className={({ isFocusVisible, isSelected }) => cn("px-2", isSelected && "bg-primary", isFocusVisible && "ring-2")}`.
- **Slots via context**: `<Dialog>` provides `slot="title"` to `Heading`, and `Button slot="close"` closes the dialog.
- **Async list**: `useAsyncList` for loading, sorting and filtering remote data in ComboBox/Table.
- **Drag and drop**: `useDragAndDrop({ getItems, onReorder })` passed as `dragAndDropHooks` to GridList/Table.
- **Router integration**: `RouterProvider navigate={router.push} useHref={...}` so `Link`/`href` items use client routing.

## Anti-Patterns
- **Using `onClick` on RAC Button**: it bypasses press normalization (touch cancel, keyboard). Use `onPress`.
- **Index-based ids in collections**: selection and focus break on reorder or filter. Use stable ids.
- **JS `Date` for date components**: time-zone bugs. Use `CalendarDate`/`ZonedDateTime`.
- **Global CSS resets targeting S2 elements**: since the layer change, global CSS wins. Scope your resets.
- **Wrapping RAC parts in extra divs** that break context/slot relationships: compose via documented parts.

## Accessibility
- The benchmark implementation. It is tested with major screen readers and devices, and supports virtual cursor quirks, touch screen readers and mobile keyboards.
- Correct focus management for overlays, focus rings only for keyboard (`isFocusVisible`), live announcements for drag and drop and selection.
- Localized ARIA strings (e.g. "Select all", calendar labels) in 30+ languages.
- Your responsibility: visual focus styles, contrast, accessible names, reduced-motion.

## Responsive Design
- Popovers use internal positioning with flipping. Components adapt to touch (larger press targets are up to your CSS).
- `Modal`/`ModalOverlay` can be styled as full-screen sheets on small viewports.
- Table column resizing and virtualization (`Virtualizer` with layouts) support dense and responsive data views.

## Performance
- RAC is large compared with Radix/Base UI. Import only the components you use (ESM, tree-shakeable).
- Use `Virtualizer` (`ListLayout`, `GridLayout`) for long ListBox/GridList/Table.
- The S2 style macro produces atomic CSS at build time (no runtime styling cost) but needs bundler macro support (Parcel, Vite, webpack via unplugin-parcel-macros; check the S2 docs).

## Security
- No HTML injection APIs. Sanitize rich content in items.
- Apache-2.0. Adobe-maintained monorepo with frequent coordinated releases.

## Testing
- Official `@react-aria/test-utils` provides ARIA-pattern testers (e.g. table and select interactions). Check the docs for availability per component.
- Use `userEvent` with pointer events. RAC relies on pointer semantics, so `fireEvent.click` may not trigger `onPress`.
- Playwright plus axe for integration. Test locales (e.g. `ar-EG`, `ja-JP`).

## Tooling
- `react-aria-components` 1.21.1, `react-aria`, `react-stately`, `@internationalized/date`, `@internationalized/number`.
- `@react-spectrum/s2` 1.7.1 (React 19 peer). Legacy React Spectrum v3 (`@adobe/react-spectrum`) is superseded by S2 for new work.
- `tailwindcss-react-aria-components` plugin. Starter kits (Tailwind/vanilla CSS) are in the docs.
- Docs moved to react-aria.adobe.com (301 redirect from react-spectrum.adobe.com/react-aria).

## Framework Notes
- **Next.js App Router**: RAC components are client components, so use `"use client"` wrappers. For SSR id consistency, React 18+ `useId` is used (older `SSRProvider` isn't needed on React 18+). Wire `RouterProvider` with `useRouter().push` in a client provider so `href` on Menu items and Tabs does client navigation.
- **React (Vite SPA)**: straightforward. Configure the macro plugin if using S2.
- React 19: supported (RAC peer range includes 19; S2 requires 19).

## AI Agent Guidance
- DO use `onPress`, `isDisabled`, `selectedKeys`, `@internationalized/date` values. DON'T translate Radix/DOM props directly.
- DO check whether the project uses RAC directly, HeroUI v3 or shadcn Aria base, and follow that layer's wrappers.
- DO add the Tailwind plugin for state variants rather than arbitrary `data-[...]` selectors everywhere.
- Verify before done: keyboard navigation in collections, labels present (no dev warnings), focus-visible styles, locale formatting for date/number fields.

## Examples
```tsx
"use client";
import { Select, Label, Button, SelectValue, Popover, ListBox, ListBoxItem, FieldError } from "react-aria-components";

type Plan = { id: string; name: string };

export function PlanSelect({ plans, value, onChange }: { plans: Plan[]; value: string | null; onChange: (id: string) => void }) {
  return (
    <Select selectedKey={value} onSelectionChange={(k) => onChange(String(k))} isRequired className="flex flex-col gap-1">
      <Label className="text-sm font-medium">Plan</Label>
      <Button className="flex h-9 items-center justify-between rounded-md border px-3 focus-visible:ring-2">
        <SelectValue />
        <span aria-hidden>▾</span>
      </Button>
      <FieldError className="text-sm text-destructive" />
      <Popover className="min-w-[--trigger-width] rounded-md border bg-popover p-1 shadow">
        <ListBox items={plans}>
          {(plan) => (
            <ListBoxItem id={plan.id} className="rounded px-2 py-1.5 outline-none focus:bg-muted selected:font-semibold">
              {plan.name}
            </ListBoxItem>
          )}
        </ListBox>
      </Popover>
    </Select>
  );
}
```

```tsx
// app/providers.tsx: client routing for RAC links
"use client";
import { RouterProvider } from "react-aria-components";
import { useRouter } from "next/navigation";

export function AriaProviders({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  return <RouterProvider navigate={router.push}>{children}</RouterProvider>;
}
```

## Related Skills
- [heroui](../heroui/Skill.md): styled layer on RAC
- [shadcn-ui](../shadcn-ui/Skill.md): `--base aria` option
- [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md): RAC date components
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md): NumberField parsing
- [drag-and-drop](../drag-and-drop/Skill.md): accessible DnD
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md): locale handling
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md): RTL layouts
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [React Aria (react-aria.adobe.com)](https://react-aria.adobe.com/): Official. Styling model, layers, i18n scope, SSR
- [React Spectrum S2 release notes](https://react-spectrum.adobe.com/beta/s2/release-notes.html): Official. Style macro cascade layers, Provider fonts, UNSAFE_className change
- [react-aria-components registry metadata](https://registry.npmjs.org/react-aria-components/latest): Official. Version 1.21.1, Apache-2.0
- [@react-spectrum/s2 registry metadata](https://registry.npmjs.org/@react-spectrum/s2/latest): Official. Version 1.7.1, React 19 peer
- [shadcn: React Aria base](https://ui.shadcn.com/docs/changelog/2026-07-react-aria): Official. `init --base aria`
- [HeroUI v3 rewrite (InfoQ)](https://www.infoq.com/news/2026/07/heroui-v3-rewrite/): Community. RAC adoption by HeroUI

## License / Usage Notes
React Aria, React Stately, RAC and Spectrum S2 are Apache-2.0 (Adobe). The Spectrum visual design is Adobe's brand language. Code examples are original summaries.

## Quality Tier
A: official docs and verified versions; test-utils coverage and macro bundler specifics should be confirmed per project.

## Status
Active

## Last Verified
2026-09-15
