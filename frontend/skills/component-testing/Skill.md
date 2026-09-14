# Component Testing

## Summary
Component testing verifies a React component (or a small feature composed of components) in isolation from the full app: rendering states, user interactions, accessibility semantics and integration with providers and mocked network. This skill compares the options for React/Next.js - Vitest + Testing Library in jsdom, Vitest Browser Mode, Storybook stories with the Vitest addon, Playwright component testing and Cypress component testing - and gives patterns for providers, Next.js module mocks, forms and data-fetching components.

## Category
Testing & QA

## Subcategories
Integration component tests, jsdom vs real browser, Storybook interaction tests, provider wrappers, Next.js module mocking, form testing, data-fetching components

## Problem It Solves
Unit tests of isolated functions miss UI integration bugs, while E2E tests are too slow to cover every state. Component tests give most of the confidence at a fraction of E2E cost - but only if the right environment is chosen and framework dependencies (router, data, fonts, images) are handled consistently.

## When To Use
- Every interactive Client Component or feature (forms, dialogs, tables, filters).
- Design-system components with many variants.
- Components with async data (TanStack Query, `use()` with promises) using MSW.

## When Not To Use
- `async` Server Components - unsupported by jsdom runners; use E2E ([testing-server-components-and-actions](../testing-server-components-and-actions/Skill.md)).
- Multi-page flows, cookies, redirects - E2E.
- Pure logic - unit tests.

## Core Principles
1. Test a component through its public contract: props in, DOM and callbacks out.
2. Prefer "feature-sized" components with real children over shallow rendering.
3. Choose the cheapest environment that is truthful for the behavior: jsdom for logic/semantics; real browser for layout, focus, pointer, CSS, canvas.
4. Mock the network (MSW), not your hooks.
5. One shared render helper provides app-level providers.

## Best Practices
- Create `test/render.tsx` exporting `renderWithProviders` (QueryClient with `retry: false`, theme, i18n, toast container).
- Use a fresh `QueryClient` per test to avoid cache leakage.
- For Next.js, centralize mocks for `next/navigation`, `next/headers` (if imported client-side via shared code), `next/font`, `next/image` in setup.
- Cover states: loading, empty, error, success, disabled, permission-restricted.
- Reuse Storybook stories as test fixtures (`composeStories`) to avoid duplicate setup.
- Use Browser Mode or Storybook Vitest addon for components where jsdom lies (popovers with floating positioning, virtualization, drag-and-drop, `ResizeObserver`).

## Implementation Guidance

### Environment decision table
| Behavior under test | jsdom (Vitest/Jest + RTL) | Vitest Browser Mode | Storybook + Vitest addon | Playwright CT | Cypress CT |
|---|---|---|---|---|---|
| Rendering by props, text, roles | Yes | Yes | Yes | Yes | Yes |
| Form validation, callbacks | Yes | Yes | Yes (play) | Yes | Yes |
| Focus trap, real Tab order | Partial (user.tab) | Yes | Yes | Yes | Plugin |
| Layout, overflow, CSS visibility | No | Yes | Yes | Yes | Yes |
| Floating UI positioning, virtualization | Usually no | Yes | Yes | Yes | Yes |
| Visual screenshots | No | `toMatchScreenshot` | Chromatic / visual addon | `toHaveScreenshot` | Plugins |
| Speed per test | Fastest | Fast | Fast | Medium | Medium |
| Next.js integration | Manual mocks | Manual mocks | `@storybook/nextjs-vite` mocks router, image, font | Your dev server (stories) | `framework: 'next'` (webpack) |

Default: jsdom for most tests; Storybook + Vitest addon for design-system components; Browser Mode for the jsdom-hostile minority.

### Render helper
```tsx
// test/render.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, type RenderOptions } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactElement, ReactNode } from 'react'
import { ThemeProvider } from '@/components/theme-provider'

export function renderWithProviders(ui: ReactElement, options?: Omit<RenderOptions, 'wrapper'>) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <ThemeProvider attribute="class" defaultTheme="light">{children}</ThemeProvider>
      </QueryClientProvider>
    )
  }
  return { user: userEvent.setup(), queryClient, ...render(ui, { wrapper: Wrapper, ...options }) }
}
```

