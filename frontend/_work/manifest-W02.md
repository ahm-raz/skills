# Manifest: W02 React

Scope applied: React + Next.js App Router only (TypeScript). Framework Notes in every skill cover React (Vite SPA) and Next.js App Router. The 6 skills written before the scope change were revised to match.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| react-component-composition | React Component Composition | React | React, Next.js | A | Active | https://react.dev/learn/passing-props-to-a-component |
| react-hooks-patterns | React Hooks Patterns | React | React, Next.js | S | Active | https://react.dev/learn/you-might-not-need-an-effect |
| react-state-management | React State Management | React | React, Next.js | A | Active | https://react.dev/learn/choosing-the-state-structure |
| react-rendering-model | React Rendering Model | React | React, Next.js | S | Active | https://react.dev/learn/render-and-commit |
| react-server-components | React Server Components | React | React, Next.js | A | Active | https://react.dev/reference/rsc/server-components |
| react-performance-optimization | React Performance Optimization | React | React, Next.js | S | Active | https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices |
| react-compiler | React Compiler | React | React, Next.js | A | Active | https://react.dev/blog/2025/10/07/react-compiler-1 |
| react-data-fetching-tanstack-query | React Data Fetching with TanStack Query | React | React, Next.js | S | Active | https://tanstack.com/query/latest/docs/framework/react/guides/advanced-ssr |
| react-suspense-and-error-boundaries | React Suspense and Error Boundaries | React | React, Next.js | A | Active | https://react.dev/reference/react/Suspense |
| react-19-actions-and-transitions | React 19 Actions and Transitions | React | React, Next.js | S | Active | https://react.dev/reference/react/useActionState |
| react-context-patterns | React Context Patterns | React | React, Next.js | A | Active | https://react.dev/learn/passing-data-deeply-with-context |
| react-refs-and-imperative-apis | React Refs and Imperative APIs | React | React, Next.js | A | Active | https://react.dev/learn/manipulating-the-dom-with-refs |
| react-typescript-patterns | React TypeScript Patterns | React | React, Next.js | A | Active | https://react.dev/learn/typescript |
| react-router-framework-mode | React Router (v8): Framework, Data and Declarative Modes | React | React (Vite SPA); Next.js comparison | B | Active | https://reactrouter.com/upgrading/v7 |
| tanstack-router-and-start | TanStack Router and TanStack Start | React | React (Vite SPA); Next.js comparison | B | Active | https://tanstack.com/start/latest/docs/framework/react/guide/server-functions |
| tanstack-table | TanStack Table | React | React, Next.js | B | Active | https://tanstack.com/blog/announcing-tanstack-table-v9 |
| react-custom-hooks-library-design | React Custom Hooks Library Design | React | React, Next.js | A | Active | https://react.dev/learn/reusing-logic-with-custom-hooks |
| react-19-migration-guide (ADDED) | React 19 Migration Guide | React | React, Next.js | A | Active | https://react.dev/blog/2024/04/25/react-19-upgrade-guide |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| react.dev: You Might Not Need an Effect | https://react.dev/learn/you-might-not-need-an-effect | Official | 11 effect anti-patterns and fixes, decision tree | Most common React bug source | S | 2026-09-15 |
| react.dev versions page | https://react.dev/versions | Official | 19.0–19.3 release dates (19.3 = 2026-09-09) | Version-gating guidance | S | 2026-09-15 |
| React 19.3 blog post | https://react.dev/blog/2026/09/09/react-19-3 | Official | ViewTransition, Fragment refs, browser(), Trusted Types, RSC Context rendering, bug fixes | Latest stable features | S | 2026-09-15 |
| React 19.2 blog post | https://react.dev/blog/2025/10/01/react-19-2 | Official | Activity, useEffectEvent, cacheSignal, Performance Tracks | Current hooks/perf APIs | S | 2026-09-15 |
| React 19 release + upgrade guide | https://react.dev/blog/2024/04/25/react-19-upgrade-guide | Official | Removed APIs, TS changes, codemods, ref as prop | Migration and outdated-pattern flags | S | 2026-09-15 |
| React Compiler v1.0 post | https://react.dev/blog/2025/10/07/react-compiler-1 | Official | Stable release, perf results, lint integration | Memoization guidance | S | 2026-09-15 |
| React Compiler intro + incremental adoption | https://react.dev/learn/react-compiler/incremental-adoption | Official | annotation mode, overrides, gating, use no memo | Rollout strategies | S | 2026-09-15 |
| RSC critical vulnerability advisory | https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components | Official | CVE-2025-55182/55183/55184/67779, CVE-2026-23864; fixed versions | Security patch floor | S | 2026-09-15 |
| Next.js docs: reactCompiler | https://nextjs.org/docs/app/api-reference/config/next-config-js/reactCompiler | Official | `reactCompiler: true`, annotation mode, SWC optimization (docs v16.3.5) | Next.js integration | S | 2026-09-15 |
| TanStack Query docs (React, v5) | https://tanstack.com/query/latest/docs/framework/react/overview | Official | queryOptions, mutations, SSR hydration for App Router | Server-state standard | S | 2026-09-15 |
| npm @tanstack/react-query | https://www.npmjs.com/package/@tanstack/react-query | Official | Current version 5.102.x | Version verification | A | 2026-09-15 |
| TkDodo: Practical React Query | https://tkdodo.eu/blog/practical-react-query | Community | staleTime/gcTime defaults, keys as deps, don't copy to state, custom hooks | Maintainer best practices | A | 2026-09-15 |
| React Router CHANGELOG | https://github.com/remix-run/react-router/blob/main/CHANGELOG.md | Open Source | v8.3.1 (2026-08-27), middleware stable, split route modules default, RSC unstable | Version verification | A | 2026-09-15 |
| React Router: Upgrading from v7 | https://reactrouter.com/upgrading/v7 | Official | v8 requirements, future flags, react-router-dom removal, loaderData | Upgrade path | A | 2026-09-15 |
| React Router: Middleware | https://reactrouter.com/how-to/middleware | Official | middleware/clientMiddleware, createContext, next() | Auth/context patterns | A | 2026-09-15 |
| TanStack Start overview + server functions | https://tanstack.com/start/latest/docs/framework/react/guide/server-functions | Official | RC status, createServerFn, validator, file organization, CSRF middleware | Full-stack alternative | A | 2026-09-15 |
| TanStack router source createServerFn.ts | https://github.com/TanStack/router/blob/main/packages/start-client-core/src/createServerFn.ts | Open Source | `inputValidator` deprecated in favor of `validator` | API correctness | A | 2026-09-15 |
| npm @tanstack/react-start | https://registry.npmjs.org/@tanstack/react-start/latest | Official | 1.168.54, peers React ≥18, Vite ≥7 | Version verification | A | 2026-09-15 |
| Announcing TanStack Table V9 | https://tanstack.com/blog/announcing-tanstack-table-v9 | Official | Stable 2026-08-04; tableFeatures, useTable, TanStack Store state | Current table API | A | 2026-09-15 |
| TanStack Table React quick start (GitHub docs) | https://github.com/TanStack/table/tree/main/docs/framework/react | Open Source | ColumnDef<typeof features, T>, table.FlexRender mention | V9 API shape | B | 2026-09-15 |
| InfoQ: TanStack Table V9 Beta | https://www.infoq.com/news/2026/07/tanstack-table-v9-beta/ | Community | Tree-shaking, memory, subscriptions summary | Context on V9 | B | 2026-09-15 |
| TanStack blog index | https://tanstack.com/blog | Official | No Start 1.0-stable post found; "We Stopped Using RSC on TanStack.com" (Jul 2026) | Status verification | B | 2026-09-15 |
| Zustand v5 migration / useShallow | https://zustand.docs.pmnd.rs/reference/migrations/migrating-to-v5 | Official | Selector stability, useShallow, infinite-loop error | Common v5 bug | A | 2026-09-15 |
| Redux Toolkit docs | https://redux-toolkit.js.org/ | Official | createSlice, withTypes hooks, RTK Query | Enterprise state option | A | 2026-09-15 |
| Jotai docs | https://jotai.org/docs | Official | Atoms, derived atoms | Fine-grained state option | A | 2026-09-15 |
| vercel-labs/agent-skills react-best-practices | https://github.com/vercel-labs/agent-skills/blob/main/skills/react-best-practices/SKILL.md | Open Source / Community | 70 rules in 8 prioritized categories | Most-adopted agent rule set for React perf | A | 2026-09-15 |
| Vite 8 + React Compiler install guide (recca0120) | https://recca0120.github.io/en/2026/04/14/react-compiler-vite-v6/ | Community | @rolldown/plugin-babel + reactCompilerPreset setup | Vite 8 changes not yet in React docs summary | B | 2026-09-15 |
| State management 2026 comparison (dev.to) | https://dev.to/jsgurujobs/state-management-in-2026-zustand-vs-jotai-vs-redux-toolkit-vs-signals-2gge | Community | Adoption trends (State of React 2025), bundle sizes | Library selection context | C | 2026-09-15 |
| Dan Abramov: Before You memo() | https://overreacted.io/before-you-memo/ | Community | Move state down / lift content up | Structural perf fixes | A | 2026-09-15 |
| Kent C. Dodds: Context / compound components | https://kentcdodds.com/blog/how-to-use-react-context-effectively | Community | Throwing context hook, compound pattern | Established patterns | A | 2026-09-15 |
| Sunsetting Create React App | https://react.dev/blog/2025/02/14/sunsetting-create-react-app | Deprecated (official notice) | CRA deprecated Feb 2025 | Flag outdated setup guidance | S | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Effect anti-patterns / derived state | react.dev "You Might Not Need an Effect" | Vercel rules rerender-derived-state-no-effect, rerender-move-effect-to-event; Abramov useEffect guide | react-hooks-patterns |
| Re-render optimization rules | vercel-labs react-best-practices | react.dev memo/useMemo docs; Abramov "Before You memo()"; Josh Comeau re-render article | react-performance-optimization |
| RSC server rules (auth actions, serialization, dedup) | react.dev RSC reference | Vercel server-* rules | react-server-components |
| forwardRef/ref-as-prop, removed legacy APIs | React 19 upgrade guide | React 19 release post; types-react-codemod docs | react-19-migration-guide (summary also in react-refs-and-imperative-apis) |
| URL state for filters | nuqs / Next.js searchParams | React Router useSearchParams, TanStack Router validateSearch | react-state-management (details deferred to W04 react-url-state-nuqs) |
| Server Actions forms | react.dev useActionState | Next.js Updating Data guide | react-19-actions-and-transitions (Next.js details deferred to W03 nextjs-server-actions) |

