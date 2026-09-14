# Frontend Build Tooling

## Summary
Choosing and configuring build tooling for React and Next.js in Sept 2026: Vite 8 (Rolldown + Oxc, stable since Mar 2026) for SPAs and libraries, Turbopack (default bundler in Next.js 16) for Next.js apps, Rsbuild/Rspack 2.x for webpack migrations and Module Federation hosts, and library bundlers (tsdown, Rslib, Vite library mode). Covers env handling, browser targets, source maps, code splitting, analysis, and migration notes flagging outdated webpack/CRA/esbuild-era guidance.

## Category
Tooling

## Subcategories
Vite, Rolldown, Oxc, Turbopack, Rspack, Rsbuild, library bundling, environment variables, source maps, browserslist/targets, bundle analysis, dev server

## Problem It Solves
Slow builds, dual-bundler inconsistencies (dev vs prod), leaked env vars, unnecessary polyfills, oversized bundles, and outdated setups (Create React App, custom webpack) slow teams and users. A modern, well-configured toolchain gives fast feedback, correct output, and small bundles.

## When To Use
- Starting a React SPA, component library, or Next.js app.
- Migrating off CRA, webpack, or Vite ≤ 7.
- Diagnosing slow builds, bundle bloat, or env leaks.

## When Not To Use
- Don't eject Next.js into custom webpack config unless a documented need exists; Turbopack is the default and most webpack plugins don't apply.
- Don't build a custom bundler pipeline for an app a framework already covers.

## Core Principles
1. **Let the framework own the build** (Next.js), or use Vite for SPA/library — avoid bespoke configs.
2. **Same bundler in dev and prod** where possible (Vite 8 unified on Rolldown; Next.js 16 on Turbopack).
3. **Transpile with the bundler, typecheck separately** (`tsc --noEmit`).
4. **Public env vars are public.** Only `VITE_*` / `NEXT_PUBLIC_*` reach the client, inlined at build.
5. **Target modern browsers;** avoid shipping legacy transforms/polyfills by default.
6. **Measure bundles on every PR** (size budgets).
7. **Source maps: generate, upload privately, don't expose publicly** unless intended.

