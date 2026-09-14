# Modern JavaScript for React

## Summary
The ES2020–ES2026 JavaScript features and mental models that React and Next.js code depends on: immutable updates (spread, `toSorted`/`with`), modules and tree-shaking, `async`/`await` with cancellation (`AbortController`), closures and stale closures, `structuredClone`, `Intl` formatting, Set/Iterator helpers, and Temporal. Focused on what prevents real React bugs, not a language tour.

## Category
React

## Subcategories
Immutability, ES modules, async programming, closures, cancellation, internationalization formatting, date/time, collections, error handling

## Problem It Solves
Many React bugs are really JavaScript bugs: mutating state so nothing re-renders, stale closures in effects and intervals, unhandled promise races, locale-broken number/date formatting, heavyweight libraries (lodash `cloneDeep`, moment) for things the platform now does natively. This skill maps language features to React correctness.

## When To Use
- Writing state updates, reducers, or derived data in components.
- Writing effects, timers, subscriptions, or async event handlers.
- Formatting numbers, currency, dates, relative times, and lists.
- Reviewing code for mutation, race conditions, or outdated dependencies.

## When Not To Use
- Hook API rules and composition (see [react-hooks-patterns](../react-hooks-patterns/Skill.md)).
- Type-level TypeScript techniques (see [react-typescript-patterns](../react-typescript-patterns/Skill.md)).
- Old-browser support targets that need transpile/polyfill planning (see [frontend-build-tooling](../frontend-build-tooling/Skill.md)).

## Core Principles
1. React compares by reference (`Object.is`). A new value must be a new object/array; never mutate state in place.
2. Every render creates new closures that capture that render's props and state.
3. Any async work started by a component must be cancellable or ignorable when it no longer matters.
4. Prefer platform built-ins (`structuredClone`, `Intl`, `AbortSignal.timeout`, Set methods) over utility libraries.
5. Use ES modules with named exports so bundlers can tree-shake; avoid side effects at module top level.
6. Treat thrown values as `unknown`; narrow before use.

## Best Practices
- Use non-mutating array methods: `toSorted`, `toReversed`, `toSpliced`, `with(i, v)`, `map`, `filter`, spread (ES2023, Baseline).
- Use `Object.groupBy(items, fn)` / `Map.groupBy` for grouping (ES2024) instead of hand-written reducers.
- Use `structuredClone` for deep copies of plain data (handles Date, Map, Set, cycles; not functions/DOM/class prototypes).
- Use optional chaining `?.` and nullish coalescing `??`; do not use `||` when `0`/`''` are valid values.
- Use `AbortController` for fetches in effects and event handlers; `AbortSignal.timeout(ms)` and `AbortSignal.any([...])` for combined deadlines.
- Use `Promise.allSettled` when partial failure is acceptable; `Promise.all` when any failure should fail the whole.
- Use `Intl.NumberFormat`, `Intl.DateTimeFormat`, `Intl.RelativeTimeFormat`, `Intl.ListFormat`, `Intl.PluralRules`; memoize/hoist formatter instances.
- Use Set methods (`union`, `intersection`, `difference`, `isSubsetOf`; ES2025) for selection logic.
- Use Temporal (ES2026, Stage 4 March 2026; shipped in Chromium and Firefox, partial in Safari) for date arithmetic and time zones where supported; otherwise a polyfill or `date-fns`. Do not add moment.js.
- Use `crypto.randomUUID()` for client-generated IDs (not for list keys when data already has IDs).
- Use `Array.prototype.at(-1)` for last element.
- Use `for...of` with `entries()` when you need index + value without mutation.

## Implementation Guidance

