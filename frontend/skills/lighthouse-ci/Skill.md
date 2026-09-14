# Lighthouse CI

## Summary
Lighthouse CI (LHCI, `@lhci/cli`) runs Lighthouse against built pages in CI, asserts scores and individual audits (performance metrics, resource budgets, accessibility, SEO, best practices), and uploads reports for comparison over time. This skill covers configuring LHCI for Next.js and Vite React apps, choosing stable assertions, controlling variance, GitHub Actions integration and how LHCI fits with Core Web Vitals field data.

## Category
Testing & QA

## Subcategories
Lab performance testing, performance budgets, Lighthouse assertions, LHCI server, GitHub status checks, performance regression testing

## Problem It Solves
Performance regressions (a heavy dependency, an unoptimized hero image, a render-blocking script) ship unnoticed because nobody runs Lighthouse manually on every PR. LHCI makes lab performance and quality checks automatic and comparable per commit.

## When To Use
- Marketing, landing, e-commerce and content pages where LCP/CLS/TBT matter.
- Enforcing bundle/resource budgets per route.
- Catching SEO/best-practice regressions (missing meta, blocked indexing, console errors).

## When Not To Use
- As the only performance signal - lab data does not represent real users; pair with RUM/CrUX ([performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md)).
- Authenticated app screens with complex state (possible via Puppeteer scripts, but usually better with Playwright traces/perf marks).
- As the primary accessibility gate - Lighthouse runs a subset of axe; see [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).

## Core Principles
1. Test production builds on consistent hardware; variance is inherent.
2. Run multiple times per URL (typically 3-5) and assert on the median/aggregate.
3. Assert on stable signals: resource budgets and specific audits are more stable than the overall performance score.
4. Start with warnings, promote to errors once baselines are understood.
5. Lab tests catch regressions; field data confirms user impact.

## Best Practices
- Use `startServerCommand: 'npm run start'` after `next build`, or `staticDistDir` for static exports / Vite `dist`.
- Audit a small set of representative URLs (home, a listing, a detail, a key landing page).
- Use `preset: 'lighthouse:recommended'` as a base only when ready; otherwise pick explicit assertions.
- Assert metrics with `maxNumericValue` (e.g., `largest-contentful-paint`, `cumulative-layout-shift`, `total-blocking-time`) and byte budgets (`resource-summary:script:size`).
- Keep `numberOfRuns` >= 3; bigger/dedicated runners give more stable results.
- Use `temporary-public-storage` only for non-sensitive public pages; use an LHCI server for private or persistent history.
- Install the Lighthouse CI GitHub App and set `LHCI_GITHUB_APP_TOKEN` secret for PR status checks.
- Pin `@lhci/cli` to a minor (e.g., `0.15.x`).

## Implementation Guidance

### lighthouserc.cjs (Next.js)
```js
/** @type {import('@lhci/cli').Config} */ // types may not be published; Check current docs
module.exports = {
  ci: {
    collect: {
      startServerCommand: 'npm run start -- -p 3000',
      startServerReadyPattern: 'Ready|started server',
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/pricing',
        'http://localhost:3000/blog/example-post',
      ],
      numberOfRuns: 3,
      settings: {
        preset: 'desktop', // omit for default mobile emulation
      },
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', { minScore: 0.9 }],
        'categories:accessibility': ['error', { minScore: 0.95 }],
        'categories:seo': ['error', { minScore: 0.95 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500, aggregationMethod: 'median-run' }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['warn', { maxNumericValue: 200 }],
        'resource-summary:script:size': ['error', { maxNumericValue: 350000 }],
        'uses-responsive-images': 'warn',
        'errors-in-console': 'error',
      },
    },
    upload: {
      target: 'temporary-public-storage',
    },
  },
}
```
`startServerReadyPattern` must match your `next start` output (Check current Next.js log text). TBT is the lab proxy for INP; LHCI cannot measure INP directly without user interaction.

### Budgets file alternative
```json
[
  {
    "path": "/*",
    "resourceSizes": [
      { "resourceType": "script", "budget": 350 },
      { "resourceType": "image", "budget": 500 },
      { "resourceType": "total", "budget": 1200 }
    ],
    "resourceCounts": [{ "resourceType": "third-party", "budget": 10 }]
  }
]
```
Reference with `assert: { budgetsFile: './budget.json' }` (sizes in KB).

