# Semantic HTML

## Summary
Choosing the right HTML element in React/Next.js JSX, so browsers expose correct roles, names, states and keyboard behaviour to assistive technology for free. This is the highest-leverage accessibility practice. It covers document structure, headings, lists, buttons vs links, and modern native primitives: `dialog`, `popover`, `details`, `search`, `inert` and invoker commands.

## Category
Accessibility

## Subcategories
Document outline, headings, lists, buttons vs links, native form controls, dialog/popover, inert, invoker commands, HTML-AAM, polymorphic components

## Problem It Solves
"Div soup" component trees yield pages with no headings to navigate, clickable divs keyboards can't reach, and unnamed controls. Four of the WebAIM Million 2026 top six errors are semantic-HTML failures: empty links, empty buttons, missing labels and missing `lang`. In 2026, 41.8% of home pages skipped heading levels.

## When To Use
- Always, for all JSX output: components, layouts, MDX content, email templates.
- Before reaching for ARIA or a component library.
- When refactoring legacy components.

## When Not To Use
- There is no case for avoiding semantics. Only avoid *wrong* semantics, such as `<table>` for layout, `<h3>` for styling, or `<button>` wrapping `<Link>`.

## Core Principles
1. **Element choice defines behaviour.** `<button>` is focusable and fires on Enter/Space; `<a href>` navigates; `<div>` does nothing.
2. **Structure mirrors meaning, not appearance.**
3. **Aim for one `<h1>` per page and no skipped levels.** Headings are screen reader users' primary navigation.
4. **Every interactive element has an accessible name**, ideally from visible text.
5. **Native before ARIA.**
6. **Components must not erase semantics.** A `<Button>` component must render `<button>`.

## Best Practices
- `<html lang>` in `app/layout.tsx` (or `index.html` for Vite); `lang` on foreign-language passages (3.1.2).
- A unique `<title>` per route: `metadata.title` in Next.js; `document.title` or `<title>` (React 19 hoists it) in SPAs.
- Buttons vs links: navigation uses `<Link href>`, an action uses `<button type="button">`. Always set `type` inside forms.
- Use `<ul>/<ol>` for nav groups, card grids and results. Tailwind's Preflight sets `list-style: none`, which makes Safari/VoiceOver drop list semantics, so add `role="list"` where the item count matters.
- `<table>` with `<caption>`, `<th scope>` for data.
- `<fieldset>` + `<legend>` for radio and checkbox groups.
- Other semantic elements: `<time dateTime>`, `<figure>/<figcaption>`, `<address>`, `<blockquote>`.
- `<dialog>` + `showModal()` for modals: top layer, inert background, Esc. Add `closedby="any"` for light dismiss where supported.
- `[popover]` for non-modal overlays: top layer, light dismiss, focus return.
- `<details>/<summary>`; `name` groups them into an exclusive accordion.
- `<search>` wraps search forms (implicit `search` landmark).
- `inert` removes a subtree from focus and the accessibility tree (React 19 boolean prop).
- Invoker commands (`commandfor`/`command`) open dialogs and popovers without JS. Support is new, so keep a JS fallback where older browsers matter.

## Implementation Guidance

### Element decision table
| Intent | JSX | Don't |
|---|---|---|
| Headings | `h1`–`h6` in order | `div className="title"` |
| Navigate | `<Link href>` / `<a href>` | `button onClick={() => router.push()}` for plain navigation |
| Action | `<button type="button">` | `div role="button"`, `<a href="#">` |
| Submit | `<button type="submit">` in `<form>` | click handler on a div |
| Text input | `<input>` + `<label htmlFor>` | `contentEditable div` |
| One of few | radios in `<fieldset>` | styled divs |
| One of many | `<select>` | custom listbox unless required |
| On/off | `<input type="checkbox" role="switch">` | `div.toggle` |
| Expand/collapse | `<details>` or `<button aria-expanded>` | click-to-toggle div |
| Modal | `<dialog>` / Radix or React Aria Dialog | plain `div.modal` |
| Non-modal float | `popover` attribute | absolutely positioned div only |
| Progress | `<progress>` / `<meter>` | div bars |
| Figure | `<figure>` + `<figcaption>` | div + p |

### Heading outline check (browser console)
```js
[...document.querySelectorAll('h1,h2,h3,h4,h5,h6')]
  .map(h => `${'  '.repeat(h.tagName[1]-1)}${h.tagName}: ${h.textContent.trim()}`).join('\n')
```
The HTML "outline algorithm" (sectioning adjusting heading levels) was never implemented and was removed from the spec. Set levels explicitly, and consider a `level` prop on reusable heading components.

