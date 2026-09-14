# SEO for Frontend

## Summary
The frontend engineer's responsibilities for search visibility in React + Next.js apps: crawlability and rendering, indexability controls, URL and canonical strategy, metadata, structured data, sitemaps and robots, internationalization signals, status codes in SPAs, Core Web Vitals as page experience, and the current state of rich results and AI search surfaces. It is a product-agnostic technical baseline. Product-specific SEO (ecommerce facets, blog taxonomies, docs versions) is covered in those skills.

## Category
Product Patterns

## Subcategories
Crawlability, JavaScript SEO, canonicalization, robots and noindex, sitemaps, metadata, Open Graph, structured data, hreflang, pagination, soft 404s, Core Web Vitals, AI search visibility

## Problem It Solves
SEO failures in modern frontends are mostly engineering bugs:
- Content that only renders client-side.
- Navigation that uses `onClick` instead of links.
- Error pages returning 200 (soft 404s).
- Canonicals rewritten inconsistently by JavaScript.
- `noindex` leaking from staging to production.
- Infinite crawlable filter URLs.
- Structured data that doesn't match visible content.

Structured-data advice also goes stale fast. Google retired several rich result types in 2025 and stopped showing FAQ rich results for nearly all sites on May 7, 2026. This skill gives current, verifiable rules.

## When To Use
- Any public, indexable React/Next.js site or app section.
- Launches, migrations, replatforms, domain/URL changes.
- Diagnosing indexing drops, duplicate content, or missing rich results.

## When Not To Use
- Authenticated app areas (should be `noindex` or blocked; minimal SEO work beyond that).
- Content strategy and keyword research (editorial disciplines); this skill is technical.
- Paid search/ads landing optimization: [landing-page-design](../landing-page-design/Skill.md).

## Core Principles
1. **Server-render indexable content.** Google renders JavaScript, but rendering is deferred and fragile. Critical content, links, and metadata must be in the initial HTML.
2. **Links are `<a href>`.** Google discovers links only from `<a>` elements with `href` attributes. Use History API routing, not fragments.
3. **One canonical URL per piece of content.** Keep canonical consistent in HTML and never change it with client JavaScript. Redirect or canonicalize duplicates.
4. **Status codes tell the truth.** Missing content returns 404/410, moved content 301/308, and temporary outages 503. SPAs must avoid soft 404s.
5. **Indexability is explicit per route.** Every route is intentionally indexable or `noindex`. Environments other than production are never indexable.
6. **Structured data describes visible content.** It must match what users see and use types that Google still supports for rich results.
7. **Page experience matters but doesn't replace relevance.** Meet Core Web Vitals (LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 at p75) as quality hygiene.
8. **Measure in Search Console.** Use indexing reports, URL Inspection, and Core Web Vitals field data, not only lab tools.

## Best Practices

### Metadata
- Unique `<title>` per page (primary topic first, brand last, ~50–60 chars visible) and meta description (~150–160 chars, not a ranking factor but affects clicks).
- Open Graph and Twitter/X card tags for share previews; `og:image` 1200×630.
- `<html lang>` set correctly; one H1 describing the page.

