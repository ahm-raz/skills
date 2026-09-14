# Next.js Metadata and SEO

## Summary
Next.js generates `<head>` tags from a static `metadata` export, an async `generateMetadata` function, `generateViewport`, and file conventions (`favicon.ico`, `icon`, `apple-icon`, `opengraph-image`, `twitter-image`, `sitemap`, `robots`, `manifest`). Dynamic OG images use `ImageResponse` from `next/og`. In v16, metadata streams for browsers on dynamic pages but blocks for HTML-limited bots, image/sitemap generator params are Promises, and metadata under Cache Components follows the same cache/Suspense rules as components.

## Category
Next.js

## Subcategories
Metadata API, generateMetadata, title templates, metadataBase, Open Graph, sitemap.ts, robots.ts, ImageResponse, JSON-LD, canonical, hreflang, streaming metadata

## Problem It Solves
Missing or duplicated titles, relative OG URLs that break sharing, `next/head` in App Router, sitemaps that don't scale, metadata that fetches data twice, OG images that fail on crawlers, and `notFound()` pages returning 200 to search engines because of streaming.

## When To Use
- Every route that should be indexed or shared.
- Building sitemaps, robots rules, canonical/alternate URLs, and localized hreflang.
- Generating per-page OG/Twitter images.
- Adding structured data (JSON-LD).

## When Not To Use
- Broad SEO strategy, content, and Core Web Vitals program (see [seo-for-frontend](../seo-for-frontend/Skill.md)).
- Pages Router `next/head` maintenance (legacy).

## Core Principles
1. **Metadata only in Server Components** (`layout`/`page` exports).
2. **Set `metadataBase` once** in the root layout; use relative URLs everywhere else (relative URLs without it fail the build).
3. **Title templates apply to children**, need `default`, and don't affect the same segment.
4. **Nested metadata merges shallowly** — a child `openGraph` object replaces the parent's entirely.
5. **Deduplicate data** between `generateMetadata` and the page with `React.cache` (or `'use cache'`).
6. **Decide 404s before streaming** so crawlers get real status codes.

## Best Practices
- Root layout: `metadataBase`, `title.template`/`default`, `description`, `openGraph` defaults, `robots`, `icons` via files.
- Use `alternates.canonical` on every indexable page; `alternates.languages` for locales.
- Keep `themeColor`, `colorScheme`, `viewport` in `export const viewport` / `generateViewport` (deprecated inside `metadata` since v14).
- Place `opengraph-image.tsx` next to the page it describes; the closest file wins.
- OG images: 1200×630, `contentType = 'image/png'`, flexbox-only CSS, load fonts explicitly, keep it fast.
- For large sites split sitemaps with `generateSitemaps` (≤50,000 URLs each); `id` is a `Promise<string>` in v16.
- Render JSON-LD with `<script type="application/ld+json">` and escape `<` to `<`.
- Under Cache Components: cache external metadata data with `'use cache'`; return strings (not `URL` objects) from cached `generateMetadata`.
- Keep `htmlLimitedBots` default unless you have a bot not detected; don't disable streaming metadata without a reason.

## Implementation Guidance

### File conventions
| File | Output | Notes |
|---|---|---|
| `app/favicon.ico` | favicon | Root only |
| `icon.(png|svg|tsx)`, `apple-icon.(png|tsx)` | icons | Can be generated |
| `opengraph-image.(jpg|png|tsx)` + `.alt.txt` | og:image | Per segment |
| `twitter-image.(…)` | twitter:image | Per segment |
| `sitemap.(xml|ts)` | `/sitemap.xml` | Cached unless request-time APIs used |
| `robots.(txt|ts)` | `/robots.txt` | |
| `manifest.(json|ts)` | web manifest | |

### Root layout metadata
```tsx
// app/layout.tsx
import type { Metadata, Viewport } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://acme.com'),
  title: { template: '%s | Acme', default: 'Acme — Project management' },
  description: 'Plan, track, and ship work.',
  openGraph: { siteName: 'Acme', type: 'website', locale: 'en_US' },
  twitter: { card: 'summary_large_image' },
  robots: { index: true, follow: true },
}

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#0a0a0a' },
  ],
}
```

