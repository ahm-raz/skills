# Category Taxonomy (React + Next.js)

Complete taxonomy of the library: 17 categories, 309 skills. Each skill lives at `skills/<slug>/Skill.md`. Last generated: 2026-09-15

| Category | Skills | Scope |
|---|---|---|
| Architecture | 12 | App structure, component APIs, design systems & tokens, monorepos, micro-frontends, state/API/error architecture, i18n, flags, observability, TypeScript. |
| Security | 5 | XSS/CSP, token handling, supply chain, env/config security for React + Next.js. |
| Tooling | 5 | Build tooling, linting/formatting, project setup. |
| React | 22 | React 19 model: composition, hooks, rendering, Server Components, state, data fetching, Suspense, Actions, compiler, routing alternatives, stack extensions. |
| Next.js | 29 | Next.js 16 App Router: routing, RSC, Server Actions, caching, rendering, proxy, metadata, images/fonts, auth, deployment, performance, migrations, content. |
| CSS & Styling | 19 | Modern CSS, Tailwind v4, CSS architecture, layout, responsive design, typography, color, theming, dark mode, RTL. |
| Components | 36 | Accessible, production-grade component patterns: overlays, navigation, display, inputs, forms. |
| UI Libraries | 20 | Engineering evaluation of React component ecosystems: shadcn/ui, Radix, Base UI, React Aria, MUI, Mantine, etc. |
| UX | 20 | UX foundations: hierarchy, IA, flows, states (empty/loading/error), microcopy, heuristics, optimistic UI, auth UX, AI chat UX, ethics. |
| Product Patterns | 17 | Patterns per product type: landing pages, SaaS, ecommerce, checkout, marketplaces, docs, dev tools, fintech, healthcare, mobile web/PWA, SEO, payments, email. |
| Accessibility | 21 | WCAG 2.2, ARIA, semantics, keyboard, focus, screen readers, contrast, motion, tables, media, live regions, SPA routing, testing, legal. |
| Performance | 21 | Core Web Vitals (LCP/INP/CLS), bundles, splitting, images, fonts, hydration, rendering, memory, network, caching, offline, profiling, RUM. |
| Animation | 12 | Motion for React, GSAP, CSS animation, View Transitions, scroll-driven animation, micro-interactions, layout animation, 3D. |
| Data Visualization | 13 | Visualization principles, chart selection, D3/Recharts/Chart.js/ECharts/Nivo/visx, dashboards, realtime, maps, accessible charts, large datasets. |
| Enterprise UI | 22 | Admin panels, data grids/tables, filtering, bulk actions, RBAC UI, audit logs, workflows, ERP/CRM/WMS, multi-tenant, power-user UI, collaboration. |
| Testing & QA | 17 | Testing strategy, Vitest/Jest, Testing Library, Playwright/Cypress, visual regression, Storybook, MSW, Lighthouse CI, CI/CD, flake management. |
| AI Agent Workflows | 18 | Agent skills/rules authoring (Claude Code, Cursor, Copilot, AGENTS.md), design-to-code, browser-MCP loops, AI a11y audits, debugging, review, verification. |

## Architecture

_App structure, component APIs, design systems & tokens, monorepos, micro-frontends, state/API/error architecture, i18n, flags, observability, TypeScript._

- [component-api-design](skills/component-api-design/Skill.md) (A) — Props design, compound components, slots, polymorphism, controlled/uncontrolled, variants, TypeScript typing, deprecation
- [design-system-architecture](skills/design-system-architecture/Skill.md) (A) — Atomic design, headless primitives, package structure, theming, multi-brand, versioning, distribution, documentation, copy-paste vs package
- [design-system-governance](skills/design-system-governance/Skill.md) (A) — Team models, contribution model, RFC process, versioning policy, deprecation, adoption metrics, component lifecycle, design-engineering handoff
- [design-token-architecture](skills/design-token-architecture/Skill.md) (S) — DTCG format, token tiers, naming conventions, aliases, theming/modes, resolver, Style Dictionary, Terrazzo, Figma variables sync
- [feature-based-architecture](skills/feature-based-architecture/Skill.md) (A) — Feature-Sliced Design, vertical slices, module public API, folder structure, import rules, Steiger
- [feature-flags-and-experimentation](skills/feature-flags-and-experimentation/Skill.md) (A) — Release toggles, experiments, kill switches, permission flags, OpenFeature, evaluation context, server-side evaluation, flicker prevention, exposure events, flag debt
- [frontend-api-layer-design](skills/frontend-api-layer-design/Skill.md) (A) — HTTP client, OpenAPI codegen, runtime validation, error mapping, BFF, Server Actions, retries, cancellation, pagination, query key design
- [frontend-architecture-principles](skills/frontend-architecture-principles/Skill.md) (A) — Modularity, dependency rules, colocation, layering, ADRs, fitness functions, rendering strategy, coupling and cohesion
- [frontend-error-handling-architecture](skills/frontend-error-handling-architecture/Skill.md) (A) — Error boundaries, Next.js error.tsx/global-error.tsx, expected errors as values, Server Action errors, global handlers, React root error callbacks, error reporting, retry/recovery, fail-closed
- [frontend-i18n-architecture](skills/frontend-i18n-architecture/Skill.md) (A) — Locale routing, ICU messages, pluralization, Intl formatting, RTL, type-safe translations, message loading, translation management, pseudo-localization
- [frontend-state-architecture](skills/frontend-state-architecture/Skill.md) (A) — Server state vs client state, URL state, derived state, global stores, state machines, SSR/RSC state, hydration, persistence
- [micro-frontends](skills/micro-frontends/Skill.md) (A) — Multi-Zones, Module Federation 2.0, runtime vs build-time integration, shared dependencies, app shell, cross-app communication, independent deployment, import maps

## Security

_XSS/CSP, token handling, supply chain, env/config security for React + Next.js._

- [content-security-policy](skills/content-security-policy/Skill.md) (S) — Strict CSP, nonces, hashes, strict-dynamic, Trusted Types, frame-ancestors, reporting, report-only, SRI, third-party scripts, Next.js proxy
- [dependency-supply-chain-security](skills/dependency-supply-chain-security/Skill.md) (S) — Lockfiles, install scripts, release cooldowns, vulnerability scanning, malware detection, trusted publishing, provenance, SBOM, third-party scripts, CI secrets, dependency updates
- [frontend-auth-token-handling](skills/frontend-auth-token-handling/Skill.md) (S) — BFF, session cookies, OAuth 2.0/OIDC, PKCE, refresh token rotation, DPoP, token storage, CSRF, logout, silent renew, Auth.js, Better Auth
- [frontend-security-fundamentals](skills/frontend-security-fundamentals/Skill.md) (S) — XSS, DOM XSS, Trusted Types, Sanitizer API, CSRF, clickjacking, security headers, cookies, secrets, open redirects, postMessage, SSRF, RSC data exposure, OWASP Top 10:2025
- [passkeys-and-webauthn](skills/passkeys-and-webauthn/Skill.md) (A) — WebAuthn, FIDO2, passkeys, conditional mediation, discoverable credentials, related origin requests, Signal API, account recovery, SimpleWebAuthn, Better Auth, Clerk, Auth.js

## Tooling

_Build tooling, linting/formatting, project setup._

- [frontend-build-tooling](skills/frontend-build-tooling/Skill.md) (A) — Vite, Rolldown, Oxc, Turbopack, Rspack, Rsbuild, library bundling, environment variables, source maps, browserslist/targets, bundle analysis, dev server
- [frontend-observability](skills/frontend-observability/Skill.md) (A) — Error monitoring, RUM, Core Web Vitals, distributed tracing, OpenTelemetry, structured logging, session replay, source maps, sampling, PII scrubbing, alerting
- [linting-and-formatting](skills/linting-and-formatting/Skill.md) (A) — ESLint flat config, typescript-eslint, eslint-plugin-react-hooks, @next/eslint-plugin-next, jsx-a11y, Biome, Oxlint, Oxfmt, Prettier, Stylelint, lint-staged, CI enforcement
- [monorepo-frontend-architecture](skills/monorepo-frontend-architecture/Skill.md) (A) — pnpm workspaces, catalogs, Turborepo, Nx, internal packages, remote caching, affected builds, module boundaries, TypeScript project config
- [typescript-for-frontend](skills/typescript-for-frontend/Skill.md) (S) — tsconfig, strict mode, TypeScript 7 native compiler, module resolution, type-safe env, discriminated unions, generics, satisfies, runtime validation, typed routes, type-checking in CI

## React

_React 19 model: composition, hooks, rendering, Server Components, state, data fetching, Suspense, Actions, compiler, routing alternatives, stack extensions._

