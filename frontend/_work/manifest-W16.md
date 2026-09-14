# Manifest - W16 Testing & QA

Scope: React + Next.js (TypeScript) only. Last Verified: 2026-09-15.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| frontend-testing-strategy | Frontend Testing Strategy | Testing & QA | React, Next.js | A | Active | https://nextjs.org/docs/app/guides/testing |
| vitest-unit-testing | Vitest Unit Testing | Testing & QA | React (Vite), Next.js | A | Active | https://vitest.dev/guide/browser/ |
| jest-testing | Jest Testing | Testing & QA | React, Next.js | A | Active | https://nextjs.org/docs/app/guides/testing/jest |
| testing-library-principles | Testing Library Principles | Testing & QA | React, Next.js | S | Active | https://testing-library.com/docs/queries/about/ |
| playwright-e2e-testing | Playwright E2E Testing | Testing & QA | React (Vite), Next.js | S | Active | https://playwright.dev/docs/best-practices |
| cypress-e2e-testing | Cypress E2E Testing | Testing & QA | React (Vite), Next.js | B | Active | https://nextjs.org/docs/app/guides/testing/cypress |
| visual-regression-testing | Visual Regression Testing | Testing & QA | React, Next.js | A | Active | https://playwright.dev/docs/test-snapshots |
| storybook-component-workshop | Storybook Component Workshop | Testing & QA | React (Vite), Next.js | A | Active | https://storybook.js.org/docs/get-started/frameworks/nextjs-vite |
| api-mocking-msw | API Mocking with MSW | Testing & QA | React (Vite), Next.js | A | Active | https://mswjs.io/docs/integrations/node |
| lighthouse-ci | Lighthouse CI | Testing & QA | React (Vite), Next.js | A | Active | https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/getting-started.md |
| cross-browser-and-device-testing | Cross-Browser and Device Testing | Testing & QA | React, Next.js | B | Active | https://playwright.dev/docs/best-practices |
| flaky-test-management | Flaky Test Management | Testing & QA | React, Next.js | A | Active | https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html |
| frontend-ci-cd-pipelines | Frontend CI/CD Pipelines | Testing & QA | React (Vite), Next.js | A | Active | https://nextjs.org/docs/app/guides/ci-build-caching |
| component-testing | Component Testing | Testing & QA | React (Vite), Next.js | A | Active | https://vitest.dev/guide/browser/ |
| test-data-and-fixtures | Test Data and Fixtures | Testing & QA | React, Next.js | B | Active | https://playwright.dev/docs/test-fixtures |
| testing-server-components-and-actions (NEW) | Testing Server Components and Server Actions | Testing & QA | Next.js | A | Active | https://nextjs.org/docs/app/api-reference/file-conventions/proxy |
| test-coverage-and-mutation-testing (NEW) | Test Coverage and Mutation Testing | Testing & QA | React (Vite), Next.js | B | Active | https://vitest.dev/guide/coverage |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Next.js Testing overview | https://nextjs.org/docs/app/guides/testing | Official | Test types; async Server Components -> E2E | Framework authority on RSC testability | High | 2026-09-15 |
| Next.js Vitest guide | https://nextjs.org/docs/app/guides/testing/vitest | Official | Packages, vitest.config.mts, sync vs async component support (docs v16.3.5) | Canonical setup | High | 2026-09-15 |
| Next.js Jest guide | https://nextjs.org/docs/app/guides/testing/jest | Official | next/jest auto-config list, moduleNameMapper, jest-dom v6 | Canonical Jest setup | High | 2026-09-15 |
| Next.js Playwright guide | https://nextjs.org/docs/app/guides/testing/playwright | Official | Test against production build; webServer | E2E environment choice | High | 2026-09-15 |
| Next.js Cypress guide | https://nextjs.org/docs/app/guides/testing/cypress | Official | E2E/CT config, CT async RSC limitation, start-server-and-test | Cypress with Next | High | 2026-09-15 |
| Next.js CI build caching | https://nextjs.org/docs/app/guides/ci-build-caching | Official | actions/cache snippet for .next/cache | CI speed | High | 2026-09-15 |
| Next.js proxy.js reference | https://nextjs.org/docs/app/api-reference/file-conventions/proxy | Official | unstable_doesProxyMatch, isRewrite/getRewrittenUrl; middleware->proxy rename v16; Server Function auth warning | Server-side unit testing and security | High | 2026-09-15 |
| Next.js experimental testmode README | https://github.com/vercel/next.js/tree/canary/packages/next/src/experimental/testmode/playwright | Open Source | experimental.testProxy, next.onFetch, external-only interception | Server fetch mocking in E2E | Medium (experimental) | 2026-09-15 |
| Vitest Browser Mode | https://vitest.dev/guide/browser/ | Official | Providers, config, vitest-browser-react | Real-browser component tests | High | 2026-09-15 |
| Vitest 4.0 announcement | https://vitest.dev/blog/vitest-4 | Official | Browser Mode stable, provider packages, toMatchScreenshot, traces | Version-sensitive APIs | High | 2026-09-15 |
| Vitest 5.0 announcement | https://vitest.dev/blog/vitest-5 | Official | Node>=22.12, Vite>=6.4, clearMocks default, strict locators, unawaited assertion failures, trace view | Current major | High | 2026-09-15 |
| Vitest environments | https://vitest.dev/guide/environment | Official | node/jsdom/happy-dom/edge-runtime trade-offs | Environment choice | High | 2026-09-15 |
| Vitest visual regression | https://vitest.dev/guide/browser/visual-regression-testing | Official | toMatchScreenshot options, baseline location, Docker advice | Visual testing option | High | 2026-09-15 |
| npm registry (vitest, @playwright/test, msw, cypress, jest, storybook, @lhci/cli, user-event) | https://registry.npmjs.org/ | Official | Latest versions: 5.0.0, 1.63.0, 2.15.0, 16.0.0, 30.5.1, 10.6.0, 0.15.1, 14.6.7 | Version accuracy | High | 2026-09-15 |
| Testing Library guiding principles | https://testing-library.com/docs/guiding-principles | Official | Behavior-first principles | Foundation of query discipline | High | 2026-09-15 |
| Testing Library queries | https://testing-library.com/docs/queries/about/ | Official | Priority order, variant table | Core reference | High | 2026-09-15 |
| user-event intro | https://testing-library.com/docs/user-event/intro | Official | setup() pattern, vs fireEvent | Interaction realism | High | 2026-09-15 |
| Playwright best practices | https://playwright.dev/docs/best-practices | Official | Isolation, locators, web-first assertions, CI tips | E2E quality | High | 2026-09-15 |
| Playwright release notes | https://playwright.dev/docs/release-notes | Official | 1.56-1.63 features (agents, CT stable, isolated retries, test locks) | Current capabilities | High | 2026-09-15 |
| Playwright auth | https://playwright.dev/docs/auth | Official | Setup project, storageState, roles, per-worker accounts | Fast isolated auth | High | 2026-09-15 |
| Playwright webServer | https://playwright.dev/docs/test-webserver | Official | Options (url, reuseExistingServer, timeout, wait, multiple) | Next.js server boot | High | 2026-09-15 |
| Playwright aria snapshots | https://playwright.dev/docs/aria-snapshots | Official | toMatchAriaSnapshot syntax, partial matching, file storage | Structural regression tests | High | 2026-09-15 |
| Playwright visual comparisons | https://playwright.dev/docs/test-snapshots | Official | toHaveScreenshot options, same-environment advice | Visual testing | High | 2026-09-15 |
| Playwright sharding | https://playwright.dev/docs/test-sharding | Official | Blob reporter, merge-reports YAML, fullyParallel balance | CI speed | High | 2026-09-15 |
| Playwright CI intro | https://playwright.dev/docs/ci-intro | Official | GitHub Actions workflow and action majors | CI baseline | High | 2026-09-15 |
| Playwright retries | https://playwright.dev/docs/test-retries | Official | Flaky classification, serial mode retries | Flake detection | High | 2026-09-15 |
| Playwright clock | https://playwright.dev/docs/clock | Official | install/setFixedTime/fastForward/runFor | Time determinism | High | 2026-09-15 |
| Playwright test agents | https://playwright.dev/docs/test-agents | Official | planner/generator/healer, init-agents loops, specs/seed layout | AI-assisted test authoring | High | 2026-09-15 |
| Playwright component testing | https://playwright.dev/docs/test-components | Official | Stable in 1.62; stories/galleries; experimental-ct packages discontinued | Component test option | Medium (new model) | 2026-09-15 |
| Playwright MCP README | https://github.com/microsoft/playwright-mcp | Open Source | Accessibility-snapshot automation; CLI+skills recommended for coding agents | Agent workflows | High | 2026-09-15 |
| Cypress React CT overview | https://docs.cypress.io/app/component-testing/react/overview | Official | React 18/19; Vite, webpack, Next.js 15/16 support | Cypress CT scope | High | 2026-09-15 |
| Storybook Next.js Vite | https://storybook.js.org/docs/get-started/frameworks/nextjs-vite | Official | Setup, navigation mock, experimentalRSC, limitations | Storybook for Next | High | 2026-09-15 |
| Storybook Vitest addon | https://storybook.js.org/docs/writing-tests/integrations/vitest-addon | Official | Config, requirements, CI command | Stories as tests | High | 2026-09-15 |
| Storybook interaction testing | https://storybook.js.org/docs/writing-tests/interaction-testing | Official | play, fn, mount, beforeEach | Interaction tests | High | 2026-09-15 |
| Storybook accessibility testing | https://storybook.js.org/docs/writing-tests/accessibility-testing | Official | a11y.test values, axe config, region rule default | A11y in stories | High | 2026-09-15 |
| Storybook visual tests | https://storybook.js.org/docs/writing-tests/visual-testing | Official | Visual Tests addon with Chromatic | Visual workflow | High | 2026-09-15 |
| MSW Node integration | https://mswjs.io/docs/integrations/node | Official | setupServer lifecycle, events | Unit test mocking | High | 2026-09-15 |
| MSW Browser integration | https://mswjs.io/docs/integrations/browser | Official | msw init, await worker.start, env gating | Dev/Storybook mocking | High | 2026-09-15 |
| MSW issue #1644 | https://github.com/mswjs/msw/issues/1644 | Open Source | App Router server-side limitation, open status | Next.js caveat | Medium | 2026-09-15 |
| Chromatic docs | https://www.chromatic.com/docs/ | Official | TurboSnap, SteadySnap, integrations, snapshot pricing | Visual SaaS option | High | 2026-09-15 |
| Argos docs (llms-full) | https://argos-ci.com/docs/llms-full.txt | Official | Playwright SDK, reporter, ARGOS_TOKEN/OIDC, MIT license, flaky detection | OSS visual option | High | 2026-09-15 |
| Lost Pixel repo | https://github.com/lost-pixel/lost-pixel | Open Source | Archived 2026-04-22 | Avoid adopting dead tool | High | 2026-09-15 |
| Lighthouse CI getting started | https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/getting-started.md | Official | collect/assert/upload, GitHub App token, variance note | Perf gating | High | 2026-09-15 |
| BrowserStack Playwright | https://www.browserstack.com/docs/automate/playwright | Official | SDK, browserstack.yml, Local tunnel | Real-device cloud | Medium | 2026-09-15 |
| Sauce Labs Playwright | https://docs.saucelabs.com/web-apps/automated-testing/playwright/ | Official | saucectl, config.yml, supported browsers | Cloud grid | Medium | 2026-09-15 |
| Testing Trophy (Kent C. Dodds) | https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications | Community | Static/unit/integration/E2E allocation | Strategy model | High | 2026-09-15 |
| Google Testing Blog - flaky tests | https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html | Official (Google) | Mitigation strategies, reliability philosophy | Flake policy | High | 2026-09-15 |
| Martin Fowler - non-determinism | https://martinfowler.com/articles/nonDeterminism.html | Community | Causes (isolation, async, remote, time, leaks) and quarantine | Flake root causes | High | 2026-09-15 |
| anthropics/skills webapp-testing | https://github.com/anthropics/skills/tree/main/skills/webapp-testing | Open Source | Reconnaissance-then-action pattern, server helper, Python Playwright | Agent testing workflow reference (translated to TS guidance) | Medium | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Next.js test setup (Vitest/Jest/Playwright/Cypress) | Next.js testing guides | Vercel with-* examples | vitest-unit-testing, jest-testing, playwright-e2e-testing, cypress-e2e-testing |
| Query priority / user-centric selectors | Testing Library queries docs | Playwright locator best practices, Storybook canvas queries | testing-library-principles |
| Screenshot comparison | Playwright test-snapshots | Vitest toMatchScreenshot, Chromatic, Argos, Percy, Lost Pixel | visual-regression-testing |
| Stories as tests / component isolation | Storybook Vitest addon | Playwright CT stories/galleries, Cypress CT, Vitest Browser Mode | component-testing (comparison) + storybook-component-workshop (Storybook depth) |
| Flaky test causes and remedies | Google Testing Blog | Martin Fowler non-determinism, Playwright retries docs | flaky-test-management |
| Server-side fetch mocking in Next.js | Next.js experimental testmode README | MSW issue #1644, env-pointed mock servers | testing-server-components-and-actions (api-mocking-msw links to it) |
| Agent-driven browser testing | Playwright test agents + Playwright MCP | anthropics/skills webapp-testing | playwright-e2e-testing (AI Agent Guidance); deeper workflow deferred to W17 browser-automation-agent-workflow |
| Automated axe checks | W11 automated-accessibility-testing | Storybook a11y addon, @axe-core/playwright, Lighthouse a11y | Linked only (not duplicated) |

