# Next.js Image and Font Optimization

## Summary
`next/image` resizes, converts (WebP/AVIF), lazy-loads, and prevents layout shift for images; `next/font` self-hosts Google and local fonts at build time with automatic fallback metrics to eliminate font CLS. Next.js 16 changed several image defaults for security and cost (`qualities: [75]`, `minimumCacheTTL` 4h, no 16px size, local IP blocked, max 3 redirects, `localPatterns` required for query strings) and deprecated `priority` in favor of `preload`. The August 2026 security release (16.3.3 / 15.5.24) disabled AVIF optimization pending an upstream libheif fix.

## Category
Next.js

## Subcategories
next/image, remotePatterns, sizes, preload, placeholder, getImageProps, image loaders, next/font/google, next/font/local, variable fonts, CSS variables, Tailwind v4

## Problem It Solves
Oversized hero images killing LCP, CLS from unsized images and late-loading fonts, open image optimizers abused for SSRF/DoS/cost, third-party font requests leaking user IPs to Google, and outdated tutorials using `layout="fill"`, `images.domains`, or `priority`.

## When To Use
- Any raster image in UI (content, hero, avatars, product photos).
- Configuring remote image sources or a CDN loader.
- Loading brand or UI fonts.
- Art direction (different images per breakpoint) or theme-dependent images.

## When Not To Use
- SVG icons (inline React components or `<img>`; SVG through the optimizer requires `dangerouslyAllowSVG` + CSP).
- Images you already optimize via a media CDN — use a custom `loader` or `unoptimized`.
- System font stacks where no web font is needed.

## Core Principles
1. **Always give the browser dimensions** (`width`/`height` or `fill` + sized parent) to prevent CLS.
2. **Always set `sizes` for responsive/`fill` images** or the browser downloads oversized candidates.
3. **Only the LCP image is eager.** Use `preload` (or `loading="eager"`/`fetchPriority="high"`) on it; everything else lazy.
4. **Allowlist remote sources narrowly** with `remotePatterns` (protocol, hostname, pathname).
5. **Fonts are defined once, at module scope,** and applied via `className` or CSS variables.

## Best Practices
- Static imports (`import hero from './hero.jpg'`) give automatic width/height and blur placeholder.
- `quality` must be in `images.qualities` (default `[75]`); other values are coerced to the closest allowed.
- Configure `images.formats` intentionally; after 16.3.3 AVIF optimization is disabled by the security patch — don't rely on AVIF output until upstream fixes ship.
- Use `remotePatterns: [new URL('https://cdn.acme.com/assets/**')]` (URL objects supported since 15.3).
- For local images with query strings add `images.localPatterns` with `search`.
- Leave `dangerouslyAllowLocalIP` false unless on a private network and you understand SSRF risk.
- Prefer variable fonts; specify `subsets`; use `display: 'swap'` (default) and `variable: '--font-sans'` for Tailwind v4 `@theme`.
- Define fonts in `app/fonts.ts` and import where needed so each font is instantiated once.
- On glibc Linux self-hosting, configure sharp's memory allocator guidance to avoid memory bloat.

## Implementation Guidance

### v16 image defaults and config
```ts
// next.config.ts
import type { NextConfig } from 'next'
const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'images.acme-cms.com', pathname: '/uploads/**' },
    ],
    localPatterns: [{ pathname: '/assets/**', search: '' }],
    qualities: [60, 75, 90],        // default [75]
    // formats: ['image/webp'],      // AVIF disabled by 16.3.3 security patch
    minimumCacheTTL: 14400,          // default since v16 (4h)
    maximumRedirects: 3,             // default since v16
    // imageSizes default no longer includes 16
    // dangerouslyAllowLocalIP: false (default)
  },
}
export default nextConfig
```

### Prop decision table
| Situation | Props |
|---|---|
| Fixed-size avatar/thumbnail | `width`, `height`, `alt` |
| Fluid content image | `width`, `height`, `sizes="(max-width: 768px) 100vw, 768px"`, `style={{ width: '100%', height: 'auto' }}` |
| Background/cover in sized container | `fill`, `sizes`, `style={{ objectFit: 'cover' }}`, parent `position: relative` |
| LCP hero | add `preload` (16+) or `loading="eager"` + `fetchPriority="high"` |
| Decorative | `alt=""` |
| Blur-up | static import + `placeholder="blur"`, or `blurDataURL` for remote |
| Already optimized | `unoptimized` or custom `loader` |

### Hero image
```tsx
import Image from 'next/image'
import hero from '@/public/hero.jpg'

export function Hero() {
  return (
    <div className="relative aspect-[16/9] w-full">
      <Image
        src={hero}
        alt="Team planning a sprint on a whiteboard"
        fill
        sizes="100vw"
        preload
        placeholder="blur"
        style={{ objectFit: 'cover' }}
      />
    </div>
  )
}
```

