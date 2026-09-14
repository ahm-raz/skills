# Web Components in React

## Summary
Using custom elements (Web Components, including Lit-based design systems, Shoelace/Web Awesome, Material Web, vendor widgets) inside React 19 and Next.js: how React 19 assigns properties vs attributes, listens to custom events, renders custom elements during SSR, TypeScript JSX typing, form participation, refs for imperative methods, and when wrappers (`@lit/react`) are still useful.

## Category
React

## Subcategories
Custom elements, React 19 interop, properties vs attributes, custom events, SSR and Declarative Shadow DOM, TypeScript JSX typing, design system interop

## Problem It Solves
Before React 19, React passed everything as string attributes and could not listen to custom events declaratively, forcing ref/effect wrappers. Teams still copy those workarounds, hit SSR errors (`HTMLElement is not defined`), lose rich props during server rendering, fight TypeScript "property does not exist on JSX.IntrinsicElements", and see flashes of unstyled content before element definitions load.

## When To Use
- Consuming a company design system published as Web Components.
- Embedding third-party widgets delivered as custom elements (maps, payments, video players, chat).
- Sharing components across React and non-React apps.

## When Not To Use
- Building new components only for a React app: plain React components are simpler.
- Authoring web components in depth (lifecycle, shadow DOM styling) — out of scope here; this skill is about consumption from React.
- Needing React Server Components to render interactive custom element internals on the server (custom elements upgrade on the client).

## Core Principles
1. React 19 on the client: if the element instance has a property matching the prop name, React sets the property; otherwise it sets an attribute.
2. React 19 on the server: primitive props (string, number, `true`) render as attributes; objects, functions, symbols, and `false` are omitted from HTML and applied after hydration.
3. Custom events are handled with `on` + exact event name (`onchange`, `onvalue-change`, `onsayHi`), case- and dash-sensitive.
4. Custom elements must be defined (`customElements.define`) in the browser; import definitions from client-only code.
5. Type the elements you use in JSX so props and events are checked.
6. Treat the custom element's public API (properties, attributes, events, methods, slots, CSS parts) as a contract; wrap it once in a typed React component.

## Best Practices
- Upgrade to React 19+ before adopting web components in React; remove ref/`addEventListener` wrappers written for React 18.
- Import element definitions in a `'use client'` module (side-effect import) or lazily in `useEffect` to avoid SSR access to `HTMLElement`/`customElements`.
- Prefer properties for complex data (arrays/objects) — ensure the element defines those properties before React sets them (class fields or reactive properties), or use a ref.
- For SSR-visible content, pass primitives as attributes and put text content in light DOM children or slots so HTML is meaningful before upgrade.
- Hide or reserve space for undefined elements to prevent layout shift: `my-button:not(:defined) { visibility: hidden; }` plus explicit dimensions, or render a skeleton.
- Use `ref` to call imperative methods (`show()`, `focus()`, `reset()`), with React 19 ref cleanup when attaching extra listeners.
- Use `className` in JSX (React renders `class`); use `slot="name"` attributes for named slots.
- Use form-associated custom elements (ElementInternals) with a `name` attribute so they participate in `FormData` and Server Actions.
- Wrap each custom element in a thin typed React component in your design-system adapter layer; apps import the wrapper, not the tag.
- For Lit-based libraries with SSR needs, evaluate Declarative Shadow DOM support (Lit SSR is labs-status; verify integration with your Next.js version before relying on it).
- Load third-party element scripts with `next/script` (`strategy="afterInteractive"` or `lazyOnload`) when they are not npm packages.

## Implementation Guidance

### React version behavior
| Concern | React 18 and earlier | React 19+ |
|---|---|---|
| Non-string props | Stringified as attributes (`[object Object]`) | Set as properties when the instance defines them |
| Custom events | Needed `ref` + `addEventListener` | `on<eventname>` props |
| SSR | Attributes only | Primitives as attributes; non-primitives omitted then set on hydration |
| `className` | Worked as `class` attribute | Works |
| Wrapper libraries (`@lit/react`) | Required for good DX | Optional (typing, event-name mapping, React 18 support) |

### Decision table: property or attribute?
| Data | Pass as | Notes |
|---|---|---|
| Short string/number/boolean config (`variant`, `size`, `disabled`) | Prop (becomes attribute on SSR, property/attribute on client) | Visible in SSR HTML |
| Arrays/objects (`options`, `items`, `config`) | Prop (property on client) | Not in SSR HTML; element must handle "not yet set" |
| Functions/callbacks the element calls | Prop (property) | Prefer events instead of callback props |
| Boolean false | Omit or `false` | `false` omitted on server; check element default |
| Content | Children / `slot` | Best for SSR and accessibility |

