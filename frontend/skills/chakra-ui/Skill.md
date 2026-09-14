# Chakra UI

## Summary
Chakra UI v3 (`@chakra-ui/react` 3.37.0, MIT) is a styled, themeable React component library. It combines Ark UI (Zag.js state machines) for behavior with a Panda-CSS-inspired styling API (tokens, semantic tokens, recipes, slot recipes) running on Emotion. v3 (October 2024) was a ground-up redesign: `createSystem` replaced `extendTheme`, framer-motion was dropped in favor of CSS animations, and many compound components became snippet-based (copied into your repo via CLI).

## Category
UI Libraries

## Subcategories
Style props, tokens/semantic tokens, recipes, slot recipes, createSystem, Ark UI, snippets CLI, color mode with next-themes, v2 to v3 migration

## Problem It Solves
It gives product teams fast, prop-based styling (`<Box p="4" bg="bg.muted">`) with a real token system and accessible components, without writing CSS files or adopting Tailwind.

## When To Use
- Product teams that like style props and a typed token system, and want a styled library they can theme deeply.
- Apps where Ark UI's breadth (DatePicker, ColorPicker, Tree View, File Upload, Tags Input) is valuable with ready styling.
- Existing Chakra v2 codebases planning a v3 migration.

## When Not To Use
- Tailwind v4-first projects (use shadcn/ui or HeroUI) or performance-critical content sites (Emotion runtime).
- Teams wanting zero-runtime CSS. Use Panda CSS + Park UI/Ark UI directly.
- Migrations from v2 without budget. v3 breaks many APIs and requires component-by-component work.

## Core Principles
1. **System, not theme object**: `createSystem(defaultConfig, defineConfig({...}))` produces the styling engine passed to `ChakraProvider value={system}`.
2. **Tokens vs semantic tokens**: raw scales (`colors.brand.500`) vs meaning (`bg.muted`, `fg.error`) that switch with color mode via `_dark` conditions.
3. **Recipes**: `defineRecipe` for single-part and `defineSlotRecipe` for multi-part components, with `variants`, `compoundVariants`, `defaultVariants`.
4. **Compound components**: `Dialog.Root`, `Dialog.Trigger`, `Dialog.Content` (Ark UI anatomy) with `asChild`.
5. **Snippets**: ready-made compositions (e.g. `color-mode`, `toaster`, `tooltip`) added with the CLI into `components/ui`.

## Best Practices
- Run `npx @chakra-ui/cli typegen ./theme.ts` after changing tokens/recipes to get typed props.
- Use semantic tokens in components (`bg="bg.panel"`, `color="fg.muted"`) so dark mode is automatic.
- Handle color mode with `next-themes` (the v3 guidance). Chakra v3 doesn't ship its own `ColorModeProvider`, so use the `color-mode` snippet.
- Add snippets with `npx @chakra-ui/cli snippet add <name>` and customize them in your repo.
- Use `hideMode` on Dialog/Drawer/Accordion (recent 3.x) to choose `display: none` or React 19 `Activity` for closed content.
- Use `data-autofocus` on an element inside Dialog/Drawer to set initial focus without refs.
- Keep `system` at module scope. Rebuilding it re-injects styles.

