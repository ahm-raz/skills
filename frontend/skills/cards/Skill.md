# Cards

## Summary
Cards group information about one entity (article, product, project, person) into a scannable unit, usually in a grid or list. This skill covers semantic card structure (list items, heading-first source order), making whole cards clickable without breaking accessibility, secondary actions, consistent layout, images, and React/Next.js component APIs.

## Category
Components

## Subcategories
Content cards, product cards, clickable cards, card grids, media cards, stat cards, selectable cards

## Problem It Solves
Cards look simple, but they're often built as a `<div onClick>` wrapped around everything. That gives no keyboard access, redundant links ("Read more" × 20), whole-card links that swallow buttons, unselectable text, and screen readers reading the image and metadata before the title. Card grids also cause layout shift and uneven heights.

## When To Use
- Browsing collections of heterogeneous entities where a summary helps choose (blog index, products, projects, templates).
- Dashboards with discrete, self-contained summaries.
- Selecting one or more options with rich descriptions (plan picker as selectable cards).

## When Not To Use
- Data users compare across attributes: use a table.
- Dense lists of homogeneous items (email, logs): use a list.
- A single piece of content: no card chrome needed.
- Decorative boxes around every page section ("card soup").

## Core Principles
1. A card in a collection is a list item (`<ul>`/`<li>`), so screen readers announce the count and users can skip between items.
2. The heading comes first in source order; its link is the primary action. Images and metadata can appear visually above via CSS.
3. One primary link per card. Avoid duplicate "Read more" links pointing to the same URL.
4. A whole-card click target must not break secondary actions, text selection, or semantics.
5. Card content length varies, so the layout must absorb it (consistent heights, clamped text with access to the full text).

## Best Practices
- Stretched-link technique: the heading link's `::after` covers the card. Secondary actions get `position: relative; z-index: 1` to sit above it.
- Mirror hover affordance for keyboard users with `:focus-within` on the card.
- Keep secondary actions few (favorite, menu). Give them clear names that include the entity ("Save ‘Atlas’ to favorites").
- Images: meaningful → descriptive `alt`; decorative or redundant with the title → `alt=""`.
- Use `object-fit: cover` and a fixed `aspect-ratio` to prevent CLS.
- Push footers down with `margin-top: auto` in a flex column so rows align.
- Clamp long descriptions with `line-clamp`. Ensure the full text is available on the detail page.
- Selectable cards: use a real radio/checkbox inside the card with a label covering the card, not `div role="radio"`.

## Implementation Guidance

### Clickable card decision table
| Card content | Technique |
|---|---|
| Title + text, no other interactive elements | Stretched link on the heading link |
| Title + secondary buttons/links | Stretched link, secondary controls raised above it |
| Needs selectable text | Stretched link covers selection. Alternative: JS click handler on the card that ignores drags/selections and calls the heading link's `click()` |
| Choice between options | `<label>` wrapping a radio/checkbox (selectable card) |
| Entire card is an action (not navigation) | A single `<button>` containing only phrasing content, rare; avoid block content in buttons |

Never wrap a card containing other links or buttons in `<a>` (nested interactive content is invalid and unpredictable).

### Structure and ARIA
| Part | Markup |
|---|---|
| Collection | `<ul role="list">` (keep list semantics if `list-style: none` removes them in Safari) |
| Card | `<li>` > `<article>` (for standalone content) or `<div>` |
| Title | `<h3>` (level fits outline) > `<a href>` |
| Meta | `<p>`, `<time dateTime>` |
| Image | `<img alt>` placed after heading in DOM; visually first via `order: -1` |
| Secondary action | `<button aria-label="Save Atlas">` |

## Recommended Workflow
1. Decide if cards are the right presentation (vs table/list).
2. Define the card content model and primary action.
3. Build semantic markup: list > item > heading link > content.
4. Apply the clickable technique; raise secondary actions.
5. Layout: grid with `auto-fill`/`minmax`, container queries for card internals.
6. Handle images (aspect ratio, `next/image` sizes), empty/loading skeletons.
7. Test keyboard, screen reader list navigation, text selection, zoom.

## Patterns

