# Cross-Browser and Device Testing

## Summary
Cross-browser and device testing verifies that a React/Next.js app works and renders acceptably across browser engines (Chromium, Gecko/Firefox, WebKit/Safari), operating systems, real mobile devices, input types and viewports. This skill defines a risk-based browser matrix, how far Playwright's bundled engines and device emulation get you, when to use real-device clouds (BrowserStack, Sauce Labs, LambdaTest), and how to structure CI so coverage is broad without slowing every PR.

## Category
Testing & QA

## Subcategories
Browser support matrix, Playwright projects, device emulation, real device clouds, BrowserStack, Sauce Labs, iOS Safari quirks, Browserslist, progressive enhancement checks

## Problem It Solves
Most teams develop and test only in Chrome. Safari-specific bugs (date inputs, `100vh` and dynamic viewport units, flex/gap in old versions, `position: sticky` in overflow containers, autoplay, WebAuthn, IndexedDB), Firefox differences, and touch/virtual-keyboard problems surface in production. Testing every browser on every PR is too slow and expensive without a strategy.

## When To Use
- Defining supported browsers for a product.
- Before releases of consumer-facing, checkout, or media-heavy features.
- When analytics show significant Safari/iOS or Firefox share.
- When using newer platform features (View Transitions, popover, anchor positioning, container queries).

## When Not To Use
- Internal tools with a mandated single browser (still test the mandated one).
- Unit/component tests - engine differences rarely matter in jsdom; keep those single-environment.

## Core Principles
1. Base the matrix on real analytics and business risk, not "test everything".
2. Engines first (Chromium, Firefox, WebKit) via Playwright; real devices for what emulation cannot reproduce.
3. Chromium on every PR; full engine matrix on main/nightly/release.
4. Emulation is not reality: Playwright WebKit is not identical to Safari on iOS; device descriptors emulate viewport/UA/touch, not the real OS browser.
5. Feature-detect and progressively enhance; test the fallback path.

## Best Practices
- Publish a support policy (e.g., "last 2 versions of evergreen browsers, Safari >= 16.4, iOS Safari >= 16.4") and encode it in `browserslist` so build tools and lint (`eslint-plugin-compat`) align.
- Configure Playwright projects: `chromium`, `firefox`, `webkit`, `mobile-chrome` (Pixel), `mobile-safari` (iPhone).
- Tag cross-browser-sensitive specs (`@cross-browser`) so nightly runs them on all projects.
- Run a pre-release manual/exploratory pass on real iOS Safari and Android Chrome for critical journeys.
- Use a cloud grid for real Safari on macOS/iOS and older browser versions when required by contract.
- Check platform features with MDN/Baseline status before use and test the no-support fallback.

## Implementation Guidance

### Matrix template
| Tier | Browsers | Where | Frequency |
|---|---|---|---|
| Tier 1 (gating) | Chromium desktop | Playwright CI | Every PR |
| Tier 1b | Mobile Chrome emulation, WebKit desktop | Playwright CI | PR for `@smoke`, full on main |
| Tier 2 | Firefox, Mobile Safari emulation (WebKit + iPhone descriptor) | Playwright CI | Nightly + release |
| Tier 3 | Real iOS Safari, real Android Chrome, Samsung Internet, Safari macOS (current and previous) | BrowserStack/Sauce/LambdaTest or device lab | Release candidate, critical flows |
| Manual | Screen reader + browser pairs (VoiceOver/Safari, NVDA/Firefox or Chrome) | Human | Release / major UI change |

### Playwright projects
```ts
// playwright.config.ts (excerpt)
import { defineConfig, devices } from '@playwright/test'

const isNightly = process.env.TEST_SCOPE === 'nightly'

export default defineConfig({
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile-chrome', use: { ...devices['Pixel 7'] }, grep: /@smoke|@mobile/ },
    ...(isNightly
      ? [
          { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
          { name: 'webkit', use: { ...devices['Desktop Safari'] } },
          { name: 'mobile-safari', use: { ...devices['iPhone 15'] } },
        ]
      : []),
  ],
})
```
Device descriptor names change with Playwright releases - Check current docs (`devices` list in `playwright-core`). CI installs: `npx playwright install --with-deps chromium` on PR; all browsers nightly.