## Gaps

- WebSearch quota exhausted; all research via WebFetch against official docs and npm registry. Summaries from WebFetch's extraction model may omit option-level details; exact option names for newest APIs (Playwright 1.59-1.63, Vitest 5 browser render await, Storybook `sb.mock`, Playwright WebP snapshots) are flagged "Check current docs" in skills.
- Vitest coverage guide and StrykerJS docs were not fetched this session (test-coverage-and-mutation-testing rated B); Stryker Vitest runner compatibility with Vitest 5 unverified.
- Percy Playwright docs redirected and were not verified; LambdaTest not verified; real iOS Safari support for Playwright on cloud grids unverified.
- MSW Next.js App Router server-side status taken from issue #1644 (open); no official MSW Next.js integration page was fetched; `jest-fixed-jsdom` recommendation unverified.
- No first-class React/Next.js utility for unit-rendering async Server Components found; workaround documented as unofficial.
- Cypress 16 changelog (WebKit status, GitHub Action major) not reviewed.
- CI analytics/flake-tracking vendors (Currents, Trunk, Datadog CI Visibility, BuildPulse) listed without verification.
- `@faker-js/faker`, `fishery`, `@mswjs/data`, Testcontainers maintenance/version status not verified.
- Vercel deployment protection bypass header specifics for preview E2E not verified.
- No dedicated skill for contract testing (Pact/OpenAPI schema validation) or load testing; considered out of frontend scope or low value for this library.
