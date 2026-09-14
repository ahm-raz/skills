# Bootstrap 5 in React and Next.js

## Summary
Bootstrap 5.3.8 (August 25, 2025, MIT) is still the latest stable Bootstrap as of September 2026. It is a Sass-based CSS framework with CSS variables, color modes (`data-bs-theme`), utilities, a grid, and vanilla JS components (Popper-based). In React you use it via **React-Bootstrap** (components reimplemented in React, no Bootstrap JS) or Bootstrap CSS with your own accessible behavior. Bootstrap 6 is in alpha on the `v6-dev` branch, with no npm release or date. It is a large rewrite with a native `<dialog>`-based Dialog, `md:`-style responsive prefixes, and ESM TypeScript JS.

## Category
UI Libraries

## Subcategories
Sass customization, CSS variables, color modes, grid and utilities, React-Bootstrap, Popper, Next.js integration, Bootstrap 6 preview

## Problem It Solves
It gives teams a familiar, documented, framework-agnostic design baseline and grid. This matters for organizations with existing Bootstrap themes (bought themes, legacy apps, server-rendered pages) moving to React/Next.js without redesigning.

## When To Use
- Migrating legacy Bootstrap sites or purchased themes to React/Next.js.
- Teams with Sass-based design customizations and designers who know Bootstrap.
- Internal tools where the Bootstrap look is acceptable and a stable CSS API matters.

## When Not To Use
- New Tailwind v4 projects. Both utility systems overlap and conflict (`.container`, spacing utilities, reset).
- Highly branded product UIs that need component-level tokens and composable primitives (use shadcn/ui or Mantine).
- Planning heavily around Bootstrap 6 now. It is alpha and subject to change.

## Core Principles
1. **Customize at the Sass layer**: override variables and maps before importing Bootstrap. Keep compiled CSS lean by importing only the needed partials.
2. **CSS variables for runtime theming**: `--bs-*` variables and `data-bs-theme="dark"` color modes.
3. **In React, don't use Bootstrap's JS directly on React-managed DOM**. Use React-Bootstrap or controlled components.
4. **Utilities for layout, components for patterns**: grid (`row`, `col-md-6`), spacing utilities, and components (`card`, `navbar`).
5. **Accessibility depends on markup**: Bootstrap CSS doesn't provide semantics. React-Bootstrap adds ARIA and focus behavior.

## Best Practices
- Import Bootstrap Sass selectively: functions, variables, maps, mixins, root, then only the needed components and utilities.
- Use the `sass` package's modern API. Expect Sass deprecation warnings for `@import` in Bootstrap 5.3. Silence dependency warnings (`quietDeps`) rather than forking.
- Enable color modes with `data-bs-theme` on `<html>`, set from a cookie on the server to avoid flashes.
- Use React-Bootstrap components (`Modal`, `Dropdown`, `OverlayTrigger`) for interactive behavior. Verify its current version and React 19 support before adopting (not verified in this research).
- Use `next/font` and map its CSS variable into `$font-family-base` or `--bs-body-font-family`.
- Don't include `bootstrap.bundle.js` in React apps using React-Bootstrap. It causes double event handling.

## Implementation Guidance
```bash
pnpm add bootstrap sass
pnpm add react-bootstrap   # React components
```
```scss
// styles/bootstrap.scss
@import "bootstrap/scss/functions";
$primary: #4f46e5;
$border-radius: .5rem;
$enable-shadows: false;
@import "bootstrap/scss/variables";
@import "bootstrap/scss/variables-dark";
@import "bootstrap/scss/maps";
@import "bootstrap/scss/mixins";
@import "bootstrap/scss/root";
@import "bootstrap/scss/reboot";
@import "bootstrap/scss/type";
@import "bootstrap/scss/containers";
@import "bootstrap/scss/grid";
@import "bootstrap/scss/buttons";
@import "bootstrap/scss/forms";
@import "bootstrap/scss/modal";
@import "bootstrap/scss/dropdown";
@import "bootstrap/scss/utilities";
@import "bootstrap/scss/utilities/api";
```

