# Reduced Motion and Vestibular Safety

## Summary
Designing and implementing motion in React/Next.js that doesn't harm people with vestibular disorders, migraines, seizure conditions, or attention difficulties. Covers `prefers-reduced-motion`, pause/stop/hide controls for auto-moving content, flash thresholds, and wiring reduced motion into CSS, Tailwind, Motion for React, GSAP and View Transitions.

## Category
Accessibility

## Subcategories
prefers-reduced-motion, vestibular disorders, parallax, auto-playing content, carousels, flashing and seizures, View Transitions, Motion for React, pause controls

## Problem It Solves
Large-scale motion (parallax, zooming page transitions, scroll-jacking, spinning or bouncing elements) can trigger dizziness, nausea and migraines. Auto-rotating carousels and background videos distract and block reading. Flashing content can trigger seizures. Many teams ignore the OS-level "Reduce motion" setting their users have already turned on.

## When To Use
- Any animation, transition, scroll effect, auto-playing video/GIF, carousel, marquee, or animated illustration (Lottie/Rive).
- Page and route transitions (View Transitions API, layout animations).
- Loading spinners and skeleton shimmer.

## When Not To Use
- Micro-feedback such as color or opacity fades under ~200ms generally needs no removal, but do respect the preference for anything involving movement, scaling or parallax.
- Don't remove *all* feedback in reduced mode. Replace motion with non-motion cues (fade, instant state change).

## Core Principles
1. **Respect the user's OS preference.** `prefers-reduced-motion: reduce` means remove or minimise non-essential motion.
2. **Reduce, don't eliminate meaning.** Swap movement for opacity or instant changes so state changes remain perceivable.
3. **Anything that moves, blinks or scrolls automatically for more than 5 seconds needs pause/stop/hide** (2.2.2 A).
4. **Nothing flashes more than three times per second** (2.3.1 A).
5. **Motion triggered by interaction can be disabled** (2.3.3 AAA). Treat it as the target for large motion.
6. **Autoplay is opt-in**, especially with audio (1.4.2 A: controls for audio over 3 seconds).

## Best Practices
- Default to motion-safe: write animations inside `@media (prefers-reduced-motion: no-preference)`, so reduced is the baseline.
- Riskiest effects (always reduce): parallax, scroll-linked zoom and rotation, large translate/scale page transitions, infinite spinning, bouncing, "shake", auto-scrolling marquees, background video, scroll-jacking and smooth-scroll hijacks.
- Keep durations short (150–300ms for UI) and avoid large-distance movement even in full-motion mode.
- Provide an in-app motion setting ("Reduce motion: system / on / off") for users who can't change the OS setting (shared devices, kiosks).
- Auto-rotating carousels: don't auto-rotate. If required, pause on hover and focus, and provide a visible pause button.
- Background video: no autoplay in reduced mode; show a poster image; always include a pause control.
- GIFs: offer a static fallback via `<picture>` with a `(prefers-reduced-motion: reduce)` source, or pause/play controls.
- `scroll-behavior: smooth` only under `no-preference`.
- Skeleton shimmer: disable the shimmer animation in reduced mode (keep the static placeholder).
- Photosensitivity: avoid full-screen red flashes; check video and animation with PEAT if content flashes.

## Implementation Guidance

### CSS baseline
```css
/* Motion only when the user hasn't asked for less */
@media (prefers-reduced-motion: no-preference) {
  html { scroll-behavior: smooth; }
  .card { transition: transform 200ms ease, box-shadow 200ms ease; }
  .card:hover { transform: translateY(-2px); }
}

/* Safety net for third-party CSS */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```
The global safety net can break JS that waits for `transitionend`. Use 0.01ms, not 0, so events still fire, and test.

### Tailwind
- `motion-safe:animate-bounce`, `motion-reduce:transition-none`, `motion-reduce:animate-none`.

### Motion for React (formerly Framer Motion)
```tsx
'use client';
import { MotionConfig, motion, useReducedMotion } from 'motion/react';

export function Providers({ children }: { children: React.ReactNode }) {
  // "user" respects the OS setting: transform/layout animations are disabled, opacity/color still animate
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}

export function Hero() {
  const reduce = useReducedMotion();
  return (
    <motion.h1 initial={{ opacity: 0, y: reduce ? 0 : 24 }} animate={{ opacity: 1, y: 0 }}
      transition={{ duration: reduce ? 0.15 : 0.5 }}>
      Build faster
    </motion.h1>
  );
}
```

