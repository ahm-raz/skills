# React Compiler

## Summary
React Compiler (v1.0 stable since October 7, 2025) is a build-time optimizer. It memoizes components, hooks, JSX and computed values automatically, based on the Rules of React, which removes most hand-written `useMemo`, `useCallback` and `React.memo`. It ships as `babel-plugin-react-compiler`, is supported natively by Next.js (`reactCompiler: true`), and powers the purity and refs lint rules in `eslint-plugin-react-hooks`.

## Category
React

## Subcategories
automatic memoization, Rules of React, eslint-plugin-react-hooks, incremental adoption, "use memo"/"use no memo", Next.js integration, Vite integration, compatibility

## Problem It Solves
Manual memoization is error-prone: missing dependencies, memoizing the wrong things, noisy code, and cascading re-renders when a single reference is unstable. The compiler applies fine-grained memoization consistently, including after early returns, which humans can't do with hooks.

## When To Use
- New React 19 / Next.js 16 projects: enable it from day one.
- Existing codebases with re-render problems that follow the Rules of React (lint clean).
- Replacing large amounts of `useMemo`/`useCallback` boilerplate.

## When Not To Use
- Code that heavily violates the Rules of React (mutating props or state, reading refs in render) until it's fixed. The compiler skips those components, or they may behave differently.
- Components that depend on libraries relying on interior mutability without stable snapshots (e.g. TanStack Table v8's `useReactTable`). Opt those out with `"use no memo"` or upgrade (TanStack Table v9 targets compiler compliance).
- As a substitute for architecture: waterfalls, bundle size and state placement still matter.

## Core Principles
1. **Follow the Rules of React**: pure render, immutable props and state, hooks at top level, no ref reads or writes during render.
2. **Lint first**: `eslint-plugin-react-hooks` (recommended preset) reports the violations the compiler would bail on.
3. **Write plain code in new files.** Let the compiler memoize, and reach for manual memo hooks only for specific needs.
4. **Don't rip out existing memoization blindly.** Removing it can change compiled output. Test before removing.
5. **Adopt incrementally** in large apps: directories, the annotation mode, or runtime gating.
6. **Verify with DevTools**: compiled components show a "Memo ✨" badge.

## Best Practices
- Pin the plugin version (`--save-exact`) and upgrade deliberately. Memoization changes can alter effect timing in code that relied on unstable references.
- Keep effect dependencies correct. The compiler doesn't make an incorrect effect correct.
- Use `"use no memo"` as a temporary escape hatch with a TODO and an issue link, not a permanent fix.
- React 17/18 codebases: set `target: "18"` (or `"17"`) and install `react-compiler-runtime`.
- Monitor with Profiler before and after. Expect fewer re-renders, not necessarily faster individual renders.

## Implementation Guidance
**Setup by stack**

| Stack | Setup |
|---|---|
| Next.js 16 | `npm i -D babel-plugin-react-compiler`, then `reactCompiler: true` in `next.config.ts` (SWC pre-filters files so only those with JSX/hooks go through Babel) |
| Vite 8 + `@vitejs/plugin-react` v6 | `npm i -D @vitejs/plugin-react @rolldown/plugin-babel babel-plugin-react-compiler`, then add `babel({ include: /\.[jt]sx?$/, babelConfig: reactCompilerPreset() })` **before** `react()` |
| Vite ≤7 + plugin-react v5 | `react({ babel: { plugins: ["babel-plugin-react-compiler"] } })` |
| Babel generic | `plugins: ["babel-plugin-react-compiler"]` (must run first in the plugin list) |

```ts
// next.config.ts
import type { NextConfig } from "next";
const nextConfig: NextConfig = {
  reactCompiler: true,
  // or opt-in mode: reactCompiler: { compilationMode: "annotation" },
};
export default nextConfig;
```

```ts
// vite.config.ts (Vite 8, plugin-react v6)
import { defineConfig } from "vite";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";
import { babel } from "@rolldown/plugin-babel";
export default defineConfig({
  plugins: [babel({ include: /\.[jt]sx?$/, babelConfig: reactCompilerPreset() }), react()],
});
```

```js
// eslint.config.js (flat config)
import reactHooks from "eslint-plugin-react-hooks";
export default [reactHooks.configs.recommended /* flat preset; check plugin README for exact key */];
```

**Adoption strategies**

| Strategy | How | Use when |
|---|---|---|
| Whole app | Default `compilationMode` | New or lint-clean apps |
| Opt-in | `compilationMode: "annotation"` + `"use memo"` in the function body | Cautious rollout, hot paths first |
| Directory | Babel `overrides` with `test: "./src/modern/**"` | Large legacy monorepos |
| Runtime gating | `gating: { source, importSpecifierName }` feature flag | A/B measure in production |
| Opt-out | `"use no memo"` in a component or hook | Isolating a regression |

**Manual memoization still justified when**
- A value is used as an effect dependency and must be stable for correctness. The compiler generally handles this, but keep an existing `useMemo` if tests show effects re-firing.
- Interop with non-compiled third-party code that compares references.
- An explicit `memo()` on a component that is re-rendered by a non-compiled parent (library boundary).

## Recommended Workflow
1. Upgrade `eslint-plugin-react-hooks` to the latest version and fix the purity, refs and set-state-in-render diagnostics.
2. Enable the compiler (annotation mode for large apps, or full mode for small ones).
3. Run the full test suite and e2e tests. Check Strict Mode warnings.
4. Inspect DevTools for the "Memo ✨" badge on key components. Investigate components that weren't compiled (use the compiler's logger or the playground).
5. Profile critical interactions before and after.
6. Gradually remove redundant `useMemo`/`useCallback` in touched files, with tests.
7. Expand scope, then remove gating.

