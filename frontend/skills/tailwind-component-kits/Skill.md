# Tailwind Component Kits (daisyUI, Flowbite, Preline, Tailwind Plus)

## Summary
Tailwind component kits provide pre-designed component classes, HTML snippets or React ports on top of Tailwind CSS v4. daisyUI 5 (5.7.37, MIT) is a pure-CSS plugin with semantic classes (`btn`, `card`, `modal`) and 35 themes. Flowbite (4.0.2 core, `flowbite-react` 0.12.17, MIT) ships Tailwind components with vanilla JS behavior and a React port. Preline (5.0.0, MIT + Fair Use License) provides Tailwind blocks plus headless JS plugins. Tailwind Plus (commercial, formerly Tailwind UI) provides official copy-paste templates and the Catalyst React kit on Headless UI. Their shared trade-off is fast visuals, but in React the interactive accessibility comes from whatever JS or headless library you pair with them.

## Category
UI Libraries

## Subcategories
daisyUI themes, Flowbite React, Preline plugins, Tailwind Plus/Catalyst, CSS-only components, Tailwind v4 plugins, theming via data-theme

## Problem It Solves
Teams using Tailwind want ready-made looks (buttons, cards, navbars, pricing sections, dashboards) without designing from scratch or adopting a heavy CSS-in-JS library.

## When To Use
- Prototypes, MVPs, marketing/landing pages, and admin templates where speed of visual output matters.
- daisyUI: you want short semantic classes and multi-theme support with zero JS.
- Flowbite React: you want prebuilt React components in Tailwind style and accept a smaller, pre-1.0 ecosystem.
- Tailwind Plus: you need high-quality official marketing/app UI blocks and have a license.

## When Not To Use
- Accessibility-critical interactive apps relying on CSS-only widgets (daisyUI `dropdown`/`modal` via checkbox or `details` hacks). Use shadcn/ui, Base UI or React Aria for behavior.
- Large design systems needing code ownership, variant APIs and typed components (shadcn/ui fits better).
- Mixing multiple kits: class-name collisions and inconsistent tokens.

## Core Principles
1. **Look and behavior are separate problems**: kits solve look. In React, behavior must come from React state plus accessible primitives.
2. **Use the Tailwind v4 CSS-first plugin syntax** (`@plugin "daisyui"`, `@import "flowbite/..."`-style imports per the docs). Avoid v3 `tailwind.config.js` plugin arrays.
3. **Theme with CSS variables**: daisyUI `data-theme`, Flowbite theme variables. Map them to your semantic tokens.
4. **Don't use vanilla-JS data-attribute initializers in React** (Flowbite `data-modal-toggle`, Preline `HSStaticMethods`) unless you manage their lifecycle. Prefer React ports or headless libraries.
5. **Know the license**: Tailwind Plus and Preline Pro are commercial. Preline's free tier carries a Fair Use License on top of MIT.

## Best Practices
- daisyUI 5: configure themes in CSS with `--default` and `--prefersdark` flags. Create custom themes with `@plugin "daisyui/theme" { name: "brand"; --color-primary: oklch(...); }`.
- Combine daisyUI classes for visuals with Base UI/Radix for interactive widgets (e.g. `className="btn btn-primary"` on a Base UI `Dialog.Trigger`).
- With `flowbite-react`, follow its Tailwind v4 setup (peer `tailwindcss ^3 || ^4`) and its theme customization API instead of editing node_modules classes.
- With Preline in Next.js, re-initialize plugins after client navigation (their docs describe calling the autoInit on route change) or, better, use Preline for static blocks only.
- With Tailwind Plus/Catalyst, keep copied components in `components/catalyst/*` and treat them as owned code.
- Run `prettier-plugin-tailwindcss` to keep long class lists readable.

## Implementation Guidance
**daisyUI 5 with Tailwind v4**
```css
/* app/globals.css */
@import "tailwindcss";
@plugin "daisyui" {
  themes: light --default, dark --prefersdark;
}
@plugin "daisyui/theme" {
  name: "brand";
  default: false;
  --color-primary: oklch(55% 0.2 270);
  --color-primary-content: oklch(98% 0.01 270);
  --radius-box: 0.75rem;
}
```
```tsx
<html data-theme="brand">...</html>
```

