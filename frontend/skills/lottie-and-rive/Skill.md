# Lottie and Rive

## Summary
Lottie and Rive deliver designer-authored vector animations to the web. Lottie plays animations exported from After Effects (via Bodymovin) or created in LottieFiles tools. The modern runtime is dotLottie (`@lottiefiles/dotlottie-web` and `@lottiefiles/dotlottie-react`, a ThorVG/WASM canvas renderer), using the compressed `.lottie` format with themes and state machines. Rive is an interactive animation tool whose runtime (`@rive-app/react-webgl2` recommended, or `@rive-app/react-canvas`) plays state machines driven by inputs and data binding. In React/Next.js both are client-only canvas components that need lazy loading, sizing, offscreen pausing, cleanup, and accessible alternatives.

## Category
Animation

## Subcategories
Vector animation, After Effects export, dotLottie, state machines, interactive illustrations, animated icons, onboarding animation, data binding

## Problem It Solves
Complex illustrative motion (animated illustrations, character animation, rich animated icons, interactive onboarding) is impractical to hand-code in CSS. Video is heavy, non-interactive, and not themeable. Lottie and Rive let designers own the motion while engineers integrate lightweight, scalable, and (with Rive/dotLottie state machines) interactive assets.

## When To Use
- Empty states, onboarding, success/celebration moments, and illustrated loading states.
- Interactive animated icons or controls with multiple states (Rive state machines, dotLottie state machines).
- Brand mascots/characters reacting to input (hover, cursor, form state), which is Rive's strength.
- Teams with designers working in After Effects (Lottie) or Rive editor.

## When Not To Use
- Simple UI transitions or spinners: CSS/SVG is lighter.
- Photographic or 3D-rendered content: use video (AV1/H.264) or three.js.
- Critical content or LCP hero imagery: canvas animation delays paint. Use a static poster.
- High-frequency micro-interactions in dense UIs (hundreds of instances): use CSS/SVG.

## Core Principles
1. Lazy-load the runtime and asset, and render a static poster/placeholder with explicit dimensions (no CLS).
2. Pause or freeze when offscreen or when the tab is hidden; loop only when necessary.
3. Clean up instances on unmount (`destroy()` for dotLottie, `cleanup()` for Rive, or rely on the React wrappers).
4. Respect reduced motion: show a static frame, or play once without looping.
5. Decorative animations are `aria-hidden`; meaningful ones need a text alternative.
6. Budget asset size: prefer `.lottie` (compressed, deduplicated) over raw JSON, and `.riv` files that are optimized in the editor.

## Best Practices
- Choose Lottie when the source is After Effects or the LottieFiles ecosystem. Choose Rive for interactivity, state machines, runtime data binding, and small file sizes with complex rigs.
- Use `renderConfig.freezeOnOffscreen` (dotLottie) and `autoResize` so canvases match container size and DPR.
- Cap `devicePixelRatio` at 2 on mobile to reduce canvas cost.
- Use `DotLottieWorker` (renders in a Web Worker) when multiple animations run at once or the main thread is busy.
- For Rive, use the WebGL2 renderer (`@rive-app/react-webgl2`) for the full feature set (feathering, advanced effects). Use `canvas-lite` when you don't need text, layouts, scripting, or audio and bundle size matters.
- Drive state machines via inputs and view model data binding rather than playing timeline animations directly. This keeps designer/engineer contracts clear (document input names).
- Self-host assets under `/public` or a CDN you control. Avoid runtime fetching from third-party URLs.
- Provide a static SVG/PNG fallback for no-JS and reduced-motion users.

## Implementation Guidance

### Selection table
| Need | Choose |
|---|---|
| After Effects-authored illustration | dotLottie (`.lottie`) |
| Themeable colors at runtime (light/dark) | dotLottie themes or Rive data binding |
| Interactive, multi-state component (hover/press/progress) | Rive state machine (or dotLottie state machine) |
| Tiny animated icon set in large quantity | CSS/SVG or Lottie icons on a single worker |
| Legacy lottie-web JSON already in use | Migrate to dotLottie-web; convert JSON → `.lottie` |
| Photographic/complex gradients | Video |

