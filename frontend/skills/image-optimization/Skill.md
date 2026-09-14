# Image Optimization

## Summary
Image optimization delivers the smallest acceptable image for each device and layout: modern formats (AVIF/WebP), correct dimensions via `srcset`/`sizes`, compression, CDN transforms with long-lived caching, lazy loading below the fold, prioritized loading for the LCP image, and reserved space to prevent CLS. In this stack that means `next/image` (Next.js) or an image CDN + plain `<img>`/`@unpic/react` (Vite SPA).

## Category
Performance

## Subcategories
AVIF, WebP, JPEG XL, srcset/sizes, next/image, image CDNs, lazy loading, fetchPriority, placeholders, SVG, caching

## Problem It Solves
Images are usually the heaviest bytes on a page and the most common LCP element. Oversized, unoptimized or badly prioritized images slow LCP, waste mobile data, and cause layout shifts when dimensions are missing.

## When To Use
- Any page with photos, product images, avatars, hero banners, user uploads.
- LCP element is an image; Lighthouse flags "Improve image delivery" insight.
- Setting up image pipelines/CDNs or `next.config` images settings.

## When Not To Use
- Icons and simple illustrations: use inline SVG / SVG sprites (and optimize with SVGO), not raster pipelines.
- Decorative gradients/shapes: CSS.
- Accessibility of image content (alt text strategy) — see [accessible-images-and-media](../accessible-images-and-media/Skill.md); art-direction layout — see [responsive-images-and-media](../responsive-images-and-media/Skill.md).

## Core Principles
1. **Right size**: never ship more pixels than rendered width × DPR (cap DPR at 2 for most photos).
2. **Right format**: AVIF first, WebP fallback, JPEG/PNG last; negotiate via `Accept` (CDN / next/image) or `<picture>`.
3. **Right priority**: LCP image eager + `fetchPriority="high"`; everything below the fold lazy.
4. **Reserve space**: width/height or aspect-ratio always.
5. **Cache forever with content-hashed URLs**; transform once at the edge.

