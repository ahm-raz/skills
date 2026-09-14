# Marketing Website Architecture

## Summary
How to architect a company's public marketing site: page types and information architecture, CMS content modeling, rendering and caching strategy, routing and localization, redirects, analytics and consent, and how the site relates to the product app and docs. The goal is a site marketing can edit safely without engineers, that stays fast and indexable, and that doesn't turn into a one-off page graveyard.

## Category
Product Patterns

## Subcategories
Information architecture, headless CMS, content modeling, page builders, static generation, redirects, localization, consent management, site/app boundary

## Problem It Solves
Marketing sites decay in predictable ways. Every campaign adds a bespoke page. The CMS allows arbitrary layouts that break the design system. Redirects are lost during replatforms, which drops SEO. Third-party tags pile up until Core Web Vitals fail. The marketing site and app share a domain with no clear routing boundary. This skill defines a durable architecture.

## When To Use
- Starting or replatforming a company/product marketing site.
- Choosing a CMS and content model, or introducing a block-based page builder.
- Splitting marketing site, app, docs, and blog across domains/subpaths.
- Adding localization, a customer stories section, or a changelog.

## When Not To Use
- Designing a single campaign page: [landing-page-design](../landing-page-design/Skill.md).
- Documentation portals: [documentation-site-patterns](../documentation-site-patterns/Skill.md).
- Editorial-heavy publishing (newsroom, magazine): [content-and-blog-sites](../content-and-blog-sites/Skill.md).
- Authenticated product UI: [saas-application-patterns](../saas-application-patterns/Skill.md).

## Core Principles
1. **Model content, not pages.** Content types (Customer Story, Feature, Integration, Author, CTA) are reused across many pages. Page layouts come from a constrained set of blocks.
2. **Constrained flexibility.** Editors compose from design-system blocks with limited variants. They don't control arbitrary color, spacing, or HTML.
3. **Static by default.** Marketing content changes on editorial timescales. Prerender and revalidate on publish.
4. **URLs are a contract.** Every URL change needs a 301 redirect. Treat the redirect map as versioned code.
5. **Clear boundaries.** Marketing, app, docs, and blog are separate deployables with explicit routing (subdomain or subpath proxy), shared design tokens, and shared analytics identity.
6. **Performance and privacy budgets are governance.** New tags and heavy blocks need an owner and must fit the budget.

## Best Practices
- **IA:** top nav by buyer intent: Product (features/platform), Solutions (by role/industry/use case), Customers, Pricing, Resources (blog, docs, guides), Company. Put Pricing and a primary CTA ("Get started") in the header. Put Sign in in the header, visually secondary.
- **Footer as sitemap:** all major sections, legal, status page, security/trust center, cookie settings.
- **Page types (templates):** Home, Product/Feature, Solution (role/industry), Integration directory + detail, Customer story index + detail, Pricing, Comparison ("X vs Y"), Changelog, Careers, Legal, Contact/Demo, 404.
- **Programmatic pages** (integrations, templates, locations) must each have unique useful content. Otherwise they become thin or duplicate pages that hurt SEO.
- **Preview:** editors must see drafts in the real frontend (draft mode) before publishing.
- **Publishing webhooks** trigger targeted revalidation (tag/path), not full rebuilds, once the site has thousands of pages.
- **Localization:** locale subpaths (`/de/`), `hreflang` alternates, translated slugs optional, and never auto-redirect by IP without offering a switch.
- **Trust center / security page:** certifications, subprocessors, status link, vulnerability disclosure. B2B buyers look for it.

## Implementation Guidance

### Content model (block-based)
```ts
// Conceptual schema (works for Sanity, Contentful, Payload, Storyblok)
type Page = {
  slug: string; seo: Seo; locale: string;
  blocks: Array<HeroBlock | LogoStripBlock | FeatureGridBlock | TestimonialBlock | CtaBlock | FaqBlock | RichTextBlock>;
};
type Seo = { title: string; description: string; ogImage?: Asset; noindex?: boolean; canonical?: string };
type HeroBlock = { _type: "hero"; eyebrow?: string; heading: string; body?: string; primaryCta: CtaRef; secondaryCta?: CtaRef; media: Asset; variant: "split" | "centered" };
type CtaRef = { label: string; href: string; trackingId: string };
type TestimonialBlock = { _type: "testimonial"; story: Reference<CustomerStory> }; // reference, not copied text
```
Keep variants enumerated (`"split" | "centered"`), not free-form style props.