### Packages (Sept 2026)
| Package | Status | Notes |
|---|---|---|
| `@lottiefiles/dotlottie-react` | Active | React wrapper; `DotLottieReact`; WASM canvas |
| `@lottiefiles/dotlottie-web` | Active (0.x) | Core; `DotLottie`, `DotLottieWorker` |
| `lottie-web` / `lottie-react` | Maintenance/legacy | SVG/canvas JS renderer; heavier main-thread cost |
| `@rive-app/react-webgl2` | Active (recommended) | Rive Renderer, full features |
| `@rive-app/react-canvas` | Active | Canvas2D, lighter |
| `@rive-app/canvas-lite` | Active | Smallest; no text/layout/scripting/audio |

## Recommended Workflow
1. Agree on the asset contract with the designer: dimensions, loop behavior, state machine name, inputs/view model properties, and theme slots.
2. Export `.lottie` / `.riv` and check the file size (target < 100–200KB for UI assets).
3. Create a client component wrapper with fixed aspect ratio, poster, and lazy loading.
4. Implement reduced-motion and offscreen handling.
5. Wire interactions (state machine inputs) to React state/events.
6. Test on low-end mobile; profile CPU/GPU and memory; verify cleanup on route change.

## Patterns

### dotLottie client component (Next.js)
```tsx
// components/lottie/success-animation.tsx
"use client";
import { DotLottieReact } from "@lottiefiles/dotlottie-react";
import { useReducedMotion } from "motion/react"; // or a small matchMedia hook

export function SuccessAnimation({ label }: { label?: string }) {
  const reduce = useReducedMotion();
  return (
    <div className="aspect-square w-40" role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <DotLottieReact
        src="/animations/success.lottie"
        autoplay={!reduce}
        loop={false}
        renderConfig={{ autoResize: true, freezeOnOffscreen: true, devicePixelRatio: Math.min(2, typeof window !== "undefined" ? window.devicePixelRatio : 1) }}
      />
    </div>
  );
}
```

### Lazy-load below the fold
```tsx
// app/onboarding/page.tsx (Server Component)
import dynamic from "next/dynamic";
const OnboardingHero = dynamic(() => import("@/components/lottie/onboarding-hero"), {
  loading: () => <img src="/animations/onboarding-poster.svg" alt="" width={320} height={240} />,
});
```
`ssr: false` isn't allowed with `next/dynamic` inside Server Components. Import a client component that itself renders only after mount, or rely on the wrapper's client-only rendering.

### dotLottie with imperative control and state machine
```tsx
"use client";
import { DotLottieReact, type DotLottie } from "@lottiefiles/dotlottie-react";
import { useState } from "react";

export function AnimatedToggle({ on, onToggle }: { on: boolean; onToggle: () => void }) {
  const [player, setPlayer] = useState<DotLottie | null>(null);
  return (
    <button role="switch" aria-checked={on} onClick={() => { onToggle(); player?.setFrame(on ? 0 : player.totalFrames - 1); }}>
      <DotLottieReact src="/animations/toggle.lottie" dotLottieRefCallback={setPlayer} className="size-8" aria-hidden />
      <span className="sr-only">Notifications</span>
    </button>
  );
}
```
State machine APIs (`stateMachineLoad`, `stateMachineStart`, and similar) differ across 0.x releases. Check the dotLottie docs for your installed version.

### Rive state machine with input (React)
```tsx
"use client";
import { useRive, useStateMachineInput, Layout, Fit, Alignment } from "@rive-app/react-webgl2";

export function RiveLikeButton({ liked, onToggle }: { liked: boolean; onToggle: () => void }) {
  const { rive, RiveComponent } = useRive({
    src: "/animations/like.riv",
    stateMachines: "Like SM",
    autoplay: true,
    layout: new Layout({ fit: Fit.Contain, alignment: Alignment.Center }),
  });
  const likedInput = useStateMachineInput(rive, "Like SM", "isLiked", liked);
  return (
    <button aria-pressed={liked} onClick={() => { onToggle(); if (likedInput) likedInput.value = !liked; }} className="size-12">
      <RiveComponent aria-hidden />
      <span className="sr-only">{liked ? "Unlike" : "Like"}</span>
    </button>
  );
}
```
Newer Rive files use view model data binding instead of inputs. The React runtime exposes data binding hooks; check the current names in the Rive React docs. The React hooks clean up the Rive instance on unmount. With the vanilla runtime, call `rive.cleanup()`.

