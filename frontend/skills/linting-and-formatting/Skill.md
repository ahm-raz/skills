# Linting and Formatting

## Summary
Setting up code quality tooling for React/Next.js TypeScript projects in Sept 2026: ESLint 10 (flat config only; eslintrc removed Feb 2026) with typescript-eslint typed linting, React Hooks/Compiler and Next.js plugins, jsx-a11y; the Rust-based alternatives Biome 2.4 (lint + format, own type inference) and Oxlint 1.x (fast lint, type-aware via tsgo) plus Oxfmt (beta, 100% Prettier JS/TS conformance); Prettier 3; Stylelint; and enforcement via editor, pre-commit, and CI.

## Category
Tooling

## Subcategories
ESLint flat config, typescript-eslint, eslint-plugin-react-hooks, @next/eslint-plugin-next, jsx-a11y, Biome, Oxlint, Oxfmt, Prettier, Stylelint, lint-staged, CI enforcement

## Problem It Solves
Inconsistent formatting causes noisy diffs; missing lint rules let bugs (floating promises, hooks misuse, a11y violations, unsafe `any`) reach production; slow linters get disabled. A fast, layered setup catches real bugs automatically and removes style debates.

## When To Use
- Every React/Next.js repository, from day one.
- Migrating from `.eslintrc` (no longer supported in ESLint 10).
- CI lint times hurting developer flow in large repos/monorepos.

## When Not To Use
- Don't add stylistic lint rules that a formatter handles (eslint-config-prettier disables conflicts; `@stylistic` rules only if you don't use a formatter).
- Don't enable every "strict" preset in a legacy codebase at once — ratchet.

## Core Principles
1. **Formatter formats, linter finds bugs.** Never both fighting over whitespace.
2. **Type-aware rules catch the valuable bugs** (floating promises, unsafe any, misused promises).
3. **Fast feedback:** editor on save, staged-file hooks, full check in CI.
4. **Rules are code:** shared config package in monorepos, versioned, documented exceptions.
5. **Errors, not warnings,** for rules you care about; warnings get ignored.
6. **Ratchet legacy code** (baseline/suppressions) instead of disabling rules.

## Best Practices
- ESLint 10: `eslint.config.js|mjs|ts` only; use `defineConfig` and `extends` from `eslint/config`; Node ^20.19 || ^22.13 || >=24. Migrate with `npx @eslint/migrate-config .eslintrc.json`.
- typescript-eslint: `projectService: true` for typed linting; `recommendedTypeChecked` baseline, `strictTypeChecked` for new code.
- React: `eslint-plugin-react-hooks` (flat `recommended` config; newer versions include React Compiler–related rules — the standalone `eslint-plugin-react-compiler` was merged into react-hooks; verify version).
- Next.js: `@next/eslint-plugin-next` (`recommended` + `core-web-vitals`), or `eslint-config-next` flat export. Note: `next lint` was deprecated/removed in Next.js 16 — run the ESLint CLI directly.
- Accessibility: `eslint-plugin-jsx-a11y` flat `recommended` (static checks only; still run axe).
- Import hygiene: `eslint-plugin-import-x` or Biome/Oxlint import rules; `no-restricted-imports` for architecture boundaries and banned packages (e.g., `lodash` full import, `moment`).
- Formatting: Prettier 3 (default choice), Biome formatter (~97% Prettier compat), or Oxfmt (beta; passes Prettier JS/TS conformance, 30x faster; adopted by vuejs/core, turborepo, sentry-javascript). Include Tailwind class sorting (prettier-plugin-tailwindcss, or Oxfmt/Biome built-ins where available).
- Speed options: run Oxlint first for syntax rules and ESLint only for type-aware/plugin rules (`eslint-plugin-oxlint` disables overlapping ESLint rules), or full Biome.
- Use ESLint's caching (`--cache --cache-location node_modules/.cache/eslint`) and lint only affected packages in monorepos.
- Legacy code: ESLint bulk suppressions (`--suppress-all` creates `eslint-suppressions.json`, available since v9.24) to adopt new rules without fixing everything immediately; prune over time.
- Stylelint for CSS Modules/global CSS: `stylelint-config-standard`, `declaration-strict-value` for tokens, logical properties plugin.
- Pre-commit: lint-staged + simple-git-hooks/husky/lefthook with formatter + fast lint on staged files; full typed lint in CI.

