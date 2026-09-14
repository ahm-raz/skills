# UI Design Principles for Engineers

## Summary
A compact, rule-based design toolkit for engineers who ship UI without a dedicated designer (or who must fill gaps in a spec). It turns perception psychology (Gestalt, Laws of UX), usability heuristics, and systematic-design ideas (constrained scales for spacing, type, color, shadow) into decisions you can make in code. The goal is interfaces that look intentional and are easy to use, not "pixel-perfect art".

## Category
UX

## Subcategories
visual design, design systems thinking, Gestalt principles, Laws of UX, spacing scales, typography basics, color usage, polish

## Problem It Solves
Engineer-built UIs typically fail in predictable ways: everything is the same weight, spacing is arbitrary, too many colors and borders, grey text on colored backgrounds, no states (hover/focus/disabled/loading/empty/error), and inconsistent components. This skill gives defaults and constraints that eliminate most of these failures before a designer ever looks.

## When To Use
- Building a feature with no mockup, or a mockup that only covers the happy path.
- Reviewing a PR whose UI "feels off" but nobody can say why.
- Setting up tokens/scales for a new app or internal tool.
- Guiding an AI agent that generates UI so the output is consistent rather than generic.

## When Not To Use
- A mature design system already specifies the decision: follow the system, raise gaps with its owners.
- Brand/marketing work that intentionally breaks conventions (see landing-page skills); still keep accessibility.
- Deep domain-specific data visualization choices (use the data-viz skills).

