# Manifest — W04: React/Next.js Stack Extensions

Scope: reassigned on 2026-09-15 from "Other Frameworks & Web Platform" to React + Next.js only (TypeScript), per the coordinator and the updated TAXONOMY.md. All skills below are written for React 19 / Next.js 16.3 (App Router) and Vite SPAs.

Last Verified: 2026-09-15

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| react-nextjs-project-setup | React + Next.js Project Setup | Next.js | Next.js 16.3 / React 19 | A | Active | https://nextjs.org/docs/app/getting-started/installation |
| vite-react-spa | Vite React SPA | React | Vite 8 / React 19 / React Router 7-8 / TanStack Router | A | Active | https://vite.dev/guide/ |
| react-url-state-nuqs | URL State with nuqs | Next.js | nuqs 2.10 / Next.js 16 | A | Active | https://nuqs.dev/docs/server-side |
| trpc-and-type-safe-apis | tRPC and Type-Safe APIs in Next.js | Next.js | tRPC v11 / TanStack Query v5 / Next.js 16 | A | Active | https://trpc.io/docs/client/tanstack-react-query/server-components |
| nextjs-database-integration | Database Integration in Next.js (Prisma / Drizzle) | Next.js | Prisma ORM 7 / Drizzle ORM / Next.js 16 | A | Active | https://nextjs.org/docs/app/guides/data-security |
| vercel-ai-sdk-integration | Vercel AI SDK Integration (Next.js) | Next.js | AI SDK 7 / Next.js 16 | A | Active | https://ai-sdk.dev/docs/getting-started/nextjs-app-router |
| progressive-enhancement | Progressive Enhancement in React and Next.js | Next.js | Next.js 16 / React 19 | A | Active | https://nextjs.org/docs/app/guides/forms |
| modern-javascript-for-react | Modern JavaScript for React | React | ES2020–ES2026 / React 19 | A | Active | https://react.dev/learn/updating-arrays-in-state |
| browser-apis-in-react | Browser APIs in React | React | React 19 / Next.js 16 | A | Active | https://react.dev/reference/react/useSyncExternalStore |
| web-components-in-react | Web Components in React | React | React 19 / Next.js 16 | A | Active | https://react.dev/reference/react-dom/components#custom-html-elements |