### Canonicals and duplicates
- Absolute self-referencing canonical on indexable pages.
- Strip tracking params (`utm_*`, `gclid`) via canonical; consider not generating internal links with them.
- Trailing slash and case consistency enforced with redirects.
- Paginated series: each page self-canonical (don't canonicalize page 2 to page 1). Google no longer uses `rel=next/prev` as an indexing signal, but crawlable pagination links are still necessary.

### Robots and noindex
- `robots.txt` controls crawling, not indexing. Blocked pages can still be indexed from links. Use `noindex` (meta or `X-Robots-Tag`) to keep pages out, and don't block them in robots.txt, or Google can't see the noindex.
- Google may skip rendering pages with `noindex` in the initial HTML, so removing noindex with JavaScript doesn't work.
- Preview/staging deployments: `X-Robots-Tag: noindex` header, plus auth where possible.

### Sitemaps
- Include only canonical, indexable, 200-status URLs; `lastmod` only when content meaningfully changed.
- Split at 50,000 URLs or 50MB uncompressed; use a sitemap index.
- Reference the sitemap in robots.txt; submit in Search Console.

### Structured data (JSON-LD)
- Still producing rich results (verify current list in Google docs): Product/merchant listings, Review snippets (with eligibility limits), Article, Breadcrumb, Organization/logo, LocalBusiness, Recipe, Video, Event, JobPosting, Discussion forum, Profile page, Software app, and others.
- Retired/limited: HowTo (removed), FAQ (no longer shown for nearly all sites as of May 7, 2026), and several types deprecated in June 2025 (e.g., Course Info, Claim Review, Estimated Salary, Learning Video, Special Announcement, Vehicle Listing). Schema.org vocabulary remains valid, but don't promise rich results for these.
- Generate JSON-LD from the same data as the visible UI; validate with Rich Results Test.

### International
- Locale in the URL path (`/de/...`) or subdomain/ccTLD; never locale by cookie/IP alone.
- `hreflang` alternates, reciprocal, including `x-default`; each locale self-canonical.

### SPA/JS specifics
- Soft 404s: return a real 404 status from the server for missing resources. In a client-only SPA, redirect to a server-404 URL or add `noindex` on error views.
- Lazy loading: content must load without user interaction (scroll or click). Use native `loading="lazy"` or IntersectionObserver for images, and never lazy-load above-the-fold content.
- Infinite scroll: provide paginated URLs that load the same items.
- Don't gate content behind cookie banners that remove it from the DOM.

### AI search surfaces
- Google's AI features (AI Overviews/AI Mode) use the same crawling/indexing systems. No special markup is required: follow the standard technical SEO baseline, and `nosnippet`/`max-snippet` controls apply.
- Other AI crawlers are controlled via their user agents in robots.txt (e.g., `GPTBot`, `ClaudeBot`, `PerplexityBot`; `Google-Extended` controls use in Gemini model training, not Search). Decide policy with legal/product.
- `llms.txt` is a community convention for agents and documentation tools, and Google Search doesn't use it. It's optional and cheap for docs.

## Implementation Guidance

### Next.js route indexability matrix
| Route type | Rendering | Robots | In sitemap |
|------------|-----------|--------|-----------|
| Home, marketing, blog, docs, product/category | Static/cached, server-rendered | index | Yes |
| Search results (`/search?q=`) | Dynamic | `noindex, follow` | No |
| Faceted combos (non-curated) | Dynamic/cached | canonical to base or `noindex` | No |
| Auth, account, app, checkout, cart | Dynamic | `noindex` (plus auth) | No |
| Preview/draft | Dynamic | `noindex` header | No |
| Error/not found | `notFound()` → 404 | n/a | No |

### Metadata defaults (root layout)
```tsx
// app/layout.tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://example.com"),
  title: { default: "Example — Reconciliation for finance teams", template: "%s | Example" },
  description: "Automated bank and card reconciliation for finance teams of 5–50.",
  openGraph: { siteName: "Example", type: "website", locale: "en_US" },
  twitter: { card: "summary_large_image" },
  robots: process.env.VERCEL_ENV === "production" || process.env.DEPLOY_ENV === "production"
    ? { index: true, follow: true }
    : { index: false, follow: false },
};
```
Also send `X-Robots-Tag: noindex` for non-production at the host/proxy level. Metadata alone is insufficient if non-HTML assets or other hosts leak.

### sitemap.ts and robots.ts
```ts
// app/sitemap.ts
import type { MetadataRoute } from "next";
import { getPublishedPosts, getProducts } from "@/server/content";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = "https://example.com";
  const [posts, products] = await Promise.all([getPublishedPosts(), getProducts({ indexable: true })]);
  return [
    { url: `${base}/`, lastModified: new Date("2026-09-01") },
    { url: `${base}/pricing` },
    ...posts.map(p => ({ url: `${base}/blog/${p.slug}`, lastModified: p.updatedAt ?? p.publishedAt })),
    ...products.map(p => ({ url: `${base}/p/${p.handle}`, lastModified: p.updatedAt })),
  ];
}
```
```ts
// app/robots.ts
import type { MetadataRoute } from "next";
export default function robots(): MetadataRoute.Robots {
  const prod = process.env.DEPLOY_ENV === "production";
  return prod
    ? { rules: [{ userAgent: "*", allow: "/", disallow: ["/api/", "/app/"] }], sitemap: "https://example.com/sitemap.xml" }
    : { rules: [{ userAgent: "*", disallow: "/" }] };
}
```
Use `generateSitemaps` to split large sitemaps.

### Per-page metadata with canonical and hreflang
```tsx
export async function generateMetadata({ params }: { params: Promise<{ locale: string; slug: string }> }): Promise<Metadata> {
  const { locale, slug } = await params;
  const page = await getPage(locale, slug);
  if (!page) return { robots: { index: false } };
  return {
    title: page.seoTitle ?? page.title,
    description: page.seoDescription,
    alternates: {
      canonical: `/${locale}/${slug}`,
      languages: Object.fromEntries(page.translations.map(t => [t.locale, `/${t.locale}/${t.slug}`]).concat([["x-default", `/en/${page.translations.find(t => t.locale === "en")?.slug ?? slug}`]])),
    },
    openGraph: { title: page.title, description: page.seoDescription, images: page.ogImage ? [page.ogImage] : undefined },
  };
}
```

### Breadcrumb JSON-LD helper
```tsx
export function BreadcrumbJsonLd({ items }: { items: { name: string; url: string }[] }) {
  const data = { "@context": "https://schema.org", "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => ({ "@type": "ListItem", position: i + 1, name: it.name, item: it.url })) };
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, "\\u003c") }} />;
}
```

## Recommended Workflow
1. Inventory routes and assign each to the indexability matrix.
2. Set root metadata defaults with environment-aware robots; add `robots.ts` and `sitemap.ts`.
3. Ensure all indexable routes render content and links server-side; audit `onClick` navigation.
4. Implement `generateMetadata` per template: title, description, canonical, OG, hreflang.
5. Add structured data per template where a supported rich result exists; validate.
6. Handle status codes: `notFound()`, `redirect()`/`permanentRedirect()`, redirects config for moved URLs.
7. Meet Core Web Vitals on key templates; set up RUM.
8. Verify in Search Console: URL Inspection (rendered HTML), Pages report, sitemaps, CWV. Re-check after each migration.

## Patterns
- **Environment guard:** robots metadata + `X-Robots-Tag` driven by a single `DEPLOY_ENV`.
- **Canonical builder:** a utility that normalizes paths (lowercase, no trailing slash, strips non-canonical params) used by metadata and internal link generation.
- **Crawlable filters:** curated facet pages as clean paths; other filters via buttons/forms updating query params with canonical to base.
- **Link component discipline:** Next `<Link href>` renders `<a href>`. Never `router.push` from a `div` for navigational items.
- **Redirect registry** with tests (see marketing site architecture).
- **Structured data from view model:** the same object feeds UI and JSON-LD.

## Anti-Patterns
- **Content fetched in `useEffect` on public pages.** Fix: Server Components/SSG.
- **`<div onClick={() => router.push(...)}>` navigation.** Not crawlable, not accessible. Fix: `<Link>`.
- **`noindex` shipped to production from staging config.** Fix: environment-driven defaults + monitoring (alert if production HTML contains noindex).
- **Blocking a page in robots.txt to deindex it.** Fix: allow crawl + `noindex`, then optionally block after removal.
- **200 status on "Not found" views.** Fix: `notFound()`.
- **Canonical to homepage for everything.** Fix: self-referencing canonicals.
- **FAQ/HowTo markup added for rich results in 2026.** No longer shown. Fix: focus on supported types; keep FAQ content for users.
- **Hash-based routing (`/#/products`).** Fix: path routing.
- **Hreflang without reciprocal links or pointing to non-canonical URLs.** Fix: generate from a translation map; validate.

## Accessibility
- SEO and accessibility share foundations: semantic headings (1.3.1), descriptive link text (2.4.4), meaningful page titles (2.4.2), `lang` attribute (3.1.1), and text alternatives for images (1.1.1).
- Don't hide content from users that's shown to crawlers (cloaking); equally, don't hide accessible names in `aria-label` only for SEO keyword stuffing.

## Responsive Design
- Google uses mobile-first indexing: the mobile rendering is what's indexed. Content, links, structured data, and metadata must be equivalent on mobile.
- Don't remove content on mobile via conditional rendering (CSS hiding in accordions is fine).
- Avoid intrusive mobile interstitials.

## Performance
- Core Web Vitals thresholds at p75: LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1.
- Crawl efficiency: fast server responses (TTFB), cacheable HTML for public pages, avoid generating infinite URL spaces.
- Image SEO: descriptive filenames and alt, `next/image` with proper `sizes`; image sitemaps for image-heavy sites.

## Security
- Open redirects harm users and SEO; validate redirect targets.
- Hacked content/spam injection: CSP, dependency hygiene, and monitoring for unexpected outbound links or pages in Search Console.
- JSON-LD injection: escape `<` in serialized JSON; never interpolate unsanitized user content into script tags.
- Preview/staging: auth + noindex; don't leak them in sitemaps.

## Testing
- CI checks per template (Playwright or a crawler):
  - HTTP status matches expected (200/404/301).
  - `<title>`, meta description, and canonical present and correct.
  - No `noindex` in production builds for indexable routes.
  - Links are `<a href>` for navigational elements.
  - JSON-LD parses and contains required properties.
- Pre-launch crawl of staging (with auth) and post-launch crawl of production.
- Rich Results Test and URL Inspection for representative URLs.
- RUM/CrUX monitoring for CWV.

## Tooling
- Google Search Console (URL Inspection, Pages, Sitemaps, CWV), Rich Results Test, Schema Markup Validator.
- Crawlers: Screaming Frog, Sitebulb, open-source alternatives; Lighthouse SEO audits (basic).
- `schema-dts` (TypeScript types for schema.org JSON-LD).
- Bing Webmaster Tools; IndexNow for faster Bing/Yandex discovery (not used by Google).

## Framework Notes
- **Next.js App Router (primary):**
  - Metadata API: `metadata`/`generateMetadata` with `metadataBase`, `alternates.canonical`, `alternates.languages`, `robots`.
  - File conventions: `sitemap.ts`, `robots.ts`, `opengraph-image.tsx`, `icon.png`, `manifest.ts`.
  - `notFound()` returns 404; `permanentRedirect()` returns 308; `redirects` in `next.config.ts` for static maps.
  - Streaming: metadata may stream after initial HTML for dynamic pages in newer Next.js versions; for bots, Next.js detects crawlers and blocks rendering until metadata resolves (configurable via `htmlLimitedBots`). Verify rendered HTML via URL Inspection.
  - Keep public pages static or cached for fast TTFB.
- **React (Vite SPA):** SEO-critical routes need prerendering (build-time static HTML per route) or migration to Next.js. Per-route titles/meta with React 19's built-in `<title>`/`<meta>` hoisting in components. Handle 404s by serving a real 404 from the host for unknown paths where possible.

## AI Agent Guidance
- For every new public route, decide and implement: indexable?, canonical, title/description, sitemap inclusion, structured data type (if supported), status code behavior.
- Don't add FAQ or HowTo structured data expecting rich results; don't invent ratings for Review markup.
- Don't use client-side data fetching for indexable content or `onClick` navigation.
- Verify before done:
  - [ ] View source (not DevTools DOM) shows content, links, title, canonical
  - [ ] Correct status codes for found/missing/moved
  - [ ] Non-production is noindex; production isn't
  - [ ] sitemap.xml lists only canonical indexable URLs
  - [ ] JSON-LD validates and matches visible content
  - [ ] CWV budgets met on the template

## Examples

```ts
// e2e/seo.spec.ts — Playwright SEO smoke checks
import { test, expect } from "@playwright/test";

const routes = [
  { path: "/", status: 200, indexable: true },
  { path: "/blog/hello-world", status: 200, indexable: true },
  { path: "/search?q=test", status: 200, indexable: false },
  { path: "/does-not-exist", status: 404, indexable: false },
];

for (const r of routes) {
  test(`SEO ${r.path}`, async ({ request, page }) => {
    const res = await request.get(r.path, { maxRedirects: 0 });
    expect(res.status()).toBe(r.status);
    if (r.status !== 200) return;
    const html = await res.text(); // raw server HTML, not hydrated DOM
    expect(html).toMatch(/<title>[^<]{10,}<\/title>/);
    const hasNoindex = /<meta[^>]+name="robots"[^>]+noindex/i.test(html);
    expect(hasNoindex).toBe(!r.indexable);
    if (r.indexable) expect(html).toMatch(/<link[^>]+rel="canonical"/);
    await page.goto(r.path);
    const fakeLinks = await page.locator("nav [role=link]:not(a), nav div[onclick]").count();
    expect(fakeLinks).toBe(0);
  });
}
```

## Related Skills
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — Next.js metadata API depth
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — locale routing and hreflang
- [core-web-vitals](../core-web-vitals/Skill.md) — page experience metrics
- [content-and-blog-sites](../content-and-blog-sites/Skill.md) — article SEO
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md) — product structured data, facets
- [documentation-site-patterns](../documentation-site-patterns/Skill.md) — docs versions, llms.txt
- [marketing-website-architecture](../marketing-website-architecture/Skill.md) — redirects and migrations
- [semantic-html](../semantic-html/Skill.md) — shared foundations
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — links and route changes

