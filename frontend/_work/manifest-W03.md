# Manifest — W03 (Next.js)

Scope: React + Next.js only (TypeScript). Current Next.js as of 2026-09-15: 16.3.x (docs 16.3.5; Active LTS 16.3.3+, Maintenance LTS 15.5.24+).

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| nextjs-app-router-fundamentals | Next.js App Router Fundamentals | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/getting-started/project-structure |
| nextjs-advanced-routing | Next.js Advanced Routing (Parallel & Intercepting Routes) | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes |
| nextjs-server-component-patterns | Next.js Server Component Patterns | Next.js | Next.js 16.3 / React 19.2 | A | Active | https://nextjs.org/docs/app/getting-started/server-and-client-components |
| nextjs-server-actions | Next.js Server Actions | Next.js | Next.js 16.3 / React 19.2 | S | Active | https://nextjs.org/docs/app/guides/server-actions |
| nextjs-caching-and-revalidation | Next.js Caching and Revalidation (Cache Components) | Next.js | Next.js 16.3 | S | Active | https://nextjs.org/docs/app/getting-started/caching |
| nextjs-rendering-strategies | Next.js Rendering Strategies | Next.js | Next.js 16.3 | S | Active | https://nextjs.org/docs/app/guides/rendering-philosophy |
| nextjs-middleware-proxy | Next.js Proxy (formerly Middleware) | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/api-reference/file-conventions/proxy |
| nextjs-metadata-and-seo | Next.js Metadata and SEO | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/getting-started/metadata-and-og-images |
| nextjs-image-and-font-optimization | Next.js Image and Font Optimization | Next.js | Next.js 16.3 | S | Active | https://nextjs.org/docs/app/api-reference/components/image |
| nextjs-authentication | Next.js Authentication and Authorization | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/guides/authentication |
| nextjs-deployment-and-self-hosting | Next.js Deployment and Self-Hosting | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/guides/self-hosting |
| nextjs-performance | Next.js Performance | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/guides/production-checklist |
| nextjs-data-fetching-patterns | Next.js Data Fetching Patterns | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/getting-started/fetching-data |
| nextjs-route-handlers | Next.js Route Handlers | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/getting-started/route-handlers |
| nextjs-streaming-and-loading-ui | Next.js Streaming and Loading UI | Next.js | Next.js 16.3 | S | Active | https://nextjs.org/docs/app/guides/streaming |
| nextjs-pages-to-app-router-migration | Migrating from Pages Router to App Router | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/guides/migrating/app-router-migration |
| nextjs-internationalization | Next.js Internationalization (i18n) | Next.js | Next.js 16.3 / next-intl 4 | A | Active | https://nextjs.org/docs/app/guides/internationalization |
| nextjs-env-and-config-security | Next.js Environment Variables and Config Security | Next.js | Next.js 16.3 | A | Active | https://nextjs.org/docs/app/guides/environment-variables |
| nextjs-instant-navigation (NEW) | Next.js Instant Navigation and Partial Prefetching | Next.js | Next.js 16.3 | A | Experimental | https://nextjs.org/docs/app/guides/instant-navigation |
| nextjs-version-16-upgrade (NEW) | Upgrading to Next.js 16 (and 16.x Minors) | Next.js | Next.js 16.0–16.3 | S | Active | https://nextjs.org/docs/app/guides/upgrading/version-16 |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Next.js Blog index | https://nextjs.org/blog | Official | Release timeline 15.3→16.3, security releases | Establishes current version | High | 2026-09-15 |
| Next.js 16 release | https://nextjs.org/blog/next-16 | Official | Cache Components, proxy, Turbopack default, breaking changes, deprecations | Baseline of current major | High | 2026-09-15 |
| Next.js 16.3 release | https://nextjs.org/blog/next-16-3 | Official | Instant Navigations, catchError, root params, import.meta.glob, TS7, SSR perf, Rust compiler, useOffline | Latest minor features | High | 2026-09-15 |
| Upgrading to v16 | https://nextjs.org/docs/app/guides/upgrading/version-16 | Official | Full breaking change checklist, codemods, agent prompt | Upgrade accuracy | High | 2026-09-15 |
| Caching (Cache Components) | https://nextjs.org/docs/app/getting-started/caching | Official | use cache model, runtime APIs, PPR, prefetching, storage | Core caching model | High | 2026-09-15 |
| Revalidating | https://nextjs.org/docs/app/getting-started/revalidating | Official | cacheLife profiles, updateTag vs revalidateTag | Invalidation semantics | High | 2026-09-15 |
| use cache reference | https://nextjs.org/docs/app/api-reference/directives/use-cache | Official | Keys, serialization, constraints, troubleshooting | Correctness pitfalls | High | 2026-09-15 |
| use cache: remote | https://nextjs.org/docs/app/api-reference/directives/use-cache-remote | Official | Directive comparison, key cardinality, nesting | Remote caching decisions | High | 2026-09-15 |
| use cache: private | https://nextjs.org/docs/app/api-reference/directives/use-cache-private | Official | Allowed APIs, stale thresholds | Per-user caching | High | 2026-09-15 |
| Caching (Previous Model) | https://nextjs.org/docs/app/guides/caching-without-cache-components | Deprecated (legacy model, still supported) | fetch cache options, segment config, unstable_cache | Legacy mapping | High | 2026-09-15 |
| Migrating to Cache Components | https://nextjs.org/docs/app/guides/migrating-to-cache-components | Official | API mapping, incremental adoption, UI state preservation | Migration | High | 2026-09-15 |
| proxy.js reference | https://nextjs.org/docs/app/api-reference/file-conventions/proxy | Official | API, matcher, execution order, runtime, testing | Proxy correctness | High | 2026-09-15 |
| Mutating Data | https://nextjs.org/docs/app/getting-started/mutating-data | Official | Server Functions creation/invocation | Actions basics | High | 2026-09-15 |
| Server Actions guide | https://nextjs.org/docs/app/guides/server-actions | Official | Single round trip, sequential dispatch, security, config, deploy | Actions depth | High | 2026-09-15 |
| Forms guide | https://nextjs.org/docs/app/guides/forms | Official | bind, validation, useFormStatus, useOptimistic | Form patterns | High | 2026-09-15 |
| Data Security guide | https://nextjs.org/docs/app/guides/data-security | Official | DAL, DTO, taint, IDOR, closures, allowedOrigins, audit | Security baseline | High | 2026-09-15 |
| Authentication guide | https://nextjs.org/docs/app/guides/authentication | Official | Sessions, DAL, proxy optimistic checks, library list | Auth | High | 2026-09-15 |
| Authentication with Cache Components | https://nextjs.org/docs/app/guides/authentication-with-cache-components | Official | Private cache sessions, user-keyed caches | Auth + caching | High | 2026-09-15 |
| Route Handlers | https://nextjs.org/docs/app/getting-started/route-handlers | Official | Conventions, caching modes, RouteContext | Endpoints | High | 2026-09-15 |
| Backend for Frontend guide | https://nextjs.org/docs/app/guides/backend-for-frontend | Official | Webhooks, callbacks, content negotiation, caveats | Endpoint patterns | High | 2026-09-15 |
| Parallel Routes | https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes | Official | Slots, default.js, modals, conditional caveat | Advanced routing | High | 2026-09-15 |
| Intercepting Routes | https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes | Official | Conventions | Advanced routing | High | 2026-09-15 |
| Project structure | https://nextjs.org/docs/app/getting-started/project-structure | Official | File conventions, groups, hierarchy | Fundamentals | High | 2026-09-15 |
| Server and Client Components | https://nextjs.org/docs/app/getting-started/server-and-client-components | Official | Boundaries, interleaving, providers, server-only | RSC patterns | High | 2026-09-15 |
| Fetching Data | https://nextjs.org/docs/app/getting-started/fetching-data | Official | Streaming, parallel/sequential, React.cache, preload | Data fetching | High | 2026-09-15 |
| Streaming guide | https://nextjs.org/docs/app/guides/streaming | Official | HTTP contract, bots, infra, web vitals | Streaming | High | 2026-09-15 |
| Error Handling | https://nextjs.org/docs/app/getting-started/error-handling | Official | error.js retry, catchError, global-error | Error boundaries | High | 2026-09-15 |
| Rendering Philosophy | https://nextjs.org/docs/app/guides/rendering-philosophy | Official | Component-level spectrum, fidelity | Rendering model | High | 2026-09-15 |
| ISR with Cache Components | https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components | Official | App Shell upgrade, Pages mapping | ISR | High | 2026-09-15 |
| Static Exports | https://nextjs.org/docs/app/guides/static-exports | Official | Supported/unsupported features | Export mode | High | 2026-09-15 |
| Instant navigation guide | https://nextjs.org/docs/app/guides/instant-navigation | Official (feature Experimental) | Validation, inspector, instant() tests | Instant nav | High | 2026-09-15 |
| instant segment config | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant | Experimental | Values, validationLevel | Instant nav config | High | 2026-09-15 |
| Route Segment Config | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | Official | Current options and removals under Cache Components | Config accuracy | High | 2026-09-15 |
| Linking and Navigating | https://nextjs.org/docs/app/getting-started/linking-and-navigating | Official | Prefetch behavior, useLinkStatus | Navigation | High | 2026-09-15 |
| Metadata and OG images | https://nextjs.org/docs/app/getting-started/metadata-and-og-images | Official | Metadata API, streaming metadata, ImageResponse | SEO | High | 2026-09-15 |
| generateMetadata reference | https://nextjs.org/docs/app/api-reference/functions/generate-metadata | Official | Title template rules, metadataBase, deprecations | SEO correctness | High | 2026-09-15 |
| sitemap.xml reference | https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap | Official | Types, generateSitemaps, v16 id Promise | SEO | High | 2026-09-15 |
| Image Component reference | https://nextjs.org/docs/app/api-reference/components/image | Official | Props/config, preload vs priority, version history | Images | High | 2026-09-15 |
| Font Optimization | https://nextjs.org/docs/app/getting-started/fonts | Official | next/font usage | Fonts | High | 2026-09-15 |
| Self-hosting guide | https://nextjs.org/docs/app/guides/self-hosting | Official | Caching, keys, deploymentId, streaming, after | Deployment | High | 2026-09-15 |
| Deploying | https://nextjs.org/docs/app/getting-started/deploying | Official | Options, verified adapters | Deployment | High | 2026-09-15 |
| Environment Variables guide | https://nextjs.org/docs/app/guides/environment-variables | Official | Load order, inlining, runtime env | Config security | High | 2026-09-15 |
| Content Security Policy guide | https://nextjs.org/docs/app/guides/content-security-policy | Official | Nonce proxy, SRI, PPR incompatibility | Security headers | High | 2026-09-15 |
| Production checklist | https://nextjs.org/docs/app/guides/production-checklist | Official | Optimization checklist | Performance | Medium (partly dated wording) | 2026-09-15 |
| Package bundling | https://nextjs.org/docs/app/guides/package-bundling | Official | experimental-analyze, optimizePackageImports | Performance | High | 2026-09-15 |
| Lazy loading | https://nextjs.org/docs/app/guides/lazy-loading | Official | next/dynamic rules | Performance | High | 2026-09-15 |
| Internationalization guide | https://nextjs.org/docs/app/guides/internationalization | Official | Proxy negotiation, dictionaries, root params | i18n | High | 2026-09-15 |
| next/root-params reference | https://nextjs.org/docs/app/api-reference/functions/next-root-params | Official | Getters, restrictions, caching | i18n/caching | High | 2026-09-15 |
| App Router migration guide | https://nextjs.org/docs/app/guides/migrating/app-router-migration | Official | Pages→App mapping | Migration | Medium (early sections v13-era) | 2026-09-15 |
| Vitest guide | https://nextjs.org/docs/app/guides/testing/vitest | Official | Async Server Components unsupported in Vitest | Testing strategy | High | 2026-09-15 |
| AI coding agents guide | https://nextjs.org/docs/app/guides/ai-agents | Official | AGENTS.md generation, bundled docs, MCP, first-party skills | Agent guidance | High | 2026-09-15 |
| August 2026 Security Release | https://nextjs.org/blog/august-2026-security-release | Official | AVIF RCE, Windows RCE, LTS versions | Security | High | 2026-09-15 |
| CVE-2025-66478 advisory | https://nextjs.org/blog/CVE-2025-66478 | Official | RSC RCE, patched versions, secret rotation | Security | High | 2026-09-15 |
| Next.js on Vercel | https://vercel.com/docs/frameworks/full-stack/nextjs | Official (Vercel) | ISR, PPR, streaming, image optimization on Vercel | Deployment | High | 2026-09-15 |
| OpenNext Cloudflare | https://opennext.js.org/cloudflare | Open Source | Next 16 support, feature list, limits | Alt deployment | Medium | 2026-09-15 |
| next-intl routing setup | https://next-intl.dev/docs/routing/setup | Open Source | defineRouting, proxy.ts, request.ts with rootParams | i18n library | High | 2026-09-15 |
| next-intl App Router getting started | https://next-intl.dev/docs/getting-started/app-router | Open Source | Plugin, provider, translations API | i18n library | Medium (partial extract) | 2026-09-15 |
| Better Auth Next.js integration | https://www.better-auth.com/docs/integrations/next | Open Source | Handler, getSession, nextCookies, proxy checks | Auth library | High | 2026-09-15 |
| Auth.js joins Better Auth | https://better-auth.com/blog/authjs-joins-better-auth | Community/Open Source | Auth.js security-patch-only status | Library selection | Medium (via search summary) | 2026-09-15 |
| Clerk Next.js quickstart | https://clerk.com/docs/quickstarts/nextjs | Community (vendor) | proxy.ts clerkMiddleware, auth() | Auth library | Medium | 2026-09-15 |
| vercel/next.js skills directory | https://github.com/vercel/next.js/tree/canary/skills | Open Source | First-party skill names (adoption/optimizer/dev-loop) | Agent workflows | Medium (names only) | 2026-09-15 |
| vercel-labs/next-skills | https://github.com/vercel-labs/next-skills | Archived (retired per 16.3 blog) | Noted as retired in favor of bundled docs | Avoid stale skill sources | Medium | 2026-09-15 |
| vercel-labs/agent-skills | https://github.com/vercel-labs/agent-skills | Community/Open Source | react-best-practices rule categories and priorities | Community agent rules | Medium (README-level) | 2026-09-15 |
| vercel-labs/nextgram | https://github.com/vercel-labs/nextgram | Open Source | Reference modal gallery (cited, not fetched) | Routing example | Medium | 2026-09-15 |
| LogRocket auth libraries 2026 | https://blog.logrocket.com/best-auth-library-nextjs-2026/ | Community | Landscape (search snippet only) | Context only | Low | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Cache Components migration (segment config → use cache) | Migrating to Cache Components guide | Caching (Previous Model) guide; route segment config reference | nextjs-caching-and-revalidation |
| ISR / static shell / PPR terminology | Rendering Philosophy + Caching guides | ISR with Cache Components guide; Vercel PPR docs | nextjs-rendering-strategies |
| Error boundaries (error.js, catchError) | Error Handling docs | 16.3 blog custom error boundaries | nextjs-streaming-and-loading-ui |
| Forms with Server Actions | Server Actions guide | Mutating Data; Forms guide | nextjs-server-actions |
| Auth with Cache Components | Authentication with Cache Components guide | Authentication guide DAL sections | nextjs-authentication |
| Static export | Static Exports guide | Deploying page; BFF export caveats | nextjs-rendering-strategies (decision) + nextjs-deployment-and-self-hosting (ops) |
| Bundle analysis / lazy loading | Package bundling guide | Lazy loading guide; production checklist | nextjs-performance |
| CSP nonces in proxy | CSP guide | proxy reference | nextjs-env-and-config-security (config) with pointer from nextjs-middleware-proxy |
| Next.js AI agent setup (AGENTS.md, skills) | AI agents guide | 16.3 AI improvements blog | nextjs-version-16-upgrade / nextjs-instant-navigation (AI Agent Guidance sections); W17 owns agents-md-conventions |

