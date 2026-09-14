# Fluent UI and Enterprise Design Systems (Carbon, Spectrum, Polaris, Atlassian)

## Summary
Large corporate design systems publish React implementations: Microsoft **Fluent UI React v9** (`@fluentui/react-components` 9.74.7, MIT, Griffel atomic CSS-in-JS), IBM **Carbon** (`@carbon/react` 1.116.0, Apache-2.0, Sass), Adobe **React Spectrum S2** (`@react-spectrum/s2` 1.7.1, Apache-2.0, style macro), Shopify **Polaris** (React package deprecated and archived September 11, 2026, replaced by Polaris web components, Shopify-restricted license) and the **Atlassian Design System** (license restricted to Atlassian-integrated products). This skill covers when these are appropriate, their styling and SSR models, and licensing traps.

## Category
UI Libraries

## Subcategories
Fluent UI v9, Griffel, Carbon React, Sass tokens, Spectrum 2, Polaris web components, Atlassian Design System, platform-extension UIs, licensing

## Problem It Solves
Apps that extend a vendor platform (Microsoft Teams/Office add-ins, Shopify admin apps, Jira/Confluence apps, Adobe plugins) or that must match a corporate standard need the vendor's official system for visual consistency, review approval and accessibility compliance. General-purpose teams also study these systems for mature token and accessibility practices.

## When To Use
- Microsoft 365 / Teams / Power Platform-adjacent web apps: Fluent UI v9.
- IBM-style enterprise or data products, or teams wanting a mature open-source system with strong docs: Carbon.
- Adobe ecosystem extensions: Spectrum S2.
- Shopify admin apps: Polaris web components (not Polaris React).
- Atlassian Forge/Connect apps: Atlassian Design System / Forge UI Kit.

## When Not To Use
- Independent brands wanting their own look. These systems encode their vendor's brand.
- Using Polaris or Atlassian components outside their platforms. Their licenses restrict usage.
- Starting new Shopify work on `@shopify/polaris` (deprecated).
- Performance-critical public sites that can't afford CSS-in-JS runtime (Fluent) or large Sass bundles (Carbon) without optimization.

## Core Principles
1. **Platform alignment beats customization**: use the vendor system where the platform expects it, with minimal overrides.
2. **Know the styling engine**: Fluent uses Griffel (`makeStyles`, atomic classes, SSR renderer), Carbon uses Sass (`@carbon/styles`, themes), Spectrum S2 uses a build-time style macro in cascade layers, and Polaris uses web components.
3. **Tokens are the integration surface**: Fluent `tokens.*`, Carbon `$interactive`-style theme tokens, Spectrum style macro values.
4. **License review first**: MIT/Apache (Fluent, Carbon, Spectrum) vs platform-restricted (Polaris, Atlassian).
5. **Accessibility is a strength**: all have dedicated a11y teams. Preserve it by avoiding DOM-altering overrides.

## Best Practices
- **Fluent v9**: wrap the app in `FluentProvider theme={webLightTheme}` (or Teams themes). Style with `makeStyles` using `tokens`. Use `mergeClasses` to combine classes (never string-concatenate Griffel classes). For SSR, use Griffel's SSR renderer (`createDOMRenderer`/`renderToStyleElements`) per the Fluent Next.js guidance. Consider Griffel build-time extraction to reduce runtime.
- **Carbon**: import `@carbon/styles` via Sass with only needed components. Use `Theme`/`GlobalTheme` zones (white, g10, g90, g100). Use the Carbon grid (`Grid`, `Column`). Sass is a peer, so configure it in Next.js/Vite.
- **Spectrum S2**: wrap in S2 `Provider` (loads locale fonts). Style only via the `style` macro and `styles` prop. Global CSS now overrides S2 (layers), so scope resets. Style macros in `UNSAFE_className` are a type error.
- **Polaris**: follow shopify.dev Polaris web components docs in Shopify app templates. Use React wrappers/JSX with custom elements as documented. Treat archived Polaris React docs as legacy reference only.
- **Atlassian**: use Atlaskit / Forge UI Kit only for Atlassian-integrated apps. You may not modify brand components or remove notices.

