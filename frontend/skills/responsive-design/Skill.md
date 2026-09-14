# Responsive Design

## Summary
Responsive design in 2026 is a layered strategy. Intrinsic layouts (flex-wrap, auto-fit grids) and fluid tokens (`clamp()`) come first, container queries handle components, viewport media queries handle page shells, and user-preference and capability media features (`prefers-*`, `hover`, `pointer`) handle the rest. This skill gives the decision model, breakpoint strategy, viewport units, input-mode handling, and React/Next.js pitfalls (JS media hooks, hydration mismatches, device sniffing).

## Category
CSS & Styling

## Subcategories
Mobile-first, breakpoints, media queries (range syntax), container queries, intrinsic design, viewport units (dvh/svh/lvh), hover/pointer, prefers-reduced-motion, prefers-contrast, safe areas, orientation, touch, reflow

## Problem It Solves
Device-based breakpoint sprawl, layouts that break between breakpoints, JS `window.innerWidth` logic that causes hydration mismatch and CLS, hover-only interactions on touch devices, `100vh` bugs on mobile, and zoom/reflow accessibility failures.

## When To Use
- Planning layout behavior for any new page or component.
- Reviewing responsive bugs or excessive media queries.
- Deciding between CSS and JS for adaptive rendering in React/Next.js.

## When Not To Use
- Image source selection details. See responsive-images-and-media.
- Detailed container query syntax. See container-queries.
- Native mobile apps.

## Core Principles
1. **Content-out, mobile-first.** Base styles are for the narrowest context; enhance upward with `min-width` / `width >=` queries.
2. **Hierarchy of tools:** intrinsic layout → fluid values → container queries → media queries → JS (last resort).
3. **Breakpoints follow content**, not devices. Add one where the design breaks.
4. **Adapt to capabilities, not device labels.** `(hover: hover)`, `(pointer: coarse)`, not "is mobile".
5. **Same HTML for all viewports** whenever possible. Hide/reflow with CSS, avoiding divergent server renders.
6. **Respect user settings:** zoom, font size, reduced motion, contrast, color scheme, reduced data.
7. **Reflow at 320 CSS px** without horizontal scroll (WCAG 1.4.10).

## Best Practices
- Use range syntax: `@media (width >= 48rem)`, `@media (40rem <= width < 64rem)`.
- Use `rem`/`em` breakpoints so they scale with user font size and zoom.
- Keep a small breakpoint set (e.g. 40/48/64/80rem; Tailwind defaults) for page layout; components use container queries.
- Include `<meta name="viewport" content="width=device-width, initial-scale=1">` (Next.js adds it by default). Never disable zoom (`user-scalable=no`, `maximum-scale=1`).
- Full-height layouts: `min-block-size: 100dvh` (dynamic) or `100svh` (stable, avoids jumps as toolbars show/hide).
- Handle notches: `padding: env(safe-area-inset-*)` with `viewport-fit=cover` if drawing edge-to-edge.
- Hover effects inside `@media (hover: hover)`; larger targets under `(pointer: coarse)`.
- Motion inside `@media (prefers-reduced-motion: no-preference)`.
- Data tables: allow horizontal scroll in a focusable, labeled region rather than crushing columns; or transform to cards via container query.
- Test real devices for touch, virtual keyboard (`interactive-widget=resizes-content` viewport option), and safe areas.

## Implementation Guidance

### Decision table
| Need | Tool |
|---|---|
| Items wrap as space runs out | `flex-wrap`, `repeat(auto-fit, minmax(min(100%, X), 1fr))` |
| Sizes scale smoothly | `clamp()` fluid tokens |
| Component changes layout in narrow slot | Container size query |
| App shell: sidebar visible / bottom nav on small screens | Viewport media query |
| Hover vs touch affordances | `(hover: hover)`, `(pointer: fine / coarse)`, `any-pointer` |
| Motion, contrast, color, transparency | `prefers-reduced-motion`, `prefers-contrast`, `prefers-color-scheme`, `prefers-reduced-transparency` |
| Different component tree (not just styling), e.g. Dialog vs Drawer | CSS if possible (render both, hide one) or JS media hook in a client component with SSR-safe default |
| Save data | `Save-Data` client hint / `prefers-reduced-data` (limited) |
| Print | `@media print` |