### Art direction with getImageProps
```tsx
import { getImageProps } from 'next/image'

export function ResponsiveBanner() {
  const common = { alt: 'Spring sale', sizes: '100vw' }
  const { props: { srcSet: desktop } } = getImageProps({ ...common, src: '/banner-wide.jpg', width: 1600, height: 600 })
  const { props: { srcSet: mobile, ...rest } } = getImageProps({ ...common, src: '/banner-tall.jpg', width: 750, height: 1000 })
  return (
    <picture>
      <source media="(min-width: 768px)" srcSet={desktop} />
      <source media="(max-width: 767px)" srcSet={mobile} />
      <img {...rest} style={{ width: '100%', height: 'auto' }} />
    </picture>
  )
}
```

### Fonts with Tailwind v4 variables
```ts
// app/fonts.ts
import { Inter, JetBrains_Mono } from 'next/font/google'
import localFont from 'next/font/local'

export const sans = Inter({ subsets: ['latin'], variable: '--font-sans', display: 'swap' })
export const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono' })
export const brand = localFont({
  src: [
    { path: './fonts/Brand-Regular.woff2', weight: '400', style: 'normal' },
    { path: './fonts/Brand-Bold.woff2', weight: '700', style: 'normal' },
  ],
  variable: '--font-brand',
})
```
```tsx
// app/layout.tsx
import { sans, mono, brand } from './fonts'
export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable} ${brand.variable}`}>
      <body className="font-sans">{children}</body>
    </html>
  )
}
```
```css
/* app/globals.css */
@import 'tailwindcss';
@theme {
  --font-sans: var(--font-sans), ui-sans-serif, system-ui, sans-serif;
  --font-mono: var(--font-mono), ui-monospace, monospace;
}
```

### Custom CDN loader
```ts
// image-loader.ts (images: { loader: 'custom', loaderFile: './image-loader.ts' })
export default function loader({ src, width, quality }: { src: string; width: number; quality?: number }) {
  return `https://cdn.acme.com/cdn-cgi/image/width=${width},quality=${quality ?? 75},format=auto${src}`
}
```

## Recommended Workflow
1. Identify the LCP element per template; give it `preload` and correct `sizes`.
2. Configure `remotePatterns`/`localPatterns`/`qualities` minimally.
3. Replace raw `<img>` for content images with `next/image`; add `alt` text.
4. Define fonts in one module; apply via CSS variables.
5. Patch to ≥16.3.3 (or 15.5.24) for the image optimizer RCE fixes.
6. Measure with Lighthouse/field CWV; check network waterfall for oversized images.

## Patterns
- **Aspect-ratio container + `fill`** for CMS images of unknown size.
- **Theme images:** two `<Image>` with CSS `dark:hidden`/`hidden dark:block` (both lazy; don't `preload` both).
- **Avatar component** wrapping `next/image` with fixed sizes and fallback initials.
- **Font subset per locale** (`subsets: ['latin', 'cyrillic']`) only where needed.

## Anti-Patterns
- **`priority` prop** — deprecated in v16. Fix: `preload` or `loading="eager"` + `fetchPriority="high"`.
- **`images.domains`** — deprecated (no protocol/path restriction). Fix: `remotePatterns`.
- **`next/legacy/image`** — deprecated. Fix: `next/image`.
- **`fill` without `sizes`** — downloads 100vw-sized images for thumbnails. Fix: accurate `sizes`.
- **Wildcard `remotePatterns` (`hostname: '**'`)** — optimizer becomes an open proxy (cost, SSRF). Fix: exact hosts and paths.
- **`preload` on many images or on theme-duplicated images** — wasted bytes, both load. Fix: one LCP image.
- **Calling `Inter()` inside a component** — new font instance per render/module. Fix: module-scope font file.
- **Google Fonts `<link>` in layout** — third-party request, CLS. Fix: `next/font/google`.
- **`quality={90}` without config** — silently coerced to 75 in v16. Fix: add 90 to `qualities`.

## Accessibility
- Meaningful `alt` for informative images; `alt=""` for decorative (WCAG 1.1.1).
- Don't embed text in images when real text works (WCAG 1.4.5); OG images are the exception.
- Blur placeholders must not be the only content during slow loads for critical info.
- Fonts: ensure fallback metrics keep text readable; respect user font-size scaling (use `rem`).

## Responsive Design
- `sizes` must mirror your CSS layout breakpoints; update both together.
- Use `getImageProps` + `<picture>` for art direction instead of CSS-hiding duplicated `next/image` with `preload`.
- `deviceSizes`/`imageSizes` defaults cover most layouts; trim them to reduce variants if costs matter.

## Performance
- LCP: correct `sizes`, `preload` on hero, keep hero outside Suspense boundaries.
- CLS: dimensions/aspect-ratio for all images; `next/font` `adjustFontFallback` (on by default) removes font swap shift.
- `minimumCacheTTL` 4h default reduces re-optimization cost; set `Cache-Control` on origin images.
- Fonts are preloaded only on routes where they are used.

## Security
- The optimizer fetches remote URLs server-side: narrow `remotePatterns`, keep `maximumRedirects` low, keep local IPs blocked.
- `dangerouslyAllowSVG` requires `contentDispositionType: 'attachment'` and a restrictive `contentSecurityPolicy`.
- August 2026: GHSA-2xp9-vwfh-vxw4 (libheif via sharp) enabled unauthenticated RCE when optimizing attacker-controlled AVIF; patched releases disable AVIF optimization — upgrade to 16.3.3+/15.5.24+.
- `next/font` self-hosting avoids sending user IPs to Google (privacy/GDPR).

## Testing
- Lighthouse CI budgets for LCP/CLS; check "Properly size images" audit.
- Playwright: assert the hero `<link rel="preload" as="image">` exists and non-hero images have `loading="lazy"`.
- Request `/_next/image?url=https://evil.example/x.png&w=64&q=75` in CI and expect 400.

