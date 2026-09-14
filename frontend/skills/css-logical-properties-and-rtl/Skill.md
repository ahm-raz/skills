# CSS Logical Properties and RTL

## Summary
Logical properties (`margin-inline-start`, `padding-block`, `inset-inline-end`, `inline-size`, `border-start-start-radius`) describe layout relative to writing mode and direction instead of physical left/right/top/bottom. Used with `dir` and `lang` attributes, they make right-to-left (Arabic, Hebrew, Persian, Urdu) and vertical writing modes work with one stylesheet. This skill covers the property mapping, RTL-specific pitfalls (icons, numbers, bidi text, transforms), Tailwind v4 logical utilities (expanded in 4.2), and Next.js i18n integration.

## Category
CSS & Styling

## Subcategories
Logical properties, writing modes, dir attribute, :dir(), bidi, unicode-bidi, mirroring icons, Tailwind logical utilities, RTL testing, next-intl locale direction

## Problem It Solves
Physical CSS (`margin-left`, `left: 0`, `text-align: left`) forces a separate RTL stylesheet or `[dir=rtl]` overrides everywhere, and it still misses cases: icons pointing the wrong way, broken mixed-direction text, and carousels scrolling backwards. Logical properties make direction-agnostic styles the default.

## When To Use
- Any app that is or may be localized into RTL languages.
- Design systems and component libraries (consumers may be RTL).
- All new CSS, since logical properties are Widely available and cost nothing.

## When Not To Use
- Genuinely physical effects that must not flip: shadows with a light-source direction, some illustrations, maps, media player progress in some locales (verify with native speakers), charts' time axes (often stay LTR).

## Core Principles
1. **Inline axis = text direction; block axis = line stacking direction.** In `horizontal-tb` LTR: inline-start = left; in RTL: inline-start = right.
2. **Set `dir` on `<html>` (and `lang`).** Don't use CSS `direction` for document direction; `dir` affects bidi algorithm, form controls, and accessibility.
3. **Default to logical properties and values**: `text-align: start`, `float: inline-start`, `inset-inline-start`, `margin-inline`, `padding-block`.
4. **Mirror what indicates direction** (back/forward arrows, progress, breadcrumbs chevrons, drawers). **Don't mirror** what doesn't (checkmarks, media play icons, clocks, logos, numbers).
5. **Isolate user-generated or mixed-direction text** with `<bdi>` or `dir="auto"` to prevent punctuation/number reordering bugs.
6. **Flexbox and grid already follow direction**; don't "fix" them with `row-reverse`.

## Best Practices
- Lint for physical properties (stylelint-plugin-logical-css or `stylelint-use-logical`).
- Use `inline-size`/`block-size` and `min-/max-inline-size` for sizing when orientation matters (vertical writing, form widths).
- Use `:dir(rtl)` (Baseline since 2023) rather than `[dir="rtl"] &` for direction-specific tweaks. It respects inherited direction.
- Mirror directional icons with `.icon-directional:dir(rtl) { scale: -1 1; }`.
- Transforms are physical: `translate: -100%` doesn't flip. Use a direction multiplier variable: `--dir: 1; :dir(rtl) { --dir: -1; } translate: calc(var(--dir) * -100%) 0;`.
- Scroll containers: `scrollLeft` semantics differ in RTL (negative values in modern browsers). Prefer `scrollIntoView`, `scroll-snap`, and logical `scroll-padding-inline`.
- Use `dir="auto"` on inputs/textareas accepting user text; use `<bdi>` for usernames/titles in UI strings.
- Pick fonts that support Arabic/Hebrew with matching vertical metrics; increase line-height for Arabic scripts if needed.
- Numbers: Arabic locales may use Arabic-Indic digits via `Intl.NumberFormat`. Let `Intl` decide, and keep phone numbers/codes LTR with `dir="ltr"` spans.

## Implementation Guidance