**Kit comparison (September 2026)**
| Kit | Delivery | JS behavior | React story | License |
|---|---|---|---|---|
| daisyUI 5.7 | CSS plugin classes | None (CSS-only patterns) | Use classes on React/headless components | MIT |
| Flowbite 4 | Tailwind plugin + vanilla JS | Popper-based data attributes | `flowbite-react` 0.12 (pre-1.0) | MIT (Pro blocks paid) |
| Preline 5 | CSS variants + JS plugins | 27 headless plugins | Vanilla plugins; manage lifecycle | MIT + Fair Use; Pro paid |
| Tailwind Plus | Copy-paste HTML/React/Vue | Tailwind Plus Elements / Headless UI | Catalyst (Headless UI v2) | Commercial |

## Recommended Workflow
1. Decide which layer provides behavior (headless library or kit's React port). Document it.
2. Configure the kit via Tailwind v4 CSS directives. Map kit theme variables to your semantic tokens.
3. Build React wrappers (`Button`, `Card`, `Modal`) that encapsulate kit classes and accessible behavior.
4. Audit interactive components with keyboard and screen readers.
5. Lock kit versions. Class names can change between majors (daisyUI 4 to 5 renamed several).

## Patterns
- **Visual kit + headless behavior**: `<Dialog.Popup className="modal-box">` (Base UI) or `<Menu.Popup className="menu bg-base-100 rounded-box">`.
- **Theme switcher**: set `document.documentElement.dataset.theme` from a client component. Persist in a cookie so SSR renders the right theme.
- **Marketing blocks as Server Components**: static Tailwind Plus/Preline sections contain no JS and render as RSC.
- **Wrapper with cva**: map `variant` props to daisyUI classes (`btn-primary`, `btn-ghost`) for a typed API.

## Anti-Patterns
- **daisyUI checkbox-hack modals/dropdowns in production apps**: no focus trap, no Escape handling, poor screen-reader semantics. Use the native `<dialog>` with `showModal()` or a headless library.
- **Flowbite vanilla JS `data-*` toggles in Next.js**: event listeners are lost after client navigation or hydration, so modals stop working. Use `flowbite-react` or headless components.
- **Mixing daisyUI and shadcn tokens** without mapping: two `primary` colors, inconsistent dark mode.
- **Pasting Tailwind Plus code into open-source repos**: license violation.
- **Using v3 plugin config** (`plugins: [require("daisyui")]`) with Tailwind v4.

## Accessibility
- CSS-only components cannot provide focus management, `aria-expanded` state or keyboard navigation. Add them via React or headless libraries (WCAG 2.1.1, 2.4.3, 4.1.2).
- Check theme contrast. Many built-in daisyUI themes are decorative, so verify `primary-content` on `primary` and base text contrast (1.4.3).
- Flowbite/Preline JS components include some ARIA handling. Audit them, especially after re-initialization in SPAs.
- Catalyst inherits Headless UI accessibility.

## Responsive Design
- All kits are Tailwind-responsive. Use breakpoint and container-query utilities as usual.
- Kit navbars/drawers often assume the vanilla JS toggle. Reimplement mobile menus with React state and accessible disclosure patterns.

## Performance
- daisyUI: CSS only, and Tailwind v4 emits only used classes, so it's very light.
- Flowbite/Preline JS bundles load globally if imported wholesale. Import per plugin, or avoid them for React-managed widgets.
- Static blocks can stay Server Components (zero client JS).

## Security
- Copy-paste blocks may include third-party script tags or external image URLs. Review before shipping (CSP implications).
- Preline Fair Use License and Tailwind Plus terms restrict redistribution. Keep them in private repos per license.

## Testing
- Visual regression per theme (`data-theme` variants).
- Keyboard/axe tests on any interactive kit component. CSS-only widgets usually fail. Document exceptions.
- For Flowbite/Preline JS components, test after client-side navigation (common regression).

## Tooling
- daisyUI 5.7.37 (MIT), theme generator.
- Flowbite 4.0.2 (Tailwind 4 dependency), `flowbite-react` 0.12.17 (React 18/19, Tailwind 3/4).
- Preline 5.0.0 (MIT + Preline UI Fair Use License), Agent Skills support per repo README.
- Tailwind Plus (commercial) with Catalyst on Headless UI v2.

## Framework Notes
- **Next.js App Router**: CSS-class kits work in Server Components with no client JS. For theme switching, read the theme from a cookie in the root layout and set `data-theme` on `<html>` to avoid a flash. Wrap vanilla-JS kits in a client component that initializes in `useEffect` and re-initializes on `usePathname()` changes, or avoid them.
- **React (Vite SPA)**: same considerations. Vanilla JS initializers still conflict with React-managed DOM.
- React 19: daisyUI is framework-agnostic. `flowbite-react` peers include React 19.

## AI Agent Guidance
- DO detect the kit (`@plugin "daisyui"`, `flowbite-react`, `preline`) and reuse its classes consistently.
- DO pair CSS-only kit visuals with accessible behavior (native `<dialog>`, Base UI, Radix, React Aria).
- DON'T generate Flowbite `data-modal-toggle` markup in React apps.
- DON'T reproduce Tailwind Plus source unless it exists in the repo (license).
- Verify before done: Tailwind v4 plugin syntax, theme contrast, keyboard access for every interactive element, no global JS initializers left unmanaged.

## Examples
```tsx
"use client";
// daisyUI visuals + native <dialog> behavior (focus trap, Escape, ::backdrop provided by the browser)
import { useRef } from "react";

export function DeleteModal({ onConfirm }: { onConfirm: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button className="btn btn-error" onClick={() => ref.current?.showModal()}>Delete</button>
      <dialog ref={ref} className="modal" aria-labelledby="del-title">
        <div className="modal-box">
          <h3 id="del-title" className="text-lg font-bold">Delete item?</h3>
          <p className="py-4">This action cannot be undone.</p>
          <div className="modal-action">
            <form method="dialog" className="flex gap-2">
              <button className="btn">Cancel</button>
              <button className="btn btn-error" onClick={onConfirm}>Delete</button>
            </form>
          </div>
        </div>
        <form method="dialog" className="modal-backdrop"><button aria-label="Close">close</button></form>
      </dialog>
    </>
  );
}
```

## Related Skills
- [tailwind-css-v4](../tailwind-css-v4/Skill.md): plugin syntax
- [headless-ui](../headless-ui/Skill.md): Catalyst foundation
- [shadcn-ui](../shadcn-ui/Skill.md): owned-code alternative
- [theming-with-css-variables](../theming-with-css-variables/Skill.md): data-theme model
- [landing-page-design](../landing-page-design/Skill.md): blocks usage
- [accessible-dialogs](../accessible-dialogs/Skill.md): fixing CSS-only modals
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): kit vs library

