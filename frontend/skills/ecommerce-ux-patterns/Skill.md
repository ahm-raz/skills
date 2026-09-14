# Ecommerce UX Patterns

## Summary
Research-backed patterns for the browse-to-cart part of online retail: homepage and category navigation, product listing pages (PLP) with filters and sorting, on-site search, product detail pages (PDP), cart, account and order tracking. It covers the technical architecture too: rendering and caching for large catalogs, structured data for product rich results, inventory and price freshness, and analytics events. Checkout itself is covered in [checkout-flow-design](../checkout-flow-design/Skill.md).

## Category
Product Patterns

## Subcategories
Product listing pages, faceted navigation, product detail pages, variants, reviews, cart, wishlists, order tracking, product structured data, headless commerce

## Problem It Solves
Ecommerce conversion is lost long before checkout. Filters don't match how shoppers think, product images are insufficient, and shipping costs and delivery dates are hidden until late. Variant selection is confusing, and PLPs load slowly or are client-rendered and poorly indexed. Baymard's large-scale research finds most sites still have mediocre UX in these areas. This skill gives the anatomy and rules for each page type.

## When To Use
- Building or redesigning a storefront (DTC, retail, B2B catalog) with Next.js on a headless commerce API (Shopify Storefront API, commercetools, BigCommerce, Medusa, Saleor) or a custom backend.
- Designing PLP filters, PDP layouts, variant pickers, cart drawers.
- Improving product SEO and structured data.

## When Not To Use
- Payment and checkout steps: [checkout-flow-design](../checkout-flow-design/Skill.md).
- Multi-seller platforms with seller onboarding and trust mechanics: [marketplace-ux-patterns](../marketplace-ux-patterns/Skill.md).
- Generic filter component mechanics: [filters-and-faceted-search](../filters-and-faceted-search/Skill.md).