### Physical → logical mapping (horizontal writing mode)
| Physical | Logical |
|---|---|
| `margin-left` / `margin-right` | `margin-inline-start` / `margin-inline-end` |
| `margin-left + margin-right` | `margin-inline` |
| `margin-top` / `margin-bottom` | `margin-block-start` / `margin-block-end` (`margin-block`) |
| `padding-*` | `padding-inline-*`, `padding-block-*` |
| `left` / `right` | `inset-inline-start` / `inset-inline-end` |
| `top` / `bottom` | `inset-block-start` / `inset-block-end` |
| `width` / `height` | `inline-size` / `block-size` |
| `border-left` | `border-inline-start` |
| `border-top-left-radius` | `border-start-start-radius` |
| `text-align: left` | `text-align: start` |
| `float: left` | `float: inline-start` |
| `overflow-x` | `overflow-inline` (support limited; keep `overflow-x` for now) |
| `scroll-margin-left` | `scroll-margin-inline-start` |

### Tailwind v4 logical utilities
| Physical | Logical (v4) |
|---|---|
| `ml-4` / `mr-4` | `ms-4` / `me-4` |
| `pl-4` / `pr-4` | `ps-4` / `pe-4` |
| `mt-4` / `mb-4` | `mbs-4` / `mbe-4` (4.2+) |
| `pt-*` / `pb-*` | `pbs-*` / `pbe-*` (4.2+) |
| `left-0` / `right-0` | `inset-s-0` / `inset-e-0` (4.2+; `start-*`/`end-*` deprecated) |
| `border-l` / `border-r` | `border-s` / `border-e` |
| `border-t` / `border-b` | `border-bs` / `border-be` (4.2+) |
| `rounded-l-*` | `rounded-s-*`; corners `rounded-ss-*`, `rounded-se-*` |
| `w-*` / `h-*` | `inline-*` / `block-*` (4.2+), `max-inline-*`, `min-block-*` |
| `text-left` | `text-start` |
| `space-x-*` | use `gap-*` |
| Direction variants | `rtl:` / `ltr:` (e.g. `rtl:-scale-x-100`) |

### Mirroring decision guide
| Element | Mirror in RTL? |
|---|---|
| Back/next arrows, chevrons in breadcrumbs/pagination | Yes |
| Sidebar/drawer side, tab order, progress bars, sliders | Yes (automatic with logical CSS/flex) |
| Undo/redo, reply/forward icons | Usually yes |
| Media play/pause, checkmarks, search magnifier, clocks | No |
| Logos, brand marks, photos | No |
| Charts time axis, code editors, phone numbers, URLs | Typically LTR (confirm per locale) |

## Recommended Workflow
1. Set `lang` and `dir` on `<html>` from the active locale.
2. Convert physical properties to logical (codemod or lint autofix); Tailwind `ml`→`ms`, etc.
3. Mark directional icons (`data-directional` or a class) and mirror with `:dir(rtl)`.
4. Fix transforms/animations with a direction variable.
5. Apply `dir="auto"`/`<bdi>` for user content; wrap LTR-only fragments.
6. Test with pseudo-RTL (force `dir="rtl"` on English) and then with real Arabic/Hebrew content reviewed by native speakers.

## Patterns
**Direction multiplier for transforms**
```css
:root { --dir: 1; }
:root:dir(rtl), [dir="rtl"] { --dir: -1; }
.drawer[data-side="start"] { inset-inline-start: 0; translate: calc(var(--dir) * -100%) 0; }
.drawer[data-side="start"][data-open] { translate: 0 0; }
```

**Directional icon**
```css
.icon[data-directional]:dir(rtl) { scale: -1 1; }
```

**Bidi-safe user content**
```tsx
<p>{t("commentBy")} <bdi>{user.name}</bdi>: <span dir="auto">{comment.text}</span></p>
<input name="title" dir="auto" />
<span dir="ltr">+1 (555) 010-2345</span>
```

**Logical corner radius for attached controls**
```css
.input-group > :first-child { border-start-start-radius: var(--radius); border-end-start-radius: var(--radius); }
.input-group > :last-child  { border-start-end-radius: var(--radius); border-end-end-radius: var(--radius); }
```