### Viewport units
| Unit | Meaning | Use |
|---|---|---|
| `vh` / `vw` | Large viewport (historically buggy on mobile) | Avoid for heights |
| `svh` | Small viewport (toolbars visible) | Stable minimum heights |
| `lvh` | Large viewport (toolbars hidden) | Backgrounds that can overflow |
| `dvh` | Dynamic, updates as UI shows/hides | Full-screen app shells (may cause reflow when scrolling) |
| `vi` / `vb` | Inline/block viewport axes | Writing-mode-aware sizing |

### Breakpoint tokens (Tailwind v4 defaults)
`sm 40rem`, `md 48rem`, `lg 64rem`, `xl 80rem`, `2xl 96rem`. Custom media in plain CSS via PostCSS/Lightning CSS: `@custom-media --md (width >= 48rem);`.

### JS media queries in React (when unavoidable)
- Use `useSyncExternalStore` with `matchMedia` and a **server snapshot** that matches your CSS-first default to avoid hydration mismatch.
- Prefer rendering both variants and hiding via CSS when the cost is small (no mismatch, no CLS).
- Never use User-Agent sniffing on the server to choose layouts (caching, wrong guesses, and foldables break it). If you must, use Client Hints (`Sec-CH-UA-Mobile`) with `Vary` headers and accept limitations.

## Recommended Workflow
1. Write semantic HTML/JSX with a sensible source order.
2. Style the narrowest layout; use intrinsic layouts and fluid tokens.
3. Widen the viewport until the design breaks; add a page breakpoint or make the component a container.
4. Add capability/preference queries (hover, pointer, motion, contrast).
5. Test: 320px, 375px, 768px, 1024px, 1440px+, landscape phone, 200%/400% zoom, virtual keyboard open, touch and mouse.
6. Remove JS layout logic replaced by CSS.

## Patterns
**Page shell: drawer nav on small, persistent sidebar on large**
```css
.shell { display: grid; grid-template-columns: minmax(0, 1fr); min-block-size: 100dvh; }
.sidebar { display: none; }
@media (width >= 64rem) {
  .shell { grid-template-columns: 16rem minmax(0, 1fr); }
  .sidebar { display: block; }
  .menu-button { display: none; }
}
```

**Hover only where supported**
```css
.card { transition: translate .15s; }
@media (hover: hover) and (prefers-reduced-motion: no-preference) {
  .card:hover { translate: 0 -2px; }
}
@media (pointer: coarse) { .icon-button { min-inline-size: 44px; min-block-size: 44px; } }
```

**Responsive table region**
```tsx
<div role="region" aria-labelledby="orders-caption" tabIndex={0} className="overflow-x-auto">
  <table className="min-w-[48rem]"><caption id="orders-caption">Orders</caption>…</table>
</div>
```

**SSR-safe media query hook**
```tsx
"use client";
import { useSyncExternalStore } from "react";
export function useMediaQuery(query: string, serverDefault = false) {
  return useSyncExternalStore(
    (cb) => { const m = matchMedia(query); m.addEventListener("change", cb); return () => m.removeEventListener("change", cb); },
    () => matchMedia(query).matches,
    () => serverDefault,
  );
}
```