### Block renderer
```tsx
const registry = { hero: Hero, logoStrip: LogoStrip, featureGrid: FeatureGrid, testimonial: Testimonial, cta: CtaBand, faq: Faq, richText: RichText } as const;

export function Blocks({ blocks }: { blocks: Page["blocks"] }) {
  return blocks.map((b, i) => {
    const C = registry[b._type as keyof typeof registry];
    if (!C) { if (process.env.NODE_ENV !== "production") console.warn("Unknown block", b._type); return null; }
    return <C key={(b as any)._key ?? i} {...(b as any)} headingLevel={i === 0 ? 1 : 2} />;
  });
}
```
Pass heading level from position so the first block owns the H1 and the heading hierarchy stays valid.

### Rendering and caching
| Content | Strategy |
|---------|----------|
| Home, product, solutions, legal | SSG + on-demand revalidate by CMS tag |
| Blog/changelog index | SSG + revalidate on publish |
| Integration/template directory (1k+ pages) | Generate top N at build, remainder on first request (ISR), cache at CDN |
| Geo-aware pricing/currency | Static page + edge-selected variant or small client island; keep HTML price indexable for default market |
| Demo form, contact | Static page + server endpoint |

### Domain/routing boundary
| Option | Pros | Cons |
|--------|------|------|
| `example.com` (marketing) + `app.example.com` | Independent deploys, cookie isolation | Separate SEO host; cross-subdomain analytics setup |
| `example.com/app` via reverse proxy | One host | Complex proxy rules, CSP/cookie coupling |
| `docs.example.com` or `example.com/docs` | Subpath consolidates SEO signals | Requires rewrites at edge |

Common default: marketing + blog + docs on the apex (subpaths via edge rewrites), app on `app.` subdomain.

### Redirects as code
```ts
// redirects.ts — reviewed in PRs, tested in CI
export const redirects = [
  { source: "/features/reporting", destination: "/product/analytics", permanent: true },
  { source: "/customers/:slug", destination: "/stories/:slug", permanent: true },
];
```
Before any replatform: crawl the old site, export all URLs with traffic/backlinks, and map every one to a new URL or intentional 410.

## Recommended Workflow
1. Inventory: crawl the existing site, analytics top pages, backlinked URLs.
2. Define IA and page templates with marketing; write the URL scheme.
3. Model content types and a block library mapped 1:1 to design-system components.
4. Build templates + block renderer with preview/draft mode.
5. Add SEO layer: metadata, sitemap, robots, canonical, hreflang, structured data (Organization, BreadcrumbList, Article).
6. Add consent manager + analytics + tag governance.
7. Redirect map, 404 page, and staging crawl comparing old vs new.
8. Launch with monitoring: Search Console coverage, RUM Core Web Vitals, 404 logs.

## Patterns
- **Global settings singleton:** nav, footer, announcement bar, default SEO, and social links live in one document.
- **Reusable CTA document:** referenced by many pages. Changing "Start free trial" to "Get started" is one edit.
- **Announcement bar:** dismissible, stored in a cookie/localStorage, reserved height to avoid CLS.
- **Comparison page template:** fair, dated, sourced feature comparison with a "last updated" date.
- **Changelog:** dated entries with tags, RSS/Atom feed, and a deep link per entry.
- **Customer story:** challenge → solution → results with metrics, pulled into testimonials by reference.

## Anti-Patterns
- **Page-builder free-for-all (arbitrary HTML/CSS fields).** Breaks accessibility and brand. Fix: enumerated block variants.
- **Full-site rebuild on every typo.** Slow, costly. Fix: tag-based on-demand revalidation.
- **Replatform without redirects.** Traffic cliff. Fix: URL inventory + 301 map + post-launch 404 monitoring.
- **Tag manager as unreviewed deploy channel.** Performance and security risk. Fix: tag inventory with owners, CSP, and quarterly audits.
- **Marketing and app in one bundle.** Marketing pages ship app JS. Fix: separate apps or strict route-level splitting.
- **IP-based forced locale redirect.** Blocks users and crawlers. Fix: suggest a locale with a banner; use hreflang.
- **Duplicate "solutions" pages that only swap the industry noun.** Fix: unique content per page, or consolidate.

