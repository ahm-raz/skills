# PrimeReact

## Summary
PrimeReact (PrimeTek, MIT) is a large React UI suite known for enterprise data components (DataTable, TreeTable, Calendar/DatePicker, AutoComplete, Charts, Editor). PrimeReact v11 shipped July 15, 2026 (11.1.0 on August 5, 2026). It is a major overhaul offering one suite consumable four ways: Styled (design-token themes), Primitive (headless components), Tailwind (copy-in, shadcn-compatible, via CLI) and Headless hooks. Docs moved to primeui.dev. It requires React 19+. (PrimeVue, the Vue sibling, is out of scope for this React/Next.js library.)

## Category
UI Libraries

## Subcategories
Enterprise components, DataTable, design tokens, theme presets (Aura, Material, Lara, Nora), pass-through props, unstyled/Tailwind mode, headless hooks, v10 to v11 migration

## Problem It Solves
It provides feature-rich data components (sortable, filterable, lazy, virtualized tables; tree tables; complex pickers) with multiple styling strategies. Teams can use a themed suite, bring their own Tailwind design, or consume only behavior hooks.

## When To Use
- Data-dense enterprise apps needing DataTable/TreeTable/Calendar breadth with less assembly than shadcn + TanStack Table.
- Teams that want to choose (or later switch) between a styled theme and Tailwind-owned components within one vendor ecosystem.
- Organizations using PrimeTek across stacks (shared Figma tokens and theme designer).

## When Not To Use
- React 18 projects that cannot upgrade. v11 peers require React >= 19.
- Teams sensitive to large-scale API changes. v11 is a rewrite, and v10 code and examples don't transfer directly.
- Accessibility-critical products without an audit budget. Complex widgets need verification despite WCAG claims.

## Core Principles
1. **Four consumption modes**: Styled (themes), Primitive (unstyled components), Tailwind (source copied via CLI), Headless (hooks such as `useDialog`, standalone `@primereact/hooks`).
2. **Design tokens in tiers** (primitive, semantic, component) power the theme engine using CSS variables. Presets: Aura, Material, Lara, Nora, with dark mode.
3. **Pass-through (pt) props** reach internal elements for attributes and classes without forking.
4. **Compound/primitive anatomy in v11** (e.g. `<Dialog>`, `<Dialog.Header>`), replacing many prop-driven templates.
5. **Figma-to-theme compatibility**: tokens map to the theme designer.

## Best Practices
- Pick one mode per app (or per design-system layer). Mixing Styled and Tailwind copies causes duplicated CSS and inconsistent tokens.
- Start with a preset and override semantic tokens (primary, surface) before component tokens.
- For DataTable, use lazy mode (server-side paging/sorting/filtering) plus virtual scrolling for large datasets.
- Use pass-through props for test ids, ARIA additions and utility classes instead of CSS descendant selectors.
- Treat v10 to v11 as a migration project. Consult the primeui.dev migration notes per component and upgrade screen by screen.
- Use the PrimeTek MCP server (v11) for component API lookup in AI-assisted workflows.

## Implementation Guidance
| Mode | Choose when | Styling source |
|---|---|---|
| Styled | Fast delivery, consistent theme, theme designer | Token presets (CSS variables) |
| Tailwind | Design system in Tailwind v4, code ownership | Copied source (shadcn-compatible) |
| Primitive | Custom CSS/CSS Modules on unstyled parts | Your CSS |
| Headless hooks | Fully custom markup | Your markup + CSS |

Package names, provider components and CLI commands changed in v11 and are documented at primeui.dev. Verify exact imports there before coding; this skill does not reproduce them to avoid stale API guesses.

**Migration notes (v10 to v11)**
- React 19 minimum.
- Theming moves to token-based presets and CSS variables. Legacy theme CSS files and `PrimeReactProvider` configuration patterns change.
- Compound component anatomy replaces many template props. Check each component.
- Tailwind "unstyled + pt" setups from v10 can move to the new Tailwind copy-in mode.
- In the v11 progress thread, AutoComplete, Select and DataTable were the last components completed. Test them thoroughly.

## Recommended Workflow
1. Decide the mode (Styled vs Tailwind vs Primitive/Headless) with design stakeholders.
2. Install per primeui.dev for your mode. Configure the preset or Tailwind tokens.
3. Build a thin app wrapper layer (e.g. `AppDataTable`) that standardizes lazy loading, empty/loading states and pt props.
4. Audit keyboard and screen reader behavior on complex components.
5. Pin minor versions early in the v11 lifecycle and read release notes (11.1 already refined overlays and Sidebar keyboard navigation).

## Patterns
- **Lazy DataTable**: table state (page, rows, sortField, filters) mirrored in URL, fetched via server action or route handler.
- **pt for testability**: `pt={{ root: { "data-testid": "orders-table" } }}`.
- **Token override layer**: define a custom preset extending Aura with brand semantic tokens and export it from `design-system/theme.ts`.
- **Tailwind mode wrapper**: keep copied components in `components/prime/*` and treat them like shadcn components (own, diff, update deliberately).

## Anti-Patterns
- **Copying v10 examples into v11 projects**: APIs and theming differ.
- **Rendering 50k rows client-side** without lazy/virtual mode: memory and INP problems.
- **Styling via `.p-*` internal class selectors**: fragile. Use tokens or pt.
- **Mixing Styled theme CSS with Tailwind mode components** on the same screens: conflicting tokens.