### Controllable next/navigation mock
```ts
// test/next-navigation.ts
import { vi } from 'vitest'

export const router = { push: vi.fn(), replace: vi.fn(), refresh: vi.fn(), back: vi.fn(), prefetch: vi.fn() }
export let searchParams = new URLSearchParams()
export const setSearchParams = (init: string) => { searchParams = new URLSearchParams(init) }

vi.mock('next/navigation', () => ({
  useRouter: () => router,
  usePathname: () => '/projects',
  useSearchParams: () => searchParams,
}))
```

### Reusing stories in Vitest (portable stories)
```tsx
import { composeStories } from '@storybook/nextjs-vite'
import { render, screen } from '@testing-library/react'
import { expect, test } from 'vitest'
import * as stories from './price-tag.stories'

const { Discounted } = composeStories(stories)

test('shows original and discounted price', () => {
  render(<Discounted />)
  expect(screen.getByText('$80.00')).toBeInTheDocument()
  expect(screen.getByText('$100.00')).toHaveStyle({ textDecoration: 'line-through' })
})
```
With `@storybook/addon-vitest` you often do not need this - stories themselves run as tests. Portable stories require project annotations setup (Check current Storybook docs).

## Recommended Workflow
1. List the component's states and interactions (from design/story list).
2. Pick environment via the decision table.
3. Write stories for visual states; write tests (or play functions) for behavior.
4. Mock network with MSW handlers per state (`server.use(http.get(..., () => HttpResponse.json([])))` for empty).
5. Assert roles, text, focus, callback arguments.
6. Run the file, then break the component to confirm failure.

## Patterns
- **State matrix**: `it.each(['loading', 'empty', 'error'])` with handler overrides per state.
- **Controlled/uncontrolled contract**: test that `value` + `onChange` works and `defaultValue` works.
- **Form submit contract**: fill fields, submit, assert `onSubmit` called with typed payload; assert error messages linked via `aria-describedby` (`toHaveAccessibleDescription`).
- **Pending UI with actions**: for `useActionState`/`useFormStatus`, pass a controllable promise-returning action and assert disabled button while pending.
- **Compound components**: render the full composition (`<Tabs><TabList/>...</Tabs>`), not each part.

## Anti-Patterns
- **Shallow rendering / mocking child components**: misses integration bugs. Fix: render real children; mock only network and framework modules.
- **Asserting on hook calls** (`expect(useQuery).toHaveBeenCalled`). Fix: assert rendered outcome with MSW data.
- **Shared QueryClient across tests**: cached data leaks. Fix: new client per render.
- **Testing layout in jsdom** (`getBoundingClientRect` returns zeros). Fix: Browser Mode/Playwright.
- **Duplicating story setup in tests**. Fix: stories as tests (Vitest addon) or `composeStories`.
- **Rendering the entire `app/layout.tsx`** in component tests. Fix: render the feature component with a helper.

## Accessibility
Component tests are the best place to lock in names, roles, states (`aria-expanded`, `aria-selected`), and focus return for dialogs/menus (WCAG 2.4.3 Focus Order, 4.1.2 Name, Role, Value). Automated axe checks via the Storybook a11y addon or Browser Mode are covered in [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).

## Responsive Design
For components that change structure by container or viewport, use real-browser environments: Storybook viewport globals, Vitest Browser Mode viewport, or Playwright CT. In jsdom only the branching logic (mocked `matchMedia`) can be tested.

## Performance
- Keep jsdom tests under ~100 ms each; slow tests usually render too much or wait on real timers.
- Do not run Browser Mode for everything; split into a `browser` project by filename (`*.browser.test.tsx`).

## Security
Test that sensitive UI is not rendered without permission (e.g., "Delete" hidden for viewers) - but also enforce authorization on the server; client-hidden controls are not security.

