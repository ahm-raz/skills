# Carousels

## Summary
Carousels (sliders, content rails) show a sequence of slides in a constrained area. This skill covers when not to use one (often), the APG carousel pattern (rotation control, slide semantics, live region), NN/g usability rules, WCAG 2.2.2 for auto-rotation, CSS scroll-snap rails and Chromium's experimental `::scroll-button`/`::scroll-marker`, and Embla Carousel in React (v8 stable; v9 with an accessibility plugin in release candidate).

## Category
Components

## Subcategories
Hero carousel, content rail, image gallery, product thumbnails, scroll-snap, auto-rotation, slide pickers

## Problem It Solves
Carousels hide most of their content, auto-rotate before people can read, trap keyboard users in endless controls, announce every slide change, and ship heavy JS and images. Users often scroll past them. When a carousel is justified, it has to be operable, pausable, and fast.

## When To Use
- Browsing a set of similar items where only a subset matters: product image galleries, "Related articles" rails, testimonials.
- Space-constrained contexts (mobile) where horizontal swiping is a familiar affordance.
- Onboarding tours with few steps (consider a stepper).

## When Not To Use
- Hero banners with key messages: use a static hero; carousel frames beyond the first are rarely seen (NN/g).
- More than ~5 frames of important promotional content.
- Content users must compare or read fully: grid or list.
- Auto-rotating anything on mobile (NN/g).
- As a way to avoid prioritizing content.

## Core Principles
1. Prefer no auto-rotation. If you must, stop on hover and on focus, and provide a visible pause/play control (APG, WCAG 2.2.2).
2. Controls are real buttons with names; previous/next plus an optional slide picker; indicate position ("3 of 5").
3. Non-visible slides aren't reachable by Tab or read as current (`inert` on hidden slides for single-slide carousels). Multi-item rails keep all items reachable.
4. Announce slide changes politely only when the user changed them (live region `off` while auto-rotating).
5. Respect `prefers-reduced-motion`: no animated transitions or auto-play.

## Best Practices
- Show partial next slide ("peek") in rails to signal scrollability.
- Controls ≥ 44px on touch, high contrast, never tiny dots only. Numbered or thumbnail pickers work better than dots (NN/g).
- Timing if auto-advancing: long enough to read (NN/g suggests roughly 1s per 3 words plus buffer; 5–7s for short headings).
- Duplicate important carousel content elsewhere on the page.
- Lazy-load offscreen slide images; eagerly load only the first visible slide.
- Keep each slide labelled ("Slide 2 of 5: Winter collection").
- Allow native horizontal scrolling (trackpad, touch, Shift+wheel) in rails; don't hijack vertical scroll.

## Implementation Guidance

### Decision table
| Need | Build | Notes |
|---|---|---|
| Horizontal product/content rail | CSS scroll-snap `<ul>` + prev/next buttons that call `scrollBy` | Works everywhere; minimal JS |
| Same, zero JS progressive enhancement | Add `::scroll-button()` / `::scroll-marker` | Chrome/Edge 135+ only (experimental, not Baseline); feature-detect with `@supports selector(::scroll-button(*))` |
| Single-slide hero/gallery with loop, autoplay, fade, thumbnails | Embla Carousel (`embla-carousel-react`) v8 stable; v9 RC adds `embla-carousel-accessibility` | Headless; you own semantics unless you use the a11y plugin |
| shadcn/ui project | shadcn Carousel (built on Embla) | Add rotation control and slide labels yourself |

### Keyboard
| Key | Behavior |
|---|---|
| Tab | Moves through rotation control (first), prev/next, picker, then the current slide's content |
| Enter/Space | Activate focused control |
| Left/Right Arrow | In a tabbed slide picker (APG tabbed carousel): move between picker tabs |