- [browser-apis-in-react](skills/browser-apis-in-react/Skill.md) (A) — Custom hooks, useSyncExternalStore, SSR safety, hydration, observers, storage, clipboard, cross-tab sync, permissions
- [modern-javascript-for-react](skills/modern-javascript-for-react/Skill.md) (A) — Immutability, ES modules, async programming, closures, cancellation, internationalization formatting, date/time, collections, error handling
- [react-19-actions-and-transitions](skills/react-19-actions-and-transitions/Skill.md) (S) — useTransition, startTransition, useActionState, useOptimistic, useFormStatus, form actions, Server Actions, requestFormReset, useDeferredValue, pending UI
- [react-19-migration-guide](skills/react-19-migration-guide/Skill.md) (A) — React 18 to 19 upgrade, removed APIs, codemods, TypeScript type changes, forwardRef deprecation path, error handling changes, Next.js alignment, RSC CVE patch levels, 19.1/19.2/19.3 feature adoption
- [react-compiler](skills/react-compiler/Skill.md) (A) — automatic memoization, Rules of React, eslint-plugin-react-hooks, incremental adoption, "use memo"/"use no memo", Next.js integration, Vite integration, compatibility
- [react-component-composition](skills/react-component-composition/Skill.md) (A) — children and slots, compound components, render props, polymorphic components (asChild), headless components, lifting content up, container/presentational split
- [react-context-patterns](skills/react-context-patterns/Skill.md) (A) — createContext, use(Context), provider placement, context splitting, context + useReducer, compound component context, dependency injection, Next.js providers
- [react-custom-hooks-library-design](skills/react-custom-hooks-library-design/Skill.md) (A) — custom hook API design, naming, return shapes, stable callbacks, SSR-safe hooks, useSyncExternalStore, "use client" in libraries, packaging, testing with renderHook, compiler compatibility
- [react-data-fetching-tanstack-query](skills/react-data-fetching-tanstack-query/Skill.md) (S) — queryOptions, query keys, staleTime/gcTime, mutations, invalidation, optimistic updates, infinite queries, useSuspenseQuery, SSR hydration, Next.js App Router, prefetching
- [react-hooks-patterns](skills/react-hooks-patterns/Skill.md) (S) — Rules of Hooks, useEffect, useEffectEvent, derived state, useReducer, useSyncExternalStore, useId, use(), cleanup, race conditions
- [react-performance-optimization](skills/react-performance-optimization/Skill.md) (S) — waterfalls, bundle size, re-renders, memoization, transitions, virtualization, code splitting, profiling, INP
- [react-refs-and-imperative-apis](skills/react-refs-and-imperative-apis/Skill.md) (A) — useRef, ref as prop, forwardRef migration, ref callbacks with cleanup, useImperativeHandle, Fragment refs, flushSync, DOM measurement, third-party widget integration
- [react-rendering-model](skills/react-rendering-model/Skill.md) (S) — render and commit phases, reconciliation and keys, state identity and preservation, batching, concurrent rendering, Strict Mode, hydration, Activity
- [react-router-framework-mode](skills/react-router-framework-mode/Skill.md) (B) — framework mode, data mode, declarative mode, loaders, actions, clientLoader, fetchers, middleware, route typegen, SPA mode, prerendering, v7 to v8 upgrade
- [react-server-components](skills/react-server-components/Skill.md) (A) — server/client boundary, "use client", "use server", Server Functions, serialization, cache(), cacheSignal, server-only, taint APIs, streaming, RSC security
- [react-state-management](skills/react-state-management/Skill.md) (A) — local state, lifting state, URL/search-param state, server state vs client state, Zustand, Jotai, Redux Toolkit, RTK Query, form state, persistence
- [react-suspense-and-error-boundaries](skills/react-suspense-and-error-boundaries/Skill.md) (A) — Suspense boundaries, lazy loading, use(), streaming SSR, error boundaries, react-error-boundary, reset keys, root error handlers, Next.js loading/error files, ViewTransition + Suspense
- [react-typescript-patterns](skills/react-typescript-patterns/Skill.md) (A) — props typing, ComponentProps, children/ReactNode, discriminated unions, generic components, event types, ref typing, hook typing, context typing, polymorphism, Next.js route types, @types/react 19 changes
- [tanstack-router-and-start](skills/tanstack-router-and-start/Skill.md) (B) — file-based routing, type-safe navigation, search param validation, loaders, preloading, router context, TanStack Query integration, createServerFn, middleware, server routes, SSR/streaming
- [tanstack-table](skills/tanstack-table/Skill.md) (B) — headless tables, column definitions, sorting, filtering, pagination, row selection, server-side (manual) mode, virtualization, v8 to v9 migration, React Compiler compatibility
- [vite-react-spa](skills/vite-react-spa/Skill.md) (A) — Vite, SPA architecture, client-side routing, environment variables, static hosting, build configuration, migration from CRA
- [web-components-in-react](skills/web-components-in-react/Skill.md) (A) — Custom elements, React 19 interop, properties vs attributes, custom events, SSR and Declarative Shadow DOM, TypeScript JSX typing, design system interop

## Next.js

_Next.js 16 App Router: routing, RSC, Server Actions, caching, rendering, proxy, metadata, images/fonts, auth, deployment, performance, migrations, content._

- [nextjs-advanced-routing](skills/nextjs-advanced-routing/Skill.md) (A) — Parallel routes, intercepting routes, modals, slots, route groups, useSelectedLayoutSegment, soft vs hard navigation
- [nextjs-after-and-post-response-work](skills/nextjs-after-and-post-response-work/Skill.md) (A) — Server Actions, Route Handlers, Observability, Background Jobs, Serverless, Deployment
- [nextjs-app-router-fundamentals](skills/nextjs-app-router-fundamentals/Skill.md) (A) — Routing, file conventions, layouts, dynamic routes, route groups, project structure, TypeScript route types
- [nextjs-authentication](skills/nextjs-authentication/Skill.md) (A) — Sessions, cookies, Data Access Layer, DTOs, proxy auth, Server Action authorization, Route Handler auth, RBAC, Better Auth, Clerk, Auth.js status, Cache Components auth
- [nextjs-caching-and-revalidation](skills/nextjs-caching-and-revalidation/Skill.md) (S) — use cache, cacheLife, cacheTag, updateTag, revalidateTag, revalidatePath, refresh, cache handlers, Partial Prerendering, legacy fetch cache
- [nextjs-data-fetching-patterns](skills/nextjs-data-fetching-patterns/Skill.md) (A) — Server Components fetching, fetch memoization, React.cache, parallel fetching, preload, streaming, use(), SWR, TanStack Query, Data Access Layer, external APIs
- [nextjs-database-integration](skills/nextjs-database-integration/Skill.md) (A) — Prisma ORM 7, Drizzle ORM, Data Access Layer, connection pooling, serverless databases, migrations, caching, server-only boundaries
- [nextjs-deployment-and-self-hosting](skills/nextjs-deployment-and-self-hosting/Skill.md) (A) — Vercel, self-hosting, Docker, standalone output, adapters, OpenNext, cache handlers, ISR, version skew, deploymentId, streaming proxies, static export, LTS policy
- [nextjs-draft-mode-and-cms-preview](skills/nextjs-draft-mode-and-cms-preview/Skill.md) (A) — Headless CMS, Caching, Route Handlers, Server Actions, Visual Editing, Content Workflows
- [nextjs-env-and-config-security](skills/nextjs-env-and-config-security/Skill.md) (A) — .env files, NEXT_PUBLIC_, runtime vs build-time env, @next/env, connection(), server-only, taint, next.config security headers, CSP, image security config, Server Actions config, secrets rotation, advisories
- [nextjs-image-and-font-optimization](skills/nextjs-image-and-font-optimization/Skill.md) (S) — next/image, remotePatterns, sizes, preload, placeholder, getImageProps, image loaders, next/font/google, next/font/local, variable fonts, CSS variables, Tailwind v4
- [nextjs-instant-navigation](skills/nextjs-instant-navigation/Skill.md) (A) — Partial Prefetching, App Shell, Link prefetch, instant segment config, Instant Insights, Navigation Inspector, @next/playwright instant(), useLinkStatus, prefetch inlining, UI state preservation, offline resilience
- [nextjs-internationalization](skills/nextjs-internationalization/Skill.md) (A) — Locale routing, proxy locale detection, [lang] segment, dictionaries, root params, next-intl, hreflang, generateStaticParams, formatting, RTL, localized metadata
- [nextjs-mdx-content](skills/nextjs-mdx-content/Skill.md) (B) — Content, Blogs, Documentation, Markdown, Syntax Highlighting, Static Generation, Security
- [nextjs-metadata-and-seo](skills/nextjs-metadata-and-seo/Skill.md) (A) — Metadata API, generateMetadata, title templates, metadataBase, Open Graph, sitemap.ts, robots.ts, ImageResponse, JSON-LD, canonical, hreflang, streaming metadata
- [nextjs-middleware-proxy](skills/nextjs-middleware-proxy/Skill.md) (A) — proxy.ts, middleware.ts migration, matcher, NextRequest, NextResponse, rewrites, redirects, headers, cookies, CORS, waitUntil
- [nextjs-pages-to-app-router-migration](skills/nextjs-pages-to-app-router-migration/Skill.md) (A) — Incremental migration, _app/_document, next/head, getServerSideProps, getStaticProps, getStaticPaths, ISR, next/router, API routes, i18n config, codemods
- [nextjs-performance](skills/nextjs-performance/Skill.md) (A) — Core Web Vitals, bundle size, waterfalls, lazy loading, next/script, third-party scripts, React Compiler, bundle analyzer, Turbopack, build performance, prefetching
- [nextjs-rendering-strategies](skills/nextjs-rendering-strategies/Skill.md) (S) — Partial Prerendering, static shell, App Shell, SSG, SSR, ISR, CSR, static export, generateStaticParams, connection(), bots
- [nextjs-route-handlers](skills/nextjs-route-handlers/Skill.md) (A) — route.ts, NextRequest, NextResponse, RouteContext, webhooks, CORS, streaming responses, SSE, file downloads, rate limiting, content negotiation, special metadata routes
- [nextjs-server-actions](skills/nextjs-server-actions/Skill.md) (S) — Mutations, forms, useActionState, useFormStatus, useOptimistic, revalidation, progressive enhancement, CSRF, action security
- [nextjs-server-component-patterns](skills/nextjs-server-component-patterns/Skill.md) (A) — React Server Components, client boundaries, composition, serialization, server-only, context providers, bundle size
- [nextjs-streaming-and-loading-ui](skills/nextjs-streaming-and-loading-ui/Skill.md) (S) — Suspense, loading.tsx, streaming HTML, static shell, error.tsx, catchError, notFound status, bots, htmlLimitedBots, proxy buffering, skeletons, Web Vitals
- [nextjs-version-16-upgrade](skills/nextjs-version-16-upgrade/Skill.md) (S) — Upgrade guide, codemods, breaking changes, Turbopack migration, async request APIs, proxy rename, image defaults, ESLint flat config, React 19.2, React Compiler, LTS policy, AI-agent upgrade flow
- [progressive-enhancement](skills/progressive-enhancement/Skill.md) (A) — Server Actions forms, useActionState, next/form, pre-hydration interactivity, no-JS fallbacks, server validation, resilience testing
- [react-nextjs-project-setup](skills/react-nextjs-project-setup/Skill.md) (A) — Scaffolding, TypeScript configuration, linting and formatting, environment variables, folder structure, package scripts, CI baseline, AI agent setup
- [react-url-state-nuqs](skills/react-url-state-nuqs/Skill.md) (A) — Search params, URL state, shallow routing, type-safe parsers, server components, filters, pagination, deep linking
- [trpc-and-type-safe-apis](skills/trpc-and-type-safe-apis/Skill.md) (A) — tRPC v11, TanStack Query integration, Server Actions, Route Handlers, OpenAPI code generation, API contracts, input validation, error handling
- [vercel-ai-sdk-integration](skills/vercel-ai-sdk-integration/Skill.md) (A) — AI SDK Core, AI SDK UI, streaming, tool calling, generative UI, AI Gateway, AI Elements, rate limiting, prompt injection, chat persistence

