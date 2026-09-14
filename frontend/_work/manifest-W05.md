# Manifest — W05 CSS, Styling, Responsive

Scope: React + Next.js (TypeScript) only, per the TAXONOMY scope note (2026-09-15). All Framework Notes cover React (Vite SPA) and Next.js App Router only. Last verified: 2026-09-15.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| modern-css-features | Modern CSS Features | CSS & Styling | React / Next.js (framework-agnostic CSS) | A | Active | https://web.dev/baseline/2026 |
| css-architecture | CSS Architecture | CSS & Styling | React / Next.js | A | Active | https://cube.fyi/ |
| tailwind-css-v4 | Tailwind CSS v4 | CSS & Styling | Tailwind v4.3 + Next.js / Vite | S | Active | https://tailwindcss.com/docs/upgrade-guide |
| tailwind-design-system-architecture | Tailwind Design System Architecture | CSS & Styling | Tailwind v4 + Next.js | A | Active | https://tailwindcss.com/docs/theme |
| css-modules | CSS Modules | CSS & Styling | Next.js / Vite | A | Active | https://github.com/css-modules/css-modules |
| css-in-js-and-zero-runtime | CSS-in-JS and Zero-Runtime Styling | CSS & Styling | React / Next.js (RSC) | A | Active | https://nextjs.org/docs/app/guides/css-in-js |
| container-queries | Container Queries | CSS & Styling | React / Next.js | S | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Containment/Container_size_and_style_queries |
| css-grid-and-flexbox-layout | CSS Grid and Flexbox Layout | CSS & Styling | React / Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_grid_layout |
| fluid-typography-and-spacing | Fluid Typography and Spacing | CSS & Styling | React / Next.js / Tailwind | A | Active | https://utopia.fyi/type/calculator/ |
| theming-with-css-variables | Theming with CSS Variables | CSS & Styling | React / Next.js | A | Active | https://web.dev/articles/baseline-in-action-color-theme |
| dark-mode-implementation | Dark Mode Implementation | CSS & Styling | Next.js (next-themes) / Vite / Tailwind | S | Active | https://tailwindcss.com/docs/dark-mode |
| css-cascade-layers-and-specificity | CSS Cascade Layers and Specificity | CSS & Styling | React / Next.js / Tailwind | S | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/@layer |
| typography-systems | Typography Systems | CSS & Styling | Next.js (next/font) / Vite | A | Active | https://nextjs.org/docs/app/getting-started/fonts |
| color-systems | Color Systems | CSS & Styling | React / Next.js / Tailwind | A | Active | https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale |
| spacing-and-layout-systems | Spacing and Layout Systems | CSS & Styling | React / Next.js / Tailwind | A | Active | https://every-layout.dev/ |
| responsive-design | Responsive Design | CSS & Styling | React / Next.js | A | Active | https://web.dev/learn/design |
| responsive-images-and-media | Responsive Images and Media | CSS & Styling | Next.js 16 (next/image) / Vite | S | Active | https://nextjs.org/docs/app/api-reference/components/image |
| css-logical-properties-and-rtl | CSS Logical Properties and RTL | CSS & Styling | Next.js / Vite / Tailwind | A | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_logical_properties_and_values |
| css-nesting-and-scope | CSS Nesting and @scope | CSS & Styling | React / Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Nesting/Using |

