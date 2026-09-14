# Jest Testing

## Summary
Jest remains a widely used test runner in React and Next.js codebases. For Next.js, `next/jest` provides a preconfigured transform (Next.js SWC compiler), CSS/image/`next/font` mocks, `.env` loading and ignore paths. This skill covers configuring Jest 30 for Next.js App Router with TypeScript, writing effective tests, common ESM pitfalls, and when and how to migrate to Vitest.

## Category
Testing & QA

## Subcategories
Jest configuration, next/jest, jsdom environment, module mocking, snapshot testing, Jest-to-Vitest migration

## Problem It Solves
Many production Next.js repos already have hundreds of Jest tests. Teams need a correct, low-maintenance Jest setup that understands Next.js compilation, path aliases and assets, plus clear guidance on ESM-only dependencies and a migration path when Jest becomes the bottleneck.

## When To Use
- Existing Jest suites in Next.js or React projects.
- Organizations standardized on Jest tooling (reporters, custom environments, shared presets).
- React Native shared packages in a monorepo where Jest is the common runner.

## When Not To Use
- Greenfield Vite React or Next.js projects: prefer [vitest-unit-testing](../vitest-unit-testing/Skill.md).
- Rendering `async` Server Components: unsupported in Jest per Next.js docs; use E2E.
- Real-browser behavior (layout, pointer events): use Vitest Browser Mode or Playwright.

## Core Principles
1. Use `next/jest` rather than hand-rolled Babel config in Next.js projects so transforms match the app build.
2. Keep `testEnvironment` per file when mixing server and client tests (`@jest-environment node` docblock).
3. Mock at the boundaries: network via MSW, Next.js modules via manual mocks.
4. Snapshots only for small, stable, reviewed outputs.
5. Migrate for concrete gains (speed, ESM pain, Vite alignment), not fashion.

## Best Practices
- Write `jest.config.ts` with `nextJest({ dir: './' })` and export `createJestConfig(config)` (it is async because it loads `next.config`).
- Set `coverageProvider: 'v8'`.
- Mirror `tsconfig` `paths` in `moduleNameMapper` (e.g., `'^@/(.*)$': '<rootDir>/$1'`).
- Import `@testing-library/jest-dom` in `jest.setup.ts` (v6+: no `extend-expect`).
- Use `jest.useFakeTimers()` with `userEvent.setup({ advanceTimers: jest.advanceTimersByTime })`.
- Add `transformIgnorePatterns` exceptions for ESM-only dependencies, or mock them.
- Enable `clearMocks: true` / `restoreMocks: true` to avoid cross-test leakage.
- Run `jest --ci` in CI (fails on missing snapshots rather than writing them).

## Implementation Guidance

### Install
`jest jest-environment-jsdom @testing-library/react @testing-library/dom @testing-library/jest-dom @testing-library/user-event ts-node @types/jest` (ts-node is needed for a TypeScript config file).

### jest.config.ts
```ts
import type { Config } from 'jest'
import nextJest from 'next/jest.js'

const createJestConfig = nextJest({ dir: './' })

const config: Config = {
  coverageProvider: 'v8',
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/$1' },
  clearMocks: true,
  restoreMocks: true,
  testPathIgnorePatterns: ['<rootDir>/e2e/'],
}

export default createJestConfig(config)
```
What `next/jest` configures: SWC transform via the Next.js compiler; auto-mocks for `.css`, `.module.css` (and scss variants), image imports and `next/font`; loads `.env*` into `process.env`; ignores `node_modules` and `.next`; reads `next.config` for SWC flags.

### ESM-only packages
If a dependency ships ESM only and Jest fails with `SyntaxError: Cannot use import statement outside a module`:
```ts
// After createJestConfig resolves, extend transformIgnorePatterns
export default async () => {
  const base = await createJestConfig(config)()
  return {
    ...base,
    transformIgnorePatterns: ['/node_modules/(?!(some-esm-pkg|other-esm-pkg)/)', '^.+\\.module\\.(css|sass|scss)$'],
  }
}
```
Alternative: mock the package (`jest.mock('some-esm-pkg')`) if its behavior is irrelevant to the test.

### Server-side tests in the same repo
```ts
/**
 * @jest-environment node
 */
import { createProject } from '@/app/projects/actions'
```

### Jest vs Vitest decision
| Factor | Stay on Jest | Move to Vitest |
|---|---|---|
| Suite size and health | Large, stable, fast enough | Slow watch mode, config churn |
| ESM dependencies | Few | Many (constant `transformIgnorePatterns` edits) |
| Build tool | Webpack/Turbopack-only app, no Vite | Vite SPA or Storybook Vite already in use |
| Browser tests needed | No | Want Vitest Browser Mode |
| Custom Jest environments/reporters | Heavy use | Light use |

### Migration outline (Jest -> Vitest)
1. Add Vitest config alongside Jest; run both in CI temporarily.
2. Replace `jest.fn/spyOn/mock` with `vi.*` (codemods exist; Check current docs for maintained ones). Note `vi.mock` factories must return the full module shape; use `importOriginal` for partial mocks.
3. Replace `@testing-library/jest-dom` import with `@testing-library/jest-dom/vitest`.
4. Replace `jest.requireActual` with `await vi.importActual`.
5. Migrate snapshot files (format is compatible in most cases; review diffs).
6. Remove Jest after parity.

