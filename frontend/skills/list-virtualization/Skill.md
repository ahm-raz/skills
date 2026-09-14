# List Virtualization

## Summary
Virtualization (windowing) renders only the rows visible in a scroll viewport, plus overscan, so lists, grids, tables and chat logs with thousands of items stay fast. This skill covers when to virtualize (and cheaper alternatives like pagination and `content-visibility`), TanStack Virtual (dynamic sizes, window scrolling, lanes/masonry, and the 2026 chat features `anchorTo: 'end'` and `followOnAppend`), the accessibility costs (find-in-page, screen reader counts, focus loss), and SSR concerns in Next.js.

## Category
Components

## Subcategories
Windowing, dynamic row heights, infinite loading, virtualized tables, grid/masonry, chat scroll anchoring, scroll restoration

## Problem It Solves
Rendering 10k DOM rows makes initial render, memory, INP and scrolling slow. Naive virtualization breaks things users rely on: Ctrl+F, screen reader item counts, keyboard focus (the focused row unmounts), anchor links, printing, and scroll position on Back. It also causes jumpy scrolling with dynamic heights and chat logs that yank users to the bottom.

## When To Use
- Hundreds to thousands of non-trivial rows rendered at once (logs, data tables, large selects, file lists, chat history, feeds).
- Profiling shows long render/commit times or high memory tied to list size.
- Infinite loading where DOM size would otherwise grow unbounded.

## When Not To Use
- Fewer than ~100–200 simple rows: just render them.
- Content that must be searchable with find-in-page, printable, or SEO-indexed (articles, docs): use pagination or `content-visibility: auto`.
- When pagination fits the UX better (see pagination).
- As a fix for slow row components: optimize rows first.

## Core Principles
1. Measure first: virtualize because profiling says so, not by default.
2. The scroll container has a known size; the inner spacer has the total size; rows are absolutely positioned (or translated) at computed offsets.
3. Stable keys (`getItemKey`) and good size estimates prevent jumps; measure dynamic rows with `measureElement`.
4. Preserve accessibility: expose set size and positions, keep keyboard focus alive (scroll to index before focusing), provide search as a find-in-page replacement.
5. Preserve scroll state across navigation (snapshot/restore) and use end-anchoring for chat.

## Best Practices
- Overscan 5–10 rows for smooth keyboard and fast scrolling. Increase for variable heights.
- Estimate sizes at the high end of typical rows to reduce layout correction (TanStack docs recommend a comfortable largest estimate).
- Use `useWindowVirtualizer` for page-level lists so the document scrolls (better mobile behavior and browser UI collapse).
- For tables, virtualize rows but keep header semantics (`role="grid"`/`table` with `aria-rowcount` and `aria-rowindex`).
- Provide in-app search/filter, since Ctrl+F only finds rendered rows.
- Chat: `anchorTo: 'end'`, `followOnAppend` only when the user is near the end, stable ids when prepending history.
- Infinite loading: trigger fetch when the last virtual item index nears `count - threshold`. Show a loader row and announce loads politely.
- Cheaper alternative for long static content: `content-visibility: auto; contain-intrinsic-size: auto 500px;` on sections. This keeps content in the DOM (findable, accessible) while skipping rendering work. Verify engine support for your matrix.

## Implementation Guidance

### Decision table
| Situation | Approach |
|---|---|
| < ~200 rows | Plain rendering (memoize rows if needed) |
| Long static page sections | `content-visibility: auto` |
| Large list/table in a scroll panel | TanStack Virtual `useVirtualizer` |
| Page-scrolling feed | `useWindowVirtualizer` |
| Chat / log tail | `useVirtualizer` with `anchorTo: 'end'`, `followOnAppend`, `scrollEndThreshold` |
| Grid/masonry | `lanes` option, or virtualize rows of N columns |
| Data grid with columns, pinning, editing | TanStack Table + Virtual, or AG Grid (built-in virtualization) |
| Very large selects/comboboxes | Library listbox with virtualization support (React Aria `Virtualizer`, cmdk alternatives) |