## Best Practices
- Quality defaults: AVIF q≈50–65, WebP q≈70–80, JPEG q≈75–85 (verify visually for your content). Next.js 16 default `images.qualities` is `[75]`.
- `sizes` must match CSS layout per breakpoint; wrong `sizes` is the #1 cause of oversized downloads.
- Generate widths in steps (e.g., 320, 640, 768, 1024, 1280, 1600, 1920) — too many widths hurt CDN cache hit ratio.
- Store intrinsic width/height (and optionally a blurhash/dominant color) with each uploaded asset.
- Strip metadata (EXIF) on upload for size and privacy.
- Use `decoding="async"` for non-critical images (browsers default sensibly; don't force `sync`).
- Animated GIFs → `<video autoplay muted loop playsinline>` (MP4/WebM) or animated AVIF/WebP.
- Background images in CSS aren't discoverable early and lack `srcset`; prefer `<img>` with `object-fit`.
- JPEG XL: Safari 17+ only (Chrome 145 behind a flag as of 2026) — don't rely on it without fallbacks.

## Implementation Guidance

### Format decision
| Content | Format | Notes |
|---|---|---|
| Photos | AVIF → WebP → JPEG | AVIF ~20–50% smaller than WebP at similar quality; slower encode (do at CDN/build) |
| Screenshots/UI with text | WebP lossless or PNG; AVIF can blur text at low q | Test legibility |
| Transparency | AVIF/WebP (alpha) | Avoid PNG-24 for photos |
| Icons/logos | SVG | SVGO; inline critical icons |
| Animations | MP4/WebM video | 5–10× smaller than GIF |

### next.config (Next.js 16)
```ts
// next.config.ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  images: {
    formats: ['image/avif', 'image/webp'],   // AVIF preferred; each format cached separately
    qualities: [60, 75],                      // required allowlist in Next 16 (default [75])
    remotePatterns: [{ protocol: 'https', hostname: 'cdn.example.com', pathname: '/uploads/**' }],
    minimumCacheTTL: 2678400,                 // 31 days for remote images; no purge mechanism, so version URLs
    // dangerouslyAllowSVG: false (default) — keep it off unless you set a strict CSP
  },
};
export default nextConfig;
```

### next/image usage table
| Situation | Props |
|---|---|
| LCP hero | `loading="eager"` `fetchPriority="high"` `sizes` (static import for blur) |
| Regular content image | default lazy; `width`/`height` or static import; `sizes` if responsive |
| Unknown aspect in a card | `fill` + parent `relative aspect-[4/3]` + `sizes` + `object-cover` |
| External CDN already optimizes | custom `loader` (Cloudinary/imgix) or `unoptimized` |
| Art direction (different crops) | `getImageProps()` + `<picture>` |
| Tiny avatars | set exact `width`/`height`; ensure a small width is generated (`images.imageSizes`) |

### Art direction with getImageProps
```tsx
import { getImageProps } from 'next/image';

export function Banner() {
  const common = { alt: 'Autumn collection', sizes: '100vw' };
  const { props: { srcSet: desktop } } = getImageProps({ ...common, src: '/banner-wide.jpg', width: 1920, height: 640, quality: 75 });
  const { props: { srcSet: mobile, ...rest } } = getImageProps({ ...common, src: '/banner-tall.jpg', width: 750, height: 1000, quality: 75 });
  return (
    <picture>
      <source media="(min-width: 768px)" srcSet={desktop} />
      <source media="(max-width: 767px)" srcSet={mobile} />
      <img {...rest} style={{ width: '100%', height: 'auto' }} />
    </picture>
  );
}
```

### Vite SPA with an image CDN
```tsx
// @unpic/react detects many CDNs and builds srcset/sizes; or hand-roll as below
type Props = { src: string; alt: string; width: number; height: number; sizes: string; priority?: boolean };
const widths = [320, 640, 960, 1280, 1920];

export function CdnImage({ src, alt, width, height, sizes, priority }: Props) {
  const url = (w: number) => `https://img.example.com/${src}?w=${w}&auto=format&q=70`;
  return (
    <img
      src={url(Math.min(width, 1280))}
      srcSet={widths.filter((w) => w <= width * 2).map((w) => `${url(w)} ${w}w`).join(', ')}
      sizes={sizes}
      width={width}
      height={height}
      alt={alt}
      loading={priority ? 'eager' : 'lazy'}
      fetchPriority={priority ? 'high' : 'auto'}
      decoding="async"
    />
  );
}
```
Build-time local assets in Vite: `vite-imagetools` (`import hero from './hero.jpg?w=640;1280&format=avif;webp&as=picture'`).

## Recommended Workflow
1. Inventory: Lighthouse "Improve image delivery" insight + Network panel sorted by size; flag images > 100 KB and those rendered much smaller than intrinsic.
2. Identify the LCP image per template/breakpoint; apply priority props.
3. Configure formats/CDN; set `sizes` from CSS layout; add dimensions everywhere.
4. Lazy-load below the fold; convert GIFs to video; SVGs through SVGO.
5. Verify: DevTools Network shows AVIF/WebP, transferred width ≈ rendered × DPR; CLS unchanged; LCP improved.
6. Guard: Lighthouse CI byte-weight budgets; lint rule forbidding raw `<img>` in Next.js (`@next/next/no-img-element`) except justified cases.

## Patterns
- **Upload pipeline**: store original → CDN transforms on request (format auto, width param) → immutable cache.
- **Blur-up placeholder**: `placeholder="blur"` (static imports auto-generate `blurDataURL`), or dominant color background.
- **Responsive sizes helper**: centralize `sizes` strings per layout component (card grid, hero, sidebar).
- **Video instead of GIF** with `poster` image sized like the video.

## Anti-Patterns
- **`sizes` omitted with `fill`** → Next assumes 100vw → huge downloads in grids. Fix: accurate `sizes`.
- **Lazy LCP image** (next/image default lazy on the hero). Fix: `loading="eager"` + `fetchPriority="high"`.
- **`unoptimized` everywhere to "fix" build/runtime cost**. Fix: use a loader for an external CDN or cache optimizations properly.
- **Unrestricted `remotePatterns` (`hostname: '**'`)** → your server becomes an open image proxy. Fix: explicit hosts/paths.
- **Serving 4000px originals from CMS**. Fix: CDN width transforms / upload limits.
- **`dangerouslyAllowSVG: true` without CSP/`contentDispositionType: 'attachment'`** → XSS vector. Fix: serve SVGs as static files or sanitize.

## Accessibility
- Meaningful `alt` for content images; `alt=""` for decorative (next/image requires `alt`).
- Don't embed text in images (SC 1.4.5); if unavoidable, replicate in alt.
- Placeholders/blur must not be the only visual for extended periods on slow networks without alt available.
- Animated media: respect `prefers-reduced-motion`; provide pause for > 5 s motion (SC 2.2.2).

## Responsive Design
- `sizes` per breakpoint mirrors grid columns: e.g., `(min-width:1280px) 25vw, (min-width:768px) 33vw, 50vw`.
- Art direction (different crops) uses `<picture>` + `media`; resolution switching uses `srcset` + `sizes`.
- `sizes="auto"` (with `loading="lazy"`) lets Chromium compute sizes from layout; not universal—keep explicit `sizes` as fallback.

## Performance
- `fetchPriority` Baseline; native lazy loading Baseline; AVIF/WebP supported in all current major browsers.
- next/image optimization runs on the server: self-hosted deployments need adequate CPU/memory and a persistent cache (`<distDir>/cache/images`) or an external loader.
- Multiple formats multiply cache storage; limit `qualities`, `deviceSizes`, `imageSizes` to what you use.

## Security
- Restrict `remotePatterns`/`localPatterns`; Next 16 requires `qualities` allowlist to prevent resource abuse.
- Keep `dangerouslyAllowSVG` off; SVG can contain scripts.
- Strip EXIF (GPS) from user uploads.
- Validate upload MIME/type server-side; don't trust extensions ([file-upload](../file-upload/Skill.md)).

## Testing
- Lighthouse CI: image-related insights, `total-byte-weight`, LCP assertions.
- Playwright: check `currentSrc` width vs `clientWidth × devicePixelRatio` for key images at several viewports.
- Visual regression at multiple DPRs for quality regressions.

## Tooling
- `next/image` (Next.js 16: `preload` prop added, `priority` deprecated, `qualities` required default `[75]`) — Active.
- `@unpic/react` — Active (multi-CDN responsive images).
- `vite-imagetools` — Active (build-time transforms in Vite).
- Sharp / Squoosh CLI (Squoosh CLI unmaintained—prefer Sharp) — Sharp Active.
- Image CDNs: Cloudinary, imgix, Cloudflare Images, Vercel Image Optimization, Netlify Image CDN.
- SVGO — Active.

## Framework Notes
- **Next.js**: always `next/image` (lint rule `@next/next/no-img-element`); static imports give dimensions + blur + immutable caching; remote images need `remotePatterns`; LCP → eager + high priority; use a custom loader when a CDN does transforms. Deeper config: [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md).
- **React (Vite SPA)**: no built-in optimizer—use an image CDN (`@unpic/react`) or `vite-imagetools`; enforce width/height via a shared `<CdnImage>` component and lint against raw `<img>` in app code.

## AI Agent Guidance
- Do: use `next/image` in Next.js with correct `sizes`; add eager/high priority only to the verified LCP image.
- Do: configure `formats: ['image/avif','image/webp']` and restrictive `remotePatterns`.
- Don't: set `unoptimized`, `dangerouslyAllowSVG`, or wildcard remote hosts without explicit instruction.
- Don't: use the deprecated `priority` prop in Next 16+.
- Before declaring done: served format is AVIF/WebP, transferred dimensions match rendered × DPR, no CLS, alt text present, LCP not lazy.

## Examples
```tsx
// Product grid card (Next.js)
import Image from 'next/image';