## CSS & Styling

_Modern CSS, Tailwind v4, CSS architecture, layout, responsive design, typography, color, theming, dark mode, RTL._

- [color-systems](skills/color-systems/Skill.md) (A) — OKLCH, color scales, semantic color roles, Radix Colors, Material 3 color roles, Adobe Leonardo, contrast (WCAG 2.2, APCA), P3 gamut, color-mix, relative colors, contrast-color(), data-vis palettes, state colors
- [container-queries](skills/container-queries/Skill.md) (S) — @container, container-type, container-name, cqi/cqb units, style queries, name-only queries, Tailwind @container variants, component-level responsiveness
- [css-architecture](skills/css-architecture/Skill.md) (A) — CUBE CSS, BEM, ITCSS, utility-first, Every Layout primitives, CSS reset, defensive CSS, file organization, style ownership
- [css-cascade-layers-and-specificity](skills/css-cascade-layers-and-specificity/Skill.md) (S) — Cascade, specificity, @layer, layer ordering, unlayered styles, !important, :where(), :is(), third-party CSS, Tailwind layers, CSS chunk ordering in Next.js
- [css-grid-and-flexbox-layout](skills/css-grid-and-flexbox-layout/Skill.md) (A) — Grid, Flexbox, subgrid, auto-fit/minmax, grid-template-areas, alignment, gap, intrinsic sizing, masonry/grid-lanes, app shells, holy grail layout, sticky footers
- [css-in-js-and-zero-runtime](skills/css-in-js-and-zero-runtime/Skill.md) (A) — styled-components, Emotion, vanilla-extract, StyleX, Panda CSS, Linaria, next-yak, Pigment CSS, RSC compatibility, style registries, migration
- [css-logical-properties-and-rtl](skills/css-logical-properties-and-rtl/Skill.md) (A) — Logical properties, writing modes, dir attribute, :dir(), bidi, unicode-bidi, mirroring icons, Tailwind logical utilities, RTL testing, next-intl locale direction
- [css-modules](skills/css-modules/Skill.md) (A) — Local scope, composes, :global, TypeScript typings, Vite/Next.js integration, Lightning CSS, CSS Modules with Tailwind, migration from CSS-in-JS
- [css-nesting-and-scope](skills/css-nesting-and-scope/Skill.md) (A) — Native nesting, & selector, relaxed syntax, nested at-rules, CSSNestedDeclarations, @scope, donut scope, :scope, scope proximity, inline scoped styles, Sass migration
- [dark-mode-implementation](skills/dark-mode-implementation/Skill.md) (S) — prefers-color-scheme, color-scheme, light-dark(), next-themes, Tailwind dark variant, FOUC prevention, hydration, theme toggle UX, dark palette design, media in dark mode
- [fluid-typography-and-spacing](skills/fluid-typography-and-spacing/Skill.md) (A) — clamp(), Utopia, modular scale, type steps, space pairs, vw/cqi units, zoom accessibility, Tailwind theme tokens
- [modern-css-features](skills/modern-css-features/Skill.md) (A) — Baseline, Interop 2026, progressive enhancement, @supports, :has(), container queries, anchor positioning, @scope, color functions, @starting-style, field-sizing, text-box, if(), grid-lanes
- [responsive-design](skills/responsive-design/Skill.md) (A) — Mobile-first, breakpoints, media queries (range syntax), container queries, intrinsic design, viewport units (dvh/svh/lvh), hover/pointer, prefers-reduced-motion, prefers-contrast, safe areas, orientation, touch, reflow
- [responsive-images-and-media](skills/responsive-images-and-media/Skill.md) (S) — srcset, sizes, picture, art direction, AVIF, WebP, next/image, getImageProps, LCP images, lazy loading, fetchpriority, aspect-ratio, object-fit, image-set(), responsive video, sizes="auto"
- [spacing-and-layout-systems](skills/spacing-and-layout-systems/Skill.md) (A) — Spacing scale, 4pt/8pt grid, space tokens, density, layout primitives, Every Layout, gap, margin strategy, page containers, gutters, vertical rhythm
- [tailwind-css-v4](skills/tailwind-css-v4/Skill.md) (S) — Utility-first CSS, @theme, @utility, @custom-variant, @source, Vite/PostCSS/webpack plugins, v3 migration, container queries, dark mode
- [tailwind-design-system-architecture](skills/tailwind-design-system-architecture/Skill.md) (A) — Design tokens, semantic colors, @theme inline, multi-brand theming, cva, tailwind-variants, tailwind-merge, shared presets, monorepo theme packages, shadcn-style theming
- [theming-with-css-variables](skills/theming-with-css-variables/Skill.md) (A) — Custom properties, @property, semantic tokens, data-theme scoping, multi-brand, white-label, color-mix, relative colors, runtime theme switching, SSR theming
- [typography-systems](skills/typography-systems/Skill.md) (A) — Type scale, font pairing, variable fonts, next/font, font fallbacks, line-height, measure, letter-spacing, text roles, tabular numbers, text-wrap, text-box-trim, prose styling

## Components

_Accessible, production-grade component patterns: overlays, navigation, display, inputs, forms._