### Immutable update cheat sheet
| Intent | Mutating (wrong for state) | Immutable |
|---|---|---|
| Add item | `arr.push(x)` | `[...arr, x]` |
| Remove by id | `arr.splice(i, 1)` | `arr.filter(t => t.id !== id)` |
| Replace at index | `arr[i] = x` | `arr.with(i, x)` |
| Update by id | `item.done = true` | `arr.map(t => t.id === id ? { ...t, done: true } : t)` |
| Sort | `arr.sort(cmp)` | `arr.toSorted(cmp)` |
| Reverse | `arr.reverse()` | `arr.toReversed()` |
| Insert at | `arr.splice(i, 0, x)` | `arr.toSpliced(i, 0, x)` |
| Nested field | `s.user.address.city = c` | `{ ...s, user: { ...s.user, address: { ...s.user.address, city: c } } }` or Immer `produce` |
| Set add | `set.add(x)` | `new Set(set).add(x)` or `set.union(new Set([x]))` |
| Map set | `map.set(k, v)` | `new Map(map).set(k, v)` |

### Stale closures: diagnosis table
| Symptom | Cause | Fix |
|---|---|---|
| Interval always logs initial count | Effect with `[]` captured first render's `count` | Functional update `setCount(c => c + 1)` or include dep |
| Event listener sees old props | Listener registered once | Re-subscribe on change, or read latest via ref / `useEffectEvent` |
| Async handler sets state for previous item | Response arrives after selection changed | AbortController or "ignore" flag in cleanup |
| Debounced callback uses old value | Debounce function created once with old closure | Keep latest callback in a ref, or recreate with deps |

### Cancellable fetch in an effect
```tsx
useEffect(() => {
  const controller = new AbortController()
  const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(10_000)])

  fetch(`/api/items?q=${encodeURIComponent(query)}`, { signal })
    .then(r => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
    .then(setItems)
    .catch((err: unknown) => {
      if (err instanceof DOMException && (err.name === 'AbortError' || err.name === 'TimeoutError')) return
      setError(err instanceof Error ? err : new Error(String(err)))
    })

  return () => controller.abort()
}, [query])
```
In production code prefer TanStack Query or Server Components; this pattern is for when you must hand-roll.

