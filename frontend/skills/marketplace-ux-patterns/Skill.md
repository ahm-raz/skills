# Marketplace UX Patterns

## Summary
Patterns for two- or multi-sided marketplaces: goods (Etsy-style), services and freelancers, rentals, and B2B procurement. It covers both sides of the product: buyer search and discovery, listing detail, trust and safety signals, messaging, booking or ordering, reviews, and disputes, plus the seller/provider onboarding, listing creation, and payouts dashboard. On the technical side it covers Next.js rendering for millions of listings, split payments via platform payment providers (e.g., Stripe Connect), moderation, and search indexing.

## Category
Product Patterns

## Subcategories
Two-sided marketplaces, listing search, trust and safety, reviews and reputation, in-platform messaging, seller onboarding, KYC for payouts, split payments, disputes, moderation

## Problem It Solves
Marketplaces fail when buyers can't trust strangers, sellers find listing tedious, liquidity is invisible (empty search results), or buyers and sellers move off-platform through contact details in messages. They also fail when payment and payout flows are confusing or non-compliant. Single-merchant ecommerce patterns don't cover identity, reputation, messaging, or dual-sided dashboards.

## When To Use
- Building a platform where third parties list goods, services, spaces, or talent, and buyers transact with them.
- Adding seller onboarding, reviews, messaging, or payouts to an existing product.

## When Not To Use
- Single-merchant stores: [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md).
- Payment step details: [checkout-flow-design](../checkout-flow-design/Skill.md).
- Internal ops tooling for moderation queues at scale: [admin-panel-architecture](../admin-panel-architecture/Skill.md) and [workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md).

## Core Principles
1. **Trust is the product.** Verified identity, transparent reviews, clear policies, and platform-held payment are what make strangers transact.
2. **Design for both sides.** Buyer and seller experiences are separate IA trees sharing one identity. A user may be both.
3. **Show liquidity, never emptiness.** Search should always return something useful: widen radius or dates, show near matches, or offer alerts.
4. **Keep the transaction on-platform** by making on-platform the easiest and safest path (protection, messaging, payment), not only by blocking.
5. **Reviews must be credible.** Only verified transactions can review, both sides review, and reviews are revealed simultaneously (double-blind) where retaliation matters.
6. **Money flows are explicit.** Buyers see the full price including platform fees. Sellers see fees, payout timing, and holds before listing.
7. **Moderation is a system.** Report → queue → decision → notification → appeal, with audit trails.

## Best Practices

### Buyer side
- Search: primary query box plus the dimension that defines liquidity (location/radius, dates, category). Map + list split view for local marketplaces, with the list as the accessible primary.
- Result cards: photo, title, price (per unit/night/hour), rating + count, seller badge (verified, top-rated), distance or delivery estimate, "new" if few reviews (not a fake rating).
- Listing detail: gallery, key facts, price breakdown, availability/calendar, seller card (photo, name, tenure, response rate/time, verification badges, rating), reviews with distribution, policies (cancellation, returns, protection guarantee), message seller, primary action (Book/Buy/Request).
- Price transparency: show all mandatory fees in the displayed price or clearly before selection. Drip pricing is a regulatory target (e.g., the FTC fees rule for short-term lodging and live-event tickets, effective 2025; EU consumer law).
- Saved searches and alerts for low-liquidity queries.

### Seller side
- Onboarding: value proposition → account → create first listing (draft auto-saved) → payouts/KYC. Defer KYC until payouts are needed if the provider allows, but state that it is required before the first payout.
- Listing creation: stepper with live preview, photo upload with guidance (count, orientation, quality tips), price suggestions from comparable listings, completeness meter.
- Seller dashboard: action items first (new orders/requests, messages awaiting reply, expiring listings), then earnings (pending, available, paid out), performance (views, conversion, rating), listings table.
- Payout transparency: fee breakdown per order, payout schedule, holds and reasons, tax forms.

### Messaging
- Thread per listing/transaction with listing context card at top.
- Detect and warn (not silently delete) on off-platform contact sharing before booking; explain protection loss.
- Attachment scanning, report message, block user.
- Response-time expectations visible to buyers.

### Reviews and disputes
- Review prompt after completion, with structured sub-ratings plus text. Sellers get a public response option.
- Dispute center: order timeline, evidence upload, platform decision, status notifications.

## Implementation Guidance

### Rendering (Next.js App Router)
| Page | Strategy |
|------|----------|
| Home, category and city landing pages | Static + tagged cache, revalidate on inventory changes |
| Search results | Dynamic (query-dependent), streamed; index only curated category/location pages |
| Listing detail | Cached per listing with `cacheTag("listing:"+id)`; availability/price island dynamic |
| Seller profile (public) | Cached per seller; revalidate on review/listing change |
| Dashboards, messages, checkout | Dynamic, per user, never cached |

