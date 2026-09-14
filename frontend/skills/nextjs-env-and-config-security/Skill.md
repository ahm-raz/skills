# Next.js Environment Variables and Config Security

## Summary
Next.js loads `.env*` files into `process.env` on the server; only variables prefixed `NEXT_PUBLIC_` are inlined into client bundles **at build time** (dynamic lookups are not inlined). `serverRuntimeConfig`/`publicRuntimeConfig` were removed in v16 — use env vars, reading runtime values after `await connection()`. Secure configuration also covers `next.config` hardening (security headers, CSP, image allowlists, `serverActions.allowedOrigins`, `poweredByHeader`), `server-only` boundaries, taint APIs, the Server Actions encryption key, and prompt patching of security advisories.

## Category
Next.js

## Subcategories
.env files, NEXT_PUBLIC_, runtime vs build-time env, @next/env, connection(), server-only, taint, next.config security headers, CSP, image security config, Server Actions config, secrets rotation, advisories

## Problem It Solves
Secrets exposed by `NEXT_PUBLIC_` misuse or client imports of server modules, wrong values baked into a Docker image promoted across environments, removed runtime config breaking on upgrade, missing security headers, over-permissive image optimizer config, and unpatched frameworks after critical CVEs.

## When To Use
- Adding any environment variable or secret.
- Building one artifact for multiple environments.
- Hardening `next.config` before production.
- Security review/audit of a Next.js codebase.

## When Not To Use
- Designing CSP policies in depth (see [content-security-policy](../content-security-policy/Skill.md)).
- Secrets management platforms and CI secret handling (see [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md)).
- Auth session secrets usage (see [nextjs-authentication](../nextjs-authentication/Skill.md)).

## Core Principles
1. **Server-only by default.** A variable without `NEXT_PUBLIC_` must never be needed in the browser.
2. **`NEXT_PUBLIC_` = public and frozen at build.** Treat every such value as visible to anyone.
3. **Only the Data Access Layer reads secrets,** in `server-only` modules.
4. **Build once, configure at runtime** for server values; never rebuild per environment just for server config.
5. **Defense in depth:** DTOs + `server-only` + taint + headers + patched dependencies.
6. **Never commit `.env*.local` or secrets;** `.env.test` may be committed if it holds no secrets.

## Best Practices
- Validate env at startup with zod (`lib/env.ts`, `server-only`) and fail fast on missing values; keep a separate `publicEnv` object for `NEXT_PUBLIC_*`.
- Access public vars with literal `process.env.NEXT_PUBLIC_X` (destructuring/dynamic keys are not inlined).
- For per-environment values in a single Docker image: read `process.env` on the server after `await connection()` (or inside request-time code) and pass non-secret values to the client as props.
- Use `@next/env` `loadEnvConfig(process.cwd())` for ORM configs, test runners, and scripts.
- Keep `.env*` at project root even with `src/`.
- Set `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (base64 AES 16/24/32 bytes) for multi-instance deploys; generate with `openssl rand -base64 32`; store as a secret.
- Configure security headers in `next.config` `headers()` (static CSP) or proxy (nonce CSP).
- Disable `X-Powered-By` with `poweredByHeader: false`.
- Enable `experimental.taint` and taint secrets/tokens that must never reach the client.
- Subscribe to Next.js/React advisories; patch within days; rotate secrets after exposure windows.

## Implementation Guidance

### Load order (first match wins)
1. `process.env`
2. `.env.$(NODE_ENV).local`
3. `.env.local` (skipped when `NODE_ENV=test`)
4. `.env.$(NODE_ENV)`
5. `.env`

`NODE_ENV` allowed: `production`, `development`, `test`. `$VAR` expansion supported (escape `\$`).

### Build-time vs runtime
| Variable | Available | When evaluated |
|---|---|---|
| `SECRET_X` in Server Component/Action/Handler | Server | Build (if prerendered) or request |
| `SECRET_X` after `await connection()` | Server | Request time |
| `NEXT_PUBLIC_X` literal access | Server + client | Build (inlined) |
| `process.env[name]` dynamic | Server only | Runtime; not inlined for client |
| `serverRuntimeConfig`/`publicRuntimeConfig` | — | Removed in v16 |

### Validated env module
```ts
// lib/env.ts
import 'server-only'
import { z } from 'zod'

