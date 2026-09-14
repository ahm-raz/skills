# MDX Content in Next.js

## Summary
MDX lets you write Markdown with embedded React components. In Next.js 16.3.x App Router you can render it three main ways. `@next/mdx` compiles local `.mdx` files as pages or imports. A content layer (content-collections, Velite, Fumadocs MDX) turns folders of MDX into typed, schema-validated collections. Remote MDX compiles strings fetched from a CMS or database at request or build time. This skill covers choosing between them, frontmatter, custom components, Shiki syntax highlighting, Turbopack plugin constraints, and the security reality that MDX is code.

## Category
Next.js

## Subcategories
Content, Blogs, Documentation, Markdown, Syntax Highlighting, Static Generation, Security

## Problem It Solves
Teams need blogs, docs, and changelogs that are easy to write, typed, fast (prerendered), and styled with the design system. Without a clear approach they end up with untyped frontmatter parsing, runtime compilation on every request, broken code highlighting under Turbopack, or remote MDX that runs untrusted JavaScript on the server.

## When To Use
- Blogs, docs, changelogs, and legal pages authored by developers or trusted writers in the repo.
- Content that needs interactive embeds (callouts, tabs, live demos, charts).
- Docs sites that need a typed index (titles, dates, tags, ordering) and static generation.
- Content stored in a trusted CMS field as MDX, compiled on the server.

## When Not To Use
- User-generated content (comments, forum posts, profile bios). MDX runs JavaScript. Use plain Markdown with sanitization (`react-markdown` or `unified` + `rehype-sanitize`).
- Non-technical editors who need WYSIWYG, scheduling, and localization workflows. Use a headless CMS with rich text (see nextjs-draft-mode-and-cms-preview).
- A handful of static pages with no Markdown benefit. Plain TSX is simpler.

## Core Principles
1. MDX is executable code. Only compile MDX from trusted authors and sources.
2. Compile at build time whenever possible (static params plus a content layer). Runtime compilation costs CPU and adds attack surface.
3. Validate frontmatter with a schema. Bad content should fail the build, not production.
4. Map Markdown elements to design-system components in one place (`mdx-components.tsx`).
5. Highlight code at build or server time (Shiki) and ship zero highlighting JS to the client.
6. Under Turbopack (default in Next 16), `@next/mdx` remark/rehype plugins must be referenced by string name with serializable options.

## Best Practices
- `mdx-components.tsx` at the project root (or `src/`) is required for `@next/mdx` in App Router. Map `a` to `next/link` for internal links, `img` to `next/image`, and `pre`/`code` to styled components.
- Use `generateStaticParams` plus `export const dynamicParams = false` for file-based posts so unknown slugs 404.
- Derive `generateMetadata` from validated frontmatter (title, description, OG image, canonical).
- Use `rehype-slug` plus `rehype-autolink-headings` for anchor links, and generate the table of contents from the same heading data.
- Use `rehype-pretty-code` (Shiki-powered) with `{ light, dark }` themes and style via its data attributes, or use `@shikijs/rehype` (check current docs).
- Wrap long code blocks in a focusable scroll container, and give them a copy button that is a real `<button>`.
- Use `@tailwindcss/typography` `prose` classes in a shared layout, and override element mappings only where needed.
- Keep drafts out of production: filter `draft: true` in the collection, not in each page.
- Don't use `next-mdx-remote` for new projects. The repo is archived. If you need remote MDX, use a maintained alternative (check current docs; the community fork `next-mdx-remote-client` exists) or compile with `@mdx-js/mdx` in a server-only module.

## Implementation Guidance
**Decision table**