## Patterns
- **Plain derived values**: `const visible = todos.filter(matches(filter));`, which the compiler memoizes by `todos` and `filter`.
- **Inline handlers are fine**: `onClick={() => select(id)}` stays stable when `id` is unchanged.
- **Early returns with memoized work after them**: allowed. The compiler handles it, whereas manual hooks can't be called after a return.
- **Escape hatch comment convention**: `"use no memo"; // TODO(#123): TanStack Table v8 mutable instance`.

## Anti-Patterns
- **Mutating during render** (`props.items.sort()`): the compiler bails or results go stale. Fix: `toSorted()`.
- **Reading `ref.current` in render**: breaks memoization. Fix: read in effects or handlers, or use state.
- **Global mutable variables read in render**: stale output. Fix: state, context or external stores via `useSyncExternalStore`.
- **Keeping `// eslint-disable react-hooks/*` lines**: hides bail-outs. Fix: fix the code.
- **Assuming the compiler fixes waterfalls or bundles**: it doesn't. Fix: architecture.
- **Removing all `useMemo` in one PR on a large app**: hard to bisect regressions. Fix: incremental removal with tests.
- **Opting the entire app out with `"use no memo"` because of one library**: fix it locally instead.

## Accessibility
- The compiler doesn't change rendered output semantics. A11y is unaffected, but test focus behaviour where effects previously fired more often (e.g. focus effects that depended on unstable references).

## Responsive Design
- Not applicable directly. Fewer re-renders during resize-driven state updates improve responsiveness on low-end mobile.

## Performance
- Meta reported up to 12% faster initial loads and navigations, and some interactions more than 2.5x faster, with neutral memory. Your results depend on how many re-render cascades you have.
- Build time increases slightly (Babel pass). Next.js limits this with SWC pre-filtering. Vite 8's Rolldown/Oxc pipeline keeps the Babel pass scoped by `include`.

## Security
- There is no direct security impact. Pin the plugin version as with any build-time dependency (supply-chain hygiene).

## Testing
- Run the existing unit and integration suites with the compiler enabled in the test transform (Vitest uses the Vite config, so the compiler applies there too).
- Add Playwright checks for critical flows before enabling it in production.
- Use runtime gating to compare RUM metrics (INP) between the compiled and non-compiled cohorts.

