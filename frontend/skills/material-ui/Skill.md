# Material UI (MUI)

## Summary
Material UI (`@mui/material`, v9.4.0 as of September 2026, MIT) is the most widely used styled React component library. It implements Material Design with a deep theming system and `sx` styling on Emotion. v9 shipped April 8, 2026, skipping v8 to align versions with MUI X. It removed deprecated APIs (system props, `GridLegacy`, `components`/`componentsProps`) and standardized on `slots`/`slotProps`. Pigment CSS (zero-runtime) is on hold in alpha, and Joy UI is on hold. New MUI components are built on Base UI.

## Category
UI Libraries

## Subcategories
Material Design, theme/createTheme, CSS variables, sx prop, styled(), slots/slotProps, Emotion, Next.js integration, MUI X (Data Grid, Date Pickers, Charts), codemods

## Problem It Solves
It delivers a complete, consistent, accessible component suite (100+ components) with one theming API. Paired with MUI X, it covers data grids, date pickers, charts and tree views, so teams ship admin and B2B applications without assembling many libraries.

## When To Use
- Admin panels, internal tools and B2B apps where breadth and MUI X (Data Grid Pro/Premium, pickers) matter.
- Teams wanting Material Design or a thoroughly themeable component set with strong TypeScript support.
- Organizations valuing long-term stability, codemods and commercial support options.

## When Not To Use
- Performance-critical marketing/content sites where Emotion runtime and hydration cost hurt LCP/INP.
- Tailwind-first design systems. Coexistence works but you maintain two styling systems. Prefer shadcn/ui or HeroUI.
- Projects needing zero-runtime CSS today. Pigment CSS is paused, so don't bet on it.

## Core Principles
1. **Theme is the design system**: palette, typography, spacing, shape, breakpoints and component `defaultProps`/`styleOverrides`/`variants` live in `createTheme`.
2. **CSS variables mode**: `createTheme({ cssVariables: true, colorSchemes: { light: true, dark: true } })` enables flicker-free dark mode and runtime theming.
3. **Customize in layers**: one-off via `sx`, reusable via `styled()`, global via theme `components`.
4. **Slots for internals**: `slots={{ transition: Fade }}` and `slotProps={{ paper: { elevation: 0 } }}` replace `PaperProps`/`TransitionComponent`.
5. **Emotion is the default engine**. SSR needs a cache provider per framework.

## Best Practices
- Enable `cssVariables: true` and use `theme.vars.palette.*` in `styled`/`sx` for dark mode without re-render flashes.
- Use `InitColorSchemeScript` (Next.js) to set the color scheme before hydration.
- Put repeated `sx` into theme `variants` or `styled` components. Large inline `sx` objects in lists cost runtime.
- Import from the package root (`@mui/material`). Modern bundlers tree-shake. Use path imports only if dev-server startup is slow.
- Run the official codemods when upgrading (`npx @mui/codemod@latest v9.0.0/<codemod>`, e.g. `accordion-props`, `button-classes`). Check exact names in the migration guide.
- Replace system props (`<Box mt={2}>`) with `sx={{ mt: 2 }}`. They were removed in v9.
- Use `Grid` (the former Grid2 API) with `size={{ xs: 12, md: 6 }}`. `GridLegacy` is removed, and Grid no longer accepts `direction="column"`.
- Wrap Tailwind coexistence in CSS layers (`enableCssLayer` on the Next.js cache provider) so utilities can override MUI styles predictably.

## Implementation Guidance
```bash
pnpm add @mui/material @emotion/react @emotion/styled
pnpm add @mui/material-nextjs     # Next.js App Router integration
```
Theme:
```tsx
// src/theme.ts
"use client";
import { createTheme } from "@mui/material/styles";

export const theme = createTheme({
  cssVariables: true,
  colorSchemes: { light: true, dark: true },
  shape: { borderRadius: 8 },
  typography: { fontFamily: "var(--font-inter)" },
  components: {
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: { root: { textTransform: "none" } },
    },
  },
});
```
Next.js App Router layout:
```tsx
// app/layout.tsx (Server Component)
import { AppRouterCacheProvider } from "@mui/material-nextjs/v15-appRouter"; // pick the entry matching your Next major (check package docs)
import { ThemeProvider } from "@mui/material/styles";
import CssBaseline from "@mui/material/CssBaseline";
import InitColorSchemeScript from "@mui/material/InitColorSchemeScript";
import { theme } from "@/theme";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <InitColorSchemeScript attribute="class" />
        <AppRouterCacheProvider options={{ enableCssLayer: true }}>
          <ThemeProvider theme={theme}>
            <CssBaseline />
            {children}
          </ThemeProvider>
        </AppRouterCacheProvider>
      </body>
    </html>
  );
}
```

