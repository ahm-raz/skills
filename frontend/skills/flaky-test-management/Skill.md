# Flaky Test Management

## Summary
A flaky test passes and fails on the same code. Flakiness destroys trust in CI, wastes engineer time and hides real bugs. This skill covers detecting flaky tests (retries classification, repeat runs, CI analytics), diagnosing the usual root causes in React/Next.js suites (async timing, shared state, test order, time, network, animations, resource contention, environment differences), fixing them with concrete patterns in Vitest, Testing Library and Playwright, and running a quarantine policy that does not become a graveyard.

## Category
Testing & QA

## Subcategories
Flake detection, root cause analysis, quarantine, retries policy, test isolation, deterministic time and data, Playwright trace debugging, CI reliability metrics

## Problem It Solves
Teams re-run CI until green, add retries and timeouts, and eventually ignore red builds. Google's testing blog describes flakiness as a pervasive problem that degrades signal and notes that a test that fails reliably is far better than a flaky one. Martin Fowler's analysis identifies isolation, async behavior, remote services, time and resource leaks as primary causes. A systematic process restores trust.

## When To Use
- A test failed in CI and passed on re-run.
- Playwright reports tests as "flaky" (passed on retry).
- CI re-run rate or time-to-green is rising.
- Introducing retries or quarantine policies.

## When Not To Use
- Consistently failing tests - that is a real failure; fix or revert.
- Infrastructure outages (runner crashes, registry down) - handle as CI reliability, not test flake, though track them.

## Core Principles
1. Flaky tests are bugs - in the test, the app, or the environment. Sometimes the flake is a real race condition in production code.
2. Retries are for detection and short-term relief, never the fix.
3. Reproduce before fixing: repeat runs, stress (CPU throttling, parallel workers), random order.
4. Quarantine fast, fix with an owner and deadline, delete if unfixable and low value.
5. Measure: flake rate per test, re-run rate per pipeline.

## Best Practices
- Playwright: `retries: 2` in CI only, `trace: 'on-first-retry'`; review the "flaky" section of reports weekly; consider `failOnFlakyTests` for critical suites (Check current docs).
- Vitest: `--sequence.shuffle` periodically to expose order dependence; `--retry` only while diagnosing.
- New tests must pass `--repeat-each=10` (Playwright) or a loop of runs before merge.
- Ban `waitForTimeout`/`sleep` via lint (`playwright/no-wait-for-timeout`).
- Use deterministic data: unique IDs per test, seeded factories, frozen clocks.
- Record CI environment details (browser version, runner type, worker count) in reports.
- Keep a quarantine list with owner, issue link and expiry date.

## Implementation Guidance

### Detection
| Signal | How |
|---|---|
| Passed on retry | Playwright status `flaky`; JUnit/JSON reporters; Vitest reports retried tests (Check current docs for reporter fields) |
| Repeated runs | `npx playwright test file --repeat-each=20 --workers=4`; `for i in $(seq 20); do npx vitest run file || break; done` |
| Order dependence | `vitest run --sequence.shuffle`; Playwright `fullyParallel` exposes shared state |
| Historical | CI analytics (Cypress Cloud, Currents, Datadog CI Visibility, Trunk, BuildPulse - Check current docs), or parse JUnit artifacts over time |

### Root cause -> fix table
| Symptom | Likely cause | Fix |
|---|---|---|
| Element not found intermittently (RTL) | Asserting before async render | `await screen.findBy*`; await user-event |
| `act(...)` warnings, state updates after test | Unawaited promises, timers | Await UI outcome; fake timers with `advanceTimers` |
| Passes alone, fails in suite | Shared module state, MSW handler/QueryClient/cache leakage, DOM not cleaned | Reset in `afterEach`, new QueryClient per test, `server.resetHandlers()` |
| Playwright click "element intercepted" | Overlay/animation/toast covering | Wait for overlay to disappear via assertion; `reducedMotion: 'reduce'`; dismiss toasts |
| Timeout on first test of shard | Next dev compile, cold server | Test against `next start`; warm-up in setup project |
| Data collisions under parallelism | Shared accounts/records | Per-worker accounts, unique names (`crypto.randomUUID()`), API seeding in fixtures |
| Fails near midnight/month end/DST | Real clock | `vi.setSystemTime`, `page.clock.setFixedTime`, fixed TZ (`TZ=UTC`) and locale |
| Fails only in CI | CPU contention, fonts, locale, screen size | Reduce workers, pin Docker image, set `locale`/`timezoneId` in Playwright `use` |
| Visual diffs of 1-2 px | Font loading, subpixel AA, animations | `document.fonts.ready`, `animations: 'disabled'`, same OS image |
| Third-party script errors | Real network | `page.route` block/mock; MSW `onUnhandledRequest: 'error'` |
| Streaming/hydration race (Next.js) | Clicking before hydration attaches handlers | Assert an element that renders only after hydration, or wait for a hydrated marker; ensure progressive-enhancement forms |
| `networkidle` waits time out | Prefetch/analytics/long polling | Wait on specific UI or response |

