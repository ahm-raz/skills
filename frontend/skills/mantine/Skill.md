# Mantine

## Summary
Mantine (`@mantine/core` 9.6.1, MIT) is a full-featured React component and hooks library styled with plain CSS (CSS Modules-friendly, `postcss-preset-mantine`) and CSS variables. There is no CSS-in-JS runtime. It ships 120+ components and 70+ hooks plus packages for forms, dates, charts (Recharts), notifications, Spotlight, rich text (Tiptap), scheduling (`@mantine/schedule`, v9) and a lightbox (v9.6). v9 (March 31, 2026) requires React 19.2+.

## Category
UI Libraries

## Subcategories
Styled components, hooks library, CSS variables theming, Styles API, @mantine/form, @mantine/dates, @mantine/charts, Spotlight, MCP server

## Problem It Solves
It gives teams a batteries-included, well-documented component system without CSS-in-JS runtime cost or Tailwind lock-in. You get broad components, rich hooks and a first-party form/date/chart stack in one consistent API.

## When To Use
- SaaS dashboards, internal tools and data-entry apps needing breadth fast.
- Teams preferring CSS Modules/vanilla CSS with a strong theme object and good TypeScript.
- Projects that value first-party integrated packages (forms, dates, notifications, spotlight, charts, scheduling).

## When Not To Use
- Projects stuck on React < 19.2. Stay on Mantine 8 or pick another library.
- Tailwind-first design systems wanting utility-driven component internals (use shadcn/ui or HeroUI). Coexistence is possible but duplicated.
- Teams wanting code ownership of every component (shadcn model).

## Core Principles
1. **Theme object compiles to CSS variables**: `createTheme({ primaryColor, colors, fontFamily, radius, spacing, components })` produces `--mantine-*` variables.
2. **Styles API**: every component exposes named inner elements for `classNames`, `styles`, `vars` and `attributes` props and theme overrides.
3. **Plain CSS + PostCSS preset**: `postcss-preset-mantine` provides `rem()`, `light-dark()`, and breakpoint mixins (`@mixin smaller-than sm`).
4. **Polymorphic components**: `component` prop (`<Button component={Link} href="/x">`) and `renderRoot`.
5. **Hooks as first-class**: `useDisclosure`, `useMediaQuery`, `useDebouncedValue`, `useHotkeys`, `useLocalStorage`, and more.

## Best Practices
- Import `@mantine/core/styles.css` (and per-package styles) once at the root, before your own CSS. Use `@layer` builds (`styles.layer.css`) to coexist with Tailwind v4 layers.
- Use `MantineProvider` + `ColorSchemeScript` to avoid color-scheme flash. In Next.js use `mantineHtmlProps` on `<html>`.
- Customize via `theme.components.Button.defaultProps/classNames` rather than one-off overrides.
- Use `@mantine/form` (`useForm` with `mode: "uncontrolled"`) for large forms to minimize re-renders. v9 supports async validation rules with `AbortSignal`.
- For combobox-heavy UIs, use the `Combobox` primitives (and v9 virtualization support) instead of forking Select.
- Adopt v9 renames: Grid `gutter` becomes `gap`, Collapse `in` becomes `expanded`, no `color` prop on Text/Anchor (use `c`). Default radius changed from 4px to 8px, so re-check visuals.

## Implementation Guidance
```bash
pnpm add @mantine/core @mantine/hooks
pnpm add -D postcss postcss-preset-mantine postcss-simple-vars
```
```js
// postcss.config.mjs
export default {
  plugins: {
    "postcss-preset-mantine": {},
    "postcss-simple-vars": { variables: { "mantine-breakpoint-xs": "36em", "mantine-breakpoint-sm": "48em", "mantine-breakpoint-md": "62em", "mantine-breakpoint-lg": "75em", "mantine-breakpoint-xl": "88em" } },
  },
};
```
```tsx
// app/layout.tsx (Next.js App Router)
import "@mantine/core/styles.css";
import { ColorSchemeScript, MantineProvider, mantineHtmlProps, createTheme } from "@mantine/core";

const theme = createTheme({ primaryColor: "indigo", defaultRadius: "md", fontFamily: "var(--font-inter)" });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" {...mantineHtmlProps}>
      <head><ColorSchemeScript defaultColorScheme="auto" /></head>
      <body>
        <MantineProvider theme={theme} defaultColorScheme="auto">{children}</MantineProvider>
      </body>
    </html>
  );
}
```
(`createTheme` returns a plain object, so it can run in a Server Component module. If it contains functions, move it to a client module.)