## Gaps

- **TanStack Table V9 exact signatures** (`table.FlexRender` props, `table.Subscribe`/selector helpers, V8→V9 migration renames) weren't fully verified. The docs pages 404'd through the fetch tool. Re-verify against tanstack.com/table/v9 docs.
- **TanStack Start stability label is ambiguous**: docs still say Release Candidate, one community post claims 1.0 in March 2026, and no official 1.0 blog post was found. Re-check before calling it stable.
- **React 19.3 `FragmentInstance` TypeScript type name** and `@types/react` 19.3 changes weren't verified.
- **Next.js `PageProps<"/route">`/`LayoutProps` global helpers**: included based on knowledge of 15.5+/16. Confirm with W03 (nextjs-app-router-fundamentals).
- **eslint-plugin-react-hooks flat config preset key** (`recommended` vs `recommended-latest`) and current major version weren't checked against the README.
- **Web search budget was exhausted** partway through. Zustand/Jotai/RTK exact latest versions and nuqs API details (`useQueryStates` options) are from knowledge, not fetched this session.
- **Scope-reduced relevance**: react-router-framework-mode and tanstack-router-and-start are secondary under the React + Next.js scope. Consider whether W02 should keep them or merge them into a single "vite-react-spa routing" section owned by W04.
- **Possible future skill**: `react-view-transitions-and-activity` (React 19.3 `<ViewTransition>` + `<Activity>` usage patterns). Partly overlaps W13 view-transitions-api, so not added.
