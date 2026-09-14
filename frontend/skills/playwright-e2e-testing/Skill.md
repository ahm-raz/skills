# Playwright E2E Testing

## Summary
Playwright Test is the recommended end-to-end framework for Next.js and React apps: one API for Chromium, Firefox and WebKit, auto-waiting locators, web-first assertions, fixtures, parallelism and sharding, trace viewer, screenshot and ARIA snapshot assertions, network mocking, clock control, and (since 1.56) AI test agents. This skill covers config for a Next.js production build, authentication setup projects, fixtures/page objects, debugging with traces, and CI.

## Category
Testing & QA

## Subcategories
E2E testing, locators, fixtures, auth storage state, network mocking, trace viewer, ARIA snapshots, test agents, Playwright MCP, sharding

## Problem It Solves
Critical flows in Next.js App Router (async Server Components, streaming, Server Actions, cookies, redirects, caching, `proxy.ts`) cannot be verified in jsdom. Teams need E2E tests that are fast, isolated and debuggable instead of slow, flaky scripts.

## When To Use
- Critical user journeys: sign-in, checkout, CRUD of core entities, permissions.
- Anything depending on the real Next.js server: RSC data, Server Actions, revalidation, route handlers, redirects, headers/cookies.
- Cross-browser and mobile-viewport checks.
- Accessibility smoke (axe) and ARIA structure snapshots on key pages.

## When Not To Use
- Validation permutations and component states - push to component tests.
- Third-party sites you do not control (mock them).
- Load/performance testing (use Lighthouse CI, k6, RUM).

## Core Principles
1. Test user-visible behavior with user-facing locators (`getByRole`, `getByLabel`, `getByText`, `getByTestId` last).
2. Every test is isolated: fresh browser context, own data, no ordering dependence.
3. Use web-first assertions (`await expect(locator).toBeVisible()`) - they auto-retry; never `waitForTimeout`.
4. Control dependencies: mock third-party network, seed your own data via API.
5. Run against a production build (`next build && next start`), as Next.js docs recommend.
6. Traces on failure are mandatory in CI.

## Best Practices
- `fullyParallel: true`, `forbidOnly: !!process.env.CI`, `retries: process.env.CI ? 2 : 0`, `trace: 'on-first-retry'`.
- Authenticate once per role in a `setup` project and reuse `storageState`; keep `playwright/.auth` gitignored.
- Seed data with `request` fixture (API) in `beforeEach` or custom fixtures; clean up in fixture teardown.
- Use `test.step()` to structure long flows for readable reports/traces.
- Use `expect.soft` for checking multiple independent fields.
- Lint with `@typescript-eslint/no-floating-promises` - a missing `await` is the top cause of false passes.
- Use `page.clock` for time-dependent UI instead of real waiting.
- Install only needed browsers in CI (`npx playwright install --with-deps chromium`).
- Tag tests (`test('...', { tag: '@smoke' }, ...)`) and filter with `--grep`.

## Implementation Guidance

### playwright.config.ts for Next.js
```ts
import { defineConfig, devices } from '@playwright/test'

const PORT = Number(process.env.PORT ?? 3000)
const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? `http://localhost:${PORT}`

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI ? [['blob'], ['github']] : [['html', { open: 'never' }]],
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'setup', testMatch: /.*\.setup\.ts/ },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], storageState: 'playwright/.auth/user.json' },
      dependencies: ['setup'],
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 15'], storageState: 'playwright/.auth/user.json' },
      dependencies: ['setup'],
      grep: /@mobile/,
    },
  ],
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
        command: `npm run build && npm run start -- -p ${PORT}`,
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 180_000,
        stdout: 'pipe',
      },
})
```
Notes: `webServer.url` must return 2xx-403 when ready; default timeout is 60 s, so raise it for `next build`. In CI you may build in an earlier step and use `command: 'npm run start'`. Set `PLAYWRIGHT_BASE_URL` to test a Vercel preview deployment instead.

### Auth setup project
```ts
// e2e/auth.setup.ts
import { test as setup, expect } from '@playwright/test'

const authFile = 'playwright/.auth/user.json'

