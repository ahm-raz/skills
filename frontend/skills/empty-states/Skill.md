# Empty States

## Summary
Empty states are what users see when a view has no content: first use, no search/filter results, cleared/completed items, missing permissions, or unavailable data. Well-designed empty states communicate system status, teach what belongs here, and give a direct path to the next action (NN/g). This skill covers the empty-state taxonomy, copy formulas, and React/Next.js implementation.

## Category
UX

## Subcategories
first-use states, zero results, cleared states, permission-empty, onboarding hooks, copy, illustrations, not-found

## Problem It Solves
Blank tables and "No data" text leave users unsure whether something is broken, still loading, filtered out, or simply unused. That lowers confidence, hides features and stalls activation.

## When To Use
- Every collection view (lists, tables, dashboards, inboxes, search, galleries).
- Any widget that can have zero items, including charts and activity feeds.

## When Not To Use
- While data is still loading (show loading state, not empty).
- When the request failed (show error state; never render "no items" on fetch failure).

## Core Principles
1. **Distinguish the cause**: first use vs. no results vs. cleared vs. no permission vs. error vs. loading. Each needs different copy and actions.
2. **Say what's here and why it's empty** in plain language.
3. **Offer the next best action** (primary CTA) directly in the empty state.
4. **Teach by showing value**: brief explanation, example, or template/sample data.
5. **Keep context**: page header, filters and nav remain visible, so users can recover.
6. **Match the tone of the moment**: celebratory for "inbox zero", neutral/helpful for no results, clear for permissions.
7. **Don't overdesign**: small containers get a line of text + action, not a big illustration.

## Best Practices
- First-use: headline naming the object ("No projects yet"), one sentence of value, primary action ("Create project"), optional secondary (import, template, docs link).
- No results (search/filter): echo query/filters, suggest fixes (check spelling, remove filters), "Clear filters" button, and nearby alternatives.
- Cleared/completed: positive confirmation ("You're all caught up"), link to archive/history.
- Permission: explain who can grant access and provide "Request access" rather than showing an empty list.
- Only show create CTAs to users who can create; otherwise explain who can.
- Keep illustrations optional, decorative (`alt=""`), small, and consistent with the icon/illustration style.
- Consider sample data or templates for complex tools (dashboards, automations), clearly labeled as sample.
- Charts with no data: keep axes/frame with a message inside, not a blank box.

## Implementation Guidance

Empty state taxonomy:

| Type | Trigger | Headline example | Primary action |
|---|---|---|---|
| First use | Collection never had items | "No invoices yet" | "Create invoice" |
| User cleared | All items done/archived | "You're all caught up" | "View archived" (secondary) |
| No results | Query/filter returns 0 | "No results for “acme corp”" | "Clear filters" |
| No permission | User lacks access | "You don't have access to Billing" | "Request access" |
| Unavailable | Feature not on plan / region | "Audit log is available on Business" | "Compare plans" (if appropriate) |
| Not found | ID doesn't exist | "We couldn't find that project" | "Go to projects" |
| Error | Fetch failed | (use error-states) | "Try again" |