- [accessible-dialogs](skills/accessible-dialogs/Skill.md) (A) — Overlays, modal dialogs, alert dialogs, confirmation dialogs, focus management, top layer, inert
- [accordions-and-disclosure](skills/accordions-and-disclosure/Skill.md) (A) — Disclosure, accordion, details/summary, exclusive accordion, show more, FAQ, collapsible sections
- [breadcrumbs](skills/breadcrumbs/Skill.md) (A) — Location navigation, hierarchy trail, mobile collapse, BreadcrumbList structured data, dynamic segments
- [buttons-and-actions](skills/buttons-and-actions/Skill.md) (A) — buttons, icon buttons, toggle buttons, button groups, split buttons, links vs buttons, submit buttons, pending states, double-submit prevention, invoker commands
- [cards](skills/cards/Skill.md) (B) — Content cards, product cards, clickable cards, card grids, media cards, stat cards, selectable cards
- [carousels](skills/carousels/Skill.md) (A) — Hero carousel, content rail, image gallery, product thumbnails, scroll-snap, auto-rotation, slide pickers
- [checkbox-radio-switch](skills/checkbox-radio-switch/Skill.md) (S) — checkbox, checkbox group, indeterminate / tri-state, radio group, radio cards, switch / toggle, segmented control, exclusive "none" option, conditional reveal
- [command-palette](skills/command-palette/Skill.md) (B) — ⌘K menu, command menu, quick switcher, keyboard shortcuts, fuzzy search, combobox, spotlight search
- [date-pickers-and-calendars](skills/date-pickers-and-calendars/Skill.md) (A) — Date input, date range picker, calendar grid, time picker, internationalized dates, timezones, Temporal API, booking UIs, SSR hydration of dates
- [drag-and-drop](skills/drag-and-drop/Skill.md) (A) — Sortable lists, kanban, cross-list moves, file drop zones, drop indicators, auto-scroll, keyboard DnD, fractional indexing
- [drawers-and-sheets](skills/drawers-and-sheets/Skill.md) (A) — Overlays, side drawer, bottom sheet, off-canvas navigation, detail panel, snap points, gestures
- [dropdown-menus](skills/dropdown-menus/Skill.md) (A) — Menu button, menu, menuitemcheckbox, menuitemradio, submenu, context menu, menubar, overflow "more" menu
- [file-upload](skills/file-upload/Skill.md) (A) — File input, dropzone, upload progress, resumable uploads, presigned URLs, Server Action file handling, image preview, avatar upload, attachment lists, camera capture
- [filters-and-faceted-search](skills/filters-and-faceted-search/Skill.md) (A) — Faceted navigation, refinement lists, range filters, applied filters, filter chips, sort, URL state, mobile filter drawer, result counts
- [floating-element-positioning](skills/floating-element-positioning/Skill.md) (A) — CSS anchor positioning, position-area, position-try-fallbacks, Floating UI, collision detection, top layer, portals, virtual elements
- [form-design-ux](skills/form-design-ux/Skill.md) (A) — Form layout, labels and hints, field sizing, required/optional marking, error recovery, form copy, autofill, mobile forms
- [form-validation-patterns](skills/form-validation-patterns/Skill.md) (A) — Validation timing, shared Zod schemas, Standard Schema, server-side validation, Server Actions, async validation, error summary, aria-invalid, focus management, constraint validation
- [list-virtualization](skills/list-virtualization/Skill.md) (A) — Windowing, dynamic row heights, infinite loading, virtualized tables, grid/masonry, chat scroll anchoring, scroll restoration
- [multi-step-forms-and-wizards](skills/multi-step-forms-and-wizards/Skill.md) (A) — Wizards, steppers, question pages, one thing per page, check answers, branching logic, save and resume, progress indicators, onboarding flows, checkout steps
- [navigation-menus-and-sidebars](skills/navigation-menus-and-sidebars/Skill.md) (A) — Header navigation, mega menu, disclosure navigation, app sidebar, navigation rail, mobile nav, skip links, active state
- [number-and-currency-inputs](skills/number-and-currency-inputs/Skill.md) (A) — number field, spinbutton, stepper, currency input, percent input, unit input, Intl.NumberFormat, locale parsing, decimal precision, minor units, quantity selector
- [otp-and-auth-forms](skills/otp-and-auth-forms/Skill.md) (A) — sign-in form, sign-up form, password field, passkeys, WebAuthn, conditional UI, conditional create, OTP input, WebOTP, one-time-code, magic link, 2FA, password reset
- [pagination](skills/pagination/Skill.md) (A) — Numbered pagination, prev/next, load more, infinite scroll, cursor pagination, table pagination, URL state
- [popovers](skills/popovers/Skill.md) (A) — Overlays, Popover API, top layer, light dismiss, anchor positioning, non-modal dialog, hover card
- [react-hook-form-and-zod](skills/react-hook-form-and-zod/Skill.md) (A) — React Hook Form, Zod 4, @hookform/resolvers, Standard Schema, Controller, useFieldArray, Next.js Server Actions, useActionState, useFormStatus, shadcn/ui Field, form performance
- [resizable-panels](skills/resizable-panels/Skill.md) (B) — Split pane, window splitter, separator, collapsible panel, layout persistence, IDE layouts
- [rich-text-editors](skills/rich-text-editors/Skill.md) (A) — WYSIWYG editing, contenteditable, document schemas, toolbars and bubble menus, markdown shortcuts, slash commands, mentions, collaborative editing, HTML sanitization, SSR hydration
- [search-and-autocomplete](skills/search-and-autocomplete/Skill.md) (A) — Site search, typeahead, query suggestions, instant search, recent searches, debounce/abort, combobox (editable), search landmark
- [select-and-combobox](skills/select-and-combobox/Skill.md) (A) — Forms, native select, customizable select, combobox, listbox, typeahead, multi-select, ARIA 1.2, headless UI
- [sliders-and-range-inputs](skills/sliders-and-range-inputs/Skill.md) (A) — Range input, multi-thumb slider, price range filter, volume/brightness controls, stepped sliders, vertical sliders, value formatting, URL-synced filters
- [tabs](skills/tabs/Skill.md) (A) — Tablist, tabpanel, activation modes, navigation tabs, URL state, responsive tabs, overflow
- [tags-and-chips-input](skills/tags-and-chips-input/Skill.md) (B) — Token input, chip group, tag group, multi-value field, email recipients input, creatable multi-select, filter chips, removable chips
- [text-inputs-and-fields](skills/text-inputs-and-fields/Skill.md) (A) — text input, textarea, field anatomy, labels, hints, error messages, autocomplete, inputmode, enterkeyhint, password field, character count, prefix/suffix
- [toasts-and-notifications](skills/toasts-and-notifications/Skill.md) (A) — Toast, snackbar, inline alert, banner, notification center, live regions, undo, promise toasts
- [tooltips](skills/tooltips/Skill.md) (A) — Overlays, hint, icon button labels, hover/focus content, delay groups, touch
- [tree-views](skills/tree-views/Skill.md) (A) — Tree, treeitem, treegrid, file explorer, hierarchical selection, lazy loading, virtualized tree

## UI Libraries

_Engineering evaluation of React component ecosystems: shadcn/ui, Radix, Base UI, React Aria, MUI, Mantine, etc._

- [animated-component-collections](skills/animated-component-collections/Skill.md) (B) — shadcn registries, Magic UI, Aceternity UI, coss ui, Origin UI, Motion, reduced motion, marketing effects, licensing
- [ant-design](skills/ant-design/Skill.md) (A) — Enterprise UI, design tokens, ConfigProvider, CSS variables, semantic classNames/styles, Form, Table, Next.js registry, v5 to v6 migration, ProComponents
- [ariakit](skills/ariakit/Skill.md) (B) — Headless components, stores, composite widgets, virtual focus, combobox/select/menu, render prop, data attributes, CSS variables
- [ark-ui-and-park-ui](skills/ark-ui-and-park-ui/Skill.md) (B) — Headless components, Zag.js state machines, data-scope/data-part styling, asChild, Panda CSS recipes, Park UI, layer z-index stacking
- [base-ui](skills/base-ui/Skill.md) (A) — Headless components, render prop composition, useRender/mergeProps, Combobox, Drawer, Toast, NumberField, OTPField, Floating UI positioning
- [bootstrap-5](skills/bootstrap-5/Skill.md) (B) — Sass customization, CSS variables, color modes, grid and utilities, React-Bootstrap, Popper, Next.js integration, Bootstrap 6 preview
- [chakra-ui](skills/chakra-ui/Skill.md) (A) — Style props, tokens/semantic tokens, recipes, slot recipes, createSystem, Ark UI, snippets CLI, color mode with next-themes, v2 to v3 migration
- [fluent-ui-and-enterprise-systems](skills/fluent-ui-and-enterprise-systems/Skill.md) (B) — Fluent UI v9, Griffel, Carbon React, Sass tokens, Spectrum 2, Polaris web components, Atlassian Design System, platform-extension UIs, licensing
- [headless-ui](skills/headless-ui/Skill.md) (B) — Headless components, Tailwind Labs, Catalyst, anchor positioning, data-attribute transitions, form fields, virtualization in Combobox
- [heroui](skills/heroui/Skill.md) (B) — React Aria Components, Tailwind v4, tailwind-variants, compound components, CSS variable theming, OKLCH, v2 to v3 migration, MCP server, agent skills
- [mantine](skills/mantine/Skill.md) (A) — Styled components, hooks library, CSS variables theming, Styles API, @mantine/form, @mantine/dates, @mantine/charts, Spotlight, MCP server
- [material-ui](skills/material-ui/Skill.md) (A) — Material Design, theme/createTheme, CSS variables, sx prop, styled(), slots/slotProps, Emotion, Next.js integration, MUI X (Data Grid, Date Pickers, Charts), codemods
- [primereact-and-primevue](skills/primereact-and-primevue/Skill.md) (B) — Enterprise components, DataTable, design tokens, theme presets (Aura, Material, Lara, Nora), pass-through props, unstyled/Tailwind mode, headless hooks, v10 to v11 migration
- [radix-ui-primitives](skills/radix-ui-primitives/Skill.md) (A) — Headless components, asChild/Slot composition, data-state styling, portals, dismissable layers, focus scopes, React 19 compatibility
- [react-aria-and-spectrum](skills/react-aria-and-spectrum/Skill.md) (A) — Headless components, hooks, i18n (dates, numbers, calendars, RTL), collections API, drag and drop, render props, data attributes, Spectrum 2 style macro
- [shadcn-ui](skills/shadcn-ui/Skill.md) (S) — Open-code components, shadcn CLI, registries, components.json, presets, Base UI / Radix / React Aria bases, Tailwind v4 theming, MCP, agent skills
- [small-ui-primitives-vaul-sonner-cmdk](skills/small-ui-primitives-vaul-sonner-cmdk/Skill.md) (A) — Toasts, command palette, drawers/bottom sheets, maintenance risk, shadcn integrations, Base UI Drawer/Toast replacements
- [tailwind-component-kits](skills/tailwind-component-kits/Skill.md) (B) — daisyUI themes, Flowbite React, Preline plugins, Tailwind Plus/Catalyst, CSS-only components, Tailwind v4 plugins, theming via data-theme
- [tremor](skills/tremor/Skill.md) (B) — Dashboards, charts (Recharts), KPI cards, copy-paste components, Tailwind theming, Vercel/v0, blocks and templates
- [ui-library-selection-guide](skills/ui-library-selection-guide/Skill.md) (A) — Library evaluation, headless vs styled, open-code vs package, styling runtime, RSC compatibility, licensing, maintenance risk, migration cost

## UX

_UX foundations: hierarchy, IA, flows, states (empty/loading/error), microcopy, heuristics, optimistic UI, auth UX, AI chat UX, ethics._

