# Animated Component Collections (Aceternity UI, Magic UI, coss ui, and shadcn Registries)

## Summary
Animated collections are copy-in component catalogs, usually installed via the shadcn CLI registry protocol, that add motion-heavy marketing effects and extended primitives on top of Tailwind and shadcn tokens. Magic UI (MIT, 22k+ GitHub stars) and Aceternity UI (free components plus a paid All-Access Pass) focus on animated heroes, backgrounds, marquees, bento grids and text effects using Motion (formerly Framer Motion). coss ui (built on Base UI) and Origin UI extend the primitive layer with many variants. This skill covers adopting them without wrecking performance, accessibility or licensing.

## Category
UI Libraries

## Subcategories
shadcn registries, Magic UI, Aceternity UI, coss ui, Origin UI, Motion, reduced motion, marketing effects, licensing

## Problem It Solves
Landing pages and product marketing need distinctive motion and visual polish quickly. These collections provide ready effects that plug into shadcn/Tailwind projects as owned source code.

## When To Use
- Marketing sites, launch pages, portfolios and hero sections where visual impact drives conversion.
- shadcn/ui projects needing extra variants (coss ui/Origin UI) that follow the same tokens and CLI.
- Rapid prototyping of visual concepts before custom design work.

## When Not To Use
- Dense application UIs (dashboards, forms) where motion distracts and costs INP.
- Accessibility-sensitive or regulated contexts without a reduced-motion strategy.
- When the effect needs WebGL/shaders beyond simple CSS/Motion. Evaluate dedicated 3D tooling instead.
- When the license tier is unclear (Aceternity Pro blocks in open-source repos).

## Core Principles
1. **Registry items are code you own**: review, trim and adapt. They aren't black-box dependencies.
2. **Motion is progressive enhancement**: content must be readable and usable without animation.
3. **Respect `prefers-reduced-motion`** for every looping, parallax or large-movement effect (WCAG 2.3.3, 2.2.2).
4. **Isolate client code**: effects are client components. Keep them small leaves inside Server Component pages.
5. **Check license per component**: free vs paid tiers differ across collections.