export function ProductCard({ p }: { p: { name: string; imageUrl: string } }) {
  return (
    <article>
      <div className="relative aspect-square overflow-hidden rounded-lg">
        <Image
          src={p.imageUrl}
          alt={p.name}
          fill
          sizes="(min-width: 1280px) 25vw, (min-width: 768px) 33vw, 50vw"
          className="object-cover"
        />
      </div>
      <h3>{p.name}</h3>
    </article>
  );
}
```

```tsx
// GIF replacement
<video autoPlay muted loop playsInline width={640} height={360} poster="/demo-poster.webp" aria-label="Demo of drag to reorder">
  <source src="/demo.webm" type="video/webm" />
  <source src="/demo.mp4" type="video/mp4" />
</video>
```

## Related Skills
- [lcp-optimization](../lcp-optimization/Skill.md) — hero image priority
- [cls-prevention](../cls-prevention/Skill.md) — dimensions and aspect ratios
- [responsive-images-and-media](../responsive-images-and-media/Skill.md) — srcset/sizes/picture fundamentals
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — next/image deep dive
- [accessible-images-and-media](../accessible-images-and-media/Skill.md) — alt text and media a11y
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) — image caching
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — lazy loading strategy

## Sources
- [Next.js Image Component API](https://nextjs.org/docs/app/api-reference/components/image) — Official — props, `preload`/`priority` deprecation, `qualities`, `formats`, `minimumCacheTTL`, getImageProps (docs v16.3.5)
- [MDN: Image file type and format guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types) — Official — AVIF/WebP/JPEG XL support
- [web.dev: Optimize LCP](https://web.dev/articles/optimize-lcp) — Official — priority and discovery
- [web.dev: Browser-level lazy loading](https://web.dev/articles/browser-level-image-lazy-loading) — Official — lazy loading behavior
- [unpic](https://unpic.pics/) — Open Source — CDN-aware responsive image components
- [Jake Archibald: Squoosh / image compression talks](https://jakearchibald.com/) — Community — format/quality trade-offs

## License / Usage Notes
Summarized from docs (MIT/CC). Examples original.

## Quality Tier
A — Verified against Next.js 16.3 docs and MDN; quality values are heuristic starting points.

## Status
Active

## Last Verified
2026-09-15
