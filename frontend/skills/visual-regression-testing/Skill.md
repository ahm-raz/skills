# Visual Regression Testing

## Summary
Visual regression testing captures screenshots of components or pages and compares them against approved baselines to catch unintended changes in layout, spacing, color, typography and rendering. For React/Next.js the main options are Storybook-based cloud services (Chromatic, Argos), Playwright `toHaveScreenshot`, Vitest Browser Mode `toMatchScreenshot`, and Percy. This skill covers choosing a tool, making screenshots deterministic, baseline management and CI review workflows.

## Category
Testing & QA

## Subcategories
Screenshot testing, baseline management, Chromatic, Argos, Percy, Playwright toHaveScreenshot, Vitest toMatchScreenshot, determinism, review workflow

## Problem It Solves
DOM assertions do not detect a broken grid, a wrong token value, overflowing text, dark-mode contrast breakage or a CSS refactor that shifts every button 2px. Manual QA misses these across dozens of components and themes. Visual tests make appearance changes explicit and reviewable in PRs.

## When To Use
- Design systems and shared component libraries (many variants, many consumers).
- CSS architecture migrations (Tailwind upgrades, token changes, CSS-in-JS removal).
- Marketing and checkout pages where visual breakage has business cost.
- Theme (light/dark), RTL and responsive variants.

## When Not To Use
- Highly dynamic pages without the ability to freeze data/time (fix determinism first).
- As a substitute for behavior tests - screenshots do not tell you the button works.
- Early prototypes where UI changes daily (baseline churn with no value).

## Core Principles
1. Determinism before coverage: fixed data, frozen time, disabled animations, loaded fonts, stable viewport, same rendering environment.
2. Baselines are code: reviewed, approved intentionally, never bulk-updated blindly.
3. Test at the smallest meaningful unit (story/component) first; add a few full-page shots for layout composition.
4. Rendering differs per OS/browser: generate and compare in the same environment (Docker or cloud).
5. Keep review friction low or people will rubber-stamp.

## Best Practices
- Use Storybook stories as the visual test inventory; one story per meaningful visual state.
- Wait for fonts (`document.fonts.ready`) and images before capture; Playwright's `toHaveScreenshot` waits for stable consecutive screenshots.
- Disable animations/caret (`animations: 'disabled'`, `caret: 'hide'` in Playwright) and honor `prefers-reduced-motion`.
- Mask volatile regions (`mask: [page.getByTestId('timestamp')]`) or hide via `stylePath` CSS.
- Freeze time (`page.clock.setFixedTime`) and seed data (MSW/fixtures).
- Use explicit viewports and test 2-3 breakpoints, not every width.
- For local Playwright baselines, run in the official Playwright Docker image so macOS/Windows developers match Linux CI.
- Set small thresholds (`maxDiffPixelRatio` around 0.01 or lower) rather than large tolerances that hide regressions.
- Use TurboSnap (Chromatic) or changed-story detection to control cost.

## Implementation Guidance

### Tool selection
| Option | Best for | Hosting / cost | Baseline storage | Notes |
|---|---|---|---|---|
| Chromatic | Storybook-centric design systems | Commercial SaaS, snapshot-based pricing | Cloud, per branch | Built by Storybook team; TurboSnap limits to changed stories; multi-browser; review UI; Playwright/Cypress/Vitest integrations |
| Argos | Playwright + Storybook, OSS-friendly teams | MIT-licensed OSS platform + hosted service | Cloud, Git-aware baselines | `@argos-ci/playwright`, flaky screenshot detection, ARIA/text snapshots, OIDC tokenless on GitHub Actions |
| Percy (BrowserStack) | Teams already on BrowserStack | Commercial | Cloud | `percySnapshot(page, name)`; runs via `percy exec` (Check current docs) |
| Playwright `toHaveScreenshot` | Page-level checks without SaaS | Free | Git repo (`*-snapshots/`) | Needs consistent OS (Docker); review via HTML report diffs |
| Vitest `toMatchScreenshot` | Component-level in Vitest Browser Mode | Free | Git repo (`__screenshots__/`) | Since Vitest 4; same consistency caveats |
| Lost Pixel | - | - | - | Repository archived April 2026; do not adopt |

Decision: Storybook design system -> Chromatic or Argos. Playwright-only app -> Argos or `toHaveScreenshot` in Docker. Small team, no budget -> `toHaveScreenshot` + Docker + PR artifact review.

