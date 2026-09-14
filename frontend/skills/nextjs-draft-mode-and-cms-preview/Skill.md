# Next.js Draft Mode and CMS Preview

## Summary
Draft Mode lets editors see unpublished content from a headless CMS on the real Next.js site without waiting for revalidation. For requests with the Draft Mode cookie, Next.js skips the fetch cache, `'use cache'` results, `unstable_cache`, and the ISR response cache. Other visitors keep getting cached pages. This skill covers the preview entry route, validating the shared secret, exiting preview, how Draft Mode works with Cache Components, and CMS visual editing (Sanity, Payload, Contentful) on Next.js 16.3.x App Router.

## Category
Next.js

## Subcategories
Headless CMS, Caching, Route Handlers, Server Actions, Visual Editing, Content Workflows

## Problem It Solves
Statically rendered or cached pages hide draft content. Without a safe preview path, editors wait for a publish plus revalidation before seeing changes. Teams also end up with hacks like `?preview=true` query params that break caching or leak drafts to the public. Draft Mode is a per-browser cache bypass that the server controls and that is protected by a secret.

## When To Use
- A headless CMS (Sanity, Contentful, Payload, Storyblok, DatoCMS, Hygraph, WordPress headless) powers pages that are prerendered, cached with `'use cache'`, or served through ISR.
- Editors need a "Preview" button in the CMS that opens the live site showing draft content.
- You want click-to-edit overlays or live updates (Sanity Presentation, Payload Live Preview, Contentful Live Preview).
- You need to share draft versions of marketing pages before launch.

## When Not To Use
- The pages are already fully dynamic (rendered per request with no caching). Just fetch drafts behind auth.
- The content is user-generated and private to a user. Use normal authentication and authorization (see nextjs-authentication), not a global preview cookie.
- Static export (`output: 'export'`). There is no server to set the cookie or bypass caches.
- Long-lived stakeholder review links for people without CMS accounts. Build signed, expiring share links with authorization instead of handing out the preview secret.

## Core Principles
1. Draft Mode is a cache bypass tied to a cookie (`__prerender_bypass`). It is not authentication. Protect the route that sets it.
2. Only a server entry point (Route Handler or Server Action) may call `enable()` or `disable()`. They throw inside `'use cache'` scopes.
3. Redirect to a path taken from the CMS record, never from raw query input. Otherwise the route is an open redirect.
4. Draft credentials (preview tokens) are server-only. They never go in `NEXT_PUBLIC_*` variables.
5. Data-fetching code only needs to branch on `isEnabled` when the CMS uses a different endpoint or token for drafts.
6. Exiting preview is a state change, so use POST (a Server Action form), not a prefetched `<Link>`.

## Best Practices
- Store the shared secret in `CMS_PREVIEW_SECRET` (server env). Compare it in constant time and rotate it if it shows up in logs. Query strings are often logged by proxies and analytics tools.
- Look up the slug in the CMS (draft perspective) before enabling. Return 401/404 if the document does not exist.
- Render a visible preview banner with `role="status"` and an "Exit preview" form from the root layout, so editors always know they are seeing drafts.
- Add `robots: { index: false }` metadata when `isEnabled` is true. Preview responses are already `Cache-Control: private, no-cache, no-store`, but noindex is cheap insurance.
- With Cache Components, keep reading data inside `'use cache'` functions. Draft Mode makes them re-execute and skip saving results. You can read `isEnabled` there, but not `cookies()` or `headers()`.
- If you exit via a GET Route Handler, trigger it with `<form method="GET">`, or `<Link prefetch={false}>` at minimum. Prefetching clears the cookie before the editor clicks.
- Visual editing iframes (Sanity Presentation, Payload Live Preview) need your CSP `frame-ancestors` and `X-Frame-Options` to allow the Studio/admin origin. Allow only that origin.
- Every `next build` generates a new bypass cookie value, so preview sessions end after a deploy. Tell editors about this.

## Implementation Guidance
**Decision table: how drafts are fetched**

| CMS behavior | What to do |
|---|---|
| Same endpoint serves drafts when caches are bypassed | Nothing extra. Draft Mode bypass is enough |
| Separate preview API/host (e.g. Contentful Preview API) | Branch URL and token on `(await draftMode()).isEnabled` |
| Perspective/param based (Sanity `perspective: 'drafts'`, Payload `draft: true`) | Pass `isEnabled` into the query options |
| Real-time visual editing | Use the vendor toolkit (`next-sanity`, `@payloadcms/live-preview-react`, `@contentful/live-preview`), and still gate it on Draft Mode |

