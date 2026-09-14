# React Refs and Imperative APIs

## Summary
Refs are React's escape hatch for values that must persist without triggering renders, and for imperative access to DOM nodes and third-party widgets. React 19 changed the ergonomics significantly: `ref` is a normal prop on function components (`forwardRef` no longer needed and slated for deprecation), ref callbacks can return cleanup functions, TypeScript requires an argument for `useRef`, and React 19.3 adds **Fragment refs** for groups of children. This skill covers refs, `useImperativeHandle`, focus/scroll/measure patterns, and integration with non-React libraries.

## Category
React

## Subcategories
useRef, ref as prop, forwardRef migration, ref callbacks with cleanup, useImperativeHandle, Fragment refs, flushSync, DOM measurement, third-party widget integration

## Problem It Solves
- Accessing DOM APIs (focus, scroll, measure, media playback).
- Integrating imperative libraries (maps, charts, editors).
- Storing mutable values like timers and previous values without re-rendering.
- Avoiding legacy `forwardRef` boilerplate and leaked observers.

## When To Use
- Focus management, scrolling into view, text selection.
- Measuring layout (tooltip positioning, virtualization).
- Holding interval ids, AbortControllers, latest values for non-render logic.
- Wrapping imperative widgets (Mapbox, CodeMirror, Chart.js).
- Exposing a narrow imperative API from a component (`open()`, `focus()`, `scrollToIndex()`).

## When Not To Use
- Anything that affects rendered output. That's state.
- Reading or writing `ref.current` during render (breaks purity; the compiler lint flags it).
- Controlling child components imperatively when props or state would do (`<Modal open={open} />` beats `modalRef.current.open()`).

## Core Principles
1. **Refs don't trigger renders**, and mutations are invisible to React.
2. **Don't read or write refs during render** (except lazy initialization: `if (ref.current === null) ref.current = create()`).
3. **Declarative first, imperative last.** Expose imperative handles only for inherently imperative actions (focus, scroll, play).
4. **In React 19, `ref` is a prop.** Accept it like any other prop and pass it down.
5. **Clean up what you attach**: observers, listeners and widget instances, via ref callback cleanup or effect cleanup.

## Best Practices
- Type DOM refs as `useRef<HTMLInputElement>(null)`, which gives `RefObject<HTMLInputElement | null>` in React 19 types.
- Prefer ref callbacks with cleanup (React 19) for per-node setup: `ref={(node) => { const ro = new ResizeObserver(...); ro.observe(node); return () => ro.disconnect(); }}`.
- Don't implicitly return from ref callbacks (`ref={n => (x = n)}`). React 19 types reject non-function returns because returned functions are treated as cleanup.
- Use `useImperativeHandle(ref, () => ({ focus, scrollToTop }), [])` to expose a minimal API instead of the raw DOM node when you need encapsulation.
- Use `flushSync` sparingly when you must read the DOM right after a state update (scroll to a newly added item).
- For a group of children without a wrapper element, use `<Fragment ref>` (React 19.3) with `focus()`, `observeUsing()` and `addEventListener()` on the FragmentInstance.
- Merge refs when a component needs its own ref plus the consumer's: a small `mergeRefs` helper, or compose callbacks.

## Implementation Guidance
**Ref vs state**

| Value | Affects UI? | Use |
|---|---|---|
| Input text shown on screen | Yes | State |
| Timer/interval id | No | Ref |
| Latest callback for a subscription | No | `useEffectEvent` (preferred) or ref |
| DOM node | No (imperative access) | Ref |
| Previous value for comparison in effects | No | Ref |
| "Has user interacted" flag for rendering | Yes | State |

**Ref as prop (React 19)**
```tsx
type TextFieldProps = React.ComponentProps<"input"> & { label: string };
export function TextField({ label, id, ref, ...props }: TextFieldProps) {
  const autoId = useId();
  const inputId = id ?? autoId;
  return (<><label htmlFor={inputId}>{label}</label><input id={inputId} ref={ref} {...props} /></>);
}
// consumer
const emailRef = useRef<HTMLInputElement>(null);
<TextField label="Email" ref={emailRef} />;
```

**forwardRef migration**
```tsx
// Before (React ≤18)
const TextField = forwardRef<HTMLInputElement, Props>((props, ref) => <input ref={ref} {...props} />);
// After (React 19+): plain function, ref in props
function TextField({ ref, ...props }: Props & { ref?: React.Ref<HTMLInputElement> }) { return <input ref={ref} {...props} />; }
```
The official codemod is `npx codemod@latest react/19/remove-forward-ref` (review the output). Libraries supporting React 18 must keep `forwardRef` until they drop 18.