| Approach | Behavior source | Use when |
|---|---|---|
| React-Bootstrap | React components (ARIA, focus) | Most React apps on Bootstrap |
| Bootstrap CSS + headless lib | Base UI/Radix/React Aria | Custom behavior, modern primitives |
| Bootstrap CSS + native `<dialog>`/`<details>` | Browser | Simple modals/disclosures |
| Bootstrap JS bundle | Vanilla JS | Avoid in React (lifecycle conflicts) |

**Bootstrap 6 preview (alpha, not on npm)**: responsive classes move to prefix form (`d-md-none` becomes `md:d-none`, `col-md-6` becomes `md:col-6`). Modal is replaced by a Dialog on native `<dialog>` with `showModal()` and `::backdrop`. JS becomes ESM TypeScript. Browser support floor rises. Plan migrations only after a stable release.

## Recommended Workflow
1. Set up the Sass entry with variable overrides and a selective import list.
2. Configure color modes and fonts in the root layout.
3. Create app components wrapping React-Bootstrap with your defaults (e.g. `AppModal`).
4. Audit accessibility (labels, focus, contrast after color overrides).
5. Track the Bootstrap 6 migration guide. Prototype on a branch when a beta appears.

## Patterns
- **Server-rendered static layout**: grid, cards and typography as Server Components (pure classes, no JS).
- **Client islands**: Modal/Dropdown/Tooltip in `"use client"` components via React-Bootstrap.
- **Theme via CSS variables**: override `--bs-primary`/`--bs-primary-rgb` per tenant at runtime in a scoped container.
- **Form validation styling**: `is-invalid` + `invalid-feedback` with `aria-invalid` and `aria-describedby` set by your form library.

## Anti-Patterns
- **`import "bootstrap/dist/js/bootstrap.bundle"` in a Next.js layout**: it runs on the server (window undefined) or conflicts with React DOM. If unavoidable, dynamically import inside `useEffect`.
- **Bootstrap + Tailwind on the same pages**: reset and utility collisions. Isolate with layers or pick one.
- **Importing all of `bootstrap.scss`** when using a handful of components: large unused CSS.
- **Using Bootstrap 6 alpha class syntax** in 5.3 projects.

## Accessibility
- Bootstrap docs give accessible markup patterns, but CSS alone doesn't enforce them. Keep required ARIA (`aria-expanded`, `aria-controls`, labels).
- React-Bootstrap handles focus trapping for Modal and keyboard behavior for Dropdown. Verify with screen readers.
- 5.3.8 included WCAG 2.1-related CSS updates. Still verify contrast after changing `$primary` (Bootstrap computes `color-contrast()` in Sass; check the output).
- Use `.visually-hidden` for screen-reader-only text.

## Responsive Design
- Mobile-first grid with breakpoints `sm` 576, `md` 768, `lg` 992, `xl` 1200, `xxl` 1400 (px). Responsive utilities `d-md-none`, `col-lg-4`.
- Navbar `expand-lg` collapse needs JS. Implement toggle state in React.
- Bootstrap 5.3 has no container-query utilities. Add custom CSS if needed.

## Performance
- The CSS bundle is the main cost. Use selective Sass imports and PurgeCSS-like tooling carefully (dynamic class names).
- React-Bootstrap adds React JS for interactive components only.
- Popper is a peer of Bootstrap JS. React-Bootstrap uses its own overlay positioning (verify dependency).

## Security
- Tooltip/Popover `html: true` with user content creates XSS risk in vanilla Bootstrap. Bootstrap ships a sanitizer, but in React render JSX instead of HTML strings.
- MIT. The maintainers participated in GitHub's Secure Open Source Fund (2025): SBOM, private vulnerability reporting.

## Testing
- Visual regression for Sass variable changes.
- Testing Library for React-Bootstrap components (roles: dialog, menu).
- axe checks for contrast after theming.

## Tooling
- `bootstrap` 5.3.8 (MIT, peer `@popperjs/core`), `sass`, React-Bootstrap (version not verified here), Bootstrap Icons.
- Bootstrap 6: alpha on `v6-dev`, migration guide published, no npm release (September 2026).
- The Bootstrap Themes marketplace is being sunset (announced August 2025).

