# Component API Design

## Summary
How to design the public interface of reusable React (TypeScript) components: props naming, variants, composition (children, slot props, compound components, render delegation via `asChild`/`render`), controlled vs uncontrolled state, ref and attribute forwarding, typing, and Server/Client Component boundaries in Next.js. Applies to design-system components and shared app components.

## Category
Architecture

## Subcategories
Props design, compound components, slots, polymorphism, controlled/uncontrolled, variants, TypeScript typing, deprecation

## Problem It Solves
Poorly designed component APIs grow boolean-prop explosions (`isPrimary isLarge hasIcon iconRight noPadding`), break accessibility when consumers need a different element, can't be controlled externally, and force breaking changes. A disciplined API stays small, composable, accessible, and evolvable.

## When To Use
- Creating any component used in more than one place, especially in a design system or shared package.
- Reviewing a component whose prop count is growing.
- Wrapping a headless library (Radix, Base UI, React Aria, Ark UI) for your system.

## When Not To Use
- One-off page sections: inline JSX is fine; don't over-generalize.
- When a headless library already provides the behavior — wrap, don't reinvent.

## Core Principles
1. **Mirror the platform.** Accept and forward native attributes (`id`, `aria-*`, `data-*`, `className`, event handlers); name props like HTML (`disabled`, not `isDisabled`, unless your system standardizes otherwise consistently).
2. **Composition over configuration.** Prefer `children`/slots and compound parts over props like `headerText`, `footerButtons`.
3. **Enums over booleans for mutually exclusive options.** `variant="primary" | "secondary"`, `size="sm" | "md"`.
4. **Support controlled and uncontrolled.** `value`/`onValueChange` + `defaultValue`.
5. **Accessible by default.** Correct role/semantics without consumer effort; required labels enforced by types.
6. **Stable, minimal surface.** Every prop is a maintenance promise; add later, remove rarely.
7. **Consistent naming across the system.** Same concept, same prop name everywhere (`open`/`onOpenChange`, `size`, `variant`, `tone`).

## Best Practices
- Event callback naming: `on<Noun><Verb>` or `on<Value>Change` (`onOpenChange(open)`, `onValueChange(value)`) passing the new value, not a synthetic event, for state changes; keep native `onClick` etc. for DOM events.
- Forward refs to the underlying DOM element. React 19: `ref` is a regular prop for function components (no `forwardRef` needed); `forwardRef` still works but is slated for eventual deprecation.
- Spread remaining props onto the root element (`...rest`) and merge `className`/`style`, not replace.
- Provide render delegation for polymorphism: Radix-style `asChild` (Slot) or Base UI-style `render` prop. Avoid generic `as` props with complex TS generics unless your team accepts the typing cost.
- Use compound components (`<Tabs.Root><Tabs.List><Tabs.Trigger/>`) for multi-part widgets; share state via context internally.
- Variants: define with `cva`/`tailwind-variants` (Tailwind) or data attributes + CSS (`data-variant="primary"`), exposing variant types from the same source.
- Expose state as data attributes (`data-state="open"`, `data-disabled`) so consumers can style without extra props.
- Deprecate with a JSDoc `@deprecated` tag + dev-only console warning + codemod; remove in next major.
- Document every prop with JSDoc; generate docs/Storybook args from types.

## Implementation Guidance

### Decision table: extension mechanism
| Need | Mechanism |
|---|---|
| Arbitrary content inside | `children` / default slot |
| Multiple named regions | ReactNode slot props (`icon`, `actions`) or compound parts |
| Change rendered element (link vs button) | `asChild` / `render` prop |
| Visual options from fixed set | `variant`, `size`, `tone` enums |
| Custom rendering of repeated items | Render prop / scoped slot (`renderItem`) |
| Behavior without markup | Headless hook (`useCombobox`) |
| Style override | `className` merge + data attributes + CSS variables |

### Controlled/uncontrolled helper (React)
```tsx
import { useCallback, useState } from 'react';
export function useControllableState<T>({ value, defaultValue, onChange }:
  { value?: T; defaultValue: T; onChange?: (v: T) => void }) {
  const [inner, setInner] = useState(defaultValue);
  const isControlled = value !== undefined;
  const current = isControlled ? value : inner;
  const set = useCallback((next: T) => {
    if (!isControlled) setInner(next);
    onChange?.(next);
  }, [isControlled, onChange]);
  return [current, set] as const;
}
```

