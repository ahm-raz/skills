# Vitest Unit Testing

## Summary
Vitest is the Vite-native test runner and the default choice for unit and component tests in React (Vite) and Next.js projects. This skill covers configuration for Next.js App Router and Vite SPAs, jsdom vs happy-dom vs Browser Mode, mocking (`vi.mock`, `vi.fn`, fake timers), projects for splitting node/jsdom/browser suites, coverage, and the breaking changes in Vitest 4 and 5.

## Category
Testing & QA

## Subcategories
Unit testing, mocking, fake timers, test environments, Vitest Browser Mode, coverage, Vitest projects

## Problem It Solves
Jest requires a separate transform pipeline (Babel/SWC) and ESM configuration; Vitest reuses Vite's transform, supports ESM and TypeScript natively, and runs fast in watch mode. Teams need a correct, reproducible config that handles `@/` aliases, `next/navigation`, CSS imports and environment differences between server and client code.

## When To Use
- Unit tests for pure TypeScript logic, zod schemas, reducers, utilities.
- Hook tests (`renderHook`) and Client Component tests with Testing Library.
- Server-side logic in `lib/`, Server Action logic, Route Handler functions (node environment).
- Real-browser component tests via Browser Mode when jsdom is insufficient (layout, `IntersectionObserver`, canvas, focus behavior).

## When Not To Use
- Rendering `async` Server Components - unsupported; use Playwright E2E.
- Full user journeys across routes, cookies, redirects - use [playwright-e2e-testing](../playwright-e2e-testing/Skill.md).
- Existing large Jest suites with no pain - see [jest-testing](../jest-testing/Skill.md); migrate only with a reason.

## Core Principles
1. One config, multiple projects: separate `node` (server logic), `jsdom` (client components) and optionally `browser` projects.
2. Default to the `node` environment; opt into DOM only where needed.
3. Mock at boundaries (network with MSW, Next.js framework modules), not your own internals.
4. Keep tests isolated: reset mocks, handlers, timers, and DOM between tests.
5. Always `await` async assertions - Vitest 5 fails tests with unawaited async assertions.

## Best Practices
- Use `vite-tsconfig-paths` (or `resolve.tsconfigPaths` if available in your Vite version - Check current docs) so `@/` aliases resolve.
- Put global matchers and cleanup in `vitest.setup.ts`: `import '@testing-library/jest-dom/vitest'`.
- Enable `globals: false` (explicit imports) for clarity and type safety; if you enable globals, add `"types": ["vitest/globals"]` to tsconfig.
- Use `vi.useFakeTimers()` with `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })`.
- Prefer `vi.spyOn` over `vi.mock` for partial mocking; use `vi.mock(import('./mod'), ...)` form for type-safe factories.
- Note Vitest 5 defaults `clearMocks: true`; do not rely on call counts leaking across tests.
- Use `test.each` / `describe.each` for tables of inputs.
- Run `vitest run` in CI (no watch), `vitest` locally.

## Implementation Guidance

### Install (Next.js)
`vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/dom @testing-library/user-event @testing-library/jest-dom vite-tsconfig-paths @vitest/coverage-v8` as devDependencies. Vitest 5 requires Node >= 22.12 and Vite >= 6.4.

### vitest.config.mts (Next.js, multiple projects)
```ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths(), react()],
  test: {
    coverage: {
      provider: 'v8',
      include: ['app/**', 'components/**', 'lib/**'],
      exclude: ['**/*.stories.tsx', '**/*.d.ts'],
    },
    projects: [
      {
        extends: true,
        test: {
          name: 'server',
          environment: 'node',
          include: ['lib/**/*.test.ts', 'app/**/actions.test.ts', 'app/**/route.test.ts'],
        },
      },
      {
        extends: true,
        test: {
          name: 'client',
          environment: 'jsdom',
          include: ['components/**/*.test.tsx', 'app/**/*.test.tsx', 'hooks/**/*.test.ts'],
          setupFiles: ['./vitest.setup.ts'],
        },
      },
    ],
  },
})
```
Vitest 5 projects inherit root config by default; `extends: true` is harmless and explicit.

### vitest.setup.ts
```ts
import '@testing-library/jest-dom/vitest'
import { afterAll, afterEach, beforeAll, vi } from 'vitest'
import { cleanup } from '@testing-library/react'
import { server } from './test/msw/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => {
  cleanup()
  server.resetHandlers()
})
afterAll(() => server.close())

// Next.js App Router navigation hooks do not work outside the Next runtime
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn(), back: vi.fn(), prefetch: vi.fn() }),
  usePathname: () => '/',
  useSearchParams: () => new URLSearchParams(),
  useParams: () => ({}),
  redirect: vi.fn(),
  notFound: vi.fn(),
}))
```