**Steps**
1. Generate a random secret and set `CMS_PREVIEW_SECRET` in the app and the CMS preview URL config: `https://site.com/api/draft?secret=<token>&slug=/posts/{slug}`.
2. Create `app/api/draft/route.ts` (GET, because the CMS opens a tab). Validate the secret and slug, call `(await draftMode()).enable()`, then `redirect()` to the CMS-sourced path.
3. Add a `PreviewBanner` Server Component with an exit Server Action that calls `disable()`.
4. Make fetchers draft-aware only where the CMS needs it.
5. Optionally add visual editing components, rendered only when `isEnabled`.
6. Make sure publish webhooks call `revalidateTag`/`revalidatePath` so published content updates for everyone (see nextjs-caching-and-revalidation).

## Recommended Workflow
1. Confirm how the CMS exposes drafts (endpoint, token, perspective) and whether it supports custom preview URLs.
2. Implement and unit-test the secret-validating route (bad secret gives 401, unknown slug gives 401/404, valid request sets the cookie and redirects).
3. Add the banner and exit action, and check that the cookie is removed.
4. Check that a published visitor in a private window never sees draft content.
5. Add visual editing last and check the iframe CSP.
6. Deploy to a preview environment and test end to end from the CMS "Preview" button.

## Patterns
**Secret-validated entry route**
```ts
// app/api/draft/route.ts
import { draftMode } from 'next/headers'
import { redirect } from 'next/navigation'
import { timingSafeEqual } from 'node:crypto'
import { getDraftDocBySlug } from '@/lib/cms'

function safeEqual(a: string, b: string) {
  const ab = Buffer.from(a)
  const bb = Buffer.from(b)
  return ab.length === bb.length && timingSafeEqual(ab, bb)
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const secret = searchParams.get('secret') ?? ''
  const slug = searchParams.get('slug')
  const expected = process.env.CMS_PREVIEW_SECRET

  if (!expected || !slug || !safeEqual(secret, expected)) {
    return new Response('Invalid token', { status: 401 })
  }
  const doc = await getDraftDocBySlug(slug) // server-only preview token inside
  if (!doc) return new Response('Not found', { status: 404 })

  ;(await draftMode()).enable()
  redirect(doc.path) // path from CMS data, not from searchParams
}
```

**Preview banner with POST exit**
```tsx
// app/preview-banner.tsx
import { draftMode } from 'next/headers'
import { redirect } from 'next/navigation'

async function exitPreview() {
  'use server'
  ;(await draftMode()).disable()
  redirect('/')
}

export async function PreviewBanner() {
  const { isEnabled } = await draftMode()
  if (!isEnabled) return null
  return (
    <aside role="status" className="fixed inset-x-0 bottom-0 bg-amber-300 p-2 text-center">
      Viewing draft content.{' '}
      <form action={exitPreview} className="inline">
        <button type="submit" className="underline">Exit preview</button>
      </form>
    </aside>
  )
}
```

**Draft-aware fetcher with a separate preview endpoint (Cache Components)**
```ts
// lib/cms.ts
import 'server-only'
import { draftMode } from 'next/headers'
import { cacheTag } from 'next/cache'

export async function getPost(slug: string) {
  'use cache'
  cacheTag(`post:${slug}`)
  const { isEnabled } = await draftMode() // readable inside 'use cache'
  const base = isEnabled ? process.env.CMS_PREVIEW_URL : process.env.CMS_DELIVERY_URL
  const token = isEnabled ? process.env.CMS_PREVIEW_TOKEN : process.env.CMS_DELIVERY_TOKEN
  const res = await fetch(`${base}/posts/${encodeURIComponent(slug)}`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  if (!res.ok) return null
  return (await res.json()) as { title: string; body: string; path: string }
}
```
In Draft Mode this function re-runs on every request and its result is not stored.

**noindex while previewing**
```ts
// app/posts/[slug]/page.tsx (excerpt)
import type { Metadata } from 'next'
import { draftMode } from 'next/headers'
export async function generateMetadata(): Promise<Metadata> {
  const { isEnabled } = await draftMode()
  return isEnabled ? { robots: { index: false, follow: false } } : {}
}
```