### Dynamic page metadata with shared data
```tsx
// lib/posts.ts
import { cache } from 'react'
export const getPost = cache(async (slug: string) => db.post.findUnique({ where: { slug } }))

// app/blog/[slug]/page.tsx
import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getPost } from '@/lib/posts'

export async function generateMetadata(props: PageProps<'/blog/[slug]'>): Promise<Metadata> {
  const { slug } = await props.params
  const post = await getPost(slug)
  if (!post) return { title: 'Not found', robots: { index: false } }
  return {
    title: post.title,
    description: post.excerpt,
    alternates: { canonical: `/blog/${slug}` },
    openGraph: { title: post.title, description: post.excerpt, type: 'article', publishedTime: post.publishedAt.toISOString() },
  }
}

export default async function Page(props: PageProps<'/blog/[slug]'>) {
  const { slug } = await props.params
  const post = await getPost(slug)
  if (!post) notFound()
  const jsonLd = { '@context': 'https://schema.org', '@type': 'BlogPosting', headline: post.title, datePublished: post.publishedAt }
  return (
    <article>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c') }} />
      <h1>{post.title}</h1>
    </article>
  )
}
```

### Generated OG image (v16 async params)
```tsx
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'
import { getPost } from '@/lib/posts'

export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'
export const alt = 'Blog post cover'

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)
  return new ImageResponse(
    <div style={{ display: 'flex', width: '100%', height: '100%', alignItems: 'center', justifyContent: 'center', fontSize: 64, background: '#0a0a0a', color: '#fff' }}>
      {post?.title ?? 'Acme'}
    </div>,
    size,
  )
}
```

### Sitemap and robots
```ts
// app/sitemap.ts
import type { MetadataRoute } from 'next'
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = 'https://acme.com'
  const posts = await getPublishedPostSlugs()
  return [
    { url: base, lastModified: new Date(), changeFrequency: 'weekly', priority: 1 },
    ...posts.map((p) => ({ url: `${base}/blog/${p.slug}`, lastModified: p.updatedAt })),
  ]
}

// app/robots.ts
import type { MetadataRoute } from 'next'
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: '*', allow: '/', disallow: ['/dashboard', '/api/'] }],
    sitemap: 'https://acme.com/sitemap.xml',
  }
}
```

### Streaming metadata behavior
| Visitor | Dynamic page metadata |
|---|---|
| Browsers / DOM-capable crawlers | Streamed, injected when `generateMetadata` resolves |
| HTML-limited bots (Twitterbot, Slackbot, Bingbot…) | Blocking; placed in `<head>` (with Cache Components, bots skip the shell) |
| Prerendered pages | Resolved at build time |

## Recommended Workflow
1. Configure root metadata + viewport + favicon/icon files.
2. Add per-route `metadata` or `generateMetadata` with canonical URLs.
3. Add `opengraph-image` files for key templates.
4. Implement `sitemap.ts` and `robots.ts`; add `generateSitemaps` at scale.
5. Add JSON-LD for articles/products/breadcrumbs.
6. Validate with a bot user agent fetch, Rich Results Test, and social card validators.

## Patterns
- **Section title template:** `app/(docs)/layout.tsx` `title: { template: '%s — Docs', default: 'Docs' }`.
- **Absolute override:** `title: { absolute: 'Pricing' }` for landing pages.
- **Noindex non-production:** `robots: { index: process.env.VERCEL_ENV === 'production' }` (or `NEXT_PUBLIC_*` flag) in root metadata.
- **Localized alternates:** `alternates.languages: { en: '/en/x', de: '/de/x' }` + sitemap `alternates.languages`.
- **Dynamic marker for runtime metadata** under Cache Components: `<Suspense><Connection/></Suspense>` in the page when `generateMetadata` needs runtime data.

## Anti-Patterns
- **`next/head` in App Router** — ignored. Fix: Metadata API.
- **Child `openGraph: { title }` expecting parent images to persist** — shallow merge drops them. Fix: spread shared OG fields from a module.
- **Relative OG URLs without `metadataBase`** — build error. Fix: set in root layout.
- **`title.template` in a page** — no effect. Fix: put in layout.
- **Fetching the post in both `generateMetadata` and page without memoization** — duplicate queries. Fix: `React.cache` (fetch is auto-memoized).
- **Unescaped JSON-LD from CMS** — XSS via `</script>`. Fix: escape `<`.
- **`display: grid` in `ImageResponse`** — unsupported. Fix: flexbox.
- **Sync `params` in `opengraph-image`/`sitemap` id** — v16 breaking. Fix: await Promises.

