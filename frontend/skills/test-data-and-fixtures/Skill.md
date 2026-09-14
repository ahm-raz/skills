# Test Data and Fixtures

## Summary
Managing test data for React/Next.js suites: typed factories/builders, deterministic fake data, shared fixtures across Vitest, Storybook, MSW and Playwright, database seeding and isolation for E2E, Playwright custom fixtures with setup/teardown, authentication states per role, and cleanup strategies. Good test data is the main lever for readable tests and parallel, non-flaky E2E runs.

## Category
Testing & QA

## Subcategories
Factories and builders, faker seeding, JSON fixtures, MSW data, Playwright fixtures, database seeding, data isolation, auth states, cleanup, snapshotting data

## Problem It Solves
Tests copy large JSON blobs that drift from real types, share mutable records that collide under parallel execution, depend on data created by other tests, or rely on a shared staging database that changes daily. The result is brittle, unreadable and flaky tests.

## When To Use
- Writing any test that needs domain objects (users, projects, orders).
- Setting up E2E environments and seeding databases.
- Sharing data between stories, MSW handlers and tests.
- Running E2E in parallel.

## When Not To Use
- Trivial primitives - inline literals are clearer.
- Production data copies - avoid for privacy and determinism (use anonymized/synthetic).

## Core Principles
1. Tests declare only the data that matters to them; factories provide valid defaults for the rest.
2. Fixtures are typed from application types/schemas so drift is a compile error.
3. Each test owns its data: create -> use -> clean up (or isolate by namespace/tenant).
4. Deterministic by default: seeded randomness, fixed dates.
5. Seed via the same layer the app uses (API or domain services) when possible, not raw SQL that bypasses invariants.

## Best Practices
- One factory per domain type in `test/factories/` with `build(overrides)` and `buildList(n, overrides)`.
- Validate factory output against zod schemas in development (catches drift).
- Use `@faker-js/faker` with `faker.seed(123)` for readable variety; avoid random data in assertions unless captured.
- Use unique identifiers for E2E records (`e2e-${test.info().workerIndex}-${crypto.randomUUID()}`).
- Keep "golden" scenario data (e.g., a user with 3 overdue invoices) as named scenarios reused by Storybook, MSW and tests.
- Use Playwright fixtures (`test.extend`) for data lifecycle; worker-scoped fixtures for expensive shared setup (accounts), test-scoped for mutable records.
- Store auth states per role via setup projects; never commit them.
- Reset or roll back databases between E2E runs; use disposable DBs (containers/branching databases) in CI.

## Implementation Guidance

### Factory pattern (no dependencies)
```ts
// test/factories/project.ts
import type { Project } from '@/lib/types'

let seq = 0
export function buildProject(overrides: Partial<Project> = {}): Project {
  seq += 1
  return {
    id: `proj_${seq}`,
    name: `Project ${seq}`,
    status: 'active',
    ownerId: 'user_1',
    createdAt: '2026-01-15T10:00:00.000Z',
    tags: [],
    ...overrides,
  }
}
export const buildProjects = (n: number, overrides: Partial<Project> = {}) =>
  Array.from({ length: n }, () => buildProject(overrides))
```
Reset `seq` in a `beforeEach` if IDs appear in snapshots or assertions. Libraries such as `fishery` or `@mswjs/data` provide richer factories/associations (Check current docs for maintenance).

### Schema-checked fixtures
```ts
import { ProjectSchema } from '@/lib/schemas'
export const buildValidProject = (o?: Partial<Project>) => ProjectSchema.parse(buildProject(o))
```

### Faker with determinism
```ts
import { faker } from '@faker-js/faker'
faker.seed(20260915)
export const buildUser = (o: Partial<User> = {}): User => ({
  id: faker.string.uuid(),
  name: faker.person.fullName(),
  email: faker.internet.email({ provider: 'example.test' }),
  ...o,
})
```
Use reserved domains (`example.com`, `.test`) so emails never reach real inboxes.

### Named scenarios shared across layers
```ts
// test/scenarios/billing.ts
export const overdueAccount = {
  user: buildUser({ name: 'Ada Overdue' }),
  invoices: [
    buildInvoice({ status: 'overdue', amountCents: 12000 }),
    buildInvoice({ status: 'overdue', amountCents: 4500 }),
  ],
}
```
Consumers: MSW handler (`HttpResponse.json(overdueAccount.invoices)`), Storybook story args, component test assertions.

