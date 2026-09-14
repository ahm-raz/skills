# Duplicates & Overlaps

Overlapping knowledge found across sources and skills, the canonical source chosen, and where it was merged. Last generated: 2026-09-15

| Topic | Canonical Source | Alternates Merged | Merged Into Slug | Workstream |
|---|---|---|---|---|
| Post-response work on Vercel | Next.js `after()` API reference | `@vercel/functions` `waitUntil` docs | nextjs-after-and-post-response-work | G1 |
| Checkout fulfillment reliability | Stripe Fulfill orders guide | Stripe webhooks guide (duplicates/ordering), Checkout quickstart success page | stripe-payments-in-nextjs | G1 |
| Draft preview in CMSs | Next.js Draft Mode guide | Sanity visual editing, Payload preview (Contentful referenced) | nextjs-draft-mode-and-cms-preview | G1 |
| Remote MDX security | Next.js MDX guide (sanitize pipeline) | next-mdx-remote README security section | nextjs-mdx-content | G1 |
| Durable background jobs | (no single canonical) | Inngest, QStash, Trigger.dev quickstarts | nextjs-after-and-post-response-work (short section) | G1 |
| Checkout/pricing UX | checkout-flow-design / pricing-page-patterns (W10) | Not duplicated; linked only | stripe-payments-in-nextjs (links) | G1 |
| Conditional UI / passkey autofill | web.dev passkey-form-autofill | passkeys.dev bootstrapping, MDN WebAuthn, SimpleWebAuthn browser docs | passkeys-and-webauthn | G2 |
| Registration option recommendations | web.dev passkey-registration | passkeys.dev bootstrapping (UV preferred), SimpleWebAuthn server docs | passkeys-and-webauthn | G2 |
| Device budgets | Performance Inequality Gap 2026 | 2024 edition | low-end-device-performance | G2 |
| Capability signals | MDN deviceMemory / Network Information | web.dev adaptive loading, web.dev Save-Data, MDN Sec-CH-Device-Memory | low-end-device-performance | G2 |
| Zoom/reflow/spacing criteria | W3C Understanding docs (1.4.4/1.4.10/1.4.12/1.4.13) | Technique C36 | reflow-zoom-and-text-spacing | G2 |
| Feature/layered folder architecture | Feature-Sliced Design docs | Generic "feature folders", eslint-plugin-boundaries guides | feature-based-architecture | W01 |
| Module boundary enforcement | Nx enforce-module-boundaries | Turborepo boundaries (experimental), eslint-plugin-boundaries, Steiger | monorepo-frontend-architecture (tools), feature-based-architecture (in-app) | W01 |
| Strict CSP | web.dev Strict CSP | Next.js CSP guide, MDN CSP reference | content-security-policy | W01 |
| Trusted Types / Sanitizer API | MDN Trusted Types API | URIports blog, Sanitizer API articles | frontend-security-fundamentals (policy), content-security-policy (headers) | W01 |
| Browser OAuth token storage | RFC 10017 | OWASP HTML5 cheat sheet storage guidance, IETF drafts | frontend-auth-token-handling | W01 |
| Server error reporting in Next.js | Next.js instrumentation.js docs | Sentry Next.js guide | frontend-observability (pipeline), frontend-error-handling-architecture (policy) | W01 |
| npm install-time hardening | pnpm supply chain docs + GitHub npm changelog | Community hardening blogs (nodejs-security, dev.to) | dependency-supply-chain-security | W01 |
| Flag taxonomy | Martin Fowler/Pete Hodgson Feature Toggles | Vendor docs | feature-flags-and-experimentation | W01 |
| Micro-frontend integration models | Martin Fowler Micro Frontends | 2026 community guides | micro-frontends | W01 |
| Effect anti-patterns / derived state | react.dev "You Might Not Need an Effect" | Vercel rules rerender-derived-state-no-effect, rerender-move-effect-to-event; Abramov useEffect guide | react-hooks-patterns | W02 |
| Re-render optimization rules | vercel-labs react-best-practices | react.dev memo/useMemo docs; Abramov "Before You memo()"; Josh Comeau re-render article | react-performance-optimization | W02 |
| RSC server rules (auth actions, serialization, dedup) | react.dev RSC reference | Vercel server-* rules | react-server-components | W02 |
| forwardRef/ref-as-prop, removed legacy APIs | React 19 upgrade guide | React 19 release post; types-react-codemod docs | react-19-migration-guide (summary also in react-refs-and-imperative-apis) | W02 |
| URL state for filters | nuqs / Next.js searchParams | React Router useSearchParams, TanStack Router validateSearch | react-state-management (details deferred to W04 react-url-state-nuqs) | W02 |
| Server Actions forms | react.dev useActionState | Next.js Updating Data guide | react-19-actions-and-transitions (Next.js details deferred to W03 nextjs-server-actions) | W02 |
| Cache Components migration (segment config → use cache) | Migrating to Cache Components guide | Caching (Previous Model) guide; route segment config reference | nextjs-caching-and-revalidation | W03 |
| ISR / static shell / PPR terminology | Rendering Philosophy + Caching guides | ISR with Cache Components guide; Vercel PPR docs | nextjs-rendering-strategies | W03 |
| Error boundaries (error.js, catchError) | Error Handling docs | 16.3 blog custom error boundaries | nextjs-streaming-and-loading-ui | W03 |
| Forms with Server Actions | Server Actions guide | Mutating Data; Forms guide | nextjs-server-actions | W03 |
| Auth with Cache Components | Authentication with Cache Components guide | Authentication guide DAL sections | nextjs-authentication | W03 |
| Static export | Static Exports guide | Deploying page; BFF export caveats | nextjs-rendering-strategies (decision) + nextjs-deployment-and-self-hosting (ops) | W03 |
| Bundle analysis / lazy loading | Package bundling guide | Lazy loading guide; production checklist | nextjs-performance | W03 |
| CSP nonces in proxy | CSP guide | proxy reference | nextjs-env-and-config-security (config) with pointer from nextjs-middleware-proxy | W03 |
| Next.js AI agent setup (AGENTS.md, skills) | AI agents guide | 16.3 AI improvements blog | nextjs-version-16-upgrade / nextjs-instant-navigation (AI Agent Guidance sections); W17 owns agents-md-conventions | W03 |
| Server Action forms / useActionState | Next.js Forms guide | react.dev useActionState, GOV.UK PE principles, earlier framework-agnostic PE draft | progressive-enhancement (links to nextjs-server-actions, react-19-actions-and-transitions for depth) | W04 |
| Data Access Layer and server-only data | Next.js Data Security guide | Prisma/Drizzle setup docs | nextjs-database-integration (referenced from trpc-and-type-safe-apis and vercel-ai-sdk-integration) | W04 |
| Env var exposure rules | Next.js Environment Variables guide | Vite env docs | react-nextjs-project-setup and vite-react-spa (each framework's rules); deep security in nextjs-env-and-config-security (W03) | W04 |
| Browser-only components in Next.js | Next.js SPA guide (`next/dynamic` ssr:false) | react.dev useSyncExternalStore | browser-apis-in-react | W04 |
| Shallow routing / URL state | nuqs docs | Next.js SPA guide pushState section | react-url-state-nuqs | W04 |
| SPA mode choices | Vite docs + React Router SPA mode | Next.js static export guide | vite-react-spa | W04 |
| Tailwind v3 to v4 migration rules | Tailwind upgrade guide | ofershap/tailwind-best-practices, shamiul-anik/tailwindcss-skills, Lombiq/Tailwind-Agent-Skills | tailwind-css-v4 | W05 |
| Semantic tokens on Tailwind (`:root`/`.dark` + `@theme inline`) | Tailwind theme docs | shadcn/ui theming convention, wshobson tailwind-design-system SKILL.md | tailwind-design-system-architecture | W05 |
| Dark mode toggling in Next.js | Tailwind dark mode docs + next-themes README | Josh Comeau dark mode article, Tailwind three-way toggle script | dark-mode-implementation | W05 |
| Runtime vs zero-runtime CSS-in-JS status | Next.js CSS-in-JS guide | styled-components maintenance discussion, mid-2026 zero-runtime roundup, PkgPulse/OpenReplay state-of articles | css-in-js-and-zero-runtime | W05 |
| Layout primitives (Stack/Cluster/Sidebar/Switcher) | Every Layout | CUBE CSS composition layer, Defensive CSS | spacing-and-layout-systems (grid/flex mechanics in css-grid-and-flexbox-layout) | W05 |
| Fluid clamp() type | Utopia | LogRocket fluid vs responsive, OddBird fluid type, SitePoint clamp article | fluid-typography-and-spacing | W05 |
| Color derivation (relative colors, color-mix) | web.dev color themes article | Ahmad Shadeed relative colors, MDN relative colors | theming-with-css-variables (palette design in color-systems) | W05 |
| Baseline/support facts for new CSS | web.dev Baseline 2026 + Interop 2026 | WebKit/Mozilla Interop posts, various 2026 roundup blogs | modern-css-features | W05 |
| Context menus | APG Menu and Menubar | Radix/Base UI ContextMenu docs | dropdown-menus | W06 |
| Menubar (app chrome) | APG Menu and Menubar | Radix/Base UI Menubar | dropdown-menus | W06 |
| Hover cards / toggletips | MDN Popover API + WCAG 1.4.13 | Radix HoverCard, Base UI PreviewCard | popovers (hover cards), tooltips (toggletips) | W06 |
| Bottom sheets vs side drawers | NN/g Bottom Sheets + APG Dialog | shadcn Sheet, Base UI Drawer, Vaul | drawers-and-sheets | W06 |
| Scroll locking | MDN dialog + Master.dev | overscroll-behavior articles | accessible-dialogs | W06 |
| Infinite scroll / load more | GOV.UK Pagination + APG Feed | TanStack Query infinite queries | pagination (UX), list-virtualization (rendering) | W06 |
| Disclosure widget | APG Accordion / Disclosure | details/summary MDN, Chrome exclusive accordion | accordions-and-disclosure | W06 |
| Navigation tabs vs in-page tabs | APG Tabs + NN/g | GOV.UK Tabs | tabs (links cross-ref navigation-menus-and-sidebars) | W06 |
| Window splitter | APG Window Splitter | react-resizable-panels, shadcn Resizable | resizable-panels | W06 |
| Positioning of all overlays | MDN anchor positioning + Floating UI | Radix/Base UI positioner props | floating-element-positioning | W06 |
| Library-specific detail for Vaul/Sonner/cmdk | Library repos | — | referenced; canonical library coverage lives in W08 small-ui-primitives-vaul-sonner-cmdk | W06 |
| Error summary + inline errors | GOV.UK Error summary | W3C WAI notifications, Adam Silver | form-validation-patterns | W07 |
| Validation timing | GOV.UK Validation + Baymard | NN/g, Adam Silver | form-validation-patterns | W07 |
| Shared Zod schema, client (RHF) + server (Server Action) | Zod 4 + @hookform/resolvers + React useActionState | Conform, TanStack Form | react-hook-form-and-zod (other W07 skills show condensed versions and link here) | W07 |
| Numeric entry guidance | GOV.UK Text input | MDN input type=number, web.dev | number-and-currency-inputs | W07 |
| Password field primitive vs auth flow | web.dev sign-in best practices | GOV.UK, MDN autocomplete | text-inputs-and-fields (PasswordField); otp-and-auth-forms (flows) | W07 |
| Toggle button vs switch | APG Button / Switch | NN/g toggle guidelines | buttons-and-actions (aria-pressed); checkbox-radio-switch (role=switch) | W07 |
| Combobox ARIA/keyboard | APG Combobox | React Aria, Base UI, Downshift, GOV.UK autocomplete | select-and-combobox (search-and-autocomplete references it) | W07 |
| Multi-select chips | Base UI Combobox Chips | React Aria TagGroup, Downshift useTagGroup | tags-and-chips-input | W07 |
| Applied-filter chips | Baymard Applied Filters | — | filters-and-faceted-search (chip semantics in tags-and-chips-input) | W07 |
| Command-palette search | — | cmdk, React Aria Autocomplete | Left to command-palette (W06); linked only | W07 |
| Calendar keyboard/ARIA | APG Date Picker Dialog | react-day-picker, React Aria docs | date-pickers-and-calendars | W07 |
| Slider keyboard/ARIA | APG Slider + Multi-Thumb | Base UI / Radix / React Aria | sliders-and-range-inputs | W07 |
| Upload security | OWASP File Upload Cheat Sheet | MDN accept/fakepath notes | file-upload | W07 |
| Rich-text HTML sanitization | OWASP XSS Prevention | DOMPurify, sanitize-html | rich-text-editors | W07 |
| Drawer primitive | Base UI Drawer / shadcn Drawer (Base UI) | Vaul | small-ui-primitives-vaul-sonner-cmdk (details), base-ui | W08 |
| Toasts | Sonner + Base UI Toast | shadcn toast/sonner components | small-ui-primitives-vaul-sonner-cmdk | W08 |
| Spectrum S2 styled system | React Spectrum S2 release notes | Adobe Spectrum in enterprise list | react-aria-and-spectrum (primary), referenced in fluent-ui-and-enterprise-systems | W08 |
| Park UI | Park UI repo | Chakra v3's styled layer | ark-ui-and-park-ui | W08 |
| Tailwind Plus / Catalyst | Catalyst docs | Headless UI coverage | headless-ui (engine), tailwind-component-kits (kit) | W08 |
| Origin UI / coss ui / Magic UI / Aceternity | shadcn registry protocol | Community registry lists (21st.dev, shadcn.io) | animated-component-collections | W08 |
| PrimeVue | PrimeReact changelog | PrimeVue (out of scope) | primereact-and-primevue (one-line mention) | W08 |
| Flowbite / Preline / daisyUI | Respective official docs | Separate kits | tailwind-component-kits | W08 |
| Error message wording | GOV.UK Design System error message | Atlassian error messages, NN/g error guidelines | error-states (wording formulas also referenced in microcopy-ux-writing) | W09 |
| Response-time / loading thresholds | NN/g response time limits & skeleton screens | Laws of UX Doherty Threshold, Carbon loading pattern | loading-states | W09 |
| Undo vs confirmation | NN/g confirmation dialogs | Vercel guidelines, GNOME HIG dialogs | destructive-actions-and-confirmation | W09 |
| Optimistic updates | React useOptimistic docs | TanStack Query optimistic updates, Vercel guidelines | optimistic-ui | W09 |
| Human-AI interaction guidelines | Microsoft HAX | Google PAIR, Apple HIG Generative AI, shapeof.ai | ai-chat-interface-ux | W09 |
| Dark pattern taxonomy | deceptive.design | NN/g deceptive patterns, Gray et al. ontology | ethical-design-and-dark-patterns | W09 |
| Gestalt / psychology laws | Laws of UX | Refactoring UI principles | ui-design-principles-for-engineers, visual-hierarchy-and-layout | W09 |
| Inspiration site descriptions | Individual site pages/terms | SaaSUI and other roundup articles | ui-inspiration-and-reference-sources | W09 |
| Cart abandonment statistics | Baymard cart abandonment list | Redstag, Zipchat, ZeroCart, CO Consulting summaries | checkout-flow-design, ecommerce-ux-patterns | W10 |
| PCI DSS 4.0.1 SAQ A change | PCI SSC FAQ blog | Hyperproof, Jscrambler, Compass IT, Top Floor, Feroot | checkout-flow-design, fintech-ui-patterns | W10 |
| Structured data deprecations 2025–2026 | Google Search Central updates/blog | Relevant Audience, Passionfruit, Elementera, Engage Coders, Proton Effect, SEJ | seo-for-frontend | W10 |
| iOS PWA support | firt.dev notes | MagicBell, MobiLoud, PushAlert, Pushly, MoEngage, Insider docs | progressive-web-apps | W10 |
| HIPAA tracking technologies ruling | HHS OCR bulletin + HIPAA Journal | Proskauer, Nixon Peabody, Quarles, Arnold & Porter, McDermott, Holland & Hart | healthcare-ui-patterns | W10 |
| llms.txt | Mintlify docs (vendor) + llmstxt.org convention | Fern, InfoQ Blume, DEV articles | documentation-site-patterns, seo-for-frontend | W10 |
| Dynamic viewport units / keyboard | web.dev viewport units + HTMHell | OpenReplay, savvy.co.il, frontend-tips | mobile-web-app-patterns | W10 |
| Landing page vs pricing CTA guidance | NN/g | Agency blogs on SaaS pricing | landing-page-design, pricing-page-patterns | W10 |
| Focus indicator styling (2.4.7/2.4.11/2.4.13) | WCAG Understanding docs | Keyboard-navigation and color-contrast notes | focus-management (others cross-reference) | W11 |
| Skip links / bypass blocks | W3C Page Structure tutorial | Keyboard-navigation skip link snippet | landmarks-and-accessible-navigation | W11 |
| Error summary + focus | GOV.UK Design System | Focus-management error example | accessible-forms | W11 |
| Route change announcements | Next.js docs + Gatsby research | Live-regions navigation note | accessible-spa-routing | W11 |
| Target size 2.5.8 | Understanding 2.5.8 | WCAG matrix row | touch-and-pointer-accessibility | W11 |
| Forced colors / system colors | MDN forced-colors, CSS Color Adjust spec | Color-contrast CSS helpers | forced-colors-and-high-contrast | W11 |
| Legal regimes (EAA, ADA, 508) | EUR-Lex, ADA.gov, Section508.gov | Standards-status bullets in wcag-2-2-compliance | accessibility-legal-compliance | W11 |
| ACR/VPAT production | ITI VPAT + WCAG-EM | Legal-compliance ACR section | accessibility-audit-process | W11 |
| Reflow / resize text / text spacing (1.4.4, 1.4.10, 1.4.12) | Understanding docs | Considered as a separate slug | wcag-2-2-compliance (not split; see Gaps) | W11 |
| CWV thresholds & definitions | web.dev Web Vitals | addyosmani/web-quality-skills core-web-vitals skill; vendor blog restatements | core-web-vitals | W12 |
| LCP subparts methodology | web.dev Optimize LCP | DebugBear/Calibre LCP breakdown articles; DevTools LCP breakdown insight | lcp-optimization | W12 |
| Yielding / long tasks | web.dev Optimize long tasks + MDN scheduler.yield | DEV.to / OpenReplay scheduler articles | inp-optimization | W12 |
| Lighthouse audits vs DevTools insights | Chrome "Lighthouse 13" blog | DebugBear insights article; SEJ coverage | performance-profiling-devtools | W12 |
| next/image & next/font performance | Next.js API docs | — (deep config owned by W03) | image-optimization, font-loading-performance (link to nextjs-image-and-font-optimization) | W12 |
| React re-render optimization | react.dev | — (owned by W02) | Not duplicated; linked to react-performance-optimization | W12 |
| Next.js route-level performance | Next.js docs | — (owned by W03) | Not duplicated; linked to nextjs-performance | W12 |
| Lab budgets in CI | Lighthouse CI docs | size-limit | performance-budgets-and-rum (LHCI details linked to W16 lighthouse-ci) | W12 |
| Animation frame performance | web.dev rendering performance | — (motion owned by W13) | rendering-performance (links animation-performance) | W12 |
| no-store & bfcache | Chrome bfcache-ccns doc | RUMvision, Joomla issue | back-forward-cache, http-caching-and-cdn | W12 |
| UI animation durations & easings | Material 3 tokens + emilkowalski/skills | vercel-labs web-animation-design, Emil's 7 tips, Apple HIG | motion-design-principles (tokens), referenced by micro-interactions, css-animations-and-transitions | W13 |
| FLIP / layout animation | Motion layout docs | GSAP Flip, AutoAnimate, React ViewTransition update/share, manual WAAPI FLIP | layout-animations | W13 |
| Route/page transitions in Next.js | Next.js view transitions guide + React ViewTransition ref | Motion AnimatePresence route patterns, template.tsx approaches, vercel react-view-transitions skill | view-transitions-api | W13 |
| Reduced-motion handling | MDN / WCAG 2.3.3 (owned by W11 reduced-motion-and-vestibular-safety) | Motion MotionConfig, gsap.matchMedia, Svelte prefersReducedMotion (dropped: out of scope) | Per-skill Accessibility sections; canonical in reduced-motion-and-vestibular-safety (W11) | W13 |
| Compositor-only properties | web.dev animations guide | Motion performance tier list, Emil's rules | animation-performance | W13 |
| Scroll-linked effects | MDN animation-timeline / WebKit guide | GSAP ScrollTrigger, Motion useScroll | scroll-driven-animations (CSS), gsap-animation (pinning) | W13 |
| Framework transition systems (Vue `<Transition>`, Svelte transitions, motion-v) | — | Researched then dropped per scope change | Skipped (svelte-and-vue-animation) | W13 |
| Sparklines | Tufte / Few | Bundled dataviz stat tile guidance | kpi-and-stat-components | W14 |
| Chart color rules (CVD, sequential/diverging) | Datawrapper colorblind guide | Bundled dataviz color-formula; Carbon palette guidance (unfetched) | data-visualization-principles (cross-ref accessible-data-visualization) | W14 |
| Canvas vs SVG vs WebGL thresholds | ECharts renderer guide + uPlot benchmarks | Chart.js performance doc; deck.gl docs | large-dataset-visualization-performance | W14 |
| Chart SSR in Next.js | ECharts SSR docs | Recharts/nivo/Chart.js client-only notes | Per-library Framework Notes (echarts canonical example) | W14 |
| Gauges vs bullets | NN/g + Few | FT Visual Vocabulary | chart-type-selection, kpi-and-stat-components | W14 |
| Operational live dashboards | MDN SSE + WebSocketStream | dashboard-design operational type | realtime-data-ui | W14 |
| Server-side table state (pagination/sort/filter) | TanStack Table v9 client-side-vs-server-side guide + nuqs server-side docs | AG Grid SSRM datasource, MUI X dataSource | enterprise-data-tables (contract), data-grids-ag-grid (grid-specific adapters) | W15 |
| Server-side authorization for admin mutations | Next.js data-security guide | refine authProviderServer, react-admin authProvider | role-based-ui-and-permissions (canonical); referenced by admin-panel-architecture, bulk-actions, workflow-and-approval-ui | W15 |
| UI permission gating | @casl/react | Permit.io frontend SDK (CASL-based), refine useCan/CanAccess | role-based-ui-and-permissions | W15 |
| Batch/bulk action bar anatomy | Carbon TableBatchActions | Polaris index table promoted bulk actions (deprecated React lib), NN/g batch actions | bulk-actions | W15 |
| Grid keyboard model | W3C APG grid pattern | EUI data grid keyboard, AG Grid keyboard | keyboard-power-user-ui (global shortcuts), enterprise-data-tables (in-grid navigation) | W15 |
| CSV/XLSX import and export | Papa Parse docs | SheetJS CE, ExcelJS, react-spreadsheet-import | data-import-export-ui | W15 |
| Drag-and-drop boards | dnd-kit | Pragmatic drag and drop, @dnd-kit/react 0.5.0 | kanban-boards (generic DnD stays in W06 drag-and-drop) | W15 |
| Floorplans (list report / object page / flexible column layout) | SAP Fiori floorplan overview (403 — from general knowledge) | UI5 Web Components for React, NN/g master-detail guidance | erp-ui-patterns (floorplans), master-detail-layouts (layout mechanics) | W15 |
| Next.js test setup (Vitest/Jest/Playwright/Cypress) | Next.js testing guides | Vercel with-* examples | vitest-unit-testing, jest-testing, playwright-e2e-testing, cypress-e2e-testing | W16 |
| Query priority / user-centric selectors | Testing Library queries docs | Playwright locator best practices, Storybook canvas queries | testing-library-principles | W16 |
| Screenshot comparison | Playwright test-snapshots | Vitest toMatchScreenshot, Chromatic, Argos, Percy, Lost Pixel | visual-regression-testing | W16 |
| Stories as tests / component isolation | Storybook Vitest addon | Playwright CT stories/galleries, Cypress CT, Vitest Browser Mode | component-testing (comparison) + storybook-component-workshop (Storybook depth) | W16 |
| Flaky test causes and remedies | Google Testing Blog | Martin Fowler non-determinism, Playwright retries docs | flaky-test-management | W16 |
| Server-side fetch mocking in Next.js | Next.js experimental testmode README | MSW issue #1644, env-pointed mock servers | testing-server-components-and-actions (api-mocking-msw links to it) | W16 |
| Agent-driven browser testing | Playwright test agents + Playwright MCP | anthropics/skills webapp-testing | playwright-e2e-testing (AI Agent Guidance); deeper workflow deferred to W17 browser-automation-agent-workflow | W16 |
| Automated axe checks | W11 automated-accessibility-testing | Storybook a11y addon, @axe-core/playwright, Lighthouse a11y | Linked only (not duplicated) | W16 |
| Skill file format | agentskills.io specification + Claude Code skills docs | Anthropic authoring best practices, VS Code/Copilot skills support | agent-skills-authoring | W17 |
| Cross-agent project instructions | agents.md | CLAUDE.md @AGENTS.md import, GEMINI.md context.fileName, Codex discovery, Windsurf/Cline/Roo AGENTS.md support | agents-md-conventions | W17 |
| React/Next.js rule sets | vercel-labs/agent-skills react-best-practices + Next.js AI agents guide | awesome-copilot nextjs.instructions.md, composition-patterns, awesome-cursorrules Next.js rules (stale parts dropped) | nextjs-agent-rules-baseline | W17 |
| UI quality checklist | Vercel Web Interface Guidelines | web-design-guidelines command.md, awesome-copilot a11y.instructions.md | ai-frontend-code-review, ai-accessibility-audit-workflow | W17 |
| Anti-"AI slop" design guidance | anthropics/skills frontend-design | Claude cookbook aesthetics notebook, Claude blog, web-artifacts-builder notes, ui-ux-pro-max anti-patterns | distinctive-frontend-design-for-agents | W17 |
| Browser control for agents | microsoft/playwright-mcp | chrome-devtools-mcp, agent-browser, anthropics webapp-testing | browser-automation-agent-workflow | W17 |
| Runtime verification loop | Claude Code best practices (verification) | next-dev-loop skill, next-devtools-mcp, Stop hook gate | frontend-agent-verification-loop | W17 |
| MCP/browser/secret security | Claude Code MCP + hooks docs | Playwright MCP security notes, chrome-devtools-mcp disclaimer, agent-browser security flags | coding-agent-security-for-frontend | W17 |

