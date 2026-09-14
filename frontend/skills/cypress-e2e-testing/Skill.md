# Cypress E2E Testing

## Summary
Cypress is an in-browser test runner for E2E and component testing with a strong interactive runner, time-travel debugging and a large plugin ecosystem. This skill covers Cypress 16 with Next.js App Router and React (Vite): configuration, custom commands, `cy.session` auth, `cy.intercept`, component testing with the Next.js dev server, CI, and when Playwright is the better choice.

## Category
Testing & QA

## Subcategories
Cypress E2E, Cypress component testing, cy.intercept, cy.session, custom commands, Cypress Cloud, framework selection

## Problem It Solves
Teams with existing Cypress suites need a reliable, non-flaky configuration for Next.js, and teams choosing a tool need an honest comparison against Playwright.

## When To Use
- Existing Cypress suites and teams skilled in Cypress.
- Teams valuing the interactive runner and Cypress Cloud analytics (flake detection, test replay).
- Component tests for Client Components using the Next.js webpack dev server or Vite.

## When Not To Use
- Greenfield Next.js E2E where multi-tab, multi-origin, WebKit coverage or free parallelism matter: prefer [playwright-e2e-testing](../playwright-e2e-testing/Skill.md).
- Async Server Components in component tests - unsupported (Next.js docs); use E2E.
- Server-side fetch mocking: `cy.intercept` only sees browser traffic.

## Core Principles
1. Cypress commands are enqueued and retried, not promises - do not `await` them or assign their return values.
2. Use `data-cy`/role-based selectors via Testing Library (`@testing-library/cypress`), never styling classes.
3. Programmatic login with `cy.session`; do not log in through the UI in every test.
4. Tests must not depend on each other; reset state in `beforeEach`.
5. Wait on aliases (`cy.wait('@save')`), never fixed times.
6. Run E2E against a production build.

## Best Practices
- Set `baseUrl` in config; use `cy.visit('/')`.
- Add `@testing-library/cypress` for `cy.findByRole`.
- Use `cy.intercept` with aliases for browser API calls you need to wait on or stub.
- Use `testIsolation: true` (default) and `cy.session` with `cacheAcrossSpecs` for auth.
- Configure `retries: { runMode: 2, openMode: 0 }` and track flakes (Cypress Cloud or reporter).
- Use `start-server-and-test` to boot `next start` before `cypress run`.
- Keep specs small; one journey per spec.
- Type custom commands via `declare global { namespace Cypress { interface Chainable { ... } } }`.

## Implementation Guidance

### cypress.config.ts
```ts
import { defineConfig } from 'cypress'

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    specPattern: 'cypress/e2e/**/*.cy.ts',
    supportFile: 'cypress/support/e2e.ts',
    retries: { runMode: 2, openMode: 0 },
    video: false,
    screenshotOnRunFailure: true,
  },
  component: {
    devServer: { framework: 'next', bundler: 'webpack' },
    specPattern: 'components/**/*.cy.tsx',
  },
})
```
For a Vite SPA: `devServer: { framework: 'react', bundler: 'vite' }`. Cypress component testing lists React 18/19 support with Vite, webpack and Next.js 15/16 (per Cypress docs).

### Auth command with cy.session
```ts
// cypress/support/commands.ts
Cypress.Commands.add('login', (role: 'user' | 'admin' = 'user') => {
  cy.session(
    ['login', role],
    () => {
      cy.request('POST', '/api/test/login', { role }) // test-only endpoint enabled by env flag
    },
    {
      validate: () => cy.request('/api/me').its('status').should('eq', 200),
      cacheAcrossSpecs: true,
    },
  )
})

declare global {
  namespace Cypress {
    interface Chainable {
      login(role?: 'user' | 'admin'): Chainable<void>
    }
  }
}
export {}
```

### Scripts
```json
{
  "scripts": {
    "e2e": "start-server-and-test start http://localhost:3000 \"cypress run --e2e\"",
    "e2e:open": "start-server-and-test dev http://localhost:3000 \"cypress open --e2e\"",
    "component": "cypress run --component"
  }
}
```
Run `next build` before `npm run e2e` in CI. The Next.js guide's scripts use `dev` for convenience; prefer `start` in CI.

### GitHub Actions
```yaml
- uses: cypress-io/github-action@v6   # Check current docs for latest major
  with:
    build: npm run build
    start: npm run start
    wait-on: 'http://localhost:3000'
```

### Cypress vs Playwright
| Need | Cypress | Playwright |
|---|---|---|
| Interactive debugging | Excellent runner, time travel | UI mode + trace viewer |
| Browsers | Chrome-family, Firefox, WebKit (experimental - Check current docs) | Chromium, Firefox, WebKit first-class |
| Multi-tab / multi-origin | Limited (`cy.origin`) | Native |
| Parallelism | Cypress Cloud or third-party | Built-in workers + sharding |
| Component testing for Next.js | Supported (webpack) | Stories/galleries model (1.62) |
| Server-side fetch mocking | No | No (both need mock server / Next test mode) |
| Language model | Chained commands | async/await |

## Recommended Workflow
1. `npm i -D cypress @testing-library/cypress start-server-and-test`.
2. `npx cypress open` to scaffold; choose E2E and/or Component (Next.js).
3. Add support commands (`login`, data seeding via `cy.request`/`cy.task`).
4. Write specs with `cy.findByRole` and `cy.intercept` aliases.
5. Run headless locally (`cypress run`) and repeat new specs several times.
6. Wire CI with the official action; upload screenshots on failure.

