# Gap Analysis

Scope: React + Next.js (TypeScript). Last updated: 2026-09-15.

This file records (1) weak or missing areas found after the first research pass, (2) the targeted gap-fill
passes run to close them, and (3) the verification backlog: facts that could not be confirmed against a
primary source during this cycle.

## Research Constraint This Cycle

The session's web-search budget ran out partway through the first pass. Most workstreams then verified
facts by fetching official documentation directly. Consequences:
- Official docs coverage is strong. The survey of community `.cursor/rules` / `SKILL.md` / `AGENTS.md` files is
  thinner for component, CSS, performance and animation topics than for AI-agent workflows.
- Version-specific details that couldn't be fetched are marked "Check current docs" / "verify" inside the skills.

## Targeted Gap-Fill Passes

| Pass | Gap addressed | Skills added |
|---|---|---|
| G1 | Next.js full-stack features with no dedicated skill: Draft Mode/CMS preview, `after()`, MDX, payments, transactional email | nextjs-draft-mode-and-cms-preview, nextjs-after-and-post-response-work, nextjs-mdx-content, stripe-payments-in-nextjs, transactional-email-with-react-email |
| G2 | Reflow/zoom/text spacing (WCAG 1.4.4/1.4.10/1.4.12), passkeys/WebAuthn, low-end device performance | reflow-zoom-and-text-spacing, passkeys-and-webauthn, low-end-device-performance |
| Workstream additions | Distinct topics found during research | react-19-migration-guide, nextjs-instant-navigation, nextjs-version-16-upgrade, web-animations-api, resizable-panels, back-forward-cache, forced-colors-and-high-contrast, accessibility-audit-process |
| Scope cleanup | Vue/Nuxt/Angular/Svelte/Solid/Astro/Qwik/Lit/htmx skills removed after scope change | 19 folders deleted; replaced by React/Next stack extensions (project setup, Vite SPA, nuqs, tRPC, database, AI SDK, progressive enhancement, modern JS, browser APIs, web components in React) |

## Remaining Gaps by Domain

### Frontend domains (weak or missing)
- **Background jobs / queues** (Inngest, Trigger.dev, QStash): only touched on in `nextjs-after-and-post-response-work`.
- **File storage uploads end-to-end** (S3/R2/Vercel Blob presigned uploads): UI is covered in `file-upload`, the storage pipeline is thin.
- **Booking/scheduling UIs** (slot holds, time zones), **social/community feeds**, **notification-permission & push UX**, **data-privacy & consent UX** (partly in `ethical-design-and-dark-patterns`).
- **Address & international phone inputs** (libphonenumber, address autocomplete): only phone basics in `text-inputs-and-fields`.
- **Component gaps:** steppers/progress indicators, avatars/badges/status indicators, table-of-contents/scrollspy, lightbox/image viewer.
- **CSS:** print stylesheets, scrollbar styling; `@function`/`if()`/typed `attr()` once Baseline.
- **Animation:** gesture/drag physics (swipe, momentum) beyond Motion drag; Material 3 Expressive motion.
- **Data viz:** network/graph visualization (react-flow, Sigma.js, Cytoscape), Gantt/timeline, commercial libraries (Highcharts, AG Charts).
- **Architecture:** Architecture Decision Records / fitness functions (embedded in `frontend-architecture-principles` only); experimentation statistics kept shallow.
- **UI libraries:** `shadcn-registry-authoring`, `mui-x-components` (licensing tiers) are candidate skills.

### Frameworks (underrepresented within scope)
- React Router framework mode and TanStack Router/Start are covered at tier B, as Vite-SPA alternatives. Kept as separate skills (not merged into `vite-react-spa`) because their data-loading models differ materially.
- React Native / Expo (React on mobile) is out of scope.
- `react-view-transitions-and-activity` (React `<ViewTransition>` + `<Activity>` patterns): partly covered by `view-transitions-api`.

### Enterprise scenarios
- Healthcare: FDA/IEC 62366 usability engineering and ONC certification UI requirements not covered in depth.
- Marketplaces: EU Digital Services Act trader traceability and notice-and-action UI not covered.
- **ERP floorplans:** SAP Fiori pages were blocked. List report, object page and worklist anatomy in `erp-ui-patterns` come from established knowledge and are flagged "verify".
- **Density specs:** Salesforce Lightning Design System, Fluent 2 and Carbon row-height/density pages couldn't be read. Numeric density values in `enterprise-data-tables` are practitioner defaults.
- **Warehouse/logistics UI** (`wms-and-logistics-ui-patterns`, tier C): no authoritative public design source exists for scanner-first warehouse UIs.
- **Unconfirmed APIs:** AG Grid Enterprise license-key call, refine pagination field name, some Liveblocks hook names.
- **Community admin-dashboard agent rules** weren't reviewed (search budget).
- **TanStack Table v9 (9.2.4)** is current and differs from v8. `tanstack-table` (React) and `enterprise-data-tables` should be re-checked together against the v9 docs.
- **Not covered:** notification/activity feeds; offline-capable field-worker apps.