```ts
// app/(market)/l/[id]/page.tsx — cached listing + dynamic availability
import { Suspense } from "react";
import { notFound } from "next/navigation";
import { getListing } from "@/server/listings"; // "use cache" + cacheTag inside
import { Availability } from "./availability";   // reads live calendar, dynamic

export default async function ListingPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const listing = await getListing(id);
  if (!listing || listing.status !== "published") notFound();
  return (
    <main>
      <ListingHeader listing={listing} />
      <SellerCard sellerId={listing.sellerId} />
      <Suspense fallback={<AvailabilitySkeleton />}>
        <Availability listingId={id} />
      </Suspense>
      <Reviews listingId={id} />
    </main>
  );
}
```

### Payments boundary
- Use a platform payments product (e.g., Stripe Connect, Adyen for Platforms). The provider handles connected-account KYC through hosted or embedded onboarding, so the platform never collects bank or ID documents directly.
- Model: buyer pays platform → platform fee retained → transfer to seller (destination charges or separate charges and transfers, depending on who is merchant of record).
- Embedded components (e.g., Connect embedded components for payouts, balances, and account management) reduce custom KYC UI and compliance burden.
- Payout and onboarding state comes from webhooks (`account.updated`, etc.), and the UI shows requirement banners ("Add your tax ID to receive payouts").

### Moderation pipeline
`listing.submitted → automated checks (prohibited items, image classifier, duplicate detection) → published | pending_review → human decision → notify seller (reason + edit/appeal link)`.

## Recommended Workflow
1. Define the transaction unit (item, booking, hour, project), who is merchant of record, and fee model.
2. Map buyer and seller journeys separately. Identify trust signals required at each decision.
3. Build listing data model + moderation states + search index (Algolia/Typesense/Meilisearch/Postgres FTS).
4. Build buyer search → listing → transaction flow with fee-inclusive pricing.
5. Build seller onboarding with provider-hosted KYC, listing editor, and dashboard.
6. Add messaging with context and safety features; reviews tied to completed transactions.
7. Add disputes, reporting, and admin moderation queue.
8. Instrument two-sided metrics: search-to-contact, contact-to-transaction, seller activation, time to first sale, repeat rate.

## Patterns
- **Seller trust card:** avatar, name, "Joined 2021", "Responds within 2 hours", verified badges with tooltips explaining what was verified.
- **Near-match results:** "No exact matches for Sep 20–22. Showing places available Sep 21–23."
- **Completeness meter:** listing quality score with specific missing items ("Add 3 more photos").
- **Double-blind reviews:** hidden until both parties submit or the window closes.
- **Protection badge:** "Covered by Buyer Protection" at listing, checkout, and message composer.
- **Dual-role switcher:** "Switch to selling" in account menu; separate nav trees.

