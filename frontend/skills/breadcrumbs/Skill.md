# Breadcrumbs

## Summary
Breadcrumbs show where the current page sits in the site hierarchy and link to its ancestors. This skill covers the APG breadcrumb pattern (`nav` landmark, ordered list, `aria-current="page"`), design guidance from GOV.UK and NN/g (hierarchy not history, mobile collapse), structured data for SEO, and generating breadcrumbs from Next.js App Router segments.

## Category
Components

## Subcategories
Location navigation, hierarchy trail, mobile collapse, BreadcrumbList structured data, dynamic segments

## Problem It Solves
In deep sites (e-commerce categories, docs, admin records), users land from search on deep pages without context. Breadcrumbs orient them and give one-click access to parent levels. Implementations often show session history instead of hierarchy, make separators readable to screen readers, wrap badly on mobile, or show raw route segments ("[id]", UUIDs).

## When To Use
- Sites with ≥3 hierarchical levels: catalogs, documentation, knowledge bases, admin apps with nested records (Org › Project › Environment).
- Pages commonly entered directly (search, shared links).

## When Not To Use
- Flat 1–2 level sites.
- Linear flows (checkout, wizards): use a step indicator.
- As a replacement for primary or local navigation (NN/g: breadcrumbs supplement).
- To represent browsing history: use the browser Back button or a "Back to results" link.

## Core Principles
1. Show hierarchy, not history.
2. `<nav aria-label="Breadcrumb">` containing an ordered list of links from the root toward the current page.
3. The current page, if shown, is the last item, marked `aria-current="page"` and not styled as a link (or not a link).
4. Separators are decorative (CSS or `aria-hidden`), never read aloud.
5. Labels are human-readable page names, not slugs or ids.

## Best Practices
- Start with Home (or the app root / org name).
- Current page: APG includes it with `aria-current="page"`; GOV.UK ends at the parent (the `<h1>` already names the page). Pick one convention per product. Including it helps orientation when the h1 differs from the nav label.
- Place above the `<h1>`, below global navigation, and before `<main>` or at its very top consistently (GOV.UK places before `<main>` so skip links bypass it).
- Mobile: avoid multi-line wrapping. Collapse to first + last (GOV.UK `collapseOnMobile`), show only the parent as "‹ Parent", or truncate middle items behind an "…" disclosure.
- Truncate long labels with an ellipsis and keep the full name accessible (visible on focus or via the page title).
- Multiple-parent items (a product in two categories): pick a canonical parent consistently, or use the category the user navigated from only if it's also a valid hierarchy path.
- Add `BreadcrumbList` JSON-LD for search engines, matching the visible trail.

## Implementation Guidance

### Markup and ARIA
| Element | Markup |
|---|---|
| Container | `<nav aria-label="Breadcrumb">` |
| List | `<ol>` |
| Ancestor | `<li><a href="/docs">Docs</a></li>` |
| Current | `<li><a href="/docs/install" aria-current="page">Install</a></li>` or `<span aria-current="page">` |
| Separator | CSS `li + li::before { content: "/" / ""; }` (empty alt text) or an inline SVG with `aria-hidden="true"` |

Keyboard: no special handling; links are in normal tab order.

### Decision table
| Situation | Approach |
|---|---|
| Static docs/marketing hierarchy | Derive from file-system routes + a title map |
| Dynamic records (`/projects/[id]/settings`) | Fetch names on the server; pass labels from the page/layout |
| Very deep (>5 levels) on mobile | Collapse middle into "…" button (disclosure) or show parent only |
| shadcn/ui project | shadcn Breadcrumb components (`Breadcrumb`, `BreadcrumbList`, `BreadcrumbItem`, `BreadcrumbLink`, `BreadcrumbPage`, `BreadcrumbSeparator`, `BreadcrumbEllipsis`) |

## Recommended Workflow
1. Confirm hierarchy depth justifies breadcrumbs.
2. Define the canonical parent chain for every page type (including dynamic records).
3. Decide the current-page convention (APG include vs GOV.UK exclude).
4. Implement server-side label resolution (no client waterfalls).
5. Add a mobile collapse strategy.
6. Add JSON-LD `BreadcrumbList`.
7. Test screen reader output (separators silent, current page announced), wrapping at 320px.

