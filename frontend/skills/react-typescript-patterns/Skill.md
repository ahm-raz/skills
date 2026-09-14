# React TypeScript Patterns

## Summary
Practical TypeScript patterns for React 19 and Next.js App Router: typing props (native element props, `children`, slots), discriminated-union props, generic components, events, refs as props, hooks (`useState`, `useReducer`, context), polymorphic components, Server Action and route types (`params` as Promise, `PageProps`/`LayoutProps` helpers), and the `@types/react` 19 breaking changes. The aim is types that catch misuse without ceremony.

## Category
React

## Subcategories
props typing, ComponentProps, children/ReactNode, discriminated unions, generic components, event types, ref typing, hook typing, context typing, polymorphism, Next.js route types, @types/react 19 changes

## Problem It Solves
`any`-typed props, components that accept impossible prop combinations, lost autocomplete for native attributes, broken generics in tables and selects, confusing event types, and upgrade breakages in `@types/react` 19 (global `JSX` removal, `useRef` arguments, `ReactElement` props as `unknown`).

## When To Use
- Authoring any React component or hook in TypeScript.
- Designing reusable UI (design systems, tables, forms).
- Upgrading to React 19 types or Next.js 15/16 async route props.

## When Not To Use
- General TypeScript configuration and strictness: see typescript-for-frontend.
- Runtime validation: TypeScript doesn't validate API or form data. Use Zod or Valibot at the boundaries.

## Core Principles
1. **`strict: true`** (plus `noUncheckedIndexedAccess` recommended). No `any` in component APIs.
2. **Extend native props** instead of re-declaring them: `React.ComponentProps<"button">`.
3. **Make impossible states unrepresentable** with discriminated unions.
4. **Infer where possible**, annotate at boundaries (props, hook return types for public hooks, API responses).
5. **Types describe; schemas validate.** Derive types from Zod schemas for external data (`z.infer`).
6. **Use React 19 types idioms**: `ref` in props, `React.JSX` namespace, and `ReactNode` for renderable content.

## Best Practices
- Type props with `type` aliases (unions and intersections compose better). `interface` is also fine for object shapes; be consistent.
- Skip `React.FC`. Annotate props directly. The return type is inferred.
- `children: React.ReactNode` for arbitrary content. `React.ReactElement` only when you must clone or inspect (rare).
- Use `React.ComponentProps<"input">` (includes `ref` in React 19). `ComponentPropsWithoutRef` is only needed when deliberately excluding refs.
- Use `Omit<..., "onChange">` when you redefine a native prop with a different signature.
- Event handler types: `React.ChangeEvent<HTMLInputElement>`, `React.FormEvent<HTMLFormElement>`, `React.KeyboardEvent<HTMLDivElement>`, `React.MouseEvent<HTMLButtonElement>`. Or type the handler: `onChange: React.ChangeEventHandler<HTMLInputElement>`.
- `useState<User | null>(null)` when the initial value doesn't reveal the full type.
- `as const` for literal tuples and option arrays. `satisfies` to check config objects without widening.
- Export prop types (`export type ButtonProps`) for consumers and wrappers.

## Implementation Guidance
**Common typing table**

| Thing | Type |
|---|---|
| Renderable content | `React.ReactNode` |
| Element-only slot | `React.ReactElement` |
| Native button props | `React.ComponentProps<"button">` |
| Props of another component | `React.ComponentProps<typeof Button>` |
| Style prop | `React.CSSProperties` |
| Ref prop | `ref?: React.Ref<HTMLDivElement>` |
| DOM ref object | `useRef<HTMLDivElement>(null)` → `RefObject<HTMLDivElement \| null>` |
| setState prop | `React.Dispatch<React.SetStateAction<T>>` (or narrower `(v: T) => void`) |
| JSX element type (global removed) | `React.JSX.Element` |
| Form Action | `(formData: FormData) => void \| Promise<void>` |
| useActionState action | `(prev: S, formData: FormData) => Promise<S>` |

**Discriminated union props**
```tsx
type ButtonLinkProps =
  | ({ as: "button" } & React.ComponentProps<"button">)
  | ({ as: "link"; href: string } & Omit<React.ComponentProps<"a">, "href">);

export function Action(props: ButtonLinkProps) {
  if (props.as === "link") { const { as, ...rest } = props; return <a {...rest} />; }
  const { as, ...rest } = props; return <button type="button" {...rest} />;
}
```

**Variant props with exhaustive check**
```tsx
type AlertProps = { variant: "info" | "warning" | "error"; children: React.ReactNode };
function iconFor(v: AlertProps["variant"]) {
  switch (v) {
    case "info": return "ℹ";
    case "warning": return "⚠";
    case "error": return "✖";
    default: { const _exhaustive: never = v; return _exhaustive; }
  }
}
```

