# Filters and Faceted Search

## Summary
How to design and build filter panels and faceted navigation for result lists: product listings, content libraries, job boards, app lists. Covers choosing filters vs facets, facet types (checkbox list, single-select, range, toggle, hierarchical), counts and zero-result handling, live vs batch apply, the applied-filters overview, URL state, mobile filter sheets, accessibility of dynamic results, and implementation with search backends (Algolia InstantSearch, Meilisearch, Typesense) or your own API. Enterprise query builders and complex boolean filter UIs belong to `advanced-filtering-ui`.

## Category
Components

## Subcategories
Faceted navigation, refinement lists, range filters, applied filters, filter chips, sort, URL state, mobile filter drawer, result counts

## Problem It Solves
Filtering can make or break findability. Baymard's testing found common failures: no overview of applied filters (28% of sites), applied filters not surfaced prominently (42%), filters that don't match the attributes shown in list items, dead-end zero-result combinations, page reloads that reset scroll and focus, and mobile panels where users can't tell whether filters applied. Engineering adds its own failures: filters stored only in component state (not shareable, lost on back), race conditions, and results updates that screen readers never hear about.

## When To Use
- A result set large enough that users need to narrow it on several attributes (roughly more than 20–50 items).
- Content with structured metadata: price, category, size, brand, date, status, location.
- Search results pages that need refinement after a query.
- App lists (projects, tickets, users) where a handful of simple filters beats a query builder.

## When Not To Use
- Fewer than about 20 items: a sort control or simple search works better.
- Boolean logic, nested conditions, saved views, or column-level filters in data grids: use `advanced-filtering-ui` / `enterprise-data-tables`.
- Mutually exclusive categories users browse hierarchically: navigation (`navigation-menus-and-sidebars`) may be better than facets.
- Users don't have the metadata vocabulary. NN/g warns that faceted navigation is expensive, so confirm users need it before investing.

## Core Principles
1. **Filters mirror what users compare.** Offer a filter for every attribute shown in list items and for the key decision criteria (Baymard: 38% of sites miss this).
2. **Always show what's applied.** Show an overview of applied filters with type and value, each removable, plus "Clear all". A count alone is not enough.
3. **The URL is the source of truth.** Filter, sort, page, and query state live in the URL so it can be shared, bookmarked, survive back/forward, and be rendered on the server.
4. **Prevent dead ends.** Show counts, disable or hide zero-count values, and offer a way out when results are empty.
5. **Predictable apply model.** Use live apply on desktop when results come back fast. Use batch apply (an explicit "Show N results" button) in mobile sheets. Don't mix the two within one panel.
6. **Changes are perceivable.** Result count updates are announced, focus is never yanked, and scroll position is handled deliberately.

