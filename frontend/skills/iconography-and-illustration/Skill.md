# Iconography and Illustration

## Summary
Choosing, sizing, labeling, and implementing icons and illustrations so they aid recognition instead of creating mystery meat. Covers when icons need text labels, consistent icon sets and grids, accessible SVG patterns (decorative vs meaningful), icon buttons, status icons, illustration style and use in empty/error/onboarding states, and performant delivery in React/Next.js.

## Category
UX

## Subcategories
icon sets, icon buttons, SVG accessibility, icon sizing, status icons, illustrations, spot illustrations, icon licensing, sprite sheets

## Problem It Solves
Icon-only controls users can't decode, mixed icon styles from multiple libraries, unlabeled SVGs that screen readers skip or read as garbage, huge icon bundles, and illustrations that distract or look off-brand.

## When To Use
- Adding icons to buttons, nav, status indicators, tables, forms.
- Choosing an icon library or building a custom set.
- Adding illustrations for empty states, onboarding, errors, marketing.

## When Not To Use
- Data visualization glyphs and chart marks (see data-viz skills).
- Brand logo design.

## Core Principles
1. **Label icons with text** unless the icon is universally understood in context (NN/g: few icons are universal — search, home, print, close are among the safest).
2. **One icon family** per product: consistent grid, stroke width, corner radius, fill style.
3. **Icons support text, not replace it**, especially in navigation and primary actions.
4. **Meaning must not depend on the icon alone** for status (pair with text) or on color alone.
5. **Decorative icons are hidden from assistive tech; meaningful icons get names.**
6. **Consistent mapping**: the same icon always means the same thing; one concept, one icon.
7. **Size for legibility and targets**: icon glyph size != touch target size.
8. **Illustrations are supporting cast**: small, purposeful, on-brand, never blocking the task.

## Best Practices
- Standard sizes: 16px (inline with 14px text), 20px (buttons/inputs, 14-16px text), 24px (standalone/nav, the Material default), 32-48px (empty states/feature). Align icon optical size with adjacent text.
- Use `currentColor` so icons inherit text color and themes.
- Stroke icons at consistent stroke width (e.g., Lucide 2px at 24px; scale `absoluteStrokeWidth` when resizing).
- Icon-only buttons: accessible name via `aria-label` or visually hidden text; tooltip for sighted users; target at least 24x24 CSS px (44x44 on touch).
- Status: icon + text + color ("⚠ Payment overdue"), with icon shapes distinct (not only color differences between success/error).
- Directional icons (arrows, chevrons, "back") flip in RTL; non-directional (checkmark, search) don't.
- Keep a mapping table (concept -> icon name) in the design system.
- Illustrations: one style (line, flat, 3D) and palette tied to tokens; spot illustrations 80-160px in-product; hide from AT when decorative; avoid culturally specific gestures/people stereotypes; ensure dark mode variants.
- Avoid emoji as UI icons (inconsistent cross-platform rendering, verbose screen reader output).

## Implementation Guidance

Label decision table:

| Context | Label? |
|---|---|
| Primary navigation | Visible text label always (desktop); bottom tab bars: icon + short label |
| Primary/secondary buttons | Text with optional leading icon |
| Toolbar of common editor actions (bold, italic) | Icon-only OK + tooltip + aria-label + shortcut hint |
| Close (X) in dialog | Icon-only OK with `aria-label="Close"` |
| Table row actions | Overflow menu with text items, or icon + tooltip for 1-2 universal actions |
| Status badges | Icon + text |
| Unfamiliar domain actions | Always text |

Icon library comparison (verify licenses before use):

| Library | Style | License | Notes |
|---|---|---|---|
| Lucide (`lucide-react`) | Stroke, 24 grid | ISC | shadcn/ui default; tree-shakable |
| Heroicons | Outline/solid/mini/micro | MIT | Tailwind Labs |
| Phosphor | 6 weights | MIT | Large set |
| Material Symbols | Variable font (fill, weight, grade, optical size) | Apache-2.0 | Font or SVG; subset for perf |
| Tabler Icons | Stroke | MIT | Large set |
| Radix Icons | 15px crisp | MIT | Small set |
| Font Awesome Free | Mixed | Icons CC BY 4.0, code MIT | Pro is commercial |
| SF Symbols | Apple platforms | Apple license restricts use to Apple platform apps | Not for web products |

