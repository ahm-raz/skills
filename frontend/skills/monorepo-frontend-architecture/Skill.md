# Monorepo Frontend Architecture

## Summary
Structuring multiple React/Next.js apps and shared packages in one repository with pnpm workspaces and a task runner (Turborepo 2.x or Nx 23.x): package boundaries, internal package strategies (source vs compiled), TypeScript configuration, caching, affected builds, dependency policy, and CI. Verified against Turborepo 2.10.x, Nx 23.2, and pnpm 11 as of Sept 2026.

## Category
Tooling

## Subcategories
pnpm workspaces, catalogs, Turborepo, Nx, internal packages, remote caching, affected builds, module boundaries, TypeScript project config

## Problem It Solves
Multiple apps (marketing Next.js site, dashboard Next.js app, Vite admin SPA) duplicate UI, configs, and API clients across repos; cross-repo changes require coordinated releases; CI rebuilds everything. A monorepo with explicit package boundaries and cached, affected-only tasks enables atomic changes and fast CI.

## When To Use
- Two or more apps sharing UI components, tokens, API clients, or configs.
- A design system developed alongside its consumers.
- Teams wanting atomic cross-package refactors.

## When Not To Use
- A single app: use feature folders instead.
- Teams needing strict access isolation or independent release cadence with separate compliance — polyrepo may be simpler.
- When you'd need micro-frontends for runtime independence — a monorepo solves code sharing, not deployment independence (though they combine).

## Core Principles
1. **Apps consume packages; packages never import apps.**
2. **Every package has an explicit public API** via `exports` in `package.json`.
3. **Dependencies declared where used** (no phantom deps from root hoisting); pnpm's strictness enforces this.
4. **Tasks are cached and hermetic:** declare inputs/outputs/env so cache hits are correct.
5. **Only build/test what changed** (affected graph).
6. **Enforce boundaries with tags/rules**, not convention.
7. **Single version policy** for framework deps (React, Next, TypeScript) via catalogs.

## Best Practices
- Layout: `apps/*` (deployables) and `packages/*` (libraries/configs). Common packages: `ui`, `tokens`, `api-client`, `eslint-config`, `typescript-config`, `utils`.
- Use pnpm workspaces with **catalogs** to pin shared versions once:
  ```yaml
  # pnpm-workspace.yaml
  packages: ["apps/*", "packages/*"]
  catalog:
    react: ^19.2.0
    react-dom: ^19.2.0
    next: ^16.3.0
    typescript: ^6.0.0
  minimumReleaseAge: 1440
  ```
  Then `"react": "catalog:"` in each package.json.
- Internal package strategies:
  | Strategy | How | Pros | Cons |
  |---|---|---|---|
  | Just-in-time (source) | `exports` point to `.ts/.tsx`; consumer bundler compiles | Zero build step, fast | Consumer must transpile (Next `transpilePackages`), no per-package cache of builds |
  | Compiled | tsup/tsdown/Rslib/Vite lib mode to `dist` | Cacheable, publishable, faster consumer builds | Build step, watch mode needed |
  | Publishable | Compiled + Changesets + npm | External consumers | Release process |
- Next.js apps consuming source packages: add them to `transpilePackages` in `next.config.ts`.
- Use `workspace:*` protocol for internal deps.
- Shared configs as packages: `@acme/typescript-config/nextjs.json`, `@acme/eslint-config` (flat config export).
- Declare env vars per task in `turbo.json` (`env`) so caches don't leak across environments; Turborepo strict env mode filters undeclared vars.
- Enable remote caching (Vercel Remote Cache, Nx Cloud, or self-hosted) with signed artifacts where supported.
- CI: `turbo run build test lint --affected` (Turborepo) or `nx affected -t build test lint` (Nx).
- Enforce boundaries: Nx `@nx/enforce-module-boundaries` with `scope:`/`type:` tags (stable); Turborepo `boundaries` with tags (experimental in 2.x) or eslint-plugin-boundaries/dependency-cruiser.
- Avoid TypeScript project references complexity unless using compiled packages with `tsc -b`; for source packages, rely on each app's typecheck plus per-package `tsc --noEmit`.

## Implementation Guidance

### Turborepo vs Nx decision table
| Need | Turborepo 2.x | Nx 23.x |
|---|---|---|
| Minimal config, JS/TS only | Strong | Good |
| Code generators, migrations | Minimal | Strong (`nx migrate`, generators) |
| Module boundary lint | Experimental `turbo boundaries` | Mature ESLint rule + Conformance |
| Distributed task execution | Via CI splitting | Nx Agents (Nx Cloud) |
| Project graph visualization | `turbo query`/graph | Rich graph UI |
| Polyglot (Java/.NET) | No | Yes (Maven, .NET plugins) |
| Vercel deployment integration | Native | Works |

