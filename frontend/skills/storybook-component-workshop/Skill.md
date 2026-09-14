# Storybook Component Workshop

## Summary
Storybook is the component workshop for developing, documenting and testing UI in isolation. Storybook 10 with `@storybook/nextjs-vite` runs Next.js components on Vite, mocks `next/navigation`, `next/image` and `next/font`, and - via `@storybook/addon-vitest` - turns every story into a Vitest test in real Chromium, including play-function interaction tests and axe accessibility checks. This skill covers setup, CSF story patterns, mocking, interaction tests, a11y, visual testing hooks and CI.

## Category
Testing & QA

## Subcategories
Storybook setup, CSF stories, args and decorators, play functions, Vitest addon, a11y addon, MSW addon, module mocking, docs, visual testing integration

## Problem It Solves
Building components inside full app pages is slow and hides edge states. Separate test fixtures, documentation and visual snapshots duplicate setup. Storybook centralizes component states as stories, which then serve as docs, interaction tests, accessibility tests and visual regression inputs.

## When To Use
- Design systems, shared UI packages, and feature components with many states.
- Building UI before backend APIs exist (with MSW).
- Collaborating with designers/PMs on review of component states.
- Running component tests in a real browser without writing separate test files.

## When Not To Use
- Tiny apps with few reusable components (cost of maintaining stories outweighs value).
- Full page flows needing real server data, auth and routing - use Playwright.
- Async Server Components that access databases/filesystem directly (RSC support is experimental and does not provide server resources).

## Core Principles
1. A story is a named, reproducible component state; it should render without network or global app state.
2. Stories are tests: every story gets a smoke render test; behavior gets a `play` function.
3. Mock at boundaries: network via MSW, framework modules via Storybook's Next.js mocks, app modules via module mocking.
4. Keep stories colocated and typed (`satisfies Meta<typeof Component>`).
5. Accessibility checks run on stories and fail CI (`a11y.test: 'error'`) once the baseline is clean.

## Best Practices
- Use `@storybook/nextjs-vite` (Vite-based, supports the Vitest addon) rather than the webpack `@storybook/nextjs` for new setups.
- Define global decorators in `.storybook/preview.tsx` for theme, fonts, QueryClient, i18n.
- Use `args` with `fn()` from `storybook/test` for callback props so interactions are logged and assertable.
- Give each story a single purpose; name by state (`Empty`, `Loading`, `WithError`, `LongContent`, `RTL`).
- Use `parameters.nextjs.appDirectory: true` for App Router components using `next/navigation`.
- Use `msw-storybook-addon` with per-story `parameters.msw.handlers`.
- Set `parameters.a11y.test: 'todo'` globally while cleaning up; switch to `'error'` for enforcement; `'off'` only for anti-pattern demos.
- Use `tags: ['autodocs']` for docs pages; `!test` tag to exclude stories from testing when necessary (Check current docs for tag names).

## Implementation Guidance

### Install
`npm create storybook@latest` in a Next.js repo detects Next and offers `@storybook/nextjs-vite` (requires Next >= 14.1 and Vite >= 5). Add testing: `npx storybook add @storybook/addon-vitest` (configures Vitest project with Playwright browser provider) and `npx storybook add @storybook/addon-a11y`.

### .storybook/main.ts
```ts
import type { StorybookConfig } from '@storybook/nextjs-vite'

const config: StorybookConfig = {
  framework: '@storybook/nextjs-vite',
  stories: ['../components/**/*.stories.@(ts|tsx)', '../app/**/*.stories.@(ts|tsx)'],
  addons: ['@storybook/addon-vitest', '@storybook/addon-a11y', '@storybook/addon-docs'],
  staticDirs: ['../public'],
  // features: { experimentalRSC: true }, // only if rendering simple Server Components
}
export default config
```

### .storybook/preview.tsx
```tsx
import type { Preview } from '@storybook/nextjs-vite'
import { initialize, mswLoader } from 'msw-storybook-addon'
import '../app/globals.css'

initialize({ onUnhandledRequest: 'bypass' })

const preview: Preview = {
  parameters: {
    nextjs: { appDirectory: true },
    a11y: { test: 'error' },
    layout: 'centered',
  },
  loaders: [mswLoader],
  decorators: [(Story) => <div className="font-sans antialiased"><Story /></div>],
}
export default preview
```
MSW browser mode needs `npx msw init public/` so `mockServiceWorker.js` is served.

### vitest.config.ts storybook project
```ts
import { defineConfig } from 'vitest/config'
import { playwright } from '@vitest/browser-playwright'
import { storybookTest } from '@storybook/addon-vitest/vitest-plugin'

export default defineConfig({
  test: {
    projects: [
      {
        extends: true,
        plugins: [storybookTest({ configDir: '.storybook' })],
        test: {
          name: 'storybook',
          browser: { enabled: true, provider: playwright({}), headless: true, instances: [{ browser: 'chromium' }] },
          setupFiles: ['.storybook/vitest.setup.ts'],
        },
      },
    ],
  },
})
```
Run in CI: `vitest --project=storybook --run` (install Chromium first: `npx playwright install --with-deps chromium`). The addon requires a Vite-based Storybook framework and Vitest >= 3.