Copy formula: **[What's empty] + [why / value in one sentence] + [action]**.

```tsx
// components/empty-state.tsx — Server Component friendly, no client JS required
import type { ReactNode } from "react";
type EmptyStateProps = {
  icon?: ReactNode;
  title: string;
  description?: ReactNode;
  primaryAction?: ReactNode;
  secondaryAction?: ReactNode;
  size?: "sm" | "md" | "lg";
  headingLevel?: "h2" | "h3";
};
export function EmptyState({ icon, title, description, primaryAction, secondaryAction, size = "md", headingLevel: H = "h2" }: EmptyStateProps) {
  return (
    <div className={`mx-auto flex max-w-md flex-col items-center text-center ${size === "sm" ? "py-6" : size === "lg" ? "py-20" : "py-12"}`}>
      {icon && size !== "sm" && <div aria-hidden className="mb-4 text-neutral-400">{icon}</div>}
      <H className="text-base font-semibold text-neutral-900">{title}</H>
      {description && <p className="mt-1 text-sm text-neutral-600">{description}</p>}
      {(primaryAction || secondaryAction) && <div className="mt-6 flex flex-wrap justify-center gap-3">{primaryAction}{secondaryAction}</div>}
    </div>
  );
}
```

```tsx
// app/(app)/invoices/page.tsx — choose the right empty variant on the server
import Link from "next/link";
import { EmptyState } from "@/components/empty-state";
import { getInvoices, getViewer } from "@/lib/data";

export default async function InvoicesPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string }> }) {
  const { q, status } = await searchParams;
  const [viewer, invoices] = await Promise.all([getViewer(), getInvoices({ q, status })]);
  const filtered = Boolean(q || status);

  if (invoices.length === 0 && filtered) {
    return (
      <EmptyState
        title={q ? `No invoices match “${q}”` : "No invoices match these filters"}
        description="Try a different search term or remove some filters."
        primaryAction={<Link className="btn-secondary" href="/invoices">Clear filters</Link>}
      />
    );
  }
  if (invoices.length === 0) {
    return (
      <EmptyState
        size="lg"
        icon={<InvoiceIcon className="size-12" />}
        title="No invoices yet"
        description="Create an invoice to bill a client and track when it’s paid."
        primaryAction={viewer.can("invoice:create")
          ? <Link className="btn-primary" href="/invoices/new">Create invoice</Link>
          : <p className="text-sm">Ask a workspace admin to give you billing access.</p>}
        secondaryAction={viewer.can("invoice:create") ? <Link className="btn-tertiary" href="/invoices/import">Import from CSV</Link> : null}
      />
    );
  }
  return <InvoiceTable invoices={invoices} />;
}
```

## Recommended Workflow
1. Inventory every collection/widget and list which empty types can occur.
2. Write copy per type with the formula; review with the glossary.
3. Decide actions per role/permission.
4. Implement a shared `EmptyState` with size variants; wire variants on the data boundary (server).
5. Test with seeded accounts: brand-new user, filtered-to-zero, no permission, fetch error.
6. Measure: CTA click-through from first-use states (activation metric).

## Patterns
- **Starter templates**: first-use shows 3 template cards + "Start from scratch".
- **Inline empty row**: tables keep headers; single full-width cell with message + action.
- **Sample data toggle**: "Explore with sample data" labeled clearly and removable.
- **Contextual education**: 1-2 sentence explanation + "Learn how X works" link.
- **Search zero-results recovery**: spelling suggestion, popular items, contact/support.

## Anti-Patterns
- **"No data"** — says nothing. Fix: name the object and next step.
- **Empty state on error** — misleads (users think their data is gone). Fix: separate error state with retry.
- **Empty flash before data loads** — Fix: render empty only after the fetch resolves; loading state first.
- **CTA shown to users without permission** — leads to a dead end. Fix: role-aware actions.
- **Huge illustration in a small widget** — pushes content. Fix: `size="sm"` text-only.
- **Removing filters UI when zero results** — user can't recover. Fix: keep filters visible + "Clear filters".
- **Guilt-trip copy** ("You haven't done anything!") — Fix: neutral, value-focused copy.

## Accessibility
- Use a real heading for the empty title at the correct level (1.3.1).
- Illustrations decorative: `aria-hidden` / `alt=""`.
- When results become empty after filtering client-side, announce the count via polite live region ("0 results") (4.1.3).
- Actions are real links/buttons with descriptive text (2.4.4).

## Responsive Design
- Center within available area; stack actions vertically on narrow screens.
- Reduce or hide illustrations on small viewports to keep CTA above the fold.

## Performance
- Use inline SVG or small optimized images; lazy-load large illustrations; avoid Lottie for empty states unless already loaded.
- Server-render empty variants (no client fetch waterfall).

## Security
- Don't reveal existence of resources a user can't access; for unauthorized object IDs prefer "not found" over "no permission" when disclosure is sensitive.

## Testing
- Component tests (Testing Library) for each variant and role.
- Playwright with seeded empty accounts and MSW/route mocks returning `[]` vs 500 to ensure empty != error.
- Visual regression for empty variants.

## Tooling
- shadcn/ui `Empty` component (added 2025), design-system empty patterns (Carbon, Polaris), unDraw/Storyset for illustrations (check licenses), Lucide icons.

## Framework Notes
- **Next.js (App Router)**: decide variant in Server Components based on data + `searchParams`; use `not-found.tsx` + `notFound()` for missing objects; keep filters in URL so "Clear filters" is a `Link`.
- **React (Vite SPA)**: with TanStack Query, render empty only when `status === "success" && data.length === 0`; `isPending` -> skeleton; `isError` -> error state.

## AI Agent Guidance
- Do: implement first-use, no-results and error variants for every list you create; make CTAs permission-aware; keep filters visible.
- Don't: output "No data found"; don't render empty during loading or on error.
- Verify: test with an empty fixture, a filtered-to-zero URL, and a failing request; copy names the object and next step.

## Examples
```tsx
// Table empty row keeping headers
<tbody>
  {rows.length === 0 ? (
    <tr><td colSpan={columns.length}>
      <EmptyState size="sm" headingLevel="h3" title="No members match “ops”" primaryAction={<button className="btn-tertiary" onClick={clearSearch}>Clear search</button>} />
    </td></tr>
  ) : rows.map(renderRow)}
</tbody>
```

## Related Skills
- [loading-states](../loading-states/Skill.md) — state before empty is known
- [error-states](../error-states/Skill.md) — failure is not empty
- [onboarding-ux](../onboarding-ux/Skill.md) — first-use empty states as onboarding
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — copy formulas
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — zero-results recovery
- [iconography-and-illustration](../iconography-and-illustration/Skill.md) — illustration style
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — permission-aware actions

## Sources
- [NN/g: Designing Empty States in Complex Applications: 3 Guidelines](https://www.nngroup.com/articles/empty-state-interface-design/) — Community (research) — status, learnability, direct pathways
- [IBM Carbon: Empty states pattern](https://carbondesignsystem.com/patterns/empty-states-pattern/) — Official (design system) — taxonomy of empty types
- [Shopify Polaris: Empty state](https://polaris-react.shopify.com/components/layout-and-structure/empty-state) — Official (design system) — structure and copy
- [Next.js docs: not-found.js](https://nextjs.org/docs/app/api-reference/file-conventions/not-found) — Official

## License / Usage Notes
Principles summarized; code original. Carbon is Apache-2.0; Polaris docs are Shopify property (summarized only).

## Quality Tier
A — research and design-system backed with concrete Next.js implementation.

## Status
Active

## Last Verified
2026-09-15