- [ai-chat-interface-ux](skills/ai-chat-interface-ux/Skill.md) (A) — chat UI, streaming, prompt input, suggestions, citations/references, reasoning display, tool calls, human-in-the-loop approval, feedback, trust calibration, AI disclosure, generative UI
- [authentication-ux](skills/authentication-ux/Skill.md) (S) — sign-in, sign-up, passkeys/WebAuthn, SSO, magic links, OTP, MFA, password reset, account recovery, session timeout, identifier-first login
- [conversion-ux](skills/conversion-ux/Skill.md) (A) — funnels, CTAs, signup conversion, trial-to-paid, checkout friction, trust signals, social proof, A/B testing, CRO, form optimization
- [destructive-actions-and-confirmation](skills/destructive-actions-and-confirmation/Skill.md) (A) — confirmation dialogs, undo, soft delete, type-to-confirm, danger zone, bulk delete, irreversible actions, alertdialog
- [empty-states](skills/empty-states/Skill.md) (A) — first-use states, zero results, cleared states, permission-empty, onboarding hooks, copy, illustrations, not-found
- [error-states](skills/error-states/Skill.md) (S) — validation errors, error summary, error boundaries, 404/500 pages, offline states, partial failures, retry, error copy
- [ethical-design-and-dark-patterns](skills/ethical-design-and-dark-patterns/Skill.md) (A) — deceptive patterns, consent UX, cookie banners, subscription cancellation, pricing transparency, confirmshaming, addictive design, AI-generated dark patterns, regulatory compliance
- [iconography-and-illustration](skills/iconography-and-illustration/Skill.md) (A) — icon sets, icon buttons, SVG accessibility, icon sizing, status icons, illustrations, spot illustrations, icon licensing, sprite sheets
- [information-architecture](skills/information-architecture/Skill.md) (A) — navigation structure, labeling, taxonomy, card sorting, tree testing, URL design, wayfinding, search, sitemaps
- [loading-states](skills/loading-states/Skill.md) (S) — skeleton screens, spinners, progress indicators, Suspense, streaming, pending states, perceived performance, response time limits
- [microcopy-ux-writing](skills/microcopy-ux-writing/Skill.md) (S) — button labels, form labels and hints, error messages, voice and tone, plain language, capitalization, terminology, inclusive language, i18n-ready copy
- [onboarding-ux](skills/onboarding-ux/Skill.md) (A) — first-run experience, activation, setup checklists, product tours, contextual help, personalization questions, sample data, re-onboarding
- [optimistic-ui](skills/optimistic-ui/Skill.md) (S) — useOptimistic, optimistic mutations, rollback, reconciliation, perceived performance, offline-first, idempotency
- [progressive-disclosure](skills/progressive-disclosure/Skill.md) (A) — staged disclosure, advanced settings, accordions, "show more", conditional fields, contextual reveal, layered help, complexity management
- [settings-and-preferences-ux](skills/settings-and-preferences-ux/Skill.md) (A) — account settings, workspace/admin settings, notification preferences, save models, defaults, settings search, theme/locale preferences, privacy controls
- [ui-design-principles-for-engineers](skills/ui-design-principles-for-engineers/Skill.md) (A) — visual design, design systems thinking, Gestalt principles, Laws of UX, spacing scales, typography basics, color usage, polish
- [ui-inspiration-and-reference-sources](skills/ui-inspiration-and-reference-sources/Skill.md) (B) — pattern libraries, design system galleries, app screenshot libraries, flow recordings, award sites, Figma Community, component galleries, licensing, moodboards, competitive analysis
- [usability-heuristics](skills/usability-heuristics/Skill.md) (S) — heuristic evaluation, UX review, severity rating, Laws of UX, cognitive load, error prevention, UI audit checklist
- [user-flow-design](skills/user-flow-design/Skill.md) (A) — task flows, user journeys, flow diagrams, state machines, edge cases, interruption recovery, deep linking, step reduction
- [visual-hierarchy-and-layout](skills/visual-hierarchy-and-layout/Skill.md) (A) — visual hierarchy, scanning patterns, Gestalt, grids, whitespace, density, page layout archetypes, alignment

## Product Patterns

_Patterns per product type: landing pages, SaaS, ecommerce, checkout, marketplaces, docs, dev tools, fintech, healthcare, mobile web/PWA, SEO, payments, email._

- [checkout-flow-design](skills/checkout-flow-design/Skill.md) (S) — Guest checkout, form field reduction, address autocomplete, shipping and delivery selection, payment methods, wallets, 3-D Secure/SCA, PCI DSS scope, order confirmation, subscription checkout
- [content-and-blog-sites](skills/content-and-blog-sites/Skill.md) (A) — MDX, headless CMS, article layout, reading typography, tags and categories, author pages, RSS, OG images, newsletters, scheduled publishing, draft preview
- [developer-tool-ui-patterns](skills/developer-tool-ui-patterns/Skill.md) (B) — Developer consoles, API keys and secrets, logs viewers, deployments, environment variables, webhooks management, usage and quotas, CLI parity, code display, keyboard shortcuts
- [documentation-site-patterns](skills/documentation-site-patterns/Skill.md) (A) — Diátaxis, docs information architecture, MDX, API reference, OpenAPI, versioning, docs search, code blocks, llms.txt, docs-as-code
- [ecommerce-ux-patterns](skills/ecommerce-ux-patterns/Skill.md) (A) — Product listing pages, faceted navigation, product detail pages, variants, reviews, cart, wishlists, order tracking, product structured data, headless commerce
- [fintech-ui-patterns](skills/fintech-ui-patterns/Skill.md) (A) — Money formatting, amount inputs, transaction history, transfers and payouts, KYC onboarding, strong customer authentication, step-up auth, disclosures, statements, fraud messaging, idempotency, session timeouts
- [healthcare-ui-patterns](skills/healthcare-ui-patterns/Skill.md) (A) — Patient portals, clinician UIs, SMART on FHIR, lab results display, medication lists, appointment scheduling, intake forms, telehealth, PHI privacy, consent, tracking technologies
- [landing-page-design](skills/landing-page-design/Skill.md) (A) — Conversion rate optimization, hero sections, social proof, lead capture, campaign pages, A/B testing, attribution/UTM, static rendering
- [marketing-website-architecture](skills/marketing-website-architecture/Skill.md) (A) — Information architecture, headless CMS, content modeling, page builders, static generation, redirects, localization, consent management, site/app boundary
- [marketplace-ux-patterns](skills/marketplace-ux-patterns/Skill.md) (B) — Two-sided marketplaces, listing search, trust and safety, reviews and reputation, in-platform messaging, seller onboarding, KYC for payouts, split payments, disputes, moderation
- [mobile-web-app-patterns](skills/mobile-web-app-patterns/Skill.md) (A) — Viewport units, safe areas, virtual keyboard, touch targets, bottom navigation, bottom sheets, history and back button, mobile forms, gestures, network resilience, iOS Safari quirks
- [pricing-page-patterns](skills/pricing-page-patterns/Skill.md) (A) — Plan tiers, feature comparison, monthly/annual toggle, usage-based pricing, seat pricing, calculators, enterprise plans, localized pricing, free trials, subscription disclosures
- [progressive-web-apps](skills/progressive-web-apps/Skill.md) (A) — Web App Manifest, installability, beforeinstallprompt, service workers, offline fallback, update flow, web push, iOS Home Screen web apps, display modes, app shortcuts, share target
- [saas-application-patterns](skills/saas-application-patterns/Skill.md) (A) — App shell, workspaces and tenancy, entitlements and plan gating, billing portal, team management, onboarding/activation, settings, notifications, command palette, product analytics
- [seo-for-frontend](skills/seo-for-frontend/Skill.md) (S) — Crawlability, JavaScript SEO, canonicalization, robots and noindex, sitemaps, metadata, Open Graph, structured data, hreflang, pagination, soft 404s, Core Web Vitals, AI search visibility
- [stripe-payments-in-nextjs](skills/stripe-payments-in-nextjs/Skill.md) (A) — Payments, Subscriptions, Webhooks, Route Handlers, Server Actions, Security, SaaS Billing
- [transactional-email-with-react-email](skills/transactional-email-with-react-email/Skill.md) (B) — Email, Server Actions, Notifications, Deliverability, Templates, Accessibility

## Accessibility

_WCAG 2.2, ARIA, semantics, keyboard, focus, screen readers, contrast, motion, tables, media, live regions, SPA routing, testing, legal._

