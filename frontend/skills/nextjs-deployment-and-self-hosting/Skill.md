# Next.js Deployment and Self-Hosting

## Summary
Next.js 16 deploys as a Node.js server (`next start`), a Docker container (typically `output: 'standalone'`), a static export (`output: 'export'`, limited), or via platform **adapters** built on the stable Adapter API (verified adapters: Vercel, Bun; Cloudflare and Netlify ship their own integrations; OpenNext powers Cloudflare/AWS). A single Node process supports every feature; multi-instance and serverless deployments need shared cache handlers, a stable Server Actions encryption key, `deploymentId` for version-skew protection, streaming-capable proxies, and graceful shutdown.

## Category
Next.js

## Subcategories
Vercel, self-hosting, Docker, standalone output, adapters, OpenNext, cache handlers, ISR, version skew, deploymentId, streaming proxies, static export, LTS policy

## Problem It Solves
Self-hosted apps that serve stale pages on some pods, break Server Actions after rolling deploys ("Failed to find Server Action"), lose streaming behind nginx, rebuild per environment and bake wrong `NEXT_PUBLIC_` values, or run unpatched versions after critical advisories.

## When To Use
- Choosing a hosting target for a Next.js app.
- Containerizing and running multiple instances behind a load balancer.
- Configuring caching/ISR persistence, CDN, and revalidation across instances.
- Planning upgrades within the LTS/security release cadence.

## When Not To Use
- CI pipeline design in general (see [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md)).
- CDN header theory (see [http-caching-and-cdn](../http-caching-and-cdn/Skill.md)).
- Database hosting/connection pooling (see [nextjs-database-integration](../nextjs-database-integration/Skill.md)).

## Core Principles
1. **Build once, promote many.** Same artifact across staging/production; runtime config via server env vars read at request time.
2. **Every instance must agree** on build/deployment ID, action encryption key, and cache state.
3. **Streaming must pass end-to-end** (load balancer, reverse proxy, CDN, compression).
4. **Put a reverse proxy in front** for TLS, slowloris/malformed request protection, payload limits, rate limiting.
5. **Patch promptly.** Follow Next.js security releases (Active LTS 16.3.x, Maintenance LTS 15.5.x as of Aug 2026).

## Best Practices
- Pin `deploymentId: process.env.DEPLOYMENT_VERSION` (skew protection: `?dpl=` on assets, `x-deployment-id` on navigations, hard reload on mismatch).
- Set `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (base64 16/24/32-byte AES key) at build for multi-instance hosts.
- Configure `cacheHandlers` (for `'use cache'` / `'use cache: remote'`) and, if using the previous model/ISR, `cacheHandler` + `cacheMaxMemorySize: 0`; implement `refreshTags` to propagate `revalidateTag` across instances.
- Disable proxy buffering: `X-Accel-Buffering: no` header (nginx); verify ALB/Lambda streaming modes.
- Handle `SIGTERM`/`SIGINT` with a 10–30s drain so in-flight requests and `after()` callbacks finish.
- Use `output: 'standalone'` for small Docker images; copy `public/` and `.next/static` into the image.
- Keep dev off Docker on macOS/Windows for performance; use Docker for prod parity tests.
- Use `assetPrefix` only when serving assets from a separate CDN domain.
- On Vercel, rely on native ISR/durable cache, skew protection, streaming, and Image Optimization; on Cloudflare use `@opennextjs/cloudflare` (supports Next 16, ISR, `'use cache'`; mind Worker size limits).

## Implementation Guidance

### Deployment options
| Target | Feature support | Notes |
|---|---|---|
| Node.js server (`next build && next start`) | All | Single instance works out of the box |
| Docker (standalone) | All | Configure shared cache + keys for replicas |
| Adapters (Vercel, Bun verified; Netlify, Cloudflare, Amplify, Firebase, Deno own integrations) | Varies / verified via test suite | Performance fidelity differs |
| Static export | Limited | No proxy, Server Actions, ISR, cookies, rewrites/redirects/headers, default image optimizer, intercepting routes |

### Multi-instance checklist
| Concern | Setting |
|---|---|
| Version skew | `deploymentId` |
| Server Action decryption | `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (stable) |
| Build ID consistency (if rebuilding per env) | `generateBuildId` (ignored when `deploymentId` set) |
| `'use cache'` sharing | `cacheHandlers` + `'use cache: remote'` |
| ISR/previous-model cache | `cacheHandler`, `cacheMaxMemorySize: 0` |
| Tag invalidation propagation | handler `refreshTags()` |
| Streaming | disable buffering at every hop |
| Graceful shutdown | SIGTERM + drain period |

