# Upgrading to Next.js 16 (and 16.x Minors)

## Summary
Next.js 16 (Oct 2025) is the current major; 16.3 (Aug 2026) is the latest minor and Active LTS line (15.5 is Maintenance LTS). The upgrade removes Next.js 15's temporary compatibility shims (sync `params`/`cookies()`), renames middleware to proxy, makes Turbopack the default bundler, removes `next lint`, AMP, runtime config, and experimental PPR flags, changes `next/image` defaults, requires `default.tsx` for parallel slots, and changes `revalidateTag` to require a cache profile. This skill is a practical checklist with codemods, verification steps, and 16.1–16.3 adoption notes.

## Category
Next.js

## Subcategories
Upgrade guide, codemods, breaking changes, Turbopack migration, async request APIs, proxy rename, image defaults, ESLint flat config, React 19.2, React Compiler, LTS policy, AI-agent upgrade flow

## Problem It Solves
Failed builds after `npm install next@latest`, silent behavior changes (image quality coercion, scroll behavior, cache TTL), webpack configs breaking Turbopack builds, lint no longer running in `next build`, and agents applying pre-16 patterns.

## When To Use
- Upgrading any 13–15 app to 16.x.
- Moving between 16 minors (16.0 → 16.3) and adopting new defaults.
- Auditing an app/codebase for deprecated APIs.

## When Not To Use
- Pages → App Router architectural migration (see [nextjs-pages-to-app-router-migration](../nextjs-pages-to-app-router-migration/Skill.md)).
- Adopting Cache Components (optional, separate step — see [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md)).

## Core Principles
1. **Mechanical first, then behavioral.** Run codemods, fix build, then review behavior changes.
2. **Upgrade framework and adopt new models separately.** Don't combine the v16 upgrade with enabling `cacheComponents` in one PR.
3. **Point agents at version-matched docs** (`node_modules/next/dist/docs/` via AGENTS.md).
4. **Verify in production mode** (`next build && next start`), not only dev.
5. **Stay on a patched LTS line** (latest 16.3.x).

## Best Practices
- Prereqs: Node.js ≥20.9, TypeScript ≥5.1, browsers Chrome/Edge/Firefox 111+, Safari 16.4+; update `@types/react`/`@types/react-dom`.
- Run `npx @next/codemod@canary upgrade latest` (turbopack config move, next lint → ESLint CLI, middleware → proxy, `unstable_` prefix removal, `experimental_ppr` removal).
- Then run `npx @next/codemod@canary next-async-request-api .` if any sync request API access remains.
- Run `npx next typegen` and adopt `PageProps`/`LayoutProps`/`RouteContext`.
- Decide Turbopack vs webpack: custom `webpack` config fails `next build` under Turbopack; migrate loaders to `turbopack.rules`/`resolveAlias` or temporarily use `--webpack`.
- Replace Sass `~` imports; add `turbopack.resolveAlias` fallbacks only as a last resort.
- Add lint to CI explicitly (`eslint .`) since `next build` no longer lints; migrate to flat config.
- Review image config: add needed `qualities`, `localPatterns.search`, `imageSizes` 16 if used; replace `priority` with `preload`; replace `images.domains`.
- Add `default.tsx` to every parallel route slot.
- Replace `revalidateTag(tag)` with `revalidateTag(tag, 'max')` or `updateTag(tag)` (Server Actions).
- Replace `serverRuntimeConfig`/`publicRuntimeConfig` with env vars (+ `connection()` for runtime reads).
- Add `data-scroll-behavior="smooth"` to `<html>` only if you relied on the old smooth-scroll override.
- If you used experimental PPR on 15 canary, stay there until migrating to Cache Components (behavior differs).
- Keep `middleware.ts` only if you need Edge runtime; `proxy.ts` is Node-only.

## Implementation Guidance