### Typed button with variants and render delegation (React 19 + Tailwind)
```tsx
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/shared/lib/cn';

const button = cva('inline-flex items-center gap-2 rounded-md font-medium focus-visible:outline-2 disabled:opacity-50', {
  variants: {
    variant: { primary: 'bg-brand text-on-brand', secondary: 'bg-surface-2', ghost: 'bg-transparent' },
    size: { sm: 'h-8 px-3 text-sm', md: 'h-10 px-4', lg: 'h-12 px-6 text-lg' },
  },
  defaultVariants: { variant: 'primary', size: 'md' },
});

type ButtonProps = React.ComponentPropsWithRef<'button'> &
  VariantProps<typeof button> & { asChild?: boolean };

export function Button({ asChild, variant, size, className, type, ...rest }: ButtonProps) {
  const Comp = asChild ? Slot : 'button';
  return <Comp className={cn(button({ variant, size }), className)}
    {...(!asChild && { type: type ?? 'button' })} {...rest} />;
}
// <Button asChild variant="ghost"><a href="/docs">Docs</a></Button>
```

### Enforce accessible names via types
```ts
type IconButtonProps = Omit<React.ComponentPropsWithRef<'button'>, 'children'> &
  ({ 'aria-label': string } | { 'aria-labelledby': string }) & { icon: React.ReactNode };
```

## Recommended Workflow
1. Write usage examples first (the call sites you want), including edge cases.
2. Check for an existing headless primitive; decide wrap vs build.
3. Define prop types: native passthrough + minimal custom props.
4. Implement with composition; add data-state attributes.
5. Write Storybook stories for each variant/state and interaction tests (keyboard).
6. Review naming against system conventions; document props.
7. Release; track deprecations with codemods.

## Patterns
- **Compound component:** `Dialog.Root/Trigger/Content/Title/Close` with internal context.
- **Slot/asChild:** merge props/handlers onto the single child element.
- **Render prop (`render`):** `render={<a href="/x" />}` or function form receiving props/state.
- **Headless hook + styled wrapper:** `useSwitch()` returns props getters; `Switch` applies styles.
- **Client shell, server content:** client compound root holds state; server-rendered content passed as `children`.
- **Polymorphic via data attributes, not props, for styling state:** `[data-state=checked]`.

