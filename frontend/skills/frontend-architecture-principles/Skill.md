# Frontend Architecture Principles

## Summary
Principles for structuring React and Next.js (TypeScript) codebases so they stay changeable as teams, features, and traffic grow. Covers boundaries, dependency direction, colocation, separation of server vs client state, rendering-strategy choice, and how to record and enforce architectural decisions. This is the "umbrella" skill; specific concerns (state, API layer, errors, monorepos, micro-frontends) have dedicated skills.

## Category
Architecture

## Subcategories
Modularity, dependency rules, colocation, layering, ADRs, fitness functions, rendering strategy, coupling and cohesion

## Problem It Solves
Frontend apps decay into "big balls of mud": components importing each other across features, global stores holding everything, business rules duplicated in UI handlers, and no one able to delete code safely. Explicit principles plus automated enforcement keep change cost roughly constant as the codebase grows.

## When To Use
- Starting a new app or major rewrite and choosing structure.
- A codebase where small changes ripple across many folders or teams.
- Onboarding multiple teams onto one frontend (before reaching for micro-frontends).
- Reviewing a PR that introduces a new top-level folder, shared module, or global store.
- Writing an Architecture Decision Record (ADR).

## When Not To Use
- Throwaway prototypes or single-page marketing sites: a flat folder is fine.
- As a justification for abstraction before a second use case exists.
- For framework-specific routing/rendering details (see framework skills).

## Core Principles
1. **Dependencies point one way.** Higher-level, volatile code (pages, features) depends on lower-level, stable code (entities, shared UI, utilities) — never the reverse.
2. **Organize by domain first, technical type second.** `features/checkout/{ui,model,api}` beats `components/`, `hooks/`, `services/` at the root.
3. **Colocate what changes together.** Tests, styles, stories, and types live next to the code they describe.
4. **Every module has a public API.** Import from `features/cart` (its `index.ts`), never `features/cart/ui/internal/Row.tsx`.
5. **Server state is not client state.** Cache remote data with a server-cache library; keep client stores for UI/session state only.
6. **Keep business logic framework-light.** Pure functions/services for rules; components orchestrate and render.
7. **Prefer composition over configuration.** Slots/children over boolean-flag explosions.
8. **Decide rendering per route, not per app.** Static, server, streaming, or client rendering chosen by data freshness and interactivity needs.
9. **Make the right thing automatic.** Encode rules in lint/boundary tools and CI, not in wiki pages.
10. **Optimize for deletion.** A feature should be removable by deleting one folder plus its route registration.

## Best Practices
- Keep a short `ARCHITECTURE.md` (or ADR index) describing layers, allowed imports, and state ownership; link it from AGENTS.md/CLAUDE.md so agents follow it.
- Record significant decisions as ADRs (context, decision, consequences, status). Supersede, never edit history.
- Limit "shared" code to things used by 3+ features; promote late, not early (rule of three).
- Name by domain language (`InvoiceStatusBadge`) rather than by generic UI shape (`Badge2`).
- Enforce boundaries with tooling: `eslint-plugin-boundaries`, `@nx/enforce-module-boundaries`, Steiger (FSD), `dependency-cruiser`, or Turborepo `boundaries` (experimental).
- Budget cross-cutting concerns explicitly: auth, i18n, flags, telemetry, error reporting each get one integration point.
- Use TypeScript path aliases for public entry points only (`@/features/cart`), not deep paths.
- Treat the URL as state: filters, tabs, pagination belong in search params when shareable.
- Define "fitness functions" in CI: bundle budgets, circular-dependency checks, boundary lint, type coverage.

## Implementation Guidance

### Decision table: structure by scale
| Situation | Recommended structure |
|---|---|
| < ~15 screens, 1–3 devs | Route-colocated folders + `components/`, `lib/` |
| Growing product, 1 team | Feature-based folders with public APIs ([feature-based-architecture](../feature-based-architecture/Skill.md)) |
| Several teams, one deploy | Monorepo packages + boundary rules ([monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md)) |
| Teams need independent deploys/tech stacks | Micro-frontends, only with strong platform team ([micro-frontends](../micro-frontends/Skill.md)) |

### Decision table: where state lives
| State kind | Owner |
|---|---|
| Remote data (lists, entities) | Server cache (TanStack Query, SWR, RTK Query, framework loaders) |
| Shareable view state (filters, page, tab) | URL search params |
| Form draft | Form library / local component state |
| Ephemeral UI (open/closed, hover) | Local component state |
| Cross-cutting session (theme, auth user, locale) | Context/provider or small store |
| Complex multi-step flows with forbidden transitions | State machine (XState v5) |