### TypeScript JSX typing (React 19 types)
```ts
// src/types/custom-elements.d.ts
import type { DetailedHTMLProps, HTMLAttributes } from 'react'

type RatingChangeEvent = CustomEvent<{ value: number }>

type CE<T, P = {}> = DetailedHTMLProps<HTMLAttributes<T>, T> & P

declare module 'react' {
  namespace JSX {
    interface IntrinsicElements {
      'ds-rating': CE<HTMLElement & { value: number; max: number }, {
        value?: number
        max?: number
        readonly?: boolean
        name?: string
        'onrating-change'?: (event: RatingChangeEvent) => void
      }>
      'ds-dialog': CE<HTMLElement & { show(): void; hide(): void }, {
        open?: boolean
        label?: string
        onclose?: (event: Event) => void
      }>
    }
  }
}
```
Many libraries publish a Custom Elements Manifest (`custom-elements.json`); generators can produce these JSX types automatically.

### Client-only definition loading (Next.js)
```tsx
// src/components/ds/define.ts
'use client'
// Side-effect import registers <ds-rating>, <ds-dialog> in the browser only.
// If the library touches `window` at import time, use the lazy variant below instead.
import '@acme/design-system/rating.js'
import '@acme/design-system/dialog.js'
```

```tsx
// Lazy variant for libraries that break on server import
'use client'
import { useEffect } from 'react'

export function DefineDesignSystem() {
  useEffect(() => {
    void import('@acme/design-system/rating.js')
    void import('@acme/design-system/dialog.js')
  }, [])
  return null
}
```

### Typed React wrapper
```tsx
// src/components/ds/rating.tsx
'use client'
import './define'

type RatingProps = {
  value: number
  max?: number
  name?: string
  readOnly?: boolean
  onValueChange?: (value: number) => void
  label: string
}

export function Rating({ value, max = 5, name, readOnly, onValueChange, label }: RatingProps) {
  return (
    <ds-rating
      value={value}
      max={max}
      name={name}
      readonly={readOnly || undefined}
      aria-label={label}
      onrating-change={e => onValueChange?.(e.detail.value)}
    />
  )
}
```

### Imperative methods via ref
```tsx
'use client'
import { useRef } from 'react'
import './define'

export function ConfirmDelete({ onConfirm }: { onConfirm: () => void }) {
  const dialogRef = useRef<HTMLElement & { show(): void; hide(): void }>(null)
  return (
    <>
      <button type="button" onClick={() => dialogRef.current?.show()}>Delete…</button>
      <ds-dialog ref={dialogRef} label="Delete project" onclose={() => dialogRef.current?.hide()}>
        <p>This cannot be undone.</p>
        <button slot="footer" type="button" onClick={() => { onConfirm(); dialogRef.current?.hide() }}>Delete</button>
      </ds-dialog>
    </>
  )
}
```

### Rich data property
```tsx
'use client'
import './define'

type Option = { value: string; label: string }

export function CountrySelect({ options, value, onChange }: { options: Option[]; value: string; onChange: (v: string) => void }) {
  // React 19 sets `options` as a property (not "[object Object]") if <ds-select> defines it
  return <ds-select name="country" value={value} options={options} onchange={(e: Event) => onChange((e.target as HTMLInputElement).value)} />
}
```
If the element defines `options` lazily (after upgrade), React may set an attribute on first client render before definition; mitigate by ensuring definitions load before rendering the component (e.g., render after `customElements.whenDefined('ds-select')`) or setting the property via ref.

### Waiting for definition to avoid FOUC and property races
```tsx
'use client'
import { useEffect, useState } from 'react'

export function useDefined(tag: string) {
  const [defined, setDefined] = useState(false)
  useEffect(() => {
    let active = true
    customElements.whenDefined(tag).then(() => { if (active) setDefined(true) })
    return () => { active = false }
  }, [tag])
  return defined
}
```

## Recommended Workflow
1. Confirm React 19+ and inventory the elements' APIs (Custom Elements Manifest, docs): properties, attributes, events, methods, slots, CSS parts, form association.
2. Add JSX type declarations (generated if possible).
3. Create a client-only definitions module; decide eager vs lazy loading.
4. Build thin typed React wrappers mapping React-style props (`onValueChange`, `readOnly`) to element API.
5. Handle SSR: meaningful light-DOM content, `:not(:defined)` styles, reserved dimensions.
6. Verify accessibility of the element (labels, keyboard, focus across shadow roots).
7. Test in `next build && next start`: hydration warnings, property assignment, events, forms.

