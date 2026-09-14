# Database Integration in Next.js (Prisma / Drizzle)

## Summary
How to connect a Next.js App Router application to a relational database safely and efficiently using Prisma ORM 7 or Drizzle ORM: a `server-only` Data Access Layer (DAL) with authorization and DTOs, client singletons that survive hot reload, connection pooling for serverless (Vercel Fluid compute `attachDatabasePool`, PgBouncer/Supavisor/Neon poolers, HTTP drivers), migrations in CI, and integration with Next.js caching.

## Category
Next.js

## Subcategories
Prisma ORM 7, Drizzle ORM, Data Access Layer, connection pooling, serverless databases, migrations, caching, server-only boundaries

## Problem It Solves
Common failures: "too many connections" in serverless, a new Prisma client per hot reload, DB queries in Client Components or proxy, raw rows with secrets passed to Client Components, missing authorization in Server Actions, migrations run during `next build`, and stale cached data after writes.

## When To Use
- Adding Postgres/MySQL/SQLite to a Next.js app.
- Choosing between Prisma and Drizzle.
- Deploying DB-backed Next.js to serverless (Vercel, Netlify, AWS Lambda) or containers.
- Auditing data access for security and performance.

## When Not To Use
- The app consumes an existing backend API instead of a database (see [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md) for OpenAPI clients).
- Client-only SPAs (never connect to a DB from the browser).
- BaaS-only apps using Supabase/Firebase client SDKs with row-level security as the primary access path (different model; still use server-side access for privileged operations).

## Core Principles
1. Database access happens only on the server, in a `server-only` DAL; UI code never imports the DB client.
2. The DAL authenticates, authorizes, and returns minimal DTOs.
3. One client/pool per server instance (global singleton); size pools for concurrency, not 1.
4. Match driver to runtime: TCP pool on Node.js (with a pooler for serverless), HTTP/WebSocket drivers where TCP is unavailable.
5. Migrations are explicit deployment steps, never implicit during request handling or `next build`.
6. Every mutation invalidates the right cache (tags/paths) and returns only what the UI needs.
7. Use parameterized queries only; never string-concatenate SQL.

## Best Practices
- Mark `src/server/db.ts` and DAL modules with `import 'server-only'`; only the DAL reads `process.env.DATABASE_URL`.
- Wrap per-request lookups (current user, org) in `React.cache` to dedupe within a request.
- Use `"use cache"` + `cacheTag(...)` (Cache Components) or `unstable_cache` equivalents for cacheable, non-user-specific reads; invalidate with `revalidateTag`/`updateTag` in Server Actions.
- Never cache user-specific data in shared caches without keying on the user and considering privacy.
- Prisma 7: use the `prisma-client` generator with explicit `output`, a driver adapter (`@prisma/adapter-pg`, `@prisma/adapter-neon`, etc.), and `prisma.config.ts`; env vars are not loaded automatically by the CLI — load them (e.g., `dotenv` or `@next/env`) in config.
- Drizzle: define schema in TS, use `drizzle-kit generate` + `migrate` in CI (reserve `push` for prototyping), and pick the driver per runtime (`node-postgres`/`postgres.js` with a pool, `neon-http` for one-shot queries, `neon-serverless` WebSocket for transactions).
- Vercel Fluid compute: create the pool at module scope and call `attachDatabasePool(pool)` from `@vercel/functions`; short idle timeout (~5s), min pool 1, max > 1.
- Supabase transaction pooler (port 6543) and PgBouncer transaction mode do not support prepared statements: set `prepare: false` (postgres.js) or use the session pooler/direct URL for migrations.
- Use a separate direct (non-pooled) URL for migrations.
- Add `postinstall: prisma generate` (or generate in build step) so CI/deploy caches do not ship stale clients.
- Select only needed columns; paginate with cursors; add indexes for filter/sort columns.
- Log slow queries and pool saturation (see [frontend-observability](../frontend-observability/Skill.md)).