## Recommended Workflow
1. Outline the page: landmarks, then headings, then content blocks.
2. Choose elements from the table. Style with Tailwind or CSS afterward.
3. Name every control from visible text; icon-only controls get a visually hidden label.
4. Validate with axe, the headings view, and the DevTools accessibility tree.
5. Tab through: every interactive thing is reachable, nothing else is.
6. Screen reader scan: the headings list (NVDA Insert+F7, VoiceOver VO+U) reads as a coherent table of contents.

## Patterns
**Visually hidden text** (Tailwind `sr-only` is equivalent)
```css
.visually-hidden:not(:focus):not(:active) {
  clip-path: inset(50%); height: 1px; width: 1px;
  overflow: hidden; position: absolute; white-space: nowrap;
}
```

**Icon button**
```tsx
<button type="button" onClick={onDelete}>
  <TrashIcon aria-hidden="true" focusable="false" />
  <span className="sr-only">Delete invoice {invoice.number}</span>
</button>
```

**Card with a stretched link (no nested interactive content)**
```tsx
<article className="relative rounded border p-4">
  <h3><Link href={`/posts/${post.slug}`} className="after:absolute after:inset-0">{post.title}</Link></h3>
  <p>{post.excerpt}</p>
</article>
```

**Polymorphic component that keeps semantics**
```tsx
type HeadingProps = { level: 1 | 2 | 3 | 4 | 5 | 6 } & React.HTMLAttributes<HTMLHeadingElement>;
export function Heading({ level, ...props }: HeadingProps) {
  const Tag = `h${level}` as const;
  return <Tag {...props} />;
}
```

**Declarative modal (native)**
```tsx
<button type="button" commandfor="confirm" command="show-modal">Delete…</button>
<dialog id="confirm" aria-labelledby="confirm-title" closedby="any">
  <h2 id="confirm-title">Delete project?</h2>
  <form method="dialog">
    <button value="cancel">Cancel</button>
    <button value="delete">Delete</button>
  </form>
</dialog>
```
If your React/TypeScript types lack `commandfor`/`command`/`closedby`, add a module augmentation for `React.ButtonHTMLAttributes` and `DialogHTMLAttributes`, or wire `showModal()` in a ref-based client component.

## Anti-Patterns
- **`<div onClick>` / `<span onClick>`.** Not focusable and no role. Use `<button>`.
- **`<a href="#">` or `<a onClick>` without href.** Use `<button>`.
- **`router.push` on a button for simple navigation.** No link semantics, no middle-click or open-in-new-tab. Use `<Link>`.
- **Headings by size.** Choose the level by hierarchy and style with classes.
- **Wrapping a card in `<Link>` that contains buttons.** Nested interactive content. Use the stretched-link pattern.
- **`placeholder` as the label.** Use `<label>`.
- **`<Button asChild>` / `as` props rendering a `div`.** Loses semantics. Constrain the allowed elements in TypeScript.
- **Wrapper `div`s inside `<ul>`/`<table>`.** Invalid children break list and table semantics. Use fragments.
- **`display: contents` on buttons or table parts.** Historically dropped semantics. Avoid it.

## Accessibility
- 1.3.1 Info and Relationships, 2.4.2 Page Titled, 2.4.6 Headings and Labels, 3.1.1/3.1.2 Language, 4.1.2 Name, Role, Value, 2.1.1 Keyboard.

## Responsive Design
- DOM order must equal visual order at every breakpoint. Tailwind `order-*`, `flex-row-reverse` and grid placement cause 1.3.2 and 2.4.3 failures. CSS `reading-flow` is experimental and not Baseline, so don't rely on it.
- Don't `hidden md:block` structural headings. Use `sr-only md:not-sr-only` if they must be visually hidden on mobile.

## Performance
- Native elements need no JS and work before hydration.
- `details`, `dialog` and `popover` replace large client components and can live in Server Components.

## Security
- `<form method="dialog">` avoids unintended submissions from modals.
- `target="_blank"` implies `noopener` in modern browsers; warn in link text ("opens in new tab").

## Testing
- axe: `button-name`, `link-name`, `html-has-lang`, `document-title`, `heading-order`, `list`, `listitem`, `empty-heading`, `nested-interactive`.
- Testing Library role queries (`getByRole('button', { name: /delete/i })`). A failing role query means the semantics are wrong.
- W3C Nu HTML Checker on the rendered output (`next build && next start`, then view source).
- Screen reader heading and landmark list review.

