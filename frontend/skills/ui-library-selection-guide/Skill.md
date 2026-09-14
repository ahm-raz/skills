# UI Library Selection Guide (React and Next.js, September 2026)

## Summary
This is a decision framework for choosing a React component library or primitive layer for Next.js App Router and Vite SPA projects as of September 2026. It compares headless primitives (Base UI, Radix, React Aria, Ariakit, Ark UI, Headless UI), open-code systems (shadcn/ui), styled libraries (Material UI, Mantine, Chakra, Ant Design, HeroUI, PrimeReact, Fluent), Tailwind kits and specialized libraries on React 19 support, RSC fit, Tailwind v4 fit, accessibility, runtime styling cost, license and maintenance.

## Category
UI Libraries

## Subcategories
Library evaluation, headless vs styled, open-code vs package, styling runtime, RSC compatibility, licensing, maintenance risk, migration cost

## Problem It Solves
Picking a UI library is a multi-year commitment affecting bundle size, accessibility, design flexibility and upgrade pain. 2025-2026 changed the landscape: Base UI 1.0, shadcn defaulting to Base UI, MUI v9 and Pigment on hold, HeroUI v3 rewrite, Vaul unmaintained, Polaris React deprecated, PrimeReact v11. Outdated advice leads to wrong choices.

## When To Use
- Starting a new React/Next.js product or design system.
- Re-evaluating a library after a major version, maintenance change or performance problem.
- Reviewing an AI-generated scaffold that chose a library by default.

## When Not To Use
- Inside an established codebase with a working design system. Follow the existing choice unless a migration is approved.
- For single components, see the component-specific skills (dialogs, comboboxes, etc.).

## Core Principles
1. **Decide the ownership model first**: own the code (shadcn/open-code), depend on a package (Mantine/MUI/HeroUI), or build on headless primitives.
2. **Styling engine matters more than components**: Tailwind v4, CSS Modules/plain CSS, or runtime CSS-in-JS (Emotion) drive performance and DX.
3. **Behavior quality is non-negotiable**: prefer libraries implementing WAI-ARIA APG with real screen-reader testing.
4. **Maintenance and license are architecture inputs**: check release cadence, bus factor and license tiers.
5. **Everything interactive is a client component**. Evaluate how much client JS each option forces into your RSC tree.

## Best Practices
- Prototype the three hardest screens (data table, complex form, overlay-heavy flow) with the top two candidates.
- Check peer ranges (`react`, `tailwindcss`) in npm metadata before committing.
- Verify license tiers (MUI X Pro, Aceternity Pro, Tailwind Plus, Preline Pro, Atlassian/Polaris restrictions).
- Avoid combining multiple styled libraries. One styling system plus one headless layer at most.
- Record the decision (ADR) with a re-evaluation trigger (major release, maintenance change).

## Implementation Guidance
**Step 1: ownership and styling model**
| If you want… | Choose |
|---|---|
| Tailwind v4 + own the code + AI-friendly CLI | shadcn/ui (Base UI default, or Radix/Aria base) |
| Tailwind v4 + packaged styled components | HeroUI v3 (React 19+, React Aria) |
| No Tailwind, no CSS-in-JS runtime, huge breadth | Mantine 9 (React 19.2+) |
| Material Design / MUI X data grid + pickers | Material UI v9 (Emotion) |
| Dense enterprise forms and tables, Ant look | Ant Design 6 |
| Style props + token recipes | Chakra UI v3 (Emotion) |
| Build your own design system on headless primitives | Base UI or React Aria (plus Ark UI for exotic widgets) |
| Microsoft 365-style product | Fluent UI React v9 |
| Enterprise data suite with multiple styling modes | PrimeReact v11 (React 19+) |
| Legacy Bootstrap theme | Bootstrap 5.3 + React-Bootstrap |

