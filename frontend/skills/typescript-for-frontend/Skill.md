# TypeScript for Frontend

## Summary
Configuring and using TypeScript effectively in React and Next.js apps as of Sept 2026: the TypeScript 6.0 -> 7.0 transition (7.0, the Go-native compiler, went GA July 2026 with 8–12x faster builds but no programmatic API until 7.1), recommended `tsconfig` settings, strictness flags, typing patterns for components/data/env, runtime validation boundaries, and tooling compatibility (typescript-eslint, Next.js typegen).

## Category
Tooling

## Subcategories
tsconfig, strict mode, TypeScript 7 native compiler, module resolution, type-safe env, discriminated unions, generics, satisfies, runtime validation, typed routes, type-checking in CI

## Problem It Solves
Loose or outdated TS configs let `any`, unchecked indexing, and implicit type assertions hide bugs; slow `tsc` runs push teams to skip typechecking; legacy options (`baseUrl`, `moduleResolution: node`, `target: es5`) now break on TypeScript 7. A current, strict, fast setup catches bugs at compile time and works with modern bundlers.

## When To Use
- New React/Next.js projects and upgrades to TypeScript 6/7.
- Tightening types in an existing codebase.
- Designing typed APIs for components, hooks, and data layers.

## When Not To Use
- Don't encode complex business validation purely in types — runtime data still needs schemas.
- Don't chase type-level cleverness (deep conditional types) in app code where simpler types suffice.

## Core Principles
1. **Strict by default** (`strict: true` is the TS 7 default) plus `noUncheckedIndexedAccess`.
2. **Types describe trusted data; schemas validate untrusted data.** Parse at boundaries, infer types from schemas.
3. **Bundler compiles, `tsc` checks.** Use `noEmit` + `isolatedModules`/`verbatimModuleSyntax` so each file transpiles independently (Vite/Oxc, Turbopack/SWC).
4. **Model states, not flags:** discriminated unions over optional-everything objects.
5. **Avoid `any`; use `unknown` and narrow.** Casts (`as`) require justification.
6. **Infer where obvious, annotate at module boundaries** (exported functions, component props, API results).

## Best Practices
- Recommended tsconfig for bundler-based React/Next apps (TS 6/7 compatible): `moduleResolution: "bundler"`, `module: "esnext"`, `target: "es2022"` or newer, `jsx: "react-jsx"` (Vite) / `"preserve"` (Next.js manages), `noEmit`, `isolatedModules`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, `noImplicitOverride`, `exactOptionalPropertyTypes` (optional, stricter), `skipLibCheck`.
- TypeScript 7 removed/locked options — migrate now (TS 6.0 deprecations foreshadowed these):
  | Removed/changed in 7.0 | Replacement |
  |---|---|
  | `target: es5`, `downlevelIteration` | ES2015+ targets; bundler handles legacy |
  | `moduleResolution: node`/`node10`/`classic` | `bundler` or `nodenext` |
  | `module: amd/umd/systemjs/none` | `esnext` / `nodenext` |
  | `baseUrl` | `paths` relative to tsconfig (e.g., `"@/*": ["./src/*"]`) |
  | `esModuleInterop`/`allowSyntheticDefaultImports: false` | Always on |
  | `alwaysStrict: false` | Always strict |
  | New defaults: `strict: true`, `types: []`, `noUncheckedSideEffectImports: true`, `rootDir: ./` | Explicitly list `types` (e.g., `["vite/client"]`, `["node"]`) |
- Tooling compatibility (Sept 2026): TS 7 has no stable programmatic API — tools that embed the TS API (typescript-eslint typed linting, some IDE plugins, MDX tooling) need TS 6 APIs. Pattern: install TS 7 for `tsc`, and alias TS 6 for tools: `"typescript": "npm:@typescript/typescript6"` per tool guidance, or keep TS 6.0 until your toolchain certifies 7.x. Check typescript-eslint's supported range before upgrading.
- Use `satisfies` to validate object literals without widening: `const routes = {...} satisfies Record<string, Route>`.
- Use `as const` for literal tuples/objects feeding unions.
- Prefer `type` imports (`import type { X }`) — enforced by `verbatimModuleSyntax`.
- Env vars: validate at startup with a schema (Zod 4 / `@t3-oss/env-nextjs`) and export typed `env`.
- Branded types for IDs that must not mix (`type UserId = string & { __brand: 'UserId' }`).
- Exhaustiveness: `const _exhaustive: never = value` in `default` branches.
- Run `tsc --noEmit` (or `tsgo`) in CI; `next build` also typechecks — don't disable `typescript.ignoreBuildErrors`.

## Implementation Guidance

### tsconfig — Vite 8 React SPA
```json
{
  "compilerOptions": {
    "target": "es2022",
    "lib": ["es2023", "dom", "dom.iterable"],
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "types": ["vite/client"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "noEmit": true,
    "skipLibCheck": true,
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"]
}
```
Vite 8: enable `resolve.tsconfigPaths: true` to honor `paths` (opt-in, small perf cost), or define `resolve.alias` explicitly.

