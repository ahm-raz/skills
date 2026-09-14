# Information Architecture

## Summary
Information architecture (IA) is the structure, organization and labeling of content and features so users can find things and understand where they are. For frontend engineers it materializes as route structure, navigation menus, URL design, page titles, breadcrumbs, search and cross-links.

## Category
UX

## Subcategories
navigation structure, labeling, taxonomy, card sorting, tree testing, URL design, wayfinding, search, sitemaps

## Problem It Solves
Features get organized by org chart or database schema rather than user mental models, producing menus with jargon, deep nesting, duplicated destinations and "where did that setting go?" support tickets. Routes and URLs become impossible to evolve.

## When To Use
- New product/section, navigation redesign, or merging products.
- Growth past ~7-10 top-level nav items or 3+ levels deep.
- Analytics show heavy search for things that exist in nav, or high pogo-sticking.

## When Not To Use
- Single-task tools (a one-screen utility needs no IA exercise).
- Visual styling of menus (see navigation-menus-and-sidebars).

## Core Principles
1. **Organize by user tasks and mental models**, not internal structure (NN/g heuristic 2: match the real world).
2. **Labels must be self-explanatory and distinct**; information scent tells users what's behind a link.
3. **Broad and shallow beats narrow and deep** for most apps: aim for <= 3 levels.
4. **Every page answers: Where am I? What can I do here? Where can I go?**
5. **One canonical home per object**; other places link to it (avoid duplicate editable copies).
6. **URLs are part of IA**: human-readable, stable, hierarchical where hierarchy is real.
7. **Validate with users** (card sort to generate, tree test to evaluate) before building nav.
8. **Search complements, never replaces, navigation.**

## Best Practices
- Top-level nav: 5-9 items max; group rest under clear categories.
- Use nouns for destinations ("Invoices"), verbs for actions ("Create invoice").
- Avoid vague labels: "Resources", "Solutions", "Tools", "Misc", "More" (unless truly overflow).
- Front-load distinctive words: "Billing settings" vs "Settings for billing".
- Keep label text identical across nav item, page `<title>`, and `<h1>`.
- Mark current location (`aria-current="page"`) and show breadcrumbs for 3+ level hierarchies.
- Object-oriented UX: identify core objects (Project, Invoice, Member), their relationships and actions; nav mostly lists objects.
- Settings split: account (personal) vs workspace/org (admin) vs object-level settings next to the object.
- Provide a global search/command palette for large apps; index objects and settings.

## Implementation Guidance

Route design decision table:

| Situation | Route pattern | Example |
|---|---|---|
| Collection | `/resource` | `/projects` |
| Item | `/resource/:id` | `/projects/p_123` |
| Sub-view of item | `/resource/:id/tab` | `/projects/p_123/members` |
| Nested owned object | `/parent/:id/child/:childId` (max 2 levels) | `/projects/p_123/tasks/t_9` |
| Filters/sort/pagination | query string | `/projects?status=active&page=2` |
| Tenant scope | path prefix | `/acme/projects` |
| Modal detail with deep link | intercepting/parallel routes or `?open=id` | `/projects?task=t_9` |

- Put UI state that should survive reload/share in the URL (tabs, filters, selected item).
- Use slugs plus stable IDs when SEO matters: `/docs/getting-started` or `/p/123-my-post`.
- Maintain redirects when restructuring (`301` for public pages).

IA artifact to keep in repo (as data, drives nav + breadcrumbs + sitemap):

```ts
export const nav = [
  { label: "Projects", href: "/projects", children: [
      { label: "All projects", href: "/projects" },
      { label: "Templates", href: "/projects/templates" } ] },
  { label: "Invoices", href: "/invoices" },
  { label: "Reports", href: "/reports" },
  { label: "Settings", href: "/settings", section: "secondary" },
] as const satisfies NavItem[];
```

## Recommended Workflow
1. Content/feature inventory (spreadsheet: item, owner, audience, frequency).
2. Identify core objects and top tasks (surveys, analytics, support tickets).
3. Open card sort (15-30 participants) to learn groupings and vocabulary.
4. Draft hierarchy + labels; closed card sort or tree test (50+ participants for quant) with 8-10 realistic tasks.
5. Iterate until task success > ~80% and directness is high.
6. Encode as route map + nav config; add breadcrumbs, titles, redirects.
7. Monitor: search logs (zero-result queries), nav click analytics, tree re-tests after big changes.

## Patterns
- **Hub and spoke**: dashboard hub linking to focused tasks (mobile-friendly).
- **Nested doll**: category -> subcategory -> item with breadcrumbs (docs, catalogs).
- **Faceted classification**: multiple attributes filterable (e-commerce, asset libraries).
- **Object-first nav + contextual actions**: nav lists objects; actions live on object pages.
- **Global + local nav**: persistent top/side nav, plus in-page tabs for object sub-views.

