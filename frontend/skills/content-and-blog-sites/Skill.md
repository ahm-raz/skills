# Content and Blog Sites

## Summary
How to build content-driven sites on Next.js: company blogs, publications, newsletters, knowledge bases, changelogs, and personal sites. It covers the content pipeline (MDX in repo vs headless CMS), article page anatomy and reading typography, index/archive/taxonomy pages, authors and credibility, RSS/Atom feeds, OG images, newsletter capture, comments, and editorial workflow (drafts, previews, scheduling). The engineering goals are fast static delivery, strong SEO, and long-term maintainability.

## Category
Product Patterns

## Subcategories
MDX, headless CMS, article layout, reading typography, tags and categories, author pages, RSS, OG images, newsletters, scheduled publishing, draft preview

## Problem It Solves
Blogs start simple and decay:
- Tag pages multiply into thin, duplicate content.
- Images are unoptimized.
- Code samples and embeds break.
- There are no feeds, and OG previews are generic.
- Authors lack credibility pages.
- Editors can't preview drafts.
- Every post ships a heavy client bundle.

This skill gives a durable structure for content that ranks, reads well, and remains easy to publish.

## When To Use
- Building or migrating a blog, publication, changelog, or knowledge base on Next.js.
- Adding RSS, OG images, newsletter signup, author pages, or content previews.

## When Not To Use
- Product documentation with Diátaxis structure, versioning, and API reference: [documentation-site-patterns](../documentation-site-patterns/Skill.md).
- Marketing site IA and page builders: [marketing-website-architecture](../marketing-website-architecture/Skill.md).
- Technical SEO details (sitemaps, canonicals, structured data): [seo-for-frontend](../seo-for-frontend/Skill.md) (used together).

