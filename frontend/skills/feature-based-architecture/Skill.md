# Feature-Based Architecture

## Summary
Organizing frontend code by business capability (features/domains) instead of technical type, with explicit layers, public APIs, and import rules. Covers Feature-Sliced Design (FSD v2.1) as the most complete published methodology, plus a lighter "feature folders" variant, and how to enforce either with linters.

## Category
Architecture

## Subcategories
Feature-Sliced Design, vertical slices, module public API, folder structure, import rules, Steiger

## Problem It Solves
Type-based structures (`components/`, `hooks/`, `services/`) scatter one feature across many folders, hide ownership, and allow any file to import any other. Feature-based structure localizes change, clarifies ownership, and makes features deletable and lazy-loadable.

## When To Use
- Apps with more than a handful of domains (orders, billing, users, search).
- Teams where several developers work in parallel on different features.
- When refactoring a type-based codebase that has become tangled.

## When Not To Use
- Tiny apps or libraries (a design-system package is organized by component, not features).
- When a framework's file-based router already provides adequate colocation and the app is small; don't layer FSD on top of a 5-route site.

## Core Principles
1. **Slice by domain, segment by purpose.** Domain folders contain `ui`, `model`, `api`, `lib`, `config` segments.
2. **Strict downward imports.** A layer may import only from layers strictly below it.
3. **No sibling imports on the same layer.** `features/a` cannot import `features/b`; compose at a higher layer.
4. **Public API per slice.** Consumers import from the slice root (`index.ts`) only.
5. **Shared has no business knowledge.** `shared/` is domain-agnostic infrastructure and UI kit.
6. **Start pages-first.** Keep code in the page until it's reused; extract to widgets/features/entities when needed (FSD v2.1 guidance).

## Best Practices
- FSD layers (top to bottom): `app`, `pages`, `widgets`, `features`, `entities`, `shared`. `processes` is **deprecated** — move its logic to `features`/`app`.
- `app` and `shared` have segments but no slices.
- Name segments by purpose (`model`, `api`), not by essence (`hooks`, `types`, `components`) — "hooks" says nothing about what the code does.
- For unavoidable entity-to-entity references (e.g., `Order` referencing `User` type), FSD provides the `@x` cross-import notation: `entities/user/@x/order.ts` exposes an explicit API for `order` only. Use sparingly.
- Keep features small: one user-valued action (`add-to-cart`, `toggle-favorite`), not "cart everything".
- Widgets = composed, self-sufficient UI blocks (header, product card with actions) reused across pages.
- Run Steiger (FSD linter) or equivalent boundary lint in CI.
- Use path aliases to slice roots only: `@/features/*`, `@/entities/*`, `@/shared/*`.

## Implementation Guidance

### FSD tree
```
src/
  app/            providers/, routes/, styles/, index.tsx
  pages/
    product/      ui/ProductPage.tsx, api/loader.ts, index.ts
  widgets/
    header/       ui/, index.ts
  features/
    add-to-cart/  ui/AddToCartButton.tsx, model/useAddToCart.ts, api/addToCart.ts, index.ts
  entities/
    product/      ui/ProductCard.tsx, model/types.ts, api/productQueries.ts, index.ts
    user/         ..., @x/order.ts
  shared/
    ui/           Button/, Dialog/
    api/          httpClient.ts
    lib/          money.ts, dates.ts
    config/       env.ts
```

### Lighter variant: feature folders
```
src/
  app/ (routing, providers)
  features/<domain>/{components,hooks,api,types}.ts + index.ts
  shared/{ui,lib,api}
```
Rules: features import `shared` only; pages/routes compose features. Choose this when FSD's six layers feel heavy.

### Decision table: where does this code go?
| Code | FSD location |
|---|---|
| Button, Input, Dialog primitives | `shared/ui` |
| HTTP client, interceptors | `shared/api` |
| `Product` type + `ProductCard` display | `entities/product` |
| "Add to cart" button + mutation | `features/add-to-cart` |
| Header combining search + user menu | `widgets/header` |
| Route component for `/product/:id` | `pages/product` |
| Router, providers, global CSS | `app` |

### Steiger setup
```bash
npm i -D steiger @feature-sliced/steiger-plugin
```
```js
// steiger.config.js
import { defineConfig } from 'steiger';
import fsd from '@feature-sliced/steiger-plugin';
export default defineConfig([...fsd.configs.recommended]);
```
```jsonc
// package.json
{ "scripts": { "lint:arch": "steiger ./src" } }
```

### Framework file-based routers
Next.js `app/` (or a React Router/TanStack Router route config in a Vite SPA) must live where the framework expects. Keep route files thin: they import from `src/pages/*` (or directly from widgets/features) and contain no business logic.

## Recommended Workflow
1. List domains/nouns (entities) and user actions (features) from product requirements.
2. Create `shared/` and move domain-agnostic primitives there.
3. Create entity slices with types + read queries.
4. Create feature slices for mutations/interactions.
5. Make pages compose widgets/features; remove logic from route files.
6. Add public `index.ts` and codemod deep imports.
7. Enable Steiger/boundary lint in warn, then error.

## Patterns
- **Slice public API:** `export { ProductCard } from './ui/ProductCard'; export type { Product } from './model/types';`
- **Composition via slots (avoid sibling imports):**
  ```tsx
  // entities/product/ui/ProductCard.tsx
  export function ProductCard({ product, actions }: { product: Product; actions?: React.ReactNode }) {
    return <article><h3>{product.name}</h3>{actions}</article>;
  }
  // pages/catalog — composes entity with feature
  <ProductCard product={p} actions={<AddToCartButton productId={p.id} />} />
  ```