## Sources
- [daisyUI themes](https://daisyui.com/docs/themes/): Official. v5 CSS plugin theming syntax
- [daisyUI 5 release notes](https://daisyui.com/docs/v5/?lang=de): Official. Rewrite for Tailwind v4, zero deps
- [daisyui registry metadata](https://registry.npmjs.org/daisyui/latest): Official. Version 5.7.37
- [themesberg/flowbite](https://github.com/themesberg/flowbite): Open Source. Data-attribute JS, framework ports, MIT
- [flowbite](https://registry.npmjs.org/flowbite/latest) / [flowbite-react](https://registry.npmjs.org/flowbite-react/latest) registry metadata: Official. Versions and peers
- [htmlstreamofficial/preline](https://github.com/htmlstreamofficial/preline): Open Source. Plugins, Fair Use License
- [preline registry metadata](https://registry.npmjs.org/preline/latest): Official. Version 5.0.0
- [Catalyst docs](https://catalyst.tailwindui.com/docs): Official. Catalyst kit
- [Tailwind Plus changelog](https://tailwindcss.com/plus/changelog): Official

## License / Usage Notes
daisyUI MIT. Flowbite MIT (Pro paid). Preline MIT plus Fair Use License (Pro paid). Tailwind Plus/Catalyst commercial. Summarized content only; no kit source reproduced beyond generic class usage.

## Quality Tier
B: versions and licensing verified, but four products are covered at a summary level; Tailwind Plus Elements details and Flowbite React's v4 setup specifics were not fully verified.

## Status
Active

## Last Verified
2026-09-15