### next.config for self-hosting
```ts
// next.config.ts
import type { NextConfig } from 'next'
const nextConfig: NextConfig = {
  output: 'standalone',
  deploymentId: process.env.DEPLOYMENT_VERSION,
  cacheComponents: true,
  cacheHandlers: {
    remote: require.resolve('./cache-handlers/redis.js'), // backs 'use cache: remote'
  },
  async headers() {
    return [{ source: '/:path*{/}?', headers: [{ key: 'X-Accel-Buffering', value: 'no' }] }]
  },
}
export default nextConfig
```
(Check the `cacheHandlers` reference for the exact handler interface and keys for your version; the vercel/next.js `examples/cache-handler-redis` shows a production starting point.)

### Dockerfile (standalone)
```dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile

FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ARG DEPLOYMENT_VERSION
ENV DEPLOYMENT_VERSION=$DEPLOYMENT_VERSION NEXT_TELEMETRY_DISABLED=1
# NEXT_SERVER_ACTIONS_ENCRYPTION_KEY supplied as a build secret, not hardcoded
RUN --mount=type=secret,id=actions_key \
    NEXT_SERVER_ACTIONS_ENCRYPTION_KEY=$(cat /run/secrets/actions_key) corepack enable && pnpm build

FROM node:22-alpine AS run
WORKDIR /app
ENV NODE_ENV=production PORT=3000 HOSTNAME=0.0.0.0
RUN addgroup -S app && adduser -S app -G app
COPY --from=build --chown=app:app /app/.next/standalone ./
COPY --from=build --chown=app:app /app/.next/static ./.next/static
COPY --from=build --chown=app:app /app/public ./public
USER app
EXPOSE 3000
CMD ["node", "server.js"]
```

### Runtime env in one image
```tsx
import { connection } from 'next/server'
export default async function Page() {
  await connection()                      // forces request-time evaluation
  const apiBase = process.env.API_BASE_URL // differs per environment
  return <Client apiBase={apiBase} />      // only non-secret values to client
}
```

### nginx streaming snippet
```nginx
location / {
  proxy_pass http://next_upstream;
  proxy_http_version 1.1;
  proxy_buffering off;         # streaming / PPR
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-Proto $scheme;
}
```

## Recommended Workflow
1. Decide target (Vercel/adapter vs Node/Docker vs static export) by feature needs and ops capacity.
2. Configure `output`, `deploymentId`, encryption key, cache handlers.
3. Build once in CI; tag image with commit SHA.
4. Deploy with rolling updates; health checks on a lightweight route handler.
5. Verify: streaming chunks arrive progressively, `revalidateTag` updates all instances, Server Actions survive a rolling deploy, skew triggers hard reload.
6. Subscribe to Next.js security releases; patch within days for critical advisories.

## Patterns
- **Vercel zero-config** with preview deployments per PR and skew protection.
- **Kubernetes + Redis cache handler** with `refreshTags` and stable keys.
- **OpenNext on Cloudflare Workers** with R2/KV incremental cache.
- **Static export to S3/nginx** for docs/marketing with `trailingSlash` and nginx `try_files`.
- **Blue/green with deploymentId** to avoid mixed-asset failures.

## Anti-Patterns
- **Rebuilding per environment** with different `NEXT_PUBLIC_` values — artifacts diverge. Fix: build once; read runtime config on the server.
- **Multiple pods with default in-memory/filesystem cache** — inconsistent pages. Fix: shared handler + tag coordination.
- **Random per-build action keys with rolling deploys** — "Failed to find Server Action". Fix: stable key + `deploymentId` + retry UI.
- **nginx default buffering** — no streaming, PPR shell delayed. Fix: `proxy_buffering off` / `X-Accel-Buffering: no`.
- **Exposing `next start` directly to the internet** — no protection against slow/malformed requests. Fix: reverse proxy/WAF.
- **Killing containers instantly** — lost `after()` work. Fix: SIGTERM drain.
- **Staying on unpatched 16.0.x/15.x** — React2Shell (Dec 2025) and Aug 2026 criticals. Fix: upgrade to latest patch in your line.
- **Mixed Pages+App Router on Windows servers without Cache Components on unpatched versions** — CVE-2026-75604 RCE. Fix: patch to 16.3.3/15.5.24+ or move to Linux.

## Accessibility
- Hard reloads triggered by version skew reset client state; persist form drafts (localStorage/URL) on critical flows so users don't lose input (WCAG 3.3.7 Redundant Entry spirit).
- Maintenance/error pages served by the reverse proxy must be accessible HTML with proper headings and language.

