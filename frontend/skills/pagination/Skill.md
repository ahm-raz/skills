# Pagination

## Summary
Pagination splits large result sets into pages navigated via links. This skill covers when to use numbered pagination vs "Load more" vs infinite scroll, accessible markup (nav landmark, `aria-current`, descriptive prev/next), ellipsis/truncation rules, URL-based page state, offset vs cursor APIs, and focus/scroll management after page changes in React and Next.js.

## Category
Components

## Subcategories
Numbered pagination, prev/next, load more, infinite scroll, cursor pagination, table pagination, URL state

## Problem It Solves
Big lists slow pages and overwhelm users. Implementations go wrong in several ways: pagination built from buttons (no URLs, no sharing, no Back), infinite scroll that hides the footer and loses position, tiny page targets, unannounced page changes, and offset queries that skip or duplicate items as data changes.

## When To Use
- Search results, catalogs, admin tables, archives where users want to know position, return to a spot, or share a page.
- When showing everything makes the page too slow, or most users only need the first pages (GOV.UK).

## When Not To Use
- Linear journeys (forms, wizards): use Continue/Back buttons.
- Only one page of results: don't render pagination.
- Feed-style browsing with no goal of returning to a position: "Load more" or infinite scroll (with safeguards) may fit better.
- Small datasets (<50 simple rows): show all, maybe with filtering.

## Core Principles
1. Pages are addressable: each page is a URL (`?page=3` or a cursor), so links work with Back, refresh, share, and open-in-new-tab.
2. Wrap in `<nav aria-label="Pagination">`; mark the current page with `aria-current="page"`.
3. Always show first, last, current and its neighbours; replace gaps with an ellipsis.
4. After a page change, bring the user to the start of the results and announce it.
5. Choose the data strategy (offset vs cursor) by dataset size and volatility.

## Best Practices
- Labels: "Previous page"/"Next page" (the visually hidden "page" adds context), numbers with a hidden "Page" prefix.
- Hide Previous on page 1 and Next on the last page (GOV.UK), or render them disabled as non-links. Don't render disabled `<a>` without `href` that still looks clickable.
- Mobile: show fewer numbers (current ±1, first, last) or just prev/next with "Page 3 of 12".
- Show a result summary: "Showing 41–60 of 1,284 results".
- Keep page size stable; offer a page-size select only in data-heavy admin contexts, and keep it in the URL.
- Load more: append results, move focus to the first new item (or announce "20 more results loaded"), and keep the URL updated (`?page=3`) so Back restores the position.
- Infinite scroll: offer a footer-reachable alternative, a "Load more" fallback, and position restoration. Consider the APG Feed pattern for accessible semantics.
- Cursor pagination for large or real-time data; offset for small, stable sets where jumping to page N matters.

## Implementation Guidance

### Pattern decision table
| Context | Pattern | Data API |
|---|---|---|
| Search results / catalog with jump-to-page | Numbered pagination | Offset/limit (cap max page), or keyset with page tokens |
| Admin table, large volatile data | Prev/next + page size | Cursor (`after`/`before`) |
| Social/news feed | Load more or infinite scroll + feed semantics | Cursor |
| E-commerce listing on mobile | Load more with URL sync | Cursor or offset |
| Very large known count | Numbered + "Go to page" input | Offset with limits / search engine |

### Markup
| Element | Attributes |
|---|---|
| `<nav>` | `aria-label="Pagination"` (unique if multiple, e.g., "Pagination, top") |
| List | `<ul>` of `<li>` |
| Page link | `<a href="?page=3">` with visually hidden "Page " prefix |
| Current | `<a aria-current="page" href="?page=4">` (or non-link text with `aria-current`) |
| Ellipsis | `<li aria-hidden="true">…</li>` or plain text "…" |
| Prev/Next | `<a rel="prev">`/`<a rel="next">` with "Previous page"/"Next page" |

### Truncation algorithm
```ts
export function pageItems(current: number, total: number, siblings = 1): (number | 'ellipsis')[] {
  const range = (a: number, b: number) => Array.from({ length: b - a + 1 }, (_, i) => a + i);
  if (total <= 5 + siblings * 2) return range(1, total);
  const start = Math.max(2, current - siblings);
  const end = Math.min(total - 1, current + siblings);
  return [
    1,
    ...(start > 2 ? ['ellipsis' as const] : []),
    ...range(start, end),
    ...(end < total - 1 ? ['ellipsis' as const] : []),
    total,
  ];
}
```