### Accessible clickable card (Server Component)
```tsx
import Link from 'next/link';
import Image from 'next/image';

type Post = { slug: string; title: string; excerpt: string; date: string; image: string; imageAlt: string };

export function PostGrid({ posts }: { posts: Post[] }) {
  return (
    <ul role="list" className="grid">
      {posts.map((p) => (
        <li key={p.slug} className="card">
          <h3 className="card-title"><Link href={`/blog/${p.slug}`}>{p.title}</Link></h3>
          <p className="card-excerpt">{p.excerpt}</p>
          <p className="card-meta"><time dateTime={p.date}>{new Date(p.date).toLocaleDateString('en-GB')}</time></p>
          <Image className="card-img" src={p.image} alt={p.imageAlt} width={640} height={360}
            sizes="(min-width: 64rem) 33vw, (min-width: 40rem) 50vw, 100vw" />
        </li>
      ))}
    </ul>
  );
}
```
```css
.grid { display: grid; gap: 1.5rem; grid-template-columns: repeat(auto-fill, minmax(min(18rem, 100%), 1fr)); }
.card { position: relative; display: flex; flex-direction: column; container-type: inline-size; }
.card-img { order: -1; inline-size: 100%; aspect-ratio: 16 / 9; object-fit: cover; }
.card-title a::after { content: ""; position: absolute; inset: 0; }
.card:focus-within, .card:hover { box-shadow: 0 0 0 2px var(--focus); }
.card-title a:focus-visible { outline: none; } /* ring shown on card via :focus-within */
.card-excerpt { display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
.card-meta { margin-block-start: auto; }
.card :is(button, a:not(.card-title a)) { position: relative; z-index: 1; }
```
If you move the focus ring to the card, make sure it's clearly visible (WCAG 2.4.7/2.4.13). Otherwise keep the link's own focus outline.

### Card with secondary action (client leaf)
```tsx
'use client';
export function SaveButton({ id, title, saved }: { id: string; title: string; saved: boolean }) {
  return (
    <button type="button" aria-pressed={saved} aria-label={`Save ${title}`} onClick={() => toggleSave(id)}>
      <HeartIcon aria-hidden />
    </button>
  );
}
```
Keep the card a Server Component and import the small client button.

### Selectable plan cards
```tsx
<fieldset>
  <legend>Choose a plan</legend>
  {plans.map((p) => (
    <label key={p.id} className="plan-card">
      <input type="radio" name="plan" value={p.id} defaultChecked={p.id === 'pro'} />
      <span className="plan-name">{p.name}</span>
      <span className="plan-price">{p.price}</span>
    </label>
  ))}
</fieldset>
```
Style the checked card with `.plan-card:has(input:checked)`.

## Anti-Patterns
- **`<div onClick={() => router.push(...)}>`**: no keyboard, no link semantics, no middle-click or open-in-new-tab. Fix: real link + stretched pseudo-element.
- **`<a>` wrapping the whole card with buttons inside**: invalid nesting. Fix: stretched link + raised buttons.
- **"Read more" links ×N**: ambiguous link list (WCAG 2.4.4). Fix: make the title the link, or add visually hidden context.
- **Image first in DOM with verbose alt**: screen readers hear the alt before the title. Fix: heading first; image `alt=""` if redundant.
- **Uneven heights with buttons at random vertical positions**: Fix: flex column + `margin-top: auto`.
- **Cards without list semantics**: no item count. Fix: `ul/li`.
- **Hover-only reveal of actions**: invisible to touch and keyboard users. Fix: always visible, or reveal on `:focus-within` too.
- **Unsized images**: CLS. Fix: `width`/`height` or `aspect-ratio`.

## Accessibility
- WCAG 1.3.1 (list/heading structure), 2.4.4 Link Purpose, 2.4.7 Focus Visible, 1.1.1 Non-text Content, 2.5.8 Target Size for secondary actions, 1.4.10 Reflow, 1.4.11 Non-text Contrast for card boundaries that convey grouping (when relied upon).
- Screen reader users navigate by heading (H) and list item. Verify both work.