## Anti-Patterns
- **`if (window.innerWidth < 768)` during render.** Crashes on server / hydration mismatch. Use CSS, or `useSyncExternalStore` with a server snapshot.
- **Device-named breakpoints (`iphone`, `ipad`).** Devices change. Use content-driven rem breakpoints.
- **Desktop-first `max-width` cascades.** Override-heavy CSS. Mobile-first `min-width`.
- **`height: 100vh` for mobile full screen.** Content hidden under browser UI. Use `dvh`/`svh`.
- **Disabling zoom in viewport meta.** Accessibility failure (1.4.4). Remove it.
- **Hover-only menus/tooltips.** Touch/keyboard users locked out. Click/focus triggers.
- **Hiding essential content on mobile.** Content parity issue; also SEO (mobile-first indexing). Reflow instead.
- **UA sniffing to serve a different layout.** Wrong guesses, cache fragmentation. Responsive CSS.
- **px breakpoints with rem content.** Layout breaks when users enlarge text. Use rem/em breakpoints.

## Accessibility
- 1.4.10 Reflow: no 2D scrolling at 320 CSS px (except tables, maps, diagrams).
- 1.4.4 Resize text 200%; 1.4.12 Text spacing; 1.3.4 Orientation (don't lock orientation).
- 2.5.8 Target size ≥24×24 CSS px; 2.5.7 Dragging movements need single-pointer alternatives.
- 2.4.11 Focus not obscured: sticky headers/bottom bars must not cover focused elements (use `scroll-padding-block-start`).
- Respect `prefers-reduced-motion`, `prefers-contrast`, `forced-colors`.
- Keep DOM order logical when rearranging for breakpoints (1.3.2, 2.4.3).

## Responsive Design
This skill is the umbrella. Delegate component adaptation to container queries, sizing to fluid tokens, and media to responsive images.

## Performance
- CSS-only adaptation avoids JS execution, hydration mismatch, and layout shift.
- Rendering both mobile and desktop variants doubles DOM. Acceptable for small fragments, not for heavy trees (use a client-side media hook with lazy loading there).
- `dvh` changes during scroll can trigger layout; prefer `svh` for large content areas where jumps matter.
- Responsive images and `content-visibility` matter more on mobile networks (see responsive-images-and-media).

## Security
Don't rely on client-reported viewport/UA for access control or feature gating. Client Hints can be spoofed.

## Testing
- Playwright projects for mobile devices (`devices["iPhone 15"]`, `devices["Pixel 7"]`) plus desktop; screenshots at key widths.
- Zoom testing: Playwright can't emulate browser zoom perfectly. Test manually at 200%/400%, or set `deviceScaleFactor` + narrow viewport (320px ≈ 1280px at 400%).
- Emulate `prefers-reduced-motion`, `forced-colors`, `colorScheme` in Playwright (`page.emulateMedia`).
- Real-device checks for virtual keyboard and safe areas (BrowserStack/Sauce or physical devices).

## Tooling
- Browser DevTools device mode, CSS overview, rendering emulation (prefers-*, vision deficiencies).
- Playwright device descriptors and `emulateMedia`.
- Polypane / Responsively App. Multi-viewport browsers (community).
- Tailwind v4 responsive and container variants.
- Lighthouse / axe for reflow-related and target-size issues.

## Framework Notes
- **Next.js App Router:** Server Components can't know the viewport, so style responsively in CSS. Next.js injects `<meta name="viewport" content="width=device-width, initial-scale=1">` by default. Customize via `export const viewport: Viewport = { width: "device-width", initialScale: 1, viewportFit: "cover", interactiveWidget: "resizes-content" }` and never set `maximumScale: 1` / `userScalable: false`. Use `next/image` `sizes` matching your CSS breakpoints. For Dialog-on-desktop / Drawer-on-mobile (common with shadcn/vaul), use a client component with `useMediaQuery(query, serverDefault)` and accept a post-hydration switch, or render the trigger and decide on open (no mismatch because content isn't rendered initially).
- **React (Vite SPA):** no SSR mismatch risk, but still prefer CSS for layout. Media hooks cause extra renders and flashes on load.
- **Tailwind:** mobile-first variants (`md:`), ranges (`md:max-lg:`), `pointer-coarse:` / `pointer-fine:` / `any-hover`-style variants, `motion-safe:`, `contrast-more:`, `portrait:`/`landscape:`, `print:`.