## Tooling
- `sharp` (bundled/automatic for `next start`).
- Custom loaders: Cloudinary, Imgix, Cloudflare Images, Vercel Image Optimization (automatic on Vercel).
- `@next/codemod` `next-image-to-legacy-image`/`next-image-experimental` (historical v13 migrations).

## Framework Notes
- v16.0: `preload` added, `priority` deprecated, `qualities` default `[75]`, `dangerouslyAllowLocalIP`, `maximumRedirects`; v16.1 added `maximumResponseBody`, `maximumDiskCacheSize`.
- Static export requires a custom loader (no built-in optimizer).
- React (Vite SPA): no built-in optimizer — use responsive `<img srcset sizes>`, `fetchpriority`, an image CDN, and `@fontsource` packages or self-hosted `@font-face` with `size-adjust` fallbacks.

## AI Agent Guidance
- Use `preload` (not `priority`) on exactly one LCP image per route; always provide `sizes` with `fill`.
- Never add wildcard `remotePatterns`; add only hosts seen in data.
- Define fonts once in `app/fonts.ts`.
- Before done: verify no console warnings about missing `sizes`/quality coercion, confirm Next.js version ≥16.3.3 (or 15.5.24), and run Lighthouse on a key page.

## Examples
```tsx
// Product grid card
import Image from 'next/image'
export function ProductCard({ p }: { p: { name: string; imageUrl: string } }) {
  return (
    <figure>
      <div className="relative aspect-square">
        <Image src={p.imageUrl} alt={p.name} fill sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw" style={{ objectFit: 'cover' }} />
      </div>
      <figcaption>{p.name}</figcaption>
    </figure>
  )
}
```

## Related Skills
- [image-optimization](../image-optimization/Skill.md) — general image formats and delivery
- [font-loading-performance](../font-loading-performance/Skill.md) — font loading theory
- [lcp-optimization](../lcp-optimization/Skill.md) — LCP diagnostics
- [cls-prevention](../cls-prevention/Skill.md) — layout shift
- [responsive-images-and-media](../responsive-images-and-media/Skill.md) — srcset/sizes/picture
- [tailwind-css-v4](../tailwind-css-v4/Skill.md) — font variables in @theme
- [accessible-images-and-media](../accessible-images-and-media/Skill.md) — alt text

## Sources
- [Image Component reference](https://nextjs.org/docs/app/api-reference/components/image) — Official — props, config, preload/priority, qualities, getImageProps, version history
- [Font Optimization](https://nextjs.org/docs/app/getting-started/fonts) — Official — google/local fonts, self-hosting
- [Upgrading to v16](https://nextjs.org/docs/app/guides/upgrading/version-16) — Official — image default changes and rationale
- [August 2026 Security Release](https://nextjs.org/blog/august-2026-security-release) — Official — AVIF/libheif RCE, patched versions
- [Self-hosting guide](https://nextjs.org/docs/app/guides/self-hosting) — Official — sharp memory note, TTL
- [Static exports](https://nextjs.org/docs/app/guides/static-exports) — Official — custom loader requirement

## License / Usage Notes
Next.js MIT; sharp Apache-2.0; Google Fonts are under their respective open font licenses (check each family). Content summarized.

## Quality Tier
S — Version-precise config changes, deprecations, and the latest security patch verified from official sources.

## Status
Active

## Last Verified
2026-09-15