### Key TanStack Virtual options
| Option / method | Purpose |
|---|---|
| `count`, `getScrollElement`, `estimateSize` | Required core |
| `overscan` | Extra rows beyond the viewport |
| `getItemKey` | Stable keys (essential for dynamic data and prepends) |
| `measureElement` + `data-index` attribute | Dynamic row sizing |
| `horizontal`, `lanes`, `gap`, `paddingStart/End`, `scrollMargin` | Layout variants |
| `rangeExtractor` | Keep sticky headers or the focused row rendered |
| `anchorTo: 'end'`, `followOnAppend`, `scrollEndThreshold` | Chat/log behavior (2026) |
| `initialMeasurementsCache`, `initialOffset`, `takeSnapshot()` | Restore scroll/measurements after remount |
| `getVirtualItems()`, `getTotalSize()`, `scrollToIndex(i, {align})`, `isAtEnd()`, `scrollToEnd()` | Instance API |

### Accessibility attributes
| Element | Attributes |
|---|---|
| List container | `role="list"` (or `listbox`/`grid`/`feed` per semantics), `aria-label` |
| Row | `role="listitem"`, `aria-setsize={count}`, `aria-posinset={index + 1}` |
| Table | `aria-rowcount={totalRows + headerRows}`, rows `aria-rowindex` |
| Feed pattern | `role="feed"`, `article` rows, `aria-busy` while loading |

## Recommended Workflow
1. Profile (React DevTools Profiler, Performance panel) with production-like data volumes.
2. Try cheaper fixes: pagination, row memoization, `content-visibility`.
3. Choose container vs window scrolling; pick the semantic role.
4. Implement the virtualizer with stable keys and good estimates; add `measureElement` for dynamic rows.
5. Wire keyboard navigation with `scrollToIndex` + focus-after-render; keep the focused row via `rangeExtractor` if needed.
6. Add infinite loading, loader rows, and announcements.
7. Add scroll restoration and chat anchoring where relevant.
8. Test performance (INP, scroll FPS), screen readers (counts), keyboard, mobile.

## Patterns