## Implementation Guidance
```bash
pnpm add @chakra-ui/react @emotion/react
npx @chakra-ui/cli snippet add        # provider, color-mode, toaster, etc.
```
```ts
// theme.ts
import { createSystem, defaultConfig, defineConfig, defineRecipe } from "@chakra-ui/react";

const badge = defineRecipe({
  base: { borderRadius: "full", px: "2", fontWeight: "medium" },
  variants: { tone: { success: { bg: "green.subtle", color: "green.fg" }, danger: { bg: "red.subtle", color: "red.fg" } } },
  defaultVariants: { tone: "success" },
});

const config = defineConfig({
  theme: {
    tokens: { colors: { brand: { 500: { value: "#5b5bd6" }, 600: { value: "#4a4ac4" } } } },
    semanticTokens: { colors: { "brand.solid": { value: { _light: "{colors.brand.500}", _dark: "{colors.brand.600}" } } } },
    recipes: { statusBadge: badge },
  },
});

export const system = createSystem(defaultConfig, config);
```
**v2 to v3 migration map**
| v2 | v3 |
|---|---|
| `extendTheme` | `createSystem` + `defineConfig` |
| `ChakraProvider theme={}` | `ChakraProvider value={system}` |
| `useColorMode` (built-in) | `next-themes` + color-mode snippet |
| `Modal` | `Dialog` (compound) |
| framer-motion transitions | CSS animations |
| `isDisabled`, `isOpen` | `disabled`, `open` |
| `colorScheme` | `colorPalette` |
| `@chakra-ui/icons` | `lucide-react`/`react-icons` |

## Recommended Workflow
1. Scaffold the provider snippet, then configure the system (tokens, semantic tokens, recipes).
2. Run typegen and commit the generated types (or generate in CI).
3. Build app components with recipes (`useRecipe`/`chakra()` factory) instead of ad hoc style props for repeated patterns.
4. Wire color mode with next-themes and verify SSR without flash.
5. Test keyboard and focus for overlays. Check bundle impact.

## Patterns
- **Recipe-backed component**: `const StatusBadge = chakra("span", badgeRecipe)`, which gives variant props typed from the recipe.
- **`colorPalette` switch**: `<Button colorPalette="red">`, where components read palette-relative tokens (`colorPalette.solid`).
- **Toaster outside React**: create `toaster` via `createToaster` (snippet) and call `toaster.create({...})` from mutation handlers.
- **`asChild` links**: `<Button asChild><NextLink href="/x">Go</NextLink></Button>`.

## Anti-Patterns
- **Copying v2 examples** (`extendTheme`, `Modal`, `isOpen`, `useColorMode`): won't compile on v3.
- **Raw color tokens everywhere** (`bg="gray.100"`): dark mode breaks. Use semantic tokens.
- **Style props inside hot lists** (thousands of rows): Emotion serialization cost. Use recipes/classNames or virtualization.
- **Defining `system` inside a component**: repeated style injection.
- **Skipping typegen**: custom tokens and recipes become `any`-ish or error-prone.

## Accessibility
- Behavior from Ark UI/Zag.js follows WAI-ARIA APG (focus trap, roving tabindex, typeahead).
- Chakra adds focus rings via the `focusRing` utilities. Verify contrast after theming.
- Form: `Field.Root` with `invalid`, `Field.Label`, `Field.ErrorText` wire ARIA automatically.
- Your responsibility: labels on icon buttons (`aria-label`), reduced motion for custom animations, contrast in both modes.

## Responsive Design
- Responsive style props: `p={{ base: "4", md: "8" }}` or array syntax. Breakpoints are configurable in the system.
- Container queries via `_container`-style conditions or `css` prop (check current docs).
- Drawer `placement` with responsive values for mobile sheets.

## Performance
- Emotion runtime plus a large default token set. v3 improved style resolution by initializing the engine outside React and removing framer-motion.
- Reduce cost with recipes, fewer dynamic style props, `hideMode` / lazy mounting of overlays, and Server Component shells for static parts.
- Consider Panda CSS + Park UI when zero runtime matters.

## Security
- No HTML injection APIs by default. MIT. Snippets copied into your repo are your code to maintain and audit.

## Testing
- Render with `ChakraProvider value={system}` in the test wrapper.
- Role-based queries. Ark UI parts expose `data-scope`/`data-part` for stable test selectors when roles are insufficient.
- Visual regression after token/recipe changes.

## Tooling
- `@chakra-ui/react` 3.37.0 (peer `@emotion/react >=11`, React 18+), `@chakra-ui/cli` (snippets, typegen, eject).
- Ark UI v5.39 underneath. Park UI (Ark + Panda) is the zero-runtime sibling.
- No v4 announcement found as of September 2026.