### Reduced motion + offscreen pause (Rive)
```tsx
useEffect(() => {
  if (!rive) return;
  const mq = matchMedia("(prefers-reduced-motion: reduce)");
  if (mq.matches) rive.pause();
  const io = new IntersectionObserver(([e]) => (e.isIntersecting && !mq.matches ? rive.play() : rive.pause()));
  const canvas = rive.canvas as HTMLCanvasElement | undefined;
  if (canvas) io.observe(canvas);
  return () => io.disconnect();
}, [rive]);
```

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| Large Lottie JSON via `lottie-web` SVG renderer on a hero | Main-thread heavy, slow LCP | dotLottie WASM canvas + poster; or video |
| No container dimensions | CLS when canvas initializes | Fixed aspect-ratio wrapper |
| Infinite loops offscreen | CPU/battery drain | `freezeOnOffscreen`, IntersectionObserver pause |
| Animation as only status indicator | Inaccessible | Text/ARIA status alongside |
| Hot-linking assets from third-party CDNs | Availability, privacy, CSP issues | Self-host in `/public` |
| Dozens of Lottie instances in a list | Each has its own renderer | CSS/SVG icons, or a shared worker |
| Hard-coded state machine input names scattered in code | Breaks when designer renames | Centralize constants; document contract |
| Not destroying vanilla instances on unmount | WASM/GPU memory leaks | React wrappers or `destroy()`/`cleanup()` |

## Accessibility
- Decorative: `aria-hidden="true"` on the container or canvas.
- Meaningful: `role="img"` + `aria-label` describing the conveyed information, with status also available as text.
- WCAG 2.2.2: animations over 5s that loop need pause controls or should stop. Use single-play for celebrations.
- WCAG 2.3.3: reduced motion shows a static representative frame (`autoplay={false}` + set the frame) or poster.
- WCAG 2.3.1: check designer assets for flashing.
- Interactive Rive controls must still be real `<button>`/`role="switch"` elements with keyboard support. The canvas itself isn't focusable.

## Responsive Design
- Use fit/alignment layout (Rive `Fit.Contain`/`Cover`; dotLottie `layout` options) inside aspect-ratio containers.
- Rive Layouts can adapt artboards responsively (`Fit.Layout`) when designers build responsive artboards.
- Cap DPR on mobile. Consider static images on very small screens where the animation adds little.
- Swap to lighter assets via `matchMedia` for small viewports.