## Implementation Guidance

### Prisma vs Drizzle
| Factor | Prisma ORM 7 | Drizzle ORM |
|---|---|---|
| Schema | `schema.prisma` DSL, generated client | TypeScript schema files |
| Query style | High-level model API, nested writes | SQL-like builder + relational queries |
| Runtime | Rust-free TS client (v7), driver adapters required | Thin TS layer over chosen driver |
| Bundle/cold start | Improved in v7; still larger | Very small |
| Migrations | `prisma migrate dev/deploy` | `drizzle-kit generate/migrate` (`push` for dev) |
| Raw SQL | `$queryRaw` tagged templates (typed SQL available) | First-class `sql` template |
| Team fit | Productive for teams wanting abstraction, Studio | Teams comfortable with SQL, edge/serverless focus |
| Status (2026-09) | v7 stable; Accelerate retiring 2026-12-01 per upgrade guide | 0.x stable line; 1.0 in RC — check npm before pinning |

### Pooling by deployment target
| Deployment | Recommended connection strategy |
|---|---|
| Long-running Node server/container | Standard pool (pg `Pool`, Prisma adapter pool) sized to DB limits / instances |
| Vercel Fluid compute (Node.js) | Module-scope pool + `attachDatabasePool`; pooled URL from provider |
| Classic serverless (one request per instance) | External pooler (PgBouncer/Supavisor/Neon pooled URL, RDS Proxy), small max per instance |
| Edge runtime / environments without TCP | HTTP driver (`neon-http`, PlanetScale serverless, Turso/libSQL) — or move the route to Node.js runtime |
| Migrations | Direct (non-pooled) connection from CI |

### Prisma 7 setup
```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client"
  output   = "../src/generated/prisma"
}

datasource db {
  provider = "postgresql"
}

model Post {
  id        String   @id @default(uuid())
  title     String
  body      String
  authorId  String
  createdAt DateTime @default(now())
  @@index([authorId, createdAt])
}
```

```ts
// prisma.config.ts
import 'dotenv/config'
import { defineConfig, env } from 'prisma/config'

export default defineConfig({
  schema: 'prisma/schema.prisma',
  datasource: { url: env('DIRECT_DATABASE_URL') }, // CLI/migrations use direct URL
})
```

```ts
// src/server/db.ts
import 'server-only'
import { PrismaPg } from '@prisma/adapter-pg'
import { PrismaClient } from '@/generated/prisma/client'

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient }

function createClient() {
  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL! }) // pooled URL at runtime
  return new PrismaClient({ adapter })
}

export const db = globalForPrisma.prisma ?? createClient()
if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = db
```

### Drizzle setup (node-postgres + Vercel pooling)
```ts
// src/server/db/schema.ts
import { index, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core'

export const posts = pgTable('posts', {
  id: uuid().primaryKey().defaultRandom(),
  title: text().notNull(),
  body: text().notNull(),
  authorId: uuid('author_id').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
}, t => [index('posts_author_created_idx').on(t.authorId, t.createdAt)])
```

```ts
// src/server/db/index.ts
import 'server-only'
import { Pool } from 'pg'
import { drizzle } from 'drizzle-orm/node-postgres'
import { attachDatabasePool } from '@vercel/functions' // only when deploying on Vercel
import * as schema from './schema'

const globalForDb = globalThis as unknown as { pool?: Pool }

const pool = globalForDb.pool ?? new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 5_000,
})
if (process.env.NODE_ENV !== 'production') globalForDb.pool = pool
attachDatabasePool(pool)

export const db = drizzle(pool, { schema })
```

```ts
// drizzle.config.ts
import { loadEnvConfig } from '@next/env'
import { defineConfig } from 'drizzle-kit'

loadEnvConfig(process.cwd())

export default defineConfig({
  schema: './src/server/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DIRECT_DATABASE_URL! },
})
```