**Generic component**
```tsx
type SelectProps<T> = {
  items: readonly T[];
  value: T | null;
  onChange: (item: T) => void;
  getKey: (item: T) => string;
  getLabel: (item: T) => string;
};
export function Select<T>({ items, value, onChange, getKey, getLabel }: SelectProps<T>) {
  return (
    <ul role="listbox">
      {items.map((it) => (
        <li key={getKey(it)} role="option" aria-selected={value !== null && getKey(value) === getKey(it)}
          onClick={() => onChange(it)}>{getLabel(it)}</li>
      ))}
    </ul>
  );
}
// <Select items={users} getKey={u => u.id} getLabel={u => u.name} value={sel} onChange={setSel} />  → T inferred as User
```
In `.tsx` arrow functions, write generics as `<T,>(props: ...) =>`.

**Typed reducer**
```ts
type State = { status: "idle" } | { status: "loading" } | { status: "success"; data: Order[] } | { status: "error"; error: string };
type Action = { type: "fetch" } | { type: "resolve"; data: Order[] } | { type: "reject"; error: string };
const reducer = (s: State, a: Action): State => { /* ... */ return s; };
const [state, dispatch] = useReducer(reducer, { status: "idle" }); // types inferred from reducer
```

**Schema-derived types**
```ts
export const OrderSchema = z.object({ id: z.string(), totalCents: z.number().int(), status: z.enum(["open", "paid"]) });
export type Order = z.infer<typeof OrderSchema>;
```

## Recommended Workflow
1. Define domain types from schemas at API and form boundaries.
2. Write the component's prop type: native extension + domain props + variants as unions.
3. Implement, letting inference work inside.
4. Add `@ts-expect-error` type tests for forbidden combinations (or `expectTypeOf` in Vitest).
5. Run `tsc --noEmit` (and `next typegen` / `next build` for Next.js route types) in CI.

## Patterns
- **Polymorphic via `asChild`** (preferred over `as` generics): see react-component-composition.
- **Props passthrough wrapper**: `function PrimaryButton(props: React.ComponentProps<typeof Button>) { return <Button variant="primary" {...props} />; }`.
- **Context with non-null hook**: `createContext<Ctx | null>(null)` + throwing hook returns `Ctx`.
- **Custom hook return as tuple**: `return [value, setValue] as const;`.
- **Typed Server Action state**: an exported `State` type shared between the action and `useActionState`.
- **Branded ids**: `type UserId = string & { readonly __brand: "UserId" }` to avoid mixing ids.

## Anti-Patterns
- **`React.FC<Props>` everywhere**: adds nothing in React 18+, and generic components are awkward. Fix: annotate props directly.
- **`any` for event handlers or `children`**: lost safety. Fix: specific event and ReactNode types.
- **Optional-everything props with runtime checks** (`href?` + `onClick?` + `as?`). Fix: discriminated unions.
- **Global `JSX.Element`** in React 19 types: the global namespace was removed. Fix: `React.JSX.Element`, or let it infer.
- **`useRef<HTMLDivElement>()` without an argument**: error in React 19 types. Fix: `useRef<HTMLDivElement>(null)`.
- **Casting API responses** (`as User`): unchecked. Fix: schema parse.
- **Next.js 15+ `params: { id: string }` synchronously**: it's a Promise now. Fix: `params: Promise<{ id: string }>` and `await`.
- **`ReactElement.props` access assuming `any`**: props default to `unknown` in React 19 types. Fix: type the element explicitly or avoid inspection.

## Accessibility
- Encode a11y requirements in types: require `aria-label` when there's no visible label (`{ label: string } | { "aria-label": string }` union), and require `alt` for images (`alt: string`, allowing `""` for decorative).
- Icon-only buttons: make `aria-label` mandatory via a variant type.

## Responsive Design
- Type responsive prop values if your design system supports them: `type Responsive<T> = T | { base: T; md?: T; lg?: T }`. Prefer CSS-driven responsiveness.

## Performance
- Types have no runtime cost, but complex generic types slow the editor and `tsc`. Avoid deeply recursive polymorphic types, and prefer `asChild`.
- Use `import type` for type-only imports so bundlers tree-shake and avoid client-bundle pulls in Next.js.

## Security
- Types don't sanitize. Validate Server Action inputs with schemas even when the TS type says `string`.
- Use `import "server-only"` in modules that export server types plus implementation, to prevent client imports.