## Anti-Patterns
- **Separate `rtl.css` overriding hundreds of rules.** Maintenance nightmare. Use logical properties.
- **`[dir=rtl] .x { margin-right: …; margin-left: 0 }` pairs.** Duplication, and misses nested direction changes. Use `margin-inline-start` or `:dir()`.
- **`flex-direction: row-reverse` for RTL.** Flex already follows `dir`, so this double-reverses. Remove it.
- **CSS `direction: rtl` instead of the `dir` attribute.** Bidi/accessibility issues. Set `dir` in HTML.
- **Mirroring every icon.** Wrong meaning (e.g. mirrored checkmark or play). Use the decision guide.
- **Physical `translate`/`left` animations.** Drawer slides in from the wrong side. Direction variable.
- **Concatenating translated strings with variables.** Word order breaks in RTL languages. Use ICU messages (next-intl/FormatJS).
- **`scrollLeft` math assuming positive values.** Broken carousels in RTL. Use `scrollBy({ left: dir * n })` with a detected sign, or scroll-snap + `scrollIntoView`.

## Accessibility
- `lang` on `<html>` (and on inline foreign-language fragments) is required for correct screen reader pronunciation (WCAG 3.1.1, 3.1.2).
- `dir` ensures correct reading and focus order visually matches DOM (1.3.2).
- Keyboard: arrow key semantics in RTL (e.g. slider, tabs) should follow visual direction. ARIA APG patterns note that Left/Right swap in RTL for horizontal widgets.
- Don't mirror text in images; provide localized assets.

## Responsive Design
Logical properties compose with responsive utilities (`md:ps-8`). Sidebars on `inline-start` automatically move to the right in RTL. Container queries use `inline-size`, which is inherently logical.

## Performance
No runtime cost. Eliminating separate RTL stylesheets reduces CSS size and avoids loading a second stylesheet on locale switch.

## Security
Bidi control characters (U+202E RLO etc.) in user content can spoof displayed text (e.g. file extensions, "Trojan Source"-style). Strip or neutralize bidi overrides in usernames/filenames, and use `<bdi>` isolation.

## Testing
- Visual regression in `dir="rtl"` for all components (Storybook global toolbar for direction; Playwright project with RTL locale).
- Pseudo-localization with RTL marks for early detection.
- Lint rule failing on physical properties (allow-list exceptions).
- Keyboard tests for arrow-key widgets in RTL.
- Native-speaker review for mirroring and typography.

## Tooling
- `stylelint-plugin-logical-css` / `stylelint-use-logical`. Community lint + autofix.
- Tailwind v4.2+ logical utilities; `rtl:`/`ltr:` variants. Official.
- Radix UI `DirectionProvider`, React Aria `I18nProvider` (automatic RTL handling in primitives).
- next-intl / FormatJS for ICU messages and locale data.
- Chrome DevTools: toggle `dir` on `<html>` quickly; Storybook `storybook-addon-rtl` (community).

## Framework Notes
- **Next.js App Router:** with `[locale]` segment routing (e.g. next-intl), set `<html lang={locale} dir={getDirection(locale)}>` in `app/[locale]/layout.tsx`. Compute direction with `new Intl.Locale(locale).getTextInfo?.().direction` (not universally available; fall back to a list: ar, he, fa, ur, ps, sd, yi, dv, ug, ckb). Keep it a Server Component, so correct `dir` is in the first HTML with no flash. Pass direction to Radix `DirectionProvider` (client) if using Radix primitives.
- **React (Vite SPA):** set `document.documentElement.dir`/`lang` when the locale changes (in an effect in the i18n provider), and render before first paint if the locale is known from URL/storage (inline script in `index.html`).
- **Component libraries:** shadcn/ui (Radix) and React Aria components support RTL via providers; custom components must use logical classes.

