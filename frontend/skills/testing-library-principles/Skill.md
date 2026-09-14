# Testing Library Principles

## Summary
Testing Library (`@testing-library/react`, `@testing-library/dom`, `@testing-library/user-event`, `@testing-library/jest-dom`) is the standard way to test React components through the DOM the way users experience it. This skill covers the guiding principles, query priority, query variants, user-event v14 usage, async patterns, and the mistakes that make tests brittle or falsely green. The same query vocabulary is used by Playwright locators, Vitest Browser Mode and Storybook play functions.

## Category
Testing & QA

## Subcategories
Queries, query priority, user-event, async utilities, jest-dom matchers, accessibility-first selectors, test readability

## Problem It Solves
Tests that select by CSS class, test IDs everywhere, or component internals break on every refactor and still miss real bugs (e.g., unlabeled inputs, buttons that are visually present but disabled). Testing Library enforces user-facing selectors and realistic interactions so tests survive refactors and double as an accessibility contract.

## When To Use
- Any React component or hook test in Vitest or Jest.
- Storybook play functions (`storybook/test` re-exports the same APIs).
- Writing Playwright locators (same priority: role, label, text, test id).

## When Not To Use
- Pure logic with no UI (test the function directly).
- Visual appearance assertions (use [visual-regression-testing](../visual-regression-testing/Skill.md)).
- Verifying real layout/scrolling (use Browser Mode or Playwright).

## Core Principles
1. "The more your tests resemble the way your software is used, the more confidence they can give you."
2. Work with DOM nodes, not component instances, props or state.
3. Query in priority order: accessible to everyone -> semantic -> test IDs.
4. Interact with `user-event` (full interaction simulation), not `fireEvent`, unless you need a specific low-level event.
5. Wait for what the user waits for (`findBy*`, `waitFor`), never for arbitrary time.

## Best Practices
- Use `screen` rather than destructuring render results.
- Prefer `getByRole('button', { name: /save/i })` - name matching via regex tolerates casing/whitespace.
- Use `queryBy*` only for asserting absence: `expect(screen.queryByRole('alert')).not.toBeInTheDocument()`.
- Use `findBy*` for elements that appear asynchronously (returns a Promise, retries; default timeout 1000 ms).
- Call `const user = userEvent.setup()` at the top of each test (before render) and `await` every interaction.
- Use jest-dom matchers for readable intent: `toBeVisible`, `toBeDisabled`, `toHaveAccessibleName`, `toHaveValue`, `toBeChecked`, `toHaveFocus`.
- Use `within(region)` to scope queries to a dialog, row or landmark.
- Use the Testing Playground or `screen.logTestingPlaygroundURL()` to find the best query.
- Enable `eslint-plugin-testing-library` and `eslint-plugin-jest-dom`.

## Implementation Guidance

### Query priority
| Priority | Query | Use for |
|---|---|---|
| 1 | `getByRole` (with `name`) | Almost everything: buttons, links, headings, textboxes, dialogs, tabs, rows |
| 1 | `getByLabelText` | Form fields |
| 1 | `getByPlaceholderText` | Only if no label exists (and fix the missing label) |
| 1 | `getByText` | Non-interactive content |
| 1 | `getByDisplayValue` | Filled form values |
| 2 | `getByAltText` | Images, `area`, `input[type=image]` |
| 2 | `getByTitle` | Rarely - not consistently announced |
| 3 | `getByTestId` | Only when no user-facing hook exists (e.g., canvas wrappers, dynamic text) |

### Query variants
| Variant | 0 matches | 1 match | >1 matches | Async |
|---|---|---|---|---|
| `getBy` | throw | element | throw | no |
| `queryBy` | `null` | element | throw | no |
| `findBy` | reject | element | reject | yes |
| `getAllBy` | throw | array | array | no |
| `queryAllBy` | `[]` | array | array | no |
| `findAllBy` | reject | array | array | yes |

### user-event vs fireEvent
- `user.click` performs pointer down/up, focus changes, click and respects `pointer-events: none` and disabled state.
- `user.type` focuses, fires keydown/keypress/input/keyup per character.
- `fireEvent.change` just dispatches one event - it can make an impossible interaction pass.
- With fake timers: `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })`.

### Async rules
- `await screen.findByText('Saved')` instead of `await waitFor(() => screen.getByText('Saved'))`.
- Put only assertions inside `waitFor`; no side effects (clicks) - the callback may run many times.
- Do not wrap `render` or user-event in `act` - Testing Library already does; `act` warnings usually mean an unawaited async update (missing `findBy`/`await`).

## Recommended Workflow
1. Describe the behavior in user terms ("when I submit without email, I see an error").
2. Render the component with necessary providers.
3. Find elements with the highest-priority query that works; if none works, fix the markup accessibility first.
4. Interact via `user`.
5. Assert on user-visible outcome (text, role state, callback called with data).
6. Assert absence with `queryBy`, async appearance with `findBy`.

## Patterns
- **Scoped queries**: `const dialog = screen.getByRole('dialog', { name: 'Delete project' }); await user.click(within(dialog).getByRole('button', { name: 'Delete' }))`.
- **Table row lookup**: `const row = screen.getByRole('row', { name: /acme corp/i }); within(row).getByRole('button', { name: /edit/i })`.
- **Accessible description**: `expect(input).toHaveAccessibleDescription(/must be 8 characters/i)`.
- **Setup function**: `function setup(props?) { const user = userEvent.setup(); render(<Form {...defaults} {...props} />); return { user } }`.