## Testing
- `tsc --noEmit` in CI. `vitest --typecheck` with `expectTypeOf` for public component and hook APIs.
- `@ts-expect-error` lines as negative tests (they fail if the error disappears).

## Tooling
- TypeScript 5.x/6.x with `strict`. `@types/react` and `@types/react-dom` 19.x.
- `types-react-codemod` for React 19 type migrations.
- `typescript-eslint` (`no-explicit-any`, `consistent-type-imports`).
- Zod v4 / Valibot for schema-derived types.
- Next.js typed routes and generated `PageProps`/`LayoutProps` helpers (`next typegen`).

## Framework Notes
### React (Vite SPA)
- `tsconfig` from the Vite React TS template (`jsx: "react-jsx"`, `moduleResolution: "bundler"`, `verbatimModuleSyntax`). Vite strips types without checking, so run `tsc -b` in build and CI.
- Type `import.meta.env` via `vite-env.d.ts` (`interface ImportMetaEnv { readonly VITE_API_URL: string }`).

### Next.js App Router
- Route props are Promises (15+):
```tsx
export default async function Page({ params, searchParams }: {
  params: Promise<{ slug: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { slug } = await params;
  const { page } = await searchParams;
  // ...
}
```
- Newer Next.js versions generate global helpers, so you can write `export default async function Page(props: PageProps<"/blog/[slug]">)` and `LayoutProps<"/dashboard">` (run `next dev`/`next build`/`next typegen` to generate them; confirm availability in your version).
- Client Components receive `params` from `useParams<{ slug: string }>()` (sync) in client code.
- Server Action types: share `State` types between `actions.ts` (`"use server"`) and client forms. Only serializable types cross the boundary (no class instances or functions).
- Props passed from Server to Client Components must be serializable. Keep prop types to plain data, `Date`, `Map`/`Set`, Promises and JSX.
- `typedRoutes: true` in `next.config.ts` for type-checked `<Link href>`.
- Env types: declare `process.env` keys in a `env.d.ts`, or validate them with a schema at startup (`@t3-oss/env-nextjs`).

## AI Agent Guidance
- Read `tsconfig.json`, the `@types/react` version and the Next.js version before generating types.
- Don't generate `React.FC`, global `JSX`, `forwardRef` generics (React 19), or sync `params` (Next 15+).
- Prefer discriminated unions for variant-dependent props, and `ComponentProps<"el">` for native extension.
- Verify: `tsc --noEmit` passes with no new `any`/`as` casts on external data, and route types are generated.

## Examples
```tsx
// Accessible icon button: label is required by type
type IconButtonProps = Omit<React.ComponentProps<"button">, "children"> & {
  icon: React.ReactNode;
  "aria-label": string;
};
export function IconButton({ icon, ...props }: IconButtonProps) {
  return <button type="button" {...props}><span aria-hidden="true">{icon}</span></button>;
}
// <IconButton icon={<TrashIcon/>} />  // TS error: aria-label missing
```

## Related Skills
- [typescript-for-frontend](../typescript-for-frontend/Skill.md): compiler config and general TS practices
- [react-component-composition](../react-component-composition/Skill.md): typing slots and asChild
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md): ref typing in React 19
- [react-custom-hooks-library-design](../react-custom-hooks-library-design/Skill.md): typing public hooks
- [trpc-and-type-safe-apis](../trpc-and-type-safe-apis/Skill.md): end-to-end types
- [react-19-migration-guide](../react-19-migration-guide/Skill.md): @types/react 19 breaking changes
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md): route file conventions

## Sources
- [react.dev: Using TypeScript](https://react.dev/learn/typescript) (Official): props, hooks, event and DOM types
- [React 19 Upgrade Guide: TypeScript changes](https://react.dev/blog/2024/04/25/react-19-upgrade-guide#typescript-changes) (Official): useRef argument, JSX namespace, ref callback returns, ReactElement props unknown
- [Next.js docs: TypeScript / page.js params Promise](https://nextjs.org/docs/app/api-reference/config/typescript) (Official): route props typing, typed routes
- [React TypeScript Cheatsheet](https://react-typescript-cheatsheet.netlify.app/) (Community): generic components, polymorphism, patterns
- [Total TypeScript: React articles (Matt Pocock)](https://www.totaltypescript.com/) (Community): ComponentProps, generics in TSX

## License / Usage Notes
React docs are CC-BY-4.0. The cheatsheet is MIT. Examples are original. Next.js typegen helper availability is version-dependent; confirm locally.

## Quality Tier
A: official React 19 type changes plus the established community cheatsheet; the Next.js `PageProps` helper is lightly verified.

## Status
Active

## Last Verified
2026-09-15
