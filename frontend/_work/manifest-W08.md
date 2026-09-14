# Manifest: W08 Component Library Ecosystems

Scope applied: React + Next.js (TypeScript) only, per the user decision of 2026-09-15. Skipped slugs: vue-ui-libraries, angular-ui-libraries, svelte-ui-libraries (none had been written). `primereact-and-primevue` covers PrimeReact only. `ark-ui-and-park-ui` covers React bindings only.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| shadcn-ui | shadcn/ui | UI Libraries | React, Next.js | S | Active | https://ui.shadcn.com/docs/changelog |
| radix-ui-primitives | Radix UI Primitives | UI Libraries | React, Next.js | A | Active (mature) | https://www.radix-ui.com/primitives/docs/overview/releases |
| base-ui | Base UI | UI Libraries | React, Next.js | A | Active | https://base-ui.com/react/overview/releases |
| react-aria-and-spectrum | React Aria and React Spectrum | UI Libraries | React, Next.js | A | Active | https://react-aria.adobe.com/ |
| ariakit | Ariakit | UI Libraries | React, Next.js | B | Active | https://ariakit.com/guide/styling |
| headless-ui | Headless UI | UI Libraries | React, Next.js | B | Active (low release activity) | https://tailwindcss.com/blog/headless-ui-v2 |
| material-ui | Material UI (MUI) | UI Libraries | React, Next.js | A | Active | https://mui.com/material-ui/migration/upgrade-to-v9/ |
| chakra-ui | Chakra UI | UI Libraries | React, Next.js | A | Active | https://chakra-ui.com/docs/theming/customization/overview |
| ant-design | Ant Design (antd) | UI Libraries | React, Next.js | A | Active | https://ant.design/docs/react/migration-v6/ |
| mantine | Mantine | UI Libraries | React, Next.js | A | Active | https://mantine.dev/changelog/9-0-0/ |
| primereact-and-primevue | PrimeReact | UI Libraries | React, Next.js | B | Active (v11 new) | https://primereact.dev/changelog |
| tailwind-component-kits | Tailwind Component Kits (daisyUI, Flowbite, Preline, Tailwind Plus) | UI Libraries | React, Next.js | B | Active | https://daisyui.com/docs/themes/ |
| bootstrap-5 | Bootstrap 5 in React and Next.js | UI Libraries | React, Next.js | B | Active (5.3 maintenance; v6 alpha) | https://blog.getbootstrap.com/ |
| heroui | HeroUI (formerly NextUI) | UI Libraries | React, Next.js | B | Active | https://www.infoq.com/news/2026/07/heroui-v3-rewrite/ |
| ark-ui-and-park-ui | Ark UI and Park UI (React) | UI Libraries | React, Next.js | B | Active | https://ark-ui.com/docs/guides/styling |
| animated-component-collections | Animated Component Collections (Aceternity, Magic UI, coss ui, registries) | UI Libraries | React, Next.js | B | Active | https://github.com/magicuidesign/magicui |
| tremor | Tremor | UI Libraries | React, Next.js | B | Active (npm lagging) | https://www.tremor.so/ |
| small-ui-primitives-vaul-sonner-cmdk | Small UI Primitives: Vaul, Sonner, cmdk | UI Libraries | React, Next.js | A | Active (Vaul unmaintained) | https://github.com/emilkowalski/vaul |
| ui-library-selection-guide | UI Library Selection Guide (React and Next.js, September 2026) | UI Libraries | React, Next.js | A | Active | https://ui.shadcn.com/docs/changelog |
| fluent-ui-and-enterprise-systems | Fluent UI and Enterprise Design Systems | UI Libraries | React, Next.js | B | Active (Polaris React archived) | https://github.com/microsoft/fluentui |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| shadcn/ui changelog | https://ui.shadcn.com/docs/changelog | Official | 2025-2026 timeline: Base UI default, cn package, GitHub registries, eject, presets, React Aria base | Canonical ecosystem state | High | 2026-09-15 |
| shadcn CLI v4 | https://ui.shadcn.com/docs/changelog/2026-03-cli-v4 | Official | Templates, --base, presets, info/docs, dry-run/diff, registry:base/font | Correct CLI usage | High | 2026-09-15 |
| shadcn CLI 3.0 + MCP | https://ui.shadcn.com/docs/changelog/2025-08-cli-3-mcp | Official | Namespaced registries, MCP server | Registry model | High | 2026-09-15 |
| components.json docs | https://ui.shadcn.com/docs/components-json | Official | Schema fields, registry headers | Config correctness | High | 2026-09-15 |
| shadcn unified Radix migration | https://ui.shadcn.com/docs/changelog/2026-02-radix-ui | Official | `migrate radix`, import changes | Radix projects | High | 2026-09-15 |
| shadcn Base UI default | https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default | Official | Default base, no forced migration, skill-based migration | Base selection | High | 2026-09-15 |
| shadcn React Aria base | https://ui.shadcn.com/docs/changelog/2026-07-react-aria | Official | `init --base aria` | Base options | High | 2026-09-15 |
| shadcn Toast (July 2026) | https://ui.shadcn.com/docs/changelog/2026-07-toast | Official | Base UI Toast features | Toast choice | Medium | 2026-09-15 |
| shadcn Drawer (Base UI) | https://ui.shadcn.com/docs/components/base/drawer | Official | Vaul replaced by Base UI Drawer; prop mapping | Vaul migration | High | 2026-09-15 |
| shadcn registry include | https://ui.shadcn.com/docs/changelog/2026-05-registry-include | Official | include/validate | Registry authoring | Medium | 2026-09-15 |
| shadcn agent skill | https://raw.githubusercontent.com/shadcn-ui/ui/main/skills/shadcn/SKILL.md | Open Source | Agent rules for CLI, composition, styling | Agent guidance | High | 2026-09-15 |
| Radix releases | https://www.radix-ui.com/primitives/docs/overview/releases | Official | 2025-2026 releases, React 19.2 fixes, tree-shaking | Maintenance evidence | High | 2026-09-15 |
| radix-ui npm / registry | https://registry.npmjs.org/radix-ui/latest | Official | 1.6.7, peers | Version | High | 2026-09-15 |
| Snyk radix-ui | https://security.snyk.io/package/npm/radix-ui | Community | Health rating | Maintenance signal | Medium | 2026-09-15 |
| Base UI releases | https://base-ui.com/react/overview/releases | Official | v1.6-1.8 highlights | Current features | High | 2026-09-15 |
| Base UI composition | https://base-ui.com/react/handbook/composition | Official | render prop forms | API model | High | 2026-09-15 |
| MUI 2026 and beyond | https://mui.com/blog/2026-and-beyond/ | Official | Pigment/Joy on hold, Base UI focus, Toolpad | Roadmap status | High | 2026-09-15 |
| MUI upgrade to v9 | https://mui.com/material-ui/migration/upgrade-to-v9/ | Official | Breaking changes, browsers, slots | Migration | High | 2026-09-15 |
| Pigment CSS repo | https://github.com/mui/pigment-css | Open Source | Alpha/on-hold banner | Avoid adoption | High | 2026-09-15 |
| React Aria site | https://react-aria.adobe.com/ | Official | Styling model, layers, i18n | Core facts | High | 2026-09-15 |
| Spectrum S2 release notes | https://react-spectrum.adobe.com/beta/s2/release-notes.html | Official | Macro layers, Provider fonts, UNSAFE_className | S2 pitfalls | High | 2026-09-15 |
| Ariakit styling guide | https://ariakit.com/guide/styling | Official | Selectors, CSS vars | Styling | High | 2026-09-15 |
| Headless UI v2 blog | https://tailwindcss.com/blog/headless-ui-v2 | Official | Anchor, forms, checkbox | v2 APIs | High | 2026-09-15 |
| Headless UI registry | https://registry.npmjs.org/@headlessui/react/latest | Official | 2.2.10, deps | Maintenance signal | High | 2026-09-15 |
| Chakra v3 announcement | https://chakra-ui.com/blog/announcing-v3 | Official | Ark + Panda-style, CSS animations | Architecture | High | 2026-09-15 |
| Chakra theming | https://chakra-ui.com/docs/theming/customization/overview | Official | createSystem, typegen | Theming | High | 2026-09-15 |
| Chakra releases | https://github.com/chakra-ui/chakra-ui/releases | Open Source | 3.37 features | Current state | High | 2026-09-15 |
| Ant Design v6 migration | https://ant.design/docs/react/migration-v6/ | Official | Requirements, renamed props | Migration | High | 2026-09-15 |
| Ant Design 6.0 (Medium) | https://medium.com/ant-design/ant-design-6-0-is-here-0f5b2803e6a0 | Official | CSS vars default, React 18+ | Architecture | High | 2026-09-15 |
| Mantine 9.0.0 changelog | https://mantine.dev/changelog/9-0-0/ | Official | Requirements, breaking changes, MCP | Migration | High | 2026-09-15 |
| Mantine all releases | https://mantine.dev/changelog/all-releases/ | Official | 9.x timeline | Currency | High | 2026-09-15 |
| PrimeReact changelog | https://primereact.dev/changelog | Official | v11 dates, four modes, primeui.dev | Current major | High | 2026-09-15 |
| PrimeReact v11 discussion | https://github.com/orgs/primefaces/discussions/4290 | Open Source | Planned modes | Architecture intent | Medium | 2026-09-15 |
| PrimeReact LICENSE | https://github.com/primefaces/primereact/blob/master/LICENSE.md | Open Source | MIT | Licensing | High | 2026-09-15 |
| HeroUI v3 (InfoQ) | https://www.infoq.com/news/2026/07/heroui-v3-rewrite/ | Community | Architecture, migration, reception | v3 facts (docs unreachable) | Medium | 2026-09-15 |
| @heroui/react registry | https://registry.npmjs.org/@heroui/react/latest | Official | 3.2.5, peers, MIT | Requirements | High | 2026-09-15 |
| Ark UI styling | https://ark-ui.com/docs/guides/styling | Official | data-scope/part, --layer-index | Styling | High | 2026-09-15 |
| Zag.js intro | https://zagjs.com/overview/introduction | Official | State machine model | Architecture | High | 2026-09-15 |
| Park UI repo | https://github.com/chakra-ui/park-ui | Open Source | Ark + Panda, MIT | Styled layer | Medium | 2026-09-15 |
| daisyUI themes | https://daisyui.com/docs/themes/ | Official | v5 CSS plugin syntax | Tailwind v4 config | High | 2026-09-15 |
| Flowbite repo | https://github.com/themesberg/flowbite | Open Source | Data-attribute JS, ports | React pitfalls | Medium | 2026-09-15 |
| Preline repo | https://github.com/htmlstreamofficial/preline | Open Source | Plugins, Fair Use License | Licensing | Medium | 2026-09-15 |
| Bootstrap blog | https://blog.getbootstrap.com/ | Official | 5.3.8, security fund | Status | High | 2026-09-15 |
| Bootstrap 2026 (Canvas) | https://canvastemplate.com/blog/bootstrap-2026 | Community | v6 alpha changes | Preview | Medium | 2026-09-15 |
| Vercel acquires Tremor | https://vercel.com/blog/vercel-acquires-tremor | Official | Acquisition, Blocks free | Status | High | 2026-09-15 |
| Tremor site | https://www.tremor.so/ | Official | Distribution modes | Usage | Medium | 2026-09-15 |
| @tremor/react registry | https://registry.npmjs.org/@tremor/react/latest | Official | 3.18.7, React ^18 peer | Compatibility risk | High | 2026-09-15 |
| Vaul repo | https://github.com/emilkowalski/vaul | Open Source | Unmaintained notice | Deprecation | High | 2026-09-15 |
| shadcn issue #8455 | https://github.com/shadcn-ui/ui/issues/8455 | Open Source | Vaul unmaintained since October 2025 | Timeline | Medium | 2026-09-15 |
| Sonner repo | https://github.com/emilkowalski/sonner | Open Source | API, MIT | Usage | High | 2026-09-15 |
| cmdk repo | https://github.com/pacocoursey/cmdk | Open Source | API, deps, perf limits | Usage | High | 2026-09-15 |
| Aceternity UI | https://ui.aceternity.com/ | Official | Install, tiers | Licensing | Medium | 2026-09-15 |
| Magic UI repo | https://github.com/magicuidesign/magicui | Open Source | MIT, stack | Usage | High | 2026-09-15 |
| coss ui | https://coss.com/ui | Official | Base UI foundation | Ecosystem | Medium | 2026-09-15 |
| 21st.dev registry landscape | https://21st.dev/blog/shadcn-registry-directory | Community | Registry ecosystem | Discovery | Low | 2026-09-15 |
| Fluent UI repo | https://github.com/microsoft/fluentui | Open Source | v9/v8/WC status, license | Status | High | 2026-09-15 |
| Carbon repo | https://github.com/carbon-design-system/carbon | Open Source | Packages, Apache-2.0 | Status | High | 2026-09-15 |
| Polaris React repo | https://github.com/Shopify/polaris-react | Archived | Deprecation, archive date, license | Avoid adoption | High | 2026-09-15 |
| @shopify/polaris registry | https://registry.npmjs.org/@shopify/polaris/latest | Deprecated | npm deprecation message | Confirmation | High | 2026-09-15 |
| Atlassian DS license | https://atlassian.design/license | Official | Usage restrictions | Licensing | High | 2026-09-15 |
| npm registry metadata (misc.) | https://registry.npmjs.org/ | Official | Versions/peers for @base-ui/react, react-aria-components, @react-spectrum/s2, @ariakit/react, @mui/material, @chakra-ui/react, antd, @mantine/core, primereact, daisyui, flowbite, flowbite-react, preline, bootstrap, @ark-ui/react, vaul, sonner, cmdk, @fluentui/react-components, @carbon/react | Version truth as of Sept 2026 | High | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Drawer primitive | Base UI Drawer / shadcn Drawer (Base UI) | Vaul | small-ui-primitives-vaul-sonner-cmdk (details), base-ui |
| Toasts | Sonner + Base UI Toast | shadcn toast/sonner components | small-ui-primitives-vaul-sonner-cmdk |
| Spectrum S2 styled system | React Spectrum S2 release notes | Adobe Spectrum in enterprise list | react-aria-and-spectrum (primary), referenced in fluent-ui-and-enterprise-systems |
| Park UI | Park UI repo | Chakra v3's styled layer | ark-ui-and-park-ui |
| Tailwind Plus / Catalyst | Catalyst docs | Headless UI coverage | headless-ui (engine), tailwind-component-kits (kit) |
| Origin UI / coss ui / Magic UI / Aceternity | shadcn registry protocol | Community registry lists (21st.dev, shadcn.io) | animated-component-collections |
| PrimeVue | PrimeReact changelog | PrimeVue (out of scope) | primereact-and-primevue (one-line mention) |
| Flowbite / Preline / daisyUI | Respective official docs | Separate kits | tailwind-component-kits |

## Gaps
- HeroUI v3 official docs pages returned 404/403, so component anatomy and CSS variable names in the heroui skill are illustrative and unverified.
- Tremor copy-paste components: current Tailwind v4 / React 19 support and 2026 maintenance cadence not verified.
- React-Bootstrap current version and React 19 support not verified.
- PrimeReact v11 concrete imports, provider and CLI (Tailwind mode) not reproduced from docs.
- Fluent UI v9 Griffel SSR setup for Next.js App Router, and Spectrum S2 macro support under Turbopack, not verified.
- Atlassian Design System styling engine and package details for external developers not verified (only license).
- coss ui and Origin UI licenses and registry namespaces not verified (originui.com returned 403).
- Park UI's current Tailwind support and CLI not verified.
- Some GitHub release pages reported "2024" dates for September releases (likely parsing errors); versions were confirmed via the npm registry instead.
- WebSearch session budget was exhausted mid-research; later verification relied on WebFetch of official pages and npm metadata.
- No extra slugs added. Candidate future slugs: `shadcn-registry-authoring` (private/GitHub registries, registry:base), `mui-x-components` (Data Grid/Pickers licensing tiers).