## Testing
This skill is about testing; to validate the suite, check that each interactive component has at least: happy path, error/empty state, keyboard interaction, and a11y assertions.

## Tooling
| Tool | Status (2026-09-15) |
|---|---|
| Vitest 5 + `@testing-library/react` | Default |
| `vitest-browser-react` + `@vitest/browser-playwright` | Real-browser component tests |
| Storybook 10.6 + `@storybook/addon-vitest` | Stories as tests in Chromium |
| Playwright CT (1.62+, stories/galleries, `mount` fixture) | Stable per docs; new model - evaluate |
| Cypress CT 16 | Supports Next.js 15/16 (webpack) |

## Framework Notes
- **Next.js**: Client Components and sync Server Components are testable; async Server Components are not. `@storybook/nextjs-vite` provides `next/navigation` mocks (`appDirectory: true`, `getRouter()` from `@storybook/nextjs-vite/navigation.mock`). Server Actions imported into Client Components should be passed as props or mocked module in tests.
- **React (Vite SPA)**: Wrap with a memory router; tests share Vite config, so aliases and CSS modules work out of the box.

## AI Agent Guidance
- Do: use the repo's render helper; create one if missing rather than duplicating providers.
- Do: cover loading/empty/error states with MSW overrides.
- Do: choose Browser Mode when asserting layout, positioning, or real focus behavior.
- Don't: mock child components or internal hooks.
- Don't: attempt to render async Server Components in jsdom.
- Before done: test file runs green, fails when behavior breaks, and states list is covered.

## Examples
```tsx
// components/project-filters.test.tsx
import { http, HttpResponse } from 'msw'
import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'
import { server } from '@/test/msw/server'
import { renderWithProviders } from '@/test/render'
import { router } from '@/test/next-navigation'
import { ProjectFilters } from './project-filters'

test('applies status filter to the URL', async () => {
  const { user } = renderWithProviders(<ProjectFilters />)
  await user.click(screen.getByRole('combobox', { name: /status/i }))
  await user.click(screen.getByRole('option', { name: /archived/i }))
  expect(router.replace).toHaveBeenCalledWith('/projects?status=archived', { scroll: false })
})

test('shows an error state when owners fail to load', async () => {
  server.use(http.get('*/api/owners', () => HttpResponse.json({ message: 'boom' }, { status: 500 })))
  renderWithProviders(<ProjectFilters />)
  expect(await screen.findByRole('alert')).toHaveTextContent(/could not load owners/i)
})
```

## Related Skills
- [testing-library-principles](../testing-library-principles/Skill.md) - queries and interactions
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) - runner and Browser Mode
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) - stories as tests
- [api-mocking-msw](../api-mocking-msw/Skill.md) - network states
- [visual-regression-testing](../visual-regression-testing/Skill.md) - appearance
- [cypress-e2e-testing](../cypress-e2e-testing/Skill.md) - Cypress CT
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) - QueryClient in tests
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) - form components under test

## Sources
- [Next.js Testing guide](https://nextjs.org/docs/app/guides/testing) - Official - component vs E2E definitions, async RSC note
- [Vitest Browser Mode](https://vitest.dev/guide/browser/) - Official - real-browser component tests
- [Storybook for Next.js with Vite](https://storybook.js.org/docs/get-started/frameworks/nextjs-vite) - Official - navigation mocks, RSC experimental
- [Storybook Vitest addon](https://storybook.js.org/docs/writing-tests/integrations/vitest-addon) - Official - stories as tests
- [Playwright Component Testing](https://playwright.dev/docs/test-components) - Official - stories/galleries model (1.62)
- [Cypress React Component Testing](https://docs.cypress.io/app/component-testing/react/overview) - Official - Next.js support

## License / Usage Notes
All referenced tools are open source (MIT/Apache-2.0). Content is an original synthesis; examples are original.

## Quality Tier
A - Comparison grounded in official docs for each tool; Playwright CT's new model is recent and less field-tested.

## Status
Active

## Last Verified
2026-09-15