**useImperativeHandle**
```tsx
export type VideoHandle = { play: () => void; pause: () => void };
export function Video({ src, ref }: { src: string; ref?: React.Ref<VideoHandle> }) {
  const el = useRef<HTMLVideoElement>(null);
  useImperativeHandle(ref, () => ({
    play: () => void el.current?.play(),
    pause: () => el.current?.pause(),
  }), []);
  return <video ref={el} src={src} controls />;
}
```

**Scroll to newly added item**
```tsx
import { flushSync } from "react-dom";
function addMessage(msg: Msg) {
  flushSync(() => setMessages((m) => [...m, msg]));
  listRef.current?.lastElementChild?.scrollIntoView({ block: "end" });
}
```

**Third-party widget**
```tsx
"use client";
export function MapView({ center }: { center: [number, number] }) {
  const mapRef = useRef<MapLib.Map | null>(null);
  const containerRef = useCallback((node: HTMLDivElement | null) => {
    if (!node) return;
    const map = new MapLib.Map({ container: node, center });
    mapRef.current = map;
    return () => { map.remove(); mapRef.current = null; };  // React 19 ref cleanup
  }, []); // create once
  useEffect(() => { mapRef.current?.setCenter(center); }, [center]); // sync props
  return <div ref={containerRef} style={{ height: 400 }} />;
}
```

## Recommended Workflow
1. Try a declarative solution (props, state, key) first.
2. If imperative access is needed, pick `useRef` (a stable node) or a ref callback (setup and teardown per node).
3. Put reads and writes in effects or handlers, never in render.
4. Expose a minimal typed handle if parents need commands.
5. Add cleanup and verify under Strict Mode (double mount).
6. Test focus and scroll behaviour with Testing Library or Playwright.

## Patterns
- **Focus on open**: `useEffect(() => { if (open) inputRef.current?.focus(); }, [open])`, or `autoFocus` inside dialogs managed by a11y primitives.
- **Measure before paint**: `useLayoutEffect(() => setRect(ref.current!.getBoundingClientRect()), [])`.
- **Lazy ref init**: `const worker = useRef<Worker | null>(null); if (worker.current === null) worker.current = new Worker(url)`. Avoid this during SSR (guard with an effect in Next.js).
- **Fragment group observer (19.3)**: `<Fragment ref={fragRef}>{children}</Fragment>` with `fragRef.current.observeUsing(intersectionObserver)`.
- **mergeRefs**:
```ts
export function mergeRefs<T>(...refs: (React.Ref<T> | undefined)[]): React.RefCallback<T> {
  return (node) => {
    const cleanups: Array<() => void> = [];
    for (const ref of refs) {
      if (typeof ref === "function") {
        const cleanup = ref(node);
        cleanups.push(typeof cleanup === "function" ? cleanup : () => ref(null));
      } else if (ref) {
        ref.current = node;
        cleanups.push(() => { ref.current = null; });
      }
    }
    return () => cleanups.forEach((c) => c());
  };
}
```

## Anti-Patterns
- **`forwardRef` in new React 19 code**: needless and slated for deprecation. Fix: ref as prop.
- **String refs (`ref="input"`) and `findDOMNode`**: removed in React 19. Fix: `useRef` or ref callbacks.
- **Reading `ref.current` in JSX** (`{ref.current?.value}`): stale UI. Fix: state.
- **Imperative show/hide APIs for modals** (`modalRef.current.open()`): state gets out of sync. Fix: a controlled `open` prop.
- **Inline ref callbacks without cleanup that create observers**: leaks, and re-runs every render. Fix: `useCallback` + returned cleanup.
- **Implicit return in ref callbacks**: TS error in React 19 and accidental cleanup semantics. Fix: block body.
- **`useRef()` without an argument**: React 19 types require one. Fix: `useRef<T>(null)` or `useRef<T | undefined>(undefined)`.

## Accessibility
- Programmatic focus must follow a logical order and not surprise users (WCAG 2.4.3). Move focus on user intent (dialog open, validation error), not on arbitrary renders.
- Restore focus to the trigger when closing overlays.
- `scrollIntoView` should respect reduced motion (`behavior: prefersReduced ? "auto" : "smooth"`).
- Fragment refs' `focus()` focuses the first focusable descendant, which is handy for focusing a group without wrapper divs (preserves semantics).

## Responsive Design
- Use `ResizeObserver` via ref callbacks for element-size-driven layouts instead of window resize handlers.
- Re-measure on container changes, not only on mount.