### Dynamic-height list with keyboard support
```tsx
'use client';
import { useRef, useState, useEffect } from 'react';
import { useVirtualizer, defaultRangeExtractor } from '@tanstack/react-virtual';

type Row = { id: string; title: string; body: string };

export function VirtualList({ rows, label }: { rows: Row[]; label: string }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState(0);
  const v = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 72,
    overscan: 8,
    getItemKey: (i) => rows[i].id,
    rangeExtractor: (range) => {
      const r = defaultRangeExtractor(range);
      return r.includes(active) ? r : [...r, active].sort((a, b) => a - b); // keep focused row mounted
    },
  });

  useEffect(() => { // focus after scroll-to-index renders the row
    parentRef.current?.querySelector<HTMLElement>(`[data-index="${active}"]`)?.focus({ preventScroll: true });
  }, [active, v.getVirtualItems().length]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    const next = e.key === 'ArrowDown' ? Math.min(active + 1, rows.length - 1)
      : e.key === 'ArrowUp' ? Math.max(active - 1, 0)
      : e.key === 'Home' ? 0 : e.key === 'End' ? rows.length - 1 : null;
    if (next === null) return;
    e.preventDefault(); setActive(next); v.scrollToIndex(next, { align: 'auto' });
  };

  return (
    <div ref={parentRef} style={{ height: '70dvh', overflow: 'auto', contain: 'strict' }}>
      <div role="list" aria-label={label} onKeyDown={onKeyDown}
        style={{ height: v.getTotalSize(), position: 'relative' }}>
        {v.getVirtualItems().map((item) => {
          const row = rows[item.index];
          return (
            <div key={item.key} ref={v.measureElement} data-index={item.index}
              role="listitem" aria-setsize={rows.length} aria-posinset={item.index + 1}
              tabIndex={item.index === active ? 0 : -1}
              style={{ position: 'absolute', top: 0, left: 0, width: '100%', transform: `translateY(${item.start}px)` }}>
              <h3>{row.title}</h3><p>{row.body}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

### Infinite loading with TanStack Query
```tsx
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
  queryKey: ['logs'], queryFn: ({ pageParam }) => fetchLogs(pageParam),
  initialPageParam: null as string | null, getNextPageParam: (last) => last.nextCursor,
});
const items = data?.pages.flatMap((p) => p.items) ?? [];
const v = useVirtualizer({ count: hasNextPage ? items.length + 1 : items.length, getScrollElement: () => ref.current, estimateSize: () => 36, overscan: 10 });
const last = v.getVirtualItems().at(-1);
useEffect(() => {
  if (last && last.index >= items.length - 1 && hasNextPage && !isFetchingNextPage) void fetchNextPage();
}, [last?.index, items.length, hasNextPage, isFetchingNextPage, fetchNextPage]);
// Render index === items.length as a "Loading more…" row; announce "50 more entries loaded" via role="status".
```

### Chat log anchored to the end
```tsx
const v = useVirtualizer({
  count: messages.length,
  getScrollElement: () => ref.current,
  estimateSize: () => 80,
  getItemKey: (i) => messages[i].id,   // required for stable prepends
  anchorTo: 'end',
  followOnAppend: 'smooth',            // follows only when the user is near the end
  scrollEndThreshold: 80,
});
// Show a "Jump to latest" button when !v.isAtEnd(); onClick={() => v.scrollToEnd()}
```
These options arrived in 2026 releases of TanStack Virtual; confirm your installed version supports them. Use `role="log"` with `aria-live="polite"` sparingly for new messages, and don't announce history loads.

### Snapshot and restore on navigation
Call `v.takeSnapshot()` on unmount and store it by route key. On remount, pass `initialMeasurementsCache` and `initialOffset` from the snapshot. This avoids re-measuring and jumps on Back.

## Anti-Patterns
- **Virtualizing a 50-row list**: complexity with no benefit. Fix: plain render.
- **Index keys with prepends or reorders**: rows remount, focus and measurements are lost. Fix: `getItemKey` with ids.
- **Focus on a row that scrolls out and unmounts**: keyboard users lose their place. Fix: keep the active row via `rangeExtractor`, or roving `aria-activedescendant` on a stable container.
- **No search when Ctrl+F can't find unrendered rows**: Fix: in-app filter.
- **Nested scroll containers on mobile**: scroll traps. Fix: window virtualizer.
- **Estimating sizes too small with dynamic content**: scroll jumps. Fix: larger estimates + `measureElement`.
- **Auto-scrolling chat to bottom on every message**: interrupts reading history. Fix: `followOnAppend` threshold + "Jump to latest".
- **Virtualizing SEO content**: crawlers see only the first rows. Fix: paginate server-rendered pages.

## Accessibility
- WCAG 1.3.1 (set size/position exposed), 2.1.1 Keyboard, 2.4.3 Focus Order, 4.1.3 Status Messages (loads), 2.4.5 Multiple Ways (search compensates for find-in-page).
- Screen readers in browse mode read only rendered DOM, so `aria-setsize`/`aria-posinset` communicate the true size. Verify with NVDA and VoiceOver.
- Consider APG Feed semantics for article feeds (Page Up/Down between articles).

## Responsive Design
- Row heights change with width, so re-measure on container resize (TanStack remeasures measured elements via ResizeObserver).
- Use `dvh` for container heights on mobile, or window scrolling.
- Masonry/grids: compute columns from container width (container queries + `lanes`).

## Performance
- Target: constant DOM size (~visible rows + overscan). Check INP while scrolling and typing filters.
- Keep row components cheap and memoized. Avoid inline heavy formatters per render.
- Use `contain: strict` (or `layout paint`) on the scroll container. Translate rows with `transform`.
- Debounce filter input; compute filtered arrays in `useMemo` or a worker for very large sets.

## Security
- Don't send the full dataset to the client just because the list is virtualized. Paginate server-side for sensitive or large data.
- Enforce authorization on each page fetch.

## Testing
- jsdom has no layout, so virtualizers render zero or few rows. Mock `getBoundingClientRect`/`ResizeObserver`, set `initialRect`, or test in browser mode.
- Playwright: scroll to the bottom and assert the last item renders; keyboard End focuses the last row; infinite load appends; Back restores scroll; chat doesn't jump when prepending history.
- Performance: Chrome Performance panel scroll traces; Lighthouse/INP in lab; RUM for production.
- Screen reader: announces "item 523 of 10,000".

## Tooling
- `@tanstack/react-virtual` (MIT): 2026 releases added chat anchoring (`anchorTo`, `followOnAppend`), iOS improvements and snapshots.
- TanStack Table (with Virtual) for tables; AG Grid for enterprise grids.
- React Aria `Virtualizer` for React Aria collections.
- CSS `content-visibility` / `contain-intrinsic-size`.

## Framework Notes
- **React (Vite SPA)**: Virtualizers are hooks; the scroll element ref must exist, so `getScrollElement` can return null initially. Keep derived arrays memoized (React Compiler helps). Store scroll snapshots in a router-keyed map for Back navigation (React Router `useLocation().key`).
- **Next.js (App Router)**: Virtualized lists are Client Components (`'use client'`). The server can't measure the viewport, so server HTML renders zero rows or an estimate. For LCP/SEO-critical lists, server-render the first page of items without virtualization and hydrate into the virtualizer (or pass `initialRect` so the first rows render on the server). Fetch the first page in a Server Component and continue with route handlers or Server Actions. Avoid `window` access during render to prevent hydration mismatches. Wrap window-virtualized pages carefully with `scroll={false}` navigation when preserving positions. Next.js restores scroll for full page lists, but custom scroll containers need your own snapshot logic.

## AI Agent Guidance
- DO profile and confirm need; DO consider pagination or `content-visibility` first.
- DO use stable keys, size estimates, `measureElement`, overscan, and set size/position attributes.
- DON'T break keyboard focus or remove the only way to search content.
- DON'T virtualize SEO content or tiny lists.
- Verify: DOM row count stays bounded; smooth scroll with dynamic heights; keyboard Home/End/arrows; screen reader counts; infinite load and announcements; Back restores position; chat anchoring behaves.

## Examples
Window virtualizer for a page-level feed:
```tsx
'use client';
import { useWindowVirtualizer } from '@tanstack/react-virtual';
import { useLayoutEffect, useRef, useState } from 'react';