setup('authenticate', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill(process.env.E2E_USER_EMAIL!)
  await page.getByLabel('Password').fill(process.env.E2E_USER_PASSWORD!)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
  await page.context().storageState({ path: authFile })
})
```
For multiple roles save `admin.json`/`user.json` and use `test.use({ storageState: ... })` per file. For tests that mutate account state, use per-worker accounts keyed by `test.info().parallelIndex`.

### Custom fixtures
```ts
// e2e/fixtures.ts
import { test as base, expect } from '@playwright/test'

type Project = { id: string; name: string }

export const test = base.extend<{ project: Project }>({
  project: async ({ request }, use) => {
    const res = await request.post('/api/test/projects', { data: { name: `e2e-${crypto.randomUUID()}` } })
    expect(res.ok()).toBeTruthy()
    const project = (await res.json()) as Project
    await use(project)
    await request.delete(`/api/test/projects/${project.id}`)
  },
})
export { expect }
```
Guard test-only API routes behind an env flag that is never enabled in production.

### Network mocking
- Browser-originated requests: `await page.route('**/api.stripe.com/**', route => route.fulfill({ json: {...} }))`.
- Server-originated fetches in Next.js (RSC, Server Actions) are NOT visible to `page.route`. Options: point env vars at a mock server started in `webServer` array, or use Next's experimental test proxy (`experimental.testProxy` + `next/experimental/testmode/playwright` with `next.onFetch`) - experimental, Check current docs. See [testing-server-components-and-actions](../testing-server-components-and-actions/Skill.md).

### ARIA snapshots
```ts
await expect(page.getByRole('navigation', { name: 'Main' })).toMatchAriaSnapshot(`
  - link "Dashboard"
  - link "Projects"
  - button "Account"
`)
```
Partial matching: omitted names/attributes are not checked. Update with `--update-snapshots`. Store long snapshots in files with `{ name: 'nav.aria.yml' }`.

### Debugging
- `npx playwright test --ui` (UI mode, watch, time-travel).
- `npx playwright test --debug` (inspector), `npx playwright codegen http://localhost:3000` (locator discovery).
- `npx playwright show-trace trace.zip` or upload to trace.playwright.dev for CI failures.
- 1.59 added `npx playwright trace` CLI commands and `--debug=cli` for agent-driven debugging - Check current docs for exact syntax.

### Recent features to know (1.56-1.63)
| Version | Feature |
|---|---|
| 1.56 | Test agents (planner, generator, healer) via `npx playwright init-agents --loop=claude|vscode|opencode|codex` |
| 1.59 | Screencast API, `browser.bind()` for CLI/MCP clients, trace CLI |
| 1.60 | `locator.drop()` for external drag-and-drop/file drop |
| 1.61 | Virtual WebAuthn passkeys, `page.localStorage` access |
| 1.62 | Component testing stable (stories/galleries + `mount` fixture), `retryStrategy: 'isolated'`, WebP screenshots |
| 1.63 | Test locks for shared resources, `locator.visible()`, aria/screen snapshots in traces |
Exact option names for newest APIs: Check current docs.

### AI test agents and MCP
- `init-agents` generates agent definitions, a `specs/` folder for Markdown plans, and `seed.spec.ts` that bootstraps the page context. Planner explores and writes a plan; generator writes tests; healer runs and repairs failing tests. Always review generated tests for weak assertions and brittle locators.
- Playwright MCP (`claude mcp add playwright npx @playwright/mcp@latest`) drives a browser via accessibility snapshots. Playwright's README recommends the Playwright CLI + skills for most coding agents (more token-efficient), MCP for exploratory/stateful sessions. See [browser-automation-agent-workflow](../browser-automation-agent-workflow/Skill.md).

## Recommended Workflow
1. `npm init playwright@latest`, choose TypeScript, `e2e/` folder, GitHub Actions workflow.
2. Replace config with the Next.js-aware config above.
3. Add auth setup project and fixtures for seeded data.
4. Write one spec per journey; use codegen to discover locators, then hand-edit to role-based locators.
5. Run locally with `--ui`; then `--repeat-each=5` to shake out flakiness.
6. Wire CI with sharding + blob report merge; upload HTML report and traces.
7. Review flaky report weekly.