## Accessibility
- Skip link to `main`; consistent landmarks across templates (WCAG 2.4.1).
- Mega menus: disclosure-button pattern (not `role="menu"` for site nav), Escape closes, focus returns. See [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md).
- CMS blocks must enforce alt text on images (required field with an explicit "decorative" toggle).
- Rich text: map headings to the correct levels; forbid skipped levels in the editor.
- Consent banner: keyboard reachable, no focus trap unless modal, doesn't obscure focus.
- In the EU, the European Accessibility Act (applies from 28 June 2025) covers ecommerce and consumer banking services, so marketing sites that sell must meet it.

## Responsive Design
- Nav collapses to a disclosure/drawer below the width where items wrap. Test with translated (longer) labels.
- Blocks declare their own responsive behavior (container queries suit blocks reused in different columns).
- Art-direct hero media per breakpoint via `<picture>`.

## Performance
- Budget per template: LCP ≤ 2.5s, CLS ≤ 0.1, INP ≤ 200ms at p75 in field data.
- Hydrate only interactive islands (nav toggle, forms, pricing toggle). Keep the rest server-rendered.
- Image CDN with automatic format/resize from CMS assets.
- Fonts: 1–2 families, subsetted, self-hosted.
- Tags: server-side tagging or delayed loading; measure each tag's cost with RUM.

## Security
- CMS preview/draft endpoints protected by a secret token and not cached publicly.
- Sanitize or restrict rich-text HTML embeds. Allowlist embed providers (YouTube, Vimeo, Loom) instead of raw iframes.
- CSP with nonce/hash for inline scripts; SRI where possible for third-party scripts.
- Forms: server validation, rate limiting, bot protection; don't expose CRM tokens.
- `security.txt` at `/.well-known/security.txt`.

## Testing
- Contract tests: every block type renders with minimal and maximal content.
- Link checker and redirect tests in CI (each source returns 301 to expected destination).
- Visual regression on templates at three widths.
- Crawl staging (Screaming Frog or open-source crawler) for broken links, missing titles, duplicate descriptions, noindex leaks.
- Lighthouse CI per template; axe checks per template.

## Tooling
- Framework: Next.js App Router (static by default, on-demand revalidation, `draftMode`, metadata files). Content-first frameworks such as Astro are out of scope for this library.
- MDX for developer-owned pages: `@next/mdx` or `next-mdx-remote-client`, or Velite/Content Collections for typed local content.
- Headless CMS: Sanity, Contentful, Storyblok (visual editing), Payload (self-hosted, TS), Strapi. Choose based on editorial workflow, localization, and visual editing needs.
- Consent: a Consent Management Platform supporting Google Consent Mode v2 where Google ads/analytics are used in the EEA/UK.
- Crawling: Screaming Frog, Sitebulb, or open-source `linkinator`.

## Framework Notes
- **Next.js App Router (primary):**
  - Route groups: `app/(marketing)/layout.tsx` (site header/footer, consent, analytics), `app/(marketing)/[[...slug]]/page.tsx` (CMS block pages), `app/(marketing)/blog/...`. Keep app routes elsewhere or in a separate deployment.
  - `generateStaticParams` returns all CMS slugs. CMS reads are cached and tagged (`"use cache"` + `cacheTag("page:" + slug)` with Cache Components, or `fetch(..., { next: { tags } })`).
  - Webhook Route Handler calls `revalidateTag(tag, "max")`; the single-argument form is deprecated in Next.js 16.
  - Preview: a `/api/draft` Route Handler validates a secret and calls `(await draftMode()).enable()`. Pages read `draftMode().isEnabled` to fetch drafts (these renders are dynamic and uncached).
  - SEO files: `app/sitemap.ts` (from CMS, `generateSitemaps` beyond 50k URLs), `app/robots.ts`, `generateMetadata` per page with `alternates.canonical` and `alternates.languages` for hreflang, and `opengraph-image.tsx` for generated OG images.
  - Redirects: `redirects()` in `next.config.ts` for hundreds of entries. For thousands, look up a key-value store in `proxy.ts` (the Next.js 16 rename of `middleware.ts`) with a tight `matcher`.
  - Locales: `app/[locale]/...` with `generateStaticParams` per locale (see [nextjs-internationalization](../nextjs-internationalization/Skill.md)).
  - Only nav toggles, forms, pricing toggles, and consent are `"use client"`. Blocks stay Server Components.