const ServerEnv = z.object({
  DATABASE_URL: z.url(),
  SESSION_SECRET: z.string().min(32),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  NODE_ENV: z.enum(['development', 'test', 'production']),
})
export const env = ServerEnv.parse(process.env)
```
```ts
// lib/public-env.ts (safe for client)
export const publicEnv = {
  siteUrl: process.env.NEXT_PUBLIC_SITE_URL!,         // literal access → inlined
  analyticsId: process.env.NEXT_PUBLIC_ANALYTICS_ID,
} as const
```

### Runtime config for one image
```tsx
// app/(app)/layout.tsx
import { Suspense } from 'react'
import { connection } from 'next/server'
import { ConfigProvider } from './config-provider'

export default function AppLayout({ children }: LayoutProps<'/'>) {
  return <Suspense fallback={null}><RuntimeConfig>{children}</RuntimeConfig></Suspense>
}
async function RuntimeConfig({ children }: { children: React.ReactNode }) {
  await connection()
  const config = { apiBaseUrl: process.env.API_BASE_URL ?? '', featureX: process.env.FEATURE_X === 'on' } // non-secret only
  return <ConfigProvider value={config}>{children}</ConfigProvider>
}
```

### Hardened next.config
```ts
// next.config.ts
import type { NextConfig } from 'next'

const securityHeaders = [
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  { key: 'X-Frame-Options', value: 'DENY' }, // or CSP frame-ancestors
]

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{ source: '/:path*', headers: securityHeaders }]
  },
  images: {
    remotePatterns: [{ protocol: 'https', hostname: 'images.acme-cms.com', pathname: '/uploads/**' }],
    // keep defaults: dangerouslyAllowLocalIP false, maximumRedirects 3, qualities [75]
  },
  experimental: {
    taint: true,
    serverActions: { allowedOrigins: ['acme.com', '*.acme.com'], bodySizeLimit: '1mb' },
    // sri: { algorithm: 'sha256' }, // hash-based CSP alternative to nonces (experimental)
  },
}
export default nextConfig
```

### Taint a secret
```ts
import 'server-only'
import { experimental_taintUniqueValue as taintUniqueValue } from 'react'
export function getApiToken() {
  const token = process.env.PARTNER_API_TOKEN!
  taintUniqueValue('Do not pass the partner token to the client', process, token)
  return token
}
```

### Tooling scripts loading env
```ts
// drizzle.config.ts / vitest.setup.ts
import { loadEnvConfig } from '@next/env'
loadEnvConfig(process.cwd())
```

## Recommended Workflow
1. Inventory variables; classify secret/server/public.
2. Create `lib/env.ts` (validated, `server-only`) and `lib/public-env.ts`.
3. Replace any `getConfig()`/runtime config usage (removed in v16).
4. Ensure `.gitignore` covers `.env*.local` (and `.env` if it holds secrets).
5. Harden `next.config` headers, images, actions, `poweredByHeader`.
6. Add CI checks: grep for `NEXT_PUBLIC_.*(SECRET|KEY|TOKEN|PASSWORD)`, secret scanning, `npm audit`/advisory monitoring.
7. Document rotation procedures; rotate after any exposure.

## Patterns
- **Env schema + fail-fast import** at server entry.
- **Runtime config provider** for multi-environment images.
- **Per-environment noindex** via env flag in root metadata.
- **Feature flags from server env** rendered into props, not `NEXT_PUBLIC_` (so they can change without rebuild).

## Anti-Patterns
- **`NEXT_PUBLIC_STRIPE_SECRET_KEY`** — secret shipped to every browser. Fix: rename without prefix, use only on server; rotate the key.
- **`const { NEXT_PUBLIC_X } = process.env` in client code** — not inlined → undefined. Fix: literal `process.env.NEXT_PUBLIC_X`.
- **Expecting `NEXT_PUBLIC_` to change per environment after build** — frozen. Fix: build per env for public values or serve runtime config from the server.
- **Importing `lib/db.ts` into a Client Component** — secrets become empty strings or leak logic. Fix: `server-only`.
- **Reading secrets across components** (`process.env` everywhere) — hard to audit. Fix: DAL-only access.
- **`publicRuntimeConfig`** — removed in v16. Fix: env vars.
- **Committing `.env.local`** — leak. Fix: gitignore + secret scanning + rotate.
- **Logging `process.env` or request headers with tokens** — leak via logs. Fix: redact.
- **`images.remotePatterns` hostname `'**'`** — open image proxy. Fix: exact hosts.

## Accessibility
- Not directly UI-facing; misconfigured CSP can block fonts/scripts needed for accessible widgets — test assistive-tech flows after tightening headers.
- `X-Frame-Options`/`frame-ancestors` may break embedded accessible widgets in trusted parents — allowlist explicitly.

## Responsive Design
- Not applicable.

## Performance
- `connection()` for runtime env makes affected subtrees request-time; scope it to a small Suspense-wrapped provider rather than the root layout.
- Nonce CSP forces dynamic rendering; SRI or static CSP preserves static shells.

## Security
- Critical advisories to track: Dec 2025 React2Shell RSC RCE (CVE-2025-55182 / CVE-2025-66478; patched 16.0.7 and 15.x.y lines; rotate secrets if online and unpatched as of Dec 4, 2025); Aug 2026 AVIF optimizer RCE (GHSA-2xp9-vwfh-vxw4) and Windows mixed-router RCE (CVE-2026-75604) patched in 16.3.3 / 15.5.24.
- Data Access Layer is the only place for `process.env` secrets; audit that DB packages and env reads aren't imported elsewhere.
- Server Actions: `allowedOrigins` for proxies, `bodySizeLimit` to cap payloads, stable encryption key for multi-instance.
- Draft Mode secrets must be strong; enabling endpoints protected.

## Testing
- Unit test the env schema with valid/invalid fixtures.
- CI: build the client bundle and scan `.next/static` for known secret patterns (e.g., `sk_live_`, private key headers).
- E2E: verify security headers on a page response; verify CSP doesn't block app functionality.
- Test builds with missing env to confirm fail-fast.

## Tooling
- `@next/env`, zod (or `@t3-oss/env-nextjs` for typed client/server env split).
- `server-only`, React taint APIs (`experimental.taint`).
- Secret scanning (GitHub push protection, gitleaks), `npm audit`, Dependabot/Renovate, `npx fix-react2shell-next` (Dec 2025 advisory).
- securityheaders.com / Mozilla Observatory for header checks.

## Framework Notes
- v16: runtime config removed; `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` documented for multi-server; `eslint` config option removed.
- `NODE_ENV` auto-set: `development` for `next dev`, `production` otherwise.
- React (Vite SPA): only `VITE_`-prefixed vars reach the client, also inlined at build — same rule: never put secrets in client env; use a backend for secrets.

## AI Agent Guidance
- Never create `NEXT_PUBLIC_` variables for secrets; never print or hardcode secret values in code, docs, or examples.
- Add new env vars to the zod schema and `.env.example` (with placeholder values only).
- Before done: grep changed files for `NEXT_PUBLIC_` misuse and client imports of `server-only` modules; confirm build passes with schema validation; confirm Next.js is at a patched version.

## Examples
```bash
# .env.example (commit this, placeholders only)
DATABASE_URL=postgres://user:password@localhost:5432/app
SESSION_SECRET=replace-with-openssl-rand-base64-32
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

