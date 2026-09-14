# React 19 Migration Guide

## Summary
A practical upgrade path from React 18 (or older 19.x) to React 19.3 (latest, released Sept 9, 2026). It covers removed legacy APIs (string refs, legacy context, `propTypes`, function `defaultProps`, `ReactDOM.render`, `findDOMNode`), the new defaults (ref as prop, `<Context>` provider, error reporting changes), `@types/react` 19 breaking changes, codemods, Next.js version alignment, and the security patch floor for Server Components. It also flags outdated guidance that AI agents commonly generate.

## Category
React

## Subcategories
React 18 to 19 upgrade, removed APIs, codemods, TypeScript type changes, forwardRef deprecation path, error handling changes, Next.js alignment, RSC CVE patch levels, 19.1/19.2/19.3 feature adoption

## Problem It Solves
Upgrades stall on runtime errors from removed APIs, type errors across hundreds of files, library incompatibilities, and confusion about which features ship in which 19.x minor. Meanwhile, agents and old tutorials keep producing React 16–18 patterns.

## When To Use
- Upgrading an app or library to React 19.x.
- Upgrading Next.js to 15/16 (App Router requires React 19).
- Auditing a codebase or AI-generated code for outdated React patterns.

## When Not To Use
- Greenfield React 19 projects: follow the feature skills directly.
- React Native specifics (out of scope for this stack).

## Core Principles
1. **Upgrade in steps**: latest 18.3 first (it warns about deprecated APIs), then 19.x.
2. **Run official codemods first**, then fix the remainder by hand.
3. **Upgrade types together with runtime** (`@types/react`, `@types/react-dom` 19).
4. **Check libraries**: anything relying on `element.ref`, `findDOMNode`, legacy context or internals must be updated.
5. **Stay on the latest patch** (RSC CVE fixes landed in 19.0.1 / 19.1.2 / 19.2.1 and later patches).
6. **Adopt new features after the upgrade is green**: Actions, `use`, Activity, `useEffectEvent`, ViewTransition.

## Best Practices
- Upgrade to `react@18.3` first and fix all console deprecation warnings.
- Enable `<StrictMode>` before upgrading to surface impure code.
- Use the migration recipe codemod and the types codemod, and review diffs carefully.
- Replace `react-test-renderer` and shallow rendering with Testing Library (`react-test-renderer` is deprecated).
- Import `act` from `react` (not `react-dom/test-utils`).
- Configure root error callbacks (`onCaughtError`, `onUncaughtError`, `onRecoverableError`) for reporting. React 19 no longer re-throws caught errors to `window.onerror` the same way.

## Implementation Guidance
**Removed / changed APIs and replacements**

| Legacy (removed or deprecated) | Replacement |
|---|---|
| `ReactDOM.render`, `ReactDOM.hydrate` | `createRoot(el).render()`, `hydrateRoot(el, <App/>)` |
| `unmountComponentAtNode` | `root.unmount()` |
| `findDOMNode` | Refs |
| String refs (`ref="input"`) | `useRef` / callback refs |
| Legacy context (`contextTypes`, `getChildContext`) | `createContext` + `use`/`useContext` |
| `propTypes` on components (silently ignored) | TypeScript (or validate at runtime elsewhere) |
| `defaultProps` on function components | ES default parameters |
| `React.createFactory`, module pattern factories | JSX |
| `react-dom/test-utils` `act` | `import { act } from "react"` |
| `react-test-renderer/shallow` | Testing Library |
| `forwardRef` (still works; deprecation planned) | `ref` as a regular prop |
| `<Context.Provider>` (still works; deprecation planned) | `<Context value>` |
| `element.ref` access | `element.props.ref` |
| `useFormState` (react-dom canary) | `useActionState` (react) |
| UMD builds | ESM CDNs (esm.sh) or a bundler |

**TypeScript changes (`@types/react` 19)**
- `useRef` requires an argument: `useRef<HTMLDivElement>(null)`. `RefObject.current` is mutable, and `MutableRefObject` is deprecated.
- Ref callbacks can't implicitly return values (returns are treated as cleanup).
- Global `JSX` namespace removed: use `React.JSX`.
- `ReactElement["props"]` defaults to `unknown` (was `any`).
- `useReducer` typing inferred from the reducer. Avoid explicit legacy generics.
- Removed deprecated types (`ReactChild`, `VoidFunctionComponent`, etc.).