## Implementation Guidance
| System | Package (Sept 2026) | Styling | Next.js SSR notes | License |
|---|---|---|---|---|
| Fluent UI React v9 | `@fluentui/react-components` 9.74.7 | Griffel atomic CSS-in-JS | Client provider; Griffel SSR style extraction | MIT (fonts/icons separate assets license) |
| Fluent UI v8 | `@fluentui/react` | Merge-styles | Legacy, used by Office/Edge | MIT |
| Fluent Web Components | `@fluentui/web-components` | Web components | Framework-agnostic | MIT |
| Carbon | `@carbon/react` 1.116.0 | Sass (`@carbon/styles`) | Compile Sass globally; client components for interactive parts | Apache-2.0 |
| Spectrum S2 | `@react-spectrum/s2` 1.7.1 | Style macro, cascade layers | Needs macro-capable bundler config | Apache-2.0 |
| Polaris | Web components (React pkg `@shopify/polaris` 13.9.5 deprecated) | Web components | Shopify app templates | Shopify-restricted |
| Atlassian DS | `@atlaskit/*` | Compiled CSS/tokens (verify) | Per Atlassian docs | Restricted to Atlassian integrations |

## Recommended Workflow
1. Identify the platform or compliance driver. If there isn't one, reconsider using a vendor system at all.
2. Review the license with legal (especially Polaris and Atlassian).
3. Set up provider, theme and style engine SSR integration in a Next.js spike.
4. Build app-level compositions using tokens. Avoid overriding internals.
5. Run the vendor's accessibility guidance and axe/keyboard tests. Keep versions aligned with platform requirements.

## Patterns
- **Fluent style hook**: `const useStyles = makeStyles({ card: { padding: tokens.spacingHorizontalL, borderRadius: tokens.borderRadiusMedium } })`.
- **Carbon theme zones**: `<Theme theme="g100">` for dark sections within a light app.
- **Spectrum macro**: `style({ padding: 16, backgroundColor: "gray-100" })` evaluated at build time.
- **Polaris migration**: route-by-route replacement of Polaris React components with Polaris web components in Shopify admin apps.

## Anti-Patterns
- **Concatenating Griffel class strings** (`${a} ${b}`): breaks atomic class precedence. Use `mergeClasses`.
- **Mixing Fluent v8 and v9 in new screens**: two styling engines and themes. Use v9 for new work.
- **Importing all of Carbon Sass**: large CSS. Import per component.
- **Using Polaris or Atlassian components in unrelated products**: license violation.
- **Overriding Spectrum S2 via global CSS resets**: since the layer change, globals win and break visuals.
- **Starting new Shopify apps on Polaris React**: deprecated and archived.

## Accessibility
- All four vendors publish a11y guidance and test components extensively. Fluent and Spectrum are built on strong internal a11y infrastructure (Spectrum on React Aria).
- Keep vendor focus indicators and high-contrast support (Fluent supports Windows high contrast via `forced-colors`).
- Carbon documents a11y per component (keyboard, ARIA). Verify custom compositions.
- WCAG 2.2 AA verification is still your responsibility for app-level flows.

## Responsive Design
- Carbon 2x Grid with breakpoints (sm, md, lg, xlg, max).
- Fluent v9 provides no grid system. Use CSS grid/flex with tokens.
- Spectrum S2 macro supports responsive conditions. Polaris web components adapt to Shopify admin layouts (mobile app included).

## Performance
- Fluent Griffel: atomic CSS deduplicates well. Runtime insertion can be reduced with build-time extraction (AOT/CSS extraction plugins).
- Carbon: Sass compiles to static CSS (no runtime), but large component CSS and the React bundle matter. Tree-shake and import selectively.
- Spectrum S2: build-time atomic CSS, minimal runtime.
- Enterprise systems are large. Lazy-load rarely used screens and heavy components (DataTable, DatePicker).

## Security
- License compliance is the main "security" risk here (legal exposure).
- Fonts and icons may have separate asset licenses (Fluent assets license, Polaris design guidelines license).
- Standard dependency hygiene. These are large corporate monorepos with active advisories handling.

## Testing
- Fluent: render within `FluentProvider` in tests. Griffel works in jsdom.
- Carbon: Sass isn't needed for unit tests (mock CSS imports). Use role queries.
- Spectrum S2: configure the macro plugin in the test bundler (Vitest) or mock styles.
- Vendor visual review: compare against Figma kits and platform review guidelines (Shopify app review, Microsoft Teams store).

## Tooling
- Fluent UI React v9 (react.fluentui.dev), Griffel devtools, Fluent Figma kits.
- Carbon: `@carbon/react`, `@carbon/styles`, `@carbon/icons-react`, Carbon for AI/charts (not covered here).
- Spectrum S2: `@react-spectrum/s2`, style macro.
- Polaris web components (shopify.dev), archived Polaris React docs.
- Atlassian: Atlaskit, Forge UI Kit, design tokens.

