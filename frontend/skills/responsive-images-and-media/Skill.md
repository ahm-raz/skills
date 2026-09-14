# Responsive Images and Media

## Summary
How to deliver images and video that look sharp, load fast, and don't shift layout on every screen. It covers `srcset`/`sizes`, `<picture>` art direction and format fallback, AVIF/WebP, `loading`/`fetchpriority`/`decoding`, `aspect-ratio` and intrinsic dimensions, `object-fit`, and responsive video (`preload`, poster, lazy loading of media, which shipped in Chrome 148). The Next.js 16 `next/image` specifics are included: `preload` replaces the deprecated `priority`, `qualities` is now required with a default of `[75]`, and `getImageProps` covers art direction.

## Category
CSS & Styling

## Subcategories
srcset, sizes, picture, art direction, AVIF, WebP, next/image, getImageProps, LCP images, lazy loading, fetchpriority, aspect-ratio, object-fit, image-set(), responsive video, sizes="auto"

## Problem It Solves
Oversized images waste bandwidth and slow LCP. Missing dimensions cause CLS. Wrong `sizes` values make browsers download desktop images on phones. Lazy-loading the hero delays LCP. Using the wrong Next.js props (`priority` in v16, unlisted `quality`) causes regressions and warnings.

## When To Use
- Any content image, hero, avatar, product image, background image or video in a React/Next.js app.
- Debugging LCP/CLS related to media.
- Setting up `next.config` image optimization.

## When Not To Use
- Icons: use inline SVG or icon components (see iconography-and-illustration).
- Deep CDN/image pipeline tuning. See image-optimization.
- Alt text writing and media accessibility depth. See accessible-images-and-media.

## Core Principles
1. **Always reserve space.** Provide `width` and `height` (or `aspect-ratio`) so the browser computes the box before load (CLS).
2. **`sizes` must describe the rendered width.** Without `sizes`, `srcset` `w` descriptors assume `100vw`, which downloads oversized images for narrow slots.
3. **Prioritize the LCP image and lazy-load the rest.** Hero: `fetchpriority="high"` + eager (never lazy). Below the fold: `loading="lazy"`.
4. **Modern formats with fallback.** AVIF (Baseline since 2024) and WebP, negotiated via `Accept` (next/image or CDN) or `<picture>` sources.
5. **Art direction uses `<picture>` + `media`**, resolution switching uses `srcset` + `sizes`. They are different problems.
6. **Serve media from an optimizer/CDN**, not raw originals.