```tsx
// components/icon-button.tsx — accessible icon-only button with tooltip
"use client";
import * as Tooltip from "@radix-ui/react-tooltip";
import type { LucideIcon } from "lucide-react";

export function IconButton({ icon: Icon, label, shortcut, ...props }: { icon: LucideIcon; label: string; shortcut?: string } & React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <Tooltip.Root>
      <Tooltip.Trigger asChild>
        <button type="button" aria-label={label} className="inline-flex size-9 items-center justify-center rounded-md hover:bg-neutral-100 focus-visible:outline-2" {...props}>
          <Icon aria-hidden="true" className="size-5" />
        </button>
      </Tooltip.Trigger>
      <Tooltip.Portal>
        <Tooltip.Content sideOffset={6} className="rounded bg-neutral-900 px-2 py-1 text-xs text-white">
          {label}{shortcut && <kbd className="ml-2 opacity-70">{shortcut}</kbd>}
        </Tooltip.Content>
      </Tooltip.Portal>
    </Tooltip.Root>
  );
}
```

```tsx
// Status with icon + text (not color-only)
import { CircleCheck, TriangleAlert, CircleX } from "lucide-react";
const map = {
  paid: { Icon: CircleCheck, text: "Paid", cls: "text-green-800 bg-green-50" },
  overdue: { Icon: TriangleAlert, text: "Overdue", cls: "text-amber-900 bg-amber-50" },
  failed: { Icon: CircleX, text: "Payment failed", cls: "text-red-800 bg-red-50" },
} as const;
export function InvoiceStatus({ status }: { status: keyof typeof map }) {
  const { Icon, text, cls } = map[status];
  return <span className={`inline-flex items-center gap-1 rounded px-2 py-0.5 text-sm ${cls}`}><Icon aria-hidden className="size-4" />{text}</span>;
}
```

```tsx
// Meaningful standalone SVG (e.g., inline chart-less indicator) needs a name
<svg role="img" aria-labelledby="sync-title" viewBox="0 0 24 24" className="size-5"><title id="sync-title">Syncing</title>{/* paths */}</svg>
```

RTL flipping: `className="rtl:-scale-x-100"` on directional icons only.

## Recommended Workflow
1. Pick one icon library matching brand style; record license.
2. Create a concept -> icon mapping table; add to design system docs.
3. Decide label rules per context (table above).
4. Wrap icons in components (`Icon`, `IconButton`, `StatusBadge`) enforcing `aria-hidden` / labels.
5. Choose illustration style and sizes; produce light/dark variants; optimize SVGs (SVGO).
6. Test with screen reader, RTL, dark mode, 200% zoom.

## Patterns
- **Leading icon button**: icon + text, icon `aria-hidden`.
- **Icon-only with tooltip + aria-label** for dense toolbars.
- **Status badge**: icon + text + tinted background.
- **Empty-state spot illustration**: 96-160px, decorative, tokenized colors.
- **Icon + count** ("💬 12" -> use `MessageSquare` + "12 comments" accessible name).
- **SVG sprite** (`<use href="/sprite.svg#id">`) for very large icon counts.

## Anti-Patterns
- **Mystery-meat navigation** (icon-only sidebar without labels/tooltips) — Fix: labels or expandable rail with tooltips.
- **Mixed libraries** (outline Heroicons + filled Material) — Fix: one family.
- **Same icon, different meanings** (gear = settings and = integrations) — Fix: mapping table.
- **Unlabeled icon buttons** — screen reader says "button". Fix: `aria-label`.
- **Labeled decorative icons** — duplicate announcements ("check icon Paid"). Fix: `aria-hidden` when text present.
- **Importing entire icon packs** (`import * as Icons`) — bundle bloat. Fix: named imports.
- **Icon fonts for UI icons** — FOIT, poor a11y, blocked fonts show boxes. Fix: SVG components (variable Material Symbols font acceptable with subsetting and `aria-hidden`).
- **Huge hero illustrations in app screens** — push content down. Fix: small spot illustrations.