## Framework Notes
- **Next.js App Router**: create `components/ui/provider.tsx` with `"use client"` wrapping `ChakraProvider` + `ThemeProvider` (next-themes, `attribute="class"`). Add `suppressHydrationWarning` on `<html>`. Chakra components need client context, so keep data fetching in Server Components and pass props. Add `experimental.optimizePackageImports: ["@chakra-ui/react"]` in next.config for faster dev and builds (recommended in the Chakra docs; verify for your Next version).
- **React (Vite SPA)**: same provider without next-themes SSR concerns.
- React 18/19 supported.

## AI Agent Guidance
- DO confirm the v3 major, then use `open`/`disabled`/`colorPalette` and compound components.
- DO use snippets (`components/ui/*`) already in the repo before creating new wrappers.
- DON'T mix Tailwind utilities into Chakra components unless the project already does with layer config.
- Verify before done: typegen run, dark mode via semantic tokens, no v2 APIs, no hydration warnings.

## Examples
```tsx
// components/ui/provider.tsx
"use client";
import { ChakraProvider } from "@chakra-ui/react";
import { ThemeProvider } from "next-themes";
import { system } from "@/theme";

export function Provider({ children }: { children: React.ReactNode }) {
  return (
    <ChakraProvider value={system}>
      <ThemeProvider attribute="class" disableTransitionOnChange>{children}</ThemeProvider>
    </ChakraProvider>
  );
}
```
```tsx
"use client";
import { Button, Dialog, Portal, CloseButton } from "@chakra-ui/react";

export function InviteDialog() {
  return (
    <Dialog.Root placement="center">
      <Dialog.Trigger asChild>
        <Button colorPalette="brand">Invite</Button>
      </Dialog.Trigger>
      <Portal>
        <Dialog.Backdrop />
        <Dialog.Positioner>
          <Dialog.Content>
            <Dialog.Header><Dialog.Title>Invite teammate</Dialog.Title></Dialog.Header>
            <Dialog.Body color="fg.muted">They will receive an email invitation.</Dialog.Body>
            <Dialog.Footer>
              <Dialog.ActionTrigger asChild><Button variant="outline">Cancel</Button></Dialog.ActionTrigger>
              <Button data-autofocus>Send</Button>
            </Dialog.Footer>
            <Dialog.CloseTrigger asChild><CloseButton size="sm" /></Dialog.CloseTrigger>
          </Dialog.Content>
        </Dialog.Positioner>
      </Portal>
    </Dialog.Root>
  );
}
```

## Related Skills
- [ark-ui-and-park-ui](../ark-ui-and-park-ui/Skill.md): behavior layer and zero-runtime sibling
- [css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md): Emotion trade-offs
- [design-token-architecture](../design-token-architecture/Skill.md): tokens and semantic tokens
- [dark-mode-implementation](../dark-mode-implementation/Skill.md): next-themes integration
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [Announcing Chakra UI v3](https://chakra-ui.com/blog/announcing-v3): Official. Ark + Panda-style APIs, CSS animations
- [Chakra theming customization](https://chakra-ui.com/docs/theming/customization/overview): Official. createSystem, defineConfig, typegen, eject
- [Chakra UI releases](https://github.com/chakra-ui/chakra-ui/releases): Open Source. 3.37.0 features (DateInput, hideMode, data-autofocus)
- [@chakra-ui/react registry metadata](https://registry.npmjs.org/@chakra-ui/react/latest): Official. Version and peers
- [Chakra, Panda and Ark: what's the plan?](https://www.adebayosegun.com/blog/chakra-panda-and-ark-whats-the-plan): Community (maintainer). Strategy

## License / Usage Notes
Chakra UI is MIT, as is Ark UI. Snippets become your code. Summarized content; examples are original.

## Quality Tier
A: official v3 docs and release notes verified; some convenience details (optimizePackageImports, container-query conditions) are noted as check-the-docs.

## Status
Active

## Last Verified
2026-09-15