### Hoisted Intl formatters
```ts
// lib/format.ts — create once per locale, not per render
const currencyCache = new Map<string, Intl.NumberFormat>()
export function formatCurrency(amount: number, currency: string, locale = 'en-US') {
  const key = `${locale}:${currency}`
  let fmt = currencyCache.get(key)
  if (!fmt) {
    fmt = new Intl.NumberFormat(locale, { style: 'currency', currency })
    currencyCache.set(key, fmt)
  }
  return fmt.format(amount)
}

const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })
export const daysAgo = (days: number) => rtf.format(-days, 'day') // "yesterday", "3 days ago"
```
SSR note: format with an explicit locale and time zone on server and client to avoid hydration mismatches (`timeZone: 'UTC'` or user's stored zone).

### Modules
- Named exports for utilities (`export function`), default exports only where frameworks require (Next.js `page.tsx`, `layout.tsx`).
- Avoid barrel files (`index.ts` re-exporting everything) in large apps; they defeat tree-shaking and slow dev servers. Next.js `optimizePackageImports` helps for third-party packages only.
- Dynamic `import()` for code splitting heavy modules on interaction.
- Import attributes for JSON: `import data from './data.json' with { type: 'json' }` (ES2025) where the bundler supports it.

### Error handling
```ts
try {
  await save()
} catch (err: unknown) {
  const message = err instanceof Error ? err.message : 'Unknown error'
  // Use cause to preserve context
  throw new Error('Saving profile failed', { cause: err })
}
```

## Recommended Workflow
1. Identify whether the code is state (must be immutable), derived data (compute during render), or side effect (effect/handler).
2. For state updates, use the cheat sheet; prefer functional updates when new state depends on old.
3. For async, decide cancellation strategy before writing the call.
4. For formatting, use `Intl` with explicit locale/time zone; hoist formatters.
5. Check Baseline/browser targets for ES2024+ features (Temporal, Set methods, Iterator helpers); add polyfills only if targets require.
6. Remove utility-library calls that the platform covers.

## Patterns
- **Functional state update**: `setItems(prev => prev.filter(...))` avoids stale reads and batches correctly.
- **Derived, not stored**: `const visible = items.filter(matches)` in render instead of syncing into another state variable.
- **Ignore flag** when a cancel API is unavailable: `let active = true; ...; if (active) setX(v); return () => { active = false }`.
- **Promise.withResolvers** (ES2024) to bridge callback APIs: `const { promise, resolve, reject } = Promise.withResolvers<T>()`.
- **Iterator helpers** (ES2025) for lazy pipelines over large iterables: `map.values().filter(p).take(10).toArray()`.
- **Temporal for date math**: `Temporal.Now.plainDateISO().add({ days: 7 })` instead of millisecond arithmetic across DST.

## Anti-Patterns
- **Mutating then setting the same reference** (`items.push(x); setItems(items)`): React bails out, no re-render. Fix: new array.
- **`arr.sort()` on props/state**: mutates the parent's data. Fix: `toSorted`.
- **`JSON.parse(JSON.stringify(obj))` deep clone**: drops Dates, Maps, undefined. Fix: `structuredClone`.
- **lodash `cloneDeep`/`groupBy`/`uniq` for simple cases**: bundle weight. Fix: `structuredClone`, `Object.groupBy`, `[...new Set(arr)]`.
- **moment.js**: large, mutable, maintenance mode. Fix: Temporal or `date-fns`/`Intl`.
- **`value || default` for numbers**: `0` becomes default. Fix: `??`.
- **`async` function directly as `useEffect` callback**: returns a promise instead of cleanup. Fix: inner async function + AbortController.
- **Fire-and-forget promises without catch**: unhandled rejections. Fix: `await` in try/catch or `.catch`.
- **`new Date('2026-09-15')` for local dates**: parsed as UTC midnight, shows previous day in western zones. Fix: `Temporal.PlainDate.from` or parse parts explicitly.
- **`var` and function hoisting tricks**: confusing scope in closures. Fix: `const`/`let`.
- **Using array index as key after immutable reorders**: breaks identity. Fix: stable IDs.

## Accessibility
- Use `Intl` to produce locale-correct numbers/dates so screen readers read them naturally; pair abbreviated displays with full text (`<time dateTime="2026-09-15">`).
- `Intl.ListFormat` produces grammatical lists ("A, B, and C") that read better aloud than joined commas.
- Cancel stale async updates so live regions do not announce outdated results.

## Responsive Design
- Use `Intl.NumberFormat` `notation: 'compact'` ("1.2K") for narrow viewports instead of truncating digits.
- Keep formatting logic independent of layout; pass compact vs full as a prop.

## Performance
- Hoist constant objects, formatters, and regexes out of components.
- Avoid deep spreads on large structures in hot paths; normalize state (by id) to keep updates shallow.
- Use `structuredClone` sparingly for large objects; it is a full copy.
- Named ES module exports + no barrels = smaller bundles.
- For heavy computation, move work to a Web Worker ([web-workers-offloading](../web-workers-offloading/Skill.md)).

## Security
- Never build HTML strings with template literals for `dangerouslySetInnerHTML`; sanitize.
- `encodeURIComponent` all user values in URLs; prefer `URL`/`URLSearchParams`.
- `structuredClone` and `JSON.parse` of untrusted data are safe from prototype pollution compared with naive recursive merges; avoid custom deep-merge utilities on user input.
- Use `crypto.randomUUID()`/`crypto.getRandomValues()`, never `Math.random()`, for tokens or IDs with security meaning.

## Testing
- Unit test reducers and pure update helpers with Vitest (input -> output, assert original unchanged via `Object.freeze` in tests).
- Use fake timers (`vi.useFakeTimers()`) to test intervals/debounces and stale closure fixes.
- Test cancellation: trigger a second request and assert the first response is ignored.
- Test formatting under multiple locales and time zones (`TZ=America/Los_Angeles` in CI).

## Tooling
| Tool | Status (2026-09) | Use |
|---|---|---|
| Native ES2023–ES2026 features | Baseline varies; check MDN/Baseline | Immutability, grouping, Set/Iterator helpers |
| Temporal | ES2026; Chromium/Firefox shipped, Safari partial | Dates/time zones; `@js-temporal/polyfill` otherwise |
| Immer | Active | Complex nested immutable updates |
| date-fns v4 | Active | Date utils where Temporal unavailable |
| eslint `unicorn`/`@typescript-eslint` rules | Active | Ban mutating methods, floating promises (`no-floating-promises`) |
| moment.js | Maintenance mode, avoid | — |
| lodash (full) | Avoid for new code | Tree-shake poorly |

## Framework Notes
- **React (Vite SPA)**: all patterns apply client-side; configure `build.target` if you must support older browsers and add polyfills deliberately.
- **Next.js**: Server Components run on Node (Temporal/Intl support depends on Node version—verify), and values passed to Client Components must be serializable (Date, Map, Set are supported by RSC; class instances and functions are not). Avoid `Date.now()`/`Math.random()` in render of prerendered components; with Cache Components they need `connection()` or caching.

## AI Agent Guidance
- Do: use immutable methods for all state and props transformations.
- Do: add AbortController/cleanup for every fetch or subscription you write in an effect.
- Do: use explicit locale and time zone for any date formatting rendered on the server.
- Don't: introduce lodash, moment, or uuid packages for functionality the platform provides.
- Don't: suppress `react-hooks/exhaustive-deps`; fix the closure instead.
- Before done: grep your diff for `.push(`, `.sort(`, `.splice(`, `.reverse(` on state/props; verify no unhandled promise; confirm features used are within the project's browser targets.

## Examples
```tsx
// Stale-closure-safe interval
function Ticker() {
  const [count, setCount] = useState(0)
  useEffect(() => {
    const id = setInterval(() => setCount(c => c + 1), 1000)
    return () => clearInterval(id)
  }, [])
  return <output aria-live="off">{count}</output>
}
```

```ts
// Selection logic with Set methods
const selected = new Set(selectedIds)
const visible = new Set(visibleIds)
const allVisibleSelected = visible.isSubsetOf(selected)
const toggleAllVisible = () =>
  allVisibleSelected ? selected.difference(visible) : selected.union(visible)
```

```ts
// Grouping for a sectioned list
const byStatus = Object.groupBy(tasks, t => t.status) // { todo: Task[], done: Task[] }
```

## Related Skills
- [react-hooks-patterns](../react-hooks-patterns/Skill.md) — effect dependencies and cleanup rules
- [react-state-management](../react-state-management/Skill.md) — immutable state design
- [react-rendering-model](../react-rendering-model/Skill.md) — reference equality and re-renders
- [typescript-for-frontend](../typescript-for-frontend/Skill.md) — typing these patterns
- [javascript-memory-leaks](../javascript-memory-leaks/Skill.md) — cleanup of timers and listeners
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md) — Intl at app scale
- [browser-apis-in-react](../browser-apis-in-react/Skill.md) — platform APIs wrapped in hooks

## Sources
- [react.dev: Updating Arrays/Objects in State](https://react.dev/learn/updating-arrays-in-state) — Official — immutable update rules
- [MDN: AbortController / AbortSignal](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) — Official — cancellation, timeout, any
- [MDN: structuredClone](https://developer.mozilla.org/en-US/docs/Web/API/Window/structuredClone) — Official — deep copy semantics
- [MDN: Intl](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl) — Official — formatters
- [Socket: TC39 advances Temporal to Stage 4](https://socket.dev/blog/tc39-advances-temporal-to-stage-4) — Community — Temporal ES2026 status and engine support
- [react.dev: useSyncExternalStore / effects docs](https://react.dev/reference/react/useSyncExternalStore) — Official — snapshot immutability caveats

## License / Usage Notes
MDN content is CC-BY-SA; react.dev is CC-BY-4.0. This skill summarizes concepts in original wording with original examples.

## Quality Tier
A — Language facts are stable and official; Temporal/Set/Iterator browser support should be rechecked against Baseline for each project's targets.

## Status
Active

## Last Verified
2026-09-15