## Best Practices
- **Facet types**: multi-select checkbox list (brand, color: OR within a facet, AND across facets), single-select radio (condition, rating ≥), range (price, date) with slider **and** numeric inputs, boolean toggle (in stock), hierarchical (category tree, drill-down).
- Order facets by importance to the task, not alphabetically. Put category and price early. Order values by count or natural order (sizes S→XL). Keep alphabetical for brands with a facet search.
- Show about 5–10 values per facet, then "Show more (23)". For long facets add an in-facet search ("Search brands").
- Show counts next to values ("Blue (42)"). Counts must reflect the current filter context (disjunctive faceting for OR facets, so selecting Blue doesn't zero out Red).
- Put the applied filters overview above the results (desktop) or as a horizontally scrolling chip row with a count (mobile). Show "Color: Blue ×" style chips and "Clear all".
- Sort is a separate control from filters. Keep it visible near the result count ("248 results · Sort: Relevance").
- Collapse facet groups with disclosure buttons, but keep the top 3–5 expanded by default. Remember the expansion state during the session.
- Show the result count prominently and update it as filters change. In batch mode, preview it on the apply button ("Show 37 results").
- Empty results: explain which filters caused it, offer to remove the last filter or clear all, and suggest related queries.
- Truthful thematic filters ("Waterproof", "Good for beginners") often matter more to users than raw specs. Include them when data supports it.
- Keep filters and results in sync on back navigation (URL-driven state + scroll restoration).

## Implementation Guidance

### Live vs batch apply
| Context | Model | Details |
|---|---|---|
| Desktop sidebar, fast backend (<~500 ms) | Live | Update results per change; keep panel stable; optimistic checkbox state; show inline loading on results |
| Mobile filter sheet/drawer | Batch | Changes staged locally; sticky footer "Show N results" (live count preview) + "Clear"; close applies |
| Slow/expensive queries | Batch | "Apply" button; indicate unapplied changes |
| Range inputs (typing) | Commit on blur/Enter or debounced 400–600 ms | Never refetch on every keystroke or slider pixel |

### URL state shape
```
/products?q=boots&color=blue&color=black&price_min=50&price_max=150&instock=1&sort=price_asc&page=2
```
- Repeat keys for multi-select (this is what a native GET form produces, so the no-JS fallback and the enhanced UI share one URL contract). Keep a stable key order for cache hits. Omit defaults.
- Reset `page` whenever filters or query change.
- Use `replace` for rapid filter tweaks (or `push` per discrete change if back should undo filters, and decide consistently). Always use `push` for new search queries.
- Validate and parse on the server. Unknown values are dropped, not echoed.
- SEO: canonicalize filtered URLs, `noindex` combinatorial pages except curated landing facets (see `seo-for-frontend`).

### Facet markup
```tsx
// app/products/filter-form.tsx — Server Component. A plain GET form: works before hydration and without JS.
// ColorFacet (client, see Examples) SSRs the same native checkboxes, then adds live apply once hydrated.
import type {Filters} from '@/lib/filters';
import {ColorFacet} from './color-facet';

export function FilterForm({filters, colorCounts, total}: {filters: Filters; colorCounts: Record<string, number>; total: number}) {
  return (
    <>
      {/* If your @types/react predates <search>, use <div role="search" aria-label="Product filters"> */}
      <search aria-label="Product filters">
        <form method="get" action="/products">
          {filters.q && <input type="hidden" name="q" value={filters.q} />}
          <ColorFacet counts={colorCounts} total={total} />
          <fieldset>
            <legend>Price</legend>
            <label>Min <input name="price_min" type="text" inputMode="numeric" pattern="[0-9]*" defaultValue={filters.price?.[0] || ''} /></label>
            <label>Max <input name="price_max" type="text" inputMode="numeric" pattern="[0-9]*" defaultValue={filters.price && filters.price[1] < Number.MAX_SAFE_INTEGER ? filters.price[1] : ''} /></label>
            <button type="submit">Apply price</button>
          </fieldset>
          <label><input type="checkbox" name="instock" value="1" defaultChecked={filters.inStock} /> In stock only</label>
          <noscript><button type="submit">Apply filters</button></noscript>
        </form>
      </search>
      <p role="status">{total} results</p>
    </>
  );
}
```
- Use native checkboxes and radios inside `<fieldset>`/`<legend>`. Don't build facets from `div`s or listboxes.
- Put counts inside the label so AT reads "Blue (42)". Consider visually hidden "42 products" wording.
- Collapsible groups: a disclosure `<button aria-expanded aria-controls>` wrapping the legend text, or `<details><summary>`.
- A no-JS fallback works because the form submits GET. Progressive enhancement turns it into live apply.

### Results update and focus
- Live apply: keep focus on the control the user changed. Never move focus to the results. Update the polite status ("37 results").
- Don't scroll to top on every change. In mobile batch mode, after "Show results" close the sheet, return focus to the "Filters" trigger (now labeled "Filters (3)"), and scroll to the top of the results.
- Show loading on the results region (`aria-busy="true"`) and keep previous results visible but dimmed.
- Removing an applied-filter chip moves focus to the next chip, or to the "Filters" heading or result count if none remain.

## Recommended Workflow
1. Audit the data: which attributes exist and how clean they are, and which attributes are shown on result cards. Interview or check analytics for decision criteria.
2. Define facets: type, operator (OR/AND), ordering, default expansion, display limits.
3. Define the URL contract and parse/serialize functions (typed, validated).
4. Build the backend query with disjunctive counts (a search engine handles this, or run a facet query per OR group).
5. Build the desktop panel (live), the applied-filters bar, sort, result count, and empty state.
6. Build the mobile sheet (batch) with a sticky apply footer and count preview.
7. Handle loading, errors, stale responses (abort), back/forward, and scroll restoration.
8. Test accessibility (fieldsets, announcements, focus), performance (INP on checkbox toggle), and SEO rules.

## Patterns
- **Sidebar facets + applied bar (desktop e-commerce).** Left column of collapsible fieldsets, chip bar above the results, sort on the right.
- **Horizontal filter toolbar.** Row of filter buttons, each opening a popover with facet controls (non-modal, `aria-expanded`). Suits wide result grids. Applied chips go below the toolbar.
- **Mobile filter sheet.** "Filters (3)" + "Sort" buttons, sticky on scroll. Full-height sheet with facet accordion, footer with "Clear all" and "Show 37 results".
- **Quick filter chips.** Toggle buttons for the top 3–6 filters (`aria-pressed`) above results, plus "All filters" for the full panel.
- **Hierarchical category facet.** Drill down ("All › Shoes › Boots") with a back link. Show only child categories of the current level, with counts.
- **Range facet.** Dual inputs synced with an optional two-thumb slider (see `sliders-and-range-inputs`). Histogram or bucketed presets ("Under $50").
- **Saved/recent filter sets (apps).** Named views stored server-side. Beyond this skill, see `advanced-filtering-ui`.

```tsx
// lib/filters.ts — typed URL <-> filter state; shared by Server Component pages and client panels
export type Filters = {q?: string; color: string[]; price?: [number, number]; inStock: boolean; sort: 'relevance' | 'price_asc' | 'price_desc'; page: number};
const SORTS = new Set(['relevance', 'price_asc', 'price_desc']);

export function parseFilters(sp: URLSearchParams, allowedColors: Set<string>): Filters {
  const min = Number.parseInt(sp.get('price_min') ?? '', 10);
  const max = Number.parseInt(sp.get('price_max') ?? '', 10);
  const hasMin = Number.isFinite(min) && min >= 0;
  const hasMax = Number.isFinite(max) && max >= 0;
  return {
    q: sp.get('q')?.slice(0, 200) || undefined,
    color: sp.getAll('color').filter((c) => allowedColors.has(c)),
    price: hasMin || hasMax ? [hasMin ? min : 0, hasMax ? max : Number.MAX_SAFE_INTEGER] : undefined,
    inStock: sp.get('instock') === '1',
    sort: (SORTS.has(sp.get('sort') ?? '') ? sp.get('sort') : 'relevance') as Filters['sort'],
    page: Math.max(1, Number(sp.get('page')) || 1),
  };
}

export function serializeFilters(f: Filters): string {
  const sp = new URLSearchParams();
  if (f.q) sp.set('q', f.q);
  [...f.color].sort().forEach((c) => sp.append('color', c));
  if (f.price && f.price[0] > 0) sp.set('price_min', String(f.price[0]));
  if (f.price && f.price[1] < Number.MAX_SAFE_INTEGER) sp.set('price_max', String(f.price[1]));
  if (f.inStock) sp.set('instock', '1');
  if (f.sort !== 'relevance') sp.set('sort', f.sort);
  if (f.page > 1) sp.set('page', String(f.page));
  return sp.toString();
}
```

## Anti-Patterns
| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Filter state only in React state | Lost on refresh/back, not shareable, not SSR | URL as source of truth (nuqs, router search params) |
| Showing "3 filters applied" only | Users can't see or undo specific filters | Applied chips with type:value and × |
| Zero-count values selectable | Dead-end empty page | Show count, disable or hide zeros, provide recovery on empty |
| Counts that ignore OR semantics | Selecting Blue makes Red show 0 | Disjunctive faceting |
| Refetch on every slider move or keystroke | Server load, janky INP, flicker | Commit on release/blur or debounce; abort stale |
| Moving focus to results after each checkbox | Disorienting, breaks multi-select flow | Keep focus; announce count via status |
| Live apply inside mobile sheet with reflow behind | Users can't tell anything happened, costly renders | Batch with "Show N results" |
| Facets built as custom listboxes | Poor AT support for multi-select, no native form | Native checkboxes in fieldsets |
| Scroll jumps to top on every change (desktop) | Loses place in panel and results | Keep scroll; only scroll to results on explicit apply |
| Filters that don't match card attributes | Users can't narrow by what they see | Facet for each displayed attribute |
| Indexable infinite filter combinations | Crawl budget waste, duplicate content | Canonical + noindex rules |
| Not resetting page on filter change | "Page 7 of 2" empty results | Reset `page` when filters change |

## Accessibility
- WCAG 1.3.1: group facets with `<fieldset>`/`<legend>`. The filter region is a labeled `<search>` or `<form>` landmark.
- WCAG 4.1.3: announce result counts and "No results" via `role="status"` after updates settle (debounce announcements).
- WCAG 3.2.2 On Input: live apply is acceptable when it doesn't cause a context change (no navigation, no focus move). If the page reloads or navigates per change, warn users or use batch apply.
- WCAG 2.4.3 focus order and 2.4.11 focus not obscured: sticky filter bars and footers must not cover focused controls.
- WCAG 1.4.1: selected state is not color-only (checkbox, check icon, pressed style). Disabled zero-count values still meet contrast for readability, or are hidden.
- Quick filter chips: `<button aria-pressed>`, in a group labeled "Quick filters".
- Mobile sheet: dialog semantics with focus trap, labeled title "Filters", and Escape closes (batch changes discarded or kept, and clearly communicated). See `drawers-and-sheets`.
- Range sliders need numeric-input alternatives (2.5.7 Dragging Movements).
- Mark the results region `aria-busy` during loading. Don't wrap huge result lists in `aria-live`, only the count.

## Responsive Design
- Under about 768–1024 px, replace the sidebar with "Filters (n)" and "Sort" buttons (sticky), opening a full-height sheet.
- Show applied chips as a horizontally scrolling row with edge fade and truncate the last visible chip to signal overflow. Include "n filters applied" text (Baymard).
- The sheet footer is sticky with "Clear all" and "Show N results". Respect safe-area insets.
- Use container queries for the filter panel so it adapts inside split layouts, not just by viewport.
- Large touch targets for checkbox rows: the full row is the label, ≥44 px tall.

## Performance
- Toggling a checkbox must feel instant. Update checkbox state synchronously (optimistic), then fetch results in a transition. Keep previous results visible.
- Debounce combined filter changes (about 150–300 ms) so rapid multi-clicks send one request. Abort stale requests.
- Cache results per serialized URL (TanStack Query key = query string). Prefetch the likely next state on hover of a facet value only if cheap.
- Server-render the initial filtered page from URL params for fast LCP and SEO. Stream results if slow.
- Large facets: cap values from the backend and use facet search instead of sending thousands of values.
- Virtualize very long result lists or use pagination and "Load more" (see `pagination`, `list-virtualization`).

## Security
- Parse URL params against allowlists. Never pass raw values into queries (injection into search DSL/SQL). Clamp numeric ranges.
- Enforce authorization in the backend filter query. Facet counts can leak the existence of restricted records ("Confidential (3)").
- Use search-only or secured API keys for client-side search engines, with tenant filters embedded server-side.
- Rate-limit expensive facet queries. Bound query string length.

## Testing
- Unit: `parseFilters`/`serializeFilters` round-trip, invalid param dropping, page reset rules.
- Component: toggling a checkbox updates the URL (mock router), the status announces the count, applied chips render with type and value, chip removal updates state and focus, empty state offers "Clear all".
- Integration: MSW for the search API with delayed responses; assert only the latest response renders.
- E2E (Playwright): deep link restores filters, back/forward restores state and scroll, mobile sheet batch apply flow, no-JS GET fallback if supported.
- A11y: axe on the panel and sheet open; manual screen reader check of status announcements; keyboard through the sheet.
- Performance: INP measurement on facet toggle with a large list (Web Vitals / Playwright tracing).

## Tooling
| Tool | Notes (Sept 2026) |
|---|---|
| React InstantSearch v7 (`react-instantsearch`) | `RefinementList` (`attribute`, `operator` or/and, `limit`, `showMore`, `searchable`, `sortBy`), `CurrentRefinements`, `ClearRefinements`, `RangeInput`, routing for URL sync; `useRefinementList` for custom UI |
| Meilisearch / Typesense / OpenSearch | Facet distribution + filters; Typesense/Meilisearch have InstantSearch adapters |
| nuqs v2 | Type-safe URL query state for Next.js (App Router adapter) and React/Vite SPAs (React and React Router adapters): `useQueryState(s)`, parsers such as arrays/literals |
| TanStack Router search params | Validated, typed search params with schemas |
| TanStack Query | Cache per filter key, `keepPreviousData`, abort signal |
| React Aria / Base UI / Radix | Checkbox groups, disclosure, dialog/sheet, toggle buttons for filter UI |

## Framework Notes
- **Next.js App Router**:
  - The page is a Server Component. It awaits `searchParams` (a Promise in Next 15+), converts them to `URLSearchParams`, runs `parseFilters`, and fetches results and facet counts on the server, so first paint is already filtered and SEO-friendly.
  - Render facets inside a GET `<form>` (or `next/form`) so they work before hydration. Put an "Apply filters" submit button in `<noscript>`, or hide it after hydration.
  - Client facet components update the URL with nuqs `useQueryStates` (`shallow: false` so the server page re-renders, `history: 'replace'`, `startTransition` for pending UI) or with `useSearchParams` + `router.replace(`?${qs}`, {scroll: false})`.
  - The nuqs adapter goes in the root layout (`NuqsAdapter` from `nuqs/adapters/next/app`). Components reading `useSearchParams` need a `<Suspense>` boundary.
  - Avoid `<Suspense key={queryString}>` around results unless you want old results hidden on every change. Prefer keeping previous results with `aria-busy`.
- **React (Vite SPA)**:
  - Keep URL state with nuqs (React or React Router adapter) or React Router's `useSearchParams` (with `replace: true` for tweaks).
  - Fetch with TanStack Query keyed on the serialized filter string, using `placeholderData: keepPreviousData`.
  - Mobile sheets stage changes in local state and write the URL once on "Show N results".
- Filters are GET/URL state, not mutations, so don't use Server Actions for applying filters. Use Server Actions only for side effects such as saving a named view.

## AI Agent Guidance
- Do: put filter, sort, page, and query in the URL with typed parse/serialize and an allowlist.
- Do: use native checkboxes and radios in fieldsets, an applied-filters chip bar with Clear all, a result count status, and an empty state with recovery.
- Do: choose live (desktop, fast) vs batch (mobile sheet) explicitly, reset page on filter change, and debounce plus abort requests.
- Don't: move focus to results on change, fetch on every slider pixel, or build facets from custom listboxes.
- Don't: scope into query builders or nested boolean logic; hand off to `advanced-filtering-ui`.
- Do: in Next.js, parse `searchParams` in the Server Component page, render facets inside a GET form that works without JS, and enhance with nuqs (`shallow: false`) or `useSearchParams` + `router.replace`.
- Verify before done: deep link and back/forward restore state; counts correct for OR facets; screen reader hears the count; mobile sheet apply works; axe clean; toggling feels instant (no long tasks).

## Examples

```tsx
// Next.js client filter panel with nuqs (live apply, desktop)
'use client';
import {useQueryStates, parseAsArrayOf, parseAsString, parseAsInteger} from 'nuqs';
import {useTransition} from 'react';

const COLORS = [{value: 'blue', label: 'Blue'}, {value: 'black', label: 'Black'}, {value: 'red', label: 'Red'}];

export function ColorFacet({counts, total}: {counts: Record<string, number>; total: number}) {
  const [isPending, startTransition] = useTransition();
  const [{color}, setFilters] = useQueryStates(
    {color: parseAsArrayOf(parseAsString).withDefault([]), page: parseAsInteger.withDefault(1)},
    {shallow: false, history: 'replace', startTransition},
  );

  const toggle = (v: string) =>
    setFilters({color: color.includes(v) ? color.filter((c) => c !== v) : [...color, v], page: null}); // null removes → resets page

  return (
    <fieldset aria-busy={isPending}>
      <legend>Color</legend>
      {COLORS.map((c) => {
        const n = counts[c.value] ?? 0;
        return (
          <label key={c.value} className="facet-row">
            <input type="checkbox" name="color" value={c.value} checked={color.includes(c.value)} disabled={n === 0 && !color.includes(c.value)} onChange={() => toggle(c.value)} />
            {c.label} <span className="count">({n})</span>
          </label>
        );
      })}
      <p role="status" className="visually-hidden">{isPending ? 'Updating results' : `${total} results`}</p>
    </fieldset>
  );
}
```
Check option names (`shallow`, `history`, `startTransition`, throttle settings) against the installed nuqs v2 docs.

```tsx
// app/products/page.tsx — Server Component: URL → validated filters → results + facet counts
import {parseFilters} from '@/lib/filters';
import {getProducts} from '@/lib/catalog'; // server-only: authorizes, builds allowlisted index query, disjunctive counts
import {FilterForm} from './filter-form';
import {ProductGrid} from './product-grid';

const ALLOWED_COLORS = new Set(['blue', 'black', 'red']);

export default async function ProductsPage({searchParams}: {searchParams: Promise<Record<string, string | string[] | undefined>>}) {
  const raw = await searchParams;
  const sp = new URLSearchParams();
  for (const [key, v] of Object.entries(raw)) (Array.isArray(v) ? v : v ? [v] : []).forEach((x) => sp.append(key, x));
  const filters = parseFilters(sp, ALLOWED_COLORS);
  const {items, total, facets} = await getProducts(filters);

  return (
    <div className="listing">
      <aside><FilterForm filters={filters} colorCounts={facets.color} total={total} /></aside>
      <main>
        <h1>Products</h1>
        {total === 0 ? <p>No products match these filters. <a href="/products">Clear all filters</a></p> : <ProductGrid items={items} />}
      </main>
    </div>
  );
}
```

```tsx
// Applied filters bar (client: removal callbacks update URL state via nuqs)
'use client';
export function AppliedFilters({items, onRemove, onClear}: {
  items: {key: string; type: string; label: string}[]; onRemove: (key: string) => void; onClear: () => void;
}) {
  if (!items.length) return null;
  return (
    <div className="applied">
      <h2 className="visually-hidden">Applied filters</h2>
      <ul>
        {items.map((f) => (
          <li key={f.key}>
            <span>{f.type}: {f.label}</span>
            <button type="button" aria-label={`Remove filter ${f.type}: ${f.label}`} onClick={() => onRemove(f.key)}>×</button>
          </li>
        ))}
      </ul>
      <button type="button" onClick={onClear}>Clear all</button>
    </div>
  );
}
```

## Related Skills
- [advanced-filtering-ui](../advanced-filtering-ui/Skill.md) — query builders, saved views, grid column filters (enterprise)
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — the query box feeding the results
- [tags-and-chips-input](../tags-and-chips-input/Skill.md) — chip semantics for applied filters
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) — facet controls
- [sliders-and-range-inputs](../sliders-and-range-inputs/Skill.md) — price/date range facets
- [drawers-and-sheets](../drawers-and-sheets/Skill.md) — mobile filter sheet
- [accordions-and-disclosure](../accordions-and-disclosure/Skill.md) — collapsible facet groups
- [pagination](../pagination/Skill.md) — paging filtered results
- [empty-states](../empty-states/Skill.md) — zero results recovery
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md) — product listing context
- [seo-for-frontend](../seo-for-frontend/Skill.md) — faceted URL indexing rules
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — result count status
- [inp-optimization](../inp-optimization/Skill.md) — responsive facet toggles
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — typed URL state for filters
- [progressive-enhancement](../progressive-enhancement/Skill.md) — GET form fallback
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — transitions for pending results