### Data Access Layer with auth and DTOs
```ts
// src/server/posts.ts
import 'server-only'
import { cache } from 'react'
import { and, desc, eq, lt } from 'drizzle-orm'
import { db } from './db'
import { posts } from './db/schema'
import { requireUser } from './auth'

export type PostDTO = { id: string; title: string; createdAt: string }

export const listMyPosts = cache(async (cursor?: string): Promise<PostDTO[]> => {
  const user = await requireUser()
  const rows = await db
    .select({ id: posts.id, title: posts.title, createdAt: posts.createdAt })
    .from(posts)
    .where(cursor
      ? and(eq(posts.authorId, user.id), lt(posts.createdAt, new Date(cursor)))
      : eq(posts.authorId, user.id))
    .orderBy(desc(posts.createdAt))
    .limit(20)
  return rows.map(r => ({ ...r, createdAt: r.createdAt.toISOString() }))
})

export async function renamePost(postId: string, title: string) {
  const user = await requireUser()
  const [updated] = await db
    .update(posts)
    .set({ title })
    .where(and(eq(posts.id, postId), eq(posts.authorId, user.id))) // authorization in the query
    .returning({ id: posts.id })
  if (!updated) throw new Error('Not found or forbidden')
  return { id: updated.id }
}
```

```ts
// src/app/posts/actions.ts
'use server'
import { z } from 'zod'
import { revalidatePath } from 'next/cache'
import { renamePost } from '@/server/posts'

const Input = z.object({ id: z.string().uuid(), title: z.string().trim().min(1).max(200) })

export async function renamePostAction(formData: FormData) {
  const { id, title } = Input.parse(Object.fromEntries(formData))
  await renamePost(id, title)
  revalidatePath('/posts')
}
```

### Migrations in CI/CD
| Tool | Dev | CI/Deploy |
|---|---|---|
| Prisma | `prisma migrate dev` | `prisma migrate deploy` as a pre-deploy job (direct URL) |
| Drizzle | `drizzle-kit generate` (+ `push` only on throwaway DBs) | `drizzle-kit migrate` pre-deploy |

Run migrations before the new app version receives traffic; make changes backward-compatible (expand -> deploy -> contract) for zero-downtime.

## Recommended Workflow
1. Choose DB provider and ORM (tables above); decide deployment target and pooling strategy.
2. Create pooled runtime URL and direct migration URL in the secret manager; add names to `.env.example`.
3. Define schema and generate the first migration.
4. Implement `db.ts` singleton with `server-only` and pooling settings.
5. Build the DAL: `requireUser`, authorization in queries, DTO mapping, `React.cache` for request dedupe.
6. Wire Server Components (reads) and Server Actions (writes) to the DAL; add cache tags/revalidation.
7. Add seed scripts and test DB (Docker/Testcontainers or provider branches).
8. Add CI migration step and integration tests; load test for pool saturation before launch.

## Patterns
- **DAL + DTO**: the only path from UI to DB.
- **Authorization in the WHERE clause**: `and(eq(id), eq(ownerId, user.id))` prevents IDOR in one query.
- **Request-scoped memoization** with `React.cache`.
- **Cached public reads** with `"use cache"` + `cacheTag('posts')`, invalidated after writes.
- **Global singleton** for clients/pools across hot reloads.
- **Branch databases** (Neon/PlanetScale/Supabase branching) per preview deployment.
- **Transactions for multi-step writes** (`db.transaction(async tx => ...)` / `prisma.$transaction`).
- **Soft deletes + audit columns** for recoverability where required.