Added slugs: none. Skipped slugs: none.

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| web.dev Baseline 2026 | https://web.dev/baseline/2026 | Official | List of features reaching Baseline in 2026 (field-sizing, container style queries, :open, contrast-color, @scope, shape(), custom highlights, text-indent, r* units) | Authoritative support tier data | S | 2026-09-15 |
| web.dev Interop 2026 | https://web.dev/blog/interop-2026 | Official | Full list of focus/investigation areas | Shows which CSS features are converging | S | 2026-09-15 |
| web.dev New to the web platform May 2026 | https://web.dev/blog/web-platform-05-2026 | Official | Firefox 151 container style queries, Chrome 148 name-only CQs and media lazy loading, Safari 26.5 :open | Confirms recent Baseline changes | S | 2026-09-15 |
| WebKit Announcing Interop 2026 | https://webkit.org/blog/17818/announcing-interop-2026/ | Official | Cross-check of focus areas | Browser vendor confirmation | A | 2026-09-15 |
| WebKit Grid Lanes post | https://webkit.org/blog/17758/when-will-css-grid-lanes-arrive-how-long-until-we-can-use-it/ | Official | grid-lanes masonry syntax and status | Masonry guidance | A | 2026-09-15 |
| MDN container size and style queries | https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Containment/Container_size_and_style_queries | Official | Syntax, custom-property-only style queries | Core reference | S | 2026-09-15 |
| MDN Using CSS nesting | https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Nesting/Using | Official | & rules, relaxed syntax, specificity, CSSNestedDeclarations, no concatenation | Correct nesting semantics vs Sass | S | 2026-09-15 |
| MDN Customizable select | https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Customizable_select | Official | Not Baseline; syntax; framework/hydration caveat | Flag Chromium-only feature | A | 2026-09-15 |
| MDN contrast-color() / if() | https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value/contrast-color | Official | contrast-color Baseline Apr 2026; if() not Baseline | Color and conditional CSS status | A | 2026-09-15 |
| Frontend Masters: @scope now Baseline | https://frontendmasters.com/blog/how-to-scope-css-now-that-its-baseline/ | Community | Firefox 146 @scope Baseline, usage | Confirms @scope status | A | 2026-09-15 |
| Tailwind CSS upgrade guide | https://tailwindcss.com/docs/upgrade-guide | Official | Full v3→v4 breaking changes, renamed utilities, browser requirements | Prevents v3 syntax in v4 projects | S | 2026-09-15 |
| Tailwind CSS theme variables | https://tailwindcss.com/docs/theme | Official | Namespaces, @theme inline/static, namespace reset, sharing themes | Token architecture on Tailwind | S | 2026-09-15 |
| Tailwind CSS v4.3 blog | https://tailwindcss.com/blog/tailwindcss-v4-3 | Official | v4.2/4.3 features: logical utilities, webpack plugin, scrollbar, @container-size, --default(), compound @variant, start/end deprecation | Latest version accuracy | S | 2026-09-15 |
| Tailwind dark mode docs | https://tailwindcss.com/docs/dark-mode | Official | @custom-variant dark class/data attribute, toggle script | Dark mode setup | S | 2026-09-15 |
| Tailwind responsive design docs | https://tailwindcss.com/docs/responsive-design | Official | Breakpoints, ranges, container query variants | Responsive utilities | S | 2026-09-15 |
| tailwindlabs/tailwindcss releases | https://github.com/tailwindlabs/tailwindcss/releases | Open Source | Latest v4.3.3 (2026-07-16) | Version currency | A | 2026-09-15 |
| ofershap/tailwind-best-practices | https://github.com/ofershap/tailwind-best-practices | Community | Agent anti-pattern list for v3→v4 | Community agent rules | B | 2026-09-15 |
| shamiul-anik/tailwindcss-skills | https://github.com/shamiul-anik/tailwindcss-skills | Community | SKILL.md reference covering v4.2 | Community agent skill (cross-check only) | C | 2026-09-15 |
| wshobson/agents tailwind-design-system SKILL.md | https://github.com/wshobson/agents/blob/main/plugins/frontend-mobile-development/skills/tailwind-design-system/SKILL.md | Community | DS-on-Tailwind agent skill patterns | Community agent skill (cross-check) | C | 2026-09-15 |
| Lombiq/Tailwind-Agent-Skills | https://github.com/Lombiq/Tailwind-Agent-Skills | Community | Gotchas list and docs snapshot approach | Community agent skill (listed, not deeply extracted) | C | 2026-09-15 |
| Next.js CSS-in-JS guide (16.3.5) | https://nextjs.org/docs/app/guides/css-in-js | Official | Supported libraries, registry pattern, Emotion pending | RSC compatibility of styling | S | 2026-09-15 |
| Next.js Font optimization (16.3.5) | https://nextjs.org/docs/app/getting-started/fonts | Official | next/font google/local usage | Typography loading in Next.js | S | 2026-09-15 |
| Next.js Image component (16.3.5) | https://nextjs.org/docs/app/api-reference/components/image | Official | preload prop, priority deprecated in v16, qualities default [75] required, config, getImageProps, version history | Responsive images in Next.js 16 | S | 2026-09-15 |
| next-themes | https://github.com/pacocoursey/next-themes | Open Source | Provider props, useTheme, suppressHydrationWarning, mounted pattern (README Tailwind note is v3-specific) | Flash-free dark mode in Next.js | A | 2026-09-15 |
| css-modules/css-modules | https://github.com/css-modules/css-modules | Open Source | Local scope, composition, naming concepts | CSS Modules concepts (implementations live in bundlers) | B | 2026-09-15 |
| styled-components maintenance discussion #5568 | https://github.com/orgs/styled-components/discussions/5568 | Deprecated | Maintenance mode (Mar 2025), RSC rationale | Flags outdated runtime CSS-in-JS | A | 2026-09-15 |
| State of zero-runtime CSS-in-JS mid-2026 (DEV) | https://dev.to/anber/the-state-of-zero-runtime-css-in-js-mid-2026-5ci6 | Community | Library statuses (Linaria, vanilla-extract, Panda, StyleX, next-yak, Pigment on hold) | Ecosystem landscape; author is Linaria maintainer (potential bias) | B | 2026-09-15 |
| vanilla-extract theming | https://vanilla-extract.style/documentation/theming/ | Official | createThemeContract, createTheme, assignInlineVars | Typed zero-runtime theming | A | 2026-09-15 |
| StyleX defining variables | https://stylexjs.com/docs/learn/theming/defining-variables/ | Official | defineVars, .stylex.ts rules, constraints | StyleX theming | A | 2026-09-15 |
| Panda CSS recipes | https://panda-css.com/docs/concepts/recipes | Official | cva vs config recipes, static extraction limits | Panda usage constraints | A | 2026-09-15 |
| Pigment CSS | https://github.com/mui/pigment-css | Experimental | On hold in alpha (via mid-2026 roundup) | Avoid for new work | B | 2026-09-15 |
| Utopia type calculator / clamp blog | https://utopia.fyi/blog/clamp/ | Community | Fluid scale method, rem+vw clamp, zoom caveat | Fluid type/space method | A | 2026-09-15 |
| Trys Mudford: Utopia WCAG warnings | https://www.trysmudford.com/blog/utopia-wcag-warnings/ | Community | SC 1.4.4 warnings in calculator | Accessibility of fluid type | A | 2026-09-15 |
| Radix Colors docs | https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale | Open Source | 12-step scale use cases, APCA targets, palette composition | Functional color scale model | S | 2026-09-15 |
| Adobe Leonardo | https://github.com/adobe/leonardo | Open Source | Contrast-ratio-driven generation, adaptive themes | Contrast-first palette generation | A | 2026-09-15 |
| Material Design 3 color roles | https://m3.material.io/styles/color/roles | Official | Role naming, tonal palettes (from existing knowledge; not re-fetched) | Semantic role model | A | 2026-09-15 |
| Adrian Roselli: WCAG3 contrast as of April 2026 | https://adrianroselli.com/2026/04/wcag3-contrast-as-of-april-2026.html | Community | APCA not normative; WCAG 2 remains the benchmark | Prevents compliance mistakes | A | 2026-09-15 |
| web.dev Color themes with Baseline | https://web.dev/articles/baseline-in-action-color-theme | Official | oklch, relative colors, color-mix, light-dark, @property approach | Theming building blocks | A | 2026-09-15 |
| CUBE CSS | https://cube.fyi/ | Community | Composition/Utility/Block/Exception methodology | CSS architecture methodology | A | 2026-09-15 |
| Every Layout | https://every-layout.dev/ | Community | Layout primitives (concept names only) | Intrinsic layout primitives | A | 2026-09-15 |
| Defensive CSS (Ahmad Shadeed) | https://defensivecss.dev/ | Community | Defensive layout snippets (from existing knowledge) | Robust layouts | A | 2026-09-15 |
| Josh W. Comeau modern CSS reset | https://www.joshwcomeau.com/css/custom-css-reset/ | Community | Reset rules and rationale | Base layer defaults | A | 2026-09-15 |
| web-features explorer: sizes="auto" | https://web-platform-dx.github.io/web-features-explorer/features/sizes-auto/ | Official | Chrome 126, Firefox 150, no Safari | Responsive image enhancement status | A | 2026-09-15 |
| LogRocket: Container queries in 2026 | https://blog.logrocket.com/container-queries-2026/ | Community | Practical caveats | Real-world guidance | B | 2026-09-15 |
| Tailwind @tailwindcss/container-queries plugin | https://github.com/tailwindlabs/tailwindcss-container-queries | Deprecated | Superseded by built-in v4 container variants | Flags outdated setup | B | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Tailwind v3 to v4 migration rules | Tailwind upgrade guide | ofershap/tailwind-best-practices, shamiul-anik/tailwindcss-skills, Lombiq/Tailwind-Agent-Skills | tailwind-css-v4 |
| Semantic tokens on Tailwind (`:root`/`.dark` + `@theme inline`) | Tailwind theme docs | shadcn/ui theming convention, wshobson tailwind-design-system SKILL.md | tailwind-design-system-architecture |
| Dark mode toggling in Next.js | Tailwind dark mode docs + next-themes README | Josh Comeau dark mode article, Tailwind three-way toggle script | dark-mode-implementation |
| Runtime vs zero-runtime CSS-in-JS status | Next.js CSS-in-JS guide | styled-components maintenance discussion, mid-2026 zero-runtime roundup, PkgPulse/OpenReplay state-of articles | css-in-js-and-zero-runtime |
| Layout primitives (Stack/Cluster/Sidebar/Switcher) | Every Layout | CUBE CSS composition layer, Defensive CSS | spacing-and-layout-systems (grid/flex mechanics in css-grid-and-flexbox-layout) |
| Fluid clamp() type | Utopia | LogRocket fluid vs responsive, OddBird fluid type, SitePoint clamp article | fluid-typography-and-spacing |
| Color derivation (relative colors, color-mix) | web.dev color themes article | Ahmad Shadeed relative colors, MDN relative colors | theming-with-css-variables (palette design in color-systems) |
| Baseline/support facts for new CSS | web.dev Baseline 2026 + Interop 2026 | WebKit/Mozilla Interop posts, various 2026 roundup blogs | modern-css-features |