### Story with interaction test
```tsx
// components/login-form.stories.tsx
import type { Meta, StoryObj } from '@storybook/nextjs-vite'
import { expect, fn, userEvent, within } from 'storybook/test'
import { LoginForm } from './login-form'

const meta = {
  component: LoginForm,
  args: { onSubmit: fn() },
} satisfies Meta<typeof LoginForm>
export default meta
type Story = StoryObj<typeof meta>

export const Empty: Story = {}

export const ValidationErrors: Story = {
  play: async ({ canvas, userEvent }) => {
    await userEvent.click(canvas.getByRole('button', { name: /sign in/i }))
    await expect(canvas.getByText(/email is required/i)).toBeVisible()
  },
}

export const SubmitsCredentials: Story = {
  play: async ({ args, canvas, userEvent, step }) => {
    await step('fill form', async () => {
      await userEvent.type(canvas.getByLabelText(/email/i), 'ada@example.com')
      await userEvent.type(canvas.getByLabelText(/password/i), 'correct-horse')
    })
    await userEvent.click(canvas.getByRole('button', { name: /sign in/i }))
    await expect(args.onSubmit).toHaveBeenCalledWith({ email: 'ada@example.com', password: 'correct-horse' })
  },
}
```
`canvas` and `userEvent` are provided in the play context in recent versions; older stories use `within(canvasElement)` - both work.

### Next.js navigation assertions
```tsx
import { getRouter } from '@storybook/nextjs-vite/navigation.mock'

export const NavigatesOnSave: Story = {
  play: async ({ canvas, userEvent }) => {
    await userEvent.click(canvas.getByRole('button', { name: /save/i }))
    await expect(getRouter().push).toHaveBeenCalledWith('/projects')
  },
}
```

### Per-story network mocking
```tsx
import { http, HttpResponse, delay } from 'msw'

export const Loading: Story = {
  parameters: { msw: { handlers: [http.get('/api/projects', async () => { await delay('infinite') })] } },
}
export const ServerError: Story = {
  parameters: { msw: { handlers: [http.get('/api/projects', () => HttpResponse.json({}, { status: 500 }))] } },
}
```

### Module mocking
Storybook supports mocking app modules (e.g., `lib/analytics`) for stories; recent versions provide an `sb.mock` API in `preview`, older ones use subpath imports (`#lib/analytics` with `storybook` condition). Module aliases cannot be mocked. Check current docs for your version.

## Recommended Workflow
1. Write stories for each state while building the component.
2. Add `play` functions for interactions and assertions.
3. Run Storybook locally; use the testing widget to run tests + a11y in UI.
4. Fix a11y violations; keep `test: 'error'`.
5. In CI run `vitest --project=storybook`; publish Storybook build (`storybook build`) for review.
6. Connect visual testing (Chromatic/Argos) to the same stories.

## Patterns
- **State catalogue**: `Default`, `Loading`, `Empty`, `Error`, `Disabled`, `LongText`, `RTL`, `Dark`.
- **Decorator providers**: QueryClient per story (new client in decorator) to avoid cache sharing.
- **Portable stories**: reuse stories in Vitest jsdom/Playwright tests with `composeStories`.
- **beforeEach in meta**: set up mocks/spies and return cleanup.
- **Mount control**: destructure `mount` in play to run setup before render.

## Anti-Patterns
- **Stories that call real APIs**: flaky, environment-dependent. Fix: MSW handlers.
- **Stories importing the whole app layout**: slow and entangled. Fix: minimal decorators.
- **Play functions with `setTimeout` waits**. Fix: `findBy*` / `waitFor` from `storybook/test`.
- **a11y `test: 'off'` globally**. Fix: `'todo'` then `'error'`; disable specific rules with justification.
- **Using Storybook for async Server Components hitting DB**: experimental RSC does not provide server resources. Fix: pass data as props to a presentational component and story that.
- **Letting stories rot** (not tested in CI). Fix: Vitest addon in CI.

## Accessibility
`@storybook/addon-a11y` runs axe-core (WCAG 2.0/2.1 A/AA by default) on each story; the `region` rule is disabled by default for component context. Configure via `parameters.a11y` (`context`, `config`, `options`, `test`). Rule selection, triage and full-page coverage are owned by [automated-accessibility-testing](../automated-accessibility-testing/Skill.md). Add keyboard-only play functions (`userEvent.tab()`, `{Enter}`, `{Escape}`) for interactive widgets.