## Anti-Patterns
- **Org-chart navigation** ("Growth team tools") — Fix: task/object-based labels from card sort.
- **Same thing, multiple names** ("Workspace", "Team", "Org") — Fix: controlled vocabulary glossary enforced in copy review.
- **Deep nesting (4+ levels)** — Fix: flatten, use facets or search.
- **Clicking a parent nav item only expands** with no landing page, when users expect a page — Fix: make parent link to overview or clearly be a disclosure button.
- **State not in URL** — can't share or refresh. Fix: URL-sync filters/tabs.
- **Mystery-meat icons in nav** — Fix: labels always visible on desktop.
- **Breaking URLs on redesign** — Fix: redirect map and link checker.

## Accessibility
- Consistent navigation across pages (3.2.3) and consistent identification (3.2.4).
- Multiple ways to find pages (2.4.5): nav plus search or sitemap.
- Page titles descriptive (2.4.2); `aria-current="page"`; `nav` landmarks with distinct `aria-label`s.
- Link purpose clear from text (2.4.4).

## Responsive Design
- Same IA across breakpoints; only presentation changes (drawer, bottom tabs max 5).
- Mobile bottom nav: top 3-5 destinations; rest in "More" or menu.
- Don't hide critical destinations only in desktop hover menus.

## Performance
- Prefetch likely next routes from nav (framework link prefetching).
- Code-split by route; IA with clean route boundaries enables that.

## Security
- Hide nav items the user cannot access, but always enforce authorization server-side; hidden != protected.
- Avoid putting sensitive data (emails, tokens) in URLs; they leak via logs and Referer.

## Testing
- Tree testing (Optimal Workshop Treejack, Maze) for findability.
- E2E: every nav config entry resolves (no 404), breadcrumbs match hierarchy.
- Link checker in CI (lychee, linkinator); analytics on zero-result searches.

## Tooling
- Optimal Workshop (card sort, tree test), Maze, UXtweak; FigJam/Miro for sitemaps; lychee link checker.

## Framework Notes
- **Next.js (App Router)**: file-system routes mirror IA; use route groups `(marketing)`/`(app)` for different layouts without URL segments; `generateMetadata` for titles matching nav labels; `redirects` in `next.config.ts` when restructuring; intercepting routes for modal detail views with shareable URLs; `usePathname` for `aria-current`.
- **React (Vite SPA)**: centralize route definitions (React Router data routers or TanStack Router) and derive nav, breadcrumbs and document titles from route metadata (`handle` / `staticData`).

## AI Agent Guidance
- Do: check existing nav config and naming glossary before adding a page; reuse established labels; put shareable state in URL.
- Don't: add a new top-level nav item without justification; invent synonyms for existing objects; nest routes beyond 2 object levels.
- Verify: new page has title, h1 matching nav label, breadcrumb (if deep), reachable from nav or search, redirect for moved routes.

## Examples
```tsx
// app/(app)/_components/main-nav.tsx — nav driven by the IA config, marks current page
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { nav } from "@/lib/nav";

export function MainNav() {
  const pathname = usePathname();
  return (
    <nav aria-label="Main">
      <ul className="flex flex-col gap-1">
        {nav.filter((i) => i.section !== "secondary").map((item) => {
          const current = pathname === item.href || pathname.startsWith(item.href + "/");
          return (
            <li key={item.href}>
              <Link href={item.href} aria-current={current ? "page" : undefined}
                className="block rounded-md px-3 py-2 aria-[current=page]:bg-neutral-100 aria-[current=page]:font-semibold">
                {item.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
```

```tsx
// app/(app)/projects/[id]/members/page.tsx — title and h1 use the same label as nav
import type { Metadata } from "next";
import { getProject } from "@/lib/data";
export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  const project = await getProject(id);
  return { title: `Members · ${project.name}` };
}
```

```ts
// next.config.ts — keep old URLs working after restructuring
import type { NextConfig } from "next";
const config: NextConfig = {
  async redirects() {
    return [{ source: "/team/:path*", destination: "/settings/members/:path*", permanent: true }];
  },
};
export default config;
```

## Related Skills
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md) — rendering the nav
- [breadcrumbs](../breadcrumbs/Skill.md) — wayfinding component
- [user-flow-design](../user-flow-design/Skill.md) — task paths through the IA
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — findability via search
- [command-palette](../command-palette/Skill.md) — power-user navigation
- [settings-and-preferences-ux](../settings-and-preferences-ux/Skill.md) — organizing settings
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md) — route groups, intercepting routes

## Sources
- [NN/g Information Architecture topic](https://www.nngroup.com/topic/information-architecture/) — Community (research) — card sort/tree test guidance, information scent
- [NN/g 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) — Community — match real world, consistency
- [GOV.UK Service Manual](https://www.gov.uk/service-manual) — Official — task-based structure and plain labels
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — 2.4.x, 3.2.3/3.2.4

## License / Usage Notes
Principles summarized; code original. GOV.UK content is OGL v3.0.

## Quality Tier
A — established IA practice with engineering mapping; research-method numbers are typical ranges.

## Status
Active

## Last Verified
2026-09-15