## Recommended Workflow
1. Choose the pattern (numbered / load more / infinite) using the decision table.
2. Choose the data API (offset vs cursor); define page size and the max page.
3. Put page state in the URL; read it on the server (Next.js `searchParams`) or router.
4. Render accessible pagination links with truncation.
5. Handle scroll/focus after navigation and announce changes for client-side updates.
6. Handle edge cases: out-of-range page (redirect to last page or 404), empty results, filters resetting page to 1.
7. Test keyboard, screen reader, Back/refresh, mobile.

## Patterns

### Server-rendered pagination (Next.js App Router)
```tsx
// app/products/page.tsx (Server Component)
import Link from 'next/link';
import { pageItems } from '@/lib/pagination';

export default async function Products({ searchParams }: { searchParams: Promise<{ page?: string }> }) {
  const { page: raw } = await searchParams;
  const page = Math.max(1, Number.parseInt(raw ?? '1', 10) || 1);
  const { items, total } = await getProducts({ page, pageSize: 24 });
  const pages = Math.max(1, Math.ceil(total / 24));
  const href = (p: number) => `/products?page=${p}`;

  return (
    <>
      <h1 id="results" tabIndex={-1}>Products</h1>
      <p>Showing {(page - 1) * 24 + 1}–{Math.min(page * 24, total)} of {total}</p>
      <ProductGrid items={items} />
      {pages > 1 && (
        <nav aria-label="Pagination">
          <ul className="pagination">
            {page > 1 && <li><Link rel="prev" href={href(page - 1)}>Previous<span className="sr-only"> page</span></Link></li>}
            {pageItems(page, pages).map((p, i) =>
              p === 'ellipsis'
                ? <li key={`e${i}`} aria-hidden="true">…</li>
                : <li key={p}><Link href={href(p)} aria-current={p === page ? 'page' : undefined}>
                    <span className="sr-only">Page </span>{p}</Link></li>)}
            {page < pages && <li><Link rel="next" href={href(page + 1)}>Next<span className="sr-only"> page</span></Link></li>}
          </ul>
        </nav>
      )}
    </>
  );
}
```
Next.js 15+ passes `searchParams` as a Promise. Next.js scrolls to the top on navigation and announces the new route's title/heading. When only the query changes, verify the announcement and consider moving focus to `#results`.

### Load more with URL sync and focus (client)
```tsx
'use client';
import { useRef } from 'react';

export function LoadMore({ items, hasMore, onLoadMore }: {
  items: { id: string; title: string }[]; hasMore: boolean; onLoadMore: () => Promise<number>;
}) {
  const listRef = useRef<HTMLUListElement>(null);
  const liveRef = useRef<HTMLParagraphElement>(null);
  return (
    <>
      <ul ref={listRef}>{items.map((it) => <li key={it.id}><a href={`/items/${it.id}`}>{it.title}</a></li>)}</ul>
      <p ref={liveRef} role="status" className="sr-only" />
      {hasMore && (
        <button type="button" onClick={async () => {
          const before = items.length;
          const added = await onLoadMore();
          liveRef.current!.textContent = `${added} more results loaded`;
          requestAnimationFrame(() => listRef.current?.querySelectorAll('a')[before]?.focus());
        }}>Load more results</button>
      )}
    </>
  );
}
```
With TanStack Query use `useInfiniteQuery`, and mirror the page count in the URL (`router.replace`) so Back restores the list.

### Cursor API contract
```ts
type Page<T> = { items: T[]; nextCursor: string | null; prevCursor: string | null };
// GET /api/orders?after=eyJpZCI6MTIzfQ&limit=50  -> opaque, signed/encoded cursor
```

## Anti-Patterns
- **Buttons with `onClick` state instead of links**: no URL, no Back, no new tab. Fix: `<a href>`/`<Link>`.
- **`aria-label="Page 3"` on a link that visually says "3" plus hidden text**: duplicate. Fix: one naming method.
- **Showing all 100 page numbers**: Fix: truncate with ellipses.
- **Page change without moving the user**: the user stays at the footer, confused. Fix: scroll/focus to results start.
- **Infinite scroll with an unreachable footer**: Fix: load more, or a footer outside the scroller.
- **Offset pagination on fast-changing data**: duplicates and skipped items. Fix: cursor/keyset.
- **Filters that don't reset page**: an empty page 9. Fix: reset to page 1 on filter change.
- **Unbounded `?page=999999`**: expensive queries. Fix: clamp and redirect.