## Responsive Design
Use viewport globals/toolbar to render stories at mobile/tablet/desktop; for container-query components, wrap in decorators with fixed-width containers. Visual testing tools can capture multiple viewport modes per story.

## Performance
- Vite-based framework starts faster than webpack; the Vitest addon runs stories in parallel in headless Chromium.
- Use TurboSnap/changed stories for visual tests.
- Keep global CSS and decorators light.

## Security
- Published Storybooks are public by default on many hosts; restrict access if components reveal unreleased features or internal URLs.
- Never put real API keys in `.storybook` env; use `STORYBOOK_*` public vars only for non-secrets.

## Testing
- CI: `vitest --project=storybook --run --coverage` for story coverage.
- Every exported story is a smoke test; ensure new components have at least one story with a play function.

## Tooling
| Package | Status (2026-09-15) |
|---|---|
| `storybook` | 10.6.0 |
| `@storybook/nextjs-vite` | Recommended Next.js framework (Next >= 14.1, Vite >= 5) |
| `@storybook/nextjs` (webpack) | Supported; no Vitest addon |
| `@storybook/addon-vitest` | Requires Vite framework, Vitest >= 3 |
| `@storybook/addon-a11y` | axe-core based |
| `msw-storybook-addon` | MSW >= 2 |
| `@chromatic-com/storybook` | Visual Tests addon |
| `storybook/test` | `expect`, `fn`, `userEvent`, `within` |

## Framework Notes
- **Next.js**: Set `nextjs.appDirectory: true` for App Router hooks; `getRouter()` from `@storybook/nextjs-vite/navigation.mock` for assertions. `experimentalRSC: true` wraps stories in Suspense for simple async components but provides no server resources; components using Node APIs require Vite aliases. Direct `.md` imports need `?raw`.
- **React (Vite SPA)**: Use `@storybook/react-vite`; Storybook reuses `vite.config.ts`. Wrap router-dependent components with a memory router decorator.

## AI Agent Guidance
- Do: add or update stories for every new visual state of a component you change.
- Do: write play functions with role-based queries and `fn()` args; run `vitest --project=storybook <file>`.
- Do: keep `a11y.test: 'error'` passing; fix markup instead of disabling rules.
- Don't: fetch real data in stories or import server-only modules.
- Don't: migrate framework packages (webpack -> vite) without the user's request.
- Before done: Storybook builds (`storybook build`), story tests pass, no new a11y violations.

## Examples
```tsx
// components/project-card.stories.tsx
import type { Meta, StoryObj } from '@storybook/nextjs-vite'
import { expect } from 'storybook/test'
import { ProjectCard } from './project-card'

const meta = {
  component: ProjectCard,
  args: { project: { id: 'p1', name: 'Apollo', status: 'active', updatedAt: '2026-01-15T10:00:00Z' } },
  parameters: { layout: 'padded' },
} satisfies Meta<typeof ProjectCard>
export default meta
type Story = StoryObj<typeof meta>

export const Active: Story = {}
export const Archived: Story = { args: { project: { ...meta.args.project, status: 'archived' } } }
export const VeryLongName: Story = {
  args: { project: { ...meta.args.project, name: 'An extraordinarily long project name that should truncate gracefully' } },
  play: async ({ canvas }) => {
    await expect(canvas.getByRole('heading')).toHaveAttribute('title', expect.stringContaining('extraordinarily'))
  },
}
```

## Related Skills
- [component-testing](../component-testing/Skill.md) - environment choices
- [visual-regression-testing](../visual-regression-testing/Skill.md) - Chromatic/Argos on stories
- [api-mocking-msw](../api-mocking-msw/Skill.md) - shared handlers
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) - Vitest projects
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) - a11y rules
- [design-system-architecture](../design-system-architecture/Skill.md) - component inventory
- [component-api-design](../component-api-design/Skill.md) - args reflect prop APIs

## Sources
- [Storybook for Next.js with Vite](https://storybook.js.org/docs/get-started/frameworks/nextjs-vite) - Official - setup, navigation mocks, experimental RSC, limitations
- [Storybook Vitest addon](https://storybook.js.org/docs/writing-tests/integrations/vitest-addon) - Official - config, requirements, CI command
- [Storybook Interaction testing](https://storybook.js.org/docs/writing-tests/interaction-testing) - Official - play functions, fn, mount, beforeEach
- [Storybook Accessibility testing](https://storybook.js.org/docs/writing-tests/accessibility-testing) - Official - a11y.test values, axe config
- [MSW browser integration](https://mswjs.io/docs/integrations/browser) - Official - worker init
- [npm: storybook](https://registry.npmjs.org/storybook/latest) - Official - version 10.6.0

## License / Usage Notes
Storybook and addons are MIT-licensed; MSW MIT. Content summarized; examples original.

## Quality Tier
A - Verified against Storybook 10.6 docs; module mocking API and tag names flagged for version checks.

## Status
Active

## Last Verified
2026-09-15