### Breaking changes checklist
| Area | Change | Action |
|---|---|---|
| Runtime | Node 20.9+, TS 5.1+ | Upgrade toolchain/CI images |
| Request APIs | Sync `params`, `searchParams`, `cookies()`, `headers()`, `draftMode()` removed | `await`; codemod; typegen |
| Metadata images | `opengraph-image`/`icon` `params` and `id` are Promises; sitemap `id` Promise | `await params`, `await id` |
| Middleware | Renamed `proxy.ts`, `export function proxy`, Node runtime | Codemod; move edge needs |
| Config flags | `skipMiddlewareUrlNormalize` → `skipProxyUrlNormalize` | Codemod |
| Bundler | Turbopack default for dev/build | Migrate webpack config or `--webpack` |
| Turbopack config | `experimental.turbopack` → top-level `turbopack` | Codemod |
| Lint | `next lint` removed; `eslint` config key removed; flat config default | `next-lint-to-eslint-cli` codemod; CI lint step |
| Caching APIs | `revalidateTag` needs profile; `updateTag`, `refresh` added; `cacheLife`/`cacheTag` stable | Update calls/imports |
| PPR | `experimental.ppr`, `experimental_ppr` removed; `dynamicIO`/`useCache` → `cacheComponents` | Remove or adopt Cache Components |
| Parallel routes | `default.js` required per slot | Add files |
| Images | `qualities` `[75]`, `minimumCacheTTL` 4h, no 16px, `localPatterns` for query strings, local IP blocked, max 3 redirects, `priority` deprecated, `domains` deprecated, `next/legacy/image` deprecated | Review config/props |
| Removed | AMP, runtime config, `devIndicators` sub-options, `unstable_rootParams` | Remove; use env; `next/root-params` (16.3) |
| Scroll | No automatic smooth-scroll override | `data-scroll-behavior="smooth"` if needed |
| Build output | Size/First Load JS columns removed | Use analyzer/Lighthouse |
| Dev | `.next/dev` separate dir, lockfile; config loaded once (`process.argv` lacks `dev`) | Use `NODE_ENV`/phase in config side effects |
| Sass | sass-loader v16; no `~` imports in Turbopack | Update imports |

### Commands
```bash
# 0. Agent docs (optional but recommended before editing)
npx @next/codemod@canary agents-md          # for <=16.1; 16.3 `next dev` writes AGENTS.md automatically

# 1. Upgrade + mechanical codemods
npx @next/codemod@canary upgrade latest
npx @next/codemod@canary next-async-request-api .
npx @next/codemod@canary middleware-to-proxy .
npx @next/codemod@canary next-lint-to-eslint-cli .

# 2. Types
npx next typegen

# 3. Verify
npx tsc --noEmit && npx eslint . && npx next build && npx next start
```

### Common code updates
```tsx
// Before (15)
export default function Page({ params }: { params: { slug: string } }) {
  return <h1>{params.slug}</h1>
}
// After (16)
export default async function Page(props: PageProps<'/blog/[slug]'>) {
  const { slug } = await props.params
  return <h1>{slug}</h1>
}
```
```ts
// Before
import { unstable_cacheLife as cacheLife } from 'next/cache'
revalidateTag('posts')
// After
import { cacheLife, updateTag, revalidateTag } from 'next/cache'
revalidateTag('posts', 'max') // or updateTag('posts') inside a Server Action
```
```ts
// next.config.ts — webpack loader → Turbopack rule example (SVGR)
const nextConfig = {
  turbopack: {
    rules: { '*.svg': { loaders: ['@svgr/webpack'], as: '*.js' } },
  },
}
```
```tsx
// app/@modal/default.tsx
export default function Default() { return null }
```

### 16.x minor adoption notes
| Version | Worth adopting |
|---|---|
| 16.1 (Dec 2025) | Turbopack FS cache for dev stable; `next experimental-analyze`; `next dev --inspect` |
| 16.2 (Mar 2026) | Faster dev startup/rendering; bundled docs in `node_modules/next/dist/docs`; `adapterPath` stable |
| 16.3 (Aug 2026) | Dev memory eviction, persistent build cache (default), TS 7 type-checking, ~22% SSR throughput, `catchError`, `next/root-params`, `import.meta.glob`, AGENTS.md auto-generation, Instant Navigations (opt-in), experimental Rust React Compiler and `useOffline` |
| 16.3.3 (Aug 25, 2026) | Security: AVIF optimizer RCE (AVIF optimization disabled), Windows mixed-router RCE |

## Recommended Workflow
1. Create an upgrade branch; ensure green tests on current version.
2. Upgrade Node/TS in CI and local.
3. Set up AGENTS.md pointing to bundled docs (if using agents).
4. Run codemods; commit mechanical changes separately.
5. Fix type errors (`typegen`), build errors (Turbopack, default.tsx, images).
6. Review behavioral changes (images, scroll, caching APIs, lint in CI).
7. Test in production mode: E2E, visual regression, Lighthouse.
8. Deploy to staging; monitor errors (image 400s, action failures).
9. Afterwards, consider Cache Components / Instant Navigations in separate PRs.

## Patterns
- **Agent-driven upgrade** using the official prompt: read AGENTS.md docs, run codemods, explain plan, verify with `next-dev-loop` skill.
- **Two-PR upgrade:** PR1 codemods + build fixes; PR2 behavior review and config tuning.
- **Temporary webpack fallback:** `next build --webpack` while migrating loaders, with a tracked issue to remove.