### tsconfig — Next.js 16 App Router
```json
{
  "compilerOptions": {
    "target": "es2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "preserve",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "isolatedModules": true,
    "noEmit": true,
    "incremental": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```
Next.js may rewrite some fields on `next dev`; keep additions compatible. Enable `typedRoutes: true` in `next.config.ts` for type-checked `href`s; Next generates route/params types (`PageProps<'/blog/[slug]'>`, `LayoutProps`) — prefer them over hand-written param types.

### Typing patterns
```tsx
// Props: extend native element props, discriminate variants
type LinkOrButton =
  | ({ as: 'link'; href: string } & Omit<React.ComponentPropsWithRef<'a'>, 'href'>)
  | ({ as?: 'button' } & React.ComponentPropsWithRef<'button'>);

// Async state union + exhaustive switch
type Load<T> = { s: 'idle' } | { s: 'loading' } | { s: 'ok'; data: T } | { s: 'err'; error: string };
function render<T>(l: Load<T>) {
  switch (l.s) {
    case 'idle': case 'loading': return null;
    case 'ok': return l.data;
    case 'err': return l.error;
    default: { const _never: never = l; return _never; }
  }
}

// Generic component with inference
type ListProps<T> = { items: readonly T[]; getKey: (item: T) => string; render: (item: T) => React.ReactNode };
export function List<T>({ items, getKey, render }: ListProps<T>) {
  return <ul>{items.map((i) => <li key={getKey(i)}>{render(i)}</li>)}</ul>;
}
```

### Schema-first types (Zod 4)
```ts
import { z } from 'zod';
export const User = z.object({ id: z.string().uuid(), email: z.email(), role: z.enum(['admin', 'member']) });
export type User = z.infer<typeof User>;
const user = User.parse(await res.json()); // runtime-checked, typed
```

### Typed env (Next.js)
```ts
// src/env.ts
import 'server-only';
import { z } from 'zod';
const Env = z.object({
  DATABASE_URL: z.url(),
  AUTH_SECRET: z.string().min(32),
  NEXT_PUBLIC_APP_URL: z.url(),
});
export const env = Env.parse(process.env);
```
Keep a separate client-safe module for `NEXT_PUBLIC_*` values (must be referenced literally, e.g. `process.env.NEXT_PUBLIC_APP_URL`, for inlining).

### Speeding up typecheck
```bash
npx tsc --noEmit            # TS 7 native (Go) compiler via the typescript package
npx tsc -b                  # project references in monorepos with compiled packages
```

## Recommended Workflow
1. Upgrade to TS 6.0 first; fix deprecation warnings (baseUrl, moduleResolution node, es5).
2. Enable `strict` + `noUncheckedIndexedAccess`; fix errors incrementally (use `// @ts-expect-error` with ticket links sparingly).
3. Add schema validation at API/env/URL boundaries; derive types from schemas.
4. Add CI `tsc --noEmit` and typed linting.
5. Evaluate TS 7: confirm typescript-eslint, Storybook, MDX, and editor tooling support; use TS6 alias for API consumers.
6. Replace hand-written route param types with Next.js generated types.

## Patterns
- **Discriminated unions** for UI states, actions, and API results.
- **`satisfies` config objects** for route maps, flag registries, token maps.
- **Branded IDs** for cross-entity safety.
- **Schema -> type inference** (Zod/Valibot).
- **`ComponentPropsWithRef<'element'>`** for native passthrough.
- **Type-only barrels** (`export type { ... }`) to avoid runtime cycles.

## Anti-Patterns
- **`any` in props or API results** — Fix: `unknown` + schema parse.
- **`as` to silence errors** (`data as User`) — Fix: validate or narrow.
- **Non-null assertions everywhere** (`user!.id`) — Fix: guard clauses; `noUncheckedIndexedAccess` forces handling.
- **`React.FC` with implicit children** (legacy) — Fix: explicit props type with `children?: React.ReactNode`.
- **Enums** in app code — emit runtime objects and conflict with `erasableSyntaxOnly`/type-stripping. Fix: string literal unions + `as const` objects.
- **`baseUrl`-based imports** — removed in TS 7. Fix: `paths` with `./` prefixes.
- **`skipLibCheck: false` in apps** — slow, noisy. Fix: `true` for apps; libraries validate their own `.d.ts`.
- **Disabling type errors in `next build`** — Fix: fix errors; run tsc in CI.

## Accessibility
- Encode accessibility requirements in types: require `aria-label` or `aria-labelledby` for icon-only buttons; require `alt` (allow empty string explicitly for decorative images) on image components.

## Responsive Design
- Type responsive prop objects if your design system supports them (`Partial<Record<Breakpoint, Value>>`) and derive `Breakpoint` from token definitions.