### Playwright determinism config
```ts
use: {
  locale: 'en-US',
  timezoneId: 'UTC',
  colorScheme: 'light',
  reducedMotion: 'reduce',
  viewport: { width: 1280, height: 800 },
  trace: 'on-first-retry',
},
retries: process.env.CI ? 2 : 0,
```

### Quarantine mechanics
```ts
// Playwright: explicit, visible, tracked
test('exports CSV', { tag: ['@quarantine'], annotation: { type: 'issue', description: 'https://github.com/org/repo/issues/1234' } }, async ({ page }) => {
  // ...
})
```
- Main CI: `--grep-invert @quarantine`. Separate non-blocking job: `--grep @quarantine --repeat-each=5` to verify fixes.
- Vitest: move to a `quarantine` project or use `test.skip` with issue link and lint rule that requires a link.
- Policy: quarantine requires owner + issue + expiry (e.g., 14 days); expired quarantines are escalated or deleted.

### Diagnosing with Playwright traces
1. Download the trace artifact from the failed attempt.
2. `npx playwright show-trace trace.zip` - inspect action timeline, DOM snapshots before/after, network, console.
3. Compare the failed attempt with the passing retry trace.
4. Look for: action performed before expected state, overlapping requests, console errors, slow responses.

### Hydration-safe waiting (Next.js)
```tsx
// app/providers.tsx (test-only marker; harmless in prod or gate by env)
'use client'
import { useEffect } from 'react'
export function HydrationMarker() {
  useEffect(() => { document.documentElement.dataset.hydrated = 'true' }, [])
  return null
}
```
```ts
await page.goto('/projects')
await expect(page.locator('html[data-hydrated="true"]')).toBeAttached()
```
Prefer designing interactions to work before hydration (native forms with Server Actions) over marker waits.

## Recommended Workflow
1. Detect: flaky report or CI re-run.
2. Triage within 24 h: is it a product bug? Check trace/logs.
3. If not immediately fixable, quarantine with owner, issue and expiry.
4. Reproduce locally with repeat/stress/shuffle, CI Docker image, reduced CPU.
5. Fix root cause using the table; never only add retries/timeouts.
6. Verify with `--repeat-each=20` in CI-like environment; unquarantine.
7. Record cause category in the issue; review categories monthly to fix systemic problems (e.g., data isolation).

## Patterns
- **Unique data per test**: fixture creates namespaced records, cleans up in teardown.
- **Wait for the cause, not time**: `await Promise.all([page.waitForResponse(isSave), button.click()])`.
- **Fresh state per test**: new `QueryClient`, `server.resetHandlers()`, `localStorage.clear()` (Vitest), new browser context (Playwright default).
- **Flake budget**: dashboard of flake rate; alert above threshold (e.g., > 1% of runs).
- **Stress mode job**: nightly job running new/changed tests with `--repeat-each` and reduced workers.

## Anti-Patterns
- **Global `retries: 5`**: hides regressions and slows CI. Fix: 0 locally, <= 2 in CI, investigate every flaky result.
- **Increasing timeouts**: masks slow app or wrong wait. Fix: wait on correct condition; investigate slowness.
- **`waitForTimeout`/`sleep`**. Fix: web-first assertions.
- **Permanent quarantine**. Fix: expiry dates and ownership.
- **Deleting a flaky test covering a critical path without replacement**. Fix: rewrite at a lower, more deterministic layer.
- **Serial mode to hide shared state**. Fix: isolate data.
- **Blaming CI and re-running**. Fix: track re-runs; require issue for each.

## Accessibility
Many flakes come from animations and focus timing; honoring `prefers-reduced-motion` in the app (and emulating it in tests) improves both determinism and accessibility (WCAG 2.3.3). Waiting for accessible state (e.g., `aria-busy="false"`, dialog role visible) is more reliable than CSS class checks.