## Best Practices
- Install via namespaced registries configured in `components.json` (e.g. `@magicui/...`, `@aceternity/...`; verify the registry names in each site's docs) and review with `--dry-run`/`--view` first.
- Pin Motion (`motion` package) to one version across all copied components. Collections may assume different majors.
- Wrap effects with a reduced-motion guard (`useReducedMotion()` from Motion, or `motion-safe:`/`motion-reduce:` Tailwind variants).
- Prefer CSS animations (transform/opacity) for marquees and gradients. Use Motion only for gesture or layout needs.
- Lazy-load below-the-fold effects (`next/dynamic` with `ssr: false` only when needed, or IntersectionObserver-gated mounting).
- Remove unused variants and props from copied code to cut bundle size.
- Replace hard-coded colors with semantic tokens so effects follow the theme.

## Implementation Guidance
| Collection | Foundation | Install | License (as of September 2026) | Best for |
|---|---|---|---|---|
| Magic UI | React, Tailwind v4, Motion, shadcn | shadcn CLI | MIT | Micro-interactions, marquee, number ticker, text effects |
| Aceternity UI | React, Tailwind, Motion | shadcn CLI registry | Free components + paid All-Access Pass (commercial terms) | Cinematic heroes, 3D cards, backgrounds, templates |
| coss ui | Base UI + Tailwind | Docs/registry (verify) | Open source (license not verified) | Large set of product "particles" |
| Origin UI | shadcn/Radix-style tokens | shadcn CLI | Verify (site blocked during research) | Extended primitive variants |

Reduced-motion wrapper:
```tsx
"use client";
import { useReducedMotion } from "motion/react";

export function MotionSafe({ children, fallback }: { children: React.ReactNode; fallback: React.ReactNode }) {
  const reduce = useReducedMotion();
  return <>{reduce ? fallback : children}</>;
}
```

## Recommended Workflow
1. Define the effect's purpose (attention, storytelling) and the performance budget for the page.
2. Pick the component. Check its license tier and dependencies (Motion, canvas, WebGL).
3. Install via registry with `--dry-run`. Review the diff and dependencies.
4. Refactor: semantic tokens, reduced-motion fallback, remove unused props, add accessible text.
5. Measure LCP, CLS and INP (Lighthouse/RUM) before and after. Test on a mid-range mobile device.

## Patterns
- **Static first frame**: render the final visual state server-side, then animate in on the client after hydration (no CLS, fast LCP).
- **Viewport-gated mount**: mount heavy canvases only when intersecting, and unmount when off-screen.
- **Decorative isolation**: `aria-hidden="true"` and `pointer-events-none` on purely decorative backgrounds.
- **Text effects with real text**: keep the full string in the DOM (screen-reader accessible). Animate spans with `aria-hidden` duplicates if splitting letters.

## Anti-Patterns
- **Animated hero text as the LCP element with delayed opacity**: LCP waits for the animation. Render visible text immediately.
- **Letter-split text without an accessible label**: screen readers read single characters. Provide `aria-label` or visually hidden full text.
- **Multiple infinite loops (marquee + particles + gradient) on one page**: main-thread and battery drain. Pause off-screen, limit concurrency.
- **Copying Aceternity Pro blocks into public repos**: license violation.
- **Unpinned mixed `framer-motion` and `motion` imports**: duplicate libraries in the bundle.

## Accessibility
- WCAG 2.3.3 (Animation from Interactions) and 2.2.2 (Pause, Stop, Hide) for auto-playing motion longer than 5s: provide reduced-motion alternatives and pause controls.
- Maintain contrast over animated gradients/backgrounds (1.4.3). Test the worst frame.
- Cursor-following and 3D tilt effects must not hide or move interactive targets (2.5.8 target size, focus visibility).
- Decorative canvases get `aria-hidden`. Meaningful visuals need text alternatives.

## Responsive Design
- Many effects are designed for desktop pointer hover. Provide tap-friendly or static variants on touch (`@media (hover: none)`).
- Scale particle counts and blur radii down on small screens. Large blur filters are expensive on mobile GPUs.
- Use container queries for bento grids so blocks adapt inside different layouts.

## Performance
- Motion adds roughly tens of KB (gzipped) to client JS. Use `LazyMotion` + `domAnimation` features to reduce it where supported.
- Animate `transform` and `opacity` only. Avoid animating `filter: blur`, `box-shadow` or layout properties in loops.
- Canvas/WebGL backgrounds: cap device pixel ratio, throttle frame rate, pause when hidden (`document.visibilityState`).
- Keep effects out of the LCP path and reserve space to avoid CLS.

## Security
- Registry installs are third-party code. Review for external script or font loads and analytics beacons (CSP impact).
- Pin registry URLs you trust. Avoid installing from arbitrary URLs in CI without review.
- Verify license compliance for commercial tiers (seat or project limits per vendor terms).

## Testing
- Visual regression with animations disabled (`prefers-reduced-motion: reduce` emulation in Playwright) for deterministic snapshots.
- Performance checks with Lighthouse CI on pages with effects. Set budgets for TBT and INP.
- Manual check with OS reduced-motion enabled.

## Tooling
- Magic UI (MIT, Tailwind v4, Motion), Aceternity UI (free + All-Access Pass), coss ui (Base UI-based), Origin UI, shadcn CLI registries and the registry directory.
- `motion` (Motion for React), `tw-animate-css`.
- Community aggregators (21st.dev, shadcn.io awesome registries) for discovery. Quality varies, so review each item.

## Framework Notes
- **Next.js App Router**: effects must be `"use client"` components. Import them into Server Component pages as leaves. Avoid wrapping entire sections in client components just for one animation. Use `next/dynamic` for heavy below-fold effects. Ensure SSR renders a meaningful static state (no blank hero before hydration).
- **React (Vite SPA)**: same component code. Lazy-load with `React.lazy` for route-level splitting.
- React 19: Motion supports React 19. Copied components may still use `forwardRef`, which is harmless but can be simplified.

## AI Agent Guidance
- DO check `components.json` registries and existing effect components before installing new ones.
- DO add reduced-motion handling and semantic tokens to any installed effect.
- DON'T use animated components in forms, tables or app chrome unless explicitly requested.
- DON'T install paid-tier components without confirming the project has a license.
- Verify before done: Lighthouse LCP and CLS not regressed, reduced-motion fallback works, decorative elements `aria-hidden`, a single Motion version in the lockfile.

## Examples
```tsx
// components/marketing/marquee.tsx: CSS-only marquee with reduced-motion and pause-on-hover
export function Marquee({ items }: { items: string[] }) {
  return (
    <div className="group relative overflow-hidden [mask-image:linear-gradient(to_right,transparent,black_10%,black_90%,transparent)]">
      <ul
        className="flex w-max gap-12 motion-safe:animate-[marquee_30s_linear_infinite] group-hover:[animation-play-state:paused]"
        aria-label="Customer logos"
      >
        {[...items, ...items].map((name, i) => (
          <li key={i} aria-hidden={i >= items.length} className="text-muted-foreground whitespace-nowrap">{name}</li>
        ))}
      </ul>
    </div>
  );
}
/* globals.css
@keyframes marquee { from { transform: translateX(0) } to { transform: translateX(-50%) } } */
```
```tsx
// Viewport-gated heavy effect
"use client";
import dynamic from "next/dynamic";
import { useEffect, useRef, useState } from "react";

const ParticlesBackground = dynamic(() => import("./particles-background"), { ssr: false });

export function LazyParticles() {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const io = new IntersectionObserver(([e]) => setVisible(e.isIntersecting), { rootMargin: "200px" });
    if (ref.current) io.observe(ref.current);
    return () => io.disconnect();
  }, []);
  return <div ref={ref} aria-hidden className="absolute inset-0 -z-10">{visible && <ParticlesBackground />}</div>;
}
```

## Related Skills
- [shadcn-ui](../shadcn-ui/Skill.md): registry mechanism
- [motion-for-react](../motion-for-react/Skill.md): Motion APIs
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md): motion accessibility
- [animation-performance](../animation-performance/Skill.md): compositor-friendly animation
- [landing-page-design](../landing-page-design/Skill.md): where these effects belong
- [lcp-optimization](../lcp-optimization/Skill.md): keep effects out of LCP
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md): third-party registries
- [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md): visual distinctiveness

## Sources
- [Aceternity UI](https://ui.aceternity.com/): Official. Install via shadcn CLI, Motion dependency, free vs All-Access Pass
- [magicuidesign/magicui](https://github.com/magicuidesign/magicui): Open Source. MIT, Tailwind v4, Motion, shadcn CLI
- [coss ui](https://coss.com/ui): Official. Built on Base UI, "particles"
- [The shadcn registry landscape (21st.dev)](https://21st.dev/blog/shadcn-registry-directory): Community. Registry ecosystem overview
- [Origin UI: more shadcn (21st.dev)](https://21st.dev/blog/origin-ui-components): Community. Origin UI positioning
- [shadcn changelog](https://ui.shadcn.com/docs/changelog): Official. Registry directory, GitHub registries

## License / Usage Notes
Magic UI is MIT. Aceternity UI has free components and commercially licensed paid content; read its terms. coss ui and Origin UI licenses were not verified (Origin UI site blocked). Summarized content; no collection source copied.

## Quality Tier
B: mechanisms and main facts verified, but licenses for coss/Origin UI and exact registry namespaces are unverified, and collections change rapidly.

## Status
Active

## Last Verified
2026-09-15