## AI Agent Guidance
- Do solve layout adaptation with intrinsic CSS, fluid tokens, and container queries before media queries, and media queries before JS.
- Do write mobile-first styles with rem-based range queries.
- Do use `dvh`/`svh`, safe-area insets, and capability queries (`hover`, `pointer`).
- Don't read `window` during render, don't sniff UA, don't disable zoom, don't hide essential content on small screens.
- Before done: verify 320px (no horizontal scroll), a tablet width, desktop, 200% zoom, touch emulation, and check the console for hydration warnings.

## Examples
```tsx
// app/layout.tsx
import type { Viewport } from "next";
import "./globals.css";

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  interactiveWidget: "resizes-content",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-dvh pb-[env(safe-area-inset-bottom)] [scroll-padding-block-start:5rem]">{children}</body>
    </html>
  );
}
```
```tsx
// app/components/ResponsiveNav.tsx — same markup for all sizes; CSS decides
import Link from "next/link";
import { MobileMenu } from "./MobileMenu"; // client component (disclosure)

const links = [{ href: "/", label: "Home" }, { href: "/pricing", label: "Pricing" }, { href: "/docs", label: "Docs" }];

export function ResponsiveNav() {
  return (
    <header className="sticky top-0 z-40 flex items-center justify-between gap-4 bg-bg/90 px-4 py-3 backdrop-blur">
      <Link href="/" className="font-semibold">Acme</Link>
      <nav aria-label="Primary" className="hidden md:block">
        <ul className="flex gap-6">
          {links.map((l) => (<li key={l.href}><Link className="hover:underline" href={l.href}>{l.label}</Link></li>))}
        </ul>
      </nav>
      <div className="md:hidden"><MobileMenu links={links} /></div>
    </header>
  );
}
```

## Related Skills
- [container-queries](../container-queries/Skill.md) — component-level responsiveness
- [fluid-typography-and-spacing](../fluid-typography-and-spacing/Skill.md) — fluid sizing
- [responsive-images-and-media](../responsive-images-and-media/Skill.md) — media delivery
- [css-grid-and-flexbox-layout](../css-grid-and-flexbox-layout/Skill.md) — intrinsic layouts
- [mobile-web-app-patterns](../mobile-web-app-patterns/Skill.md) — mobile-specific UX
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — target sizes and input modes
- [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md) — device test matrix
- [responsive-dashboard-layouts](../responsive-dashboard-layouts/Skill.md) — dashboards across sizes

## Sources
- [MDN — Using media queries (range syntax)](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_media_queries/Using_media_queries) — Official — syntax, media features
- [MDN — Viewport units (length)](https://developer.mozilla.org/en-US/docs/Web/CSS/length#relative_length_units_based_on_viewport) — Official — svh/lvh/dvh
- [Tailwind CSS — Responsive design](https://tailwindcss.com/docs/responsive-design) — Official — breakpoints, ranges, container variants
- [Next.js — generateViewport](https://nextjs.org/docs/app/api-reference/functions/generate-viewport) — Official — viewport export
- [W3C — Understanding SC 1.4.10 Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html) — Official — 320px reflow
- [web.dev — Learn Responsive Design](https://web.dev/learn/design) — Official — macro/micro layouts, capability queries
- [LogRocket — Container queries in 2026](https://blog.logrocket.com/container-queries-2026/) — Community — container vs media tradeoffs
- [Every Layout](https://every-layout.dev/) — Community — intrinsic design approach

## License / Usage Notes
MDN is CC-BY-SA, web.dev is CC-BY 4.0, and Next.js/Tailwind docs are MIT. Content is summarized, and code is original.

## Quality Tier
A — Comprehensive, current decision model grounded in official docs. Device testing specifics vary by audience.

## Status
Active

## Last Verified
2026-09-15
