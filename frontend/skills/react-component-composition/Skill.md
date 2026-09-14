# React Component Composition

## Summary
Composition is React's main way to reuse code and shape component APIs. You build UIs by nesting components through `children`, slot props, compound components and render delegation, instead of piling boolean props onto one big component. Done well, you get small components that are easy to change and that stay fast without memoization, because state stays low in the tree and the rest of the tree gets passed in as elements.

## Category
React

## Subcategories
children and slots, compound components, render props, polymorphic components (asChild), headless components, lifting content up, container/presentational split

## Problem It Solves
- "Prop explosion": components with 20+ props like `showHeader`, `headerVariant` and `hideFooterOnMobile`.
- Prop drilling through layers that don't use the data.
- Re-render cascades when stateful parents wrap large static subtrees.
- Components that can't be extended without forking them.

## When To Use
- Designing reusable UI (cards, dialogs, tabs, menus, layouts, tables).
- A component starts collecting mode flags (`isCompact`, `variant="with-icon-left"`).
- Props are drilled 2+ levels only to reach a leaf.
- A stateful wrapper (hover, scroll, open state) wraps expensive content.

## When Not To Use
- Leaf components with one clear job (`<Avatar src size />`). Plain props are simpler.
- Don't reach for compound components when a data-driven API (`items={[...]}`) is clearer, e.g. for 1,000-row menus built from data.
- Don't use render props when a custom hook does the same job without the extra JSX nesting.

## Core Principles
1. **Pass elements, not configuration.** `children` and slot props (`header`, `actions`) beat `headerTitle` + `headerIcon` + `headerVariant`.
2. **Keep state where it's used, and pass the rest down as elements.** Elements created by a parent don't re-render when a child's state changes.
3. **One component, one reason to change.** Split by behaviour (state, a11y) and by presentation.
4. **Explicit variants over boolean combinations.** Use a `variant` union, or separate components, instead of booleans that combine.
5. **Share implicit state through context scoped to the compound parent**, never through global stores.
6. **Composition before inheritance.** Never extend React components. Class components are legacy.

## Best Practices
- Type `children` as `React.ReactNode`. Type slot props as `React.ReactNode` too, unless you need to call them.
- Spread the remaining native props (`...props`) onto the root DOM element and merge `className` and handlers instead of replacing them.
- Compound components: expose them as `Tabs.Root`/`Tabs.List`, or named exports (`TabsList`), which tree-shake better and work in RSC. Throw a clear error when a child is used outside its parent.
- In React 19, `ref` is a regular prop on function components. Don't write new `forwardRef` wrappers.
- Prefer `asChild` (Radix Slot pattern) or a `render` prop (Base UI pattern) over an `as` prop when you need polymorphism with correct typing.
- Avoid `React.Children.map`/`cloneElement`. They break with fragments, wrappers and Server Components. Use context instead.
- Never define a component inside another component's body. It remounts on every render and loses state.

## Implementation Guidance
**Choose the composition technique:**

| Need | Technique |
|---|---|
| Arbitrary inner content | `children` |
| Multiple distinct regions | Named slot props (`header`, `footer`, `actions`) |
| Parts that share implicit state (Tabs, Accordion, Select) | Compound components + scoped context |
| Consumer controls the rendered element | `asChild`/Slot or a `render` prop |
| Share only logic | Custom hook (headless) |
| Parent decides how items render, based on child data | Render function prop (`renderItem`) |
| Avoid re-rendering a static subtree on local state | Lift the content up as `children` |

**Steps:**
1. List the regions and behaviours of the component.
2. Put the behaviour in a hook or context provider, and the regions in slot or sub-components.
3. Define variants as string unions and document the defaults.
4. Forward `ref`, `className` and the rest of the props to the root element.
5. Add a throwing context hook so misuse fails loudly.

## Recommended Workflow
1. Write the ideal consumer JSX first, before any implementation.
2. Identify state owners, and what is static versus interactive.
3. Implement the headless logic (hook), then the styled parts.
4. Add TypeScript types for slots and variants, then check that misuse fails type-checking.
5. Test through the public API with Testing Library (roles, not internals).
6. Document examples in Storybook.

## Patterns
**Slot props**
```tsx
type CardProps = { title: React.ReactNode; actions?: React.ReactNode; children: React.ReactNode };
export function Card({ title, actions, children }: CardProps) {
  return (
    <section className="card">
      <header className="card-header"><h2>{title}</h2>{actions}</header>
      <div className="card-body">{children}</div>
    </section>
  );
}
```