## Performance
- dotLottie renders via ThorVG compiled to WASM on canvas, which is typically far cheaper than lottie-web SVG for complex files. Load the WASM lazily (it's fetched on first use; self-host it if CSP or offline needs require).
- `DotLottieWorker` moves rendering off the main thread, which helps INP when animations play during interaction.
- Rive's WebGL2 renderer uses GPU. Many simultaneous canvases each hold GL contexts, and browsers cap contexts (~16), so consolidate or use a shared renderer approach where supported.
- Keep asset complexity reasonable (masks, mattes, and effects in After Effects are expensive at runtime).
- Preload critical `.riv`/`.lottie` with `<link rel="preload" as="fetch" crossorigin>` only when shown immediately.

## Security
- Treat animation files as untrusted if user-uploaded. Lottie JSON can embed expressions in some renderers (lottie-web supports AE expressions, which evaluate JS). Don't render user-supplied Lottie JSON with expression support. dotLottie/ThorVG don't execute JS expressions, but validate the source anyway.
- CSP: WASM runtimes may need `'wasm-unsafe-eval'` in `script-src`, and `connect-src` for asset/WASM URLs. Self-host to avoid broad allowances.
- Pin runtime versions. WASM binaries fetched from CDNs by default should be self-hosted for integrity.

## Testing
- Component tests: mock the runtime packages (canvas/WASM don't work in jsdom). Assert wrapper ARIA and fallback rendering.
- Playwright: verify the canvas renders (non-blank screenshot region) in Chromium/WebKit, reduced-motion shows a static state, and route changes don't leak (heap snapshots in DevTools for long sessions).
- Performance: CPU profile with 4x throttle; count WebGL contexts on pages with multiple Rive instances.
- Designer contract tests: load the file and assert expected state machine and input names exist (a dev-only check).

## Tooling
- LottieFiles Creator / After Effects + Bodymovin / dotLottie converter (Official).
- `@lottiefiles/dotlottie-react` / `dotlottie-web` (Active, MIT).
- Rive Editor, `@rive-app/react-webgl2`, `@rive-app/react-canvas` (Active, MIT runtimes).
- `lottie-web` (Legacy/maintenance).
- Rive Data Binding (view models) — current recommended way to drive runtime values.

## Framework Notes
- **React (Vite SPA)**: import the wrappers directly. Lazy-load with `React.lazy` + `Suspense` for non-critical animations. Place `.lottie`/`.riv` in `public/`.
- **Next.js App Router**: both runtimes touch `window`/canvas, so wrappers must be `"use client"`. Keep a Server Component parent that renders the poster and sizes the container. Load the client animation via `next/dynamic` from a client boundary. Add `.riv`/`.lottie` to `public/` and serve with long cache headers (`next.config` `headers()` for `/animations/*`). If WASM is fetched from a CDN by default, configure the runtime to use a self-hosted URL and allow it in CSP.
- **Hydration**: server HTML should show the poster frame. The canvas replaces it after load, so swap without layout shift by using the same box. Don't render animation-specific markup that differs between server and client (e.g. reading `matchMedia` during render), or you'll get hydration mismatches. Read preferences in effects or via `useSyncExternalStore` with a server snapshot.

## AI Agent Guidance
- DO wrap runtimes in `"use client"` components with fixed-size containers and posters.
- DO add reduced-motion handling, offscreen pausing, and ARIA (hidden or labeled).
- DO prefer dotLottie over lottie-web for new work; prefer `@rive-app/react-webgl2` for Rive.
- DON'T use Lottie/Rive for simple UI transitions or LCP hero content.
- DON'T guess state machine/input names. Read them from the file or ask the designer.
- Verify: no hydration mismatch; no CLS; animation pauses offscreen; reduced motion shows static frame; memory stable across navigations.

## Examples

### Poster-first wrapper
```tsx
// components/lottie/animated-illustration.tsx (Server Component)
import { LazyLottie } from "./lazy-lottie"; // client component

export function AnimatedIllustration({ src, poster, alt }: { src: string; poster: string; alt: string }) {
  return (
    <figure className="relative aspect-[4/3] w-full max-w-md">
      <img src={poster} alt={alt} className="absolute inset-0 size-full object-contain" />
      <LazyLottie src={src} className="absolute inset-0" />
    </figure>
  );
}
```
```tsx
// components/lottie/lazy-lottie.tsx
"use client";
import { useEffect, useState } from "react";
import { DotLottieReact } from "@lottiefiles/dotlottie-react";

export function LazyLottie({ src, className }: { src: string; className?: string }) {
  const [ready, setReady] = useState(false);
  useEffect(() => {
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches) setReady(true);
  }, []);
  if (!ready) return null; // poster remains
  return <DotLottieReact src={src} autoplay loop className={className} aria-hidden
    renderConfig={{ autoResize: true, freezeOnOffscreen: true }} />;
}
```

## Related Skills
- [iconography-and-illustration](../iconography-and-illustration/Skill.md) — illustration strategy
- [empty-states](../empty-states/Skill.md) — common placement
- [onboarding-ux](../onboarding-ux/Skill.md) — onboarding animations
- [micro-interactions](../micro-interactions/Skill.md) — when CSS beats Lottie
- [animation-performance](../animation-performance/Skill.md) — canvas and main-thread costs
- [content-security-policy](../content-security-policy/Skill.md) — WASM and asset CSP
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — deferring runtimes
- [accessible-images-and-media](../accessible-images-and-media/Skill.md) — alternatives for animated media

## Sources
- [dotLottie web runtime docs](https://docs.lottiefiles.com/en/runtimes/distributions/js) — Official — packages, renderConfig, worker, destroy
- [Rive web runtime docs](https://rive.app/docs/runtimes/web/web-js) — Official — packages, renderers, state machines, data binding, cleanup
- [LottieFiles developer portal](https://developers.lottiefiles.com/) — Official — dotLottie player overview
- [Rive React runtime](https://rive.app/docs/runtimes/react/react) — Official — useRive, useStateMachineInput
- [lottie-web (GitHub)](https://github.com/airbnb/lottie-web) — Open Source — legacy renderer, expressions caveat

## License / Usage Notes
dotLottie runtimes and Rive runtimes are MIT. Rive Editor and LottieFiles platform features have their own commercial terms. Animation assets carry their creators' licenses; check LottieFiles free-asset licensing before use. Content summarized; code original.

## Quality Tier
B — Official docs fetched, but dotLottie is 0.x and state-machine/data-binding APIs change frequently. Hook names for Rive data binding weren't verified in detail.

## Status
Active

## Last Verified
2026-09-15