## Recommended Workflow
1. Scaffold with `create-next-app --example with-jest` or add `jest.config.ts` manually.
2. Add scripts `"test": "jest"`, `"test:watch": "jest --watch"`, `"test:ci": "jest --ci --coverage"`.
3. Write tests beside components using RTL and user-event.
4. Add MSW `setupServer` in `jest.setup.ts` (for MSW 2 in jsdom you may need `jest-fixed-jsdom` or polyfills for `fetch`/`TextEncoder`/streams - Check current MSW docs).
5. In CI, shard with `--shard=1/3` and cache Jest's cache dir.

## Patterns
- **Manual mock for next/navigation** in `__mocks__/next/navigation.ts` exporting `useRouter`, `usePathname`, `useSearchParams` backed by `jest.fn()`.
- **Render helper** `renderWithProviders` shared across tests.
- **Inline snapshots** for small serialized values: `expect(slugify('Hello World')).toMatchInlineSnapshot('"hello-world"')`.
- **Custom environment per file** via docblock for server modules.

## Anti-Patterns
- **Hand-written Babel config for Next.js**: diverges from SWC output, disables Next optimizations. Fix: `next/jest`.
- **Large `container` snapshots**: noisy diffs. Fix: role/text assertions.
- **`jest.mock` with no factory for large modules**: automock surprises. Fix: explicit factory.
- **Forgetting async**: `getBy` for async content leads to failures; `await waitFor(() => expect(...))` with side effects inside causes repeated calls. Fix: `findBy*`, side-effect-free `waitFor` callbacks.
- **`--updateSnapshot` in CI**: hides regressions. Fix: `--ci`.

## Accessibility
Use role and label queries; add `jest-axe` for component-level axe checks only as a supplement - canonical guidance lives in [automated-accessibility-testing](../automated-accessibility-testing/Skill.md). jsdom cannot evaluate color contrast.

## Responsive Design
No layout in jsdom. Mock `window.matchMedia` in `jest.setup.ts` for components that read media queries; test real breakpoints in Playwright.

## Performance
- `next/jest` uses SWC, which is much faster than Babel.
- Use `--maxWorkers=50%` locally; in CI tune to runner cores.
- `jest --onlyChanged` / `--changedSince=origin/main` on PRs for fast feedback, full suite on main.
- Avoid heavy global setup; lazy-create providers.

## Security
`next/jest` loads `.env` files into tests - keep real secrets out of `.env` files committed or used in CI; use `.env.test` with dummy values. Never snapshot tokens or PII.

## Testing
Validate the setup with one test per environment (jsdom component, node server module) and one CSS-module-importing component to confirm mocks work.

## Tooling
| Package | Status (2026-09-15) |
|---|---|
| `jest` | 30.5.x latest |
| `jest-environment-jsdom` | Required separately since Jest 28 |
| `next/jest` | Built into `next` |
| `@testing-library/jest-dom` | v6+ (import root, not `extend-expect`) |
| `ts-jest` | Not needed with `next/jest`; useful outside Next |
| `jest-axe` | Community axe matcher |

## Framework Notes
- **Next.js**: Official support via `next/jest` since Next 12. Async Server Components unsupported; mock `next/navigation`, `next/headers`. `proxy.ts` helpers from `next/experimental/testing/server` work with Jest too.
- **React (Vite SPA)**: Jest does not use Vite config; you need `babel-jest` or `@swc/jest` plus manual asset mocks. This friction is the main reason to choose Vitest for Vite apps.

## AI Agent Guidance
- Do: check whether the repo uses Jest or Vitest before writing tests; follow the existing runner.
- Do: use `@jest-environment node` for server modules.
- Do: run `npx jest <path>` and ensure it passes; check for new snapshot files and review them.
- Don't: introduce Vitest into a Jest repo without being asked.
- Don't: add `transformIgnorePatterns` hacks before confirming the failing package is ESM-only.
- Before done: `jest --ci` passes, no obsolete snapshots (`--ci` reports them), no `.only`.

## Examples
```tsx
// components/newsletter-form.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { NewsletterForm } from './newsletter-form'

describe('NewsletterForm', () => {
  it('shows a validation error for invalid email', async () => {
    const user = userEvent.setup()
    const onSubscribe = jest.fn()
    render(<NewsletterForm onSubscribe={onSubscribe} />)

    await user.type(screen.getByLabelText(/email/i), 'not-an-email')
    await user.click(screen.getByRole('button', { name: /subscribe/i }))

    expect(await screen.findByRole('alert')).toHaveTextContent(/valid email/i)
    expect(onSubscribe).not.toHaveBeenCalled()
  })
})
```

## Related Skills
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) - recommended alternative and migration target
- [testing-library-principles](../testing-library-principles/Skill.md) - query discipline
- [api-mocking-msw](../api-mocking-msw/Skill.md) - network mocking
- [frontend-testing-strategy](../frontend-testing-strategy/Skill.md) - layer allocation
- [test-coverage-and-mutation-testing](../test-coverage-and-mutation-testing/Skill.md) - coverage settings

## Sources
- [Next.js: Setting up Jest](https://nextjs.org/docs/app/guides/testing/jest) - Official - next/jest config, what it auto-configures, async RSC limitation
- [Jest documentation](https://jestjs.io/docs/getting-started) - Official - CLI, configuration options
- [npm registry: jest](https://registry.npmjs.org/jest/latest) - Official - latest version 30.5.1
- [Testing Library user-event intro](https://testing-library.com/docs/user-event/intro) - Official - setup pattern

## License / Usage Notes
Jest is MIT-licensed. Content summarized from official docs; config snippets are original adaptations.

## Quality Tier
A - Based on current Next.js official guide and Jest docs; migration codemod and MSW/jsdom polyfill details flagged as "Check current docs".

## Status
Active

## Last Verified
2026-09-15