## Anti-Patterns
- **Unprotected `/api/draft`.** Anyone can turn on cache bypass, which lets them hammer your CMS and may expose drafts. Fix: require the secret and validate the slug.
- **`redirect(searchParams.get('slug'))`.** This is an open redirect (`slug=https://evil.tld`). Fix: redirect to a path from the fetched document, or allow only relative paths that start with a single `/`.
- **Preview token in `NEXT_PUBLIC_CMS_PREVIEW_TOKEN`.** It ships in the JS bundle and exposes every draft. Fix: server-only env var. Vendor browser tokens (Sanity `browserToken`) are handed out only during Draft Mode by the toolkit.
- **Calling `draftMode().enable()` inside a `'use cache'` function.** It throws. Fix: toggle it only in Route Handlers or Server Actions.
- **Reading `cookies()` inside cached code to detect preview.** That is not allowed in cache scopes. Fix: use `(await draftMode()).isEnabled`.
- **Exit link as a prefetched `<Link href="/api/disable-draft">`.** Prefetch deletes the cookie. Fix: use a Server Action form.
- **`?preview=true` query param that switches data sources.** Anyone can use it, and it fragments the cache. Fix: use Draft Mode.
- **Global `X-Frame-Options: DENY` blocking the Studio iframe, "fixed" by removing framing protection entirely.** Fix: `frame-ancestors 'self' https://your-studio.example`.

## Accessibility
- The preview banner uses `role="status"` (WCAG 4.1.3 Status Messages). It must not cover content or focus targets (WCAG 2.4.11 Focus Not Obscured). Reserve space or put it in a landmark.
- The exit button is a real `<button>` inside a form, keyboard operable (2.1.1), with a visible focus style (2.4.7).
- Visual-editing overlays add clickable outlines. Make sure they don't trap focus or break the published page's reading order. Test with the overlays turned off.

## Responsive Design
- Keep the banner compact on small screens (one line with an icon and an "Exit" button) and respect safe-area insets (`env(safe-area-inset-bottom)`).
- CMS preview panes often render the site in narrow iframes. Test preview at 320-400px widths because editors see that layout first.

## Performance
- Draft requests are uncached by design, so CMS latency is felt directly. Keep draft queries lean and use Suspense streaming for slow sections.
- Published traffic is unaffected. Don't add `await draftMode()` in places that would otherwise be static without checking the build output. `draftMode` is designed to work with prerendering, but confirm with `next build` route output.
- Live-preview subscriptions (e.g. `SanityLive`) open long-lived connections. Render them only when `isEnabled`.

## Security
- Treat the preview secret like a password: server env only, rotate it, and never commit it. The CMS also stores it, so limit who can see CMS settings.
- Use constant-time comparison. Return the same 401 message for a bad secret and a missing slug so the route doesn't reveal which check failed.
- Consider rate limiting `/api/draft` in `proxy.ts` or at the edge (see nextjs-middleware-proxy).
- The draft cookie is `HttpOnly`, and its value changes every build. Check the cookie attributes in DevTools after deploy. Embedded Studio iframes may need specific `SameSite` handling, so check current docs for your CMS toolkit.
- Stega-encoded strings (Sanity) insert invisible characters. Keep stega off outside Draft Mode, and strip it before using values in URLs, `<meta>`, or comparisons.
- Never let Draft Mode alone unlock private or paywalled data. Keep it separate from the auth checks in nextjs-authentication.

## Testing
- Route handler unit tests (Vitest): mock `draftMode` and the CMS lookup, then check the 401 cases, the redirect target, and that `enable` was called.
- Playwright E2E: visit `/api/draft?secret=...&slug=...`, check the banner is visible and the draft title renders, click "Exit preview", and check the published title returns. Also check that a fresh context never sees the draft.
- Check response headers in preview: `Cache-Control: private, no-cache, no-store...`.
- Security test: `slug=https://example.org` must not redirect off-site.

## Tooling
- `next/headers` `draftMode()` (async since v15). Stable in Next.js 16.3.x.
- `next-sanity` (`defineEnableDraftMode`, `defineLive`, `VisualEditing`) plus `@sanity/visual-editing` and Presentation tool. Active. The Sanity docs at time of research referenced next-sanity v13.x with Next 16.
- Payload: `admin.preview` URL function and `draft: isDraftMode` in `payload.find`, plus Live Preview (`@payloadcms/live-preview-react`). Active.
- Contentful: `@contentful/live-preview` (provider, live updates, inspector mode) with the Content Preview API. Check current docs (not re-verified this pass).

## Framework Notes
- **Next.js (App Router, 16.3.x):** `draftMode()` from `next/headers`. Enable in a Route Handler, disable in a Server Action or Route Handler. With Cache Components, `isEnabled` is readable in `'use cache'` and cached scopes re-execute without saving. Pages Router's old `previewData`/`setPreviewData` Preview Mode is legacy. Migrate to Draft Mode.
- **React (Vite SPA):** there is no server cache to bypass. Preview is a client concern: authenticate the editor, call the CMS preview API through your backend (never expose tokens in the bundle), and show a banner. Vendor live-preview SDKs work client-side.