**Codemods (review output)**
```bash
npx codemod@latest react/19/migration-recipe      # runtime API migrations
npx types-react-codemod@latest preset-19 ./src    # type migrations
npx codemod@latest react/19/remove-forward-ref    # optional: ref-as-prop
```

**Feature availability by minor**

| Version | Date | Adds |
|---|---|---|
| 19.0 | Dec 2024 | Actions, `useActionState`, `useOptimistic`, `useFormStatus`, `use`, ref as prop, ref cleanup, `<Context>` provider, document metadata hoisting, stylesheet/script support, `preload`/`preinit`, Server Components/Functions stable |
| 19.1 | Mar 2025 | Owner stacks, Suspense and RSC refinements |
| 19.2 | Oct 2025 | `<Activity>`, `useEffectEvent`, `cacheSignal`, Performance Tracks, partial pre-rendering APIs, SSR Suspense batching, eslint-plugin-react-hooks v6 flat config |
| 19.3 | Sep 2026 | `<ViewTransition>`, Fragment refs, `browser()` (react-dom), Trusted Types support, direct Context rendering from Server Components, independent transition rendering |

## Recommended Workflow
1. Inventory: `npm ls react react-dom @types/react`, framework version, and libraries with React peer ranges.
2. Upgrade to React 18.3 and fix warnings. Enable Strict Mode.
3. Upgrade libraries that declare React 19 support (router, UI kits, form, query, table).
4. Install React 19.3 + types. Run the codemods.
5. Fix the remaining type errors (useRef args, JSX namespace, ref callbacks).
6. Replace test utilities (`act` import, remove the shallow renderer).
7. Run unit, e2e and visual tests. Watch for hydration and double-effect warnings.
8. Wire root error callbacks to observability.
9. Adopt new features incrementally: forms → Actions, `forwardRef` → ref prop, effects → `useEffectEvent`, tab UIs → Activity.
10. Enable the React Compiler after the codebase is lint-clean.

## Patterns
- **Default props via destructuring**: `function Button({ variant = "primary", ...props }: Props)`.
- **Root with error reporting**:
```tsx
createRoot(document.getElementById("root")!, {
  onUncaughtError: (error, info) => report("uncaught", error, info.componentStack),
  onCaughtError: (error, info) => report("caught", error, info.componentStack),
  onRecoverableError: (error) => report("recoverable", error),
}).render(<StrictMode><App /></StrictMode>);
```
- **Document metadata in components** (non-Next.js): `<title>`/`<meta>`/`<link>` rendered anywhere are hoisted to `<head>`. In Next.js, use the Metadata API instead.

## Anti-Patterns
Outdated patterns agents still generate, and their fixes:
- Class components for new code, including `componentDidMount` data fetching. Fix: function components + hooks/loaders.
- `ReactDOM.render(<App/>, el)`. Fix: `createRoot`.
- `forwardRef` wrappers in React 19-only code. Fix: ref prop.
- `Component.defaultProps = {...}` on functions. Fix: default params.
- `PropTypes` validation. Fix: TypeScript + runtime schema at boundaries.
- `import { act } from "react-dom/test-utils"`. Fix: `from "react"`.
- `useFormState`. Fix: `useActionState`.
- `<Context.Provider value>` in new code. Fix: `<Context value>`.
- Create React App (sunset Feb 2025). Fix: Vite or Next.js.
- Suppressing Strict Mode double effects. Fix: add cleanup.

## Accessibility
- Upgrading doesn't change semantics, but re-test focus management where refs were migrated (`findDOMNode` removal, ref callbacks with cleanup).
- React 19 metadata hoisting helps set page titles in SPAs, which benefits screen-reader context on navigation.

## Responsive Design
- Not directly affected. Verify hydration of responsive components after upgrading (19.x hydration error messages are clearer, so fix the mismatches they reveal).

## Performance
- React 19 improves Suspense and hydration behaviour, and 19.2/19.3 improve SSR reveal batching and transition independence.
- Measure before and after with the Profiler and RUM. Enable the React Compiler as a separate, measurable step.