| Need | Package |
|---|---|
| Forms | `@mantine/form` |
| Date inputs/calendars | `@mantine/dates` (dayjs) |
| Charts | `@mantine/charts` (Recharts 3+ in v9) |
| Toasts | `@mantine/notifications` |
| Command palette | `@mantine/spotlight` |
| Rich text | `@mantine/tiptap` (Tiptap 3+ in v9) |
| Calendar scheduling | `@mantine/schedule` (v9) |
| AI docs access | `@mantine/mcp-server` |

## Recommended Workflow
1. Set up the PostCSS preset, provider, ColorSchemeScript and global styles.
2. Define the theme (colors as 10-shade tuples, radius, fonts, component defaults).
3. Build pages with layout components (`AppShell`, `Stack`, `Group`, `Grid`) and CSS Modules for custom styling.
4. Add `@mantine/form` validation (zod via a resolver if desired).
5. Upgrade by reading each minor changelog. Majors have explicit breaking lists.

## Patterns
- **CSS Module + Styles API**: `<TextInput classNames={{ input: classes.input, label: classes.label }} />`.
- **Theme-level variant**: `Button.extend({ classNames: { root: classes.root }, vars: (theme, props) => ({ root: { "--button-height": props.size === "xl" ? "56px" : undefined } }) })`.
- **Modal manager**: `@mantine/modals` `modals.openConfirmModal({...})` for confirmation flows.
- **AppShell**: header/navbar/aside layout with responsive `navbar={{ breakpoint: "sm", collapsed: { mobile: !opened } }}`.

## Anti-Patterns
- **Forgetting `styles.css` imports**: components render unstyled.
- **Using the `sx`/`createStyles` APIs from Mantine v6**: removed since v7. Use CSS Modules or the Styles API.
- **Inline `styles` objects everywhere**: style attributes bloat HTML. Prefer classNames.
- **Upgrading to v9 on React 19.0/19.1**: peer requires ^19.2.
- **Global CSS overriding `.mantine-*` classes without layers**: order-dependent bugs. Use layered CSS or the Styles API.

## Accessibility
- Components ship ARIA semantics, focus trapping (Modal/Drawer), keyboard support for Combobox/Menu/Tabs, and focus rings (`focusRing` theme setting: auto/always/never; keep auto or always).
- Inputs wire `label`, `description`, `error` with `aria-describedby` and `aria-invalid`.
- Verify custom Combobox builds and color contrast of the chosen `primaryColor` shades.
- Respect `prefers-reduced-motion`: `theme.respectReducedMotion` (verify current name in docs).

## Responsive Design
- Style props with breakpoints (`p={{ base: "sm", md: "xl" }}`), `hiddenFrom`/`visibleFrom`, `useMediaQuery`, and PostCSS mixins.
- Container queries: `Grid type="container"` and `SimpleGrid type="container"`.
- `AppShell` handles mobile navbar collapse.

## Performance
- No runtime CSS-in-JS. Styles are static CSS files, a major advantage over MUI/Chakra.
- The components still require client-side JS (context/hooks). Keep interactive islands small in Next.js.
- The global `styles.css` is sizable. Import per-component CSS files for tighter bundles if needed.
- Use `@mantine/form` uncontrolled mode and virtualization for large comboboxes.

## Security
- `@mantine/tiptap`: sanitize stored HTML on the server before rendering elsewhere.
- Dropzone: validate files server-side.
- MIT. Primarily one lead maintainer (Vitaly Rtishchev) with a very consistent release history, which is still a bus-factor consideration.

