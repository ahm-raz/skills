# shadcn/ui

## Summary
shadcn/ui is an open-code component distribution system, not an npm component library. A CLI copies TSX source into your repo. The components sit on a headless primitive layer (Base UI by default since July 2026, Radix or React Aria optionally) and are styled with Tailwind CSS v4 and CSS variables. By September 2026 it has become an ecosystem: CLI v4 with project templates and presets, namespaced registries (public, private, GitHub), an MCP server, and an official agent skill.

## Category
UI Libraries

## Subcategories
Open-code components, shadcn CLI, registries, components.json, presets, Base UI / Radix / React Aria bases, Tailwind v4 theming, MCP, agent skills

## Problem It Solves
Teams want polished, accessible components they fully own. They don't want a black-box dependency whose styling they fight, or version upgrades that break customizations. shadcn/ui puts the code in your repo, keeps behavior in a maintained headless library, and adds a distribution protocol (the registry) so organizations can ship their own design system the same way.

## When To Use
- React/Next.js apps using Tailwind CSS v4 that need a design-system starting point you can freely modify.
- Building an internal design system distributed via a private registry (`registries` in components.json).
- AI-assisted development. The CLI, `shadcn docs`, the MCP server and the official skill give agents reliable context.
- Apps that want a choice of primitive layer (Base UI, Radix, React Aria) behind a consistent styling API.

## When Not To Use
- Teams that want upstream fixes delivered via `npm update` without owning component code. Prefer Mantine, MUI or Chakra.
- Projects that cannot adopt Tailwind (e.g. a Sass/CSS-in-JS mandated stack).
- Very dense enterprise data apps needing a full data grid, scheduler and tree-table out of the box. Consider Ant Design, PrimeReact or MUI X, or pair shadcn with TanStack Table.

## Core Principles
1. **You own the code.** Components live in `components/ui`. Customize by editing them, not by overriding from outside.
2. **Behavior comes from the base, looks come from Tailwind.** Accessibility and interaction logic live in Base UI, Radix or React Aria. Visuals come from utility classes and semantic tokens.
3. **Semantic tokens only.** Use `bg-primary` and `text-muted-foreground`, never raw palette colors, so theming works.
4. **The CLI is the source of truth.** Add, update, diff and migrate through `shadcn`, not by copying from GitHub.
5. **Composition over configuration.** Use compound parts (`CardHeader`, `DialogTitle`) rather than prop-heavy monoliths.

## Best Practices
- Run `npx shadcn@latest info` first. It reports framework, base (radix/base/aria), aliases, icon library and installed components.
- Use `npx shadcn@latest docs <component>` before writing usage code. APIs differ between bases (`asChild` on Radix vs `render` on Base UI).
- Preview updates with `shadcn add <c> --dry-run` or `--diff`. Never use `--overwrite` without explicit approval, because it destroys local edits.
- Use `className` for layout (margins, width, grid placement). Change visual variants inside the component with `cva` variants.
- Use `flex gap-*` instead of `space-x-*`/`space-y-*`, and `size-*` when width equals height (official skill rules).
- Forms: use `FieldGroup` + `Field`, `data-invalid` on `Field`, and `aria-invalid` on the control.
- Every overlay needs a title (`DialogTitle`, `SheetTitle`, `DrawerTitle`). Use `sr-only` if it must be visually hidden.
- Adopt the `cn` package (September 2026) via `shadcn migrate cn` so registry components and local code share one helper.
- On Radix projects, run `shadcn migrate radix` (February 2026) to move from `@radix-ui/react-*` packages to the unified `radix-ui` package.

## Implementation Guidance
**Initialize (CLI v4, March 2026)**
```bash
pnpm dlx shadcn@latest init --template next          # also: vite, react-router, tanstack-start, astro, laravel
pnpm dlx shadcn@latest init --base base              # base | radix | aria  (base is default since July 2026)
pnpm dlx shadcn@latest init --preset <code>          # apply a shared design-system preset
pnpm dlx shadcn@latest add button dialog field
```