## Related Skills
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — baseline security
- [content-security-policy](../content-security-policy/Skill.md) — CSP design
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md) — patching and advisories
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) — server-only boundaries
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) — runtime env in containers
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — nonce CSP
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — DB credentials handling

## Sources
- [Environment Variables guide](https://nextjs.org/docs/app/guides/environment-variables) — Official — load order, NEXT_PUBLIC_ inlining, runtime env, @next/env, test env
- [Data Security guide](https://nextjs.org/docs/app/guides/data-security) — Official — DAL-only env access, taint, encryption key, allowedOrigins, auditing
- [Upgrading to v16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — runtime config removal, connection()
- [Content Security Policy guide](https://nextjs.org/docs/app/guides/content-security-policy) — Official — nonce vs static CSP, SRI
- [Self-hosting guide](https://nextjs.org/docs/app/guides/self-hosting) — Official — encryption key for multi-server
- [CVE-2025-66478 advisory](https://nextjs.org/blog/CVE-2025-66478) — Official — patching and secret rotation
- [August 2026 Security Release](https://nextjs.org/blog/august-2026-security-release) — Official — current critical fixes

## License / Usage Notes
Next.js MIT; zod MIT. Security header values are common recommended defaults (general practice, not from Next.js docs) — tune per application.

## Quality Tier
A — Official env and security guidance verified; header set drawn from widely accepted practice.

## Status
Active

## Last Verified
2026-09-15
