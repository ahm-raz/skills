# Automated Accessibility Testing

## Summary
A layered, CI-enforced automated accessibility testing setup for React/Next.js (TypeScript):
- static linting (eslint-plugin-jsx-a11y)
- component tests (vitest-axe or jest-axe plus Testing Library role queries)
- Storybook a11y checks
- end-to-end page scans (@axe-core/playwright)
- optional site crawls (pa11y-ci, Lighthouse CI)

Automation catches a large share of issues cheaply, but never proves conformance.

## Category
Accessibility

## Subcategories
axe-core, @axe-core/playwright, vitest-axe, jest-axe, eslint-plugin-jsx-a11y, Storybook addon-a11y, Lighthouse CI, pa11y-ci, ARIA snapshots, CI gating, baselines

## Problem It Solves
Accessibility regressions ship silently: a refactor drops a label, a new color token fails contrast, a component library upgrade changes roles. Manual audits are periodic and expensive. Automated checks in PRs catch the high-frequency failures (the WebAIM Million top six account for 96% of detected errors) before merge. Deque reports axe-core finds on average about 57% of WCAG issues by volume.

## When To Use
- Every React/Next.js repository with UI.
- Design systems: test every component and state.
- Before and after dependency upgrades (UI libraries, Next.js, React).

## When Not To Use
- As the sole evidence for WCAG conformance, ACRs, or legal claims. Many criteria need human judgement: alt quality, focus order logic, meaningful sequence, captions accuracy, cognitive clarity.
- Don't run page-level axe in jsdom and trust contrast results. `color-contrast` doesn't work in jsdom.

## Core Principles
1. **Layer the tests.** Lint (instant) → component (fast) → E2E page states (realistic) → crawl (coverage).
2. **Test states, not just initial render.** Open menus, dialogs, error states, dark mode, mobile viewport.
3. **Zero new violations policy.** Fail CI on violations; track known issues via explicit, expiring exclusions.
4. **Use WCAG tags explicitly**: `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa` (plus `best-practice` if agreed).
5. **Role-based queries are accessibility tests too.** `getByRole(name)` failing means semantics broke.
6. **Automation complements manual testing**, it doesn't replace it.

## Best Practices
- Pin axe-core major/minor via your integration packages. New axe minors add rules, so upgrade deliberately and fix new findings in a dedicated PR.
- Scan real rendered output: E2E against `next build && next start` (not `next dev`, whose overlays and dev-only markup add noise).
- Scope scans with `.include('main')` for component-focused pages. Avoid blanket `.exclude()` of large areas (it disables all rules for them).
- Don't snapshot entire violation arrays (brittle). Assert `violations` is empty, or fingerprint by rule id plus target selector.
- Report readable output: rule id, impact, help URL, target selectors.
- Tag tests (`@a11y`) so they can run in a dedicated CI job with artifacts (HTML reports).
- Treat `incomplete` ("needs review") results as manual-review tasks, not passes.
- Test color modes and viewports: `page.emulateMedia({ colorScheme: 'dark' })`, mobile viewport, `forcedColors: 'active'`.

## Implementation Guidance

### 1. Lint: eslint-plugin-jsx-a11y (flat config)
```ts
// eslint.config.mjs
import jsxA11y from 'eslint-plugin-jsx-a11y';
import nextVitals from 'eslint-config-next/core-web-vitals';

export default [
  ...nextVitals,
  jsxA11y.flatConfigs.strict,
  {
    settings: {
      'jsx-a11y': {
        polymorphicPropName: 'as',
        components: { Button: 'button', Link: 'a', Image: 'img', TextField: 'input' },
      },
    },
  },
];
```
eslint-config-next enables only a handful of jsx-a11y rules, so add the plugin's `recommended` or `strict` config explicitly. Recent Next.js versions run ESLint via the ESLint CLI rather than `next lint`. Check your version's docs for the exact config import.