## Tooling
- `babel-plugin-react-compiler` 1.x (stable).
- `eslint-plugin-react-hooks` (recommended preset includes the compiler-powered rules; the old separate `eslint-plugin-react-compiler` has been folded into it).
- `react-compiler-runtime` (only for React 17/18 targets).
- React DevTools ("Memo ✨" badge). React Compiler Playground (playground.react.dev) to inspect output.
- Work is ongoing on native SWC/OXC compiler support, so today Babel remains the reference implementation.

## Framework Notes
### React (Vite SPA)
- Vite 8 + `@vitejs/plugin-react` v6 dropped its internal Babel. Use `@rolldown/plugin-babel` with `reactCompilerPreset()`, placed before `react()`. The old `react({ babel: {...} })` option no longer works in v6.
- Vitest picks up the Vite config, so tests run compiled code, which is good for parity.

### Next.js App Router
- `reactCompiler: true` in `next.config.ts` (stable in Next.js 16). Supports `compilationMode: "annotation"`.
- The compiler optimizes **Client Components**. Server Components render once per request, so memoization has little value there. The compiler still runs on shared files, and that is harmless.
- Keep `"use client"` and `"use memo"`/`"use no memo"` directives at the top of the module or function body respectively. They coexist.
- Turbopack builds work with the compiler via Next's integration. No custom Babel config is needed. Adding a `.babelrc` disables SWC and is not recommended.

## AI Agent Guidance
- Check whether the compiler is enabled (`next.config.*` `reactCompiler`, or Vite babel plugin) before adding memoization. If it's enabled, write plain code.
- Never add `"use no memo"` without a comment explaining why and a follow-up.
- Fix lint diagnostics from `react-hooks` rather than disabling them.
- Verify: build succeeds, lint is clean, tests pass, DevTools shows compiled components, and no new effect loops appear.

## Examples
```tsx
// Before (manual)
const Row = memo(function Row({ item, onSelect }: RowProps) { /* ... */ });
function List({ items, filter, onSelect }: ListProps) {
  const visible = useMemo(() => items.filter((i) => i.tag === filter), [items, filter]);
  const handle = useCallback((id: string) => onSelect(id), [onSelect]);
  return visible.map((i) => <Row key={i.id} item={i} onSelect={handle} />);
}

// After (compiler enabled)
function Row({ item, onSelect }: RowProps) { /* ... */ }
function List({ items, filter, onSelect }: ListProps) {
  const visible = items.filter((i) => i.tag === filter);
  return visible.map((i) => <Row key={i.id} item={i} onSelect={(id) => onSelect(id)} />);
}
```

## Related Skills
- [react-performance-optimization](../react-performance-optimization/Skill.md): where the compiler fits in the perf playbook
- [react-hooks-patterns](../react-hooks-patterns/Skill.md): Rules of React and effects
- [linting-and-formatting](../linting-and-formatting/Skill.md): eslint-plugin-react-hooks setup
- [vite-react-spa](../vite-react-spa/Skill.md): Vite configuration
- [react-nextjs-project-setup](../react-nextjs-project-setup/Skill.md): enabling in new projects
- [tanstack-table](../tanstack-table/Skill.md): v8 compatibility caveat

## Sources
- [React Compiler v1.0 announcement](https://react.dev/blog/2025/10/07/react-compiler-1) (Official): stability, results, lint integration
- [react.dev: React Compiler introduction](https://react.dev/learn/react-compiler/introduction) (Official): what it memoizes, existing memo guidance
- [react.dev: Incremental adoption](https://react.dev/learn/react-compiler/incremental-adoption) (Official): overrides, annotation mode, gating
- [Next.js docs: reactCompiler](https://nextjs.org/docs/app/api-reference/config/next-config-js/reactCompiler) (Official): config, SWC optimization, annotation mode
- [React Compiler + Vite 8 install guide (recca0120, Apr 2026)](https://recca0120.github.io/en/2026/04/14/react-compiler-vite-v6/) (Community): plugin-react v6 + @rolldown/plugin-babel setup

## License / Usage Notes
React and the compiler are MIT. Docs are summarized. The Vite v6 setup comes from a community source and should be verified against the `@vitejs/plugin-react` README.

## Quality Tier
A: official sources for the core material; the Vite 8 setup and the exact eslint preset key come from secondary sources and change quickly.

## Status
Active

## Last Verified
2026-09-15