## Framework Notes
- **Next.js App Router**: import compiled CSS (`import "@/styles/bootstrap.scss"`) in `app/layout.tsx`. Next.js supports Sass with `sass` installed. Class-only components work in Server Components. React-Bootstrap interactive components need `"use client"` wrappers. Set `data-bs-theme` from cookies in the layout to prevent flash.
- **React (Vite SPA)**: import the SCSS entry in `main.tsx`. Vite compiles Sass natively with `sass` installed.
- React 19: Bootstrap CSS is framework-agnostic. Check React-Bootstrap release notes for React 19 support.

## AI Agent Guidance
- DO use Bootstrap 5.3 class syntax (`col-md-6`, `d-md-none`), not Bootstrap 6 alpha syntax.
- DO prefer React-Bootstrap or headless primitives for interactive components. Never emit `data-bs-toggle` markup expecting Bootstrap JS in React.
- DON'T add Tailwind to a Bootstrap project (or vice versa) without an explicit decision.
- Verify before done: Sass compiles without errors, no Bootstrap JS bundle in React code paths, color mode works without flash, focus and labels on interactive widgets.

## Examples
```tsx
"use client";
import { useState } from "react";
import Button from "react-bootstrap/Button";
import Modal from "react-bootstrap/Modal";
import Form from "react-bootstrap/Form";

export function RenameModal({ initial, onSave }: { initial: string; onSave: (name: string) => void }) {
  const [show, setShow] = useState(false);
  const [name, setName] = useState(initial);
  const invalid = name.trim().length === 0;

  return (
    <>
      <Button variant="outline-primary" onClick={() => setShow(true)}>Rename</Button>
      <Modal show={show} onHide={() => setShow(false)} aria-labelledby="rename-title" centered>
        <Modal.Header closeButton><Modal.Title id="rename-title">Rename file</Modal.Title></Modal.Header>
        <Modal.Body>
          <Form.Group controlId="rename-input">
            <Form.Label>Name</Form.Label>
            <Form.Control value={name} onChange={(e) => setName(e.target.value)} isInvalid={invalid} aria-describedby="rename-error" />
            <Form.Control.Feedback id="rename-error" type="invalid">Name is required.</Form.Control.Feedback>
          </Form.Group>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={() => setShow(false)}>Cancel</Button>
          <Button disabled={invalid} onClick={() => { onSave(name); setShow(false); }}>Save</Button>
        </Modal.Footer>
      </Modal>
    </>
  );
}
```

## Related Skills
- [css-architecture](../css-architecture/Skill.md): Sass structure
- [css-cascade-layers-and-specificity](../css-cascade-layers-and-specificity/Skill.md): coexistence
- [responsive-design](../responsive-design/Skill.md): grid usage
- [dark-mode-implementation](../dark-mode-implementation/Skill.md): data-bs-theme
- [nextjs-pages-to-app-router-migration](../nextjs-pages-to-app-router-migration/Skill.md): legacy migrations
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): when Bootstrap still fits

## Sources
- [Bootstrap Blog](https://blog.getbootstrap.com/): Official. 5.3.8 release, security fund, Themes sunset
- [bootstrap registry metadata](https://registry.npmjs.org/bootstrap/latest): Official. Version 5.3.8, Popper peer
- [Bootstrap in 2026: 5.3.8 and Bootstrap 6 news](https://canvastemplate.com/blog/bootstrap-2026): Community. v6 alpha changes (prefix classes, native dialog, ESM TS)
- [HeroDevs: Bootstrap end-of-life dates](https://www.herodevs.com/blog-posts/bootstrap-end-of-life-dates-bootstrap-2-3-4-and-5-2026-guide): Community. Version support context

## License / Usage Notes
Bootstrap is MIT, as is React-Bootstrap. Bootstrap 6 details come from community summaries of the alpha branch and may change. Summarized content only.

## Quality Tier
B: Bootstrap 5.3.8 status verified officially, but React-Bootstrap's current version and React 19 support are unverified, and the v6 details are community-sourced.

## Status
Active (maintenance mode on 5.3.x; v6 in alpha)

## Last Verified
2026-09-15