### Shared hook (SSR-safe)
```tsx
'use client';
import { useSyncExternalStore } from 'react';

const query = '(prefers-reduced-motion: reduce)';
export function usePrefersReducedMotion() {
  return useSyncExternalStore(
    cb => { const m = matchMedia(query); m.addEventListener('change', cb); return () => m.removeEventListener('change', cb); },
    () => matchMedia(query).matches,
    () => true, // server: assume reduced to avoid a motion flash before hydration
  );
}
```

### GSAP
```ts
const mm = gsap.matchMedia();
mm.add('(prefers-reduced-motion: no-preference)', () => {
  gsap.from('.hero-title', { y: 40, opacity: 0, duration: 0.6 });
  ScrollTrigger.create({ /* parallax only here */ });
});
mm.add('(prefers-reduced-motion: reduce)', () => {
  gsap.from('.hero-title', { opacity: 0, duration: 0.2 });
});
```

### View Transitions (cross-document and `document.startViewTransition`)
```css
@media (prefers-reduced-motion: reduce) {
  ::view-transition-group(*), ::view-transition-old(*), ::view-transition-new(*) { animation: none !important; }
}
```
For React's `<ViewTransition>` component (experimental/canary in React and Next.js) the same CSS applies.

### Pause control for auto-moving content (2.2.2)
```tsx
export function AutoPlayVideo({ src, poster }: { src: string; poster: string }) {
  const reduce = usePrefersReducedMotion();
  const ref = useRef<HTMLVideoElement>(null);
  const [playing, setPlaying] = useState(!reduce);
  useEffect(() => { playing ? ref.current?.play().catch(() => setPlaying(false)) : ref.current?.pause(); }, [playing]);
  return (
    <div className="relative">
      <video ref={ref} src={src} poster={poster} muted loop playsInline aria-hidden="true" />
      <button type="button" className="absolute bottom-2 right-2" aria-pressed={!playing} onClick={() => setPlaying(p => !p)}>
        {playing ? 'Pause background video' : 'Play background video'}
      </button>
    </div>
  );
}
```

## Recommended Workflow
1. Inventory motion: transitions, scroll effects, carousels, videos, Lottie, route transitions.
2. Classify each: essential (conveys state), decorative, or risky (large or parallax).
3. Implement motion-safe defaults and reduced alternatives (opacity or instant).
4. Add pause controls for anything auto-moving for more than 5 seconds.
5. Test with the OS setting on:
   - macOS: System Settings > Accessibility > Display > Reduce motion
   - Windows: Settings > Accessibility > Visual effects > Animation effects off
   - iOS: Accessibility > Motion > Reduce Motion
   - Android: Accessibility > Remove animations
   - or DevTools emulation
6. Automated check: Playwright `emulateMedia({ reducedMotion: 'reduce' })` visual snapshots.

## Patterns
- **Motion tokens.** `--duration-fast: 150ms` becomes `0ms` under `prefers-reduced-motion: reduce`, and all components use the tokens.
- **Crossfade substitution.** Slide transitions become opacity fades in reduced mode.
- **User override.** Store `motion: 'system' | 'reduce' | 'full'` in settings; set `data-motion="reduce"` on `<html>`; CSS `[data-motion="reduce"] …` mirrors the media query.
- **Static poster for Lottie/Rive.** Render the first frame, or an SVG, when reduced.

## Anti-Patterns
- **Ignoring the preference entirely.** Common in marketing sites. Wrap animations.
- **Setting `animation: none` and losing essential state feedback** (e.g., progress). Keep non-motion indicators.
- **Auto-advancing carousels without pause.** 2.2.2 failure. Remove autoplay or add controls.
- **Scroll-jacking and parallax heroes.** Vestibular triggers. Remove them in reduced mode, and ideally altogether.
- **`scroll-behavior: smooth` globally.** Long smooth scrolls from skip links or anchors are disorienting. Restrict it to `no-preference`.
- **Server rendering with motion, then disabling after hydration.** The animation plays once. Assume reduced on the server or use CSS media queries.
- **Flashing "attention" effects.** Seizure risk (2.3.1). Never exceed three flashes per second.

## Accessibility
- 2.2.2 Pause, Stop, Hide (A), 2.3.1 Three Flashes or Below Threshold (A), 2.3.3 Animation from Interactions (AAA), 1.4.2 Audio Control (A), 2.3.2 Three Flashes (AAA).
- Media query: `prefers-reduced-motion` (Baseline, widely available).
- Pause buttons need accessible names and `aria-pressed` or label swaps, plus keyboard operability.