## Core Principles
1. **Total cost and delivery date early.** Unexpected extra costs are the most-cited reason for abandoning checkout (about 48% of US shoppers in Baymard's surveys). Show shipping thresholds, estimated taxes/fees, and delivery dates on PDP and cart.
2. **Filters mirror shopper vocabulary.** Filters should match the product attributes shoppers care about for that category (e.g., "Fit" for jeans, "Screen size" for TVs), not generic ones.
3. **Images carry the sale.** Provide multiple high-resolution images, including in-scale/in-use shots, zoom, and variant-specific images.
4. **Variants are explicit.** Show available and unavailable options visually. Never let users add an invalid combination.
5. **Every listing state is linkable.** Category + filters + sort + page reflect in the URL.
6. **Indexable and fast.** PLP/PDP HTML must contain product names, prices, and links server-side. Personalization layers on top.
7. **Trust is cumulative.** Reviews, return policy, security, and contact info should be visible without hunting.

## Best Practices

### Navigation and homepage
- Main nav by category with clear, mutually exclusive labels; the mega menu shows subcategories, not promotional clutter.
- Show category "intermediary" pages for broad categories (visual subcategory tiles) before dumping thousands of products.
- Homepage: value props (free shipping threshold, returns), key categories, current promotions, best sellers. Avoid auto-rotating carousels as the only path.

### Search
- Search field visible (not icon-only) on desktop; autocomplete with query suggestions, categories, and products with thumbnails.
- Tolerate typos, synonyms, plurals, and units ("32 inch", "32in").
- No-results page: spelling suggestion, related categories, popular products, never a dead end.

### PLP (category and search results)
- Display applied filters as removable chips above results + "Clear all".
- Common filters promoted (price, size, color, rating, availability/in-stock, delivery speed) with counts.
- Sort options: Relevance/Featured, Best selling, Price low–high, high–low, Newest, Top rated.
- Product card: image (swap to alternate on hover only on pointer devices), name, price (and sale price with original), rating + count, swatches for key variants, badges sparingly ("Low stock" only if true).
- Pagination vs load more vs infinite scroll: "Load more" button with URL updates is a good default. Infinite scroll hurts footer access and return position.
- Preserve scroll position and filters when returning from PDP.

### PDP
- Above the fold (desktop): gallery left, buy box right: title, rating summary link, price, variant selectors, quantity, Add to cart, delivery estimate ("Get it by Thu, Sep 18"), shipping/returns summary.
- Below: description (scannable bullets first), specs table, size guide, reviews (with filters and images), Q&A, related/complementary products.
- Variant selection updates URL (`?variant=123`), price, images, stock, and SKU.
- Out of stock: say so clearly, offer "Notify me" and alternatives; keep page indexable if restock expected.
- Reviews: show distribution histogram, allow sorting by most recent/helpful, show negative reviews (their presence increases credibility).

### Cart
- Cart drawer or page confirms add-to-cart without navigating away (unless the shopper prefers going to cart).
- Line items: image, name, variant, price, quantity stepper (buttons, not only text entry), remove, save for later.
- Order summary: subtotal, shipping (or estimate/threshold progress), taxes (estimate or "calculated at checkout" explicitly), discounts, total.
- Promo code field collapsed behind a link, since an open field sends users off-site to hunt for coupons.
- Persist the cart server-side for signed-in users and in a cookie/ID for guests; merge on login.

### Account and post-purchase
- Order list with status, tracking link, reorder, return initiation.
- Guest order lookup by email + order number.

## Implementation Guidance

### Rendering strategy
| Page | Strategy | Notes |
|------|----------|-------|
| Home, category landing | SSG/ISR + CDN | Revalidate on merchandising changes |
| PLP | SSR or ISR per canonical filter combo; client transitions for filter changes | Only index curated filter combos; `noindex` or canonical others |
| PDP | ISR with short TTL + on-demand revalidation on price/stock webhook | Price/stock island refreshed client-side if volatile |
| Cart, account | Dynamic, uncached, per user | Never cache at CDN |
| Search results | SSR, usually `noindex` for arbitrary queries | Avoid index bloat |

### Faceted URL strategy
- Canonical category URL: `/c/jeans`.
- Filters as query params in stable order: `/c/jeans?fit=slim&color=blue`.
- Indexable curated facets get clean paths: `/c/jeans/slim-fit` with unique title/description/content.
- Other combos: `<link rel="canonical" href="/c/jeans">` or `noindex`, and don't put crawlable links to infinite combinations (use buttons/forms for filter toggles, or `rel="nofollow"` is not sufficient alone).

### Structured data (PDP)
Use `Product` with `offers` for merchant listing eligibility; add shipping and return policy; use `ProductGroup` for variants.

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Merino Crew Sweater",
  "image": ["https://shop.example/img/crew-1.avif"],
  "description": "Midweight merino wool crew neck.",
  "sku": "MCS-NAVY-M",
  "brand": { "@type": "Brand", "name": "Example" },
  "aggregateRating": { "@type": "AggregateRating", "ratingValue": 4.6, "reviewCount": 212 },
  "offers": {
    "@type": "Offer",
    "url": "https://shop.example/p/merino-crew?variant=navy-m",
    "priceCurrency": "USD",
    "price": 89.00,
    "availability": "https://schema.org/InStock",
    "itemCondition": "https://schema.org/NewCondition",
    "shippingDetails": { "@type": "OfferShippingDetails",
      "shippingRate": { "@type": "MonetaryAmount", "value": 0, "currency": "USD" },
      "shippingDestination": { "@type": "DefinedRegion", "addressCountry": "US" } },
    "hasMerchantReturnPolicy": { "@type": "MerchantReturnPolicy", "applicableCountry": "US",
      "returnPolicyCategory": "https://schema.org/MerchantReturnFiniteReturnWindow", "merchantReturnDays": 30 }
  }
}
</script>
```
Structured data must match visible page content (price, availability, rating). Generate it from the same data as the UI.

### Analytics events (GA4-style ecommerce names)
`view_item_list`, `select_item`, `view_item`, `add_to_cart`, `remove_from_cart`, `view_cart`, `begin_checkout`, `purchase` (send `purchase` from the server/webhook, not only the thank-you page).

## Recommended Workflow
1. Gather category-specific attributes and top shopper questions (support tickets, search logs).
2. Define URL scheme for categories, facets, variants; decide indexable facet set.
3. Build PDP buy box with variant state machine + delivery estimate + structured data.
4. Build PLP with URL-synced filters, chips, sort, load more, scroll restoration.
5. Build cart drawer/page with full cost summary and persistence.
6. Add search autocomplete and no-results handling.
7. Instrument ecommerce events; validate with Rich Results Test; RUM for CWV on PLP/PDP.
8. Usability test with 5+ shoppers per key flow; iterate.

## Patterns
- **Variant state machine:** `options → resolved variant | null`; disable impossible combos while keeping them visible with "Unavailable" labels.
- **Free shipping progress:** "You're $12 away from free shipping" with a progress bar in cart.
- **Sticky add-to-cart (mobile):** appears when the main button scrolls out; includes selected variant.
- **Size guide dialog + fit recommendation:** "Runs small: 62% of reviewers suggest sizing up" (only from real data).
- **Back-in-stock notification:** email capture per variant.
- **Recently viewed:** local storage list, rendered client-side below the fold.

## Anti-Patterns
- **"Calculated at checkout" for all costs.** Top abandonment driver. Fix: estimate by location or show thresholds and flat rates early.
- **Filters that reset on navigation back.** Fix: URL-synced state + scroll restoration.
- **Dropdown variant selectors hiding availability.** Fix: buttons/swatches with availability state.
- **Only studio images.** Fix: add scale, in-use, texture close-ups, and customer images.
- **Infinite scroll without URL state.** Fix: "Load more" with `?page=` updates.
- **Fake low-stock or countdown badges.** Deceptive; regulators increasingly act on these. Fix: real inventory thresholds only.
- **Client-only rendered PLP.** Poor indexing and LCP. Fix: SSR/ISR the initial product grid.
- **Add-to-cart that navigates away with no confirmation.** Fix: drawer/toast with cart summary and "Checkout" + "Continue shopping".

## Accessibility
- Product cards: one link wrapping the product name (card clickable via pseudo-element), not nested interactive elements.
- Swatches: radio group semantics with accessible names ("Navy"), not color alone (WCAG 1.4.1).
- Price: sale prices expose both values textually ("Was $120, now $89").
- Filter changes: announce result count via polite live region ("48 products").
- Image gallery: thumbnails are buttons with labels; zoom operable via keyboard; alt text describes the view.
- Quantity stepper: buttons with labels, input with `inputmode="numeric"`, and bounds announced.
- Star ratings: text equivalent ("4.6 out of 5, 212 reviews").
- The European Accessibility Act applies to ecommerce services in the EU from 28 June 2025.

## Responsive Design
- Mobile PLP: filters in a full-height sheet with "Show 48 results" apply button; sort as separate control.
- Two-column product grid on phones; ensure prices and names not truncated to uselessness.
- PDP gallery: swipeable with visible indicators and thumbnails; pinch zoom not disabled.
- Sticky add-to-cart bar on mobile PDP.

## Performance
- LCP on PDP is usually the primary product image: serve responsive AVIF/WebP, `fetchpriority="high"`, explicit dimensions.
- PLP images below the first rows lazy-load; reserve aspect ratio to avoid CLS.
- Filter interactions: keep INP ≤ 200ms by transitioning results (`startTransition`) and debouncing range sliders.
- Third-party (reviews widgets, personalization, chat) are frequent LCP/INP regressions; SSR reviews summary from API instead of client widget where possible.
- Edge cache PLP/PDP HTML; keep cart/price islands dynamic.

## Security
- Never trust client-side price, discount, or quantity: server recalculates cart totals.
- Rate-limit coupon validation and inventory endpoints (scraping, coupon brute force).
- Bot mitigation for high-demand drops (queue page, proof-of-work challenge) without blocking assistive tech.
- Storefront API tokens exposed to the browser must be public/read-only scoped (e.g., Shopify Storefront public token), admin tokens server-only.
- User-generated reviews: sanitize HTML; moderate images.

## Testing
- E2E: search → filter → PDP variant → add to cart → cart totals correct; back navigation restores filters.
- Variant matrix unit tests: impossible combos disabled, price/image updates.
- Structured data validation in CI (schema lint) + manual Rich Results Test on templates.
- Visual regression on product card and buy box across breakpoints.
- Load tests on PLP/search for sale events.

## Tooling
- Headless commerce: Shopify (Hydrogen/Storefront API), commercetools, BigCommerce, Medusa (open source), Saleor (open source), Vendure (open source).
- Search: Algolia, Typesense (open source), Meilisearch (open source), Elastic, Constructor.
- Reviews: Yotpo, Okendo, Judge.me, Bazaarvoice (prefer API/SSR integration).
- Validation: Google Rich Results Test, Schema Markup Validator.

## Framework Notes
- **Next.js App Router (primary):**
  - Route map: `app/(shop)/c/[...slug]/page.tsx` (PLP), `app/(shop)/p/[handle]/page.tsx` (PDP), `app/cart/page.tsx` (dynamic).
  - `generateStaticParams` for top products and categories; the rest render on first request and are cached.
  - Commerce reads are cached and tagged: `"use cache"` + `cacheTag(\`product:${handle}\`)` with Cache Components, or `fetch(url, { next: { tags: [...] } })`.
  - A commerce webhook Route Handler calls `revalidateTag(\`product:${handle}\`, "max")`, or `{ expire: 0 }` for price and stock changes that must not be served stale. The single-argument form is deprecated in Next.js 16.
  - PLP filters: read `searchParams` on the server for the initial grid. Update the URL client-side with nuqs (`shallow: false` so server data refetches) inside `startTransition`.
  - `generateMetadata` for PDP title, description, canonical (strip tracking and non-canonical params), `openGraph.images`. JSON-LD rendered in the page from the same product object as the UI.
  - `next/image` with `loading="eager"` + `fetchPriority="high"` on the first gallery image (not the deprecated `priority` prop) and `sizes` on grid cards; configure `images.remotePatterns` for the commerce CDN.
  - Cart: cart ID in an httpOnly cookie, mutations via Server Actions (`addToCart`) that call `updateTag("cart")` and return the updated cart; `useOptimistic` for quantity changes, rolled back on error.
  - `sitemap.ts` generated from the catalog API (split with `generateSitemaps` for large catalogs).
  - Vercel's open-source Next.js Commerce is a useful reference implementation. Shopify Hydrogen is a separate React Router-based stack, out of scope here.
- **React (Vite SPA):** acceptable for authenticated B2B catalogs or behind-login reorder portals where SEO is irrelevant. Public storefronts need server rendering for indexation and LCP.

## AI Agent Guidance
- Don't invent prices, ratings, stock levels, or reviews. Wire them to data or clearly marked fixtures.
- Always compute totals server-side; UI totals are display only.
- Keep structured data generated from the same source as visible content.
- Verify before done:
  - [ ] Filters/sort/page/variant reflected in URL; back button restores state
  - [ ] Delivery estimate and shipping/returns info visible on PDP
  - [ ] Cart shows full cost breakdown or explicit estimates
  - [ ] Swatches and filters keyboard- and screen-reader-operable
  - [ ] Rich Results Test passes for PDP template
  - [ ] PDP LCP image is prioritized; no CLS from gallery or reviews widget

## Examples

```tsx
// Variant picker as accessible radio groups (React)
function OptionGroup({ name, values, selected, isAvailable, onChange }: {
  name: string; values: string[]; selected?: string;
  isAvailable: (v: string) => boolean; onChange: (v: string) => void;
}) {
  return (
    <fieldset>
      <legend>{name}{selected ? `: ${selected}` : ""}</legend>
      <div className="swatches">
        {values.map(v => {
          const available = isAvailable(v);
          return (
            <label key={v} className="swatch" data-unavailable={!available || undefined}>
              <input type="radio" name={name} value={v} checked={selected === v}
                     onChange={() => onChange(v)} aria-describedby={!available ? `${name}-${v}-na` : undefined} />
              <span>{v}</span>
              {!available && <span id={`${name}-${v}-na`} className="sr-only">(sold out)</span>}
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}
```
Sold-out options stay selectable so shoppers can reach "Notify me". The buy button reflects availability.

## Related Skills
- [checkout-flow-design](../checkout-flow-design/Skill.md) — the next stage after cart
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — facet component mechanics
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — search UI
- [marketplace-ux-patterns](../marketplace-ux-patterns/Skill.md) — multi-seller variants
- [seo-for-frontend](../seo-for-frontend/Skill.md) — indexation of facets, structured data
- [image-optimization](../image-optimization/Skill.md) — product media performance
- [carousels](../carousels/Skill.md) — galleries and merchandising rails
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — urgency/scarcity limits
- [drawers-and-sheets](../drawers-and-sheets/Skill.md) — cart drawer and mobile filter sheet

## Sources
- [Baymard Institute — Cart abandonment rate statistics](https://baymard.com/lists/cart-abandonment-rate) — Official research — 70.22% average abandonment; extra costs as top reason
- [Baymard Institute — Current state of checkout UX](https://baymard.com/blog/current-state-of-checkout-ux) — Official research — delivery dates, quantity steppers, fulfillment options
- [Google Search Central — Product structured data](https://developers.google.com/search/docs/appearance/structured-data/product) — Official — product snippet vs merchant listing, shipping/returns, variants
- [NN/g — Ecommerce UX: Product Pages report](https://www.nngroup.com/reports/ecommerce-ux-product-pages-including-reviews/) — Official research — PDP and review guidelines (summary level)
- [Google Search Central — JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics) — Official — crawlable links, rendering
- [schema.org Product](https://schema.org/Product) — Official — vocabulary

## License / Usage Notes
Baymard and NN/g reports are paywalled; only publicly available summary findings are paraphrased. Code examples are original.

## Quality Tier
A — Grounded in the largest public ecommerce UX research bodies and Google's official product docs; detailed Baymard guidelines are paywalled so some specifics are summary-level.

## Status
Active

## Last Verified
2026-09-15