### Environment choice
| Environment | Use for | Trade-off |
|---|---|---|
| `node` | Pure logic, Server Actions, Route Handlers | No DOM |
| `jsdom` | Most component tests | Most complete emulation; slower; no layout |
| `happy-dom` | Large component suites needing speed | Faster but "lacks some API"; verify before switching |
| `edge-runtime` | Code targeting edge runtime | Narrow use |
| Browser Mode (Playwright provider) | Layout, focus, pointer, real CSS, visual screenshots | Needs browser binaries; slower startup |
Per-file override: `// @vitest-environment happy-dom` at file top.

### Browser Mode (stable since Vitest 4)
```ts
// vitest.browser.config.mts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { playwright } from '@vitest/browser-playwright'

export default defineConfig({
  plugins: [react()],
  test: {
    include: ['**/*.browser.test.tsx'],
    browser: {
      enabled: true,
      provider: playwright(),
      headless: true,
      instances: [{ browser: 'chromium' }],
    },
  },
})
```
```tsx
import { expect, test } from 'vitest'
import { render } from 'vitest-browser-react'
import { Disclosure } from './disclosure'

test('toggles panel', async () => {
  const screen = await render(<Disclosure title="Details">Body</Disclosure>)
  await screen.getByRole('button', { name: 'Details' }).click()
  await expect.element(screen.getByText('Body')).toBeVisible()
})
```
Vitest 4 moved providers to separate packages (`@vitest/browser-playwright`, `-webdriverio`, `-preview`) and context imports to `vitest/browser`. Vitest 5 makes locators strict/exact by default and adds a built-in trace view. Whether `render` from `vitest-browser-react` must be awaited depends on the package version - Check current docs.

### Mocking cheat sheet
```ts
vi.mock('@/lib/db', () => ({ db: { project: { create: vi.fn() } } }))
const spy = vi.spyOn(console, 'error').mockImplementation(() => {})
vi.stubEnv('NEXT_PUBLIC_API_URL', 'http://api.test')
vi.useFakeTimers(); vi.setSystemTime(new Date('2026-01-01T00:00:00Z'))
```
`vi.mock` calls are hoisted; reference outer variables via `vi.hoisted()`.

## Recommended Workflow
1. Install and add `vitest.config.mts` + `vitest.setup.ts`.
2. Add scripts: `"test": "vitest"`, `"test:ci": "vitest run --coverage"`.
3. Write the test next to the source (`button.test.tsx`) or in `__tests__/`.
4. Run the single file in watch mode while developing (`vitest components/button`).
5. Break the implementation briefly to verify the test fails for the right reason.
6. In CI run `vitest run --reporter=default --reporter=junit --outputFile=reports/junit.xml`; shard large suites with `--shard=1/3`.

## Patterns
- **Hook test**: `const { result } = renderHook(() => useCounter(), { wrapper: Providers })`, then `act(() => result.current.increment())`.
- **Provider wrapper**: a `renderWithProviders(ui, options)` helper that wraps QueryClientProvider (retry: false), theme, i18n.
- **Table-driven**: `test.each([[0, '$0.00'], [1234.5, '$1,234.50']])('formats %d', (n, s) => expect(formatPrice(n)).toBe(s))`.
- **Type tests**: `expectTypeOf(fn).parameters.toEqualTypeOf<[string]>()` in `*.test-d.ts` with `vitest --typecheck`.
- **In-source tests** for tiny utilities via `if (import.meta.vitest)` (exclude from build with `define`).

## Anti-Patterns
- **Global `environment: 'jsdom'` for everything**: server code gets DOM globals it will not have in production. Fix: per-project environments.
- **Mocking `fetch` by hand in every test**: duplicated, drifts from API. Fix: MSW `setupServer` with shared handlers.
- **Forgetting `await` on `expect.element` / `findBy` / user-event**: false positives. Fix: lint with `no-floating-promises`; Vitest 5 fails unawaited async assertions.
- **Testing `async` Server Components by calling them and rendering**: unsupported and fragile. Fix: E2E; unit test the data function.
- **Leaking fake timers**: later tests hang. Fix: `afterEach(() => vi.useRealTimers())`.
- **`vi.mock` of the module under test**: tests assert on mocks. Fix: mock only collaborators at boundaries.

## Accessibility
- Use role/label queries so tests enforce accessible names. jsdom cannot compute visual contrast or focus-visible styles; run axe in Browser Mode, Storybook or Playwright - see [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).
- Assert focus management with `expect(document.activeElement).toBe(...)` or `toHaveFocus()` after keyboard interactions (`user.keyboard('{Escape}')`, `user.tab()`).

## Responsive Design
jsdom does not implement layout or media queries (`window.matchMedia` must be mocked). Test breakpoint logic by mocking `matchMedia` for hooks like `useMediaQuery`; verify actual layout in Browser Mode with `page.viewport(width, height)` or in Playwright.

## Performance
- Split projects so server tests skip DOM setup.
- `pool: 'threads'` is often faster than `forks`; test both (`forks` is more isolated for native modules).
- Avoid importing barrel files that pull the whole app; import leaf modules.
- Use `--changed` locally and `--shard` in CI.
- Vitest 5 reports 8-53% speedups over 4.1 depending on configuration (per release post).