| Situation | Choose |
|---|---|
| Few MDX pages, colocated in `app/` | `@next/mdx` file-based routing |
| Blog/docs folder with frontmatter, listing pages, types | content-collections or Velite (build-time content layer) |
| Full documentation site (search, sidebar, versioning) | Fumadocs (Fumadocs MDX) |
| MDX stored in trusted CMS/DB | Server-side compile (`@mdx-js/mdx` `evaluate` or maintained remote-MDX lib), cached with `'use cache'` |
| Untrusted Markdown | Not MDX: `react-markdown` + `rehype-sanitize` |

**@next/mdx setup (Next.js 16, Turbopack)**
1. Install `@next/mdx @mdx-js/loader @mdx-js/react @types/mdx`.
2. Configure `next.config.ts`/`.mjs` with `pageExtensions` and `createMDX`. Plugins go in as strings.
3. Add `mdx-components.tsx`.
4. Frontmatter: `@next/mdx` has no frontmatter support by default. Either `export const metadata = {...}` inside the MDX, or use `remark-frontmatter` + `remark-mdx-frontmatter`.
5. By default only `.mdx` is compiled. Set `extension: /\.(md|mdx)$/` for `.md` (webpack). Check current docs for the Turbopack equivalent.
6. The Rust compiler (`experimental.mdxRs`) is experimental and not for production.

## Recommended Workflow
1. Decide on the source and trust level (repo, trusted CMS, or users). If users, stop and use sanitized Markdown.
2. Pick the approach from the decision table and scaffold one post end to end.
3. Define the frontmatter schema (title, description, date, tags, draft, ogImage) and fail the build on errors.
4. Build `mdx-components.tsx` with the design-system typography, links, images, callouts, and code blocks.
5. Add Shiki highlighting with light and dark themes, and check contrast.
6. Add listing, tag, and RSS pages from the collection. Add `generateMetadata` and sitemap entries.
7. Run `next build` and confirm posts are prerendered (static) in the route output.

## Patterns
**next.config.ts with string plugins**
```ts
// next.config.ts
import createMDX from '@next/mdx'
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  pageExtensions: ['ts', 'tsx', 'md', 'mdx'],
}

const withMDX = createMDX({
  options: {
    remarkPlugins: ['remark-gfm', 'remark-frontmatter', ['remark-mdx-frontmatter', { name: 'frontmatter' }]],
    rehypePlugins: [
      'rehype-slug',
      ['rehype-pretty-code', { theme: { light: 'github-light', dark: 'github-dark' }, keepBackground: false }],
    ],
  },
})

export default withMDX(nextConfig)
```
Options must be JSON-serializable under Turbopack. Plugins that take functions (custom Shiki transformers) need webpack or a content layer that runs plugins in JS.

**mdx-components.tsx mapped to the design system**
```tsx
// mdx-components.tsx
import type { MDXComponents } from 'mdx/types'
import Link from 'next/link'
import Image, { type ImageProps } from 'next/image'
import { Callout } from '@/components/callout'

const components = {
  a: ({ href = '', ...props }) =>
    href.startsWith('/') ? <Link href={href} {...props} /> : <a href={href} rel="noopener noreferrer" target="_blank" {...props} />,
  img: (props) => <Image sizes="(min-width: 768px) 720px, 100vw" style={{ width: '100%', height: 'auto' }} {...(props as ImageProps)} />,
  pre: (props) => <pre tabIndex={0} className="overflow-x-auto rounded-lg p-4" {...props} />,
  Callout,
} satisfies MDXComponents

export function useMDXComponents(): MDXComponents {
  return components
}
```

**Static dynamic route over a content folder**
```tsx
// app/blog/[slug]/page.tsx
import type { Metadata } from 'next'
import { readdir } from 'node:fs/promises'

export const dynamicParams = false

export async function generateStaticParams() {
  const files = await readdir('content/blog')
  return files.filter((f) => f.endsWith('.mdx')).map((f) => ({ slug: f.replace(/\.mdx$/, '') }))
}

export async function generateMetadata({ params }: PageProps<'/blog/[slug]'>): Promise<Metadata> {
  const { slug } = await params
  const { frontmatter } = await import(`@/content/blog/${slug}.mdx`)
  return { title: frontmatter.title, description: frontmatter.description }
}

export default async function Page({ params }: PageProps<'/blog/[slug]'>) {
  const { slug } = await params
  const { default: Post } = await import(`@/content/blog/${slug}.mdx`)
  return <article className="prose dark:prose-invert mx-auto"><Post /></article>
}
```