## Accessibility
- Non-text content (1.1.1): meaningful icons have text alternatives; decorative `aria-hidden="true"` / `alt=""`.
- Use of color (1.4.1) and non-text contrast (1.4.11): meaningful icons at 3:1 against background.
- Label in name (2.5.3): if a tooltip/visible label exists, `aria-label` should match it.
- Target size (2.5.8): 24x24 minimum.
- Tooltips accessible via focus, dismissible (1.4.13).
- Sensory characteristics (1.3.3): don't instruct "click the gear icon" only.

## Responsive Design
- Bottom tab bars on mobile: icon + short label, max 5.
- Collapse text buttons to icon-only on small screens only if accessible names and tooltips remain; prefer overflow menus.
- Scale illustrations down or hide on small screens.

## Performance
- Tree-shake icon imports; `lucide-react` named imports are tree-shaken; in Next.js, `optimizePackageImports` includes common icon libraries by default (e.g., lucide-react) to speed dev/builds.
- Inline small SVGs in Server Components (zero JS); avoid client components just for icons.
- Optimize illustrations with SVGO; use `next/image` for raster illustrations; lazy-load below-the-fold.

## Security
- Sanitize user-uploaded SVGs (can contain scripts); serve with `Content-Disposition`/CSP or rasterize; never inject untrusted SVG via `dangerouslySetInnerHTML`.

## Testing
- axe: `button-name`, `svg-img-alt`, `image-alt`.
- Visual regression for icon alignment and dark mode.
- Unit test that `IconButton` requires `label` (TypeScript required prop).

## Tooling
- lucide-react, @heroicons/react, @phosphor-icons/react, Material Symbols; SVGO / SVGR; Figma icon plugins (Iconify); unDraw (open license, check terms), Storyset/Humaaans (check attribution requirements).

## Framework Notes
- **Next.js (App Router)**: icons render in Server Components without `"use client"`; only interactive wrappers (tooltips) need client code; `next/image` for PNG/WebP illustrations, SVG imports via SVGR require webpack/turbopack config or use inline components.
- **React (Vite SPA)**: `vite-plugin-svgr` for `?react` SVG imports; named icon imports for tree-shaking.

## AI Agent Guidance
- Do: use the project's existing icon library; pair icons with text; add `aria-hidden` to decorative icons and `aria-label` to icon-only buttons; keep sizes on the scale.
- Don't: add a second icon library; use emoji as icons; ship icon-only nav; import whole packs.
- Verify: axe `button-name` passes; icons inherit color in dark mode; directional icons flip in RTL.

## Examples
```tsx
// Nav item with icon + label and current state
import Link from "next/link";
import { FolderKanban } from "lucide-react";
<Link href="/projects" aria-current={active ? "page" : undefined} className="flex items-center gap-3 rounded-md px-3 py-2">
  <FolderKanban aria-hidden className="size-5" />
  <span>Projects</span>
</Link>
```

## Related Skills
- [empty-states](../empty-states/Skill.md) — spot illustrations
- [buttons-and-actions](../buttons-and-actions/Skill.md) — icon buttons
- [tooltips](../tooltips/Skill.md) — labeling icon-only controls
- [accessible-images-and-media](../accessible-images-and-media/Skill.md) — alt text
- [color-contrast-and-non-color-cues](../color-contrast-and-non-color-cues/Skill.md) — non-color status cues
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md) — RTL icon flipping
- [bundle-optimization](../bundle-optimization/Skill.md) — tree-shaking icon libraries

## Sources
- [NN/g: Icon Usability](https://www.nngroup.com/articles/icon-usability/) — Community (research) — labels, few universal icons
- [Material Design 3: Icons](https://m3.material.io/styles/icons/overview) — Official — Material Symbols variable axes, sizes
- [Apple HIG: Icons / SF Symbols](https://developer.apple.com/design/human-interface-guidelines/icons) — Official — consistency; SF Symbols licensing limits
- [Lucide](https://lucide.dev/) — Open Source (ISC)
- [Heroicons](https://heroicons.com/) — Open Source (MIT)
- [WAI: Images tutorial (decorative, functional)](https://www.w3.org/WAI/tutorials/images/) — Official
- [Next.js: optimizePackageImports](https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports) — Official

## License / Usage Notes
Library licenses summarized from their repos; verify before commercial use. Code original.

## Quality Tier
A — research and official guidance, with concrete accessible React patterns; Material icon page content was only partially retrievable during verification.

## Status
Active

## Last Verified
2026-09-15