## Tooling
- eslint-plugin-jsx-a11y: `anchor-is-valid`, `no-static-element-interactions`, `click-events-have-key-events`, `heading-has-content`, `no-noninteractive-element-interactions`. Configure `settings['jsx-a11y'].components` to map design-system components (`Button: 'button'`).
- W3C Nu HTML Checker, axe DevTools, Accessibility Insights, WAVE, HeadingsMap.

## Framework Notes
- **Next.js (App Router).**
  - Set `lang` on `<html>` in `app/layout.tsx`.
  - Use `metadata` for titles.
  - `<Link>` renders an `<a>`; put `className`/`aria-*` directly on `<Link>`.
  - Static semantic markup belongs in Server Components; only interactive islands need `'use client'`.
  - MDX content: map `h1`–`h6`, `table` and `img` components in `mdx-components.tsx` without breaking semantics.
- **React (Vite SPA).**
  - Set `lang` in `index.html`.
  - React 19 hoists `<title>` rendered in components.
  - Use React Router's or TanStack Router's `<Link>`.
- **Both.**
  - Fragments avoid invalid wrappers.
  - Headless libraries' `asChild` (Radix) and `render` (Base UI) props let you keep native elements; verify the rendered tag.

## AI Agent Guidance
- Do: emit `button`, `Link`, `label htmlFor`, `fieldset/legend`, `table/th`, `nav`, `main`, ordered headings, `lang`, and a unique title per route.
- Do: prefer `dialog`, `popover`, `details` and `inert` before custom client widgets.
- Don't: generate `onClick` on `div`/`span`/`li`/`img`, `href="#"`, `tabIndex > 0`, placeholder-only inputs, skipped heading levels, or redundant roles.
- Verify before done:
  - heading outline coherent
  - all interactive elements native or justified
  - `getByRole` tests pass
  - jsx-a11y and axe clean

## Examples
```tsx
// app/(marketing)/docs/page.tsx
import Link from 'next/link';

export const metadata = { title: 'Getting started – Docs' };

export default function DocsPage() {
  return (
    <>
      <h1>Getting started</h1>
      <search>
        <form action="/search">
          <label htmlFor="q">Search docs</label>
          <input id="q" name="q" type="search" />
          <button type="submit">Search</button>
        </form>
      </search>
      <section aria-labelledby="install">
        <h2 id="install">Install</h2>
        <ol>
          <li>Create the app with <code>create-next-app</code>.</li>
          <li>Run <code>npm run dev</code>.</li>
        </ol>
      </section>
      <section aria-labelledby="faq">
        <h2 id="faq">FAQ</h2>
        <details name="faq"><summary>Which Node version?</summary><p>Node 22 LTS or newer.</p></details>
        <details name="faq"><summary>Does it support ESM?</summary><p>Yes.</p></details>
      </section>
      <p><Link href="/docs/routing">Next: Routing</Link></p>
    </>
  );
}
```

## Related Skills
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — when native isn't enough
- [landmarks-and-accessible-navigation](../landmarks-and-accessible-navigation/Skill.md) — page regions and skip links
- [accessible-forms](../accessible-forms/Skill.md) — labels and groups
- [accessible-dialogs](../accessible-dialogs/Skill.md) — dialog component details
- [popovers](../popovers/Skill.md) — Popover API
- [progressive-enhancement](../progressive-enhancement/Skill.md) — HTML-first delivery
- [buttons-and-actions](../buttons-and-actions/Skill.md) — button vs link design
- [component-api-design](../component-api-design/Skill.md) — polymorphic components that keep semantics

## Sources
- [HTML Living Standard](https://html.spec.whatwg.org/) — Official — element semantics, dialog, popover, inert
- [MDN: button element (command, commandfor, interestfor)](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/button) — Official (MDN) — invoker commands
- [HTML-AAM](https://www.w3.org/TR/html-aam-1.0/) — Official — implicit role mappings
- [MDN: reading-flow](https://developer.mozilla.org/en-US/docs/Web/CSS/reading-flow) — Official (MDN) — experimental status
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — heading and empty-control prevalence
- [eslint-plugin-jsx-a11y](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y) — Open Source — static rules, component mapping
- [Adrian Roselli blog](https://adrianroselli.com/) — Community — list semantics and `display: contents` history, card patterns

## License / Usage Notes
The WHATWG spec is CC BY 4.0; MDN is CC BY-SA 2.5; jsx-a11y is MIT. Content is summarised and examples are original.

## Quality Tier
S — foundational, spec-backed, with current data and React/Next.js specifics.

## Status
Active

## Last Verified
2026-09-15
