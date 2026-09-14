# Frontend Testing Strategy

## Summary
How to decide what to test, at which layer, with which tool, for a React + Next.js (App Router, TypeScript) codebase. Uses the Testing Trophy (static -> unit -> integration -> E2E) as the allocation model, maps each layer to a concrete tool (TypeScript/ESLint, Vitest, Testing Library, Storybook + Vitest addon, Playwright, visual and performance checks), and defines what must run on every PR versus nightly.

## Category
Testing & QA

## Subcategories
Testing Trophy, test pyramid, test layering, risk-based testing, test ownership, CI gating, React Server Components testing boundaries

## Problem It Solves
Teams either over-invest in brittle unit tests of implementation details (high maintenance, low confidence) or rely on a handful of slow, flaky E2E tests. Next.js adds a split: Client Components run fine in jsdom, while async Server Components, Server Actions, caching and `proxy.ts` only behave truthfully in a running Next server. Without an explicit strategy, critical flows go untested and CI becomes slow and noisy.

## When To Use
- Starting a new Next.js or Vite React project and choosing a test stack.
- Auditing an existing suite that is slow, flaky, or failing to catch regressions.
- Writing a TESTING.md / contributing guide or an agent rules file for a repo.
- Deciding where a new feature's tests belong (unit vs component vs E2E).

## When Not To Use
- Tool-specific setup details: see [vitest-unit-testing](../vitest-unit-testing/Skill.md), [playwright-e2e-testing](../playwright-e2e-testing/Skill.md).
- Throwaway prototypes where the code will be deleted within days (keep static checks only).

## Core Principles
1. "The more your tests resemble the way your software is used, the more confidence they can give you" (Testing Library / Kent C. Dodds). Test behavior, not implementation.
2. Allocate effort by confidence per cost: static checks are nearly free, integration-style component tests give the best ROI, E2E covers what only a real server/browser can prove.
3. Every layer has one job. Do not re-test the same assertion at three layers.
4. Async Server Components, Server Actions end-to-end, caching/revalidation, redirects, cookies and `proxy.ts` behavior need E2E against a production build (`next build && next start`). Next.js docs explicitly recommend E2E for async Server Components.
5. Mock at the network boundary (MSW, Playwright `page.route`), not at module internals.
6. A flaky test is a bug. A red build must mean "something is broken".
7. Tests are part of the feature definition of done.

## Best Practices
- Keep `tsc --noEmit` and ESLint (including `@typescript-eslint/no-floating-promises` for Playwright/Vitest browser tests) as the first CI gate.
- Extract business logic from Server Components/Actions into plain TypeScript modules and unit test those in Vitest's `node` environment.
- Write most UI tests as "integration component tests": render a feature-level component with real children and providers, mock only HTTP.
- Keep E2E suites focused on critical user journeys (auth, checkout, create/edit/delete of core entities, permissions) - typically 10-50 specs, not hundreds.
- Run E2E against `next build && next start` in CI, never `next dev` (dev compiles on demand, is slower and behaves differently).
- Treat visual regression and Lighthouse CI as separate, opt-in signals with owned baselines.
- Tag tests (`@smoke`, `@critical`) so PRs run a fast subset and nightly runs everything across browsers.
- Track flake rate and suite duration as first-class metrics.

## Implementation Guidance

### Layer map for React + Next.js
| Layer | What it proves | Tool | Environment | Runs |
|---|---|---|---|---|
| Static | Types, lint rules, unused code | `tsc --noEmit`, ESLint | Node | Every PR |
| Unit | Pure functions, reducers, zod schemas, formatters, hooks | Vitest | `node` / `jsdom` | Every PR |
| Component / integration | Client Components with user interaction, forms, a11y roles | Vitest + Testing Library (jsdom) or Vitest Browser Mode; Storybook play functions | jsdom or real Chromium | Every PR |
| Server logic | Server Action/Route Handler logic with mocked `next/headers`, DB | Vitest `node` | Node | Every PR |
| E2E | Real routing, RSC streaming, Server Actions, auth, caching, proxy | Playwright | `next start` + Chromium (+ Firefox/WebKit nightly) | PR (smoke) + main |
| Visual | Pixel regressions in design system and key pages | Storybook + Chromatic/Argos, or Playwright `toHaveScreenshot` | Pinned Linux/Docker or cloud | PR (changed stories) |
| A11y | axe rule violations | Storybook a11y addon, `@axe-core/playwright` | Browser | PR |
| Performance | Lighthouse scores/budgets | Lighthouse CI | `next start` | PR on key URLs / nightly |