### Turborepo `turbo.json`
```json
{
  "$schema": "https://turborepo.dev/schema.json",
  "ui": "tui",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["$TURBO_DEFAULT$", ".env*"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"],
      "env": ["NEXT_PUBLIC_API_URL"]
    },
    "typecheck": { "dependsOn": ["^build"] },
    "lint": {},
    "test": { "dependsOn": ["^build"], "outputs": ["coverage/**"] },
    "dev": { "cache": false, "persistent": true }
  }
}
```

### Internal UI package (source strategy)
```json
{
  "name": "@acme/ui",
  "private": true,
  "type": "module",
  "exports": {
    "./button": "./src/button.tsx",
    "./dialog": "./src/dialog.tsx",
    "./styles.css": "./src/styles.css"
  },
  "peerDependencies": { "react": "catalog:" },
  "devDependencies": { "@acme/typescript-config": "workspace:*", "typescript": "catalog:" }
}
```
```ts
// apps/web/next.config.ts
import type { NextConfig } from 'next';
const config: NextConfig = { transpilePackages: ['@acme/ui', '@acme/api-client'] };
export default config;
```
Prefer per-component subpath exports over a root barrel for tree-shaking and faster dev compilation.

### Shared tsconfig
```json
// packages/typescript-config/base.json
{
  "compilerOptions": {
    "strict": true, "target": "ES2022", "module": "ESNext", "moduleResolution": "Bundler",
    "jsx": "react-jsx", "isolatedModules": true, "noUncheckedIndexedAccess": true,
    "verbatimModuleSyntax": true, "skipLibCheck": true, "types": []
  }
}
```

### Nx boundary tags (project.json or package.json "nx" field)
```json
{ "name": "ui", "tags": ["scope:shared", "type:ui"] }
```
Constraint example: `type:app` may depend on `type:feature|ui|util`; `type:ui` only on `type:ui|util`.

## Recommended Workflow
1. Create workspace: `apps/`, `packages/`, `pnpm-workspace.yaml` with catalogs and supply-chain settings.
2. Extract shared configs (tsconfig, eslint, prettier/biome) into packages.
3. Move apps in one at a time (preserve git history with `git subtree`/filter-repo if needed).
4. Extract shared UI/api-client packages with explicit `exports`.
5. Configure Turborepo/Nx tasks with inputs/outputs/env; enable remote cache.
6. Add boundary enforcement and affected-only CI.
7. Measure CI time and cache hit rate; tune inputs.

## Patterns
- **Config packages:** `@acme/eslint-config` exporting flat config arrays; apps compose.
- **Catalog-pinned framework versions** to prevent React duplicates.
- **App-specific wrappers:** `apps/web/src/components/ui` re-exports `@acme/ui` with app defaults, avoiding app-specific code in the shared package.
- **Generated API client package** (`@acme/api-client` from OpenAPI) consumed by all apps.
- **Affected + remote cache CI** with nightly full build for cache warming.

## Anti-Patterns
- **Importing across apps** (`apps/admin` imports `apps/web/src/...`) — Fix: extract a package.
- **Root-level dependencies used by packages** (phantom deps) — Fix: declare per package; pnpm strict mode.
- **Multiple React copies** (mismatched versions) — invalid hook call errors. Fix: catalogs + `peerDependencies`.
- **Undeclared env vars in cached tasks** — wrong artifacts served. Fix: `env`/`globalEnv` in turbo.json; strict env mode.
- **One giant `@acme/shared` package** — everything rebuilds on any change. Fix: small focused packages.
- **Root barrel exports in UI package** — slow Next dev compile and poor tree-shaking. Fix: subpath exports.
- **Caching `dev`** — Fix: `cache: false, persistent: true`.

## Accessibility
- Centralize accessible primitives in `@acme/ui` and share `eslint-plugin-jsx-a11y` config via the eslint-config package so every app enforces the same rules.
- Run axe checks in the shared Storybook for packages; app-level E2E a11y per app.

## Responsive Design
- Shared UI components should rely on container queries so apps with different layouts reuse them.

## Performance
- Remote cache + affected graph are the main CI levers; track cache hit rate.
- Subpath exports and `sideEffects` declarations keep app bundles lean.
- Turbopack (Next.js 16 default bundler for dev/build) handles workspace source packages; verify `transpilePackages` for non-standard packages.