## Patterns
- **Adapter layer**: `src/components/ds/*` wrappers; ESLint-ban raw `ds-*` tags elsewhere.
- **Event name mapping**: wrapper converts `onrating-change` to `onValueChange` with typed payload.
- **Definition gate**: `customElements.whenDefined` before rendering property-heavy elements.
- **Slots for content**: children with `slot` attributes for SSR-visible, accessible content.
- **Form-associated elements with Server Actions**: `name` attribute + ElementInternals -> values in `FormData`.
- **Theming via CSS custom properties and `::part()`** from your global CSS or Tailwind arbitrary properties.
- **`@lit/react` `createComponent`** when supporting React 18 consumers or wanting generated camelCase event props.

## Anti-Patterns
- **React 18-era wrappers** (ref + `addEventListener` + manual property sets) in a React 19 codebase. Extra code and bugs. Fix: native props/events.
- **Importing element definitions in Server Components or shared modules.** `HTMLElement is not defined` during SSR/build. Fix: client-only module or lazy import.
- **Using camelCase event props** (`onRatingChange`) directly on the tag. React listens for event `RatingChange`, which never fires. Fix: exact event name (`onrating-change`) or a wrapper.
- **`JSON.stringify` props into attributes.** Parsing cost, size, lost types. Fix: properties.
- **Relying on object props being present in SSR HTML.** They are omitted. Fix: primitives/slots for server-visible content.
- **No `:not(:defined)` handling.** Flash of unstyled or collapsed content and CLS. Fix: styles/skeletons with reserved space.
- **Untyped `any` JSX (`// @ts-ignore`).** Fix: IntrinsicElements declarations.
- **Assuming `onChange` works like React inputs.** Custom elements dispatch native/custom events with their own semantics. Fix: read element docs; use the exact event.
- **Label/ARIA references across shadow boundaries** (`aria-labelledby` pointing into or out of a shadow root). IDs do not cross shadow roots. Fix: `aria-label`, element-provided label props/slots.

## Accessibility
- Verify each element's role, name, value and keyboard support (WCAG 4.1.2, 2.1.1); shadow DOM does not exempt components.
- ID references do not cross shadow roots (cross-root ARIA "reference target" is not Baseline as of 2026-09); prefer element label properties, `aria-label`, or slotted labels.
- Focus management for dialogs/menus is the element's responsibility; confirm focus trapping and return focus to the trigger (WCAG 2.4.3).
- Form-associated elements should expose validity and labels via ElementInternals so errors are announced.
- Test with screen readers; automated tools may not pierce closed shadow roots.

## Responsive Design
- Style via exposed CSS custom properties and `::part()`; avoid relying on internal selectors.
- Container queries inside shadow DOM respond to the host's container; confirm the library supports your breakpoints.
- Reserve intrinsic size for undefined elements on mobile to avoid CLS.

## Performance
- Load only the element definitions you use (per-component entry points); avoid importing an entire library bundle.
- Lazy-define below-the-fold elements (dynamic import on visibility/interaction).
- Prefer npm-bundled definitions over CDN scripts to share dependencies and enable tree-shaking; if using `next/script`, choose non-blocking strategies.
- Avoid passing new object/array literals every render to property-heavy elements (can trigger element re-render); memoize or rely on React Compiler.
- Declarative Shadow DOM SSR (where supported by the library) improves FCP/CLS but adds HTML weight.

## Security
- Vet third-party custom element scripts like any third-party JS: pin versions, use SRI for CDN scripts, and restrict via CSP ([third-party-script-management](../third-party-script-management/Skill.md)).
- Elements that accept HTML strings (`innerHTML`-style properties) are XSS sinks; sanitize input.
- Do not pass secrets as attributes; they appear in HTML and DOM inspectors.
- Validate form values from custom elements on the server like any input.