- **Cross-import via @x:** `entities/user/@x/order.ts` exports `UserSummary` for the order slice only.
- **Lazy page slice:** router lazy-imports `pages/*/index.ts`.

## Anti-Patterns
- **Feature imports feature** — circular coupling. Fix: slot composition at widget/page, or extract to entity.
- **Everything is a feature** — 200 micro-features. Fix: keep code in pages until reused.
- **`shared/` containing domain logic** (`shared/lib/calculateOrderTax`) — Fix: move to `entities/order/lib`.
- **Deep imports** (`@/features/cart/model/store`) — Fix: export from slice index; lint `no-restricted-imports` with patterns.
- **Segments named `hooks/`, `components/`** — Fix: `model/`, `ui/`.
- **Business logic inside `app/**/page.tsx` in Next.js** — routing and domain mixed. Fix: page file only composes slices.
- **Using `processes` layer** — deprecated; Fix: features or app-level orchestration.

## Accessibility
- Accessible primitives live in `shared/ui` so every feature inherits correct semantics, focus handling, and ARIA.
- Page-level concerns (document title, focus on navigation, landmarks) belong to `app`/`pages` layers.

## Responsive Design
- Entities/widgets should be layout-agnostic (container queries), since pages place them in different contexts.

## Performance
- Slices align with lazy-loading boundaries: pages lazy-load; features pulled in only by pages using them.
- Avoid a `shared/index.ts` barrel re-exporting everything — import `@/shared/ui/button` granularly or ensure `sideEffects: false` and ESM so bundlers tree-shake.

## Security
- Keep auth/session handling in `shared/api` (transport) and `entities/session` (model) — one place to audit.

## Testing
- Test each slice through its public API.
- Entities: unit tests on model/lib; features: component tests with mocked API (MSW); pages: E2E for journeys.
- `steiger ./src` and boundary lint in CI.

## Tooling
- Steiger + `@feature-sliced/steiger-plugin` — Active (FSD official linter).
- eslint-plugin-boundaries / dependency-cruiser — Active, methodology-agnostic.
- `@feature-sliced/eslint-config` — older; prefer Steiger for FSD-specific rules (verify maintenance before adopting).

## Framework Notes
- **Next.js App Router (16.x):** keep `app/` (routes, layouts, `loading.tsx`, `error.tsx`) as a thin routing shell and put FSD layers under `src/`. A folder named `src/pages` collides with Next's Pages Router detection — either name the FSD layer `src/views` or keep an empty root `pages/` with a README (check the current FSD "Usage with Next.js" guide). Route files re-export or compose: `export { ProductPage as default } from '@/views/product'`.
- **Next.js server/client split per slice:** segment `api/` may hold `queries.ts` (server-only, imported by RSC) and `actions.ts` (`'use server'`); `ui/` components default to Server Components and only interactive leaves get `'use client'`. Don't re-export server-only modules from a slice `index.ts` that Client Components import — split into `index.ts` (client-safe) and `index.server.ts`.
- **React (Vite SPA):** the router config in `app/routes` lazy-imports `pages/*/index.ts`; `api/` segments export TanStack Query `queryOptions` and mutation hooks.

## AI Agent Guidance
- Identify the correct layer using the decision table before creating a file.
- Do: add to slice `index.ts` when something must be consumed elsewhere; compose via props/slots.
- Don't: import between sibling slices; don't create `processes/`; don't put domain logic in `shared`.
- Verify: `steiger ./src` (or boundary lint) passes, typecheck passes, no deep imports added (`grep -r "@/features/.*/" src | grep -v index`).

## Examples
```ts
// entities/product/api/productQueries.ts
import { queryOptions } from '@tanstack/react-query';
import { http } from '@/shared/api';
import type { Product } from '../model/types';
export const productQuery = (id: string) =>
  queryOptions({ queryKey: ['product', id], queryFn: () => http.get<Product>(`/products/${id}`) });
```
```ts
// features/add-to-cart/model/useAddToCart.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { http } from '@/shared/api';
export function useAddToCart() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (productId: string) => http.post('/cart/items', { productId }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['cart'] }),
  });
}
```

## Related Skills
- [frontend-architecture-principles](../frontend-architecture-principles/Skill.md) — underlying principles
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — slices as packages at scale
- [component-api-design](../component-api-design/Skill.md) — slot composition
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — `api` segment design
- [linting-and-formatting](../linting-and-formatting/Skill.md) — boundary enforcement
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — routing shell that composes slices
- [react-server-components](../react-server-components/Skill.md) — server/client split inside slices

## Sources
- [Feature-Sliced Design docs (v2.1)](https://feature-sliced.design/docs/get-started/overview) — Community methodology — layers, slices, segments, import rule, Steiger
- [FSD: Cross-imports with @x](https://feature-sliced.design/docs/reference/public-api) — Community — public API and cross-import notation
- [Steiger](https://github.com/feature-sliced/steiger) — Open Source — linter setup
- [eslint-plugin-boundaries](https://github.com/javierbrea/eslint-plugin-boundaries) — Open Source — generic enforcement

## License / Usage Notes
FSD documentation is MIT-licensed; this skill summarizes it. Tools referenced are MIT.

## Quality Tier
A — based on the official FSD methodology docs plus generic enforcement tooling; Next.js `pages` conflict note should be re-checked against current FSD guides.

## Status
Active

## Last Verified
2026-09-15