**v7 to v9 migration checklist (there is no v8)**
| Removed/changed | Replacement |
|---|---|
| System props on Box/Typography/Stack/Grid | `sx` |
| `GridLegacy` | `Grid` with `size` |
| `components`/`componentsProps`, `PaperProps`, `TransitionComponent` | `slots`/`slotProps` |
| `disableEscapeKeyDown` on Dialog/Modal | Handle in `onClose(event, reason)` |
| Icons `*Outline` (23 legacy) | `*Outlined` |
| Combined deprecated classes (`textPrimary`) | `.MuiButton-text.MuiButton-colorPrimary` |
| Stepper/Step `div` markup | Semantic `<ol>/<li>`, so update CSS selectors |
Browser floor: Chrome 117, Edge 121, Firefox 121, Safari 17.

## Recommended Workflow
1. Define the theme (tokens, color schemes, component defaults) before building screens.
2. Set up the framework integration (cache provider, CssBaseline, InitColorSchemeScript).
3. Build app-level wrappers (e.g. `AppDialog`) using `slots`/`slotProps`.
4. Add MUI X components where needed. Check the license tier (Community MIT vs Pro/Premium commercial).
5. Upgrade majors with codemods, then fix selectors that targeted changed DOM.

## Patterns
- **Custom variant**: theme `components.MuiButton.variants: [{ props: { variant: "dashed" }, style: {...} }]` plus module augmentation of `ButtonPropsVariantOverrides`.
- **Palette augmentation**: add `brand` to `Palette`/`PaletteOptions` via TypeScript declaration merging.
- **Polymorphic link**: `<Button component={NextLink} href="/x">` or set `LinkBehavior` in theme `MuiButtonBase.defaultProps.LinkComponent`.
- **Responsive sx**: `sx={{ p: { xs: 2, md: 4 } }}`.

## Anti-Patterns
- **Deep class selectors** (`& .MuiInputBase-root > div`): break on DOM changes (v9 changed Stepper and others). Use `slotProps` or theme overrides.
- **Creating the theme inside a component render**: new object identity re-styles everything. Define it at module scope.
- **Mixing `@mui/material` majors with MUI X majors**: v9 aligns them. Upgrade together.
- **Adopting Pigment CSS for production**: alpha and on hold.
- **Starting new work on Joy UI**: on hold with no roadmap.
- **Huge inline `sx` in virtualized rows**: runtime style serialization per row. Use `styled` or classes.

## Accessibility
- Strong baseline: ARIA roles, focus management in Dialog/Menu/Popover, keyboard support. v9 improved semantics (Stepper lists, ButtonBase Enter/Space click bubbling).
- Material's default contrast and focus ripple: ensure `focusVisible` styles meet WCAG 2.4.7/2.4.11 after theming.
- Use `TextField` `label`/`helperText` for accessible names and errors. Don't replace labels with placeholders.
- Test color-scheme variants for contrast (1.4.3).

## Responsive Design
- Theme breakpoints (`xs, sm, md, lg, xl`) drive `sx` responsive values, `Grid size`, and `useMediaQuery`.
- `useMediaQuery` on the server defaults to false. In Next.js, avoid layout decisions that cause hydration flips, and prefer CSS breakpoints.
- Container queries: use `sx` with `@container` strings or the theme `containerQueries` helper (verify availability in your version).

## Performance
- Emotion adds runtime style injection plus hydration of every styled component. This is the main cost versus Tailwind/CSS Modules.
- Mitigate: CSS variables mode (no theme re-render), fewer dynamic `sx` objects, lazy-load heavy MUI X components, and Server Component shells for static content.
- MUI components require `"use client"` context, so client bundles grow with each screen's component usage.

## Security
- No HTML injection except explicit patterns (e.g. rendering user content in `Typography` is text-safe). Avoid `dangerouslySetInnerHTML` in custom slots.
- MUI X Pro/Premium require a license key. Set it via env at build and never commit it to public repos.