### 2. Component tests: Vitest + vitest-axe (jsdom)
```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig({
  plugins: [react()],
  test: { environment: 'jsdom', setupFiles: ['./vitest.setup.ts'] }, // happy-dom is incompatible with vitest-axe
});
```
```ts
// vitest.setup.ts
import '@testing-library/jest-dom/vitest';
import * as matchers from 'vitest-axe/matchers';
import { expect } from 'vitest';
expect.extend(matchers);
```
```tsx
// Dialog.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe } from 'vitest-axe';

test('dialog open state has no axe violations', async () => {
  const user = userEvent.setup();
  const { baseElement } = render(<DeleteDialog name="Alpha" />);
  await user.click(screen.getByRole('button', { name: /delete alpha/i }));
  expect(screen.getByRole('dialog', { name: /delete alpha\?/i })).toBeVisible();
  expect(await axe(baseElement, { rules: { 'color-contrast': { enabled: false } } })).toHaveNoViolations();
});
```
Use `baseElement` (document.body) when components portal (Radix, React Aria). For TypeScript matcher types, add a `vitest.d.ts` augmenting `Assertion` with vitest-axe matchers (per its README). For Jest projects, jest-axe is the equivalent (`toHaveNoViolations`).

### 3. Storybook
- `@storybook/addon-a11y` runs axe per story in the a11y panel. With Storybook's Vitest integration (`@storybook/addon-vitest`) you can fail tests on violations (`parameters.a11y.test: 'error'`).
- Write stories for every state (open, error, disabled, loading, dark). Each story becomes an a11y test.

### 4. E2E: @axe-core/playwright
```ts
// e2e/fixtures.ts
import { test as base } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

export const test = base.extend<{ makeAxeBuilder: () => AxeBuilder }>({
  makeAxeBuilder: async ({ page }, use) => {
    await use(() => new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']));
  },
});
export { expect } from '@playwright/test';
```
```ts
// e2e/a11y.spec.ts
import { test, expect } from './fixtures';

const routes = ['/', '/pricing', '/docs', '/signup', '/dashboard'];

for (const route of routes) {
  test(`@a11y ${route} has no detectable WCAG A/AA violations`, async ({ page, makeAxeBuilder }, testInfo) => {
    await page.goto(route);
    await page.getByRole('main').waitFor();
    const results = await makeAxeBuilder().analyze();
    await testInfo.attach('axe-results', { body: JSON.stringify(results.violations, null, 2), contentType: 'application/json' });
    expect(results.violations.map(v => `${v.id} (${v.impact}): ${v.nodes.map(n => n.target.join(' ')).join(', ')}`)).toEqual([]);
  });
}

test('@a11y signup error state', async ({ page, makeAxeBuilder }) => {
  await page.goto('/signup');
  await page.getByRole('button', { name: 'Create account' }).click();
  await expect(page.getByRole('heading', { name: 'There is a problem' })).toBeVisible();
  expect((await makeAxeBuilder().analyze()).violations).toEqual([]);
});
```
```ts
// playwright.config.ts (excerpt)
webServer: { command: 'npm run build && npm run start', url: 'http://localhost:3000', reuseExistingServer: !process.env.CI },
projects: [
  { name: 'desktop', use: { viewport: { width: 1280, height: 800 } } },
  { name: 'mobile', use: { ...devices['Pixel 7'] } },
],
```

### 5. Known-issue exclusions (time-boxed)
```ts
new AxeBuilder({ page })
  .withTags([...])
  .disableRules(['color-contrast']) // TODO(A11Y-123, expires 2026-10-31): legacy marketing hero
```
Prefer targeted `.exclude('#legacy-widget')` over disabling rules globally. Track every exclusion with a ticket and an expiry.

### 6. Crawls and reports
- **pa11y-ci** with a sitemap (`pa11y-ci --sitemap https://staging.example.com/sitemap.xml`) using the axe runner, for broad coverage of content pages.
- **Lighthouse CI** accessibility score as a trend signal only (it's a weighted axe subset; 100 doesn't mean accessible).
- **Playwright `toMatchAriaSnapshot`** for critical component structure (roles, names, states) to catch semantic regressions axe can't.