- [accessibility-audit-process](skills/accessibility-audit-process/Skill.md) (A) — WCAG-EM, audit scoping, sampling, manual evaluation, severity rating, ACT Rules, issue reporting, remediation planning, retesting, ACR/VPAT, accessibility statement, Trusted Tester
- [accessibility-legal-compliance](skills/accessibility-legal-compliance/Skill.md) (A) — European Accessibility Act, EN 301 549, Web Accessibility Directive, ADA Title II, ADA Title III, Section 508, Section 504, UK PSBAR, AODA, Accessible Canada Act, VPAT/ACR, accessibility statements
- [accessible-data-tables](skills/accessible-data-tables/Skill.md) (A) — table semantics, caption, th scope, headers/id, aria-sort, row selection, responsive tables, scrollable regions, role=grid, TanStack Table, virtualization, aria-rowcount
- [accessible-forms](skills/accessible-forms/Skill.md) (S) — Labels, hints, fieldset/legend, required fields, autocomplete, error identification, error summary, aria-invalid, aria-describedby, Server Actions, React Hook Form
- [accessible-images-and-media](skills/accessible-images-and-media/Skill.md) (S) — Alt text, decorative images, SVG accessibility, icon accessibility, complex images, next/image, captions, subtitles, transcripts, audio description, video players, images of text
- [accessible-spa-routing](skills/accessible-spa-routing/Skill.md) (A) — Route change announcements, document title, focus on navigation, scroll restoration, loading states, intercepting route modals, back/forward, hash links, Next.js route announcer
- [aria-authoring-practices](skills/aria-authoring-practices/Skill.md) (S) — WAI-ARIA 1.2, ARIA 1.3, APG patterns, accessible name computation, roles, states and properties, composite widgets, roving tabindex, aria-activedescendant
- [automated-accessibility-testing](skills/automated-accessibility-testing/Skill.md) (S) — axe-core, @axe-core/playwright, vitest-axe, jest-axe, eslint-plugin-jsx-a11y, Storybook addon-a11y, Lighthouse CI, pa11y-ci, ARIA snapshots, CI gating, baselines
- [cognitive-accessibility](skills/cognitive-accessibility/Skill.md) (A) — COGA, plain language, memory load, attention and distraction, consistent help, redundant entry, accessible authentication, timeouts, error prevention, undo, progress indicators, readable typography
- [color-contrast-and-non-color-cues](skills/color-contrast-and-non-color-cues/Skill.md) (S) — Contrast ratio, large text, non-text contrast, focus indicator contrast, use of color, links in text, dark mode contrast, APCA, prefers-contrast, token validation
- [focus-management](skills/focus-management/Skill.md) (A) — Focus restoration, focus trapping, inert, dialog/popover focus, focus after deletion, error focus, focus indicators, focus-visible, scroll-padding
- [forced-colors-and-high-contrast](skills/forced-colors-and-high-contrast/Skill.md) (A) — forced-colors, Windows Contrast Themes, prefers-contrast, CSS system colors, forced-color-adjust, SVG currentColor, focus indicators, Tailwind forced-colors variant
- [keyboard-navigation](skills/keyboard-navigation/Skill.md) (A) — Tab order, tabindex, roving tabindex, aria-activedescendant, keyboard shortcuts, skip links, focus visible, keyboard traps, focusgroup
- [landmarks-and-accessible-navigation](skills/landmarks-and-accessible-navigation/Skill.md) (S) — Landmark regions, skip links, bypass blocks, nav labelling, aria-current, disclosure navigation, breadcrumbs, consistent navigation, page titles
- [live-regions-and-announcements](skills/live-regions-and-announcements/Skill.md) (A) — aria-live, role=status, role=alert, role=log, aria-atomic, aria-busy, ariaNotify, announcer, toasts, loading states, search results, chat streaming
- [reduced-motion-and-vestibular-safety](skills/reduced-motion-and-vestibular-safety/Skill.md) (A) — prefers-reduced-motion, vestibular disorders, parallax, auto-playing content, carousels, flashing and seizures, View Transitions, Motion for React, pause controls
- [reflow-zoom-and-text-spacing](skills/reflow-zoom-and-text-spacing/Skill.md) (A) — Browser zoom, reflow at 320 CSS px, resize text 200%, text spacing overrides, hover/focus content, relative units, viewport meta, sticky headers, Tailwind v4 sizing
- [screen-reader-testing](skills/screen-reader-testing/Skill.md) (A) — NVDA, JAWS, VoiceOver, TalkBack, Narrator, browse vs focus mode, rotor, test scripts, AT/browser pairings, speech viewer
- [semantic-html](skills/semantic-html/Skill.md) (S) — Document outline, headings, lists, buttons vs links, native form controls, dialog/popover, inert, invoker commands, HTML-AAM, polymorphic components
- [touch-and-pointer-accessibility](skills/touch-and-pointer-accessibility/Skill.md) (A) — Target size, pointer gestures, dragging movements, pointer cancellation, label in name, voice control, motion actuation, hover, pinch zoom, pointer media queries, switch access
- [wcag-2-2-compliance](skills/wcag-2-2-compliance/Skill.md) (S) — WCAG 2.2, success criteria, conformance, POUR, Understanding documents, conformance testing, WCAG 3 roadmap

## Performance

_Core Web Vitals (LCP/INP/CLS), bundles, splitting, images, fonts, hydration, rendering, memory, network, caching, offline, profiling, RUM._

- [back-forward-cache](skills/back-forward-cache/Skill.md) (A) — bfcache eligibility, pagehide/pageshow, unload deprecation, Cache-Control no-store, notRestoredReasons API, WebSocket/WebRTC blockers, stale state on restore, Next.js and SPA interaction
- [bundle-optimization](skills/bundle-optimization/Skill.md) (A) — Bundle analysis, tree-shaking, barrel files, dependency auditing, RSC client boundary, RSC payload, Vite 8/Rolldown, Turbopack, size-limit, modern build targets
- [cls-prevention](skills/cls-prevention/Skill.md) (S) — Layout Instability API, aspect-ratio, reserved space, font metric overrides, ads and embeds, skeletons, bfcache, animations
- [code-splitting-and-lazy-loading](skills/code-splitting-and-lazy-loading/Skill.md) (A) — Route-based splitting, component-level splitting, import-on-interaction, import-on-visibility, prefetching, Suspense boundaries, native lazy loading, chunk strategy
- [core-web-vitals](skills/core-web-vitals/Skill.md) (S) — Web Vitals, field data, CrUX, lab vs field, INP, LCP, CLS, soft navigations, supporting metrics (TTFB, FCP, TBT)
- [font-loading-performance](skills/font-loading-performance/Skill.md) (A) — font-display, WOFF2, subsetting, unicode-range, variable fonts, preload, size-adjust and metric overrides, next/font, Fontsource, icon fonts
- [http-caching-and-cdn](skills/http-caching-and-cdn/Skill.md) (A) — Cache-Control directives, validators (ETag/Last-Modified), stale-while-revalidate, CDN-Cache-Control, Vary, cache keys, purging, immutable assets, edge caching of HTML, Next.js cache headers
- [hydration-strategies](skills/hydration-strategies/Skill.md) (A) — React Server Components, selective hydration, streaming SSR, Suspense, client boundaries, lazy hydration, hydration mismatches, Partial Prerendering, Activity
- [image-optimization](skills/image-optimization/Skill.md) (A) — AVIF, WebP, JPEG XL, srcset/sizes, next/image, image CDNs, lazy loading, fetchPriority, placeholders, SVG, caching
- [inp-optimization](skills/inp-optimization/Skill.md) (S) — Long tasks, Long Animation Frames (LoAF), scheduler.yield, event handlers, main-thread scheduling, framework re-renders, layout thrashing, TBT
- [javascript-memory-leaks](skills/javascript-memory-leaks/Skill.md) (A) — Heap snapshots, detached DOM, effect cleanup, event listeners, timers, subscriptions, closures, caches, AbortController, WeakMap/WeakRef, server-side leaks, MemLab
- [lcp-optimization](skills/lcp-optimization/Skill.md) (S) — LCP subparts, fetchpriority, preload, TTFB, render-blocking resources, hero images, SSR, image CDN
- [low-end-device-performance](skills/low-end-device-performance/Skill.md) (A) — Device-class budgets, CPU/network throttling, adaptive loading, Save-Data, Device Memory, Network Information API, client hints, hydration cost, INP on slow CPUs, real-device testing, RUM segmentation
- [performance-budgets-and-rum](skills/performance-budgets-and-rum/Skill.md) (A) — Performance budgets, milestone/quantity/rule budgets, RUM, web-vitals, CrUX API, Vercel Speed Insights, segmentation, alerting, SLOs, size-limit, Lighthouse CI assertions, release tracking
- [performance-profiling-devtools](skills/performance-profiling-devtools/Skill.md) (S) — Performance panel, Insights, live metrics, CPU/network throttling, flame charts, React Profiler, React performance tracks, User Timing, extensibility API, Lighthouse, Chrome DevTools MCP, production profiling
- [rendering-performance](skills/rendering-performance/Skill.md) (A) — Pixel pipeline, layout thrashing, forced reflow, style recalculation, DOM size, CSS containment, content-visibility, compositing, scroll performance, virtualization, frame budget
- [resource-hints-and-network-optimization](skills/resource-hints-and-network-optimization/Skill.md) (A) — preconnect, dns-prefetch, preload, modulepreload, prefetch, fetchpriority, 103 Early Hints, HTTP/2, HTTP/3, Brotli, Zstandard, Compression Dictionary Transport, request waterfalls, React 19 resource APIs
- [service-workers-and-offline](skills/service-workers-and-offline/Skill.md) (B) — Service worker lifecycle, caching strategies, precaching, runtime caching, navigation preload, offline fallback, update flow, Workbox, Serwist, Static Routing API, Background Sync
- [speculation-rules-and-prerendering](skills/speculation-rules-and-prerendering/Skill.md) (A) — Speculation Rules API, prefetch, prerender, eagerness, document rules, list rules, Speculation-Rules header, prerender_until_script, document.prerendering, activationStart, Sec-Purpose, multi-zone navigation
- [third-party-script-management](skills/third-party-script-management/Skill.md) (A) — Tag managers, next/script strategies, @next/third-parties, facades, consent-gated loading, Partytown, server-side tagging, LoAF attribution, CSP/SRI, embeds, A/B testing scripts
- [web-workers-offloading](skills/web-workers-offloading/Skill.md) (A) — Dedicated workers, module workers, Comlink, transferables, structured clone, OffscreenCanvas, SharedArrayBuffer and cross-origin isolation, WASM, worker pools, React hooks for workers