## Testing
- Unit/component tests: jsdom supports `customElements` but not full shadow DOM layout/styles; many libraries need `happy-dom` or browser mode. Consider Vitest Browser Mode or Playwright component testing for element-heavy UIs.
- Assert property assignment (`element.options` is an array) and event wiring (dispatch `new CustomEvent('rating-change', { detail: { value: 3 } })`).
- E2E: Playwright locators pierce open shadow DOM by default; test keyboard, forms (`FormData` includes element values), and SSR (no hydration warnings, no CLS from undefined elements).
- Accessibility: axe with shadow DOM support; manual screen reader checks.

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| React 19 custom element support | Stable | Properties, events, SSR rules |
| `@lit/react` (`createComponent`) | Active | Optional in React 19; useful for React 18/typed wrappers |
| Custom Elements Manifest + JSX type generators | Community | Generate IntrinsicElements types |
| Lit 3.x | Active | Common base for design-system elements |
| Lit SSR (`@lit-labs/ssr`) and Next.js integration | Labs/experimental | Verify before relying on DSD SSR in Next.js |
| custom-elements-everywhere.com | Community | Framework interop test results |
| Playwright | Active | Shadow DOM-aware locators |

## Framework Notes
- **Next.js**: Server Components can render custom element tags as HTML (primitives as attributes), but definitions, events, refs, and property assignment require Client Components. Import definitions only in `'use client'` modules or lazily. Watch for hydration warnings when elements mutate their own attributes during upgrade before React hydrates (consider `suppressHydrationWarning` only on the specific element when the mutation is expected and harmless).
- **React (Vite SPA)**: no SSR caveats; import definitions in `main.tsx` or per-component modules. Same typing, property, and event rules apply.

## AI Agent Guidance
- Do: check React version (19+) and use native props/events; read the element's API docs or `custom-elements.json` before wiring.
- Do: add JSX type declarations and a typed wrapper component; load definitions from client-only code.
- Do: use exact, case-sensitive event names with the `on` prefix.
- Don't: add ref/`addEventListener` wrappers or `JSON.stringify` props unless supporting React 18.
- Don't: import definition modules in Server Components or rely on object props in SSR HTML.
- Before done: `next build` passes with no `HTMLElement is not defined` errors; in the browser, inspect the element to confirm properties are set (not `[object Object]` attributes); events fire handlers; no hydration warnings; keyboard and screen reader basics work.

## Examples
```tsx
// Server Action form with a form-associated custom element
// app/profile/page.tsx (Server Component)
import { saveRating } from './actions'
import { RatingField } from './rating-field'

export default function Page() {
  return (
    <form action={saveRating}>
      <RatingField name="rating" label="Rate your experience" />
      <button type="submit">Save</button>
    </form>
  )
}
```

```tsx
// app/profile/rating-field.tsx
'use client'
import '@/components/ds/define'
export function RatingField({ name, label }: { name: string; label: string }) {
  return <ds-rating name={name} max={5} aria-label={label} />
}
```

```css
/* Prevent FOUC/CLS before definitions load */
ds-rating:not(:defined) {
  display: inline-block;
  inline-size: 7.5rem;
  block-size: 1.5rem;
  visibility: hidden;
}
```

## Related Skills
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md) — calling element methods
- [react-typescript-patterns](../react-typescript-patterns/Skill.md) — JSX typing
- [design-system-architecture](../design-system-architecture/Skill.md) — cross-framework design systems
- [hydration-strategies](../hydration-strategies/Skill.md) — SSR and hydration concerns
- [third-party-script-management](../third-party-script-management/Skill.md) — vendor widgets
- [browser-apis-in-react](../browser-apis-in-react/Skill.md) — client-only platform access
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — verifying component semantics
- [cls-prevention](../cls-prevention/Skill.md) — reserving space for undefined elements

## Sources
- [react.dev: Custom HTML elements](https://react.dev/reference/react-dom/components#custom-html-elements) — Official — property vs attribute rule, `on` + event name, case sensitivity
- [React 19 release: Support for Custom Elements](https://react.dev/blog/2024/12/05/react-19) — Official — SSR primitive/non-primitive behavior, client property assignment
- [Lit: React integration](https://lit.dev/docs/frameworks/react/) — Official — `@lit/react` createComponent usage and event mapping
- [MDN: Using custom elements](https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_custom_elements) — Official — definition, `:defined`, lifecycle
- [MDN: ElementInternals](https://developer.mozilla.org/en-US/docs/Web/API/ElementInternals) — Official — form-associated custom elements
- [Custom Elements Everywhere](https://custom-elements-everywhere.com/) — Community — framework interop test suite

## License / Usage Notes
react.dev (CC-BY-4.0), MDN (CC-BY-SA), Lit (BSD-3-Clause). Content summarized; examples are original (`ds-*` elements are hypothetical).

## Quality Tier
A — React 19 behavior from official docs; SSR/DSD integration with Lit in Next.js and cross-root ARIA are evolving and flagged.

## Status
Active

## Last Verified
2026-09-15