## Sources
- [Baymard: Display applied filters in an overview](https://baymard.com/blog/how-to-design-applied-filters) — Community (research) — placement, type+value, individual removal, mobile chip row
- [Baymard: Have filters for all displayed list item info](https://baymard.com/blog/have-filters-for-list-item-info) — Community (research) — filter coverage
- [NN/g: Filters vs. Facets](https://www.nngroup.com/articles/filters-vs-facets/) — Community (research) — definitions, cost/complexity trade-off
- [DWP Design System: Filters research](https://design-system.dwp.gov.uk/research/filters/summary) — Official (government design system) — batch vs live apply findings
- [Algolia React InstantSearch RefinementList](https://www.algolia.com/doc/api-reference/widgets/refinement-list/react/) — Open Source — facet props, operator, show more, searchable
- [nuqs docs](https://nuqs.dev/docs) — Open Source — v2 adapters and URL state API
- [MDN: `<search>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/search) — Official — landmark for filter controls

## License / Usage Notes
Baymard and NN/g findings are paraphrased from copyrighted research, and statistics are cited as reported. Algolia InstantSearch and nuqs are MIT, but Algolia's hosted search is commercial. DWP Design System content is under the Open Government Licence. Code examples are original and illustrative. Check library option names against installed versions.

## Quality Tier
A — Research-backed UX (Baymard, NN/g, DWP) plus concrete URL-state, accessibility, and library guidance. Some nuqs option names and live-apply WCAG interpretation need per-project verification.

## Status
Active

## Last Verified
2026-09-15
