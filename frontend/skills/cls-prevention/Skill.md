# CLS Prevention

## Summary
Cumulative Layout Shift (CLS) measures unexpected movement of visible content. It's the largest burst ("session window") of layout-shift scores over the page's lifetime. Each shift's score is impact fraction × distance fraction. Shifts within 500 ms of user input are excluded. The goal is ≤ 0.1 at p75. Most CLS comes from media without dimensions, late-injected content (ads, banners, embeds), web-font swaps, and animations of layout properties.

## Category
Performance

## Subcategories
Layout Instability API, aspect-ratio, reserved space, font metric overrides, ads and embeds, skeletons, bfcache, animations

## Problem It Solves
Content jumps that make users lose their place or tap the wrong button (for example, "Buy" becoming "Cancel" as a banner loads). It's also a Core Web Vital, so it affects page-experience signals.

## When To Use
- Field CLS above 0.1, or visible jumps during load or scrolling.
- Adding ads, consent banners, embeds, lazy content, infinite scroll, or web fonts.
- Building skeleton or loading states ([loading-states](../loading-states/Skill.md)).

## When Not To Use
- Intentional, user-initiated layout changes (accordion open on click). These are excluded if they start within 500 ms of input.
- Transform-based animations. They don't cause layout shifts.

## Core Principles
1. **Reserve space for everything that arrives later**: images, video, iframes, ads, banners, async components.
2. **Change layout only in response to user input**, or add new content below the viewport.
3. **Animate `transform` and `opacity`, never `top`/`left`/`width`/`height`/`margin`** for movement.
4. **Make font swaps metric-compatible** with fallback overrides, or use `font-display: optional`.
5. **CLS is measured across the whole visit** (session windows: max 1 s gap, max 5 s window). Shifts during scrolling and SPA updates count too, not just the initial load.

## Best Practices
- Always set `width` and `height` attributes on `<img>`/`<video>`. Modern browsers derive `aspect-ratio` from them. Add CSS `height: auto` for responsive scaling.
- Use CSS `aspect-ratio` for iframes, embeds and responsive containers.
- Ad slots: set `min-height` to the most likely creative size (per breakpoint). Don't collapse an empty slot after it rendered.
- Cookie and consent banners: overlay them (`position: fixed` at the bottom). Don't push content down from the top.
- Skeletons must match final dimensions. A 40 px skeleton replaced by 120 px content still shifts.
- Load fonts with `size-adjust`/`ascent-override`/`descent-override`/`line-gap-override` on a local fallback, or use framework tooling that generates them.
- Insert new feed items above the viewport only with scroll anchoring (`overflow-anchor` default `auto`), or show a "N new items" button.
- Keep pages bfcache-eligible. A restored page has no load shift ([back-forward-cache](../back-forward-cache/Skill.md)).
- Prefer `content-visibility: auto` only with `contain-intrinsic-size: auto <estimate>` to avoid scrollbar and position jumps.

## Implementation Guidance

### Cause → fix table
| Cause | Detection clue | Fix |
|---|---|---|
| Image/video without dimensions | Shift source is the element below the media | `width`/`height` attrs + `height:auto` |
| Late ad/embed | Shift at ad load time; source `div` below the slot | Reserved `min-height`, placeholder, avoid collapsing |
| Banner inserted at top | Whole page shifts down | Fixed overlay or reserved space in SSR |
| Web font swap | Text blocks reflow ~FCP+font load | Metric-override fallback, `font-display: optional`, preload font |
| Async component (reviews, recommendations) | Shift after API response | Skeleton with same height, render below the fold, or SSR |
| Layout-property animation | Repeated small shifts | `transform: translate()` / `scale()` |
| Hydration mismatch rendering different content | Shift right after JS loads | Fix SSR/CSR parity; don't render client-only content in place without reserving space |
| Infinite scroll/"load more" footer | Footer jumps | Place footer outside the growing list or reserve loader space |