## Accessibility
- Unique descriptive `<title>` per page (WCAG 2.4.2 Page Titled); titles are announced on client navigation.
- Set `<html lang>` correctly (WCAG 3.1.1) and `alternates.languages` for localized pages.
- Provide `opengraph-image.alt.txt` or `alt` export for generated images.
- Don't disable zoom via viewport (`maximumScale: 1`, `userScalable: false`) — WCAG 1.4.4.

## Responsive Design
- Default viewport meta (`width=device-width, initial-scale=1`) is injected automatically; only override for `themeColor`/`colorScheme` or `interactiveWidget`.

## Performance
- Streaming metadata prevents slow `generateMetadata` from blocking visual content for browsers.
- OG image routes are cached by default unless using request-time APIs; heavy fonts/images in them add latency for crawlers.
- Keep sitemap generation cached (CMS tag + revalidation) for large catalogs.

## Security
- Sanitize CMS-provided metadata strings and JSON-LD.
- Don't include private/draft URLs in sitemaps; disallow authenticated areas in robots (not a security control — also require auth).
- Keep preview/staging deployments noindexed.

## Testing
- Unit test `generateMetadata` return shape (sync-safe logic).
- E2E: fetch HTML with `User-Agent: Twitterbot/1.0` and assert `<title>`, `og:image` absolute URLs, canonical.
- Assert invalid slugs return HTTP 404 (not 200 + noindex).
- Lighthouse SEO audit in CI.

## Tooling
- `next/og` `ImageResponse` (satori + resvg), Vercel OG Playground.
- `schema-dts` for typed JSON-LD.
- Google Rich Results Test, Search Console, social debuggers.

## Framework Notes
- v16: image metadata `params` and `generateImageMetadata` `id` are Promises; sitemap `id` is a Promise.
- v15.2+: streaming metadata with `htmlLimitedBots`.
- React (Vite SPA): no server metadata; React 19 hoists `<title>`/`<meta>` rendered in components to `<head>` at runtime, but crawlers that don't execute JS won't see them — prerender or use Next.js for SEO-critical pages.

## AI Agent Guidance
- Never emit `next/head` in `app/`; always set `metadataBase` in the root layout.
- Memoize shared data between metadata and page.
- Before done: fetch the page as a bot UA and verify head tags; confirm 404 status for missing content; check OG image renders at `/…/opengraph-image`.

## Examples
```ts
// lib/seo.ts — shared OG defaults to avoid shallow-merge loss
export const baseOpenGraph = { siteName: 'Acme', type: 'website' as const, locale: 'en_US' }

// app/pricing/page.tsx
import type { Metadata } from 'next'
import { baseOpenGraph } from '@/lib/seo'
export const metadata: Metadata = {
  title: 'Pricing',
  alternates: { canonical: '/pricing' },
  openGraph: { ...baseOpenGraph, title: 'Acme Pricing', url: '/pricing' },
}
```

## Related Skills
- [seo-for-frontend](../seo-for-frontend/Skill.md) — broader SEO practice
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — hreflang and localized metadata
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — status codes and bots
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — caching metadata data
- [content-and-blog-sites](../content-and-blog-sites/Skill.md) — content site patterns
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — title announcements

## Sources
- [Metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images) — Official — APIs, streaming metadata, memoization, ImageResponse
- [generateMetadata reference](https://nextjs.org/docs/app/api-reference/functions/generate-metadata) — Official — title template rules, metadataBase, deprecations, cache serialization note
- [sitemap.xml reference](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap) — Official — types, generateSitemaps, v16 id Promise
- [Upgrading to v16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — async image params
- [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) — Official — generateMetadata under Cache Components
- [Streaming guide](https://nextjs.org/docs/app/guides/streaming) — Official — status codes, bots

## License / Usage Notes
Next.js MIT; satori MPL-2.0 (bundled via next/og). Content summarized; examples original. JSON-LD escaping pattern is a widely documented community practice.

## Quality Tier
A — Official-grounded and version-precise; JSON-LD/social validation guidance from general practice.

## Status
Active

## Last Verified
2026-09-15