## Core Principles
1. **Content first, chrome second.** The article body is the LCP and the reason for the visit, so minimize interruptions (popups, sticky banners).
2. **Static by default.** Posts are prerendered and revalidated on publish. Only interactive islands hydrate.
3. **Every URL earns its place.** Tag, category, and author pages must have enough unique value, or they're `noindex`/consolidated.
4. **Readable typography.** Line length ~60–75ch, body ≥ 16–18px, generous line height, strong heading hierarchy.
5. **Credibility is visible.** Real author names, bios, dates (published and updated), and sources support trust (Google's helpful content guidance emphasizes people-first content and clear authorship).
6. **Own your distribution.** RSS/Atom feeds, email newsletter, and good share previews.
7. **Editors need previews and safety.** Drafts, scheduled publishing, and preview URLs that aren't indexed or publicly cached.

## Best Practices

### Article page anatomy
1. Breadcrumb/category link
2. H1 title; dek/subtitle
3. Byline: author(s) with link to author page, avatar, published date, updated date (if materially updated), reading time
4. Hero image (optional; meaningful, with alt text) or none. Don't use generic stock imagery as filler
5. Table of contents for long posts (≥ ~1,500 words), sticky on desktop
6. Body: headings every few paragraphs, short paragraphs, pull quotes, figures with captions, code blocks with copy
7. End matter: author bio card, related posts (3), newsletter signup, share links, comments (optional)
8. Footer: categories, RSS link, about, privacy

### Index and taxonomy pages
- Blog index: newest first with featured slot, paginated with real URLs (`/blog/page/2`), excerpt, date, author, category.
- Categories: a few curated, each with an intro paragraph. Index them.
- Tags: many and granular. `noindex` unless they have enough posts and a custom description.
- Author pages: bio, credentials, social links, list of posts. Index them.
- Archives by date: usually unnecessary; if present, `noindex`.

### Content pipeline choice
| Option | Best for | Trade-offs |
|--------|----------|-----------|
| MDX in repo (`@next/mdx`, Velite, Content Collections, next-mdx-remote-client) | Developer-authored blogs, changelogs | PR-based publishing; non-devs need Git or a Git-based CMS (Keystatic, TinaCMS) |
| Headless CMS (Sanity, Contentful, Payload, Storyblok, WordPress headless) | Editorial teams, scheduling, roles | Vendor/API dependency; rich text → React rendering layer needed |
| Notion/Google Docs as CMS | Tiny teams | Fragile APIs, image hosting issues; avoid for serious publications |

### Media
- Images through `next/image` (local imports get automatic width/height; remote need `remotePatterns`).
- Embeds (YouTube, X/Twitter, CodeSandbox) via facades: static thumbnail + click to load iframe.
- Captions for video; transcripts for podcasts.

### Newsletter and engagement
- Inline signup after the article and in the footer. At most one non-blocking prompt per session; no entry popups.
- Double opt-in where required (e.g., Germany), and an unchecked consent checkbox for marketing where needed.
- Comments: moderate by default; use a provider or GitHub Discussions (Giscus) for dev blogs; lazy-load.

## Implementation Guidance

### Route structure (Next.js App Router)
```
app/(site)/blog/page.tsx                    # index (page 1)
app/(site)/blog/page/[n]/page.tsx           # pagination
app/(site)/blog/[slug]/page.tsx             # article
app/(site)/blog/[slug]/opengraph-image.tsx  # generated OG image
app/(site)/blog/category/[category]/page.tsx
app/(site)/blog/tag/[tag]/page.tsx          # noindex unless curated
app/(site)/authors/[author]/page.tsx
app/(site)/blog/feed.xml/route.ts           # RSS
app/sitemap.ts
```

### Article page
```tsx
// app/(site)/blog/[slug]/page.tsx
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getAllPosts, getPost } from "@/lib/posts"; // cached + tagged reads

export async function generateStaticParams() {
  return (await getAllPosts()).map(p => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPost(slug);
  if (!post) return {};
  return {
    title: post.title,
    description: post.excerpt,
    alternates: { canonical: `/blog/${post.slug}` },
    authors: post.authors.map(a => ({ name: a.name, url: `/authors/${a.slug}` })),
    openGraph: { type: "article", publishedTime: post.publishedAt, modifiedTime: post.updatedAt, authors: post.authors.map(a => a.name) },
  };
}

export default async function Article({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await getPost(slug);
  if (!post || post.status !== "published") notFound();
  const jsonLd = {
    "@context": "https://schema.org", "@type": "BlogPosting",
    headline: post.title, description: post.excerpt,
    datePublished: post.publishedAt, dateModified: post.updatedAt ?? post.publishedAt,
    author: post.authors.map(a => ({ "@type": "Person", name: a.name, url: `https://example.com/authors/${a.slug}` })),
    image: [`https://example.com/blog/${post.slug}/opengraph-image`],
    mainEntityOfPage: `https://example.com/blog/${post.slug}`,
  };
  return (
    <article className="prose">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
      <header>
        <p><a href={`/blog/category/${post.category.slug}`}>{post.category.name}</a></p>
        <h1>{post.title}</h1>
        <p className="dek">{post.excerpt}</p>
        <Byline post={post} />
      </header>
      <post.Body components={mdxComponents} />
      <footer><AuthorCards authors={post.authors} /><RelatedPosts slug={post.slug} /><NewsletterForm /></footer>
    </article>
  );
}
```

### RSS feed
```ts
// app/(site)/blog/feed.xml/route.ts
import { getAllPosts } from "@/lib/posts";
export const dynamic = "force-static";