### Roles and attributes (APG)
| Element | Attributes |
|---|---|
| Container | `<section aria-roledescription="carousel" aria-label="Featured products">` (region) or `role="group"` |
| Slides wrapper | `aria-live="polite"` when not auto-rotating; `aria-live="off"` while rotating; `aria-atomic="false"` |
| Slide | `role="group" aria-roledescription="slide" aria-label="2 of 5"` (or `tabpanel` in tabbed variant) |
| Rotation control | `<button aria-label="Stop automatic slide show">` / "Start automatic slide show" (label changes, not `aria-pressed`) |
| Prev/Next | `<button aria-label="Previous slide">`, `aria-controls` → slides wrapper |
| Picker (tabbed) | `role="tablist"` of `role="tab" aria-selected` controlling slide tabpanels |

`aria-roledescription` should only be used with localized, human-readable values.

## Recommended Workflow
1. Challenge the carousel: would a grid, list, or static hero work better?
2. Choose rail (multi-item scroll-snap) vs single-slide carousel.
3. Decide auto-rotation (default: none). If yes, implement the pause control and the hover/focus stop.
4. Build semantic markup and controls; label slides.
5. Handle images (`next/image`, first slide priority, others lazy, fixed aspect ratio).
6. Add reduced-motion handling.
7. Test keyboard, screen reader announcements, touch swipe, RTL, CLS.

## Patterns