## Anti-Patterns
- **Enabling `cacheComponents` during the major upgrade** — compounding errors. Fix: separate step.
- **Assuming `next build` lints** — silent lint regressions. Fix: explicit CI lint.
- **Keeping `images.qualities` unset with `quality={90}` props** — coerced to 75 silently. Fix: configure qualities.
- **Leaving `middleware.ts` and adding `proxy.ts`** — only one should exist; confusion. Fix: codemod rename.
- **Pinning to 16.0.x** — missing critical security fixes (RSC RCE fixed 16.0.7; Aug 2026 fixes in 16.3.3). Fix: latest 16.3.x.
- **Checking `process.argv.includes('dev')` in next.config** — false in 16. Fix: `NODE_ENV` or `phase`.
- **Copying pre-16 tutorials/agent memory** (`priority`, `domains`, sync params). Fix: bundled docs.

## Accessibility
- Upgrade is a good time to run automated a11y checks; behavioral changes (scroll behavior, preserved UI state if adopting Cache Components) can affect focus and scroll position after navigation — verify keyboard flows.

## Responsive Design
- Image default changes (`imageSizes`, `qualities`) can alter delivered image sharpness at small sizes; visually check thumbnails/icons across breakpoints.

## Performance
- Turbopack: 2–5× faster builds, up to 10× faster Fast Refresh; 16.3 persistent cache speeds CI (cache `.next/cache`).
- React Compiler (`reactCompiler: true`) is stable but increases compile time (Babel); Rust version experimental in 16.3.
- Re-measure with analyzer/Lighthouse since build size columns were removed.

## Security
- Image optimizer defaults are safer (local IP blocked, limited redirects, localPatterns) — don't revert them casually.
- Patch cadence: Active LTS 16.3.x, Maintenance LTS 15.5.x; apply security releases immediately.
- After upgrading from vulnerable versions that were internet-facing, rotate secrets per advisories.

## Testing
- Full E2E and visual regression suites on `next start`.
- Specific checks: parallel route pages load on refresh, images render at expected quality, redirects/rewrites via proxy still match, Server Actions work after deploy.
- CI matrix on Node 20.9+ and 22.

## Tooling
- `@next/codemod` (upgrade, next-async-request-api, middleware-to-proxy, next-lint-to-eslint-cli, remove-experimental-ppr, cache-components-instant-false).
- `next typegen`, `next experimental-analyze`, Next.js DevTools MCP.
- Next.js Skills: `next-dev-loop` (verification), adoption skills for later steps.

## Framework Notes
- React 19.2 features available: `<ViewTransition>`, `useEffectEvent`, `<Activity>`.
- Pages Router apps also receive v16 breaking changes that apply (image defaults, Node version, lint removal, AMP removal).
- React (Vite SPA): not applicable; if the SPA consumes a Next.js backend, re-test API routes/handlers after upgrade.

## AI Agent Guidance
- Read AGENTS.md / bundled docs first; follow the official upgrade guide as source of truth.
- Explain the plan briefly, run codemods, keep scope to the upgrade, inspect the diff, run checks.
- Before done: `tsc`, `eslint`, `next build`, and E2E pass; summary lists what changed, what was verified, and what could not be verified; Next.js version is the latest patched 16.3.x.

## Examples
```json
// package.json after upgrade
{
  "engines": { "node": ">=20.9.0" },
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint .",
    "typegen": "next typegen"
  }
}
```

## Related Skills
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — v16 conventions
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — proxy rename
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — image default changes
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — caching API changes
- [linting-and-formatting](../linting-and-formatting/Skill.md) — ESLint flat config
- [frontend-build-tooling](../frontend-build-tooling/Skill.md) — Turbopack/webpack
- [agents-md-conventions](../agents-md-conventions/Skill.md) — AGENTS.md for version-matched docs
- [react-nextjs-project-setup](../react-nextjs-project-setup/Skill.md) — baseline project config

## Sources
- [How to upgrade to version 16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — full breaking change list, codemods, agent prompt
- [Next.js 16 release](https://nextjs.org/blog/next-16) — Official — features, removals, deprecations, behavior changes
- [Next.js 16.3 release](https://nextjs.org/blog/next-16-3) — Official — minor features
- [Next.js blog index](https://nextjs.org/blog) — Official — 16.1/16.2 summaries, release dates
- [AI coding agents guide](https://nextjs.org/docs/app/guides/ai-agents) — Official — AGENTS.md, bundled docs, skills
- [August 2026 Security Release](https://nextjs.org/blog/august-2026-security-release) — Official — LTS lines and critical fixes
- [CVE-2025-66478 advisory](https://nextjs.org/blog/CVE-2025-66478) — Official — 16.0.7 fix

## License / Usage Notes
Next.js MIT. Checklist condensed from official upgrade guide and release posts; the SVGR Turbopack rule is a common community configuration — verify against the Turbopack config reference.

## Quality Tier
S — Exhaustive, version-precise checklist verified against the official upgrade guide and release notes through 16.3.3.

## Status
Active

## Last Verified
2026-09-15