const esc = (s: string) => s.replace(/[<>&'"]/g, c => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", "'": "&apos;", '"': "&quot;" }[c]!));

export async function GET() {
  const posts = (await getAllPosts()).slice(0, 50);
  const items = posts.map(p => `<item><title>${esc(p.title)}</title><link>https://example.com/blog/${p.slug}</link><guid isPermaLink="true">https://example.com/blog/${p.slug}</guid><pubDate>${new Date(p.publishedAt).toUTCString()}</pubDate><description>${esc(p.excerpt)}</description></item>`).join("");
  const xml = `<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>Example Blog</title><link>https://example.com/blog</link><description>Articles from Example</description>${items}</channel></rss>`;
  return new Response(xml, { headers: { "Content-Type": "application/rss+xml; charset=utf-8" } });
}
```
Advertise it: `alternates: { types: { "application/rss+xml": "/blog/feed.xml" } }` in the blog layout metadata.

### Publishing and revalidation
- CMS publish webhook → Route Handler → `revalidateTag("post:"+slug, "max")` + `revalidateTag("posts", "max")`, or `{ expire: 0 }` for corrections that must not be served stale.
- Scheduled posts: CMS scheduler triggers publish webhook at the time. For MDX, filter by `publishedAt <= now` at build, plus a scheduled rebuild/cron.
- Draft preview: `draftMode()` enabled via secret-protected Route Handler; draft renders dynamic and uncached, and `robots: { index: false }`.

## Recommended Workflow
1. Choose pipeline (MDX vs CMS) based on who writes; define content schema (title, slug, excerpt, authors, category, tags, dates, hero, status, canonical override).
2. Build article template with typography scale and MDX/rich text component map.
3. Build index, pagination, category, author pages; decide tag indexing policy.
4. Add metadata, JSON-LD, OG images, RSS, sitemap.
5. Add newsletter form (Server Action → ESP API), related posts, optional comments.
6. Set up previews, publish webhooks, scheduled publishing.
7. Performance/a11y pass on article template; test long posts, many images, code-heavy posts.
8. Monitor: Search Console, RUM on article template, newsletter conversion.

## Patterns
- **Reading progress bar:** thin top bar via CSS scroll-driven animation (`animation-timeline: scroll()`), no JS. Decorative, so `aria-hidden`.
- **Heading anchors:** `rehype-slug` + `rehype-autolink-headings` with visible "#" on hover/focus and accessible labels.
- **Updated notice:** "Updated Sep 10, 2026: added section on X" at top of materially changed posts.
- **Series navigation:** "Part 2 of 4" with prev/next links.
- **Embed facade:** YouTube thumbnail button → iframe on click (`youtube-nocookie.com`).
- **Generated OG images:** `opengraph-image.tsx` using `ImageResponse` from `next/og` with title and author.

## Anti-Patterns
- **Entry popups and scroll-jacking newsletter modals.** Hurt reading, CLS/INP, and Google's intrusive interstitial guidance. Fix: inline signups.
- **Indexing hundreds of thin tag pages.** Fix: `noindex` tags or curate.
- **Client-rendering post bodies (fetch in `useEffect`).** Fix: Server Components/static generation.
- **Changing slugs without redirects.** Fix: slug history in CMS + redirects.
- **Fake "updated" dates to look fresh.** Misleading, and search engines may ignore them. Fix: update the date only on meaningful edits.
- **Unoptimized images pasted from CMS at 4000px.** Fix: image CDN/`next/image` with `sizes`.
- **Loading every embed script on page load.** Fix: facades and lazy loading.
- **AI-generated filler content at scale without editorial value.** Violates search spam policies on scaled content abuse. Fix: people-first, reviewed content.

## Accessibility
- Semantic structure: `<article>`, one H1, sequential headings, `<time datetime>` for dates, `<figure>/<figcaption>`.
- Alt text required in CMS schema, with a decorative option.
- Links descriptive (no "click here"); external link indication optional but consistent.
- Code blocks: focusable scroll containers; sufficient syntax contrast.
- Video: captions; audio: transcripts (WCAG 1.2.x).
- Reading typography: body ≥ 16px, line height ≥ 1.5, paragraph spacing, and support for text spacing overrides (1.4.12).
- TOC links move focus to headings; skip link to article.

## Responsive Design
- Single-column reading layout; TOC moves from sticky side rail (desktop) to collapsible "Contents" (mobile).
- Wide elements (tables, code, images) break out of the text column on desktop and scroll horizontally on mobile.
- Fluid type scale with `clamp()` for headings.

## Performance
- Articles fully static; target near-zero client JS apart from small islands (newsletter form, copy buttons).
- LCP: title text or hero image. If a hero image is used, give it `loading="eager"` + `fetchPriority="high"` (use `preload` only if it is discovered late; `priority` is deprecated since Next.js 16) and accurate `sizes`.
- Fonts via `next/font` with a limited set of weights.
- Syntax highlighting at build/server (Shiki), not a client highlighter.
- Comments and embeds lazy-loaded on visibility or interaction.

## Security
- MDX from untrusted authors can execute code at build/render. Only trusted authors publish MDX; CMS rich text rendered through a component map, not raw HTML.
- Sanitize any HTML fields (e.g., `sanitize-html`) and allowlist embed providers.
- JSON-LD: escape `<` when injecting into script tags (as in the example).
- Preview routes protected by secrets; not cached or indexed.
- Newsletter endpoint: validation, rate limiting, bot protection; ESP keys server-only.

## Testing
- Build-time validation of frontmatter/CMS schema (Zod) — missing excerpt/alt text fails build.
- Link checker on content; RSS feed validation (W3C Feed Validator); Rich Results Test on article template.
- Visual regression for article template with edge-case content (long titles, wide tables, many code blocks).
- axe scan on article, index, author pages.
- Lighthouse CI on a long, image-heavy post.

## Tooling
- MDX: `@next/mdx`, Velite, Content Collections, `next-mdx-remote-client`; remark/rehype plugins (`remark-gfm`, `rehype-slug`, `rehype-pretty-code` with Shiki).
- Git-based CMS: Keystatic, TinaCMS. Headless CMS: Sanity, Payload, Contentful, Storyblok, WordPress (headless via WPGraphQL).
- Newsletter/ESP: Buttondown, ConvertKit (Kit), Resend Audiences, Beehiiv, Mailchimp.
- Comments: Giscus (GitHub Discussions), provider-hosted options.
- OG images: `next/og` `ImageResponse`.

## Framework Notes
- **Next.js App Router (primary):** `generateStaticParams` for posts, `generateMetadata` for SEO, `opengraph-image.tsx` per post, Route Handlers for RSS, `sitemap.ts`, `draftMode()` for CMS previews, tagged caching with `revalidateTag(tag, "max")` on publish. MDX components mapped in `mdx-components.tsx` (required for `@next/mdx`). Use Server Components for article rendering and client components only for interactive pieces.
- **React (Vite SPA):** unsuitable for public blogs without prerendering. If constrained, prerender every post at build time and inject per-route meta tags; prefer moving the blog to Next.js.

## AI Agent Guidance
- Don't generate placeholder articles that could ship. Mark sample content clearly and keep it out of sitemaps/feeds.
- Enforce schema: title, excerpt, author, dates, alt text.
- Keep articles static; don't introduce client data fetching for content.
- Verify before done:
  - [ ] Article has H1, byline with author link, `<time>` dates, JSON-LD matching visible content
  - [ ] OG image and metadata render (check with a social preview debugger)
  - [ ] RSS feed validates and is linked
  - [ ] Tag page indexing policy applied; sitemap excludes noindex pages
  - [ ] Draft preview works and isn't indexable/cached
  - [ ] Article template passes axe and LCP budget

## Examples

```tsx
// app/(site)/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from "next/og";
import { getPost } from "@/lib/posts";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = "Article preview";

export default async function OG({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await getPost(slug);
  return new ImageResponse(
    (
      <div style={{ display: "flex", flexDirection: "column", justifyContent: "space-between", width: "100%", height: "100%", padding: 72, background: "#0f172a", color: "#f8fafc" }}>
        <div style={{ fontSize: 28, opacity: 0.8 }}>Example Blog</div>
        <div style={{ fontSize: 64, fontWeight: 700, lineHeight: 1.1 }}>{post?.title ?? "Example Blog"}</div>
        <div style={{ fontSize: 28 }}>{post?.authors.map(a => a.name).join(", ")}</div>
      </div>
    ),
    size,
  );
}
```

## Related Skills
- [seo-for-frontend](../seo-for-frontend/Skill.md) — technical SEO for content
- [documentation-site-patterns](../documentation-site-patterns/Skill.md) — shared MDX pipeline
- [marketing-website-architecture](../marketing-website-architecture/Skill.md) — CMS and site structure
- [typography-systems](../typography-systems/Skill.md) — reading typography
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — metadata API, OG images
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — publish revalidation
- [accessible-images-and-media](../accessible-images-and-media/Skill.md) — alt text, captions
- [pagination](../pagination/Skill.md) — index pagination
- [third-party-script-management](../third-party-script-management/Skill.md) — embeds and comments

## Sources
- [Google Search Central — Article structured data](https://developers.google.com/search/docs/appearance/structured-data/article) — Official — BlogPosting/Article properties
- [Google Search Central — Creating helpful, reliable, people-first content](https://developers.google.com/search/docs/fundamentals/creating-helpful-content) — Official — authorship, people-first content
- [Google Search Central — Spam policies (scaled content abuse)](https://developers.google.com/search/docs/essentials/spam-policies) — Official — mass low-value content risk
- [Next.js docs — opengraph-image, sitemap, generateMetadata](https://nextjs.org/docs/app/api-reference/file-conventions/metadata) — Official — metadata file conventions
- [Next.js docs — revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag) — Official — two-argument signature, profile "max"
- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification) — Official — feed format
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — media alternatives, text spacing

## License / Usage Notes
Summaries of public docs; code original. CMS and tool names are trademarks of their owners.

## Quality Tier
A — Grounded in Google Search Central, Next.js, RSS spec, and WCAG with complete implementation examples; editorial best practices are established convention.

## Status
Active

## Last Verified
2026-09-15
