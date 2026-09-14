# React Context Patterns

## Summary
Context passes values through the tree without prop drilling. It's React's dependency-injection mechanism, not a state manager. This skill covers React 19 idioms (`<Context value>` as provider, `use(Context)`), typed context with a throwing hook, splitting contexts by update frequency, context + reducer, scoped compound-component context, and Next.js App Router provider placement (including React 19.3's direct Context rendering from Server Components).

## Category
React

## Subcategories
createContext, use(Context), provider placement, context splitting, context + useReducer, compound component context, dependency injection, Next.js providers

## Problem It Solves
Prop drilling through many layers. It also avoids the opposite mistake: one giant context that re-renders the whole app on every keystroke, or context used where a URL, query cache or store fits better.

## When To Use
- Low-frequency app-wide values: theme, locale, current user/session DTO, feature flags, design-system config.
- Dependency injection: API clients, analytics, store instances (Zustand/Query clients).
- Implicit state for compound components (Tabs, Accordion, Form field).

## When Not To Use
- High-frequency updates consumed by many components (cursor positions, form keystrokes, live data). Use a selector-based store (Zustand/Jotai) or local state.
- Server data: use the query cache or Server Components.
- To avoid passing props 1–2 levels. Props or composition are clearer.

## Core Principles
1. **Context is transport, not storage.** State still lives in `useState`/`useReducer`/stores.
2. **Every consumer re-renders when the provided value changes (by `Object.is`).** There's no built-in selector.
3. **Keep values stable**: memoize objects (or rely on the React Compiler) and split state from dispatch.
4. **Scope providers as low as possible.** Wrap only the subtree that needs them.
5. **Default to `null` plus a throwing hook** so a missing provider fails fast with a clear message.

## Best Practices
- React 19: render `<ThemeContext value={theme}>` directly. `<Context.Provider>` still works but is slated for deprecation.
- Read with `use(ThemeContext)`, which can be called conditionally or after early returns. `useContext` is still fine.
- Split contexts: `StateContext` and `DispatchContext` (dispatch is stable), or by domain and frequency.
- Expose a custom hook (`useTheme()`) and don't export the raw context unless consumers need it.
- Pass the store *instance* through context, not its state, for stores that support subscriptions (Zustand, Jotai store, QueryClient). Consumers subscribe with selectors.
- Name contexts for DevTools: `ThemeContext.displayName = "ThemeContext"` (optional; named variables usually suffice).

## Implementation Guidance
**Context or something else?**

| Value | Changes | Consumers | Use |
|---|---|---|---|
| Theme, locale, direction | Rarely | Many | Context |
| Auth session (user DTO) | Rarely | Many | Context (seeded from server) |
| Feature flags | Rarely | Many | Context |
| Modal/toast manager API | Stable functions | Many | Context (dispatch only) |
| Form field registration | Per interaction | Few (within a form) | Scoped context |
| Filters, pagination | Per interaction | Several | URL state (nuqs) |
| Cart, selection in huge list | Frequently | Many | Zustand/Jotai |
| API data | Async | Many | TanStack Query / RSC |

**Typed context with throwing hook**
```tsx
"use client";
import { createContext, use, useMemo, useState } from "react";

type Theme = "light" | "dark";
type ThemeCtx = { theme: Theme; setTheme: (t: Theme) => void };
const ThemeContext = createContext<ThemeCtx | null>(null);

export function ThemeProvider({ initial, children }: { initial: Theme; children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>(initial);
  const value = useMemo(() => ({ theme, setTheme }), [theme]); // omit useMemo if React Compiler is on
  return <ThemeContext value={value}>{children}</ThemeContext>;
}

export function useTheme() {
  const ctx = use(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within <ThemeProvider>");
  return ctx;
}
```

**State/dispatch split with reducer**
```tsx
const TasksState = createContext<Task[] | null>(null);
const TasksDispatch = createContext<React.Dispatch<TaskAction> | null>(null);

export function TasksProvider({ children }: { children: React.ReactNode }) {
  const [tasks, dispatch] = useReducer(tasksReducer, []);
  return (
    <TasksDispatch value={dispatch}>
      <TasksState value={tasks}>{children}</TasksState>
    </TasksDispatch>
  );
}
// Components that only dispatch (AddTask button) don't re-render when tasks change.
```

## Recommended Workflow
1. Confirm the value is low-frequency or DI-style (table above).
2. Create the context with `null` default and a typed throwing hook.
3. Place the provider at the lowest common ancestor.
4. Make the value stable (memo or compiler). Split if some consumers only need part of it.
5. Verify re-render scope in React DevTools Profiler.
6. Test consumers by rendering with the real provider (or a test provider with fixture values).

## Patterns
- **Provider composition component**: a single `AppProviders` client component nesting Theme, Query, Toast providers.
- **Scoped compound context**: see react-component-composition (Tabs).
- **Context of a store instance**: `createStore` per provider plus a `useStore(store, selector)` hook, which gives selector-based subscriptions.
- **Nested override**: inner `<LocaleContext value="fr">` overrides for a subtree (preview panes, embedded widgets).
- **Seed from server**: a Server Component reads the session and passes a DTO to the client provider as `initial`.

## Anti-Patterns
- **One `AppContext` with everything**: every change re-renders every consumer. Fix: split by domain and frequency.
- **New object literal every render** (`value={{ user, setUser }}`) without compiler or memo: all consumers re-render on every provider render. Fix: `useMemo`, or enable the compiler.
- **Context for rapidly changing state**: typing lag. Fix: local state or a selector store.
- **Default value that silently works** (`createContext({ theme: "light", setTheme: () => {} })`): missing provider bugs go unnoticed. Fix: `null` + throw.
- **Legacy context API** (`contextTypes`, `childContextTypes`, `getChildContext`): removed in React 19. Fix: `createContext`.
- **Provider at the root of a Next.js layout wrapping everything with `"use client"` logic inside the layout itself**: turns the layout into a client module. Fix: a separate `providers.tsx` client component that receives `children`.

## Accessibility
- Locale and direction contexts must also set `lang` and `dir` on `<html>` (Next.js root layout), not just provide strings (WCAG 3.1.1).
- Theme context must respect `prefers-color-scheme` and `prefers-reduced-motion` as defaults. Persist user overrides.
- Announcement or toast managers exposed through context should render one shared live region.

## Responsive Design
- Don't provide viewport size through context from resize listeners (global re-render storm). Use CSS, or a `useSyncExternalStore` media-query hook that consumers call directly.

## Performance
- Context consumers can't bail out partially. Split contexts, or pass a store instance and subscribe with selectors.
- The React Compiler memoizes provider values automatically in compiled components, but still can't prevent consumer re-renders when the value really changes.
- Components between provider and consumer don't re-render because of context. Only consumers do (plus normal parent re-renders).

## Security
- Session context should contain only a public DTO (id, name, roles for UI), never tokens.
- Don't use client-side role context as authorization. Always enforce on the server.

## Testing
- Create a `renderWithProviders(ui, { theme, user })` helper using the real providers.
- Test that hooks throw a helpful error outside the provider.
- Avoid mocking `useContext`. Provide real values.

## Tooling
- React DevTools (inspect context values per component).
- `use-context-selector` (community): selector-based context. It's niche, and a store library is usually a better fit.
- Deprecated/removed: legacy string-based context (`contextTypes`), removed in React 19.

## Framework Notes
### React (Vite SPA)
- Place providers in `main.tsx`/`App.tsx`. A theme can be read synchronously from `localStorage` in the initializer (no SSR mismatch concern).

### Next.js App Router
- **Server Components can't consume context** (`use(Context)`/`useContext` are client-only). Pass data as props to Server Components.
- Create `app/providers.tsx` with `"use client"` that renders providers around `{children}`, and use it in `app/layout.tsx`. `children` passed from the Server Component layout stay Server Components.
- **React 19.3**: a Server Component can render a client-module Context directly, `<UserContext value={userDTO}>{children}</UserContext>`, without a wrapper provider component. The value must be serializable.
- Seed providers with server data (session DTO, locale, flags) to avoid hydration mismatch and loading flashes.
- Theme: avoid a flash of incorrect theme by setting a class on `<html>` via cookie on the server, or an inline blocking script (e.g. `next-themes`), plus `suppressHydrationWarning` on `<html>` only.
- Per-request instances: create QueryClient or Zustand stores inside the client provider (`useState(() => createStore())`), never at module scope on the server.

## AI Agent Guidance
- Before creating context, check the decision table. Prefer composition for 1–2 levels, and stores for high-frequency values.
- Always `createContext<T | null>(null)` + throwing hook. Use React 19 `<Context value>` syntax when `react >= 19`.
- In Next.js, keep providers in a dedicated client file. Don't add `"use client"` to `layout.tsx`.
- Verify: Profiler shows only intended consumers re-rendering, no hydration warnings (theme), and hooks throw outside providers.

## Examples
```tsx
// app/providers.tsx
"use client";
import { QueryClientProvider } from "@tanstack/react-query";
import { getQueryClient } from "./get-query-client";
import { ThemeProvider } from "@/components/theme";
export function Providers({ theme, children }: { theme: "light" | "dark"; children: React.ReactNode }) {
  return (
    <QueryClientProvider client={getQueryClient()}>
      <ThemeProvider initial={theme}>{children}</ThemeProvider>
    </QueryClientProvider>
  );
}

// app/layout.tsx (Server Component)
import { cookies } from "next/headers";
import { Providers } from "./providers";
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const theme = (await cookies()).get("theme")?.value === "dark" ? "dark" : "light";
  return (
    <html lang="en" className={theme}>
      <body><Providers theme={theme}>{children}</Providers></body>
    </html>
  );
}
```

## Related Skills
- [react-state-management](../react-state-management/Skill.md): when to use a store instead
- [react-component-composition](../react-component-composition/Skill.md): composition before context; compound components
- [react-server-components](../react-server-components/Skill.md): RSC/context boundary
- [dark-mode-implementation](../dark-mode-implementation/Skill.md): theme context without flashes
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md): locale providers
- [feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md): flag providers

## Sources
- [react.dev: Passing Data Deeply with Context](https://react.dev/learn/passing-data-deeply-with-context) (Official): use cases, alternatives
- [react.dev: Scaling Up with Reducer and Context](https://react.dev/learn/scaling-up-with-reducer-and-context) (Official): state/dispatch split
- [React 19 release post](https://react.dev/blog/2024/12/05/react-19) (Official): `<Context>` as provider, `use`
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): direct context rendering from Server Components
- [Next.js docs: Server and Client Components (context providers)](https://nextjs.org/docs/app/getting-started/server-and-client-components) (Official): providers.tsx pattern
- [Kent C. Dodds: How to use React Context effectively](https://kentcdodds.com/blog/how-to-use-react-context-effectively) (Community): throwing custom hook pattern

## License / Usage Notes
React/Next.js docs are MIT/CC-BY-4.0. Community article summarized. Code is original.

## Quality Tier
A: official and current (React 19.3); the performance guidance relies on well-established community consensus.

## Status
Active

## Last Verified
2026-09-15