## Security
- **Minimum patch floor** for apps using Server Components/Functions (Next.js App Router): React `react-server-dom-*` ≥ 19.0.1 / 19.1.2 / 19.2.1, preferably latest 19.3.x, due to CVE-2025-55182 (RCE, CVSS 10), CVE-2025-55183, CVE-2025-55184, CVE-2025-67779, CVE-2026-23864.
- React 19.3 Trusted Types support: enable `require-trusted-types-for 'script'` CSP progressively.
- Keep `javascript:` URL blocking expectations: React blocks them in `href`/`src`. Still validate URLs.

## Testing
- Full unit suite on React 19 (Testing Library ≥ 16 for React 19 support).
- e2e smoke tests for hydration errors (Playwright console listeners).
- Add a CI check that fails on React deprecation warnings in test output (optional).

## Tooling
- `codemod` (react/19 recipes), `types-react-codemod`.
- `eslint-plugin-react-hooks` latest (flat config).
- `@testing-library/react` 16+.
- Deprecated: `react-test-renderer`, Create React App, Enzyme (no React 18/19 adapters).

## Framework Notes
### React (Vite SPA)
- Update `main.tsx` to `createRoot`. Update `@vitejs/plugin-react` to match your Vite version (v6 for Vite 8).
- SPA metadata: React 19 `<title>` hoisting replaces `react-helmet` for simple cases.

### Next.js App Router
- Next.js 15+ App Router runs on React 19 (Next.js 16.x in Sept 2026). The Pages Router in Next 15 still supported React 18, but upgrade both for consistency.
- Next.js pins compatible React versions. Upgrade `next`, `react` and `react-dom` together (`npx @next/codemod@canary upgrade latest` handles async request APIs like `await params`, `await cookies()`).
- Use the Metadata API (`export const metadata` / `generateMetadata`) rather than React 19 `<title>` hoisting in App Router pages.
- After the Dec 2025 RSC CVEs, Next.js shipped patched releases across 14.x–16.x lines, so keep `next` on the latest patch of your minor.

## AI Agent Guidance
- First read `package.json` for `react`, `react-dom`, `@types/react` and `next` versions. Generate code for that version only.
- Never emit any legacy pattern from the Anti-Patterns list in React 19 projects.
- When upgrading: run codemods, then `tsc`, tests and build. Report remaining manual fixes with file paths.
- Verify: no deprecation warnings in the console, types clean, tests green, RSC packages at or above the patched versions.

## Examples
```tsx
// Before (React 18 style)
const Input = forwardRef<HTMLInputElement, Props>(function Input(props, ref) {
  return <input ref={ref} {...props} />;
});
Input.defaultProps = { type: "text" };
ReactDOM.render(<App />, document.getElementById("root"));

// After (React 19)
function Input({ type = "text", ref, ...props }: Props & { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} type={type} {...props} />;
}
createRoot(document.getElementById("root")!).render(<StrictMode><App /></StrictMode>);
```

## Related Skills
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md): ref-as-prop migration
- [react-typescript-patterns](../react-typescript-patterns/Skill.md): type changes
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md): adopting Actions
- [react-compiler](../react-compiler/Skill.md): the next step after upgrading
- [nextjs-pages-to-app-router-migration](../nextjs-pages-to-app-router-migration/Skill.md): Next.js migration path
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md): patch management

## Sources
- [React 19 Upgrade Guide](https://react.dev/blog/2024/04/25/react-19-upgrade-guide) (Official): removed APIs, codemods, TypeScript changes
- [React 19 release post](https://react.dev/blog/2024/12/05/react-19) (Official): new features, deprecations
- [React 19.2 post](https://react.dev/blog/2025/10/01/react-19-2) (Official): Activity, useEffectEvent, cacheSignal
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): ViewTransition, Fragment refs, browser(), Trusted Types
- [react.dev versions page](https://react.dev/versions) (Official): release dates
- [RSC security advisory](https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components) (Official): CVE list and fixed versions
- [Sunsetting Create React App](https://react.dev/blog/2025/02/14/sunsetting-create-react-app) (Official): CRA deprecation

## License / Usage Notes
React docs are CC-BY-4.0/MIT. This is a summarized migration table. Codemod commands are listed for reference; review them before running.

## Quality Tier
A: official sources throughout, and version/date verified; the 19.1 feature summary is brief.

## Status
Active

## Last Verified
2026-09-15