## Implementation Guidance

### Decision table
| Situation | Recommended stack |
|---|---|
| Standard Next.js/React app | ESLint 10 + typescript-eslint (typed) + react-hooks + next + jsx-a11y; Prettier 3 |
| Large monorepo, lint too slow | Oxlint (most rules) + ESLint (typed + plugin-only rules) + Prettier/Oxfmt |
| Greenfield, want one tool | Biome 2.4 (lint + format); add ESLint only for Next/a11y/plugin gaps |
| Heavy custom ESLint plugins | ESLint 10; consider Oxlint JS plugins compatibility later |

### ESLint 10 flat config for Next.js 16
```js
// eslint.config.mjs
import js from '@eslint/js';
import { defineConfig, globalIgnores } from 'eslint/config';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import next from '@next/eslint-plugin-next';
import prettier from 'eslint-config-prettier/flat';

export default defineConfig([
  globalIgnores(['.next/**', 'dist/**', 'coverage/**', 'next-env.d.ts']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommendedTypeChecked,
      reactHooks.configs['recommended-latest'] ?? reactHooks.configs.recommended, // name varies by plugin version
      jsxA11y.flatConfigs.recommended,
    ],
    plugins: { '@next/next': next },
    languageOptions: { parserOptions: { projectService: true } },
    rules: {
      ...next.configs.recommended.rules,
      ...next.configs['core-web-vitals'].rules,
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/switch-exhaustiveness-check': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
      'no-restricted-imports': ['error', {
        patterns: [{ group: ['@/features/*/*'], message: 'Import features via their public index.' }],
        paths: [{ name: 'moment', message: 'Use date-fns or Intl/Temporal.' }],
      }],
    },
  },
  prettier,
]);
```
Check exact exported config names for each plugin version (`flat/recommended` vs `recommended`); they changed during the flat-config transition.

### Vite React SPA variant
Same as above minus the Next plugin; add `eslint-plugin-react-refresh` (`only-export-components`) for HMR safety.

### Oxlint + ESLint hybrid
```json
// .oxlintrc.json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["typescript", "react", "jsx-a11y", "import", "nextjs"],
  "categories": { "correctness": "error", "suspicious": "warn" },
  "rules": { "react/rules-of-hooks": "error", "no-console": ["warn", { "allow": ["warn", "error"] }] }
}
```
```js
// eslint.config.mjs (append last)
import oxlint from 'eslint-plugin-oxlint';
export default defineConfig([ /* ...typed rules... */, ...oxlint.buildFromOxlintConfigFile('./.oxlintrc.json') ]);
```
```json
{ "scripts": { "lint": "oxlint && eslint --cache ." } }
```
Oxlint type-aware mode (uses tsgo / TS 7 internals) is 10–20x slower than syntax-only but still faster than ESLint typed linting; evaluate for replacing typescript-eslint typed rules.

### Biome 2.4 config
```json
// biome.json
{
  "$schema": "https://biomejs.dev/schemas/2.4.0/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "formatter": { "enabled": true, "indentStyle": "space", "lineWidth": 100 },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "a11y": { "recommended": true },
      "nursery": { "noFloatingPromises": "error" }
    },
    "domains": { "react": "recommended", "next": "recommended" }
  },
  "assist": { "actions": { "source": { "organizeImports": "on" } } }
}
```
Biome's type-aware rules use its own inference (partial parity with typescript-eslint); verify rule names/groups against the installed version.