**Compound components with scoped context (React 19)**
```tsx
import { createContext, use, useId, useState } from "react";

type TabsCtx = { value: string; setValue: (v: string) => void; baseId: string };
const TabsContext = createContext<TabsCtx | null>(null);
function useTabs() {
  const ctx = use(TabsContext);
  if (!ctx) throw new Error("Tabs.* must be rendered inside <Tabs.Root>");
  return ctx;
}

function Root({ defaultValue, children }: { defaultValue: string; children: React.ReactNode }) {
  const [value, setValue] = useState(defaultValue);
  const baseId = useId();
  return <TabsContext value={{ value, setValue, baseId }}>{children}</TabsContext>;
}
function Trigger({ value, children }: { value: string; children: React.ReactNode }) {
  const t = useTabs();
  return (
    <button role="tab" id={`${t.baseId}-t-${value}`} aria-selected={t.value === value}
      aria-controls={`${t.baseId}-p-${value}`} onClick={() => t.setValue(value)}>
      {children}
    </button>
  );
}
function Panel({ value, children }: { value: string; children: React.ReactNode }) {
  const t = useTabs();
  if (t.value !== value) return null;
  return <div role="tabpanel" id={`${t.baseId}-p-${value}`} aria-labelledby={`${t.baseId}-t-${value}`}>{children}</div>;
}
export const Tabs = { Root, Trigger, Panel };
```
(A complete tabs widget also needs a `tablist` wrapper and arrow-key roving focus. See the tabs skill.)

**Lift content up (a free performance win)**
```tsx
// Bad: every scroll update re-renders <ExpensiveTree/>
function Page() { const y = useScrollY(); return <Layout y={y}><ExpensiveTree /></Layout>; }

// Good: the stateful wrapper receives an already-created element
function ScrollShell({ children }: { children: React.ReactNode }) {
  const y = useScrollY();
  return <Layout y={y}>{children}</Layout>;
}
function Page() { return <ScrollShell><ExpensiveTree /></ScrollShell>; }
```

**asChild / Slot**
```tsx
import { Slot } from "radix-ui"; // or @radix-ui/react-slot
type ButtonProps = React.ComponentProps<"button"> & { asChild?: boolean };
export function Button({ asChild, ...props }: ButtonProps) {
  const Comp = asChild ? Slot.Root : "button";
  return <Comp className="btn" {...props} />;
}
// <Button asChild><a href="/pricing">Pricing</a></Button>
```

## Anti-Patterns
- **Boolean prop soup** (`<Modal hasHeader noPadding isFullscreen isDanger />`). Combinations explode. Fix: variants plus slots or sub-components.
- **Defining components inside render.** This remounts the subtree and loses state and focus. Fix: hoist to module scope.
- **`cloneElement` to inject props.** It's fragile and invisible to types. Fix: context or render props.
- **Prop drilling 4+ levels.** Fix: composition first (pass the element), then context.
- **Wrapper `div` soup that breaks semantics** (e.g. a `div` between `ul` and `li`). Fix: accept `asChild`, or render fragments.
- **`forwardRef` in new React 19 code.** It's unnecessary and slated for deprecation. Fix: take `ref` as a prop.

## Accessibility
- Compound widgets must wire ARIA relationships (`aria-controls`, `aria-labelledby`) with `useId`, not with hard-coded ids.
- Make sure `asChild` merges handlers and keeps the focusability and semantics of the child.
- Slots must not produce invalid DOM nesting (interactive inside interactive, `p > div`), which breaks WCAG 4.1.2 name/role/value parsing expectations.
- Prefer headless primitives (Radix, React Aria, Base UI) for complex widgets instead of hand-rolled keyboard logic.

## Responsive Design
- Let layout components accept slots and use CSS (container queries, grid areas) to rearrange regions. Don't render different trees per breakpoint in JS, which causes hydration mismatches.
- If markup really must differ, render both and hide with CSS, or use `useSyncExternalStore` with `matchMedia` on the client only.

## Performance
- Passing children elements keeps re-renders local without `memo`.
- Split large context values so sub-components subscribe only to what they read.
- With the React Compiler enabled, composition still matters. The compiler memoizes inside a component, but can't stop state that sits too high in the tree from invalidating it.

## Security
- Never pass untrusted HTML through slots via `dangerouslySetInnerHTML`. Sanitize first (DOMPurify), and prefer Trusted Types (supported in React 19.3).
- For `href` slots on `asChild` links, validate URL schemes (`javascript:` URLs are blocked by React 19 in `href` but should still be validated server-side).