## Anti-Patterns
- **Importing the DB client in a Client Component or shared utility.** Build errors or secret exposure. Fix: `server-only` DAL.
- **Querying the DB in `proxy.ts` (formerly middleware) for every request.** Latency and connection storms. Fix: optimistic cookie checks in proxy; real auth checks in DAL.
- **`new PrismaClient()` inside functions or per request.** Connection exhaustion. Fix: singleton.
- **Pool `max: 1` on Fluid/serverless.** Serializes concurrent requests. Fix: min 1, max sized to concurrency and DB limits.
- **Prepared statements through a transaction-mode pooler.** Errors like "prepared statement already exists". Fix: `prepare: false` or session mode.
- **Running `prisma migrate dev` or `drizzle-kit push` against production.** Data loss risk. Fix: generated migrations + deploy step.
- **Migrations inside `next build`.** Builds run in parallel/preview environments. Fix: separate pipeline job.
- **Passing Prisma/Drizzle row objects directly to Client Components.** Leaks fields. Fix: DTOs.
- **String-built SQL** (`sql.raw(\`... ${input}\`)`, `$queryRawUnsafe`). SQL injection. Fix: tagged templates/params.
- **Outdated Prisma patterns**: `prisma-client-js` generator without output, `datasource url = env(...)` in schema for v7, client middleware (`$use`) — removed. Fix: v7 generator, config file, client extensions.
- **Edge runtime routes with TCP drivers.** Fails at runtime. Fix: Node.js runtime or HTTP driver.

## Accessibility
- Database work affects UX states: always provide loading (Suspense fallbacks), empty, and error states with accessible text ([loading-states](../loading-states/Skill.md), [error-states](../error-states/Skill.md)).
- Surface validation/constraint errors (unique email) as field-level messages, not generic 500s.

## Responsive Design
- Paginate and limit columns so mobile views do not download large payloads.
- Provide server-side sorting/filtering so small screens do not need full datasets client-side.

## Performance
- Size pools: total connections = instances x max pool <= DB/pooler limit; prefer provider poolers for bursty serverless.
- Colocate functions and database regions; cross-region queries dominate latency.
- Use indexes for WHERE/ORDER BY columns; inspect `EXPLAIN ANALYZE` for slow queries.
- Avoid N+1: Drizzle relational queries/joins, Prisma `include`/`select` with care; batch lookups.
- Parallelize independent queries (`Promise.all`) in Server Components; stream slower sections with Suspense.
- Cache stable reads with tags; avoid caching per-user data globally.
- HTTP drivers add per-query overhead but avoid connection setup; choose per workload.

## Security
- Secrets (DB URLs) only in server env vars, loaded in the DAL; never `NEXT_PUBLIC_`.
- Least-privilege DB roles: runtime role without DDL; migration role separate.
- Authorization in every DAL function; verify ownership/tenant in queries (IDOR prevention); multi-tenant filters mandatory ([multi-tenant-ui](../multi-tenant-ui/Skill.md) for UI side).
- Validate inputs (Zod) before queries; parameterized queries only.
- Return DTOs; consider React taint APIs (`experimental.taint`) as a backstop.
- TLS for DB connections (`sslmode=require`); restrict network access/IP allowlists where supported.
- Do not log full query parameters containing PII.

## Testing
- Unit test DAL authorization logic with a real test DB (Docker Postgres or Testcontainers) rather than mocking the ORM.
- Integration tests: run migrations on a fresh DB, seed, exercise Server Actions as functions.
- Preview environments with branch databases for e2e (Playwright).
- Load test pool behavior (k6) to catch connection exhaustion.
- CI check that migrations are generated and committed (`drizzle-kit check` / `prisma migrate diff`).

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| Prisma ORM 7 | Active | `prisma-client` generator, driver adapters, `prisma.config.ts`, ESM, Node 20.19+ |
| Prisma Accelerate | Retiring 2026-12-01 (per Prisma 7 upgrade guide) | Plan alternative pooling/caching |
| Drizzle ORM + drizzle-kit | Active (1.0 RC) | Verify version tags on npm |
| `@vercel/functions` `attachDatabasePool` | Active | Fluid compute pooling |
| Neon serverless driver | Active | HTTP/WebSocket |
| Supabase Supavisor / PgBouncer | Active | Transaction vs session pooling |
| `server-only` | Active | Import guard |
| Testcontainers | Active | Real DB in tests |