## Animation

_Motion for React, GSAP, CSS animation, View Transitions, scroll-driven animation, micro-interactions, layout animation, 3D._

- [3d-web-three-and-r3f](skills/3d-web-three-and-r3f/Skill.md) (B) — WebGL, WebGPU, React Three Fiber, drei, 3D product viewers, hero scenes, shaders, GLTF models, performance scaling, postprocessing
- [animation-performance](skills/animation-performance/Skill.md) (A) — Rendering pipeline, compositor properties, layer management, main-thread contention, React re-renders, INP/CLS interactions, profiling, battery and low-end devices
- [css-animations-and-transitions](skills/css-animations-and-transitions/Skill.md) (A) — Transitions, keyframes, easing functions, entry/exit animation, popover/dialog animation, discrete properties, custom properties (@property)
- [gsap-animation](skills/gsap-animation/Skill.md) (A) — Timelines, scroll-triggered animation, ScrollTrigger pinning/scrub, SVG animation, text splitting, FLIP, React/Next.js integration
- [layout-animations](skills/layout-animations/Skill.md) (A) — FLIP, shared element transitions, list reorder, expand/collapse, height auto animation, tab indicators, grid/list view switch
- [lottie-and-rive](skills/lottie-and-rive/Skill.md) (B) — Vector animation, After Effects export, dotLottie, state machines, interactive illustrations, animated icons, onboarding animation, data binding
- [micro-interactions](skills/micro-interactions/Skill.md) (A) — Press feedback, hover states, toggles, copy confirmation, loading buttons, form validation feedback, tooltips, number/tick animations, haptic-like cues
- [motion-design-principles](skills/motion-design-principles/Skill.md) (A) — Easing, duration, choreography, springs, motion tokens, spatial models, purpose of motion, brand expressiveness, Disney principles for UI
- [motion-for-react](skills/motion-for-react/Skill.md) (A) — React animation, exit animations, gestures, spring physics, scroll-linked animation, layout animation, bundle optimization
- [scroll-driven-animations](skills/scroll-driven-animations/Skill.md) (A) — Scroll progress timelines, view progress timelines, animation-range, reveal-on-scroll, parallax, scroll-triggered animations, ScrollTimeline JS API
- [view-transitions-api](skills/view-transitions-api/Skill.md) (S) — Route transitions, shared element transitions, Suspense reveal animation, directional navigation, list reorder, React ViewTransition, Next.js navigation
- [web-animations-api](skills/web-animations-api/Skill.md) (A) — Imperative animation, Animation objects, promises, commitStyles, getAnimations, composite modes, scroll timelines, pseudo-element animation

## Data Visualization

_Visualization principles, chart selection, D3/Recharts/Chart.js/ECharts/Nivo/visx, dashboards, realtime, maps, accessible charts, large datasets._

- [accessible-data-visualization](skills/accessible-data-visualization/Skill.md) (A) — text alternatives, data tables, keyboard navigation, screen readers, color-vision deficiency, contrast, reduced motion, forced colors, sonification, Chartability audits
- [chart-type-selection](skills/chart-type-selection/Skill.md) (A) — visual vocabulary, chart taxonomy, form selection, small multiples, tables vs charts
- [chartjs](skills/chartjs/Skill.md) (A) — canvas charts, react-chartjs-2, plugins, decimation, tree-shaking, OffscreenCanvas, Next.js client components
- [d3-fundamentals](skills/d3-fundamentals/Skill.md) (A) — d3-scale, d3-shape, d3-array, d3-hierarchy, d3-force, d3-geo, d3-zoom, d3-brush, data join, Observable Plot
- [dashboard-design](skills/dashboard-design/Skill.md) (A) — operational dashboards, analytical dashboards, KPI rows, filter bars, drill-down, data freshness, dashboard layout, Next.js streaming dashboards
- [data-visualization-principles](skills/data-visualization-principles/Skill.md) (A) — visual encoding, perception, color for data, annotation, chart integrity, storytelling
- [echarts](skills/echarts/Skill.md) (A) — canvas/SVG charts, echarts-for-react, option API, dataset, dataZoom, visualMap, geo, SSR SVG, ECharts 6 migration
- [kpi-and-stat-components](skills/kpi-and-stat-components/Skill.md) (A) — stat tile, KPI row, delta badge, sparkline, bullet chart, meter/progress, hero number, number formatting, Tremor/shadcn stat cards
- [large-dataset-visualization-performance](skills/large-dataset-visualization-performance/Skill.md) (A) — SVG vs Canvas vs WebGL, downsampling, LTTB, binning, Apache Arrow, typed arrays, Web Workers, OffscreenCanvas, deck.gl, uPlot, hit-testing
- [maps-and-geospatial-ui](skills/maps-and-geospatial-ui/Skill.md) (B) — MapLibre GL JS, react-map-gl, Leaflet, react-leaflet, Mapbox licensing, deck.gl, vector tiles, PMTiles, choropleth, clustering, geocoding UI
- [nivo-and-visx](skills/nivo-and-visx/Skill.md) (B) — React charts, d3 primitives, custom chart libraries, canvas variants, react-spring, SSR charts
- [realtime-data-ui](skills/realtime-data-ui/Skill.md) (A) — WebSockets, SSE/EventSource, polling, backpressure, throttling, ring buffers, useSyncExternalStore, live charts, connection status, Next.js route handlers
- [recharts](skills/recharts/Skill.md) (A) — React charts, SVG charts, Recharts 3 migration, shadcn/ui charts, tooltips, responsive containers

## Enterprise UI

_Admin panels, data grids/tables, filtering, bulk actions, RBAC UI, audit logs, workflows, ERP/CRM/WMS, multi-tenant, power-user UI, collaboration._

- [admin-panel-architecture](skills/admin-panel-architecture/Skill.md) (A) — App shell, resource routing, CRUD, Server Components, Server Actions, Data Access Layer, URL state, list/detail/edit floorplans
- [advanced-filtering-ui](skills/advanced-filtering-ui/Skill.md) (A) — Filter bar, filter builder, filtered search tokens, saved views, operators, relative dates, URL-serialized filters, server-side filter compilation
- [audit-log-interfaces](skills/audit-log-interfaces/Skill.md) (B) — Audit trails, activity history, change diffs, compliance export, event schema, impersonation logging, retention
- [bulk-actions](skills/bulk-actions/Skill.md) (A) — Row selection, select all across pages, batch action bar, bulk edit, bulk delete, background jobs, progress, partial failures, undo
- [crm-ui-patterns](skills/crm-ui-patterns/Skill.md) (B) — Record pages, highlights panel, related lists, activity timeline, stage path, pipeline kanban, list views, inline edit, duplicate management, global search, ownership and territories
- [data-grids-ag-grid](skills/data-grids-ag-grid/Skill.md) (A) — AG Grid, MUI X Data Grid, Glide Data Grid, server-side row model, inline editing, grid theming, licensing, grid accessibility
- [data-import-export-ui](skills/data-import-export-ui/Skill.md) (A) — CSV import, Excel import, column mapping, validation, bulk upsert, background jobs, export, CSV injection
- [dense-form-screens](skills/dense-form-screens/Skill.md) (B) — Form layout, sections and fieldsets, multi-column grids, read/edit mode, dirty state and navigation guards, autosave, server validation, React Hook Form + Zod, density, keyboard shortcuts, performance
- [enterprise-data-tables](skills/enterprise-data-tables/Skill.md) (A) — Data tables, server-side pagination, sorting, column visibility, density, row actions, URL state, TanStack Table, table API contracts
- [erp-ui-patterns](skills/erp-ui-patterns/Skill.md) (B) — Floorplans (list report, worklist, object page, flexible column layout), business documents, line items, currency and units, fiscal periods, draft handling and locking, variant management (saved views)
- [kanban-boards](skills/kanban-boards/Skill.md) (A) — drag and drop, sortable lists, dnd-kit, fractional indexing, optimistic UI, WIP limits, swimlanes, workflow states
- [keyboard-power-user-ui](skills/keyboard-power-user-ui/Skill.md) (A) — keyboard shortcuts, hotkeys, command palette, roving tabindex, list navigation, accessibility, productivity
- [master-detail-layouts](skills/master-detail-layouts/Skill.md) (B) — Split view, list-detail, side panel, object page, flexible column layout, parallel routes, intercepting routes, record navigation, inspector panels
- [multi-tenant-ui](skills/multi-tenant-ui/Skill.md) (B) — Tenant resolution, organization switcher, workspace scoping, tenant branding, cache isolation, invitations, cross-tenant admin (support/impersonation)
- [realtime-collaboration-ui](skills/realtime-collaboration-ui/Skill.md) (B) — presence, live cursors, CRDT, Yjs, Liveblocks, PartyKit, conflict resolution, optimistic concurrency, comments, offline
- [refine-and-react-admin-frameworks](skills/refine-and-react-admin-frameworks/Skill.md) (A) — Admin frameworks, data providers, auth providers, access control providers, CRUD scaffolding, Next.js integration
- [report-builder-ui](skills/report-builder-ui/Skill.md) (B) — Ad-hoc reporting, saved reports, column picker, group-by, aggregations, filter builder, pivot, scheduled reports, export, report sharing, semantic layer
- [resource-scheduling-and-timeline-views](skills/resource-scheduling-and-timeline-views/Skill.md) (B) — resource timeline, scheduler, Gantt, booking, dispatch board, shift planning, capacity, time zones, virtualization, drag to reschedule
- [responsive-dashboard-layouts](skills/responsive-dashboard-layouts/Skill.md) (B) — app shell, sidebar, CSS grid, container queries, widget grid, drag-to-arrange, streaming, parallel routes, layout persistence
- [role-based-ui-and-permissions](skills/role-based-ui-and-permissions/Skill.md) (A) — RBAC, ABAC, ReBAC, CASL, OpenFGA, Permit.io, permission-aware navigation, field-level permissions, disabled vs hidden actions
- [wms-and-logistics-ui-patterns](skills/wms-and-logistics-ui-patterns/Skill.md) (C) — Barcode scanning, task-directed work, handheld/rugged device UX, offline queues, shipment tracking, dock scheduling, exception management, labels and printing
- [workflow-and-approval-ui](skills/workflow-and-approval-ui/Skill.md) (B) — State machines, approval inbox / worklist, multi-level approvals, delegation, SLA and escalation, comments and audit trail, optimistic concurrency, idempotent mutations