### Coverage map (what automation can and can't do)
| Area | Automated | Manual needed |
|---|---|---|
| Missing alt, labels, button/link names, lang, title | Yes | Quality of text |
| Color contrast (text) | Yes (real browser) | Text over images/gradients |
| Non-text contrast (1.4.11) | No | Yes |
| ARIA validity, required children, roles | Yes | Correct pattern choice |
| Keyboard operability, focus order | Partial (scripted tests) | Yes |
| Focus visible/not obscured | Partial (visual tests) | Yes |
| Live region announcements | No (text presence only) | Yes |
| Reflow, text spacing, zoom | Partial (viewport screenshots) | Yes |
| Captions, audio description | Presence only | Accuracy |
| Target size (2.5.8) | Yes (axe `target-size`) | Edge cases |
| Cognitive, plain language, consistent help | No | Yes |

## Recommended Workflow
1. Add jsx-a11y `strict` to ESLint; fix or justify all errors.
2. Add vitest-axe to component tests for every design-system component and its states.
3. Enable Storybook addon-a11y, and fail tests on violations.
4. Add a Playwright `@a11y` suite for key routes and states, run against a production build in CI (desktop plus mobile, light plus dark).
5. Gate PRs on lint, component and E2E a11y jobs. Upload axe JSON and HTML reports as artifacts.
6. Nightly: pa11y-ci or Playwright crawl of the staging sitemap; Lighthouse CI trend.
7. Quarterly: manual audit and screen reader testing, and feed new findings back into automated tests where possible.

## Patterns
- **Axe fixture** shared across E2E tests.
- **State matrix.** For each component story: default, hover/focus (via play functions), open, error, disabled, loading, dark.
- **Violation formatter.** Map violations to `rule – impact – selector – helpUrl` for PR comments.
- **Semantic contract tests.** Testing Library role queries plus `toHaveAccessibleName`/`toHaveAccessibleDescription`.
- **ARIA snapshot** for complex widgets (combobox, tabs) to lock structure.

## Anti-Patterns
- **Treating Lighthouse 100 or zero axe violations as "accessible".** Coverage is partial. Keep manual testing.
- **Running axe only on initial page load.** Misses dialogs, menus and error states. Test interactive states.
- **Blanket `.exclude('body > div')` or disabling rules without tickets.** Hides regressions. Use time-boxed, targeted exclusions.
- **Color contrast in jsdom.** Always passes or errors silently. Test contrast in Playwright.
- **Testing `next dev`.** Dev overlays and unoptimised output cause false results. Use the production build.
- **Snapshotting full axe output.** Churns on every axe upgrade. Assert empty or fingerprint.
- **Suppressing jsx-a11y rules inline without a comment explaining why.**

## Accessibility
- Automates checks for many A/AA criteria: 1.1.1, 1.3.1 (partial), 1.4.3, 2.4.2, 2.4.4 (partial), 2.5.8, 3.1.1, 3.3.2 (partial), 4.1.2.
- Manual verification remains required for most of 1.3.x, 1.4.10–1.4.13, 2.1.x, 2.4.3, 2.4.7, 2.4.11, 3.2.x, 3.3.x and 4.1.3.

## Responsive Design
- Run E2E a11y scans in at least one mobile viewport project: reflowed navigation, hamburger menus, and touch target sizes change the results.
- Screenshot at 320px width (the 400% zoom equivalent) for visual reflow review.

## Performance
- axe scans take roughly 0.5–3s per page state. Parallelise Playwright workers; scope component scans; run full crawls nightly rather than per PR.
- vitest-axe in jsdom is slower than plain unit tests. Group a11y assertions per component file, not per tiny test.

## Security
- Don't run pa11y or Lighthouse crawls against production with authenticated sessions containing real data. Use staging with seeded test accounts.
- Store auth state for Playwright (`storageState`) in CI secrets or ephemeral artifacts, never committed.
- Only install known packages (`axe-core`, `@axe-core/playwright`, `vitest-axe`, `jest-axe`, `eslint-plugin-jsx-a11y`, `pa11y-ci`, `@lhci/cli`). Watch for typosquats.

## Testing
This skill is the testing strategy. See Implementation Guidance for code. Verification of the setup itself: intentionally introduce a missing label in a branch and confirm that lint, component and E2E jobs all fail.