### Accessibility
- Accessible PDFs/documents (PDF/UA) and accessible email: out of scope, but relevant for EAA/ADA Title II.
- Evolving APIs to re-verify within ~6 months: `ariaNotify`, `focusgroup`, `reading-flow`, cross-root ARIA (Reference Target), invoker commands (`command`/`commandfor`), `dialog closedby`.
- No first-hand screen reader test matrix (NVDA/JAWS/VoiceOver/TalkBack); guidance is documentation-based.
- Screen reader behavior during streamed AI responses lacks authoritative guidance.

### MCP categories
- **No verified MCP server found for:** design tokens (Style Dictionary / Tokens Studio), Drizzle ORM, Storyblok, Lokalise, official Crowdin or Strapi, a Builder.io CMS server, icon systems (Iconify/Lucide), image generation, a Deque axe accessibility server, Google Drive (official).
- **Archived or replaced servers this cycle:** Storybook MCP (now `@storybook/addon-mcp`), Penpot, Railway (moved into its CLI), PostHog, Sanity (now remote), Browserbase self-hosted. Asana MCP V1 shut down 2026-05-11; Atlassian v1 endpoints sunset after 2026-06-30.
- **Unverified:** Sourcegraph MCP (docs returned 403). About 10 repos' last-activity dates and star counts came from repo pages, not the GitHub API (rate-limited).
- **License to confirm:** Netlify MCP and Vercel `mcp-handler` show no license in GitHub metadata; next-devtools-mcp's MIT license is stated only in its README.
- **Not hands-on tested:** no MCP server was installed or run. Configs in `MCP_CATALOG.md` come from official READMEs.

### Testing capabilities
- None of the TSX examples have been compiled or type-checked. Highest-risk examples are flagged in the W07 manifest (React Aria FieldError with external errors, RHF register on custom Checkbox, ComboBox `selectedKey` vs `value`).
- **Async Server Components can't be unit-rendered.** Per Next.js docs, Vitest, Jest and Cypress component testing can't render `async` Server Components. Coverage relies on E2E plus unit tests of the extracted data and action functions (see `testing-server-components-and-actions`).
- **Server-side network mocking in App Router:** MSW can't reliably intercept server-side fetches in the Next.js App Router (mswjs/msw issue #1644 is open). Skills recommend an injected data layer or a test backend for E2E instead.
- **Not fetched this cycle:** Vitest coverage docs, StrykerJS with Vitest 5, Percy, LambdaTest. Details are marked "Check current docs".
- **Visual regression:** Lost Pixel was archived April 2026, which leaves Chromatic, Argos, Percy and Playwright `toHaveScreenshot` as options.
- **Not covered:** contract testing against OpenAPI/tRPC schemas beyond type-safety; load/performance regression testing in CI beyond Lighthouse CI.

### Performance
- Safari INP accuracy and RUM normalization; CrUX soft-navigation reporting.
- Next.js default `Cache-Control` headers per rendering mode should be confirmed empirically (`curl -I`) on Next 16 with Cache Components.
- Performance budget numbers are heuristics, not standards.
- Turbopack compatibility matrix for zero-runtime CSS-in-JS (vanilla-extract, StyleX, Panda, Linaria, next-yak) and for `new Worker(new URL())`.

### AI-agent workflows
- Community agent rules for architecture, CSS, performance, animation and charts were only lightly surveyed (search budget).
- **No hands-on validation:** none of the rule files, hooks or MCP configs in the AI-agent skills have been run in a real Next.js 16 repo. They are built from docs.
- **Unreadable community rules:** awesome-cursorrules and cursor.directory individual rule files couldn't be read (404/403/429). Their C/D ratings rest on repo structure and summaries.
- **AI UI generators:** v0, Lovable and Bolt prompting guidance is thin, so `ai-ui-generation-tools` is tier B.
- **Fast-moving tools:** Figma MCP tool names, rate limits and seat rules change often. Re-verify quarterly.
- **Accessibility MCP:** the Deque axe MCP server couldn't be verified. The AI accessibility workflow relies on `@axe-core/playwright` and the Chrome DevTools MCP Lighthouse audit instead.
- **Unverified config shapes:** private shadcn registry `headers` in `components.json`; `logging.browserToTerminal`.
- **Not covered:** eval harnesses that measure how well agents follow skills/rules (only the authoring checklist is covered).
- **Popularity signals:** star counts on community skill packs (e.g., ui-ux-pro-max) weren't independently checked for inflation; ratings are based on content, not stars.

## Verification Backlog (re-check against primary sources)