### Prettier + lint-staged
```json
// package.json
{
  "prettier": { "singleQuote": true, "printWidth": 100, "plugins": ["prettier-plugin-tailwindcss"] },
  "lint-staged": {
    "*.{ts,tsx,js,mjs}": ["prettier --write", "eslint --cache --fix --max-warnings=0"],
    "*.{css,md,json,yml}": ["prettier --write"]
  },
  "simple-git-hooks": { "pre-commit": "npx lint-staged" }
}
```

### CI
```yaml
- run: pnpm prettier --check .
- run: pnpm eslint --cache --max-warnings=0 .
- run: pnpm tsc --noEmit
```

## Recommended Workflow
1. Choose stack via decision table; install formatter first and format the repo in one commit (add to `.git-blame-ignore-revs`).
2. Add ESLint 10 flat config (or migrate with `@eslint/migrate-config`).
3. Enable typed linting with `projectService`; fix or suppress (bulk suppressions) existing violations.
4. Add React Hooks, Next.js, jsx-a11y, and architecture `no-restricted-imports` rules.
5. Add editor settings (`.vscode/settings.json` format on save, ESLint flat config enabled).
6. Add lint-staged pre-commit and CI checks with `--max-warnings=0`.
7. Measure lint time; introduce Oxlint hybrid or Biome if slow.

## Patterns
- **Shared config package** (`@acme/eslint-config/next`, `/react`, `/library`).
- **Formatter commit + blame ignore.**
- **Ratchet with suppressions file**, burning down per sprint.
- **Architecture rules as lint** (`no-restricted-imports`, boundaries plugin).
- **Hybrid fast/slow linting:** Oxlint pre-commit, full typed ESLint in CI.

## Anti-Patterns
- **`.eslintrc.*` files** — ignored by ESLint 10. Fix: flat config.
- **`next lint`** — removed/deprecated with Next.js 16. Fix: `eslint .`.
- **ESLint formatting rules + Prettier** — conflicts. Fix: `eslint-config-prettier`.
- **Warnings that never fail CI** — Fix: `--max-warnings=0` or make them errors.
- **Blanket `eslint-disable` at file top** — Fix: line-level disables with reason (`-- reason`), `reportUnusedDisableDirectives`.
- **Typed linting with legacy `project: ['./tsconfig.json']` globs** in monorepos — slow/misconfigured. Fix: `projectService: true`.
- **Disabling `react-hooks/exhaustive-deps`** — stale closures. Fix: restructure, or rely on React Compiler rules guidance.
- **Running full typed lint in pre-commit** — slow, bypassed. Fix: staged fast checks; typed in CI.

## Accessibility
- `eslint-plugin-jsx-a11y` catches static issues (missing `alt`, invalid ARIA, click handlers on non-interactive elements, label association) mapped to WCAG 1.1.1, 2.1.1, 4.1.2; Biome and Oxlint include a11y rule groups. Static lint covers only a fraction of WCAG — pair with axe and manual testing.

## Responsive Design
- Stylelint rules can enforce logical properties and token usage for spacing/breakpoints; no direct linting of responsive behavior.

## Performance
- Oxlint: ~30–50x faster than ESLint on syntax rules; Biome similar class; Oxfmt ~30x faster than Prettier and ~3x faster than Biome formatting (vendor benchmarks).
- ESLint caching and affected-only runs in monorepos.
- Next.js core-web-vitals rules flag performance footguns (`<img>` instead of `next/image`, sync scripts).

## Security
- Security-relevant rules: `no-eval`, `no-implied-eval`, `react/no-danger` (or Biome `noDangerouslySetInnerHtml`), `@typescript-eslint/no-unsafe-*`, `no-restricted-imports` banning `child_process` in client code, eslint-plugin-security / eslint-plugin-no-unsanitized for DOM sinks.
- Lint configs and plugins are dependencies executed on every developer machine — apply supply-chain hygiene (pinning, cooldown).

## Testing
- Test custom lint rules with ESLint `RuleTester`.
- CI verifies formatter check, lint with zero warnings, typecheck.
- Periodically run `eslint --print-config file.tsx` to confirm expected rules apply.