## Sources
- [Google Search Central — JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics) — Official — rendering pipeline, `<a href>` links, soft 404 strategies, canonical and noindex with JS
- [Google Search Central — What's new / documentation updates](https://developers.google.com/search/updates) — Official — FAQ rich results no longer appearing as of May 7, 2026
- [Google Search Central Blog — Simplifying the search results page (June 2025)](https://developers.google.com/search/blog/2025/06/simplifying-search-results) — Official — retired structured data features
- [Google Search Central — Product structured data](https://developers.google.com/search/docs/appearance/structured-data/product) — Official — product snippets vs merchant listings
- [web.dev — Core Web Vitals](https://web.dev/articles/vitals) — Official — thresholds
- [Next.js docs — Metadata files, revalidateTag, proxy](https://nextjs.org/docs/app/api-reference/file-conventions/metadata) — Official — sitemap.ts, robots.ts, metadata API
- [Search Engine Journal — Google is not diminishing structured data in 2026](https://www.searchenginejournal.com/google-is-not-diminishing-the-use-of-structured-data-in-2026/560516/) — Community — context on continued structured data use

## License / Usage Notes
Summaries of Google and Next.js documentation; code original. Rich result eligibility changes frequently—re-verify against Google's structured data gallery before promising features.

## Quality Tier
S — Directly grounded in current Google Search Central and Next.js official docs (including 2025–2026 rich result changes), with testable implementation and CI checks.

## Status
Active

## Last Verified
2026-09-15