- **React (Vite SPA):** not recommended for public marketing sites (indexing, LCP, previews). If the marketing site must live inside an SPA, prerender routes at build time and ship real `<a href>` links plus per-route `<title>`/meta.

## AI Agent Guidance
- Start by listing page templates, content types, and the URL scheme. Get agreement before building blocks.
- Map every CMS block to an existing design-system component. Don't invent one-off styling per page.
- Never hardcode marketing copy that should be CMS-managed, unless the project has no CMS by design.
- When changing any route, add a redirect and a test.
- Verify before done:
  - [ ] Draft preview works and is not publicly cacheable
  - [ ] sitemap.xml, robots.txt, canonical, and hreflang (if localized) correct
  - [ ] Redirect tests pass; 404 page returns 404 status
  - [ ] Each template passes axe and a Lighthouse budget
  - [ ] Marketing pages don't load app bundles

## Examples

```ts
// app/api/revalidate/route.ts — Next.js CMS webhook → tag revalidation
import { revalidateTag } from "next/cache";
import { timingSafeEqual } from "node:crypto";

export async function POST(req: Request) {
  const secret = req.headers.get("x-webhook-secret") ?? "";
  const expected = process.env.CMS_WEBHOOK_SECRET ?? "";
  if (!expected || secret.length !== expected.length || !timingSafeEqual(Buffer.from(secret), Buffer.from(expected))) {
    return new Response("Unauthorized", { status: 401 });
  }
  const { type, slug } = await req.json();
  revalidateTag(`${type}:${slug}`, "max"); // stale-while-revalidate; use { expire: 0 } for legal/pricing corrections
  if (type === "globalSettings") revalidateTag("global", "max");
  return Response.json({ revalidated: true });
}
```

## Related Skills
- [landing-page-design](../landing-page-design/Skill.md) — individual campaign page anatomy
- [information-architecture](../information-architecture/Skill.md) — IA methods
- [seo-for-frontend](../seo-for-frontend/Skill.md) — metadata, sitemaps, structured data
- [content-and-blog-sites](../content-and-blog-sites/Skill.md) — blog and editorial sections
- [design-system-architecture](../design-system-architecture/Skill.md) — block library as design system consumer
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — ISR/tag revalidation
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — metadata API, sitemap.ts, robots.ts
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — locale routing in App Router
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md) — localization
- [third-party-script-management](../third-party-script-management/Skill.md) — tag governance
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md) — site navigation

## Sources
- [Google Search Central — JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics) — Official — links, status codes, canonical rules
- [Google Search Central — Site moves with URL changes](https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes) — Official — redirect mapping during replatforms
- [Google Search Central — Localized versions (hreflang)](https://developers.google.com/search/docs/specialty/international/localized-versions) — Official — locale alternates
- [NN/g B2B Website Usability](https://www.nngroup.com/reports/b2b-websites-usability/) — Official research — navigation, pricing visibility, trust content
- [European Commission — European Accessibility Act](https://commission.europa.eu/strategy-and-policy/policies/justice-and-fundamental-rights/disability/union-equality-strategy-rights-persons-disabilities-2021-2030/european-accessibility-act_en) — Official — ecommerce and banking in scope
- [web.dev — Core Web Vitals](https://web.dev/articles/vitals) — Official — field thresholds

## License / Usage Notes
Summarized guidance; no proprietary content copied. Code is original. CMS/framework names are trademarks of their owners.

## Quality Tier
A — Strong official grounding for SEO/performance/accessibility; CMS modeling guidance reflects widely used industry practice rather than a single standard.

## Status
Active

## Last Verified
2026-09-15