**components.json (key fields)**
```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "tailwind": { "config": "", "css": "app/globals.css", "baseColor": "neutral", "cssVariables": true, "prefix": "" },
  "rsc": true,
  "tsx": true,
  "aliases": { "components": "@/components", "ui": "@/components/ui", "lib": "@/lib", "hooks": "@/hooks", "utils": "@/lib/utils" },
  "registries": {
    "@acme": { "url": "https://registry.acme.dev/r/{name}.json", "headers": { "Authorization": "Bearer ${REGISTRY_TOKEN}" } }
  }
}
```
- `rsc: true` makes the CLI add `"use client"` to interactive components.
- With Tailwind v4, leave `tailwind.config` empty. Tokens live in CSS (`@theme inline`).
- Registry auth uses `${ENV_VAR}` interpolation. Never commit literal tokens.

**Choosing a base**
| Base | Choose when | Composition prop |
|---|---|---|
| Base UI (default) | New projects; actively developed by the MUI/Radix/Floating UI authors | `render={<Button />}` |
| Radix | Existing projects; mature; no migration required | `asChild` |
| React Aria | Strong i18n, date/number, drag and drop, and mobile interaction needs | RAC render props |

**Theming (Tailwind v4)**
Define CSS variables in `:root` / `.dark`, then map them with `@theme inline { --color-primary: var(--primary); }`. Presets (`shadcn apply <code> --only theme,font`) rewrite these tokens in bulk.

## Recommended Workflow
1. `shadcn info` to learn the base, aliases and icon library. Check what is already installed.
2. `shadcn search -q "<term>"` or `shadcn docs <component>` to find the right component and API.
3. `shadcn add` the components (or `@registry/item` for namespaced registries). Ask which registry if unspecified.
4. Compose in feature components. Keep `components/ui` edits intentional and minimal.
5. For upstream updates, `shadcn add <c> --diff`, then merge by hand.
6. Verify keyboard, focus and dark mode, then run type-check and lint.

## Patterns
- **Private design-system registry**: publish `registry.json` items (`registry:ui`, `registry:block`, `registry:base`, `registry:font`). Validate with `shadcn registry validate`. Compose large registries with `include` (May 2026).
- **GitHub registry**: `shadcn add acme/internal-toolkit/auth-kit` uses `gh auth` credentials locally and `GH_TOKEN` in CI (August 2026).
- **Wrapper, not fork**: for product-specific behavior, create `components/app/confirm-dialog.tsx` that composes `ui/dialog` instead of bloating the primitive.
- **Variant extension**: add variants to the component's `cva` definition, keeping the typed `VariantProps`.
- **Eject**: `shadcn eject` extracts components when you want to decouple from registry updates (May 2026).

## Anti-Patterns
- **Hardcoding `@/components/ui`**: aliases vary. Read `aliases` from components.json.
- **Mixing `asChild` and `render`**: the wrong prop for the base silently fails or renders nested buttons. Check the base first.
- **Raw colors (`bg-blue-500`) in app code**: breaks theming and dark mode. Use semantic tokens or add a new token.
- **Hand-rolled toasts, empty states and callouts**: use `Toast`/`Sonner`, `Empty` and `Alert` from the registry.
- **Treating shadcn as a dependency to upgrade**: there is no `npm update`. Plan a periodic `--diff` review.
- **Forcing a Radix-to-Base UI migration**: not required. If you do it, go component by component with the migration skill and review behavior changes.