### Media and embeds (TSX)
```tsx
import Image from 'next/image';

export function ProductMedia({ src, w, h, videoId }: { src: string; w: number; h: number; videoId: string }) {
  return (
    <>
      {/* Known intrinsic size: width/height reserve the aspect ratio */}
      <Image src={src} width={w} height={h} alt="Product photo" sizes="(min-width: 768px) 50vw, 100vw" />

      {/* Unknown size: fill inside a sized, positioned parent */}
      <div className="relative aspect-[4/3]">
        <Image src={src} fill alt="" sizes="(min-width: 768px) 33vw, 100vw" className="object-cover" />
      </div>

      {/* Embed: aspect-ratio box */}
      <div className="aspect-video w-full">
        <iframe className="h-full w-full border-0" src={`https://www.youtube-nocookie.com/embed/${videoId}`}
                title="Product demo video" loading="lazy" allowFullScreen />
      </div>

      {/* Ad slot: reserve per breakpoint (Tailwind) */}
      <div className="min-h-[250px] md:min-h-[90px]" data-ad-slot="pdp-1" />
    </>
  );
}
```
In a Vite SPA without `next/image`, a plain `<img width={w} height={h} style={{ height: 'auto', maxWidth: '100%' }}>` does the same job.

### Font fallback metrics
```css
@font-face {
  font-family: "Inter Fallback";
  src: local("Arial");
  size-adjust: 107%;
  ascent-override: 90%;
  descent-override: 22%;
  line-gap-override: 0%;
}
body { font-family: "Inter", "Inter Fallback", system-ui, sans-serif; }
```
Generate values with tooling (Next.js `next/font`, `fontaine`, Capsize) rather than guessing.

### Finding the shifting element
```js
new PerformanceObserver((list) => {
  for (const e of list.getEntries()) {
    if (e.hadRecentInput) continue;
    for (const s of e.sources ?? []) {
      console.log(e.value.toFixed(4), s.node, s.previousRect, s.currentRect);
    }
  }
}).observe({ type: 'layout-shift', buffered: true });
```
Use web-vitals `onCLS` attribution in the field: `largestShiftTarget`, `largestShiftTime`, `loadState`.

## Recommended Workflow
1. Check field CLS and attribution: which element moves, when (`loadState`: loading / dom-interactive / complete), and on which template.
2. Reproduce with DevTools Performance panel, using the Layout shifts track and "Layout shift culprits" insight. Enable the Rendering → "Layout Shift Regions" overlay.
3. Test after load too: scroll, open the consent banner, wait for ads, navigate within the SPA.
4. Apply the fix from the table. Retest on narrow and wide viewports.
5. Add a Lighthouse CI assertion (`cumulative-layout-shift` ≤ 0.1) and a visual regression check for reserved slots.

## Patterns
- **Reserve-then-fill**: container with fixed or aspect-ratio size, content fades in with opacity.
- **Overlay UI**: toasts, banners, chat launchers are `position: fixed` and never push layout.
- **User-triggered expansion**: expand on click, which is excluded from CLS.
- **Transform animations**: animate `translate`, `scale` and `opacity`; use FLIP for layout changes ([layout-animations](../layout-animations/Skill.md)).
- **"New content" pill**: in live feeds, add items only when the user asks.

## Anti-Patterns
- **Dimensionless images from a CMS.** Fix: store intrinsic dimensions at upload time and render the attributes.
- **Collapsing an ad slot on no-fill.** Fix: keep the space or show a house ad or placeholder.
- **Top-inserted promo banner after hydration.** Fix: render it in SSR or overlay it.
- **Skeleton height mismatch.** Fix: measure final component heights per breakpoint.
- **Animating `height` for expanders on load.** Fix: `grid-template-rows: 0fr → 1fr` only on user input, or use `transform`.
- **`font-display: swap` with a wildly different fallback.** Fix: metric overrides or `optional`.

## Accessibility
- Stable layouts support WCAG 2.2 SC 2.5.x (pointer accuracy) in practice and reduce disorientation for screen-magnifier users.
- Overlays such as consent banners must remain keyboard-accessible and must not trap or hide focus (SC 2.4.11 Focus Not Obscured).
- Respect `prefers-reduced-motion` for reveal animations used to mask content arrival.

## Responsive Design
- Reserve space per breakpoint. Ad sizes and hero aspect ratios differ between mobile and desktop.
- Text wrapping at narrow widths makes font-swap shifts larger. Test at 320–390 px.
- Container queries changing layout after async data can shift. Reserve the container size.

## Performance
- Reserving space has essentially no cost. Metric-override fallbacks avoid needing `font-display: block`.
- `content-visibility` plus a good `contain-intrinsic-size` improves rendering without shifts. Bad estimates cause scrollbar jumps (not counted as CLS, but disruptive).

## Security
- Ad and embed iframes: sandbox where possible. Don't let third-party scripts resize containers arbitrarily; fix the container size in CSS.

## Testing
- Lighthouse CI CLS assertion (lab covers load only; post-load shifts need scripted user flows).
- Playwright: scroll through the page, then read CLS via web-vitals `onCLS` with `reportAllChanges` and assert ≤ 0.1.
- Visual regression screenshots at load milestones for templates with ads or banners ([visual-regression-testing](../visual-regression-testing/Skill.md)).

## Tooling
- Chrome DevTools: Layout shifts track, "Layout shift culprits" insight, Rendering → Layout Shift Regions. Active.
- web-vitals `onCLS` attribution (Chromium-only API). Active.
- Font fallback generators: `next/font` (built-in), `fontaine` (unjs), Capsize. Active.
- WebPageTest filmstrip with layout-shift highlighting.

## Framework Notes
- **React (Vite SPA)**: everything renders client-side, so every data-dependent block is a potential shift. Suspense fallbacks and TanStack Query loading states must be size-matched skeletons. Use `fontaine` (Vite plugin) or Capsize to generate fallback font metrics. Plain `<img>` needs explicit `width`/`height` (store them with your image metadata).
- **Next.js**: `next/image` requires `width`/`height` (static imports infer them) or `fill` inside a positioned, sized parent (`position: relative` plus `aspect-ratio`). `next/font` self-hosts and sets `adjustFontFallback` by default, generating a metric-matched fallback. `loading.tsx` and `<Suspense>` fallbacks must reserve the final height, or streamed content will push the layout. Avoid rendering client-only UI in place (`useEffect(() => setMounted(true))` patterns) without reserved space. Hydration mismatches that re-render different markup also cause shifts. See [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) and [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md).

## AI Agent Guidance
- Do: add `width`/`height` to every `<img>` you create. Use `aspect-ratio` for embeds.
- Do: implement banners and toasts as overlays.
- Do: measure CLS after scrolling and interaction, not just at load.
- Don't: animate layout properties for entrances, or insert content above the current scroll position without user action.
- Don't: guess font override percentages; use a generator.
- Before declaring done: DevTools shows no layout-shift clusters > 0.05 on load and during scroll at mobile width, and Lighthouse CLS ≤ 0.1.

## Examples
```css
/* Accordion expand without layout-property keyframes on load */
.panel { display: grid; grid-template-rows: 0fr; transition: grid-template-rows .2s; }
.panel[data-open="true"] { grid-template-rows: 1fr; }   /* toggled only on click */
.panel > div { overflow: hidden; }
@media (prefers-reduced-motion: reduce) { .panel { transition: none; } }
```

```tsx
// Size-matched skeleton for async reviews (Next.js App Router server component)
export function Reviews() {
  return (
    <Suspense fallback={<div className="reviews" style={{ minHeight: 480 }} aria-busy="true" />}>
      <ReviewList />
    </Suspense>
  );
}
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md) — metric definitions
- [font-loading-performance](../font-loading-performance/Skill.md) — font swap shifts
- [image-optimization](../image-optimization/Skill.md) — dimensions and aspect ratios
- [third-party-script-management](../third-party-script-management/Skill.md) — ads and embeds
- [loading-states](../loading-states/Skill.md) — skeleton design
- [layout-animations](../layout-animations/Skill.md) — FLIP and transform-based motion
- [back-forward-cache](../back-forward-cache/Skill.md) — shift-free back navigations

## Sources
- [Cumulative Layout Shift](https://web.dev/articles/cls) — Official — session windows, input exclusion, thresholds
- [Optimize CLS](https://web.dev/articles/optimize-cls) — Official — causes and fixes
- [Chrome DevTools Performance reference](https://developer.chrome.com/docs/devtools/performance/reference) — Official — layout shift track and insights
- [web-vitals](https://github.com/GoogleChrome/web-vitals) — Open Source — CLS attribution, Chromium-only note, v6.2 bfcache CLS fix
- [font-best-practices](https://web.dev/articles/font-best-practices) — Official — font-display and fallback guidance

## License / Usage Notes
web.dev CC BY 4.0. Summarized, with original examples.

## Quality Tier
S — Official definitions and complete cause/fix mapping, verified against current tools.

## Status
Active

## Last Verified
2026-09-15