## Security
- pnpm 11: `minimumReleaseAge` (default 1440 min), `allowBuilds` allowlist for lifecycle scripts, `blockExoticSubdeps: true`, `trustPolicy: no-downgrade`.
- Remote cache poisoning: use signed artifacts (Turborepo `signature: true` with `TURBO_REMOTE_CACHE_SIGNATURE_KEY`) and read-only cache tokens for untrusted PR builds.
- CODEOWNERS per package.

## Testing
- Per-package Vitest with workspace projects (`vitest.config.ts` `projects: ['packages/*', 'apps/*']`).
- Typecheck every package in CI (`turbo run typecheck --affected`).
- E2E per app with Playwright; run only for affected apps.

## Tooling
- pnpm 11 — Active (workspaces, catalogs, supply-chain defaults).
- Turborepo 2.10.x — Active; `boundaries` Experimental.
- Nx 23.2 — Active (Sept 2026); `@nx/enforce-module-boundaries`, Nx Agents, Conformance.
- Changesets — Active (publishable packages).
- tsdown / tsup / Rslib — Active library bundlers (tsup is in maintenance-mode direction in favor of tsdown; verify).
- syncpack / sherif — Active (version consistency lint).
- Lerna — maintained by Nx team; use only for publishing legacy setups.

## Framework Notes
- **Next.js 16:** `transpilePackages` for source packages; output `standalone` for Docker needs `outputFileTracingRoot` set to the monorepo root so workspace deps are traced. Env vars: `NEXT_PUBLIC_*` inlined at build — declare in turbo `env` to key caches correctly.
- **React (Vite 8 SPA):** Vite resolves workspace source packages natively via `exports`; use `resolve.tsconfigPaths` (Vite 8, opt-in) only if you rely on TS path aliases rather than package exports.
- **Mixed apps:** keep shared UI server-compatible (no browser globals at module scope) so both Next.js RSC and Vite SPA can import it.

## AI Agent Guidance
- Run tasks through the task runner (`pnpm turbo run build --filter=web...` or `nx run web:build`), not ad hoc scripts, so caching and dependency order apply.
- Do: add dependencies to the specific package (`pnpm add zod --filter @acme/api-client`); use `catalog:` for framework deps; export new modules via `exports`.
- Don't: import from another app; import package internals (`@acme/ui/src/internal`); add root dependencies for package code.
- Verify: `pnpm install` passes without new build-script approvals you didn't intend, `turbo run typecheck lint test --affected` passes, boundary checks pass.

## Examples
```yaml
# .github/workflows/ci.yml (excerpt)
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: 24, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm turbo run lint typecheck test build --affected
        env:
          TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
          TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```
```js
// packages/eslint-config/next.js — shared flat config
import next from '@next/eslint-plugin-next';
import tseslint from 'typescript-eslint';
export default [
  ...tseslint.configs.recommended,
  { plugins: { '@next/next': next }, rules: { ...next.configs.recommended.rules, ...next.configs['core-web-vitals'].rules } },
];
```

## Related Skills
- [frontend-build-tooling](../frontend-build-tooling/Skill.md) — bundlers inside packages
- [micro-frontends](../micro-frontends/Skill.md) — runtime composition
- [linting-and-formatting](../linting-and-formatting/Skill.md) — shared configs
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md) — pnpm hardening
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) — CI setup
- [design-system-architecture](../design-system-architecture/Skill.md) — shared UI package
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) — standalone output in monorepos

## Sources
- [Turborepo: Configuring turbo.json](https://turborepo.dev/docs/reference/configuration) — Official — tasks, env, outputs
- [Turborepo: Boundaries](https://turborepo.dev/docs/reference/boundaries) — Official — experimental tags/rules
- [Nx: Enforce module boundaries](https://nx.dev/docs/features/enforce-module-boundaries) — Official — depConstraints
- [Nx 23 release](https://nx.dev/blog/nx-23-release) — Official — current version features
- [pnpm: Mitigating supply chain attacks](https://pnpm.io/supply-chain-security) — Official — pnpm 11 settings
- [pnpm catalogs](https://pnpm.io/catalogs) — Official — version catalogs
- [Next.js transpilePackages](https://nextjs.org/docs/app/api-reference/config/next-config-js/transpilePackages) — Official

## License / Usage Notes
Summarized from official docs; config examples are original. Turborepo MIT, Nx MIT, pnpm MIT.

## Quality Tier
A — official docs for all tools, versions verified Sept 2026; some flags (signature, tsup status) should be re-verified at adoption.

## Status
Active

## Last Verified
2026-09-15