## Anti-Patterns
- **Fees revealed at the last step.** Fix: fee-inclusive prices, or an itemized breakdown before commitment.
- **Unverifiable badges ("Trusted seller") with no criteria.** Fix: link each badge to its definition.
- **Silent message censorship.** Fix: inline warning explaining protection and policy.
- **Empty search page.** Fix: widen criteria automatically with disclosure, and offer alerts.
- **KYC collected in custom forms storing ID images on your servers.** Fix: provider-hosted or embedded onboarding.
- **Reviews from non-transactions or incentivized only positive.** Fix: verified-transaction reviews; disclose incentives; never suppress negatives (regulators, e.g., the FTC's 2024 rule on fake reviews, target this).
- **Seller dashboard as vanity metrics.** Fix: actionable queue first.

## Accessibility
- Map views: the list is the equivalent, keyboard-operable primary. Map markers are focusable with names, or hidden from AT when duplicative (WCAG 1.1.1, 2.1.1). See [maps-and-geospatial-ui](../maps-and-geospatial-ui/Skill.md).
- Ratings as text ("4.8 out of 5, 126 reviews"); badges have text labels, not icon-only.
- Messaging: new messages announced politely; composer labelled; attachment errors announced.
- Calendars/availability: accessible date grid with unavailable dates conveyed non-visually (see [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md)).
- Listing photo upload: keyboard-accessible, progress announced, alt text prompt for sellers.

## Responsive Design
- Mobile search: list-first with "Map" toggle button; filters in full-screen sheet.
- Listing detail: sticky bottom bar with price + primary action on mobile.
- Seller dashboard: action queue as cards on mobile; tables become stacked rows.
- Photo capture from device camera: `<input type="file" accept="image/*" capture="environment">` as an option, not a requirement.

## Performance
- Search: debounce input, stream results, keep previous results visible during transitions (`useTransition`).
- Map: load the map library only when map view is opened (`next/dynamic` with `ssr: false`); cluster markers.
- Listing images through an image CDN via `next/image` with `sizes`; the first image has priority.
- Messaging: WebSocket/SSE for live threads; virtualize long threads.

## Security
- Authorization on every listing/order/message access (IDOR is the classic marketplace bug): user must be party to the transaction.
- Rate-limit messaging and listing creation; spam and scam detection.
- Mask contact details and hide exact addresses until booking where safety requires it.
- Signed, expiring URLs for private attachments; malware scanning.
- Webhooks from payments provider verified; payouts state never trusted from client.
- Server Actions re-check session and ownership (a seller can only edit own listings).

## Testing
- Authorization tests: user A cannot read B's messages, orders, or payouts via direct IDs.
- E2E: buyer search → message → book/buy; seller onboarding → listing → publish → receive order → payout pending.
- Moderation state transitions; notifications sent.
- Fee calculation unit tests (rounding, currency, refunds, partial refunds).
- Provider test mode for connected account requirements and payout failures.

## Tooling
- Payments for platforms: Stripe Connect (with embedded components), Adyen for Platforms, PayPal for Marketplaces, Mangopay (EU).
- Search: Algolia, Typesense (OSS), Meilisearch (OSS), Elastic, Postgres + PostGIS for geo.
- Messaging: in-house (Postgres + realtime), Stream Chat, Sendbird, TalkJS.
- Maps: Mapbox GL / MapLibre GL (OSS), Google Maps JS API.
- Moderation: provider image moderation APIs + in-house queue.

## Framework Notes
- **Next.js App Router (primary):**
  - Separate route groups `(market)` for public buyer pages, `(buyer)` for account and orders, and `(seller)/seller/...` for the seller dashboard, each with its own layout and nav.
  - Public listing and seller pages: cached with `cacheTag`. Dynamic islands use Suspense. `generateMetadata` + JSON-LD (Product/Offer or LocalBusiness as appropriate, generated from real data only).
  - Mutations (publish listing, send message, accept booking) as Server Actions with ownership checks and `updateTag`/`revalidateTag` for affected listing and seller tags.
  - Realtime messaging needs a separate realtime service (Route Handlers aren't long-lived socket servers on most serverless hosts).
- **React (Vite SPA):** suitable for the seller dashboard and messaging app when the public buyer site is server-rendered elsewhere. Use TanStack Query with keys scoped by user and role.

## AI Agent Guidance
- Identify which side (buyer/seller/admin) each screen serves before building.
- Never build custom ID/bank document collection; use provider onboarding.
- Never invent ratings, review counts, or badges. Use real data or labelled fixtures.
- Verify before done:
  - [ ] Ownership/party checks on every read and mutation (tested)
  - [ ] Full price including mandatory fees shown before commitment
  - [ ] Empty/near-match search state implemented
  - [ ] Map has an accessible list equivalent
  - [ ] Reviews only from completed transactions
  - [ ] Seller sees fees and payout timing before publishing

## Examples

```tsx
// Seller trust card
export function SellerCard({ seller }: { seller: PublicSeller }) {
  return (
    <section aria-labelledby="seller-heading" className="seller-card">
      <img src={seller.avatarUrl} alt="" width={56} height={56} />
      <div>
        <h2 id="seller-heading">{seller.displayName}</h2>
        <p>Member since {new Date(seller.joinedAt).getFullYear()}</p>
        {seller.reviewCount > 0
          ? <p>{seller.rating.toFixed(1)} out of 5 · {seller.reviewCount} reviews</p>
          : <p>New seller · no reviews yet</p>}
        {seller.medianResponseMinutes != null && <p>Usually responds within {formatDuration(seller.medianResponseMinutes)}</p>}
        <ul aria-label="Verifications">
          {seller.verifications.map(v => <li key={v}><a href={`/help/verification#${v}`}>{verificationLabel(v)}</a></li>)}
        </ul>
      </div>
    </section>
  );
}
```

## Related Skills
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md) — shared browse/listing patterns
- [checkout-flow-design](../checkout-flow-design/Skill.md) — buyer payment flow
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — discovery
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — result filtering
- [maps-and-geospatial-ui](../maps-and-geospatial-ui/Skill.md) — map/list views
- [file-upload](../file-upload/Skill.md) — listing photos, evidence
- [realtime-data-ui](../realtime-data-ui/Skill.md) — live messaging and availability
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — drip pricing, fake reviews
- [workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md) — moderation queues

## Sources
- [Stripe Docs — Online payments (platform/Connect options)](https://docs.stripe.com/payments/online-payments) — Official — hosted/embedded components, webhook lifecycle
- [Baymard Institute — checkout and cart research](https://baymard.com/lists/cart-abandonment-rate) — Official research — extra costs as top abandonment reason (applies to fee transparency)
- [Next.js docs — revalidateTag / cacheTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag) — Official — tag caching for listing pages
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — map alternatives, keyboard access
- NN/g articles on trust and credibility signals, reviews, and social proof (nngroup.com) — Official research — trust cues (summary level)
- FTC Rule on Unfair or Deceptive Fees and Rule on Consumer Reviews and Testimonials (ftc.gov) — Official — fee transparency and fake review prohibitions (summary; verify scope with counsel)

## License / Usage Notes
Summarized principles in original words; code original. Regulatory mentions are informational, not legal advice.

## Quality Tier
B — Solid synthesis of trust, payments, and accessibility guidance; limited public controlled research specific to marketplaces, and regulatory details vary by jurisdiction.

## Status
Active

## Last Verified
2026-09-15