## Accessibility
- Inherits ARIA, keyboard and focus management from the base (Radix, Base UI and React Aria all follow WAI-ARIA APG patterns).
- Custom edits can break a11y. Keep the primitive parts (Title, Description, Trigger) and don't swap semantic elements without `render`/`asChild`.
- Icons in buttons need an accessible name (visible text or `aria-label`). Icon-only buttons use `size="icon"` plus `aria-label`.
- Verify focus-visible styles survive token changes (WCAG 2.4.7, 2.4.11) and color contrast of `muted-foreground` (1.4.3).
- RTL support is built in (January 2026). Prefer logical `start`/`end` utilities.

## Responsive Design
- Components are layout-agnostic. Handle responsiveness in composition (`md:grid-cols-2`, container queries `@container`).
- Use Dialog on desktop and Drawer on mobile (media-query hook) for touch-friendly sheets.
- `Sidebar` supports collapsible/offcanvas modes on small screens.

## Performance
- Only installed components ship. There is no library-wide bundle.
- Base cost is the primitive package plus `class-variance-authority` and `cn` (clsx + tailwind-merge).
- `"use client"` components hydrate. Keep them leaf-level and render static shells (Card, Badge, typography) as Server Components.
- `tailwind-merge` runs at runtime on every `cn` call. Avoid `cn` in very hot render loops (large lists); precompute class strings.

## Security
- Registry items are arbitrary code, and installing one is equivalent to adding a dependency. Review diffs (`--view`, `--dry-run`) and pin trusted registries.
- Private registry tokens go in env vars referenced as `${REGISTRY_TOKEN}`, never in components.json literals.
- Treat third-party registries (animation kits, blocks) as supply-chain inputs. See dependency-supply-chain-security.

## Testing
- Unit/component tests with Testing Library query by role (`getByRole("dialog", { name })`), which validates base semantics.
- Portaled overlays render in `document.body`. Use `screen` queries, not container queries.
- Visual regression (Storybook + Chromatic/Playwright) after preset or token changes.
- Run axe in Playwright on key pages after customizing components.

## Tooling
- `shadcn` CLI v4 (active): `init`, `add`, `info`, `docs`, `search`, `apply`, `preset`, `migrate`, `eject`, `registry validate`.
- shadcn MCP server (active since CLI 3.0, August 2025) for browsing and installing registry items from agents.
- Official agent skill: `skills/shadcn` in the shadcn-ui/ui repo (SKILL.md, cli.md, registry.md, mcp.md, customization.md).
- `cn` package (September 2026), `class-variance-authority`, `tailwind-merge`, `tw-animate-css`.

## Framework Notes
- **Next.js App Router**: set `rsc: true`. Interactive components carry `"use client"`, so import them freely from Server Components but pass only serializable props. Theme switching usually uses `next-themes` in a client `ThemeProvider` with `suppressHydrationWarning` on `<html>`.
- **React (Vite SPA)**: use `init --template vite`, set `rsc: false`, and configure the `@/*` alias in both `tsconfig` and `vite.config.ts`.
- React 19 is supported (October 2025). `forwardRef` is removed in favor of ref-as-prop in current components.

## AI Agent Guidance
- DO run `shadcn info` and read `components.json` before generating imports or picking `asChild` vs `render`.
- DO use `shadcn docs <component>` rather than memory. APIs changed across bases and 2026 releases.
- DO use the project's package runner (`pnpm dlx`, `npx`, `bunx --bun`).
- DON'T hand-edit files fetched from GitHub. Use the CLI. DON'T pass `--overwrite` without approval.
- DON'T assume lucide-react. Check `iconLibrary`.
- DON'T decode preset codes by hand. Use `shadcn preset decode`.
- Before declaring done, check that type-check passes, overlays have titles, no raw color utilities were added, and dark mode and keyboard navigation work.