### Branded browsers
Playwright can run Google Chrome and Microsoft Edge via `channel: 'chrome'` / `'msedge'` when installed - useful for codec/DRM or policy differences.

### Real-device cloud options
| Service | Playwright integration | Notes |
|---|---|---|
| BrowserStack Automate | `browserstack-node-sdk` + `browserstack.yml` (platforms list), Local tunnel for localhost | Credentials via env vars (username/access key); large real device inventory |
| Sauce Labs | `saucectl` CLI + `.sauce/config.yml`; Sauce Connect tunnel | Runs your Playwright suite in their cloud |
| LambdaTest | Playwright via CDP endpoint/SDK (Check current docs) | Similar model |
Important: Playwright on clouds typically runs Playwright's engines on remote OSes; real iOS Safari automation for Playwright is limited - many providers use Appium/XCUITest or WebDriver for real iOS Safari. Check current provider docs for what "Safari" means.

### Nightly workflow
```yaml
name: cross-browser-nightly
on:
  schedule: [{ cron: '0 3 * * *' }]
  workflow_dispatch:
jobs:
  e2e:
    runs-on: ubuntu-latest
    env: { TEST_SCOPE: nightly }
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run build
      - run: npx playwright test --grep "@smoke|@cross-browser"
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with: { name: nightly-report, path: playwright-report/, retention-days: 14 }
```

### Known engine-sensitive areas to cover
| Area | Why |
|---|---|
| Date/time inputs, `input type=number` | Different native UIs and parsing |
| Viewport units (`dvh`, `svh`) and virtual keyboard | iOS Safari toolbar/keyboard behavior |
| Scroll/`position: sticky`/scroll-snap | Engine differences |
| Popover, `<dialog>`, anchor positioning, View Transitions | Newer features - Baseline status varies |
| Clipboard, WebAuthn/passkeys, notifications, autoplay | Permission and policy differences |
| Fonts and text rendering | Wrapping and truncation differences |
| `IntersectionObserver` timing, `requestIdleCallback` (not in Safari historically) | API availability |

## Recommended Workflow
1. Pull 90 days of browser/device analytics; define tiers and publish policy.
2. Set `browserslist` and `eslint-plugin-compat`.
3. Add Playwright projects; tag specs.
4. PR: Chromium + mobile Chrome smoke. Main/nightly: full engines.
5. Release: real-device cloud or manual pass for Tier 3 on critical journeys.
6. Log browser-specific bugs with a regression spec tagged `@cross-browser`.

## Patterns
- **Tag-driven matrix**: `grep` per project controls breadth without duplicating tests.
- **Browser-conditional expectations**: `test.skip(browserName === 'webkit', 'Feature X unsupported; fallback tested in other spec')` with a linked issue - never silent.
- **Fallback spec**: emulate lack of support by deleting the API in `page.addInitScript` (e.g., `delete window.IntersectionObserver`) to test degradation.
- **Visual cross-browser**: cloud visual tools (Chromatic/Argos/Percy) render stories in multiple browsers.

## Anti-Patterns
- **All browsers on every PR**: slow feedback, costs. Fix: tiered matrix.
- **Assuming WebKit on Linux = iPhone Safari**. Fix: real-device checks for Tier 3.
- **Blanket `test.skip` for failing browsers**. Fix: fix, or skip with issue link and fallback test.
- **UA sniffing in app code to "fix" browsers**. Fix: feature detection (`CSS.supports`, `'popover' in HTMLElement.prototype`).
- **No written support policy**: endless debates. Fix: publish policy + browserslist.

## Accessibility
Assistive technology behavior differs by browser pairing (VoiceOver works best with Safari; NVDA commonly with Firefox/Chrome; TalkBack with Chrome). Include screen-reader + browser pairs in manual release checks - see [screen-reader-testing](../screen-reader-testing/Skill.md). Test keyboard navigation in Safari/WebKit specifically: macOS Safari does not Tab to links by default unless the user setting is enabled; do not "fix" by changing tabindex.

## Responsive Design
Emulate representative devices (small phone, large phone, tablet, laptop, desktop) and test orientation changes (`page.setViewportSize`). Validate touch targets and hover-less interactions with `hasTouch: true` / `isMobile: true` projects. See [responsive-design](../responsive-design/Skill.md) and [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md).