## Responsive Design
- Not deployment-specific; ensure CDN cache keys don't vary on device headers unless required.

## Performance
- Static shells should be served from CDN; dynamic holes from origin (performance fidelity depends on platform).
- Turbopack persistent build cache (default in 16.3) speeds CI rebuilds — cache `.next/cache` between CI runs.
- Tune `cacheMaxMemorySize` for single-instance; use remote handlers only when hit rates justify latency.
- Image optimization with sharp is CPU-heavy; consider a dedicated loader/CDN at scale.

## Security
- Secrets injected at runtime (not baked into images) except the action encryption key, which is embedded at build — pass via build secrets.
- Run containers as non-root; drop capabilities.
- `Cache-Control: private` is automatic for dynamic pages — don't override at CDN to cache personalized HTML.
- Draft Mode on self-host: every draft request hits origin and cookies can be spoofed — protect the enable endpoint with a strong secret.
- Track LTS and advisories: Dec 2025 RSC RCE (patched 16.0.7 / 15.x.y), Aug 2026 AVIF optimizer RCE and Windows RCE (patched 16.3.3 / 15.5.24); rotate secrets if exposed.

## Testing
- Smoke test against `next start` in CI (not `next dev`).
- Stream observer script (fetch with `Accept-Encoding: identity`, log chunk timings) through the full proxy chain.
- Multi-replica test: revalidate on pod A, read from pod B.
- Rolling-deploy test: open page on old build, deploy, submit a form.

## Tooling
- Vercel CLI; OpenNext (`@opennextjs/cloudflare`, AWS); Bun adapter.
- Docker official Next.js guides; vercel/next.js `examples/with-docker`, `with-docker-multi-env`, `cache-handler-redis`.
- `npx fix-react2shell-next` (vercel-labs) for the Dec 2025 advisory version bumps.

## Framework Notes
- v16.2: `adapterPath` stable top-level option; v16.3: immutable static assets reusable across deployments, persistent Turbopack build cache default.
- `next dev` and `next build` use separate output dirs (`.next/dev`) and a lockfile (v16).
- React (Vite SPA): deploy static `dist/` to any CDN; SPA fallback rewrite to `index.html`; no server features.

## AI Agent Guidance
- Ask/confirm the hosting target before adding config; don't add cache handlers for Vercel.
- For Docker: standalone output, non-root user, static assets copied, no secrets in layers.
- Before done: verify streaming through the proxy, `deploymentId` set, action key stable across replicas, Next.js at latest patched version in its line.

## Examples
```js
// Graceful shutdown wrapper (custom server or orchestrator-level)
process.on('SIGTERM', () => {
  console.log('SIGTERM received, draining…')
  // next start handles in-flight requests and pending after() callbacks;
  // orchestrator should allow terminationGracePeriodSeconds: 30
})
```

## Related Skills
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — cache semantics
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — runtime vs build env
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — streaming infra
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md) — static export trade-offs
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) — CI/CD
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) — CDN caching
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md) — patch management

## Sources
- [Deploying](https://nextjs.org/docs/app/getting-started/deploying) — Official — options table, adapters, verified adapters
- [Self-Hosting guide](https://nextjs.org/docs/app/guides/self-hosting) — Official — reverse proxy, caching, keys, deploymentId, streaming, after()
- [Rendering Philosophy](https://nextjs.org/docs/app/guides/rendering-philosophy) — Official — functional vs performance fidelity
- [Next.js 16.3](https://nextjs.org/blog/next-16-3) — Official — build cache, immutable assets
- [August 2026 Security Release](https://nextjs.org/blog/august-2026-security-release) — Official — LTS versions, CVEs
- [CVE-2025-66478 advisory](https://nextjs.org/blog/CVE-2025-66478) — Official — patched versions, secret rotation
- [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs) — Official (Vercel) — ISR, PPR, streaming, image optimization
- [OpenNext Cloudflare](https://opennext.js.org/cloudflare) — Open Source — Next 16 support, features, limits
- [Static exports](https://nextjs.org/docs/app/guides/static-exports) — Official — unsupported features

## License / Usage Notes
Next.js MIT; OpenNext MIT. Dockerfile and nginx snippets are original illustrations; verify `cacheHandlers` interface against the installed version's bundled docs.

## Quality Tier
A — Thorough and current; handler interface details intentionally deferred to the reference because they are version-sensitive.

## Status
Active

## Last Verified
2026-09-15
