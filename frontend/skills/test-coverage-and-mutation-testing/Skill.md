# Test Coverage and Mutation Testing

## Summary
How to measure and use test adequacy signals in React/Next.js projects: code coverage with Vitest (`@vitest/coverage-v8` or istanbul) or Jest, merging unit and E2E coverage when needed, sensible thresholds and diff coverage on PRs, and mutation testing with StrykerJS to find tests that execute code without actually asserting behavior. Coverage is a gap finder, not a quality score.

## Category
Testing & QA

## Subcategories
Code coverage, V8 vs Istanbul, coverage thresholds, diff/patch coverage, E2E coverage, mutation testing, StrykerJS, test effectiveness metrics

## Problem It Solves
Teams either ignore coverage (critical code untested) or chase a global percentage (assertion-free tests, coverage of trivial code). Line coverage says code ran, not that tests would catch a bug. Mutation testing and diff coverage provide more honest signals.

## When To Use
- Setting coverage reporting and thresholds in CI.
- Finding untested branches in critical modules (pricing, permissions, validation).
- Auditing whether an existing suite actually detects regressions.

## When Not To Use
- As a performance target for engineers (Goodhart's law).
- Mutation testing across the entire UI codebase on every PR - too slow; scope to critical logic.

## Core Principles
1. Coverage reveals what is untested; it cannot prove what is tested well.
2. Prefer thresholds on critical directories and on changed lines (diff coverage) over a single global number.
3. Branch coverage is more informative than line coverage for logic.
4. Mutation score measures assertion strength; use it where bugs are expensive.
5. Exclude generated, config, story and type-only files from coverage denominators.

## Best Practices
- Use `@vitest/coverage-v8` (fast, default) and switch to istanbul only if you need its instrumentation behavior.
- Configure `coverage.include` explicitly so untested files appear (otherwise only imported files count, depending on version - Check current docs for `all`/include behavior).
- Set per-glob thresholds for `lib/**` (e.g., branches 90) and modest global thresholds.
- Report diff coverage on PRs (Codecov/Coveralls or `vitest --coverage` + a diff tool); require e.g. 80% of changed lines covered for `lib/`.
- Run Stryker nightly or on-demand for `lib/` domain logic and critical hooks; review surviving mutants.
- Do not count E2E-only coverage toward unit thresholds unless you deliberately merge.

## Implementation Guidance

### Vitest coverage config
```ts
// vitest.config.mts (excerpt)
test: {
  coverage: {
    provider: 'v8',
    reporter: ['text-summary', 'html', 'lcov', 'json-summary'],
    include: ['app/**/*.{ts,tsx}', 'components/**/*.{ts,tsx}', 'lib/**/*.ts', 'hooks/**/*.ts'],
    exclude: [
      '**/*.stories.tsx', '**/*.test.{ts,tsx}', '**/*.d.ts',
      'app/**/layout.tsx', 'app/**/loading.tsx', 'app/**/not-found.tsx',
      '**/types.ts', 'lib/generated/**',
    ],
    thresholds: {
      lines: 70,
      branches: 65,
      'lib/pricing/**': { lines: 95, branches: 90, functions: 95 },
      'lib/auth/**': { lines: 90, branches: 90 },
    },
  },
}
```
Run: `vitest run --coverage`. Async Server Components excluded from unit coverage expectations since they are E2E-tested; keep them thin.

### Jest coverage
```ts
// jest.config.ts (excerpt)
coverageProvider: 'v8',
collectCoverageFrom: ['app/**/*.{ts,tsx}', 'components/**/*.{ts,tsx}', 'lib/**/*.ts', '!**/*.stories.tsx', '!**/*.d.ts'],
coverageThreshold: { global: { lines: 70, branches: 65 }, './lib/pricing/': { branches: 90 } },
```

### Coverage decision table
| Area | Target | Why |
|---|---|---|
| Domain logic (`lib/pricing`, `lib/permissions`, validation schemas) | High branch coverage + mutation testing | Bugs are costly; pure code is cheap to test |
| Server Actions / Route Handlers | High branch coverage of auth/validation paths | Security relevant |
| Client Components | Moderate; focus on behavior tests | Coverage misleading for JSX |
| Layouts, loading/error boundaries, config | Exclude or low | Verified by E2E |
| Generated code, stories, types | Exclude | Noise |

### E2E coverage (optional)
- Chromium V8 coverage via Playwright `page.coverage.startJSCoverage()` / `stopJSCoverage()` and convert with `v8-to-istanbul` or `monocart-coverage-reports` (Check current docs). Source maps required; for Next.js production builds enable `productionBrowserSourceMaps` only in the E2E build and never deploy them publicly.
- Server-side coverage for `next start` requires `NODE_V8_COVERAGE` and source map handling - complex; usually not worth it versus unit tests for server logic.

### Mutation testing with StrykerJS
```json
// stryker.config.json (Vitest runner)
{
  "$schema": "./node_modules/@stryker-mutator/core/schema/stryker-schema.json",
  "testRunner": "vitest",
  "mutate": ["lib/pricing/**/*.ts", "lib/permissions/**/*.ts", "!**/*.test.ts"],
  "reporters": ["html", "clear-text", "progress"],
  "thresholds": { "high": 85, "low": 70, "break": 60 },
  "incremental": true,
  "vitest": { "configFile": "vitest.config.mts" }
}
```
Packages: `@stryker-mutator/core` + `@stryker-mutator/vitest-runner` (or `jest-runner`). Compatibility of the Vitest runner with Vitest 5 - Check current docs before adopting. Run `npx stryker run` nightly; `incremental` reuses previous results.

Interpreting survivors:
| Surviving mutant | Meaning | Action |
|---|---|---|
| `>=` changed to `>` survives | Boundary not tested | Add boundary case |
| Removed function call survives | Side effect not asserted | Assert the call/outcome |
| Conditional replaced with `true` survives | Negative branch untested | Add failing-path test |
| String literal changed survives | Message not asserted | Assert only if user-facing contract |
| Equivalent mutant | Behavior genuinely unchanged | Ignore/disable with comment |

## Recommended Workflow
1. Enable coverage reporting in CI (no thresholds yet); publish HTML/LCOV artifacts.
2. Identify critical directories; add per-glob thresholds there.
3. Add diff coverage reporting on PRs.
4. Run Stryker on one critical module; fix surviving mutants; set break threshold.
5. Schedule nightly mutation runs for critical modules; review trends monthly.
6. Revisit exclusions quarterly.

## Patterns
- **Ratchet**: thresholds only move up; CI job updates baseline when exceeded (Vitest has `thresholds.autoUpdate` - Check current docs).
- **Critical-path thresholds**: strict per-glob thresholds for money/auth code.
- **Mutation on changed files**: run Stryker with `--mutate` set to changed files in a non-blocking PR job.
- **Coverage-guided review**: reviewers open the HTML report for changed files to spot untested branches.

## Anti-Patterns
- **Global 100% requirement**: encourages trivial and assertion-free tests. Fix: targeted thresholds + mutation testing.
- **Tests with no assertions to raise coverage**. Fix: lint rule `vitest/expect-expect` / `jest/expect-expect`.
- **Counting stories/generated code**: distorts metrics. Fix: exclusions.
- **Snapshot tests as coverage filler**. Fix: behavior assertions.
- **Shipping source maps publicly to get E2E coverage**. Fix: separate E2E build; never deploy.
- **Mutation testing whole repo per PR**. Fix: scope and schedule.

## Accessibility
Coverage does not measure accessibility. Ensure a11y assertions (roles, names, axe) exist for interactive components regardless of coverage numbers - see [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).

## Responsive Design
Not applicable to coverage metrics; viewport-specific branches (e.g., `useMediaQuery` results) should appear covered by tests mocking both states.

## Performance
- V8 coverage adds modest overhead; istanbul instrumentation is slower.
- Stryker runtime scales with mutants x test time; use `incremental`, narrow `mutate`, and per-test coverage analysis (`coverageAnalysis: 'perTest'` where supported).

## Security
- Coverage HTML reports include source code; keep artifacts private with short retention.
- Coverage services (Codecov etc.) receive source paths/line data; use tokens from secrets and review data policies; OIDC/tokenless where supported.

## Testing
Validate thresholds by removing a test in a branch and confirming CI fails for the critical glob.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| `@vitest/coverage-v8`, `@vitest/coverage-istanbul` | Active (match Vitest major) |
| Jest built-in coverage (`coverageProvider: 'v8'`) | Active |
| StrykerJS (`@stryker-mutator/core`, vitest/jest runners) | Active; verify Vitest 5 runner compatibility |
| Codecov / Coveralls | Commercial/free-for-OSS diff coverage |
| `monocart-coverage-reports`, `v8-to-istanbul` | E2E V8 coverage conversion (Check current docs) |
| `eslint-plugin-vitest` / `eslint-plugin-jest` `expect-expect` | Assertion enforcement |

## Framework Notes
- **Next.js**: Unit coverage covers Client Components, sync components, `lib/` and Server Action logic; async Server Components and route segment files are better validated by E2E, so exclude or accept lower numbers. `productionBrowserSourceMaps` for E2E coverage builds only.
- **React (Vite SPA)**: Vitest coverage covers nearly all app code; Vite plugins like `vite-plugin-istanbul` enable E2E coverage collection (Check current docs).

## AI Agent Guidance
- Do: check coverage for the files you changed and add tests for uncovered branches in critical code.
- Do: when asked to "increase coverage", write behavior-asserting tests for meaningful branches, not trivial renders.
- Don't: lower thresholds or add exclusions to pass CI without explicit approval.
- Don't: write tests without assertions.
- Before done: coverage thresholds pass, new tests would fail if the covered logic broke (spot-check by mutating a condition manually).

## Examples
Boundary test that kills a surviving `>=` -> `>` mutant:
```ts
import { describe, expect, test } from 'vitest'
import { shippingFeeCents } from '@/lib/pricing/shipping'

describe('shippingFeeCents', () => {
  test('free shipping at exactly the threshold', () => {
    expect(shippingFeeCents({ subtotalCents: 5000 })).toBe(0)
  })
  test('charges shipping one cent below threshold', () => {
    expect(shippingFeeCents({ subtotalCents: 4999 })).toBe(599)
  })
})
```

## Related Skills
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) - coverage provider config
- [jest-testing](../jest-testing/Skill.md) - Jest coverage
- [frontend-testing-strategy](../frontend-testing-strategy/Skill.md) - coverage in context
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) - reporting and artifacts
- [testing-server-components-and-actions](../testing-server-components-and-actions/Skill.md) - server logic coverage

## Sources
- [Vitest Coverage guide](https://vitest.dev/guide/coverage) - Official - providers, include/exclude, thresholds (not re-fetched this session; Check current docs)
- [Jest configuration: coverage options](https://jestjs.io/docs/configuration) - Official - collectCoverageFrom, coverageThreshold
- [StrykerJS documentation](https://stryker-mutator.io/docs/stryker-js/introduction/) - Official - mutation testing concepts, runners, config (not re-fetched this session)
- [Next.js: Setting up Vitest](https://nextjs.org/docs/app/guides/testing/vitest) - Official - async Server Components limitation affecting coverage scope

## License / Usage Notes
Vitest and Jest MIT; StrykerJS Apache-2.0. Content summarized; configuration examples are original and should be checked against current option names.

## Quality Tier
B - Sound, established practices, but Vitest coverage options and Stryker runner compatibility with Vitest 5 were not directly re-verified this session.

## Status
Active

## Last Verified
2026-09-15