## Patterns
- **Page object light**: small classes/functions per page exposing intent (`projectsPage.create(name)`) returning locators; keep assertions in tests.
- **API seeding + UI assertion**: create data via `request`, verify via UI.
- **Wait for server response when needed**: `const resp = page.waitForResponse(r => r.url().includes('/api/save') && r.ok()); await click; await resp`.
- **Server Action form flow**: fill, submit, assert on success message/redirect with `await expect(page).toHaveURL(/\/projects\/\w+/)`.
- **Time control**: `await page.clock.install({ time: new Date('2026-01-01T09:00:00') })` before `goto`.

## Anti-Patterns
- **`page.waitForTimeout(3000)`**: slow and flaky. Fix: web-first assertions or `waitForResponse`.
- **CSS/XPath selectors tied to Tailwind classes**. Fix: roles/labels/test IDs.
- **`expect(await locator.isVisible()).toBe(true)`**: no retry. Fix: `await expect(locator).toBeVisible()`.
- **Shared mutable account across parallel tests**. Fix: per-worker accounts or unique data.
- **Logging in through UI in every test**. Fix: setup project + storageState.
- **Running against `next dev` in CI**: compile-on-demand timeouts. Fix: production build.
- **`networkidle` waits in Next.js apps**: streaming, prefetch and analytics keep network busy. Fix: wait for specific UI state.
- **Retries hiding real failures**. Fix: treat "flaky" results as bugs; see [flaky-test-management](../flaky-test-management/Skill.md).
- **Committing `playwright/.auth/*.json`**: leaks session cookies. Fix: gitignore.

## Accessibility
- Run `@axe-core/playwright` on key pages and states; configuration and triage are owned by [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).
- Test keyboard journeys: `await page.keyboard.press('Tab')`, `await expect(page.getByRole('menuitem', { name: 'Settings' })).toBeFocused()`.
- ARIA snapshots guard landmark/heading/name structure against regressions.
- Emulate `reducedMotion: 'reduce'` and `colorScheme: 'dark'` via `test.use` for relevant flows.

## Responsive Design
Use device projects (`devices['Pixel 7']`, `devices['iPhone 15']`) or `test.use({ viewport: { width: 390, height: 844 } })`. Assert mobile-only UI (drawer nav, bottom bar). WebKit on Linux approximates Safari but is not real iOS Safari - see [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md).

## Performance
- Shard in CI (`--shard=i/n`) with `fullyParallel` for balanced shards; merge blob reports.
- Reuse one production build across shards (build job -> artifact) instead of building per shard.
- Block heavy third-party scripts via `page.route` in tests that do not need them.
- Chromium-only on PRs; full browser matrix on main/nightly.

## Security
- Store test credentials in CI secrets; read via `process.env`. Never hardcode.
- Test-only routes/seed endpoints must be disabled unless an explicit env flag is set and never deployed to production.
- Traces, videos and HTML reports can contain tokens, cookies and PII - restrict artifact access and retention.
- Include authorization E2E: a normal user gets 403/redirect on admin pages and cannot invoke admin Server Actions.

## Testing
- Stability check: `npx playwright test --repeat-each=10 --workers=4 e2e/new.spec.ts` before merging new specs.
- Track flaky counts in the HTML/JSON report per run.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| `@playwright/test` | 1.63.0 |
| Playwright VS Code extension | Active |
| `@axe-core/playwright` | Active |
| `@playwright/mcp` | Active; agent browser control |
| Playwright Test Agents | Introduced 1.56; review generated output |
| `next/experimental/testmode/playwright` | Experimental |
| Official Docker image `mcr.microsoft.com/playwright:v<version>-noble` | Pin to installed version (Check current docs for tag) |

## Framework Notes
- **Next.js**: Official guide recommends testing against production build. `page.route` only intercepts browser requests, not server-side fetches from RSC/Server Actions. Server Actions post to the page route; assert UI outcome rather than internal action IDs. Use `PLAYWRIGHT_BASE_URL` to run against preview deployments (handle Vercel deployment protection with a bypass header from secrets - Check current Vercel docs).
- **React (Vite SPA)**: `webServer.command: 'npm run build && npm run preview -- --port 4173'`; all requests originate in the browser so `page.route`/MSW browser worker can mock everything.