## Testing
- Test compound components as a unit, the way consumers use them: `getByRole("tab", { name: "Billing" })`.
- Assert that using a sub-component outside its root throws a helpful error.
- Type tests (`expectTypeOf` in Vitest, `@ts-expect-error`) for invalid slot or variant props.

## Tooling
- `radix-ui` (Slot), `@base-ui/react` (`render` prop), `react-aria-components`: active, a11y-tested primitives.
- `class-variance-authority` / `tailwind-variants` for typed variants.
- Storybook for documenting composition examples.

## Framework Notes
### React (Vite SPA)
- Every component is a client component, so no directives are needed. All the patterns above apply as written.
- Route layouts in a SPA router are just composition: a layout component that renders an outlet or `children`.

### Next.js App Router
- Components are Server Components by default. Compound parts that use context, state or event handlers need `"use client"` at the top of their module. Keep that module small, containing only the interactive parts.
- A Server Component can pass Server Components as `children` or slot props into a Client Component (`<ClientTabs panels={<ServerPanel />} />`). This is the main way to keep interactive shells small while the heavy content renders on the server.
- Props passed from a Server Component into a client compound component must be serializable: data and JSX, not functions (Server Functions are the exception).
- Avoid dotted namespaces (`Tabs.Root`) when a Server Component consumes a client compound component. Property access on a client reference isn't reliably supported, so export named parts (`TabsRoot`, `TabsTrigger`) as well.
- Route-level composition: `layout.tsx` keeps its state across navigations, `template.tsx` remounts on every navigation, and parallel-route slots (`@modal`, `@sidebar`) are named slot props provided by the router.
- Hydration: slot content must render identically on server and client, so don't branch on `typeof window` inside slots.

## AI Agent Guidance
- Do: sketch the consumer API first; use slots/compound parts once there are more than about 3 visual boolean props; accept `ref` as a prop; spread rest props; generate ids with `useId`.
- Don't: create `forwardRef` wrappers in React 19 projects; use `cloneElement`; declare components inside components; add `memo` before trying the lift-content-up pattern.
- Verify before done: types reject misuse; keyboard and roles work; no hydration warnings; no component defined in render (eslint `react/no-unstable-nested-components` or the React Compiler lint rules).

## Examples
```tsx
// Consumer API for a dialog built with composition
<Dialog.Root>
  <Dialog.Trigger asChild><Button>Delete project</Button></Dialog.Trigger>
  <Dialog.Content>
    <Dialog.Title>Delete project?</Dialog.Title>
    <Dialog.Description>This cannot be undone.</Dialog.Description>
    <footer>
      <Dialog.Close asChild><Button variant="ghost">Cancel</Button></Dialog.Close>
      <Button variant="danger" onClick={onDelete}>Delete</Button>
    </footer>
  </Dialog.Content>
</Dialog.Root>
```

## Related Skills
- [component-api-design](../component-api-design/Skill.md): API design principles beyond React
- [react-context-patterns](../react-context-patterns/Skill.md): scoped context for compound components
- [react-typescript-patterns](../react-typescript-patterns/Skill.md): typing slots, polymorphic props
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md): ref as prop in React 19
- [radix-ui-primitives](../radix-ui-primitives/Skill.md): Slot/asChild source
- [react-performance-optimization](../react-performance-optimization/Skill.md): lift-content-up for re-renders

## Sources
- [react.dev: Passing Props to a Component / children](https://react.dev/learn/passing-props-to-a-component) (Official): children and composition basics
- [react.dev: Preserving and Resetting State](https://react.dev/learn/preserving-and-resetting-state) (Official): nested component definition pitfall
- [React 19 release post](https://react.dev/blog/2024/12/05/react-19) (Official): ref as prop, `<Context>` as provider
- [Radix UI Slot / composition guide](https://www.radix-ui.com/primitives/docs/guides/composition) (Open Source): asChild pattern
- [Dan Abramov: Before You memo()](https://overreacted.io/before-you-memo/) (Community): lift-content-up technique
- [Kent C. Dodds: Compound Components](https://kentcdodds.com/blog/compound-components-with-react-hooks) (Community): compound pattern

## License / Usage Notes
Summarized guidance from MIT-licensed React docs and Radix, plus community articles. Code samples are original illustrations, not copies.

## Quality Tier
A: grounded in official React 19 docs and well-established community patterns; the compound examples leave out full keyboard handling for brevity.

## Status
Active

## Last Verified
2026-09-15