**Step 2: comparison matrix (September 2026)**
| Library | Version | React 19 | RSC fit* | Tailwind v4 fit | Styling runtime | A11y depth | License | Maintenance |
|---|---|---|---|---|---|---|---|---|
| shadcn/ui | CLI v4 | Yes | High (static parts stay RSC) | Native | None | Base-dependent (high) | MIT | Very active |
| Base UI | 1.8.0 | Yes | High | Excellent | None | High | MIT | Very active (MUI) |
| Radix | radix-ui 1.6.7 | Yes (2026 fixes) | High | Excellent | None | High | MIT | Active, mature |
| React Aria Components | 1.21.1 | Yes | High | Good (plugin) | None | Highest (i18n) | Apache-2.0 | Very active (Adobe) |
| Ariakit | 0.4.40 | Yes | High | Good | None | High | MIT | Active, pre-1.0 |
| Ark UI | 5.39.2 | Yes | High | Good | None | High | MIT | Active |
| Headless UI | 2.2.10 | Yes | High | Native | None | Good | MIT | Low cadence |
| HeroUI | 3.2.5 | Required | Medium | Native (requires v4) | None (CSS) | High (RAC) | MIT | Active |
| Mantine | 9.6.1 | Requires 19.2 | Medium | Coexist (layers) | None (CSS) | Good | MIT | Very active |
| Material UI | 9.4.0 | Yes | Medium-low | Coexist (layers) | Emotion | Good | MIT (X Pro paid) | Active |
| Chakra UI | 3.37.0 | Yes | Medium-low | Poor fit | Emotion | Good (Ark) | MIT | Active |
| Ant Design | 6.6.4 | Yes (18+) | Medium-low | Coexist | cssinjs (CSS vars) | Fair-good | MIT | Very active |
| PrimeReact | 11.1.0 | Required | Medium | Tailwind mode | Tokens/CSS vars | Claimed WCAG (verify) | MIT | Active (new major) |
| Fluent UI v9 | 9.74.7 | Yes | Medium-low | Poor fit | Griffel (atomic CSS-in-JS) | High | MIT | Active (Microsoft) |
| daisyUI 5 | 5.7.37 | N/A (CSS) | High | Native | None | You add behavior | MIT | Active |
| Tremor (npm) | 3.18.7 | Peer ^18 | Medium | v3-era (verify) | None | Fair | Apache-2.0 | Uncertain |
*RSC fit = how much markup can stay in Server Components and whether providers/registries force client wrappers or SSR style extraction.

**Step 3: red flags (September 2026)**
- Vaul: unmaintained. Use Base UI Drawer.
- Polaris React: deprecated and archived (September 11, 2026). Polaris web components are Shopify-only.
- Pigment CSS: alpha, on hold. Joy UI: on hold.
- HeroUI v2 / NextUI packages: superseded by v3 (no coexistence).
- `@tremor/react`: React ^18 peer. Prefer copy-paste or shadcn charts.
- Headless UI: stable but low release cadence.
- Atlassian Design System: licensed only for Atlassian-integrated products.

## Recommended Workflow
1. Gather constraints: React/Next versions, Tailwind or not, brand flexibility, a11y requirements, data density, license budget, team skills.
2. Shortlist 2-3 options from the decision table.
3. Check npm peers, last releases, open critical issues and license tiers.
4. Build a spike (table + form + overlay) in Next.js App Router. Measure JS size, hydration, INP and a11y (axe + keyboard).
5. Decide, write an ADR, create the wrapper layer (`components/ui`), and set lint rules to prevent direct cross-library imports.

## Patterns
- **Headless + tokens + Tailwind (shadcn-style)**: highest control and lowest runtime. Suits product companies.
- **Styled suite + theme**: fastest for internal tools. Accept the library look and runtime.
- **Hybrid**: styled suite for complex data widgets (MUI X Data Grid, AG Grid) inside a shadcn app. Isolate styling with CSS layers and wrappers.
- **Adapter layer**: app code imports only from `@/components/ui`, which enables library swaps later.

## Anti-Patterns
- **Choosing by GitHub stars or AI default**: stars don't reflect 2026 maintenance or React 19 fit.
- **Multiple styled libraries** (MUI + Chakra + antd): conflicting resets, tokens and bundles.
- **Runtime CSS-in-JS for content-heavy public sites**: hurts LCP/INP. Prefer zero-runtime styling.
- **Ignoring license tiers** until launch (MUI X Premium, Aceternity Pro, Tailwind Plus).
- **Deep internal CSS overrides** of styled libraries: upgrades become painful. Choose a library whose theming covers your brand.

## Accessibility
- Rank behavior quality: React Aria (highest, i18n), then Base UI / Radix / Ariakit / Ark, then styled suites (varying). CSS-only kits need you to build behavior.
- Regardless of choice, verify the WCAG 2.2 AA essentials: focus visible, keyboard operability, names/roles/values, contrast after theming, target size.
- Include screen-reader testing of the three spike screens in the evaluation.

## Responsive Design
- All options support responsive layouts. Differences lie in overlay adaptation (Drawer availability: Base UI, Mantine, MUI, antd, Chakra) and dense-table behavior on mobile.
- Container query support: Tailwind v4 native, Mantine container grids, others via custom CSS.

## Performance
- Zero-runtime (Tailwind/CSS Modules/CSS vars): shadcn, Base UI, Radix, RAC, Mantine, HeroUI, daisyUI.
- Runtime CSS-in-JS: MUI (Emotion), Chakra (Emotion), Fluent (Griffel, with build-time extraction options), antd (cssinjs with CSS variables).
- Measure per screen. Import cost of a DatePicker/DataGrid often dominates library choice.

## Security
- Treat copy-in registries as third-party code (review diffs).
- Prefer libraries with security reporting processes and active maintenance. Avoid unmaintained packages.
- Check licenses (Apache-2.0 vs MIT vs restricted brand licenses) with legal for commercial products.

## Testing
- The evaluation spike should include Testing Library role-based tests. Libraries with correct semantics make tests easier.
- Visual regression setup cost differs: runtime CSS-in-JS may need style extraction in test environments.
- Check jsdom friction (ResizeObserver, pointer events) for RAC/Base UI/Radix. Plan Playwright for overlays.