Added slugs (beyond assignment): none. Skipped slugs: none.

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Next.js Installation | https://nextjs.org/docs/app/getting-started/installation | Official | v16.3.5; create-next-app prompts/defaults (TS, ESLint/Biome, React Compiler, Tailwind, src, alias, AGENTS.md); Node 20.9; `next build` no longer lints; codemod from `next lint` | Current scaffolding baseline | S | 2026-09-15 |
| Next.js TypeScript config | https://nextjs.org/docs/app/api-reference/config/typescript | Official | typedRoutes, `next typegen`, PageProps/LayoutProps helpers, `next-env.d.ts` in .gitignore, TS 7 via CLI, typedEnv, ignoreBuildErrors warning | Strict, typed project setup | S | 2026-09-15 |
| Next.js Environment Variables | https://nextjs.org/docs/app/guides/environment-variables | Official | Load order, NEXT_PUBLIC build-time inlining, dynamic lookups not inlined, runtime env via `connection()`, `@next/env` | Env handling and secret safety | S | 2026-09-15 |
| Next.js AI agents guide | https://nextjs.org/docs/app/guides/ai-agents | Official | Bundled docs in node_modules, managed AGENTS.md block, MCP at `/_next/mcp`, official skills | Agent-ready repos | A | 2026-09-15 |
| Next.js Data Security | https://nextjs.org/docs/app/guides/data-security | Official | DAL + DTO approach, server-only, taint, Server Action auth/IDOR, closures encryption, allowedOrigins, audit checklist | Security foundation for DB, tRPC, AI, PE skills | S | 2026-09-15 |
| Next.js Forms guide | https://nextjs.org/docs/app/guides/forms | Official | Server Action forms, bind args, Zod validation, useActionState, useFormStatus, useOptimistic, requestSubmit | Progressive enhancement primitives | S | 2026-09-15 |
| Next.js SPA guide | https://nextjs.org/docs/app/guides/single-page-applications | Official | use()+context streaming, `next/dynamic` ssr:false, shallow routing via pushState, static export limits | SPA vs Next decision; browser-only components | A | 2026-09-15 |
| Vite Getting Started / Env and Modes | https://vite.dev/guide/env-and-mode | Official | Vite 8.3 with Rolldown, Node 20.19+/22.12+, react-ts template, VITE_ prefix, modes, ImportMetaEnv typing | Vite SPA baseline | S | 2026-09-15 |
| React Router SPA mode | https://reactrouter.com/how-to/spa | Official | `ssr: false`, HydrateFallback, clientLoader/clientAction, rewrites (docs v8.3.1) | SPA routing option | A | 2026-09-15 |
| nuqs docs (installation, adapters, options, parsers, server-side) | https://nuqs.dev/docs/options | Official | v2.10.1 compatibility, adapter paths, option defaults (replace/shallow/throttle/clearOnDefault), parsers, createLoader/cache/serializer, urlKeys, strict mode | URL state implementation | S | 2026-09-15 |
| tRPC TanStack React Query + RSC | https://trpc.io/docs/client/tanstack-react-query/server-components | Official | v11 init/query-client/client/server files, pending dehydration, createTRPCOptionsProxy, HydrateClient, prefetch, caller | Canonical App Router tRPC setup | S | 2026-09-15 |
| Hey API openapi-ts | https://heyapi.dev/openapi-ts/get-started | Official | Config file, plugins (client-fetch, sdk, TanStack Query, Zod), pin exact version (pre-1.0) | OpenAPI codegen alternative | A | 2026-09-15 |
| Orval | https://orval.dev/ | Official | v8; React Query/SWR hooks, Zod, MSW mocks, fetch/axios clients | OpenAPI codegen alternative | B | 2026-09-15 |
| Prisma: Upgrading to Prisma ORM 7 | https://www.prisma.io/docs/orm/more/upgrade-guides/upgrading-versions/upgrading-to-prisma-7 | Official | `prisma-client` generator + required output, ESM, driver adapters required, prisma.config.ts, env not auto-loaded, Node 20.19/TS 5.4, Accelerate retiring 2026-12-01, middleware removed | Flags outdated Prisma patterns | S | 2026-09-15 |
| Prisma: Next.js help | https://www.prisma.io/docs/orm/more/help-and-troubleshooting/nextjs-help | Official | globalThis singleton, monorepo output, postinstall generate | Hot-reload connection safety | A | 2026-09-15 |
| Drizzle: Get started with Neon | https://orm.drizzle.team/docs/get-started/neon-new | Official | Driver options (neon-http vs websocket vs pg), schema, drizzle-kit generate/migrate/push | Drizzle setup and migrations | A | 2026-09-15 |
| Vercel: Connection pooling with Functions | https://vercel.com/guides/connection-pooling-with-functions | Official | `attachDatabasePool`, module-scope pools, ~5s idle timeout, avoid max=1 | Serverless pooling rules | A | 2026-09-15 |
| AI SDK Next.js App Router quickstart | https://ai-sdk.dev/docs/getting-started/nextjs-app-router | Official | v7 route handler (streamText, convertToModelMessages, createUIMessageStreamResponse, toUIMessageStream, isStepCount), useChat, tool(), AI_GATEWAY_API_KEY | Current AI SDK baseline | S | 2026-09-15 |
| AI SDK 6 to 7 migration guide | https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0 | Official | Renames (system to instructions, onFinish to onEnd, fullStream to stream, stepCountIs to isStepCount), UI stream helper deprecations, Node 22, ESM-only, telemetry default | Prevents outdated AI SDK code | S | 2026-09-15 |
| AI SDK UI chatbot + tool usage | https://ai-sdk.dev/docs/ai-sdk-ui/chatbot-tool-usage | Official | useChat status values, DefaultChatTransport, parts types, addToolOutput, tool states, approvals, sendAutomaticallyWhen | Client chat implementation | A | 2026-09-15 |
| AI Elements | https://elements.ai-sdk.dev/ | Official | shadcn/ui-based AI components (Conversation, Message, Reasoning, Tool, etc.) | Chat UI building blocks | B | 2026-09-15 |
| react.dev useSyncExternalStore | https://react.dev/reference/react/useSyncExternalStore | Official | Signature, getServerSnapshot requirement, immutable snapshot and stable subscribe caveats, online-status example | SSR-safe browser API hooks | S | 2026-09-15 |
| React 19 release post | https://react.dev/blog/2024/12/05/react-19 | Official | Custom element SSR/client prop rules, ref cleanup functions, document metadata | Web components and observer hooks | S | 2026-09-15 |
| react.dev custom HTML elements | https://react.dev/reference/react-dom/components#custom-html-elements | Official | Property-if-defined rule, `on` + event name, case sensitivity | Web component interop | S | 2026-09-15 |
| Lit React integration | https://lit.dev/docs/frameworks/react/ | Official | `@lit/react` createComponent and event mapping | Optional wrappers | B | 2026-09-15 |
| Socket: TC39 advances Temporal to Stage 4 | https://socket.dev/blog/tc39-advances-temporal-to-stage-4 | Community | Temporal Stage 4 (March 2026, ES2026); Chromium/Firefox shipped, Safari partial | Modern JS date guidance | B | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Server Action forms / useActionState | Next.js Forms guide | react.dev useActionState, GOV.UK PE principles, earlier framework-agnostic PE draft | progressive-enhancement (links to nextjs-server-actions, react-19-actions-and-transitions for depth) |
| Data Access Layer and server-only data | Next.js Data Security guide | Prisma/Drizzle setup docs | nextjs-database-integration (referenced from trpc-and-type-safe-apis and vercel-ai-sdk-integration) |
| Env var exposure rules | Next.js Environment Variables guide | Vite env docs | react-nextjs-project-setup and vite-react-spa (each framework's rules); deep security in nextjs-env-and-config-security (W03) |
| Browser-only components in Next.js | Next.js SPA guide (`next/dynamic` ssr:false) | react.dev useSyncExternalStore | browser-apis-in-react |
| Shallow routing / URL state | nuqs docs | Next.js SPA guide pushState section | react-url-state-nuqs |
| SPA mode choices | Vite docs + React Router SPA mode | Next.js static export guide | vite-react-spa |

## Gaps

- **RESOLVED 2026-09-15: the 19 old out-of-scope folders were deleted by the orchestrator** after the scope change to React + Next.js. The workstream's own deletion attempt had been blocked by the permission classifier. The folders were:
  - Vue, Pinia and Nuxt: vue-3-composition-api, vue-component-patterns, pinia-state-management, nuxt-fundamentals, nuxt-data-fetching-and-rendering
  - Angular and signals: angular-signals-and-standalone, angular-application-architecture, angular-change-detection-performance, signals-reactivity-concepts
  - Solid, Svelte, Astro and Qwik: solidjs-reactivity, svelte-5-runes, sveltekit-fundamentals, astro-islands-architecture, qwik-resumability
  - Other: framework-selection-guide, web-components-fundamentals, lit-components, vanilla-js-modern-patterns, htmx-hypermedia-patterns
- **progressive-enhancement was rewritten, not deleted.** It is still a W04 slug, so I overwrote the old framework-agnostic version in place with React/Next.js content.
- **Research limits.** The session's WebSearch budget (200 calls) ran out during the reassignment, so everything for the new scope was checked with WebFetch on official docs only. Community agent skills and rules for these topics (skills.sh, .cursor/rules) were not surveyed.
- **Drizzle 1.0 status is unconfirmed.** npm returned 403 and the GitHub releases page returned inconsistent dates. The skill says 1.0 is in RC and to verify before pinning.
- **AI SDK 7 details need re-checking.** The exact identifiers for the approval part shape, the throttle option name and the `Output.object` structured-output helper are flagged in the skill for verification against the installed version.
- **Next.js cache invalidation signatures.** `revalidateTag(tag, profile)` and `updateTag` under Cache Components are mentioned but not fully checked in this workstream (W03 owns caching).
- **Lit SSR / Declarative Shadow DOM in Next.js.** Still labs status, not verified end to end. Cross-shadow-root ARIA (reference target) is not Baseline.
- **Uncovered topics.** Candidates for future slugs with no current owner: auth libraries (Better Auth / Auth.js v5) outside nextjs-authentication, payments (Stripe) integration, background jobs/queues (Inngest, Trigger.dev), email (React Email/Resend), file storage uploads in Next.js.
- **Framework-agnostic research from the earlier run was dropped.** Vue/Nuxt, Angular 22, Svelte 5/SvelteKit, Solid 2.0, Astro 6, Qwik 2, Lit and htmx 4 are now out of scope for this library.