## Tooling
| Tool | Layer | Status (Sept 2026) |
|---|---|---|
| axe-core (Deque, MPL-2.0) | Engine | Active; 4.1x releases through 2026 add rules (e.g., `aria-tab-name`) and Element Internals support |
| @axe-core/playwright | E2E | Active, official Deque integration |
| eslint-plugin-jsx-a11y (MIT) | Lint | Active; flat config via `flatConfigs.recommended/strict` |
| vitest-axe (MIT) | Component | Small project; works with jsdom, not happy-dom |
| jest-axe (MIT) | Component (Jest) | Mature |
| @storybook/addon-a11y | Workshop/CI | Active |
| Lighthouse / Lighthouse CI | Trend | Active; axe subset |
| pa11y / pa11y-ci | Crawl | Active; supports axe and HTML_CodeSniffer runners |
| Accessibility Insights for Web | Manual-assisted | Active (Microsoft) |
| Playwright ARIA snapshots | Semantic regression | Active |
| Guidepup | Screen reader automation | Experimental |

## Framework Notes
- **Next.js.**
  - E2E against `next build && next start` via Playwright `webServer`.
  - Server Components can't be rendered by Testing Library directly. Test client components in isolation and cover RSC pages via E2E.
  - Add `Image` and `Link` to jsx-a11y component mapping.
- **React (Vite SPA).** Component tests via Vitest + jsdom; E2E against `vite build && vite preview`.
- **Portals.** Radix and React Aria render overlays into `document.body`. Run axe on `baseElement`/`document` and wait for open animations to finish.

## AI Agent Guidance
- Do: add or extend automated a11y tests for every component or route you create or change (a role-query test, an axe assertion on the relevant states, and an E2E scan if it's a route).
- Do: run lint and tests, and report the exact results (violations fixed, remaining exclusions with tickets).
- Don't: disable rules or exclude selectors to get green CI without a documented reason and expiry.
- Don't: claim WCAG conformance from automated results. Always list the manual checks still needed.
- Verify before done: jsx-a11y clean; vitest-axe clean on all new states; Playwright `@a11y` specs pass in desktop and mobile projects; manual checklist items stated.

## Examples
```yaml
# .github/workflows/a11y.yml (excerpt)
jobs:
  a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npx eslint .
      - run: npx vitest run
      - run: npx playwright install --with-deps chromium
      - run: npx playwright test --grep @a11y
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: playwright-report, path: playwright-report }
```

## Related Skills
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — what the checks map to
- [screen-reader-testing](../screen-reader-testing/Skill.md) — manual layer
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) — E2E foundation
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) — component test setup
- [testing-library-principles](../testing-library-principles/Skill.md) — role queries
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) — story-based a11y checks
- [lighthouse-ci](../lighthouse-ci/Skill.md) — trend reporting
- [linting-and-formatting](../linting-and-formatting/Skill.md) — ESLint setup
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) — CI gating
- [ai-accessibility-audit-workflow](../ai-accessibility-audit-workflow/Skill.md) — agent-driven checks

## Sources
- [axe-core (GitHub)](https://github.com/dequelabs/axe-core) — Open Source — tags, ~57% coverage claim, jsdom contrast limitation, MPL-2.0
- [axe-core releases](https://github.com/dequelabs/axe-core/releases) — Open Source — 4.12/4.13 changes
- [Playwright: Accessibility testing](https://playwright.dev/docs/accessibility-testing) — Official — AxeBuilder API, fixtures, snapshot caveats
- [eslint-plugin-jsx-a11y](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y) — Open Source — flat configs, component mapping
- [vitest-axe](https://github.com/chaance/vitest-axe) — Open Source — setup, happy-dom incompatibility
- [Storybook accessibility testing](https://storybook.js.org/docs/writing-tests/accessibility-testing) — Official — addon-a11y and test integration
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — top detectable errors
- [pa11y-ci](https://github.com/pa11y/pa11y-ci) — Open Source — sitemap crawling

## License / Usage Notes
axe-core MPL-2.0; @axe-core/playwright MPL-2.0; jsx-a11y, vitest-axe, jest-axe and pa11y are MIT/LGPL (pa11y is LGPL-3.0); Storybook MIT. Content is summarised and code original.

## Quality Tier
S — official tool docs, verified 2026 tool status, and complete CI-ready React/Next.js setup.

## Status
Active

## Last Verified
2026-09-15