### Playwright data fixtures
```ts
// e2e/fixtures.ts
import { test as base, expect, type APIRequestContext } from '@playwright/test'

type Workspace = { id: string; slug: string }

async function createWorkspace(request: APIRequestContext, slug: string): Promise<Workspace> {
  const res = await request.post('/api/test/workspaces', { data: { slug } })
  expect(res.ok()).toBeTruthy()
  return res.json()
}

export const test = base.extend<{ workspace: Workspace }, { workerAccount: { email: string } }>({
  workerAccount: [
    async ({}, use, workerInfo) => {
      await use({ email: `e2e-worker-${workerInfo.workerIndex}@example.test` })
    },
    { scope: 'worker' },
  ],
  workspace: async ({ request }, use, testInfo) => {
    const ws = await createWorkspace(request, `e2e-${testInfo.workerIndex}-${Date.now().toString(36)}`)
    await use(ws)
    await request.delete(`/api/test/workspaces/${ws.id}`)
  },
})
export { expect }
```
Test-only endpoints (`/api/test/*`) must return 404 unless `E2E_TEST_ROUTES=1` and never be enabled in production; alternatively seed via a Node script that uses your domain services directly in `globalSetup`.

### Database strategies for E2E
| Strategy | How | Pros | Cons |
|---|---|---|---|
| Disposable DB per CI run | Docker service container / DB branching; migrate + seed in `globalSetup` | Clean, realistic | Setup time |
| Per-test namespacing (tenant/workspace) | Fixture creates tenant, deletes after | Parallel-safe on shared DB | Needs multi-tenant model |
| Transaction rollback | Wrap in transaction | Fast | Hard with app server in separate process; rarely viable for E2E |
| Snapshot restore | Restore DB dump before run | Fast reset | Dumps drift from migrations |
| Mocked backend (mock server) | Env-pointed mock API | Deterministic | Less realistic |

### Playwright global setup (seeding)
```ts
// playwright.config.ts
export default defineConfig({
  globalSetup: './e2e/global-setup.ts',
})
```
```ts
// e2e/global-setup.ts
import { execSync } from 'node:child_process'
export default async function globalSetup() {
  execSync('npm run db:migrate && npm run db:seed:e2e', { stdio: 'inherit', env: { ...process.env } })
}
```
Alternatively use a `setup` project with dependencies so seeding appears in reports and traces.

## Recommended Workflow
1. Define types/schemas first; create factories for core entities.
2. Replace inline JSON blobs in tests with factories + overrides.
3. Create named scenarios for recurring states; wire into MSW and Storybook.
4. For E2E, choose DB strategy; implement seeding in setup project/globalSetup.
5. Add fixtures for per-test data with teardown; per-worker accounts for parallelism.
6. Enforce: lint/grep for hardcoded production URLs/emails in fixtures; review data privacy.

## Patterns
- **Builder with traits**: `buildOrder({ ...traits.paid, ...traits.international })`.
- **Object Mother for scenarios** (named business situations) on top of factories.
- **Per-worker identity**: `workerInfo.workerIndex` / `parallelIndex` to map to pre-provisioned accounts.
- **Arrange via API, assert via UI** in E2E.
- **Frozen time**: factories use fixed ISO dates; tests control clock.

## Anti-Patterns
- **Giant shared JSON fixture files**: unreadable, drift. Fix: factories + overrides.
- **Tests depending on data created by other tests**. Fix: each test arranges its own data.
- **Shared staging DB for CI E2E**: nondeterministic. Fix: disposable DB or namespacing.
- **Random data in assertions without capture**: irreproducible failures. Fix: seed faker or assert on captured values.
- **Real PII or production dumps**: privacy/legal risk. Fix: synthetic data; anonymize strictly if unavoidable.
- **Test-only routes enabled in production**. Fix: env guard + deployment check.
- **Cleanup in `afterAll` only**: crashed tests leave data. Fix: fixture teardown + periodic sweeper deleting `e2e-*` records older than N hours.