## Tooling
- ESLint 10.x — Active (flat config only).
- typescript-eslint 8.x — Active (confirm TS 7 support; use TS 6 alias if needed).
- eslint-plugin-react-hooks — Active (includes compiler-related rules in recent versions).
- @next/eslint-plugin-next / eslint-config-next — Active.
- eslint-plugin-jsx-a11y — Active.
- Biome 2.4 — Active.
- Oxlint 1.x — Active; type-aware mode newer (2026).
- Oxfmt — Beta (Feb 2026).
- Prettier 3.x — Active.
- Stylelint 16/17 — Active.
- lint-staged, simple-git-hooks, husky, lefthook — Active.
- eslint-plugin-react-compiler (standalone) — superseded by react-hooks plugin rules (verify).
- TSLint — Archived.

## Framework Notes
- **React (Vite SPA):** add `eslint-plugin-react-refresh` to keep Fast Refresh working (components-only exports); jsx-a11y and react-hooks as core; no Next plugin.
- **Next.js 16:** use ESLint CLI with `@next/eslint-plugin-next` (`next lint` gone); `next build` no longer runs lint automatically in 16 — run lint in CI explicitly. Include rules for `'use client'`/server-only misuse where available (e.g., restrict `next/headers` imports in client directories via `no-restricted-imports`).

## AI Agent Guidance
- Run the project's lint and format commands after edits; fix violations rather than disabling rules.
- Do: follow existing config; use line-level disables with a reason only when justified; keep formatting via the configured formatter.
- Don't: add `.eslintrc` files, reformat unrelated files, change lint config to pass your change, or introduce a second formatter.
- Verify: `prettier --check` (or `biome check`/`oxfmt --check`), `eslint --max-warnings=0`, and `tsc --noEmit` all pass.

## Examples
```tsx
// Justified, scoped disable with reason (ESLint 9+/10 syntax)
// eslint-disable-next-line react-hooks/exhaustive-deps -- subscribe once on mount; handler read via ref
useEffect(() => subscribe(handlerRef), []);
```
```json
// .vscode/settings.json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": { "source.fixAll.eslint": "explicit" }
}
```

## Related Skills
- [typescript-for-frontend](../typescript-for-frontend/Skill.md) — typed rules depend on TS setup
- [feature-based-architecture](../feature-based-architecture/Skill.md) — boundary rules
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) — beyond static a11y lint
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — shared configs
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) — CI enforcement
- [react-compiler](../react-compiler/Skill.md) — compiler lint rules

## Sources
- [ESLint v10.0.0 released](https://eslint.org/blog/2026/02/eslint-v10.0.0-released/) — Official — eslintrc removal, Node support
- [ESLint: Migrate to v10](https://eslint.org/docs/latest/use/migrate-to-10.0.0) — Official — migration
- [typescript-eslint: Typed linting](https://typescript-eslint.io/getting-started/typed-linting) — Official — projectService, presets
- [Oxfmt Beta announcement](https://oxc.rs/blog/2026-02-24-oxfmt-beta) — Official — conformance, adoption
- [Biome](https://biomejs.dev) — Official — v2.x config, type-aware rules
- [Oxlint](https://oxc.rs/docs/guide/usage/linter) — Official — config, eslint-plugin-oxlint
- [Faster Type-Aware Lint Rules: Biome vs Oxlint](https://www.solberg.is/fast-type-aware-linting) — Community — type-aware tradeoffs
- [Next.js ESLint config](https://nextjs.org/docs/app/api-reference/config/eslint) — Official — plugin usage

## License / Usage Notes
All tools MIT. Summarized; configs original; plugin export names flagged for verification.

## Quality Tier
A — ESLint 10, typescript-eslint, Oxfmt verified from official sources; some plugin config export names and Next 16 lint behavior should be rechecked per version.

## Status
Active

## Last Verified
2026-09-15