### Scroll-snap rail with buttons (React)
```tsx
'use client';
import { useRef } from 'react';

export function Rail({ label, children }: { label: string; children: React.ReactNode[] }) {
  const ref = useRef<HTMLUListElement>(null);
  const scroll = (dir: 1 | -1) => {
    const el = ref.current!;
    const rtl = getComputedStyle(el).direction === 'rtl' ? -1 : 1;
    const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
    el.scrollBy({ left: dir * rtl * el.clientWidth * 0.85, behavior: reduce ? 'auto' : 'smooth' });
  };
  return (
    <section aria-roledescription="carousel" aria-label={label}>
      <div className="rail-controls">
        <button type="button" aria-label="Scroll previous" onClick={() => scroll(-1)}>‹</button>
        <button type="button" aria-label="Scroll next" onClick={() => scroll(1)}>›</button>
      </div>
      <ul ref={ref} className="rail" role="list">
        {children.map((c, i) => <li key={i} aria-label={`${i + 1} of ${children.length}`}>{c}</li>)}
      </ul>
    </section>
  );
}
```
```css
.rail { display: grid; grid-auto-flow: column; grid-auto-columns: min(80%, 18rem); gap: 1rem;
  overflow-x: auto; scroll-snap-type: inline mandatory; overscroll-behavior-inline: contain; padding-block-end: .5rem; }
.rail > li { scroll-snap-align: start; }
@supports selector(::scroll-button(*)) {
  .rail { scroll-marker-group: after; }
  .rail::scroll-button(inline-start) { content: "‹" / "Scroll previous"; }
  .rail::scroll-button(inline-end) { content: "›" / "Scroll next"; }
  .rail > li::scroll-marker { content: ""; inline-size: .75rem; block-size: .75rem; border-radius: 50%; border: 1px solid; }
  .rail > li::scroll-marker:target-current { background: currentColor; }
  .rail-controls { display: none; } /* native buttons replace JS ones */
}
```
Rail items stay in the tab order (they're all "visible" by scrolling). Focusing an item scrolls it into view. Disable the JS buttons at the scroll ends if you want (track `scrollLeft`).

### Single-slide carousel with Embla + APG semantics
```tsx
'use client';
import { useCallback, useEffect, useState } from 'react';
import useEmblaCarousel from 'embla-carousel-react';
import Autoplay from 'embla-carousel-autoplay';

export function Hero({ slides }: { slides: { id: string; title: string; content: React.ReactNode }[] }) {
  const reduce = typeof window !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  const [autoplayOn, setAutoplayOn] = useState(false); // default: off
  const [emblaRef, api] = useEmblaCarousel({ loop: true, duration: reduce ? 0 : 25 },
    [Autoplay({ playOnInit: false, stopOnInteraction: true, stopOnMouseEnter: true, stopOnFocusIn: true, delay: 7000 })]);
  const [index, setIndex] = useState(0);

  useEffect(() => {
    if (!api) return;
    const onSelect = () => setIndex(api.selectedScrollSnap());
    api.on('select', onSelect);
    return () => { api.off('select', onSelect); };
  }, [api]);

  const toggle = useCallback(() => {
    const ap = api?.plugins().autoplay; if (!ap) return;
    if (autoplayOn) ap.stop(); else ap.play();
    setAutoplayOn(!autoplayOn);
  }, [api, autoplayOn]);

  return (
    <section aria-roledescription="carousel" aria-label="Highlights">
      <button type="button" onClick={toggle}>
        {autoplayOn ? 'Stop automatic slide show' : 'Start automatic slide show'}
      </button>
      <button type="button" aria-label="Previous slide" onClick={() => api?.scrollPrev()}>‹</button>
      <button type="button" aria-label="Next slide" onClick={() => api?.scrollNext()}>›</button>
      <div ref={emblaRef} className="embla">
        <div className="embla__container" aria-live={autoplayOn ? 'off' : 'polite'} aria-atomic="false">
          {slides.map((s, i) => (
            <div key={s.id} className="embla__slide" role="group" aria-roledescription="slide"
              aria-label={`${i + 1} of ${slides.length}: ${s.title}`} inert={i !== index}>
              {s.content}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
```
The option and event names above follow Embla v8. v9 renamed several APIs (snap-centric naming, lowercase events), so check the migration notes. The v9 accessibility plugin can replace the manual ARIA wiring. React 19 accepts a boolean `inert` prop.

## Anti-Patterns
- **Auto-rotating hero on mobile**: missed content and motion issues. Fix: static hero or manual carousel.
- **No pause control while rotating**: WCAG 2.2.2 failure. Fix: a visible first-in-order rotation button, plus stop on hover/focus.
- **Tiny dots as the only navigation**: Fix: prev/next buttons ≥ 44px, numbered/thumbnail pickers.
- **Hidden slides still tabbable**: focus disappears offscreen. Fix: `inert` on non-current slides (single-slide mode).
- **`aria-live="polite"` while auto-rotating**: constant announcements. Fix: `off` during rotation.
- **Scroll-jacking vertical wheel into horizontal movement**: Fix: native horizontal scrolling only.
- **Eager-loading 10 full-size hero images**: LCP and bandwidth cost. Fix: prioritize the first image, lazy-load the rest.
- **Relying on `::scroll-marker` without fallback**: invisible controls in Firefox/Safari. Fix: `@supports` + JS buttons.

## Accessibility
- WCAG 2.2.2 Pause, Stop, Hide; 2.1.1 Keyboard; 4.1.2 Name/Role/Value; 1.4.11 Non-text Contrast (controls); 2.5.8 Target Size; 2.3.3 Animation from Interactions; 1.1.1 alt text for slide images; 2.4.3 Focus Order (rotation control first).
- Chromium's `scroll-marker-group` exposes tablist/tab semantics automatically. Verify with screen readers because the implementation is new.

## Responsive Design
- Rails: `grid-auto-columns` with `min()` to show a peek; switch to a grid at wide container sizes if all items fit.
- Use logical scroll-snap (`inline`) and mirrored arrow direction for RTL.
- Avoid carousels inside carousels, and horizontal rails inside horizontally scrolling tables.

## Performance
- `next/image` with `sizes`; `loading="eager"` + `fetchPriority="high"` only for the first visible slide (the `priority` prop is deprecated since Next.js 16); others `loading="lazy"`.
- Fixed `aspect-ratio` on slides prevents CLS. Embla v9 `ssrStyles()` improves the first paint.
- CSS scroll-snap rails need no library JS; lazy-hydrate carousels below the fold.

## Security
- Slide content from CMS: sanitize rich text and restrict remote image hosts.
- Don't autoplay third-party video embeds (privacy, performance); use click-to-load facades.

## Testing
- Playwright: prev/next change the visible slide and label; rotation button stops autoplay; hovering or focusing pauses it; hidden slides not focusable; reduced-motion emulation disables animation.
- Visual regression for peek layout at breakpoints.
- Lighthouse: LCP of the first slide image; CLS 0.
- Screen reader: announcements only on user-initiated changes.

## Tooling
- Embla Carousel (MIT): `embla-carousel-react` v8 stable; v9.0.0 RC with `embla-carousel-accessibility` plugin (roles, labels, live region). Plugins: autoplay, auto-scroll, fade, auto-height, class names.
- shadcn/ui Carousel (Embla-based).
- Native CSS scroll-snap (Baseline); `::scroll-button`/`::scroll-marker` (Chromium 135+, experimental).

## Framework Notes
- **React (Vite SPA)**: Embla hooks give you a ref and API. Clean up event listeners in effects. Avoid state updates on every scroll event; use `select`/`settle` events. For galleries opened in a lightbox, combine with a dialog and restore focus to the thumbnail.
- **Next.js (App Router)**: Carousels are Client Components (`'use client'`). Slide content can be server-rendered children. Reading `matchMedia` during render causes hydration mismatches, so read `prefers-reduced-motion` in an effect (or use CSS-only reduced-motion rules). Put the first slide image in server HTML with `loading="eager"` and `fetchPriority="high"` for LCP (not the deprecated `priority` prop). Consider `next/dynamic` for below-the-fold carousels. For CMS-driven slides, fetch in a Server Component and pass serializable data.

## AI Agent Guidance
- DO question the need for a carousel; propose a grid or static hero when appropriate.
- DO default autoplay off; if on, add a rotation control, hover/focus stop, and reduced-motion handling.
- DON'T ship dot-only navigation or leave hidden slides focusable.
- DON'T rely on `::scroll-marker` without fallback.
- Verify: keyboard operation; slide labels; live region behavior; first-image LCP; CLS; RTL; touch swipe; WebKit/Firefox fallback.

## Examples
shadcn/ui Carousel with labelled controls:
```tsx
'use client';
import { Carousel, CarouselContent, CarouselItem, CarouselPrevious, CarouselNext } from '@/components/ui/carousel';

export function Testimonials({ items }: { items: { id: string; quote: string; author: string }[] }) {
  return (
    <Carousel opts={{ align: 'start' }} aria-label="Customer testimonials">
      <CarouselContent>
        {items.map((t, i) => (
          <CarouselItem key={t.id} className="md:basis-1/2" aria-label={`${i + 1} of ${items.length}`}>
            <blockquote><p>{t.quote}</p><footer>{t.author}</footer></blockquote>
          </CarouselItem>
        ))}
      </CarouselContent>
      <CarouselPrevious /> {/* renders sr-only "Previous slide" */}
      <CarouselNext />
    </Carousel>
  );
}
```

## Related Skills
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md): motion preferences
- [responsive-images-and-media](../responsive-images-and-media/Skill.md): slide images
- [lcp-optimization](../lcp-optimization/Skill.md): hero image priority
- [scroll-driven-animations](../scroll-driven-animations/Skill.md): CSS scroll features
- [landing-page-design](../landing-page-design/Skill.md): hero alternatives
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md): product galleries
- [tabs](../tabs/Skill.md): tabbed slide pickers

## Sources
- [WAI-ARIA APG: Carousel Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/carousel/) — Official — rotation control, roles, live region
- [NN/g: Designing Effective Carousels](https://www.nngroup.com/articles/designing-effective-carousels/) — Research — ≤5 frames, no mobile auto-forward, indicators
- [Chrome for Developers: Carousels with CSS](https://developer.chrome.com/blog/carousels-with-css) — Official — scroll-button/marker, Chrome 135
- [MDN: ::scroll-marker](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/::scroll-marker) — Official — experimental status, generated semantics
- [Embla Carousel: Accessibility plugin](https://www.embla-carousel.com/docs/plugins/accessibility) — Open Source — v9 RC plugin options
- [Embla v9 Release Notes discussion](https://github.com/davidjerleke/embla-carousel/discussions/1271) — Open Source — v9 changes

## License / Usage Notes
Summarized in original wording; code original. Embla and shadcn/ui MIT.

## Quality Tier
A — APG + NN/g + verified platform/library status; Embla v9 API still RC, so code targets v8.

## Status
Active

## Last Verified
2026-09-15