## Accessibility
- WCAG 1.3.1, 2.4.4 Link Purpose, 2.4.3 Focus Order, 2.5.8 Target Size (≥ 24px; aim 44px on touch), 4.1.3 Status Messages for load-more announcements, 2.4.5 Multiple Ways.
- `aria-current="page"` plus a visual current state that doesn't rely on color alone.
- For infinite feeds, APG Feed pattern: `role="feed"`, `article` items with `aria-posinset`/`aria-setsize`, `aria-busy` while loading.

## Responsive Design
- Collapse to prev/next + "Page X of Y" under narrow container widths. Keep targets large.
- Don't let the pagination row overflow horizontally; wrap or reduce siblings.

## Performance
- Server-render pages (cacheable per URL). Prefetching neighbouring pages via `next/link` helps; limit it for large nav rows.
- Avoid `COUNT(*)` on huge tables for every request. Use estimates or "Next" without total.
- Cursor pagination keeps queries index-friendly.

## Security
- Validate and clamp `page`/`limit`. Sign or encode cursors and don't expose raw internal ids if sensitive.
- Rate-limit list endpoints to deter scraping.
- Enforce tenant scoping in every page query.

## Testing
- Unit: `pageItems` truncation edge cases (1, 2, 7, 100 pages; first/last/middle).
- Testing Library: `getByRole('navigation', {name:'Pagination'})`, `getByRole('link', {current:'page'})`.
- Playwright: page links navigate and preserve filters; Back returns to the previous page; out-of-range redirects; load more focuses the first new item.
- SEO check: each page has a canonical URL (self-canonical, not canonical to page 1).

## Tooling
- shadcn/ui Pagination (presentational links), TanStack Table pagination state, TanStack Query `useInfiniteQuery`, nuqs for URL state.

## Framework Notes
- **React (Vite SPA)**: Put the page in the URL (React Router `useSearchParams`, TanStack Router validated search). Use TanStack Query with `placeholderData: keepPreviousData` to avoid flashing empty states between pages. After a client page change, scroll the results container to the top and focus the results heading (`tabIndex={-1}`). SPA routers don't announce, so add a live region.
- **Next.js (App Router)**: Read `searchParams` in the Server Component page (async in Next 15+), fetch server-side, and render `next/link` pagination with no client JS needed. Changing only `searchParams` re-renders the server page; wrap the list in `<Suspense key={page}>` to show a loading state. `useSearchParams` in client components needs a Suspense boundary. For "Load more", fetch additional pages with a Server Action or route handler and append on the client. Set `generateMetadata` titles like "Products – Page 3".

## AI Agent Guidance
- DO use links with URL state; DO read page params server-side in Next.js.
- DO implement truncation, `aria-current`, and the result summary.
- DON'T implement pagination as stateful buttons; DON'T forget to reset page on filter change.
- Verify: Back/refresh preserve page; focus/scroll after change; out-of-range handling; mobile layout; keyboard order; filters + page combine correctly.

## Examples
TanStack Table + URL state (client, Vite SPA):
```tsx
const [search, setSearch] = useSearchParams();
const pageIndex = Number(search.get('page') ?? 1) - 1;
const table = useReactTable({
  data, columns, pageCount, manualPagination: true,
  state: { pagination: { pageIndex, pageSize: 50 } },
  onPaginationChange: (updater) => {
    const next = typeof updater === 'function' ? updater({ pageIndex, pageSize: 50 }) : updater;
    setSearch((s) => { s.set('page', String(next.pageIndex + 1)); return s; });
  },
  getCoreRowModel: getCoreRowModel(),
});
```

## Related Skills
- [list-virtualization](../list-virtualization/Skill.md): rendering long loaded lists
- [tanstack-table](../tanstack-table/Skill.md): table pagination state
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md): infinite queries
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md): URL state
- [enterprise-data-tables](../enterprise-data-tables/Skill.md): table pagination UX
- [accessible-spa-routing](../accessible-spa-routing/Skill.md): focus after navigation
- [seo-for-frontend](../seo-for-frontend/Skill.md): paginated URLs and canonicals
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md): load-more announcements

## Sources
- [GOV.UK Design System: Pagination](https://design-system.service.gov.uk/components/pagination/) — Official design system — when to use, markup, ellipsis rules, mobile
- [WAI-ARIA APG: Feed Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/feed/) — Official — accessible infinite scroll semantics
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Community (agent skill) — deep-link pagination, restore scroll

## License / Usage Notes
Summarized in original wording; code original. GOV.UK Design System content is OGL v3; shadcn/TanStack MIT.

## Quality Tier
A — GOV.UK + APG grounding with complete Next.js server and client implementations.

## Status
Active

## Last Verified
2026-09-15