### Playwright toHaveScreenshot config
```ts
// playwright.config.ts (excerpt)
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.005,
      animations: 'disabled',
      caret: 'hide',
      scale: 'css',
      stylePath: './e2e/screenshot.css',
    },
  },
  snapshotPathTemplate: '{testDir}/__screenshots__/{testFilePath}/{arg}-{projectName}{ext}',
  projects: [
    { name: 'visual-chromium', testMatch: /.*\.visual\.ts/, use: { ...devices['Desktop Chrome'] } },
  ],
})
```
```css
/* e2e/screenshot.css - hide volatile UI */
[data-volatile], iframe[src*="youtube"], .toast-region { visibility: hidden !important; }
```
Default naming includes browser and platform (e.g., `home-chromium-linux.png`); the custom template above drops platform, so you must generate baselines only on Linux/Docker. Recent Playwright (1.62) supports WebP golden files - Check current docs for option name.

### Running baselines consistently
```bash
# Update baselines in the same image CI uses (match the installed @playwright/test version)
docker run --rm -v "$PWD":/work -w /work mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c "npm ci && npx playwright test --project=visual-chromium --update-snapshots"
```
Check the exact image tag in Playwright docs for your version.

### Vitest Browser Mode
```tsx
import { expect, test } from 'vitest'
import { page } from 'vitest/browser'
import { render } from 'vitest-browser-react'
import { Button } from './button'

test('primary button visual', async () => {
  await page.viewport(400, 200)
  const screen = await render(<Button variant="primary">Save</Button>)
  await expect.element(screen.getByRole('button')).toMatchScreenshot('button-primary')
})
```
Configure `comparatorName: 'pixelmatch'`, `threshold`, `allowedMismatchedPixelRatio` under `test.browser.expect.toMatchScreenshot` (Check current docs for exact nesting). Update with `vitest --update`.

### Chromatic in GitHub Actions
```yaml
- uses: chromaui/action@latest   # pin a major in production; Check current docs
  with:
    projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
    onlyChanged: true            # TurboSnap
    exitZeroOnChanges: true      # rely on the PR status check for review
```
Requires full git history (`actions/checkout` with `fetch-depth: 0`) for TurboSnap baselines.

### Argos with Playwright
```ts
// playwright.config.ts reporter (excerpt)
import { createArgosReporterOptions } from '@argos-ci/playwright/reporter'
reporter: [
  process.env.CI ? ['dot'] : ['list'],
  ['@argos-ci/playwright/reporter', createArgosReporterOptions({ uploadToArgos: !!process.env.CI })],
],
```
```ts
import { argosScreenshot } from '@argos-ci/playwright'
test('pricing page', async ({ page }) => {
  await page.goto('/pricing')
  await argosScreenshot(page, 'pricing')
})
```
Token via `ARGOS_TOKEN` secret, or tokenless OIDC on GitHub Actions (Check current docs).

## Recommended Workflow
1. Stabilize: fonts self-hosted (`next/font`), mock data, freeze clock, disable animations.
2. Choose tool from the decision table.
3. Start with design-system stories (atoms, molecules) in light + dark.
4. Add 5-15 critical full-page screenshots at mobile and desktop widths.
5. Establish baselines from `main` in CI environment.
6. On PRs: diffs block merge until a designated reviewer approves.
7. Monitor flaky diffs; fix root causes (usually async content or font loading).

## Patterns
- **Theme matrix story**: decorator renders light and dark side by side in one snapshot to halve snapshot count.
- **Viewport modes**: Chromatic modes / Storybook globals for `mobile`, `desktop`.
- **Element-level page shots**: `await expect(page.getByRole('main')).toHaveScreenshot()` to exclude nav/ads.
- **Baseline-on-main**: only `main` updates baselines automatically after merge (auto-accept), PRs require approval.

## Anti-Patterns
- **Generating baselines on developer laptops (macOS/Windows) and comparing on Linux CI**: constant diffs from font rendering. Fix: Docker or cloud.
- **High thresholds (`maxDiffPixelRatio: 0.1`)**: real regressions pass. Fix: fix determinism, keep thresholds tight.
- **Full-page screenshots of everything**: slow, noisy, costly. Fix: component stories + few pages.
- **`--update-snapshots` in CI**: approves regressions automatically. Fix: explicit, reviewed updates.
- **Screenshots of live data/time/ads**. Fix: mocks, `page.clock`, `mask`.
- **Adopting archived tools (Lost Pixel)**. Fix: Argos/Chromatic/Playwright native.

## Accessibility
Visual tests can catch focus indicator removal (capture focused state stories), contrast regressions in themes, and text zoom/reflow issues (capture at 320 CSS px width, WCAG 1.4.10). They do not replace axe or manual checks - see [automated-accessibility-testing](../automated-accessibility-testing/Skill.md). Chromatic and Argos also offer accessibility/ARIA checks; keep ownership in one place.