## Testing & QA

_Testing strategy, Vitest/Jest, Testing Library, Playwright/Cypress, visual regression, Storybook, MSW, Lighthouse CI, CI/CD, flake management._

- [api-mocking-msw](skills/api-mocking-msw/Skill.md) (A) — Network mocking, request handlers, setupServer, setupWorker, GraphQL mocking, Storybook MSW addon, Next.js server-side mocking, contract drift
- [component-testing](skills/component-testing/Skill.md) (A) — Integration component tests, jsdom vs real browser, Storybook interaction tests, provider wrappers, Next.js module mocking, form testing, data-fetching components
- [cross-browser-and-device-testing](skills/cross-browser-and-device-testing/Skill.md) (B) — Browser support matrix, Playwright projects, device emulation, real device clouds, BrowserStack, Sauce Labs, iOS Safari quirks, Browserslist, progressive enhancement checks
- [cypress-e2e-testing](skills/cypress-e2e-testing/Skill.md) (B) — Cypress E2E, Cypress component testing, cy.intercept, cy.session, custom commands, Cypress Cloud, framework selection
- [flaky-test-management](skills/flaky-test-management/Skill.md) (A) — Flake detection, root cause analysis, quarantine, retries policy, test isolation, deterministic time and data, Playwright trace debugging, CI reliability metrics
- [frontend-ci-cd-pipelines](skills/frontend-ci-cd-pipelines/Skill.md) (A) — GitHub Actions, caching, sharding, artifacts, required status checks, preview deployments, monorepo affected builds, secrets, supply chain hardening
- [frontend-testing-strategy](skills/frontend-testing-strategy/Skill.md) (A) — Testing Trophy, test pyramid, test layering, risk-based testing, test ownership, CI gating, React Server Components testing boundaries
- [jest-testing](skills/jest-testing/Skill.md) (A) — Jest configuration, next/jest, jsdom environment, module mocking, snapshot testing, Jest-to-Vitest migration
- [lighthouse-ci](skills/lighthouse-ci/Skill.md) (A) — Lab performance testing, performance budgets, Lighthouse assertions, LHCI server, GitHub status checks, performance regression testing
- [playwright-e2e-testing](skills/playwright-e2e-testing/Skill.md) (S) — E2E testing, locators, fixtures, auth storage state, network mocking, trace viewer, ARIA snapshots, test agents, Playwright MCP, sharding
- [storybook-component-workshop](skills/storybook-component-workshop/Skill.md) (A) — Storybook setup, CSF stories, args and decorators, play functions, Vitest addon, a11y addon, MSW addon, module mocking, docs, visual testing integration
- [test-coverage-and-mutation-testing](skills/test-coverage-and-mutation-testing/Skill.md) (B) — Code coverage, V8 vs Istanbul, coverage thresholds, diff/patch coverage, E2E coverage, mutation testing, StrykerJS, test effectiveness metrics
- [test-data-and-fixtures](skills/test-data-and-fixtures/Skill.md) (B) — Factories and builders, faker seeding, JSON fixtures, MSW data, Playwright fixtures, database seeding, data isolation, auth states, cleanup, snapshotting data
- [testing-library-principles](skills/testing-library-principles/Skill.md) (S) — Queries, query priority, user-event, async utilities, jest-dom matchers, accessibility-first selectors, test readability
- [testing-server-components-and-actions](skills/testing-server-components-and-actions/Skill.md) (A) — React Server Components, Server Actions, Route Handlers, proxy/middleware testing, next/headers and next/cache mocking, server-side fetch mocking, Next.js experimental test mode
- [visual-regression-testing](skills/visual-regression-testing/Skill.md) (A) — Screenshot testing, baseline management, Chromatic, Argos, Percy, Playwright toHaveScreenshot, Vitest toMatchScreenshot, determinism, review workflow
- [vitest-unit-testing](skills/vitest-unit-testing/Skill.md) (A) — Unit testing, mocking, fake timers, test environments, Vitest Browser Mode, coverage, Vitest projects

## AI Agent Workflows

_Agent skills/rules authoring (Claude Code, Cursor, Copilot, AGENTS.md), design-to-code, browser-MCP loops, AI a11y audits, debugging, review, verification._

- [agent-skills-authoring](skills/agent-skills-authoring/Skill.md) (A) — SKILL.md format, progressive disclosure, prompt engineering for agents, Claude Code skills, skill evaluation, skill distribution/plugins, design-system skills
- [agents-md-conventions](skills/agents-md-conventions/Skill.md) (A) — AGENTS.md spec, monorepo nesting, cross-tool interop, CLAUDE.md/GEMINI.md bridging, Next.js bundled docs, instruction hygiene
- [ai-accessibility-audit-workflow](skills/ai-accessibility-audit-workflow/Skill.md) (A) — WCAG 2.2 AA, axe-core, eslint-plugin-jsx-a11y, Lighthouse, accessibility tree, keyboard testing, remediation, audit reporting
- [ai-frontend-code-review](skills/ai-frontend-code-review/Skill.md) (A) — Code review, reviewer subagents, Copilot code review, Web Interface Guidelines, React performance review, composition review, Next.js security review, accessibility review, severity triage
- [ai-frontend-debugging-workflow](skills/ai-frontend-debugging-workflow/Skill.md) (A) — Next.js runtime errors, hydration mismatch, server/client boundaries, Cache Components, build errors, console and network inspection, regression tests, root-cause analysis
- [ai-ui-generation-tools](skills/ai-ui-generation-tools/Skill.md) (B) — v0, shadcn registry, Claude artifacts, prototyping, code integration, design systems, generated-code hardening
- [browser-automation-agent-workflow](skills/browser-automation-agent-workflow/Skill.md) (A) — Playwright MCP, Chrome DevTools MCP, agent-browser, accessibility snapshots, dev-server reuse, exploratory testing, E2E test generation, browser session security
- [claude-code-frontend-workflow](skills/claude-code-frontend-workflow/Skill.md) (A) — CLAUDE.md, .claude/rules, hooks, subagents, skills, plan mode, permissions, MCP, plugins, headless mode, verification
- [coding-agent-security-for-frontend](skills/coding-agent-security-for-frontend/Skill.md) (A) — prompt injection, MCP security, permissions, sandboxing, secrets management, supply chain, browser automation safety, hooks
- [cursor-rules-for-frontend](skills/cursor-rules-for-frontend/Skill.md) (A) — Cursor, project rules, .mdc, AGENTS.md, context engineering, Next.js App Router conventions, Tailwind/shadcn conventions, rule hygiene
- [design-to-code-figma-workflow](skills/design-to-code-figma-workflow/Skill.md) (A) — Figma MCP, design tokens, Tailwind v4 @theme, shadcn/ui mapping, Code Connect, visual verification
- [distinctive-frontend-design-for-agents](skills/distinctive-frontend-design-for-agents/Skill.md) (A) — Visual direction, typography, color, motion, backgrounds, design briefs, Tailwind v4 tokens, craft details, prompt design
- [frontend-agent-verification-loop](skills/frontend-agent-verification-loop/Skill.md) (A) — Definition of done, typecheck, lint, Vitest, next build, next-dev-loop, browser verification, axe, Playwright, Stop hooks, reviewer subagents, CI parity, evidence reporting
- [github-copilot-custom-instructions](skills/github-copilot-custom-instructions/Skill.md) (A) — GitHub Copilot, copilot-instructions.md, path-specific instructions, prompt files, custom agents, Copilot code review, Copilot cloud agent, VS Code customization
- [mcp-for-frontend-development](skills/mcp-for-frontend-development/Skill.md) (A) — Model Context Protocol, next-devtools-mcp, Playwright MCP, Chrome DevTools MCP, shadcn MCP, Figma MCP, agent-browser, MCP security, tool permissions
- [nextjs-agent-rules-baseline](skills/nextjs-agent-rules-baseline/Skill.md) (A) — agent instructions, rule sets, Next.js App Router, React 19, Server Components, caching, composition, Tailwind, shadcn/ui, rule hygiene
- [other-coding-agents-frontend-rules](skills/other-coding-agents-frontend-rules/Skill.md) (A) — Windsurf rules, Cline rules, Roo Code rules and modes, Gemini CLI context files, Aider conventions, Codex AGENTS.md, multi-agent repo setup, instruction file compatibility
- [screenshot-driven-ui-iteration](skills/screenshot-driven-ui-iteration/Skill.md) (A) — Visual verification, browser MCP, Playwright screenshots, responsive checks, visual regression, vision model limits