## Patterns
- **Alias and wait**: `cy.intercept('POST', '/api/projects').as('create'); cy.findByRole('button', { name: 'Create' }).click(); cy.wait('@create').its('response.statusCode').should('eq', 201)`.
- **Seed via task**: `cy.task('db:seed', { projects: 3 })` with `setupNodeEvents` calling your seeding script.
- **Component mount with providers**: custom `cy.mount` wrapping QueryClientProvider and router mocks.
- **Clock**: `cy.clock(new Date('2026-01-01').getTime())` for time-based UI.

## Anti-Patterns
- **`const el = cy.get(...)` then using `el` later**: commands are async chains. Fix: chain or use aliases (`.as('row')`).
- **`cy.wait(2000)`**. Fix: `cy.wait('@alias')` or assertion retry.
- **Mixing `async/await` with Cypress commands**. Fix: chain `.then()`.
- **UI login in every test**. Fix: `cy.session`.
- **Conditional testing based on DOM state** ("if banner exists click it"). Fix: control state deterministically.
- **Expecting `cy.intercept` to stub RSC/Server Action server fetches**. Fix: mock server via env vars or E2E against seeded backend.

## Accessibility
Use `cypress-axe` or `@testing-library/cypress` role queries for accessibility signal; rules and triage live in [automated-accessibility-testing](../automated-accessibility-testing/Skill.md). Cypress has no native real Tab key; use `cypress-real-events` or `@testing-library/user-event`-style plugins for keyboard flows (Check current docs).

## Responsive Design
`cy.viewport('iphone-x')` or `cy.viewport(390, 844)` per test; run a mobile spec subset. Cypress does not emulate device user agents/touch as fully as Playwright device descriptors.

## Performance
- Disable video by default; enable on failure only if needed.
- Parallelize via CI matrix + spec splitting (Cypress Cloud or community splitters).
- Use `cy.session` caching and API seeding to cut per-test time.

## Security
Store credentials in CI secrets and pass via `CYPRESS_*` env vars or `cypress.env.json` (gitignored). Test-only login endpoints must be disabled in production builds. Screenshots may capture PII - limit artifact retention.

## Testing
Run `cypress run --spec path --browser chrome` repeatedly (e.g., loop 5x in CI job) for new specs; watch Cypress Cloud flaky analytics if used.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| `cypress` | 16.0.0 |
| `@testing-library/cypress` | Active |
| `cypress-io/github-action` | Active |
| `start-server-and-test` | Active |
| Cypress Cloud | Commercial (recording, parallelization, flake detection, Test Replay) |
| `cypress-axe` | Community |

## Framework Notes
- **Next.js**: E2E against `next build && next start`. Component testing uses `framework: 'next', bundler: 'webpack'`; `next/image` and server-dependent features may not work in component tests; async Server Components unsupported. Server-side data must be controlled via seeded backends or mock servers.
- **React (Vite SPA)**: Component testing with `bundler: 'vite'` reuses your Vite config; all network is browser-side so `cy.intercept` covers everything.

## AI Agent Guidance
- Do: follow the repo's existing runner - only write Cypress if Cypress is already used.
- Do: use `cy.findByRole` and intercept aliases; run the spec headless and report results.
- Don't: use `await` with `cy` commands, `cy.wait(ms)`, or conditional DOM logic.
- Don't: propose migrating to Playwright unless asked; note trade-offs if relevant.
- Before done: `cypress run --spec` passes twice consecutively, no `it.only`, custom command types compile.

## Examples
```ts
// cypress/e2e/projects.cy.ts
describe('Projects', () => {
  beforeEach(() => {
    cy.login()
    cy.intercept('POST', '/api/projects').as('createProject')
  })

  it('creates a project', () => {
    cy.visit('/projects')
    cy.findByRole('button', { name: /new project/i }).click()
    cy.findByRole('dialog', { name: /create project/i }).within(() => {
      cy.findByLabelText(/name/i).type('Apollo')
      cy.findByRole('button', { name: /create/i }).click()
    })
    cy.wait('@createProject').its('response.statusCode').should('eq', 201)
    cy.findByRole('heading', { level: 1, name: 'Apollo' }).should('be.visible')
  })
})
```

## Related Skills
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - primary alternative
- [component-testing](../component-testing/Skill.md) - component test options compared
- [frontend-testing-strategy](../frontend-testing-strategy/Skill.md) - layer allocation
- [test-data-and-fixtures](../test-data-and-fixtures/Skill.md) - seeding
- [flaky-test-management](../flaky-test-management/Skill.md) - retries and quarantine
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) - axe integration

## Sources
- [Next.js: Setting up Cypress](https://nextjs.org/docs/app/guides/testing/cypress) - Official - E2E/CT config, async RSC limitation, start-server-and-test
- [Cypress React Component Testing overview](https://docs.cypress.io/app/component-testing/react/overview) - Official - supported frameworks and versions
- [npm: cypress](https://registry.npmjs.org/cypress/latest) - Official - version 16.0.0
- [Cypress documentation](https://docs.cypress.io/) - Official - cy.session, cy.intercept, retries

## License / Usage Notes
Cypress App is MIT-licensed; Cypress Cloud is commercial. Content summarized; examples original.

## Quality Tier
B - Core guidance verified against Next.js and Cypress docs, but Cypress 16 changelog specifics (WebKit status, action major version) not individually verified.

## Status
Active

## Last Verified
2026-09-15