## Patterns

### Breadcrumb component (Server Component)
```tsx
import Link from 'next/link';

export type Crumb = { href: string; label: string };

export function Breadcrumbs({ items }: { items: Crumb[] }) {
  const last = items.length - 1;
  return (
    <nav aria-label="Breadcrumb" className="breadcrumbs">
      <ol>
        {items.map((c, i) => (
          <li key={c.href}>
            {i === last
              ? <span aria-current="page">{c.label}</span>
              : <Link href={c.href}>{c.label}</Link>}
          </li>
        ))}
      </ol>
    </nav>
  );
}
```
```css
.breadcrumbs ol { display: flex; flex-wrap: wrap; gap: .25rem; list-style: none; padding: 0; }
.breadcrumbs li + li::before { content: "/" / ""; margin-inline-end: .25rem; color: var(--muted); }
.breadcrumbs [aria-current="page"] { font-weight: 600; }
@media (max-width: 40rem) {
  .breadcrumbs li:not(:first-child):not(:nth-last-child(-n+2)) { display: none; } /* keep first, parent, current */
}
```
`content: "/" / ""` gives the separator empty alternative text. Where that syntax isn't supported, the declaration is dropped, so provide a fallback declaration first, or use `aria-hidden` SVG separators.

### Dynamic record trail with server-resolved labels
```tsx
// app/orgs/[org]/projects/[project]/settings/page.tsx
export default async function Settings({ params }: { params: Promise<{ org: string; project: string }> }) {
  const { org, project } = await params;
  const [o, p] = await Promise.all([getOrg(org), getProject(org, project)]); // enforce access here
  return (
    <>
      <Breadcrumbs items={[
        { href: '/orgs', label: 'Organizations' },
        { href: `/orgs/${org}`, label: o.name },
        { href: `/orgs/${org}/projects/${project}`, label: p.name },
        { href: `/orgs/${org}/projects/${project}/settings`, label: 'Settings' },
      ]} />
      <h1>Project settings</h1>
    </>
  );
}
```

### JSON-LD
```tsx
export function BreadcrumbJsonLd({ items, origin }: { items: Crumb[]; origin: string }) {
  const data = {
    '@context': 'https://schema.org', '@type': 'BreadcrumbList',
    itemListElement: items.map((c, i) => ({ '@type': 'ListItem', position: i + 1, name: c.label, item: origin + c.href })),
  };
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, '\\u003c') }} />;
}
```
Escape `<` so user-controlled names can't break out of the script tag.

## Anti-Patterns
- **History-based trails**: long, repetitive, inconsistent. Fix: hierarchy.
- **Separators as text in links or spans read aloud** ("slash, Docs, slash…"): Fix: CSS pseudo-content with empty alt or `aria-hidden`.
- **Current page as a live link identical to the others**: Fix: `aria-current` + distinct styling (or plain text).
- **Raw segments/UUIDs as labels**: Fix: resolve names server-side.
- **Client-side fetching of each crumb label**: waterfalls and CLS. Fix: fetch on the server with the page data.
- **`<div>` list without nav landmark**: not discoverable. Fix: `nav` + `ol`.
- **Tiny touch targets crammed on mobile**: Fix: collapse; ≥24px targets (aim 44px).
- **Breadcrumbs as the only way to navigate up**: Fix: keep sidebar/local nav.

## Accessibility
- WCAG 2.4.8 Location (AAA), 2.4.5 Multiple Ways, 1.3.1 Info and Relationships (ordered list), 2.4.4 Link Purpose, 2.5.8 Target Size, 1.4.10 Reflow.
- Screen readers should hear "Breadcrumb navigation, list, 4 items … current page, Settings".

## Responsive Design
- Collapse middle items on narrow screens (first + parent + current, or parent-only back link).
- Avoid horizontal scrolling breadcrumbs unless they scroll to the end by default and have visible overflow cues.
- RTL: separators should be direction-neutral (`/`) or mirrored chevrons.

## Performance
- Pure server-rendered markup; zero client JS unless using an interactive ellipsis disclosure.
- Batch label lookups with the page's data fetching (`Promise.all`, request memoization via `React.cache`).

## Security
- Label resolution must respect authorization. Don't reveal names of orgs or projects the user can't access (return 404 before rendering).
- Escape JSON-LD content.