**Typed collection (content-collections)**
```ts
// content-collections.ts
import { defineCollection, defineConfig } from '@content-collections/core'
import { compileMDX } from '@content-collections/mdx'
import { z } from 'zod'

const posts = defineCollection({
  name: 'posts',
  directory: 'content/posts',
  include: '**/*.mdx',
  schema: z.object({
    title: z.string(),
    description: z.string().max(160),
    date: z.coerce.date(),
    draft: z.boolean().default(false),
  }),
  transform: async (doc, context) => ({
    ...doc,
    slug: doc._meta.path,
    mdx: await compileMDX(context, doc),
  }),
})

export default defineConfig({ collections: [posts] })
```
Wrap `next.config` with `withContentCollections` from `@content-collections/next` and render with `MDXContent` from `@content-collections/mdx/react`. The schema API form has changed across versions (function `(z) => ({})` vs a Standard Schema object), so check current docs.

## Anti-Patterns
- **Rendering user-submitted MDX.** That is remote code execution or XSS on your server. Fix: use sanitized Markdown (`rehype-sanitize`) and never MDX for untrusted input.
- **Disabling `blockJS`/`blockDangerousJS` in next-mdx-remote v6 "to make expressions work".** It removes the RCE guardrails. Fix: pass data as component props, or only compile fully trusted content.
- **Starting a new project on `next-mdx-remote`.** The repo is archived and won't get security fixes. Fix: use a content layer, `@next/mdx`, or a maintained alternative.
- **Passing plugin functions in `createMDX` under Turbopack.** The build fails or plugins are silently skipped. Fix: string plugin names with serializable options.
- **Parsing frontmatter with `gray-matter` in every page without validation.** Typos ship to production. Fix: a schema in a content layer, or a zod parse in one loader.
- **Client-side highlighting (Prism or highlight.js in the bundle).** Adds JS weight and flashes unstyled code. Fix: build-time Shiki.
- **Raw `<img>` in MDX without dimensions.** Causes CLS and no optimization. Fix: map `img` to `next/image` and require alt text.
- **`dynamicParams` left true with a filesystem import.** Unknown slugs throw 500s. Fix: `dynamicParams = false` or explicit `notFound()`.

## Accessibility
- Keep one `h1` per page (from frontmatter) and start MDX body headings at `##` (WCAG 1.3.1 Info and Relationships, 2.4.6 Headings and Labels).
- Scrollable `pre` blocks need `tabIndex={0}` so keyboard users can scroll them (2.1.1). Syntax themes must meet 4.5:1 text contrast in both light and dark (1.4.3). Many default Shiki themes fail on comments, so check.
- Autolinked heading anchors need an accessible name (`aria-label="Link to section: …"`) or visually hidden text.
- Require `alt` on images. Consider a remark lint rule that fails when alt is missing. Decorative images get `alt=""`.
- Copy-code buttons: a real `<button>` with a label, announcing "Copied" via `aria-live="polite"`.
- Set `lang` for code and for foreign-language passages where relevant.

## Responsive Design
- Constrain measure to about 65-75ch (`prose` max-width) and let code blocks scroll horizontally instead of overflowing the viewport.
- Tables: wrap them in an overflow container with a visible scroll affordance.
- Embedded demos and iframes: use `aspect-ratio` wrappers and lazy loading.
- Set `sizes` on mapped `next/image` to match the content column width.