## Testing
- Testing Library with role queries. MUI components expose proper roles (`combobox`, `listbox`, `dialog`).
- Transitions: set `transitions: { create: () => "none" }` in a test theme or use `disablePortal` to simplify jsdom tests.
- Visual regression is valuable after theme changes (Storybook + Chromatic/Playwright).

## Tooling
- `@mui/material` 9.4.0, `@mui/icons-material`, `@mui/material-nextjs`, `@mui/codemod`.
- MUI X (Data Grid, Date/Time Pickers, Charts, Tree View): Community MIT, Pro/Premium commercial.
- Pigment CSS: alpha, on hold (`@mui/material-pigment-css` is still listed as an optional peer). Joy UI: on hold. Toolpad: not actively maintained.

## Framework Notes
- **Next.js App Router**: MUI components are client components, but `@mui/material` marks them so they can be imported into Server Components directly. Theme creation with functions must stay in client modules. Use `AppRouterCacheProvider` from `@mui/material-nextjs` for Emotion SSR and `InitColorSchemeScript` for dark mode. Use `next/font` variables in `typography.fontFamily`.
- **React (Vite SPA)**: `ThemeProvider` + `CssBaseline` at root. No cache provider needed.
- React 17-19 peers. React 19 supported.

## AI Agent Guidance
- DO check the installed major (`@mui/material` version) before writing code. v5/v6 examples (system props, `PaperProps`, `Grid item xs`) are invalid in v9.
- DO use `slots`/`slotProps`, `sx`, `Grid size`.
- DON'T introduce Pigment CSS or Joy UI.
- DON'T add Tailwind to an MUI app without CSS layer configuration.
- Verify before done: no hydration warnings, dark mode works without flash, TypeScript augmentation for custom variants compiles, codemods applied on upgrade.

## Examples
```tsx
"use client";
import Dialog from "@mui/material/Dialog";
import DialogTitle from "@mui/material/DialogTitle";
import DialogContent from "@mui/material/DialogContent";
import DialogActions from "@mui/material/DialogActions";
import Button from "@mui/material/Button";
import Slide from "@mui/material/Slide";

export function ConfirmDialog({ open, onClose, onConfirm }: { open: boolean; onClose: () => void; onConfirm: () => void }) {
  return (
    <Dialog
      open={open}
      onClose={(_e, reason) => { if (reason !== "backdropClick") onClose(); }}
      slots={{ transition: Slide }}
      slotProps={{ paper: { sx: { borderRadius: 3, p: 1 } }, transition: { direction: "up" } }}
      aria-labelledby="confirm-title"
    >
      <DialogTitle id="confirm-title">Archive project?</DialogTitle>
      <DialogContent sx={{ color: "text.secondary" }}>You can restore it later from settings.</DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={onConfirm}>Archive</Button>
      </DialogActions>
    </Dialog>
  );
}
```

## Related Skills
- [css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md): Emotion and Pigment trade-offs
- [base-ui](../base-ui/Skill.md): MUI's headless foundation
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md): grid alternatives to MUI X
- [admin-panel-architecture](../admin-panel-architecture/Skill.md): typical MUI use case
- [dark-mode-implementation](../dark-mode-implementation/Skill.md): color schemes
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md): provider placement
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [MUI: 2026 and beyond](https://mui.com/blog/2026-and-beyond/): Official. Pigment on hold, Joy on hold, Base UI focus, Toolpad status
- [Upgrade to v9](https://mui.com/material-ui/migration/upgrade-to-v9/): Official. Breaking changes, browser floor, codemods
- [Material UI v7 is here](https://mui.com/blog/material-ui-v7-is-here/): Official. Prior major context
- [Pigment CSS repo](https://github.com/mui/pigment-css): Open Source. Alpha, on-hold status
- [@mui/material registry metadata](https://registry.npmjs.org/@mui/material/latest): Official. Version 9.4.0, peers
- [Styling direction discussion #45759](https://github.com/mui/material-ui/issues/45759): Community. Styling-engine uncertainty

## License / Usage Notes
Material UI core is MIT. MUI X Pro/Premium are commercial. Material Design is Google's design language. This skill summarizes the docs; code is original.

## Quality Tier
A: official migration guide and roadmap verified; the exact `@mui/material-nextjs` entry names per Next.js major should be checked against the docs.

## Status
Active

## Last Verified
2026-09-15