## Testing
- Testing Library: `getByRole('navigation', {name:'Breadcrumb'})`, `within(nav).getAllByRole('listitem')`, current item has `aria-current="page"`.
- Playwright: mobile viewport collapse; links navigate to correct ancestors.
- Validate structured data with Google's Rich Results Test (manual) or schema validators in CI.

## Tooling
- shadcn/ui Breadcrumb (with `BreadcrumbEllipsis` + DropdownMenu for collapsed items).
- Next.js `useSelectedLayoutSegments` (client) for simple static-hierarchy trails.

## Framework Notes
- **React (Vite SPA)**: With React Router data routers, attach `handle: { crumb: (data) => ({ href, label }) }` to routes and build the trail from `useMatches()`. Labels come from loader data (no extra fetches). TanStack Router offers similar route context/loader data.
- **Next.js (App Router)**: Prefer Server Components that receive resolved labels from the page. For hierarchy that mirrors folders, a client `useSelectedLayoutSegments()` + static title map works, but it can't resolve dynamic names without fetching. Alternatively render crumbs in each `page.tsx` or in a parallel route slot (`@breadcrumbs`) so each route provides its own trail. Use `React.cache` to share the record fetch between `generateMetadata`, the breadcrumb, and the page. Keep crumbs out of `loading.tsx` shells that would flash placeholder labels.

## AI Agent Guidance
- DO use `nav[aria-label="Breadcrumb"] > ol > li`; DO mark the current page with `aria-current`.
- DO resolve human-readable labels server-side and enforce access before rendering.
- DON'T show history trails, raw slugs, or read-aloud separators.
- Verify: separators silent in a screen reader; mobile layout at 320px; JSON-LD matches the visible trail; convention (include/exclude current) consistent.

## Examples
shadcn/ui Breadcrumb with collapsed middle items:
```tsx
import Link from 'next/link';
import {
  Breadcrumb, BreadcrumbList, BreadcrumbItem, BreadcrumbLink, BreadcrumbPage, BreadcrumbSeparator, BreadcrumbEllipsis,
} from '@/components/ui/breadcrumb';

<Breadcrumb>
  <BreadcrumbList>
    <BreadcrumbItem><BreadcrumbLink asChild><Link href="/">Home</Link></BreadcrumbLink></BreadcrumbItem>
    <BreadcrumbSeparator />
    <BreadcrumbItem><BreadcrumbEllipsis /></BreadcrumbItem>{/* wrap in a DropdownMenu listing hidden levels */}
    <BreadcrumbSeparator />
    <BreadcrumbItem><BreadcrumbLink asChild><Link href="/docs/components">Components</Link></BreadcrumbLink></BreadcrumbItem>
    <BreadcrumbSeparator />
    <BreadcrumbItem><BreadcrumbPage>Breadcrumb</BreadcrumbPage></BreadcrumbItem>
  </BreadcrumbList>
</Breadcrumb>
```
If `BreadcrumbEllipsis` is purely visual, make the collapsed levels reachable: wrap it in a menu trigger button with an accessible name ("Show more breadcrumbs").

## Related Skills
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md): primary navigation
- [landmarks-and-accessible-navigation](../landmarks-and-accessible-navigation/Skill.md): nav landmarks
- [information-architecture](../information-architecture/Skill.md): hierarchy design
- [seo-for-frontend](../seo-for-frontend/Skill.md): structured data
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md): JSON-LD in Next.js
- [documentation-site-patterns](../documentation-site-patterns/Skill.md): docs trails
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md): category trails

## Sources
- [WAI-ARIA APG: Breadcrumb Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/) — Official — nav landmark, label, aria-current
- [GOV.UK Design System: Breadcrumbs](https://design-system.service.gov.uk/components/breadcrumbs/) — Official design system — when to use, collapseOnMobile, placement, current page excluded
- [NN/g: Breadcrumbs guidelines](https://www.nngroup.com/articles/breadcrumbs/) — Research — hierarchy not history, mobile, supplementary role

## License / Usage Notes
Summarized in original wording; code original. GOV.UK content OGL v3; shadcn MIT.

## Quality Tier
A — APG + GOV.UK + NN/g with Next.js server-side implementation.

## Status
Active

## Last Verified
2026-09-15