## Responsive Design
- Intrinsic grid: `repeat(auto-fill, minmax(min(18rem, 100%), 1fr))` avoids breakpoint juggling.
- Container queries for card internals (horizontal layout when the card is wide).
- On mobile, horizontal-scroll card rails need visible overflow cues and keyboard access (see carousels).

## Performance
- `next/image` with correct `sizes`. Only priority-load above-the-fold card images.
- For very long grids, paginate or virtualize (grid virtualization is harder; prefer pagination).
- `content-visibility: auto` with `contain-intrinsic-size` on off-screen cards can cut rendering cost; verify the engine support you need.

## Security
- Escape user-generated titles and excerpts (React does this by default; avoid `dangerouslySetInnerHTML`).
- Validate remote image hosts (`next.config` `images.remotePatterns`).

## Testing
- Testing Library: `getAllByRole('listitem')` count; `getByRole('link', {name: title})` has correct `href`; secondary button accessible names include the entity.
- Playwright: clicking a card body navigates; clicking the save button doesn't; Tab order is title link → secondary actions.
- Visual regression for grid alignment across content lengths.
- axe: link-name, image-alt, nested-interactive.

## Tooling
- shadcn/ui Card (presentational wrapper; add semantics yourself).
- `next/image`, Tailwind `line-clamp-*`, container queries.

## Framework Notes
- **React (Vite SPA)**: Cards are presentational. Use composition (`Card.Header/Title/Media/Actions`) or slots via props, and don't expose `onClick` on the root. Use React Router `<Link>` for the primary link. Memoization is rarely needed; virtualize or paginate long lists instead.
- **Next.js (App Router)**: Render card grids as Server Components. Only interactive bits (save, menu) are client leaves. `next/link` prefetches in-viewport links in production, so for huge grids consider `prefetch={false}` on card links to limit requests. `next/image` needs `sizes` for responsive grids. Use `loading.tsx`/Suspense skeletons that match card dimensions to avoid CLS.

## AI Agent Guidance
- DO render collections as lists with a heading link per card.
- DO use the stretched-link technique; raise secondary actions.
- DON'T use clickable divs or `router.push` on card click.
- DON'T nest interactive elements in anchors.
- Verify: keyboard reaches title link and actions; one link per destination; images sized; focus visible; screen reader announces list count and headings.

## Examples
Composable Card API (TypeScript):
```tsx
export function Card({ children, className }: { children: React.ReactNode; className?: string }) {
  return <article className={`card ${className ?? ''}`}>{children}</article>;
}
Card.Title = function Title({ href, children, level: H = 'h3' }: { href: string; children: React.ReactNode; level?: 'h2' | 'h3' | 'h4' }) {
  return <H className="card-title"><Link href={href}>{children}</Link></H>;
};
Card.Actions = function Actions({ children }: { children: React.ReactNode }) {
  return <div className="card-actions">{children}</div>;
};
```

## Related Skills
- [component-api-design](../component-api-design/Skill.md): composable card APIs
- [css-grid-and-flexbox-layout](../css-grid-and-flexbox-layout/Skill.md): intrinsic grids
- [container-queries](../container-queries/Skill.md): card internals
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md): card images
- [cls-prevention](../cls-prevention/Skill.md): sized media and skeletons
- [loading-states](../loading-states/Skill.md): card skeletons
- [kpi-and-stat-components](../kpi-and-stat-components/Skill.md): stat cards
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md): product cards

## Sources
- [Inclusive Components: Cards (Heydon Pickering)](https://inclusive-components.design/cards/) — Community (expert) — list structure, heading-first order, pseudo-element link, redundant click, focus-within, secondary actions
- [WCAG 2.2 Understanding 2.4.4 Link Purpose](https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html) — Official — ambiguous links
- [MDN: content-visibility](https://developer.mozilla.org/en-US/docs/Web/CSS/content-visibility) — Official — rendering optimization

## License / Usage Notes
Summarized in original wording; code original. shadcn/ui MIT.

## Quality Tier
B — strong expert source and WCAG basis, but no APG pattern exists and design-system card guidance (Material/Polaris) wasn't retrieved this pass.

## Status
Active

## Last Verified
2026-09-15