## Performance
- Store high-frequency values (pointer position, scroll offset) in refs and write to the DOM or CSS variables directly when React doesn't need to re-render.
- Avoid `flushSync` in loops. It forces synchronous renders.
- `useLayoutEffect` measurements block paint. Keep them cheap.

## Security
- Imperative `innerHTML` writes through refs bypass React escaping. Sanitize and prefer Trusted Types (React 19.3 passes TrustedHTML through without string coercion).
- Clean up `postMessage` listeners attached to iframes via refs, and validate origins.

## Testing
- Testing Library: assert `expect(screen.getByLabelText("Email")).toHaveFocus()` after interactions.
- Test imperative handles by rendering a parent with a ref and calling methods inside `act`.
- jsdom has no layout. Measurement logic needs Playwright/browser-mode tests (Vitest browser mode).

## Tooling
- `@types/react` 19.x (ref-as-prop typings, `useRef` argument required).
- Codemods: `react/19/remove-forward-ref`, `types-react-codemod` for ref typing changes.
- `@floating-ui/react` handles ref merging and measurement for overlays.

## Framework Notes
### React (Vite SPA)
- DOM refs are available after commit, and there's no SSR consideration. Browser APIs in ref callbacks are safe.

### Next.js App Router
- Refs, `useImperativeHandle` and ref callbacks work only in Client Components. Server Components can't pass refs: a ref is not serializable, and function props can't cross the boundary.
- Client Components also render on the server, where refs stay `null` and ref callbacks and effects don't run. Never touch `window`/DOM in render. Do it in ref callbacks or effects.
- Heavy imperative widgets (maps, editors): load with `next/dynamic(() => import("./MapView"), { ssr: false })` **from a Client Component**, or gate with `use(browser())` (React 19.3) inside Suspense.
- Focus management after App Router navigation: route changes don't move focus automatically for custom layouts. Use a ref on the main heading and focus it in an effect keyed on `usePathname()`.

## AI Agent Guidance
- Check the React version. For ≥19, never generate `forwardRef` or `useRef()` without an argument. For libraries supporting 18, keep `forwardRef`.
- Prefer props or state over imperative handles. Justify each `useImperativeHandle`.
- Always return cleanup from ref callbacks that attach observers or instances.
- Verify: no ref reads in render (lint clean), Strict Mode double-mount doesn't duplicate widgets, and focus behaviour works with keyboard only.

## Examples
```tsx
// React 19.3 Fragment ref: focus first item of a group without wrapper
import { Fragment, useEffect, useRef } from "react";
export function ResultsGroup({ items, focusOnMount }: { items: Result[]; focusOnMount: boolean }) {
  const groupRef = useRef<FragmentInstance>(null); // type name per @types/react 19.3; verify
  useEffect(() => { if (focusOnMount) groupRef.current?.focus(); }, [focusOnMount]);
  return (
    <Fragment ref={groupRef}>
      {items.map((r) => <a key={r.id} href={r.href}>{r.title}</a>)}
    </Fragment>
  );
}
```

## Related Skills
- [focus-management](../focus-management/Skill.md): focus rules for overlays and routing
- [react-hooks-patterns](../react-hooks-patterns/Skill.md): useEffectEvent vs latest-ref pattern
- [react-typescript-patterns](../react-typescript-patterns/Skill.md): ref typings
- [browser-apis-in-react](../browser-apis-in-react/Skill.md): observers and browser APIs
- [floating-element-positioning](../floating-element-positioning/Skill.md): measurement with refs
- [react-19-migration-guide](../react-19-migration-guide/Skill.md): forwardRef and string ref removal

## Sources
- [react.dev: Referencing Values with Refs / Manipulating the DOM with Refs](https://react.dev/learn/manipulating-the-dom-with-refs) (Official): rules, flushSync
- [react.dev: useImperativeHandle](https://react.dev/reference/react/useImperativeHandle) (Official): handle API with ref prop
- [React 19 release post & upgrade guide](https://react.dev/blog/2024/04/25/react-19-upgrade-guide) (Official): ref as prop, ref cleanup, useRef argument, removed string refs/findDOMNode
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): Fragment refs and FragmentInstance methods
- [Next.js docs: Lazy Loading (next/dynamic ssr:false)](https://nextjs.org/docs/app/guides/lazy-loading) (Official): client-only widgets

## License / Usage Notes
React/Next.js docs are MIT/CC-BY-4.0. Code is original. The `FragmentInstance` type name should be verified against the installed `@types/react`.

## Quality Tier
A: official and current through 19.3; Fragment ref TypeScript type naming is not yet verified.

## Status
Active

## Last Verified
2026-09-15