## Gaps

- WebSearch budget was exhausted mid-research: community `.cursor/rules` for Next.js, community SKILL.md files beyond vercel-labs/agent-skills README, and the "Next.js 16.3: AI Improvements" and "Instant Navigations" blog posts were not fetched in full.
- The `cacheHandlers` handler interface (method signatures, `refreshTags`) was not fetched; the deployment skill defers to the reference.
- next-intl: only routing setup and a partial getting-started extract were retrieved; current major version and Cache Components specifics (e.g., `use cache` with `getTranslations`) need verification.
- "Adopting Partial Prefetching" and "Optimizing prefetching" guides (including `unstable_eager` migration and `prefetch` segment config) were not fetched.
- Vercel-specific features (Fluid compute, skew protection details, remote cache handler pricing) only lightly covered.
- Auth vendor snippets (Better Auth, Clerk) are summaries of quickstart pages; Auth.js status came from a search summary, not the full announcement.
- CVE-2025-29927 (2025 middleware bypass) cited from prior knowledge, not re-verified this session.
- No dedicated coverage of `next/script`/`@next/third-parties` reference, `after()`, Draft Mode, `instrumentation.ts`/OpenTelemetry, MDX, or `useOffline` offline guide; candidates for future skills or owned by W12/W01.
- Next.js Devtools MCP (`/_next/mcp`) tool list not detailed (W17/W18 overlap).