### Decision table: where does this test go?
| Subject | Put the test in |
|---|---|
| `formatPrice()`, zod schema, reducer | Unit (Vitest, node) |
| Custom hook with state | Vitest + `renderHook` |
| `'use client'` form with validation | Component test (RTL + user-event) |
| Sync Server Component that only renders props | Component test is fine |
| `async` Server Component fetching data | E2E (Playwright); optionally extract data logic to unit |
| Server Action (`'use server'`) | Unit-test logic with mocked `next/headers`/`next/cache`; one E2E for the full form submit |
| `proxy.ts` matcher/redirects | `next/experimental/testing/server` helpers (unit) + one E2E |
| Design-system component variants | Storybook stories + Vitest addon + visual tests |
| Cross-browser layout quirk | Playwright projects (webkit/firefox) or cloud grid |

### Recommended default stack (2026-09)
- Vitest 5 (latest 5.0.0, Sep 2026) + `@testing-library/react` + `@testing-library/user-event` 14 + `@testing-library/jest-dom`.
- Playwright Test 1.63.
- Storybook 10 with `@storybook/nextjs-vite` + `@storybook/addon-vitest` + `@storybook/addon-a11y`.
- MSW 2.x for HTTP mocking in unit/component tests and Storybook.
- Jest 30 with `next/jest` only if the repo already uses Jest.

### Suggested scripts
```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "test": "vitest",
    "test:ci": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:e2e:smoke": "playwright test --grep @smoke",
    "test:storybook": "vitest --project=storybook"
  }
}
```

## Recommended Workflow
1. Inventory critical user journeys and risk areas (money, auth, data loss, legal/a11y).
2. Set up static gates first (typecheck, lint) and make them required checks.
3. Add Vitest + RTL; write component tests for each interactive feature as it is built.
4. Add Playwright with `webServer` running `next build && next start`; cover each critical journey with one happy path plus the most important failure path.
5. Add MSW handlers shared across Vitest and Storybook.
6. Add Storybook + Vitest addon for design-system components; add visual tests where UI churn is risky.
7. Wire CI (see [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md)): parallel jobs, caches, artifacts (traces, reports).
8. Monitor flake rate and duration monthly; quarantine and fix flaky tests.

## Patterns
- **Trophy allocation**: many component/integration tests, fewer unit tests of glue code, a thin E2E layer, static checks everywhere.
- **Humble Server Component**: async page fetches data via `getX()` from `lib/`, passes plain props to a sync presentational component. Unit test `getX()` and the presentational component; E2E the page.
- **Smoke vs full**: `@smoke` E2E on every PR in Chromium; full matrix on merge to main/nightly.
- **Contract at the edge**: one set of MSW handlers typed from the API schema used in unit, Storybook and local dev.

## Anti-Patterns
- **Snapshotting whole component trees** (`toMatchSnapshot` on `container`): brittle, reviewers rubber-stamp updates. Fix: assert specific roles/text; use visual testing for appearance.
- **Testing implementation details** (state values, private methods, CSS classes). Fix: query by role/label, assert what users see.
- **E2E for every edge case**: slow and flaky. Fix: push validation permutations down to component/unit tests.
- **Mocking `fetch`/modules everywhere in component tests**: tests pass while real integration breaks. Fix: MSW at the network layer.
- **E2E against `next dev`**: slow first-compile timeouts and dev-only behavior. Fix: `next build && next start`.
- **Coverage percentage as the goal**: encourages assertion-free tests. Fix: coverage as a gap finder; see [test-coverage-and-mutation-testing](../test-coverage-and-mutation-testing/Skill.md).
- **Unit-testing async Server Components with hacks as the only coverage**. Fix: E2E is the source of truth.

## Accessibility
- Role-based queries (`getByRole`) in component and E2E tests double as a basic accessibility contract: if a button has no accessible name the test cannot find it.
- Automated axe checks belong in Storybook and Playwright; ownership of rules and coverage lives in [automated-accessibility-testing](../automated-accessibility-testing/Skill.md). Automated tools catch only a subset of WCAG issues; manual keyboard and screen reader passes remain required.

## Responsive Design
- Cover responsive behavior in Playwright projects with device descriptors (e.g., `devices['Pixel 7']`, `devices['iPhone 15']`) for journeys whose UI differs on mobile (nav drawer, sticky CTA).
- jsdom has no layout engine: never assert media query or container query behavior in jsdom; use Browser Mode, Storybook viewports or Playwright.

## Performance
- Target: static + unit + component < 2-3 minutes on PR; E2E smoke < 10 minutes with sharding.
- Prefer happy-dom or Browser Mode only where it actually helps; measure.
- Cache `node_modules`, `.next/cache`, Playwright browsers (see CI skill).
- Performance regressions are tested with Lighthouse CI and RUM budgets, not unit tests.