## Gaps

- Search quota ran out partway through, so some facts come from existing knowledge and weren't re-fetched: Material 3 role names, MUI `enableCssLayer`, Defensive CSS snippets, and the exact Baseline status of `text-box-trim` and `text-wrap: pretty`. Re-check these next cycle.
- Anchor positioning versions are inconsistent across secondary sources (reported "Baseline Newly available Jan 2026"). Confirm browser versions on webstatus.dev.
- Name-only container queries (Chrome 148) were reported as Baseline Newly available by web.dev in May 2026. That claim needs checking against Safari/Firefox release notes.
- Turbopack compatibility of zero-runtime CSS-in-JS plugins (vanilla-extract, StyleX, Panda, Linaria, next-yak) in Next.js 16 wasn't verified per library. It needs a compatibility matrix.
- The CSS Modules spec repo gives no maintenance statement. The status is inferred from bundler implementations.
- No official Tailwind Labs agent skill was verified. A GitHub discussion (#19594) proposes one but wasn't fetched.
- `@function` / `if()` / `sibling-index()` / typed `attr()` are covered only as "limited" in modern-css-features. A dedicated skill may be worthwhile once they reach Baseline.
- Print stylesheets, `forced-colors` design and scrollbar styling have no dedicated skill. They are touched on in the cascade, responsive and color skills.
- Community agent skills (shamiul-anik, Lombiq, wshobson) were only checked at the summary level, not audited line by line.