## Anti-Patterns
- **Boolean explosion** (`primary`, `secondary`, `danger` all booleans) — impossible states. Fix: single `variant` enum.
- **Content props** (`title`, `subtitle`, `footerActions` arrays) — rigid. Fix: children/slots/compound parts.
- **Swallowing native props** (not spreading `...rest`) — breaks `aria-*`, `data-testid`. Fix: spread and merge.
- **`onChange` passing inconsistent shapes** across components. Fix: `onValueChange(value)` convention.
- **Only controlled** (forces state management for trivial use) or **only uncontrolled** (can't sync). Fix: support both.
- **`as` prop with any tag** — lets consumers render `<Button as="div">`, losing semantics. Fix: `asChild` with docs; restrict allowed elements.
- **Styling via `style` override props per part** (`headerStyle`, `bodyStyle`). Fix: className on parts + CSS variables.
- **Breaking prop renames without deprecation window.** Fix: alias old prop, warn, codemod, remove next major.

## Accessibility
- Component must render correct semantics by default (`<button type="button">`, `role="tablist"` etc. per WAI-ARIA APG).
- Require accessible names for icon-only controls through types (WCAG 4.1.2 Name, Role, Value).
- Keyboard interaction and focus management are part of the API contract (WCAG 2.1.1 Keyboard, 2.4.7 Focus Visible).
- When using `asChild`, document that the child must be interactive-appropriate (don't slot a `<div>` into a Button).

## Responsive Design
- Avoid breakpoint-specific props (`sizeMobile`); prefer container-query-aware styles or responsive variant objects only if your system standardizes them.
- Layout props (`gap`, `direction`) belong on layout primitives (Stack, Grid), not on every component.

## Performance
- Stable callbacks and context value memoization in compound components (or rely on React Compiler).
- Avoid context re-rendering all parts on every state change; split contexts (state vs actions) for large lists.
- Keep variant class computation static (cva) rather than runtime CSS-in-JS for hot components.

## Security
- Never accept raw HTML props (`htmlContent`) — if unavoidable, sanitize internally and name it `dangerouslySetInnerHTML`-style.
- Links rendered via `asChild`/`href` props: validate or restrict `javascript:` URLs.

## Testing
- Test the contract: renders correct role, forwards ref, spreads props, merges className, controlled/uncontrolled behavior, keyboard interactions.
- Type tests (`expectTypeOf`, `tsd`) for required aria props and variant unions.
- Storybook interaction tests + axe checks per story.

## Tooling
- class-variance-authority, tailwind-variants — Active (Tailwind variants).
- `@radix-ui/react-slot` — Active; Base UI `render` prop — Active (Base UI 1.x).
- react-docgen-typescript / Storybook autodocs — Active.
- tsd / Vitest `expectTypeOf` — Active.

## Framework Notes
- **React 19 (Vite SPA and Next.js):** `ref` is a regular prop; type with `ComponentPropsWithRef<'button'>`; `forwardRef` is legacy. With React Compiler enabled, manual `useMemo`/`useCallback` in compound-component context values is usually unnecessary.
- **Next.js Server Components:** props crossing from a Server Component into a `'use client'` component must be serializable — no functions (except Server Actions), class instances, or Symbols. Design APIs so a Server Component can pass `children`/ReactNode slots into a client wrapper (`<Tabs.Root>` client, panel content server-rendered).
- **Next.js `'use client'` placement:** put the directive in the interactive parts (`Dialog.Root`, `Tabs.Trigger`) inside the package; pure display components (Card, Badge) stay server-compatible. Libraries must preserve directives in their build output (check bundler banner/`preserveDirectives` settings).
- **Links:** for polymorphic link buttons in Next.js, use `<Button asChild><Link href="/x">…</Link></Button>` so client navigation and prefetching are kept.
- **Server Action props:** accept `formAction`/`action` passthrough on Button/Form components so Server Actions work without client JS.

## AI Agent Guidance
- Before creating a component, search the design system for an existing one; extend via variants rather than duplicating.
- Do: forward ref and `...rest`, merge `className`, use enums for variants, support controlled + uncontrolled for stateful components.
- Don't: add boolean props for visual options, content-string props for regions, or `as` props without constraints.
- Verify: keyboard behavior matches APG pattern, axe passes in stories, types reject missing accessible names, existing call sites still compile.

## Examples
```tsx
// Compound Tabs API usage
<Tabs.Root defaultValue="account" onValueChange={track}>
  <Tabs.List aria-label="Settings">
    <Tabs.Trigger value="account">Account</Tabs.Trigger>
    <Tabs.Trigger value="billing">Billing</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Panel value="account"><AccountForm /></Tabs.Panel>
  <Tabs.Panel value="billing"><BillingForm /></Tabs.Panel>
</Tabs.Root>
```
```tsx
// Disclosure supporting controlled + uncontrolled, usable from a Server Component parent
'use client';
import { useId } from 'react';
import { useControllableState } from './useControllableState';

type DisclosureProps = {
  trigger: React.ReactNode;          // slot prop (serializable ReactNode from RSC)
  children: React.ReactNode;
  open?: boolean;
  defaultOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
};
export function Disclosure({ trigger, children, open, defaultOpen = false, onOpenChange }: DisclosureProps) {
  const [isOpen, setOpen] = useControllableState({ value: open, defaultValue: defaultOpen, onChange: onOpenChange });
  const id = useId();
  return (
    <div data-state={isOpen ? 'open' : 'closed'}>
      <button type="button" aria-expanded={isOpen} aria-controls={id} onClick={() => setOpen(!isOpen)}>{trigger}</button>
      <div id={id} hidden={!isOpen}>{children}</div>
    </div>
  );
}
// app/faq/page.tsx (Server Component)
// <Disclosure trigger="Shipping">{await getShippingCopy()}</Disclosure>
```

## Related Skills
- [design-system-architecture](../design-system-architecture/Skill.md) — where components live and ship
- [react-component-composition](../react-component-composition/Skill.md) — React composition depth
- [radix-ui-primitives](../radix-ui-primitives/Skill.md) — asChild origin
- [base-ui](../base-ui/Skill.md) — render prop approach
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — interaction contracts
- [typescript-for-frontend](../typescript-for-frontend/Skill.md) — prop typing
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) — documenting APIs

## Sources
- [React docs: ref as a prop (React 19)](https://react.dev/blog/2024/12/05/react-19) — Official — ref prop, forwardRef status
- [Radix Primitives: Composition (asChild)](https://www.radix-ui.com/primitives/docs/guides/composition) — Official — Slot pattern
- [Base UI: Composition (render prop)](https://base-ui.com/react/handbook/composition) — Official — render delegation
- [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/) — Official — keyboard/role contracts
- [Next.js: Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components) — Official — serializable props, 'use client' placement
- [cva](https://cva.style/docs) — Open Source — variant API

## License / Usage Notes
Summarized guidance; code examples are original. Radix, Base UI, cva are MIT.

## Quality Tier
A — grounded in official framework and headless-library docs; API conventions are industry consensus rather than a single spec.

## Status
Active

## Last Verified
2026-09-15
