# Visual Hierarchy and Layout

## Summary
How to arrange content so users see what matters first, scan efficiently, and understand grouping without reading everything. Covers scanning patterns (F, layer-cake, spotted), Gestalt grouping, emphasis levers, grids, density, and page-level layout archetypes for apps and content pages.

## Category
UX

## Subcategories
visual hierarchy, scanning patterns, Gestalt, grids, whitespace, density, page layout archetypes, alignment

## Problem It Solves
Users scan rather than read. Flat hierarchy forces them to parse everything, hides the primary action, and makes dense app screens exhausting. Poor grouping causes mis-association (a label read as belonging to the wrong input, a button assumed to act on the wrong item).

## When To Use
- Designing a new page/screen or reorganizing an overloaded one.
- Dashboards, detail pages, settings pages, tables with toolbars.
- When usability tests show users missing a primary action or key information.

## When Not To Use
- Micro-level token definition (see spacing/typography skills).
- Navigation structure and labeling decisions (see information-architecture).

## Core Principles
1. **One focal point per view.** Decide the single most important element; everything else supports it.
2. **Users scan in patterns.** Text-heavy pages get F-pattern scanning; support "layer-cake" scanning with meaningful headings and front-loaded words.
3. **Grouping via proximity beats containers.** Internal spacing < external spacing, always.
4. **Alignment creates order.** Few alignment axes; strong left edge for LTR languages.
5. **Emphasis is relative.** To elevate one thing, reduce the others (Von Restorff: the different item stands out only if the rest are uniform).
6. **Reading order = DOM order.** Visual order must match source order for keyboard and screen reader users.
7. **Density follows task.** Expert, repeated tasks tolerate high density; occasional tasks need more whitespace.
8. **Chunk content** into groups of manageable size (Chunking; Miller's Law as a caution against long ungrouped lists, not a hard "7" rule).

## Best Practices
- Front-load headings and list items with the information-carrying word ("Billing: update card" not "Click here to update your billing card").
- Heading levels reflect structure (h1 once per page, no skipped levels).
- Put page-level primary action in a predictable location (top-right of page header in apps; end of form).
- Summaries before details: totals, status, key metadata at top of detail pages.
- Use a 12-column grid (desktop) with consistent gutters (16-24px); 4 columns on mobile.
- Max content width for reading: ~65-75ch; app shells may be full-width but constrain forms (~480-640px).
- Tables: right-align numbers, left-align text, align headers with their data.
- Use whitespace to separate sections (32-64px), not stacked dividers.
- Limit emphasis tools per screen: e.g., one accent color usage for CTA, one bold level for headings.

## Implementation Guidance

Layout archetypes:

| Archetype | Use for | Structure |
|---|---|---|
| App shell | SaaS apps | Top bar + collapsible sidebar + main; page header (title, actions) |
| List-detail | Inbox, CRM | List pane + detail pane (stack on mobile) |
| Dashboard | Monitoring | Summary KPIs row -> primary chart -> secondary widgets |
| Settings | Preferences | Left section nav + grouped forms; one save model |
| Article | Docs, blog | Centered 65ch column + optional TOC rail |
| Form page | Transactions | Single column, 480-640px, actions at end |

```css
/* Page header with title + actions, wraps on small screens */
.page-header { display:flex; flex-wrap:wrap; align-items:end; justify-content:space-between; gap: var(--space-4); margin-block-end: var(--space-8); }
.page-header h1 { font-size: var(--text-2xl); font-weight: 600; }
.page-header p { color: var(--neutral-600); max-width: 65ch; }

/* Section rhythm: more space between sections than within */
.stack > * + * { margin-block-start: var(--stack-gap, var(--space-4)); }
.section + .section { margin-block-start: var(--space-12); }

/* Responsive grid without media queries */
.auto-grid { display:grid; gap: var(--space-6); grid-template-columns: repeat(auto-fill, minmax(min(18rem, 100%), 1fr)); }
```

Emphasis ladder (use from top to bottom, stop when enough):
1. Position (top/left, near related content)
2. Weight (400 -> 600)
3. Color contrast (neutral-600 -> neutral-900 / brand)
4. Size (one step)
5. Container/background
6. Motion (rarely; respect reduced motion)

## Recommended Workflow
1. List content items and rank them (Must see / Should see / On demand).
2. Choose archetype; place Must-see items in the first viewport region.
3. Group with proximity; label groups with headings.
4. Apply emphasis ladder to the top-ranked items only.
5. Verify DOM order equals visual order; check heading outline (e.g., HeadingsMap).
6. Squint/blur test and 5-second test: "What is this page for? What would you click?"
7. Test at 320px, 768px, 1280px, 1920px.

## Patterns
- **Inverted pyramid**: conclusion/status first, then details, then background.
- **Z-pattern for sparse hero**: logo -> nav -> headline -> CTA.
- **Key-value summary grid**: `dl` in 2-4 columns at top of detail page.
- **Sticky action bar**: for long edit pages, keep Save/Cancel visible.
- **Progressive density toggle**: "Comfortable / Compact" row density for tables.

## Anti-Patterns
- **Centered everything** — ragged edges, slow scanning. Fix: left-align body and forms; center only short hero content.
- **Equal-weight cards grid for unequal importance** — nothing stands out. Fix: make the key metric larger or span columns.
- **Visual order differs from DOM (CSS `order`, absolute positioning)** — keyboard confusion (fails 1.3.2/2.4.3). Fix: reorder source.
- **Ambiguous spacing** — label equidistant between two fields. Fix: label closer to its input than to the previous field.
- **Wall of text** — Fix: headings, bullets, bolded key phrases, shorter paragraphs.
- **Full-width lines on wide monitors** — Fix: `max-width: 65ch` for prose.
- **Hiding the primary action below the fold on first use** — Fix: place in page header or first viewport.

## Accessibility
- Meaningful sequence (1.3.1, 1.3.2), focus order (2.4.3).
- Headings and labels describe topic or purpose (2.4.6); use landmarks (`header`, `nav`, `main`, `aside`).
- Reflow at 320px without horizontal scroll (1.4.10), except data tables.
- Don't encode grouping only visually: use `fieldset/legend`, lists, `section` with `aria-labelledby`.

## Responsive Design
- Collapse multi-column to single column in priority order, not source-accident order.
- Use container queries for components that appear in both sidebars and main areas.
- On mobile, key summary and primary action appear before secondary panels; sidebars become drawers or tabs.

## Performance
- CSS Grid/Flex layouts over JS-measured layouts; reserve space for async content to avoid CLS.
- Avoid rendering hidden desktop-only panels on mobile if expensive; render conditionally.

## Security
- Keep security-relevant info (account being acted on, environment "Production") visually prominent to prevent mistaken actions.

## Testing
- 5-second tests and first-click tests (Lyssna, Maze).
- Screenshot diffs across breakpoints.
- Automated heading-order and landmark checks (axe rules `heading-order`, `region`).

## Tooling
- Browser DevTools grid/flex overlays, Polypane, HeadingsMap extension, Lyssna/Maze for 5-second tests.

## Framework Notes
- **React (Vite SPA)**: build layout primitives (`Stack`, `Cluster`, `Grid`, `PageHeader`) once; expose `gap` tokens, not raw values.
- **Next.js (App Router)**: put the app shell (nav, sidebar, page chrome) in `layout.tsx` so it persists across navigations; keep layout primitives as Server Components; use `loading.tsx` skeletons that mirror the final layout to avoid shift.

## AI Agent Guidance
- Do: rank content before placing it; one focal point; use layout primitives already in the codebase.
- Don't: use CSS `order` or absolute positioning to reorder meaningful content; don't center long text.
- Verify: heading outline is logical, DOM order matches visual order, primary action visible in first viewport at 375px and 1440px.

## Examples
```tsx
export function DetailPage({ order }: { order: Order }) {
  return (
    <main>
      <header className="page-header">
        <div>
          <h1>Order #{order.number}</h1>
          <p>Placed {formatDate(order.placedAt)} by {order.customer.name}</p>
        </div>
        <div className="flex gap-2">
          <Button emphasis="secondary">Print</Button>
          <Button emphasis="primary">Mark as shipped</Button>
        </div>
      </header>
      <dl className="grid grid-cols-2 md:grid-cols-4 gap-6">
        <Stat label="Status" value={<StatusBadge status={order.status} />} />
        <Stat label="Total" value={formatMoney(order.total)} />
        <Stat label="Items" value={order.items.length} />
        <Stat label="Payment" value={order.paymentMethod} />
      </dl>
      <section aria-labelledby="items-h" className="section">
        <h2 id="items-h">Items</h2>
        {/* table */}
      </section>
    </main>
  );
}
```

## Related Skills
- [ui-design-principles-for-engineers](../ui-design-principles-for-engineers/Skill.md) — scales and emphasis basics
- [information-architecture](../information-architecture/Skill.md) — what goes where across pages
- [spacing-and-layout-systems](../spacing-and-layout-systems/Skill.md) — tokenized spacing
- [css-grid-and-flexbox-layout](../css-grid-and-flexbox-layout/Skill.md) — implementation mechanics
- [dashboard-design](../dashboard-design/Skill.md) — dashboard-specific hierarchy
- [landmarks-and-accessible-navigation](../landmarks-and-accessible-navigation/Skill.md) — structural semantics

## Sources
- [NN/g F-Shaped Pattern](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/) — Community (research) — scanning patterns
- [Laws of UX](https://lawsofux.com/) — Community — Proximity, Common Region, Von Restorff, Chunking
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Open Source (MIT) — layout rules
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — sequence, reflow
- [Refactoring UI](https://www.refactoringui.com/) — Community — hierarchy via de-emphasis (principle only)

## License / Usage Notes
Summarized principles in original wording; code is original.

## Quality Tier
A — well-established research-backed principles with concrete implementation.

## Status
Active

## Last Verified
2026-09-15