## Best Practices
- Write `sizes` from your CSS layout: `(min-width: 80rem) 25rem, (min-width: 48rem) 33vw, 100vw`. Update it when the layout changes.
- `sizes="auto"` (with `loading="lazy"`) lets the browser use the laid-out width. Chrome 126+ and Firefox 150 support it, Safari doesn't. Use `sizes="auto, (min-width: 48rem) 33vw, 100vw"` so unsupported browsers fall back.
- Use `fetchpriority="high"` on only one or two LCP candidates per page.
- `decoding="async"` for non-critical images. It's the default behavior in most engines anyway, so don't overthink it.
- For images covering a box: `object-fit: cover` + `object-position`, with a fixed `aspect-ratio` container.
- Use responsive CSS backgrounds sparingly (they're not discoverable early and have no alt). Prefer `<img>` with `object-fit`. If you need backgrounds, use `image-set()`.
- Blur/LQIP placeholders only when they improve perceived performance. Keep them tiny (next/image `placeholder="blur"` with static imports).
- Video: `preload="none"` or `"metadata"`, a `poster` image sized like the video, `playsinline muted` for autoplay loops, and `loading="lazy"` on `<video>` where supported (Chrome 148, progressive enhancement). Provide captions (`<track kind="captions">`).
- Replace animated GIFs with `<video autoplay loop muted playsinline>` (MP4/WebM), which is much smaller.
- Crop avatars/thumbnails at the source or optimizer, not only with CSS.

## Implementation Guidance

### Decision table
| Case | Markup |
|---|---|
| Same image, various sizes | `<img srcset="… 480w, … 960w, … 1440w" sizes="…">` / `next/image` with `sizes` |
| Fixed-size (avatar, logo) | `srcset` with `x` descriptors (`1x, 2x`) / `next/image` width+height, no `sizes` |
| Different crop per breakpoint | `<picture><source media="(min-width: 64rem)" srcset>…<img></picture>` / `getImageProps` |
| Format fallback without optimizer | `<picture><source type="image/avif"><source type="image/webp"><img src=jpg>` |
| Theme-dependent image | `<picture><source media="(prefers-color-scheme: dark)">` (system) or two lazy images toggled by CSS (manual theme) |
| Fill parent of unknown size | `next/image fill` + `sizes` + parent `position: relative` + aspect ratio |
| Decorative background | CSS `image-set()` (next: `getImageProps` → image-set string) |

### next/image (Next.js 16.x) essentials
| Prop / config | Notes |
|---|---|
| `src`, `alt` | Required. Static import gives automatic width/height + blur data |
| `width`/`height` or `fill` | Required unless static import |
| `sizes` | Required for responsive/`fill` images, otherwise srcset uses only 1x/2x |
| `preload` | New in v16. Inserts `<link rel=preload>` in `<head>`. Use for a single clear LCP hero. Don't combine with `loading`/`fetchPriority` |
| `priority` | **Deprecated in v16** in favor of `preload` |
| `loading="eager"` / `fetchPriority="high"` | Docs recommend these over `preload` in most cases |
| `quality` | Must be in `images.qualities`. **Required config since v16, default `[75]`**. Other values are coerced to the nearest allowed value |
| `placeholder="blur"` | Automatic for static imports; `blurDataURL` for remote |
| `overrideSrc`, `decoding`, `unoptimized` | Available |
| `images.formats` | Default WebP; `['image/avif', 'image/webp']` to prefer AVIF (caches each format separately) |
| `images.remotePatterns` / `localPatterns` | Allow-list sources (security) |
| `images.minimumCacheTTL` | Default 4 hours (14400s) in current docs. Raise it for stable remote images |
| `images.deviceSizes` / `imageSizes` | Defaults `[640, 750, 828, 1080, 1200, 1920, 2048, 3840]` / `[32, 48, 64, 96, 128, 256, 384]` |
| `maximumRedirects`, `dangerouslyAllowLocalIP` | v16 security-related config |
| `getImageProps()` | Returns `<img>` props for `<picture>` art direction, backgrounds, canvas |

## Recommended Workflow
1. Identify the LCP image per template (Lighthouse / Chrome DevTools Performance LCP marker) at mobile and desktop.
2. For each image, pick the markup case from the decision table.
3. Write `sizes` from the CSS grid/columns at each breakpoint.
4. Set dimensions/aspect ratio, and add `object-fit` if cropping.
5. Prioritize the LCP image and lazy-load everything else.
6. Configure `next.config` `images` (formats, qualities, remotePatterns).
7. Verify in DevTools Network that the downloaded width is close to rendered width × DPR, and check CLS = 0 for images.

## Patterns
**Card grid image with accurate sizes**
```tsx
import Image from "next/image";
<div className="relative aspect-[4/3] overflow-hidden rounded-lg">
  <Image src={p.image} alt={p.alt} fill className="object-cover"
         sizes="(min-width: 80rem) 20rem, (min-width: 48rem) calc((100vw - 6rem) / 3), calc(100vw - 2rem)" />
</div>
```

**LCP hero (Server Component)**
```tsx
import Image from "next/image";
import hero from "@/public/hero.jpg"; // static import: dimensions + blur
<Image src={hero} alt="Team collaborating in the studio" placeholder="blur" fetchPriority="high" loading="eager"
       sizes="100vw" className="h-auto w-full" />
```

**Plain HTML resolution switching with sizes="auto" enhancement**
```tsx
<img
  src="/img/shoe-800.avif"
  srcSet="/img/shoe-400.avif 400w, /img/shoe-800.avif 800w, /img/shoe-1200.avif 1200w"
  sizes="auto, (min-width: 48rem) 33vw, 100vw"
  loading="lazy" decoding="async" width={1200} height={900} alt="Red running shoe, side view"
/>
```

**Lightweight looping video instead of GIF**
```tsx
<video autoPlay loop muted playsInline preload="metadata" poster="/demo-poster.webp" width={960} height={540} className="h-auto w-full">
  <source src="/demo.webm" type="video/webm" />
  <source src="/demo.mp4" type="video/mp4" />
</video>
```

**Responsive video iframe (YouTube etc.)**
```css
.embed { aspect-ratio: 16 / 9; inline-size: 100%; border: 0; }
```

## Anti-Patterns
- **`loading="lazy"` on the hero/LCP image.** Delays LCP. Use eager + `fetchPriority="high"`.
- **`priority` prop in Next.js 16.** Deprecated. Use `preload` (single clear LCP) or `fetchPriority="high"`/`loading="eager"`.
- **`fill` / responsive `next/image` without `sizes`.** Downloads up to the largest device size. Add `sizes`.
- **`quality={90}` without adding 90 to `images.qualities`.** Coerced to 75 with a dev warning. Configure qualities.
- **Missing width/height (or aspect-ratio).** CLS. Always reserve space.
- **Preloading multiple viewport-dependent LCP candidates.** Wasted bytes. Use `fetchPriority` or `<picture>` with media + `getImageProps`.
- **`<picture>` for simple resolution switching.** Verbose. `srcset` + `sizes`.
- **CSS `display:none` on a large eager image for mobile.** It still downloads. Use `<picture>` media sources or lazy loading.
- **`unoptimized` everywhere to "fix" remote image errors.** Loses optimization. Configure `remotePatterns`.
- **Autoplaying video with sound, or without pause control.** Accessibility failure (WCAG 1.4.2, 2.2.2). Muted plus controls/pause.
- **Animated GIFs for demos.** Huge files. Use video.

## Accessibility
- Meaningful `alt` for informative images; `alt=""` for decorative (WCAG 1.1.1). Art-directed variants share one `alt` describing the content.
- Text in images must be avoided or duplicated as real text (1.4.5).
- Video: captions (1.2.2), audio description where needed (1.2.5), pause/stop for motion over 5s (2.2.2), no auto-playing audio (1.4.2).
- Respect `prefers-reduced-motion` for autoplaying decorative video: don't autoplay, or show the poster instead.
- Images of charts need text alternatives or data tables.

## Responsive Design
- `sizes` must mirror breakpoints and container widths. When components live in containers of varying width, `sizes="auto"` (lazy images) helps where supported; otherwise use conservative `sizes` per slot and pass `sizes` as a component prop.
- Use `aspect-ratio` + `object-fit` to adapt crops across breakpoints; use `<picture>` when the subject would be lost.
- Use `image-set()` for resolution-aware CSS backgrounds.

## Performance
- LCP: discoverable in initial HTML (Server Components render `<img>` directly), high priority, correctly sized, AVIF/WebP, served from the same origin or preconnected CDN.
- CLS: dimensions/aspect ratio always.
- Use lazy loading for below-the-fold images, iframes (`loading="lazy"`), and video (Chrome 148+).
- Static imports in Next.js get content-hashed, immutable caching. Remote images depend on `minimumCacheTTL` and upstream headers.
- AVIF encodes slower (first-request latency on on-demand optimizers) and gives smaller files. Consider prebuilt variants or CDN optimization for large catalogs.

## Security
- Next.js `remotePatterns`/`localPatterns` allow-lists prevent your optimizer from being abused as an open proxy. Keep patterns specific (protocol, hostname, pathname).
- `qualities` allow-list (required in v16) limits resource-exhaustion attacks.
- Don't enable `dangerouslyAllowSVG` for user-uploaded SVGs (script injection). If needed, combine with `contentDispositionType: "attachment"` and a restrictive `contentSecurityPolicy`.
- `dangerouslyAllowLocalIP` should stay false in production (SSRF risk).
- Strip EXIF metadata (GPS) from user uploads before serving.

## Testing
- Lighthouse / PageSpeed: "Properly size images", "Serve images in next-gen formats", LCP element, "Largest Contentful Paint image was lazily loaded".
- Playwright: assert LCP image has `fetchpriority="high"` and no `loading="lazy"`; assert all `<img>` have width/height or are inside aspect-ratio containers.
- DevTools Network: compare intrinsic vs rendered size (hover image in Elements panel).
- Visual regression for crops at breakpoints.
- RUM (web-vitals attribution) to confirm field LCP improvements.

## Tooling
- `next/image` (Next.js 16.x). Official.
- Unpic (`@unpic/react`). Community CDN-aware image component for Vite SPAs.
- sharp / Squoosh CLI / `vite-imagetools`. Build-time resizing and formats.
- Image CDNs (Cloudinary, imgix, Vercel Image Optimization, Cloudflare Images).
- `web-vitals` library with attribution build.
- Deprecated: `next/legacy/image`, `images.domains` (use `remotePatterns`), `onLoadingComplete` (use `onLoad`), `priority` (v16).

## Framework Notes
- **Next.js App Router (16.x):** `next/image` works in Server Components (no client JS for basic usage). Use static imports for local assets (auto dimensions/blur). Configure `images` in `next.config.ts`: `formats`, `qualities`, `remotePatterns`, and `localPatterns` if you use query strings on local images. For art direction or theme images, use `getImageProps()` to build `<picture>`, or render two lazy `<Image>`s toggled by CSS. In that case avoid `preload`/`eager`, which would load both. For OG images, use `next/og` `ImageResponse` (separate concern).
- **React (Vite SPA):** no built-in optimizer. Use build-time variants (`vite-imagetools`: `import srcset from "./hero.jpg?w=480;960;1440&format=avif;webp&as=srcset"`) or an image CDN with Unpic. Put the LCP image in the initial HTML if possible (SPA LCP often suffers because images are discovered after JS runs; consider `<link rel="preload" as="image" imagesrcset imagesizes>` in `index.html` for a known hero).

## AI Agent Guidance
- Do give every image dimensions (or `fill` + sized parent) and a correct `sizes` derived from the layout.
- Do mark exactly the LCP image as high priority. In Next.js 16, use `preload` or `fetchPriority="high"`, never `priority`.
- Do check `images.qualities` before using a non-75 `quality`, and `remotePatterns` for remote hosts.
- Don't lazy-load above-the-fold images; don't hide heavy images with CSS; don't use GIFs for animation.
- Before done: Lighthouse on mobile shows no image-size/format warnings, the LCP image isn't lazy, CLS from images is 0, and there are no `next/image` console warnings.

## Examples
```ts
// next.config.ts
import type { NextConfig } from "next";

const config: NextConfig = {
  images: {
    formats: ["image/avif", "image/webp"],
    qualities: [60, 75, 85],
    remotePatterns: [new URL("https://cdn.example.com/products/**")],
    minimumCacheTTL: 60 * 60 * 24 * 7,
  },
};
export default config;
```
```tsx
// app/components/ArtDirectedHero.tsx — Server Component
import { getImageProps } from "next/image";

export function ArtDirectedHero() {
  const common = { alt: "Mountain cabin at sunrise", sizes: "100vw", quality: 75 };
  const { props: { srcSet: desktop } } = getImageProps({ ...common, src: "/hero-wide.jpg", width: 1920, height: 800 });
  const { props: { srcSet: mobile, ...rest } } = getImageProps({ ...common, src: "/hero-tall.jpg", width: 828, height: 1100 });

  return (
    <picture>
      <source media="(min-width: 48rem)" srcSet={desktop} />
      <source srcSet={mobile} />
      <img {...rest} fetchPriority="high" className="h-auto w-full object-cover" />
    </picture>
  );
}
```
```tsx
// app/products/ProductGallery.tsx
import Image from "next/image";

type Product = { id: string; image: string; alt: string };

export function ProductGallery({ products }: { products: Product[] }) {
  return (
    <ul className="grid grid-cols-[repeat(auto-fill,minmax(min(100%,15rem),1fr))] gap-4">
      {products.map((p, i) => (
        <li key={p.id} className="relative aspect-square overflow-hidden rounded-lg bg-surface-2">
          <Image
            src={p.image} alt={p.alt} fill className="object-cover"
            sizes="(min-width: 80rem) 18rem, (min-width: 40rem) 45vw, 100vw"
            {...(i < 2 ? { fetchPriority: "high" as const, loading: "eager" as const } : {})}
          />
        </li>
      ))}
    </ul>
  );
}
```

## Related Skills
- [image-optimization](../image-optimization/Skill.md) — pipelines, CDNs, formats in depth
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — next/image and next/font setup
- [lcp-optimization](../lcp-optimization/Skill.md) — LCP image prioritization
- [cls-prevention](../cls-prevention/Skill.md) — reserving space
- [accessible-images-and-media](../accessible-images-and-media/Skill.md) — alt text, captions
- [responsive-design](../responsive-design/Skill.md) — breakpoints that drive `sizes`
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — theme-dependent images

## Sources
- [Next.js — Image component API reference (v16.3.5 docs)](https://nextjs.org/docs/app/api-reference/components/image) — Official — props, preload vs priority deprecation, qualities default, config, getImageProps, version history
- [MDN — Responsive images](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Structuring_content/HTML_images#responsive_images) — Official — srcset/sizes, art direction
- [web.dev — Browser-level image lazy loading](https://web.dev/articles/browser-level-image-lazy-loading) — Official — lazy loading behavior
- [web-features explorer — sizes="auto"](https://web-platform-dx.github.io/web-features-explorer/features/sizes-auto/) — Official — support (Chrome 126, Firefox 150, no Safari)
- [web.dev — New to the web platform in May 2026](https://web.dev/blog/web-platform-05-2026) — Official — lazy loading for video/audio in Chrome 148
- [web.dev — Optimize LCP / fetchpriority](https://web.dev/articles/fetch-priority) — Official — priority hints
- [MDN — image-set()](https://developer.mozilla.org/en-US/docs/Web/CSS/image/image-set) — Official — CSS backgrounds

## License / Usage Notes
Next.js docs are MIT, MDN is CC-BY-SA, and web.dev is CC-BY 4.0. Content is summarized. Examples are original, with the art-direction approach adapted from the documented `getImageProps` API.

## Quality Tier
S — Verified against the current Next.js 16.3.5 image API (including v16 breaking changes) plus fresh browser support data.

## Status
Active

## Last Verified
2026-09-15
