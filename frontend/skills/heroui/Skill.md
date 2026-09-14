# HeroUI (formerly NextUI)

## Summary
HeroUI is a styled React component library (renamed from NextUI in 2025). v3 (released March 2026, `@heroui/react` 3.2.5 as of September 2026) is a ground-up rewrite on **React Aria Components** for behavior and **Tailwind CSS v4** for styling. It has 75+ web components, a compound component API with no provider wrapper, CSS-only animations, and theming via CSS variables with OKLCH colors and BEM-style modifiers. A separate `heroui-native` targets React Native. It requires React 19+ and Tailwind 4+.

## Category
UI Libraries

## Subcategories
React Aria Components, Tailwind v4, tailwind-variants, compound components, CSS variable theming, OKLCH, v2 to v3 migration, MCP server, agent skills

## Problem It Solves
It offers attractive, accessible, Tailwind-native components with npm-style upgrades (unlike shadcn's copy-in model). The accessibility depth of React Aria comes without writing your own styled wrappers.

## When To Use
- Tailwind v4 + React 19 apps wanting polished defaults and React Aria-grade accessibility with low setup.
- Teams preferring a versioned dependency over owning component source.
- Products spanning web and React Native wanting one design language (HeroUI + HeroUI Native).

## When Not To Use
- React 18 or Tailwind v3 projects (hard peer requirements).
- Existing HeroUI/NextUI v2 apps without migration budget. v2 and v3 cannot coexist, and several v2 features were removed.
- Teams needing full control of component internals. Use shadcn/ui (with `--base aria` if React Aria is desired).

## Core Principles
1. **Behavior from React Aria Components, styling from Tailwind v4** (`@heroui/styles` with tailwind-variants).
2. **Compound components** (e.g. `Card.Header`, `Modal.Content` style anatomy) replace v2's prop-heavy slot APIs. There is no `HeroUIProvider` requirement.
3. **Theme = CSS variables** (OKLCH), overridable in your CSS. Variants and modifiers follow BEM-like naming.
4. **CSS-first animation**: no framer-motion runtime.
5. **React Aria semantics**: `onPress`, `isDisabled`, `selectedKeys`, `@internationalized/date` for dates.

## Best Practices
- Install peers explicitly and keep React Aria packages aligned with HeroUI's peer ranges (`react-aria-components ^1.21`, `react-aria ^3.52`).
- Import HeroUI styles into your Tailwind v4 entry CSS as documented, then override theme CSS variables in `:root` / `.dark`.
- Use RAC event props (`onPress`), not `onClick`, on HeroUI interactive components.
- Use the HeroUI MCP server or `llms.txt` for current v3 APIs. Most online examples are v2.
- Use `tailwind-merge`-aware `className` overrides sparingly. Prefer variants and theme variables.
- Plan v2 to v3 migration with the official full or incremental guides and the migration MCP server.

## Implementation Guidance
```bash
pnpm add @heroui/react react-aria-components react-aria @react-aria/ssr @react-aria/i18n @react-aria/utils
# tailwindcss >= 4 must already be configured
```
CSS entry (check the exact import path in the HeroUI v3 install docs):
```css
@import "tailwindcss";
@import "@heroui/styles";   /* verify path */

:root {
  --accent: oklch(0.62 0.19 265);      /* token names illustrative; use names from HeroUI theming docs */
}
.dark {
  --accent: oklch(0.72 0.16 265);
}
```

**v2 to v3 migration**
| v2 (NextUI/HeroUI) | v3 |
|---|---|
| `HeroUIProvider` required | No provider wrapper |
| framer-motion animations | CSS animations |
| Tailwind v3 plugin (`heroui()` in config) | Tailwind v4 CSS-first styles |
| Prop/slot-based `classNames={{ base, label }}` | Compound components + BEM modifiers |
| `Image` component | Removed; use `next/image` or `<img>` |
| Some v2 features (label animations, autocomplete variants, Navbar) | Removed or changed; check component list |
| Coexistence | v2 and v3 cannot be installed together |

## Recommended Workflow
1. Confirm React 19 and Tailwind v4. Install peers.
2. Add styles to CSS. Define brand tokens as CSS variables for light and dark.
3. Build screens with compound components. Wrap repeated compositions in app components.
4. For v2 apps, choose full vs incremental migration. Migrate route by route, using the migration MCP server if useful.
5. Test keyboard and screen readers (inherited from RAC) and visual themes.

## Patterns
- **Theme per tenant**: set CSS variables on a wrapper element (`style={{ "--accent": tenant.color }}`) since theming is variable-based.
- **Next.js links**: use RAC `RouterProvider` with `useRouter().push` so HeroUI `href` components navigate client-side.
- **Form composition**: RAC `Form` validation (`isRequired`, `validate`) with HeroUI field components. Server errors via `validationErrors`.
- **Dark mode**: toggle `.dark` class via `next-themes`. Tokens switch automatically.

## Anti-Patterns
- **Copying v2 examples** (`HeroUIProvider`, `@nextui-org/*` imports, `classNames` slot objects): won't work in v3.
- **`onClick` on HeroUI buttons**: bypasses React Aria press handling. Use `onPress`.
- **Mixing `@nextui-org/*` and `@heroui/*` packages**: duplicate React Aria contexts.
- **Overriding internals with deep selectors** instead of variables/modifiers: brittle between minors.
- **Assuming roadmap transparency**: community feedback noted missing v2 components. Verify component availability before committing.

## Accessibility
- Inherits React Aria's APG-compliant behavior, i18n and screen-reader testing, among the strongest of the styled libraries.
- Check the contrast of OKLCH theme overrides (WCAG 1.4.3) and focus-ring visibility (2.4.7/2.4.11).
- Provide labels for icon-only buttons (`aria-label`).
- CSS animations should respect `prefers-reduced-motion`. Verify the library's defaults and add `motion-reduce:` overrides if needed.

## Responsive Design
- Tailwind v4 responsive utilities apply to `className`.
- Overlays (Modal/Drawer/Popover) inherit RAC positioning. Style modals as sheets on small screens.
- Container queries are available through Tailwind v4 (`@container`).

## Performance
- No framer-motion runtime in v3. CSS animations reduce JS.
- RAC is heavier than Radix/Base UI, but tree-shaken per component.
- Components are client components. Keep static content in Server Components.

## Security
- No HTML injection APIs. Sanitize user content.
- License: MIT per npm metadata (`@heroui/react` 3.2.5). One press article cited Apache-2.0, so check the repo LICENSE for your compliance records. HeroUI Pro (heroui.pro) is a commercial add-on.

## Testing
- Use `userEvent` with pointer events for RAC press semantics.
- Role-based queries. Test themes via visual regression (light/dark and brand variables).
- Playwright for overlays and date components.

## Tooling
- `@heroui/react` 3.2.5, `@heroui/styles`, `tailwind-variants` 3.x, `tailwind-merge` 3.x, `heroui-native`.
- HeroUI MCP server, Agent Skills, `llms.txt`, Figma Kit v3.
- HeroUI Pro (premium composable components, commercial).

## Framework Notes
- **Next.js App Router**: components are client components, so use them in `"use client"` files (or rely on package directives if present; verify). No provider is required for styling, but add RAC `RouterProvider` in a client providers file for client-side `href` navigation. v3.1 fixed SSR issues in `useTheme`, so stay current.
- **React (Vite SPA)**: Tailwind v4 via `@tailwindcss/vite`, then install HeroUI and peers.
- React >= 19 required.

## AI Agent Guidance
- DO check `@heroui/react` major. v2 and v3 APIs are incompatible, and most web examples are v2.
- DO use the HeroUI MCP server or docs for current anatomy. Don't guess CSS variable names.
- DO use `onPress`/`isDisabled` (React Aria conventions).
- DON'T add `HeroUIProvider` in v3 or reference `@nextui-org/*`.
- Verify before done: peers installed and aligned, styles imported in Tailwind entry, dark mode tokens defined, no console React Aria warnings (missing labels).

## Examples
```tsx
"use client";
// Illustrative v3-style usage. Confirm exact subcomponent names in the HeroUI v3 docs.
import { Button, Card } from "@heroui/react";

export function PlanCard({ name, price, onChoose }: { name: string; price: string; onChoose: () => void }) {
  return (
    <Card className="w-72">
      <Card.Header>
        <Card.Title>{name}</Card.Title>
        <Card.Description>{price} / month</Card.Description>
      </Card.Header>
      <Card.Footer>
        <Button onPress={onChoose} className="w-full">Choose {name}</Button>
      </Card.Footer>
    </Card>
  );
}
```
```tsx
// app/providers.tsx
"use client";
import { RouterProvider } from "react-aria-components";
import { useRouter } from "next/navigation";
import { ThemeProvider } from "next-themes";

export function Providers({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  return (
    <ThemeProvider attribute="class">
      <RouterProvider navigate={router.push}>{children}</RouterProvider>
    </ThemeProvider>
  );
}
```

## Related Skills
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md): behavior foundation
- [tailwind-css-v4](../tailwind-css-v4/Skill.md): styling engine
- [shadcn-ui](../shadcn-ui/Skill.md): owned-code alternative (Aria base available)
- [theming-with-css-variables](../theming-with-css-variables/Skill.md): OKLCH token theming
- [color-systems](../color-systems/Skill.md): OKLCH palettes
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [HeroUI v3 rewrite (InfoQ, July 2026)](https://www.infoq.com/news/2026/07/heroui-v3-rewrite/): Community. Architecture, migration, reception, AI tooling
- [HeroUI home](https://heroui.com/): Official. v3 positioning
- [Introducing HeroUI v3 (Pro)](https://heroui.pro/docs/react/releases/v3-0-0): Official. Release context
- [@heroui/react registry metadata](https://registry.npmjs.org/@heroui/react/latest): Official. Version 3.2.5, peers, MIT
- [HeroUI Tailwind v4 guide (beta)](https://beta.heroui.com/docs/guide/tailwind-v4): Official. Tailwind v4 context
- [HeroUI v2.8.0](https://www.heroui.com/blog/v2.8.0): Official. Last v2 line context

## License / Usage Notes
`@heroui/react` npm metadata states MIT (a press article mentions Apache-2.0; confirm in the repo). HeroUI Pro is commercial. The v3 docs pages could not be fetched directly (404/403), so component anatomy in the examples is illustrative and must be verified.

## Quality Tier
B: release facts, peers and migration themes verified via npm and InfoQ, but official v3 docs were not directly retrievable, so exact component anatomy and CSS variable names are unverified.

## Status
Active

## Last Verified
2026-09-15