## AI Agent Guidance
- Do use logical properties and Tailwind logical utilities (`ms/me/ps/pe/inset-s/inset-e/text-start/border-s`) in all new code.
- Do set `lang` and `dir` on `<html>` from locale in the root/locale layout.
- Do mirror only directional icons; use a direction variable for transforms.
- Don't use `row-reverse`, a separate RTL stylesheet, or physical `left/right` for layout.
- Before done: toggle `dir="rtl"` and check layout, icons, drawers/animations, carousels, and arrow-key behavior; confirm no physical-property lint errors.

## Examples
```tsx
// app/[locale]/layout.tsx
import { notFound } from "next/navigation";
import { DirectionProvider } from "@/components/DirectionProvider"; // client wrapper around Radix DirectionProvider
import "../globals.css";

const LOCALES = ["en", "ar", "he", "de"] as const;
const RTL = new Set(["ar", "he", "fa", "ur"]);

export default async function LocaleLayout({ children, params }: { children: React.ReactNode; params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!LOCALES.includes(locale as (typeof LOCALES)[number])) notFound();
  const dir = RTL.has(locale) ? "rtl" : "ltr";
  return (
    <html lang={locale} dir={dir}>
      <body>
        <DirectionProvider dir={dir}>{children}</DirectionProvider>
      </body>
    </html>
  );
}
```
```tsx
// components/BackLink.tsx
import Link from "next/link";
import { ChevronLeft } from "lucide-react";

export function BackLink({ href, label }: { href: string; label: string }) {
  return (
    <Link href={href} className="inline-flex items-center gap-1 ps-1 pe-3 text-start hover:underline">
      <ChevronLeft aria-hidden className="size-4 rtl:-scale-x-100" />
      {label}
    </Link>
  );
}
```
```css
/* Toast sliding in from the inline-end edge in both directions */
.toast { position: fixed; inset-block-end: 1rem; inset-inline-end: 1rem; --dir: 1; }
.toast:dir(rtl) { --dir: -1; }
@starting-style { .toast { translate: calc(var(--dir) * 110%) 0; } }
.toast { transition: translate .25s ease-out; }
@media (prefers-reduced-motion: reduce) { .toast { transition: none; } }
```

## Related Skills
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md) — locale architecture
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — locale routing and messages
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — logical utilities
- [css-grid-and-flexbox-layout](../css-grid-and-flexbox-layout/Skill.md) — direction-aware layout
- [keyboard-navigation](../keyboard-navigation/Skill.md) — arrow keys in RTL
- [radix-ui-primitives](../radix-ui-primitives/Skill.md) — DirectionProvider
- [typography-systems](../typography-systems/Skill.md) — script-appropriate fonts

## Sources
- [MDN — CSS logical properties and values](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_logical_properties_and_values) — Official — property mapping
- [MDN — :dir()](https://developer.mozilla.org/en-US/docs/Web/CSS/:dir) — Official — direction pseudo-class
- [W3C — Structural markup and right-to-left text in HTML](https://www.w3.org/International/questions/qa-html-dir) — Official — dir attribute guidance
- [W3C — Inline markup and bidirectional text](https://www.w3.org/International/articles/inline-bidi-markup/) — Official — bdi, dir=auto
- [Tailwind CSS v4.3 blog (v4.2 logical utilities)](https://tailwindcss.com/blog/tailwindcss-v4-3) — Official — pbs/mbs/inset-s/border-bs/inline-* utilities, start/end deprecation
- [Material Design — Bidirectionality](https://m2.material.io/design/usability/bidirectionality.html) — Official — icon mirroring guidance
- [Radix UI — Direction Provider](https://www.radix-ui.com/primitives/docs/utilities/direction-provider) — Open Source — RTL in primitives
- [WAI-ARIA APG — Keyboard interface (RTL note)](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/) — Official — arrow key direction

## License / Usage Notes
MDN is CC-BY-SA, W3C documents are under the W3C license, and Tailwind/Radix are MIT. Material guidance is referenced conceptually. Code is original.

## Quality Tier
A — Official standards and verified Tailwind v4.2 utility names. Mirroring decisions still need native-speaker review.

## Status
Active

## Last Verified
2026-09-15