## AI Agent Guidance
- Do: create the secret-validated route, the CMS-sourced redirect, the banner with a POST exit, and server-only tokens. Branch data sources only where the CMS requires it.
- Do: check `next.config` for `cacheComponents`, and keep `enable()`/`disable()` out of cached scopes.
- Don't: invent CMS SDK APIs. Open the vendor's current Next.js guide before writing Sanity, Payload, or Contentful code.
- Don't: put secrets in code or `NEXT_PUBLIC_*`. Use placeholders like `process.env.CMS_PREVIEW_SECRET`.
- Verify before done: bad secret gives 401, off-site slug doesn't redirect, the cookie is set and cleared, a published visitor sees no drafts, and the build output shows pages still prerendered.

## Examples
**Sanity (next-sanity) enable route and layout overlay**
```ts
// app/api/draft-mode/enable/route.ts
import { defineEnableDraftMode } from 'next-sanity/draft-mode'
import { client } from '@/sanity/lib/client'

export const { GET } = defineEnableDraftMode({
  client: client.withConfig({ token: process.env.SANITY_API_READ_TOKEN }),
})
```
```tsx
// app/layout.tsx (excerpt)
import { draftMode } from 'next/headers'
import { VisualEditing } from 'next-sanity/visual-editing'

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const { isEnabled } = await draftMode()
  return (
    <html lang="en">
      <body>
        {children}
        {isEnabled && <VisualEditing />}
      </body>
    </html>
  )
}
```
Sanity's Presentation tool calls the enable route with its own authenticated handshake, so you don't manage a shared secret for it.

**Payload preview URL and draft-aware query**
```ts
// collections/Pages.ts (excerpt)
admin: {
  preview: ({ slug }) =>
    `/preview?${new URLSearchParams({ slug: String(slug), path: `/${slug}`, previewSecret: process.env.PREVIEW_SECRET ?? '' })}`,
},
```
```ts
// in page.tsx
const { isEnabled } = await draftMode()
const { docs } = await payload.find({ collection: 'pages', where: { slug: { equals: slug } }, draft: isEnabled })
```
In the Payload `/preview` route, validate `previewSecret` and the Payload user session before calling `enable()`.

## Related Skills
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md): what Draft Mode bypasses, and publish-webhook revalidation
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md): the preview entry route
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): the exit-preview action
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md): rate limiting and header rules for preview routes
- [content-security-policy](../content-security-policy/Skill.md): `frame-ancestors` for visual-editing iframes
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md): keeping preview tokens server-only
- [content-and-blog-sites](../content-and-blog-sites/Skill.md): CMS-driven content sites
- [marketing-website-architecture](../marketing-website-architecture/Skill.md): editor workflows for marketing pages
- [nextjs-mdx-content](../nextjs-mdx-content/Skill.md): alternative file-based content

## Sources
- [Next.js Guide: Draft Mode](https://nextjs.org/docs/app/guides/draft-mode) (Official): route, secret, redirect, banner, Cache Components behavior (docs v16.3.5)
- [Next.js API: draftMode](https://nextjs.org/docs/app/api-reference/functions/draft-mode) (Official): methods, cookie name, per-build cookie value, cache-scope rules
- [Next.js Guide: Self-hosting](https://nextjs.org/docs/app/guides/self-hosting) (Official): Draft Mode `Cache-Control` headers
- [Sanity: Visual Editing with Next.js App Router](https://www.sanity.io/docs/visual-editing/visual-editing-with-next-js-app-router) (Official): `defineEnableDraftMode`, `VisualEditing`, `defineLive`, stega, Presentation config
- [Payload: Preview](https://payloadcms.com/docs/admin/preview) (Official): `admin.preview`, preview route with secret, `draft: isDraftMode`
- [Contentful: Live Preview](https://www.contentful.com/developers/docs/tutorials/general/live-preview/) (Official): referenced only. The fetch was rate-limited, so check current docs

## License / Usage Notes
Next.js docs (MIT-licensed project; docs content © Vercel), Sanity/Payload/Contentful docs are vendor-owned. This skill summarizes and adapts them. Code is illustrative and original, not copied verbatim.

## Quality Tier
A: core Draft Mode behavior verified against current Next.js 16.3.5 docs and Sanity/Payload official guides. Contentful details not re-verified.

## Status
Active

## Last Verified
2026-09-15