## Examples
```tsx
// app/settings/delete-account.tsx  (Base UI base)
"use client";
import { Button } from "@/components/ui/button";
import {
  Dialog, DialogTrigger, DialogContent, DialogHeader,
  DialogTitle, DialogDescription, DialogFooter, DialogClose,
} from "@/components/ui/dialog";

export function DeleteAccount({ onConfirm }: { onConfirm: () => Promise<void> }) {
  return (
    <Dialog>
      <DialogTrigger render={<Button variant="destructive" />}>Delete account</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delete account?</DialogTitle>
          <DialogDescription>This permanently removes your data.</DialogDescription>
        </DialogHeader>
        <DialogFooter className="gap-2">
          <DialogClose render={<Button variant="outline" />}>Cancel</DialogClose>
          <Button variant="destructive" onClick={onConfirm}>Delete</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
// Radix base equivalent: <DialogTrigger asChild><Button variant="destructive">...</Button></DialogTrigger>
```

```tsx
// Extending a variant inside components/ui/button.tsx
const buttonVariants = cva("inline-flex items-center gap-2 rounded-md text-sm font-medium", {
  variants: {
    variant: {
      default: "bg-primary text-primary-foreground hover:bg-primary/90",
      success: "bg-success text-success-foreground hover:bg-success/90", // new token in globals.css
    },
    size: { default: "h-9 px-4", icon: "size-9" },
  },
  defaultVariants: { variant: "default", size: "default" },
});
```

## Related Skills
- [base-ui](../base-ui/Skill.md): default primitive layer
- [radix-ui-primitives](../radix-ui-primitives/Skill.md): alternative base, legacy default
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md): third base option
- [tailwind-css-v4](../tailwind-css-v4/Skill.md): styling engine
- [tailwind-design-system-architecture](../tailwind-design-system-architecture/Skill.md): tokens and variants at scale
- [theming-with-css-variables](../theming-with-css-variables/Skill.md): token model
- [animated-component-collections](../animated-component-collections/Skill.md): third-party registries
- [small-ui-primitives-vaul-sonner-cmdk](../small-ui-primitives-vaul-sonner-cmdk/Skill.md): Drawer/Toast/Command internals
- [mcp-for-frontend-development](../mcp-for-frontend-development/Skill.md): shadcn MCP server
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): shadcn vs packaged libraries

## Sources
- [shadcn/ui Changelog](https://ui.shadcn.com/docs/changelog): Official. 2025-2026 timeline (Base UI default, cn package, registries, eject, presets)
- [shadcn CLI v4 (March 2026)](https://ui.shadcn.com/docs/changelog/2026-03-cli-v4): Official. Templates, `--base`, presets, `info`/`docs`, dry-run/diff
- [CLI 3.0 and MCP (August 2025)](https://ui.shadcn.com/docs/changelog/2025-08-cli-3-mcp): Official. Namespaced registries, MCP server
- [components.json](https://ui.shadcn.com/docs/components-json): Official. Config schema, registries with headers
- [Unified Radix UI package (February 2026)](https://ui.shadcn.com/docs/changelog/2026-02-radix-ui): Official. `migrate radix`
- [Base UI as default (July 2026)](https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default): Official. No forced migration; skill-based migration
- [React Aria base (July 2026)](https://ui.shadcn.com/docs/changelog/2026-07-react-aria): Official. `--base aria`
- [Registry include/validate (May 2026)](https://ui.shadcn.com/docs/changelog/2026-05-registry-include): Official
- [Drawer (Base UI)](https://ui.shadcn.com/docs/components/base/drawer): Official. Vaul replaced by Base UI Drawer
- [shadcn agent skill SKILL.md](https://raw.githubusercontent.com/shadcn-ui/ui/main/skills/shadcn/SKILL.md): Open Source. Agent rules for composition, styling and the CLI

## License / Usage Notes
shadcn/ui is MIT. Copied component code becomes your code. Underlying bases: Base UI MIT, Radix MIT, React Aria Apache-2.0. Third-party registries carry their own licenses; check before installing. This skill summarizes the docs and does not copy them.

## Quality Tier
S: official, very active (monthly 2026 releases), verified against the changelog and the official agent skill.

## Status
Active

## Last Verified
2026-09-15