## Responsive Design
- Mobile users often enable Reduce Motion to save battery. Test on iOS and Android.
- Scroll-driven animations on small screens magnify vestibular effects (larger relative movement). Reduce by default on narrow viewports if in doubt.

## Performance
- Reduced motion improves performance: fewer composited layers and less main-thread animation work.
- Don't load heavy animation libraries (Lottie players, GSAP ScrollTrigger) when reduced. Dynamic-import them only under `no-preference`.

## Security
- None specific.

## Testing
```ts
test('hero respects reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  const duration = await page.locator('.card').evaluate(el => getComputedStyle(el).transitionDuration);
  expect(['0s', '1e-05s']).toContain(duration);
  await expect(page.getByRole('button', { name: /pause background video/i })).toBeVisible();
});
```
- Manual: enable the OS setting and walk through route transitions, modals, carousels and scroll effects.
- Photosensitivity: PEAT (Trace Center) for video content with flashing.

## Tooling
- Chrome DevTools Rendering > Emulate CSS `prefers-reduced-motion`; Playwright `reducedMotion` emulation.
- Motion for React `MotionConfig reducedMotion="user"`, `useReducedMotion`; GSAP `gsap.matchMedia()`; Tailwind `motion-safe:`/`motion-reduce:` variants.
- PEAT (Photosensitive Epilepsy Analysis Tool).

## Framework Notes
- **Next.js.**
  - Put `MotionConfig` in a client `Providers` component in `app/layout.tsx`.
  - Prefer CSS media queries for initial-render animations, to avoid hydration flashes.
  - Experimental View Transitions integration (`viewTransition` flag / React `<ViewTransition>`) must include the reduced-motion CSS.
- **React (Vite SPA).** Same hooks. Route-transition libraries should check the preference before animating page changes.

## AI Agent Guidance
- Do: wrap every movement animation in `motion-safe`/`no-preference`, or check `useReducedMotion`; add pause controls to auto-moving media; default `scroll-behavior` only under `no-preference`.
- Do: provide a non-motion alternative for state changes.
- Don't: add parallax, scroll-jacking, auto-rotating carousels, autoplay video without controls, or flashing effects.
- Verify before done:
  - page tested with reduced-motion emulation (no large movement)
  - pause controls work by keyboard
  - no flashing content

## Examples
```tsx
// Carousel without autoplay; slide transition becomes instant in reduced mode
<div className="flex transition-transform duration-300 motion-reduce:transition-none"
     style={{ transform: `translateX(-${index * 100}%)` }}>
  {slides}
</div>
```

## Related Skills
- [motion-design-principles](../motion-design-principles/Skill.md) — purposeful motion
- [motion-for-react](../motion-for-react/Skill.md) — Motion library details
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md) — CSS motion
- [view-transitions-api](../view-transitions-api/Skill.md) — page transitions
- [scroll-driven-animations](../scroll-driven-animations/Skill.md) — scroll effects to reduce
- [carousels](../carousels/Skill.md) — pause/rotation controls
- [cognitive-accessibility](../cognitive-accessibility/Skill.md) — distraction reduction

## Sources
- [Understanding 2.3.3 Animation from Interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html) — Official — vestibular rationale
- [Understanding 2.2.2 Pause, Stop, Hide](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html) — Official — 5-second rule
- [Understanding 2.3.1 Three Flashes](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) — Official — flash thresholds
- [MDN: prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion) — Official (MDN) — media feature
- [Motion for React accessibility guide](https://motion.dev/docs/react-accessibility) — Open Source — MotionConfig reducedMotion
- [GSAP matchMedia](https://gsap.com/docs/v3/GSAP/gsap.matchMedia()) — Open Source (free license) — conditional animation
- [Vestibular Disorders Association & practitioner articles (Val Head, Eric Bailey)](https://www.a11yproject.com/posts/understanding-vestibular-disorders/) — Community — trigger types

## License / Usage Notes
Summarised from W3C, MDN, and library docs. GSAP is free under its own license (no longer requiring purchase). Motion is MIT. Code is original.

## Quality Tier
A — standards-backed and implementation-complete. Vestibular trigger research is less formalised.

## Status
Active

## Last Verified
2026-09-15