## Tooling
- npm registry metadata (`registry.npmjs.org/<pkg>/latest`) for peers and versions.
- Library MCP servers and llms.txt: shadcn MCP, Mantine MCP server, HeroUI MCP, PrimeReact MCP. Useful for AI-assisted development and evaluation.
- Bundle analysis: `@next/bundle-analyzer`, `vite-bundle-visualizer`.

## Framework Notes
- **Next.js App Router**: favor libraries that don't need global runtime style registries. Emotion-based libraries require cache providers (`@mui/material-nextjs`) or registries (`@ant-design/nextjs-registry`), plus client providers. Headless libraries require `"use client"` only on interactive wrappers.
- **React (Vite SPA)**: runtime styling costs are less tied to SSR, but INP and bundle size still matter. All options work.
- React 19: confirm peer ranges. HeroUI and PrimeReact require 19, and Mantine requires 19.2.

## AI Agent Guidance
- DO detect existing libraries (`package.json`, `components.json`) and follow them. Never introduce a second styled library unprompted.
- DO state versions and maintenance caveats when recommending (e.g. "Vaul is unmaintained").
- DO recommend shadcn/ui (Base UI) for Tailwind v4 greenfield apps, Mantine for no-Tailwind breadth, MUI/antd for data-dense enterprise needs, and React Aria for i18n/a11y-critical products, while explaining trade-offs.
- DON'T recommend Pigment CSS, Joy UI, Vaul, Polaris React or NextUI packages for new work.
- Verify before done: peers satisfied, licenses noted, decision recorded.

## Examples
```md
<!-- docs/adr/0007-ui-library.md -->
# ADR 0007: UI component foundation
Status: Accepted (2026-09-15)
Context: Next.js 16 App Router, React 19.2, Tailwind v4, WCAG 2.2 AA, dense admin + marketing site.
Options: shadcn/ui (Base UI), Mantine 9, Material UI 9.
Decision: shadcn/ui with Base UI base; AG Grid for data grid; Sonner for toasts.
Consequences: we own components/ui; quarterly `shadcn add --diff` review; no Emotion runtime.
Re-evaluate when: Base UI 2.0, shadcn base changes, or grid needs exceed AG Grid Community.
```
```ts
// eslint.config.mjs: enforce the adapter layer
export default [
  {
    rules: {
      "no-restricted-imports": ["error", {
        patterns: [
          { group: ["@base-ui/react/*", "radix-ui", "@mui/*"], message: "Import from @/components/ui instead." },
        ],
      }],
    },
    ignores: ["src/components/ui/**"],
  },
];
```

## Related Skills
- [shadcn-ui](../shadcn-ui/Skill.md), [base-ui](../base-ui/Skill.md), [radix-ui-primitives](../radix-ui-primitives/Skill.md), [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md): headless and open-code options
- [material-ui](../material-ui/Skill.md), [mantine](../mantine/Skill.md), [chakra-ui](../chakra-ui/Skill.md), [ant-design](../ant-design/Skill.md), [heroui](../heroui/Skill.md), [primereact-and-primevue](../primereact-and-primevue/Skill.md): styled suites
- [fluent-ui-and-enterprise-systems](../fluent-ui-and-enterprise-systems/Skill.md): corporate design systems
- [design-system-architecture](../design-system-architecture/Skill.md): building on top of the choice
- [css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md): styling engine trade-offs
- [bundle-optimization](../bundle-optimization/Skill.md): measuring cost

## Sources
- [shadcn changelog](https://ui.shadcn.com/docs/changelog): Official. Base UI default, bases, registries
- [MUI: 2026 and beyond](https://mui.com/blog/2026-and-beyond/): Official. Pigment/Joy status
- [Base UI releases](https://base-ui.com/react/overview/releases): Official
- [HeroUI v3 (InfoQ)](https://www.infoq.com/news/2026/07/heroui-v3-rewrite/): Community
- [Mantine 9.0.0](https://mantine.dev/changelog/9-0-0/): Official
- [Ant Design v6 migration](https://ant.design/docs/react/migration-v6/): Official
- [PrimeReact changelog](https://primereact.dev/changelog): Official
- [Shopify/polaris-react (archived)](https://github.com/Shopify/polaris-react): Open Source
- [emilkowalski/vaul](https://github.com/emilkowalski/vaul): Open Source. Unmaintained
- [Radix vs Base UI (ShadcnDeck)](https://www.shadcndeck.com/blog/radix-vs-base-ui): Community. Ecosystem framing
- npm registry metadata for all listed packages (e.g. [@mui/material](https://registry.npmjs.org/@mui/material/latest)): Official. Versions and peers

## License / Usage Notes
The matrix summarizes each project's public metadata as of 2026-09-15. Licenses: see each library's skill. Ratings such as "RSC fit" and "A11y depth" are editorial judgments.

## Quality Tier
A: versions and statuses verified from primary sources; comparative ratings are expert judgment and should be re-validated per project.

## Status
Active

## Last Verified
2026-09-15