## Framework Notes
- **Next.js**: Server Components and Server Actions call the DAL; Route Handlers for webhooks/external clients. Default runtime is Node.js — keep DB routes on it. Next 16 renamed middleware to `proxy.ts`; do not do DB-backed auth there. With Cache Components, dynamic DB reads need `<Suspense>` or `"use cache"`; see [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md). Use `@next/env` `loadEnvConfig` in ORM config files.
- **React (Vite SPA)**: never connect to the DB from the browser; use a backend (Hono/Fastify/Express, or a BFF) with the same DAL principles, and a typed API layer to the SPA.

## AI Agent Guidance
- Do: locate the existing `db.ts`/DAL and follow its patterns; add new queries to the DAL, not components.
- Do: include authorization in every new DAL function and return DTOs.
- Do: generate migrations for schema changes and commit them; never apply to production from the agent session.
- Don't: create new ORM clients per call, import DB modules into `'use client'` files, or add DB queries to `proxy.ts`.
- Don't: print or commit connection strings; reference env var names only.
- Before done: typecheck passes; migration generated and reviewed; unauthorized access test fails as expected; revalidation verified by performing a mutation and seeing fresh data.

## Examples
```ts
// Cached public read with Cache Components
import 'server-only'
import { cacheTag } from 'next/cache'
import { db } from './db'
import { posts } from './db/schema'
import { desc } from 'drizzle-orm'

export async function getLatestPublicPosts() {
  'use cache'
  cacheTag('posts')
  return db.select({ id: posts.id, title: posts.title }).from(posts).orderBy(desc(posts.createdAt)).limit(10)
}
// In a Server Action after writes: revalidateTag('posts', 'max') or updateTag('posts') — check the installed Next.js docs for the exact signature.
```

```ts
// postgres.js through a transaction-mode pooler
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
const client = postgres(process.env.DATABASE_URL!, { prepare: false, max: 5 })
export const db = drizzle(client)
```

## Related Skills
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) — reading data in RSC
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — writes and revalidation
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — cache tags and Cache Components
- [nextjs-authentication](../nextjs-authentication/Skill.md) — session checks the DAL relies on
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — secret handling
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) — runtime and region choices
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md) — API layer over the DAL
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — injection and IDOR

## Sources
- [Next.js: Data Security](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, DTOs, server-only, taint, action authorization
- [Prisma: Upgrading to Prisma ORM 7](https://www.prisma.io/docs/orm/more/upgrade-guides/upgrading-versions/upgrading-to-prisma-7) — Official — generator/output, adapters, prisma.config.ts, env loading, Accelerate retirement
- [Prisma: Next.js help](https://www.prisma.io/docs/orm/more/help-and-troubleshooting/nextjs-help) — Official — singleton pattern, monorepo, postinstall generate
- [Drizzle: Get started with Neon](https://orm.drizzle.team/docs/get-started/neon-new) — Official — drivers, schema, drizzle-kit commands
- [Vercel: Connection pooling with Functions](https://vercel.com/guides/connection-pooling-with-functions) — Official — attachDatabasePool, pool sizing, idle timeouts
- [Next.js: Environment variables](https://nextjs.org/docs/app/guides/environment-variables) — Official — `@next/env` for ORM config files

## License / Usage Notes
Prisma (Apache-2.0), Drizzle (Apache-2.0), Next.js (MIT). Content summarized; code examples are original and should be verified against installed ORM versions.

## Quality Tier
A — Grounded in official Next.js, Prisma 7, Drizzle, and Vercel docs; Drizzle 1.0 release status and Next cache invalidation signatures should be rechecked when pinning versions.

## Status
Active

## Last Verified
2026-09-15