### Layering reference (generic)
```
app/        bootstrapping, providers, routing, global styles
pages/      route entry components (compose widgets/features)
features/   user-facing capabilities (add-to-cart, filter-orders)
entities/   domain models + their UI atoms (User, Order)
shared/     design-system UI, api client, lib, config (no domain knowledge)
```
Rule: a layer imports only from layers below it.

### Boundary enforcement (eslint-plugin-boundaries, ESLint 10 flat config)
```js
// eslint.config.js
import boundaries from 'eslint-plugin-boundaries';
export default [
  {
    plugins: { boundaries },
    settings: {
      'boundaries/elements': [
        { type: 'app', pattern: 'src/app/*' },
        { type: 'pages', pattern: 'src/pages/*' },
        { type: 'features', pattern: 'src/features/*' },
        { type: 'entities', pattern: 'src/entities/*' },
        { type: 'shared', pattern: 'src/shared/*' },
      ],
    },
    rules: {
      'boundaries/element-types': ['error', {
        default: 'disallow',
        rules: [
          { from: 'app', allow: ['pages', 'features', 'entities', 'shared'] },
          { from: 'pages', allow: ['features', 'entities', 'shared'] },
          { from: 'features', allow: ['entities', 'shared'] },
          { from: 'entities', allow: ['shared'] },
          { from: 'shared', allow: ['shared'] },
        ],
      }],
    },
  },
];
```
(Verify rule names against the plugin version you install; the plugin has renamed rules across majors.)

### ADR template (keep under one page)
```md
# ADR-012: Use TanStack Query for server state
Status: Accepted (2026-09-15)  Supersedes: ADR-004
Context: Redux slices duplicate fetch/caching logic; stale data bugs.
Decision: All remote reads via query hooks in features/*/api; Redux removed for server data.
Consequences: + dedupe/caching; - team training; migration tracked in #123.
```

## Recommended Workflow
1. Inventory current pain: change-coupling hotspots (git log co-change), circular deps, largest modules.
2. Define layers/domains and allowed import directions; write ADR.
3. Add boundary lint in warn mode; measure violations.
4. Introduce public `index.ts` per module; codemod deep imports.
5. Move server data to a server-cache library; shrink global store.
6. Flip boundary lint to error; add circular-dependency check to CI.
7. Revisit quarterly: prune `shared/`, update ADRs.

## Patterns
- **Public API barrel (per module, not per folder):** one `index.ts` exporting only what consumers need.
- **Container/presentational split at feature edges:** data hooks in `model/`, pure UI in `ui/`.
- **Ports and adapters for external services:** `analytics.track()` interface with a vendor adapter swapped per environment.
- **Strangler fig migration:** new routes built in the new structure; old routes migrated opportunistically.
- **App shell + route modules:** shell owns providers/layout; each route lazy-loads its feature.

## Anti-Patterns
- **Root-level `components/` with 300 files** — no ownership. Fix: move domain components into features; keep only design-system primitives shared.
- **Global store as a cache of API responses** — stale data, manual invalidation. Fix: server-cache library.
- **Barrel files re-exporting whole trees (`export * from`) in app code** — breaks tree-shaking and creates cycles. Fix: explicit named exports at module boundaries only.
- **"utils" dumping ground** — hidden coupling. Fix: name by purpose (`shared/lib/money`), delete unused.
- **Premature micro-frontends** — distributed monolith. Fix: modular monolith with enforced boundaries first.
- **Cross-feature imports** (`features/a` importing `features/b/ui`) — Fix: lift shared piece to `entities`/`shared`, or compose at the page level.
- **Architecture documented only in a wiki** — drifts. Fix: lint rules + ADRs in repo.

## Accessibility
- Architecture should centralize a11y-critical infrastructure: focus management on route change, live region announcer, skip links, and accessible primitives in the design system (WCAG 2.4.3 Focus Order, 4.1.3 Status Messages).
- Make the accessible primitive the easiest import; forbid raw `<div onClick>` via lint (`jsx-a11y`).

## Responsive Design
- Keep responsive tokens (breakpoints, container sizes) in the design-token layer, not scattered per feature.
- Prefer container queries in shared components so they adapt to where features place them.

## Performance
- Route-level code splitting follows feature boundaries naturally; keep features lazy-loadable.
- Avoid shared modules that import heavy dependencies (charts, editors) — they get pulled into every chunk.
- Add bundle-size budgets as a CI fitness function.