## AI Agent Guidance
- Do: use `getByRole`/`getByLabel` locators and web-first assertions; `await` every Playwright call.
- Do: run the new spec with `--repeat-each=3` at least; inspect trace on failure before changing code.
- Do: when using Playwright MCP or test agents, convert exploratory findings into deterministic spec files and review them.
- Don't: add `waitForTimeout`, raise global timeouts, or add retries to force green.
- Don't: test against production data or commit auth state.
- Before done: spec passes in CI config locally (`CI=1 npx playwright test file`), no `test.only`, locators are role-based, failure produces a useful trace.

## Examples
```ts
// e2e/projects.spec.ts
import { test, expect } from './fixtures'

test.describe('projects', () => {
  test('create a project and see it persisted', { tag: '@smoke' }, async ({ page }) => {
    await page.goto('/projects')
    await page.getByRole('button', { name: 'New project' }).click()

    const dialog = page.getByRole('dialog', { name: 'Create project' })
    const name = `Apollo ${Date.now()}`
    await dialog.getByLabel('Name').fill(name)
    await dialog.getByRole('button', { name: 'Create' }).click()

    await expect(page).toHaveURL(/\/projects\/[\w-]+$/)
    await expect(page.getByRole('heading', { level: 1, name })).toBeVisible()

    await page.reload()
    await expect(page.getByRole('heading', { level: 1, name })).toBeVisible()
  })

  test('rename shows validation error for empty name', async ({ page, project }) => {
    await page.goto(`/projects/${project.id}/settings`)
    await page.getByLabel('Name').clear()
    await page.getByRole('button', { name: 'Save' }).click()
    await expect(page.getByRole('alert')).toHaveText(/name is required/i)
  })
})
```

## Related Skills
- [frontend-testing-strategy](../frontend-testing-strategy/Skill.md) - what belongs in E2E
- [testing-server-components-and-actions](../testing-server-components-and-actions/Skill.md) - server-side mocking in E2E
- [test-data-and-fixtures](../test-data-and-fixtures/Skill.md) - seeding and fixtures
- [visual-regression-testing](../visual-regression-testing/Skill.md) - `toHaveScreenshot`
- [flaky-test-management](../flaky-test-management/Skill.md) - retries and quarantine
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) - sharding and artifacts
- [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md) - browser matrix and cloud grids
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) - axe in Playwright
- [browser-automation-agent-workflow](../browser-automation-agent-workflow/Skill.md) - agent-driven browser use

## Sources
- [Next.js: Setting up Playwright](https://nextjs.org/docs/app/guides/testing/playwright) - Official - production build recommendation
- [Playwright Best Practices](https://playwright.dev/docs/best-practices) - Official - isolation, locators, web-first assertions
- [Playwright Authentication](https://playwright.dev/docs/auth) - Official - setup project and storageState
- [Playwright webServer](https://playwright.dev/docs/test-webserver) - Official - options
- [Playwright ARIA snapshots](https://playwright.dev/docs/aria-snapshots) - Official - toMatchAriaSnapshot
- [Playwright Clock](https://playwright.dev/docs/clock) - Official - time control
- [Playwright Test Agents](https://playwright.dev/docs/test-agents) - Official - planner/generator/healer
- [Playwright release notes](https://playwright.dev/docs/release-notes) - Official - 1.56-1.63 features
- [Playwright MCP README](https://github.com/microsoft/playwright-mcp) - Open Source - MCP vs CLI guidance
- [Next.js experimental test mode README](https://github.com/vercel/next.js/tree/canary/packages/next/src/experimental/testmode/playwright) - Open Source - server fetch interception

## License / Usage Notes
Playwright and Playwright MCP are Apache-2.0. Next.js is MIT. Content summarized; code is original.

## Quality Tier
S - Built from current official Playwright and Next.js docs with complete config, auth, fixtures, CI and agent guidance; newest-API option names flagged.

## Status
Active

## Last Verified
2026-09-15