## Core Principles
1. **Start with the feature, not the layout.** Design the one task a screen supports first; add chrome (nav, sidebars) later.
2. **Constrain choices with scales.** Spacing, font sizes, radii, shadows and colors come from a small predefined set; never pick values ad hoc.
3. **Hierarchy is created by contrast of weight, size, and color, not size alone.** De-emphasize secondary content rather than only emphasizing primary content.
4. **Proximity communicates relationship** (Law of Proximity, Common Region). More space between groups than within them.
5. **Familiar beats novel** (Jakob's Law). Use conventional patterns for navigation, forms, tables, and controls.
6. **Fewer choices, faster decisions** (Hick's Law, Choice Overload). One primary action per view.
7. **Big, close targets are faster** (Fitts's Law). Minimum 24x24 CSS px (WCAG 2.5.8), 44x44 recommended for touch.
8. **Every component has states.** Default, hover, focus-visible, active, disabled, loading, empty, error, selected.
9. **Respond within 400ms** (Doherty Threshold); acknowledge input within 100ms.
10. **Aesthetics buy tolerance, not usability** (Aesthetic-Usability Effect). Polish never excuses broken flows; test anyway.

## Best Practices
- Spacing scale (4px base): `4, 8, 12, 16, 24, 32, 48, 64, 96`. Stop using values between them.
- Type scale: `12, 14, 16, 18, 20, 24, 30, 36, 48, 60`. Body text 16px on web; line-height 1.5 for body, 1.1-1.25 for large headings; line length 45-75 characters (`max-width: 65ch`).
- Use 2 font weights for UI text (regular 400, semibold 600); add bold 700 only for display.
- Color: 1 primary brand hue, 1 neutral ramp (9-11 steps), semantic hues (success, warning, danger, info). Each with 9-11 shades defined up front.
- On colored backgrounds, make secondary text a tint of the background hue rather than grey with opacity.
- Prefer fewer borders: separate with spacing, background tints, or subtle shadow instead.
- Shadows as elevation: define 3-5 levels; higher elevation = larger blur and offset.
- Align to a grid and a consistent left edge; center-align only short, standalone content.
- Label-value pairs: de-emphasize the label (smaller/lighter) and emphasize the value, or merge them ("12 left in stock").
- Buttons: one primary (filled), secondary (outline/tonal), tertiary (text). Destructive primary only inside a confirmation.
- Images with text overlay need a scrim/gradient to keep 4.5:1 contrast.
- Empty, loading and error states are designed alongside the happy path, not after.

## Implementation Guidance
Encode the constraints as tokens so the "right" value is also the easy one.

```css
:root {
  /* spacing */
  --space-1: 4px; --space-2: 8px; --space-3: 12px; --space-4: 16px;
  --space-6: 24px; --space-8: 32px; --space-12: 48px; --space-16: 64px;
  /* type */
  --text-xs: .75rem; --text-sm: .875rem; --text-base: 1rem; --text-lg: 1.125rem;
  --text-xl: 1.25rem; --text-2xl: 1.5rem; --text-3xl: 1.875rem; --text-4xl: 2.25rem;
  /* elevation */
  --shadow-1: 0 1px 2px rgb(0 0 0 / .06), 0 1px 3px rgb(0 0 0 / .10);
  --shadow-2: 0 4px 6px -1px rgb(0 0 0 / .10), 0 2px 4px -2px rgb(0 0 0 / .10);
  --shadow-3: 0 10px 15px -3px rgb(0 0 0 / .10), 0 4px 6px -4px rgb(0 0 0 / .10);
  /* radius */
  --radius-sm: 4px; --radius-md: 8px; --radius-lg: 12px;
}
```

Decision table — "how do I make X stand out / recede?"

| Goal | First lever | Second lever | Avoid |
|---|---|---|---|
| Emphasize primary | Weight 600 + darker color | Size step up | Adding more colors |
| De-emphasize secondary | Lighter color (neutral-600) | Smaller size | Opacity on colored bg |
| Group related items | Reduce spacing between them | Shared background | Borders everywhere |
| Separate sections | Larger spacing (32-48px) | Background change | Horizontal rules stacked |
| Call to action | Filled primary button | Placement at end of reading path | Two filled buttons side by side |
| Warn | Semantic color + icon + text | Placement near cause | Color alone |

Nested radius rule: `inner-radius = outer-radius - padding` (clamp at 0) so nested corners look concentric.

## Recommended Workflow
1. Write the job-to-be-done of the screen in one sentence; list data and actions needed.
2. Sketch in grayscale with real content (longest realistic strings, zero items, many items).
3. Establish hierarchy using weight/color/size from the scales.
4. Group with spacing; add containers only where spacing is insufficient.
5. Add color last: primary for actions, semantic for status.
6. Design all states (loading, empty, error, disabled, focus).
7. Check contrast, target sizes, keyboard path, 320px width and 200% zoom.
8. Squint test / blur screenshot: is the primary action still the most visible thing?

## Patterns
- **Label-value emphasis**: `<dt class="text-sm text-neutral-600">Plan</dt><dd class="text-base font-semibold">Team</dd>`.
- **Action bar**: primary right-most in dialogs/forms on desktop (or follow platform convention consistently); secondary to its left; destructive separated.
- **Card**: media, title (semibold), meta (small, muted), one primary action; whole card clickable only if it has a single destination.
- **Section header**: title + optional description + right-aligned action.
- **Stat**: large value, small label, trend with icon + text (not color only).

## Anti-Patterns
- **Arbitrary spacing (13px, 17px, 22px)** — creates visual noise. Fix: snap to scale tokens; lint for raw px values.
- **Grey text on colored background** — muddy, low contrast. Fix: use a hue-matched tint with verified contrast.
- **Every item bold** — no hierarchy. Fix: bold only the one thing per group users scan for.
- **Border soup** — tables, cards, inputs all boxed. Fix: remove borders, use spacing and alternating tints.
- **Multiple primary buttons** — decision paralysis. Fix: one primary, demote the rest.
- **Icon-only toolbar with no labels** — recall over recognition. Fix: visible labels or at minimum tooltips + `aria-label`.
- **Ignoring states** — flashes of blank, dead buttons. Fix: state checklist per component.
- **Novel custom controls** (custom scrollbars, fake selects) — break expectations and accessibility. Fix: native or well-tested headless primitives.

## Accessibility
- Text contrast 4.5:1 (1.4.3), large text 3:1; non-text UI and focus indicators 3:1 (1.4.11).
- Don't use color alone (1.4.1); pair with icon/text/pattern.
- Target size minimum 24x24 CSS px (2.5.8, WCAG 2.2 AA).
- Visible focus (2.4.7) and not obscured by sticky headers (2.4.11).
- Support 400% zoom / 320px reflow (1.4.10) and text spacing overrides (1.4.12).

## Responsive Design
- Design mobile-first content priority, then add columns.
- Scale spacing down one step on small screens (e.g., section gap 48 -> 32).
- Keep body text 16px on mobile (prevents iOS zoom on inputs too).
- Place primary actions within thumb reach on mobile; sticky bottom bars for long forms.

## Performance
- Limit font families (1-2) and weights (2-3) to reduce font payload.
- Prefer CSS shadows/gradients over images for decoration.
- Reserve space for media (aspect-ratio) to avoid layout shift.

## Security
- Visual design must not disguise security-relevant info (permissions, payment amounts, external links). Make destination domains and amounts legible.

## Testing
- Visual regression (Playwright screenshots / Chromatic) per state.
- Automated contrast checks (axe-core) in CI.
- Lint for off-scale values (Stylelint `declaration-strict-value`, Tailwind config without arbitrary values).
- 5-user hallway test on the primary task.

## Tooling
- Tailwind CSS (scales built in), Open Props, Radix Colors (accessible color ramps), Stylelint.
- Figma/Penpot for quick grayscale sketches.
- axe DevTools, Polypane for multi-viewport checks.

## Framework Notes
- **React (Vite SPA)**: expose variants (`size`, `tone`, `emphasis`) instead of free-form `className`/`style` props to keep choices constrained (`cva` / `tailwind-variants`); merge consumer classes with `tailwind-merge` only for layout overrides.
- **Next.js (App Router)**: keep presentational primitives as Server Components when they have no interactivity (no `"use client"`), so tokens/styles add zero client JS; load fonts via `next/font` to limit families/weights and avoid layout shift.

## AI Agent Guidance
- Do: use existing tokens/components before inventing; generate all states; use realistic content lengths; keep one primary action.
- Do: run a self-review against the anti-pattern list and a contrast check before finishing.
- Don't: introduce new colors, font sizes, or spacing outside the scale; don't add gradients/glassmorphism by default; don't produce icon-only buttons without accessible names.
- Verify before done: screenshot at 375px and 1440px, keyboard tab-through, axe run with zero serious violations.

## Examples
```tsx
// Constrained button API instead of free-form styling
import { cva } from "class-variance-authority";
export const button = cva(
  "inline-flex items-center justify-center gap-2 rounded-md font-semibold min-h-10 px-4 focus-visible:outline-2 focus-visible:outline-offset-2 disabled:opacity-50 disabled:cursor-not-allowed",
  {
    variants: {
      emphasis: {
        primary: "bg-brand-600 text-white hover:bg-brand-700",
        secondary: "border border-neutral-300 bg-white text-neutral-900 hover:bg-neutral-50",
        tertiary: "text-brand-700 hover:bg-brand-50",
        danger: "bg-red-600 text-white hover:bg-red-700",
      },
      size: { sm: "min-h-8 px-3 text-sm", md: "min-h-10 px-4 text-sm", lg: "min-h-12 px-6 text-base" },
    },
    defaultVariants: { emphasis: "secondary", size: "md" },
  }
);
```

## Related Skills
- [visual-hierarchy-and-layout](../visual-hierarchy-and-layout/Skill.md) — deeper treatment of hierarchy and grids
- [usability-heuristics](../usability-heuristics/Skill.md) — evaluation lens for the same principles
- [design-token-architecture](../design-token-architecture/Skill.md) — encoding scales as tokens
- [typography-systems](../typography-systems/Skill.md) — type scale details
- [color-systems](../color-systems/Skill.md) — building color ramps
- [spacing-and-layout-systems](../spacing-and-layout-systems/Skill.md) — spacing scale implementation
- [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md) — avoiding generic AI output

## Sources
- [Laws of UX](https://lawsofux.com/) — Community — Doherty Threshold, Fitts, Hick, Jakob, Gestalt laws
- [NN/g 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) — Community (research firm) — heuristic framing
- [Refactoring UI](https://www.refactoringui.com/) — Community (commercial book) — principles only: constrained scales, de-emphasis, fewer borders
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Open Source (MIT) — target sizes, nested radii, interactive state contrast
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — contrast, target size, focus criteria
- [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — Community — pre-delivery checklist concept for agents

## License / Usage Notes
Principles summarized in original wording; no text or figures copied from Refactoring UI (commercial) or NN/g. Vercel guidelines are MIT. Code examples are original.

## Quality Tier
A — grounded in established research and widely adopted guidelines; numeric scales are opinionated defaults, not universal truths.

## Status
Active

## Last Verified
2026-09-15