## Best Practices
- CRA is deprecated (officially sunset in Feb 2025) — migrate to Vite or a framework.
- Vite 8: Node 20.19+ / 22.12+; Rolldown replaces esbuild+Rollup; Oxc handles TS/JSX transforms and minification; a compatibility layer auto-converts `esbuild` and `build.rollupOptions` config, but prefer the Rolldown/Oxc-native options going forward (check the migration guide for exact names). `@vitejs/plugin-react` v6 uses Oxc (no Babel) — add Babel only for React Compiler if required by your setup.
- Vite 8 new options: `resolve.tsconfigPaths` (opt-in), `devtools`, `server.forwardConsole`; WASM `?init` in SSR.
- Next.js 16: Turbopack is the default for `next dev` and `next build`; `--webpack` flag opts out when a webpack-only plugin is essential. Configure Turbopack via `turbopack` key in `next.config.ts` (loaders/aliases).
- Rsbuild 2.x / Rspack 2.x (Apr 2026; 2.2 Aug 2026): webpack-compatible API, ESM-first, Node 20+; best for large webpack migrations and Module Federation 2.0 hosts.
- Libraries: tsdown (Rolldown-based) or Rslib or Vite library mode; output ESM (+ CJS only if consumers need it), `.d.ts`, preserve `'use client'` directives, declare `sideEffects`.
- Browser targets: default modern baseline (Vite's default target is Baseline Widely Available-oriented); set explicit `build.target` only when you support older browsers, and add `@vitejs/plugin-legacy` only for real legacy traffic.
- Bundle analysis: `vite-bundle-analyzer`/`rollup-plugin-visualizer` (verify Rolldown compat), Next.js `next experimental-analyze` or `@next/bundle-analyzer` (webpack-only historically — check Turbopack analyzer support), `size-limit` in CI.
- Source maps: Vite `build.sourcemap: 'hidden'` + upload; Next.js `productionBrowserSourceMaps: false` (default) + vendor plugin uploads.
- Cache busting via content hashes is default; serve hashed assets with `Cache-Control: public, max-age=31536000, immutable`.

## Implementation Guidance

### Tool decision table
| Project | Tool (Sept 2026) | Notes |
|---|---|---|
| Next.js app | Next.js 16 built-in (Turbopack) | Don't add Vite/webpack |
| React SPA / dashboard | Vite 8 + `@vitejs/plugin-react` v6 | Rolldown build, fast HMR |
| React SPA with router framework | React Router framework mode or TanStack Start (Vite-based) | SSR/data loading |
| Large webpack app migration | Rsbuild 2 (or Rspack directly) | Webpack plugin compat |
| Module Federation host/remotes | Rsbuild/Rspack 2 or Vite 8 + MF 2.0 plugin | See micro-frontends |
| Component library | tsdown / Rslib / Vite lib mode | ESM + d.ts + directives |
| Legacy CRA | Migrate to Vite 8 | CRA deprecated |

### Vite 8 React SPA config
```ts
// vite.config.ts
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  return {
    plugins: [react()],
    resolve: { tsconfigPaths: true },
    server: { port: 5173, proxy: { '/api': { target: 'http://localhost:3000', changeOrigin: true } } },
    build: {
      sourcemap: 'hidden',
      // chunking: prefer defaults; customize only after analysis (check Rolldown advancedChunks / output options in Vite 8 docs)
    },
    define: { __RELEASE__: JSON.stringify(env.VITE_RELEASE ?? 'dev') },
  };
});
```

### Env variable exposure rules
| Tool | Client-exposed prefix | Server-only | Gotcha |
|---|---|---|---|
| Vite | `VITE_` (via `import.meta.env`) | Everything else (only in config/SSR) | Changing `envPrefix` to `''` leaks all vars |
| Next.js | `NEXT_PUBLIC_` (inlined at build) | All others (server runtime) | Values frozen at build; dynamic lookup `process.env[name]` isn't inlined |

### Next.js 16 config
```ts
// next.config.ts
import type { NextConfig } from 'next';
const config: NextConfig = {
  reactCompiler: true,               // if adopting React Compiler (verify stable flag location for your version)
  typedRoutes: true,
  transpilePackages: ['@acme/ui'],
  turbopack: {
    rules: { '*.svg': { loaders: ['@svgr/webpack'], as: '*.js' } },
  },
  productionBrowserSourceMaps: false,
};
export default config;
```

### Library build with tsdown
```ts
// tsdown.config.ts
import { defineConfig } from 'tsdown';
export default defineConfig({
  entry: ['src/index.ts', 'src/button/index.ts', 'src/dialog/index.ts'],
  format: ['esm'],
  dts: true,
  sourcemap: true,
  external: ['react', 'react-dom'],
  // ensure 'use client' banners survive: verify directive preservation option in current tsdown docs
});
```

### Size budget in CI
```json
// package.json
{
  "size-limit": [
    { "path": "dist/assets/index-*.js", "limit": "180 kB", "gzip": true }
  ],
  "scripts": { "size": "size-limit" }
}
```

## Recommended Workflow
1. Pick tool from the decision table; scaffold with official templates (`npm create vite@latest`, `create-next-app`).
2. Configure env handling and verify no secrets in client bundles (`grep` built assets for known secret names).
3. Set browser targets per analytics; avoid legacy plugin unless needed.
4. Configure source maps + private upload.
5. Add bundle analysis and size budgets to CI.
6. For migrations: run old and new builds side by side; compare bundle stats and E2E results.
7. Keep toolchain updated monthly (Renovate/Dependabot with cooldown).

## Patterns
- **Unified bundler dev/prod** (Vite 8, Turbopack) to avoid "works in dev" bugs.
- **Route-level lazy chunks** (`React.lazy`, `next/dynamic`) instead of manual chunk config.
- **Dev proxy** for API calls to avoid CORS configuration in development.
- **Hidden source maps + upload** in CI.
- **Per-component library entries** for tree-shaking.

## Anti-Patterns
- **Create React App / react-scripts** — deprecated. Fix: Vite 8.
- **Custom webpack config in Next.js 16 by default** — forces webpack path, slower. Fix: Turbopack config or remove.
- **Relying on esbuild-specific options/plugins in Vite 8** — now handled by Oxc/Rolldown compat layer, may be deprecated. Fix: migrate to native options per Vite 8 migration guide.
- **Manual `manualChunks` splitting everything into vendor chunks** — cache churn and waterfalls. Fix: defaults + route splitting; customize only with evidence.
- **Secrets in `VITE_`/`NEXT_PUBLIC_`** — shipped to users. Fix: server-side access only.
- **Public source maps in production** without intent — Fix: hidden + upload.
- **Polyfilling everything via `core-js` global import** — bloat. Fix: target modern browsers; targeted polyfills.
- **Babel for plain TS/JSX** — slow. Fix: Oxc/SWC; Babel only for specific plugins.

## Accessibility
- Build tooling doesn't make UI accessible, but can enforce it: wire `eslint-plugin-jsx-a11y` into dev overlays/CI and run axe in Storybook/E2E pipelines.
- Ensure HTML template (Vite `index.html`) sets `lang` and a meaningful `<title>`.

## Responsive Design
- Use image tooling appropriate to the stack: `next/image` in Next.js; in Vite, `vite-imagetools` or a CDN image service for responsive `srcset` generation.

## Performance
- Vite 8 Rolldown: large reductions in build time reported (e.g., Linear 46s -> 6s); dev server speed gains are smaller than build gains.
- Next.js Turbopack: faster dev startup/HMR and builds versus webpack.
- Output: minified with Oxc (Vite 8) / SWC or Turbopack minifier (Next), modern syntax, content-hashed files, CSS minified with Lightning CSS (Vite 8 bundles lightningcss).
- Enforce size budgets; analyze duplicates (multiple React/date libs).

## Security
- Env prefix discipline (see table); scan built output for secrets in CI (e.g., gitleaks on `dist/`).
- Pin toolchain versions via lockfile; toolchain packages run with full machine access at build — apply supply-chain controls (cooldowns, script allowlists).
- Dev servers: don't expose to network (`--host`) on untrusted networks; Vite has had dev-server file-serving CVEs — keep patched and use `server.fs.allow` defaults.

## Testing
- Vitest shares Vite config (Vitest 4 with Vite 8) — unit/component tests use the same transforms.
- Smoke test production build in CI (`vite build && vite preview` + Playwright; `next build && next start`).
- Compare bundle stats between main and PR (size-limit action, relative-ci).

## Tooling
- Vite 8.x — Active (Rolldown, Oxc; stable Mar 2026).
- `@vitejs/plugin-react` v6 — Active (Oxc-based).
- Next.js 16.3 Turbopack — Active (default).
- Rspack 2.2 / Rsbuild 2.2 — Active (Aug 2026).
- Rolldown — Active (Vite's bundler; usable standalone).
- tsdown — Active; Rslib — Active; tsup — maintenance direction (prefer tsdown for new libs; verify).
- webpack 5 — Maintenance; acceptable for existing apps, not for new ones.
- Create React App — Deprecated.
- Parcel 2 — Active but niche for React apps.
- esbuild — Active as a standalone tool; no longer Vite's internal bundler.

## Framework Notes
- **React (Vite SPA):** `index.html` is the entry; env via `import.meta.env.VITE_*`; configure SPA fallback on the host (all routes -> `index.html`); React Compiler via Babel plugin config in plugin-react if used (check v6 docs for compiler integration).
- **Next.js 16:** the build is framework-managed; customize via `next.config.ts` (`turbopack`, `transpilePackages`, `images`, `headers`, `experimental`); `output: 'standalone'` for Docker; `NEXT_PUBLIC_*` inlined at build so build per environment or use runtime config via server components/env at request time.

## AI Agent Guidance
- Identify the build tool from `package.json`/config files before editing; don't add a second bundler.
- Do: use framework-native config keys; keep env prefix rules; add lazy loading at route level; run production build locally before declaring done.
- Don't: introduce webpack config into Next.js 16 without need, add CRA, expose secrets via public prefixes, or hand-tune chunks without analysis.
- Verify: `build` succeeds, bundle size within budget, no secrets in output (`grep -r "sk_live\|SECRET" dist .next/static` returns nothing), preview/start serves the app.

## Examples
```bash
# Migrate CRA -> Vite 8 (outline)
npm remove react-scripts
npm i -D vite @vitejs/plugin-react
# move public/index.html -> ./index.html, add <script type="module" src="/src/main.tsx"></script>
# rename REACT_APP_* env vars to VITE_* and process.env.X -> import.meta.env.X
```
```tsx
// Route-level code splitting (Vite SPA with React Router)
const Reports = lazy(() => import('./pages/reports'));
<Route path="/reports" element={<Suspense fallback={<PageSkeleton />}><Reports /></Suspense>} />
```

## Related Skills
- [vite-react-spa](../vite-react-spa/Skill.md) — SPA specifics
- [react-nextjs-project-setup](../react-nextjs-project-setup/Skill.md) — scaffolding
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — builds across packages
- [bundle-optimization](../bundle-optimization/Skill.md) — reducing output size
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — splitting strategy
- [micro-frontends](../micro-frontends/Skill.md) — Module Federation builds
- [typescript-for-frontend](../typescript-for-frontend/Skill.md) — typecheck vs transpile

## Sources
- [Vite 8.0 announcement](https://vite.dev/blog/announcing-vite8) — Official — Rolldown/Oxc, Node reqs, new options, plugin-react v6
- [Vite 8 beta announcement](https://vite.dev/blog/announcing-vite8-beta) — Official — migration/compat layer
- [Announcing Rsbuild 2.0](https://rsbuild.rs/blog/v2-0) — Official — Rspack 2, ESM-first
- [Announcing Rspack 2.2](https://rspack.rs/blog/announcing-2-2) — Official — current version
- [Next.js docs: Turbopack](https://nextjs.org/docs/app/api-reference/turbopack) — Official — default bundler/config
- [Next.js: Environment variables](https://nextjs.org/docs/app/guides/environment-variables) — Official — NEXT_PUBLIC inlining
- [React blog: Sunsetting Create React App](https://react.dev/blog/2025/02/14/sunsetting-create-react-app) — Official — CRA deprecation

## License / Usage Notes
All referenced tools are MIT. Summarized from official docs; config examples original; option names flagged "verify" where docs were not fetched directly.

## Quality Tier
A — major version facts verified against official announcements; some Vite 8/Rolldown-native option names and analyzer compatibility need rechecking at use.

## Status
Active

## Last Verified
2026-09-15