## Anti-Patterns
- **`container.querySelector('.btn-primary')`**: couples to styling. Fix: `getByRole('button', { name })`.
- **`getByTestId` as the default**: skips accessibility signal. Fix: roles/labels; add test IDs only as last resort.
- **Destructuring `getByText` from `render`**: harder to maintain. Fix: `screen`.
- **`expect(queryByX).toBeNull()` for presence checks**: misleading errors. Fix: `getBy` for presence (throws helpful DOM output).
- **`waitFor` with side effects or empty callbacks**. Fix: `findBy*`, assertions only.
- **Wrapping everything in `act`**. Fix: remove; await the async behavior.
- **`fireEvent` for typing and clicking**. Fix: `user-event`.
- **Using `getByRole` with `hidden: true` routinely**: tests pass for invisible UI. Fix: only for intentionally hidden content.
- **Testing that a hook's internal state changed**. Fix: test what renders.

## Accessibility
Role queries rely on the accessibility tree computed by `dom-accessibility-api`; a test that cannot find `getByRole('button', { name: 'Close' })` often signals a real WCAG 4.1.2 (Name, Role, Value) failure. Label queries enforce WCAG 1.3.1 / 3.3.2 for form fields. These are necessary but not sufficient - pair with axe automation per [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) and manual screen reader checks.

## Responsive Design
Queries are layout-agnostic. If a component renders different DOM for mobile (e.g., hamburger menu) based on `matchMedia`, mock `matchMedia` per test to exercise both branches, and confirm real breakpoints in Playwright.

## Performance
- `getByRole` is the slowest query on very large DOMs; scope with `within` or pass `{ name }` to narrow. Avoid `hidden: true` which widens the search.
- Keep rendered trees small by rendering the feature, not the whole app.

## Security
Do not render components with real tokens or PII in fixtures; debug output (`screen.debug()`) prints DOM into CI logs.

## Testing
Enable lint plugins to enforce principles: `eslint-plugin-testing-library` (e.g., `prefer-screen-queries`, `no-wait-for-side-effects`, `prefer-find-by`, `no-node-access`) and `eslint-plugin-jest-dom`.

## Tooling
| Package | Status |
|---|---|
| `@testing-library/react` | Active; requires `@testing-library/dom` peer (Check current docs for version) |
| `@testing-library/user-event` | 14.6.x |
| `@testing-library/jest-dom` | v6; `/vitest` entry for Vitest |
| `eslint-plugin-testing-library`, `eslint-plugin-jest-dom` | Active |
| Testing Playground (browser extension / site) | Query discovery |

## Framework Notes
- **Next.js**: RTL renders Client Components and sync Server Components in jsdom. Components using `next/navigation` need mocks; `next/link` renders an `<a>` and can be queried with `getByRole('link', { name })`. Async Server Components cannot be rendered - test via E2E.
- **React (Vite SPA)**: Wrap with router (`createMemoryRouter`/`MemoryRouter`) and data providers in a render helper.
- Playwright (`page.getByRole`), Vitest Browser Mode (`page.getByRole`) and Storybook (`canvas.getByRole`) share the same mental model.

## AI Agent Guidance
- Do: start every element lookup with `getByRole` + `name`; fall back down the priority table only with a reason.
- Do: create `user` via `userEvent.setup()` and `await` all interactions.
- Do: when a role query fails, inspect with `screen.debug()` / `logRoles(container)` and consider fixing component accessibility rather than switching to test IDs.
- Don't: add `data-testid` attributes to production components by default.
- Don't: wrap in `act` to silence warnings.
- Before done: lint rules pass, test fails if the user-visible behavior is removed.

## Examples
```tsx
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'
import { ProjectList } from './project-list'

test('deletes a project after confirmation', async () => {
  const user = userEvent.setup()
  const onDelete = vi.fn().mockResolvedValue(undefined)
  render(<ProjectList projects={[{ id: 'p1', name: 'Apollo' }]} onDelete={onDelete} />)

  const row = screen.getByRole('row', { name: /apollo/i })
  await user.click(within(row).getByRole('button', { name: /delete/i }))

  const dialog = await screen.findByRole('alertdialog', { name: /delete apollo/i })
  await user.click(within(dialog).getByRole('button', { name: /^delete$/i }))

  expect(onDelete).toHaveBeenCalledWith('p1')
  expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: /delete/i })).toHaveFocus()
})
```

## Related Skills
- [vitest-unit-testing](../vitest-unit-testing/Skill.md) - runner
- [jest-testing](../jest-testing/Skill.md) - runner
- [component-testing](../component-testing/Skill.md) - broader component test approaches
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - same locator priority in E2E
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) - axe automation
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) - correct roles to query for

## Sources
- [Testing Library Guiding Principles](https://testing-library.com/docs/guiding-principles) - Official - core principles
- [Testing Library: About Queries](https://testing-library.com/docs/queries/about/) - Official - priority list, variant table
- [user-event Introduction](https://testing-library.com/docs/user-event/intro) - Official - setup, differences from fireEvent
- [npm: @testing-library/user-event](https://registry.npmjs.org/@testing-library/user-event/latest) - Official - version 14.6.7

## License / Usage Notes
Testing Library packages are MIT-licensed. Tables are summarized/restructured from official docs; examples are original.

## Quality Tier
S - Stable, authoritative guidance directly from official docs with complete actionable patterns and lint enforcement.

## Status
Active

## Last Verified
2026-09-15