## Performance
- TS 7 native compiler: 8–12x faster full builds and much faster editor load; use it in CI once tooling allows.
- Avoid pathological types (deep recursive conditional types over large unions) — check with `tsc --extendedDiagnostics` / `--generateTrace` (TS 6).
- Keep `include` tight; exclude build outputs.

## Security
- Types don't validate runtime data: always parse external input (requests, Server Action FormData, URL params, postMessage).
- Server-only modules: `import 'server-only'` so accidental client imports fail at build.
- Never type secrets as available on the client (`NEXT_PUBLIC_` prefix only for public values).

## Testing
- `tsc --noEmit` in CI as a required check.
- Type tests: Vitest `expectTypeOf` / `assertType` for public component and hook APIs.
- Lint rules: typescript-eslint `no-explicit-any`, `no-unsafe-*`, `switch-exhaustiveness-check`, `no-floating-promises`.

## Tooling
- TypeScript 7.0 (Go-native, GA July 2026) — Active; no API until 7.1. `@typescript/typescript6` compat package for API consumers.
- TypeScript 6.0 — Active (bridge release; recommended stepping stone).
- `@typescript/native-preview` (`tsgo`) — superseded by `typescript@7` for most uses.
- typescript-eslint (typed linting via `projectService`) — Active; confirm TS 7 support status.
- Zod 4 / Valibot / ArkType — Active runtime schemas.
- `@t3-oss/env-nextjs` — Active typed env.
- ts-reset — Community (tightens built-in lib types).

## Framework Notes
- **React (Vite 8):** Oxc transpiles TS (type-only, no checking) — run `tsc --noEmit` separately (`vite-plugin-checker` optional in dev). Vite 8 supports `emitDecoratorMetadata` automatically; avoid decorators in React code anyway. Add `"types": ["vite/client"]` for `import.meta.env` typing and augment `ImportMetaEnv`.
- **Next.js 16:** `next build` typechecks; generated `.next/types` provide `PageProps`/`LayoutProps`/route types (run `next typegen` in CI before `tsc` if typechecking separately); `params` and `searchParams` are Promises in App Router pages/layouts; `typedRoutes` for `Link href` safety; `next.config.ts` supported natively.
- **React 19 types:** `ref` as prop, `useActionState` generic state, `React.JSX` namespace (global `JSX` namespace removed in `@types/react` 19).

## AI Agent Guidance
- Read the project's tsconfig and TS version first; don't introduce options removed in TS 7 (`baseUrl`, `moduleResolution: node`).
- Do: type exported functions/props explicitly; validate external data with schemas; use discriminated unions; use generated Next.js route types.
- Don't: add `any`, `as` casts, `@ts-ignore`, enums, or `!` assertions to make errors disappear.
- Verify: `tsc --noEmit` (and `next typegen` for Next.js) passes with zero new errors; typed lint passes.

## Examples
```tsx
// Next.js 16 page with generated types and schema-validated search params
import { z } from 'zod';
const Search = z.object({ page: z.coerce.number().int().min(1).default(1), q: z.string().max(100).optional() });
export default async function Page(props: PageProps<'/products'>) {
  const { page, q } = Search.parse(await props.searchParams);
  const products = await getProducts({ page, q });
  return <ProductGrid products={products} />;
}
```
```ts
// Vite env typing
/// <reference types="vite/client" />
interface ImportMetaEnv { readonly VITE_API_URL: string; readonly VITE_RELEASE: string }
interface ImportMeta { readonly env: ImportMetaEnv }
```

## Related Skills
- [react-typescript-patterns](../react-typescript-patterns/Skill.md) — React-specific typing depth
- [linting-and-formatting](../linting-and-formatting/Skill.md) — typed lint rules
- [frontend-build-tooling](../frontend-build-tooling/Skill.md) — transpilation vs checking
- [frontend-api-layer-design](../frontend-api-layer-design/Skill.md) — schema boundaries
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — env typing/safety
- [modern-javascript-for-react](../modern-javascript-for-react/Skill.md) — language features

## Sources
- [Announcing TypeScript 7.0](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/) — Official — removed options, new defaults, API status, tooling compatibility
- [TypeScript TSConfig reference](https://www.typescriptlang.org/tsconfig/) — Official — option semantics
- [Vite 8 announcement](https://vite.dev/blog/announcing-vite8) — Official — resolve.tsconfigPaths, Oxc
- [Next.js TypeScript docs](https://nextjs.org/docs/app/api-reference/config/typescript) — Official — typedRoutes, generated types
- [typescript-eslint typed linting](https://typescript-eslint.io/getting-started/typed-linting) — Official — projectService
- [InfoQ: TypeScript 7.0 released](https://www.infoq.com/news/2026/08/typescript-7-released/) — Community — release context

## License / Usage Notes
TypeScript is Apache-2.0; summarized. Examples original.

## Quality Tier
S — based on official TS 7.0 release notes and framework docs verified Sept 2026; tooling-compat table must be rechecked as 7.1 lands.

## Status
Active

## Last Verified
2026-09-15