## Security
- Never commit real credentials, storage state files, or production data into fixtures; use `.gitignore`d `playwright/.auth/` and CI secrets.
- Include negative authorization tests (user A cannot access user B's resource) at E2E level and in Server Action unit tests; Next.js docs note Server Functions must check auth themselves rather than relying on proxy matchers.
- Do not point E2E at production with destructive flows.

## Testing
This skill is the testing strategy itself. Validate the strategy by: tracking escaped defects by layer, measuring suite time and flake rate, and reviewing each incident for "which layer should have caught this?".

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| Vitest | Active; 5.0.0 released Sep 2026 (Node >= 22.12, Vite >= 6.4) |
| Jest | Active; 30.x; use via `next/jest` in existing Jest repos |
| Testing Library (React, user-event 14.6.x, jest-dom) | Active |
| Playwright Test | Active; 1.63 |
| Cypress | Active; 16.0.0 |
| Storybook | Active; 10.6 |
| MSW | Active; 2.15 |
| Lighthouse CI (`@lhci/cli`) | Active; 0.15.x |
| Chromatic / Argos | Active commercial / MIT-licensed OSS |
| Lost Pixel | Archived April 2026 - do not adopt |

## Framework Notes
- **Next.js (App Router)**: Vitest/Jest cannot render `async` Server Components (official guidance: use E2E). `next/navigation` hooks need mocking in jsdom. `proxy.ts` (renamed from middleware in Next 16) can be unit tested with `next/experimental/testing/server`. Run E2E against production builds.
- **React (Vite SPA)**: Everything renders client-side, so component tests cover more; Vitest shares `vite.config.ts`. E2E runs against `vite preview` or the built static output.

## AI Agent Guidance
- Do: identify the layer from the decision table before writing a test; place Server Component data tests in E2E.
- Do: run the relevant command (`vitest run path`, `playwright test file`) and confirm it passes and fails when the behavior is broken (temporarily invert an assertion).
- Do: query by role/label; mock HTTP with MSW rather than `vi.mock` of fetch wrappers when possible.
- Don't: add snapshot tests of large trees, `waitForTimeout`/sleep calls, or tests that only assert "renders without crashing" for complex components.
- Don't: increase retries or timeouts to make a failing test pass.
- Before done: typecheck passes, new tests pass locally 3x in a row (`--repeat-each=3` for Playwright), no `.only` left, CI config updated if a new test type was added.

## Examples
Test plan fragment for a "Create project" feature:
```md
- unit: lib/projects/slugify.test.ts (edge cases: unicode, collisions)
- unit: app/projects/actions.test.ts (createProject: auth required, zod errors returned, revalidatePath called)
- component: components/project-form.test.tsx (validation messages, disabled submit while pending)
- storybook: ProjectForm.stories.tsx (Empty, WithErrors, Submitting) + a11y 'error'
- e2e: e2e/projects.spec.ts @smoke (create -> appears in list -> reload persists)
```

## Related Skills
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) - unit and component runner
- [testing-library-principles](../testing-library-principles/Skill.md) - query and interaction discipline
- [component-testing](../component-testing/Skill.md) - component-level test approaches
- [testing-server-components-and-actions](../testing-server-components-and-actions/Skill.md) - RSC/Server Action boundaries
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - E2E layer
- [visual-regression-testing](../visual-regression-testing/Skill.md) - appearance layer
- [flaky-test-management](../flaky-test-management/Skill.md) - keeping signal trustworthy
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) - wiring layers into CI
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) - a11y automation ownership

## Sources
- [The Testing Trophy and Testing Classifications](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications) - Community - layer model and confidence/cost trade-off
- [Next.js Testing guide](https://nextjs.org/docs/app/guides/testing) - Official - test types, async Server Component recommendation
- [Testing Library Guiding Principles](https://testing-library.com/docs/guiding-principles) - Official - behavior-first principle
- [Playwright Best Practices](https://playwright.dev/docs/best-practices) - Official - isolation, user-visible behavior
- [Vitest 5 announcement](https://vitest.dev/blog/vitest-5) - Official - current version and requirements
- [Next.js proxy.js reference](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) - Official - proxy unit testing helpers, Server Function auth note

## License / Usage Notes
Content is an original synthesis summarizing the cited docs; no verbatim copying beyond short quotes. Vitest, Testing Library, Playwright, Storybook, MSW are MIT-licensed; Jest MIT; Lighthouse CI Apache-2.0.

## Quality Tier
A - Grounded in current official Next.js/Vitest/Playwright docs with concrete decision tables; strategy guidance is necessarily partly opinion.

## Status
Active

## Last Verified
2026-09-15