| Area | Item | Skill(s) |
|---|---|---|
| React | TanStack Table V9 render/subscribe signatures; React 19.3 `FragmentInstance` type; react-hooks ESLint preset key | tanstack-table, react-refs-and-imperative-apis, linting-and-formatting |
| Next.js | `cacheHandlers` interface; Partial Prefetching adoption guide; next-intl + `use cache`; `PageProps`/`LayoutProps` helpers; `serverActions.bodySizeLimit` location | nextjs-caching-and-revalidation, nextjs-instant-navigation, nextjs-internationalization, nextjs-app-router-fundamentals, form skills |
| Stack | AI SDK 7 tool-approval/throttle/`Output.object` names; nuqs throttle option name | nextjs-database-integration, vercel-ai-sdk-integration, react-url-state-nuqs |
| Tooling/Security | typescript-eslint support for TS 7; pnpm `allowBuilds` format; npm v12 install-script defaults; Auth.js v5 stability; Vite 8 option names | typescript-for-frontend, dependency-supply-chain-security, nextjs-authentication, frontend-build-tooling |
| UI libraries | HeroUI v3 component names; Tremor on Tailwind v4/React 19; PrimeReact v11 imports; React-Bootstrap React 19; Fluent UI v9 SSR in App Router; coss/Origin UI licenses | heroui, tremor, primereact-and-primevue, bootstrap-5, fluent-ui-and-enterprise-systems, animated-component-collections |
| CSS/Platform | Anchor positioning engine versions; name-only container queries Baseline; `text-box-trim`; `appearance: base-select` Safari/Firefox; `::details-content`, `interpolate-size` | modern-css-features, container-queries, floating-element-positioning, select-and-combobox, accordions-and-disclosure |
| Animation | Firefox scroll-driven animations and cross-document view transitions; R3F + WebGPU; dotLottie/Rive React APIs; GSAP license wording | scroll-driven-animations, view-transitions-api, 3d-web-three-and-r3f, lottie-and-rive, gsap-animation |
| Data viz | react-map-gl/react-leaflet React 19; echarts-for-react maintenance; Recharts 3.x hooks; MapLibre v6; ECharts large-data defaults | maps-and-geospatial-ui, echarts, recharts, large-dataset-visualization-performance |
| Components | dnd-kit roadmap; React Aria Tree role and Toast naming; react-resizable-panels v4 props; Embla v9 | drag-and-drop, tree-views, toasts-and-notifications, resizable-panels, carousels |
| Performance | Serwist/vite-plugin-pwa APIs + Turbopack; MemLab maintenance; `@next/third-parties` status; Early Hints support; Compression Dictionary Transport; font metric overrides in Safari | service-workers-and-offline, javascript-memory-leaks, third-party-script-management, resource-hints-and-network-optimization, font-loading-performance |
| Legal/Standards | ARIA 1.3 CR; EN 301 549 v4.1.1 in OJEU; HHS Section 504 dates; EU withdrawal button; FTC click-to-cancel; PSD3/PSR; iOS PWAs in the EU | accessibility-legal-compliance, ethical-design-and-dark-patterns, fintech-ui-patterns, progressive-web-apps |

## Verified During Final Audit

| Claim | Result |
|---|---|
| RFC 10017 "OAuth 2.0 for Browser-Based Applications" recommends a BFF, tokens kept off the browser | Confirmed (BCP 212, 2026) |
| TypeScript 7.0 released; `baseUrl`, `moduleResolution node/classic`, `target es5` deprecated in 6.0 and removed in 7.0 | Confirmed (TS 7.0 released 2026-07-08; TS 6.0 announcement) |
| npm v12 released | Confirmed (v12.0.2, 2026-07-29); install-script default changes not confirmed |
| `@module-federation/nextjs-mf` deprecated/EOL, App Router unsupported | Confirmed (module-federation/core issue #3153; package README says maintenance mode) |
| `next/image` `priority` deprecated in favor of `preload` | Confirmed (Next.js 16.3.5 Image docs: deprecated since v16.0.0; docs prefer `loading="eager"` or `fetchPriority="high"` in most cases). Skills swept for stale `priority` usage. |
| TanStack Start is Release Candidate, not 1.0 | Confirmed (tanstack.com/start overview: "currently in the Release Candidate stage") |
| SimpleWebAuthn `generateRegistrationOptions` `userID` must be bytes, not a string | Confirmed (source: `userID?: Uint8Array_`; strings throw). `passkeys-and-webauthn` passes `isoBase64URL.toBuffer(...)`, which is correct. The `@simplewebauthn/server/helpers` subpath export is confirmed in v14.0.2. |
| `next-mdx-remote` archived | Confirmed (hashicorp/next-mdx-remote is archived and unsupported; README points to `next-mdx-remote-client`, `mdx-bundler`, or core `@mdx-js/mdx` for RSC) |
| Drizzle ORM 1.0 not yet stable | Confirmed (latest release v1.0.0-rc.4 on GitHub releases) |