## Performance
- Nightly matrices can run in parallel jobs per browser.
- Cloud grids are slower per test; run only critical journeys there.
- Cache Playwright browsers keyed by Playwright version, or use the official Docker image.

## Security
- Cloud tunnels (BrowserStack Local, Sauce Connect) expose local/staging environments to the provider - use test data and short-lived tunnels.
- Store cloud credentials as CI secrets; never in `browserstack.yml` committed values - reference env vars.

## Testing
Track per-browser pass rates and browser-specific bug counts; if a tier never finds bugs over several releases, reconsider its frequency.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| Playwright 1.63 (Chromium, Firefox, WebKit, device descriptors) | Primary |
| BrowserStack Automate (`browserstack-node-sdk`) | Commercial |
| Sauce Labs (`saucectl`) | Commercial |
| LambdaTest | Commercial |
| `browserslist`, `eslint-plugin-compat` | Active |
| MDN Baseline / caniuse | Feature support reference |

## Framework Notes
- **Next.js**: Next's default browserslist targets modern browsers (Check current docs); polyfills are limited - verify features you use. Test RSC streaming and Server Action forms in WebKit since streaming/hydration timing can differ. `next/image` format negotiation (AVIF/WebP) varies by browser.
- **React (Vite SPA)**: Vite's `build.target` defaults to modern baseline browsers; use `@vitejs/plugin-legacy` only if the policy requires legacy browsers, and test that bundle in those browsers.

## AI Agent Guidance
- Do: check the repo's browser support policy/browserslist before using new CSS/JS features; add fallback tests.
- Do: run affected specs in `webkit` and `firefox` projects when changing layout, forms, dialogs or scrolling behavior.
- Don't: claim Safari compatibility based only on Chromium runs.
- Don't: add UA sniffing.
- Before done: relevant specs pass in all Tier 1/2 projects locally or in a CI run; unsupported cases documented with fallback.

## Examples
```ts
// e2e/date-filter.spec.ts
import { test, expect } from '@playwright/test'

test('date range filter works across engines @cross-browser', async ({ page, browserName }) => {
  await page.goto('/reports')
  const from = page.getByLabel('From date')
  await from.fill('2026-01-01')
  await page.getByLabel('To date').fill('2026-01-31')
  await page.getByRole('button', { name: 'Apply' }).click()
  await expect(page).toHaveURL(/from=2026-01-01&to=2026-01-31/)
  await expect(page.getByRole('status')).toHaveText(/31 days/)
  test.info().annotations.push({ type: 'engine', description: browserName })
})

test('degrades without IntersectionObserver', async ({ page }) => {
  await page.addInitScript(() => { // @ts-expect-error simulate missing API
    delete window.IntersectionObserver
  })
  await page.goto('/feed')
  await expect(page.getByRole('button', { name: 'Load more' })).toBeVisible()
})
```

## Related Skills
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - projects and config
- [visual-regression-testing](../visual-regression-testing/Skill.md) - rendering differences
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) - nightly and release jobs
- [screen-reader-testing](../screen-reader-testing/Skill.md) - AT/browser pairs
- [progressive-enhancement](../progressive-enhancement/Skill.md) - fallbacks
- [responsive-design](../responsive-design/Skill.md) - viewport coverage
- [modern-css-features](../modern-css-features/Skill.md) - Baseline-aware feature use

## Sources
- [Playwright Best Practices](https://playwright.dev/docs/best-practices) - Official - test across all browsers, install only needed browsers in CI
- [Playwright release notes](https://playwright.dev/docs/release-notes) - Official - current version features
- [BrowserStack Playwright docs](https://www.browserstack.com/docs/automate/playwright) - Official - SDK, browserstack.yml, Local tunnel
- [Sauce Labs Playwright docs](https://docs.saucelabs.com/web-apps/automated-testing/playwright/) - Official - saucectl, config.yml, supported browsers

## License / Usage Notes
Playwright is Apache-2.0; cloud services are commercial. Content summarized; examples original.

## Quality Tier
B - Playwright guidance verified; cloud-provider real-iOS-Safari capabilities and LambdaTest details not fully verified this session.

## Status
Active

## Last Verified
2026-09-15