export function Feed({ posts }: { posts: { id: string; title: string }[] }) {
  const listRef = useRef<HTMLUListElement>(null);
  const [offset, setOffset] = useState(0);
  useLayoutEffect(() => setOffset(listRef.current?.offsetTop ?? 0), []);
  const v = useWindowVirtualizer({ count: posts.length, estimateSize: () => 120, overscan: 6, scrollMargin: offset, getItemKey: (i) => posts[i].id });
  return (
    <ul ref={listRef} aria-label="Posts" style={{ height: v.getTotalSize(), position: 'relative' }}>
      {v.getVirtualItems().map((it) => (
        <li key={it.key} ref={v.measureElement} data-index={it.index} aria-setsize={posts.length} aria-posinset={it.index + 1}
          style={{ position: 'absolute', top: 0, width: '100%', transform: `translateY(${it.start - v.options.scrollMargin}px)` }}>
          <a href={`/posts/${posts[it.index].id}`}>{posts[it.index].title}</a>
        </li>
      ))}
    </ul>
  );
}
```

## Related Skills
- [pagination](../pagination/Skill.md): alternative and complement
- [tanstack-table](../tanstack-table/Skill.md): virtualized tables
- [enterprise-data-tables](../enterprise-data-tables/Skill.md): large table UX
- [rendering-performance](../rendering-performance/Skill.md): DOM size and rendering cost
- [inp-optimization](../inp-optimization/Skill.md): responsiveness during scroll and filter
- [ai-chat-interface-ux](../ai-chat-interface-ux/Skill.md): chat scroll anchoring
- [tree-views](../tree-views/Skill.md): virtualizing flattened trees
- [react-performance-optimization](../react-performance-optimization/Skill.md): row memoization

## Sources
- [TanStack Virtual: Virtualizer API](https://tanstack.com/virtual/latest/docs/api/virtualizer) — Open Source — options, methods, snapshots, lanes
- [TanStack Blog: Chat UIs Are Lists Until They Aren't (May 2026)](https://tanstack.com/blog/tanstack-virtual-chat) — Open Source — anchorTo, followOnAppend, scrollEndThreshold
- [TanStack Blog: performance and iOS](https://tanstack.com/blog/tanstack-virtual-perf-and-ios) — Open Source — 2026 performance and iOS improvements
- [WAI-ARIA APG: Feed Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/feed/) — Official — accessible infinite scrolling semantics
- [MDN: content-visibility](https://developer.mozilla.org/en-US/docs/Web/CSS/content-visibility) — Official — rendering-skip alternative

## License / Usage Notes
Summarized in original wording; code original. TanStack Virtual/Query MIT; AG Grid community MIT with commercial enterprise features.

## Quality Tier
A — current TanStack docs including 2026 features and APG feed guidance; `content-visibility` engine support not re-verified.

## Status
Active

## Last Verified
2026-09-15