## Framework Notes
- **Next.js App Router**: Fluent needs a `"use client"` provider plus Griffel SSR style handling (follow Fluent's Next.js docs; verify the current recommended setup for App Router). Carbon: add `sass`, import the global Carbon SCSS in `app/layout.tsx`, and make interactive components client components. Spectrum S2: configure the macro plugin in Next's bundler (check S2 docs for webpack/Turbopack support). Polaris web components: follow the Shopify app template, not a generic Next.js setup.
- **React (Vite SPA)**: Fluent and Carbon work out of the box (Sass for Carbon). S2 via `unplugin-parcel-macros` (verify).
- React 19: Fluent v9 peers <20 (includes 19), Carbon peers include 19, S2 requires 19.

## AI Agent Guidance
- DO confirm the platform context before proposing a vendor design system.
- DO use `makeStyles` + `tokens` + `mergeClasses` for Fluent. Use Carbon Sass tokens and themes. Use the style macro for S2.
- DON'T use `@shopify/polaris` for new code. DON'T use Atlassian/Polaris components outside their platforms.
- DON'T mix Fluent v8 and v9 in new code.
- Verify before done: provider and theme present, SSR styles render without FOUC, licenses noted in the PR description, no internal DOM overrides.

## Examples
```tsx
// app/fluent-provider.tsx (client)
"use client";
import { FluentProvider, webLightTheme } from "@fluentui/react-components";
export function AppFluentProvider({ children }: { children: React.ReactNode }) {
  return <FluentProvider theme={webLightTheme}>{children}</FluentProvider>;
}
```
```tsx
"use client";
import { makeStyles, mergeClasses, tokens, Button, Card, CardHeader, Text } from "@fluentui/react-components";

const useStyles = makeStyles({
  card: { width: "320px", padding: tokens.spacingHorizontalL },
  highlighted: { border: `${tokens.strokeWidthThick} solid ${tokens.colorBrandStroke1}` },
});

export function PolicyCard({ title, highlighted, onOpen }: { title: string; highlighted?: boolean; onOpen: () => void }) {
  const s = useStyles();
  return (
    <Card className={mergeClasses(s.card, highlighted && s.highlighted)}>
      <CardHeader header={<Text weight="semibold">{title}</Text>} />
      <Button appearance="primary" onClick={onOpen}>Open</Button>
    </Card>
  );
}
```
```tsx
// Carbon: theme zone + grid (styles imported globally from app/globals.scss: @use "@carbon/react";)
"use client";
import { Theme, Grid, Column, Button, Tile } from "@carbon/react";

export function DarkHero() {
  return (
    <Theme theme="g100">
      <Grid>
        <Column sm={4} md={8} lg={10}>
          <Tile><h2>Usage overview</h2><Button kind="primary">View report</Button></Tile>
        </Column>
      </Grid>
    </Theme>
  );
}
```

## Related Skills
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md): Spectrum S2 foundation
- [css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md): Griffel and macros
- [design-system-architecture](../design-system-architecture/Skill.md): lessons from corporate systems
- [design-token-architecture](../design-token-architecture/Skill.md): token models
- [web-components-in-react](../web-components-in-react/Skill.md): Polaris/Fluent web components
- [enterprise-data-tables](../enterprise-data-tables/Skill.md): Carbon/Fluent data tables
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): when vendor systems fit

## Sources
- [microsoft/fluentui](https://github.com/microsoft/fluentui): Open Source. v9/v8/web components status, MIT, assets license
- [@fluentui/react-components registry metadata](https://registry.npmjs.org/@fluentui/react-components/latest): Official. Version 9.74.7
- [carbon-design-system/carbon](https://github.com/carbon-design-system/carbon): Open Source. Packages, Apache-2.0
- [@carbon/react registry metadata](https://registry.npmjs.org/@carbon/react/latest): Official. Version 1.116.0, Sass peer
- [React Spectrum S2 release notes](https://react-spectrum.adobe.com/beta/s2/release-notes.html): Official. Style macro and layers
- [@react-spectrum/s2 registry metadata](https://registry.npmjs.org/@react-spectrum/s2/latest): Official. Version 1.7.1
- [Shopify/polaris-react](https://github.com/Shopify/polaris-react): Open Source. Deprecated, archived September 11, 2026, web components successor, license
- [@shopify/polaris registry metadata](https://registry.npmjs.org/@shopify/polaris/latest): Official. Deprecation notice
- [Atlassian Design System license](https://atlassian.design/license): Official. Usage restrictions

## License / Usage Notes
Fluent UI MIT (separate fonts/icons license). Carbon Apache-2.0. Spectrum S2 Apache-2.0. Polaris custom MIT-based license restricted to Shopify integrations. Atlassian Design System limited license for Atlassian-integrated software. Summarized content; examples are original.

## Quality Tier
B: status and licensing verified from primary sources, but framework-specific SSR setup details (Griffel in App Router, S2 macro bundler support, Atlassian styling engine) were not re-verified in depth.

## Status
Active (Polaris React: Archived)

## Last Verified
2026-09-15