## Security
- Use `vi.stubEnv` with fake values; never load real `.env.production` into tests.
- Set `onUnhandledRequest: 'error'` so tests never hit real external APIs.
- Keep coverage/HTML reports out of public artifacts if they include source you consider sensitive.

## Testing
- Verify the config itself: a smoke test per project (`node` test asserts `typeof window === 'undefined'`; `jsdom` test renders a component).
- Track slow tests with `--reporter=verbose` and the duration output; set `testTimeout` deliberately (default 5s).

## Tooling
| Package | Notes |
|---|---|
| `vitest` 5.0.x | Latest major (Sep 2026) |
| `@vitest/browser-playwright` | Browser Mode provider (Vitest >= 4) |
| `vitest-browser-react` | React render for Browser Mode |
| `@vitest/coverage-v8` / `@vitest/coverage-istanbul` | Coverage |
| `@vitest/ui` | Interactive UI |
| `vite-tsconfig-paths` | Path aliases |
| `jsdom` / `happy-dom` | DOM emulation |
| VS Code Vitest extension | Run/debug tests in editor |

## Framework Notes
- **Next.js**: Official guide uses `vitest.config.mts`, `@vitejs/plugin-react`, `jsdom`, `vite-tsconfig-paths`. Async Server Components are not supported; sync Server and Client Components are. Mock `next/navigation`, `next/headers`, `next/cache` where needed. `next/image` and `next/font` may need mocks in jsdom (e.g., mock `next/font/google` to return `{ className: 'font' }`).
- **React (Vite SPA)**: Put `test` config directly in `vite.config.ts` (with `/// <reference types="vitest/config" />`) or `mergeConfig` it into `vitest.config.ts` so aliases and plugins are shared.

## AI Agent Guidance
- Do: detect Vitest major version from `package.json` before using APIs (Browser Mode provider syntax changed in v4; strict locators and `clearMocks` default in v5).
- Do: run `npx vitest run <file>` and report the result; confirm the test fails when the logic is broken.
- Do: put new tests in the correct project (node vs jsdom).
- Don't: switch a whole repo to happy-dom or Browser Mode without measuring and running the full suite.
- Don't: add `vi.mock` for modules you own just to make a test pass.
- Before done: no `.only`/`.skip` added, `tsc --noEmit` passes for test files, coverage thresholds (if configured) still met.

## Examples
Testing a Client Component with fake timers (debounced search):
```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'
import { SearchBox } from './search-box'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

test('calls onSearch once after typing stops', async () => {
  const onSearch = vi.fn()
  const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
  render(<SearchBox onSearch={onSearch} delayMs={300} />)

  await user.type(screen.getByRole('searchbox', { name: /search/i }), 'react')
  expect(onSearch).not.toHaveBeenCalled()

  await vi.advanceTimersByTimeAsync(300)
  expect(onSearch).toHaveBeenCalledOnce()
  expect(onSearch).toHaveBeenCalledWith('react')
})
```

## Related Skills
- [testing-library-principles](../testing-library-principles/Skill.md) - queries and user-event
- [component-testing](../component-testing/Skill.md) - jsdom vs browser component tests
- [api-mocking-msw](../api-mocking-msw/Skill.md) - network mocking in setup files
- [jest-testing](../jest-testing/Skill.md) - alternative runner and migration
- [testing-server-components-and-actions](../testing-server-components-and-actions/Skill.md) - server-side unit tests
- [test-coverage-and-mutation-testing](../test-coverage-and-mutation-testing/Skill.md) - coverage config
- [vite-react-spa](../vite-react-spa/Skill.md) - shared Vite config

## Sources
- [Next.js: Setting up Vitest](https://nextjs.org/docs/app/guides/testing/vitest) - Official - packages, config, async RSC limitation
- [Vitest Browser Mode](https://vitest.dev/guide/browser/) - Official - providers, config, vitest-browser-react
- [Vitest Test Environments](https://vitest.dev/guide/environment) - Official - node/jsdom/happy-dom/edge-runtime trade-offs
- [Announcing Vitest 4.0](https://vitest.dev/blog/vitest-4) - Official - Browser Mode stable, provider packages
- [Announcing Vitest 5.0](https://vitest.dev/blog/vitest-5) - Official - requirements, breaking changes, performance
- [npm registry: vitest](https://registry.npmjs.org/vitest/latest) - Official - latest version 5.0.0

## License / Usage Notes
Vitest is MIT-licensed. Configuration examples are original, adapted from patterns in official docs; no verbatim copying of large sections.

## Quality Tier
A - Verified against official Next.js and Vitest docs including the v5 release; some v5 API specifics (render await, tsconfig paths option) marked "Check current docs".

## Status
Active

## Last Verified
2026-09-15