## Accessibility
- PrimeTek states WCAG-compliant keyboard, screen reader and focus behavior across the v11 suite.
- Independently verify complex widgets (DataTable cell navigation, TreeTable, AutoComplete, DatePicker) with NVDA/VoiceOver. Historically these are where suites fall short.
- Provide labels (`aria-label`/`aria-labelledby` via props or pt). Ensure focus indicators survive token changes.

## Responsive Design
- DataTable responsive layouts (stack/scroll) and breakpoints. Verify the v11 option names.
- Overlay components (Sidebar/Drawer, Dialog) support full-screen or mobile positioning. Use breakpoint-based sizes.
- In Tailwind mode, responsiveness is controlled by your utilities.

## Performance
- The Styled suite is heavy. Import components individually and lazy-load data-heavy screens.
- DataTable virtual scrolling and lazy mode are essential for large data.
- The Headless hooks library supports SSR (per v11 notes), enabling lighter custom renders.

## Security
- Editor components: sanitize HTML server-side.
- FileUpload: validate server-side. Client checks are UX only.
- MIT license (LICENSE.md in the repo; npm shows "SEE LICENSE IN LICENSE.md"). Paid add-ons (templates/blocks, if used) have separate licenses.

## Testing
- Use pt to inject stable `data-testid`s where roles are ambiguous (virtualized tables).
- Playwright for DataTable sorting, filtering and pagination flows with mocked APIs.
- Visual regression per preset (light/dark).

## Tooling
- `primereact` 11.1.0 (React >= 19), `@primereact/hooks` (standalone headless hooks), theme presets, theme designer, Figma UI kit, MCP server.
- Docs: primeui.dev (PrimeUI umbrella branding, 2026).

## Framework Notes
- **Next.js App Router**: interactive Prime components are client components, so place them behind `"use client"` wrappers and fetch data in Server Components or route handlers. Configure the theme provider in a client `providers.tsx` included from `app/layout.tsx`. With Styled mode, ensure theme CSS variables are emitted during SSR to avoid FOUC (follow the primeui.dev Next.js guide).
- **React (Vite SPA)**: provider plus preset at root. Tailwind mode uses the Vite Tailwind plugin.
- React 19 required in v11.

## AI Agent Guidance
- DO check the installed `primereact` major. v10 and v11 code are incompatible in many places.
- DO fetch the current component docs from primeui.dev (or the MCP server) before generating imports and props. Don't rely on memory.
- DON'T mix modes unless the project already does.
- Verify before done: DataTable uses lazy mode for server data, labels present, no FOUC in Next.js, theme tokens (not CSS overrides) used for branding.

## Examples
```tsx
// Pattern-level example: server-driven table state in a client wrapper.
// Replace <PrimeTable> with the v11 DataTable import/anatomy from primeui.dev.
"use client";
import { useRouter, useSearchParams } from "next/navigation";

type Order = { id: string; customer: string; total: number };

export function OrdersTable({ rows, totalRecords, PrimeTable }: {
  rows: Order[];
  totalRecords: number;
  PrimeTable: React.ComponentType<any>; // v11 DataTable
}) {
  const router = useRouter();
  const params = useSearchParams();
  const page = Number(params.get("page") ?? 0);

  return (
    <PrimeTable
      value={rows}
      dataKey="id"
      lazy
      paginator
      rows={25}
      first={page * 25}
      totalRecords={totalRecords}
      onPage={(e: { page: number }) => {
        const next = new URLSearchParams(params);
        next.set("page", String(e.page));
        router.replace(`?${next.toString()}`, { scroll: false });
      }}
      pt={{ root: { "data-testid": "orders-table", "aria-label": "Orders" } }}
    />
  );
}
```

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md): DataTable use cases
- [data-grids-ag-grid](../data-grids-ag-grid/Skill.md): grid alternatives
- [design-token-architecture](../design-token-architecture/Skill.md): token tiers
- [tailwind-design-system-architecture](../tailwind-design-system-architecture/Skill.md): Tailwind mode
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): table state in URL
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [PrimeReact changelog](https://primereact.dev/changelog): Official. v11.0.0 (July 15, 2026), 11.1.0 (August 5, 2026), four modes, primeui.dev
- [PrimeReact v11 discussion #4290](https://github.com/orgs/primefaces/discussions/4290): Open Source. Hooks, Primitives, Styled, Tailwind plan
- [primereact registry metadata](https://registry.npmjs.org/primereact/latest): Official. Version 11.1.0, React >= 19
- [PrimeReact LICENSE.md](https://github.com/primefaces/primereact/blob/master/LICENSE.md): Open Source. MIT
- [primereact-tailwind (legacy)](https://github.com/primefaces/primereact-tailwind): Open Source. Pre-v11 Tailwind approach context

## License / Usage Notes
PrimeReact is MIT (PrimeTek). Premium templates/blocks, if used, have separate commercial terms. The v11 API isn't reproduced in detail because it is brand-new; always consult primeui.dev.

## Quality Tier
B: release facts and licensing verified, but v11 component APIs are new and not reproduced from docs here; the Tailwind-mode CLI specifics are unverified.

## Status
Active (v11 new; APIs settling)

## Last Verified
2026-09-15