## Performance
- Build-time compilation plus static params gives zero MDX runtime cost. Confirm prerendered pages in `next build` output.
- Shiki at build time ships no client JS. Avoid shipping large language grammars to the client.
- Keep interactive MDX components as small Client Components. The MDX body stays a Server Component.
- For remote MDX, cache compiled output (`'use cache'` + `cacheTag`) and revalidate on CMS publish instead of compiling per request.
- Watch build times with thousands of posts. Content layers cache transforms. Parallelize image processing.

## Security
- Trust boundary: MDX from the repo (reviewed via PRs) is trusted. MDX from a CMS is trusted only if CMS write access is tightly controlled. MDX from users is never trusted.
- For untrusted Markdown, use `unified().use(remarkParse).use(remarkRehype).use(rehypeSanitize)`. The sanitizer strips `javascript:` URLs, event handlers, and prefixes ids to prevent DOM clobbering.
- Don't allow raw HTML passthrough (`rehype-raw`) without sanitizing after it.
- External links: add `rel="noopener noreferrer"`. Consider allowlisting embed domains for iframes, and enforce with CSP `frame-src`.
- Components exposed to MDX are an API surface. Don't expose components that read secrets, run queries from props, or render `dangerouslySetInnerHTML`.
- Remote compile happens on the server, so limit input size and compile time to avoid DoS.

## Testing
- Build test in CI: `next build` fails on schema or frontmatter errors and broken imports.
- Unit test the `mdx-components` mappings (internal vs external link behavior, image alt required) with Testing Library.
- Link checking: run a link checker over the built output for broken internal anchors.
- Visual regression on a "kitchen sink" MDX page (headings, lists, tables, code in light and dark, callouts).
- Accessibility: axe on the kitchen-sink page and contrast checks for code themes.
- Security test: feed `<img src=x onerror=alert(1)>` and `[x](javascript:alert(1))` through the untrusted-Markdown path and assert both are stripped.

## Tooling
- `@next/mdx` + `@mdx-js/loader` + `@mdx-js/react` + `@types/mdx`: official, Active (Next.js 16.3.x docs).
- `experimental.mdxRs`: experimental, not for production.
- `next-mdx-remote`: archived, no longer supported. v6 defaults `blockJS: true`, `blockDangerousJS: true`. Avoid for new work.
- content-collections (`@content-collections/core`, `/next`, `/mdx`): Active, MIT.
- Velite: Active. The recommended Next.js integration starts the build from `next.config` (top-level await) because the webpack plugin doesn't work with Turbopack. Check current docs.
- Fumadocs (Fumadocs MDX): Active. A docs framework with official Next.js support, ESM-only.
- `rehype-pretty-code` (Shiki): Active. Build-time, multi-theme, unstyled data attributes.
- `remark-gfm`, `remark-frontmatter`, `remark-mdx-frontmatter`, `rehype-slug`, `rehype-autolink-headings`, `rehype-sanitize`: Active unified ecosystem.
- `@tailwindcss/typography`: `prose` styling.

## Framework Notes
- **Next.js (App Router, 16.3.x):** MDX pages and imports are Server Components by default. `mdx-components.tsx` is required. Turbopack is the default bundler, so use string plugin names. Metadata comes from `export const metadata` in MDX pages or `generateMetadata` in wrapper pages.
- **React (Vite SPA):** use `@mdx-js/rollup` in `vite.config.ts` and `MDXProvider` from `@mdx-js/react` for component mapping. Content ships in the JS bundle and highlighting happens at build time via the rehype plugin. Use prerendering if SEO matters.

## AI Agent Guidance
- Do: ask or determine the content trust level first. Refuse MDX for user-generated content and use sanitized Markdown instead.
- Do: check `next.config` for Turbopack/webpack before adding plugins, and use string names under Turbopack.
- Do: create `mdx-components.tsx` if it's missing, and map links, images, and code blocks.
- Don't: add `next-mdx-remote` to new code, or disable its JS blocking.
- Don't: invent content-collections or Velite config keys. Read their current docs, since APIs have shifted.
- Verify before done: `next build` passes, posts are static, unknown slug returns 404, code themes meet contrast in light and dark, and axe is clean on a sample post.