## Accessibility
Include data that stresses accessible UI: long names (truncation with accessible full names), RTL strings, empty values, and large lists (virtualization announcements). Screen-reader-relevant content like `alt` text should come from realistic fixture fields.

## Responsive Design
Include extreme content lengths and counts in scenarios to validate layouts at small viewports (overflow, wrapping) in visual and E2E tests.

## Performance
- Factories are cheap; DB seeding is not - seed once per worker/run where data is read-only.
- Use API seeding (single request creating a graph) instead of UI steps.
- Keep seed datasets small; large-data performance testing is a separate suite.

## Security
- Never use real credentials or customer data in fixtures; use `example.test` domains.
- Test endpoints for seeding must require env flag and ideally a secret header, and must be excluded from production builds.
- Auth storage state files contain session cookies: gitignore and short artifact retention.

## Testing
Unit test factories against schemas (`ProjectSchema.parse(buildProject())`) and run E2E in parallel with `--repeat-each` to detect data collisions.

## Tooling
| Tool | Notes |
|---|---|
| `@faker-js/faker` | Seedable fake data (Check current version) |
| `fishery` | TypeScript factories (Check maintenance) |
| `@mswjs/data` | Data modeling for MSW (Check maintenance) |
| zod | Schema validation of fixtures |
| Playwright fixtures, setup projects, `globalSetup` | E2E data lifecycle |
| Testcontainers / DB branching services | Disposable databases (Check current docs) |

## Framework Notes
- **Next.js**: Server Components read from the DB/API directly, so E2E data must exist in the backing store (or mock server) before `page.goto`; seed via API/scripts, not browser mocks. Beware caching: `use cache`/fetch caching may serve stale data between tests - use unique records per test or disable caching in the E2E environment where appropriate.
- **React (Vite SPA)**: Data typically flows through a browser-side API client, so MSW scenarios or `page.route` can supply fixtures entirely in E2E; still test at least one flow against a real backend.

## AI Agent Guidance
- Do: use existing factories; add fields to factories when types change.
- Do: generate unique names/IDs for E2E-created records and clean them up in fixture teardown.
- Don't: paste large JSON blobs from API responses into tests; don't include real emails/tokens.
- Don't: create test-only endpoints without env guards.
- Before done: types compile, factories validate against schemas, E2E passes with multiple workers.

## Examples
```tsx
// components/invoice-summary.test.tsx
import { render, screen } from '@testing-library/react'
import { expect, test } from 'vitest'
import { buildInvoice } from '@/test/factories/invoice'
import { InvoiceSummary } from './invoice-summary'

test('totals only overdue invoices', () => {
  const invoices = [
    buildInvoice({ status: 'overdue', amountCents: 12000 }),
    buildInvoice({ status: 'paid', amountCents: 99999 }),
    buildInvoice({ status: 'overdue', amountCents: 4500 }),
  ]
  render(<InvoiceSummary invoices={invoices} currency="USD" />)
  expect(screen.getByRole('status', { name: /overdue total/i })).toHaveTextContent('$165.00')
})
```

## Related Skills
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - fixtures and auth states
- [api-mocking-msw](../api-mocking-msw/Skill.md) - handlers using factories
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) - args from scenarios
- [flaky-test-management](../flaky-test-management/Skill.md) - isolation
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) - seeding and migrations
- [typescript-for-frontend](../typescript-for-frontend/Skill.md) - typed fixtures

## Sources
- [Playwright Fixtures](https://playwright.dev/docs/test-fixtures) - Official - test/worker scoped fixtures
- [Playwright Authentication](https://playwright.dev/docs/auth) - Official - roles, per-worker accounts
- [Playwright Best Practices](https://playwright.dev/docs/best-practices) - Official - test isolation
- [Eradicating Non-Determinism in Tests](https://martinfowler.com/articles/nonDeterminism.html) - Community - isolation and cleanup strategies
- [MSW Node integration](https://mswjs.io/docs/integrations/node) - Official - handler lifecycle

## License / Usage Notes
Summarized guidance; examples original. Playwright Apache-2.0; MSW and faker MIT.

## Quality Tier
B - Patterns are well-established and grounded in Playwright docs, but third-party factory/DB tooling maintenance status was not verified this session.

## Status
Active

## Last Verified
2026-09-15