### GitHub Actions
```yaml
name: lighthouse
on: [pull_request]
jobs:
  lhci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - uses: actions/cache@v4
        with:
          path: ${{ github.workspace }}/.next/cache
          key: ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-${{ hashFiles('**/*.ts', '**/*.tsx') }}
          restore-keys: ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-
      - run: npm run build
      - run: npx --yes @lhci/cli@0.15.x autorun
        env:
          LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

### Testing preview deployments
Run LHCI against a Vercel/Netlify preview URL instead of a local server: omit `startServerCommand`, pass URLs via CLI `--collect.url=$PREVIEW_URL/`. Preview infra adds network variance; compare against previous preview runs, not absolute thresholds only.

### Variance control
| Source | Mitigation |
|---|---|
| Shared CI runner CPU | `numberOfRuns: 5`, larger runners, assert medians |
| Third-party scripts | Block in LHCI via `settings.blockedUrlPatterns` for regression runs; test with them separately |
| Cold server caches | Warm up with one request before collection or discard first run |
| Network (previews) | Prefer local `next start` for gating; previews for trend |

## Recommended Workflow
1. Pick 3-5 representative URLs.
2. Run `lhci autorun` locally against `next start` to see baseline values.
3. Set assertions slightly above baseline (warn), commit config.
4. Add CI job; observe for 1-2 weeks; tighten and switch key assertions to `error`.
5. On failure, open the uploaded report, identify the audit, fix or consciously adjust budget with justification.
6. Correlate with field Core Web Vitals monthly.

## Patterns
- **Budget-first gating**: byte/request budgets as `error`, scores as `warn`.
- **Per-route assertion matrix**: `assertMatrix` with different thresholds for marketing vs app pages (Check current docs for syntax).
- **Nightly full audit**: many URLs, desktop + mobile presets; PR runs only critical URLs.
- **LHCI server**: self-hosted `@lhci/server` for history and diffing across builds.

## Anti-Patterns
- **Asserting `categories:performance` minScore 1.0 as error**: flaky failures. Fix: metric/budget assertions with medians.
- **Running against `next dev`**: unminified, unoptimized. Fix: `next build && next start`.
- **Single run per URL**: noise. Fix: `numberOfRuns >= 3`.
- **Uploading private/staging reports to public storage**. Fix: LHCI server or filesystem target.
- **Treating Lighthouse accessibility 100 as compliance**. Fix: full axe + manual testing.
- **Raising budgets silently to pass**. Fix: require justification in PR.

## Accessibility
Lighthouse's accessibility category covers a subset of automated checks; use it as a smoke signal only. Canonical a11y automation is in [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).

## Responsive Design
Default Lighthouse collection emulates a mobile device with throttling; add `preset: 'desktop'` runs separately if desktop matters. Mobile LCP is usually the binding constraint - keep mobile as the gating profile.

## Performance
- LHCI adds ~30-60 s per URL per run; limit PR URLs and use nightly for breadth.
- Cache `.next/cache` so the build step is fast.
- See [core-web-vitals](../core-web-vitals/Skill.md) and [lcp-optimization](../lcp-optimization/Skill.md) for fixing findings.

## Security
- `temporary-public-storage` makes reports publicly accessible via URL - do not use for internal apps.
- Store `LHCI_GITHUB_APP_TOKEN` and LHCI server tokens as secrets.
- When auditing authenticated pages, use dedicated test accounts and never commit cookies/scripts with credentials.

## Testing
Validate the setup by intentionally adding a large image or blocking script in a branch and confirming the assertion fails.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| `@lhci/cli` | 0.15.x |
| `@lhci/server` | Self-hosted history/diff server |
| Lighthouse CI GitHub App | Status checks |
| `treosh/lighthouse-ci-action` | Community GitHub Action wrapper (Check current docs) |
| Unlighthouse | Community whole-site scanning (Check current docs) |

## Framework Notes
- **Next.js**: Build once, `next start`, audit. For `output: 'export'` use `staticDistDir: './out'`. Watch `next/script` strategy for third-party impact and `next/image` priority on LCP images. Partial prerendering/streaming can shift LCP timing - audit real routes, not only `/`.
- **React (Vite SPA)**: `staticDistDir: './dist'` works for SPA routes if the LHCI static server handles fallbacks; otherwise use `startServerCommand: 'npx vite preview --port 4173'`. SPAs typically show higher TBT and later LCP - consider prerendering critical routes.

## AI Agent Guidance
- Do: run LHCI (or Lighthouse) against a production build before claiming performance improvements; report median values.
- Do: tie each budget change to a reason in the PR.
- Don't: loosen assertions to make CI pass without the user's approval.
- Don't: upload non-public pages to temporary public storage.
- Before done: `lhci autorun` passes locally or in CI, assertions reference realistic baselines.

## Examples
Minimal static-export config:
```js
module.exports = {
  ci: {
    collect: { staticDistDir: './out', url: ['/', '/docs/'], numberOfRuns: 3 },
    assert: { preset: 'lighthouse:no-pwa', assertions: { 'categories:performance': ['warn', { minScore: 0.9 }] } },
    upload: { target: 'filesystem', outputDir: './lhci-reports' },
  },
}
```
Preset names (`lighthouse:recommended`, `lighthouse:no-pwa`) - Check current docs for availability in your LHCI version.

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md) - metrics being asserted
- [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md) - field data and budgets
- [bundle-optimization](../bundle-optimization/Skill.md) - fixing script budget failures
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) - CI job wiring
- [nextjs-performance](../nextjs-performance/Skill.md) - Next.js-specific fixes
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) - full a11y automation

## Sources
- [Lighthouse CI Getting Started](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/getting-started.md) - Official - collect/assert/upload config, GitHub App token, variance guidance
- [npm: @lhci/cli](https://registry.npmjs.org/@lhci/cli/latest) - Official - version 0.15.1
- [Next.js CI build caching](https://nextjs.org/docs/app/guides/ci-build-caching) - Official - .next/cache action snippet
- [Playwright CI intro](https://playwright.dev/docs/ci-intro) - Official - current actions/checkout and setup-node majors

## License / Usage Notes
Lighthouse and Lighthouse CI are Apache-2.0. Config examples are original; assertion names follow Lighthouse audit IDs.

## Quality Tier
A - Config and workflow grounded in official LHCI docs; `assertMatrix` and preset details flagged; LHCI release cadence is slow so check compatibility with current Chrome.

## Status
Active

## Last Verified
2026-09-15