## Testing
- Render with `MantineProvider` in a custom `render` helper. Mock `matchMedia` and `ResizeObserver` in jsdom.
- Disable transitions in tests via theme (`components.Modal.defaultProps.transitionProps: { duration: 0 }`).
- Playwright for Spotlight/hotkeys flows.

## Tooling
- `@mantine/core` 9.6.1 (React ^19.2), Node.js 22 required for v9.6 tooling.
- v9.x additions: TreeSelect (9.2), ComboboxPopover (9.4), oxc tooling (9.5), `@mantine/lightbox` (9.6).
- `@mantine/mcp-server` for AI access to docs and props.

## Framework Notes
- **Next.js App Router**: Mantine components include `"use client"` directives, so they can be imported in Server Components, but hooks-based usage (`useDisclosure`, `useForm`) must be in client files. Use `ColorSchemeScript` + `mantineHtmlProps`. Compound components with dot notation (`Menu.Item`) must be used inside client components (dot access doesn't work across the RSC boundary).
- **React (Vite SPA)**: provider plus PostCSS config. No SSR concerns.
- React 19.2+ required for v9.

## AI Agent Guidance
- DO check the Mantine major. v6-era `createStyles`/`sx` and v8-era `gutter`/`in` props are wrong in v9.
- DO use CSS Modules + the Styles API for customization and `c` instead of `color` on Text.
- DON'T use `Menu.Item`-style dot components directly in Server Components.
- Verify before done: styles imported, no color-scheme flash, PostCSS preset configured, React >= 19.2.

## Examples
```tsx
"use client";
import { Button, Modal, Stack, TextInput } from "@mantine/core";
import { useDisclosure } from "@mantine/hooks";
import { useForm } from "@mantine/form";

export function CreateProject({ onCreate }: { onCreate: (name: string) => Promise<void> }) {
  const [opened, { open, close }] = useDisclosure(false);
  const form = useForm({
    mode: "uncontrolled",
    initialValues: { name: "" },
    validate: { name: (v) => (v.trim().length < 3 ? "At least 3 characters" : null) },
  });

  return (
    <>
      <Button onClick={open}>New project</Button>
      <Modal opened={opened} onClose={close} title="Create project" centered>
        <form onSubmit={form.onSubmit(async ({ name }) => { await onCreate(name); close(); form.reset(); })}>
          <Stack gap="md">
            <TextInput label="Name" key={form.key("name")} {...form.getInputProps("name")} data-autofocus />
            <Button type="submit">Create</Button>
          </Stack>
        </form>
      </Modal>
    </>
  );
}
```

## Related Skills
- [css-modules](../css-modules/Skill.md): Mantine's styling approach
- [css-cascade-layers-and-specificity](../css-cascade-layers-and-specificity/Skill.md): layered coexistence
- [saas-application-patterns](../saas-application-patterns/Skill.md): typical use
- [recharts](../recharts/Skill.md): @mantine/charts base
- [command-palette](../command-palette/Skill.md): Spotlight
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [Mantine 9.0.0 changelog](https://mantine.dev/changelog/9-0-0/): Official. Requirements, breaking changes, new packages, MCP server
- [Mantine all releases](https://mantine.dev/changelog/all-releases/): Official. 9.x timeline
- [Mantine 9.6.0](https://mantine.dev/changelog/9-6-0/): Official. Lightbox, Node 22
- [@mantine/core registry metadata](https://registry.npmjs.org/@mantine/core/latest): Official. Version 9.6.1, React ^19.2 peer
- [mantinedev/mantine releases](https://github.com/mantinedev/mantine/releases): Open Source

## License / Usage Notes
MIT. Summarized from the official changelog and docs; code examples are original. Some option names (reduced motion, per-component CSS files) are flagged for verification.

## Quality Tier
A: official changelogs and versions verified; the Next.js setup follows the long-standing documented pattern, re-checked only at a high level.

## Status
Active

## Last Verified
2026-09-15