## Responsive Design
Capture 2-3 representative widths (e.g., 375, 768, 1280) plus 320 for reflow. Test container-query components at different container sizes via story decorators. Keep device scale factor consistent (`scale: 'css'`).

## Performance
- Snapshot count drives time and cost; use TurboSnap/changed-only and theme-matrix stories.
- Run visual projects in a separate CI job so functional E2E feedback is not blocked.
- Store baselines with Git LFS if repository-based baselines grow large.

## Security
- Screenshots may include PII - always use synthetic data.
- Store `CHROMATIC_PROJECT_TOKEN`, `ARGOS_TOKEN`, `PERCY_TOKEN` as CI secrets; for PRs from forks, secrets are unavailable by default - do not switch to `pull_request_target` with untrusted code checkout.
- Published Storybook builds may expose unreleased features; restrict access if needed.

## Testing
Verify determinism by running the visual suite twice on the same commit: zero diffs expected. Intentionally change a token to confirm diffs are detected.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| Chromatic | Active commercial; TurboSnap, SteadySnap |
| Argos | Active; MIT-licensed platform, hosted plans |
| Percy | Active commercial (BrowserStack) |
| Playwright `toHaveScreenshot` | Stable (1.63) |
| Vitest `toMatchScreenshot` | Since Vitest 4; stable Browser Mode |
| Storybook Visual Tests addon (`@chromatic-com/storybook`) | Active; runs Chromatic from Storybook UI |
| Lost Pixel | Archived 2026-04 |

## Framework Notes
- **Next.js**: Use `next/font` self-hosting so fonts are deterministic; `next/image` with placeholder blur can cause mid-load captures - wait for images or use `unoptimized` in visual test builds. Visual test pages against `next start`, not dev (dev overlays/indicators appear in screenshots).
- **React (Vite SPA)**: Storybook React Vite + Chromatic/Argos or Vitest Browser Mode screenshots; `vite preview` for page shots.

## AI Agent Guidance
- Do: prefer existing visual tool in the repo; add stories for new visual states.
- Do: ensure determinism (mocks, clock, animations off) before adding a screenshot assertion.
- Don't: run `--update-snapshots` to make CI green unless the user confirmed the visual change is intended; report the diff instead.
- Don't: raise thresholds to hide diffs.
- Before done: baseline generated in CI-equivalent environment, rerun shows zero diff, reviewers know a baseline change is included.

## Examples
```ts
// e2e/marketing.visual.ts
import { test, expect } from '@playwright/test'

test.use({ colorScheme: 'light', reducedMotion: 'reduce' })

for (const width of [375, 1280]) {
  test(`home hero @${width}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    await page.clock.setFixedTime(new Date('2026-01-15T10:00:00Z'))
    await page.goto('/')
    await page.evaluate(() => document.fonts.ready)
    await expect(page.getByRole('region', { name: 'Hero' })).toHaveScreenshot(`hero-${width}.png`, {
      mask: [page.getByTestId('live-visitor-count')],
    })
  })
}
```

## Related Skills
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) - stories as visual inventory
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - page-level screenshots
- [flaky-test-management](../flaky-test-management/Skill.md) - diff flakiness
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) - CI jobs and secrets
- [design-system-architecture](../design-system-architecture/Skill.md) - what to cover
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) - theme variants
- [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md) - browser rendering differences

## Sources
- [Playwright Visual comparisons](https://playwright.dev/docs/test-snapshots) - Official - toHaveScreenshot options, same-environment advice
- [Vitest Visual Regression Testing](https://vitest.dev/guide/browser/visual-regression-testing) - Official - toMatchScreenshot config
- [Chromatic docs](https://www.chromatic.com/docs/) - Official - TurboSnap, SteadySnap, integrations, pricing model
- [Argos docs (llms-full)](https://argos-ci.com/docs/llms-full.txt) - Official - Playwright SDK, OIDC, MIT license, flaky detection
- [Storybook Visual tests](https://storybook.js.org/docs/writing-tests/visual-testing) - Official - Visual Tests addon
- [Lost Pixel repository](https://github.com/lost-pixel/lost-pixel) - Open Source - archived status
- [Playwright release notes](https://playwright.dev/docs/release-notes) - Official - WebP snapshots

## License / Usage Notes
Playwright Apache-2.0; Vitest MIT; Argos MIT; Chromatic and Percy are commercial services. Content summarized, examples original.

## Quality Tier
A - Tool comparison and configs grounded in official docs; Percy and some option nesting not directly verified this session.

## Status
Active

## Last Verified
2026-09-15