## Security
- Single, audited integration points for auth, HTML sanitization, and API calls make review tractable.
- Keep secrets out of client bundles entirely; only public config in `shared/config`.

## Testing
- Unit test pure domain logic heavily; component-test features through their public API; E2E only critical journeys.
- Architecture tests: boundary lint, `dependency-cruiser --validate`, `madge --circular` in CI.

## Tooling
- eslint-plugin-boundaries, dependency-cruiser, madge — Active.
- Steiger (FSD linter) — Active.
- Nx `@nx/enforce-module-boundaries` (Nx 23.x) — Active.
- Turborepo `turbo boundaries` — Experimental (2.x).
- ESLint 10 (flat config only; eslintrc removed Feb 2026).

## Framework Notes
- **React (Vite SPA):** routes (React Router / TanStack Router) lazy-load `pages/*`; all data flows through a server-cache library (TanStack Query) in `features/*/api` or `entities/*/api`; there is no server layer, so treat every module as public to the user (no secrets).
- **Next.js (App Router, 16.x):** the `app/` directory is the routing layer only — keep `page.tsx`/`layout.tsx` thin and import from `src/features|entities|widgets`. Server Components are the default "server layer": fetch in RSC or `server-only` modules (`import 'server-only'`), mutate via Server Actions in `features/*/api/actions.ts`, and push `'use client'` down to leaf interactive components. Cross-cutting request concerns (auth redirects, CSP nonce, locale) live in `proxy.ts` (renamed from `middleware.ts` in Next.js 16). Choose rendering per route: static/cached (`'use cache'`/revalidate) vs dynamic (`await connection()`, `headers()`).
- **Both:** mark client-only modules with `import 'client-only'` in Next and keep domain logic in plain TS so it runs in RSC, Client Components, and tests alike.

## AI Agent Guidance
- Before adding files, read ARCHITECTURE.md/ADRs and mirror existing folder conventions.
- Do: import only from module public APIs; put new remote data in the server-cache layer; colocate tests.
- Don't: create new top-level folders, global stores, or `utils.ts` dumping grounds without an ADR.
- Don't: add a cross-feature import to "just make it work" — lift or compose instead.
- Verify before done: boundary lint passes, no new circular deps, typecheck passes, the feature can be removed by deleting its folder.

## Examples
```ts
// features/add-to-cart/index.ts — public API
export { AddToCartButton } from './ui/AddToCartButton';
export { useAddToCart } from './model/useAddToCart';
// internal files are not exported
```
```tsx
// pages/product/ProductPage.tsx — composition at page level (no feature-to-feature import)
import { ProductGallery } from '@/widgets/product-gallery';
import { AddToCartButton } from '@/features/add-to-cart';
import { ReviewsList } from '@/features/reviews';
export function ProductPage({ id }: { id: string }) {
  return (<><ProductGallery id={id} /><AddToCartButton productId={id} /><ReviewsList productId={id} /></>);
}
```

## Related Skills
- [feature-based-architecture](../feature-based-architecture/Skill.md) — concrete folder methodology
- [frontend-state-architecture](../frontend-state-architecture/Skill.md) — state ownership details
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — data access layer
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — scaling across packages
- [micro-frontends](../micro-frontends/Skill.md) — when independent deployment is required
- [linting-and-formatting](../linting-and-formatting/Skill.md) — enforcement tooling
- [react-nextjs-project-setup](../react-nextjs-project-setup/Skill.md) — bootstrapping the stack
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) — server/client boundary design

## Sources
- [Feature-Sliced Design overview](https://feature-sliced.design/docs/get-started/overview) — Community (methodology) — layer/import rules
- [Nx: Enforce module boundaries](https://nx.dev/docs/features/enforce-module-boundaries) — Official — tag-based constraints
- [Turborepo Boundaries](https://turborepo.dev/docs/reference/boundaries) — Official — experimental boundaries
- [Martin Fowler: Micro Frontends](https://martinfowler.com/articles/micro-frontends.html) — Community (respected) — when not to distribute
- [ESLint v10.0.0 released](https://eslint.org/blog/2026/02/eslint-v10.0.0-released/) — Official — flat-config-only status
- [Michael Nygard: Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) — Community — ADR format

## License / Usage Notes
Content is summarized and synthesized from the listed sources; no proprietary text copied. Referenced tools are MIT/Apache-2.0 licensed.

## Quality Tier
A — synthesized from official tool docs and established methodologies; principles are stable, tooling versions verified Sept 2026.

## Status
Active

## Last Verified
2026-09-15
