# View Transitions API

## Summary
The View Transitions API animates between two DOM states by snapshotting the old view, applying the update, and cross-fading/morphing to the new view with CSS-controllable pseudo-elements. In React 19.3 (stable since September 9, 2026) it's exposed declaratively via `<ViewTransition>` and `addTransitionType`. The Next.js App Router (16.x) activates it on navigation with no config and supports `Link transitionTypes` for directional animations. Same-document transitions have been Baseline since October 2025 (Chrome 111, Safari 18, Firefox 144). Cross-document transitions (`@view-transition`) work in Chromium 126+ and Safari 18.2+, with Firefox partial.

## Category
Animation

## Subcategories
Route transitions, shared element transitions, Suspense reveal animation, directional navigation, list reorder, React ViewTransition, Next.js navigation

## Problem It Solves
Route changes and large state swaps replace content abruptly, with no visual continuity. Library-based page transitions have to keep old trees mounted, measure positions, and coordinate timing, which fights the App Router's segment model. View transitions let the browser handle snapshotting and morphing. React decides when to start them (Transitions, Suspense reveals), and CSS styles them.

## When To Use
- Next.js App Router route transitions: crossfades, directional slides, thumbnail→hero morphs.
- Skeleton→content handoff when a Suspense boundary resolves.
- Same-route content swaps (tabs, filters, pagination) wrapped in `startTransition`.
- List reorder/filter animations where each item has a unique `name`.
- Vite React SPAs with React Router, where navigations run inside `startTransition` (React Router's `viewTransition` option or manual wrapping).

## When Not To Use
- Gesture-driven, interruptible motion (drag, swipe with velocity). Transitions aren't interruptible mid-flight; use Motion.
- High-frequency updates (typing, sliders). Each transition blocks interaction with named elements and captures snapshots.
- Animating inner content that changes while morphing (video playing, live text). Snapshots are static images.
- Urgent updates that must reflect instantly (input values). React intentionally skips animation for non-Transition updates.

## Core Principles
1. Only Transitions animate: `startTransition`, `useDeferredValue`, Suspense reveals, and Next.js navigations. Plain `setState` and `flushSync` don't.
2. `<ViewTransition>` must be the first thing rendered in its subtree (before any DOM node) for enter/exit to fire.
3. A `name` must be unique among mounted elements at any moment. Use `name={`photo-${id}`}`.
4. Set `default="none"` on named or long-lived boundaries so they don't crossfade during unrelated transitions, and then set `share`/`enter`/`exit` explicitly.
5. Keep transitions short (150–400ms) and encode meaning: morph = same object, slide = spatial direction, crossfade = same place with new content.
6. Unsupported browsers must work normally without animation. Treat the API as progressive enhancement.
7. Always add a `prefers-reduced-motion` override for view-transition pseudo-elements.

## Best Practices
- Put page-level directional `<ViewTransition>` wrappers in each `page.tsx`, not in `layout.tsx`. Layouts persist, so enter and exit never fire there.
- Anchor persistent chrome (header, sidebar) with `viewTransitionName` and `animation: none` so it doesn't slide with content.
- Add `::view-transition { pointer-events: none; }` so clicks during animations reach the live page.
- Use asymmetric timing: exit fast (~150ms) and enter slightly slower (~200–250ms), with movement up to ~400ms.
- Give shared image pairs the same aspect ratio on both sides, or use `object-fit` with a blur keyframe mid-flight to mask interpolation artifacts.
- Tag navigations with types (`nav-forward`, `nav-back`) on `Link` or `router.push(href, { transitionTypes })`. Browser back/forward doesn't carry types, so the default should be `none` or a crossfade.
- For same-route swaps, key the `<ViewTransition>` by the changing param so React treats it as exit/enter (a share pair when named).
- Keep animated names off elements the user clicks rapidly; named participants skip hit-testing during the transition.

## Implementation Guidance

### Browser support (Sept 2026)
| Capability | Chrome/Edge | Safari | Firefox |
|---|---|---|---|
| Same-document `startViewTransition` | 111+ | 18+ | 144+ |
| `view-transition-class`, types | 125+ | 18.2+ | Partial (types arrived later) |
| Cross-document `@view-transition` | 126+ | 18.2+ | Partial |
| `view-transition-name: match-element` | 137+ | Check | Check |
| `document.activeViewTransition` | 142+ | Check | Check |
| Element-scoped `element.startViewTransition()` | Experimental (140+) | No | No |

### Prop semantics for React `<ViewTransition>`
| Prop | Fires when | Values |
|---|---|---|
| `enter` | Boundary inserted in a Transition | `"auto"`, `"none"`, class name, `{ [type]: class, default }` |
| `exit` | Boundary deleted in a Transition | same |
| `update` | DOM inside changes or layout shifts due to siblings | same |
| `share` | Named boundary removed in one place and inserted elsewhere | same |
| `default` | Fallback for any unspecified trigger | usually `"none"` |
| `name` | Identity for shared elements | unique string |
| `onEnter`/`onExit`/`onUpdate`/`onShare` | Imperative WAAPI control | `(instance, types) => cleanup` |

Class names map to `view-transition-class`, so style them with `::view-transition-old(.slide)`, `::view-transition-new(.slide)`, and `::view-transition-group(.slide)`.

### Which trigger to use
| Scenario | Setup |
|---|---|
| Thumbnail → detail morph | Same `name` on both routes + `share="morph" default="none"` |
| Skeleton → content | Fallback wrapped with `exit="..."`, content with `enter="..."` |
| Forward/back slides | `Link transitionTypes`; page wrapper with type-keyed `enter`/`exit` |
| Tab/filter swap in one route | `key={param}` + `enter="auto"` or named `share="auto"` |
| Non-React MPA (marketing pages outside the app) | `@view-transition { navigation: auto; }` |

## Recommended Workflow
1. Confirm React ≥ 19.3 (Vite) or the Next.js App Router version bundling it. Import `ViewTransition` from `react`.
2. Identify meaning per interaction: morph, reveal, direction, or crossfade.
3. Add global CSS: keyframes, class rules, header anchoring, `pointer-events: none`, reduced-motion override.
4. Wrap targets with `<ViewTransition>` and add `default="none"` to named/persistent ones.
5. Tag navigations with `transitionTypes`.
6. Test in Chrome, Safari, and Firefox: animations degrade gracefully, and back/forward and hard reloads behave.
7. Test with reduced motion, keyboard navigation (focus lands on new content), and a slow network (fallbacks).

## Patterns

### Shared element morph (Next.js)
```tsx
// components/photo-grid.tsx (Server Component OK)
import { ViewTransition } from "react";
import Image from "next/image";
import Link from "next/link";

export function PhotoGrid({ photos }: { photos: { id: string; src: string; title: string }[] }) {
  return (
    <ul className="grid grid-cols-3 gap-3">
      {photos.map((p) => (
        <li key={p.id}>
          <Link href={`/photo/${p.id}`} transitionTypes={["nav-forward"]}>
            <ViewTransition name={`photo-${p.id}`} share="morph" default="none">
              <Image src={p.src} alt={p.title} width={400} height={267} />
            </ViewTransition>
          </Link>
        </li>
      ))}
    </ul>
  );
}
```
The detail page renders `<ViewTransition name={`photo-${id}`} share="morph" default="none">` around the hero. The morph forms only if the destination renders in the same commit (prefetched). If it suspends first, the content plays its enter animation instead.

### Suspense reveal
```tsx
<Suspense
  fallback={<ViewTransition exit="slide-down" default="none"><DetailSkeleton /></ViewTransition>}
>
  <ViewTransition enter="slide-up" default="none">
    <PhotoDetail id={id} />
  </ViewTransition>
</Suspense>
```

### Directional page wrapper
```tsx
// components/page-transition.tsx
import { ViewTransition } from "react";

const dir = { "nav-forward": "nav-forward", "nav-back": "nav-back", default: "none" } as const;

export function PageTransition({ children }: { children: React.ReactNode }) {
  return <ViewTransition enter={dir} exit={dir} default="none">{children}</ViewTransition>;
}
// Use inside each page.tsx, not layout.tsx.
```

### Same-page state transition (Vite SPA or client component)
```tsx
"use client";
import { startTransition, addTransitionType, useState, ViewTransition } from "react";

export function Slides({ slides }: { slides: React.ReactNode[] }) {
  const [i, setI] = useState(0);
  const go = (delta: 1 | -1) =>
    startTransition(() => {
      addTransitionType(delta > 0 ? "next" : "prev");
      setI((n) => (n + delta + slides.length) % slides.length);
    });
  return (
    <>
      <ViewTransition key={i} enter={{ next: "from-right", prev: "from-left", default: "auto" }}
        exit={{ next: "to-left", prev: "to-right", default: "auto" }}>
        <div>{slides[i]}</div>
      </ViewTransition>
      <button onClick={() => go(-1)}>Previous</button>
      <button onClick={() => go(1)}>Next</button>
    </>
  );
}
```

### Global CSS
```css
/* app/globals.css */
::view-transition { pointer-events: none; }

::view-transition-group(.morph) { animation-duration: 350ms; }
::view-transition-image-pair(.morph) { animation-name: via-blur; }
@keyframes via-blur { 30% { filter: blur(3px); } }

::view-transition-old(.nav-forward) { animation: 150ms ease-in both fade-out, 350ms cubic-bezier(0.77,0,0.175,1) both slide-to-left; }
::view-transition-new(.nav-forward) { animation: 210ms ease-out 150ms both fade-in, 350ms cubic-bezier(0.77,0,0.175,1) both slide-from-right; }
::view-transition-old(.nav-back)    { animation: 150ms ease-in both fade-out, 350ms cubic-bezier(0.77,0,0.175,1) both slide-to-right; }
::view-transition-new(.nav-back)    { animation: 210ms ease-out 150ms both fade-in, 350ms cubic-bezier(0.77,0,0.175,1) both slide-from-left; }

@keyframes fade-in { from { opacity: 0; } }
@keyframes fade-out { to { opacity: 0; } }
@keyframes slide-from-right { from { translate: 60px; } }
@keyframes slide-from-left  { from { translate: -60px; } }
@keyframes slide-to-left    { to { translate: -60px; } }
@keyframes slide-to-right   { to { translate: 60px; } }

/* anchored header */
::view-transition-group(site-header) { animation: none; z-index: 100; }
::view-transition-old(site-header) { display: none; }
::view-transition-new(site-header) { animation: none; }

@media (prefers-reduced-motion: reduce) {
  ::view-transition-group(*), ::view-transition-old(*), ::view-transition-new(*) {
    animation-duration: 0s !important; animation-delay: 0s !important;
  }
}
```
A gentler reduced-motion option: keep `fade-in`/`fade-out` and remove only the `slide-*` animations.

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| Plain `setState` expecting animation | Only Transitions animate | `startTransition` / navigation / Suspense |
| `<div><ViewTransition>…` for enter/exit | Boundary isn't first in subtree | Put `<ViewTransition>` outermost |
| Same `name` for every list item | Duplicate-name error, no animation | `name={`item-${id}`}` |
| Named boundary without `default="none"` | Crossfades on every unrelated transition | `default="none"` + explicit `share` |
| `default="none"` without `share` on named pair | Morph silently stops | Keep `share="auto"`/class |
| Directional wrapper in `layout.tsx` | Layouts persist; never enter/exit | Put in `page.tsx` |
| Calling `document.startViewTransition` manually in React | Conflicts with React's own call | Use `<ViewTransition>` only |
| `flushSync` in the update | Skips the transition | Remove `flushSync` |
| Long (>500ms) page slides | Blocks clicks on named elements; feels slow | 150–400ms |
| AnimatePresence around App Router `children` for exits | Old segment isn't kept mounted | `<ViewTransition>` |

## Accessibility
- WCAG 2.3.3: provide the reduced-motion CSS override above. Slides are the main vestibular risk; crossfades and small morphs are lower risk.
- Focus: animations don't move focus. After navigation, Next.js announces route changes, but you must still ensure focus starts sensibly (e.g. an `h1` with `tabIndex={-1}` or a skip link) for custom in-page swaps.
- Don't encode meaning only in direction. Pair it with headings and breadcrumbs.
- Snapshots are images during the animation, but the live DOM underneath stays accessible. Keep durations short so screen reader and keyboard users aren't blocked by `pointer-events` capture.

## Responsive Design
- Scale slide offsets with viewport (`translate: min(60px, 8vw)`).
- Morphing between different aspect ratios (mobile card vs desktop hero) distorts. Use `object-fit: cover` on `::view-transition-old/new` of that name and consider `layout`-stable containers.
- On mobile Safari, full-page slides can conflict with edge-swipe back gestures. Use crossfades for untyped (browser) navigations.

## Performance
- Snapshot capture costs memory proportional to named element area. Name only what needs to morph.
- Rendering is paused between snapshot and update. Slow update callbacks (heavy commits) delay the animation; keep transitions to cached or prefetched routes where possible.
- Pseudo-element animations run on the compositor when they use transform/opacity. Avoid animating `width`/`height` on groups with custom keyframes (the default group animation handles size).
- `<ViewTransition>` opts images and fonts into Suspense during load to avoid flicker. Make sure images have explicit sizes so this doesn't delay reveals unexpectedly.

## Security
- No direct risks. Cross-document transitions only work same-origin by design.

## Testing
- Playwright (Chromium/WebKit/Firefox): assert final DOM state after navigation. Use `page.emulateMedia({ reducedMotion: "reduce" })` for deterministic runs.
- For animation QA, record video in Chromium, or use the DevTools Animations panel at 10% speed to inspect `::view-transition-*` pseudo-elements.
- Unit tests in jsdom: `startViewTransition` is absent, so React falls back to an instant update. Test state only.
- Check duplicate-name errors in the console during list operations.

## Tooling
- React 19.3 `ViewTransition`, `addTransitionType` (Stable).
- Next.js App Router: `Link transitionTypes`, `useRouter().push(href, { transitionTypes })` (Active; docs v16.3).
- React Router: `viewTransition` on `Link`/`navigate` wraps DOM updates in `document.startViewTransition` (use CSS classes directly).
- Chrome DevTools Animations panel supports view-transition pseudo-elements.
- `vercel-labs/agent-skills` react-view-transitions skill (Community) — CSS recipes and troubleshooting.

## Framework Notes
- **React (Vite SPA)**: wrap state or route updates in `startTransition`. Whether React Router navigations run inside React Transitions depends on router version and configuration; check the router docs for your version. If they don't, wrap `navigate()` calls in `startTransition` yourself so `<ViewTransition>` activates. Don't combine React Router's `viewTransition` link flag (which calls `document.startViewTransition` directly) with React `<ViewTransition>` on the same navigation.
- **Next.js App Router**: works with no configuration. Navigations are Transitions, and the App Router's bundled React includes `ViewTransition`. `<ViewTransition>` can render in Server Components (it has no client state). `addTransitionType` and `startTransition` handlers need `"use client"`. `template.tsx` isn't needed for route transitions. Prefetched routes are required for shared-element morphs; dynamic uncached pages suspend first and play enter instead.
- **Next.js Pages Router**: no built-in integration. Prefer migrating or use plain CSS entrance animations.
- **Hydration**: view transitions don't run on initial page load, so there's no SSR flash concern. For MPA-style full reloads between separate Next.js apps (zones), use cross-document `@view-transition { navigation: auto; }` in both apps' CSS.

## AI Agent Guidance
- DO import `ViewTransition` from `react` and verify the React version supports it (19.3+, or the Next.js App Router's bundled React).
- DO add `default="none"` to named and persistent boundaries; DO provide unique names; DO add the reduced-motion and `pointer-events` CSS.
- DO put directional wrappers in `page.tsx` and use `Link transitionTypes`.
- DON'T use Motion `AnimatePresence` for App Router exit animations.
- DON'T call `document.startViewTransition` inside React-managed trees.
- Verify: animation works in Chrome and Safari; Firefox degrades or works; back button is sensible; no duplicate-name console errors; reduced motion disables slides; clicks during transitions aren't lost.

## Examples

### Crossfade tab content keyed by route param
```tsx
// app/collection/[slug]/page.tsx
import { Suspense, ViewTransition } from "react";

export default async function CollectionPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  return (
    <Suspense fallback={<GridSkeleton />}>
      <ViewTransition key={slug} name="collection-content" share="auto" enter="auto" default="none">
        <CollectionGrid slug={slug} />
      </ViewTransition>
    </Suspense>
  );
}
```

### Programmatic navigation with type
```tsx
"use client";
import { useRouter } from "next/navigation";

export function NextPhotoButton({ nextId }: { nextId: string }) {
  const router = useRouter();
  return (
    <button onClick={() => router.push(`/photo/${nextId}`, { transitionTypes: ["nav-forward"] })}>
      Next photo
    </button>
  );
}
```

### Imperative WAAPI via onEnter
```tsx
<ViewTransition
  onEnter={(instance) => {
    const a = instance.new.animate([{ opacity: 0, transform: "scale(0.98)" }, { opacity: 1, transform: "none" }],
      { duration: 220, easing: "cubic-bezier(0.23,1,0.32,1)" });
    return () => a.cancel();
  }}
>
  <Panel />
</ViewTransition>
```

## Related Skills
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — Transitions that activate animations
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md) — Suspense reveal behavior
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — layouts vs pages
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — loading states that transition
- [layout-animations](../layout-animations/Skill.md) — when to use Motion layout instead
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — focus and announcements on navigation
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — motion preferences
- [motion-design-principles](../motion-design-principles/Skill.md) — meaning of morph/slide/fade

## Sources
- [React 19.3 release](https://react.dev/blog/2026/09/09/react-19-3) — Official — ViewTransition stable, triggers, addTransitionType
- [React ViewTransition reference](https://react.dev/reference/react/ViewTransition) — Official — props, callbacks, caveats
- [Next.js: Designing view transitions](https://nextjs.org/docs/app/guides/view-transitions) — Official — Link transitionTypes, patterns, CSS, reduced motion
- [MDN View Transition API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API) — Official — pseudo-elements, events, types
- [Chrome: View transitions in 2025](https://developer.chrome.com/blog/view-transitions-in-2025) — Official — Firefox 144, match-element, scoped transitions
- [Chrome view transitions docs](https://developer.chrome.com/docs/web-platform/view-transitions) — Official — support matrix
- [Can I use: cross-document view transitions](https://caniuse.com/cross-document-view-transitions) — Community — cross-doc support
- [vercel-labs/agent-skills react-view-transitions](https://github.com/vercel-labs/agent-skills) — Community — agent skill patterns

## License / Usage Notes
React (MIT), Next.js (MIT). Docs content is summarized; CSS recipes are adapted and rewritten.

## Quality Tier
S — Verified against the React 19.3 release, React reference, and Next.js 16.3 guide from the past month. Some Safari/Firefox sub-feature versions are marked "Check".

## Status
Active

## Last Verified
2026-09-15