## Examples
**Sanitized Markdown for untrusted input (not MDX)**
```tsx
// components/user-markdown.tsx (Server Component)
import { unified } from 'unified'
import remarkParse from 'remark-parse'
import remarkRehype from 'remark-rehype'
import rehypeSanitize from 'rehype-sanitize'
import rehypeStringify from 'rehype-stringify'

export async function UserMarkdown({ source }: { source: string }) {
  if (source.length > 20_000) throw new Error('Content too long')
  const html = String(
    await unified().use(remarkParse).use(remarkRehype).use(rehypeSanitize).use(rehypeStringify).process(source),
  )
  return <div className="prose" dangerouslySetInnerHTML={{ __html: html }} /> // safe only because sanitized
}
```

**Server compile of trusted CMS MDX with caching**
```tsx
// lib/cms-mdx.tsx
import 'server-only'
import { evaluate } from '@mdx-js/mdx'
import * as runtime from 'react/jsx-runtime'
import { cacheTag } from 'next/cache'
import { useMDXComponents } from '@/mdx-components'

export async function CmsMdx({ id, source }: { id: string; source: string }) {
  'use cache'
  cacheTag(`cms-mdx:${id}`)
  const { default: Content } = await evaluate(source, { ...runtime }) // trusted editors only
  return <Content components={useMDXComponents()} />
}
```
Only use this when CMS write access is restricted to trusted staff. Check current `@mdx-js/mdx` docs for `evaluate` options.

## Related Skills
- [content-and-blog-sites](../content-and-blog-sites/Skill.md): information architecture for blogs
- [documentation-site-patterns](../documentation-site-patterns/Skill.md): docs navigation, search, versioning
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md): metadata from frontmatter, sitemaps
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md): static generation of content routes
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md): mapping MDX images to `next/image`
- [nextjs-draft-mode-and-cms-preview](../nextjs-draft-mode-and-cms-preview/Skill.md): CMS-authored content previews
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md): XSS and sanitization
- [content-security-policy](../content-security-policy/Skill.md): restricting embeds
- [dark-mode-implementation](../dark-mode-implementation/Skill.md): dual Shiki themes
- [tailwind-css-v4](../tailwind-css-v4/Skill.md): typography plugin styling

## Sources
- [Next.js Guide: Markdown and MDX](https://nextjs.org/docs/app/guides/mdx) (Official): setup, `mdx-components.tsx`, frontmatter, dynamic imports, Turbopack string plugins, sanitize pipeline, mdxRs (docs v16.3.5)
- [next-mdx-remote README](https://github.com/hashicorp/next-mdx-remote) (Open Source): archived status, RSC API, `blockJS`/`blockDangerousJS` defaults, user-input warning
- [content-collections README](https://github.com/sdorra/content-collections) (Open Source): purpose, collections, MDX package, status
- [Velite: with Next.js](https://velite.js.org/guide/with-nextjs) (Open Source): integration methods, Turbopack note
- [Fumadocs README](https://github.com/fuma-nama/fumadocs) (Open Source): scope and Next.js support
- [Rehype Pretty Code](https://rehype-pretty.pages.dev/) (Open Source): Shiki-based highlighting, themes, data attributes

## License / Usage Notes
Next.js docs, and MIT-licensed packages (@next/mdx, MDX, unified plugins, content-collections, Velite, Fumadocs, rehype-pretty-code; verify each repo's license). next-mdx-remote is MPL-2.0 (check repo). This content is summarized, and the examples are original.

## Quality Tier
B: `@next/mdx` and security guidance verified against Next.js 16.3.5 docs. Content-layer API specifics (content-collections schema form, Velite config) are only partially verified and flagged.

## Status
Active

## Last Verified
2026-09-15