## Responsive Design
Flakes that appear only on mobile projects often involve sticky headers covering targets or off-canvas animation; use `scrollIntoViewIfNeeded` implicitly via locators and wait for drawer open state.

## Performance
Flakiness correlates with resource contention: too many workers on small runners. Tune `workers` to CPU count, use sharding across machines instead of oversubscribing one runner.

## Security
Traces and videos used for flake diagnosis can contain credentials/PII; restrict artifact access and retention.

## Testing
Measure: flake rate = flaky results / total results per test over N days; CI re-run rate; mean time to fix quarantined tests.

## Tooling
| Tool | Use |
|---|---|
| Playwright retries, trace viewer, `--repeat-each`, HTML report flaky section | Detection and diagnosis |
| Playwright `retryStrategy: 'isolated'` (1.62) | Retries failed tests sequentially at end - reduces contention-induced flake (Check current docs) |
| Playwright test locks (1.63) | Serialize access to shared resources |
| Vitest `--sequence.shuffle`, `--retry` | Order dependence detection |
| `eslint-plugin-playwright`, `eslint-plugin-testing-library` | Ban flaky patterns |
| CI analytics (Cypress Cloud, Currents, Datadog CI Visibility, Trunk Flaky Tests) | Historical flake tracking - Check current docs |

## Framework Notes
- **Next.js**: Common sources are testing against `next dev`, clicking before hydration, streaming Suspense boundaries resolving at different times, prefetching affecting `networkidle`, and caches shared across tests on the same server (unique data per test; avoid relying on `revalidate` timing).
- **React (Vite SPA)**: Common sources are React Query cache leakage, unmocked network, and route transitions with lazy chunks (wait on target UI).

## AI Agent Guidance
- Do: when a test is flaky, reproduce with repeat runs and inspect traces before editing.
- Do: fix with correct waits, isolation or determinism; document the cause in the commit message.
- Don't: add retries, bigger timeouts, `waitForTimeout`, or `test.skip` as the fix without explicit user approval and an issue link.
- Don't: mark a failing test flaky without evidence (a passing retry).
- Before done: test passes `--repeat-each=20` (or 20 loop runs) in CI-like conditions; no new sleeps; quarantine tag removed if applicable.

## Examples
Fixing a classic Playwright race:
```ts
// Flaky: clicks "Save" then immediately navigates, sometimes before request completes
await page.getByRole('button', { name: 'Save' }).click()
await page.goto('/projects')
await expect(page.getByText('Apollo v2')).toBeVisible()

// Fixed: wait for the user-visible confirmation (or the response) before navigating
await page.getByRole('button', { name: 'Save' }).click()
await expect(page.getByRole('status')).toHaveText('Saved')
await page.goto('/projects')
await expect(page.getByRole('link', { name: 'Apollo v2' })).toBeVisible()
```
Fixing a Vitest leak:
```ts
// Flaky: module-level QueryClient shares cache across tests
const queryClient = new QueryClient()

// Fixed: create per render in a helper
export function renderWithProviders(ui: ReactElement) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(<QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>)
}
```

## Related Skills
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - retries and traces
- [test-data-and-fixtures](../test-data-and-fixtures/Skill.md) - isolation via data
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) - quarantine jobs and artifacts
- [visual-regression-testing](../visual-regression-testing/Skill.md) - visual flake
- [testing-library-principles](../testing-library-principles/Skill.md) - async query discipline
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) - reduced motion

## Sources
- [Flaky Tests at Google and How We Mitigate Them](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html) - Official (Google Testing Blog) - mitigation strategies, reliability philosophy
- [Eradicating Non-Determinism in Tests (Martin Fowler)](https://martinfowler.com/articles/nonDeterminism.html) - Community - causes and quarantine
- [Playwright Retries](https://playwright.dev/docs/test-retries) - Official - flaky classification, testInfo.retry, serial mode
- [Playwright release notes](https://playwright.dev/docs/release-notes) - Official - isolated retries, test locks
- [Playwright Clock](https://playwright.dev/docs/clock) - Official - time determinism

## License / Usage Notes
Articles summarized in original words; Playwright Apache-2.0, Vitest MIT. Examples original.

## Quality Tier
A - Combines authoritative flake research with concrete, framework-specific fixes; some newer Playwright options and third-party analytics flagged.

## Status
Active

## Last Verified
2026-09-15
